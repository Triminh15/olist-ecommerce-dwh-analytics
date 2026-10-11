# 🛒 Olist E-commerce: Galaxy Schema Data Warehouse & Business Intelligence Analytics
> **End-to-End Data Analyst, Data Engineering & BI Portfolio transforming raw Brazilian marketplace data into a centralized analytical data warehouse and an interactive 3-page executive dashboard.**

---

## 📌 1. Business Context & Objectives

### Problem Statement
Operating a large-scale e-commerce marketplace like **Olist Store** generates millions of fragmented transactional records spanning customer orders, item lines, payments, reviews, and logistics. Without a centralized analytical repository, business stakeholders face severe blind spots regarding revenue drivers, regional delivery bottlenecks, and vendor performance distribution.

### Project Objectives
- **Architecting a Robust DWH:** Transition raw, uncleaned transactional data into a normalized **Galaxy Schema Data Warehouse** hosted in SQL Server (SSMS) to ensure data integrity and query performance.
- **Diagnostic & Operational Analytics:** Diagnose revenue scaling patterns, quantify shipping delay risks across Brazilian states, and evaluate merchant concentration using the Pareto principle ($80/20$ rule).
- **Executive BI Dashboard:** Surface actionable intelligence through a professionally designed, multi-page Power BI Dashboard following enterprise dark-theme UI standards (`#0D1117`).

### Tech Stack
- **Database & SQL:** SQL Server (SSMS, T-SQL, ETL Pipelines, CTEs, Views)
- **Business Intelligence:** Power BI Desktop (Galaxy Schema Modeling, Advanced DAX, UI/UX Design)
- **Version Control:** Git / GitHub

---

## 🏗️ 2. Data Architecture & ERD

To handle multi-faceted analytical queries without performance bottlenecks, the relational structure was refactored into a **Galaxy Schema** (Fact-Constellation Schema), where multiple fact tables share common dimension tables.

### Schema Breakdown
- **Dimension Tables (Shared Core):**
  - `dim_customer`: Standardized customer profiles (`customer_unique_id`, city, uppercase state codes).
  - `dim_product`: Product catalog metadata with sanitized English category mappings (`'Unknown'` fallback) and dimension bounds.
  - `dim_seller`: Marketplace vendor profiles capturing geographical footprints.
  - `dim_date`: Comprehensive calendar dimension (`2016-01-01` to `2018-12-31`) providing hierarchical time attributes.
- **Fact Tables (Domain-Specific Grains):**
  - `fact_order_items`: Granular line-item grain tracking unit price and freight value.
  - `fact_orders`: Order-level grain tracking lifecycle timelines and statuses.
  - `fact_payments`: Captures payment methods, installments, and values.
  - `fact_reviews`: Records customer satisfaction scores linked to order fulfillment.

```
       +------------------+             +------------------+
       |   dim_product    |             |   dim_customer   |
       +------------------+             +------------------+
       | PK product_key   |             | PK customer_key  |
       |    product_id    |             |    customer_id   |
       +--------+---------+             +--------+---------+
                |                                |
                | N                              | N
+---------------+--------------------------------+---------------+
|                         fact_order_items                        |
+-----------------------------------------------------------------+
| FK  order_item_id, product_key, customer_key, seller_key, date  |
|     price, freight_value                                        |
+---------------+--------------------------------+----------------+
                |                                | 1
                | 1                              |
       +--------+---------+             +--------+---------+
       |    dim_seller    |             |     dim_date     |
       +------------------+             +------------------+
       | PK seller_key    |             | PK date_key      |
       |    seller_id     |             |    full_date     |
       +------------------+             +------------------+
```

---

## ⚙️ 3. Các Giai đoạn Triển khai Kỹ thuật (Implementation & ETL Stages)

### Stage 1: Staging & Data Cleaning (ETL Preparation)
- **String Standardization:** Applied `LTRIM`, `RTRIM`, and `UPPER` on city and state fields across customer and seller staging tables to eliminate whitespace anomalies and formatting discrepancies.
- **Handling Missing Values:** Replaced `NULL` product category names with `'Unknown'` and default-initialized missing physical dimensions/weights to `0` to prevent downstream mathematical errors.

### Stage 2: Data Warehouse Modeling & Anti-Fan-Out Strategy (SQL Server T-SQL)
- **Surrogate Keys & Identity:** Created primary keys using `IDENTITY(1,1)` across all dimensions to ensure efficient indexing.
- **Anti-Fan-Out Optimization in `fact_orders`:** 
  To prevent row explosion (fan-out duplication) during table loading caused by multiple customer records sharing the same base identifier, a Common Table Expression (CTE) utilizing `MIN(customer_key)` was implemented:
  ```sql
  WITH CleanCustomers AS (
      SELECT sc.customer_id, MIN(c.customer_key) AS customer_key 
      FROM stg_customers sc
      JOIN dim_customer c ON sc.customer_unique_id = c.customer_unique_id
      GROUP BY sc.customer_id
  )
  SELECT o.order_id, ISNULL(cc.customer_key, -1) AS customer_key, ...
  INTO fact_orders FROM stg_orders o
  LEFT JOIN CleanCustomers cc ON o.customer_id = cc.customer_id;
  ```

### Stage 3: Semantic Layer & Advanced DAX Architecture
Developed rigorous semantic calculations organized by business domains:
- **Financial & Volume:** 
  $$\text{Average Order Value} = \frac{\text{[Total Sales]}}{\text{[Total Orders]}}$$
- **Operations & Logistics:** Precise delivery duration calculations utilizing second differences divided by 86,400 to obtain exact fractional days, paired with strict delay evaluations:
  $$\text{Delayed Orders \%} = \frac{\text{Orders where Delivered Date } > \text{ Estimated Date}}{\text{Total Delivered Orders}}$$
- **Marketplace Performance:** Automated ABC categorization and low-rated seller ratio metrics ($<\text{3.5 stars}$).

---

## 🔍 4. Diagnostic Findings

| Domain | Data Evidence | Root Cause & Impact |
| :--- | :--- | :--- |
| **Financial Scaling** | Monthly revenue expanded dramatically from $\sim \$120,000$ in early 2017 to peak at over $\$1.45\text{M}$ per month by late 2018. | Reflects rapid market penetration and successful merchant acquisition by the platform, though accompanied by logistical friction. |
| **Logistics Delays** | States such as Rio de Janeiro (RJ) and Bahia (BA) exhibit delay rates up to $3\times$ higher than economic hubs like São Paulo (SP). | Geographical transit distance across Brazil combined with regional carrier infrastructure bottlenecks directly impairs customer satisfaction. |
| **ABC Concentration** | The top $10\%$ of active vendors (**Elite / Champions**) generate over $50\%$ of cumulative platform revenue. | Demonstrates strong adherence to the Pareto principle; platform liquidity relies heavily on core merchants, requiring targeted retention policies. |

---

## 📊 5. Dashboard Overview

The Power BI report is structured into **3 dedicated operational lenses** linked via a synchronized dark theme (`#0D1117`):
1. **Page 1: General Overview & Financial Health** – Executive KPI cards (`[Total Sales]`, `[Total Orders]`, `[AOV]`), monthly revenue trend analysis, and top-performing product categories.
2. **Page 2: Supply Chain & Logistics Bottlenecks** – Geographical heatmaps of delivery delays, `[Freight to Sales Ratio]` impact, and carrier lead-time evaluations.
3. **Page 3: Seller Performance & Risk Management** – ABC Analysis Donut Chart (`[Seller_Segment]`), low-rated vendor tracking tables, and processing time distributions.

---

## 💡 6. Strategic Recommendations

1. **Regional Logistics Optimization:** Establish localized fulfillment hubs or partner with regional third-party logistics (3PL) providers in high-delay states (RJ, BA) to reduce transit duration.
2. **Tiered Vendor Management Program:** Implement automated incentive programs (e.g., lower commission fees) for **Elite / Champions** while enforcing SLA penalties or training for low-rated long-tail sellers.
3. **Transparent Shipping Estimations:** Incorporate dynamic machine learning-based delivery estimates at checkout rather than static rule-based timelines to manage customer expectations.

---

## 📁 7. Repository Structure

```plaintext
Olist E-commerce Project/
├── Olist_Documentation.md
├── README.md
├── Data/
│   ├── olist_customers_dataset.csv
│   ├── olist_geolocation_dataset.csv
│   ├── olist_orders_dataset.csv
│   ├── olist_order_items_dataset.csv
│   ├── olist_order_payments_dataset.csv
│   ├── olist_order_reviews_dataset.csv
│   ├── olist_products_dataset.csv
│   ├── olist_sellers_dataset.csv
│   └── product_category_name_translation.csv
├── PowerBI/
│   ├── DAX Measures & Business Intelligence.md
│   ├── Executive Growth & Revenue Engine.jpg
│   ├── Model view.jpg
│   ├── Olist E-Commerce Dashboard Video.mp4
│   ├── Olist E-Commerce Performance Dashboard.pbix
│   ├── Seller Performance & Detailed Analysis.jpg
│   └── Supply Chain Bottleneck & Logistics Risk.jpg
└── SQL/
    ├── Data Exploring.sql
    └── Star Schema.sql

```