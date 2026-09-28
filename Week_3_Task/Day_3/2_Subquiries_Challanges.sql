-- Q1. Customers who spent more than the average customer spend
-- Inner subquery: total per customer. Outer subquery: average of those totals.
SELECT c.customer_id,
       c.first_name,
       c.last_name,
       SUM(p.amount) AS total_spent
FROM customer c
JOIN payment p ON c.customer_id = p.customer_id
GROUP BY c.customer_id, c.first_name, c.last_name
HAVING SUM(p.amount) > (
    SELECT AVG(customer_total)
    FROM (
        SELECT SUM(amount) AS customer_total
        FROM payment
        GROUP BY customer_id
    ) AS totals
)
ORDER BY total_spent DESC;


-- Q2. Films with the highest rental rate in each category (correlated subquery)
-- The inner query runs once per row and looks only at that row's category.
SELECT c.name AS category,
       f.title,
       f.rental_rate
FROM film f
JOIN film_category fc ON f.film_id = fc.film_id
JOIN category c ON fc.category_id = c.category_id
WHERE f.rental_rate = (
    SELECT MAX(f2.rental_rate)
    FROM film f2
    JOIN film_category fc2 ON f2.film_id = fc2.film_id
    WHERE fc2.category_id = fc.category_id
)
ORDER BY c.name, f.title;


-- Q3. Customers who have never rented a film (NOT EXISTS)
SELECT c.customer_id,
       c.first_name,
       c.last_name
FROM customer c
WHERE NOT EXISTS (
    SELECT 1
    FROM rental r
    WHERE r.customer_id = c.customer_id
);

-- Same thing using NOT IN:
SELECT customer_id, first_name, last_name
FROM customer
WHERE customer_id NOT IN (SELECT customer_id FROM rental);


-- Q4. Store with the highest total revenue (subquery in WHERE)
SELECT s.store_id,
       SUM(p.amount) AS total_revenue
FROM payment p
JOIN staff s ON p.staff_id = s.staff_id
WHERE s.store_id = (
    SELECT s2.store_id
    FROM payment p2
    JOIN staff s2 ON p2.staff_id = s2.staff_id
    GROUP BY s2.store_id
    ORDER BY SUM(p2.amount) DESC
    LIMIT 1
)
GROUP BY s.store_id;