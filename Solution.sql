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

customer_id	total_spent
A			152
B			148
C			72

---- 2. Count number of days each cust visited
select customer_id, 
	   COUNT(DISTINCT order_date) day_visited
from sales
GROUP BY customer_id
;

customer_id	 day_visited
A				4
B				6
C				2


---- 3. First item from the menu purchased by custs.
WITH time_visits AS (
SELECT DISTINCT customer_id,
		order_date, product_id,
		DENSE_RANK() OVER(PARTITION BY customer_id ORDER BY order_date) visit_time
FROM sales
)
SELECT a.customer_id, a.order_date, STRING_AGG(b.product_name,',') product_name
FROM time_visits a
LEFT JOIN menu b ON a.product_id=b.product_id
WHERE visit_time = 1
GROUP BY a.customer_id, a.order_date

customer_id	order_date	product_name
A			2021-01-01	sushi,curry
B			2021-01-01	curry
C			2021-01-01	ramen

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

product_name	orders
ramen			16

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

customer_id	product_id	times_order	rank_in_order	product_name
A			3			6			1				ramen
B			1			4			1				sushi
B			2			4			1				curry
B			3			4			1				ramen
C			3			6			1				ramen

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
SELECT DISTINCT a.*, b.product_name
FROM purchase_after_join a
LEFT JOIN menu b ON a.product_id = b.product_id
WHERE time_visit = '1'

customer_id	join_date	order_date	product_id	time_visit	product_name
A			2021-01-07	2021-01-07	2			1			curry
B			2021-01-09	2021-01-11	1			1			sushi

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
SELECT DISTINCT a.*, b.product_name
FROM purchase_after_join a
LEFT JOIN menu b ON a.product_id = b.product_id
WHERE time_visit = '1'

customer_id	join_date	order_date	product_id	time_visit	product_name
A			2021-01-07	2021-01-01	1			1			sushi
A			2021-01-07	2021-01-01	2			1			curry
B			2021-01-09	2021-01-04	1			1			sushi

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

customer_id	total_items	total_spent
A			4			50
B			6			80

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

customer_id	total_point
A			1020
B			880

---- In the first week after a customer joins the program (including their join date) they earn 2x points on all items, not just sushi.
---- How many points do customer A and B have at the end of January?
WITH 
all_promotion_order AS (
SELECT a.customer_id, a.product_id,
	   b.join_date, a.order_date,
	   COUNT(a.product_id) time_order
FROM sales a
LEFT JOIN members b ON a.customer_id = b.customer_id
WHERE a.order_date >= b.join_date
GROUP BY a.customer_id, a.product_id, b.join_date, a.order_date
),  --SELECT * FROM all_promotion
point AS (
SELECT a.customer_id, a.product_id, a.join_date, a.order_date, b.product_name, b.price, a.time_order,
		CASE WHEN a.order_date <= DATEADD(DAY,7,a.join_date) THEN b.price*20*a.time_order
			 WHEN a.order_date > DATEADD(DAY,7,a.join_date) THEN b.price*10*a.time_order
			 WHEN b.product_name = 'sushi' THEN b.price*20
			 ELSE NULL END AS point
FROM all_promotion_order a
LEFT JOIN menu b ON a.product_id = b.product_id
) --SELECT * FROM point
SELECT customer_id, SUM(point) total_point
FROM point
GROUP BY customer_id
--
customer_id	total_pont
A			2040
B			1120