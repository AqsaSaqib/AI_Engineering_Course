-- Q1. Rank customers by total spend within each city
WITH customer_spend AS (
    SELECT c.customer_id,
           c.first_name,
           c.last_name,
           ci.city,
           SUM(p.amount) AS total_spent
    FROM customer c
    JOIN address a  ON c.address_id = a.address_id
    JOIN city ci    ON a.city_id = ci.city_id
    JOIN payment p  ON c.customer_id = p.customer_id
    GROUP BY c.customer_id, c.first_name, c.last_name, ci.city
)
SELECT city,
       first_name,
       last_name,
       total_spent,
       RANK() OVER (PARTITION BY city ORDER BY total_spent DESC) AS rank_in_city
FROM customer_spend
ORDER BY city, rank_in_city;


-- Q2. Most recently rented film for each customer
WITH ranked_rentals AS (
    SELECT r.customer_id,
           f.title,
           r.rental_date,
           ROW_NUMBER() OVER (PARTITION BY r.customer_id
                              ORDER BY r.rental_date DESC) AS rn
    FROM rental r
    JOIN inventory i ON r.inventory_id = i.inventory_id
    JOIN film f      ON i.film_id = f.film_id
)
SELECT customer_id,
       title AS latest_film,
       rental_date
FROM ranked_rentals
WHERE rn = 1
ORDER BY customer_id;


-- Q3. Month-over-month rental revenue growth
WITH monthly_revenue AS (
    SELECT EXTRACT(YEAR FROM payment_date)  AS year,
           EXTRACT(MONTH FROM payment_date) AS month,
           SUM(amount) AS revenue
    FROM payment
    GROUP BY year, month
)
SELECT year,
       month,
       revenue,
       LAG(revenue) OVER (ORDER BY year, month) AS previous_month_revenue,
       ROUND(
           (revenue - LAG(revenue) OVER (ORDER BY year, month))
           / LAG(revenue) OVER (ORDER BY year, month) * 100
       , 2) AS growth_percent
FROM monthly_revenue
ORDER BY year, month;


-- Q4. Top 3 highest-grossing films per category
WITH film_revenue AS (
    SELECT c.name AS category,
           f.title,
           SUM(p.amount) AS revenue
    FROM payment p
    JOIN rental r         ON p.rental_id = r.rental_id
    JOIN inventory i      ON r.inventory_id = i.inventory_id
    JOIN film f           ON i.film_id = f.film_id
    JOIN film_category fc ON f.film_id = fc.film_id
    JOIN category c       ON fc.category_id = c.category_id
    GROUP BY c.name, f.title
),
ranked_films AS (
    SELECT category,
           title,
           revenue,
           RANK() OVER (PARTITION BY category ORDER BY revenue DESC) AS film_rank
    FROM film_revenue
)
SELECT category, title, revenue, film_rank
FROM ranked_films
WHERE film_rank <= 3
ORDER BY category, film_rank;

