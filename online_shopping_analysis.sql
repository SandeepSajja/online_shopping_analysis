create database miniproject2;
use miniproject2;
#1.	Join all the tables and create a new table called combined_table.
#(market_fact, cust_dimen, orders_dimen, prod_dimen, shipping_dimen)

select *
from market_fact mr join cust_dimen cd
on mr.cust_id = cd.cust_id
join orders_dimen od
on od.ord_id = mr.ord_id
join prod_dimen pd
on pd.prod_id = mr.prod_id
join shipping_dimen sd
on sd.ship_id = mr.ship_id;

select * from orders_dimen;

#2.Find the top 3 customers who have the maximum number of orders
with temp(c_id,count_id) as
(select cust_id,count(ord_id)
from market_fact
group by cust_id
)
select cust_id,customer_name,count_id 
from cust_dimen,temp
where cust_id = c_id
order by count_id desc
limit 3;
# 	HERE WE CAN GET ONLY THREE VALUE BUT LOT CUSTOMERS HAVE SAME NUMBER OF ORDERS FOR THAT I TRIED RANKING METHOD
create view cust_orders as
with temp(c_id,count_id) as
(select cust_id,count(ord_id)
from market_fact
group by cust_id
)
select cust_id,customer_name,count_id,
dense_rank() over(order by count_id desc rows unbounded preceding) ranking
from cust_dimen,temp
where cust_id = c_id;

select cust_id,customer_name,count_id,ranking
from cust_orders
where ranking <=3;

#3.	Create a new column DaysTakenForDelivery that contains the date difference of Order_Date and Ship_Date.

desc shipping_dimen;
desc orders_dimen;

set sql_safe_updates = 0;

update orders_dimen set order_date = str_to_date(order_date,"%d-%m-%Y");
update shipping_dimen set ship_date = str_to_date(ship_date,"%d-%m-%Y");

alter table orders_dimen modify order_date  date;
alter table shipping_dimen modify ship_date date; 

with temp(or_id,sh_id,or_date) as
(select ord_id,ship_id,order_date
from market_fact m,
(select order_id,ord_id as o_id,order_date from orders_dimen)o
where m.ord_id =o.o_id)
select or_id,sh_id,datediff(ship_date,or_date) days_taken_for_delivery
from shipping_dimen,temp
where ship_id = sh_id;

#4.	Find the customer whose order took the maximum time to get delivered

with temp (ord_id,cus_id,days)as
(select mf.ord_id,cust_id,datediff(ship_date,order_date) as days_taken_for_deliver
from market_fact mf join orders_dimen od
on mf.ord_id = od.ord_id
join shipping_dimen sd
on mf.ship_id = sd.ship_id)
select cust_id,customer_name,days
from cust_dimen,temp
where cust_id = cus_id
order by days desc
limit 1;


#5.	Retrieve total sales made by each product from the data (use Windows function)

select prod_id,sales,
round(sum(sales) over(partition by prod_id),2) as total_sales_prod
from market_fact;

# 6.Retrieve total profit made from each product from the data (use windows function)

select prod_id,profit,
round(sum(profit) over(partition by prod_id),2) as total_profit_prod
from market_fact;

#7.	Count the total number of unique customers in January and how many of them came back every month over the entire year in 2011

create view cust as
(select cust_id,mf.ord_id,
count(cust_id) over()as no_customer_in_jan
from market_fact mf join orders_dimen od
on mf.ord_id = od.ord_id
where date_format(order_date,"%Y-%m") = 2011-01);

select no_customer_in_jan,count(cust_id) every_month_cust from cust where cust_id in
(select distinct cust_id
from market_fact where ord_id in
(select ord_id from orders_dimen where date_format(order_date,"%Y") = 2011 and month(order_date)  between 2 and 12));


#8.	Retrieve month-by-month customer retention rate since the start of the business.(using views)

#Tips: 
#1: Create a view where each user’s visits are logged by month, 
# allowing for the possibility that these will have occurred over multiple 
# years since whenever business started operations

drop view Year_wise_customer;

create view Year_wise_customer as (
select distinct Cust_id,year,month,yearmonth from 
(select mf.Cust_id,mf.Ord_id,extract(YEAR_MONTH from Order_Date) as yearmonth, month(Order_Date) as month , year(Order_Date) as year  from `market_fact` as MF 
join cust_dimen as cd
on mf.Cust_id = cd.Cust_id
join orders_dimen as od
on mf.Ord_id = od.Ord_id)t1
order by Cust_id,year,month,yearmonth);

select * from Year_wise_customer;

# 2: Identify the time lapse between each visit. So, for each person and for each month, we see when the next visit is.

create view time_lapse as
(select *,lead(yearmonth) over(partition by Cust_id order by yearmonth) as nextvistyearmonth from Year_wise_customer);

select * from time_lapse;

# 3: Calculate the time gaps between visits

create view timegap as
select *,period_diff(nextvistyearmonth,yearmonth) as time_gap from time_lapse;

select * from timegap;

# 4: categorise the customer with time gap 1 as retained, >1 as irregular and NULL as churned

create view retention as 
select *,
case 
when time_gap = 1 then 'retained'
when time_gap > 1 then 'Irregular'
when time_gap = null then 'churned'
end as retention from timegap;

select * from retention;

# 5: calculate the retention month wise

select month,count(*) as rention_customer from retention
where retention = 'retained'
group by month
order by month;












