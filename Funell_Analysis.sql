/* =========================================================
   B2C E-commerce Funnel & Revenue Optimization Analysis
   Tools: MySQL + Power BI
   Author: [Your Name]
   ========================================================= */

/* =========================================================
   1. CREATE DATABASE
   ========================================================= */

CREATE DATABASE IF NOT EXISTS ecommerce_project;
USE ecommerce_project;


/* =========================================================
   2. CREATE TABLES
   ========================================================= */

/* Users Table */
CREATE TABLE users (
    user_id INT PRIMARY KEY,
    country VARCHAR(50),
    user_type VARCHAR(20),
    device VARCHAR(20)
);

/* Sessions Table */
CREATE TABLE sessions (
    session_id INT PRIMARY KEY,
    user_id INT,
    session_date DATE,
    FOREIGN KEY (user_id) REFERENCES users(user_id)
);

/* Events Table */
CREATE TABLE events (
    event_id INT PRIMARY KEY,
    session_id INT,
    event_type VARCHAR(50),
    FOREIGN KEY (session_id) REFERENCES sessions(session_id)
);

/* Orders Table */
CREATE TABLE orders (
    order_id INT PRIMARY KEY,
    user_id INT,
    order_value INT,
    payment_status VARCHAR(20),
    FOREIGN KEY (user_id) REFERENCES users(user_id)
);


/* =========================================================
   3. DATA VALIDATION
   ========================================================= */

-- Verify row counts
SELECT COUNT(*) AS total_users FROM users;
SELECT COUNT(*) AS total_sessions FROM sessions;
SELECT COUNT(*) AS total_events FROM events;
SELECT COUNT(*) AS total_orders FROM orders;


/* =========================================================
   4. FUNNEL ANALYSIS – DISTINCT USERS PER STEP
   ========================================================= */

SELECT 
    e.event_type,
    COUNT(DISTINCT s.user_id) AS users_count
FROM events e
JOIN sessions s 
    ON e.session_id = s.session_id
GROUP BY e.event_type
ORDER BY users_count DESC;


/* =========================================================
   5. FUNNEL CONVERSION PERCENTAGE (FROM HOMEPAGE)
   ========================================================= */

WITH funnel AS (
    SELECT 
        e.event_type,
        COUNT(DISTINCT s.user_id) AS users_count
    FROM events e
    JOIN sessions s 
        ON e.session_id = s.session_id
    GROUP BY e.event_type
)

SELECT 
    event_type,
    users_count,
    ROUND(
        users_count * 100.0 /
        (SELECT users_count 
         FROM funnel 
         WHERE event_type = 'homepage_view'),
        2
    ) AS conversion_from_homepage_percent
FROM funnel
ORDER BY users_count DESC;


/* =========================================================
   6. DEVICE-LEVEL FUNNEL ANALYSIS
   ========================================================= */

SELECT 
    u.device,
    e.event_type,
    COUNT(DISTINCT u.user_id) AS users_count
FROM users u
JOIN sessions s 
    ON u.user_id = s.user_id
JOIN events e 
    ON s.session_id = e.session_id
GROUP BY u.device, e.event_type
ORDER BY u.device, users_count DESC;


/* =========================================================
   7. REVENUE BY DEVICE (SUCCESSFUL ORDERS ONLY)
   ========================================================= */

SELECT 
    u.device,
    COUNT(o.order_id) AS total_orders,
    SUM(o.order_value) AS total_revenue,
    ROUND(AVG(o.order_value), 2) AS avg_order_value
FROM users u
JOIN orders o 
    ON u.user_id = o.user_id
WHERE o.payment_status = 'Success'
GROUP BY u.device;


/* =========================================================
   8. PAYMENT SUCCESS ANALYSIS
   ========================================================= */

SELECT 
    payment_status,
    COUNT(*) AS order_count
FROM orders
GROUP BY payment_status;


/* =========================================================
   9. CART ABANDONMENT & REVENUE LEAKAGE
   ========================================================= */

WITH cart_users AS (
    SELECT DISTINCT s.user_id
    FROM events e
    JOIN sessions s 
        ON e.session_id = s.session_id
    WHERE e.event_type = 'add_to_cart'
),
purchase_users AS (
    SELECT DISTINCT s.user_id
    FROM events e
    JOIN sessions s 
        ON e.session_id = s.session_id
    WHERE e.event_type = 'purchase'
),
avg_order AS (
    SELECT AVG(order_value) AS avg_value
    FROM orders
    WHERE payment_status = 'Success'
)

SELECT 
    (SELECT COUNT(*) FROM cart_users) AS total_cart_users,
    (SELECT COUNT(*) FROM purchase_users) AS total_purchase_users,
    ((SELECT COUNT(*) FROM cart_users) - 
     (SELECT COUNT(*) FROM purchase_users)) AS abandoned_users,
    ROUND(
        ((SELECT COUNT(*) FROM cart_users) - 
         (SELECT COUNT(*) FROM purchase_users))
        * (SELECT avg_value FROM avg_order),
        2
    ) AS estimated_revenue_leakage;