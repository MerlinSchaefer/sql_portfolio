# Danny's Diner - Case Study


# Context
Danny seriously loves Japanese food so in the beginning of 2021, he decides to embark upon a risky venture and opens up a cute little restaurant that sells his 3 favourite foods: sushi, curry and ramen.

Danny’s Diner is in need of your assistance to help the restaurant stay afloat - the restaurant has captured some very basic data from their few months of operation but have no idea how to use their data to help them run the business.

# Problem Statement
Danny wants to use the data to answer a few simple questions about his customers, especially about their visiting patterns, how much money they’ve spent and also which menu items are their favourite. Having this deeper connection with his customers will help him deliver a better and more personalised experience for his loyal customers.

He plans on using these insights to help him decide whether he should expand the existing customer loyalty program - additionally he needs help to generate some basic datasets so his team can easily inspect the data without needing to use SQL.

#  Datasets
Danny has shared with you 3 key datasets for this case study:

`sales` : The sales table captures all customer_id level purchases with an corresponding order_date and product_id information for when and what menu items were ordered.

| customer_id | order_date | product_id |
|-------------|------------|------------|
| A           | 2021-01-01 | 1          |
| A           | 2021-01-01 | 2          |
| ...         | ...        | ...        |


`menu` : The menu table maps the product_id to the actual product_name and price of each menu item.

| product_id | product_name | price |
|------------|--------------|-------|
| 1          | sushi        | 10    |
| 2          | curry        | 15    |
| 3          | ramen        | 12    |

`members` : The final members table captures the join_date when a customer_id joined the beta version of the Danny’s Diner loyalty program.

| customer_id | join_date  |
|-------------|------------|
| A           | 2021-01-07 |
| B           | 2021-01-09 |

All of the required datasets for this case study reside within the dannys_diner schema on the PostgreSQL Docker setup.


# Case Study Questions

## Exploration
```sql
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
```
- there are two duplicates Customer A ordering product_id 3 on 2021-01-11 and Customer C ordering product_id 3 on 2021-01-01. This is however possible as a customer may place an order with the same product twice at a given date.

I am first creating a complete table (as a temp table) as requested in question 11 (+ join_date column). This will serve as a basis for answering some questions. All questions could be answered without this table however as the dataset is small this complete table will avoid a couple of join operations and not take up much memory. It may thus provide a more readable and equally or more efficient solution.

```sql
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
```

1. What is the total amount each customer spent at the restaurant?
```sql
SELECT
  customer_id,
  SUM(price) AS total_spent
FROM
  diner_data_complete
GROUP BY
  customer_id
ORDER BY
  customer_id;
```

|customer_id|total_spent|
|-----------|---|
|A          |76 |
|B          |74 |
|C          |36 |

2. How many days has each customer visited the restaurant?
```sql
SELECT
  customer_id,
  COUNT(DISTINCT order_date) As num_days
FROM
  diner_data_complete
GROUP BY
  customer_id
ORDER BY
  customer_id;
```
|customer_id|num_days|
|-----------|-----|
|A          |4    |
|B          |6    |
|C          |2    |

3. What was the first item from the menu purchased by each customer?
```sql
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
```
|customer_id|product_name|
|-----------|------------|
|A          |curry       |
|B          |curry       |
|C          |ramen       |

4. What is the most purchased item on the menu and how many times was it purchased by all customers?
```sql
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
```
|product_name|num_purchases|
|-----------|------------|
|ramen      |8           |

5. Which item was the most popular for each customer?
```sql
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
```
|customer_id|product_name|
|-----------|------------|
|A          |ramen       |
|B          |sushi       |
|B          |ramen       |
|B          |curry       |
|C          |ramen       |


6. Which item was purchased first by the customer after they became a member?
```sql
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
```
|customer_id|product_name|
|-----------|------------|
|A          |curry       |
|B          |sushi       |

7. Which item was purchased just before the customer became a member?
- Note: there are shorter ways to solve this but these rely on info we only have because the table is so small, (e.g. C is never a member) this query should work universally if the data grows

```sql
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
```
|customer_id|last_nonmember_purchase|
|-----------|------------|
|A          |sushi       |
|B          |sushi       |



8. What is the total items and amount spent for each member before they became a member?
```sql
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
```
|customer_id|total_amount|total_items|
|-----------|---|-----|
|A          |25 |2    |
|B          |40 |3    |

9. If each $1 spent equates to 10 points and sushi has a 2x points multiplier - how many points would each customer have?
```sql
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
```
|customer_id|total_points|
|-----------|------------|
|A          |860         |
|B          |940         |
|C          |360         |


10. In the first week after a customer joins the program (including their join date) they earn 2x points on all items, not just sushi - how many points do customer A and B have at the end of January?

```sql
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
```
|customer_id|total_points|
|-----------|------------|
|A          |1370        |
|B          |820         |


11. Recreate the following table output using the available data:

| customer_id | order_date | product_name | price | member |
|-------------|------------|--------------|-------|--------|
| A           | 2021-01-01 | curry        | 15    | N      |
| A           | 2021-01-01 | sushi        | 10    | N      |
| A           | 2021-01-07 | curry        | 15    | Y      |
| A           | 2021-01-10 | ramen        | 12    | Y      |
| A           | 2021-01-11 | ramen        | 12    | Y      |
| A           | 2021-01-11 | ramen        | 12    | Y      |
| B           | 2021-01-01 | curry        | 15    | N      |
| ...         | ...        | ...          | ...   | ...    |

```sql
-- see beginning of case study for table creation (exclude join_date)
SELECT 
    customer_id,
    order_date,
    product_name,
    price,
    member
FROM diner_data_complete;
```

|customer_id|order_date|product_name|price|member|
|-----------|----------|------------|-----|------|
|A          |2021-01-01T00:00:00.000Z|curry       |15   |N     |
|A          |2021-01-01T00:00:00.000Z|sushi       |10   |N     |
|A          |2021-01-07T00:00:00.000Z|curry       |15   |Y     |
|A          |2021-01-10T00:00:00.000Z|ramen       |12   |Y     |
|A          |2021-01-11T00:00:00.000Z|ramen       |12   |Y     |
|A          |2021-01-11T00:00:00.000Z|ramen       |12   |Y     |
|B          |2021-01-01T00:00:00.000Z|curry       |15   |N     |
|B          |2021-01-02T00:00:00.000Z|curry       |15   |N     |
|B          |2021-01-04T00:00:00.000Z|sushi       |10   |N     |
|B          |2021-01-11T00:00:00.000Z|sushi       |10   |Y     |
|B          |2021-01-16T00:00:00.000Z|ramen       |12   |Y     |
|B          |2021-02-01T00:00:00.000Z|ramen       |12   |Y     |
|C          |2021-01-01T00:00:00.000Z|ramen       |12   |N     |
|C          |2021-01-01T00:00:00.000Z|ramen       |12   |N     |
|C          |2021-01-07T00:00:00.000Z|ramen       |12   |N     |


12. Danny also requires further information about the ranking of customer products, but he purposely does not need the ranking for non-member purchases so he expects null ranking values for the records when customers are not yet part of the loyalty program.

```sql
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
```
|customer_id|order_date|product_name|price|member|ranking|
|-----------|----------|------------|-----|------|-------|
|A          |2021-01-01|curry       |15   |N     |       |
|A          |2021-01-01|sushi       |10   |N     |       |
|A          |2021-01-07|curry       |15   |N     |       |
|A          |2021-01-10|ramen       |12   |Y     |1      |
|A          |2021-01-11|ramen       |12   |Y     |2      |
|A          |2021-01-11|ramen       |12   |Y     |2      |
|B          |2021-01-01|curry       |15   |N     |       |
|B          |2021-01-02|curry       |15   |N     |       |
|B          |2021-01-04|sushi       |10   |N     |       |
|B          |2021-01-11|sushi       |10   |Y     |1      |
|B          |2021-01-16|ramen       |12   |Y     |2      |
|B          |2021-02-01|ramen       |12   |Y     |3      |
|C          |2021-01-01|ramen       |12   |N     |       |
|C          |2021-01-01|ramen       |12   |N     |       |
|C          |2021-01-07|ramen       |12   |N     |       |
