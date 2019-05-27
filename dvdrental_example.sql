-- EXTRACT month, ORDER BY column index
SELECT payment_id, customer_id, amount, payment_date
FROM payment
WHERE EXTRACT(month FROM payment_date) = 2
AND customer_id > 589
ORDER BY 2, 3 DESC; 

-- EXTRACT date and COUNT
SELECT payment_date::date, COUNT(*)
FROM payment
GROUP BY 1
ORDER BY 2 DESC;

-- GROUP as array
SELECT customer_id, ARRAY_AGG(payment_date::date)
FROM payment
GROUP BY 1;

-- INNER JOIN
SELECT gs:: date, gs2::date
FROM generate_series('2017-08-01', current_date::date, INTERVAL '1 Day') gs
INNER JOIN generate_series('2017-08-10', current_date::date, INTERVAL '1 Day') gs2
	    ON gs::date = gs2::date;
		
-- LEFT JOIN / GROUP BY / HAVING
SELECT * FROM payment p;

SELECT gs::date, COUNT(*)
FROM generate_series('2007-02-01', '2007-02-28', INTERVAL '1 Day') gs
LEFT JOIN payment p ON p.payment_date::date = gs::date
GROUP BY 1
HAVING COUNT(*) = 1;

-- Has all inventory ever been rented?
SELECT
		f.film_id, f.title,
		i.store_id, i.inventory_id,
		COUNT(distinct r.rental_id) as rentals
FROM film f
		LEFT JOIN inventory i ON i.film_id = f.film_id
		LEFT JOIN rental r ON r.inventory_id = i.inventory_id
GROUP BY 1, 2, 3, 4
ORDER BY 3 NULLS FIRST;

-- Find a customer's first rental and various attributes about it
-- correlated query
SELECT r.customer_id, min(r.rental_id) as first_rental_id,
(
	SELECT rental_date FROM rental r2 WHERE r2.rental_id = min(r.rental_id)
)::date as first_rental_date
FROM rental r
GROUP BY 1
ORDER BY 1;

-- Everything is a table: How many customers purchase from multiple stores?
SELECT * FROM
(
	SELECT t.customer_id, COUNT(*) as number_of_stores FROM
	(
		SELECT DISTINCT r.customer_id, s.store_id
		FROM rental r
			LEFT JOIN staff s ON r.staff_id = s.staff_id
		ORDER BY 1
	) t
	GROUP BY 1
) t2
WHERE t2.customer_id < 10;

-- Another option
WITH base_table AS (
	SELECT DISTINCT r.customer_id, s.store_id
		FROM rental r
			LEFT JOIN staff s ON r.staff_id = s.staff_id
		ORDER BY 1
)

SELECT customer_id, COUNT(*) as number_of_stores 
FROM base_table
GROUP BY 1;

-- JOIN gotchas, sometimes, if using a LEFT JOIN and NULLS matter,
-- put the filter on the JOIN itself
SELECT zebra::date, 'zebra', p.*
FROM generate_series('2007-02-01', '2007-02-28', INTERVAL '1 day') as zebra
LEFT JOIN payment p ON p.payment_date::date = zebra::date AND staff_id = 2
ORDER BY 3 NULLS FIRST;

-- Chaining multiple conditions where OR is involved
-- from rental_id > 1400 and payment hour is between 8am to Noon or 2pm to 3pm
WITH base_table AS (
	SELECT zebra::date, 'zebra', p.*
	FROM generate_series('2007-02-01', '2007-02-28', INTERVAL '1 day') as zebra
	LEFT JOIN payment p ON p.payment_date::date = zebra::date AND staff_id = 2
	ORDER BY 3 NULLS FIRST
)

SELECT * FROM base_table bt
WHERE bt.rental_id > 1400
  AND (EXTRACT(HOUR FROM bt.payment_date) IN (8, 9, 10, 11, 12) OR
	   EXTRACT(HOUR FROM bt.payment_date) IN (14))
ORDER BY 6;

-- WHERE vs. HAVING
-- HAVING was added to SQL because WHERE could not be used for aggregation functions
-- Return customers whose first order was on the weekend and was worth over 5
-- and who have spent at least 100 in total
-- Note: Sunday = 0, Saturday = 6
SELECT p.*, EXTRACT(dow FROM p.payment_date),
	(
		SELECT SUM(p3.amount) FROM payment p3
		WHERE p3.customer_id = p.customer_id
	) as CLV 	-- CLV = Customer Lifetime Value
FROM payment p
WHERE p.payment_id = (
	SELECT MIN(p2.payment_id)
	FROM payment p2
	WHERE p2.customer_id = p.customer_id
)
AND EXTRACT(dow FROM p.payment_date) IN (0, 6)
AND p.amount > 5
GROUP BY 1
HAVING (
	SELECT SUM(p3.amount) FROM payment p3
	WHERE p3.customer_id = p.customer_id
) > 100;

-- Sub query
SELECT t.grouping, COUNT(*) FROM (
	SELECT 'above' as grouping, f.* FROM film f
	WHERE f.replacement_cost > (SELECT AVG(f2.replacement_cost) FROM film f2)
		UNION
	SELECT 'below_eq' as grouping, f.* FROM film f
	WHERE f.replacement_cost <= (SELECT AVG(f2.replacement_cost) FROM film f2)
) t
GROUP BY 1;

-- Unique join condition
SELECT p.*
FROM payment p JOIN (
	SELECT p2.customer_id, min(p2.payment_date) as first_date
	FROM payment p2
	GROUP BY 1
) t ON p.customer_id = t.customer_id AND p.payment_date = t.first_date;

-- Correlated subquery
-- Get a customer's total rental amount, 
-- but also their total rental amount in the month of their first month
WITH base_table AS (
	SELECT p.customer_id, SUM(p.amount) as LTV,
		(
			SELECT EXTRACT(MONTH FROM MIN(p2.payment_date)) FROM payment p2
			WHERE p2.customer_id = p.customer_id
		) AS first_order
	FROM payment p
	GROUP BY 1
)

SELECT bt.*, (
	SELECT SUM(p3.amount) FROM payment p3
	WHERE p3.customer_id = bt.customer_id
	AND EXTRACT(MONTH FROM p3.payment_date) = bt.first_order
) AS rental_amt_month_1
FROM base_table bt;

-- Common table expression, Window functions
WITH some_table AS (
	SELECT f.film_id, f.title, f.rating, SUM(p.amount),
		ROW_NUMBER() OVER(PARTITION BY f.rating ORDER BY SUM(p.amount) DESC)
	FROM film f
		JOIN inventory i ON f.film_id = i.film_id
		JOIN rental r ON r.inventory_id = i.inventory_id
		JOIN payment p ON p.rental_id = r.rental_id
	GROUP BY 1, 2, 3
	ORDER BY 3
)

SELECT st.* FROM some_table st WHERE st.row_number = 1;

-- Dealing with date and time
SELECT
	p.payment_date::date,
	current_date,
	to_char(p.payment_date::date, 'YYYY/Month/DD'),
	EXTRACT(YEAR FROM p.payment_date),
	EXTRACT(MONTH FROM p.payment_date),
	EXTRACT(WEEK FROM p.payment_date),
	EXTRACT(dow FROM p.payment_date),
	age(p.payment_date::date) as age_of_pdate,
	-- p.payment_date - INTERVAL '7 days' as days_7_b4_pmt
	COUNT(*)
FROM payment p
GROUP BY 1,2,3,4,5,6,7;

-- CASE statement, Substring
-- want to get counts of people whose last name starts with a vowel(AEIOU)
SELECT t.my_case_outcome, COUNT(*) FROM (
	SELECT c.*, substring(c.last_name, '^[AEIOUaeiou]') AS x,
		CASE
			WHEN substring(c.last_name, '^[AEIOUaeiou]') IS NOT NULL THEN 'last_starts_vow'
			ELSE 'novowel'
			END as my_case_outcome,

		CASE
			WHEN substring(c.last_name, '^[AEIOUaeiou]') IS NOT NULL THEN substring(c.last_name, '^[AEIOUaeiou]')
			ELSE 'novowel'
			END as the_letter_or_not
	FROM customer c
) t
GROUP BY 1;
    
-- LAG function
SELECT t.*, t.amount - t.prior_order FROM (
	SELECT 
		p.*, 
		LAG(p.amount) OVER (PARTITION BY p.customer_id ORDER BY p.amount) AS prior_order 
	FROM payment p 
) t;

-- Moving average, window function
SELECT 
	p.*,
	AVG(p.amount) OVER w AS avg_over_prior7,
	AVG(p.amount) OVER w2 AS back3_fwd_3_avg
FROM payment p

WINDOW w AS (ORDER BY p.payment_id ROWS BETWEEN 7 PRECEDING AND 0 FOLLOWING),
	   w2 AS (ORDER BY p.payment_id ROWS BETWEEN 3 PRECEDING AND 3 FOLLOWING);

-- top 10% of movies by dollar value rented
SELECT f.film_id, f.title, SUM(p.amount) AS sales,
	NTILE(100) OVER (ORDER BY SUM(p.amount) DESC) AS p_rank
FROM rental r JOIN inventory i ON i.inventory_id = r.inventory_id
			  JOIN film f ON f.film_id = i.film_id
			  JOIN payment p ON p.rental_id = r.rental_id
GROUP BY 1, 2
ORDER BY 3 DESC;

