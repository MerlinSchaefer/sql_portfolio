# Data-Mart - Case Study


# Context
Data Mart is Danny’s latest venture and after running international operations for his online supermarket that specialises in fresh produce - Danny is asking for your support to analyse his sales performance.

In June 2020 - large scale supply changes were made at Data Mart. All Data Mart products now use sustainable packaging methods in every single step from the farm all the way to the customer.

Danny needs your help to quantify the impact of this change on the sales performance for Data Mart and it’s separate business areas.

The key business question he wants you to help him answer are the following:

What was the quantifiable impact of the changes introduced in June 2020?
Which platform, region, segment and customer types were the most impacted by this change?
What can we do about future introduction of similar sustainability updates to the business to minimise impact on sales?


#  Datasets
All of the required datasets for this case study reside within the data_mart schema on the PostgreSQL Docker setup.

For this case study there is only a single table: `data_mart.weekly_sales`

![ERD](ERD.png)

The columns are pretty self-explanatory based on the column names but here are some further details about the dataset:

- Data Mart has international operations using a multi-region strategy
- Data Mart has both, a retail and online platform in the form of a Shopify store front to serve their customers
- Customer segment and customer_type data relates to personal age and demographics information that is shared with Data Mart
transactions is the count of unique purchases made through Data Mart and sales is the actual dollar amount of purchases
- Each record in the dataset is related to a specific aggregated slice of the underlying sales data rolled up into a week_date value which represents the start of the sales week.

|week_date|region       |platform|segment|customer_type|transactions|sales     |
|---------|-------------|--------|-------|-------------|------------|----------|
|9/9/20   |OCEANIA      |Shopify |C3     |New          |610         |110033.89 |
|29/7/20  |AFRICA       |Retail  |C1     |New          |110692      |3053771.19|
|22/7/20  |EUROPE       |Shopify |C4     |Existing     |24          |8101.54   |
|13/5/20  |AFRICA       |Shopify |null   |Guest        |5287        |1003301.37|
|24/7/19  |ASIA         |Retail  |C1     |New          |127342      |3151780.41|
|10/7/19  |CANADA       |Shopify |F3     |New          |51          |8844.93   |
|26/6/19  |OCEANIA      |Retail  |C3     |New          |152921      |5551385.36|
|29/5/19  |SOUTH AMERICA|Shopify |null   |New          |53          |10056.2   |
|22/8/18  |AFRICA       |Retail  |null   |Existing     |31721       |1718863.58|
|25/7/18  |SOUTH AMERICA|Retail  |null   |New          |2136        |81757.91  |


# Data Cleaning

Checking for duplicates
```sql
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
```
- no duplicates

### Necessary Cleaning steps:

- Convert the week_date to a DATE format 

- Add a week_number as the second column for each week_date value, for example any value from the 1st of January to 7th of January will be 1, 8th to 14th will be 2 etc

- Add a month_number with the calendar month for each week_date value as the 3rd column

- Add a calendar_year column as the 4th column containing either 2018, 2019 or 2020 values

- Add a new column called age_band after the original segment column using the following mapping on the number inside the segment value

|segment|age_band     |
|-------|-------------|
|1      |Young Adults |
|2      |Middle Aged  |
|3 or 4 |Retirees     |

- Add a new demographic column using the following mapping for the first letter in the segment values:

|segment | demographic |
|--------|-------------|
|C | Couples |
|F | Families |

- Ensure all null string values with an "unknown" string value in the original segment column as well as the new age_band and demographic columns

- Generate a new avg_transaction column as the sales value divided by transactions rounded to 2 decimal places for each record

```sql
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
```

# Data Exploration

1. What day of the week is used for each week_date value?
```sql
SELECT
  DATE_PART('DOW',week_date) AS day_of_week
FROM
  clean_weekly_sales;
```

- 1, Monday


What range of week numbers are missing from the dataset?
```sql
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
```
- weeks 37-52 and 1-12

3. How many total transactions were there for each year in the dataset?
```sql
SELECT
  calendar_year,
  SUM(transactions) AS sum_transactions
FROM
  clean_weekly_sales
GROUP BY
  calendar_year
ORDER BY 
  calendar_year;
```

|calendar_year|sum_transactions          |
|-------------|-------------|
|2018         |346406460    |
|2019         |365639285    |
|2020         |375813651    |


4. What is the total sales for each region for each month?
```sql
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
```
|region |calendar_year|month_number|sum_sales|
|-------|-------------|------------|---------|
|AFRICA |2018         |3           |130542213|
|ASIA   |2018         |3           |119180883|
|CANADA |2018         |3           |33815571 |
|EUROPE |2018         |3           |8402183  |
|OCEANIA|2018         |3           |175777460|
|SOUTH AMERICA|2018         |3           |16302144 |
|USA    |2018         |3           |52734998 |
|AFRICA |2018         |4           |650194751|
|ASIA   |2018         |4           |603716301|
|CANADA |2018         |4           |163479820|
|EUROPE |2018         |4           |44549418 |
|OCEANIA|2018         |4           |869324594|
|...|...         |...           |... |


5. What is the total count of transactions for each platform?
```sql
SELECT
  platform,
  SUM(transactions) sum_transactions
FROM
  clean_weekly_sales
GROUP BY
  platform;
```

|platform|sum_transactions       |
|--------|----------|
|Shopify |5925169   |
|Retail  |1081934227|


6. What is the percentage of sales for Retail vs Shopify for each month?
```sql
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
```
|_month                  |platform|perc_monthly_sales|
|------------------------|--------|------------------|
|2018-03-01T00:00:00.000Z|Retail  |97.92             |
|2018-03-01T00:00:00.000Z|Shopify |2.08              |
|2018-04-01T00:00:00.000Z|Retail  |97.93             |
|2018-04-01T00:00:00.000Z|Shopify |2.07              |
|2018-05-01T00:00:00.000Z|Retail  |97.73             |
|2018-05-01T00:00:00.000Z|Shopify |2.27              |
|2018-06-01T00:00:00.000Z|Retail  |97.76             |
|2018-06-01T00:00:00.000Z|Shopify |2.24              |
|2018-07-01T00:00:00.000Z|Retail  |97.75             |
|2018-07-01T00:00:00.000Z|Shopify |2.25              |
|2018-08-01T00:00:00.000Z|Retail  |97.71             |
|2018-08-01T00:00:00.000Z|Shopify |2.29              |
|2018-09-01T00:00:00.000Z|Retail  |97.68             |
|2018-09-01T00:00:00.000Z|Shopify |2.32              |
|2019-03-01T00:00:00.000Z|Shopify |2.29              |
|...                     |...     |...               |


**For a pivoted version**
```sql
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
  ROUND(
    100 * MAX(
      CASE
        WHEN platform = 'Retail' THEN monthly_sales
        ELSE NULL
      END
    ) / SUM(monthly_sales) :: NUMERIC,
    2
  ) AS perc_monthly_sales_retail,
  ROUND(
    100 * MAX(
      CASE
        WHEN platform = 'Shopify' THEN monthly_sales
        ELSE NULL
      END
    ) / SUM(monthly_sales) :: NUMERIC,
    2
  ) AS shopify_percentage
FROM
  platform_cte
GROUP BY
  _month
ORDER BY
  _month;
```

7. What is the percentage of sales by demographic for each year in the dataset?
```sql
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
```

|calendar_year|perc_yearly_families|perc_yearly_couples|perc_yearly_unknown|
|-------------|--------------------|-------------------|-------------------|
|2018         |31.99               |26.38              |41.63              |
|2019         |32.47               |27.28              |40.25              |
|2020         |32.73               |28.72              |38.55              |

8. Which age_band and demographic values contribute the most to Retail sales?
```sql
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
```
|age_band|demographic|sum_sales|perc_sales|
|--------|-----------|---------|----------|
|Unknown |Unknown    |16067285533|40.52     |
|Retirees|Families   |6634686916|16.73     |
|Retirees|Couples    |6370580014|16.07     |
|Middle Aged|Families   |4354091554|10.98     |
|Young Adults|Couples    |2602922797|6.56      |
|Middle Aged|Couples    |1854160330|4.68      |
|Young Adults|Families   |1770889293|4.47      |


9. Can we use the avg_transaction column to find the average transaction size for each year for Retail vs Shopify? If not - how would you calculate it instead?
```sql
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

```
# Before and After Analysis

Taking the week_date value of 2020-06-15 as the baseline week where the Data Mart sustainable packaging changes came into effect.

We would include all week_date values for 2020-06-15 as the start of the period after the change and the previous week_date values would be before

Using this analysis approach - answer the following questions:

**Cutoff Week**
```sql
SELECT
  DISTINCT week_number
FROM
  clean_weekly_sales
WHERE
  week_date = '2020-06-15';
```

- 25

What is the total sales for the 4 weeks before and after 2020-06-15? 
What is the growth or reduction rate in actual values and percentage of sales?

```sql
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
```

|sales_diff|perc_diff|
|--------|-----------|
|-26884188 |-1.15    |

What about the entire 12 weeks before and after?

```sql

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
    WHERE calendar_year = 2020
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
```

|sales_diff|perc_diff|
|--------|-----------|
|-152325394 | -2.14   |

How do the sale metrics for these 2 periods before and after compare with the previous years in 2018 and 2019?

```sql
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
```

|calendar_year|sales_diff|perc_diff|time_period       |
|-------------|----------|---------|------------------|
|2018         |104256193 |1.63     |12 week difference|
|2019         |-20740294 |-0.3     |12 week difference|
|2020         |-152325394|-2.14    |12 week difference|
|2018         |4102105   |0.19     |4 week difference |
|2019         |2336594   |0.1      |4 week difference |
|2020         |-26884188 |-1.15    |4 week difference |
