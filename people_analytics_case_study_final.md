# People Analytics Case Study Final Solution

## Problem
We have been tasked by HR Analytica to generate reusable data assets to power 2 of their client HR analytics tools.

We’ve also been asked specifically to generate database views that HR Analytica team can use for 2 key dashboards, reporting solutions and ad-hoc analytics requests.

Additionally - we’ve been alerted to the presence of date issues with our datasets where there were data-entry issues related to all DATE related fields - we will need to incorporate the fixes as we compile our solution.

## Required Insights

### Current Data - Company Level

For all following metrics - we need a current snapshot of all the data as well as a split by gender specifically:

- Total number of employees
- Average company tenure in years
- Average latest payrise percentage
- Statistical metrics for salary values including:
    * MIN, MAX, STDDEV, Inter-quartile range and median

### Current Data - Department Level
For all following metrics - we need a current snapshot of all the data as well as a split by gender specifically:

- Total number of employees per department
- Average department tenure in years
- Average latest payrise percentage per department
- Statistical metrics for salary values including per department:
    * MIN, MAX, STDDEV, Inter-quartile range and median

### Current Data - Title Level
For all following metrics - we need a current snapshot of all the data as well as a split by gender specifically:

- Total number of employees per title
- Average title tenure in years
- Average latest payrise percentage per title
- Statistical metrics for salary values including per title:
    * MIN, MAX, STDDEV, Inter-quartile range and median


### Historic Data - Employee Deep Dive
The following insights must be generated for the Employee Deep Dive tool that can spotlight recent events for a single employee over time:

- See all the various employment history ordered by effective date including salary, department, manager and title changes
- Calculate previous historic payrise percentages and value changes
- Calculate the previous position and department history in months with start and end dates
- Compare an employee’s current salary, total company tenure, department, position and gender to the average benchmarks for their current position

## Data Exploration
Since we’ve been alerted to the presence of data issues for all date related fields - we will need to inspect each table to see what adjustments we need to make.

Additionally - we will start profiling all of our available tables to see how we can join them for our complete analytical solution.

From our initial inspection of the ERD - it also seems like there are slow changing dimension tables as we can see from_date and to_date columns for some tables.

### Inspecting Columns

1. General Overview of all tables (here example with employee)
```sql
SELECT 
   table_name, 
   column_name, 
   data_type 
FROM 
   information_schema.columns
WHERE 
   table_name = 'employee';
```
|table_name|column_name|data_type        |
|----------|-----------|-----------------|
|employee  |id         |bigint           |
|employee  |birth_date |date             |
|employee  |first_name |character varying|
|employee  |last_name  |character varying|
|employee  |gender     |USER-DEFINED     |
|employee  |hire_date  |date             |
|employee  |id         |bigint           |
|employee  |birth_date |timestamp without time zone|
|employee  |first_name |character varying|
|employee  |last_name  |character varying|
|employee  |gender     |USER-DEFINED     |
|employee  |hire_date  |timestamp without time zone|


2. Table Indexes
```sql
SELECT *
FROM pg_indexes
WHERE schemaname = 'employees';
```
There are unique indexes on most tables.
The following tables seem to have unique indexes on a single column:

`employees.employee`
`employees.department`

The rest of the tables seem to have multiple records for the employee_id values based off the indexes:

`employees.department_employee`
`employees.department_manager`
`employees.salary`
`employees.title`

3. Individual Table Analysis
Viewing some data from all tables (here example employee table)
```sql
SELECT *
FROM employees.employee
LIMIT 5;
```
Confirm that there is indeed only a single record per employee:
```sql
WITH id_cte AS(
SELECT
id,
COUNT(*) AS row_count
FROM employees.employee
GROUP BY id)
SELECT
row_count,
COUNT(*) AS num_ids_with_count
FROM id_cte
GROUP BY row_count;
```
|row_count|num_ids_with_count|
|----------|-----------|
|1  |300024         |

There are probably more employees in the table then there are current employees in the company as there should be some churn. This will need to be adressed later on, when getting the current company data.

### Initial Insights:

- There is the issue with the dates where our young unlucky intern accidentally input the year which is 18 years behind what it should be.

- The historical tables all have `from_date` and `to_date` records which signal some sort of historical slow changing dimension style table.

- In `title`, `salary`,`department_employee`, `department_manager` the `to_date` is  **9999-01-01** if the timespan has not yet ended.

- There are 9 Departments with a direct mapping to the department_ids in `department_employee`.

- there is a one-to-many relationship between employee and (salary,title, department_employee)

## Analysis
For our complete solution we will need to split up components into the following parts:

1. Data Cleaning & Date Adjustments
2. Current Data Analysis
3. Historical Analysis (employee deep dive)

The key aspect of our entire SQL analysis will be to generate a completely reusable data asset in the form of multiple analytical views for the HR Analytica team to consume.

All of our analytical outputs will be generated in an entirely new view schema called `mv_employees` which will be refered to throughout the SQL code snippets and the final complete SQL script.

### Data Cleaning
Let’s first start with the data cleaning component to adjust the dates and fix the date data issues.
We will be incrementing all of the date fields except the arbitrary end date of 9999-01-01 - we will also need to cast our results back to a DATE data type as PostgreSQL interval addition forces the data type to a TIMESTAMP which we’d like to avoid to keep our data as similar to the original as possible.

To account for future updates and to maximise the efficiency and productivity for the HR Analytica team - we will be implementing our adjusted datasets as materialized views with exact original indexes as per the original tables in the employees schema.

```sql
DROP SCHEMA IF EXISTS mv_employees CASCADE;
CREATE SCHEMA mv_employees;

-- department
DROP MATERIALIZED VIEW IF EXISTS mv_employees.department;
CREATE MATERIALIZED VIEW mv_employees.department AS
SELECT * FROM employees.department;


-- department employee
DROP MATERIALIZED VIEW IF EXISTS mv_employees.department_employee;
CREATE MATERIALIZED VIEW mv_employees.department_employee AS
SELECT
  employee_id,
  department_id,
  (from_date + interval '18 years')::DATE AS from_date,
  CASE
    WHEN to_date <> '9999-01-01' THEN (to_date + interval '18 years')::DATE
    ELSE to_date
    END AS to_date
FROM employees.department_employee;

-- department manager
DROP MATERIALIZED VIEW IF EXISTS mv_employees.department_manager;
CREATE MATERIALIZED VIEW mv_employees.department_manager AS
SELECT
  employee_id,
  department_id,
  (from_date + interval '18 years')::DATE AS from_date,
  CASE
    WHEN to_date <> '9999-01-01' THEN (to_date + interval '18 years')::DATE
    ELSE to_date
    END AS to_date
FROM employees.department_manager;

-- employee
DROP MATERIALIZED VIEW IF EXISTS mv_employees.employee;
CREATE MATERIALIZED VIEW mv_employees.employee AS
SELECT
  id,
  (birth_date + interval '18 years')::DATE AS birth_date,
  first_name,
  last_name,
  gender,
  (hire_date + interval '18 years')::DATE AS hire_date
FROM employees.employee;

-- salary
DROP MATERIALIZED VIEW IF EXISTS mv_employees.salary;
CREATE MATERIALIZED VIEW mv_employees.salary AS
SELECT
  employee_id,
  amount,
  (from_date + interval '18 years')::DATE AS from_date,
  CASE
    WHEN to_date <> '9999-01-01' THEN (to_date + interval '18 years')::DATE
    ELSE to_date
    END AS to_date
FROM employees.salary;

-- title
DROP MATERIALIZED VIEW IF EXISTS mv_employees.title;
CREATE MATERIALIZED VIEW mv_employees.title AS
SELECT
  employee_id,
  title,
  (from_date + interval '18 years')::DATE AS from_date,
  CASE
    WHEN to_date <> '9999-01-01' THEN (to_date + interval '18 years')::DATE
    ELSE to_date
    END AS to_date
FROM employees.title;

-- Index Creation
-- NOTE: we do not name the indexes as they will be given randomly upon creation!
CREATE UNIQUE INDEX ON mv_employees.employee USING btree (id);
CREATE UNIQUE INDEX ON mv_employees.department_employee USING btree (employee_id, department_id);
CREATE INDEX        ON mv_employees.department_employee USING btree (department_id);
CREATE UNIQUE INDEX ON mv_employees.department USING btree (id);
CREATE UNIQUE INDEX ON mv_employees.department USING btree (dept_name);
CREATE UNIQUE INDEX ON mv_employees.department_manager USING btree (employee_id, department_id);
CREATE INDEX        ON mv_employees.department_manager USING btree (department_id);
CREATE UNIQUE INDEX ON mv_employees.salary USING btree (employee_id, from_date);
CREATE UNIQUE INDEX ON mv_employees.title USING btree (employee_id, title, from_date);
```

### Current Data Analysis
For our current company, department and title level dashboard outputs we will first create a current snapshot view which we will use as the base for each of the aggregated layers for the different dashboard outputs.
Let’s start by listing out the steps we need to include for our granular current snapshot:

1. Apply LAG window functions on the salary materialized view to obtain the latest previous_salary value, keeping only current valid records with to_date = '9999-01-01'
2. Join previous salary and all other required information from the materialized views for the dashboard analysis (omitting the department_manager view)
3. Apply WHERE filter to keep only current records
4. Make sure to include the gender column from the employee view for all calculations
5. Use the hire_date column from the employee view to calculate the number of tenure years
6. Include the from_date columns from the title and department are included to calculate tenure
7. Use the salary table to calculate the current average salary
8. Include department and title information for additional group by aggregations
9. Implement the various statistical measures for the salary amount
10. Combine all of these elements into a single final current snapshot view

```sql
DROP VIEW IF EXISTS mv_employees.current_employee_snapshot CASCADE;
CREATE VIEW mv_employees.current_employee_snapshot AS
WITH cte_previous_salary AS(
SELECT * FROM (
SELECT 
employee_id,
to_date,
LAG(amount) OVER(
            PARTITION BY employee_id
            ORDER BY from_date)
AS amount
FROM mv_employees.salary
) all_salaries
WHERE to_date = '9999-01-01'),
cte_joined_data AS(
SELECT
employee.id AS employee_id,
employee.gender,
employee.hire_date,
title.title,
salary.amount AS salary,
cte_previous_salary.amount AS previous_salary,
department.dept_name AS department,
title.from_date AS title_from_date,
department_employee.from_date AS department_from_date
FROM mv_employees.employee
INNER JOIN mv_employees.title
  ON employee.id = title.employee_id
INNER JOIN mv_employees.salary
  ON employee.id = salary.employee_id
INNER JOIN cte_previous_salary
  ON employee.id = cte_previous_salary.employee_id
INNER JOIN mv_employees.department_employee
  ON employee.id = department_employee.employee_id
INNER JOIN mv_employees.department
  ON department_employee.department_id = department.id
WHERE salary.to_date = '9999-01-01'
  AND title.to_date = '9999-01-01'
  AND department_employee.to_date = '9999-01-01'),
  final_output AS(
  SELECT
  employee_id,
  gender,
  salary,
  department,
  title,
  ROUND(
      ((salary-previous_salary)/
      previous_salary::NUMERIC)
      * 100, 2) AS salary_percentage_change,
  DATE_PART('year', now()) -
      DATE_PART('year', hire_date) AS company_tenure_years,
  DATE_PART('year', now()) -
      DATE_PART('year', title_from_date) AS title_tenure_years,
  DATE_PART('year', now()) -
      DATE_PART('year', department_from_date) AS department_tenure_years
  FROM cte_joined_data
)
SELECT * FROM final_output;
```
Sample output:
|employee_id|gender    |salary           |department     |title          |salary_percentage_change|company_tenure_years|title_tenure_years|department_tenure_years|
|-----------|----------|-----------------|---------------|---------------|------------------------|--------------------|------------------|-----------------------|
|10001      |M         |88958            |Development    |Senior Engineer|4.54                    |17                  |17                |17                     |
|10002      |F         |72527            |Sales          |Staff          |0.78                    |18                  |7                 |7                      |
|10003      |M         |43311            |Production     |Senior Engineer|-0.89                   |17                  |8                 |8                      |
|10004      |M         |74057            |Production     |Senior Engineer|4.75                    |17                  |8                 |17                     |
|10005      |M         |94692            |Human Resources|Senior Staff   |3.54                    |14                  |7                 |14                     |

#### Dashboard Aggregation Views

1. Company Level

- Total number of employees
- Average company tenure in years
- Average latest payrise percentage
- Statistical metrics for salary values including:
    * MIN, MAX, STDDEV, Inter-quartile range and median
```sql
DROP VIEW IF EXISTS mv_employees.company_level_dashboard;
CREATE VIEW mv_employees.company_level_dashboard AS
SELECT
'all' AS gender,
COUNT(DISTINCT employee_id) AS num_employees,
ROUND(100*COUNT(*)::NUMERIC/SUM(COUNT(*)) OVER()) AS employee_perc,
ROUND(AVG(company_tenure_years)) AS avg_company_tenure,
ROUND(AVG(salary_percentage_change)) AS avg_latest_payrise_percentage,
MIN(salary) AS min_salary,
MAX(salary) AS max_salary,
ROUND(STDDEV(salary)) AS std_salary,
ROUND(PERCENTILE_CONT(0.75) WITHIN GROUP (ORDER BY salary) -
PERCENTILE_CONT(0.25) WITHIN GROUP (ORDER BY salary)) AS iqr_salary,
ROUND(PERCENTILE_CONT(0.5) WITHIN GROUP (ORDER BY salary)) AS median_salary
FROM mv_employees.current_employee_snapshot
UNION 
SELECT
gender::CHAR(3) AS gender,
COUNT(DISTINCT employee_id) AS num_employees,
ROUND(100*COUNT(*)::NUMERIC/SUM(COUNT(*)) OVER()) AS employee_perc,
ROUND(AVG(company_tenure_years)) AS avg_company_tenure,
ROUND(AVG(salary_percentage_change),2) AS avg_latest_payrise_percentage,
MIN(salary) AS min_salary,
MAX(salary) AS max_salary,
ROUND(STDDEV(salary)) AS std_salary,
ROUND(PERCENTILE_CONT(0.75) WITHIN GROUP (ORDER BY salary) -
PERCENTILE_CONT(0.25) WITHIN GROUP (ORDER BY salary)) AS iqr_salary,
ROUND(PERCENTILE_CONT(0.5) WITHIN GROUP (ORDER BY salary)) AS median_salary
FROM mv_employees.current_employee_snapshot
GROUP BY gender;
```

Result:
|gender   |num_employees|employee_perc    |avg_company_tenure|avg_latest_payrise_percentage|min_salary|max_salary|std_salary|iqr_salary|median_salary|
|---------|-------------|-----------------|------------------|-----------------------------|----------|----------|----------|----------|-------------|
|M        |144114       |60               |13                |3.02                         |38623     |158220    |17363     |23624     |69830        |
|F        |96010        |40               |13                |3.03                         |38936     |152710    |17230     |23326     |69764        |
|all      |240124       |100              |13                |3                            |38623     |158220    |17310     |23497     |69805        |


2. Department Level

```sql
DROP VIEW IF EXISTS mv_employees.department_level_dashboard;
CREATE VIEW mv_employees.department_level_dashboard AS
SELECT
'all' AS gender,
department,
COUNT(DISTINCT employee_id) AS num_employees,
ROUND(100*COUNT(*)::NUMERIC/SUM(COUNT(*)) OVER(
        PARTITION BY department)) AS employee_perc,
ROUND(AVG(department_tenure_years)) AS avg_deparment_tenure,
ROUND(AVG(salary_percentage_change)) AS avg_latest_payrise_percentage,
MIN(salary) AS min_salary,
MAX(salary) AS max_salary,
ROUND(STDDEV(salary)) AS std_salary,
ROUND(PERCENTILE_CONT(0.75) WITHIN GROUP (ORDER BY salary) -
PERCENTILE_CONT(0.25) WITHIN GROUP (ORDER BY salary)) AS iqr_salary,
ROUND(PERCENTILE_CONT(0.5) WITHIN GROUP (ORDER BY salary)) AS median_salary
FROM mv_employees.current_employee_snapshot
GROUP BY department
UNION 
SELECT
gender::CHAR(3) AS gender,
department,
COUNT(DISTINCT employee_id) AS num_employees,
ROUND(100*COUNT(*)::NUMERIC/SUM(COUNT(*)) OVER(
        PARTITION BY department)) AS employee_perc,
ROUND(AVG(department_tenure_years)) AS avg_department_tenure,
ROUND(AVG(salary_percentage_change),2) AS avg_latest_payrise_percentage,
MIN(salary) AS min_salary,
MAX(salary) AS max_salary,
ROUND(STDDEV(salary)) AS std_salary,
ROUND(PERCENTILE_CONT(0.75) WITHIN GROUP (ORDER BY salary) -
PERCENTILE_CONT(0.25) WITHIN GROUP (ORDER BY salary)) AS iqr_salary,
ROUND(PERCENTILE_CONT(0.5) WITHIN GROUP (ORDER BY salary)) AS median_salary
FROM mv_employees.current_employee_snapshot
GROUP BY gender, department;
```

Result Sample:
|gender   |department|num_employees    |employee_perc  |avg_deparment_tenure|avg_latest_payrise_percentage|min_salary|max_salary|std_salary|iqr_salary|median_salary|
|---------|----------|-----------------|---------------|--------------------|-----------------------------|----------|----------|----------|----------|-------------|
|F        |Customer Service|7007             |40             |9                   |3.19                         |39812     |144866    |15979     |20450     |65198        |
|all      |Customer Service|17569            |100            |9                   |3                            |39373     |144866    |15944     |20243     |65149        |
|M        |Customer Service|10562            |60             |9                   |3.26                         |39373     |143950    |15921     |20097     |65100        |
|F        |Development|24533            |40             |11                  |3.20                         |39469     |144434    |14149     |19309     |66355        |
|all      |Development|61386            |100            |11                  |3                            |39036     |144434    |14220     |19529     |66450        |

3. Title Level

```sql
DROP VIEW IF EXISTS mv_employees.title_level_dashboard;
CREATE VIEW mv_employees.title_level_dashboard AS
SELECT
'all' AS gender,
title,
COUNT(DISTINCT employee_id) AS num_employees,
ROUND(100*COUNT(*)::NUMERIC/SUM(COUNT(*)) OVER(
        PARTITION BY title)) AS employee_perc,
ROUND(AVG(title_tenure_years)) AS avg_title_tenure,
ROUND(AVG(salary_percentage_change)) AS avg_latest_payrise_percentage,
MIN(salary) AS min_salary,
MAX(salary) AS max_salary,
ROUND(STDDEV(salary)) AS std_salary,
ROUND(PERCENTILE_CONT(0.75) WITHIN GROUP (ORDER BY salary) -
PERCENTILE_CONT(0.25) WITHIN GROUP (ORDER BY salary)) AS iqr_salary,
ROUND(PERCENTILE_CONT(0.5) WITHIN GROUP (ORDER BY salary)) AS median_salary
FROM mv_employees.current_employee_snapshot
GROUP BY title
UNION 
SELECT
gender::CHAR(3) AS gender,
title,
COUNT(DISTINCT employee_id) AS num_employees,
ROUND(100*COUNT(*)::NUMERIC/SUM(COUNT(*)) OVER(
        PARTITION BY title)) AS employee_perc,
ROUND(AVG(title_tenure_years)) AS avg_title_tenure,
ROUND(AVG(salary_percentage_change),2) AS avg_latest_payrise_percentage,
MIN(salary) AS min_salary,
MAX(salary) AS max_salary,
ROUND(STDDEV(salary)) AS std_salary,
ROUND(PERCENTILE_CONT(0.75) WITHIN GROUP (ORDER BY salary) -
PERCENTILE_CONT(0.25) WITHIN GROUP (ORDER BY salary)) AS iqr_salary,
ROUND(PERCENTILE_CONT(0.5) WITHIN GROUP (ORDER BY salary)) AS median_salary
FROM mv_employees.current_employee_snapshot
GROUP BY gender, title;
```

Result Sample:
|gender   |title     |num_employees    |employee_perc  |avg_title_tenure|avg_latest_payrise_percentage|min_salary|max_salary|std_salary|iqr_salary|median_salary|
|---------|----------|-----------------|---------------|----------------|-----------------------------|----------|----------|----------|----------|-------------|
|all      |Assistant Engineer|3588             |100            |6               |4                            |39469     |117636    |11013     |14965     |54779        |
|F        |Assistant Engineer|1440             |40             |6               |3.84                         |39469     |106340    |10805     |14679     |55234        |
|M        |Assistant Engineer|2148             |60             |6               |3.75                         |39827     |117636    |11152     |14972     |54384        |
|M        |Engineer  |18571            |60             |6               |3.59                         |38942     |130939    |12416     |17311     |56941        |
|F        |Engineer  |12412            |40             |6               |3.61                         |39519     |115444    |12211     |17223     |57220        |


### Historic Employee Analysis

For the historic employee deep dive analysis - we will need to split up our interim outputs into 3 parts:

1. Current Employee Information

- Full name
- Gender
- Birthday
- Department
- Title/Position tenure
- Company tenure
- Current salary
- Latest salary change percentage
- Manager name

```sql
-- 1. Replace the view with an updated version with manager info
CREATE OR REPLACE VIEW mv_employees.current_employee_snapshot AS
WITH cte_previous_salary AS(
SELECT * FROM (
SELECT 
employee_id,
to_date,
LAG(amount) OVER(
            PARTITION BY employee_id
            ORDER BY from_date)
AS amount
FROM mv_employees.salary
) all_salaries
WHERE to_date = '9999-01-01'),
cte_joined_data AS(
SELECT
employee.id AS employee_id,
employee.gender,
employee.hire_date,
title.title,
salary.amount AS salary,
cte_previous_salary.amount AS previous_salary,
department.dept_name AS department,
title.from_date AS title_from_date,
department_employee.from_date AS department_from_date,
CONCAT(employee.first_name, ' ', employee.last_name) AS full_name,
employee.birth_date,
CONCAT(managers.first_name, ' ', managers.last_name) AS manager_name
FROM mv_employees.employee
INNER JOIN mv_employees.title
  ON employee.id = title.employee_id
INNER JOIN mv_employees.salary
  ON employee.id = salary.employee_id
INNER JOIN cte_previous_salary
  ON employee.id = cte_previous_salary.employee_id
INNER JOIN mv_employees.department_employee
  ON employee.id = department_employee.employee_id
INNER JOIN mv_employees.department
  ON department_employee.department_id = department.id
INNER JOIN mv_employees.department_manager
  ON department.id = department_manager.department_id
INNER JOIN mv_employees.employee AS managers
  ON department_manager.employee_id = managers.id
WHERE salary.to_date = '9999-01-01'
  AND title.to_date = '9999-01-01'
  AND department_employee.to_date = '9999-01-01'
  AND department_manager.to_date = '9999-01-01'),
final_output AS(
  SELECT
  employee_id,
  gender,
  salary,
  department,
  title,
  ROUND(
      ((salary-previous_salary)/
      previous_salary::NUMERIC)
      * 100, 2) AS salary_percentage_change,
  DATE_PART('year', now()) -
      DATE_PART('year', hire_date) AS company_tenure_years,
  DATE_PART('year', now()) -
      DATE_PART('year', title_from_date) AS title_tenure_years,
  DATE_PART('year', now()) -
      DATE_PART('year', department_from_date) AS department_tenure_years,
  full_name,
  birth_date,
  manager_name
  FROM cte_joined_data
)
SELECT * FROM final_output;
```

2. Salary comparison to various benchmarks including:

- Company tenure
- Title/Position
- Department
- Gender

Create Benchmarks:

```sql
-- 2. Generate benchmark views for company tenure, gender, department and title
-- Note the slightly verbose column names - this helps us avoid renaming later!
DROP VIEW IF EXISTS mv_employees.tenure_benchmark;
CREATE VIEW mv_employees.tenure_benchmark AS
SELECT
company_tenure_years,
AVG(salary) AS tenure_benchmark_salary
FROM  mv_employees.current_employee_snapshot
GROUP BY company_tenure_years;

DROP VIEW IF EXISTS mv_employees.title_benchmark;
CREATE VIEW mv_employees.title_benchmark AS
SELECT
title,
AVG(salary) AS title_benchmark_salary
FROM mv_employees.current_employee_snapshot
GROUP BY title;

DROP VIEW IF EXISTS mv_employees.department_benchmark;
CREATE VIEW mv_employees.department_benchmark AS
SELECT
department,
AVG(salary) AS department_benchmark_salary
FROM mv_employees.current_employee_snapshot
GROUP BY department;

DROP VIEW IF EXISTS mv_employees.gender_benchmark;
CREATE VIEW mv_employees.gender_benchmark AS
SELECT
gender,
AVG(salary) AS gender_benchmark_salary
FROM mv_employees.current_employee_snapshot
GROUP BY gender;
```

3. The last 5 historical employee events categorised into:

- Salary increase/decrease
- Department transfer
- Manager reporting line change
- Title changes

```sql

-- historic data
DROP VIEW IF EXISTS mv_employees.historic_employee_records CASCADE;
CREATE VIEW mv_employees.historic_employee_records AS
WITH cte_previous_salary AS(
SELECT * FROM (
SELECT 
employee_id,
to_date,
LAG(amount) OVER(
            PARTITION BY employee_id
            ORDER BY from_date)
AS amount,
ROW_NUMBER() OVER(PARTITION BY employee_id 
ORDER BY to_date DESC) AS record_rank
FROM mv_employees.salary
) all_salaries
WHERE record_rank = 1),
cte_joined_data AS(
SELECT
employee.id AS employee_id,
employee.gender,
CONCAT(employee.first_name, ' ', employee.last_name) AS full_name,
employee.birth_date,
DATE_PART('year', NOW()) - DATE_PART('year', employee.birth_date) AS employee_age,
CONCAT(managers.first_name, ' ', managers.last_name) AS manager_name,
employee.hire_date,
title.title,
salary.amount AS salary,
cte_previous_salary.amount AS previous_latest_salary,
department.dept_name AS department,
title.from_date AS title_from_date,
department_employee.from_date AS department_from_date,
DATE_PART('year', now()) -
      DATE_PART('year', employee.hire_date) AS company_tenure_years,
DATE_PART('year', now()) -
      DATE_PART('year', title.from_date) AS title_tenure_years,
DATE_PART('year', now()) -
      DATE_PART('year', department_employee.from_date) AS department_tenure_years,
DATE_PART('month',AGE(NOW(),title.from_date)) AS title_tenure_months,
  GREATEST(
    title.from_date,
    salary.from_date,
    department_employee.from_date,
    department_manager.from_date
  ) AS effective_date,
  LEAST(
    title.to_date,
    salary.to_date,
    department_employee.to_date,
    department_manager.to_date
  ) AS expiry_date
FROM mv_employees.employee AS employee
INNER JOIN mv_employees.title
  ON employee.id = title.employee_id
INNER JOIN mv_employees.salary
  ON employee.id = salary.employee_id
INNER JOIN cte_previous_salary
  ON employee.id = cte_previous_salary.employee_id
INNER JOIN mv_employees.department_employee
  ON employee.id = department_employee.employee_id
INNER JOIN mv_employees.department
  ON department_employee.department_id = department.id
INNER JOIN mv_employees.department_manager
  ON department.id = department_manager.department_id
INNER JOIN mv_employees.employee AS managers
  ON department_manager.employee_id = managers.id
),
-- filter out top 5 events
cte_ordered_transactions AS(
  SELECT
  employee_id,
  birth_date,
  employee_age,
  gender,
  hire_date,
  salary,
  previous_latest_salary,
  LAG(salary) OVER w AS previous_salary,
  department,
  LAG(department) OVER w AS previous_department,
  title,
  LAG(title) OVER w AS previous_title,
  full_name,
  manager_name,
  LAG(manager_name) OVER w AS previous_manager,
  company_tenure_years,
  title_tenure_years,
  title_tenure_months,
  department_tenure_years,
  effective_date,
  expiry_date,
  ROW_NUMBER() OVER(PARTITION BY employee_id
  ORDER BY effective_date DESC) AS event_order
  FROM cte_joined_data
  -- remove all invalid records which occurred in join
  WHERE effective_date <= expiry_date
  WINDOW w AS (PARTITION BY employee_id ORDER BY effective_date)
  ),
  -- apply CASE statement to generate events
  -- generate benchmark comparisons
  final_output AS (
  SELECT
  base.employee_id,
  base.gender,
  base.birth_date,
  base.employee_age,
  base.hire_date,
  base.title,
  base.full_name,
  base.previous_title,
  base.salary,
    -- previous latest salary is based off the CTE
  previous_latest_salary,
  -- previous salary is based off the LAG records
  base.previous_salary,
  base.department,
  base.previous_department,
  base.manager_name,
  base.previous_manager,
    -- tenure metrics
  base.company_tenure_years,
  base.title_tenure_years,
  base.title_tenure_months,
  base.department_tenure_years,
  base.event_order,
    -- only include the latest salary change for the first event_order row
  CASE
      WHEN event_order = 1
        THEN ROUND(
          100 * (base.salary - base.previous_latest_salary) /
            base.previous_latest_salary::NUMERIC,
          2
        )
      ELSE NULL
    END AS latest_salary_percentage_change,
    -- event type logic by comparing all of the previous lag records
    CASE
      WHEN base.previous_salary < base.salary
        THEN 'Salary Increase'
      WHEN base.previous_salary > base.salary
        THEN 'Salary Decrease'
      WHEN base.previous_department <> base.department
        THEN 'Dept Transfer'
      WHEN base.previous_manager <> base.manager_name
        THEN 'Reporting Line Change'
      WHEN base.previous_title <> base.title
        THEN 'Title Change'
      ELSE NULL
    END AS event_name,
    -- salary change
    ROUND(base.salary - base.previous_salary) AS salary_amount_change,
    ROUND(
      100 * (base.salary - base.previous_salary) / base.previous_salary::NUMERIC,
      2
    ) AS salary_percentage_change,
    --benchmark comparisions
    ROUND(tenure_benchmark_salary) AS tenure_benchmark_salary,
    ROUND(100* (base.salary - tenure_benchmark_salary)
    /tenure_benchmark_salary::NUMERIC) AS tenure_comparison,
    -- title
    ROUND(title_benchmark_salary) AS title_benchmark_salary,
    ROUND(
      100 * (base.salary - title_benchmark_salary)
        / title_benchmark_salary::NUMERIC
    ) AS title_comparison,
    -- department
    ROUND(department_benchmark_salary) AS department_benchmark_salary,
    ROUND(
      100 * (salary - department_benchmark_salary)
        / department_benchmark_salary::NUMERIC
    ) AS department_comparison,
    -- gender
    ROUND(gender_benchmark_salary) AS gender_benchmark_salary,
    ROUND(
      100 * (base.salary - gender_benchmark_salary)
        / gender_benchmark_salary::NUMERIC
    ) AS gender_comparison,
    base.effective_date,
    base.expiry_date
  FROM cte_ordered_transactions AS base
  INNER JOIN mv_employees.tenure_benchmark
    ON base.company_tenure_years = tenure_benchmark.company_tenure_years
  INNER JOIN mv_employees.title_benchmark
    ON base.title = title_benchmark.title
  INNER JOIN mv_employees.department_benchmark
    ON base.department = department_benchmark.department
  INNER JOIN mv_employees.gender_benchmark
    ON base.gender = gender_benchmark.gender
  )
SELECT * FROM final_output;

-- This final view powers the employee deep dive tool
-- by keeping only the 5 latest events
DROP VIEW IF EXISTS mv_employees.employee_deep_dive;
CREATE VIEW mv_employees.employee_deep_dive AS
SELECT *
FROM mv_employees.historic_employee_records
WHERE event_order <= 5;
```

**Further Simplified Employee Events**
We can also further reduce the above deep dive output into 2 separate views to simplify the data outputs required for the deep dive employee tool:

1. Current employee and salary benchmark details
```sql
SELECT
  employee_id,
  employee_name,
  UPPER(title || ' - ' || department) AS line_1,
  CASE
    WHEN gender = 'M'
      THEN UPPER('MALE ' || employee_age || ', BIRTHDAY ' || birth_date)
    ELSE UPPER('FEMALE ' || employee_age || ', BIRTHDAY ' || birth_date)
    END AS line_2,
  title_tenure_months,
  company_tenure_years,
  TO_CHAR(salary, '$FM999,999,999') AS salary,
  latest_salary_percentage_change,
  manager,
  -- salary benchmark values
  TO_CHAR(tenure_benchmark_salary, '$FM999,999,999') AS tenure_benchmark_salary,
  tenure_comparison,
  TO_CHAR(title_benchmark_salary, '$FM999,999,999') AS title_benchmark_salary,
  title_comparison,
  TO_CHAR(department_benchmark_salary, '$FM999,999,999') AS department_benchmark_salary,
  department_comparison,
  TO_CHAR(gender_benchmark_salary, '$FM999,999,999') AS gender_benchmark_salary,
  gender_comparison
FROM mv_employees.employee_deep_dive
WHERE employee_name = 'Leah Anguita'
  AND event_order = 1;
  ```
2. Latest 5 historic employee events with detailed event info
```sql
SELECT
  employee_id,
  event_order,
  event_name,
  CASE
    WHEN event_name IN ('Salary Increase', 'Salary Decrease')
      THEN 'New salary: ' || TO_CHAR(salary, '$FM999,999,999')
    WHEN event_name = 'Dept Transfer'
      THEN 'To: ' || department
    WHEN event_name = 'Reporting Line Change'
      THEN 'New manager: ' || manager
    WHEN event_name = 'Title Change'
      THEN 'To: ' || title
  END AS line_1,
  CASE
    WHEN event_name = 'Salary Increase'
      THEN 'Increase: ' || TO_CHAR(salary_amount_change, '$FM999,999,999') ||
        ' (+' || ROUND(salary_percentage_change::NUMERIC, 1) || ' %)'
    WHEN event_name = 'Salary Decrease'
      THEN 'Decrease: ' || TO_CHAR(salary_amount_change, '$FM999,999,999') ||
        ' (' || ROUND(salary_percentage_change::NUMERIC, 1) || ' %)'
    WHEN event_name = 'Dept Transfer'
      THEN 'From: ' || previous_department
    WHEN event_name = 'Reporting Line Change'
      THEN 'Previous manager: ' || previous_manager
    WHEN event_name = 'Title Change'
      THEN 'To: ' || previous_title
  END AS line_2,
  effective_date AS event_date
FROM mv_employees.employee_deep_dive
WHERE employee_name = 'Leah Anguita'
ORDER BY event_order;
```