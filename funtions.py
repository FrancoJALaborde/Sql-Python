import base64
import pandas as pd
import matplotlib.pyplot as plt
import io
from fastapi.responses import HTMLResponse


calendar = pd.read_csv("Data-csv/calendar.csv")
channels = pd.read_csv("Data-csv/channels.csv")
customers = pd.read_csv("Data-csv/customers.csv")
employees = pd.read_csv("Data-csv/employees.csv")
expensetypes = pd.read_csv("Data-csv/expense-types.csv")
expenses = pd.read_csv("Data-csv/expenses.csv")
products = pd.read_csv("Data-csv/products.csv")
salepoints = pd.read_csv("Data-csv/sale-points.csv")
sales = pd.read_csv("Data-csv/sales.csv")


def plot_graph1():
    # Step 1: Merge customers and sales DataFrames using 'CustomerID'
    customer_sales = customers.merge(sales, on="CustomerID", how="inner")

    # Step 2: Merge the combined DataFrame with salepoints DataFrame using 'BranchID'
    customer_sales_salepoints = customer_sales.merge(
        salepoints, on="BranchID", how="inner"
    )

    # Step 3: Group by age range (Age_Range) and BranchID to count the number of customers in each category
    age_branch_counts = (
        customer_sales_salepoints.groupby(["Age_Range", "BranchID"]).size().unstack()
    )

    # Step 4: Create the stacked bar chart
    age_branch_counts.plot(kind="bar", stacked=True, figsize=(16, 8))
    plt.xlabel("Age Range")
    plt.ylabel("Number of Customers")
    plt.title("Distribution of customers by age range and Branch")
    plt.legend(title="BranchID", loc="upper right", fontsize=6)
    plt.tight_layout()

    # Step 5: Save the chart to a BytesIO object to return it in the response
    buffer = io.BytesIO()
    plt.savefig(buffer, format="png")
    buffer.seek(0)

    # Step 6: Close the figure to free up memory
    plt.close()

    # Step 7: Read the chart from the BytesIO object and convert it to a base64 string
    data = buffer.getvalue()
    data_base64 = base64.b64encode(data).decode()

    # Step 8: Create the HTML response with the embedded image
    html_content = f'<img src="data:image/png;base64,{data_base64}" />'
    return HTMLResponse(content=html_content)


def plot_graph2():
    # Step 1: Merge customers, sales, and products DataFrames based on 'CustomerID' and 'ProductID'
    customer_sales_products = customers.merge(
        sales, on="CustomerID", how="inner"
    ).merge(products, on="ProductID", how="inner")

    # Step 2: Group by age range and product name to calculate the total quantity of each product bought by customers in each age range
    product_quantity_by_age_range = customer_sales_products.groupby(
        ["Age_Range", "Product"]
    )["Quantity"].sum()

    # Step 3: Get the top 5 products for each age range based on total quantity sold
    top_5_products_by_age_range = (
        product_quantity_by_age_range.groupby("Age_Range")
        .nlargest(5)
        .reset_index(level=0, drop=True)
    )

    # Step 4: Plot the bar chart for the top 5 products in each age range
    ax = top_5_products_by_age_range.unstack().plot(kind="bar", figsize=(16, 8))
    plt.xlabel("Age Range")
    plt.ylabel("Total Quantity Sold")
    plt.title("Top 5 Selling Products by Age Range")
    plt.legend(title="Product", loc="upper right", fontsize=6)
    plt.tight_layout()

    # Step 5: Save the chart to a BytesIO object to return it in the response
    buffer = io.BytesIO()
    plt.savefig(buffer, format="png")
    buffer.seek(0)

    # Step 6: Close the figure to free up memory
    plt.close()

    # Step 7: Read the chart from the BytesIO object and convert it to a base64 string
    data = buffer.getvalue()
    data_base64 = base64.b64encode(data).decode()

    # Step 8: Create the HTML response with the embedded image
    html_content = f'<img src="data:image/png;base64,{data_base64}" />'
    return HTMLResponse(content=html_content)


def plot_graph3():
    # Step 1: Get the top 5 products for each age range based on total quantity sold
    customer_sales_products = customers.merge(
        sales, on="CustomerID", how="inner"
    ).merge(products, on="ProductID", how="inner")
    product_quantity_by_age_range = (
        customer_sales_products.groupby(["Age_Range", "ProductID"])["Quantity"]
        .sum()
        .reset_index()
    )
    top_5_products_by_age_range = (
        product_quantity_by_age_range.groupby("Age_Range")
        .apply(lambda x: x.nlargest(5, "Quantity"))
        .reset_index(drop=True)
    )

    # Step 2: Filter sales to include only the products in the top 5 for each age range
    sales_top_5_products = sales[
        sales["ProductID"].isin(top_5_products_by_age_range["ProductID"])
    ]

    # Step 3: Merge sales_top_5_products with employees to get all the information about the employees who made sales of top 5 products
    top_employees_sales = sales_top_5_products.merge(
        employees, on="EmployeeID", how="left"
    )

    # Step 4: Group top_employees_sales by EmployeeID and ProductID and calculate the total quantity sold for each product by each employee
    employee_sales_by_product = (
        top_employees_sales.groupby(["EmployeeID", "ProductID"])["Quantity"]
        .sum()
        .reset_index()
    )

    # Step 5: Find the EmployeeID with the highest total quantity sold for each product
    top_employees_by_product = (
        employee_sales_by_product.groupby("ProductID")
        .apply(lambda x: x.nlargest(1, "Quantity"))
        .reset_index(drop=True)
    )

    # Step 6: Merge with the product names and employee names for better visualization
    top_employees_by_product = top_employees_by_product.merge(
        products[["ProductID", "Product"]],
        on="ProductID",
        how="left",
        suffixes=("_Employee", "_Product"),
    )
    top_employees_by_product = top_employees_by_product.merge(
        employees[["EmployeeID", "Firstname", "Lastname"]], on="EmployeeID", how="left"
    )

    # Step 7: Combine Firstname, Lastname, and EmployeeID into a single column
    top_employees_by_product["EmployeeName"] = (
        top_employees_by_product["Firstname"]
        + " "
        + top_employees_by_product["Lastname"]
        + " "
        + top_employees_by_product["EmployeeID"].astype(str)
    )

    # Step 8: Drop unnecessary columns
    top_employees_by_product.drop(
        ["ProductID", "Firstname", "Lastname"], axis=1, inplace=True
    )

    # Step 9: Rename the Quantity column to Quantity_Employee
    top_employees_by_product.rename(
        columns={"Quantity": "Quantity_Employee"}, inplace=True
    )

    # Step 10: Sort the DataFrame by EmployeeName and Quantity_Employee in descending order
    top_employees_by_product.sort_values(
        by=["EmployeeName", "Quantity_Employee"], ascending=[True, False], inplace=True
    )

    # Step 11: Reset the index for better visualization
    top_employees_by_product.reset_index(drop=True, inplace=True)

    # Step 12: Plot the bar chart for the top employees by product
    ax = top_employees_by_product.pivot_table(
        index="EmployeeName", columns="Product", values="Quantity_Employee"
    ).plot(kind="bar", stacked=True, figsize=(16, 8))
    plt.xlabel("Employee")
    plt.ylabel("Total Quantity Sold")
    plt.title("Top Employees by Product")
    plt.legend(title="Product", bbox_to_anchor=(1, 1), loc="upper right", fontsize=6)
    plt.tight_layout()

    # Step 13: Save the chart to a BytesIO object to return it in the response
    buffer = io.BytesIO()
    plt.savefig(buffer, format="png")
    buffer.seek(0)

    # Step 14: Close the figure to free up memory
    plt.close()

    # Step 15: Read the chart from the BytesIO object and convert it to a base64 string
    data = buffer.getvalue()
    data_base64 = base64.b64encode(data).decode()

    # Step 16: Create the HTML response with the embedded image
    html_content = f'<img src="data:image/png;base64,{data_base64}" />'
    return HTMLResponse(content=html_content)


def plot_graph4():
    # Step 1: Merge the DataFrames using 'ExpenseTypeID' column
    merged_data = pd.merge(expenses, expensetypes, on="ExpenseTypeID")

    # Step 2: Calculate total expenses for each expense type
    total_expenses_per_type = (
        merged_data.groupby("Expense_Type")["Amount"].sum().reset_index()
    )

    # Step 3: Create the bar chart to show total expenses per expense type
    plt.figure(figsize=(10, 6))
    plt.bar(total_expenses_per_type["Expense_Type"], total_expenses_per_type["Amount"])
    plt.xlabel("Expense Type")
    plt.ylabel("Total Expenses")
    plt.title("Total Expenses per Expense Type")
    plt.xticks(rotation=45, ha="right")
    plt.tight_layout()

    # Step 4: Save the chart to a BytesIO object to return it in the response
    buffer = io.BytesIO()
    plt.savefig(buffer, format="png")
    buffer.seek(0)

    # Step 5: Close the figure to free up memory
    plt.close()

    # Step 6: Read the chart from the BytesIO object and convert it to a base64 string
    data = buffer.getvalue()
    data_base64 = base64.b64encode(data).decode()

    # Step 7: Create the HTML response with the embedded image
    html_content = f'<img src="data:image/png;base64,{data_base64}" />'
    return HTMLResponse(content=html_content)


def plot_graph5():
    # Calculate total sales grouped by year (summing the quantities)
    sales["Year"] = pd.to_datetime(sales["Date"]).dt.year
    sales_grouped = sales.groupby("Year")["Quantity"].sum()

    # Create the bar chart to show total sales per year
    plt.figure(figsize=(5, 6))  # Adjust the figure size for better visualization
    bars = plt.bar(
        sales_grouped.index, sales_grouped.values, width=0.2, color="skyblue"
    )

    plt.xlabel("Year")
    plt.ylabel("Total Sales")
    plt.title("Total Sales Grouped by Year")

    # Set the years as labels for the x-axis
    plt.xticks(sales_grouped.index, [str(year) for year in sales_grouped.index])

    # Customizing colors for each bar
    colors = ["darkred", "darkgreen", "orange", "purple"]
    for i, bar in enumerate(bars):
        bar.set_color(colors[i % len(colors)])

    plt.tight_layout()

    # Save the chart to a BytesIO object to return it in the response
    buffer = io.BytesIO()
    plt.savefig(buffer, format="png")
    buffer.seek(0)

    # Close the figure to free up memory
    plt.close()

    # Read the chart from the BytesIO object and convert it to a base64 string
    data = buffer.getvalue()
    data_base64 = base64.b64encode(data).decode()

    # Create the HTML response with the embedded image
    html_content = f'<img src="data:image/png;base64,{data_base64}" />'
    return HTMLResponse(content=html_content)


def plot_graph6():
    # Calculate total sales grouped by month in the year with the most sales
    sales["Year"] = pd.to_datetime(sales["Date"]).dt.year
    year_with_most_sales = sales["Year"].value_counts().idxmax()
    sales_in_year_with_most_sales = sales[sales["Year"] == year_with_most_sales]
    sales_in_year_with_most_sales["Month"] = pd.to_datetime(
        sales_in_year_with_most_sales["Date"]
    ).dt.month
    sales_grouped_by_month = sales_in_year_with_most_sales.groupby("Month")[
        "Quantity"
    ].sum()

    # Normalize the sales data to the range [0, 1]
    normalized_sales = (sales_grouped_by_month - sales_grouped_by_month.min()) / (
        sales_grouped_by_month.max() - sales_grouped_by_month.min()
    )

    # Get a colormap (e.g., "viridis" or "coolwarm") from matplotlib
    colormap = plt.cm.viridis

    # Create the bar chart to show total sales per month in the year with the most sales
    month_names = [
        "Jan",
        "Feb",
        "Mar",
        "Apr",
        "May",
        "Jun",
        "Jul",
        "Aug",
        "Sep",
        "Oct",
        "Nov",
        "Dec",
    ]
    plt.bar(month_names, sales_grouped_by_month, color=colormap(normalized_sales))
    plt.xlabel("Month")
    plt.ylabel("Total Sales")
    plt.title(f"Total Sales per Month in Year {year_with_most_sales}")
    plt.tight_layout()

    # Save the chart to a BytesIO object to return it in the response
    buffer = io.BytesIO()
    plt.savefig(buffer, format="png")
    buffer.seek(0)

    # Close the figure to free up memory
    plt.close()

    # Read the chart from the BytesIO object and convert it to a base64 string
    data = buffer.getvalue()
    data_base64 = base64.b64encode(data).decode()

    # Create the HTML response with the embedded image
    html_content = f'<img src="data:image/png;base64,{data_base64}" />'
    return HTMLResponse(content=html_content)


def plot_graph7():
    # Calculate total sales grouped by year and product
    sales["Year"] = pd.to_datetime(sales["Date"]).dt.year
    sales["Month"] = pd.to_datetime(sales["Date"]).dt.month
    sales_grouped_by_year_product = (
        sales.groupby(["Year", "Month", "ProductID"])["Quantity"].sum().reset_index()
    )

    # Find the year with the highest sales
    year_with_highest_sales = sales["Year"].value_counts().idxmax()

    # Filter the data for the year with the highest sales
    sales_in_year_with_highest_sales = sales[sales["Year"] == year_with_highest_sales]

    # Find the most sold product in each month of the year with highest sales
    most_sold_products_by_month = (
        sales_in_year_with_highest_sales.groupby(["Month", "ProductID"])["Quantity"]
        .sum()
        .reset_index()
    )
    most_sold_products_by_month = (
        most_sold_products_by_month.groupby("Month")
        .apply(lambda x: x.nlargest(1, "Quantity"))
        .reset_index(drop=True)
    )
    most_sold_products_by_month = most_sold_products_by_month.merge(
        products, on="ProductID", how="left"
    )

    # Calculate total sales grouped by month in the year with the most sales
    year_with_most_sales = sales["Year"].value_counts().idxmax()
    sales_in_year_with_most_sales = sales[sales["Year"] == year_with_most_sales]
    sales_in_year_with_most_sales["Month"] = pd.to_datetime(
        sales_in_year_with_most_sales["Date"]
    ).dt.month
    sales_grouped_by_month = sales_in_year_with_most_sales.groupby("Month")[
        "Quantity"
    ].sum()

    # Normalize the sales data to the range [0, 1]
    normalized_sales = (sales_grouped_by_month - sales_grouped_by_month.min()) / (
        sales_grouped_by_month.max() - sales_grouped_by_month.min()
    )
    # Get a colormap (e.g., "viridis" or "coolwarm") from matplotlib
    colormap = plt.cm.viridis

    # Plot the most sold products per month in the year with highest sales
    plt.figure(figsize=(18, 9))
    plt.bar(
        most_sold_products_by_month["Product"],
        most_sold_products_by_month["Quantity"],
        color=colormap(normalized_sales),
    )
    plt.xlabel("Product")
    plt.ylabel("Total Sales")
    plt.title(f"Most Sold Products per Month in Year {year_with_highest_sales}")
    plt.xticks(rotation=45, ha="right")
    plt.tight_layout()

    # Save the chart to a BytesIO object to return it in the response
    buffer = io.BytesIO()
    plt.savefig(buffer, format="png")
    buffer.seek(0)

    # Close the figure to free up memory
    plt.close()

    # Read the chart from the BytesIO object and convert it to a base64 string
    data = buffer.getvalue()
    data_base64 = base64.b64encode(data).decode()

    # Create the HTML response with the embedded image
    html_content = f'<img src="data:image/png;base64,{data_base64}" />'
    return HTMLResponse(content=html_content)


def plot_graph8():
    # Calculate total sales grouped by year and product
    sales["Year"] = pd.to_datetime(sales["Date"]).dt.year
    sales["Month"] = pd.to_datetime(sales["Date"]).dt.month
    sales_grouped_by_year_product = (
        sales.groupby(["Year", "Month", "ProductID"])["Quantity"].sum().reset_index()
    )

    # Find the year with the highest sales
    year_with_highest_sales = sales["Year"].value_counts().idxmax()

    # Filter the data for the year with the highest sales
    sales_in_year_with_highest_sales = sales[sales["Year"] == year_with_highest_sales]

    # Find the least sold product in each month of the year with highest sales
    least_sold_products_by_month = (
        sales_in_year_with_highest_sales.groupby(["Month", "ProductID"])["Quantity"]
        .sum()
        .reset_index()
    )
    least_sold_products_by_month = (
        least_sold_products_by_month.groupby("Month")
        .apply(lambda x: x.nsmallest(1, "Quantity"))
        .reset_index(drop=True)
    )
    least_sold_products_by_month = least_sold_products_by_month.merge(
        products, on="ProductID", how="left"
    )

    # Calculate total sales grouped by month in the year with the most sales
    year_with_most_sales = sales["Year"].value_counts().idxmax()
    sales_in_year_with_most_sales = sales[sales["Year"] == year_with_most_sales]
    sales_in_year_with_most_sales["Month"] = pd.to_datetime(
        sales_in_year_with_most_sales["Date"]
    ).dt.month
    sales_grouped_by_month = sales_in_year_with_most_sales.groupby("Month")[
        "Quantity"
    ].sum()

    # Normalize the sales data to the range [0, 1]
    normalized_sales = (sales_grouped_by_month - sales_grouped_by_month.min()) / (
        sales_grouped_by_month.max() - sales_grouped_by_month.min()
    )
    # Get a colormap (e.g., "viridis" or "coolwarm") from matplotlib
    colormap = plt.cm.viridis

    # Plot the least sold products per month in the year with highest sales
    plt.figure(figsize=(18, 9))
    plt.bar(
        least_sold_products_by_month["Product"],
        least_sold_products_by_month["Quantity"],
        color=colormap(normalized_sales),
    )
    plt.xlabel("Product")
    plt.ylabel("Total Sales")
    plt.title(f"Least Sold Products per Month in Year {year_with_highest_sales}")
    plt.xticks(rotation=45, ha="right")
    plt.tight_layout()

    # Save the chart to a BytesIO object to return it in the response
    buffer = io.BytesIO()
    plt.savefig(buffer, format="png")
    buffer.seek(0)

    # Close the figure to free up memory
    plt.close()

    # Read the chart from the BytesIO object and convert it to a base64 string
    data = buffer.getvalue()
    data_base64 = base64.b64encode(data).decode()

    # Create the HTML response with the embedded image
    html_content = f'<img src="data:image/png;base64,{data_base64}" />'
    return HTMLResponse(content=html_content)


def plot_graph9():
    # Calculate total sales grouped by month in the year with the least sales
    sales["Year"] = pd.to_datetime(sales["Date"]).dt.year
    year_with_least_sales = sales["Year"].value_counts().idxmin()
    sales_in_year_with_least_sales = sales[sales["Year"] == year_with_least_sales]
    sales_in_year_with_least_sales["Month"] = pd.to_datetime(
        sales_in_year_with_least_sales["Date"]
    ).dt.month
    sales_grouped_by_month = sales_in_year_with_least_sales.groupby("Month")[
        "Quantity"
    ].sum()

    # Normalize the sales data to the range [0, 1]
    normalized_sales = (sales_grouped_by_month - sales_grouped_by_month.min()) / (
        sales_grouped_by_month.max() - sales_grouped_by_month.min()
    )

    # Get a colormap (e.g., "viridis" or "coolwarm") from matplotlib
    colormap = plt.cm.viridis

    # Create the bar chart to show total sales per month in the year with the least sales
    month_names = [
        "Jan",
        "Feb",
        "Mar",
        "Apr",
        "May",
        "Jun",
        "Jul",
        "Aug",
        "Sep",
        "Oct",
        "Nov",
        "Dec",
    ]
    plt.bar(month_names, sales_grouped_by_month, color=colormap(normalized_sales))
    plt.xlabel("Month")
    plt.ylabel("Total Sales")
    plt.title(f"Total Sales per Month in Year {year_with_least_sales}")
    plt.tight_layout()

    # Save the chart to a BytesIO object to return it in the response
    buffer = io.BytesIO()
    plt.savefig(buffer, format="png")
    buffer.seek(0)

    # Close the figure to free up memory
    plt.close()

    # Read the chart from the BytesIO object and convert it to a base64 string
    data = buffer.getvalue()
    data_base64 = base64.b64encode(data).decode()

    # Create the HTML response with the embedded image
    html_content = f'<img src="data:image/png;base64,{data_base64}" />'
    return HTMLResponse(content=html_content)


def plot_graph10():
    # Calculate total sales grouped by year and product
    sales["Year"] = pd.to_datetime(sales["Date"]).dt.year
    sales["Month"] = pd.to_datetime(sales["Date"]).dt.month
    sales_grouped_by_year_product = (
        sales.groupby(["Year", "Month", "ProductID"])["Quantity"].sum().reset_index()
    )

    # Find the year with the lowest sales
    year_with_lowest_sales = sales["Year"].value_counts().idxmin()

    # Filter the data for the year with the lowest sales
    sales_in_year_with_lowest_sales = sales[sales["Year"] == year_with_lowest_sales]

    # Find the most sold product in each month of the year with lowest sales
    most_sold_products_by_month = (
        sales_in_year_with_lowest_sales.groupby(["Month", "ProductID"])["Quantity"]
        .sum()
        .reset_index()
    )
    most_sold_products_by_month = (
        most_sold_products_by_month.groupby("Month")
        .apply(lambda x: x.nlargest(1, "Quantity"))
        .reset_index(drop=True)
    )
    most_sold_products_by_month = most_sold_products_by_month.merge(
        products, on="ProductID", how="left"
    )

    # Calculate total sales grouped by month in the year with the least sales
    year_with_least_sales = sales["Year"].value_counts().idxmin()
    sales_in_year_with_least_sales = sales[sales["Year"] == year_with_least_sales]
    sales_in_year_with_least_sales["Month"] = pd.to_datetime(
        sales_in_year_with_least_sales["Date"]
    ).dt.month
    sales_grouped_by_month = sales_in_year_with_least_sales.groupby("Month")[
        "Quantity"
    ].sum()

    # Normalize the sales data to the range [0, 1]
    normalized_sales = (sales_grouped_by_month - sales_grouped_by_month.min()) / (
        sales_grouped_by_month.max() - sales_grouped_by_month.min()
    )
    # Get a colormap (e.g., "viridis" or "coolwarm") from matplotlib
    colormap = plt.cm.viridis

    # Plot the most sold products per month in the year with least sales
    plt.figure(figsize=(18, 9))
    plt.bar(
        most_sold_products_by_month["Product"],
        most_sold_products_by_month["Quantity"],
        color=colormap(normalized_sales),
    )
    plt.xlabel("Product")
    plt.ylabel("Total Sales")
    plt.title(f"Most Sold Products per Month in Year {year_with_least_sales}")
    plt.xticks(rotation=45, ha="right")
    plt.tight_layout()

    # Save the chart to a BytesIO object to return it in the response
    buffer = io.BytesIO()
    plt.savefig(buffer, format="png")
    buffer.seek(0)

    # Close the figure to free up memory
    plt.close()

    # Read the chart from the BytesIO object and convert it to a base64 string
    data = buffer.getvalue()
    data_base64 = base64.b64encode(data).decode()

    # Create the HTML response with the embedded image
    html_content = f'<img src="data:image/png;base64,{data_base64}" />'
    return HTMLResponse(content=html_content)


def plot_graph11():
    # Calculate total sales grouped by year and product
    sales["Year"] = pd.to_datetime(sales["Date"]).dt.year
    sales["Month"] = pd.to_datetime(sales["Date"]).dt.month
    sales_grouped_by_year_product = (
        sales.groupby(["Year", "Month", "ProductID"])["Quantity"].sum().reset_index()
    )

    # Find the year with the lowest sales
    year_with_lowest_sales = sales["Year"].value_counts().idxmin()

    # Filter the data for the year with the lowest sales
    sales_in_year_with_lowest_sales = sales[sales["Year"] == year_with_lowest_sales]

    # Find the least sold product in each month of the year with lowest sales
    least_sold_products_by_month = (
        sales_in_year_with_lowest_sales.groupby(["Month", "ProductID"])["Quantity"]
        .sum()
        .reset_index()
    )
    least_sold_products_by_month = (
        least_sold_products_by_month.groupby("Month")
        .apply(lambda x: x.nsmallest(1, "Quantity"))
        .reset_index(drop=True)
    )
    least_sold_products_by_month = least_sold_products_by_month.merge(
        products, on="ProductID", how="left"
    )

    # Calculate total sales grouped by month in the year with the least sales
    year_with_least_sales = sales["Year"].value_counts().idxmin()
    sales_in_year_with_least_sales = sales[sales["Year"] == year_with_least_sales]
    sales_in_year_with_least_sales["Month"] = pd.to_datetime(
        sales_in_year_with_least_sales["Date"]
    ).dt.month
    sales_grouped_by_month = sales_in_year_with_least_sales.groupby("Month")[
        "Quantity"
    ].sum()

    # Normalize the sales data to the range [0, 1]
    normalized_sales = (sales_grouped_by_month - sales_grouped_by_month.min()) / (
        sales_grouped_by_month.max() - sales_grouped_by_month.min()
    )
    # Get a colormap (e.g., "viridis" or "coolwarm") from matplotlib
    colormap = plt.cm.viridis

    # Plot the least sold products per month in the year with lowest sales
    plt.figure(figsize=(18, 9))
    plt.bar(
        least_sold_products_by_month["Product"],
        least_sold_products_by_month["Quantity"],
        color=colormap(normalized_sales),
    )
    plt.xlabel("Product")
    plt.ylabel("Total Sales")
    plt.title(f"Least Sold Products per Month in Year {year_with_lowest_sales}")
    plt.xticks(rotation=45, ha="right")
    plt.tight_layout()

    # Save the chart to a BytesIO object to return it in the response
    buffer = io.BytesIO()
    plt.savefig(buffer, format="png")
    buffer.seek(0)

    # Close the figure to free up memory
    plt.close()

    # Read the chart from the BytesIO object and convert it to a base64 string
    data = buffer.getvalue()
    data_base64 = base64.b64encode(data).decode()

    # Create the HTML response with the embedded image
    html_content = f'<img src="data:image/png;base64,{data_base64}" />'
    return HTMLResponse(content=html_content)
