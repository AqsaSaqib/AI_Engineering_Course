# Concept Check

### 1. Why are multiple CTEs preferred over one large nested query?
Multiple CTEs make a query easier to read and understand. Each CTE handles one specific step instead of putting everything into one complicated query.

### 2. When would you use a window function instead of GROUP BY?
Use a window function for calculations like ranking or running totals without combining rows. `GROUP BY` is used to summarize rows.

### 3. Explain the difference between ROW_NUMBER(), RANK(), and DENSE_RANK().
- `ROW_NUMBER()` gives every row a unique number.
- `RANK() gives` the same rank to ties but skips numbers.
- `DENSE_RANK()` gives the same rank to ties without skipping numbers.

### 4. What is conditional aggregation?
Conditional aggregation uses functions like `SUM()` or `COUNT()` with a condition. For example, counting only employees whose salary is above 50,000.

### 5. How does CASE WHEN improve analytical reporting?
`CASE WHEN` helps create categories or conditions in reports. For example, labeling sales as `"High"`, `"Medium"`, or `"Low"`.

### 6. Why should SQL queries be broken into logical stages?
Breaking queries into stages makes them easier to read, debug, and modify. Each stage performs a clear task.

### 7. What makes a SQL query maintainable?
A maintainable query has clear names, simple logic, proper formatting, and logical CTEs. It should be easy to understand and update.