-- inspect data
SELECT 
   table_name, 
   column_name, 
   data_type 
FROM 
   information_schema.columns
WHERE 
   table_schema = 'data_mart'
ORDER BY table_name;

-- inspect  tables
SELECT
  *
FROM
  data_mart.weekly_sales
LIMIT
  20;
-- check table table for duplicates
WITH dup_cte AS (
    SELECT
      transactions,
      sales,
      platform,
      week_date,
      customer_type,
      segment,
      region,
      COUNT(*) AS frequency
    FROM
      data_mart.weekly_sales
    GROUP BY
      transactions,
      sales,
      platform,
      week_date,
      customer_type,
      segment,
      region
  )
SELECT
  *
FROM
  dup_cte
WHERE
  frequency > 1;


--clean table
  DROP TABLE IF EXISTS clean_weekly_sales;
CREATE TEMP TABLE clean_weekly_sales AS(
    SELECT
      TO_DATE(week_date, 'DD/MM/YY') AS week_date,
      DATE_PART('WEEK', TO_DATE(week_date, 'DD/MM/YY')) AS week_number,
      DATE_PART('MONTH', TO_DATE(week_date, 'DD/MM/YY')) AS month_number,
      DATE_PART('YEAR', TO_DATE(week_date, 'DD/MM/YY')) AS calendar_year,
      region,
      platform,
      segment,
      CASE
        RIGHT(segment, 1)
        WHEN '1' THEN 'Young Adults'
        WHEN '2' THEN 'Middle Aged'
        WHEN '3' THEN 'Retirees'
        WHEN '4' THEN 'Retirees'
        ELSE 'Unknown'
      END AS age_band,
      CASE
        LEFT(segment, 1)
        WHEN 'C' THEN 'Couples'
        WHEN 'F' THEN 'Families'
        ELSE 'Unknown'
      END AS demographic,
      customer_type,
      transactions,
      sales,
      ROUND(sales / transactions :: NUMERIC, 2) AS avg_transaction
    FROM
      data_mart.weekly_sales
  );


-- q1
SELECT
  DATE_PART('DOW', week_date) AS day_of_week
FROM
  clean_weekly_sales;

-- q2

WITH all_week_numbers AS (
  SELECT GENERATE_SERIES(1, 52) AS week_number
)
SELECT
  week_number
FROM all_week_numbers AS t1
WHERE NOT EXISTS (
  SELECT 1
  FROM clean_weekly_sales AS t2
  WHERE t1.week_number = t2.week_number
);

-- q3
SELECT
  calendar_year,
  SUM(transactions)
FROM
  clean_weekly_sales
GROUP BY
  calendar_year
ORDER BY 
  calendar_year;

-- q4
SELECT
  region,
  calendar_year,
  month_number,
  SUM(sales) AS sum_sales
FROM
  clean_weekly_sales
GROUP BY
  region,
  calendar_year,
  month_number
ORDER BY
  calendar_year,
  month_number,
  region;

-- q5
SELECT
  platform,
  SUM(transactions) sum_transactions
FROM
  clean_weekly_sales
GROUP BY
  platform;

-- q6
WITH platform_cte AS (
  SELECT
    DATE_TRUNC('month', week_date) :: DATE AS _month,
    platform,
    SUM(sales) AS monthly_sales
  FROM
    clean_weekly_sales
  GROUP BY
    _month,
    platform
)
SELECT
  _month,
  platform,
  ROUND(
    100 * monthly_sales / SUM(monthly_sales) OVER(PARTITION BY _month),
    2
  ) AS perc_monthly_sales
FROM
  platform_cte;

--q7
WITH demo_cte AS (
    SELECT
      calendar_year,
      demographic,
      SUM(sales) AS yearly_sales
    FROM
      clean_weekly_sales
    GROUP BY
      calendar_year,
      demographic
  )
SELECT
  calendar_year,
  ROUND(
    100 * MAX(
      CASE
        WHEN demographic = 'Families' THEN yearly_sales
        ELSE NULL
      END
    ) / SUM(yearly_sales) :: NUMERIC,
    2
  ) AS perc_yearly_families,
  ROUND(
    100 * MAX(
      CASE
        WHEN demographic = 'Couples' THEN yearly_sales
        ELSE NULL
      END
    ) / SUM(yearly_sales) :: NUMERIC,
    2
  ) AS perc_yearly_couples,
  ROUND(
    100 * MAX(
      CASE
        WHEN demographic = 'Unknown' THEN yearly_sales
        ELSE NULL
      END
    ) / SUM(yearly_sales) :: NUMERIC,
    2
  ) AS perc_yearly_unknown
FROM
  demo_cte
GROUP BY
  calendar_year
ORDER BY
  calendar_year;

-- q8
WITH agedemo_cte AS(
    SELECT
      age_band,
      demographic,
      SUM(sales) AS sum_sales
    FROM
      clean_weekly_sales
    WHERE
      platform = 'Retail'
    GROUP BY
      age_band,
      demographic
  )
SELECT
  age_band,
  demographic,
  sum_sales,
  ROUND(100 * sum_sales / SUM(sum_sales) OVER() :: NUMERIC, 2) AS perc_sales
FROM
  agedemo_cte
ORDER BY
  sum_sales DESC

--q9
SELECT
  calendar_year,
  platform,
  ROUND(AVG(avg_transaction)) AS avg_avg_transaction,
  -- here a incorrect fraction is formed
  -- avg_transaction is a row based value
  ROUND(AVG(sales) / AVG(transactions)) AS avg_annual_transaction --correct
FROM
  clean_weekly_sales
GROUP BY
  calendar_year,
  platform
ORDER BY
  calendar_year,
  platform;

-- before and after 1
SELECT
  DISTINCT week_number
FROM
  clean_weekly_sales
WHERE
  week_date = '2020-06-15';
WITH four_weeks_cte AS (
    SELECT
      CASE
        WHEN week_number BETWEEN 21
        AND 24 THEN '1 previous 4 weeks'
        WHEN week_number BETWEEN 25
        AND 28 THEN '2 following 4 weeks'
        ELSE NULL
      END AS calc_periods,
      SUM(transactions) AS total_transactions,
      SUM(sales) AS total_sales,
      SUM(sales) / SUM(transactions) AS avg_transaction_size
    FROM
      clean_weekly_sales
    WHERE
      week_number BETWEEN 21
      AND 28
      AND calendar_year = 2020
    GROUP BY
      calc_periods
  ),
  cte_sales_diff AS (
    SELECT
      total_sales - LAG(total_sales) OVER(
        ORDER BY
          calc_periods
      ) AS sales_diff,
      ROUND(
        100 * (
          total_sales :: NUMERIC / LAG(total_sales) OVER(
            ORDER BY
              calc_periods
          ) -1
        ),
        2
      ) AS perc_diff
    FROM
      four_weeks_cte
  )
SELECT
  *
FROM
  cte_sales_diff
WHERE
  sales_diff IS NOT NULL;

-- before and after 2

WITH twelve_weeks_cte AS (
    SELECT
      CASE
        WHEN week_number <= 24 THEN '1 previous 12 weeks'
        WHEN week_number >= 25 THEN '2 following 12 weeks'
        ELSE NULL
      END AS calc_periods,
      SUM(transactions) AS total_transactions,
      SUM(sales) AS total_sales,
      SUM(sales) / SUM(transactions) AS avg_transaction_size
    FROM
      clean_weekly_sales
    WHERE
      calendar_year = 2020
    GROUP BY
      calc_periods
  ),
  cte_sales_diff AS (
    SELECT
      total_sales - LAG(total_sales) OVER(
        ORDER BY
          calc_periods
      ) AS sales_diff,
      ROUND(
        100 * (
          total_sales :: NUMERIC / LAG(total_sales) OVER(
            ORDER BY
              calc_periods
          ) -1
        ),
        2
      ) AS perc_diff
    FROM
      twelve_weeks_cte
  )
SELECT
  *
FROM
  cte_sales_diff
WHERE
  sales_diff IS NOT NULL;

-- before and after 3
WITH twelve_weeks_cte AS (
    SELECT
      calendar_year,
      CASE
        WHEN week_number <= 24 THEN '1 previous 12 weeks'
        WHEN week_number >= 25 THEN '2 following 12 weeks'
        ELSE NULL
      END AS calc_periods,
      SUM(transactions) AS total_transactions,
      SUM(sales) AS total_sales,
      SUM(sales) / SUM(transactions) AS avg_transaction_size
    FROM
      clean_weekly_sales
    WHERE
      calendar_year IN (2018, 2019, 2020)
    GROUP BY
      calendar_year,
      calc_periods
    ORDER BY
      calendar_year,
      calc_periods
  ),
  cte_sales_diff_twelve AS (
    SELECT
      calendar_year,
      total_sales - LAG(total_sales) OVER(
        PARTITION BY calendar_year
        ORDER BY
          calc_periods
      ) AS sales_diff,
      ROUND(
        100 * (
          total_sales :: NUMERIC / LAG(total_sales) OVER(
            PARTITION BY calendar_year
            ORDER BY
              calc_periods
          ) -1
        ),
        2
      ) AS perc_diff
    FROM
      twelve_weeks_cte
  ),
four_weeks_cte AS (
    SELECT
      calendar_year,
      CASE
        WHEN week_number BETWEEN 21
        AND 24 THEN '1 previous 4 weeks'
        WHEN week_number BETWEEN 25
        AND 28 THEN '2 following 4 weeks'
        ELSE NULL
      END AS calc_periods,
      SUM(transactions) AS total_transactions,
      SUM(sales) AS total_sales,
      SUM(sales) / SUM(transactions) AS avg_transaction_size
    FROM
      clean_weekly_sales
    WHERE
      calendar_year IN (2018, 2019, 2020)
      AND week_number BETWEEN 21
      AND 28
    GROUP BY
      calendar_year,
      calc_periods
    ORDER BY
      calendar_year,
      calc_periods
  ),
  cte_sales_diff_four AS (
    SELECT
      calendar_year,
      total_sales - LAG(total_sales) OVER(
        PARTITION BY calendar_year
        ORDER BY
          calc_periods
      ) AS sales_diff,
      ROUND(
        100 * (
          total_sales :: NUMERIC / LAG(total_sales) OVER(
            PARTITION BY calendar_year
            ORDER BY
              calc_periods
          ) -1
        ),
        2
      ) AS perc_diff
    FROM
      four_weeks_cte
  )
SELECT
calendar_year, 
sales_diff,
perc_diff,
'12 week difference' AS time_period
FROM
  cte_sales_diff_twelve
WHERE sales_diff IS NOT NULL
UNION 
SELECT
calendar_year, 
sales_diff,
perc_diff,
'4 week difference' AS time_period
FROM
  cte_sales_diff_four
WHERE sales_diff IS NOT NULL
ORDER BY
  time_period,
    calendar_year;