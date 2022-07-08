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

--new overview tables
--table1
DROP TABLE IF EXISTS product_overview;
CREATE TEMP TABLE product_overview AS
WITH purchase_visits AS (
  SELECT
    visit_id
  FROM
    clique_bait.events
  WHERE
    event_type = 3
),
purchases_cte AS(
  SELECT
    product_id,
    page_name,
    product_category,
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
    page_name,
    product_category
),
viewed_added_cte AS(
  SELECT
    product_id,
    page_name,
    product_category,
    SUM(
      CASE
        WHEN event_name = 'Page View' THEN 1
        ELSE 0
      END
    ) AS num_viewed,
    SUM(
      CASE
        WHEN event_name = 'Add to Cart' THEN 1
        ELSE 0
      END
    ) AS num_add_to_cart
  FROM
    clique_bait.events
    JOIN clique_bait.event_identifier ON event_identifier.event_type = events.event_type
    JOIN clique_bait.page_hierarchy ON page_hierarchy.page_id = events.page_id
  WHERE
    product_id IS NOT NULL
  GROUP BY
    product_id,
    page_name,
    product_category
)
SELECT
  purchases_cte.product_id,
  purchases_cte.page_name,
  purchases_cte.product_category,
  num_purchases,
  num_viewed,
  num_add_to_cart,
  num_add_to_cart - num_purchases AS num_cart_abandoned
FROM
  purchases_cte
  JOIN viewed_added_cte ON purchases_cte.product_id = viewed_added_cte.product_id
ORDER BY
  purchases_cte.product_id;

--table2
DROP TABLE IF EXISTS category_overview;
CREATE TEMP TABLE category_overview AS
SELECT
  product_category,
  SUM(num_purchases) AS num_purchases,
  SUM(num_viewed) AS num_viewed,
  SUM(num_add_to_cart) AS num_add_to_cart,
  SUM(num_cart_abandoned) AS num_cart_abandoned
FROM product_overview
GROUP BY product_category;

--q1 overview
SELECT
  *
FROM
  product_overview
ORDER BY
  num_viewed DESC
LIMIT
  1;
SELECT
  *
FROM
  product_overview
ORDER BY
  num_add_to_cart DESC
LIMIT
  1;
SELECT
  *
FROM
  product_overview
ORDER BY
  num_purchases DESC
LIMIT
  1;

--q2 overview
  
SELECT
  product_id,
  page_name,
  ROUND(num_cart_abandoned / num_add_to_cart :: NUMERIC, 2)
FROM
  product_overview
ORDER BY
  num_cart_abandoned DESC
LIMIT
  1;
--q3 overview
SELECT
  product_id,
  page_name,
  num_viewed,
  num_purchases,
  ROUND(100 * num_purchases :: NUMERIC / num_viewed, 2) AS perc_view_to_purchase
FROM
  product_overview
ORDER BY
  perc_view_to_purchase DESC;
--q4 overview
SELECT
  ROUND(AVG(num_add_to_cart / num_viewed :: NUMERIC), 4) AS avg_conversion_view_cart
FROM
  product_overview;
--q5 overview
SELECT
  ROUND(AVG( num_purchases/ num_add_to_cart :: NUMERIC), 4) AS avg_conversion_view_cart
FROM
  product_overview;

--final table view
WITH base_cte AS(
    SELECT
      user_id,
      visit_id,
      MIN(event_time) AS visit_start_time,
      SUM(
        CASE
          WHEN event_name = 'Page View' THEN 1
          ELSE 0
        END
      ) AS page_views,
      SUM(
        CASE
          WHEN event_name = 'Add to Cart' THEN 1
          ELSE 0
        END
      ) AS cart_adds,
      MAX(
        CASE
          WHEN event_name = 'Purchase' THEN 1
          ELSE 0
        END
      ) AS purchase,
      CASE
        WHEN MIN(event_time) BETWEEN '2020-01-01'
        AND '2020-01-14' THEN 1
        WHEN MIN(event_time) BETWEEN '2020-01-15'
        AND '2020-01-28' THEN 2
        WHEN MIN(event_time) BETWEEN '2020-02-01'
        AND '2020-03-31' THEN 3
        ELSE NULL
      END AS campaign_id,
      SUM(
        CASE
          WHEN event_name = 'Ad Impression' THEN 1
          ELSE 0
        END
      ) AS impression,
      SUM(
        CASE
          WHEN event_name = 'Ad Click' THEN 1
          ELSE 0
        END
      ) AS click,
        STRING_AGG(
    CASE
      WHEN page_hierarchy.product_id IS NOT NULL AND events.event_type = 2
        THEN page_hierarchy.page_name
      ELSE NULL END,
    ', ' ORDER BY events.sequence_number
  ) AS cart_products
    FROM
      clique_bait.events
      JOIN clique_bait.users ON users.cookie_id = events.cookie_id
      JOIN clique_bait.event_identifier On event_identifier.event_type = events.event_type
      LEFT JOIN clique_bait.page_hierarchy ON page_hierarchy.page_id = events.page_id
    GROUP BY
      user_id,
      visit_id
    ORDER BY
      user_id,
      visit_id
  )
SELECT
  base_cte.user_id,
  base_cte.visit_id,
  visit_start_time,
  page_views,
  cart_adds,
  purchase,
  campaign_name,
  impression,
  click,
  cart_products
FROM
  base_cte
  LEFT JOIN clique_bait.campaign_identifier ON campaign_identifier.campaign_id = base_cte.campaign_id
ORDER BY
      user_id;