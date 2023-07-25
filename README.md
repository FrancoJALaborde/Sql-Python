## Description
This project integrates SQL, Python, and FastAPI to create an API that provides useful explorations and visualizations for the company's board of directors. The API accesses data stored in a SQL database and offers insights into the company's performance.

## Setup
### Prerequisites
- Python 3.x
- FastAPI
- SQL Database (MySQL, PostgreSQL, etc.)

### Installation
1. Clone this repository to your local machine.
2. Install the required Python packages:
    pip install -r requirements.txt
3. Ensure that your SQL database is up and running.

## Usage
1. Run the SQL script `database-tables.sql` to create the necessary tables in your SQL database.
2. If you already have a SQL database with data, skip to step 5.
3. Use the Jupyter Notebook `load-data-from-csv-to-SQL.ipynb` to connect to the SQL database and load data from the corresponding CSV files into each table.
4. Complete the ETL process using `ETL.ipynb` to correct any errors in the CSV files, saving the cleaned data to new CSV files.
5. Use `EDA.ipynb` to visualize the information from each table and generate useful graphs and insights about the company's performance.
6. The functions to recreate the visualizations as an API are provided in `functions.py`.
7. Launch the API by running `main.py` and accessing the endpoints provided by FastAPI.

## Files and Directories
- `database-tables.sql`: SQL script to create tables in the database.
- `functions-sql.sql`: SQL script containing functions for useful explorations.
- `load-data-from-csv-to-SQL.ipynb`: Jupyter Notebook to load data into the SQL database.
- `ETL.ipynb`: Jupyter Notebook for data cleaning and transformation.
- `EDA.ipynb`: Jupyter Notebook for exploratory data analysis and visualizations.
- `functions.py`: Python file with functions to recreate visualizations as an API.
- `main.py`: Python file containing the FastAPI code for the API.

## API Endpoints
- `/visualizations`: Get visualizations for the company's performance.
- `/data/{table_name}`: Get data from a specific table in the database.


