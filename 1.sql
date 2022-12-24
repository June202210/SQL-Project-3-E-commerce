/*objective: analysing data from 11/25/2021 to 12/03/2021 to give business insights*/

SELECT * FROM sys.userbehavior;

# 1. data cleaning

1) check if there is any null value(value count is consistant, no null value)
SELECT 
    COUNT(user_id),
    COUNT(item_id),
    COUNT(category_id),
    COUNT(behavior_type),
    COUNT(time_stamp)
FROM
    userbehavior;
    
2)check if there is duplicate

###create a new column named ID
alter table userbehavior add id int primary key auto_increment;

### find rows with duplicates（2 duplicate rows found）
drop table if exists temp;
create temporary table temp
select id, user_id,item_id, time_stamp,row_number()over(partition by user_id, item_id,time_stamp)as duplicates
from userbehavior;
	
select *from temp where duplicates>1;

### delete duplicates 
delete from userbehavior where id = 100001 or id=100002;


3) convert timestamp 
### add a new column named new_dates to take the corrected time value
alter table userbehavior add new_dates varchar(255);
update userbehavior set new_dates = from_unixtime(time_stamp, '%Y-%m-%d');
select* from userbehavior;
alter table userbehavior drop column new_date;
alter table userbehavior drop column dates;

### add a new column named hour
alter table userbehavior add hour varchar(255);
update userbehavior set hour = from_unixtime(time_stamp, '%H');
select* from userbehavior;
	
### add a new column named datetimes
alter table userbehavior add datetimes varchar(255);
update userbehavior set datetimes = from_unixtime(time_stamp, '%Y-%m-%d %H:%i:%s');
select* from userbehavior;

4) check if all records are within time range (11/25/2021-12/03/2021)
select * from userbehavior where new_dates<'2021-11-25' or new_dates>'2021-12-03';

###delete records that are not needed
delete from userbehavior where new_dates<'2021-11-25' or new_dates>'2021-12-03';


# 2. data exploration with AIPL model(A- awareness, I-interest, P- purchase/buy, L=loyalty)

1) calculate AIP
###create view behavior
drop view if exists behavior;
create view behavior as
select user_id,datetimes,new_dates, hour,
max(case behavior_type when 'pv' then 1 else 0 end)as'pv',
max(case behavior_type when 'fav' then 1 else 0 end)as'favor',
max(case behavior_type when 'cart' then 1 else 0 end)as'cart',
max(case behavior_type when 'buy' then 1 else 0 end)as'buy'
from userbehavior
group by user_id,datetimes,new_dates, hour;

select * from behavior;

###get AIP
select sum(pv)as 'A',
sum(favor)+sum(cart)as'I', sum(buy)as'P'
from behavior;

2) calculate L
drop table if exists consume;
create temporary table consume 
select user_id,datetimes,buy,dense_rank()over(partition by user_id order by datetimes)as 'n_consume'
from behavior where buy=1
order by user_id,datetimes;

/* SUMMARY:A VALUE- 86458, I VALUE- 7876, P VALUE-1814 L VALUE-1150;
Rate through each funnel is 9%, 23%, 63% respectively. 
A(awareness) to I(interest) converstion rate is very low. */


# 3. data analysis
/*From user behavior and products dimensions, find the reason behind the low conversion rate, and provide advice accordingly.*/

1)From user behavior dimension, find converstion rate at different hour 
create temporary table A_view
select hour, count(*)as A_view_behavior
from behavior
where pv=1 
group by hour;

create temporary table I_interest
select hour, count(*)as I_interest_behavior
from behavior
where favor=1 or cart=1
group by hour;

select A_view.hour,A_view_behavior,I_interest_behavior,
concat(round(I_interest_behavior/A_view_behavior,3)*100,'%')as A_to_I_rate
from A_view 
left join I_interest
on A_view.hour=I_interest.hour
order by A_view.hour;



###use average A to I conversion rate as measurement standard

select round(avg(A_view_behavior)),round(avg(I_interest_behavior)),
concat(round(avg(I_interest_behavior/A_view_behavior),3)*100,'%')as avg_A_to_I_rate
from A_view 
left join I_interest
on A_view.hour=I_interest.hour;

/*find the hour whose view behavior,interest_behavior and rate go above average. hour:02, 03, 06, 10, 22. 
Among these hours, 10 o'clock has the best performance, converstion rate is 10.1%. 
Recommend to use 10 o'clock as the primary advertising time to attract more customers.*/

2) From product dimension, analyze data to see if product recommendation is useful.
### find how many items that customers viewed and were interested

#### items viewed
select count(distinct item_id)as A_item
from userbehavior
where behavior_type='pv';

#### interested items
select count(distinct item_id)as I_item
from userbehavior
where behavior_type in('favor','cart');

####A_item value 58744, I_item_value 5022. Client viewed a lot of items(58744) but were only interested in a few of them(5022).

3) hypothesis testing to find the reason behind this
/* Hypothesis:Clients were not interested in most products that the platform recommended.
If the products that client viewed consist only a small portion of the products that client marked as favourite or put into cart, 
it means hypothesis is true.*/

drop view if exists A;
create view A as
select item_id,count(*)as'A'
from userbehavior
where behavior_type='pv'
group by item_id 
order by A desc;
select count(*) from A;
	
drop view if exists I;
create view I as
select item_id,count(*)as'I'
from userbehavior
where behavior_type in('favor','cart')
group by item_id 
order by I desc;

select count(*) from I;
	

select count(*)'same_item' from A
inner join I
on A.item_id= I.item_id;
	

### In total, 58744 products were recommended,but only 3032 were marked as favor or put into cart by customers. That meands the recommendation didn't work well. 
/*summary：Most products are tail items which don't attract many customers.
Thus, recommend product department to update product information on the platform,
and take actions to get rid of low converstion rate products.*/






