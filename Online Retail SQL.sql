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
/* 91.355% of invoices are from the UK */
WITH country_count_table as (
		SELECT country, COUNT(country) as count
		FROM public."Online Retail"
		GROUP BY country)

SELECT country, count, ROUND(100*count/SUM(count) OVER (), 3) AS percentage_of_total
FROM country_count_table
GROUP BY country, count
ORDER BY 3 DESC;


-- Check blank descriptions
/* All of these blank invoices are from the UK.
   Invoices with blank descriptions don't have UnitPrice and CustomerID, so we don't have enough information to fill in these blanks. */
SELECT * FROM public."Online Retail"
WHERE description IS NULL;
/*Since we don't seem to learn anything from these invoices, we could delete them. */ 
DELETE FROM public."Online Retail" WHERE description is NULL;


-- Check for bad invoices
/* Bad invoices are the ones that are described as lost, damaged, smashed, mixed up, or given away*/
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
/* Can't draw anything from this */
WITH lost_invoices AS (
SELECT invoice_no, stock_code, LOWER(description) AS description, quantity, invoice_date, unit_price, customer_id, country
FROM public."Online Retail" 
WHERE description LIKE '%ost%'
OR	 description LIKE '%issin%'
OR	 description LIKE '%ix%up%'
)					
, found_invoices AS (
SELECT invoice_no, stock_code, LOWER(description) AS description, quantity, invoice_date, unit_price, customer_id, country
FROM public."Online Retail" 
WHERE description LIKE '%found%'
)
					
SELECT * 
FROM lost_invoices l
JOIN found_invoices f ON l.country = f.country AND l.stock_code = f.stock_code

-----------------------------------------------

-- Create a view to analyze sales-related metrics
DROP TABLE IF exists invoice_sales;
CREATE TABLE invoice_sales AS
(SELECT *, quantity * unit_price AS sales
FROM public."Online Retail"
WHERE quantity > 0 
  AND unit_price > 0 
  AND LENGTH(stock_code) >= 5 
  AND stock_code NOT LIKE 'AMAZON%'
ORDER BY sales DESC);

-- Sales Analysis 
--- Top 10 countries by total sales
/* Netherlands, Australia, Japan, Sweden, and Denmark are the top five countries that should be considered for operations scaling */
SELECT country, ROUND(AVG(sales)) AS average_sales
FROM invoice_sales
GROUP BY 1
ORDER BY 2 DESC
LIMIT 10;

--- Country with the highest sales by a single invoice
SELECT country, MAX(sales) AS max_sales
FROM invoice_sales
GROUP BY 1
ORDER BY 2 DESC;

--- Sales by months
WITH sales_with_month AS (
SELECT invoice_no, stock_code, description, quantity, unit_price, sales, customer_id, country, DATE_TRUNC('month', invoice_date) AS month
FROM invoice_sales
)

SELECT month, SUM(sales) AS sales_over_month
FROM sales_with_month
GROUP BY 1
ORDER BY month;

--- Sales by 2011's quarters 
WITH sales_with_quarter AS (
SELECT invoice_no, stock_code, description, quantity, unit_price, sales, customer_id, country, invoice_date, DATE_PART('quarter', invoice_date) AS quarter
FROM invoice_sales
WHERE invoice_date > '2010-12-31'
)

SELECT quarter, SUM(sales) AS sales_by_quarter
FROM sales_with_quarter
GROUP BY 1
ORDER BY 1;

--- Average basket size by country
/* Netherlands, Australia, Japan, Sweden, and Denmark have high average sales due to their high average basket size */
SELECT i.country, ROUND(AVG(sub.basket_size)) average_basket_size
FROM (
	SELECT invoice_no, ROUND(SUM(quantity)::NUMERIC/ COUNT(invoice_no))  AS basket_size
	FROM invoice_sales
	WHERE stock_code NOT LIKE 'BANK%'
	GROUP BY 1) AS sub
JOIN invoice_sales i ON i.invoice_no = sub.invoice_no
GROUP BY 1
ORDER BY 2 DESC

--- Average Order Value (AOV) by month
/* AOV seems to be consistent across the months in 2011, however, none of them are higher than Dec-2010's AOV. We may say that the stores did worse than the previous year or there could be a spike due to something happened around that month */
SELECT DATE_TRUNC('month', invoice_date) AS month, ROUND(SUM(sales)/ SUM(quantity), 2) AS average_order_value
FROM invoice_sales
WHERE stock_code NOT LIKE 'BANK%'
GROUP BY 1
ORDER BY month DESC;

------------------------------------------

-- Customer Analysis
-- Create a table/ select a data frame to analyze customer-related metrics
/* The starting month which is Dec-2010 will be marked as month '0' */
DROP TABLE IF exists customer_table;
CREATE TABLE customer_table AS
SELECT *, 
CASE WHEN invoice_date < '2011-01-01' THEN 0 ELSE DATE_PART('month', invoice_date) END AS visit_month
FROM public."Online Retail"
WHERE unit_price > 0 
AND   quantity > 0
AND   customer_id IS NOT NULL;

--- Customer count by month
SELECT DATE_TRUNC('month', invoice_date) AS month, COUNT(DISTINCT customer_id) AS monthly_customer_count
FROM public."Online Retail"
WHERE unit_price > 0 
AND   quantity > 0
AND   customer_id IS NOT NULL
GROUP BY 1
ORDER BY 1 ASC;

--- Customer Retention Rate by Month
/* Create views for calculation */
DROP VIEW IF exists customer_visits;
CREATE VIEW customer_visits AS
SELECT visit_month, customer_id
FROM customer_table
GROUP BY 1, 2
ORDER BY 2 ASC;

DROP VIEW IF exists customer_first_visits;
CREATE VIEW customer_first_visits AS
/* Calculate the first month of login for every user using the MIN function and GROUP BY to return the first month of every user. */
SELECT customer_id, MIN(visit_month) AS first_month
FROM customer_table
GROUP BY 1;

DROP VIEW IF exists customer_retention_rate_view;
CREATE VIEW customer_retention_rate_view AS
WITH customer_cohort AS (
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

SELECT first_month, after_0_month AS new_customer,
		after_0_month*100/after_0_month AS rt_0_month, 
		after_1_month*100/after_0_month AS rt_1_month,
		after_2_month*100/after_0_month AS rt_2_month,	
		after_3_month*100/after_0_month AS rt_3_month,	
		after_4_month*100/after_0_month AS rt_4_month,	
		after_5_month*100/after_0_month AS rt_5_month,	
		after_6_month*100/after_0_month AS rt_6_month,	
		after_7_month*100/after_0_month AS rt_7_month,	
		after_8_month*100/after_0_month AS rt_8_month,	
		after_9_month*100/after_0_month AS rt_9_month,	
		after_10_month*100/after_0_month AS rt_10_month,	
		after_11_month*100/after_0_month AS rt_11_month,	
		after_12_month*100/after_0_month AS rt_12_month
FROM customer_cohort
ORDER BY 1;

--- Average retention rate for all customers
SELECT ROUND(AVG(rt_0_month)) AS average_retention_rate
FROM   (SELECT rt_0_month FROM customer_retention_rate_view
		UNION ALL
		SELECT rt_1_month FROM customer_retention_rate_view
		UNION ALL
		SELECT rt_2_month FROM customer_retention_rate_view
		UNION ALL
		SELECT rt_3_month FROM customer_retention_rate_view
		UNION ALL
		SELECT rt_4_month FROM customer_retention_rate_view
		UNION ALL
		SELECT rt_5_month FROM customer_retention_rate_view
		UNION ALL
		SELECT rt_6_month FROM customer_retention_rate_view
		UNION ALL
		SELECT rt_7_month FROM customer_retention_rate_view
		UNION ALL
		SELECT rt_8_month FROM customer_retention_rate_view
		UNION ALL
		SELECT rt_9_month FROM customer_retention_rate_view
		UNION ALL
		SELECT rt_10_month FROM customer_retention_rate_view
		UNION ALL
		SELECT rt_11_month FROM customer_retention_rate_view
		UNION ALL
		SELECT rt_12_month FROM customer_retention_rate_view) AS sub 
WHERE rt_0_month != 0;

--- Customer Lifetime Value 
DROP VIEW IF exists customer_life_time_value;
CREATE VIEW customer_life_time_value AS
WITH average_purchase_value AS(
SELECT customer_id,
	   ROUND(AVG(quantity * unit_price)) AS avg_value
FROM customer_table
GROUP BY 1
)
, purchase_frequency AS(
SELECT customer_id, COUNT(DISTINCT invoice_date) AS frequency
FROM public."Online Retail"
WHERE unit_price > 0 
AND   quantity > 0
AND   customer_id IS NOT NULL
GROUP BY 1
)
, average_life_span AS(
SELECT v.customer_id, AVG(v.visit_month - fv.first_month) AS average_life_span
FROM customer_visits v
JOIN customer_first_visits fv ON v.customer_id = fv.customer_id
GROUP BY 1
ORDER BY 1
)

SELECT customer_id, ROUND(v.avg_value * f.frequency * l.average_life_span) AS life_time_value
FROM average_purchase_value v
NATURAL JOIN purchase_frequency f
NATURAL JOIN average_life_span l
ORDER BY 2 DESC;

--- RFM
DROP TABLE IF exists customer_rfm_table;
CREATE TABLE customer_rfm_table AS
WITH customer_last_visits AS(
SELECT
	customer_id,
	MAX(visit_month) AS last_month
FROM customer_visits
GROUP BY customer_id
)
, customer_frequency AS(
SELECT customer_id, COUNT(DISTINCT invoice_date) AS frequency
FROM public."Online Retail"
WHERE unit_price > 0 
AND   quantity > 0
AND   customer_id IS NOT NULL
GROUP BY 1
)
, customer_monetary_value AS(
SELECT customer_id,
	   SUM(quantity * unit_price) AS monetary_value
FROM customer_table
GROUP BY 1
)
, customer_rfm_ranking AS(
SELECT f.customer_id,
	   (SELECT MAX(visit_month) FROM customer_table) - l.last_month AS recency,
	   fr.frequency,
	   m.monetary_value AS monetary,
	   NTILE(3) OVER (ORDER BY (SELECT MAX(visit_month) FROM customer_table) - l.last_month DESC) as R_rank,
	   NTILE(3) OVER (ORDER BY fr.frequency) as F_rank,
	   NTILE(3) OVER (ORDER BY m.monetary_value) as M_rank,
	   CONCAT(NTILE(3) OVER (ORDER BY (SELECT MAX(visit_month) FROM customer_table) - l.last_month DESC)::text, 					  NTILE(3) OVER (ORDER BY fr.frequency)::text,
			  NTILE(3) OVER (ORDER BY m.monetary_value)::text) AS RFM_rank
FROM customer_last_visits l
NATURAL JOIN customer_first_visits f 
NATURAL JOIN customer_frequency fr 
NATURAL JOIN customer_monetary_value m
)


SELECT customer_id, r_rank, f_rank, m_rank, rfm_rank,
CASE
	WHEN rfm_rank IN ('111') THEN 'Lost' 
	WHEN rfm_rank IN ('112','121','113', '122') THEN 'Cooled' -- Customers who purchased a long time ago
	WHEN rfm_rank IN ('131', '132', '123', '133') THEN 'Need reheat' -- Slipping customers who purchased frequently and largely 
	WHEN rfm_rank IN ('222', '213', '223', '313', '212', '221') THEN 'Potential' -- Recent customers with decent monetary value
	WHEN rfm_rank IN ('311', '312', '211') THEN 'New' -- New customers
	WHEN rfm_rank IN ('321', '322', '331', '231', '232', '233', '323', '332') THEN 'Hot'
	WHEN rfm_rank IN ('333') THEN 'Champion' -- Ideal customers
	END AS rfm_segment 
FROM customer_rfm_ranking;

--- Customer cancellation rate
/* An acceptable cancel_rate should be around 10% of a customer's total orders */
WITH customer_cancel_count AS(
SELECT customer_id, COUNT(invoice_no) cancel_count_per_customer
FROM public."Online Retail"
WHERE quantity < 0
	  AND invoice_no LIKE 'C%'
	  AND customer_id IS NOT NULL
	  AND LENGTH(invoice_no) >= 6 
GROUP BY 1
ORDER BY 2 DESC
)
, cancel_count_support AS(
SELECT c.customer_id, COUNT(p.invoice_date) AS customer_total_order
FROM customer_cancel_count c
JOIN public."Online Retail" p ON c.customer_id = p.customer_id
GROUP BY 1
)

SELECT s.customer_id, 100*c.cancel_count_per_customer/s.customer_total_order AS cancel_rate, c.cancel_count_per_customer
FROM cancel_count_support s
JOIN customer_cancel_count c
ON s.customer_id = c.customer_id
WHERE 100*c.cancel_count_per_customer/s.customer_total_order != 0
ORDER BY 3 DESC

--- Product recommendation for customer based on customer's purchase history
SELECT customer_id, stock_code, description
FROM public."Online Retail"
WHERE customer_id IS NOT NULL
GROUP BY 1, 2, 3
ORDER BY 1

------------------------------------------

-- Inventory analysis
--- Popular products for us to stock more
WITH CTE AS(
SELECT stock_code, SUM(quantity) AS total_purchased_quantity
FROM invoice_sales
GROUP BY 1
ORDER BY 2 DESC
)

SELECT DISTINCT a.stock_code, b.description, a.total_purchased_quantity
FROM CTE a
JOIN public."Online Retail" b ON a.stock_code = b.stock_code
ORDER BY 3 DESC;

--- Products with high cancellation rates for us to stock less
WITH product_cancel_count AS(
SELECT stock_code, COUNT(invoice_no) AS cancel_frequency
FROM public."Online Retail"
WHERE invoice_no LIKE 'C%' 
	AND LENGTH(stock_code) >= 5 
	AND LENGTH(invoice_no) >= 6
GROUP BY 1
ORDER BY 2 DESC
)
, product_cancel_rate_support AS(
SELECT m.stock_code, 100*c.cancel_frequency/m.product_total_order AS product_cancel_rate
FROM
	(SELECT stock_code, COUNT(DISTINCT invoice_date) AS product_total_order
	FROM public."Online Retail"
	GROUP BY 1
	ORDER BY 2 DESC) AS m
JOIN product_cancel_count c
ON m.stock_code = c.stock_code
ORDER BY 2 DESC
)

SELECT DISTINCT a.stock_code, b.description, a.product_cancel_rate, c.cancel_frequency
FROM product_cancel_rate_support a
LEFT JOIN public."Online Retail" b ON a.stock_code = b.stock_code
LEFT JOIN product_cancel_count c ON b.stock_code = c.stock_code
WHERE a.product_cancel_rate > 10
ORDER BY 4 DESC

---- Recommend to the customer the products that are most frequently purchased together
DROP TABLE IF exists product_recommondation_by_frequency;
CREATE TABLE product_recommondation_by_frequency AS
WITH sub AS(
SELECT invoice_date, COUNT(invoice_date)
FROM public."Online Retail"
GROUP BY 1
HAVING COUNT(invoice_date) > 1
)
, sub_2 AS(
SELECT invoice_date, ROW_NUMBER() OVER (ORDER BY invoice_date) AS basket_number
FROM 
(SELECT DISTINCT invoice_date FROM sub) AS sub_2_support
)
, big_invoice_with_basket_number AS(
SELECT s.invoice_date, p.stock_code, p.description, s.basket_number
FROM public."Online Retail" p
RIGHT JOIN sub_2 s ON s.invoice_date = p.invoice_date
WHERE unit_price > 0 
	  AND quantity > 0 
	  AND customer_id IS NOT NULL
	  AND LENGTH(stock_code) >= 5 
GROUP BY 1,2,3,4
ORDER BY 1
)
, basket_group AS (
SELECT c.product_bought, c.bought_with, COUNT(*) AS bought_together_frequency
FROM
	(SELECT a.basket_number, a.stock_code AS product_bought, b.stock_code AS bought_with 
	FROM big_invoice_with_basket_number a
	JOIN big_invoice_with_basket_number b
	ON a.basket_number = b.basket_number AND a.stock_code != b.stock_code) AS c
GROUP BY 1, 2
HAVING COUNT(*) > 2
)

SELECT s.product_bought, b.bought_with, s.highest_frequency
FROM 
	(SELECT product_bought, MAX(bought_together_frequency) AS highest_frequency
	FROM basket_group 
	GROUP BY 1) AS s
LEFT JOIN basket_group b ON b.product_bought = s.product_bought AND s.highest_frequency = b.bought_together_frequency
ORDER BY 1;
