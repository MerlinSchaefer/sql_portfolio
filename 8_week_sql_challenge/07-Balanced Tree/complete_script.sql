-- inspect data
SELECT 
   table_name, 
   column_name, 
   data_type 
FROM 
   information_schema.columns
WHERE 
   table_schema = 'balanced_tree'
ORDER BY table_name;

SELECT
  *
FROM
  balanced_tree.product_details
LIMIT
  10;

SELECT
  COUNT(*)
FROM
  balanced_tree.product_details;

SELECT
  *
FROM
  balanced_tree.sales
LIMIT
  10;

  SELECT
  COUNT(*)
FROM
  balanced_tree.sales;

-- check for duplicates
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

-- q1.1
-- varifying txn
SELECT
COUNT(*)
FROM 
balanced_tree.sales
WHERE txn_id IS NULL;

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

 -- q1.2
SELECT 
SUM(qty * price) AS total_revenue
FROM 
balanced_tree.sales;

-- q1.3
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

-- q2.1
SELECT
  COUNT(DISTINCT txn_id) AS unique_txn
FROM
  balanced_tree.sales;


-- q2.2  
WITH cte_transaction_products AS (
  SELECT
    txn_id,
    COUNT(DISTINCT prod_id) AS product_count  
  FROM balanced_tree.sales
  GROUP BY txn_id)
SELECT
ROUND(AVG(product_count)) AS avg_prod_per_txn
FROM cte_transaction_products;


-- q2.3
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

-- q2.4
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

-- q2.5

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

-- q2.6

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