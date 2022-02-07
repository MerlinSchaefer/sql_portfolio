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