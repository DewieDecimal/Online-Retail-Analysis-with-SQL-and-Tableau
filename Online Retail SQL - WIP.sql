--When importing the original dataset to postgresql, I reformatted the InvoiceDate to fit the datatype "timestamp without time zone"


--Check if columns are looking alright
/*  Findings:
	+ Some products are being sold on amazon, ebay, dotcom, so these stores are selling through an additional channel
	+ There are two invoices that have negative UnitPrice, which are used to adjust bad debts
*/
SELECT description, quantity, customer_id, country, unit_price FROM public."Online Retail" ORDER BY unit_price, quantity;


--Check for duplicates
/* Found 5848 dups */
WITH duplicates AS (SELECT *,
ROW_NUMBER() OVER(
	PARTITION BY stock_code, description, quantity, invoice_date, unit_price, customer_id, country 
	ORDER BY invoice_no) AS rownum
FROM public."Online Retail")

SELECT * FROM duplicates
WHERE rownum > 1;


/* Delete duplicate, since PostgreSQL doesn't allow direct delete from CTE, we are adding an id column and will drop it later. We will see that the row numbers went from 541909 to 536061 */
ALTER TABLE public."Online Retail" ADD COLUMN id SERIAL PRIMARY KEY;

WITH duplicates AS (SELECT *,
ROW_NUMBER() OVER(
	PARTITION BY stock_code, description, quantity, invoice_date, unit_price, customer_id, country 
	ORDER BY invoice_no) AS rownum
FROM public."Online Retail")

DELETE FROM public."Online Retail"
WHERE id IN (SELECT id FROM duplicates WHERE rownum > 1);

ALTER TABLE public."Online Retail" DROP COLUMN id;


--Check cancellation invoices
SELECT * FROM public."Online Retail" WHERE invoice_no LIKE 'C%'


-- Country count as percentage of the grand total 
/* 91.36% of invoices are from the UK */
WITH country_count_table as (
		SELECT country, COUNT(country) as count
		FROM public."Online Retail"
		GROUP BY country)

SELECT country, count, 100*count/SUM(count) OVER () AS percentage_of_total
FROM country_count_table
GROUP BY country, count
ORDER BY 3 DESC;


-- Check blank descriptions
/* All of these blank invoices are from the UK.
   Invoices with blank descriptions don't have UnitPrice and CustomerID, so we don't have enough information to fill in these blanks.
   Since we don't seem to learn anything from these invoices, we could delete them. */ 
SELECT * FROM public."Online Retail"
WHERE description IS NULL;

DELETE FROM public."Online Retail" WHERE description is NULL;


-- Check for bad invoices
/* Bad invoices are the one which are described as lost, damaged, smashed, mixed up, or given away
   These bad invoices are the results of poor inventory management and they are all from the UK.
   It also means other stores in other countries are doing good in managing inventory */
SELECT invoice_no, stock_code, LOWER(description) AS description, quantity, invoice_date, unit_price, customer_id, country 
FROM (SELECT * 
	  FROM public."Online Retail"
	  WHERE description IS NOT NULL AND quantity < 0 AND unit_price = 0 AND customer_id IS NULL) as sub
WHERE description NOT LIKE '%ive%'
AND   description NOT LIKE '%old%'
AND   description NOT LIKE '%mazon%'
AND   description NOT LIKE '%bay%'
AND   description NOT LIKE '%otcom%'
AND   description NOT LIKE '%everse%'


-- Check descriptions that started with "?". 
/* All invoices that have a description started with "?": 
  + Either gives no information or describes that there were missing, lost, and damaged products 
  + Are all from United Kingdom
  + Mostly negative in quantity
  + Have no UnitPrice and CustomerID */
SELECT * FROM public."Online Retail"
WHERE description LIKE '?%'
ORDER BY quantity DESC;

DELETE FROM public."Online Retail" WHERE description LIKE '?%';


--Check if we can get anything from lost and found invoices
WITH lost_invoices AS (
SELECT invoice_no, stock_code, LOWER(description) AS description, quantity, invoice_date, unit_price, customer_id, country
FROM public."Online Retail" 
WHERE description LIKE '%ost%'
OR	 description LIKE '%issin%'
OR	 description LIKE '%ix%up%'),
					
found_invoices AS (
SELECT invoice_no, stock_code, LOWER(description) AS description, quantity, invoice_date, unit_price, customer_id, country
FROM public."Online Retail" 
WHERE description LIKE '%found%')
					
SELECT * 
FROM lost_invoices l
JOIN found_invoices f ON l.country = f.country AND l.stock_code = f.stock_code

-----------------------------------------------

-- Create a view to analyze sales-related metrics
DROP VIEW IF exists invoice_sales;
CREATE VIEW invoice_sales AS
(SELECT *, quantity * unit_price AS sales
FROM public."Online Retail"
WHERE quantity > 0 
  AND unit_price > 0 
  AND LENGTH(stock_code) >= 5 
  AND stock_code NOT LIKE 'AMAZON%'
ORDER BY sales DESC);

-- Sales Analysis by Country
--- Top 10 countries by total sales
SELECT country, SUM(sales) AS total_sales
FROM invoice_sales
GROUP BY 1
ORDER BY 2 DESC
LIMIT 10;

--- Country with the highest sales by a single invoice is UK
SELECT country, MAX(sales) AS max_sales
FROM invoice_sales
GROUP BY 1
ORDER BY 2 DESC;


-- Sales over time period* (add country inside the bars/columns to do stacked ...) 
--- Sales by months
/* The sales of Dec-2010 is larger than Dec-2011 */ 
WITH sales_with_month AS 
(SELECT invoice_no, stock_code, description, quantity, unit_price, sales, customer_id, country, DATE_TRUNC('month', invoice_date) AS month
FROM invoice_sales)

SELECT month, SUM(sales) AS sales_over_month
FROM sales_with_month
GROUP BY 1
ORDER BY month;

--- Sales by 2011's quarters 
WITH sales_with_quarter AS 
(SELECT invoice_no, stock_code, description, quantity, unit_price, sales, customer_id, country, invoice_date, DATE_PART('quarter', invoice_date) AS quarter
FROM invoice_sales
WHERE invoice_date > '2010-12-31')

SELECT quarter, SUM(sales) AS sales_by_quarter
FROM sales_with_quarter
GROUP BY 1
ORDER BY 1;


-- Sales Analysis by Retail Industry
--- Basket Size
SELECT invoice_no, ROUND(SUM(quantity)::NUMERIC/ COUNT(invoice_no), 2)  AS basket_size
FROM invoice_sales
WHERE stock_code NOT LIKE 'BANK%'
GROUP BY 1
ORDER BY 2 DESC;

--- Average Order Value (AOV)
/* AOV seems to be consistent across the months in 2011, however, none of them are higher than Dec-2010's AOV. We may say the the stores did worse than the previous year or there could be a spike due to something happened around that month */
SELECT DATE_TRUNC('month', invoice_date) AS AOV_month, ROUND(SUM(sales)/ SUM(quantity), 2) AS average_order_value
FROM invoice_sales
WHERE stock_code NOT LIKE 'BANK%'
GROUP BY 1
ORDER BY AOV_month DESC;

------------------------------------------

-- Customer Analysis
-- Create a View to analyze customer-related metrics
/* The starting month which is Dec-2010 will be marked as month '0' */
DROP VIEW IF exists customer_view;
CREATE VIEW customer_view AS
SELECT *, 
CASE WHEN invoice_date < '2011-01-01' THEN 0 ELSE DATE_PART('month', invoice_date) END AS visit_month
FROM public."Online Retail"
WHERE unit_price > 0 AND customer_id IS NOT NULL;

--- Customer count by month
SELECT visit_month, COUNT(DISTINCT customer_id) AS monthly_customer_count
FROM customer_view
GROUP BY 1
ORDER BY 1 ASC;

--- Customer Retention Rate by Month
WITH customer_visits AS (
SELECT visit_month, customer_id
FROM customer_view
GROUP BY 1, 2
ORDER BY 2 ASC
),
customer_first_visits AS (
/* Calculate the first month of login for every user using the MIN function and GROUP BY to return the first month of every user. */
SELECT customer_id, MIN(visit_month) AS first_month
FROM customer_view
GROUP BY 1
),
customer_cohort AS (
SELECT first_month,
		SUM(CASE WHEN month_number = 0 THEN 1 ELSE 0 END) AS after_0_month,
		SUM(CASE WHEN month_number = 1 THEN 1 ELSE 0 END) AS after_1_month,
		SUM(CASE WHEN month_number = 2 THEN 1 ELSE 0 END) AS after_2_month,
		SUM(CASE WHEN month_number = 3 THEN 1 ELSE 0 END) AS after_3_month,
		SUM(CASE WHEN month_number = 4 THEN 1 ELSE 0 END) AS after_4_month,
		SUM(CASE WHEN month_number = 5 THEN 1 ELSE 0 END) AS after_5_month,
		SUM(CASE WHEN month_number = 6 THEN 1 ELSE 0 END) AS after_6_month,
		SUM(CASE WHEN month_number = 7 THEN 1 ELSE 0 END) AS after_7_month,
		SUM(CASE WHEN month_number = 8 THEN 1 ELSE 0 END) AS after_8_month,
		SUM(CASE WHEN month_number = 9 THEN 1 ELSE 0 END) AS after_9_month,
		SUM(CASE WHEN month_number = 10 THEN 1 ELSE 0 END) AS after_10_month,
		SUM(CASE WHEN month_number = 11 THEN 1 ELSE 0 END) AS after_11_month,
		SUM(CASE WHEN month_number = 12 THEN 1 ELSE 0 END) AS after_12_month
FROM 
(SELECT v.customer_id, fv.first_month, v.visit_month, v.visit_month - fv.first_month AS month_number
FROM customer_visits v
JOIN customer_first_visits fv
ON v.customer_id = fv.customer_id) AS customer_month_number
GROUP BY 1
ORDER BY 1
)
SELECT first_month, 
		after_0_month*100/after_0_month AS crt_0_month, 
		after_1_month*100/after_0_month AS crt_1_month,
		after_2_month*100/after_0_month AS crt_2_month,	
		after_3_month*100/after_0_month AS crt_3_month,	
		after_4_month*100/after_0_month AS crt_4_month,	
		after_5_month*100/after_0_month AS crt_5_month,	
		after_6_month*100/after_0_month AS crt_6_month,	
		after_7_month*100/after_0_month AS crt_7_month,	
		after_8_month*100/after_0_month AS crt_8_month,	
		after_9_month*100/after_0_month AS crt_9_month,	
		after_10_month*100/after_0_month AS crt_10_month,	
		after_11_month*100/after_0_month AS crt_11_month,	
		after_12_month*100/after_0_month AS crt_12_month
FROM customer_cohort
ORDER BY 1


--- RFM

--- Churn Rate


--- Customer Lifetime Value over a period
Customer Lifetime Value (CLV): This is a prediction of the net profit attributed to the entire future relationship with a customer.


--- Customer Segmentation
Customer Segmentation: This can be performed by grouping customers based on spending patterns, or location.





-- Note for analyzing stuff:

-- Time-series Analysis: This can be performed by analyzing the sales data over time to identify trends and patterns such as seasonality, cyclicality, and overall growth.

-- Geographic Analysis: This can be performed by analyzing the sales data by geographic location, such as country, region, or city, to identify regional trends and patterns.


