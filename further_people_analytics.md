# Further People Analytics

## Current Analysis

1. What is the full name of the employee with the highest salary?
```sql
SELECT 
*
FROM mv_employees.current_employee_snapshot
ORDER BY salary DESC
LIMIT 1;
```
- Tokuyasu Pesch

2. How many current employees have the equal longest time in their current positions?
```sql
SELECT 
title_tenure_years,
COUNT(*) AS num_employees_with_tenure
FROM mv_employees.current_employee_snapshot
WHERE title_tenure_years = (SELECT MAX(title_tenure_years)
                            FROM mv_employees.current_employee_snapshot)
GROUP BY title_tenure_years;
```
- 3505

3. Which department has the least number of current employees?
```sql
SELECT 
department,
COUNT(*) AS num_employees
FROM mv_employees.current_employee_snapshot
GROUP BY department
ORDER BY num_employees
LIMIT 1;
```
- Finance, 12437

4. What is the largest difference between minimum and maximum salary values for all current employees?
```sql
SELECT 
MIN(salary) AS min_salary,
MAX(salary) AS max_salary,
MAX(salary) - MIN(salary) AS max_difference_salary
FROM mv_employees.current_employee_snapshot;
```
- 119597

5. How many male employees are above the average salary value for the Production department?
```sql
SELECT
COUNT(DISTINCT employee_id)
FROM mv_employees.current_employee_snapshot
WHERE department = 'Production'
AND gender = 'M'
AND salary > (SELECT
              AVG(salary)
              FROM  mv_employees.current_employee_snapshot
              WHERE department = 'Production');
```
- 14999
6. Which title has the highest average salary for male employees?
```sql
SELECT
title,
ROUND(AVG(salary),2) AS avg_salary
FROM mv_employees.current_employee_snapshot
WHERE gender = 'M'
GROUP BY title
ORDER BY avg_salary DESC
LIMIT 1;
```
- Senior Staff, 80735.48

7. Which department has the highest average salary for female employees?
```sql
SELECT
department,
ROUND(AVG(salary),2) AS avg_salary
FROM mv_employees.current_employee_snapshot
WHERE gender = 'F'
GROUP BY department
ORDER BY avg_salary DESC
LIMIT 1;
```
- Sales, 88835.96

8. Which department has the most female employees?
```sql
SELECT
department,
COUNT(DISTINCT employee_id) AS num_employees
FROM mv_employees.current_employee_snapshot
WHERE gender = 'F'
GROUP BY department
ORDER BY num_employees DESC
LIMIT 1;
```
- Development, 24533

9. What is the gender ratio in the department which has the highest average male salary and what is the average male salary value for that department?
```sql
WITH dept_highest_m_salary AS(
SELECT
department,
AVG(salary) AS avg_salary
FROM mv_employees.current_employee_snapshot
WHERE gender = 'M'
GROUP BY department
ORDER BY avg_salary DESC
LIMIT 1)
SELECT 
gender,
department,
ROUND(100 * (COUNT(*)/SUM(COUNT(*)) OVER())),
ROUND(AVG(salary),2) AS avg_salary
FROM mv_employees.current_employee_snapshot
WHERE department = (SELECT department FROM dept_highest_m_salary)
GROUP BY gender,department;
```
|gender|department|round|avg_salary|
|------|----------|-----|----------|
|M     |Sales     |60   |88864.20  |
|F     |Sales     |40   |88835.96  |


10. HR Analytica want to change the average salary increase percentage value to 2 decimal places - what will the new value be for males for the company level dashboard?

**was already implemented by me in first dashboard version**
```sql
SELECT
*
FROM mv_employees.company_level_dashboard
WHERE gender = 'M';
```
- 3.02

## Employee Churn

HR Analytica want to perform an employee churn analysis and wants you to help them answer the following questions using your generated views:

1. How many employees have left the company?
```sql
SELECT
  COUNT(*) AS churn_employee_count
FROM mv_employees.historic_employee_records
WHERE event_order = 1
AND expiry_date != '9999-01-01';s;
```
-59910

2. What percentage of churn employees were male?
```sql
WITH calculations_cte AS (
  SELECT
    gender,
    ROUND(100 * COUNT(*) / (SUM(COUNT(*)) OVER ())::NUMERIC) AS churn_percentage
  FROM mv_employees.historic_employee_records
  WHERE
    event_order = 1
    AND expiry_date != '9999-01-01'
  GROUP BY gender
)
SELECT
  churn_percentage
FROM calculations_cte
WHERE gender = 'M';
```
- ~60%
3. Which title had the most churn?
```sql
SELECT
title,
COUNT(DISTINCT employee_id) AS num_employees,
100 * COUNT(DISTINCT employee_id)/
    SUM(COUNT(DISTINCT employee_id)) OVER() 
AS perc_employees
FROM mv_employees.historic_employee_records
WHERE 
  event_order = 1
  AND expiry_date != '9999-01-01'
GROUP BY title
ORDER BY num_employees DESC;
```
- Engineer

4. Which department had the most churn?
```sql

SELECT
department,
COUNT(DISTINCT employee_id) AS num_employees,
100 * COUNT(DISTINCT employee_id)/
    SUM(COUNT(DISTINCT employee_id)) OVER() 
AS perc_employees
FROM mv_employees.historic_employee_records
WHERE record_order = 1 
    AND expiry_date != '9999-01-01'
GROUP BY department
ORDER BY num_employees DESC;
```
- Development

5. Which year had the most churn?
```sql
SELECT
  EXTRACT(YEAR FROM expiry_date) AS churn_year,
  COUNT(*) AS churn_employee_count
FROM mv_employees.historic_employee_records
WHERE
  event_order = 1
  AND expiry_date != '9999-01-01'
GROUP BY churn_year
ORDER BY churn_employee_count DESC;
```

- 2018

6. What was the average salary for each employee who has left the company?
```sql
SELECT
AVG(salary) AS average_salary
FROM mv_employees.historic_employee_records
WHERE event_order = 1
  AND expiry_date != '9999-01-01';
```

- 61577 (61574?)

7. What was the median total company tenure for each churn employee just before they left?
```sql
SELECT
ROUND(PERCENTILE_CONT(0.5) 
WITHIN GROUP (ORDER BY company_tenure_years)) AS median_tenure
FROM mv_employees.employee_deep_dive
WHERE event_order = 1
  AND expiry_date != '9999-01-01';
```

- 14

8. On average, how many different titles did each churn employee hold?
```sql
WITH churn_employees_cte AS (
  SELECT
    employee_id
  FROM mv_employees.historic_employee_records
  WHERE
    event_order = 1
    AND expiry_date != '9999-01-01'
),
title_count_cte AS (
SELECT
  employee_id,
  COUNT(DISTINCT title) AS title_count
FROM mv_employees.historic_employee_records AS t1
WHERE EXISTS (
  SELECT 1
  FROM churn_employees_cte
  WHERE historic_employee_records.employee_id = churn_employees_cte.employee_id
)
GROUP BY employee_id
)
SELECT
  AVG(title_count) AS average_title_count
FROM title_count_cte;
```
- 1.2

9. What was the average last pay increase for churn employees?
```sql
SELECT
  AVG(latest_salary_amount_change) AS avg_latest_pay_change
FROM mv_employees.historic_employee_records
WHERE
  event_order = 1
  AND expiry_date != '9999-01-01'
  -- we're only interested in the last increase not the decreases!
  AND latest_salary_amount_change > 0;
```
- 2254 

10. What proportion of churn employees had a pay decrease event in their last 5 events?
```sql
WITH churned_employees_decrease AS(                          
SELECT
  COUNT(DISTINCT employee_id) AS num_emp_decrease
FROM mv_employees.employee_deep_dive
WHERE employee_id NOT IN (SELECT employee_id 
                          FROM mv_employees.current_employee_snapshot)
AND event_name = 'Salary Decrease'),
churned_employees AS(
SELECT
  COUNT(DISTINCT employee_id) AS num_emp_churned
FROM mv_employees.employee_deep_dive
WHERE employee_id NOT IN (SELECT employee_id 
                          FROM mv_employees.current_employee_snapshot))
SELECT 
num_emp_churned,
num_emp_decrease,
num_emp_decrease/num_emp_churned::NUMERIC AS prop_churned_decrease
FROM churned_employees_decrease
CROSS JOIN  churned_employees;
```

- 0.24, 24%





## Management Analysis
The HR Analytica team also want to perform a management analysis and need answers for these questions:

1. How many managers are there currently in the company?
```sql
SELECT
*
FROM mv_employees.title_level_dashboard
WHERE gender = 'all' 
AND title = 'Manager';
```
- 9
2. How many employees have ever been a manager?
```sql
SELECT
COUNT(DISTINCT employee_id)
FROM mv_employees.historic_employee_records
WHERE title = 'Manager';
```
or
```sql
SELECT
  COUNT(DISTINCT employee_id) AS total_manager_count
FROM mv_employees.title
WHERE
  title = 'Manager';
```
- 24
3. On average - how long did it take for an employee to first become a manager from their the date they were originally hired in days?
```sql
WITH manager_cte AS (
  SELECT
    employee_id,
    MIN(from_date) AS first_appointment_date
  FROM mv_employees.title
  WHERE title = 'Manager'
  GROUP BY employee_id
)
SELECT
  AVG(
    DATE_PART(
      'DAY',
      manager_cte.first_appointment_date::TIMESTAMP -
        employee.hire_date::TIMESTAMP
    )
  ) AS average_days_till_management
FROM mv_employees.employee
INNER JOIN manager_cte
  ON employee.id = manager_cte.employee_id
```
- 909 days,

4. What was the most common title that managers had just before before they became a manager?
```sql
SELECT
previous_title,
COUNT(*) num_employees
FROM mv_employees.historic_employee_records
WHERE title = 'Manager' 
AND event_name = 'Title Change'
ORDER BY num_employees DESC;
```
- Senior Staff

5. How many managers were first hired by the company as a manager?
```sql
SELECT
COUNT(*)
FROM mv_employees.title
INNER JOIN mv_employees.employee
ON title.employee_id = employee.id
WHERE title = 'Manager'
AND from_date = hire_date;
```
- 9 
6. On average - how much more do current managers make on average compared to all other employees?

```sql
WITH salary_overall AS(
SELECT 
AVG(salary) AS avg_salary_overall
FROM mv_employees.current_employee_snapshot
WHERE title != 'Manager'),
salary_manager AS(
SELECT 
AVG(salary) AS avg_salary_manager
FROM mv_employees.current_employee_snapshot
WHERE title = 'Manager')
SELECT 
avg_salary_manager,
avg_salary_overall,
avg_salary_manager - avg_salary_overall AS diff_manager_overall
FROM salary_overall
CROSS JOIN salary_manager;
```
- 5711.64

7. Which current manager has the most employees in their department?
```sql
SELECT 
manager_name,
COUNT(*) AS num_employees
FROM mv_employees.current_employee_snapshot
GROUP BY manager_name
ORDER BY num_employees DESC;
```
- Leon DasSarma, 61386 employees

8. What is the difference in employee count between the 3rd and 4th ranking departments by size?
```sql
WITH department_ranking AS(
SELECT 
department,
ROW_NUMBER() OVER(ORDER BY COUNT(*) DESC) AS dept_rank,
COUNT(*) AS num_employees
FROM mv_employees.current_employee_snapshot
GROUP BY department),
third_largest_dept AS(
SELECT *
FROM department_ranking
WHERE dept_rank = 3),
fourth_largest_dept AS(
SELECT *
FROM department_ranking
WHERE dept_rank = 4)
SELECT
third_largest_dept.num_employees - 
fourth_largest_dept.num_employees AS diff_3rd_to_4th
FROM third_largest_dept
CROSS JOIN fourth_largest_dept;
```
or
```sql
WITH employee_count_cte AS (
SELECT
  department,
  COUNT(*) AS employee_count
FROM mv_employees.current_employee_snapshot
GROUP BY
  department
),
window_function_cte AS (
SELECT
  department,
  employee_count,
  RANK() OVER (ORDER BY employee_count DESC) AS department_rank,
  employee_count - LAG(employee_count) OVER (ORDER BY employee_count) AS difference_to_lower_rank
FROM employee_count_cte
)
SELECT *
FROM window_function_cte
WHERE department_rank = 3;
```

- 20132