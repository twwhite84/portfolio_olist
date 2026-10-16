-- OLIST PROJECT: VIEWS

use portfolio_olist;

/*
 * FACT TABLE: SALES
 * a sales view based on delivered items, this will be imported into powerBI
 */

-- integrity checks
select * from order_items where order_id not in (select order_id from orders); -- no orphaned order items
select * from orders where order_status='delivered' and purchase_timestamp is null; -- there's always a purchase timestamp
select * from orders where order_status='delivered' and approved_at is null; -- 14 delivered orders with no approval timestamp
select * from orders where order_status='delivered' and delivered_customer_date is null; -- 8 delivered orders with no customer delivery date
select * from orders where order_status='delivered' and delivered_carrier_date is null; -- 2 delivered orders with no carrier delivery date

-- trimming lower end below 2017 and higher end part way through 2018 august to demonstrate incomplete period
create or replace view vw_FactSales as
select
	date(o.purchase_timestamp) as d,
	o.customer_id,
	o.id as order_id,
	oi.product_id,
	p.category_id,	
	oi.price,
	oi.freight_value,
	c.geolocation_id,
	o.order_status
from order_items as oi
	join orders as o on o.id=oi.order_id
	join products as p on p.id=oi.product_id
	join customers as c on c.id=o.customer_id
where year(o.purchase_timestamp) >= 2017
	and o.purchase_timestamp <= date('2018-08-20')
order by purchase_timestamp
;

select * from vw_FactSales limit 100;


/*
 * MONTHLY REVENUE AND GROWTH BY PRODUCT CATEGORY
 * this demonstrates creating a spine (here monthly calendar and product category), 
 * attaching patchy aggregated values, and use of a window function for lagging 
 */

create or replace view vw_FactRevenue as
with recursive
-- monthly calendar spine starting from earliest date in sales data
sq_mcal as (
	select date(date_format(min(d), '%Y-%m-01')) as m from vw_FactSales
	union all
	select date_add(m, interval 1 month) from sq_mcal
	where m < (select date(date_format(max(d), '%Y-%m-01')) from vw_FactSales)
),
-- adding product categories for each month to spine
sq_spine as (
	select
		sq_mcal.m,
		pc.id category_id
	from sq_mcal
		cross join product_categories pc
),
-- monthly revenue by category from delivered orders 
sq_rev as (
	select
		date(date_format(d, '%Y-%m-01')) m,
		category_id,
		sum(price) as revenue
	from vw_FactSales fs
	where fs.order_status='delivered'
	group by m, category_id
),
-- joining revenues to spine, keeping all spine even if no sales for a month
sq_spinerev as (
	select
		s.m,
		s.category_id,
		coalesce(r.revenue, 0) as revenue
	from sq_spine s
		-- <=> is null safe equality (ie = but also works for nulls)
		left join sq_rev r on s.m=r.m and s.category_id <=> r.category_id
),
-- lagging revenue by 12 months to compute year-over-year growth figures 
sq_spinerevlag as (
	select *, lag(revenue, 12) over(partition by category_id order by m) as revenue_previous
	from sq_spinerev
),
-- computing the growth column
sq_revgrowth as (
	select *, round(((revenue - revenue_previous) / nullif(revenue_previous, 0))*100, 2) as revenue_growth_percent
	from sq_spinerevlag
)
select * from sq_revgrowth
;

select * from vw_factrevenue limit 100;

-- suppose i instead want to see total revenue per year
select
	date(date_format(m, '%Y-01-01')) as y,
	sum(revenue) as revenue
from vw_FactRevenue
group by date(date_format(m, '%Y-01-01'))
;