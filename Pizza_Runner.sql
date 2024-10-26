-- Cleaning the customer orders table
DROP TABLE IF EXISTS new_customer_orders2;
CREATE TABLE new_customer_orders2 AS
-- First, include all rows where exclusions and extras are NULL or empty
SELECT
    order_id,
    customer_id,
    pizza_id,
    NULL AS exclusion_value,
    NULL AS extra_value,
    order_time
FROM new_customer_orders
WHERE (exclusions IS NULL OR exclusions = '')
    AND (extras IS NULL OR extras = '')
UNION ALL
-- Now, split exclusions where there are values
SELECT
    order_id,
    customer_id,
    pizza_id,
    CAST(SUBSTRING_INDEX(SUBSTRING_INDEX(exclusions, ',', numbers.n), ',', -1) AS SIGNED) AS exclusion_value,
    NULL AS extra_value,
    order_time
FROM new_customer_orders
JOIN (
    SELECT 1 AS n UNION ALL
    SELECT 2 UNION ALL
    SELECT 3 UNION ALL
    SELECT 4
) numbers
ON CHAR_LENGTH(exclusions) - CHAR_LENGTH(REPLACE(exclusions, ',', '')) >= numbers.n - 1
WHERE exclusions IS NOT NULL AND exclusions != ''
UNION ALL
-- Now, split extras where there are values
SELECT
    order_id,
    customer_id,
    pizza_id,
    NULL AS exclusion_value,
    CAST(SUBSTRING_INDEX(SUBSTRING_INDEX(extras, ',', numbers.n), ',', -1) AS SIGNED) AS extra_value,
    order_time
FROM new_customer_orders
JOIN (
    SELECT 1 AS n UNION ALL
    SELECT 2 UNION ALL
    SELECT 3 UNION ALL
    SELECT 4
) numbers
ON CHAR_LENGTH(extras) - CHAR_LENGTH(REPLACE(extras, ',', '')) >= numbers.n - 1
WHERE extras IS NOT NULL AND extras != '';

DROP TABLE IF EXISTS new_customer_orders;
DROP TABLE IF EXISTS customer_orders;
RENAME TABLE new_customer_orders2 TO customer_orders;

-- Cleaning the runner_orders table.
DROP TABLE IF EXISTS runner_orders_new;
CREATE TABLE runner_orders_new (
    order_id INTEGER,
    runner_id INTEGER,
    pickup_time TIMESTAMP,
    distance DECIMAL(10,1),
    duration INTEGER,
    cancellation VARCHAR(255)
) AS
SELECT 
    order_id,
    runner_id,
    CASE
        WHEN pickup_time = 'null' THEN NULL
        ELSE pickup_time
    END,
    CASE
        WHEN distance = 'null' THEN NULL
        WHEN distance LIKE '%km' THEN TRIM('km' FROM distance)
        ELSE distance
    END,
    CASE
        WHEN duration = 'null' THEN NULL
        WHEN duration LIKE '%mins' THEN TRIM('mins' FROM duration)
        WHEN duration LIKE '%minute' THEN TRIM('minute' FROM duration)
        WHEN duration LIKE '%minutes' THEN TRIM('minutes' FROM duration)
        ELSE duration
    END,
    cancellation
FROM runner_orders;

DROP TABLE IF EXISTS runner_orders;
RENAME TABLE runner_orders_new TO runner_orders;

-- Cleaning the pizza_recipes table
DROP TABLE IF EXISTS pizza_recipes_new;
CREATE TABLE pizza_recipes_new AS
SELECT 
    pizza_id,
    CAST(SUBSTRING_INDEX(SUBSTRING_INDEX(toppings, ', ', numbers.n), ', ', -1) AS SIGNED) AS topping_id
FROM pizza_recipes
JOIN (
    SELECT 1 AS n UNION ALL
    SELECT 2 UNION ALL
    SELECT 3 UNION ALL
    SELECT 4 UNION ALL
    SELECT 5 UNION ALL
    SELECT 6 UNION ALL
    SELECT 7 UNION ALL
    SELECT 8  -- Added enough numbers to cover the maximum number of toppings
) numbers
ON CHAR_LENGTH(toppings) - CHAR_LENGTH(REPLACE(toppings, ', ', '')) >= numbers.n - 1;

DROP TABLE IF EXISTS pizza_recipes;
RENAME TABLE pizza_recipes_new TO pizza_recipes;

-- QUESTIONS - PART A
-- How many pizzas were ordered?
SELECT COUNT(order_id) AS pizza_orders
FROM customer_orders;

-- How many unique customer orders were made?
SELECT COUNT(DISTINCT order_id) AS unique_orders
FROM customer_orders;

-- How many successful orders were delivered by each runner?
SELECT runner_id, COUNT(*) AS no_of_orders
FROM runner_id
WHERE pickup_time IS NOT NULL
GROUP BY runner_id;

-- How many of each type of pizza was delivered?
SELECT pizza_name, COUNT(*) AS count
FROM customer_orders
JOIN pizza_names ON customer_orders.pizza_id = pizza_names.pizza_id
GROUP BY pizza_name;

-- How many Vegetarian and Meatlovers were ordered by each customer?
SELECT customer_id, pizza_name, COUNT(*) AS total_orders
FROM customer_orders
JOIN pizza_names ON customer_orders.pizza_id = pizza_names.pizza_id
GROUP BY customer_id, pizza_name
ORDER BY pizza_name;

-- What was the maximum number of pizzas delivered in a single order?
SELECT run_ord.runner_id, COUNT(*) AS pizza_orders
FROM customer_orders cust_ord
JOIN runner_orders run_ord ON cust_ord.order_id = run_ord.order_id
GROUP BY run_ord.order_id
ORDER BY pizza_orders DESC
LIMIT 1;

-- For each customer, how many delivered pizzas had at least 1 change and how many had no changes?
SELECT 
	customer_id,
    COUNT(CASE
		WHEN exclusion_value IS NOT NULL AND exclusion_value != ''
        OR extra_value IS NOT NULL AND extra_value != ''
        THEN 1
        END) AS pizza_changed,
	COUNT(CASE
		WHEN exclusion_value IS NULL AND exclusion_value = ''
        OR extra_value IS NULL AND extra_value = ''
        THEN 1
        END) AS pizza_unchanged
FROM customer_orders
GROUP BY customer_id;

-- What was the total volume of pizzas ordered for each hour of the day?
SELECT HOUR(order_time) AS hour_of_day,
	   CONCAT(HOUR(order_time), ':00 - ', HOUR(order_time), ':59') AS time_range,
       COUNT(pizza_id) AS pizza_num
FROM customer_orders
GROUP BY hour_of_day, time_range
ORDER BY hour_of_day;

-- What was the volume of orders for each day of the week?
SELECT
	DATE_FORMAT(order_time, '%W') AS week_day,
    COUNT(pizza_id) AS pizza_num
FROM pizza_orders
GROUP BY week_day
ORDER BY pizza_num DESC;

-- QUESTIONS - PART B
-- Number of runners who registered
SELECT 
    FLOOR(DATEDIFF(registration_date, '2021-01-01') / 7) AS week_number,
    COUNT(runner_id) AS number_of_runners
FROM runners
GROUP BY week_number
ORDER BY week_number;

-- Average number of minutes
SELECT runner_id, SEC_TO_TIME(AVG(TIMESTAMPDIFF(SECOND, order_time, pickup_time))) AS avg_time_diff
FROM customer_orders cust_ord
JOIN runner_orders run_ord
ON cust_ord.order_id = run_ord.order_id
WHERE pickup_time IS NOT NULL
GROUP BY runner_id;

-- Relationship between the number of pizzas and how long the order takes to prepare
    SELECT 
    COUNT(run_ord.order_id) AS num_pizzas, 
    TIME_FORMAT(
        SEC_TO_TIME(
            AVG(TIMESTAMPDIFF(SECOND, order_time, pickup_time))
        ), 
        '%H:%i:%s'
    ) AS avg_prep_time
    FROM customer_orders cust_ord
    JOIN runner_orders run_ord ON cust_ord.order_id = run_ord.order_id
    GROUP BY run_ord.runner_id;

-- Average distance travelled for each customer
SELECT cust_ord.customer_id, ROUND(AVG(distance), 2) AS average_distance
FROM customer_orders cust_ord
JOIN runner_orders run_ord ON cust_ord.order_id = run_ord.order_id
GROUP BY cust_ord.customer_id
ORDER BY average_distance DESC;

-- Difference between the longest and shortest delivery times for all orders
SELECT (MAX(duration) - MIN(duration)) AS duration_diff
FROM runner_orders;

-- Average speed for each runner for each delivery and do you notice any trend for these values
SELECT DISTINCT run_ord.order_id, run_ord.runner_id,
ROUND(distance/(duration/60), 2) AS average_speed
FROM customer_orders cust_ord
JOIN runner_orders run_ord ON cust_ord.order_id = run_ord.order_id
WHERE distance IS NOT NULL AND duration IS NOT NULL
GROUP BY run_ord.runner_id, run_ord.order_id
ORDER BY run_ord.runner_id;

-- Successful delivery percentage for each runner
SELECT runner_id,
       ROUND((SUM(CASE WHEN cancellation IS NULL THEN 1 ELSE 0 END) / COUNT(order_id)) * 100, 2) AS percent_delivery
FROM runner_orders
GROUP BY runner_id;


