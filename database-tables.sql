CREATE TABLE calendar (
    IdDate INT PRIMARY KEY,
    date DATE,
    year INT,
    month INT,
    day INT,
    quarter INT,
    week INT,
    day_name VARCHAR(15),
    month_name VARCHAR(15)
);

CREATE TABLE channels (
    ChannelId INT PRIMARY KEY,
    Channel VARCHAR(50)
);

CREATE TABLE customers (
    CustomerId INT PRIMARY KEY,
    Name_and_Surname VARCHAR(100),
    Address VARCHAR(200),
    Phone VARCHAR(20),
    Age INT,
    Age_Range VARCHAR(50),
    LocalityId INT,
    Latitude FLOAT,
    Longitude FLOAT
);

CREATE TABLE employees (
    EmployeeID INT PRIMARY KEY,
    EmployeeCode INT,
    Lastname VARCHAR(50),
    Firstname VARCHAR(50),
    BranchID INT,
    SectorID INT,
    PositionID INT,
    Salary FLOAT
);

CREATE TABLE expense_types (
    ExpenseTypeID INT PRIMARY KEY,
    Expense_Type VARCHAR(50),
    Approximate_Amount FLOAT
);

CREATE TABLE expenses (
    ExpenseID INT PRIMARY KEY,
    BranchID INT,
    ExpenseTypeID INT,
    Date DATE,
    Amount FLOAT
);

CREATE TABLE products (
    ProductID INT PRIMARY KEY,
    Product VARCHAR(100),
    Price FLOAT,
    ProductTypeID INT
);

CREATE TABLE sales-points (
    BranchID INT PRIMARY KEY,
    Branch VARCHAR(50),
    Address VARCHAR(100),
    LocalityID INT,
    Latitude FLOAT,
    Longitude FLOAT
);

CREATE TABLE sales (
    SaleID INT PRIMARY KEY,
    Date DATE,
    Delivery_Date DATE,
    ChannelID INT,
    CustomerID INT,
    BranchID INT,
    EmployeeID INT,
    ProductID INT,
    Price FLOAT,
    Quantity INT
);