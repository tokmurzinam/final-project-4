CREATE DATABASE final_project;
UPDATE customers
SET Gender = NULL
WHERE Gender = '';

UPDATE customers
SET Age = NULL
WHERE Age = '';

ALTER TABLE customers MODIFY Age INT null;

SELECT * FROM transactions;

CREATE TABLE transactions
(date_new DATE,
Id_check INT,
ID_client INT,
Count_products DECIMAL(10,3),
Sum_payment DECIMAL(10,2) );

LOAD DATA INFILE "C:\\ProgramData\\MySQL\\MySQL Server 8.0\\Uploads\\TRANSACTIONS.csv"
INTO TABLE transactions
FIELDS TERMINATED BY ','
LINES TERMINATED BY '\n'
IGNORE 1 ROWS; 

SHOW variables LIKE 'secure_file_priv';
##########################################################
CREATE TEMPORARY TABLE months_needed (
    month_start DATE
);

CREATE TEMPORARY TABLE transactions_by_month AS
SELECT 
    ID_client,
    DATE_FORMAT(date_new, '%Y-%m-01') AS month_start,
    Sum_payment
FROM transactions
WHERE date_new >= '2015-06-01' AND date_new < '2016-06-01';

CREATE TEMPORARY TABLE full_year_clients AS
SELECT ID_client
FROM transactions_by_month
GROUP BY ID_client
HAVING COUNT(DISTINCT month_start) = 12;

SELECT 
    c.ID_client,
    COUNT(t.Id_check) AS total_operations,
    ROUND(SUM(t.Sum_payment) / COUNT(t.Id_check), 2) AS average_check,
    ROUND(SUM(t.Sum_payment) / 12, 2) AS avg_monthly_sum
FROM transactions t
JOIN full_year_clients c ON t.ID_client = c.ID_client
WHERE t.date_new >= '2015-06-01' AND t.date_new < '2016-06-01'
GROUP BY c.ID_client;

###########################################
WITH transactions_by_month AS (
    SELECT 
        DATE_FORMAT(date_new, '%Y-%m-01') AS month,
        ID_client,
        Id_check,
        Sum_payment
    FROM transactions
    WHERE date_new >= '2015-06-01' AND date_new < '2016-06-01'
),
year_totals AS (
    SELECT 
        COUNT(*) AS total_operations_year,
        SUM(Sum_payment) AS total_sum_year
    FROM transactions_by_month
),
monthly_stats AS (
    SELECT
        month,
        COUNT(*) AS operations_count,
        SUM(Sum_payment) AS sum_total,
        COUNT(DISTINCT ID_client) AS unique_clients,
        ROUND(SUM(Sum_payment) / COUNT(*), 2) AS avg_check
    FROM transactions_by_month
    GROUP BY month
) 
SELECT 
    m.month AS month_start,
    m.avg_check AS average_check_in_month,
    m.operations_count AS operations_in_month,
    m.unique_clients AS clients_in_month,
    ROUND(m.operations_count / y.total_operations_year, 4) AS operations_share_of_year,
    ROUND(m.sum_total / y.total_sum_year, 4) AS sum_share_of_year
FROM monthly_stats m
JOIN year_totals y
ORDER BY m.month;

##############################################################
WITH customer_age_grouped AS (
    SELECT 
        ID_client,
        CASE 
            WHEN Age IS NULL THEN 'No data'
            WHEN Age BETWEEN 0 AND 9 THEN '00-09'
            WHEN Age BETWEEN 10 AND 19 THEN '10-19'
            WHEN Age BETWEEN 20 AND 29 THEN '20-29'
            WHEN Age BETWEEN 30 AND 39 THEN '30-39'
            WHEN Age BETWEEN 40 AND 49 THEN '40-49'
            WHEN Age BETWEEN 50 AND 59 THEN '50-59'
            WHEN Age BETWEEN 60 AND 69 THEN '60-69'
            ELSE '70+'
        END AS age_group
    FROM customers
),
transactions_with_age AS (
    SELECT 
        t.*,
        ca.age_group,
        QUARTER(t.date_new) AS quarter,
        YEAR(t.date_new) AS year
    FROM transactions t
    LEFT JOIN customer_age_grouped ca ON t.ID_client = ca.ID_client
    WHERE t.date_new >= '2015-06-01' AND t.date_new < '2016-06-01'
),
total_by_age_group AS (
    SELECT 
        age_group,
        COUNT(*) AS total_operations,
        SUM(Sum_payment) AS total_sum
    FROM transactions_with_age
    GROUP BY age_group
),
quarterly_by_age_group AS (
    SELECT 
        CONCAT(year, '-Q', quarter) AS year_quarter,
        age_group,
        COUNT(*) AS operations_count,
        SUM(Sum_payment) AS sum_total,
        ROUND(SUM(Sum_payment) / COUNT(*), 2) AS avg_check
    FROM transactions_with_age
    GROUP BY year, quarter, age_group
)
SELECT 
    q.year_quarter,
    q.age_group,
    q.operations_count,
    q.sum_total,
    q.avg_check,
    ROUND(q.operations_count / t.total_operations * 100, 2) AS operations_share_percent,
    ROUND(q.sum_total / t.total_sum * 100, 2) AS sum_share_percent
FROM quarterly_by_age_group q
JOIN total_by_age_group t 
  ON q.age_group = t.age_group
ORDER BY q.year_quarter, 
         FIELD(q.age_group, '00-09','10-19','20-29','30-39','40-49','50-59','60-69','70+','No data');