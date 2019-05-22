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