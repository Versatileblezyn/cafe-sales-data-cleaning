-- =====================================================================
-- Project 2: Café Data Cleanup
-- File:      02_clean.sql
-- Purpose:   Turn the dirty café sales into a trustworthy table:
--            standardise missing values, rescue what can be calculated,
--            label (never guess) what can't, and prove the result.
-- Database:  cafe_sales (PostgreSQL)
-- Input:     cafe_raw (from 01_load_raw.sql), 10,000 rows
-- Output:    cafe_clean
-- =====================================================================
-- Two facts make rescue possible (both checked in Excel first):
--   1. Every menu item has one fixed price.
--   2. Quantity x Price = Total in all 8,544 complete rows.
-- =====================================================================


-- ---------------------------------------------------------------------
-- Piece 1. One kind of "missing", proper data types
-- Blank, 'ERROR' and 'UNKNOWN' all become NULL.
-- ---------------------------------------------------------------------
DROP TABLE IF EXISTS cafe_typed;

CREATE TABLE cafe_typed AS
SELECT
    transaction_id,
    NULLIF(NULLIF(item, 'ERROR'), 'UNKNOWN')                         AS item,
    NULLIF(NULLIF(quantity, 'ERROR'), 'UNKNOWN')::INTEGER            AS quantity,
    NULLIF(NULLIF(price_per_unit, 'ERROR'), 'UNKNOWN')::NUMERIC(6,2) AS price_per_unit,
    NULLIF(NULLIF(total_spent, 'ERROR'), 'UNKNOWN')::NUMERIC(8,2)    AS total_spent,
    NULLIF(NULLIF(payment_method, 'ERROR'), 'UNKNOWN')               AS payment_method,
    NULLIF(NULLIF(location, 'ERROR'), 'UNKNOWN')                     AS location,
    CASE
        WHEN transaction_date IN ('ERROR', 'UNKNOWN') THEN NULL
        WHEN transaction_date ~ '^\d{4}-' THEN TO_DATE(transaction_date, 'YYYY-MM-DD')
        ELSE TO_DATE(transaction_date, 'MM/DD/YYYY')
    END                                                              AS transaction_date
FROM cafe_raw;
-- Missing now: item 969 | quantity 479 | price 533 | total 502 |
--              payment 3,178 | location 3,961 | date 460


-- ---------------------------------------------------------------------
-- Piece 2. Rescue item, quantity, price and total
-- Each recovered value is flagged so original and recovered can
-- always be told apart.
-- ---------------------------------------------------------------------
DROP TABLE IF EXISTS cafe_rescued;

CREATE TABLE cafe_rescued AS
WITH menu(menu_item, menu_price) AS (
    VALUES ('Cookie', 1.00), ('Tea', 1.50), ('Coffee', 2.00), ('Cake', 3.00),
           ('Juice', 3.00), ('Sandwich', 4.00), ('Smoothie', 4.00), ('Salad', 5.00)
),
step1 AS (   -- price: from the item, or Total / Quantity
    SELECT t.*,
           COALESCE(t.price_per_unit, m.menu_price,
                    ROUND(t.total_spent / NULLIF(t.quantity, 0), 2)) AS price_new
    FROM cafe_typed t
    LEFT JOIN menu m ON m.menu_item = t.item
),
step2 AS (   -- item: from the price, only where one item has that price
    SELECT step1.*,
           COALESCE(item, CASE price_new WHEN 1.00 THEN 'Cookie'
                                         WHEN 1.50 THEN 'Tea'
                                         WHEN 2.00 THEN 'Coffee'
                                         WHEN 5.00 THEN 'Salad' END) AS item_new
    FROM step1
),
step3 AS (   -- quantity: Total / Price
    SELECT step2.*,
           COALESCE(quantity, ROUND(total_spent / NULLIF(price_new, 0))::INTEGER) AS quantity_new
    FROM step2
)
SELECT
    transaction_id,
    item_new                                        AS item,
    quantity_new                                    AS quantity,
    price_new                                       AS price_per_unit,
    COALESCE(total_spent, quantity_new * price_new) AS total_spent,
    payment_method,
    location,
    transaction_date,
    (item IS NULL AND item_new IS NOT NULL)                AS item_recovered,
    (quantity IS NULL AND quantity_new IS NOT NULL)        AS quantity_recovered,
    (price_per_unit IS NULL AND price_new IS NOT NULL)     AS price_recovered,
    (total_spent IS NULL
        AND quantity_new * price_new IS NOT NULL)          AS total_recovered
FROM step3;
-- Recovered: item 489 | quantity 456 | price 527 | total 479


-- ---------------------------------------------------------------------
-- Piece 3. Label what can't be rescued (never guess)
-- ---------------------------------------------------------------------
DROP TABLE IF EXISTS cafe_clean;

CREATE TABLE cafe_clean AS
SELECT
    transaction_id,
    COALESCE(item,
        CASE price_per_unit WHEN 3.00 THEN 'Cake or Juice'
                            WHEN 4.00 THEN 'Sandwich or Smoothie'
                            ELSE 'Unknown' END)        AS item,
    quantity,
    price_per_unit,
    total_spent,
    COALESCE(payment_method, 'Unknown')                AS payment_method,
    COALESCE(location, 'Unknown')                      AS location,
    transaction_date,                                  -- missing dates stay NULL
    CASE WHEN total_spent IS NULL THEN 'Missing'
         WHEN total_recovered     THEN 'Recovered'
         ELSE 'Original' END                           AS amount_status,
    item_recovered,
    quantity_recovered,
    price_recovered,
    total_recovered
FROM cafe_rescued;
-- amount_status: Original 9,498 (£84,763.50) | Recovered 479 (£4,332.50) | Missing 23


-- ---------------------------------------------------------------------
-- Piece 4. Prove the result
-- ---------------------------------------------------------------------
-- No leftover junk. Expected: 0
SELECT COUNT(*) AS rows_still_containing_error_or_unknown
FROM cafe_clean
WHERE item IN ('ERROR', 'UNKNOWN')
   OR payment_method IN ('ERROR', 'UNKNOWN')
   OR location IN ('ERROR', 'UNKNOWN');

-- The maths still holds. Expected: 9,974 rows checked, 0 mismatches
SELECT
    COUNT(*) FILTER (WHERE quantity IS NOT NULL AND price_per_unit IS NOT NULL
                       AND total_spent IS NOT NULL)                       AS rows_checked,
    COUNT(*) FILTER (WHERE quantity * price_per_unit <> total_spent)      AS mismatches
FROM cafe_clean;

-- Before / after summary
SELECT 'Sales with a known amount' AS measure,
       (SELECT COUNT(total_spent) FROM cafe_typed)::TEXT AS before,
       (SELECT COUNT(total_spent) FROM cafe_clean)::TEXT AS after
UNION ALL
SELECT 'Revenue you can count (£)',
       (SELECT SUM(total_spent) FROM cafe_typed)::TEXT,
       (SELECT SUM(total_spent) FROM cafe_clean)::TEXT
UNION ALL
SELECT 'Sales with item, quantity, price and total all known',
       (SELECT COUNT(*) FROM cafe_typed
         WHERE item IS NOT NULL AND quantity IS NOT NULL
           AND price_per_unit IS NOT NULL AND total_spent IS NOT NULL)::TEXT,
       (SELECT COUNT(*) FROM cafe_clean
         WHERE item NOT IN ('Cake or Juice', 'Sandwich or Smoothie', 'Unknown')
           AND quantity IS NOT NULL AND price_per_unit IS NOT NULL
           AND total_spent IS NOT NULL)::TEXT
UNION ALL
SELECT 'Sales with every field known',
       (SELECT COUNT(*) FROM cafe_typed
         WHERE item IS NOT NULL AND quantity IS NOT NULL AND price_per_unit IS NOT NULL
           AND total_spent IS NOT NULL AND payment_method IS NOT NULL
           AND location IS NOT NULL AND transaction_date IS NOT NULL)::TEXT,
       (SELECT COUNT(*) FROM cafe_clean
         WHERE item NOT IN ('Cake or Juice', 'Sandwich or Smoothie', 'Unknown')
           AND quantity IS NOT NULL AND price_per_unit IS NOT NULL
           AND total_spent IS NOT NULL AND payment_method <> 'Unknown'
           AND location <> 'Unknown' AND transaction_date IS NOT NULL)::TEXT;
-- Expected: 9,498 -> 9,977 | 84,763.50 -> 89,096.00 | 7,732 -> 9,500 | 3,089 -> 3,771
