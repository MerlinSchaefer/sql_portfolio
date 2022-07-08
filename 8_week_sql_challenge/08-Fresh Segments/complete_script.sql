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

