/* ============================================================================
   ANALYTICS PIPELINE - AdventureWorks (PostgreSQL)
   Week 3 Friday Hackathon
   ----------------------------------------------------------------------------
   IDEA IN ONE LINE
   The raw database is made for saving orders, not for reports. So we build a
   separate "analytics" schema with ready-made tables/views, and every report
   or dashboard reads from these instead of the raw tables.

   THE 4 LAYERS (each layer only uses the layer before it)

     Raw tables  (sales, production, purchasing, person ...)
        |
     LAYER 1  base_*        3 tables  - clean copy of the raw data   <- ONLY layer that reads raw tables
        |
     LAYER 2  *_analytics   8 views   - one summary per business area
        |
     LAYER 3  business      3 views   - segments, retention, categories
        |
     LAYER 4  kpi_*         4 views   - final numbers for the executive dashboard
        |
     Python notebook (reads layers 2-4 only, never the raw tables)

   HOW TO RUN
     (open in pgAdmin -> Query Tool -> F5). You can run it again any time;
     it deletes and rebuilds the analytics schema.
   ============================================================================ */


/* ============================================================================
   LAYER 0 - create a fresh schema
   ============================================================================ */
DROP SCHEMA IF EXISTS analytics CASCADE;
CREATE SCHEMA analytics;


/* ============================================================================
   LAYER 1 - BASE TABLES (clean copy of the raw data)
   These are TABLES, so the raw database is read only once.
   ============================================================================ */

-- ----------------------------------------------------------------------------
-- 1. base_sales : one row per product sold (order line) with all the names
--    we need. Revenue, cost and profit are calculated HERE, only once.
-- ----------------------------------------------------------------------------
CREATE TABLE analytics.base_sales AS
WITH order_lines AS (
    -- Step A: join every order line to its order header
    SELECT h.salesorderid      AS order_id,
           h.orderdate::date   AS order_date,
           h.customerid        AS customer_id,
           h.territoryid       AS territory_id,
           h.salespersonid     AS salesperson_id,
           CASE WHEN h.onlineorderflag THEN 'Online' ELSE 'Reseller' END AS channel,
           d.productid         AS product_id,
           d.orderqty          AS quantity,
           -- the Postgres version has no LineTotal column, so we calculate revenue
           d.orderqty * d.unitprice * (1 - d.unitpricediscount) AS revenue
    FROM sales.salesorderheader h
    JOIN sales.salesorderdetail d ON d.salesorderid = h.salesorderid
),
lines_with_product AS (
    -- Step B: add product name, category and the product cost
    --         that was valid on the order date (cost changes every year)
    SELECT ol.*,
           p.name                          AS product,
           COALESCE(pc.name, 'Other')      AS category,
           COALESCE(ps.name, 'Other')      AS subcategory,
           ol.quantity * COALESCE(ch.standardcost, p.standardcost) AS cost
    FROM order_lines ol
    JOIN production.product p                 ON p.productid  = ol.product_id
    LEFT JOIN production.productsubcategory ps ON ps.productsubcategoryid = p.productsubcategoryid
    LEFT JOIN production.productcategory pc    ON pc.productcategoryid    = ps.productcategoryid
    LEFT JOIN production.productcosthistory ch
           ON ch.productid = ol.product_id
          AND ol.order_date BETWEEN ch.startdate AND COALESCE(ch.enddate, '2099-12-31')
)
-- Step C: add customer, territory and salesperson names
SELECT l.order_id,
       l.order_date,
       date_trunc('month', l.order_date)::date        AS order_month,
       EXTRACT(YEAR FROM l.order_date)::int           AS order_year,
       EXTRACT(QUARTER FROM l.order_date)::int        AS order_quarter,
       l.channel,
       l.customer_id,
       CASE WHEN c.storeid IS NOT NULL THEN 'Store' ELSE 'Individual' END AS customer_type,
       COALESCE(st.name, cp.firstname || ' ' || cp.lastname)             AS customer_name,
       t.name                                         AS territory,
       t."group"                                      AS region,
       sp.firstname || ' ' || sp.lastname            AS salesperson,      -- empty for online orders
       l.product_id,
       l.product,
       l.category,
       l.subcategory,
       l.quantity,
       l.revenue,
       l.cost,
       l.revenue - l.cost                             AS profit
FROM lines_with_product l
JOIN sales.customer c           ON c.customerid        = l.customer_id
LEFT JOIN sales.store st        ON st.businessentityid = c.storeid
LEFT JOIN person.person cp      ON cp.businessentityid = c.personid
LEFT JOIN sales.salesterritory t ON t.territoryid      = l.territory_id
LEFT JOIN person.person sp      ON sp.businessentityid = l.salesperson_id;


-- ----------------------------------------------------------------------------
-- 2. base_inventory : current stock of every product we still sell
-- ----------------------------------------------------------------------------
CREATE TABLE analytics.base_inventory AS
SELECT p.productid                    AS product_id,
       p.name                         AS product,
       COALESCE(pc.name, 'Other')     AS category,
       CASE WHEN p.finishedgoodsflag THEN 'Finished product' ELSE 'Component' END AS product_type,
       p.safetystocklevel             AS safety_stock,
       p.reorderpoint                 AS reorder_point,
       COALESCE(SUM(i.quantity), 0)   AS stock_qty
FROM production.product p
LEFT JOIN production.productinventory i    ON i.productid = p.productid
LEFT JOIN production.productsubcategory ps ON ps.productsubcategoryid = p.productsubcategoryid
LEFT JOIN production.productcategory pc    ON pc.productcategoryid    = ps.productcategoryid
WHERE p.sellenddate IS NULL            -- only products that are still on sale
  AND p.discontinueddate IS NULL
GROUP BY p.productid, p.name, pc.name, p.finishedgoodsflag, p.safetystocklevel, p.reorderpoint;


-- ----------------------------------------------------------------------------
-- 3. base_purchasing : one row per purchase order line with the supplier name
-- ----------------------------------------------------------------------------
CREATE TABLE analytics.base_purchasing AS
SELECT h.purchaseorderid                        AS po_id,
       h.orderdate::date                        AS po_date,
       date_trunc('month', h.orderdate)::date   AS po_month,
       v.businessentityid                       AS vendor_id,
       v.name                                   AS vendor,
       d.productid                              AS product_id,
       CASE h.status WHEN 1 THEN 'Pending'
                     WHEN 2 THEN 'Approved'
                     WHEN 3 THEN 'Rejected'
                     WHEN 4 THEN 'Complete' END AS po_status,
       d.orderqty                               AS ordered_qty,
       d.receivedqty                            AS received_qty,
       d.rejectedqty                            AS rejected_qty,
       d.orderqty * d.unitprice                 AS amount
FROM purchasing.purchaseorderheader h
JOIN purchasing.purchaseorderdetail d ON d.purchaseorderid  = h.purchaseorderid
JOIN purchasing.vendor v              ON v.businessentityid = h.vendorid;


/* ============================================================================
   LAYER 2 - ANALYTICS VIEWS (one summary per business area)
   A VIEW is a saved query. These views read ONLY the base tables above.
   ============================================================================ */

-- ----------------------------------------------------------------------------
-- 4. sales_analytics : one row per month (Sales + Date analytics)
-- ----------------------------------------------------------------------------
CREATE VIEW analytics.sales_analytics AS
SELECT order_month,
       order_year,
       order_quarter,
       EXTRACT(MONTH FROM order_month)::int                              AS month_number,
       SUM(revenue)                                                      AS revenue,
       SUM(cost)                                                         AS cost,
       SUM(profit)                                                       AS profit,
       -- conditional aggregation: split by sales channel
       SUM(CASE WHEN channel = 'Online'   THEN revenue ELSE 0 END)       AS online_revenue,
       SUM(CASE WHEN channel = 'Reseller' THEN revenue ELSE 0 END)       AS reseller_revenue,
       SUM(CASE WHEN channel = 'Online'   THEN profit  ELSE 0 END)       AS online_profit,
       SUM(CASE WHEN channel = 'Reseller' THEN profit  ELSE 0 END)       AS reseller_profit,
       COUNT(DISTINCT order_id)                                          AS orders,
       COUNT(DISTINCT customer_id)                                       AS customers,
       -- Data starts on 30 May 2022 and reseller orders stop after April 2025,
       -- so only June 2022 - April 2025 are FULL months. We use only full
       -- months when we calculate growth.
       (order_month BETWEEN DATE '2022-06-01' AND DATE '2025-04-01')     AS is_full_month
FROM analytics.base_sales
GROUP BY order_month, order_year, order_quarter;


-- ----------------------------------------------------------------------------
-- 5. customer_analytics : one row per customer
-- ----------------------------------------------------------------------------
CREATE VIEW analytics.customer_analytics AS
SELECT customer_id,
       customer_name,
       customer_type,
       territory,
       COUNT(DISTINCT order_id)                          AS total_orders,
       SUM(revenue)                                      AS lifetime_value,   -- CLV = all money the customer has spent
       SUM(profit)                                       AS lifetime_profit,
       SUM(revenue) / COUNT(DISTINCT order_id)           AS avg_order_value,
       MIN(order_date)                                   AS first_order_date,
       MAX(order_date)                                   AS last_order_date,
       (SELECT MAX(order_date) FROM analytics.base_sales) - MAX(order_date) AS days_since_last_order,
       COUNT(DISTINCT order_id) > 1                      AS is_repeat_customer
FROM analytics.base_sales
GROUP BY customer_id, customer_name, customer_type, territory;


-- ----------------------------------------------------------------------------
-- 6. product_analytics : one row per product, with rankings
-- ----------------------------------------------------------------------------
CREATE VIEW analytics.product_analytics AS
WITH product_totals AS (
    SELECT product_id, product, category, subcategory,
           SUM(quantity)             AS units_sold,
           SUM(revenue)              AS revenue,
           SUM(cost)                 AS cost,
           SUM(profit)               AS profit,
           COUNT(DISTINCT order_id)  AS orders
    FROM analytics.base_sales
    GROUP BY product_id, product, category, subcategory
)
SELECT pt.*,
       ROUND(100 * profit / NULLIF(revenue, 0), 2)                     AS margin_pct,
       RANK()       OVER (ORDER BY revenue DESC)                       AS sales_rank,        -- 1 = best seller
       RANK()       OVER (ORDER BY profit ASC)                         AS worst_profit_rank, -- 1 = biggest loss
       DENSE_RANK() OVER (PARTITION BY category ORDER BY revenue DESC) AS rank_in_category,
       CASE WHEN profit < 0                  THEN 'Loss-making'
            WHEN profit < 0.10 * revenue     THEN 'Low margin (under 10%)'
            ELSE 'Healthy margin'
       END                                                             AS profit_status
FROM product_totals pt;


-- ----------------------------------------------------------------------------
-- 7. employee_analytics : one row per salesperson
--    People joined at different times, so we compare revenue PER MONTH.
-- ----------------------------------------------------------------------------
CREATE VIEW analytics.employee_analytics AS
WITH person_totals AS (
    SELECT salesperson,
           SUM(revenue)                  AS revenue,
           SUM(profit)                   AS profit,
           COUNT(DISTINCT order_id)      AS orders,
           COUNT(DISTINCT customer_id)   AS customers,
           COUNT(DISTINCT order_month)   AS active_months
    FROM analytics.base_sales
    WHERE salesperson IS NOT NULL                 -- online orders have no salesperson
    GROUP BY salesperson
),
per_month AS (
    SELECT pt.*, revenue / active_months AS revenue_per_month
    FROM person_totals pt
)
SELECT pm.*,
       RANK() OVER (ORDER BY revenue DESC)                                  AS revenue_rank,
       ROUND(100 * revenue / SUM(revenue) OVER (), 2)                       AS contribution_pct,  -- share of team revenue
       ROUND(100 * revenue_per_month / AVG(revenue_per_month) OVER (), 1)   AS vs_team_average_pct, -- 100 = average
       CASE WHEN revenue_per_month >= 1.2 * AVG(revenue_per_month) OVER () THEN 'Above average'
            WHEN revenue_per_month >= 0.8 * AVG(revenue_per_month) OVER () THEN 'Average'
            ELSE 'Below average'
       END                                                                  AS performance
FROM per_month pm;


-- ----------------------------------------------------------------------------
-- 8. territory_analytics : one row per sales territory
-- ----------------------------------------------------------------------------
CREATE VIEW analytics.territory_analytics AS
WITH territory_totals AS (
    SELECT territory, region,
           SUM(revenue)                                                   AS revenue,
           SUM(profit)                                                    AS profit,
           SUM(CASE WHEN channel = 'Online' THEN revenue ELSE 0 END)      AS online_revenue,
           SUM(CASE WHEN order_year = 2023  THEN revenue ELSE 0 END)      AS revenue_2023,
           SUM(CASE WHEN order_year = 2024  THEN revenue ELSE 0 END)      AS revenue_2024,
           COUNT(DISTINCT customer_id)                                    AS customers
    FROM analytics.base_sales
    GROUP BY territory, region
)
SELECT territory, region, revenue, profit, customers,
       ROUND(100 * profit / revenue, 2)                                AS margin_pct,
       ROUND(100 * revenue / SUM(revenue) OVER (), 2)                  AS share_of_revenue_pct,
       ROUND(100 * online_revenue / revenue, 1)                        AS online_share_pct,
       revenue_2023,
       revenue_2024,
       ROUND(100 * (revenue_2024 - revenue_2023) / revenue_2023, 2)    AS growth_2024_pct,   -- 2024 vs 2023 (both full years)
       RANK() OVER (ORDER BY revenue DESC)                             AS revenue_rank,
       CASE WHEN RANK() OVER (ORDER BY revenue DESC) <= 3 THEN 'Top 3'
            WHEN RANK() OVER (ORDER BY revenue ASC)  <= 3 THEN 'Lowest 3'
            ELSE 'Middle'
       END                                                             AS territory_group
FROM territory_totals;


-- ----------------------------------------------------------------------------
-- 9. inventory_analytics : stock health of every product still on sale
-- ----------------------------------------------------------------------------
CREATE VIEW analytics.inventory_analytics AS
WITH last_12_months AS (
    -- sales in the last 12 FULL months (May 2024 - April 2025)
    SELECT product_id,
           SUM(quantity) AS units_last_12m,
           SUM(revenue)  AS revenue_last_12m
    FROM analytics.base_sales
    WHERE order_date BETWEEN DATE '2024-05-01' AND DATE '2025-04-30'
    GROUP BY product_id
)
SELECT i.product_id, i.product, i.category, i.product_type,
       i.stock_qty, i.safety_stock, i.reorder_point,
       COALESCE(s.units_last_12m, 0)                    AS units_last_12m,
       ROUND(COALESCE(s.units_last_12m, 0) / 12.0, 1)   AS avg_units_per_month,
       COALESCE(s.revenue_last_12m, 0)                  AS revenue_last_12m,
       CASE WHEN i.stock_qty = 0              THEN 'Out of stock'
            WHEN i.stock_qty < i.safety_stock THEN 'Low stock'
            ELSE 'Healthy'
       END                                              AS stock_status
FROM analytics.base_inventory i
LEFT JOIN last_12_months s ON s.product_id = i.product_id;


-- ----------------------------------------------------------------------------
-- 10. vendor_analytics : one row per supplier
-- ----------------------------------------------------------------------------
CREATE VIEW analytics.vendor_analytics AS
WITH vendor_totals AS (
    SELECT vendor_id, vendor,
           COUNT(DISTINCT po_id)                                            AS purchase_orders,
           SUM(CASE WHEN po_status <> 'Rejected' THEN amount ELSE 0 END)    AS total_spend,
           SUM(received_qty)                                                AS received_qty,
           SUM(rejected_qty)                                                AS rejected_qty
    FROM analytics.base_purchasing
    GROUP BY vendor_id, vendor
)
SELECT vt.*,
       ROUND(100 * rejected_qty / NULLIF(received_qty, 0), 2)    AS rejection_rate_pct,
       RANK() OVER (ORDER BY total_spend DESC)                   AS spend_rank,
       CASE WHEN rejected_qty >= 0.05 * received_qty THEN 'Poor quality (5%+ rejected)'
            WHEN rejected_qty >= 0.02 * received_qty THEN 'Watch (2-5% rejected)'
            ELSE 'Good (under 2% rejected)'
       END                                                       AS supplier_rating
FROM vendor_totals vt;


-- ----------------------------------------------------------------------------
-- 11. purchasing_analytics : purchase spend per month
-- ----------------------------------------------------------------------------
CREATE VIEW analytics.purchasing_analytics AS
SELECT po_month,
       SUM(CASE WHEN po_status <> 'Rejected' THEN amount ELSE 0 END)     AS purchase_spend,
       COUNT(DISTINCT po_id)                                             AS purchase_orders,
       SUM(ordered_qty)                                                  AS units_ordered,
       ROUND(100 * SUM(rejected_qty) / NULLIF(SUM(received_qty), 0), 2)  AS rejection_rate_pct
FROM analytics.base_purchasing
GROUP BY po_month;


/* ============================================================================
   LAYER 3 - BUSINESS VIEWS (built on Layer 2 / Layer 1)
   ============================================================================ */

-- ----------------------------------------------------------------------------
-- 12. customer_segments : put every customer into a simple group
--     Step 1: NTILE(4) splits customers into 4 equal groups by spending
--             (stores and individuals separately, because a store spends far more).
--     Step 2: CASE rules, checked from top to bottom.
-- ----------------------------------------------------------------------------
CREATE VIEW analytics.customer_segments AS
WITH value_groups AS (
    SELECT ca.*,
           NTILE(4) OVER (PARTITION BY customer_type ORDER BY lifetime_value DESC) AS value_group  -- 1 = top 25%
    FROM analytics.customer_analytics ca
)
SELECT vg.*,
       CASE WHEN days_since_last_order > 365                  THEN 'Lost'       -- no order for over a year
            WHEN days_since_last_order > 180                  THEN 'At Risk'    -- quiet for 6-12 months
            WHEN value_group = 1 AND total_orders >= 2        THEN 'Champion'   -- top spender, buys again, recent
            WHEN total_orders >= 2                            THEN 'Loyal'      -- buys again, recent
            ELSE 'New'                                                          -- one recent order
       END AS segment
FROM value_groups vg;


-- ----------------------------------------------------------------------------
-- 13. customer_retention : of the customers who bought in a year,
--     how many bought again the NEXT year? (self-join)
-- ----------------------------------------------------------------------------
CREATE VIEW analytics.customer_retention AS
WITH customer_years AS (
    SELECT DISTINCT customer_id, customer_type, order_year
    FROM analytics.base_sales
)
SELECT this_year.order_year                                              AS year,
       this_year.customer_type,
       COUNT(*)                                                          AS customers,
       COUNT(next_year.customer_id)                                      AS bought_again_next_year,
       ROUND(100.0 * COUNT(next_year.customer_id) / COUNT(*), 1)         AS retention_rate_pct
FROM customer_years this_year
LEFT JOIN customer_years next_year
       ON next_year.customer_id = this_year.customer_id
      AND next_year.order_year  = this_year.order_year + 1
WHERE this_year.order_year < 2025          -- 2026 does not exist yet, so 2025 cannot be measured
GROUP BY this_year.order_year, this_year.customer_type;


-- ----------------------------------------------------------------------------
-- 14. category_analytics : revenue and profit per category / subcategory
-- ----------------------------------------------------------------------------
CREATE VIEW analytics.category_analytics AS
WITH subcategory_totals AS (
    SELECT category, subcategory,
           COUNT(*)          AS products,
           SUM(units_sold)   AS units_sold,
           SUM(revenue)      AS revenue,
           SUM(profit)       AS profit
    FROM analytics.product_analytics
    GROUP BY category, subcategory
)
SELECT st.*,
       ROUND(100 * profit / revenue, 2)                                AS margin_pct,
       ROUND(100 * revenue / SUM(revenue) OVER (), 2)                  AS share_of_revenue_pct,
       RANK() OVER (PARTITION BY category ORDER BY revenue DESC)       AS rank_in_category
FROM subcategory_totals st;


/* ============================================================================
   LAYER 4 - EXECUTIVE KPI VIEWS (the final dashboard numbers)
   ============================================================================ */

-- ----------------------------------------------------------------------------
-- 15. kpi_monthly_revenue : monthly revenue + growth
--     LAG() looks at the previous row, so we can compare with last month
--     and with the same month last year (12 rows back).
-- ----------------------------------------------------------------------------
CREATE VIEW analytics.kpi_monthly_revenue AS
WITH with_previous AS (
    SELECT s.*,
           LAG(revenue)           OVER (ORDER BY order_month) AS last_month_revenue,
           LAG(is_full_month)     OVER (ORDER BY order_month) AS last_month_is_full,
           LAG(revenue, 12)       OVER (ORDER BY order_month) AS same_month_last_year,
           LAG(is_full_month, 12) OVER (ORDER BY order_month) AS same_month_last_year_is_full
    FROM analytics.sales_analytics s
)
SELECT order_month,
       order_year,
       is_full_month,
       ROUND(revenue, 2)                                       AS revenue,
       ROUND(online_revenue, 2)                                AS online_revenue,
       ROUND(reseller_revenue, 2)                              AS reseller_revenue,
       ROUND(profit, 2)                                        AS profit,
       ROUND(100 * profit / revenue, 2)                        AS margin_pct,
       orders,
       CASE WHEN is_full_month AND last_month_is_full
            THEN ROUND(100 * (revenue - last_month_revenue) / last_month_revenue, 2)
       END                                                     AS growth_vs_last_month_pct,
       CASE WHEN is_full_month AND same_month_last_year_is_full
            THEN ROUND(100 * (revenue - same_month_last_year) / same_month_last_year, 2)
       END                                                     AS growth_vs_last_year_pct,
       ROUND(AVG(revenue) OVER (ORDER BY order_month ROWS BETWEEN 2 PRECEDING AND CURRENT ROW), 2)
                                                               AS moving_avg_3_months,
       ROUND(SUM(revenue) OVER (PARTITION BY order_year ORDER BY order_month), 2)
                                                               AS running_total_this_year
FROM with_previous;


-- ----------------------------------------------------------------------------
-- 16. kpi_quarterly_revenue : quarterly revenue + growth
-- ----------------------------------------------------------------------------
CREATE VIEW analytics.kpi_quarterly_revenue AS
WITH quarters AS (
    SELECT order_year,
           order_quarter,
           order_year || '-Q' || order_quarter                    AS quarter_name,
           SUM(revenue)                                           AS revenue,
           SUM(profit)                                            AS profit,
           SUM(orders)                                            AS orders,
           SUM(CASE WHEN is_full_month THEN 1 ELSE 0 END) = 3     AS is_full_quarter
    FROM analytics.sales_analytics
    GROUP BY order_year, order_quarter
),
with_previous AS (
    SELECT q.*,
           LAG(revenue)            OVER (ORDER BY order_year, order_quarter) AS last_quarter_revenue,
           LAG(is_full_quarter)    OVER (ORDER BY order_year, order_quarter) AS last_quarter_is_full,
           LAG(revenue, 4)         OVER (ORDER BY order_year, order_quarter) AS same_quarter_last_year,
           LAG(is_full_quarter, 4) OVER (ORDER BY order_year, order_quarter) AS last_year_is_full
    FROM quarters q
)
SELECT order_year, order_quarter, quarter_name, is_full_quarter,
       ROUND(revenue, 2)                     AS revenue,
       ROUND(profit, 2)                      AS profit,
       ROUND(100 * profit / revenue, 2)      AS margin_pct,
       orders,
       CASE WHEN is_full_quarter AND last_quarter_is_full
            THEN ROUND(100 * (revenue - last_quarter_revenue) / last_quarter_revenue, 2) END   AS growth_vs_last_quarter_pct,
       CASE WHEN is_full_quarter AND last_year_is_full
            THEN ROUND(100 * (revenue - same_quarter_last_year) / same_quarter_last_year, 2) END AS growth_vs_last_year_pct
FROM with_previous;


-- ----------------------------------------------------------------------------
-- 17. kpi_yearly_growth : yearly revenue, growth and profit by channel
--     2022 and 2025 are not full years, so we ALSO compare the same months
--     (January to April) every year - that is the fair comparison.
-- ----------------------------------------------------------------------------
CREATE VIEW analytics.kpi_yearly_growth AS
WITH years AS (
    SELECT order_year,
           SUM(revenue)                                                AS revenue,
           SUM(profit)                                                 AS profit,
           SUM(CASE WHEN is_full_month THEN 1 ELSE 0 END)              AS full_months,
           SUM(CASE WHEN month_number <= 4 THEN revenue ELSE 0 END)    AS jan_to_apr_revenue,
           SUM(online_revenue)   AS online_revenue,
           SUM(online_profit)    AS online_profit,
           SUM(reseller_revenue) AS reseller_revenue,
           SUM(reseller_profit)  AS reseller_profit
    FROM analytics.sales_analytics
    GROUP BY order_year
),
with_previous AS (
    SELECT y.*,
           LAG(revenue)            OVER (ORDER BY order_year) AS last_year_revenue,
           LAG(full_months)        OVER (ORDER BY order_year) AS last_year_full_months,
           LAG(jan_to_apr_revenue) OVER (ORDER BY order_year) AS last_year_jan_to_apr
    FROM years y
)
SELECT order_year,
       full_months,
       ROUND(revenue, 2)                                         AS revenue,
       ROUND(profit, 2)                                          AS profit,
       ROUND(100 * profit / revenue, 2)                          AS margin_pct,
       ROUND(100 * online_revenue / revenue, 2)                  AS online_share_pct,
       ROUND(100 * online_profit / online_revenue, 2)            AS online_margin_pct,
       ROUND(100 * reseller_profit / reseller_revenue, 2)        AS reseller_margin_pct,
       CASE WHEN full_months = 12 AND last_year_full_months = 12
            THEN ROUND(100 * (revenue - last_year_revenue) / last_year_revenue, 2) END    AS full_year_growth_pct,
       ROUND(jan_to_apr_revenue, 2)                              AS jan_to_apr_revenue,
       ROUND(100 * (jan_to_apr_revenue - last_year_jan_to_apr) / NULLIF(last_year_jan_to_apr, 0), 2) AS jan_to_apr_growth_pct
FROM with_previous;


-- ----------------------------------------------------------------------------
-- 18. kpi_executive_summary : ONE row with the most important numbers.
--     Every number comes from the views above (no raw tables).
-- ----------------------------------------------------------------------------
CREATE VIEW analytics.kpi_executive_summary AS
SELECT
    (SELECT ROUND(SUM(revenue), 2) FROM analytics.sales_analytics)                          AS total_revenue,
    (SELECT ROUND(SUM(profit), 2)  FROM analytics.sales_analytics)                          AS total_profit,
    (SELECT ROUND(100 * SUM(profit) / SUM(revenue), 2) FROM analytics.sales_analytics)      AS profit_margin_pct,
    (SELECT SUM(orders)            FROM analytics.sales_analytics)                          AS total_orders,
    (SELECT COUNT(*)               FROM analytics.customer_analytics)                       AS total_customers,
    (SELECT ROUND(100.0 * SUM(CASE WHEN is_repeat_customer THEN 1 ELSE 0 END) / COUNT(*), 2)
       FROM analytics.customer_analytics)                                                   AS repeat_customer_pct,
    (SELECT full_year_growth_pct   FROM analytics.kpi_yearly_growth WHERE order_year = 2024) AS growth_2024_pct,
    (SELECT jan_to_apr_growth_pct  FROM analytics.kpi_yearly_growth WHERE order_year = 2025) AS growth_jan_apr_2025_pct,
    (SELECT ROUND(100 * SUM(online_profit) / SUM(online_revenue), 2)     FROM analytics.sales_analytics) AS online_margin_pct,
    (SELECT ROUND(100 * SUM(reseller_profit) / SUM(reseller_revenue), 2) FROM analytics.sales_analytics) AS reseller_margin_pct,
    (SELECT territory   FROM analytics.territory_analytics WHERE revenue_rank = 1)          AS top_territory,
    (SELECT product     FROM analytics.product_analytics  WHERE sales_rank = 1)             AS best_selling_product,
    (SELECT salesperson FROM analytics.employee_analytics WHERE revenue_rank = 1)           AS top_salesperson,
    (SELECT COUNT(*)    FROM analytics.product_analytics  WHERE profit < 0)                 AS loss_making_products,
    (SELECT COUNT(*)    FROM analytics.inventory_analytics
       WHERE stock_status = 'Out of stock' AND units_last_12m > 0)                          AS selling_products_out_of_stock,
    (SELECT ROUND(100 * SUM(rejected_qty) / SUM(received_qty), 2) FROM analytics.vendor_analytics) AS supplier_rejection_pct;


/* ============================================================================
   QUICK CHECKS - every row should say OK
   (These are the only queries outside Layer 1 that look at raw tables,
    because their job is to prove the analytics layer matches the source.)
   ============================================================================ */
SELECT 'Revenue in analytics = revenue in raw orders' AS check_name,
       CASE WHEN ABS((SELECT SUM(revenue) FROM analytics.base_sales)
                   - (SELECT SUM(subtotal) FROM sales.salesorderheader)) < 1
            THEN 'OK' ELSE 'PROBLEM' END AS result
UNION ALL
SELECT 'Every order line copied (no duplicates, none missing)',
       CASE WHEN (SELECT COUNT(*) FROM analytics.base_sales)
               = (SELECT COUNT(*) FROM sales.salesorderdetail) THEN 'OK' ELSE 'PROBLEM' END
UNION ALL
SELECT 'Every customer who ordered has a segment',
       CASE WHEN (SELECT COUNT(*) FROM analytics.customer_segments)
               = (SELECT COUNT(DISTINCT customerid) FROM sales.salesorderheader) THEN 'OK' ELSE 'PROBLEM' END
UNION ALL
SELECT 'Every purchase order line copied',
       CASE WHEN (SELECT COUNT(*) FROM analytics.base_purchasing)
               = (SELECT COUNT(*) FROM purchasing.purchaseorderdetail) THEN 'OK' ELSE 'PROBLEM' END;

-- List of everything that was created
SELECT table_name AS object_name, table_type AS object_type
FROM information_schema.tables
WHERE table_schema = 'analytics'
ORDER BY table_type, table_name;

/* BONUS IDEA (optional, run once as admin):
   A dashboard user that can ONLY see the analytics schema.
   CREATE ROLE dashboard_user LOGIN PASSWORD 'change_me';
   GRANT USAGE ON SCHEMA analytics TO dashboard_user;
   GRANT SELECT ON ALL TABLES IN SCHEMA analytics TO dashboard_user;
*/