-- 1. Вывести сколько заказов было оформлено, и сколько в итоге получено. Не учитывать тестовые заказы.

select count(case when ClientOrderStateID = 1 then id end) as Orders_placed, 
       count(case when ClientOrderStateID = 2 then id end) as Orders_recieved
from Orders o
     inner join AdditionalInfo ai on o.id = ai.ClientOrderID
where ai.value = 0;

-- 2. Для каждой платформы и категории посчитать: сколько было куплено товаров, сколько было получено заказов, GMV. 
-- Не учитывать тестовые заказы. 

select platform
       ,category 
       ,sum(qty) as Orders_purchased 
       ,count(case when ClientOrderStateID = 2 then coi.ClientOrderID end) as Orders_recieved
	   ,sum(qty*price) as GMV
from ClientOrderItem coi
     inner join Orders o on coi.ClientOrderID = o.id
	 inner join AdditionalInfo ai on coi.ClientOrderID = ai.ClientOrderID
where ai.value = 0
group by platform, category
order by platform, category;

-- 3. Найти категорию, которая приносит наибольшую выручку.

select category
       ,sum(qty*price) as max_revenue
from ClientOrderItem 
group by category
having sum(qty*price) = 
       (select max(revenue) as max_gmv
	    from (select category, sum(qty*price) as revenue 
		      from ClientOrderItem
			  group by category) query_in
	   );
     
-- 4. Какой товар чаще других встречается в отмененных заказах.

select ItemId
from ClientOrderItem coi
     inner join Orders o on o.id = coi.ClientOrderID
group by ItemId
having count(case when ClientOrderStateID = 3 then ItemId end) = 
       (
	   select max(Amount) as max_amount
	   from (select ItemId, count(case when ClientOrderStateID = 3 then ItemId end) as Amount
	         from ClientOrderItem coi
                  inner join Orders o on o.id = coi.ClientOrderID
			 group by ItemId) query_in
	   );
       
-- 5. Найдите среднее время между первым и вторым заказом у пользователей. 
-- Для решения запроса не используйте джойны. Тестовые заказы фильтровать не нужно.

WITH cte AS 
    (
     select clientId
	        ,date
            ,lead(date) over (partition by clientId order by date) as second_purchase
            ,row_number () over (partition by clientId order by date) RN
     from Orders
	 )

select avg(datediff(second_purchase, date)) AS average_time
from cte
where RN = 1;

-- 6. Для каждой категории найдите топ – 3 пользователей, у которых наименьшее количество дней 
-- между первой и последней покупкой в этой категории. Тестовые заказы фильтровать не надо.

with cte as
(select *
		,row_number () over (partition by category order by time_diff) RN
from (select category
       ,clientId
	   ,datediff(max(date),min(date)) as time_diff 
	from Orders o
    inner join ClientOrderItem coi on o.id = coi.ClientOrderID
    group by category, clientId
    having max(date) !=  min(date)
    order by category, time_diff) query_in
)  

select *
from cte
where RN <= 3