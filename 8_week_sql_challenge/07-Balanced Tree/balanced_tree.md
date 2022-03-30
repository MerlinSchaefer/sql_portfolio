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