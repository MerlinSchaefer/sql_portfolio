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


--q7
  WITH deposit_by_customer AS(
    SELECT
      customer_id,
      SUM(txn_amount) AS total_amount_deposits,
      COUNT(*) AS num_deposits
    FROM
      data_bank.customer_transactions
    WHERE
      txn_type = 'deposit'
    GROUP BY
      customer_id
  )
SELECT
  ROUND(SUM(total_amount_deposits) / SUM(num_deposits)) AS avg_total_deposit,
  ROUND(AVG(num_deposits)) AS avg_num_deposits
FROM
  deposit_by_customer;


-- q8
WITH cte_month AS(
    SELECT
      DATE_TRUNC('MONTH', txn_date) AS txn_month,
      customer_id,
      SUM(
        CASE
          WHEN txn_type = 'deposit' THEN 1
          ELSE 0
        END
      ) AS num_deposits,
      SUM(
        CASE
          WHEN txn_type = 'withdrawal' THEN 1
          ELSE 0
        END
      ) AS num_withdrawals,
      SUM(
        CASE
          WHEN txn_type = 'purchase' THEN 1
          ELSE 0
        END
      ) AS num_purchases
    FROM
      data_bank.customer_transactions
    GROUP BY
      txn_month,
      customer_id
  )
SELECT
  txn_month,
  COUNT(customer_id)
FROM
  cte_month
WHERE
  num_deposits > 1
  AND (
    num_withdrawals >= 1
    OR num_purchases >= 1
  )
GROUP BY
  txn_month;

--q9
WITH cte_balances AS(
    SELECT
      customer_id,
      DATE_TRUNC('MONTH', txn_date) AS txn_month,
      SUM(
        CASE
          WHEN txn_type = 'deposit' THEN txn_amount
          ELSE txn_amount * -1
        END
      ) AS end_of_month_balance
    FROM
      data_bank.customer_transactions
    GROUP BY
      customer_id,
      txn_month
    ORDER BY
      customer_id,
      txn_month
  ),
  cte_months AS(
    SELECT
      DISTINCT customer_id,
      (
        '2020-01-01' :: DATE + GENERATE_SERIES(0, 3) * INTERVAL '1 MONTH'
      ) :: DATE AS txn_month
    FROM
      data_bank.customer_transactions
  )
SELECT
  cte_months.customer_id,
  cte_months.txn_month,
  COALESCE(cte_balances.end_of_month_balance, 0) AS balance_contribution,
  SUM(cte_balances.end_of_month_balance) OVER (
    PARTITION BY cte_months.customer_id
    ORDER BY
      cte_months.txn_month 
      ROWS BETWEEN UNBOUNDED PRECEDING
      AND CURRENT ROW
  ) AS ending_balance
FROM
  cte_months
  LEFT JOIN cte_balances ON cte_months.customer_id = cte_balances.customer_id
  AND cte_months.txn_month = cte_balances.txn_month
ORDER BY
  cte_months.customer_id;

-- q10
  WITH cte_balances AS(
    SELECT
      customer_id,
      DATE_TRUNC('MONTH', txn_date) AS txn_month,
      SUM(
        CASE
          WHEN txn_type = 'deposit' THEN txn_amount
          ELSE txn_amount * -1
        END
      ) AS end_of_month_balance
    FROM
      data_bank.customer_transactions
    GROUP BY
      customer_id,
      txn_month
    ORDER BY
      customer_id,
      txn_month
  ),
  cte_months AS(
    SELECT
      DISTINCT customer_id,
      (
        '2020-01-01' :: DATE + GENERATE_SERIES(0, 3) * INTERVAL '1 MONTH'
      ) :: DATE AS txn_month
    FROM
      data_bank.customer_transactions
  ),
  monthly_balances AS(
    SELECT
      cte_months.customer_id,
      cte_months.txn_month,
      ROW_NUMBER() OVER(
        PARTITION BY cte_months.customer_id
        ORDER BY
          cte_months.txn_month
      ) AS month_number,
      SUM(cte_balances.end_of_month_balance) OVER (
        PARTITION BY cte_months.customer_id
        ORDER BY
          cte_months.txn_month ROWS BETWEEN UNBOUNDED PRECEDING
          AND CURRENT ROW
      ) AS ending_balance
    FROM
      cte_months
      LEFT JOIN cte_balances ON cte_months.customer_id = cte_balances.customer_id
      AND cte_months.txn_month = cte_balances.txn_month
    ORDER BY
      cte_months.customer_id
  ),
  first_months AS(
    SELECT
      customer_id,
      txn_month,
      ending_balance,
      LEAD(ending_balance) OVER(
        PARTITION BY customer_id
        ORDER BY
          month_number
      ) AS following_ending_balance,
      month_number
    FROM
      monthly_balances
    WHERE
      month_number <= 2
  ),
  cte_exploration AS (
    SELECT
      customer_id,
      ending_balance,
      following_ending_balance,
      CASE
        WHEN ending_balance < 0 THEN 1
        ELSE 0
      END AS neg_first_month,
      CASE
        WHEN ending_balance > 0 THEN 1
        ELSE 0
      END AS pos_first_month,
      CASE
        WHEN ending_balance > 0
        AND ending_balance *1.05 < following_ending_balance THEN 1
        ELSE 0
      END AS pos_first_over_5_perc_increase,
      CASE
        WHEN ending_balance > 0
        AND ending_balance  - (ending_balance * 0.05) > following_ending_balance THEN 1
        ELSE 0
      END AS pos_first_over_5_perc_reduction,
      CASE
        WHEN ending_balance > 0
        AND following_ending_balance < 0 THEN 1
        ELSE 0
      END AS pos_first_neg_second
    FROM
      first_months
    WHERE
      month_number = 1
  )
SELECT
  ROUND(100 * SUM(neg_first_month) / COUNT(*) :: NUMERIC, 2) AS neg_first_month_perc,
  ROUND(100 * SUM(pos_first_month) / COUNT(*) :: NUMERIC, 2) AS pos_first_month_perc,
ROUND(
  100 * SUM(pos_first_over_5_perc_increase) / COUNT(*) :: NUMERIC,
  2
) AS pos_first_over_5_perc_increase_perc,
ROUND(
  100 * SUM(pos_first_over_5_perc_reduction) / COUNT(*) :: NUMERIC,
  2
) AS pos_first_over_5_perc_reduction_perc,
ROUND(
  100 * SUM(pos_first_neg_second) / COUNT(*) :: NUMERIC,
  2
) AS pos_first_neg_second_perc
FROM
  cte_exploration;