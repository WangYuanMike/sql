-- EXTRACT month, ORDER BY column index
-- SELECT payment_id, customer_id, amount, payment_date
-- FROM payment
-- WHERE EXTRACT(month FROM payment_date) = 2
-- AND customer_id > 589
-- ORDER BY 2, 3 DESC

-- EXTRACT date and COUNT
-- SELECT payment_date::date, COUNT(*)
-- FROM payment
-- GROUP BY 1
-- ORDER BY 2 DESC

-- GROUP as array
SELECT customer_id, ARRAY_AGG(payment_date::date)
FROM payment
GROUP BY 1
