-- inspect data
SELECT 
   table_name, 
   column_name, 
   data_type 
FROM 
   information_schema.columns
WHERE 
   table_schema = 'clique_bait'
ORDER BY table_name;

SELECT
  *
FROM
  clique_bait.users
LIMIT
  10;

SELECT
  *
FROM
  clique_bait.events
LIMIT
  10;

SELECT
  *
FROM
  clique_bait.page_hierarchy;

SELECT
  *
FROM
  clique_bait.event_identifier;
-- check for duplicates
SELECT
  user_id,
  cookie_id,
  start_date,
  COUNT(*) AS frequency
FROM
  clique_bait.users
GROUP BY
  user_id,
  cookie_id,
  start_date
ORDER BY frequency DESC;

SELECT
  visit_id,
  cookie_id,
  page_id,
  event_type,
  sequence_number,
  event_time,
  COUNT(*) AS frequency
FROM
  clique_bait.events
GROUP BY
  visit_id,
  cookie_id,
  page_id,
  event_type,
  sequence_number,
  event_time
ORDER BY
  frequency DESC;

--q1

SELECT
  COUNT(DISTINCT user_id) AS num_users
FROM
  clique_bait.users;

--q2

WITH cookie_count AS (
    SELECT
      user_id,
      COUNT(*) AS num_cookies
    FROM
      clique_bait.users
    GROUP BY
      user_id
  )
SELECT
  ROUND(AVG(num_cookies), 2)
FROM
  cookie_count;

--q3
SELECT
  DATE_TRUNC('month', event_time) AS month,
  COUNT(DISTINCT(visit_id))
FROM
  clique_bait.events
GROUP BY
  month;

--q4
SELECT
  event_name,
  COUNT(*) AS num_events
FROM
  clique_bait.events
  JOIN clique_bait.event_identifier ON event_identifier.event_type = events.event_type
GROUP BY
  event_name
ORDER BY
  num_events;

--q5
WITH purchase_cte AS(
    SELECT
      visit_id,
      MAX(
        CASE
          WHEN event_name = 'Purchase' THEN 1
          ELSE 0
        END
      ) AS has_purchase
    FROM
      clique_bait.events
      JOIN clique_bait.event_identifier ON event_identifier.event_type = events.event_type
    GROUP BY
      visit_id
  )
SELECT
  COUNT(*) AS count,
  SUM(has_purchase) AS count_purchase,
  ROUND(
    100 *(SUM(has_purchase) / COUNT(*) :: NUMERIC),
    2
  ) AS perc_purchase
FROM
  purchase_cte;

--q6
WITH view_purchase_cte AS(
    SELECT
      visit_id,
      MAX(
        CASE
          WHEN event_name = 'Page View'
          AND page_name = 'Checkout' THEN 1
          ELSE 0
        END
      ) AS view_checkout,
      MAX(
        CASE
          WHEN event_name = 'Purchase' THEN 1
          ELSE 0
        END
      ) AS has_purchase
    FROM
      clique_bait.events
      JOIN clique_bait.event_identifier ON event_identifier.event_type = events.event_type
      JOIN clique_bait.page_hierarchy ON events.page_id = page_hierarchy.page_id
    GROUP BY
      visit_id
  )
SELECT
  SUM(
    CASE
      WHEN has_purchase = 0 THEN 1
      ELSE 0
    END
  ) AS num_no_purchases,
  COUNT(*) AS view_checkout,
  ROUND(
    100 * SUM(
      CASE
        WHEN has_purchase = 0 THEN 1
        ELSE 0
      END
    ) / COUNT(*) :: NUMERIC,
    2
  ) AS perc_view_checkout_no_purchase
FROM
  view_purchase_cte
WHERE
  view_checkout = 1;

--q7
SELECT
  page_name,
  COUNT(*) AS num_visits
FROM
  clique_bait.events
  JOIN clique_bait.event_identifier ON event_identifier.event_type = events.event_type
  JOIN clique_bait.page_hierarchy ON events.page_id = page_hierarchy.page_id
WHERE
  event_name = 'Page View'
GROUP BY
  page_name
ORDER BY
  num_visits DESC
LIMIT
  3;

--q8
SELECT
  product_category,
  event_name,
  COUNT(*) AS num_events
FROM
  clique_bait.events
  JOIN clique_bait.event_identifier ON event_identifier.event_type = events.event_type
  JOIN clique_bait.page_hierarchy ON events.page_id = page_hierarchy.page_id
WHERE
  event_name IN ('Page View', 'Add to Cart')
  AND product_category IS NOT NULL
GROUP BY
  product_category,
  event_name
ORDER BY
  product_category;

--q9
WITH purchase_visits AS (
    SELECT
      visit_id
    FROM
      clique_bait.events
    WHERE
      event_type = 3
  )
SELECT
  product_id,
  page_name,
  SUM(
    CASE
      WHEN event_name = 'Add to Cart' THEN 1
      ELSE 0
    END
  ) AS num_purchases
FROM
  clique_bait.events
  JOIN clique_bait.event_identifier ON event_identifier.event_type = events.event_type
  JOIN clique_bait.page_hierarchy ON page_hierarchy.page_id = events.page_id
WHERE
  EXISTS (
    SELECT
      1
    FROM
      purchase_visits
    WHERE
      events.visit_id = purchase_visits.visit_id
  )
  AND product_id IS NOT NULL
GROUP BY
  product_id,
  page_name
ORDER BY
  num_purchases DESC
LIMIT
  3;