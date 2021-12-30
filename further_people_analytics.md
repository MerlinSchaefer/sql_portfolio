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

