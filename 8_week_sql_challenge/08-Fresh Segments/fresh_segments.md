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

```sql
WITH cte_top5_std_perc_ranking AS (
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
    5
)
SELECT
  interest_id,
  interest_name,
  month_year,
  percentile_ranking,
  MAX(percentile_ranking) OVER(PARTITION BY interest_id) overall_max_perc_ranking,
  MIN(percentile_ranking) OVER(PARTITION BY interest_id) overall_min_perc_ranking
FROM
  fresh_segments.interest_metrics AS metrics
  JOIN fresh_segments.interest_map AS map ON map.id = metrics.interest_id
WHERE
  interest_id IN (
    SELECT
      interest_id
    FROM
      cte_top5_std_perc_ranking
  )
ORDER BY
  interest_id,
  percentile_ranking;
```

|interest_id|interest_name                         |month_year|percentile_ranking|overall_max_perc_ranking|overall_min_perc_ranking|
|-----------|--------------------------------------|----------|------------------|------------------------|------------------------|
|23         |Techies                               |Aug-19    |7.92              |86.69                   |7.92                    |
|23         |Techies                               |Feb-19    |9.46              |86.69                   |7.92                    |
|23         |Techies                               |Mar-19    |9.68              |86.69                   |7.92                    |
|23         |Techies                               |Sep-18    |23.85             |86.69                   |7.92                    |
|23         |Techies                               |Aug-18    |30.9              |86.69                   |7.92                    |
|23         |Techies                               |Jul-18    |86.69             |86.69                   |7.92                    |
|131        |Android Fans                          |Mar-19    |4.84              |75.03                   |4.84                    |
|131        |Android Fans                          |Aug-19    |4.96              |75.03                   |4.84                    |
|131        |Android Fans                          |Feb-19    |5.62              |75.03                   |4.84                    |
|131        |Android Fans                          |Aug-18    |10.82             |75.03                   |4.84                    |
|131        |Android Fans                          |Jul-18    |75.03             |75.03                   |4.84                    |
|150        |TV Junkies                            |Aug-19    |10.01             |93.28                   |10.01                   |
|150        |TV Junkies                            |Aug-18    |37.29             |93.28                   |10.01                   |
|150        |TV Junkies                            |Dec-18    |37.79             |93.28                   |10.01                   |
|150        |TV Junkies                            |Oct-18    |49.82             |93.28                   |10.01                   |
|150        |TV Junkies                            |Jul-18    |93.28             |93.28                   |10.01                   |
|6260       |Blockbuster Movie Fans                |Aug-19    |2.26              |60.63                   |2.26                    |
|6260       |Blockbuster Movie Fans                |Jul-18    |60.63             |60.63                   |2.26                    |
|20764      |Entertainment Industry Decision Makers|Aug-19    |11.23             |86.15                   |11.23                   |
|20764      |Entertainment Industry Decision Makers|Mar-19    |11.53             |86.15                   |11.23                   |
|20764      |Entertainment Industry Decision Makers|Aug-18    |16.04             |86.15                   |11.23                   |
|20764      |Entertainment Industry Decision Makers|Oct-18    |18.67             |86.15                   |11.23                   |
|20764      |Entertainment Industry Decision Makers|Feb-19    |22.12             |86.15                   |11.23                   |
|20764      |Entertainment Industry Decision Makers|Jul-18    |86.15             |86.15                   |11.23                   |



# Index Analysis
The index_value is a measure which can be used to reverse calculate the average composition for Fresh Segments’ clients.

Average composition can be calculated by dividing the composition column by the index_value column rounded to 2 decimal places.

1. What are the top 10 interests by the average composition for each month?

```sql
WITH cte_avg_comp AS (
  SELECT
    interest_id,
    interest_name,
    month_year,
    ROUND(composition :: NUMERIC / index_value :: NUMERIC, 2) AS avg_composition,
    RANK() OVER(
      PARTITION BY month_year
      ORDER BY
        composition :: NUMERIC / index_value :: NUMERIC DESC
    ) AS avg_composition_rank
  FROM
    fresh_segments.interest_metrics AS metrics
    JOIN fresh_segments.interest_map AS map ON map.id = metrics.interest_id
  WHERE
    month_year IS NOT NULL
)
SELECT
  *
FROM
  cte_avg_comp
WHERE
  avg_composition_rank <= 10
ORDER BY
 month_year, avg_composition_rank;
```

- showing only the first couple of rows as there are 140

|interest_id|interest_name                         |month_year|avg_composition|avg_composition_rank|
|-----------|--------------------------------------|----------|---------------|--------------------|
|6324       |Las Vegas Trip Planners               |2018-07-01T00:00:00.000Z|7.36           |1                   |
|6284       |Gym Equipment Owners                  |2018-07-01T00:00:00.000Z|6.94           |2                   |
|4898       |Cosmetics and Beauty Shoppers         |2018-07-01T00:00:00.000Z|6.78           |3                   |
|77         |Luxury Retail Shoppers                |2018-07-01T00:00:00.000Z|6.61           |4                   |
|39         |Furniture Shoppers                    |2018-07-01T00:00:00.000Z|6.51           |5                   |
|18619      |Asian Food Enthusiasts                |2018-07-01T00:00:00.000Z|6.1            |6                   |
|6208       |Recently Retired Individuals          |2018-07-01T00:00:00.000Z|5.72           |7                   |
|21060      |Family Adventures Travelers           |2018-07-01T00:00:00.000Z|4.85           |8                   |
|21057      |Work Comes First Travelers            |2018-07-01T00:00:00.000Z|4.8            |9                   |
|82         |HDTV Researchers                      |2018-07-01T00:00:00.000Z|4.71           |10                  |
|6324       |Las Vegas Trip Planners               |2018-08-01T00:00:00.000Z|7.21           |1                   |
|6284       |Gym Equipment Owners                  |2018-08-01T00:00:00.000Z|6.62           |2                   |
|77         |Luxury Retail Shoppers                |2018-08-01T00:00:00.000Z|6.53           |3                   |
|39         |Furniture Shoppers                    |2018-08-01T00:00:00.000Z|6.3            |4                   |
|4898       |Cosmetics and Beauty Shoppers         |2018-08-01T00:00:00.000Z|6.28           |5                   |
|21057      |Work Comes First Travelers            |2018-08-01T00:00:00.000Z|5.7            |6                   |
|18619      |Asian Food Enthusiasts                |2018-08-01T00:00:00.000Z|5.68           |7                   |
|6208       |Recently Retired Individuals          |2018-08-01T00:00:00.000Z|5.58           |8                   |
|7541       |Alabama Trip Planners                 |2018-08-01T00:00:00.000Z|4.83           |9                   |


2. For all of these top 10 interests - which interest appears the most often?

```sql
WITH cte_avg_comp AS (
  SELECT
    interest_id,
    interest_name,
    month_year,
    ROUND(
      composition :: NUMERIC / index_value :: NUMERIC,
      2
    ) AS avg_composition,
    RANK() OVER(
      PARTITION BY month_year
      ORDER BY
        composition :: NUMERIC / index_value :: NUMERIC DESC
    ) AS avg_composition_rank
  FROM
    fresh_segments.interest_metrics AS metrics
    JOIN fresh_segments.interest_map AS map ON map.id = metrics.interest_id
  WHERE
    month_year IS NOT NULL
),
top_10_avg_comp AS (
  SELECT
    *
  FROM
    cte_avg_comp
  WHERE
    avg_composition_rank <= 10
)
SELECT
  interest_id,
  interest_name,
  COUNT(*) AS count_apperance_monthly_top_10
FROM
  top_10_avg_comp
GROUP BY
  interest_id,
  interest_name
ORDER BY
  count_apperance_monthly_top_10 DESC;
```

|interest_id|interest_name                         |count_apperance_monthly_top_10|
|-----------|--------------------------------------|------------------------------|
|6065       |Solar Energy Researchers              |10                            |
|7541       |Alabama Trip Planners                 |10                            |
|5969       |Luxury Bedding Shoppers               |10                            |
|21245      |Readers of Honduran Content           |9                             |
|18783      |Nursing and Physicians Assistant Journal Researchers|9                             |
|10981      |New Years Eve Party Ticket Purchasers |9                             |
|34         |Teen Girl Clothing Shoppers           |8                             |
|21057      |Work Comes First Travelers            |8                             |
|10977      |Christmas Celebration Researchers     |7                             |
|4898       |Cosmetics and Beauty Shoppers         |5                             |
|6284       |Gym Equipment Owners                  |5                             |
|39         |Furniture Shoppers                    |5                             |
|6208       |Recently Retired Individuals          |5                             |
|77         |Luxury Retail Shoppers                |5                             |
|6324       |Las Vegas Trip Planners               |5                             |
|18619      |Asian Food Enthusiasts                |5                             |
|15878      |Readers of Catholic News              |4                             |
|19620      |PlayStation Enthusiasts               |4                             |
|6253       |Medicare Researchers                  |3                             |
|13497      |Restaurant Supply Shoppers            |3                             |
|7535       |Medicare Provider Researchers         |2                             |
|82         |HDTV Researchers                      |1                             |
|21237      |Chelsea Fans                          |1                             |
|21060      |Family Adventures Travelers           |1                             |
|2          |Gamers                                |1                             |
|107        |Cruise Travel Intenders               |1                             |
|12133      |Luxury Boutique Hotel Researchers     |1                             |
|4931       |Marijuana Legalization Advocates      |1                             |
|7536       |Medicare Price Shoppers               |1                             |
|15884      |Video Gamers                          |1                             |

3. What is the average of the average composition for the top 10 interests for each month?

```sql
WITH cte_avg_comp AS (
  SELECT
    interest_id,
    interest_name,
    month_year,
    ROUND(
      composition :: NUMERIC / index_value :: NUMERIC,
      2
    ) AS avg_composition,
    RANK() OVER(
      PARTITION BY month_year
      ORDER BY
        composition :: NUMERIC / index_value :: NUMERIC DESC
    ) AS avg_composition_rank
  FROM
    fresh_segments.interest_metrics AS metrics
    JOIN fresh_segments.interest_map AS map ON map.id = metrics.interest_id
  WHERE
    month_year IS NOT NULL
),
top_10_avg_comp AS (
  SELECT
    *
  FROM
    cte_avg_comp
  WHERE
    avg_composition_rank <= 10
)
SELECT
month_year,
  ROUND(AVG(avg_composition),2) AS avg_avg_composition
FROM
  top_10_avg_comp
GROUP BY
  month_year
ORDER BY month_year;
```

|       month_year       |avg_avg_composition |
|------------------------|--------------------|
|2018-07-01T00:00:00.000Z|        6.04        |
|2018-08-01T00:00:00.000Z|        5.95        |
|2018-09-01T00:00:00.000Z|        6.9         |
|2018-10-01T00:00:00.000Z|        7.07        |
|2018-11-01T00:00:00.000Z|        6.62        |
|2018-12-01T00:00:00.000Z|        6.65        |
|2019-01-01T00:00:00.000Z|        6.4         |
|2019-02-01T00:00:00.000Z|        6.58        |
|2019-03-01T00:00:00.000Z|        6.17        |
|2019-04-01T00:00:00.000Z|        5.75        |
|2019-05-01T00:00:00.000Z|        3.54        |
|2019-06-01T00:00:00.000Z|        2.43        |
|2019-07-01T00:00:00.000Z|        2.77        |
|2019-08-01T00:00:00.000Z|        2.63        |



4. What is the 3 month rolling average of the max average composition value from September 2018 to August 2019 and include the previous 2 top ranking interests and their composition in the same output.

```sql
WITH cte_avg_comp AS (
  SELECT
    interest_id,
    interest_name,
    month_year,
    ROUND(
      composition :: NUMERIC / index_value :: NUMERIC,
      2
    ) AS avg_composition,
    RANK() OVER(
      PARTITION BY month_year
      ORDER BY
        composition :: NUMERIC / index_value :: NUMERIC DESC
    ) AS avg_composition_rank
  FROM
    fresh_segments.interest_metrics AS metrics
    JOIN fresh_segments.interest_map AS map ON map.id = metrics.interest_id
  WHERE
    month_year IS NOT NULL
),
final_output AS (
  SELECT
    month_year,
    interest_id,
    interest_name,
    avg_composition AS max_avg_composition,
    ROUND(
      AVG(avg_composition) OVER(
        ORDER BY
          month_year ROWS BETWEEN 2 PRECEDING
          AND CURRENT ROW
      ),
      2
    ) AS "3_month_moving_avg",
    LAG(interest_name || ': ' || avg_composition, 1) OVER(
      ORDER BY
        month_year
    ) AS one_month_prior,
    LAG(interest_name || ': ' || avg_composition, 2) OVER(
      ORDER BY
        month_year
    ) AS two_months_prior
  FROM
    cte_avg_comp
  WHERE
    avg_composition_rank = 1
)
SELECT
  *
FROM
  final_output
WHERE
  two_months_prior IS NOT NULL;
```
|month_year|interest_id                           |interest_name|max_avg_composition|3_month_moving_avg|one_month_prior                  |two_months_prior                 |
|----------|--------------------------------------|-------------|-------------------|------------------|---------------------------------|---------------------------------|
|2018-09-01T00:00:00.000Z|21057                                 |Work Comes First Travelers|8.26               |7.61              |Las Vegas Trip Planners: 7.21    |Las Vegas Trip Planners: 7.36    |
|2018-10-01T00:00:00.000Z|21057                                 |Work Comes First Travelers|9.14               |8.2               |Work Comes First Travelers: 8.26 |Las Vegas Trip Planners: 7.21    |
|2018-11-01T00:00:00.000Z|21057                                 |Work Comes First Travelers|8.28               |8.56              |Work Comes First Travelers: 9.14 |Work Comes First Travelers: 8.26 |
|2018-12-01T00:00:00.000Z|21057                                 |Work Comes First Travelers|8.31               |8.58              |Work Comes First Travelers: 8.28 |Work Comes First Travelers: 9.14 |
|2019-01-01T00:00:00.000Z|21057                                 |Work Comes First Travelers|7.66               |8.08              |Work Comes First Travelers: 8.31 |Work Comes First Travelers: 8.28 |
|2019-02-01T00:00:00.000Z|21057                                 |Work Comes First Travelers|7.66               |7.88              |Work Comes First Travelers: 7.66 |Work Comes First Travelers: 8.31 |
|2019-03-01T00:00:00.000Z|7541                                  |Alabama Trip Planners|6.54               |7.29              |Work Comes First Travelers: 7.66 |Work Comes First Travelers: 7.66 |
|2019-04-01T00:00:00.000Z|6065                                  |Solar Energy Researchers|6.28               |6.83              |Alabama Trip Planners: 6.54      |Work Comes First Travelers: 7.66 |
|2019-05-01T00:00:00.000Z|21245                                 |Readers of Honduran Content|4.41               |5.74              |Solar Energy Researchers: 6.28   |Alabama Trip Planners: 6.54      |
|2019-06-01T00:00:00.000Z|6324                                  |Las Vegas Trip Planners|2.77               |4.49              |Readers of Honduran Content: 4.41|Solar Energy Researchers: 6.28   |
|2019-07-01T00:00:00.000Z|6324                                  |Las Vegas Trip Planners|2.82               |3.33              |Las Vegas Trip Planners: 2.77    |Readers of Honduran Content: 4.41|
|2019-08-01T00:00:00.000Z|4898                                  |Cosmetics and Beauty Shoppers|2.73               |2.77              |Las Vegas Trip Planners: 2.82    |Las Vegas Trip Planners: 2.77    |

