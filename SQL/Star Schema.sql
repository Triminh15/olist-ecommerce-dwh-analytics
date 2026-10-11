-- 1.1 Dimension Table: dim_customer
CREATE TABLE dim_customer (
    customer_key INT IDENTITY(1,1) PRIMARY KEY,
    customer_unique_id VARCHAR(50) NOT NULL,
    customer_city VARCHAR(100),
    customer_state VARCHAR(10)
);

-- Data Cleaning: Trim whitespaces from city names, convert state codes to uppercase, and filter out records with NULL unique IDs.
INSERT INTO dim_customer (customer_unique_id, customer_city, customer_state)
SELECT DISTINCT 
    customer_unique_id,
    LTRIM(RTRIM(customer_city)) AS customer_city, 
    UPPER(TRIM(customer_state))) AS customer_state 
FROM stg_customers
WHERE customer_unique_id IS NOT NULL; 


-- 1.2 Dimension Table: dim_product
CREATE TABLE dim_product (
    product_key INT IDENTITY(1,1) PRIMARY KEY,
    product_id VARCHAR(50) NOT NULL,
    product_category_name_english VARCHAR(100),
    product_weight_g FLOAT,
    product_length_cm FLOAT,
    product_height_cm FLOAT,
    product_width_cm FLOAT
);

-- Data Cleaning: Handle missing category translations by defaulting to 'Unknown' and replace NULL weights/dimensions with 0 to prevent downstream calculation errors.
INSERT INTO dim_product (
    product_id, product_category_name_english, 
    product_weight_g, product_length_cm, product_height_cm, product_width_cm
)
SELECT 
    p.product_id,
    COALESCE(t.product_category_name_english, 'Unknown') AS product_category_name_english,
    COALESCE(p.product_weight_g, 0) AS product_weight_g,
    COALESCE(p.product_length_cm, 0) AS product_length_cm,
    COALESCE(p.product_height_cm, 0) AS product_height_cm,
    COALESCE(p.product_width_cm, 0) AS product_width_cm
FROM stg_products p
LEFT JOIN stg_category_translation t 
    ON p.product_category_name = t.product_category_name
WHERE p.product_id IS NOT NULL;


-- 1.3 Dimension Table: dim_seller
CREATE TABLE dim_seller (
    seller_key INT IDENTITY(1,1) PRIMARY KEY,
    seller_id VARCHAR(50) NOT NULL,
    seller_city VARCHAR(100),
    seller_state VARCHAR(10)
);

-- Data Cleaning: Trim leading/trailing whitespaces from seller city and standardize seller state to uppercase.
INSERT INTO dim_seller (seller_id, seller_city, seller_state)
SELECT DISTINCT 
    seller_id,
    LTRIM(RTRIM(seller_city)) AS seller_city,
    UPPER(LTRIM(RTRIM(seller_state))) AS seller_state
FROM stg_sellers
WHERE seller_id IS NOT NULL;

-- 1.4 Dimension Table: dim_date
CREATE TABLE dim_date (
    date_key INT PRIMARY KEY, -- Format: YYYYMMDD
    full_date DATE,
    year INT,
    quarter INT,
    month INT,
    month_name VARCHAR(20),
    day INT,
    day_of_week INT,
    day_name VARCHAR(20)
);

-- Data Generation: Populate calendar date dimension ranging from 2016-01-01 to 2018-12-31 with hierarchical time attributes.
DECLARE @StartDate DATE = '2016-01-01';
DECLARE @EndDate DATE = '2018-12-31';

WHILE @StartDate <= @EndDate
BEGIN
    INSERT INTO dim_date (date_key, full_date, year, quarter, month, month_name, day, day_of_week, day_name)
    SELECT 
        CAST(FORMAT(@StartDate, 'yyyyMMdd') AS INT),
        @StartDate,
        YEAR(@StartDate),
        DATEPART(QUARTER, @StartDate),
        MONTH(@StartDate),
        DATENAME(MONTH, @StartDate),
        DAY(@StartDate),
        DATEPART(WEEKDAY, @StartDate),
        DATENAME(WEEKDAY, @StartDate);

    SET @StartDate = DATEADD(day, 1, @StartDate);
END

-- 1.5 Fact Table: fact_order_items
CREATE TABLE fact_order_items (
    order_id VARCHAR(50) NOT NULL,
    order_item_id INT NOT NULL,
    customer_key INT,
    product_key INT,
    seller_key INT,
    order_purchase_date_key INT, 
    order_status VARCHAR(50),
    order_purchase_timestamp DATETIME,
    order_delivered_customer_date DATETIME,
    shipping_limit_date DATETIME,
    price DECIMAL(10, 2),
    freight_value DECIMAL(10, 2)
);

-- Data Processing: Map granular order line items with foreign keys (customer, product, seller, date) and safely cast datetimes and financial values.
INSERT INTO fact_order_items (
    order_id, order_item_id, customer_key, product_key, seller_key, 
    order_purchase_date_key, order_status, order_purchase_timestamp, 
    order_delivered_customer_date, shipping_limit_date, price, freight_value
)
SELECT 
    i.order_id,
    i.order_item_id,
    c.customer_key,
    p.product_key,
    s.seller_key,
    ISNULL(CAST(FORMAT(TRY_CAST(o.order_purchase_timestamp AS DATETIME), 'yyyyMMdd') AS INT), 19000101) AS order_purchase_date_key,
    o.order_status,
    TRY_CAST(o.order_purchase_timestamp AS DATETIME) AS order_purchase_timestamp,
    TRY_CAST(o.order_delivered_customer_date AS DATETIME) AS order_delivered_customer_date,
    TRY_CAST(i.shipping_limit_date AS DATETIME) AS shipping_limit_date,
    i.price,
    i.freight_value
FROM stg_order_items i
JOIN stg_orders o 
    ON i.order_id = o.order_id
JOIN stg_customers sc 
    ON o.customer_id = sc.customer_id
JOIN dim_customer c 
    ON sc.customer_unique_id = c.customer_unique_id
JOIN dim_product p 
    ON i.product_id = p.product_id
JOIN dim_seller s 
    ON i.seller_id = s.seller_id


-- 1.6 Fact Table: fact_payments
CREATE TABLE fact_payments (
    order_id VARCHAR(50) NOT NULL,
    customer_key INT NULL,
    order_purchase_date_key INT NULL,
    payment_sequential INT NOT NULL,
    payment_type VARCHAR(50) NOT NULL,
    payment_installments INT NOT NULL,
    payment_value DECIMAL(10,2) NOT NULL
);

-- Data Processing: Capture payment types, installments, and values per order, handling missing mappings with default fallback keys (-1 / 'unknown').
INSERT INTO fact_payments (
    order_id, 
    customer_key, 
    order_purchase_date_key, 
    payment_sequential, 
    payment_type, 
    payment_installments, 
    payment_value
)
SELECT 
    p.order_id,
    ISNULL(c.customer_key, -1) AS customer_key,
    ISNULL(d.date_key, 19000101) AS order_purchase_date_key,
    p.payment_sequential,
    ISNULL(LOWER(TRIM(p.payment_type)), 'unknown') AS payment_type,
    ISNULL(p.payment_installments, 1) AS payment_installments,
    COALESCE(p.payment_value, 0.00) AS payment_value
FROM stg_order_payments p
LEFT JOIN stg_orders o ON p.order_id = o.order_id
LEFT JOIN stg_customers sc ON o.customer_id = sc.customer_id
LEFT JOIN dim_customer c ON sc.customer_unique_id = c.customer_unique_id 
LEFT JOIN dim_date d ON CAST(o.order_purchase_timestamp AS DATE) = d.full_date;


-- 1.7 Fact Table: fact_reviews
CREATE TABLE fact_reviews (
    review_id VARCHAR(50) NOT NULL,
    order_id VARCHAR(50) NOT NULL,
    customer_key INT NULL,
    review_date_key INT NULL,
    review_score INT NOT NULL
);

-- Data Processing: Record customer review scores mapped against order and customer dimensions, handling review creation date lookups.
INSERT INTO fact_reviews (
    review_id, 
    order_id, 
    customer_key, 
    review_date_key, 
    review_score
)
SELECT 
    r.review_id,
    r.order_id,
    ISNULL(c.customer_key, -1) AS customer_key,
    ISNULL(d.date_key, 19000101) AS review_date_key,
    ISNULL(r.review_score, 0) AS review_score

FROM stg_order_reviews r
LEFT JOIN stg_orders o ON r.order_id = o.order_id
LEFT JOIN stg_customers sc ON o.customer_id = sc.customer_id -- Nối qua bảng staging khách hàng
LEFT JOIN dim_customer c ON sc.customer_unique_id = c.customer_unique_id -- Nối sang dim theo unique_id chuẩn
LEFT JOIN dim_date d ON CAST(r.review_creation_date AS DATE) = d.full_date;


-- 1.8 Fact Table: fact_orders
CREATE TABLE fact_orders (
    order_id VARCHAR(50) NOT NULL,
    customer_key INT NULL,
    order_purchase_date_key INT NULL,
    order_status VARCHAR(50) NULL,
    order_purchase_timestamp DATETIME NULL,
    order_approved_at DATETIME NULL,
    order_delivered_carrier_date DATETIME NULL,
    order_delivered_customer_date DATETIME NULL,
    order_estimated_delivery_date DATETIME NULL
);

-- Uses a CTE (CleanCustomers) with MIN(customer_key) to deduplicate customer mappings beforehand. This guarantees a strict 1:1 grain per order_id and 
-- completely prevents row explosion (fan-out duplication) during table loading.
WITH CleanCustomers AS (
    SELECT 
        sc.customer_id,
        MIN(c.customer_key) AS customer_key 
    FROM stg_customers sc
    JOIN dim_customer c ON sc.customer_unique_id = c.customer_unique_id
    GROUP BY sc.customer_id
)

SELECT 
    o.order_id,
    ISNULL(cc.customer_key, -1) AS customer_key,
    ISNULL(d.date_key, 19000101) AS order_purchase_date_key,
    ISNULL(LOWER(TRIM(o.order_status)), 'unknown') AS order_status,
    o.order_purchase_timestamp,
    o.order_approved_at,
    o.order_delivered_carrier_date,
    o.order_delivered_customer_date,
    o.order_estimated_delivery_date

INTO fact_orders
FROM stg_orders o
LEFT JOIN CleanCustomers cc ON o.customer_id = cc.customer_id
LEFT JOIN dim_date d ON CAST(o.order_purchase_timestamp AS DATE) = d.full_date;