-- Q1. Total revenue generated per store
-- Each payment is taken by a staff member, and each staff member works at a store.
SELECT s.store_id,
       SUM(p.amount) AS total_revenue
FROM payment p
JOIN staff s ON p.staff_id = s.staff_id
GROUP BY s.store_id
ORDER BY s.store_id;


-- Q2. Average rental duration per film category
-- rental_duration = number of days a film can be rented for
SELECT c.name AS category,
       ROUND(AVG(f.rental_duration), 2) AS avg_rental_duration
FROM film f
JOIN film_category fc ON f.film_id = fc.film_id
JOIN category c ON fc.category_id = c.category_id
GROUP BY c.name
ORDER BY c.name;


-- Q3. Number of rentals made each month
SELECT EXTRACT(YEAR FROM rental_date)  AS rental_year,
       EXTRACT(MONTH FROM rental_date) AS rental_month,
       COUNT(*) AS total_rentals
FROM rental
GROUP BY rental_year, rental_month
ORDER BY rental_year, rental_month;


-- Q4. Categories with more than 50 films
SELECT c.name AS category,
       COUNT(*) AS film_count
FROM film_category fc
JOIN category c ON fc.category_id = c.category_id
GROUP BY c.name
HAVING COUNT(*) > 50
ORDER BY film_count DESC;
