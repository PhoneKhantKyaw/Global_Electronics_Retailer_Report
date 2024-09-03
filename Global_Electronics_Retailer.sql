USE Global_Electronics_Retailer;

EXEC sp_rename 'sales.Order Number','order_number','COLUMN';
EXEC sp_rename 'sales.Line Item','line_item','COLUMN';
EXEC sp_rename 'sales.Order Date','order_date','COLUMN';
EXEC sp_rename 'sales.Delivery Date','delivery_date','COLUMN';
EXEC sp_rename 'sales.CustomerKey','customer_key','COLUMN';
EXEC sp_rename 'sales.StoreKey','store_key','COLUMN';
EXEC sp_rename 'sales.ProductKey','product_key','COLUMN';
EXEC sp_rename 'sales.Quantity','quantity','COLUMN';
EXEC sp_rename 'sales.Currency Code','currency_code','COLUMN';

EXEC sp_rename 'products.ProductKey','product_key','COLUMN';
EXEC sp_rename 'products.Product Name','product_name','COLUMN';
EXEC sp_rename 'products.Brand','brand','COLUMN';
EXEC sp_rename 'products.Color','color','COLUMN';
EXEC sp_rename 'products.Unit Cost USD','unit_cost_usd','COLUMN';
EXEC sp_rename 'products.Unit Price USD','unit_price_usd','COLUMN';
EXEC sp_rename 'products.SubcategoryKey','subcategory_key','COLUMN';
EXEC sp_rename 'products.Subcategory','subcategory','COLUMN';
EXEC sp_rename 'products.CategoryKey','category_key','COLUMN';
EXEC sp_rename 'products.Category','category','COLUMN';

EXEC sp_rename 'stores.StoreKey','store_key','COLUMN';
EXEC sp_rename 'stores.Country','country','COLUMN';
EXEC sp_rename 'stores.State','state','COLUMN';
EXEC sp_rename 'stores.Square Meters','square_meters','COLUMN';
EXEC sp_rename 'stores.Open Date','open_date','COLUMN';

EXEC sp_rename 'customers.CustomerKey','customer_key','COLUMN';
EXEC sp_rename 'customers.Gender','gender','COLUMN';
EXEC sp_rename 'customers.Name','name','COLUMN';
EXEC sp_rename 'customers.City','city','COLUMN';
EXEC sp_rename 'customers.State_Code','state_code','COLUMN';
EXEC sp_rename 'customers.State','state','COLUMN';
EXEC sp_rename 'customers.Zip_Code','zip_code','COLUMN';
EXEC sp_rename 'customers.Country','country','COLUMN';
EXEC sp_rename 'customers.Continent','continent','COLUMN';
EXEC sp_rename 'customers.Birthday','birthday','COLUMN';

-- change date format to year-month-day
UPDATE sales
SET order_date = FORMAT(CONVERT(DATE, order_date), 'yyyy-MM-dd');

UPDATE sales
SET delivery_date = FORMAT(CONVERT(DATE, delivery_date), 'yyyy-MM-dd');

UPDATE stores
SET open_date = FORMAT(CONVERT(DATE, open_date), 'yyyy-MM-dd');

UPDATE customers
SET birthday = FORMAT(CONVERT(DATE, birthday), 'yyyy-MM-dd');

--Total sales vs total profit
WITH tb1 AS (
    SELECT CEILING(SUM(p.unit_price_usd * s.quantity)) AS total_sales_USD,
        CEILING(
            SUM(p.unit_price_usd * s.quantity) - SUM(p.unit_cost_usd * s.quantity)
        ) AS total_profit_USD
    FROM customers AS c
        JOIN sales AS s ON c.customer_key = s.customer_key
        JOIN products AS p ON s.product_key = p.product_key
)
SELECT *
FROM tb1;

--Sales by country
SELECT C.Country,
    CEILING(SUM(p.unit_price_usd * s.quantity)) AS sales
FROM Global_Electronics_Retailer.dbo.Customers AS c
    JOIN sales AS s ON c.customer_key = s.customer_key
    JOIN products AS p ON s.product_key = p.product_key
GROUP BY c.Country
ORDER BY sales DESC;

--Sales by brand
SELECT p.Brand,
    CEILING(SUM(p.unit_price_usd * s.quantity)) AS sales
FROM sales AS s
    JOIN products AS p ON s.product_key = p.product_key
GROUP BY p.Brand
ORDER BY sales DESC;

--Top 5 popular color
SELECT TOP 5 color,
    SUM(quantity) AS count
FROM products AS p
    JOIN sales AS s ON s.product_key = p.product_key
GROUP BY color
ORDER BY count DESC;

--Sales by gender
SELECT c.gender,
    CEILING(SUM(p.unit_price_usd * s.quantity)) AS sales
FROM customers AS c
    JOIN sales AS s ON c.customer_key = s.customer_key
    JOIN products AS p ON s.product_key = p.product_key
GROUP BY c.gender
ORDER BY sales DESC;

-- highest profit by brand per category
WITH product AS (
    SELECT brand,
        category,
        ROUND(
            SUM(
                (unit_price_usd * quantity) - (unit_cost_usd * quantity)
            ),
            2
        ) AS profit,
        RANK() OVER(
            PARTITION BY brand
            ORDER BY category,
                ROUND(
                    SUM(
                        (p.unit_price_usd * s.quantity) - (p.unit_cost_usd * s.quantity)
                    ),
                    2
                ) DESC
        ) AS rank
    FROM sales AS s
        JOIN products AS p ON s.product_key = p.product_key
    GROUP BY brand,
        category
)
SELECT brand,
    category,
    profit
FROM product
WHERE rank = 1
ORDER BY profit DESC;


-- orders count by delivery timeframes
WITH tb1 AS (
    SELECT DATEDIFF(DAY, order_date, delivery_date) days_to_deliver
    FROM sales AS s
        JOIN stores AS st ON s.store_key = st.store_key
        JOIN products AS p ON s.product_key = p.product_key
    WHERE st.country = 'Online'
),
tb2 AS (
    SELECT *,
        CASE
            WHEN days_to_deliver <= 5 THEN 'Fast Shipping'
            WHEN days_to_deliver <= 10 THEN 'Moderate Shipping'
            ELSE 'Delayed Shipping'
        END AS days_range,
        CASE
            WHEN days_to_deliver IS NOT NULL THEN 1
        END AS count
    FROM tb1
)
SELECT days_range,
    COUNT(*) order_counts
FROM tb2
GROUP BY days_range
ORDER BY order_counts DESC;

-- adding new column and updaing age value
ALTER TABLE customers
ADD age NUMERIC;

UPDATE customers
SET age = DATEDIFF(YEAR, birthday, GETDATE());

--Store sales vs online sales
WITH sales AS (
    SELECT p.unit_price_usd, s.quantity,
        CASE
            WHEN state = 'Online' THEN 1
            ELSE 0
        END AS online,
        CASE
            WHEN state != 'Online' THEN 1
            ELSE 0
        END AS store
    FROM sales AS s
        JOIN products AS p ON s.product_key = p.product_key
        JOIN stores AS st ON s.store_key = st.store_key
)
SELECT CEILING(SUM(unit_price_usd * quantity * online)) AS online_sales,
    CEILING(SUM(unit_price_usd * quantity * store)) AS store_sales
FROM sales;

--Sales by age range
WITH table1 AS (
    SELECT
        CASE
            WHEN age BETWEEN 18 AND 39 THEN 'Young_Adult'
            WHEN age BETWEEN 40 AND 59 THEN 'Middle_Age'
            ELSE 'Senior'
        END AS age_range
    FROM customers AS c
    JOIN sales AS s ON s.customer_key = c.customer_key
)
SELECT age_range, COUNT(*) AS count
FROM table1
GROUP BY age_range
ORDER BY count DESC;
