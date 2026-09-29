-- Music Store Business Intelligence Project (PostgreSQL)

-- STAGE 1: customer profile
-- making one row for every customer with all their important numbers
CREATE OR REPLACE VIEW customer_profile AS
-- step 1: how much money each customer spent
WITH spending AS (
    SELECT
        customer_id,
        SUM(total) AS total_spent,          -- all money spent
        COUNT(*) AS total_invoices,         -- how many bills
        COUNT(DISTINCT TO_CHAR(invoice_date, 'YYYY-MM')) AS purchase_months  -- in how many months they bought
    FROM invoice
    GROUP BY customer_id
),
-- step 2: what each customer bought (kept separate so money doesnt get counted twice)
purchases AS (
    SELECT
        i.customer_id,
        SUM(il.quantity) AS total_tracks,             -- total songs bought
        COUNT(DISTINCT t.genre_id) AS unique_genres,  -- different genres
        COUNT(DISTINCT a.artist_id) AS unique_artists -- different artists
    FROM invoice i
    JOIN invoice_line il ON i.invoice_id = il.invoice_id  -- bill -> bill items
    JOIN track t ON il.track_id = t.track_id              -- item -> song
    JOIN album a ON t.album_id = a.album_id               -- song -> album (to get artist)
    GROUP BY i.customer_id
)
-- step 3: put both together with customer name
SELECT
    c.customer_id,
    c.first_name || ' ' || c.last_name AS customer_name,  -- full name
    c.country,
    c.support_rep_id,
    s.total_spent,
    s.total_invoices,
    p.total_tracks,
    p.unique_genres,
    p.unique_artists,
    s.purchase_months,
    ROUND(s.total_spent / s.total_invoices, 2) AS avg_invoice_value  -- average bill
FROM customer c
JOIN spending s ON c.customer_id = s.customer_id
JOIN purchases p ON c.customer_id = p.customer_id;
-- checking the result
SELECT * FROM customer_profile ORDER BY total_spent DESC;



-- STAGE 2: customer segments
-- giving points to customers and putting them in Platinum / Gold / Silver / Bronze

CREATE OR REPLACE VIEW customer_segments AS

-- step 1: find averages of all customers
-- OVER () puts the average on every row
WITH with_averages AS (
    SELECT *,
        AVG(total_spent) OVER () AS avg_spent,
        AVG(purchase_months) OVER () AS avg_months,
        AVG(unique_genres) OVER () AS avg_genres,
        AVG(unique_artists) OVER () AS avg_artists
    FROM customer_profile
),
-- step 2: give points if customer is better than average
-- spending gives 2 points because its most important
points AS (
    SELECT *,
          (CASE WHEN total_spent > avg_spent THEN 2 ELSE 0 END)
        + (CASE WHEN purchase_months >= avg_months THEN 1 ELSE 0 END)
        + (CASE WHEN unique_genres > avg_genres THEN 1 ELSE 0 END)
        + (CASE WHEN unique_artists > avg_artists THEN 1 ELSE 0 END) AS score
    FROM with_averages
)
-- step 3: turn points into segment name
SELECT *,
    CASE
        WHEN score >= 4 THEN 'Platinum'  -- best customers
        WHEN score = 3 THEN 'Gold'
        WHEN score = 2 THEN 'Silver'
        ELSE 'Bronze'                    -- low activity customers
    END AS segment
FROM points;
-- checking how many customers in each segment
SELECT segment, COUNT(*) AS customers
FROM customer_segments
GROUP BY segment;



-- STAGE 3: favorite genre + campaigns
-- finding top genre of each customer and picking a campaign for each segment
CREATE OR REPLACE VIEW customer_favorite_genre AS
-- step 1: count songs bought from each genre
WITH genre_purchases AS (
    SELECT
        i.customer_id,
        g.name AS genre,
        SUM(il.quantity) AS tracks_bought
    FROM invoice i
    JOIN invoice_line il ON i.invoice_id = il.invoice_id
    JOIN track t ON il.track_id = t.track_id
    JOIN genre g ON t.genre_id = g.genre_id
    GROUP BY i.customer_id, g.name
),
-- step 2: rank genres for each customer (1 = most bought)
ranked AS (
    SELECT *,
        ROW_NUMBER() OVER (PARTITION BY customer_id ORDER BY tracks_bought DESC, genre) AS genre_rank
    FROM genre_purchases
)
-- step 3: keep only the number 1 genre
SELECT
    s.customer_id,
    s.customer_name,
    s.segment,
    r.genre AS favorite_genre
FROM customer_segments s
JOIN ranked r ON s.customer_id = r.customer_id
WHERE r.genre_rank = 1;
-- campaign for each segment
-- step 1: count which genre is most liked in each segment
WITH segment_genres AS (
    SELECT
        segment,
        favorite_genre,
        COUNT(*) AS fans,
        RANK() OVER (PARTITION BY segment ORDER BY COUNT(*) DESC) AS rnk
    FROM customer_favorite_genre
    GROUP BY segment, favorite_genre
)
-- step 2: show top genre and campaign
-- bronze gets win back coupon because everyone already bought before
SELECT
    segment,
    favorite_genre AS top_genre,
    fans,
    CASE segment
        WHEN 'Platinum' THEN 'Early access to new releases'
        WHEN 'Gold' THEN 'Album bundles'
        WHEN 'Silver' THEN 'Genre discounts'
        ELSE 'Win-back coupons'
    END AS campaign
FROM segment_genres
WHERE rnk = 1;



-- STAGE 4: country ranking
-- scoring every country to find best ones for expansion

CREATE OR REPLACE VIEW country_ranking AS
-- step 1: main numbers for each country
WITH country_kpis AS (
    SELECT
        country,
        SUM(total_spent) AS total_revenue,
        COUNT(*) AS total_customers,
        ROUND(AVG(total_spent), 2) AS revenue_per_customer,
        ROUND(SUM(total_spent) / SUM(total_invoices), 2) AS avg_invoice_value,
        -- counting only platinum and gold customers
        SUM(CASE WHEN segment IN ('Platinum', 'Gold') THEN 1 ELSE 0 END) AS high_value_customers,
        COUNT(DISTINCT segment) AS customer_diversity  -- how many types of customers
    FROM customer_segments
    GROUP BY country
),
-- step 2: how many genres each country bought
country_genres AS (
    SELECT c.country, COUNT(DISTINCT t.genre_id) AS genres_purchased
    FROM customer c
    JOIN invoice i ON c.customer_id = i.customer_id
    JOIN invoice_line il ON i.invoice_id = il.invoice_id
    JOIN track t ON il.track_id = t.track_id
    GROUP BY c.country
),
-- step 3: rank country in every metric (1 = best)
metric_ranks AS (
    SELECT k.*, g.genres_purchased,
        RANK() OVER (ORDER BY k.total_revenue DESC) AS revenue_rank,
        RANK() OVER (ORDER BY k.total_customers DESC) AS customers_rank,
        RANK() OVER (ORDER BY k.revenue_per_customer DESC) AS rpc_rank,
        RANK() OVER (ORDER BY k.avg_invoice_value DESC) AS invoice_rank,
        RANK() OVER (ORDER BY g.genres_purchased DESC) AS genre_rank,
        RANK() OVER (ORDER BY k.customer_diversity DESC) AS diversity_rank
    FROM country_kpis k
    JOIN country_genres g ON k.country = g.country
),
-- step 4: mix all ranks with weights
-- smaller score = better country
scored AS (
    SELECT *,
          0.25 * revenue_rank     -- revenue 25%
        + 0.20 * customers_rank   -- customers 20%
        + 0.20 * rpc_rank         -- money per customer 20%
        + 0.10 * invoice_rank     -- bill size 10%
        + 0.15 * genre_rank       -- genres 15%
        + 0.10 * diversity_rank   -- customer types 10%
        AS weighted_score
    FROM metric_ranks
)
-- step 5: final rank of countries
SELECT *,
    RANK() OVER (ORDER BY weighted_score) AS country_rank
FROM scored;
-- top 3 countries for expansion
SELECT country, weighted_score, total_revenue, total_customers, revenue_per_customer
FROM country_ranking
WHERE country_rank <= 3;



-- STAGE 5: executive report
-- using all views we made above

-- 1. customers and revenue in each segment
SELECT
    segment,
    COUNT(*) AS customers,
    SUM(total_spent) AS revenue,
    ROUND(AVG(total_spent), 2) AS avg_spent
FROM customer_segments
GROUP BY segment
ORDER BY revenue DESC;

-- 1b. same revenue but in one row (using CASE inside SUM)
SELECT
    SUM(CASE WHEN segment = 'Platinum' THEN total_spent ELSE 0 END) AS platinum_revenue,
    SUM(CASE WHEN segment = 'Gold' THEN total_spent ELSE 0 END) AS gold_revenue,
    SUM(CASE WHEN segment = 'Silver' THEN total_spent ELSE 0 END) AS silver_revenue,
    SUM(CASE WHEN segment = 'Bronze' THEN total_spent ELSE 0 END) AS bronze_revenue
FROM customer_segments;

-- 2. top customer in every segment
WITH ranked AS (
    SELECT segment, customer_name, total_spent,
        RANK() OVER (PARTITION BY segment ORDER BY total_spent DESC) AS rnk
    FROM customer_segments
)
SELECT * FROM ranked WHERE rnk = 1;

-- 3. top genre in every segment
WITH ranked AS (
    SELECT segment, favorite_genre, COUNT(*) AS fans,
        RANK() OVER (PARTITION BY segment ORDER BY COUNT(*) DESC) AS rnk
    FROM customer_favorite_genre
    GROUP BY segment, favorite_genre
)
SELECT * FROM ranked WHERE rnk = 1;

-- 4. best country
SELECT country, weighted_score FROM country_ranking WHERE country_rank = 1;

-- 5. how much % revenue each country gives
SELECT
    country,
    total_revenue,
    ROUND(100 * total_revenue / SUM(total_revenue) OVER (), 1) AS revenue_pct
FROM country_ranking
ORDER BY total_revenue DESC;

-- 6. best employee (money from customers they handle)
SELECT e.first_name || ' ' || e.last_name AS employee, SUM(cp.total_spent) AS revenue
FROM customer_profile cp
JOIN employee e ON cp.support_rep_id = e.employee_id
GROUP BY e.first_name, e.last_name
ORDER BY revenue DESC
LIMIT 1;

-- 7. best artist by sales
SELECT ar.name AS artist, SUM(il.unit_price * il.quantity) AS revenue
FROM invoice_line il
JOIN track t ON il.track_id = t.track_id
JOIN album al ON t.album_id = al.album_id
JOIN artist ar ON al.artist_id = ar.artist_id
GROUP BY ar.name
ORDER BY revenue DESC
LIMIT 1;

-- 8. best album by sales
SELECT al.title AS album, SUM(il.unit_price * il.quantity) AS revenue
FROM invoice_line il
JOIN track t ON il.track_id = t.track_id
JOIN album al ON t.album_id = al.album_id
GROUP BY al.title
ORDER BY revenue DESC
LIMIT 1;




-- STAGE 6 (BONUS): whole pipeline in one query
-- every CTE uses the one before it run everything together, from WITH to the last ;

WITH

-- step 1: one row for every song sold, with all its details
sales AS (
    SELECT
        c.customer_id,
        c.first_name || ' ' || c.last_name AS customer_name,
        c.country,
        e.first_name || ' ' || e.last_name AS employee,
        i.invoice_id,
        i.invoice_date,
        g.name AS genre,
        ar.name AS artist,
        al.title AS album,
        il.unit_price * il.quantity AS revenue
    FROM invoice_line il
    JOIN invoice i   ON il.invoice_id = i.invoice_id
    JOIN customer c  ON i.customer_id = c.customer_id
    JOIN employee e  ON c.support_rep_id = e.employee_id
    JOIN track t     ON il.track_id = t.track_id
    JOIN genre g     ON t.genre_id = g.genre_id
    JOIN album al    ON t.album_id = al.album_id
    JOIN artist ar   ON al.artist_id = ar.artist_id
),

-- step 2: customer profile (one row per customer)
profile AS (
    SELECT
        customer_id, customer_name, country,
        SUM(revenue) AS total_spent,
        COUNT(DISTINCT invoice_id) AS total_invoices,
        COUNT(DISTINCT TO_CHAR(invoice_date, 'YYYY-MM')) AS purchase_months,
        COUNT(DISTINCT genre) AS unique_genres,
        COUNT(DISTINCT artist) AS unique_artists
    FROM sales
    GROUP BY customer_id, customer_name, country
),

-- step 3: give points if customer is better than average
points AS (
    SELECT *,
          (CASE WHEN total_spent > AVG(total_spent) OVER () THEN 2 ELSE 0 END)
        + (CASE WHEN purchase_months >= AVG(purchase_months) OVER () THEN 1 ELSE 0 END)
        + (CASE WHEN unique_genres > AVG(unique_genres) OVER () THEN 1 ELSE 0 END)
        + (CASE WHEN unique_artists > AVG(unique_artists) OVER () THEN 1 ELSE 0 END) AS score
    FROM profile
),

-- step 4: turn points into segment name
segments AS (
    SELECT *,
        CASE WHEN score >= 4 THEN 'Platinum'
             WHEN score = 3 THEN 'Gold'
             WHEN score = 2 THEN 'Silver'
             ELSE 'Bronze' END AS segment
    FROM points
),

-- step 5: rank customers inside each segment (1 = biggest spender)
top_customers AS (
    SELECT *,
        ROW_NUMBER() OVER (PARTITION BY segment ORDER BY total_spent DESC) AS rn
    FROM segments
),

-- step 6: rank genres inside each segment (1 = most songs bought)
segment_genres AS (
    SELECT s.segment, sa.genre, COUNT(*) AS songs,
        ROW_NUMBER() OVER (PARTITION BY s.segment ORDER BY COUNT(*) DESC) AS rn
    FROM sales sa
    JOIN segments s ON sa.customer_id = s.customer_id
    GROUP BY s.segment, sa.genre
),

-- step 7: main numbers for each country
countries AS (
    SELECT
        sa.country,
        SUM(sa.revenue) AS revenue,
        COUNT(DISTINCT sa.customer_id) AS customers,
        ROUND(SUM(sa.revenue) / COUNT(DISTINCT sa.customer_id), 2) AS per_customer,
        ROUND(SUM(sa.revenue) / COUNT(DISTINCT sa.invoice_id), 2) AS avg_invoice,
        COUNT(DISTINCT sa.genre) AS genres,
        COUNT(DISTINCT s.segment) AS diversity
    FROM sales sa
    JOIN segments s ON sa.customer_id = s.customer_id
    GROUP BY sa.country
),

-- step 8: score every country (rank each metric, then mix with weights)
-- smaller score = better country
country_ranking AS (
    SELECT *,
          0.25 * RANK() OVER (ORDER BY revenue DESC)
        + 0.20 * RANK() OVER (ORDER BY customers DESC)
        + 0.20 * RANK() OVER (ORDER BY per_customer DESC)
        + 0.10 * RANK() OVER (ORDER BY avg_invoice DESC)
        + 0.15 * RANK() OVER (ORDER BY genres DESC)
        + 0.10 * RANK() OVER (ORDER BY diversity DESC) AS score,
        ROUND(100 * revenue / SUM(revenue) OVER (), 1) AS revenue_pct
    FROM countries
)

-- step 9: final dashboard
-- every row = section, item, value, and a sentence explaining it
-- UNION ALL stacks all the small results into one table queries with LIMIT go inside ( ) brackets
SELECT * FROM (

    -- 1. money from each segment
    SELECT '1. Segment Revenue' AS section, segment AS item, SUM(total_spent) AS value,
           COUNT(*) || ' customers in this segment' AS what_it_means
    FROM segments
    GROUP BY segment

    UNION ALL

    -- 2. biggest spender in each segment
    SELECT '2. Top Customer', customer_name, total_spent,
           'Best ' || segment || ' customer, from ' || country
    FROM top_customers
    WHERE rn = 1

    UNION ALL

    -- 3. most bought genre in each segment
    SELECT '3. Top Genre', segment, songs,
           segment || ' customers bought ' || songs || ' ' || genre || ' songs'
    FROM segment_genres
    WHERE rn = 1

    UNION ALL

    -- 4. top 3 countries to expand into
    (SELECT '4. Expansion Pick #' || ROW_NUMBER() OVER (ORDER BY score), country, revenue,
            customers || ' customers, $' || per_customer || ' per customer'
     FROM country_ranking
     ORDER BY score
     LIMIT 3)

    UNION ALL

    -- 5. share of revenue from each country
    SELECT '5. Country Revenue', country, revenue,
           revenue_pct || '% of all revenue'
    FROM country_ranking

    UNION ALL

    -- 6. best employee (money from the customers they look after)
    (SELECT '6. Top Employee', employee, SUM(revenue),
            'Their customers spent the most'
     FROM sales
     GROUP BY employee
     ORDER BY SUM(revenue) DESC
     LIMIT 1)

    UNION ALL

    -- 7. best artist
    (SELECT '7. Top Artist', artist, SUM(revenue),
            'Artist who earned the most'
     FROM sales
     GROUP BY artist
     ORDER BY SUM(revenue) DESC
     LIMIT 1)

    UNION ALL

    -- 8. best album
    (SELECT '8. Top Album', album, SUM(revenue),
            'Album that earned the most'
     FROM sales
     GROUP BY album
     ORDER BY SUM(revenue) DESC
     LIMIT 1)

) AS dashboard
ORDER BY section, value DESC;