# Online Retail Analysis with SQL and Tableau
Online Retail Exploratory SQL Project using PostgreSQL with the use of Tableau for visualizing findings (https://public.tableau.com/app/profile/duy.nguyen2347/viz/OnlineRetailWIP/MainDashboard)


# Project Description
Explore a public transnational data set of 1 CSV file containing all the transactions occurring between 01/12/2010 and 09/12/2011 for a UK-based and registered non-store online retail.


## Methodology
Explore and analyze the data set using the tools that I have been learning and using at work:
- Excel for skimming and improving the efficiency of cleaning data
- PostgreSQL for cleaning and analyzing data
- Tableau for visualizing findings


## Attribute Information:
* InvoiceNo: Invoice number. Nominal, a 6-digit integral number uniquely assigned to each transaction. If this code starts with letter 'c', it indicates a cancellation.
* StockCode: Product (item) code. Nominal, a 5-digit integral number uniquely assigned to each distinct product.
* Description: Product (item) name. Nominal.
* Quantity: The quantities of each product (item) per transaction. Numeric.
* InvoiceDate: Invice Date and time. Numeric, the day and time when each transaction was generated.
* UnitPrice: Unit price. Numeric, Product price per unit in sterling.
* CustomerID: Customer number. Nominal, a 5-digit integral number uniquely assigned to each customer.
* Country: Country name. Nominal, the name of the country where each customer resides.


## Primary Objective
1. Clean data by:
* Checking the formats and raw data of all columns
* Removing duplications and unused data
* Creating views for analyzing data


2. Check data contribution by country.


3. Check abnormal invoices and non-transactional invoices for additional findings.


4. Sales analysis:
* Top 10 countries by total sales
* Country with the highest sales by a single invoice in UK
* Sales over a time period (by month, by quarter)
* Basket size
* Average order value


5. Customer analysis:
* Customer retention rate by month
* RFM
* Customer lifetime value
* Customer fraud detection
* Product recommendation for customer based on customer's purchase history

6. Inventory analysis:
* Popular products
* Product cancellation rate
* Products that are most frequently purchased together

7. Export tables as csv files.

8. Import SQL tables into Tableau to visualize findings.


## Bonus Objective
1. Try using Tableau to visualize cohort charts

2. Look for additional findings using Tableau visualizations
