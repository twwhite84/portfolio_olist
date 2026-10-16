-- OLIST PROJECT: DATABASE FROM CSVS
-- this makes use of MariaDB, an open-source version of MySQL

-- full unicode to handle some brazilian characters, and case insensitive querying
create database portfolio_olist
character set utf8mb4
collate utf8mb4_unicode_ci
;

use portfolio_olist;

/*
 * SETTING UP TABLES AND RELATIONSHIPS FROM CSVS
 * using CSVs and descriptions from https://www.kaggle.com/datasets/olistbr/brazilian-ecommerce
 */

-- deletion sequence
drop table order_items;
drop table products;
drop table product_categories;
drop table order_reviews;
drop table order_payments;
drop table closed_deals;
drop table marketing_qualified_leads;
drop table orders;
drop table customers;
drop table sellers;
drop table geolocation;

/*
 * ORDERS
 */

create table orders (
	id char(32) primary key,
	customer_id char(32),
	order_status varchar(20),
	purchase_timestamp datetime,
	approved_at datetime,
	delivered_carrier_date datetime,
	delivered_customer_date datetime,
	estimated_delivery_date datetime
)
;

load data local infile '/learning/olist/csvs/olist_orders_dataset.csv'
into table orders
fields terminated by ','
optionally enclosed by '"'
lines terminated by '\n'
ignore 1 rows
(
	@order_id,
	@customer_id,
	@order_status,
	@order_purchase_timestamp,
	@order_approved_at,
	@order_delivered_carrier_date,
	@order_delivered_customer_date,
	@order_estimated_delivery_date
)
set
id = nullif(@order_id, ''),
customer_id = nullif(@customer_id, ''),
order_status = nullif(@order_status, ''),
purchase_timestamp = nullif(@order_purchase_timestamp, ''),
approved_at = nullif(@order_approved_at, ''),
delivered_carrier_date = nullif(@order_delivered_carrier_date, ''),
delivered_customer_date = nullif(@order_delivered_customer_date, ''),
estimated_delivery_date = nullif(@order_estimated_delivery_date, '')
;

describe orders;
select * from orders limit 100;

-- null checks: delivered dates have nulls
select count(*) from orders where id is null; -- 0
select count(*) from orders where customer_id is null; -- 0
select count(*) from orders where order_status is null; -- 0
select count(*) from orders where purchase_timestamp is null; -- 0
select count(*) from orders where approved_at is null; -- 160
select count(*) from orders where delivered_carrier_date is null; -- 1783
select count(*) from orders where delivered_customer_date is null; -- 2965
select count(*) from orders where estimated_delivery_date is null; -- 0


/*
 * ORDER ITEMS
 * order_item_id is actually just a sequence index number partitioned by order
 * together they form a composite key order_id.order_item_id
 * i'm modifying this table slightly to use a regular integer primary key 
 */

create table order_items (
	order_id char(32),
	sequence_n int,
	product_id char(32),
	seller_id char(32),
	shipping_limit_date datetime,
	price decimal(6,2),
	freight_value decimal(6,2)
)
;

load data local infile '/learning/olist/csvs/olist_order_items_dataset.csv'
into table order_items
fields terminated by ','
optionally enclosed by '"'
lines terminated by '\n'
ignore 1 rows
(
	@order_id,
	@order_item_id,
	@product_id,
	@seller_id,
	@shipping_limit_date,
	@price,
	@freight_value
)
set
order_id = nullif(@order_id, ''),
sequence_n = nullif(@order_item_id, ''),
product_id = nullif(@product_id, ''),
seller_id = nullif(@seller_id, ''),
shipping_limit_date = nullif(@shipping_limit_date, ''),
price = nullif(@price, ''),
freight_value = nullif(@freight_value, '')
;

-- modifying the order items table as i don't like having order_item_id being both a sequence number plus part of a key
alter table order_items
add column id int auto_increment primary key first,
add constraint fk_orderitems_orders
foreign key (order_id) references orders(id)
;

describe order_items;
select * from order_items limit 100;

-- null checks: no nulls
select count(*) from order_items where id is null; -- 0
select count(*) from order_items where order_id is null; -- 0
select count(*) from order_items where sequence_n is null; -- 0
select count(*) from order_items where product_id is null; -- 0
select count(*) from order_items where seller_id is null; -- 0
select count(*) from order_items where shipping_limit_date is null; -- 0
select count(*) from order_items where price is null; -- 0
select count(*) from order_items where freight_value is null; -- 0


/*
 * CUSTOMERS
 * each new "customer" (id) can map to the same real customer (uid), ie the same real customer can be repeatedly listed across differnet ids 
 */

create table customers (
	id char(32) primary key, -- key to the orders dataset, each order has a unique customer_id
	uid char(32),
	zip_code_prefix char(5),
	city varchar(50),
	state char(2)
)
;

load data local infile '/learning/olist/csvs/olist_customers_dataset.csv'
into table customers
fields terminated by ','
optionally enclosed by '"'
lines terminated by '\n'
ignore 1 rows
(
	@customer_id,
	@customer_unique_id,
	@customer_zip_code_prefix,
	@customer_city,
	@customer_state
)
set
id = nullif(@customer_id, ''),
uid = nullif(@customer_unique_id, ''),
zip_code_prefix = nullif(@customer_zip_code_prefix, ''),
city = nullif(@customer_city, ''),
state = nullif(@customer_state, '')
;

describe customers;
select * from customers limit 100;

-- null checks: no nulls
select count(*) from customers where id is null; -- 0
select count(*) from customers where uid is null; -- 0
select count(*) from customers where zip_code_prefix is null; -- 0
select count(*) from customers where city is null; -- 0
select count(*) from customers where state is null; -- 0

-- you can see multiple records may have the same unique customer id but different locations eg zip code prefixes
-- perhaps uid originally was a foreign key to a customer details table, and customer here means a combination of that plus location at time of purchase 
select
	uid,
	id,	
	count(*) over(partition by uid) as n
from customers
order by n desc, uid, id
;

select * from customers where uid='3e43e6105506432c953e165fb2acf44c';

-- update orders table to use customers as foreign key
alter table orders
add constraint fk_orders_customers
foreign key (customer_id) references customers(id)
;


/*
 * PRODUCTS
 */

create table products(
	id char(32) primary key,
	category_name varchar(50),
	n_photos int,
	weight_g int,
	length_cm int,
	height_cm int,
	width_cm int
)
;

-- this was edited later to trim carriage returns as i found some fields had them
load data local infile '/learning/olist/csvs/olist_products_dataset.csv'
into table products
fields terminated by ','
optionally enclosed by '"'
lines terminated by '\n'
ignore 1 rows
(
	@id,
	@category_name,
	@name_length,
	@description_length,
	@n_photos,
	@weight_g,
	@length_cm,
	@height_cm,
	@width_cm
)
set
id = @id,
category_name = nullif(trim(trailing '\r' from @category_name), ''),
n_photos = nullif(@n_photos, ''),
weight_g = nullif(@weight_g, ''),
length_cm = nullif(@length_cm, ''),
height_cm = nullif(@height_cm, ''),
width_cm = nullif(@width_cm, '')
;

describe products;
select * from products limit 100;

-- null checks: many, with missing category data probably going to be main issue
select count(*) from products where id is null; -- 0
select count(*) from products where category_name is null; -- 610
select count(*) from products where n_photos is null; -- 610
select count(*) from products where weight_g is null; -- 2
select count(*) from products where length_cm is null; -- 2
select count(*) from products where height_cm is null; -- 2
select count(*) from products where width_cm is null; -- 2

-- order items makes use of product ids so add the foreign key
alter table order_items
add constraint fk_orderitems_products
foreign key (product_id) references products(id)
;


/*
 * PRODUCT CATEGORY NAME ENGLISH
 * i'm going to use this csv file as a base of a new categories table, add a primary key
 * then i'll update the products table to refer to it instead of containing the portugese name
 */

create table product_categories (
	id int auto_increment primary key,
	name_portugese varchar(50),
	name varchar(50)
)
;

load data local infile '/learning/olist/csvs/product_category_name_translation.csv'
into table product_categories
fields terminated by ','
optionally enclosed by '"'
lines terminated by '\n'
ignore 1 rows
(
	@product_category_name,
	@product_category_name_english
)
set
name_portugese = nullif(trim(trailing '\r' from @product_category_name), ''),
name = nullif(trim(trailing '\r' from @product_category_name_english), '')
;

describe product_categories;
select * from product_categories;

-- now i need to swap out the category in the products table for the id
-- theres a couple of categories in the products table that aren't in the translation table, add them in.
select distinct category_name from products where category_name not in (select name_portugese from product_categories);
insert into product_categories(name_portugese, name) values ('pc_gamer', 'pc_gamer');
insert into product_categories(name_portugese, name) values ('portateis_cozinha_e_preparadores_de_alimentos', 'small_kitchen_appliances');

-- am going to change the nulls for category data in products to be 'uncategorised', so add a lookup value here too
-- insert into product_categories(name_portugese, name) values ('uncategorised', 'uncategorised');

select count(*) from products;
select count(*) from products where category_name is null; -- 610 out of 32951 products dont have categories

-- updating products so null categories are 'uncategorised'
-- update products p
-- set p.category_name = 'uncategorised'
-- where p.category_name is null
-- ;

-- modify the products table to use a foreign product_categories id instead of storing the category names directly
alter table products
add column category_id int
;

-- copy in the category ids, update affects current records, not to be confused with insert which adds new records
-- no where clause because i want to update every record
update products p
join product_categories pc on pc.name_portugese=p.category_name
set p.category_id = pc.id
;

-- drop the category_name field from products now
alter table products
drop column category_name,
add constraint fk_products_productcategories
foreign key (category_id) references product_categories(id)
;

-- drop the portugese names from product_categories
alter table product_categories
drop column name_portugese
;

describe product_categories;
select * from product_categories;
select * from products limit 100;

select count(*) from products where category_id is null; -- 610

-- 2026-09-07 i will add a new id for uncategorised items
insert into product_categories values (-1, 'uncategorised');
select * from product_categories;

-- 2026-09-07 updating products table so that records with no category lookup id get -1, the 'uncategorised' key
update products p
set p.category_id = -1
where p.category_id is null
;

/*
 * SELLERS
 */

create table sellers (
	id char(32) primary key,
	zip_code_prefix char(5),
	city varchar(50),
	state char(2)
)
;

load data local infile '/learning/olist/csvs/olist_sellers_dataset.csv'
into table sellers
fields terminated by ','
optionally enclosed by '"'
lines terminated by '\n'
ignore 1 rows
(
	@seller_id,
	@seller_zip_code_prefix,
	@seller_city,
	@seller_state
)
set
id = nullif(@seller_id, ''),
zip_code_prefix = nullif(@seller_zip_code_prefix, ''),
city = nullif(@seller_city, ''),
state = nullif(@seller_state, '')
;

describe sellers;
select * from sellers limit 100;

-- null checks: no nulls
select count(*) from sellers where id is null; -- 0
select count(*) from sellers where zip_code_prefix is null; -- 0
select count(*) from sellers where city is null; -- 0
select count(*) from sellers where state is null; -- 0

-- order_items makes use of sellers id so modify the table
describe order_items;

alter table order_items
add constraint fk_orderitems_sellers
foreign key (seller_id) references sellers(id)
;


/*
 * GEOLOCATION
 */

create table geolocation (
	zip_code_prefix char(5),
	lat double,
	lng double,
	city varchar(50),
	state char(2)
)
;

load data local infile '/learning/olist/csvs/olist_geolocation_dataset.csv'
into table geolocation
fields terminated by ','
optionally enclosed by '"'
lines terminated by '\n'
ignore 1 rows
(
	@geolocation_zip_code_prefix,
	@geolocation_lat,
	@geolocation_lng,
	@geolocation_city,
	@geolocation_state
)
set
zip_code_prefix = nullif(@geolocation_zip_code_prefix, ''),
lat = nullif(@geolocation_lat, ''),
lng = nullif(@geolocation_lng, ''),
city = nullif(@geolocation_city, ''),
state = nullif(@geolocation_state, '')
;

-- over a million records, many with similar coordinates
-- a few groups with high variance, this might be explained by some zip code prefixes referring to totally different locations
select count(*) from geolocation;

select
	zip_code_prefix,
	variance(lat),
	variance(lng)
from geolocation
group by zip_code_prefix
order by (variance(lat)+variance(lng))/2 desc
;

-- a common zip code prefix may refer to different locations eg different cities
select * from geolocation where zip_code_prefix=57319;
-- or significantly different coordinates within the same city and state, maybe data has errors?
select * from geolocation where zip_code_prefix=29654;

-- look at distinct city and state count per zip code prefix
select 
	zip_code_prefix, 
	count(*) as k
from (select distinct zip_code_prefix, city, state from geolocation) _
group by zip_code_prefix
order by k desc
;

-- n distinct records per zip code also includes slight variations of spellings for the same city
select * from geolocation where zip_code_prefix=13454;

-- i will group by zip_code_prefix and select for the middle (or lower-middle for even counts) coordinates in each
create table geolocation_reduced
with sq as (
	select
		*,
		row_number() over(partition by zip_code_prefix order by lat, lng) as i,
		count(*) over(partition by zip_code_prefix) as k
	from geolocation
)
select
	zip_code_prefix,
	lat,
	lng,
	city,
	state
from sq where i = floor((k+1)/2)
;

-- ideally i should have a business rule: given a zip_code_prefix, state and city, where more than one coordinate cluster then null coordinates
	
-- reduced from over a million records down to 19015 by averaging the coordinates
select count(*) from geolocation_reduced;

drop table geolocation;
rename table geolocation_reduced to geolocation;

-- there are 162 zip code prefixes from customers and sellers that aren't in geolocation
select count(*)
from (select zip_code_prefix from customers union select zip_code_prefix from sellers) x 
where x.zip_code_prefix not in (select zip_code_prefix from geolocation);

-- insert new records for those missing zip_code_prefix, city and state data from customers into geolocation table
insert into geolocation (
	zip_code_prefix,
	lat,
	lng,
	city,
	state
)
select
	c.zip_code_prefix,
	null,
	null,
	c.city,
	c.state
from (
	select zip_code_prefix, city, state
	from customers
	union
	select zip_code_prefix, city, state
	from sellers
) c
where c.zip_code_prefix not in (select zip_code_prefix from geolocation)
;

-- add an id primary key to geolocation and put it on the left as usual
alter table geolocation
add column id int auto_increment primary key first
;

-- change customers and sellers to use the key to geolocation instead of storing the data directly
alter table customers
add column geolocation_id int
;

-- need to add an index otherwise the update takes over 16 minutes
show index from geolocation; -- i see only an index on id, the primary key
show index from customers; -- i see only an index on id, the primary key
create index idx_geolocation_zip_code_prefix on geolocation(zip_code_prefix);

-- copy in the geolocation ids
update customers c
join geolocation g on g.zip_code_prefix=c.zip_code_prefix
set c.geolocation_id=g.id
;

-- quick check eg row 1 in customers has prefix 06273, city osasco, state SP, geolocation_id 3140
select * from geolocation where id=3140;

-- drop the zip_code_prefix, city and state fields from customers and add the foreign key relationship
alter table customers
drop column zip_code_prefix,
drop column city,
drop column state,
add constraint fk_customers_geolocation
foreign key (geolocation_id) references geolocation(id)
;

-- repeat process for sellers
alter table sellers
add column geolocation_id int
;

update sellers s
join geolocation g on g.zip_code_prefix=s.zip_code_prefix
set s.geolocation_id=g.id
;

-- geolocation_id 4059 from first seller should go to zip 09080, city santo andre, state SP
select * from geolocation where id=4059;

alter table sellers
drop column zip_code_prefix,
drop column city,
drop column state,
add constraint fk_sellers_geolocation
foreign key (geolocation_id) references geolocation(id)
;

-- null checks: some missing coordinates
select count(*) from geolocation where id is null;
select count(*) from geolocation where zip_code_prefix is null;
select count(*) from geolocation where lat is null; -- 162
select count(*) from geolocation where lng is null; -- 162
select count(*) from geolocation where city is null;
select count(*) from geolocation where state is null;

-- 2026-09-16: adding state names for each state code
alter table geolocation
add column state_name text
;

update geolocation
set state_name = case state
	when 'AC' then 'Acre'
	when 'AL' then 'Alagoas'
	when 'AP' then 'Amapá'
	when 'AM' then 'Amazonas'
	when 'BA' then 'Bahia'
	when 'CE' then 'Ceará'
	when 'DF' then 'Distrito Federal'
	when 'ES' then 'Espírito Santo'
	when 'GO' then 'Goiás'
	when 'MA' then 'Maranhão'
	when 'MT' then 'Mato Grosso'
	when 'MS' then 'Mato Grosso do Sul'
	when 'MG' then 'Minas Gerais'
	when 'PA' then 'Pará'
	when 'PB' then 'Paraíba'
	when 'PR' then 'Paraná'
	when 'PE' then 'Pernambuco'
	when 'PI' then 'Piauí'
	when 'RJ' then 'Rio de Janeiro'
	when 'RN' then 'Rio Grande do Norte'
	when 'RS' then 'Rio Grande do Sul'
	when 'RO' then 'Rondônia'
	when 'RR' then 'Roraima'
	when 'SC' then 'Santa Catarina'
	when 'SP' then 'São Paulo'
	when 'SE' then 'Sergipe'
	when 'TO' then 'Tocantins'
	else state_name
end
;

select * from geolocation where state_name is null limit 100;


/*
 * ORDER REVIEWS
 * has a relationship with orders
 */

create table order_reviews (
	review_id char(32),
	order_id char(32),
	score int,
	comment_title varchar(50),
	comment_message text,
	creation_date datetime,
	answer_timestamp datetime
)
;

-- dont worry about single row 77917
load data local infile '/learning/olist/csvs/olist_order_reviews_dataset.csv'
into table order_reviews
fields terminated by ','
optionally enclosed by '"'
lines terminated by '\n'
ignore 1 rows
(
	@review_id,
	@order_id,
	@review_score,
	@review_comment_title,
	@review_comment_message,
	@review_creation_date,
	@review_answer_timestamp
)
set
review_id = nullif(@review_id, ''),
order_id = nullif(@order_id, ''),
score = nullif(@review_score, ''),
comment_title = nullif(@review_comment_title, ''),
comment_message = nullif(@review_comment_message, ''),
creation_date = nullif(@review_creation_date, ''),
answer_timestamp = nullif(@review_answer_timestamp, '')
;

-- an order can have multiple reviews
select * from order_reviews where order_id='df56136b8031ecd28e200bb18e6ddb2e';

-- a review can cover multiple orders
select * from order_reviews where review_id='c444278834184f72b1484dfe47de7f97';

-- so i think there's a many-to-many relationship between orders and order_reviews via order_id
describe order_reviews;

alter table order_reviews
add constraint fk_orderreviews_orders
foreign key (order_id) references orders(id)
;

select review_id, count(*) from order_reviews group by review_id order by count(*) desc;


/*
 * ORDER PAYMENTS
 * order_id: unique identifier of an order
 * payment_sequential: a customer may pay an order with more than one payment method. If he does so, a sequence will be created to accommodate all payments
 * payment_type: method of payment chosen by the customer
 * payment_installments: number of installments chosen by the customer
 * payment_value: transaction value
 */

create table order_payments (
	order_id char(32),
	sequential int,
	payment_type varchar(20),
	installments int,
	value decimal(7,2)
)
;

load data local infile '/learning/olist/csvs/olist_order_payments_dataset.csv'
into table order_payments
fields terminated by ','
optionally enclosed by '"'
lines terminated by '\n'
ignore 1 rows
(
	@order_id,
	@payment_sequential,
	@payment_type,
	@payment_installments,
	@payment_value
)
set
order_id=nullif(@order_id, ''),
sequential=nullif(@payment_sequential, ''),
payment_type=nullif(@payment_type, ''),
installments=nullif(@payment_installments, ''),
value=nullif(@payment_value, '')
;

-- example case: sequence on a delivered order has 3 payment types (2 distinct), with each having its own number of installments
select order_status from orders where id='0cd93455c51655ebb590c07a06d584a1';
select * from order_payments where order_id='0cd93455c51655ebb590c07a06d584a1';
select price, freight_value from order_items where order_id='0cd93455c51655ebb590c07a06d584a1';

-- total value from payments on the delivered order equals the price + freight, as should be the case for a completed order
select sum(value) from order_payments where order_id='0cd93455c51655ebb590c07a06d584a1';
select price+freight_value from order_items where order_id='0cd93455c51655ebb590c07a06d584a1';

alter table order_payments
add constraint fk_orderpayments_orders
foreign key (order_id) references orders(id)
;

-- null checks: no nulls
select count(*) from order_payments where order_id is null; -- 0
select count(*) from order_payments where sequential is null; -- 0
select count(*) from order_payments where payment_type is null; -- 0
select count(*) from order_payments where installments is null; -- 0
select count(*) from order_payments where value is null; -- 0


/*
 * CLOSED DEALS
 * Marketing Funnel add-on data from https://www.kaggle.com/datasets/olistbr/marketing-funnel-olist
 * "After a qualified lead fills in a form at a landing page he is contacted by a Sales Development Representative.
 * At this step some information is checked and more information about the lead is gathered.
 * This dataset can also be linked to the Brazilian E-Commerce Public Dataset by Olist using seller_id."
 * 
 * FIELD							DESCRIPTION																DATA TYPE
 * mql_id							Marketing Qualified Lead id.											char(32)
 * seller_id						Seller id.																char(32), fk
 * sdr_id							Sales Development Representative id.									char(32)
 * sr_id							Sales Representative.													char(32)
 * won_date							Date the deal was closed.												datetime
 * business_segment					Lead business segment. Informed on contact.								varchar(50)
 * lead_type						Lead type. Informed on contact.											varchar(50)
 * lead_behaviour_profile			Lead behaviour profile. SDR identify it on contact.						varchar(50)
 * has_company						Does the lead have a company (formal documentation)?					bool
 * has_gtin							Does the lead have Global Trade Item Number (barcode) for his products?	bool
 * average_stock					Lead declared average stock. Informed on contact.						varchar(50)
 * business_type					Type of business (reseller/manufacturer etc.)							varchar(50)
 * declared_product_catalog_size	Lead declared catalog size. Informed on contact.						int
 * delcared_monthly_revenue			Lead declared estimated monthly revenue. Informed on contact.			decimal(10,2)
 */

create table closed_deals (
	mql_id char(32),
	seller_id char(32),
	sdr_id char(32),
	sr_id char(32),
	won_date datetime,
	business_segment varchar(50),
	lead_type varchar(50),
	lead_behaviour_profile varchar(50),
	has_company bool,
	has_gtin bool,
	average_stock varchar(50),
	business_type varchar(50),
	declared_product_catalog_size int,
	declared_monthly_revenue decimal(10,2)
)
;

load data local infile '/learning/olist/csvs/olist_closed_deals_dataset.csv'
into table closed_deals
fields terminated by ','
optionally enclosed by '"'
lines terminated by '\n'
ignore 1 rows
(
	@mql_id,
	@seller_id,
	@sdr_id,
	@sr_id,
	@won_date,
	@business_segment,
	@lead_type,
	@lead_behaviour_profile,
	@has_company,
	@has_gtin,
	@average_stock,
	@business_type,
	@declared_product_catalog_size,
	@declared_monthly_revenue
)
set
mql_id=nullif(@mql_id, ''),
seller_id=nullif(@seller_id, ''),
sdr_id=nullif(@sdr_id, ''),
sr_id=nullif(@sr_id, ''),
won_date=nullif(@won_date, ''),
business_segment=nullif(@business_segment, ''),
lead_type=nullif(@lead_type, ''),
lead_behaviour_profile=nullif(@lead_behaviour_profile, ''),
has_company=case
	when lower(@has_company) in ('true', 't') then true
	when lower(@has_company) in ('false', 'f') then false
	else null	
end,
has_gtin=case
	when lower(@has_gtin) in ('true', 't') then true
	when lower(@has_gtin) in ('false', 'f') then false
	else null
end,
average_stock=nullif(@average_stock, ''),
business_type=nullif(@business_type, ''),
declared_product_catalog_size=nullif(@declared_product_catalog_size, ''),
declared_monthly_revenue=nullif(@declared_monthly_revenue, '')
;

describe closed_deals;
select * from closed_deals limit 100;

-- null checks
select count(*) from closed_deals where mql_id is null; -- 0
select count(*) from closed_deals where seller_id is null; -- 0
select count(*) from closed_deals where sdr_id is null; -- 0
select count(*) from closed_deals where sr_id is null; -- 0
select count(*) from closed_deals where won_date is null; -- 0
select count(*) from closed_deals where business_segment is null; -- 1
select count(*) from closed_deals where lead_type is null; -- 6
select count(*) from closed_deals where lead_behaviour_profile is null; -- 177
select count(*) from closed_deals where has_company is null; -- 779
select count(*) from closed_deals where has_gtin is null; -- 778
select count(*) from closed_deals where average_stock is null; -- 776
select count(*) from closed_deals where business_type is null; -- 10
select count(*) from closed_deals where declared_product_catalog_size is null; -- 773
select count(*) from closed_deals where declared_monthly_revenue is null;

-- 462 seller ids in closed_deals aren't currently in my sellers table
select nm.n_missing, ns.n_sellers
from (
	select count(*) as n_missing from (
		select distinct seller_id as sellers_missing
		from closed_deals
		where seller_id not in (select id from sellers)
	) _
) nm
cross join (select count(*) as n_sellers from sellers) ns
;

-- i'll append them as new records in sellers, though i won't have their geolocation ids
insert into sellers (id, geolocation_id)
select cd.seller_id, null
from (select seller_id from closed_deals) cd
where cd.seller_id not in (select id from sellers)
;

select count(*)=(3095+462) from sellers; -- counts match

alter table closed_deals
add constraint fk_closeddeals_sellers
foreign key (seller_id) references sellers(id)
;


/*
 * MARKETING QUALIFIED LEADS
 * "After a lead fills in a form at a landing page, a filter is made to select the ones that are qualified to sell their products at Olist. 
 * They are the Marketing Qualified Leads (MQLs)."
 * 
 * FIELD				DESCRIPTION									DATA TYPE
 * mql_id				Marketing Qualified Lead id					char(32)
 * first_contact_date	Date of the first contact solicitation.		date
 * landing_page_id		Landing page id where the lead was acquired	char(32)
 * origin				Type of media where the lead was acquired	varchar(50)
 */

create table marketing_qualified_leads (
	mql_id char(32),
	first_contact_date date,
	landing_page_id char(32),
	origin varchar(50)
)
;

load data local infile '/learning/olist/csvs/olist_marketing_qualified_leads_dataset.csv'
into table marketing_qualified_leads
fields terminated by ','
optionally enclosed by '"'
lines terminated by '\n'
ignore 1 rows
(
	@mql_id,
	@first_contact_date,
	@landing_page_id,
	@origin
)
set
mql_id=nullif(@mql_id, ''),
first_contact_date=nullif(@first_contact_date, ''),
landing_page_id=nullif(@landing_page_id, ''),
origin=nullif(@origin, '')
;

-- make mql_id in marketing_qualified_leads a primary key
alter table marketing_qualified_leads
add primary key (mql_id);

-- make closed_deals reference it
alter table closed_deals
add constraint fk_closeddeals_marketingqualifiedleads
foreign key (mql_id) references marketing_qualified_leads(mql_id);