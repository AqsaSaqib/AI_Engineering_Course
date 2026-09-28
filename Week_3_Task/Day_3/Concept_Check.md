### 1. What is the difference between WHERE and HAVING?
`WHERE` is used to filter individual rows before grouping.
`HAVING` is used to filter groups after using GROUP BY.

---

### 2. When would you use a correlated subquery instead of a JOIN?
A correlated subquery is used when the inner query depends on the current row of the outer query. It is useful when we need to check a condition for each row separately.

---

### 3. What is a CTE, and why is it more readable than a nested subquery?
CTE stands for Common Table Expression. It creates a temporary result that we can use in the main query.It makes the query easier to read, understand, and manage compared to a nested subquery.

---

### 4. Explain the difference between RANK() and DENSE_RANK().
Both `RANK()` and `DENSE_RANK()` are used to give rank numbers to rows. The main difference is that `RANK()` skips a rank after there is same value, while `DENSE_RANK()` does not skip any rank.
Example:
* `RANK()` → 1, 1, 3
* `DENSE_RANK()` → 1, 1, 2

---

### 5. What does PARTITION BY do differently from GROUP BY?
`GROUP BY` combines rows into groups, and then we can apply aggregate functions like `SUM()` or `COUNT()`.
`PARTITION BY` also divides rows into groups, but it keeps all the original rows and calculates the result for each row within its group.

---

### 6. Can a subquery return multiple rows? What operator would you use in that case?
Yes, a subquery can return **multiple rows**. When it returns multiple values, we can use the `IN` operator to compare a value with all the returned values.
Example:
```sql
SELECT *
FROM employees
WHERE department_id IN (
    SELECT department_id
    FROM departments
);
```

---

### 7. Give an example of when CASE WHEN is useful inside an aggregate function.
`CASE WHEN` is useful inside an aggregate function when we want to count or calculate only specific rows.
For example, we can count how many tasks are completed:
```sql
SELECT SUM(
    CASE 
        WHEN status = 'Completed' THEN 1
        ELSE 0
    END
) AS completed_tasks
FROM tasks;
```
Here, `CASE WHEN` gives `1` for completed tasks and `0` for other tasks, and `SUM()` gives the total number of completed tasks.