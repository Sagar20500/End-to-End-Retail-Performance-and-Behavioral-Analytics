Use  Retail_and_Behavioral_Analysis

SELECT * FROM sales_cleaned

SELECT * FROM INFORMATION_SCHEMA.KEY_COLUMN_USAGE
	WHERE 
		TABLE_NAME = 'sales_cleaned';

	SELECT 
		COLUMN_NAME,
		DATA_TYPE,
		CHARACTER_MAXIMUM_LENGTH
	FROM 
		INFORMATION_SCHEMA.COLUMNS
	WHERE 
		TABLE_NAME = 'sales_cleaned';

SELECT 
		COLUMN_NAME,
		DATA_TYPE,
		CHARACTER_MAXIMUM_LENGTH
	FROM 
		INFORMATION_SCHEMA.KEY_COLUMN_USAGE
	WHERE 
		TABLE_NAME = 'sales_cleaned';

ALTER TABLE sales_cleaned
ADD CONSTRAINT fk_sales_customer
FOREIGN KEY (customer_id)
REFERENCES customers_cleaned(customer_id);

-- Link to products
ALTER TABLE sales_cleaned
ADD CONSTRAINT fk_sales_product
FOREIGN KEY (product_id)
REFERENCES products_cleaned(product_id);

ALTER TABLE sales_cleaned
DROP CONSTRAINT fk_sales_product;

-- Link to stores (nullable is okay)
ALTER TABLE sales_cleaned
ADD CONSTRAINT fk_sales_store
FOREIGN KEY (store_id)
REFERENCES stores_cleaned(store_id);

ALTER TABLE sales_cleaned
DROP CONSTRAINT fk_sales_store;

SELECT DISTINCT store_id
FROM sales_cleaned
WHERE store_id IS NOT NULL
  AND store_id NOT IN (SELECT store_id FROM stores_cleaned);

UPDATE sales_cleaned
SET store_id = NULL
WHERE store_id IS NOT NULL
  AND store_id NOT IN (SELECT store_id FROM stores_cleaned);

ALTER TABLE sales_cleaned
ADD CONSTRAINT fk_sales_store
FOREIGN KEY (store_id)
REFERENCES stores_cleaned(store_id);


SELECT 
    s.order_id,
    s.product_id,
    s.quantity,
    s.total_amount,
    p.cost_price,
    
    -- Total cost to company
    (s.quantity * p.cost_price) AS total_cost,
    
    -- Profit = revenue - cost
    (s.total_amount - (s.quantity * p.cost_price)) AS profit
FROM 
    sales_cleaned s
JOIN 
    products_cleaned p ON s.product_id = p.product_id;


SELECT 
    s.order_id,
    s.product_id,
    s.unit_price,
    s.quantity,
    s.total_amount,

    -- Original total price before discount
    (s.unit_price * s.quantity) AS original_price,

    -- Discount amount
    ((s.unit_price * s.quantity) - s.total_amount) AS discount_amount,

    -- Discount % = discount / original price

    ROUND(
      ((s.unit_price * s.quantity - s.total_amount) / (s.unit_price * s.quantity)) * 100, 2
    ) AS calculated_discount_pct
FROM 
    sales_cleaned s;

SELECT 
    s.order_id,
    s.product_id,
    s.unit_price,
    s.quantity,
    s.total_amount,
    p.cost_price,

    -- Derived metrics
    (s.unit_price * s.quantity) AS original_price,
    ROUND(((s.unit_price * s.quantity - s.total_amount) / (s.unit_price * s.quantity)) * 100, 2) AS discount_pct,
    (s.total_amount - (s.quantity * p.cost_price)) AS profit
FROM 
    sales_cleaned s
JOIN 
    products_cleaned p ON s.product_id = p.product_id;


ALTER TABLE sales_cleaned
ALTER COLUMN cost_price DECIMAL(10,2);



SELECT * FROM sales_cleaned

--1. What is the total revenue generated in the last 12 months? 
SELECT 
    SUM(total_amount) AS total_revenue
FROM 
    sales_cleaned
WHERE 
    order_date >= DATEADD(MONTH, -12, GETDATE());


--2. Which are the top 5 best-selling products by quantity? 
SELECT TOP 5 
    p.product_name,
    SUM(s.quantity) AS total_quantity_sold
FROM 
    sales_cleaned s
JOIN 
    products_cleaned p ON s.product_id = p.product_id
GROUP BY 
    p.product_name
ORDER BY 
    total_quantity_sold DESC;

--3. How many customers are from each region? 
SELECT
    region,
    COUNT(*) AS customer_count
FROM 
    customers_cleaned
GROUP BY 
    region;

--4. Which store has the highest profit in the past year? 
SELECT TOP 1
    st.store_name,
    SUM(s.profit) AS total_profit
FROM 
    sales_cleaned s
JOIN 
    stores_cleaned st ON s.store_id = st.store_id
WHERE 
    s.order_date >= DATEADD(YEAR, -1, GETDATE())
GROUP BY 
    st.store_name
ORDER BY 
    total_profit DESC;

--5. What is the return rate by product category? 
SELECT 
    p.category,
    COUNT(DISTINCT r.order_id) * 1.0 / COUNT(DISTINCT s.order_id) AS return_rate
FROM 
    products_cleaned p
JOIN 
    sales_cleaned s ON p.product_id = s.product_id
LEFT JOIN 
    returns_cleaned r ON s.order_id = r.order_id
GROUP BY 
    p.category;

--6. What is the average revenue per customer by age group? 
SELECT 
    c.age_group,
    ROUND(SUM(s.total_amount) * 1.0 / COUNT(DISTINCT c.customer_id), 2) AS avg_revenue_per_customer
FROM 
    customers_cleaned c
JOIN 
    sales_cleaned s ON c.customer_id = s.customer_id
GROUP BY 
    c.age_group;

--7. Which sales channel (Online vs In-Store) is more profitable on average? 
SELECT 
    sales_channel,
    ROUND(AVG(profit), 2) AS avg_profit
FROM 
    sales_cleaned
GROUP BY 
    sales_channel;

--8. How has monthly profit changed over the last 2 years by region? 
SELECT 
    FORMAT(order_date, 'yyyy-MM') AS month,
    st.region,
    SUM(s.profit) AS total_profit
FROM 
    sales_cleaned s
JOIN 
    stores_cleaned st ON s.store_id = st.store_id
WHERE 
    order_date >= DATEADD(YEAR, -2, GETDATE())
GROUP BY 
    FORMAT(order_date, 'yyyy-MM'), st.region
ORDER BY 
    month, region;


--9. Identify the top 3 products with the highest return rate in each category. 
WITH ReturnStats AS (
  SELECT 
      p.category,
      p.product_name,
      COUNT(DISTINCT r.order_id) * 1.0 / COUNT(DISTINCT s.order_id) AS return_rate
  FROM 
      products_cleaned p
  JOIN 
      sales_cleaned s ON p.product_id = s.product_id
  LEFT JOIN 
      returns_cleaned r ON s.order_id = r.order_id
  GROUP BY 
      p.category, p.product_name
)
SELECT *
FROM (
    SELECT *, 
           RANK() OVER (PARTITION BY category ORDER BY return_rate DESC) AS rank
    FROM ReturnStats
) AS ranked
WHERE rank <= 3;




--10. Which 5 customers have contributed the most to total profit, and what is their tenure with the company? 
SELECT TOP 5
    c.customer_id,
    c.first_name + ' ' + c.last_name AS customer_name,
    DATEDIFF(YEAR, c.signup_date, GETDATE()) AS tenure_years,
    SUM(s.profit) AS total_profit
FROM 
    customers_cleaned c
JOIN 
    sales_cleaned s ON c.customer_id = s.customer_id
GROUP BY 
    c.customer_id, c.first_name, c.last_name, c.signup_date
ORDER BY 
    total_profit DESC;
