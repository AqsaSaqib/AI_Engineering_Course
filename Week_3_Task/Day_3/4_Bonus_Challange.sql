-- BONUS: Top staff member per store + their % of store revenue
WITH staff_revenue AS (
    SELECT s.store_id, s.staff_id, SUM(p.amount) AS staff_total
    FROM payment p
    JOIN staff s ON p.staff_id = s.staff_id
    GROUP BY s.store_id, s.staff_id
),
store_revenue AS (
    SELECT store_id, SUM(staff_total) AS store_total
    FROM staff_revenue
    GROUP BY store_id
)
SELECT sr.store_id,
       sr.staff_id,
       sr.staff_total,
       st.store_total,
       ROUND(sr.staff_total * 100 / st.store_total, 2) AS percent_of_store
FROM staff_revenue sr
JOIN store_revenue st ON sr.store_id = st.store_id
WHERE sr.staff_total = (
    SELECT MAX(staff_total)
    FROM staff_revenue
    WHERE store_id = sr.store_id
);