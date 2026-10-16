-- OLIST PROJECT: METRICS
-- these will be recoded as dax measures in powerBI  

use portfolio_olist;


/*
 * REPURCHASE RATE
 * tells you what proportion of your base is re-buying inside a window you set
 * Repurchase rate = (Customers with more than one order in the period / Total customers in the period) x 100
 * eg customers in q1 2018 with order count > 1 / all customers q1 2018
 */

-- structure of customers
-- id | uid | geolocation
-- ----------------------
-- 1  | 1   | 1
-- 2  | 1   | 1
-- 3  | 1   | 1

select *
from customers
where uid='8d50f5eadf50201ccdcedfb9e2ac8455'
;

-- "Each order has a unique customer_id", ie the same customer uid has a different customer id on each order
-- I want to track actual customers, so use the uid

with
sq_customer_orders as (
	select distinct -- distinct because order_id is basket-level but factsales is at line-item level 
		c.uid,
		fs.order_id
	from vw_factsales fs
		join customers c on fs.customer_id=c.id
	where d >= date('2018-01-01') and d < date('2018-04-01')
),
sq_repeat_customers as (
	select uid, count(order_id) n
	from sq_customer_orders
	group by uid
	having n > 1
)
select
	total_customers,
	repeat_customers,
	repeat_customers/total_customers*100 as repurchase_rate
from
	(select count(*) total_customers from sq_customer_orders) _
	cross join (select count(*) repeat_customers from sq_repeat_customers) __
;


/*
 * RETURN CUSTOMER RATE
 * measures the percentage of repeat customers, those who have placed more than one order with your business
 * Returning customer rate = (Returning customers / Total customers) x 100
 * eg n customers q2 who have any prior history / n customers q2 
 */

with 
customers_current as (
	select distinct c.uid
	from vw_factsales fs join customers c on fs.customer_id=c.id
	where fs.d >= date('2018-01-01') and fs.d < date('2018-04-01')
),
customers_previous as (
	select distinct	c.uid
	from vw_factsales fs join customers c on fs.customer_id=c.id
	where fs.d < date('2018-01-01')
),
customers_returned_count as (
	select count(*) n_returned from (
		select uid
		from customers_current
		where uid in (select uid from customers_previous) 
	) _
)
select count(*) n_current, n_returned, (n_returned/count(*))*100
from customers_current cross join customers_returned_count
;


/*
 * CUSTOMER RETENTION RATE
 * Measures the percentage of customers retained over a specific period.
 * Retention rate = [(customers at end of period − new customers acquired) / customers at start of period] × 100
 * Customers at start of period: the number of existing customers before the period began.
 * Customers at end of period: the number of customers who purchased during or by the close of the period.
 * New customers acquired: customers making their first purchase within the period.
 */

with 
customers_current as (
	select distinct	c.uid
	from vw_factsales fs join customers c on fs.customer_id=c.id
	where fs.d >= date('2018-04-01') and fs.d < date('2018-07-01')
),
customers_history as (
	select distinct c.uid
	from vw_factsales fs join customers c on fs.customer_id=c.id
	where fs.d < date('2018-04-01')
),
customers_previous as (
	select distinct	c.uid
	from vw_factsales fs join customers c on fs.customer_id=c.id
	where fs.d >= date('2018-01-01') and fs.d < date('2018-04-01')
),
customers_current_notnew as (
	select count(*) n_current_notnew from (
		select uid
		from customers_current
		where uid in (select uid from customers_history)
	) _
)
select count(*) n_previous, n_current_notnew, (n_current_notnew/count(*))*100
from customers_previous cross join customers_current_notnew
;


/*
 * PURCHASE FREQUENCY
 * measures how many orders the average customer places within a defined window
 * Purchase frequency = Total orders / Total customers who ordered in the period
 */

with 
sq as (
	select distinct 
		c.uid,
		fs.order_id
	from vw_factsales fs join customers c on fs.customer_id=c.id
	where fs.d >= date('2018-01-01') and fs.d < date('2018-04-01')
),
sq_totalorders as (select count(*) n_orders from sq),
sq_totalcustomers as (select count(*) n_customers from (select distinct uid from sq) _)
select n_customers, n_orders, n_orders/n_customers purchase_freq 
	from sq_totalcustomers 
	cross join sq_totalorders 
;


/*
 * NEW CUSTOMER SHARE
 * new customer share tells you what proportion of a period's revenue came from them
 * shows whether growth is arriving from an expanding customer base or preexisting base
 * Formula: New customer share = (Revenue from first-time customers / Total revenue) x 100
 */

with 
customers_history as (
	select distinct c.uid
	from vw_factsales fs join customers c on fs.customer_id=c.id
	where fs.d < date('2018-01-01') and c.uid is not null
),
sales_total as (
	select sum(price) revenue
	from vw_factsales fs
	where fs.d >= date('2018-01-01') and fs.d < date('2018-04-01')
),
sales_new_customers as (
	select sum(price) revenue
	from vw_factsales fs join customers c on fs.customer_id=c.id
	where fs.d >= date('2018-01-01') 
		and fs.d < date('2018-04-01') 
		and uid not in (select uid from customers_history)
)
select
	st.revenue,
	snc.revenue,
	(snc.revenue/st.revenue)*100 new_customer_share 
from sales_total st cross join sales_new_customers snc
;