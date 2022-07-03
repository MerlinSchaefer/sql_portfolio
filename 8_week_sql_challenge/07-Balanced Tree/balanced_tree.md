# Balanced Tree - Case Study


# Context
Balanced Tree Clothing Company prides themselves on providing an optimised range of clothing and lifestyle wear for the modern adventurer!

Danny, the CEO of this trendy fashion company has asked you to assist the team’s merchandising teams analyse their sales performance and generate a basic financial report to share with the wider business.

#  Datasets
All of the required datasets for this case study reside within the balanced_tree schema on the PostgreSQL Docker setup.

For this case study there is a total of 4 datasets

## tables

**Product Details**

balanced_tree.product_details includes all information about the entire range that Balanced Clothing sells in their store.

|product_id|price|product_name                    |category_id|segment_id|style_id|category_name|segment_name|style_name    |
|----------|-----|--------------------------------|-----------|----------|--------|-------------|------------|--------------|
|c4a632    |13   |Navy Oversized Jeans - Womens   |1          |3         |7       |Womens       |Jeans       |Navy Oversized|
|e83aa3    |32   |Black Straight Jeans - Womens   |1          |3         |8       |Womens       |Jeans       |Black Straight|
|e31d39    |10   |Cream Relaxed Jeans - Womens    |1          |3         |9       |Womens       |Jeans       |Cream Relaxed |
|d5e9a6    |23   |Khaki Suit Jacket - Womens      |1          |4         |10      |Womens       |Jacket      |Khaki Suit    |
|72f5d4    |19   |Indigo Rain Jacket - Womens     |1          |4         |11      |Womens       |Jacket      |Indigo Rain   |
|9ec847    |54   |Grey Fashion Jacket - Womens    |1          |4         |12      |Womens       |Jacket      |Grey Fashion  |
|5d267b    |40   |White Tee Shirt - Mens          |2          |5         |13      |Mens         |Shirt       |White Tee     |
|c8d436    |10   |Teal Button Up Shirt - Mens     |2          |5         |14      |Mens         |Shirt       |Teal Button Up|
|2a2353    |57   |Blue Polo Shirt - Mens          |2          |5         |15      |Mens         |Shirt       |Blue Polo     |
|f084eb    |36   |Navy Solid Socks - Mens         |2          |6         |16      |Mens         |Socks       |Navy Solid    |
|b9a74d    |17   |White Striped Socks - Mens      |2          |6         |17      |Mens         |Socks       |White Striped |
|2feb6b    |29   |Pink Fluro Polkadot Socks - Mens|2          |6         |18      |Mens         |            |              |


**Product Sales**
balanced_tree.sales contains product level information for all the transactions made for Balanced Tree including quantity, price, percentage discount, member status, a transaction ID and also the transaction timestamp.


|prod_id|qty|price                           |discount|member|txn_id|start_txn_time|
|-------|---|--------------------------------|--------|------|------|--------------|
|c4a632 |4  |13                              |17      |t     |54f307|2021-02-13 01:59:43.296|
|5d267b |4  |40                              |17      |t     |54f307|2021-02-13 01:59:43.296|
|b9a74d |4  |17                              |17      |t     |54f307|2021-02-13 01:59:43.296|
|2feb6b |2  |29                              |17      |t     |54f307|2021-02-13 01:59:43.296|
|c4a632 |5  |13                              |21      |t     |26cc98|2021-01-19 01:39:00.3456|
|e31d39 |2  |10                              |21      |t     |26cc98|2021-01-19 01:39:00.3456|
|72f5d4 |3  |19                              |21      |t     |26cc98|2021-01-19 01:39:00.3456|
|2a2353 |3  |57                              |21      |t     |26cc98|2021-01-19 01:39:00.3456|
|f084eb |3  |36                              |21      |t     |26cc98|2021-01-19 01:39:00.3456|
|c4a632 |1  |13                              |21      |f     |ef648d|2021-01-27 02:18:17.1648|

**Product Hierarcy & Product Price**

These tables are used only for recreating the balanced_tree.product_details table.




# Data Cleaning

Checking for duplicates in Sales (Products only contains 12 Items, they are all unique)
```sql
WITH duplicates_cte AS(
SELECT
  COUNT(*) AS num_occurences,
  prod_id,
  qty,
  price,
  discount,
  member,
  txn_id,
  start_txn_time
FROM
balanced_tree.sales
GROUP BY 
  prod_id,
  qty,
  price,
  discount,
  member,
  txn_id,
  start_txn_time)
SELECT
*
FROM
duplicates_cte
WHERE num_occurences > 1;
```

- no duplicates


# High Level Sales Analysis

1. What was the total quantity sold for all products?

I am first varifying that all sales have a txn_id that is not null. (I would expect only valid transactions to have a txn_id)
```sql
SELECT
COUNT(*)
FROM 
balanced_tree.sales
WHERE txn_id IS NULL;
```
- 0 NULL txn_ids

```sql
SELECT
  product_id,
  product_name,
  SUM(s.qty) AS num_sold
FROM
  balanced_tree.sales AS s
  JOIN balanced_tree.product_details AS pd ON s.prod_id = pd.product_id
GROUP BY 
product_id,
product_name;
```

|product_id|product_name                    |num_sold|
|----------|--------------------------------|--------|
|2a2353    |Blue Polo Shirt - Mens          |3819    |
|e83aa3    |Black Straight Jeans - Womens   |3786    |
|e31d39    |Cream Relaxed Jeans - Womens    |3707    |
|b9a74d    |White Striped Socks - Mens      |3655    |
|c4a632    |Navy Oversized Jeans - Womens   |3856    |
|5d267b    |White Tee Shirt - Mens          |3800    |
|c8d436    |Teal Button Up Shirt - Mens     |3646    |
|72f5d4    |Indigo Rain Jacket - Womens     |3757    |
|d5e9a6    |Khaki Suit Jacket - Womens      |3752    |
|9ec847    |Grey Fashion Jacket - Womens    |3876    |
|f084eb    |Navy Solid Socks - Mens         |3792    |
|2feb6b    |Pink Fluro Polkadot Socks - Mens|3770    |



2. What is the total generated revenue for all products before discounts?

```sql
SELECT 
SUM(qty * price) AS total_revenue
FROM 
balanced_tree.sales;
```
- 1289453

3. What was the total discount amount for all products?
```sql
WITH discount_cte AS(
    SELECT
      qty,
      CASE
        WHEN discount != 0 THEN ROUND(price * (discount :: NUMERIC / 100), 2)
        ELSE 0
      END AS discount_amount
    FROM
      balanced_tree.sales
  )
SELECT
SUM(qty*discount_amount) AS total_discount_amount
FROM
discount_cte;
```
- 156229.14

# Transaction Analysis

1. How many unique transactions were there?
```SQL
SELECT
  COUNT(DISTINCT txn_id) AS unique_txn
FROM
  balanced_tree.sales;
```
- 2500 

2. What is the average unique products purchased in each transaction?
```sql
WITH cte_transaction_products AS (
  SELECT
    txn_id,
    COUNT(DISTINCT prod_id) AS product_count  
  FROM balanced_tree.sales
  GROUP BY txn_id)
SELECT
ROUND(AVG(product_count)) AS avg_prod_per_txn
FROM cte_transaction_products;
```
- 6 unique products 

3. What are the 25th, 50th and 75th percentile values for the revenue per transaction?
```sql
WITH cte_txn_revenue AS (
    SELECT
      SUM(price*qty) txn_revenue
    FROM
      balanced_tree.sales
    GROUP BY
      txn_id
  )
SELECT
  PERCENTILE_CONT(0.25) WITHIN GROUP (
    ORDER BY
      txn_revenue
  ) AS percentile_25_revenue,
  PERCENTILE_CONT(0.5) WITHIN GROUP (
    ORDER BY
      txn_revenue
  ) AS percentile_50_revenue,
  PERCENTILE_CONT(0.75) WITHIN GROUP (
    ORDER BY
      txn_revenue
  ) AS percentile_75_revenue
FROM
  cte_txn_revenue;
```

|percentile_25_revenue|percentile_50_revenue|percentile_75_revenue |
|---------------------|---------------------|----------------------|
|         375.75         |         509.5         |         647          |



4. What is the average discount value per transaction?
```sql
WITH cte_total_discount AS(
    SELECT
      SUM(price * qty *(discount :: NUMERIC / 100)) AS total_discount
    FROM
      balanced_tree.sales
    GROUP BY
      txn_id
  )
SELECT
  ROUND(AVG(total_discount), 2) AS avg_total_discount
FROM
  cte_total_discount;
```
- 62.49 ($?)

5. What is the percentage split of all transactions for members vs non-members?

```sql
SELECT
  member,
  COUNT(DISTINCT txn_id) AS num_transactions,
  ROUND(
    COUNT(DISTINCT txn_id) /(
      SELECT
        COUNT(DISTINCT txn_id)
      FROM
        balanced_tree.sales
    ) :: NUMERIC,
    2
  ) * 100 AS perc_transactions
FROM
  balanced_tree.sales
GROUP BY
  member;
```

|member|num_transactions|perc_transactions |
|------|----------------|------------------|
|false |      995       |        40        |
| true |      1505      |        60        |





6. What is the average revenue for member transactions and non-member transactions?
```sql
WITH cte_revenue_member AS (
    SELECT
      txn_id,
      member,
      SUM(price * qty) AS total_revenue
    FROM
      balanced_tree.sales
    GROUP BY
      txn_id,
      member
  )
SELECT
  member,
  ROUND(AVG(total_revenue), 2) AS avg_revneue
FROM
  cte_revenue_member
GROUP BY
  member;
```
|   member   |avg_revneue |
|------------|------------|
|   false    |   515.04   |
|    true    |   516.27   |



# Product Analysis

1. What are the top 3 products by total revenue before discount?
```sql
SELECT
  sales.prod_id,
  pd.product_name,
  SUM(sales.qty * sales.price) AS total_revenue
FROM
  balanced_tree.sales AS sales
  JOIN balanced_tree.product_details AS pd ON sales.prod_id = pd.product_id
GROUP BY
  sales.prod_id,
  pd.product_name
ORDER BY
  total_revenue DESC
LIMIT
  3;
```

|prod_id|product_name|         total_revenue         |
|-------|------------|-------------------------------|
|2a2353 |    Blue    |   Polo Shirt - Mens 217683    |
|9ec847 |    Grey    |Fashion Jacket - Womens 209304 |
|5d267b |   White    |    Tee Shirt - Mens 152000    |




2. What is the total quantity, revenue and discount for each segment?

```sql
SELECT
  pd.segment_id,
  pd.segment_name,
  SUM(sales.qty) AS total_qty,
  SUM(sales.qty * sales.price) AS total_revenue,
  ROUND(
    SUM(
      sales.qty * sales.price * sales.discount :: NUMERIC / 100
    ),
    2
  ) AS total_discount
FROM
  balanced_tree.sales AS sales
  JOIN balanced_tree.product_details AS pd ON sales.prod_id = pd.product_id
GROUP BY
  pd.segment_id,
  pd.segment_name;
```

|segment_id|segment_name|total_qty|total_revenue|total_discount |
|----------|------------|---------|-------------|---------------|
|    4     |   Jacket   |  11385  |   366983    |   44277.46    |
|    6     |   Socks    |  11217  |   307977    |   37013.44    |
|    5     |   Shirt    |  11265  |   406143    |   49594.27    |
|    3     |   Jeans    |  11349  |   208350    |   25343.97    |



3. What is the top selling product for each segment?

- top selling is ambiguous. Would need to clarify the exact meaning. Here I am going with quantity.

```sql
WITH cte_prod_qty AS (
    SELECT
      pd.segment_id,
      pd.segment_name,
      pd.product_id,
      pd.product_name,
      SUM(sales.qty) AS total_qty,
      RANK() OVER(
        PARTITION BY pd.segment_id
        ORDER BY
          SUM(sales.qty) DESC
      ) rank_total_qty
    FROM
      balanced_tree.sales AS sales
      JOIN balanced_tree.product_details AS pd ON sales.prod_id = pd.product_id
    GROUP BY
      pd.segment_id,
      pd.segment_name,
      pd.product_id,
      pd.product_name
  )
SELECT
  *
FROM
  cte_prod_qty
WHERE rank_total_qty = 1
ORDER BY
  segment_id;
```

|segment_id|segment_name|product_id|product_name|total_qty|    rank_total_qty     |
|----------|------------|----------|------------|---------|-----------------------|
|    3     |   Jeans    |  c4a632  |    Navy    |Oversized| Jeans - Womens 3856 1 |
|    4     |   Jacket   |  9ec847  |    Grey    | Fashion |Jacket - Womens 3876 1 |
|    5     |   Shirt    |  2a2353  |    Blue    |  Polo   |  Shirt - Mens 3819 1  |
|    6     |   Socks    |  f084eb  |    Navy    |  Solid  |  Socks - Mens 3792 1  |


4. What is the total quantity, revenue and discount for each category?
```sql
SELECT
  pd.category_id,
  pd.category_name,
  SUM(sales.qty) AS total_qty,
  SUM(sales.qty * sales.price) AS total_revenue,
  ROUND(
    SUM(
      sales.qty * sales.price * sales.discount :: NUMERIC / 100
    ),
    2
  ) AS total_discount
FROM
  balanced_tree.sales AS sales
  JOIN balanced_tree.product_details AS pd ON sales.prod_id = pd.product_id
GROUP BY
  pd.category_id,
  pd.category_name
ORDER BY
  pd.category_id;
```

|category_id|category_name|total_qty|total_revenue|total_discount |
|-----------|-------------|---------|-------------|---------------|
|     1     |   Womens    |  22734  |   575333    |   69621.43    |
|     2     |    Mens     |  22482  |   714120    |   86607.71    |


5. What is the top selling product for each category?

```sql
WITH cte_prod_qty AS (
    SELECT
      pd.category_id,
      pd.category_name,
      pd.product_id,
      pd.product_name,
      SUM(sales.qty) AS total_qty,
      RANK() OVER(
        PARTITION BY pd.category_id
        ORDER BY
          SUM(sales.qty) DESC
      ) rank_total_qty
    FROM
      balanced_tree.sales AS sales
      JOIN balanced_tree.product_details AS pd ON sales.prod_id = pd.product_id
    GROUP BY
      pd.category_id,
      pd.category_name,
      pd.product_id,
      pd.product_name
  )
SELECT
  *
FROM
  cte_prod_qty
WHERE rank_total_qty = 1
ORDER BY
  category_id;
```

|category_id|category_name|product_id|product_name|total_qty|    rank_total_qty     |
|-----------|-------------|----------|------------|---------|-----------------------|
|     1     |   Womens    |  9ec847  |    Grey    | Fashion |Jacket - Womens 3876 1 |
|     2     |    Mens     |  2a2353  |    Blue    |  Polo   |  Shirt - Mens 3819 1  |


6. What is the percentage split of revenue by product for each segment?
```sql
WITH cte_segment_revenue AS(
    SELECT
      pd.segment_id,
      pd.segment_name,
      pd.product_id,
      pd.product_name,
      SUM(sales.qty * sales.price) AS revenue
    FROM
      balanced_tree.sales AS sales
      JOIN balanced_tree.product_details AS pd ON sales.prod_id = pd.product_id
    GROUP BY
      segment_id,
      segment_name,
      pd.product_id,
      pd.product_name
  )
SELECT
  segment_id,
  segment_name,
  product_id,
  product_name,
  ROUND(
    revenue :: NUMERIC / SUM(revenue) OVER(PARTITION BY segment_id) * 100,
    2
  ) AS perc_revenue
FROM
  cte_segment_revenue
ORDER BY
  segment_id;
```

|segment_id|segment_name|product_id|product_name|          perc_revenue           |
|----------|------------|----------|------------|---------------------------------|
|    3     |   Jeans    |  c4a632  |    Navy    | Oversized Jeans - Womens 24.06  |
|    3     |   Jeans    |  e83aa3  |   Black    |  Straight Jeans - Womens 58.15  |
|    3     |   Jeans    |  e31d39  |   Cream    |  Relaxed Jeans - Womens 17.79   |
|    4     |   Jacket   |  d5e9a6  |   Khaki    |   Suit Jacket - Womens 23.51    |
|    4     |   Jacket   |  9ec847  |    Grey    |  Fashion Jacket - Womens 57.03  |
|    4     |   Jacket   |  72f5d4  |   Indigo   |   Rain Jacket - Womens 19.45    |
|    5     |   Shirt    |  5d267b  |   White    |     Tee Shirt - Mens 37.43      |
|    5     |   Shirt    |  2a2353  |    Blue    |     Polo Shirt - Mens 53.6      |
|    5     |   Shirt    |  c8d436  |    Teal    |   Button Up Shirt - Mens 8.98   |
|    6     |   Socks    |  f084eb  |    Navy    |    Solid Socks - Mens 44.33     |
|    6     |   Socks    |  b9a74d  |   White    |   Striped Socks - Mens 20.18    |
|    6     |   Socks    |  2feb6b  |    Pink    |Fluro Polkadot Socks - Mens 35.5 |

7. What is the percentage split of revenue by segment for each category?

```sql
WITH cte_category_revenue AS(
    SELECT
      pd.category_id,
      pd.category_name,
      segment_id,
      segment_name,
      SUM(sales.qty * sales.price) AS revenue
    FROM
      balanced_tree.sales AS sales
      JOIN balanced_tree.product_details AS pd ON sales.prod_id = pd.product_id
    GROUP BY
      pd.category_id,
      pd.category_name,
      pd.segment_id,
      pd.segment_name
  )
SELECT
  category_id,
  category_name,
  segment_id,
  segment_name,
  ROUND(
    revenue :: NUMERIC / SUM(revenue) OVER(PARTITION BY category_id) * 100,
    2
  ) AS perc_revenue
FROM
  cte_category_revenue
ORDER BY
  category_id;
```

|category_id|category_name|segment_id|segment_name|perc_revenue |
|-----------|-------------|----------|------------|-------------|
|     1     |   Womens    |    4     |   Jacket   |    63.79    |
|     1     |   Womens    |    3     |   Jeans    |    36.21    |
|     2     |    Mens     |    5     |   Shirt    |    56.87    |
|     2     |    Mens     |    6     |   Socks    |    43.13    |


8. What is the percentage split of total revenue by category?

```sql
WITH cte_category_revenue AS(
    SELECT
      pd.category_id,
      pd.category_name,
      SUM(sales.qty * sales.price) AS revenue
    FROM
      balanced_tree.sales AS sales
      JOIN balanced_tree.product_details AS pd ON sales.prod_id = pd.product_id
    GROUP BY
      pd.category_id,
      pd.category_name
  )
SELECT
  category_id,
  category_name,
  ROUND(
    revenue :: NUMERIC / SUM(revenue) OVER() * 100,
    2
  ) AS perc_revenue
FROM
  cte_category_revenue
ORDER BY
  category_id;
```

|category_id|category_name|perc_revenue |
|-----------|-------------|-------------|
|     1     |   Womens    |    44.62    |
|     2     |    Mens     |    55.38    |



9. What is the total transaction “penetration” for each product? (hint: penetration = number of transactions where at least 1 quantity of a product was purchased divided by total number of transactions)

```sql
SELECT
  prod_id,
  product_name,
  ROUND(
    COUNT(DISTINCT txn_id) / (
      SELECT
        COUNT(DISTINCT txn_id)
      FROM
        balanced_tree.sales
    )::NUMERIC * 100,
    2
  ) AS product_penetration
FROM
  balanced_tree.sales AS sales
  JOIN balanced_tree.product_details AS pd ON pd.product_id = sales.prod_id
GROUP BY
  prod_id,
  product_name
ORDER BY product_penetration DESC;
```

|prod_id|product_name|       product_penetration        |
|-------|------------|----------------------------------|
|f084eb |    Navy    |     Solid Socks - Mens 51.24     |
|9ec847 |    Grey    |    Fashion Jacket - Womens 51    |
|c4a632 |    Navy    |  Oversized Jeans - Womens 50.96  |
|2a2353 |    Blue    |     Polo Shirt - Mens 50.72      |
|5d267b |   White    |      Tee Shirt - Mens 50.72      |
|2feb6b |    Pink    |Fluro Polkadot Socks - Mens 50.32 |
|72f5d4 |   Indigo   |     Rain Jacket - Womens 50      |
|d5e9a6 |   Khaki    |    Suit Jacket - Womens 49.88    |
|e83aa3 |   Black    |  Straight Jeans - Womens 49.84   |
|e31d39 |   Cream    |   Relaxed Jeans - Womens 49.72   |
|b9a74d |   White    |    Striped Socks - Mens 49.72    |
|c8d436 |    Teal    |   Button Up Shirt - Mens 49.68   |



10. What is the most common combination of at least 1 quantity of any 3 products in a 1 single transaction?

```sql
DROP TABLE IF EXISTS temp_prod_combinations;
CREATE TEMP TABLE temp_prod_combinations AS WITH RECURSIVE input(product) AS(
    SELECT
      product_id :: TEXT
    FROM
      balanced_tree.product_details
  ),
  cte_prod_combinations AS(
    SELECT
      ARRAY [product] as combination,
      product,
      1 AS product_counter
    FROM
      input
    UNION
    SELECT
      ARRAY_APPEND(cte_prod_combinations.combination, input.product),
      input.product,
      product_counter + 1
    FROM
      cte_prod_combinations
      JOIN input ON input.product > cte_prod_combinations.product
    WHERE
      cte_prod_combinations.product_counter <= 2
  )
SELECT
  *
FROM
  cte_prod_combinations
WHERE
  product_counter >= 3;
SELECT
  *
FROM
  temp_prod_combinations;
WITH cte_transaction_products AS(
    SELECT
      txn_id,
      ARRAY_AGG(
        prod_id :: TEXT
        ORDER BY
          prod_id
      ) AS products
    FROM
      balanced_tree.sales
    GROUP BY
      txn_id
  ),
  cte_transaction_combinations AS(
    SELECT
      txn_id,
      products,
      combination
    FROM
      cte_transaction_products
      CROSS JOIN temp_prod_combinations
    WHERE
      combination <@ products
  ),
  cte_ranked_combinations AS (
    SELECT
      combination,
      COUNT(DISTINCT txn_id) AS count_combination,
      RANK() OVER(
        ORDER BY
          COUNT(DISTINCT txn_id) DESC
      ) AS combination_rank,
      ROW_NUMBER() OVER(
        ORDER BY
          COUNT(DISTINCT txn_id) DESC
      ) AS combination_rownumber
    FROM
      cte_transaction_combinations
    GROUP BY
      combination
    ORDER BY
      count_combination DESC
  ),
  cte_most_common_combination_txn AS(
    SELECT
      cte_transaction_combinations.txn_id,
      cte_ranked_combinations.combination_rownumber,
      UNNEST(cte_ranked_combinations.combination) AS prod_id
    FROM
      cte_transaction_combinations
      INNER JOIN cte_ranked_combinations ON cte_transaction_combinations.combination = cte_ranked_combinations.combination
    WHERE
      cte_ranked_combinations.combination_rank = 1
  )
SELECT
  product_details.product_id,
  product_details.product_name,
  COUNT(DISTINCT sales.txn_id) AS combo_transaction_count,
  SUM(sales.qty) AS total_qty,
  SUM(sales.qty * sales.price) AS total_revenue,
  ROUND(
    SUM(
      sales.qty * sales.price * sales.discount :: NUMERIC / 100
    ),
    2
  ) AS total_discount,
  SUM(sales.qty * sales.price) - ROUND(
    SUM(
      sales.qty * sales.price * sales.discount :: NUMERIC / 100
    ),
    2
  ) AS net_revenue
FROM
  balanced_tree.sales
  JOIN cte_most_common_combination_txn ON cte_most_common_combination_txn.prod_id = sales.prod_id
  AND cte_most_common_combination_txn.txn_id = sales.txn_id
  JOIN balanced_tree.product_details ON product_details.product_id = sales.prod_id
GROUP BY
  product_id,
  product_name;
```
|product_id|product_name|combo_transaction_count|total_qty|total_revenue|total_discount|           net_revenue            |
|----------|------------|-----------------------|---------|-------------|--------------|----------------------------------|
|  5d267b  |   White    |          Tee          |  Shirt  |      -      |     Mens     |  352 1007 40280 5049.2 35230.8   |
|  9ec847  |    Grey    |        Fashion        | Jacket  |      -      |    Womens    | 352 1062 57348 6997.86 50350.14  |
|  c8d436  |    Teal    |        Button         |   Up    |    Shirt    |      -       |Mens 352 1054 10540 1325.3 9214.7 |

