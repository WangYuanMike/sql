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

SELECT inventory_id, COUNT(rental_id) as rentals
FROM rental
GROUP BY 1
ORDER BY 2 DESC;

