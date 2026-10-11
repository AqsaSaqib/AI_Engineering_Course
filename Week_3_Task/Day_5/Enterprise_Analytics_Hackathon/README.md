# AdventureWorks Analytics Project
**Week 3 Friday Hackathon**

## What is this project?

AdventureWorks is a company that makes and sells **bicycles, parts, clothing and accessories**.
Its database is built to **save daily orders**, not to make reports. Every report would need long, messy queries.

So I built an **analytics layer**: a separate schema called `analytics` with ready-made tables and views.
Now any report or dashboard can read simple, clean data from there and never touches the raw tables.
Then I used Python to make **13 charts** and **business recommendations** from that data.

---

## What's in the folder

| File / folder | What it is |
|---|---|
| `analytics_pipeline.sql` | All the SQL. It creates 18 tables/views in 4 layers. |
| `executive_analysis.ipynb` | Jupyter notebook: connects to PostgreSQL, makes 13 charts, insights and recommendations. |
| `executive_analysis_colab.ipynb` | The same notebook for **Google Colab**. It installs PostgreSQL inside Colab and loads the data by itself. |
| `README.md` | This file. |
| `charts/` | All 13 charts saved as pictures. |
| `screenshots/` | Screenshots of the SQL results and the notebook. |
| `documentation/` | A simple diagram, an explanation of every table/view, and a web-page copy of the notebook. |

---

## How to run it (3 steps)

1. **Load the database.** Open a terminal in the dataset folder (where `install.sql` is) and run:
   ```
   psql -U postgres -c "CREATE DATABASE \"Adventureworks\";"
   psql -U postgres -d Adventureworks -f install.sql
   ```
2. **Build the analytics layer:**
   ```
   psql -U postgres -d Adventureworks -f analytics_pipeline.sql
   ```
   At the end you should see 4 checks that all say **OK**. (You can also open the file in pgAdmin and press F5.)
3. **Run the notebook.** Install the packages once with
   `pip install pandas matplotlib sqlalchemy psycopg2-binary jupyter`, then open
   `executive_analysis.ipynb`, type your PostgreSQL password in the connection cell, and click **Run All**.

**Using Google Colab instead?** Open `executive_analysis_colab.ipynb` in Colab (File → Upload notebook) and run the cells
from top to bottom. When it asks, upload two files: the dataset zip and `analytics_pipeline.sql`. It installs PostgreSQL inside
Colab, loads the data, builds the analytics layer and makes all the charts. Colab forgets everything when closed, so just run it again next time.

---

## The data (database overview)

The database has **68 tables** in 5 groups (schemas):

| Schema | What it holds | Main tables I used |
|---|---|---|
| `sales` | orders, customers, stores, salespeople, regions | salesorderheader (31,465 orders), salesorderdetail (121,317 order lines), customer, store, salesterritory |
| `production` | products, categories, stock | product (504), productcategory, productsubcategory, productinventory, productcosthistory |
| `purchasing` | suppliers and what we buy from them | vendor (104), purchaseorderheader, purchaseorderdetail |
| `person` | names of people | person |
| `humanresources` | employees | employee *(salespeople are employees)* |

**Time period:** sales from **30 May 2022 to 29 June 2025**.
**Two ways of selling:** **Online** (people buy on the website) and **Reseller** (bike shops buy in bulk through salespeople).

---

## How the pipeline works (analytics architecture)

![How it works](documentation/how_it_works.png)

```
Raw tables
   ↓
Layer 1: base tables      (3)  → clean copy of the raw data
   ↓
Layer 2: analytics views  (8)  → one summary for each business area
   ↓
Layer 3: business views   (3)  → customer groups, retention, categories
   ↓
Layer 4: KPI views        (4)  → final numbers for the boss / dashboard
   ↓
Python notebook (charts + insights)
```

**Rule:** each layer only reads from the layer above it. **Only Layer 1 touches the raw tables.**

---

## The tables and views I created (18)

| # | Name | Layer | What it tells you |
|---|---|---|---|
| 1 | `base_sales` | 1 (table) | Every product sold, with revenue, cost, profit, customer, product, region and salesperson in one row |
| 2 | `base_inventory` | 1 (table) | How much stock we have of every product still on sale |
| 3 | `base_purchasing` | 1 (table) | Every purchase order line with the supplier name |
| 4 | `sales_analytics` | 2 | Revenue, profit, orders and customers **per month**, split into online and reseller |
| 5 | `customer_analytics` | 2 | One row per customer: orders, total spending (lifetime value), last order date |
| 6 | `product_analytics` | 2 | One row per product: sales, profit, margin and rank |
| 7 | `employee_analytics` | 2 | One row per salesperson: revenue, revenue per month, rank, share of team |
| 8 | `territory_analytics` | 2 | One row per region: revenue, margin, growth 2024 vs 2023, rank |
| 9 | `inventory_analytics` | 2 | Stock vs sales: Healthy / Low stock / Out of stock |
| 10 | `vendor_analytics` | 2 | One row per supplier: spend, % of items rejected, rating |
| 11 | `purchasing_analytics` | 2 | How much we spend on purchases per month |
| 12 | `customer_segments` | 3 | Puts every customer in a group: Champion, Loyal, New, At Risk, Lost |
| 13 | `customer_retention` | 3 | % of customers who bought again the next year |
| 14 | `category_analytics` | 3 | Revenue, profit and margin per category / subcategory |
| 15 | `kpi_monthly_revenue` | 4 | Monthly revenue with growth vs last month and vs last year |
| 16 | `kpi_quarterly_revenue` | 4 | Quarterly revenue with growth |
| 17 | `kpi_yearly_growth` | 4 | Yearly revenue, growth, and profit for online vs reseller |
| 18 | `kpi_executive_summary` | 4 | One row with the 16 most important numbers |

**7 business areas covered:** Sales, Customers, Products, Employees, Territories, Inventory, Purchasing/Suppliers.

**SQL skills used (Task 4):**
- **CTEs** (`WITH ... AS`): `base_sales` is built in 3 steps (A → B → C).
- **Window functions:** `LAG` for growth, `SUM() OVER` for running totals and shares, `AVG() OVER` for the 3-month average.
- **Ranking:** `RANK`, `DENSE_RANK`, `NTILE`.
- **CASE WHEN:** every label (segment, stock status, supplier rating).
- **Conditional aggregation:** `SUM(CASE WHEN channel = 'Online' ...)`.
- **Complex joins:** 10 tables in `base_sales`, a join on a date range for product cost, and a self-join in `customer_retention`.

---

## Why I built it this way (design decisions)

1. **Calculate once, use everywhere.** Revenue, cost and profit are calculated only once, in `base_sales`. Every other view just adds them up, so all numbers always match.
2. **Tables first, then views.** Layer 1 is saved as tables, so the raw database is read only once. Layers 2-4 are views (saved queries), so they always show the latest numbers.
3. **Simple names.** Every view is named after the business area (`customer_analytics`, `product_analytics`, ...), so anyone can guess what is inside.
4. **Fair comparisons.** Growth uses only full months, and years are also compared on the same months (Jan-Apr).
5. **Ready for new dashboards (bonus).** A new dashboard only needs `SELECT * FROM analytics.<view>`; nobody has to touch the raw tables again.

---

## Problems I faced (challenges)

| Problem | What I did |
|---|---|
| The Postgres version has **no "LineTotal" column** for the price of an order line | Calculated it myself: `quantity × price × (1 − discount)`. It matches the order totals exactly ($109,846,381.40). |
| **The first and last months are incomplete.** Data starts on 30 May 2022, and shop (reseller) orders stop after April 2025 | Marked only June 2022 to April 2025 as "full months" and used only those for growth. Otherwise May-June 2025 would show a fake 60-98% drop. |
| **2022 and 2025 are not full years** | Also compared the same months (January to April) every year. |
| **Product cost changes every year** | Joined each sale to the cost that was valid on the order date. |
| **Stores spend much more than individual buyers** | Ranked stores and individuals separately when making customer groups. |
| **Salespeople started at different times** | Compared them on revenue **per month**, not total revenue. |

---

## Things I assumed (assumptions)

- **Revenue** = order amount without tax and shipping.
- **Profit** = revenue − product cost (no shipping or office costs).
- **"Today"** = the last order date in the data (29 June 2025).
- **Purchase spend** does not include purchase orders that were *Rejected*.
- **Stock** in `productinventory` is the current stock.
- **Retention** for 2024 → 2025 is not final, because 2025 is not over yet.

---

## What I found (key results)

- **Growing fast:** revenue grew **+38%** in 2024, and **+74%** in Jan-Apr 2025 vs Jan-Apr 2024.
- **Online makes the profit:** online earns about **41%** profit, while resellers earn about **0%** (negative in 2024).
- **A few customers matter most:** **13%** of customers (Champions) bring **59%** of revenue, and **146 shops** worth **$12.4M** stopped ordering.
- **Products:** Mountain-200 bikes sell best, while **32 products lose money** (mostly Touring bikes and jerseys).
- **Stock problem:** **46 products** that customers buy are **out of stock** ($4.75M of sales in the last year).
- **Purchasing:** in Q1 2025 the company **spent more on purchases ($13.6M) than it earned from sales ($12.8M)**, and **25%** of purchase money goes to suppliers that reject **5%+** of items.

The full list of **5 opportunities, 5 risks and 5 recommendations** is at the end of the notebook.
