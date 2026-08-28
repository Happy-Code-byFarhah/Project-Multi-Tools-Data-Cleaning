-- Data Cleaning Project --
CREATE DATABASE project;
USE project;

CREATE TABLE cafe_sales_raw (
	transaction_id 		VARCHAR(50),
	item 				VARCHAR(50),
    quantity 			VARCHAR(50),
    price_per_unit 		VARCHAR(50),
    total_spent 		VARCHAR(50),
	payment_method 		VARCHAR(50),
    location 			VARCHAR(50),
    transaction_date 	VARCHAR(50)
)
ENGINE = InnoDB;

SELECT * FROM cafe_sales_raw
LIMIT 10;

-- Cheak Data Structure --
DESCRIBE cafe_sales_raw;

-- Total Rows --
SELECT COUNT(*) AS total_rows FROM cafe_sales_raw;

-- Total Missing Value --
SELECT
	'UNKNOWN' AS status,
    SUM(item = 'UNKNOWN') AS item,
    SUM(quantity = 'UNKNOWN') AS quantity,
    SUM(price_per_unit = 'UNKNOWN') AS price_per_unit,
    SUM(total_spent = 'UNKNOWN') AS total_spent,
    SUM(payment_method='UNKNOWN') AS payment_method,
    SUM(location='UNKNOWN') AS location,
    SUM(transaction_date='UNKNOWN') AS transaction_date
FROM cafe_sales_raw

UNION ALL

SELECT
    'ERROR',
    SUM(item = 'ERROR'),
    SUM(quantity = 'ERROR'),
    SUM(price_per_unit = 'ERROR'),
    SUM(total_spent = 'ERROR'),
    SUM(payment_method='ERROR'),
    SUM(location='ERROR'),
    SUM(transaction_date='ERROR')
FROM cafe_sales_raw

UNION ALL

SELECT
    'Blank',
    SUM(item IS NULL OR item = ''),
    SUM(quantity IS NULL OR quantity = ''),
    SUM(price_per_unit IS NULL OR price_per_unit = ''),
    SUM(total_spent IS NULL OR total_spent = ''),
    SUM(payment_method=''),
    SUM(location=''),
    SUM(transaction_date='') 
FROM cafe_sales_raw;

-- Chek Unique Values --
SELECT DISTINCT item AS item FROM cafe_sales_raw;

SELECT DISTINCT payment_method AS payment_method FROM cafe_sales_raw;

SELECT DISTINCT location AS location FROM cafe_sales_raw;

-- Chek Duplicate Data --
SELECT COUNT(*) AS total_duplicated
FROM cafe_sales_raw
GROUP BY 
	transaction_id, 
    item, 
    quantity, 
    price_per_unit,
    total_spent,
    payment_method,
    location, 
    transaction_date
HAVING COUNT(*) > 1;

-- ETL Data Cleaning Pipeline Using CTEs --
CREATE TABLE cafe_sales AS
WITH cafe_sales_clean AS (
	-- 1. Standardize Raw Data --
    SELECT
        transaction_id,

        CASE
            WHEN item IN ('', 'UNKNOWN', 'ERROR')
                 OR item IS NULL
            THEN 'Unknown'
            ELSE item
        END AS item,

        CASE
            WHEN quantity IN ('', 'UNKNOWN', 'ERROR')
                 OR quantity IS NULL
            THEN NULL
            ELSE quantity
        END AS quantity,

        CASE
            WHEN price_per_unit IN ('', 'UNKNOWN', 'ERROR')
                 OR price_per_unit IS NULL
            THEN NULL
            ELSE price_per_unit
        END AS price_per_unit,

        CASE
            WHEN total_spent IN ('', 'UNKNOWN', 'ERROR')
                 OR total_spent IS NULL
            THEN NULL
            ELSE total_spent
        END AS total_spent,

        CASE
            WHEN payment_method IN ('', 'UNKNOWN', 'ERROR')
                 OR payment_method IS NULL
            THEN 'Unknown'
            ELSE payment_method
        END AS payment_method,

        CASE
            WHEN location IN ('', 'UNKNOWN', 'ERROR')
                 OR location IS NULL
            THEN 'Unknown'
            ELSE location
        END AS location,

        CASE
            WHEN transaction_date IN ('', 'UNKNOWN', 'ERROR')
                 OR transaction_date IS NULL
            THEN NULL
            ELSE transaction_date
        END AS transaction_date

    FROM cafe_sales_raw
),

fix_item AS (
    -- 2. Fix Item Using Price Mapping --
    SELECT
        transaction_id,

        CASE
            WHEN item = 'Unknown'
                 AND price_per_unit = '2'
            THEN 'Coffee'

            WHEN item = 'Unknown'
                 AND price_per_unit = '1'
            THEN 'Cookie'

            WHEN item = 'Unknown'
                 AND price_per_unit = '5'
            THEN 'Salad'

            WHEN item = 'Unknown'
                 AND price_per_unit = '1.5'
            THEN 'Tea'

            ELSE item
        END AS item,

        quantity,
        price_per_unit,
        total_spent,
        payment_method,
        location,
        transaction_date

    FROM cafe_sales_clean
),

fix_price AS (
    -- 3. Fix Price Using Item Mapping --
    SELECT
        transaction_id,
        item,
        quantity,

        CASE
            WHEN price_per_unit IS NULL
                 AND item = 'Coffee'
            THEN 2

            WHEN price_per_unit IS NULL
                 AND item = 'Cake'
            THEN 3

            WHEN price_per_unit IS NULL
                 AND item = 'Cookie'
            THEN 1

            WHEN price_per_unit IS NULL
                 AND item = 'Salad'
            THEN 5

            WHEN price_per_unit IS NULL
                 AND item = 'Smoothie'
            THEN 4

            WHEN price_per_unit IS NULL
                 AND item = 'Sandwich'
            THEN 4

            WHEN price_per_unit IS NULL
                 AND item = 'Juice'
            THEN 3

            WHEN price_per_unit IS NULL
                 AND item = 'Tea'
            THEN 1.5

            ELSE CAST(price_per_unit AS DECIMAL(10,2))

        END AS price_per_unit,

        total_spent,
        payment_method,
        location,
        transaction_date

    FROM fix_item
),

fix_quantity AS (
    -- 4. Fix Quantity Using Spent and Price --
    SELECT
        transaction_id,
        item,
        price_per_unit,

        CASE
            WHEN quantity IS NULL
                 AND total_spent IS NOT NULL
                 AND price_per_unit IS NOT NULL

            THEN ROUND(
                CAST(total_spent AS DECIMAL(10,2))
                / price_per_unit,
                0
            )

            ELSE CAST(quantity AS UNSIGNED)

        END AS quantity,

        total_spent,
        payment_method,
        location,
        transaction_date

    FROM fix_price
),

fix_total AS (

    -- 5. Fix Spent Using Price and Quantity --
    SELECT
        transaction_id,
        item,
        price_per_unit,
        quantity,

        CASE
            WHEN total_spent IS NULL
                 AND quantity IS NOT NULL
                 AND price_per_unit IS NOT NULL

            THEN ROUND(
                quantity * price_per_unit,
                2
            )

            ELSE CAST(total_spent AS DECIMAL(10,2))

        END AS total_spent,

        payment_method,
        location,
        transaction_date

    FROM fix_quantity
),

fix_price_final AS (
    -- 6. Recalculate Price If Still Missing -- 
    SELECT
        transaction_id,
        item,
        quantity,

        CASE
            WHEN price_per_unit IS NULL
                 AND quantity IS NOT NULL
                 AND total_spent IS NOT NULL

            THEN ROUND(
                total_spent / quantity,
                2
            )

            ELSE price_per_unit

        END AS price_per_unit,

        total_spent,
        payment_method,
        location,
        transaction_date

    FROM fix_total
),

fix_item_final AS (
    -- 7. Final Item Fix --
    SELECT
        transaction_id,

        CASE
            WHEN item = 'Unknown'
                 AND price_per_unit = 2
            THEN 'Coffee'

            WHEN item = 'Unknown'
                 AND price_per_unit = 1
            THEN 'Cookie'

            WHEN item = 'Unknown'
                 AND price_per_unit = 5
            THEN 'Salad'

            WHEN item = 'Unknown'
                 AND price_per_unit = 1.5
            THEN 'Tea'

            ELSE item

        END AS item,

        quantity,
        price_per_unit,
        total_spent,
        payment_method,
        location,
        transaction_date

    FROM fix_price_final
),

remove_null AS(
	-- 8. Remove Nilai Null in Numeric Values --
	SELECT * FROM fix_item_final
	WHERE price_per_unit IS NOT NULL
	AND quantity IS NOT NULL
	AND total_spent IS NOT NULL
),

validation AS (
    -- 9. Data Quality Chek ---
	SELECT
        *,

        CASE
            WHEN ROUND(quantity * price_per_unit,2)
                 =
                 ROUND(total_spent,2)
            THEN 'VALID'
            ELSE 'INVALID'
        END AS data_quality_total_spent,
        
        CASE
            WHEN ROUND(total_spent / price_per_unit,2)
                 =
                 ROUND(quantity,2)
            THEN 'VALID'
            ELSE 'INVALID'
        END AS data_quality_quantity,
        
		CASE
            WHEN ROUND(total_spent / quantity,2)
                 =
                 ROUND(price_per_unit,2)
            THEN 'VALID'
            ELSE 'INVALID'
        END AS data_quality_price

    FROM remove_null
    # There isn't invalid data
),

feature_engineering AS(
	SELECT
		*,
		DAYNAME(transaction_date) AS day,
		MONTHNAME(transaction_date) AS month
	FROM remove_null
)
SELECT * FROM feature_engineering;

-- Chek Structure Data Final --
DESCRIBE cafe_sales;

-- Total Rows --
SELECT COUNT(*) AS total_rows FROM cafe_sales;

-- Total Missing Value --
SELECT
	'UNKNOWN' AS status,
    SUM(item = 'UNKNOWN') AS item,
    SUM(quantity = 'UNKNOWN') AS quantity,
    SUM(price_per_unit = 'UNKNOWN') AS price_per_unit,
    SUM(total_spent = 'UNKNOWN') AS total_spent,
    SUM(payment_method='UNKNOWN') AS payment_method,
    SUM(location='UNKNOWN') AS location
FROM cafe_sales;

SELECT SUM(transaction_date IS NULL) AS transaction_date_null
FROM cafe_sales;

-- Chek Unique Values --
SELECT DISTINCT item AS item FROM cafe_sales;

SELECT DISTINCT payment_method AS payment_method FROM cafe_sales;

SELECT DISTINCT location AS location FROM cafe_sales;

SELECT * FROM cafe_sales
LIMIT 10;
