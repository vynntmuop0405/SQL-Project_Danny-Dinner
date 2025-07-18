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

---- 5.Which item was the most popular for each customer?
WITH 
item_count AS (
SELECT a.customer_id, a.product_id,
	   COUNT(*) times_order
FROM sales a
GROUP BY a.customer_id, a.product_id
),
ranking AS (
SELECT *,
	   RANK() OVER(PARTITION BY customer_id ORDER BY times_order DESC) rank_in_order 
FROM item_count
)
SELECT a.*	, b.product_name		
FROM ranking a
LEFT JOIN menu b ON a.product_id = b.product_id 
WHERE rank_in_order = '1'

---- 6.item was purchased first by the customer after they became a member
WITH
purchase_after_join AS (
SELECT a.customer_id, b.join_date,
	   a.order_date, a.product_id,
	   DENSE_RANK() OVER(PARTITION BY a.customer_id ORDER BY a.order_date) time_visit
FROM sales a
LEFT JOIN members b ON a.customer_id = b.customer_id
WHERE a.order_date >= b.join_date
)
SELECT a.*, b.product_name
FROM purchase_after_join a
LEFT JOIN menu b ON a.product_id = b.product_id
WHERE time_visit = '1'

---- 7. item was purchased just before the customer became a member?
WITH
purchase_after_join AS (
SELECT a.customer_id, b.join_date,
	   a.order_date, a.product_id,
	   DENSE_RANK() OVER(PARTITION BY a.customer_id ORDER BY a.order_date DESC) time_visit
FROM sales a
LEFT JOIN members b ON a.customer_id = b.customer_id
WHERE a.order_date < b.join_date
)
SELECT a.*, b.product_name
FROM purchase_after_join a
LEFT JOIN menu b ON a.product_id = b.product_id
WHERE time_visit = '1'

---- 8.total items and amount spent for each member before they became a member?
WITH
purchase_before_join AS (
SELECT a.customer_id, b.join_date,
	   a.order_date, a.product_id, c.product_name, c.price
FROM sales a
LEFT JOIN members b ON a.customer_id = b.customer_id
LEFT JOIN menu c ON a.product_id = c.product_id
WHERE a.order_date < b.join_date
),
total_items AS (
SELECT customer_id, product_name, price, 
	   COUNT(product_name) count,
	   price * COUNT(product_name) total_price
FROM purchase_before_join a
GROUP BY customer_id, product_name, price
)
SELECT customer_id, SUM(count) total_items, SUM(total_price) total_spent
FROM total_items
GROUP BY customer_id

---- 9. If each $1 spent equates to 10 points and sushi has a 2x points multiplier - how many points would each customer have?
WITH 
point AS (
SELECT a.*,
	   CASE WHEN a.product_name <> 'sushi' THEN a.price*10
			ELSE a.price*10*2 END AS point
FROM menu a ),
all_promotion AS (
SELECT a.customer_id, c.product_name,
	   COUNT(a.product_id) time_order,
	   COUNT(a.product_id) * d.point AS points
FROM sales a
LEFT JOIN members b ON a.customer_id = b.customer_id
LEFT JOIN menu c ON a.product_id = c.product_id
LEFT JOIN point d ON d.product_id = a.product_id
WHERE a.order_date >= b.join_date
GROUP BY a.customer_id, c.product_name, d.point
)
SELECT customer_id, SUM(points) total_point
FROM all_promotion
GROUP BY customer_id

---- In the first week after a customer joins the program (including their join date) they earn 2x points on all items, not just sushi.
---- How many points do customer A and B have at the end of January?
WITH 
point AS (
SELECT a.*,
	   CASE WHEN a.product_name <> 'sushi' THEN a.price*10
			ELSE a.price*10*2 END AS point
FROM menu a ),
all_promotion AS (
SELECT a.customer_id, c.product_name,
	   b.join_date, a.order_date,
	   COUNT(a.product_id) time_order,
	   CASE WHEN a.order_date <= DATEADD(DAY, 7, b.join_date) THEN d.point*2
			ELSE d.point END AS point
FROM sales a
LEFT JOIN members b ON a.customer_id = b.customer_id
LEFT JOIN menu c ON a.product_id = c.product_id
LEFT JOIN point d ON d.product_id = a.product_id
WHERE a.order_date >= b.join_date
GROUP BY a.customer_id, c.product_name, d.point, b.join_date, a.order_date
)  ---SELECT * FROM all_promotion
SELECT customer_id, SUM(point) total_point
FROM all_promotion
WHERE order_date <= '2021-01-31'
GROUP BY customer_id