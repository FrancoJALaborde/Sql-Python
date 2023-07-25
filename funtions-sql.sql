CREATE OR REPLACE FUNCTION plot_graph1_sql()
RETURNS TEXT AS
$$
DECLARE
    chart_data TEXT;
BEGIN
    -- Step 1: Merge customers and sales tables using 'CustomerID'
    CREATE TEMPORARY TABLE temp_customer_sales AS
    SELECT c.CustomerID, c.Age_Range, s.SaleAmount
    FROM customers c
    INNER JOIN sales s ON c.CustomerID = s.CustomerID;

    -- Step 2: Merge the combined table with salepoints table using 'BranchID'
    CREATE TEMPORARY TABLE temp_customer_sales_salepoints AS
    SELECT cs.CustomerID, cs.Age_Range, cs.SaleAmount, sp.BranchID
    FROM temp_customer_sales cs
    INNER JOIN salepoints sp ON cs.BranchID = sp.BranchID;

    -- Step 3: Group by age range (Age_Range) and BranchID to count the number of customers in each category
    CREATE TEMPORARY TABLE temp_age_branch_counts AS
    SELECT Age_Range, BranchID, COUNT(DISTINCT CustomerID) AS num_customers
    FROM temp_customer_sales_salepoints
    GROUP BY Age_Range, BranchID;

    -- Step 4: Return the chart data as a string in JSON format
    SELECT json_object_agg(Age_Range, json_object_agg(BranchID, num_customers)) INTO chart_data
    FROM temp_age_branch_counts;

    -- Step 5: Free up temporary tables
    DROP TABLE IF EXISTS temp_customer_sales_salepoints;
    DROP TABLE IF EXISTS temp_customer_sales;
    DROP TABLE IF EXISTS temp_age_branch_counts;

    -- Step 6: Return the chart data
    RETURN chart_data;
END;
$$
LANGUAGE plpgsql;



CREATE OR REPLACE FUNCTION plot_graph2_sql()
RETURNS TEXT AS
$$
DECLARE
    chart_data TEXT;
BEGIN
    -- Step 1: Merge customers, sales, and products tables based on 'CustomerID' and 'ProductID'
    CREATE TEMPORARY TABLE temp_customer_sales_products AS
    SELECT c.CustomerID, c.Age_Range, p.ProductName, s.Quantity
    FROM customers c
    INNER JOIN sales s ON c.CustomerID = s.CustomerID
    INNER JOIN products p ON s.ProductID = p.ProductID;

    -- Step 2: Group by age range and product name to calculate the total quantity of each product bought by customers in each age range
    CREATE TEMPORARY TABLE temp_product_quantity_by_age_range AS
    SELECT Age_Range, ProductName, SUM(Quantity) AS total_quantity
    FROM temp_customer_sales_products
    GROUP BY Age_Range, ProductName;

    -- Step 3: Get the top 5 products for each age range based on total quantity sold
    CREATE TEMPORARY TABLE temp_top_5_products_by_age_range AS
    SELECT Age_Range, ProductName, total_quantity,
           ROW_NUMBER() OVER (PARTITION BY Age_Range ORDER BY total_quantity DESC) AS rn
    FROM temp_product_quantity_by_age_range;

    -- Step 4: Filter for the top 5 products for each age range
    CREATE TEMPORARY TABLE temp_top_5_products AS
    SELECT Age_Range, ProductName, total_quantity
    FROM temp_top_5_products_by_age_range
    WHERE rn <= 5;

    -- Step 5: Return the chart data as a string in JSON format
    SELECT json_object_agg(Age_Range, json_object_agg(ProductName, total_quantity)) INTO chart_data
    FROM temp_top_5_products;

    -- Step 6: Free up temporary tables
    DROP TABLE IF EXISTS temp_top_5_products;
    DROP TABLE IF EXISTS temp_top_5_products_by_age_range;
    DROP TABLE IF EXISTS temp_product_quantity_by_age_range;
    DROP TABLE IF EXISTS temp_customer_sales_products;

    -- Step 7: Return the chart data
    RETURN chart_data;
END;
$$
LANGUAGE plpgsql;


CREATE OR REPLACE FUNCTION plot_graph3_sql()
RETURNS TEXT AS
$$
DECLARE
    chart_data TEXT;
BEGIN
    -- Step 1: Get the top 5 products for each age range based on total quantity sold
    CREATE TEMPORARY TABLE temp_customer_sales_products AS
    SELECT c.CustomerID, c.Age_Range, s.ProductID, s.Quantity, s.EmployeeID
    FROM customers c
    INNER JOIN sales s ON c.CustomerID = s.CustomerID;

    CREATE TEMPORARY TABLE temp_product_quantity_by_age_range AS
    SELECT Age_Range, ProductID, SUM(Quantity) AS total_quantity
    FROM temp_customer_sales_products
    GROUP BY Age_Range, ProductID;

    CREATE TEMPORARY TABLE temp_top_5_products_by_age_range AS
    SELECT Age_Range, ProductID, total_quantity,
           ROW_NUMBER() OVER (PARTITION BY Age_Range ORDER BY total_quantity DESC) AS rn
    FROM temp_product_quantity_by_age_range;

    CREATE TEMPORARY TABLE temp_top_5_products AS
    SELECT Age_Range, ProductID
    FROM temp_top_5_products_by_age_range
    WHERE rn <= 5;

    -- Step 2: Filter sales to include only the products in the top 5 for each age range
    CREATE TEMPORARY TABLE temp_sales_top_5_products AS
    SELECT s.SaleID, s.CustomerID, s.ProductID, s.Quantity, s.EmployeeID
    FROM sales s
    INNER JOIN temp_top_5_products t ON s.ProductID = t.ProductID;

    -- Step 3: Merge sales_top_5_products with employees to get all the information about the employees who made sales of top 5 products
    CREATE TEMPORARY TABLE temp_top_employees_sales AS
    SELECT s.SaleID, s.CustomerID, s.ProductID, s.Quantity, s.EmployeeID, e.Firstname, e.Lastname
    FROM temp_sales_top_5_products s
    LEFT JOIN employees e ON s.EmployeeID = e.EmployeeID;

    -- Step 4: Group top_employees_sales by EmployeeID and ProductID and calculate the total quantity sold for each product by each employee
    CREATE TEMPORARY TABLE temp_employee_sales_by_product AS
    SELECT EmployeeID, ProductID, SUM(Quantity) AS Quantity_Employee
    FROM temp_top_employees_sales
    GROUP BY EmployeeID, ProductID;

    -- Step 5: Find the EmployeeID with the highest total quantity sold for each product
    CREATE TEMPORARY TABLE temp_top_employees_by_product AS
    SELECT ProductID, EmployeeID, Quantity_Employee,
           ROW_NUMBER() OVER (PARTITION BY ProductID ORDER BY Quantity_Employee DESC) AS rn
    FROM temp_employee_sales_by_product;

    -- Step 6: Merge with the product names and employee names for better visualization
    CREATE TEMPORARY TABLE temp_top_employees_by_product_with_names AS
    SELECT t.ProductID, t.EmployeeID, t.Quantity_Employee, p.ProductName, e.Firstname, e.Lastname
    FROM temp_top_employees_by_product t
    LEFT JOIN products p ON t.ProductID = p.ProductID
    LEFT JOIN employees e ON t.EmployeeID = e.EmployeeID
    WHERE t.rn = 1;

    -- Step 7: Combine Firstname, Lastname, and EmployeeID into a single column
    CREATE TEMPORARY TABLE temp_combined_employee_name AS
    SELECT EmployeeID, CONCAT(Firstname, ' ', Lastname, ' ', EmployeeID) AS EmployeeName
    FROM temp_top_employees_by_product_with_names;

    -- Step 8: Drop unnecessary columns
    CREATE TEMPORARY TABLE temp_top_employees_final AS
    SELECT ProductName, EmployeeName, Quantity_Employee
    FROM temp_top_employees_by_product_with_names
    DROP COLUMN EmployeeID, Firstname, Lastname;

    -- Step 9: Sort the DataFrame by EmployeeName and Quantity_Employee in descending order
    CREATE TEMPORARY TABLE temp_sorted_top_employees AS
    SELECT ProductName, EmployeeName, Quantity_Employee
    FROM temp_top_employees_final
    ORDER BY EmployeeName ASC, Quantity_Employee DESC;

    -- Step 10: Reset the index for better visualization
    CREATE TEMPORARY TABLE temp_sorted_top_employees_with_index AS
    SELECT ROW_NUMBER() OVER () - 1 AS index, ProductName, EmployeeName, Quantity_Employee
    FROM temp_sorted_top_employees;

    -- Step 11: Plot the bar chart for the top employees by product
    -- You will need a separate charting library compatible with your SQL database to create the chart directly in SQL.
    -- The chart data can be returned as a JSON object or any other format suitable for your charting library.

    -- Step 12: Convert the chart data to a suitable format for return
    -- For example, you can convert the chart data to JSON format.

    -- ...

    -- Step 13: Return the chart data
    -- For example, you can return the JSON object containing the chart data.

    -- ...

    -- Step 14: Free up temporary tables
    DROP TABLE IF EXISTS temp_sorted_top_employees_with_index;
    DROP TABLE IF EXISTS temp_sorted_top_employees;
    DROP TABLE IF EXISTS temp_top_employees_final;
    DROP TABLE IF EXISTS temp_combined_employee_name;
    DROP TABLE IF EXISTS temp_top_employees_by_product_with_names;
    DROP TABLE IF EXISTS temp_top_employees_by_product;
    DROP TABLE IF EXISTS temp_employee_sales_by_product;
    DROP TABLE IF EXISTS temp_top_employees_sales;
    DROP TABLE IF EXISTS temp_sales_top_5_products;
    DROP TABLE IF EXISTS temp_top_5_products;
    DROP TABLE IF EXISTS temp_top_5_products_by_age_range;
    DROP TABLE IF EXISTS temp_product_quantity_by_age_range;
    DROP TABLE IF EXISTS temp_customer_sales_products;

    -- Step 15: Return the chart data
    -- This is a placeholder since the actual chart data and return format would depend on the specific SQL database and charting library used.
    RETURN 'Chart data not implemented';
END;
$$
LANGUAGE plpgsql;


CREATE OR REPLACE FUNCTION plot_graph4_sql()
RETURNS TEXT AS
$$
DECLARE
    chart_data TEXT;
BEGIN
    -- Step 1: Merge the DataFrames using 'ExpenseTypeID' column
    CREATE TEMPORARY TABLE temp_merged_data AS
    SELECT e.ExpenseID, e.ExpenseTypeID, e.Amount, et.Expense_Type
    FROM expenses e
    INNER JOIN expensetypes et ON e.ExpenseTypeID = et.ExpenseTypeID;

    -- Step 2: Calculate total expenses for each expense type
    CREATE TEMPORARY TABLE temp_total_expenses_per_type AS
    SELECT Expense_Type, SUM(Amount) AS total_expenses
    FROM temp_merged_data
    GROUP BY Expense_Type;

    -- Step 3: Return the chart data as a string in JSON format
    SELECT json_object_agg(Expense_Type, total_expenses) INTO chart_data
    FROM temp_total_expenses_per_type;

    -- Step 4: Free up temporary tables
    DROP TABLE IF EXISTS temp_total_expenses_per_type;
    DROP TABLE IF EXISTS temp_merged_data;

    -- Step 5: Return the chart data
    RETURN chart_data;
END;
$$
LANGUAGE plpgsql;



CREATE OR REPLACE FUNCTION plot_graph5_sql()
RETURNS TEXT AS
$$
DECLARE
    chart_data TEXT;
BEGIN
    -- Step 1: Calculate total sales grouped by year (summing the quantities)
    CREATE TEMPORARY TABLE temp_sales_grouped AS
    SELECT EXTRACT(YEAR FROM "Date") AS Year, SUM(Quantity) AS total_sales
    FROM sales
    GROUP BY EXTRACT(YEAR FROM "Date");

    -- Step 2: Return the chart data as a string in JSON format
    SELECT json_object_agg(Year, total_sales) INTO chart_data
    FROM temp_sales_grouped;

    -- Step 3: Free up temporary tables
    DROP TABLE IF EXISTS temp_sales_grouped;

    -- Step 4: Return the chart data
    RETURN chart_data;
END;
$$
LANGUAGE plpgsql;



CREATE OR REPLACE FUNCTION plot_graph6_sql()
RETURNS TEXT AS
$$
DECLARE
    chart_data TEXT;
    year_with_most_sales INTEGER;
BEGIN
    -- Step 1: Calculate total sales grouped by month in the year with the most sales
    CREATE TEMPORARY TABLE temp_sales_with_year AS
    SELECT EXTRACT(YEAR FROM "Date") AS Year, EXTRACT(MONTH FROM "Date") AS Month, Quantity
    FROM sales;

    CREATE TEMPORARY TABLE temp_sales_grouped_by_year AS
    SELECT Year, SUM(Quantity) AS total_sales
    FROM temp_sales_with_year
    GROUP BY Year;

    -- Get the year with the most sales
    SELECT Year INTO year_with_most_sales
    FROM temp_sales_grouped_by_year
    ORDER BY total_sales DESC
    LIMIT 1;

    -- Get the sales data for the year with the most sales
    CREATE TEMPORARY TABLE temp_sales_in_year_with_most_sales AS
    SELECT Year, Month, Quantity
    FROM temp_sales_with_year
    WHERE Year = year_with_most_sales;

    -- Group sales by month and calculate total sales per month in the year with the most sales
    CREATE TEMPORARY TABLE temp_sales_grouped_by_month AS
    SELECT Month, SUM(Quantity) AS total_sales
    FROM temp_sales_in_year_with_most_sales
    GROUP BY Month;

    -- Normalize the sales data to the range [0, 1]
    CREATE TEMPORARY TABLE temp_normalized_sales AS
    SELECT Month, (total_sales - MIN(total_sales)) / (MAX(total_sales) - MIN(total_sales)) AS normalized_sales
    FROM temp_sales_grouped_by_month;

    -- Step 2: Return the chart data as a string in JSON format
    SELECT json_object_agg(Month, total_sales) INTO chart_data
    FROM temp_sales_grouped_by_month;

    -- Step 3: Free up temporary tables
    DROP TABLE IF EXISTS temp_normalized_sales;
    DROP TABLE IF EXISTS temp_sales_grouped_by_month;
    DROP TABLE IF EXISTS temp_sales_in_year_with_most_sales;
    DROP TABLE IF EXISTS temp_sales_grouped_by_year;
    DROP TABLE IF EXISTS temp_sales_with_year;

    -- Step 4: Return the chart data
    RETURN chart_data;
END;
$$
LANGUAGE plpgsql;



CREATE OR REPLACE FUNCTION plot_graph7_sql()
RETURNS TEXT AS
$$
DECLARE
    chart_data TEXT;
    year_with_highest_sales INTEGER;
BEGIN
    -- Step 1: Calculate total sales grouped by year and product
    CREATE TEMPORARY TABLE temp_sales_with_year AS
    SELECT EXTRACT(YEAR FROM "Date") AS Year, EXTRACT(MONTH FROM "Date") AS Month, ProductID, Quantity
    FROM sales;

    CREATE TEMPORARY TABLE temp_sales_grouped_by_year_product AS
    SELECT Year, Month, ProductID, SUM(Quantity) AS total_sales
    FROM temp_sales_with_year
    GROUP BY Year, Month, ProductID;

    -- Step 2: Find the year with the highest sales
    CREATE TEMPORARY TABLE temp_sales_grouped_by_year AS
    SELECT Year, SUM(total_sales) AS total_sales
    FROM temp_sales_grouped_by_year_product
    GROUP BY Year;

    SELECT Year INTO year_with_highest_sales
    FROM temp_sales_grouped_by_year
    ORDER BY total_sales DESC
    LIMIT 1;

    -- Step 3: Filter the data for the year with the highest sales
    CREATE TEMPORARY TABLE temp_sales_in_year_with_highest_sales AS
    SELECT Year, Month, ProductID, total_sales
    FROM temp_sales_grouped_by_year_product
    WHERE Year = year_with_highest_sales;

    -- Step 4: Find the most sold product in each month of the year with highest sales
    CREATE TEMPORARY TABLE temp_most_sold_products_by_month AS
    SELECT Month, ProductID, SUM(total_sales) AS total_sales
    FROM temp_sales_in_year_with_highest_sales
    GROUP BY Month, ProductID;

    CREATE TEMPORARY TABLE temp_most_sold_products AS
    SELECT Month, ProductID
    FROM temp_most_sold_products_by_month
    WHERE (Month, total_sales) IN (
        SELECT Month, MAX(total_sales) AS total_sales
        FROM temp_most_sold_products_by_month
        GROUP BY Month
    );

    -- Step 5: Get the product names for better visualization
    CREATE TEMPORARY TABLE temp_most_sold_products_with_names AS
    SELECT m.Month, m.ProductID, p.ProductName, m.total_sales
    FROM temp_most_sold_products m
    LEFT JOIN products p ON m.ProductID = p.ProductID;

    -- Step 6: Calculate total sales grouped by month in the year with the most sales
    CREATE TEMPORARY TABLE temp_sales_grouped_by_month AS
    SELECT EXTRACT(MONTH FROM "Date") AS Month, SUM(Quantity) AS total_sales
    FROM sales
    WHERE EXTRACT(YEAR FROM "Date") = year_with_highest_sales
    GROUP BY EXTRACT(MONTH FROM "Date");

    -- Step 7: Normalize the sales data to the range [0, 1]
    CREATE TEMPORARY TABLE temp_normalized_sales AS
    SELECT Month, (total_sales - MIN(total_sales)) / (MAX(total_sales) - MIN(total_sales)) AS normalized_sales
    FROM temp_sales_grouped_by_month;

    -- Step 8: Return the chart data as a string in JSON format
    SELECT json_object_agg(ProductName, total_sales) INTO chart_data
    FROM temp_most_sold_products_with_names;

    -- Step 9: Free up temporary tables
    DROP TABLE IF EXISTS temp_normalized_sales;
    DROP TABLE IF EXISTS temp_sales_grouped_by_month;
    DROP TABLE IF EXISTS temp_most_sold_products_with_names;
    DROP TABLE IF EXISTS temp_most_sold_products;
    DROP TABLE IF EXISTS temp_most_sold_products_by_month;
    DROP TABLE IF EXISTS temp_sales_in_year_with_highest_sales;
    DROP TABLE IF EXISTS temp_sales_grouped_by_year_product;
    DROP TABLE IF EXISTS temp_sales_grouped_by_year;
    DROP TABLE IF EXISTS temp_sales_with_year;

    -- Step 10: Return the chart data
    RETURN chart_data;
END;
$$
LANGUAGE plpgsql;




CREATE OR REPLACE FUNCTION plot_graph8_sql()
RETURNS TEXT AS
$$
DECLARE
    chart_data TEXT;
    year_with_highest_sales INTEGER;
BEGIN
    -- Step 1: Calculate total sales grouped by year and product
    CREATE TEMPORARY TABLE temp_sales_with_year AS
    SELECT EXTRACT(YEAR FROM "Date") AS Year, EXTRACT(MONTH FROM "Date") AS Month, ProductID, Quantity
    FROM sales;

    CREATE TEMPORARY TABLE temp_sales_grouped_by_year_product AS
    SELECT Year, Month, ProductID, SUM(Quantity) AS total_sales
    FROM temp_sales_with_year
    GROUP BY Year, Month, ProductID;

    -- Step 2: Find the year with the highest sales
    CREATE TEMPORARY TABLE temp_sales_grouped_by_year AS
    SELECT Year, SUM(total_sales) AS total_sales
    FROM temp_sales_grouped_by_year_product
    GROUP BY Year;

    SELECT Year INTO year_with_highest_sales
    FROM temp_sales_grouped_by_year
    ORDER BY total_sales DESC
    LIMIT 1;

    -- Step 3: Filter the data for the year with the highest sales
    CREATE TEMPORARY TABLE temp_sales_in_year_with_highest_sales AS
    SELECT Year, Month, ProductID, total_sales
    FROM temp_sales_grouped_by_year_product
    WHERE Year = year_with_highest_sales;

    -- Step 4: Find the least sold product in each month of the year with highest sales
    CREATE TEMPORARY TABLE temp_least_sold_products_by_month AS
    SELECT Month, ProductID, SUM(total_sales) AS total_sales
    FROM temp_sales_in_year_with_highest_sales
    GROUP BY Month, ProductID;

    CREATE TEMPORARY TABLE temp_least_sold_products AS
    SELECT Month, ProductID
    FROM temp_least_sold_products_by_month
    WHERE (Month, total_sales) IN (
        SELECT Month, MIN(total_sales) AS total_sales
        FROM temp_least_sold_products_by_month
        GROUP BY Month
    );

    -- Step 5: Get the product names for better visualization
    CREATE TEMPORARY TABLE temp_least_sold_products_with_names AS
    SELECT m.Month, m.ProductID, p.ProductName, m.total_sales
    FROM temp_least_sold_products m
    LEFT JOIN products p ON m.ProductID = p.ProductID;

    -- Step 6: Calculate total sales grouped by month in the year with the most sales
    CREATE TEMPORARY TABLE temp_sales_grouped_by_month AS
    SELECT EXTRACT(MONTH FROM "Date") AS Month, SUM(Quantity) AS total_sales
    FROM sales
    WHERE EXTRACT(YEAR FROM "Date") = year_with_highest_sales
    GROUP BY EXTRACT(MONTH FROM "Date");

    -- Step 7: Normalize the sales data to the range [0, 1]
    CREATE TEMPORARY TABLE temp_normalized_sales AS
    SELECT Month, (total_sales - MIN(total_sales)) / (MAX(total_sales) - MIN(total_sales)) AS normalized_sales
    FROM temp_sales_grouped_by_month;

    -- Step 8: Return the chart data as a string in JSON format
    SELECT json_object_agg(ProductName, total_sales) INTO chart_data
    FROM temp_least_sold_products_with_names;

    -- Step 9: Free up temporary tables
    DROP TABLE IF EXISTS temp_normalized_sales;
    DROP TABLE IF EXISTS temp_sales_grouped_by_month;
    DROP TABLE IF EXISTS temp_least_sold_products_with_names;
    DROP TABLE IF EXISTS temp_least_sold_products;
    DROP TABLE IF EXISTS temp_least_sold_products_by_month;
    DROP TABLE IF EXISTS temp_sales_in_year_with_highest_sales;
    DROP TABLE IF EXISTS temp_sales_grouped_by_year_product;
    DROP TABLE IF EXISTS temp_sales_grouped_by_year;
    DROP TABLE IF EXISTS temp_sales_with_year;

    -- Step 10: Return the chart data
    RETURN chart_data;
END;
$$
LANGUAGE plpgsql;



CREATE OR REPLACE FUNCTION plot_graph9_sql()
RETOURS TEXT AS
$$
DECLARE
    chart_data TEXT;
    year_with_least_sales INTEGER;
BEGIN
    -- Step 1: Calculate total sales grouped by month in the year with the least sales
    CREATE TEMPORARY TABLE temp_sales_with_year AS
    SELECT EXTRACT(YEAR FROM "Date") AS Year, EXTRACT(MONTH FROM "Date") AS Month, ProductID, Quantity
    FROM sales;

    CREATE TEMPORARY TABLE temp_sales_grouped_by_year AS
    SELECT Year, SUM(Quantity) AS total_sales
    FROM temp_sales_with_year
    GROUP BY Year;

    SELECT Year INTO year_with_least_sales
    FROM temp_sales_grouped_by_year
    ORDER BY total_sales ASC
    LIMIT 1;

    CREATE TEMPORARY TABLE temp_sales_in_year_with_least_sales AS
    SELECT Year, Month, ProductID, Quantity
    FROM temp_sales_with_year
    WHERE Year = year_with_least_sales;

    CREATE TEMPORARY TABLE temp_sales_grouped_by_month AS
    SELECT Month, SUM(Quantity) AS total_sales
    FROM temp_sales_in_year_with_least_sales
    GROUP BY Month;

    -- Step 2: Normalize the sales data to the range [0, 1]
    CREATE TEMPORARY TABLE temp_normalized_sales AS
    SELECT Month, (total_sales - MIN(total_sales)) / (MAX(total_sales) - MIN(total_sales)) AS normalized_sales
    FROM temp_sales_grouped_by_month;

    -- Step 3: Return the chart data as a string in JSON format
    SELECT json_object_agg(Month, total_sales) INTO chart_data
    FROM temp_normalized_sales;

    -- Step 4: Free up temporary tables
    DROP TABLE IF EXISTS temp_normalized_sales;
    DROP TABLE IF EXISTS temp_sales_grouped_by_month;
    DROP TABLE IF EXISTS temp_sales_in_year_with_least_sales;
    DROP TABLE IF EXISTS temp_sales_grouped_by_year;
    DROP TABLE IF EXISTS temp_sales_with_year;

    -- Step 5: Return the chart data
    RETURN chart_data;
END;
$$
LANGUAGE plpgsql;



CREATE OR REPLACE FUNCTION plot_graph10_sql()
RETURNS TEXT AS
$$
DECLARE
    chart_data TEXT;
    year_with_least_sales INTEGER;
BEGIN
    -- Step 1: Calculate total sales grouped by year and product
    CREATE TEMPORARY TABLE temp_sales_with_year AS
    SELECT EXTRACT(YEAR FROM "Date") AS Year, EXTRACT(MONTH FROM "Date") AS Month, ProductID, Quantity
    FROM sales;

    CREATE TEMPORARY TABLE temp_sales_grouped_by_year AS
    SELECT Year, SUM(Quantity) AS total_sales
    FROM temp_sales_with_year
    GROUP BY Year;

    SELECT Year INTO year_with_least_sales
    FROM temp_sales_grouped_by_year
    ORDER BY total_sales ASC
    LIMIT 1;

    CREATE TEMPORARY TABLE temp_sales_in_year_with_least_sales AS
    SELECT Year, Month, ProductID, Quantity
    FROM temp_sales_with_year
    WHERE Year = year_with_least_sales;

    CREATE TEMPORARY TABLE temp_sales_grouped_by_month AS
    SELECT Month, SUM(Quantity) AS total_sales
    FROM temp_sales_in_year_with_least_sales
    GROUP BY Month;

    -- Step 2: Normalize the sales data to the range [0, 1]
    CREATE TEMPORARY TABLE temp_normalized_sales AS
    SELECT Month, (total_sales - MIN(total_sales)) / (MAX(total_sales) - MIN(total_sales)) AS normalized_sales
    FROM temp_sales_grouped_by_month;

    -- Step 3: Return the chart data as a string in JSON format
    SELECT json_object_agg(Month, total_sales) INTO chart_data
    FROM temp_normalized_sales;

    -- Step 4: Free up temporary tables
    DROP TABLE IF EXISTS temp_normalized_sales;
    DROP TABLE IF EXISTS temp_sales_grouped_by_month;
    DROP TABLE IF EXISTS temp_sales_in_year_with_least_sales;
    DROP TABLE IF EXISTS temp_sales_grouped_by_year;
    DROP TABLE IF EXISTS temp_sales_with_year;

    -- Step 5: Return the chart data
    RETURN chart_data;
END;
$$
LANGUAGE plpgsql;



CREATE OR REPLACE FUNCTION plot_graph11_sql()
RETURNS TEXT AS
$$
DECLARE
    chart_data TEXT;
    year_with_lowest_sales INTEGER;
BEGIN
    -- Step 1: Calculate total sales grouped by year and product
    CREATE TEMPORARY TABLE temp_sales_with_year AS
    SELECT EXTRACT(YEAR FROM "Date") AS Year, EXTRACT(MONTH FROM "Date") AS Month, ProductID, Quantity
    FROM sales;

    CREATE TEMPORARY TABLE temp_sales_grouped_by_year AS
    SELECT Year, SUM(Quantity) AS total_sales
    FROM temp_sales_with_year
    GROUP BY Year;

    SELECT Year INTO year_with_lowest_sales
    FROM temp_sales_grouped_by_year
    ORDER BY total_sales ASC
    LIMIT 1;

    CREATE TEMPORARY TABLE temp_sales_in_year_with_lowest_sales AS
    SELECT Year, Month, ProductID, Quantity
    FROM temp_sales_with_year
    WHERE Year = year_with_lowest_sales;

    CREATE TEMPORARY TABLE temp_sales_grouped_by_month AS
    SELECT Month, SUM(Quantity) AS total_sales
    FROM temp_sales_in_year_with_lowest_sales
    GROUP BY Month;

    -- Step 2: Normalize the sales data to the range [0, 1]
    CREATE TEMPORARY TABLE temp_normalized_sales AS
    SELECT Month, (total_sales - MIN(total_sales)) / (MAX(total_sales) - MIN(total_sales)) AS normalized_sales
    FROM temp_sales_grouped_by_month;

    -- Step 3: Return the chart data as a string in JSON format
    SELECT json_object_agg(Month, total_sales) INTO chart_data
    FROM temp_normalized_sales;

    -- Step 4: Free up temporary tables
    DROP TABLE IF EXISTS temp_normalized_sales;
    DROP TABLE IF EXISTS temp_sales_grouped_by_month;
    DROP TABLE IF EXISTS temp_sales_in_year_with_lowest_sales;
    DROP TABLE IF EXISTS temp_sales_grouped_by_year;
    DROP TABLE IF EXISTS temp_sales_with_year;

    -- Step 5: Return the chart data
    RETURN chart_data;
END;
$$
LANGUAGE plpgsql;