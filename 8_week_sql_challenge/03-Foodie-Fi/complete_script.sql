-- inspect data
SELECT 
   table_name, 
   column_name, 
   data_type 
FROM 
   information_schema.columns
WHERE 
   table_schema = 'foodie_fi'
ORDER BY table_name;

-- inspect  tables

SELECT
  *
FROM foodie_fi.plans;

SELECT
  *
FROM
  foodie_fi.subscriptions
LIMIT
  20;


-- check subscription table for duplicates

WITH cte_duplicates AS(
    SELECT
      customer_id,
      plan_id,
      start_date,
      COUNT(*) AS frequency
    FROM
      foodie_fi.subscriptions
    GROUP BY
      customer_id,
      plan_id,
      start_date
    ORDER BY
      frequency
  )
SELECT
  *
FROM
  cte_duplicates
WHERE
  frequency > 1;


SELECT
  order_id,
  customer_id,
  pizza_id,
  exclusions,
  extras,
  order_time,
  COUNT(*) AS frequency
FROM pizza_runner.customer_orders
GROUP BY
  order_id,
  customer_id,
  pizza_id,
  exclusions,
  extras,
  order_time
ORDER BY frequency DESC;

SELECT
  COUNT(DISTINCT customer_id) AS customers
FROM
  foodie_fi.subscriptions;
SELECT
  DATE_TRUNC('MONTH', start_date) :: DATE AS month,
  COUNT(*) AS num_trial_signups
FROM
  foodie_fi.subscriptions
WHERE
  plan_id = 0
GROUP BY
  month
ORDER BY
  month;
SELECT
  plan_name,
  COUNT(*) num_occured
FROM
  foodie_fi.subscriptions AS subs
  JOIN foodie_fi.plans ON subs.plan_id = plans.plan_id
WHERE
  EXTRACT(
    'YEAR'
    FROM
      start_date
  ) > 2020
GROUP BY
  plan_name
ORDER BY
  num_occured;
WITH cte_churn AS(
    SELECT
      customer_id,
      CASE
        WHEN plan_name = 'churn' THEN 1
        ELSE 0
      END AS customer_churn
    FROM
      foodie_fi.subscriptions AS subs
      JOIN foodie_fi.plans ON subs.plan_id = plans.plan_id
  )
SELECT
  SUM(customer_churn) AS num_churned,
  COUNT(DISTINCT customer_id) AS num_total,
  ROUND(
    100 * (
      SUM(customer_churn) / COUNT(DISTINCT customer_id) :: NUMERIC
    ),
    1
  ) AS perc_churned
FROM
  cte_churn;
WITH cte_previous_plan AS (
    SELECT
      customer_id,
      plan_name,
      LAG(plan_name) OVER(
        PARTITION BY customer_id
        ORDER BY
          start_date
      ) AS previous_plan,
      start_date
    FROM
      foodie_fi.subscriptions AS subs
      JOIN foodie_fi.plans ON subs.plan_id = plans.plan_id
  )
SELECT
  SUM(
    CASE
      WHEN plan_name = 'churn'
      AND previous_plan = 'trial' THEN 1
      ELSE 0
    END
  ) AS num_churned_after_trial,
  ROUND(
    100 * SUM(
      CASE
        WHEN plan_name = 'churn'
        AND previous_plan = 'trial' THEN 1
        ELSE 0
      END
    ) / COUNT(DISTINCT customer_id) :: NUMERIC,
    1
  ) AS perc_churn_trial
FROM
  cte_previous_plan;
WITH cte_previous_plan AS (
    SELECT
      customer_id,
      plan_name,
      LAG(plan_name) OVER(
        PARTITION BY customer_id
        ORDER BY
          start_date
      ) AS previous_plan,
      start_date
    FROM
      foodie_fi.subscriptions AS subs
      JOIN foodie_fi.plans ON subs.plan_id = plans.plan_id
  )
SELECT
  plan_name,
  COUNT(DISTINCT customer_id) AS num_customers,
  ROUND(
    100 * COUNT(DISTINCT customer_id) :: NUMERIC / SUM(COUNT(customer_id)) OVER(),
    1
  ) AS perc_customers
FROM
  cte_previous_plan
WHERE
  previous_plan = 'trial'
GROUP BY
  plan_name;
WITH ranked_subscriptions_2020 AS (
    SELECT
      customer_id,
      subs.plan_id,
      plan_name,
      start_date,
      ROW_NUMBER() OVER(
        PARTITION BY customer_id
        ORDER BY
          start_date DESC
      ) AS latest_subscription,
      price
    FROM
      foodie_fi.subscriptions AS subs
      JOIN foodie_fi.plans ON subs.plan_id = plans.plan_id
    WHERE
      start_date < '2020-12-31'
  )
SELECT
  plan_name,
  COUNT(*) num_customers,
  ROUND(
    100 * COUNT(*) :: NUMERIC / SUM(COUNT(*)) OVER(),
    1
  ) AS perc_customers
FROM
  ranked_subscriptions_2020
WHERE
  latest_subscription = 1
GROUP BY
  plan_name
ORDER BY
  num_customers;
SELECT
  COUNT(DISTINCT customer_id)
FROM
  foodie_fi.subscriptions AS subs
  JOIN foodie_fi.plans ON subs.plan_id = plans.plan_id
WHERE
  plan_name = 'pro annual'
  AND start_date <= '2020-12-31';
WITH cte_join_date AS(
    SELECT
      customer_id,
      subs.plan_id,
      plan_name,
      start_date,
      MIN(start_date) OVER(PARTITION BY customer_id) AS join_date
    FROM
      foodie_fi.subscriptions AS subs
      JOIN foodie_fi.plans ON subs.plan_id = plans.plan_id
  )
SELECT
  ROUND(AVG(start_date - join_date)) AS avg_days_to_annual
FROM
  cte_join_date
WHERE
  plan_name = 'pro annual';
WITH cte_join_date AS(
    SELECT
      customer_id,
      subs.plan_id,
      plan_name,
      start_date,
      MIN(start_date) OVER(PARTITION BY customer_id) AS join_date
    FROM
      foodie_fi.subscriptions AS subs
      JOIN foodie_fi.plans ON subs.plan_id = plans.plan_id
  ),
  cte_upgrade_days AS (
    SELECT
      CASE
        WHEN start_date - join_date <= 30 THEN '0-30 days'
        WHEN start_date - join_date <= 60 THEN '31-60 days'
        WHEN start_date - join_date <= 90 THEN '61-90 days'
        ELSE '>90 days'
      END AS days_to_upgrade
    FROM
      cte_join_date
    WHERE
      plan_name = 'pro annual'
  )
SELECT
  days_to_upgrade,
  COUNT(*)
FROM
  cte_upgrade_days
GROUP BY
  days_to_upgrade;
WITH cte_previous_plan AS (
    SELECT
      customer_id,
      plan_name,
      LAG(plan_name) OVER(
        PARTITION BY customer_id
        ORDER BY
          start_date DESC
      ) AS previous_plan,
      start_date
    FROM
      foodie_fi.subscriptions AS subs
      JOIN foodie_fi.plans ON subs.plan_id = plans.plan_id
    WHERE
      DATE_PART('year', start_date) = 2020
  )
SELECT
  COUNT(*)
FROM
  cte_previous_plan
WHERE
  plan_name = 'basic monthly'
  AND previous_plan = 'pro annual';

DROP TABLE IF EXISTS pricing;
CREATE TEMP TABLE pricing AS 
-- first generate the lead plans as above
WITH lead_plans AS (
SELECT
  customer_id,
  plan_id,
  start_date,
  LEAD(plan_id) OVER (
      PARTITION BY customer_id
      ORDER BY start_date
    ) AS lead_plan_id,
  LEAD(start_date) OVER (
      PARTITION BY customer_id
      ORDER BY start_date
    ) AS lead_start_date
FROM foodie_fi.subscriptions
WHERE DATE_PART('year', start_date) = 2020
AND plan_id != 0
),
-- case 1: non churn monthly customers
case_1 AS (
SELECT
  customer_id,
  plan_id,
  start_date,
  DATE_PART('mon', AGE('2020-12-31'::DATE, start_date))::INTEGER AS month_diff
FROM lead_plans
WHERE lead_plan_id is null
-- not churn and annual customers
AND plan_id NOT IN (3, 4)
),
-- generate a series to add the months to each start_date
case_1_payments AS (
  SELECT
    customer_id,
    plan_id,
    (start_date + GENERATE_SERIES(0, month_diff) * INTERVAL '1 month')::DATE AS start_date
  FROM case_1
),
-- case 2: churn customers
case_2 AS (
  SELECT
    customer_id,
    plan_id,
    start_date,
    DATE_PART('mon', AGE(lead_start_date - 1, start_date))::INTEGER AS month_diff
  FROM lead_plans
  -- churn accounts only
  WHERE lead_plan_id = 4 
),
case_2_payments AS (
  SELECT
    customer_id,
    plan_id,
    (start_date + GENERATE_SERIES(0, month_diff) * INTERVAL '1 month')::DATE AS start_date
  from case_2
),
-- case 3: customers who move from basic to pro plans
case_3 AS (
  SELECT
    customer_id,
    plan_id,
    start_date,
    DATE_PART('mon', AGE(lead_start_date - 1, start_date))::INTEGER AS month_diff
  FROM lead_plans
  WHERE plan_id = 1 AND lead_plan_id IN (2, 3)
),
case_3_payments AS (
  SELECT
    customer_id,
    plan_id,
    (start_date + GENERATE_SERIES(0, month_diff) * INTERVAL '1 month')::DATE AS start_date
  from case_3
),
-- case 4: pro monthly customers who move up to annual plans
case_4 AS (
  SELECT
    customer_id,
    plan_id,
    start_date,
    DATE_PART('mon', AGE(lead_start_date - 1, start_date))::INTEGER AS month_diff
  FROM lead_plans
  WHERE plan_id = 2 AND lead_plan_id = 3
),
case_4_payments AS (
  SELECT
    customer_id,
    plan_id,
    (start_date + GENERATE_SERIES(0, month_diff) * INTERVAL '1 month')::DATE AS start_date
  from case_4
),
-- case 5: annual pro payments
case_5_payments AS (
  SELECT
    customer_id,
    plan_id,
    start_date
  FROM lead_plans
  WHERE plan_id = 3
),
-- union all where we union all parts
union_output AS (
  SELECT * FROM case_1_payments
  UNION ALL 
  SELECT * FROM case_2_payments
  UNION ALL 
  SELECT * FROM case_3_payments
  UNION  ALL 
  SELECT * FROM case_4_payments
  UNION ALL 
  SELECT * FROM case_5_payments
)
SELECT
  customer_id,
  plans.plan_id,
  plans.plan_name,
  start_date AS payment_date,
  -- price deductions are applied here
  CASE
    WHEN union_output.plan_id IN (2, 3) AND
      LAG(union_output.plan_id) OVER w = 1
    THEN plans.price - 9.90
    ELSE plans.price
    END AS amount,
  RANK() OVER w AS payment_order
FROM union_output
INNER JOIN foodie_fi.plans
  ON union_output.plan_id = plans.plan_id
-- where filter for outputs for testing
-- WHERE customer_id IN (1, 2, 7, 11, 13, 15, 16, 18, 19, 25, 39)
WINDOW w AS (
  PARTITION BY customer_id
  ORDER BY start_date
);