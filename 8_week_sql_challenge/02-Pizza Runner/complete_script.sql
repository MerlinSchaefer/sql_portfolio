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

-- question  8
SELECT
  COUNT(*)
FROM
  customer_orders_clean
WHERE
  extras IS NOT NULL
  AND exclusions IS NOT NULL;

-- question 9

SELECT
  EXTRACT(
    'HOUR'
    FROM
      order_time
  ) AS hour_of_day,
  COUNT(*) AS num_pizzas
FROM
  customer_orders_clean
GROUP BY
  hour_of_day
ORDER BY
  hour_of_day;

-- question 10

SELECT
  TO_CHAR(order_time, 'Dy') AS day_of_week,
  COUNT(*) AS num_pizzas
FROM
  customer_orders_clean
GROUP BY
  day_of_week
ORDER BY
  day_of_week;

-- runner and customer exp

SELECT
  (
    DATE_TRUNC('WEEK', registration_date - INTERVAL '4 DAY') + INTERVAL '4 DAY'
  ) :: DATE AS signup_week,
  COUNT(*)
FROM
  pizza_runner.runners
GROUP BY
  signup_week
ORDER BY
  signup_week;

SELECT
  ro.runner_id AS runner_id,
  ROUND(
    AVG(
      EXTRACT(
        "MIN"
        FROM
          (ro.pickup_time - co.order_time)
      )
    )
  ) AS avg_pickup_time_diff
FROM
  customer_orders_clean AS co
  JOIN runner_orders_clean AS ro ON co.order_id = ro.order_id
GROUP BY
  runner_id
ORDER BY
  runner_id;

WITH orders_summarized AS(
    SELECT
      co.order_id,
      AVG(
        EXTRACT(
          "MIN"
          FROM
            (ro.pickup_time - co.order_time)
        )
      ) AS time_to_prepare,
      COUNT(*) as num_pizzas
    FROM
      customer_orders_clean AS co
      JOIN runner_orders_clean AS ro ON co.order_id = ro.order_id
    WHERE
      ro.cancellation IS NULL
    GROUP BY
      co.order_id
  )
SELECT
  ROUND(
    CORR(time_to_prepare, num_pizzas)::NUMERIC, 
    2) AS corr_num_pizzas_time_to_prepare
FROM
  orders_summarized;

SELECT
  co.customer_id AS customer,
  ROUND(
    AVG(
      ro.distance_km
    )
  ) AS avg_km_travelled
FROM
  customer_orders_clean AS co
  JOIN runner_orders_clean AS ro ON co.order_id = ro.order_id
GROUP BY
  customer
ORDER BY
  customer;

SELECT
  MAX(duration_min) AS max_delivery_time,
  MIN(duration_min) AS min_delivery_time,
  MAX(duration_min) - MIN(duration_min) AS diff_max_min_delivery_time
FROM
  runner_orders_clean
WHERE
  cancellation IS NULL;

SELECT
  runner_id,
  ROUND(
    AVG(distance_km :: NUMERIC /(duration_min :: NUMERIC / 60)),
    2
  ) AS avg_kmh_speed
FROM
  runner_orders_clean
GROUP BY
  runner_id
ORDER BY
  runner_id;

WITH delivery_success AS(
    SELECT
      runner_id,
      CASE
        WHEN cancellation IS NULL THEN 1
        ELSE 0
      END AS delivery_success
    FROM
      runner_orders_clean
  )
SELECT
  runner_id,
  COUNT(*) AS total_orders,
  SUM(delivery_success) AS successful_delivery,
  ROUND(SUM(delivery_success :: NUMERIC) / COUNT(*), 2) AS perc_successful_deliveries
FROM
  delivery_success
GROUP BY
  runner_id
ORDER BY
  runner_id;