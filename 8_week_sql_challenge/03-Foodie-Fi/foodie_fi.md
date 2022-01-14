# Foodie-Fi - Case Study


# Context
Subscription based businesses are super popular and Danny realised that there was a large gap in the market - he wanted to create a new streaming service that only had food related content - something like Netflix but with only cooking shows!

Danny finds a few smart friends to launch his new startup Foodie-Fi in 2020 and started selling monthly and annual subscriptions, giving their customers unlimited on-demand access to exclusive food videos from around the world!

Danny created Foodie-Fi with a data driven mindset and wanted to ensure all future investment decisions and new features were decided using data. This case study focuses on using subscription style digital data to answer important business questions.


#  Datasets
Danny has shared the data design for Foodie-Fi and also short descriptions on each of the database tables - our case study focuses on only 2 tables but there will be a challenge to create a new table for the Foodie-Fi team.

All of the required datasets for this case study reside within the foodie_fi schema on the PostgreSQL Docker setup.



`plans` table

Customers can choose with which plans to join Foodie-Fi when they first sign up.

Basic plan customers have limited access and can only stream their videos and its only available monthly at $9.90

Pro plan customers have no watch time limits and are able to download videos for offline viewing. Pro plans start at $19.90 a month or $199 for an annual subscription.

Customers can sign up to an initial 7 day free trial that will automatically continue with the pro monthly subscription plan unless they cancel, downgrade to basic or upgrade to an annual pro plan at any point during the trial.

When customers cancel their Foodie-Fi service - they will have a churn plan record with a null price but their plan will continue until the end of the billing period.

| plan_id | plan_name     | price |
|---------|---------------|-------|
| 0       | trial         | 0     |
| 1       | basic monthly | 9.90  |
| 2       | pro monthly   | 19.90 |
| 3       | pro annual    | 199   |
| 4       | churn         | null  |


`subscriptions` table

Customer subscriptions show the exact date where their specific plan_id starts.

If customers downgrade from a pro plan or cancel their subscription - the higher plan will remain in place until the period is over - the start_date in the subscriptions table will reflect the date that the actual plan changes.

When customers upgrade their account from a basic plan to a pro or annual pro plan - the higher plan will take effect straightaway.

When customers churn - they will keep their access until the end of their current billing period but the start_date will be technically the day they decided to cancel their service.

| customer_id | plan_id | start_date |
|-------------|---------|------------|
| 1           | 0       | 2020-08-01 |
| 1           | 1       | 2020-08-08 |
| 2           | 0       | 2020-09-20 |
| 2           | 3       | 2020-09-27 |
| 11          | 0       | 2020-11-19 |
| 11          | 4       | 2020-11-26 |
| 13          | 0       | 2020-12-15 |
| 13          | 1       | 2020-12-22 |
| ...         | ...     | ...        |


# Case Study Questions
The questions of this case study are broken up by area of focus: 
* Data Analysis Questions 
* Payment Question


Before starting with the SQL queries however - I want to investigate the data
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
   table_schema = 'foodie_fi'
ORDER BY table_name;

-- inspect tables
SELECT
  *
FROM
  foodie_fi.plans;
SELECT
  *
FROM
  foodie_fi.subscriptions
LIMIT
  20;

-- check subscriptions table for duplicates
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

```

- there are no duplicates



## Data Analytics
How many customers has Foodie-Fi ever had?
```sql
SELECT
  COUNT(DISTINCT customer_id) AS customers
FROM
  foodie_fi.subscriptions;
```
- 1000

What is the monthly distribution of trial plan start_date values for our dataset - use the start of the month as the group by value
```sql
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
```
|month                   |num_trial_signups|
|------------------------|-----------------|
|2020-01-01T00:00:00.000Z|88               |
|2020-02-01T00:00:00.000Z|68               |
|2020-03-01T00:00:00.000Z|94               |
|2020-04-01T00:00:00.000Z|81               |
|2020-05-01T00:00:00.000Z|88               |
|2020-06-01T00:00:00.000Z|79               |
|2020-07-01T00:00:00.000Z|89               |
|2020-08-01T00:00:00.000Z|88               |
|2020-09-01T00:00:00.000Z|87               |
|2020-10-01T00:00:00.000Z|79               |
|2020-11-01T00:00:00.000Z|75               |
|2020-12-01T00:00:00.000Z|84               |

What plan start_date values occur after the year 2020 for our dataset? Show the breakdown by count of events for each plan_name
```sql
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
  num_occured
;
```
|plan_name               |num_occured|
|------------------------|-----------|
|basic monthly           |8          |
|pro monthly             |60         |
|pro annual              |63         |
|churn                   |71         |

What is the customer count and percentage of customers who have churned rounded to 1 decimal place?
```sql
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
```
- 307 churned , 30.7% churn_rate

How many customers have churned straight after their initial free trial - what percentage is this rounded to the nearest whole number?
```sql
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
```
- 92 churned after trial , 9.2%

What is the number and percentage of customer plans after their initial free trial?
```sql
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
```
|plan_name               |num_customers|perc_customers|
|------------------------|-------------|--------------|
|basic monthly           |546          |54.6          |
|churn                   |92           |9.2           |
|pro annual              |37           |3.7           |
|pro monthly             |325          |32.5          |


What is the customer count and percentage breakdown of all 5 plan_name values at 2020-12-31?
```sql
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
  ROUND(100 * COUNT(*) :: NUMERIC / SUM(COUNT(*)) OVER(), 1) AS perc_customers
FROM
  ranked_subscriptions_2020
WHERE
  latest_subscription = 1
GROUP BY
  plan_name
ORDER BY 
  num_customers;
```
|plan_name               |num_customers|perc_customers|
|------------------------|-------------|--------------|
|trial                   |19           |1.9           |
|pro annual              |195          |19.5          |
|basic monthly           |224          |22.4          |
|churn                   |235          |23.5          |
|pro monthly             |327          |32.7          |

How many customers have upgraded to an annual plan in 2020?
```sql
SELECT
  COUNT(DISTINCT customer_id)
FROM
  foodie_fi.subscriptions AS subs
  JOIN foodie_fi.plans ON subs.plan_id = plans.plan_id
WHERE
  plan_name = 'pro annual'
  AND start_date <= '2020-12-31';
```
- 195

How many days on average does it take for a customer to an annual plan from the day they join Foodie-Fi?
```sql
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
```
- 105

Can you further breakdown this average value into 30 day periods (i.e. 0-30 days, 31-60 days etc)
```sql
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
```
|days_to_upgrade         |count|
|------------------------|-----|
|0-30 days               |49   |
|31-60 days              |24   |
|61-90 days              |34   |
|>90 days                |151  |

How many customers downgraded from a pro monthly to a basic monthly plan in 2020?
```sql
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
```
- 88

The Foodie-Fi team wants you to create a new payments table for the year 2020 that includes amounts paid by each customer in the subscriptions table with the following requirements:

monthly payments always occur on the same day of month as the original start_date of any monthly paid plan
upgrades from basic to monthly or pro plans are reduced by the current paid amount in that month and start immediately
upgrades from pro monthly to pro annual are paid at the end of the current billing period and also starts at the end of the month period
once a customer churns they will no longer make payments
Example outputs for this table might look like the following:
| customer_id | plan_id | plan_name     | payment_date | amount | payment_order |
|-------------|---------|---------------|--------------|--------|---------------|
| 1           | 1       | basic monthly | 2020-08-08   | 9.90   | 1             |
| 1           | 1       | basic monthly | 2020-09-08   | 9.90   | 2             |
| 1           | 1       | basic monthly | 2020-10-08   | 9.90   | 3             |
| 1           | 1       | basic monthly | 2020-11-08   | 9.90   | 4             |
| 1           | 1       | basic monthly | 2020-12-08   | 9.90   | 5             |
| 2           | 3       | pro annual    | 2020-09-27   | 199.00 | 1             |
| 7           | 1       | basic monthly | 2020-02-12   | 9.90   | 1             |
| 7           | 1       | basic monthly | 2020-03-12   | 9.90   | 2             |
| 7           | 1       | basic monthly | 2020-04-12   | 9.90   | 3             |
| 7           | 1       | basic monthly | 2020-05-12   | 9.90   | 4             |
| 7           | 2       | pro monthly   | 2020-05-22   | 10.00  | 5             |
| 7           | 2       | pro monthly   | 2020-06-22   | 19.90  | 6             |
| 7           | 2       | pro monthly   | 2020-07-22   | 19.90  | 7             |
| 7           | 2       | pro monthly   | 2020-08-22   | 19.90  | 8             |
| 7           | 2       | pro monthly   | 2020-09-22   | 19.90  | 9             |
| 7           | 2       | pro monthly   | 2020-10-22   | 19.90  | 10            |
| 7           | 2       | pro monthly   | 2020-11-22   | 19.90  | 11            |
| 7           | 2       | pro monthly   | 2020-12-22   | 19.90  | 12            |
| 13          | 1       | basic monthly | 2020-12-22   | 9.90   | 1             |
| 15          | 2       | pro monthly   | 2020-03-24   | 19.90  | 1             |
| 15          | 2       | pro monthly   | 2020-04-24   | 19.90  | 2             |
| 16          | 1       | basic monthly | 2020-06-07   | 9.90   | 1             |
| 16          | 1       | basic monthly | 2020-07-07   | 9.90   | 2             |
| 16          | 1       | basic monthly | 2020-08-07   | 9.90   | 3             |
| 16          | 1       | basic monthly | 2020-09-07   | 9.90   | 4             |
| 16          | 1       | basic monthly | 2020-10-07   | 9.90   | 5             |
| 16          | 3       | pro annual    | 2020-10-21   | 189.10 | 6             |
| 18          | 2       | pro monthly   | 2020-07-13   | 19.90  | 1             |
| 18          | 2       | pro monthly   | 2020-08-13   | 19.90  | 2             |
| 18          | 2       | pro monthly   | 2020-09-13   | 19.90  | 3             |
| 18          | 2       | pro monthly   | 2020-10-13   | 19.90  | 4             |
| 18          | 2       | pro monthly   | 2020-11-13   | 19.90  | 5             |
| 18          | 2       | pro monthly   | 2020-12-13   | 19.90  | 6             |
| 19          | 2       | pro monthly   | 2020-06-29   | 19.90  | 1             |
| 19          | 2       | pro monthly   | 2020-07-29   | 19.90  | 2             |
| 19          | 3       | pro annual    | 2020-08-29   | 199.00 | 3             |
| 25          | 1       | basic monthly | 2020-05-17   | 9.90   | 1             |
| 25          | 2       | pro monthly   | 2020-06-16   | 10.00  | 2             |
| 25          | 2       | pro monthly   | 2020-07-16   | 19.90  | 3             |
| 25          | 2       | pro monthly   | 2020-08-16   | 19.90  | 4             |
| 25          | 2       | pro monthly   | 2020-09-16   | 19.90  | 5             |
| 25          | 2       | pro monthly   | 2020-10-16   | 19.90  | 6             |
| 25          | 2       | pro monthly   | 2020-11-16   | 19.90  | 7             |
| 25          | 2       | pro monthly   | 2020-12-16   | 19.90  | 8             |
| 39          | 1       | basic monthly | 2020-06-04   | 9.90   | 1             |
| 39          | 1       | basic monthly | 2020-07-04   | 9.90   | 2             |
| 39          | 1       | basic monthly | 2020-08-04   | 9.90   | 3             |
| 39          | 2       | pro monthly   | 2020-08-25   | 10.00  | 4             |


```sql
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
WHERE customer_id IN (1, 2, 7, 11, 13, 15, 16, 18, 19, 25, 39)
WINDOW w AS (
  PARTITION BY customer_id
  ORDER BY start_date
);
```
