# Fresh Segments - Case Study


# Context
Danny created Fresh Segments, a digital marketing agency that helps other businesses analyse trends in online ad click behaviour for their unique customer base.

Clients share their customer lists with the Fresh Segments team who then aggregate interest metrics and generate a single dataset worth of metrics for further analysis.

In particular - the composition and rankings for different interests are provided for each client showing the proportion of their customer list who interacted with online assets related to each interest for each month.

Danny has asked for your assistance to analyse aggregated metrics for an example client and provide some high level insights about the customer list and their interests.

#  Datasets
All of the required datasets for this case study reside within the balanced_tree schema on the PostgreSQL Docker setup.

For this case study there is a total of 2 datasets.

## tables

**Interest Metrics**

This table contains information about aggregated interest metrics for a specific major client of Fresh Segments which makes up a large proportion of their customer base.

Each record in this table represents the performance of a specific interest_id based on the client’s customer base interest measured through clicks and interactions with specific targeted advertising content.
|_month|_year|month_year|interest_id|composition|index_value|ranking|percentile_ranking |
|------|-----|----------|-----------|-----------|-----------|-------|-------------------|
|  7   |2018 | 07-2018  |   32486   |   11.89   |   6.19    |   1   |       99.86       |
|  7   |2018 | 07-2018  |   6106    |   9.93    |   5.31    |   2   |       99.73       |
|  7   |2018 | 07-2018  |   18923   |   10.85   |   5.29    |   3   |       99.59       |
|  7   |2018 | 07-2018  |   6344    |   10.32   |    5.1    |   4   |       99.45       |
|  7   |2018 | 07-2018  |    100    |   10.77   |   5.04    |   5   |       99.31       |
|  7   |2018 | 07-2018  |    69     |   10.82   |   5.03    |   6   |       99.18       |
|  7   |2018 | 07-2018  |    79     |   11.21   |   4.97    |   7   |       99.04       |
|  7   |2018 | 07-2018  |   6111    |   10.71   |   4.83    |   8   |       98.9        |
|  7   |2018 | 07-2018  |   6214    |   9.71    |   4.83    |   8   |       98.9        |
|  ...   | ... | ...  |   ...  |   ...   |   ...    |  ...   |      ...      |

For example - let’s interpret the first row of the interest_metrics table together:

In July 2018, the composition metric is 11.89, meaning that 11.89% of the client’s customer list interacted with the interest interest_id = 32486 - we can link interest_id to a separate mapping table to find the segment name called “Vacation Rental Accommodation Researchers”

The index_value is 6.19, means that the composition value is 6.19x the average composition value for all Fresh Segments clients’ customers for this particular interest in the month of July 2018.

The ranking and percentage_ranking relates to the order of index_value records in each month year.

**Interest Map**
This mapping table links the interest_id with their relevant interest information. You will need to join this table onto the previous interest_details table to obtain the interest_name as well as any details about the summary information.

| id | interest_name             | interest_summary                                                                   | created_at       | last_modified    |
|----|---------------------------|------------------------------------------------------------------------------------|------------------|------------------|
| 1  | Fitness Enthusiasts       | Consumers using fitness tracking apps and websites.                                | 26/05/2016 14:57 | 23/05/2018 11:30 |
| 2  | Gamers                    | Consumers researching game reviews and cheat codes.                                | 26/05/2016 14:57 | 23/05/2018 11:30 |
| 3  | Car Enthusiasts           | Readers of automotive news and car reviews.                                        | 26/05/2016 14:57 | 23/05/2018 11:30 |
| 4  | Luxury Retail Researchers | Consumers researching luxury product reviews and gift ideas.                       | 26/05/2016 14:57 | 23/05/2018 11:30 |
| 5  | Brides & Wedding Planners | People researching wedding ideas and vendors.                                      | 26/05/2016 14:57 | 23/05/2018 11:30 |
| 6  | Vacation Planners         | Consumers reading reviews of vacation destinations and accommodations.             | 26/05/2016 14:57 | 23/05/2018 11:30 |
| 7  | Motorcycle Enthusiasts    | Readers of motorcycle news and reviews.                                            | 26/05/2016 14:57 | 23/05/2018 11:30 |
| 8  | Business News Readers     | Readers of online business news content.                                           | 26/05/2016 14:57 | 23/05/2018 11:30 |
| 12 | Thrift Store Shoppers     | Consumers shopping online for clothing at thrift stores and researching locations. | 26/05/2016 14:57 | 16/03/2018 13:14 |
| ...         | ...         | ... | ...  | ... | 




# Basic Data Inspection

Checking for duplicates in Interest Metrics 
```sql
WITH duplicates_cte AS(
SELECT
  COUNT(*) AS num_occurences,
  id,
  created_at,
  last_modified,
  interest_name,
  interest_summary
FROM
  fresh_segments.interest_map
GROUP BY
  id,
  created_at,
  last_modified,
  interest_name,
  interest_summary)
SELECT
  *
FROM 
  duplicates_cte
WHERE num_occurences > 1;
```

- no duplicates

Get Count of entries in the table
```sql
SELECT
  COUNT(*)
FROM
  fresh_segments.interest_metrics;
```

- 14273

```sql
SELECT
  COUNT(*)
FROM
  fresh_segments.interest_map;
```

- 1209

NULL Values
```sql
SELECT
  *
FROM
  fresh_segments.interest_map
WHERE
  id IS NULL;
```
No relevant NULL Values in the ide column.
```sql
SELECT
  *
FROM
  fresh_segments.interest_metrics
WHERE
  interest_id IS NULL;
```
There are a lot of NULL values in the table.
As the id and thus the foreign key is missing these are almost useless. I will keep them for now in case any aggregate metrics include them.

# Data Exploration and Cleansing

1. Update the fresh_segments.interest_metrics table by modifying the month_year column to be a date data type with the start of the month

```sql
UPDATE fresh_segments.interest_metrics
SET month_year = TO_DATE(month_year, 'MM-YYYY');

ALTER TABLE fresh_segments.interest_metrics
ALTER month_year TYPE DATE USING month_year::DATE;
```

2. What is count of records in the fresh_segments.interest_metrics for each month_year value sorted in chronological order (earliest to latest) with the null values appearing first?

```sql
SELECT
month_year,
COUNT(*) AS records
FROM fresh_segments.interest_metrics
GROUP BY month_year
ORDER BY month_year NULLS FIRST;
```

|month_year|records |
|----------|------|
|     null | 1194 |
|2018-07-01| 729  |
|2018-08-01| 767  |
|2018-09-01| 780  |
|2018-10-01| 857  |
|2018-11-01| 928  |
|2018-12-01| 995  |
|2019-01-01| 973  |
|2019-02-01| 1121 |
|2019-03-01| 1136 |
|2019-04-01| 1099 |
|2019-05-01| 857  |
|2019-06-01| 824  |
|2019-07-01| 864  |
|2019-08-01| 1149 |



3. What do you think we should do with these null values in the fresh_segments.interest_metrics?

These values probably have no value as all relevant business questions are based on either a date or an id, neither of which is present here. I would thus remove them.

```sql
DROP TABLE IF EXISTS interest_metrics_clean;
CREATE TEMP TABLE interest_metrics_clean AS
SELECT 
  *
FROM 
  fresh_segments.interest_metrics
WHERE interest_id IS NOT NULL;
```

4. How many interest_id values exist in the fresh_segments.interest_metrics table but not in the fresh_segments.interest_map table? What about the other way around?

```sql
SELECT
  COUNT(DISTINCT interest_id) AS metrics_ids,
  COUNT(DISTINCT id) AS map_ids,
  COUNT(
    CASE
      WHEN id IS NULL THEN interest_id
      ELSE NULL
    END
  ) AS metrics_ids_not_map,
  COUNT(
    CASE
      WHEN interest_id IS NULL THEN id
      ELSE NULL
    END
  ) AS map_ids_not_in_metrics
FROM
  interest_metrics_clean as metrics 
  FULL OUTER JOIN fresh_segments.interest_map as map ON map.id = metrics.interest_id;
```
|metrics_ids|map_ids|metrics_ids_not_map|map_ids_not_in_metrics |
|-----------|-------|-------------------|-----------------------|
|   1202    | 1209  |         0         |           7           |



5. Summarise the id values in the fresh_segments.interest_map by its total record count in this table

```sql
WITH record_counts AS(
    SELECT
      id,
      COUNT(*) AS num_records
    FROM
      fresh_segments.interest_map
    GROUP BY
      id
  )
SELECT
  num_records,
  COUNT(id)
FROM
  record_counts
GROUP BY
  num_records;
```
|num_records|count |
|-----------|------|
|     1     | 1209 |


6. What sort of table join should we perform for our analysis and why? Check your logic by checking the rows where interest_id = 21246 in your joined output and include all columns from fresh_segments.interest_metrics and all columns from fresh_segments.interest_map except from the id column.

- either LEFT or INNER JOIN, depending on the base table. With INNER JOIN we make sure no missing IDs are present.

7. Are there any records in your joined table where the month_year value is before the created_at value from the fresh_segments.interest_map table? Do you think these values are valid and why?

```sql
SELECT
  month_year,
  created_at,
  id,
  interest_name
FROM
  interest_metrics_clean AS metrics
  JOIN fresh_segments.interest_map AS map ON metrics.interest_id = map.id
WHERE
  month_year < created_at;
```
There are 188 records where this is the case, however they all share the month and year. The "measurement before creation" is an artifact of the way the date was represented in the interest_metrics table. Here every record only has the month and year which was then converted into the first  day of the month.

# Interest Analysis

1. Which interests have been present in all month_year dates in our dataset?
```sql
WITH cte_monthcount AS (
    SELECT
      interest_id,
      COUNT(month_year) AS month_count
    FROM
      interest_metrics_clean
    GROUP BY
      interest_id
  )
SELECT
  month_count,
  COUNT(interest_id)
FROM
  cte_monthcount
GROUP BY
  month_count
ORDER BY
  month_count DESC
LIMIT
  1;
```
- 480 interest have been present in all 14 month_year dates. The actual interests can be obtained via:
```sql
    SELECT
      interest_id
    FROM
      interest_metrics_clean
    GROUP BY
      interest_id
    HAVING COUNT(month_year) = 14
```
- table not shown due to length


2. Using this same total_months measure - calculate the cumulative percentage of all records starting at 14 months - which total_months value passes the 90% cumulative percentage value?
```sql
WITH cte_monthcount AS (
    SELECT
      interest_id,
      COUNT(month_year) AS month_count
    FROM
      interest_metrics_clean
    GROUP BY
      interest_id
  ),
  cte_interestcount AS (
    SELECT
      month_count,
      COUNT(interest_id) as num_interests
    FROM
      cte_monthcount
    GROUP BY
      month_count
    ORDER BY
      month_count DESC
  )
SELECT
  month_count,
  num_interests,
  ROUND(
    (
      SUM(num_interests) OVER(
        ORDER BY
          month_count DESC
      ) / SUM(num_interests) OVER() * 100
    ),
    2
  ) AS percentile_of_interests
FROM
  cte_interestcount
ORDER BY month_count DESC;
```

|month_count|num_interests|percentile_of_interests |
|-----------|-------------|------------------------|
|    14     |     480     |         39.93          |
|    13     |     82      |         46.76          |
|    12     |     65      |         52.16          |
|    11     |     94      |         59.98          |
|    10     |     86      |         67.14          |
|     9     |     95      |         75.04          |
|     8     |     67      |         80.62          |
|     7     |     90      |          88.1          |
|     6     |     33      |         90.85          |
|     5     |     38      |         94.01          |
|     4     |     32      |         96.67          |
|     3     |     15      |         97.92          |
|     2     |     12      |         98.92          |
|     1     |     13      |          100           |


3. If we were to remove all interest_id values which are lower than the total_months value we found in the previous question - how many total data points would we be removing?
```sql
WITH cte_removed_interests AS (
SELECT
  interest_id
FROM interest_metrics_clean
GROUP BY interest_id
HAVING COUNT(DISTINCT month_year) < 6
)
SELECT
  COUNT(*) AS removed_rows
FROM interest_metrics_clean
WHERE  EXISTS (
  SELECT *
  FROM cte_removed_interests
  WHERE interest_metrics_clean.interest_id = cte_removed_interests.interest_id
);
```
- 400


# Segment Analysis

1. Using the complete dataset - which are the top 10 and bottom 10 interests which have the largest composition values in any month_year? Only use the maximum composition value for each interest but keep the corresponding month_year

```sql
WITH cte_ranked_composition AS(
  SELECT
    metrics.month_year,
    map.interest_name,
    metrics.composition,
    RANK() OVER(
      PARTITION BY interest_id
      ORDER BY
        composition DESC
    ) AS comp_rank_within
  FROM
    fresh_segments.interest_map AS map
    JOIN fresh_segments.interest_metrics AS metrics ON map.id = metrics.interest_id
),
cte_top_10 AS(
  SELECT
    month_year,
    interest_name,
    composition
  FROM
    cte_ranked_composition
  WHERE
    comp_rank_within = 1
  ORDER BY
    composition DESC
  LIMIT
    10
), cte_bottom_10 AS(
  SELECT
    month_year,
    interest_name,
    composition
  FROM
    cte_ranked_composition
  WHERE
    comp_rank_within = 1
  ORDER BY
    composition ASC
  LIMIT
    10
)
SELECT
  *
FROM
  cte_top_10
UNION ALL
SELECT
  *
FROM
  cte_bottom_10
ORDER BY
  composition DESC;
```

|month_year|interest_name|            composition            |
|----------|-------------|-----------------------------------|
|  Dec-18  |    Work Comes First Travelers      |    21.2     |
|  Jul-18  |     Gym Equipment Owners     |      18.82       |
|  Jul-18  |  Furniture Shoppers  |           17.44           |
|  Jul-18  |   Luxury Retail Shoppers   |        17.19       |
|  Oct-18  |   Luxury Boutique Hotel Researchers  | 15.15   |
|  Dec-18  |   Luxury Bedding Shoppers   |       15.05       |
|  Jul-18  |    Shoe  Shoppers   |           14.91           |
|  Jul-18  |  Cosmetics and Beauty Shoppers |      14.23     |
|  Jul-18  |   Luxury  Hotel Guests   |         14.1         |
|  Jul-18  |   Luxury  Retail Researchers  |      13.97      |
|  Jul-18  |   Readers of Jamaican Content  |      1.86      |
|  Feb-19  | Automotive News Readers |          1.84         |
|  Jul-18  |   Comedy Fans   |              1.83             |
|  Aug-19  |    World  of Warcraft Enthusiasts  |    1.82    |
|  Aug-18  |    Miami  Heat Fans   |          1.81           |
|  Jul-18  |   Online Role Playing Game Enthusiasts   | 1.73 |
|  Aug-19  | Hearthstone Video Game Fans  |       1.66        |
|  Sep-18  |    Scifi  Movie and TV Enthusiasts  |    1.61   |
|  Sep-18  |   Action  Movie and TV Enthusiasts  |    1.59   |
|  Mar-19  |     The   Sims Video Game Fans  |      1.57     |


2. Which 5 interests had the lowest average ranking value?

```sql
SELECT
  DISTINCT interest_id,
  interest_name,
  ROUND(AVG(ranking) OVER(PARTITION BY interest_id), 2) avg_ranking
FROM
  fresh_segments.interest_metrics AS metrics
  JOIN fresh_segments.interest_map AS map ON map.id = metrics.interest_id
ORDER BY
  avg_ranking
LIMIT
  5;
```

|interest_id|interest_name|        avg_ranking         |
|-----------|-------------|----------------------------|
|   41548   |   Winter Apparel Shoppers   |      1     |
|   42203   |   Fitness Activity Tracker Users   | 4.11 |
|    115    |    Men's Shoe Shoppers   |      5.93     |
|   48154   |    Elite   Cycling Gear Shoppers |  7.8  |
|    171    |    Shoe   Shoppers  |        9.36        |


3. Which 5 interests had the largest standard deviation in their percentile_ranking value?
```sql
SELECT
  DISTINCT interest_id,
  interest_name,
  STDDEV(percentile_ranking) OVER(PARTITION BY interest_id) std_percentile_ranking
FROM
  fresh_segments.interest_metrics AS metrics
  JOIN fresh_segments.interest_map AS map ON map.id = metrics.interest_id
ORDER BY
  std_percentile_ranking DESC NULLS LAST
LIMIT
  5;
```

|interest_id|interest_name|       std_percentile_ranking        |
|-----------|-------------|-------------------------------------|
|   6260    | Blockbuster Movie Fans |        41.27382282        |
|    131    |   Android Fans  |           30.72076789           |
|    150    |     TV   Junkies   |          30.36397487         |
|    23     |   Techies   |             30.17504709             |
|   20764   |Entertainment Industry Decision Makers | 28.97491996 |


4. For the 5 interests found in the previous question - what was minimum and maximum percentile_ranking values for each interest and its corresponding year_month value? Can you describe what is happening for these 5 interests?

5. How would you describe our customers in this segment based off their composition and ranking values? What sort of products or services should we show to these customers and what should we avoid?

# Index Analysis
The index_value is a measure which can be used to reverse calculate the average composition for Fresh Segments’ clients.

Average composition can be calculated by dividing the composition column by the index_value column rounded to 2 decimal places.

1. What is the top 10 interests by the average composition for each month?

2. For all of these top 10 interests - which interest appears the most often?

3. What is the average of the average composition for the top 10 interests for each month?

4. What is the 3 month rolling average of the max average composition value from September 2018 to August 2019 and include the previous top ranking interests in the same output shown below.

5. Provide a possible reason why the max average composition might change from month to month? Could it signal something is not quite right with the overall business model for Fresh Segments?