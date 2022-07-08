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

-- q3.1
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

-- q3.2
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

-- q3.3
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

-- q3.4
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

  -- q3.5
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
-- q3.6
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

-- q3.7
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

-- q3.8
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

-- q3.9
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

-- q.10
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