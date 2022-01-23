-- inspect data
SELECT 
   table_name, 
   column_name, 
   data_type 
FROM 
   information_schema.columns
WHERE 
   table_schema = 'data_bank'
ORDER BY table_name;

-- inspect  tables

SELECT
  *
FROM data_bank.customer_nodes
LIMIT
  20;

SELECT
  *
FROM
  data_bank.customer_transactions
LIMIT
  20;
  
SELECT
  *
FROM data_bank.regions
LIMIT
  20;


-- check customer_nodes table for duplicates 
WITH cte_duplicates AS(
    SELECT
      customer_id,
      region_id,
      node_id,
      start_date,
      end_date,
      COUNT(*) AS frequency
    FROM
      data_bank.customer_nodes
    GROUP BY
      customer_id,
      region_id,
      node_id,
      start_date,
      end_date
    ORDER BY
      frequency
  )
SELECT
  *
FROM
  cte_duplicates
WHERE
  frequency > 1;
  
  
-- check customer_transactions table for duplicates 
WITH cte_duplicates AS(
    SELECT
      customer_id,
      txn_date,
      txn_type,
      txn_amount,
      COUNT(*) AS frequency
    FROM
      data_bank.customer_transactions
    GROUP BY
      customer_id,
      txn_date,
      txn_type,
      txn_amount
    ORDER BY
      frequency
  )
SELECT
  *
FROM
  cte_duplicates
WHERE
  frequency > 1;


-- q1
WITH combinations AS (
SELECT DISTINCT
  node_id,
  region_id
FROM data_bank.customer_nodes
)
SELECT COUNT(*) FROM combinations;

--q2
SELECT
  region_name,
  COUNT(DISTINCT node_id)
FROM
  data_bank.customer_nodes AS nodes
JOIN data_bank.regions ON nodes.region_id = regions.region_id
GROUP BY
  region_name;

-- q3
SELECT
  region_name,
  COUNT(DISTINCT customer_id)
FROM
  data_bank.customer_nodes AS nodes
  JOIN data_bank.regions ON nodes.region_id = regions.region_id
GROUP BY
  region_name;

-- q4
  WITH nodes_cte AS(
    SELECT
      customer_id,
      node_id,
      LEAD(node_id, 1, 0) OVER(
        PARTITION BY customer_id
        ORDER BY
          end_date DESC
      ) AS previous_node_id,
      start_date,
      end_date
    FROM
      data_bank.customer_nodes
    WHERE
      end_date != '9999-12-31'
  ),
  ranked_nodes AS(
    SELECT
      customer_id,
      node_id,
      previous_node_id,
      end_date - start_date AS duration
    FROM
      nodes_cte
    WHERE
      node_id != previous_node_id
  )
SELECT
  AVG(duration)
FROM
  ranked_nodes;
-- q5
  WITH nodes_cte AS(
    SELECT
      customer_id,
      region_id,
      node_id,
      LEAD(node_id, 1, 0) OVER(
        PARTITION BY customer_id
        ORDER BY
          end_date DESC
      ) AS previous_node_id,
      start_date,
      end_date
    FROM
      data_bank.customer_nodes
    WHERE
      end_date != '9999-12-31'
  ),
  ranked_nodes AS(
    SELECT
      customer_id,
      region_id,
      node_id,
      previous_node_id,
      end_date - start_date AS duration
    FROM
      nodes_cte
    WHERE
      node_id != previous_node_id
  )
SELECT
  region_name,
  PERCENTILE_CONT(0.5) WITHIN GROUP(
    ORDER BY
      duration
  ) AS median_allocation_duration,
  PERCENTILE_CONT(0.8) WITHIN GROUP(
    ORDER BY
      duration
  ) AS perc_80th_allocation_duration,
  PERCENTILE_CONT(0.95) WITHIN GROUP(
    ORDER BY
      duration
  ) AS perc_95th_allocation_duration
FROM
  ranked_nodes
  JOIN data_bank.regions ON regions.region_id = ranked_nodes.region_id
GROUP BY
  region_name;

-- q6
SELECT
txn_type,
SUM(txn_amount) AS total_amount,
COUNT(*) AS num_txns
FROM data_bank.customer_transactions
GROUP BY txn_type;