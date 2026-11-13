-- =====================================================================
-- Project 2: Café Data Cleanup
-- File:      01_load_raw.sql
-- Purpose:   Load the dirty café sales CSV into PostgreSQL exactly as
--            it is, so every problem can be measured and fixed in SQL.
-- Database:  cafe_sales (PostgreSQL)
-- =====================================================================
-- Every column is TEXT: the file has "ERROR" and "UNKNOWN" inside
-- number and date columns, which a numeric or date column would reject.
-- Note: COPY turns empty cells into NULL, so a blank cell = NULL here.
-- =====================================================================

DROP TABLE IF EXISTS cafe_raw;

CREATE TABLE cafe_raw (
    transaction_id    TEXT,
    item              TEXT,
    quantity          TEXT,
    price_per_unit    TEXT,
    total_spent       TEXT,
    payment_method    TEXT,
    location          TEXT,
    transaction_date  TEXT
);

-- Load the ORIGINAL CSV (not the Excel copy, which may change dates)
COPY cafe_raw
FROM 'C:\Users\Public\dirty_cafe_sales.csv'
WITH (FORMAT csv, HEADER true);


-- ---------------------------------------------------------------------
-- Check 1: nothing lost. Expected: 10,000 rows, 10,000 unique IDs
-- ---------------------------------------------------------------------
SELECT COUNT(*)                        AS total_rows,
       COUNT(DISTINCT transaction_id)  AS unique_transaction_ids
FROM cafe_raw;


-- ---------------------------------------------------------------------
-- Check 2: bad values per column, the same table as the Excel check.
-- "Bad" = blank (NULL), 'ERROR' or 'UNKNOWN'.
-- ---------------------------------------------------------------------
SELECT 'item' AS column_name,
       COUNT(*) FILTER (WHERE item IS NULL)          AS blank,
       COUNT(*) FILTER (WHERE item = 'ERROR')        AS error,
       COUNT(*) FILTER (WHERE item = 'UNKNOWN')      AS unknown
FROM cafe_raw
UNION ALL
SELECT 'quantity',
       COUNT(*) FILTER (WHERE quantity IS NULL),
       COUNT(*) FILTER (WHERE quantity = 'ERROR'),
       COUNT(*) FILTER (WHERE quantity = 'UNKNOWN')
FROM cafe_raw
UNION ALL
SELECT 'price_per_unit',
       COUNT(*) FILTER (WHERE price_per_unit IS NULL),
       COUNT(*) FILTER (WHERE price_per_unit = 'ERROR'),
       COUNT(*) FILTER (WHERE price_per_unit = 'UNKNOWN')
FROM cafe_raw
UNION ALL
SELECT 'total_spent',
       COUNT(*) FILTER (WHERE total_spent IS NULL),
       COUNT(*) FILTER (WHERE total_spent = 'ERROR'),
       COUNT(*) FILTER (WHERE total_spent = 'UNKNOWN')
FROM cafe_raw
UNION ALL
SELECT 'payment_method',
       COUNT(*) FILTER (WHERE payment_method IS NULL),
       COUNT(*) FILTER (WHERE payment_method = 'ERROR'),
       COUNT(*) FILTER (WHERE payment_method = 'UNKNOWN')
FROM cafe_raw
UNION ALL
SELECT 'location',
       COUNT(*) FILTER (WHERE location IS NULL),
       COUNT(*) FILTER (WHERE location = 'ERROR'),
       COUNT(*) FILTER (WHERE location = 'UNKNOWN')
FROM cafe_raw
UNION ALL
SELECT 'transaction_date',
       COUNT(*) FILTER (WHERE transaction_date IS NULL),
       COUNT(*) FILTER (WHERE transaction_date = 'ERROR'),
       COUNT(*) FILTER (WHERE transaction_date = 'UNKNOWN')
FROM cafe_raw;
-- Expected: matches the Excel Checks sheet exactly
