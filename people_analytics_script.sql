-- start with materialized views and correcting data
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
