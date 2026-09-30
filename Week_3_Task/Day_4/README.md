# Music Store Business Intelligence Project
In this project I used SQL (PostgreSQL) on a music store database. I grouped customers into segments, ranked countries, and made marketing suggestions.
All code is in `Business_Intelligence_Pipeline.sql`.

---

## Segmentation Logic
I compared every customer with the average of all customers and gave points:
- Spent more than average = **2 points**
- Bought in more months than average = **1 point**
- Bought more genres than average = **1 point**
- Bought more artists than average = **1 point**
Then:
- 4 or 5 points = **Platinum**
- 3 points = **Gold**
- 2 points = **Silver**
- 0 or 1 point = **Bronze**
**Why:** Spending gets 2 points because money matters most for the business. Months show loyalty, and genres/artists show how much music the customer explores.

---

## Country Ranking Methodology
I ranked every country in 6 things and gave each one a weight:
- Total revenue – 25%
- Number of customers – 20%
- Revenue per customer – 20%
- Genres bought – 15%
- Average bill size – 10%
- Types of customers – 10%
Then I added them together. **Lower score = better country.** The top 3 countries are best for expansion.
I used ranks because the numbers are of different sizes, so ranks make it fair.

---

## Marketing Strategy
Each segment gets a different campaign based on its favorite genre:
- **Platinum** – Early access to new releases
- **Gold** – Album bundles
- **Silver** – Genre discounts
- **Bronze** – Win-back coupons

---

## Recommendations
1. Give Platinum customers early access so they stay loyal.
2. Offer album bundles to Gold customers so they spend more.
3. Send coupons to Bronze customers to bring them back.
4. Focus marketing on the top 3 countries.
5. Promote the top artist and top album more.
6. Other employees should learn from the top employee.

---

## Challenges and Solutions
1. **Money was counted twice** when joining invoice with invoice_line.
   **Solution:** I calculated money and songs in separate CTEs and then joined them.

2. **Normal AVG gave only one row**, so I couldn't compare each customer.
   **Solution:** I used `AVG() OVER ()` so the average shows on every row.

3. **Some customers had two favorite genres** (tie).
   **Solution:** I used `ROW_NUMBER()` so each customer gets only one.

4. **LIMIT gave an error inside UNION ALL.**
   **Solution:** I put those queries inside brackets `( )`.

---

## 6. Screenshots
Screenshots are in the `screenshots` folder:
1. `executive_report.png` – Final executive report (Stage 6 dashboard)
2. `customer_segments.png` – Customer segmentation results (Stage 2)
3. `country_ranking.png` – Country ranking results (Stage 4)
4. `pipeline_success.png` – Successful execution of the complete SQL file

---

## How to Run
1. Open pgAdmin (or any PostgreSQL tool) and connect to the music store database.
2. Open `Business_Intelligence_Pipeline.sql`.
3. Run the stages in order (Stage 1 to Stage 5), because each view uses the one before it.
4. For the bonus, run the whole Stage 6 query from `WITH` to the last `;`.