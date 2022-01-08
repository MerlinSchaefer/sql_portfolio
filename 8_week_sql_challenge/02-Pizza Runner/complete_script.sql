-- inspect data
SELECT 
   table_name, 
   column_name, 
   data_type 
FROM 
   information_schema.columns
WHERE 
   table_schema = 'pizza_runenr'
ORDER BY table_name;

-- tables are small can inspect whole table

SELECT 
  *
FROM pizza_runner.customer_orders;

SELECT
  * 
FROM pizza_runner.pizza_names;

SELECT
  * 
FROM pizza_runner.pizza_recipes;

SELECT
  * 
FROM pizza_runner.pizza_toppings;

SELECT
  * 
FROM pizza_runner.runner_orders;

SELECT
 *
FROM pizza_runner.runners;

-- check sales table for duplicates

SELECT
  order_id,
  runner_id,
  pickup_time,
  distance,
  duration,
  cancellation,
  COUNT(*) AS frequency
FROM pizza_runner.runner_orders
GROUP BY
  order_id,
  runner_id,
  pickup_time,
  distance,
  duration,
  cancellation
ORDER BY frequency DESC;


SELECT
  order_id,
  customer_id,
  pizza_id,
  exclusions,
  extras,
  order_time,
  COUNT(*) AS frequency
FROM pizza_runner.customer_orders
GROUP BY
  order_id,
  customer_id,
  pizza_id,
  exclusions,
  extras,
  order_time
ORDER BY frequency DESC;


-- clean tables

DROP TABLE IF EXISTS customer_orders_clean;
CREATE TEMP TABLE customer_orders_clean AS
SELECT
  order_id,
  customer_id,
  pizza_id,
  CASE
    WHEN exclusions IN ('null', '') THEN NULL
    ELSE exclusions
  END AS exclusions,
  CASE
    WHEN extras IN ('null', 'NaN', '') THEN NULL
    ELSE extras
  END AS extras,
  order_time
FROM
  pizza_runner.customer_orders;

DROP TABLE IF EXISTS runner_orders_clean;
CREATE TEMP TABLE runner_orders_clean AS
SELECT
  order_id,
  runner_id,
  CASE
    WHEN pickup_time IN ('null', '') THEN NULL
    ELSE pickup_time :: TIMESTAMP
  END AS pickup_time,
  CASE
    WHEN distance IN ('null', '') THEN NULL
    ELSE TO_NUMBER(distance, '999.99')
  END AS distance_km,
  CASE
    WHEN duration IN ('null', '') THEN NULL
    ELSE TO_NUMBER(duration, '999')
  END AS duration_min,
  CASE
    WHEN cancellation IN ('null', '') THEN NULL
    ELSE cancellation
  END AS cancellation
FROM
  pizza_runner.runner_orders;

-- question 1
SELECT
  COUNT(pizza_id)
FROM
  customer_orders_clean;

-- question 2
SELECT
  COUNT(DISTINCT order_id)
FROM
  customer_orders_clean;
  
-- question 3
SELECT
  runner_id,
  COUNT(*)
FROM
  runner_orders_clean
WHERE
  cancellation IS NULL
GROUP BY
  runner_id;

-- question 4

SELECT
  pizza_name,
  COUNT(*)
FROM
  customer_orders_clean
  JOIN pizza_runner.pizza_names ON customer_orders_clean.pizza_id = pizza_names.pizza_id
GROUP BY
  pizza_name;

-- question 5

SELECT
  customer_id,
  pizza_name,
  COUNT(*)
FROM
  customer_orders_clean
  JOIN pizza_runner.pizza_names ON customer_orders_clean.pizza_id = pizza_names.pizza_id
GROUP BY
  customer_id,
  pizza_name
ORDER BY
  customer_id;

-- question 6

SELECT
  co.order_id,
  SUM(COUNT(*)) OVER(PARTITION BY co.order_id) AS num_pizzas_ordered
FROM
  customer_orders_clean AS co
  JOIN runner_orders_clean AS ro ON co.order_id = ro.order_id
WHERE
  ro.cancellation IS NULL
GROUP BY
  co.order_id
ORDER BY
  num_pizzas_ordered DESC
LIMIT
  1;

-- question 7
WITH order_changes AS(
    SELECT
      order_id,
      customer_id,
      CASE
        WHEN exclusions IS NOT NULL
        OR extras IS NOT NULL THEN 'changed'
        ELSE 'unchanged'
      END AS pizza_changes
    FROM
      customer_orders_clean
  )
SELECT
  customer_id,
  pizza_changes,
  COUNT(*) AS num_pizzas
FROM
  order_changes
GROUP BY
  customer_id,
  pizza_changes
ORDER BY
  customer_id;
