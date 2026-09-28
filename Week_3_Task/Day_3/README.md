# Week 3 – Day 3: SQL Practice (DVD Rental Database)
In this task I solved business questions using SQL on the **DVD Rental** database.

---

## Folder Structure

```
Day_3/
├── ScreenShots/                             → query outputs
├── 1_Aggregation_basics_queries.sql         → Part 1 (4 questions)
├── 2_Subquiries_Challanges.sql              → Part 2 (4 questions)
├── 3_CTE_&_Window_Function_Challenges.sql   → Part 3 (4 questions)
├── 4_Bonus_Challange.sql                    → Bonus
├── Concept_Check.md
└── README.md
```

---

## Subquery vs CTE vs Window Function

- **Subquery:** a query inside another query. I used it when I needed one value to compare with, like an average.
- **CTE:** a temporary table made with `WITH`. I used it to break a long query into small, easy steps.
- **Window Function:** used for ranking or comparing rows without losing any rows, like `RANK()`, `ROW_NUMBER()` and `LAG()`.

---

## How I Solved Each Question

### Part 1 – Aggregation (`1_Aggregation_basics_queries.sql`)

1. **Revenue per store:** joined `payment` with `staff` and used `SUM(amount)` for each store.
2. **Average rental duration per category:** joined `film` with `category` and used `AVG(rental_duration)`.
3. **Rentals per month:** used `EXTRACT(YEAR ...)` and `EXTRACT(MONTH ...)` to get the year and month, then counted rentals with `COUNT(*)`.
4. **Categories with more than 50 films:** counted films in each category and used `HAVING COUNT(*) > 50`.

### Part 2 – Subqueries (`2_Subquiries_Challanges.sql`)

1. **Customers who spent more than average:** found each customer's total spend, then a subquery found the average. `HAVING` kept customers above it.
2. **Highest rental rate film in each category:** a correlated subquery found the max rental rate for each film's category, and only matching films were shown.
3. **Customers who never rented:** used `NOT EXISTS` and also `NOT IN` to find customers with no rentals.
4. **Store with highest revenue:** a subquery in `WHERE` picked the top store using `ORDER BY ... DESC LIMIT 1`.

### Part 3 – CTEs & Window Functions (`3_CTE_&_Window_Function_Challenges.sql`)

1. **Rank customers by spend in each city:** a CTE calculated each customer's total and city, then `RANK()` ranked them inside each city.
2. **Most recent film for each customer:** `ROW_NUMBER()` numbered rentals from newest to oldest, and I kept only row 1.
3. **Month-over-month revenue growth:** a CTE calculated monthly revenue using `EXTRACT(YEAR ...)` and `EXTRACT(MONTH ...)`, then `LAG()` got last month's revenue. Then growth % = (this month − last month) ÷ last month × 100.
4. **Top 3 films per category:** the first CTE calculated revenue for each film, the second CTE ranked films with `RANK()`, and I kept ranks 1 to 3.

### Bonus (`4_Bonus_Challange.sql`)
The first CTE found each staff member's revenue, and the second CTE found each store's total revenue. Then I picked the top staff member in each store and calculated their percentage of the store's revenue.

---

## Business Insights
1. Both stores make almost the same revenue. *(1_Aggregation_basics_queries.sql → Q1: Revenue per store)*
2. Every customer has rented at least one film, because the query returned 0 rows. *(2_Subquiries_Challanges.sql → Q3: Customers who never rented)*
3. Each store has only one staff member, so that one person handles 100% of the store's revenue. *(4_Bonus_Challange.sql → Bonus: Top staff member per store)*
