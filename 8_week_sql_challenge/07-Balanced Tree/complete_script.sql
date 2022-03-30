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