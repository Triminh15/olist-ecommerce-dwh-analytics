--1. Executive Overview & High-Level KPIs
-- Executive Overall Summary (Revenue, Orders, AOV, Customers)
SELECT 
    SUM(f.price + f.freight_value) AS total_revenue,
    SUM(f.price) AS total_product_sales,
    COUNT(DISTINCT f.order_id) AS total_orders,
    SUM(f.price + f.freight_value) / NULLIF(COUNT(DISTINCT f.order_id), 0) AS aov,
    COUNT(DISTINCT c.customer_unique_id) AS total_customers
FROM fact_order_items f
JOIN dim_customer c ON f.customer_key = c.customer_key;

-- Monthly Revenue and Order Trends
SELECT 
    d.year,
    d.month,
    d.month_name,
    COUNT(DISTINCT f.order_id) AS total_orders,
    SUM(f.price + f.freight_value) AS total_revenue
FROM fact_order_items f
JOIN dim_date d ON f.order_purchase_date_key = d.date_key
GROUP BY d.year, d.month, d.month_name
ORDER BY d.year, d.month;

-- Order Status Breakdown and Revenue Impact
SELECT 
    order_status,
    COUNT(DISTINCT order_id) AS order_count,
    SUM(price + freight_value) AS status_revenue
FROM fact_order_items
GROUP BY order_status
ORDER BY order_count DESC;

--2. Customer Behavior & Geographic Analysis
-- Revenue and Customer Distribution by City and State
SELECT 
    c.customer_city,
    c.customer_state,
    COUNT(DISTINCT c.customer_unique_id) AS total_customers,
    COUNT(DISTINCT f.order_id) AS total_orders,
    SUM(f.price + f.freight_value) AS state_revenue
FROM fact_order_items f
JOIN dim_customer c ON f.customer_key = c.customer_key
GROUP BY c.customer_state, c.customer_city
ORDER BY state_revenue DESC;

-- Repeat Customer Rate Analysis
WITH customer_orders AS (
    SELECT 
        c.customer_unique_id,
        COUNT(DISTINCT f.order_id) AS order_count
    FROM fact_order_items f
    JOIN dim_customer c ON f.customer_key = c.customer_key
    GROUP BY c.customer_unique_id
)
SELECT 
    COUNT(CASE WHEN order_count = 1 THEN 1 END) AS one_time_customers,
    COUNT(CASE WHEN order_count > 1 THEN 1 END) AS repeat_customers,
    CAST(COUNT(CASE WHEN order_count > 1 THEN 1 END) * 100.0 / COUNT(*) AS DECIMAL(5,2)) AS repeat_customer_rate_percentage
FROM customer_orders;

--3. Product Performance & Category Insights
-- Top 10 Product Categories by Revenue
SELECT TOP 10
    p.product_category_name_english,
    COUNT(f.order_item_id) AS total_items_sold,
    SUM(f.price) AS pure_product_revenue,
    SUM(f.price + f.freight_value) AS total_revenue_with_shipping
FROM fact_order_items f join dim_product p on f.product_key = p.product_key
GROUP BY p.product_category_name_english
ORDER BY total_revenue_with_shipping DESC;

-- Average Freight Cost to Price Ratio by Product Category
SELECT 
    p.product_category_name_english,
    AVG(f.price) AS avg_product_price,
    AVG(f.freight_value) AS avg_freight_value,
    AVG(f.freight_value / NULLIF(f.price, 0)) * 100 AS avg_freight_to_price_ratio_percentage
FROM fact_order_items f
JOIN dim_product p ON f.product_key = p.product_key
GROUP BY p.product_category_name_english
ORDER BY avg_freight_value DESC;

--4. Operations, Logistics & Shipping Performance
-- Order-Level Shipping Cost Ratio and Delivery Duration Sample
SELECT TOP 100
    order_id,
    price,
    freight_value,
    CAST(freight_value / NULLIF(price, 0) * 100 AS DECIMAL(10,2)) AS freight_percentage_of_price,
    DATEDIFF(day, order_purchase_timestamp, order_delivered_customer_date) AS delivery_days
FROM fact_order_items
WHERE order_delivered_customer_date IS NOT NULL
ORDER BY order_purchase_timestamp DESC;

-- Overall Logistics Performance (Average Delivery Days and Late Rate)
SELECT 
    AVG(CAST(DATEDIFF(day, order_purchase_timestamp, order_delivered_customer_date) AS FLOAT)) AS avg_delivery_days,
    CAST(SUM(CASE WHEN order_delivered_customer_date > shipping_limit_date THEN 1 ELSE 0 END) * 100.0 / COUNT(*) AS DECIMAL(5,2)) AS late_delivery_rate_percentage
FROM fact_order_items
WHERE order_delivered_customer_date IS NOT NULL 
  AND shipping_limit_date IS NOT NULL;

-- Logistics Bottleneck Analysis (Late Delivery Rate by Region)
SELECT 
    c.customer_city,
    c.customer_state,
    COUNT(f.order_id) AS total_delivered_orders,
    SUM(CASE WHEN f.order_delivered_customer_date > f.shipping_limit_date THEN 1 ELSE 0 END) AS late_orders_count,
    CAST(SUM(CASE WHEN f.order_delivered_customer_date > f.shipping_limit_date THEN 1 ELSE 0 END) * 100.0 / COUNT(f.order_id) AS DECIMAL(5,2)) AS state_late_rate_percentage
FROM fact_order_items f
JOIN dim_customer c ON f.customer_key = c.customer_key
WHERE f.order_delivered_customer_date IS NOT NULL
GROUP BY c.customer_state, c.customer_city
ORDER BY state_late_rate_percentage DESC;

--5. Payment & Financial Analytics
-- Payment Methods Distribution & Revenue Contribution
SELECT 
    payment_type,
    COUNT(DISTINCT order_id) AS total_orders,
    SUM(payment_value) AS total_payment_value,
    CAST(SUM(payment_value) * 100.0 / (SELECT SUM(payment_value) FROM stg_order_payments) AS DECIMAL(5,2)) AS revenue_share_percentage
FROM stg_order_payments
GROUP BY payment_type
ORDER BY total_payment_value DESC;

-- Installment Behavior Analysis
SELECT 
    payment_installments,
    COUNT(DISTINCT order_id) AS total_orders,
    SUM(payment_value) AS total_payment_value,
    AVG(payment_value) AS avg_payment_per_installment
FROM stg_order_payments
GROUP BY payment_installments
ORDER BY payment_installments ASC;

--6. Customer Satisfaction & Seller Marketplace Analytics
-- Customer Satisfaction and Review Score Breakdown
SELECT 
    review_score,
    COUNT(review_id) AS total_reviews,
    CAST(COUNT(review_id) * 100.0 / (SELECT COUNT(*) FROM stg_order_reviews) AS DECIMAL(5,2)) AS review_percentage
FROM stg_order_reviews
GROUP BY review_score
ORDER BY review_score DESC;

-- Top Performing Sellers by Revenue
SELECT TOP 10
    s.seller_id,
    s.seller_city,
    s.seller_state,
    COUNT(DISTINCT f.order_id) AS total_orders_fulfilled,
    SUM(f.price + f.freight_value) AS total_seller_revenue
FROM fact_order_items f
JOIN dim_seller s ON f.seller_key = s.seller_key
GROUP BY s.seller_id, s.seller_city, s.seller_state
ORDER BY total_seller_revenue DESC;

-- Impact of Delivery Delay on Customer Review Scores
SELECT 
    r.review_score,
    COUNT(DISTINCT r.order_id) AS total_orders,
    AVG(CAST(DATEDIFF(day, o.order_purchase_timestamp, o.order_delivered_customer_date) AS FLOAT)) AS avg_actual_delivery_days,
    SUM(CASE WHEN o.order_delivered_customer_date > o.order_estimated_delivery_date THEN 1 ELSE 0 END) AS delayed_orders_count,
    CAST(SUM(CASE WHEN o.order_delivered_customer_date > o.order_estimated_delivery_date THEN 1 ELSE 0 END) * 100.0 / COUNT(DISTINCT r.order_id) AS DECIMAL(5,2)) AS delay_percentage_in_group
FROM stg_order_reviews r
JOIN stg_orders o ON r.order_id = o.order_id
WHERE o.order_delivered_customer_date IS NOT NULL
GROUP BY r.review_score
ORDER BY r.review_score DESC;

--7. Advanced Time Intelligence
-- Year-over-Year (YoY) Sales Growth Analysis
WITH yearly_revenue AS (
    SELECT 
        d.year,
        SUM(f.price + f.freight_value) AS annual_revenue
    FROM fact_order_items f
    JOIN dim_date d ON f.order_purchase_date_key = d.date_key
    GROUP BY d.year
)
SELECT 
    curr.year,
    curr.annual_revenue AS current_year_revenue,
    prev.annual_revenue AS previous_year_revenue,
    CAST((curr.annual_revenue - prev.annual_revenue) * 100.0 / NULLIF(prev.annual_revenue, 0) AS DECIMAL(10,2)) AS yoy_growth_percentage
FROM yearly_revenue curr
LEFT JOIN yearly_revenue prev ON curr.year = prev.year + 1
ORDER BY curr.year;