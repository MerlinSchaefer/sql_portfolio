-- inspect data
SELECT 
   table_name, 
   column_name, 
   data_type 
FROM 
   information_schema.columns
WHERE 
   table_schema = 'dannys_diner'
ORDER BY table_name;

-- tables are small can inspect whole table
SELECT 
  *
FROM dannys_diner.members;

SELECT
  * 
FROM dannys_diner.menu;

SELECT
  * 
FROM dannys_diner.sales;

-- check sales table for duplicates

SELECT
  customer_id,
  order_date,
  product_id,
  COUNT(*) AS frequency
FROM dannys_diner.sales
GROUP BY
  customer_id,
  order_date,
  product_id
ORDER BY frequency DESC;

-- create complete table (as requested in question 11)
DROP TABLE IF EXISTS diner_data_complete;
CREATE TEMP TABLE diner_data_complete AS(
    SELECT
      sales.customer_id,
      sales.order_date,
      menu.product_name,
      menu.price,
      CASE
        WHEN members.join_date <= sales.order_date THEN 'Y'
        ELSE 'N'
      END AS member,
      members.join_date
    FROM
      dannys_diner.sales
      LEFT JOIN dannys_diner.menu ON sales.product_id = menu.product_id
      LEFT JOIN dannys_diner.members ON sales.customer_id = members.customer_id
    ORDER BY
      sales.customer_id,
      order_date,
      price DESC
  );

-- question 1

SELECT
  customer_id,
  SUM(price) AS total_spent
FROM
  diner_data_complete
GROUP BY
  customer_id
ORDER BY
  customer_id;

-- question 2
SELECT
  customer_id,
  COUNT(DISTINCT order_date) As num_days
FROM
  diner_data_complete
GROUP BY
  customer_id
ORDER BY
  customer_id;

-- question 3

WITH ranked_orders AS(
    SELECT
      customer_id,
      product_name,
      ROW_NUMBER() OVER(
        PARTITION BY customer_id
        ORDER BY
          order_date
      ) AS purchase_rank
    FROM
      diner_data_complete
  )
SELECT
  customer_id,
  product_name
FROM
  ranked_orders
WHERE
  purchase_rank = 1
ORDER BY
  customer_id;

-- question 4

SELECT
  product_name,
  COUNT(*) AS num_purchases
FROM
  diner_data_complete
GROUP BY
  product_name
ORDER BY
  num_purchases DESC
LIMIT
  1;

-- question 5
WITH ranked_purchases AS(
    SELECT
      customer_id,
      product_name,
      RANK() OVER(
        PARTITION BY customer_id
        ORDER BY
          COUNT(*) DESC
      ) AS rank_num_purchases
    FROM
      diner_data_complete
    GROUP BY
      customer_id,
      product_name
  )
SELECT
  customer_id,
  product_name
FROM
  ranked_purchases
WHERE
  rank_num_purchases = 1;

-- question 6
WITH ranked_purchases AS (
    SELECT
      customer_id,
      product_name,
      RANK() OVER(
        PARTITION BY customer_id
        ORDER BY
          order_date
      ) AS order_rank
    FROM
      diner_data_complete
    WHERE
      member = 'Y'
  )
SELECT
  customer_id,
  product_name
FROM
  ranked_purchases
WHERE
  order_rank = 1;

-- question 7
WITH lag_orders AS(
    SELECT
      customer_id,
      order_date,
      product_name,
      LAG(product_name) OVER customer_date AS previous_order,
      member
    FROM
      diner_data_complete WINDOW customer_date AS (
        PARTITION BY customer_id
        ORDER BY
          order_date
      )
  ),
  ranked_lag_orders AS (
    SELECT
      customer_id,
      previous_order,
      RANK() OVER customer_date AS order_rank
    FROM
      lag_orders
    WHERE
      member = 'Y' WINDOW customer_date AS (
        PARTITION BY customer_id
        ORDER BY
          order_date
      )
  )
SELECT
  customer_id,
  previous_order AS last_nonmember_purchase
FROM
  ranked_lag_orders
WHERE
  order_rank = 1;

-- question 8

SELECT
  customer_id,
  SUM(price) AS total_amount,
  COUNT(*) AS total_items
FROM
  diner_data_complete
WHERE
  member = 'N'
  AND join_date IS NOT NULL
GROUP BY
  customer_id;

-- question 9
WITH point_data AS (
    SELECT
      customer_id,
      CASE
        WHEN product_name = 'sushi' THEN price * 20
        ELSE price * 10
      END AS points
    FROM
      diner_data_complete
  )
SELECT
  customer_id,
  SUM(points) AS total_points
FROM
  point_data
GROUP BY
  customer_id
ORDER BY
  customer_id;

-- question 10
WITH point_data AS (
SELECT
  customer_id,
  order_date,
  join_date,
  product_name,
  CASE
    WHEN product_name = 'sushi' THEN price * 20
    WHEN join_date + INTERVAL '7 DAY' > order_date AND join_date <= order_date THEN price * 20
    ELSE price * 10
  END AS points
FROM
  diner_data_complete
WHERE
  join_date IS NOT NULL)
SELECT
customer_id,
SUM(points) AS total_points
FROM point_data
WHERE EXTRACT('MONTH' FROM order_date) = 1
GROUP BY customer_id
ORDER BY customer_id;

-- question 11
SELECT 
    customer_id,
    order_date,
    product_name,
    price,
    member
FROM diner_data_complete;

-- question 12
SELECT 
    customer_id,
    order_date,
    product_name,
    price,
    member,
    CASE
    WHEN member = 'N' THEN NULL
    ELSE RANK() OVER(PARTITION BY customer_id, member ORDER BY order_date) 
    END AS ranking
FROM diner_data_complete;