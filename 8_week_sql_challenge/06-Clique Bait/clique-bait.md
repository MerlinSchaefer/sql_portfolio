# Clique-Bait - Case Study


# Context
Clique Bait is not like your regular online seafood store - the founder and CEO Danny, was also a part of a digital data analytics team and wanted to expand his knowledge into the seafood industry!

In this case study - you are required to support Danny’s vision and analyse his dataset and come up with creative solutions to calculate funnel fallout rates for the Clique Bait online store.

#  Datasets
All of the required datasets for this case study reside within the data_mart schema on the PostgreSQL Docker setup.

For this case study there are a total of 5 datasets.

## tables

**Users**

Customers who visit the Clique Bait website are tagged via their cookie_id.

|user_id|cookie_id|start_date         |
|-------|---------|-------------------|
|397    |3759ff   |2020-03-30 00:00:00|
|215    |863329   |2020-01-26 00:00:00|
|191    |eefca9   |2020-03-15 00:00:00|
|89     |764796   |2020-01-07 00:00:00|
|127    |17ccc5   |2020-01-22 00:00:00|
|81     |b0b666   |2020-03-01 00:00:00|
|260    |a4f236   |2020-01-08 00:00:00|
|203    |d1182f   |2020-04-18 00:00:00|
|23     |12dbc8   |2020-01-18 00:00:00|
|375    |f61d69   |2020-01-03 00:00:00|


**Events**

Customer visits are logged in this events table at a cookie_id level and the event_type and page_id values can be used to join onto relevant satellite tables to obtain further information about each event.

The sequence_number is used to order the events within each visit.

|visit_id|cookie_id|page_id            |event_type|sequence_number|event_time                |
|--------|---------|-------------------|----------|---------------|--------------------------|
|719fd3  |3d83d3   |5                  |1         |4              |2020-03-02 00:29:09.975502|
|fb1eb1  |c5ff25   |5                  |2         |8              |2020-01-22 07:59:16.761931|
|23fe81  |1e8c2d   |10                 |1         |9              |2020-03-21 13:14:11.745667|
|ad91aa  |648115   |6                  |1         |3              |2020-04-27 16:28:09.824606|
|5576d7  |ac418c   |6                  |1         |4              |2020-01-18 04:55:10.149236|
|48308b  |c686c1   |8                  |1         |5              |2020-01-29 06:10:38.702163|
|46b17d  |78f9b3   |7                  |1         |12             |2020-02-16 09:45:31.926407|
|9fd196  |ccf057   |4                  |1         |5              |2020-02-14 08:29:12.922164|
|edf853  |f85454   |1                  |1         |1              |2020-02-22 12:59:07.652207|
|3c6716  |02e74f   |3                  |2         |5              |2020-01-31 17:56:20.777383|


**Event Identifier**

The event_identifier table shows the types of events which are captured by Clique Bait’s digital data systems.

|event_type|event_name   |
|----------|-------------|
|1         |Page View    |
|2         |Add to Cart  |
|3         |Purchase     |
|4         |Ad Impression|
|5         |Ad Click     |

**Campaign Identifier**

This table shows information for the 3 campaigns that Clique Bait has ran on their website so far in 2020.

|campaign_id|products     |campaign_name                    |start_date         |end_date           |
|-----------|-------------|---------------------------------|-------------------|-------------------|
|1          |1-3          |BOGOF - Fishing For Compliments  |2020-01-01 00:00:00|2020-01-14 00:00:00|
|2          |4-5          |25% Off - Living The Lux Life    |2020-01-15 00:00:00|2020-01-28 00:00:00|
|3          |6-8          |Half Off - Treat Your Shellf(ish)|2020-02-01 00:00:00|2020-03-31 00:00:00|


**Page Hierarchy**
This table lists all of the pages on the Clique Bait website which are tagged and have data passing through from user interaction events.

|page_id|page_name    |product_category                 |product_id         |
|-------|-------------|---------------------------------|-------------------|
|1      |Home Page    |null                             |null               |
|2      |All Products |null                             |null               |
|3      |Salmon       |Fish                             |1                  |
|4      |Kingfish     |Fish                             |2                  |
|5      |Tuna         |Fish                             |3                  |
|6      |Russian Caviar|Luxury                           |4                  |
|7      |Black Truffle|Luxury                           |5                  |
|8      |Abalone      |Shellfish                        |6                  |
|9      |Lobster      |Shellfish                        |7                  |
|10     |Crab         |Shellfish                        |8                  |
|11     |Oyster       |Shellfish                        |9                  |
|12     |Checkout     |null                             |null               |
|13     |Confirmation |null                             |null               |




# Data Cleaning

Checking for duplicates in Users and Events 
```sql
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
```
- no duplicates

# Digital Analysis

How many users are there?
```sql
SELECT
  COUNT(DISTINCT user_id) AS num_users
FROM
  clique_bait.users;
```

- 500

How many cookies does each user have on average?
```sql
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
```

What is the unique number of visits by all users per month?
```sql
SELECT
  DATE_TRUNC('month', event_time) AS month,
  COUNT(DISTINCT(visit_id))
FROM
  clique_bait.events
GROUP BY
  month;
```

|month                   |count|
|------------------------|-----|
|2020-01-01T00:00:00.000Z|876  |
|2020-02-01T00:00:00.000Z|1488 |
|2020-03-01T00:00:00.000Z|916  |
|2020-04-01T00:00:00.000Z|248  |
|2020-05-01T00:00:00.000Z|36   |


What is the number of events for each event type?
```sql
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
```

|event_name              |num_events|
|------------------------|----------|
|Ad Click                |702       |
|Ad Impression           |876       |
|Purchase                |1777      |
|Add to Cart             |8451      |
|Page View               |20928     |



What is the percentage of visits which have a purchase event?
```sql
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
```
- 49.86 %


What is the percentage of visits which view the checkout page but do not have a purchase event?
```sql
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
```

- 15.50%

What are the top 3 pages by number of views?

```sql
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
```

|page_name               |num_visits|
|------------------------|----------|
|All Products            |3174      |
|Checkout                |2103      |
|Home Page               |1782      |


What is the number of views and cart adds for each product category?
```sql
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
```

|product_category        |event_name|num_events|
|------------------------|----------|----------|
|Fish                    |Add to Cart|2789      |
|Fish                    |Page View |4633      |
|Luxury                  |Add to Cart|1870      |
|Luxury                  |Page View |3032      |
|Shellfish               |Add to Cart|3792      |
|Shellfish               |Page View |6204      |


What are the top 3 products by purchases?
```sql
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
```
|product_id              |page_name|num_purchases|
|------------------------|---------|-------------|
|7                       |Lobster  |754          |
|9                       |Oyster   |726          |
|8                       |Crab     |719          |


# Product Funnel Analysis
Using a single SQL query - create a new output table which has the following details:

How many times was each product viewed?
How many times was each product added to cart?
How many times was each product added to a cart but not purchased (abandoned)?
How many times was each product purchased?
Additionally, create another table which further aggregates the data for the above points but this time for each product category instead of individual products.

Use your 2 new output tables - answer the following questions:

Which product had the most views, cart adds and purchases?
Which product was most likely to be abandoned?
Which product had the highest view to purchase percentage?
What is the average conversion rate from view to cart add?
What is the average conversion rate from cart add to purchase?


# Generate a table that has 1 single row for every unique visit_id record and has the following columns:

user_id
visit_id
visit_start_time: the earliest event_time for each visit
page_views: count of page views for each visit
cart_adds: count of product cart add events for each visit
purchase: 1/0 flag if a purchase event exists for each visit
campaign_name: map the visit to a campaign if the visit_start_time falls between the start_date and end_date
impression: count of ad impressions for each visit
click: count of ad clicks for each visit
(Optional column) cart_products: a comma separated text value with products added to the cart sorted by the order they were added to the cart (hint: use the sequence_number)
Use the subsequent dataset to generate at least 5 insights for the Clique Bait team - bonus: prepare a single A4 infographic that the team can use for their management reporting sessions, be sure to emphasise the most important points from your findings.

Some ideas you might want to investigate further include:

Identifying users who have received impressions during each campaign period and comparing each metric with other users who did not have an impression event
Does clicking on an impression lead to higher purchase rates?
What is the uplift in purchase rate when comparing users who click on a campaign impression versus users who do not receive an impression? What if we compare them with users who just an impression but do not click?
What metrics can you use to quantify the success or failure of each campaign compared to eachother?