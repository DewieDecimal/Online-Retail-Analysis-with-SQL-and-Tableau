# Online Retail Analysis with SQL and Tableau
Online Retail Exploratory SQL Project using PostgreSQL with the use of Tableau for visualizing findings (https://public.tableau.com/app/profile/duy.nguyen2347/viz/OnlineRetailWIP/MainDashboard)


# Project Description
Explore a public transnational data set of 1 CSV file containing all the transactions occurring between 01/12/2010 and 09/12/2011 for a UK-based and registered non-store online retail.


## Methodology
Explore and analyze the data set using the tools that I have been learning and using at work:
- Excel for skimming and improving the efficiency of cleaning data
- PostgreSQL for cleaning and analyzing data
- Tableau for visualizing findings


## Data Dictionary:
* InvoiceNo: Invoice number. Nominal, a 6-digit integral number uniquely assigned to each transaction. If this code starts with letter 'C', it indicates a cancellation.
* StockCode: Product (item) code. Nominal, a 5-digit integral number uniquely assigned to each distinct product.
* Description: Product (item) name. Nominal.
* Quantity: The quantities of each product (item) per transaction. Numeric.
* InvoiceDate: Invice Date and time. Numeric, the day and time when each transaction was generated.
* UnitPrice: Unit price. Numeric, Product price per unit in sterling.
* CustomerID: Customer number. Nominal, a 5-digit integral number uniquely assigned to each customer.
* Country: Country name. Nominal, the name of the country where each customer resides.


## Analysis Steps
1. Prepare Data:
* Issue Check: Checking the formats and raw data of all columns to make sure they adhere to the data dictionary
* Duplicate Check:
  * Duplicates in the dataset are identified using a common table expression (CTE)
  * The duplicates are then deleted, and the row count is verified


2. Cancellation Invoices: Invoices in the InvoiceNo column that starts with the letter "C" are identified as cancellation invoices.
* The cancellation invoices will be kept in mind when we do further analysis


3. Data Contribution: Check the percentage of invoices contributed by each country.
* We found that 91.355% of invoices are from the UK


4. Blank Descriptions: Invoices with blank descriptions are identified and deleted from the dataset.
* All of the blank invoices are from the UK
* Invoices with blank descriptions don't have UnitPrice and CustomerID, so we don't have enough information to fill in these blanks
* Since we cannot learn anything from these invoices, we could delete them


5. Bad Invoices: Invoices with descriptions indicating lost, damaged, or other issues are identified. These invoices are considered the result of poor inventory management.
* All of the bad invoices are from the UK


6. Descriptions Starting with "?": Invoices with descriptions starting with "?" are analyzed. These invoices usually provide no useful information or indicate missing, lost, or damaged products.
* Either gives no information or describes that there were missing, lost, and damaged products
* Are all from the UK
* Mostly negative in quantity
* Have no UnitPrice and CustomerID


7. Lost and Found Invoices: Invoices with descriptions related to lost or found items are analyzed to identify any patterns or correlations. These invoices also provide no useful information.


8. Sales Analysis: A view is created to analyze sales-related metrics.
* Top 10 countries by total sales
* Country with the highest sales by a single invoice in UK
* Sales over a time period (by month, by quarter)
* Basket size
* Average order value


9. Customer Analysis: A table is created to analyze customer-related metrics.
* Customer retention rate by month
* RFM (Recency, Frequency, Monetary) analysis
* Customer lifetime value
* Customer fraud detection
* Product recommendation for customer based on customer's purchase history


10. Inventory Analysis:
* Popular products
* Product cancellation rate
* Products that are most frequently purchased together


11. Export CSV: Export tables as csv files.


12. Tableau Data Import: Import SQL tables into Tableau to visualize findings and look for additional findings using Tableau visualizations


## Findings and Recommendations:
The analysis provides several insights into the online retail dataset, including:

All of the bad invoices or blank invoices are registered as from the UK. It means that this online retail store doesn't have a warehouse or base location outside of the UK.

![image](https://github.com/DewieDecimal/Online-Retail-Analysis-with-SQL-and-Tableau/assets/125356334/a06066e4-02dc-4549-8c19-06bf3869d5ea)
* The top countries with the highest average sales are the Netherlands, Australia, Japan, Sweden, Denmark, etc. This is due to their high average basket sizes. Still, it indicates <b>potential areas for scaling operations<b>.
* In combination with market research initiatives regarding the market potential, competitive landscape, culture, etc. we could <b>consider upselling, cross-selling, and introducing higher-priced products or services when targeting these countries</b>.
* By focusing on countries with higher average basket sizes, we can allocate resources and marketing efforts more strategically to maximize revenue.
* United Kingdom where most of our customers are from, ranks 32/38 with an average basket size of 10 products/items per transaction.

![image](https://github.com/DewieDecimal/Online-Retail-Analysis-with-SQL-and-Tableau/assets/125356334/183051b0-51a1-4b0e-90d0-db00a3f96a8a)
*Note: We only have the transactions occurring between 01/12/2010 and 09/12/2011, hence we don't have enough data to make any meaningful conclusions about December 2011*
* Sales in November 2011 ($1,452,090) are significantly higher compared to previous months, indicating a potential boost from holiday shopping. Similarly, September 2011 ($1,028,177) also shows a spike in sales, possibly due to seasonal factors or specific promotions.
* This could indicate a potential seasonal trend. Still, there are not enough data points to conclude that there is a seasonality.

![image](https://github.com/DewieDecimal/Online-Retail-Analysis-with-SQL-and-Tableau/assets/125356334/472f1375-ebff-44e1-b5e6-8a89e94ba292)
*Note: We only have the transactions occurring between 01/12/2010 and 09/12/2011, hence we don't have enough data to make any meaningful conclusions about December 2011*
* There is an obvious positive correlation between the number of customers and sales figures. However, the sales in some months are not on par with the customer count, such as Feb 2011 and Apr 2011. If there are months with a high customer count but relatively low sales, it may indicate that <b>there is room to improve the pricing strategies and encourage customers to spend more during their visits</b>.

![image](https://github.com/DewieDecimal/Online-Retail-Analysis-with-SQL-and-Tableau/assets/125356334/88e005ab-d38d-4e84-ad75-afca24ac3c13)
* The customer retention rates are consistent over the months. However, these retention rates are still low (averaging 23%), and we should aim for an average of 60-70%.
* The customer retention rates after the first month should have been larger than the later months, however, it doesn't seem to be the case here.
* It is recommended that we <b>improve the onboarding process for new customers, personalize the customer experience, enhance the customer support quality, offer loyalty/membership programs, etc.</b>

![image](https://github.com/DewieDecimal/Online-Retail-Analysis-with-SQL-and-Tableau/assets/125356334/f89aba33-df59-4f53-8d96-6b0d062e6180)
* Most of the noticeable "bubbles" range around 1-18%. Still, the "50% bubble" and "100% bubble" are quite big.
* If there are 21 customers who have a 50% cancellation rate and 33 customers who have a 100% cancellation rate, it is quite concerning. Hence, we should take further steps to <b>investigate reasons for cancellations and enhance customer support and customer experience</b>.
