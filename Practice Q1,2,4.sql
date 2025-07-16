---- 1. Total amount each customer spent
WITH 
revenue AS 
(
SELECT a.*, b.price
FROM sales a
LEFT JOIN menu b on a.product_id = b.product_id
)
SELECT DISTINCT customer_id,
	   SUM(price) OVER(PARTITION BY customer_id) total_spent
FROM revenue
;
---- 2. Count number of days each cust visited
select customer_id, 
	   COUNT(DISTINCT order_date) day_visited
from sales
GROUP BY customer_id
;
---- 3. First item from the menu purchased by custs.
---- 4. Most purchase item in menu and times it purchased by all customers?
WITH 
dish_order_times AS (
SELECT b.product_name,
	   COUNT(*) orders
FROM sales a
LEFT JOIN menu b ON a.product_id = b.product_id
GROUP BY b.product_name
)
SELECT TOP 1 * FROM dish_order_times ORDER BY orders DESC