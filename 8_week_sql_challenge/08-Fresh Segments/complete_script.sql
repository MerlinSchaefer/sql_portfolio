-- inspect data
SELECT 
   table_name, 
   column_name, 
   data_type 
FROM 
   information_schema.columns
WHERE 
   table_schema = 'fresh_segments'
ORDER BY table_name;

SELECT
  *
FROM
  fresh_segments.interest_map
LIMIT
  10;

SELECT
  *
FROM
  fresh_segments.interest_metrics
LIMIT
  10;

SELECT
  COUNT(*)
FROM
  fresh_segments.interest_metrics;

SELECT
  COUNT(*)
FROM
  fresh_segments.interest_map;

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

-- Count of entries in the table

SELECT
  COUNT(*)
FROM
  fresh_segments.interest_metrics;

SELECT
  COUNT(*)
FROM
  fresh_segments.interest_map;

-- NULL Values

SELECT
  *
FROM
  fresh_segments.interest_map
WHERE
  id IS NULL;
  
SELECT
  *
FROM
  fresh_segments.interest_metrics
WHERE
  interest_id IS NULL;

-- q1.1
UPDATE fresh_segments.interest_metrics
SET month_year = TO_DATE(month_year, 'MM-YYYY');

ALTER TABLE fresh_segments.interest_metrics
ALTER month_year TYPE DATE USING month_year::DATE;

-- q1.2 
SELECT
month_year,
COUNT(*) AS records
FROM fresh_segments.interest_metrics
GROUP BY month_year
ORDER BY month_year NULLS FIRST;

-- q1.3
DROP TABLE IF EXISTS interest_metrics_clean;
CREATE TEMP TABLE interest_metrics_clean AS
SELECT 
  *
FROM 
  fresh_segments.interest_metrics
WHERE interest_id IS NOT NULL;

-- q1.4
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

  -- q1.5
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

-- q1.6 (text only)
-- q1.7
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

-- q2.1
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

-- q2.2
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

-- q2.3
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

-- q3.1 
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

-- q3.2
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

-- q3.3 
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

-- q3.4
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

-- q4.1
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

 -- q4.2
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

  -- q4.3
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

-- q4.4
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