-- ============================================================
-- Logistics Operations Analytics Project
-- Author: Umesh Zampadiya
-- Database: sales_ops_analytics
-- Description: End-to-end SQL analysis for logistics and sales operations
-- ============================================================


-- ============================================================
-- 1. DATABASE CREATION
-- ============================================================

CREATE DATABASE IF NOT EXISTS sales_ops_analytics;
USE sales_ops_analytics;


-- ============================================================
-- 2. TABLE CREATION
-- ============================================================

-- Customers Table
CREATE TABLE customers (
    customer_id INT PRIMARY KEY,
    customer_name VARCHAR(100),
    city VARCHAR(50),
    state VARCHAR(50),
    segment VARCHAR(50)
);

-- Products Table
CREATE TABLE products (
    product_id INT PRIMARY KEY,
    product_name VARCHAR(100),
    category VARCHAR(50),
    price DECIMAL(10,2)
);

-- Orders Table
CREATE TABLE orders (
    order_id INT PRIMARY KEY,
    order_date DATE,
    customer_id INT,
    order_status VARCHAR(50),
    sales_rep VARCHAR(50),
    FOREIGN KEY (customer_id) REFERENCES customers(customer_id)
        ON DELETE CASCADE
);

-- Order Items Table
CREATE TABLE order_items (
    order_item_id INT PRIMARY KEY,
    order_id INT,
    product_id INT,
    quantity INT,
    unit_price DECIMAL(10,2),
    FOREIGN KEY (order_id) REFERENCES orders(order_id)
        ON DELETE CASCADE,
    FOREIGN KEY (product_id) REFERENCES products(product_id)
        ON DELETE CASCADE
);

-- Shipments Table
CREATE TABLE shipments (
    shipment_id INT PRIMARY KEY,
    order_id INT,
    ship_date DATE,
    delivery_date DATE,
    status VARCHAR(30),
    FOREIGN KEY (order_id) REFERENCES orders(order_id)
        ON DELETE CASCADE
);


-- ============================================================
-- 3. DATA QUALITY CHECKS
-- ============================================================

-- Check missing deliveries
SELECT COUNT(*) AS missing_deliveries
FROM shipments
WHERE delivery_date IS NULL;

-- Check negative or zero quantities
SELECT *
FROM order_items
WHERE quantity <= 0;

-- Check duplicate orders
SELECT order_id, COUNT(*) AS duplicate_count
FROM orders
GROUP BY order_id
HAVING COUNT(*) > 1;


-- ============================================================
-- 4. BUSINESS ANALYSIS QUERIES (BASIC METHOD)
-- ============================================================

-- Q1. Total Revenue
SELECT SUM(quantity * unit_price) AS total_revenue
FROM order_items;


-- Q2. Monthly Revenue
SELECT 
    DATE_FORMAT(o.order_date,'%Y-%m') AS month,
    SUM(oi.quantity * oi.unit_price) AS revenue
FROM order_items oi
JOIN orders o ON oi.order_id = o.order_id
GROUP BY month
ORDER BY month;


-- Q3. Top Customers by Revenue
SELECT 
    c.customer_name,
    SUM(oi.quantity * oi.unit_price) AS revenue
FROM customers c
JOIN orders o ON c.customer_id = o.customer_id
JOIN order_items oi ON o.order_id = oi.order_id
GROUP BY c.customer_name
ORDER BY revenue DESC;


-- Q4. Top Selling Products by Quantity
SELECT 
    p.product_name,
    SUM(oi.quantity) AS total_quantity_sold
FROM products p
JOIN order_items oi ON p.product_id = oi.product_id
GROUP BY p.product_name
ORDER BY total_quantity_sold DESC;


-- Q5. Revenue by Product Category
SELECT 
    p.category,
    SUM(oi.quantity * oi.unit_price) AS revenue
FROM products p
JOIN order_items oi ON p.product_id = oi.product_id
GROUP BY p.category;


-- Q6. Average Delivery Time
SELECT 
    AVG(DATEDIFF(delivery_date, ship_date)) AS avg_delivery_days
FROM shipments
WHERE delivery_date IS NOT NULL;


-- Q7. Late Delivery Percentage (>3 days)
SELECT 
    ROUND(
        SUM(
            CASE 
                WHEN DATEDIFF(delivery_date, ship_date) > 3 THEN 1 
                ELSE 0 
            END
        ) / COUNT(*) * 100,
    2) AS late_delivery_percentage
FROM shipments
WHERE delivery_date IS NOT NULL;


-- Q8. Orders by Status
SELECT 
    order_status,
    COUNT(*) AS total_orders
FROM orders
GROUP BY order_status;


-- Q9. Orders with Longest Delivery Delay
SELECT 
    order_id,
    DATEDIFF(delivery_date, ship_date) AS delay_days
FROM shipments
WHERE delivery_date IS NOT NULL
ORDER BY delay_days DESC;


-- Q10. Monthly Revenue vs Average Delivery Time
SELECT 
    DATE_FORMAT(o.order_date, '%Y-%m') AS month,
    SUM(oi.quantity * oi.unit_price) AS revenue,
    AVG(DATEDIFF(s.delivery_date, s.ship_date)) AS avg_delivery_days
FROM orders o
JOIN order_items oi ON o.order_id = oi.order_id
JOIN shipments s ON o.order_id = s.order_id
GROUP BY month
ORDER BY month DESC;


-- ============================================================
-- 5. ADVANCED SQL ANALYSIS (CTE, WINDOW FUNCTIONS, VIEW, PROCEDURE)
-- ============================================================

-- Total Revenue using CTE
WITH revenue_data AS (
    SELECT quantity * unit_price AS revenue
    FROM order_items
)
SELECT SUM(revenue) AS total_revenue
FROM revenue_data;


-- Monthly Revenue using CTE
WITH monthly_sales AS (
    SELECT 
        o.order_date,
        oi.quantity * oi.unit_price AS revenue
    FROM orders o
    JOIN order_items oi ON o.order_id = oi.order_id
)
SELECT 
    DATE_FORMAT(order_date, '%Y-%m') AS month,
    SUM(revenue) AS total_revenue
FROM monthly_sales
GROUP BY month
ORDER BY month;


-- Top Customer using Window Function
WITH customer_sales AS (
    SELECT 
        c.customer_name,
        SUM(oi.quantity * oi.unit_price) AS revenue
    FROM customers c
    JOIN orders o ON c.customer_id = o.customer_id
    JOIN order_items oi ON o.order_id = oi.order_id
    GROUP BY c.customer_name
),
ranked_customer AS (
    SELECT 
        customer_name,
        revenue,
        RANK() OVER (ORDER BY revenue DESC) AS rank_position
    FROM customer_sales
)
SELECT *
FROM ranked_customer
WHERE rank_position = 1;


-- Category Revenue View
CREATE OR REPLACE VIEW category_revenue AS
SELECT 
    p.category,
    oi.quantity * oi.unit_price AS revenue
FROM products p
JOIN order_items oi ON p.product_id = oi.product_id;

SELECT 
    category,
    SUM(revenue) AS total_revenue
FROM category_revenue
GROUP BY category;


-- Stored Procedure for Monthly KPI
DELIMITER $$

DROP PROCEDURE IF EXISTS monthly_sales_kpi $$

CREATE PROCEDURE monthly_sales_kpi(
    IN p_year INT,
    IN p_month INT
)
BEGIN
    SELECT 
        DATE_FORMAT(o.order_date,'%Y-%m') AS month,
        SUM(oi.quantity * oi.unit_price) AS revenue,
        AVG(DATEDIFF(s.delivery_date, s.ship_date)) AS avg_delivery_days
    FROM orders o
    JOIN order_items oi ON o.order_id = oi.order_id
    JOIN shipments s ON o.order_id = s.order_id
    WHERE YEAR(o.order_date) = p_year
    AND MONTH(o.order_date) = p_month
    GROUP BY month;
END $$

DELIMITER ;

CALL monthly_sales_kpi(2025,3);

-- ============================================================
-- END OF PROJECT
-- ============================================================