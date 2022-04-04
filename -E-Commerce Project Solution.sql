
--E-Commerce Project Solution

--1. Join all the tables and create a new table called combined_table. 
--(market_fact, cust_dimen, orders_dimen, prod_dimen, shipping_dimen)


select A.*,C.*,D.*,E.*,B.Sales,b.Discount,b.Order_Quantity,b.Product_Base_Margin
into combined_table
from cust_dimen A 
	inner join market_fact$ B on A.Cust_id = B.Cust_id 
	inner join orders_dimen C on C.Ord_id = B.Ord_id
	inner join prod_dimen$ D on D.Prod_id = B.Prod_id
	inner join shipping_dimen E on E.Ship_id = B.Ship_id

select *
from combined_table


--2. Find the top 3 customers who have the maximum count of orders.

select top 3 Customer_Name, count(ord_id) cnt_order
from combined_table
group by Customer_Name
order by cnt_order desc



--3.Create a new column at combined_table as DaysTakenForDelivery that contains the 
--date difference of Order_Date and Ship_Date. Use "ALTER TABLE", "UPDATE" etc.

select Order_Date,Ship_Date,
	datediff(DAY,Order_Date,Ship_Date) DaysTakenForDelivery
from combined_table
order by  DaysTakenForDelivery desc

--4. Find the customer whose order took the maximum time to get delivered.
--Use "MAX" or "TOP"

select top 1 Customer_Name, Order_Date,Ship_Date,
	datediff(DAY,Order_Date,Ship_Date) DaysTakenForDelivery
from combined_table
order by  DaysTakenForDelivery desc

--5. Count the total number of unique customers in January and how many of them came back every 
--month over the entire year in 2011 You can use date functions and subqueries

select distinct Cust_id
from combined_table
where MONTH(Order_Date) = 1

with mnt_cust as(
select distinct Cust_id,month(order_date) month_2011
from combined_table
where Cust_id in (select distinct Cust_id
				from combined_table
				where MONTH(Order_Date) = 1) and
				year(Order_Date)  =2011
				)

select Cust_id,count(month_2011)
from mnt_cust
group by Cust_id
order by count(month_2011) desc

--6. write a query to return for each user acording to the time elapsed between the 
--first purchasing and the third purchasing, 
--in ascending order by Customer ID  Use "MIN" with Window Functions

with dif_table as
			(
			select	distinct cust_id,min(order_date)
				over (partition by cust_id order by cust_id asc) frst_ord_date,				
				lead(Order_Date,2) over(partition by cust_id order by cust_id asc) thrd_ordr_date
			from combined_table
			)
select *,datediff(DAY,frst_ord_date,thrd_ordr_date) dif_day
from dif_table
	

--7. Write a query that returns customers who purchased both product 11 and product 14, 
--as well as the ratio of these products to the total number of products purchased by all customers.
--Use CASE Expression, CTE, CAST and/or Aggregate Functions

select Cust_id, COUNT(distinct Prod_id) two_prod,
		SUM(CASE WHEN Prod_id= 'Prod_11' THEN 1.0  WHEN Prod_id='Prod_14' THEN 1.0  ELSE 0 END)/
				(SELECT COUNT(Prod_id) FROM combined_table) ratio
from combined_table
where  Prod_id = 'Prod_11' or Prod_id = 'Prod_14'
group by Cust_id



--CUSTOMER SEGMENTATION



--1. Create a view that keeps visit logs of customers on a monthly basis. (For each log, three field is kept: Cust_id, Year, Month)
--Use such date functions. Don't forget to call up columns you might need later.

create view visit_logs as 
select cust_id, year(order_date) [year] ,MONTH(order_date) [month]
from combined_table


  --2.Create a “view” that keeps the number of monthly visits by users. (Show separately all months from the beginning  business)
--Don't forget to call up columns you might need later.

create view num_of_vist_mnt as

select Cust_id,year(order_date) [year], MONTH(order_date) [month],count(MONTH(order_date)) month_vst
from combined_table
group by Cust_id,MONTH(order_date),year(order_date)

select *
from num_of_vist_mnt

--3. For each visit of customers, create the next month of the visit as a separate column.
--You can order the months using "DENSE_RANK" function.
--then create a new column for each month showing the next month using the order you have made above. (use "LEAD" function.)
--Don't forget to call up columns you might need later.

create view next_month_tbl as
select Cust_id,YEAR(order_date)[year],MONTH(order_date) [month],
		  DENSE_RANK() OVER(PARTITION BY Cust_id ORDER BY YEAR(order_date), MONTH(order_date)) D_Rank,
	      LEAD(YEAR(order_date)) OVER(PARTITION BY Cust_id ORDER BY YEAR(order_date), MONTH(order_date)) Next_Year,
		  LEAD(MONTH(order_date)) OVER(PARTITION BY Cust_id ORDER BY YEAR(order_date), MONTH(order_date)) Next_Month
from combined_table
group by Cust_id,YEAR(order_date),MONTH(order_date)

select *
from next_month_tbl



--4. Calculate monthly time gap between two consecutive visits by each customer.
--Don't forget to call up columns you might need later.

create view gap_table as
	select *, (CASE WHEN Next_month is null THEN 0
	       ELSE (Next_year-[year])*12 +Next_month - [month]
		   END) AS gap		      
	from next_month_tbl


--5.Categorise customers using average time gaps. Choose the most fitted labeling model for you.
--For example: 
--Labeled as ?churn? if the customer hasn't made another purchase for the months since they made their first purchase.
--Labeled as ?regular? if the customer has made a purchase every month.
--Etc.

create view avg_gap as
select Cust_id,
	   avg(gap) avg_gap, 
	   case when avg(gap) = 0 or avg(gap) >= 5 THEN 'Churn'
	   ELSE 'Regular' END Chr_Rgl
from gap_table
group by Cust_id



--MONTH-WISE RETENT?ON RATE


--Find month-by-month customer retention rate  since the start of the business.


--1. Find the number of customers retained month-wise. (You can use time gaps)
--Use Time Gaps

select COUNT(*)
from avg_gap
where avg_gap =1


--2. Calculate the month-wise retention rate.

--Basic formula: o	Month-Wise Retention Rate = 1.0 * Number of Customers Retained in The Current Month / Total Number of Customers in the Current Month

--It is easier to divide the operations into parts rather than in a single ad-hoc query. It is recommended to use View. 
--You can also use CTE or Subquery if you want.

--You should pay attention to the join type and join columns between your views or tables.

 create view montly_ttl_cust as
 select  YEAR(order_date) order_year, MONTH(order_date) order_month, COUNT(DISTINCT Cust_id) Total_Cust
 from combined_table
 group by  YEAR(order_date),MONTH(order_date) 

 create view Retained_monthly_cstm as
 select [year],[MONTH],COUNT(DISTINCT Cust_id) R_Total_Cust
 from gap_table
 group by  [year],[MONTH]
 having avg(gap) =1

 select *
 from montly_ttl_cust A,Retained_monthly_cstm B

SELECT order_year, order_month, Total_Cust, R_Total_Cust,
	   CAST((R_Total_Cust*1.0/Total_Cust) AS DECIMAL (5,4)) ret_rate
FROM montly_ttl_cust,Retained_monthly_cstm 
ORDER BY order_year, order_month