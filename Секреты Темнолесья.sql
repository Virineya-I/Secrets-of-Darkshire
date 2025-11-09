/* Проект «Секреты Тёмнолесья»
 * Цель проекта: изучить влияние характеристик игроков и их игровых персонажей 
 * на покупку внутриигровой валюты «райские лепестки», а также оценить 
 * активность игроков при совершении внутриигровых покупок
 * 
 * Автор: Ильященко Виринея Юрьевна
 * Дата: 03.10.2024
*/

-- Часть 1. Исследовательский анализ данных
-- Задача 1. Исследование доли платящих игроков

-- 1.1. Доля платящих пользователей по всем данным:
SELECT COUNT(id) AS count_all_users,
       SUM(payer) AS payer_users,
       ROUND(SUM(payer)::numeric/COUNT(id), 4) share_of_payer_players
FROM fantasy.users 

-- 1.2. Доля платящих пользователей в разрезе расы персонажа:
SELECT r.race,
       COUNT(u.id) AS count_all_users_per_race,
       SUM(u.payer) AS payer_users_per_race,
       ROUND(SUM(u.payer)::numeric/COUNT(u.id), 4) AS share_of_payer_players_per_race
FROM fantasy.users u 
LEFT JOIN fantasy.race r USING(race_id)  
GROUP BY r.race
ORDER BY share_of_payer_players_per_race DESC

-- Задача 2. Исследование внутриигровых покупок
-- 2.1. Статистические показатели по полю amount:
SELECT COUNT(transaction_id) AS count_of_all_pur,
       SUM(amount) AS total_amount,
       MIN(amount) AS min_amount,
       MAX(amount) AS max_amount,
       ROUND(AVG(amount)::numeric, 2) AS avg_amount,
       PERCENTILE_DISC(0.5) WITHIN GROUP (ORDER BY amount) AS mediana_of_amount,
       ROUND(STDDEV(amount)::numeric, 2) AS stddev_of_amount
FROM fantasy.events 

-- 2.2: Аномальные нулевые покупки:
SELECT COUNT(*) AS zero_purchases,
       ROUND(COUNT(*)::numeric/(SELECT COUNT(*)
                        FROM fantasy.events), 6) AS part_off_zero_purchases
FROM fantasy.events
WHERE amount = 0

-- 2.3: Сравнительный анализ активности платящих и неплатящих игроков:
--Найдем количество покупок и суммарную стоимость покупок для каждого неплатящего игрока
WITH count_and_sum_nopayer AS (
SELECT e.id, 
       COUNT(e.transaction_id) count_of_pur_for_nopayer, 
       SUM(e.amount) AS sum_amount_for_nopayer
FROM fantasy.events AS e
LEFT JOIN fantasy.users AS u USING(id)
WHERE e.amount > 0 AND u.payer = 0
GROUP BY e.id 
   ),
--Посчитаем общее количество неплатящих игроков, среднее количество покупок и среднюю суммарную стоимость покупок на одного неплатящего игрока 
data_for_nopayer AS (
SELECT COUNT(id) AS count_of_user,
       ROUND(AVG(count_of_pur_for_nopayer), 2) AS avg_count_of_pur_for_nopayer,
       ROUND(SUM(sum_amount_for_nopayer)::numeric/COUNT(id), 2) AS avg_sum_amount_for_nopayer
FROM count_and_sum_nopayer
    ),
--Найдем количество покупок и суммарную стоимость покупок для каждого платящего игрока
count_and_sum_payer AS (
SELECT e.id, 
       COUNT(e.transaction_id) count_of_pur_for_payer, 
       SUM(e.amount) AS sum_amount_for_payer
FROM fantasy.events AS e
LEFT JOIN fantasy.users AS u USING(id)
WHERE e.amount > 0 AND u.payer = 1
GROUP BY e.id 
   ),
--Посчитаем общее количество платящих игроков, среднее количество покупок и среднюю суммарную стоимость покупок на одного платящего игрока    
data_for_payer AS (
SELECT COUNT(id) AS count_of_user,
       ROUND(AVG(count_of_pur_for_payer), 2) AS avg_count_of_pur_for_payer,
       ROUND(SUM(sum_amount_for_payer)::numeric/COUNT(id), 2) AS avg_sum_amount_for_payer
FROM count_and_sum_payer
    ) 
--ОбЪединим данные из финальных таблиц для платящих и неплатящих пользователей, отсортируем данные в порядке убывания средней стоимости покупки на человека    
SELECT 'payer' AS name_of_group,
        count_of_user,
        avg_count_of_pur_for_payer AS avg_count_of_pur,
        avg_sum_amount_for_payer AS avg_sum_amount
FROM data_for_payer
UNION
SELECT 'nopayer',
        *
FROM data_for_nopayer
ORDER BY avg_sum_amount DESC

-- 2.4: Популярные эпические предметы:
SELECT i.game_items AS name_of_item,
       COUNT(e.transaction_id) AS count_of_item,
       ROUND(COUNT(e.transaction_id)::numeric/(SELECT COUNT(*) FROM fantasy.events), 4) AS share_of_item,
       ROUND(COUNT(DISTINCT id)::numeric/(SELECT COUNT(DISTINCT id) FROM fantasy.events), 4) AS share_of_player_who_pay,
       ROUND(COUNT(DISTINCT id)::numeric/(SELECT COUNT(id) FROM fantasy.users), 4) AS share_of_all_player
FROM fantasy.events AS e
LEFT JOIN fantasy.items AS i USING(item_code)
WHERE amount > 0
GROUP BY i.game_items
ORDER BY count_of_item DESC

-- Часть 2. Решение ad hoc-задач
-- Задача 1. Зависимость активности игроков от расы персонажа:
--Расчет числа игроков и платящих игроков в пределах расы
WITH all_count_per_race AS (
    SELECT r.race,
           COUNT(u.id) AS count_per_race
    FROM fantasy.users  u
    LEFT JOIN fantasy.race r USING(race_id)
    GROUP BY r.race
),
--Расчет пользователей, которые покупают в пределах расы
count_of_buyer AS (
    SELECT r.race,
           COUNT(DISTINCT id) AS count_of_bayer_for_race
    FROM fantasy.events e
    LEFT JOIN fantasy.users u USING(id)
    LEFT JOIN fantasy.race r USING(race_id) 
    WHERE e.amount > 0 
    GROUP BY r.race
),
--Расчет числа платящих игроков и покупающих в пределах расы
buyer_and_payer AS (
 SELECT r.race,
        COUNT(DISTINCT id) AS count_of_bayer_and_payer_for_race
    FROM fantasy.events e
    LEFT JOIN fantasy.users u USING(id)
    LEFT JOIN fantasy.race r USING(race_id) 
    WHERE e.amount > 0 and u.payer = 1
    GROUP BY r.race
),
--Расчет числа покупок и средняя сумма покупки на пользователя  в пределах расы 
qty_for_race AS (
    SELECT r.race,
       count(e.transaction_id) AS qty_purchase_for_race,
       ROUND(AVG(e.amount)::numeric, 2) AS avg_amount_per_user
    FROM fantasy.events e
    LEFT JOIN fantasy.users u USING(id)
    LEFT JOIN fantasy.race r USING(race_id)
    WHERE e.amount > 0 
    GROUP BY r.race
),
--Расчет суммы всех покупок для каждого пользователя
sum_amount_per_user AS (
    SELECT e.id,
           r.race,
           SUM(e.amount) AS sum_amount_per_person
    FROM fantasy.events e
    LEFT JOIN fantasy.users u USING(id)
    LEFT JOIN fantasy.race r USING(race_id) 
    GROUP BY e.id, r.race
),
--Расчет средней суммы покупок на человека в пределах расы    
avg_sum_amount_per_race AS (
    SELECT race,
           ROUND(SUM(sum_amount_per_person)::numeric/COUNT(id), 2) AS avg_sum_amount
    FROM sum_amount_per_user
    GROUP BY race
)
--Собираем данные в одну таблицу, по ходу вычисляем долю платящих от всех покупателей расы и среднее количество покупок на одного игрока в пределах расы
SELECT first_table.race,
       first_table.count_per_race,
       second_table.count_of_bayer_for_race,
       ROUND(second_table.count_of_bayer_for_race::numeric/first_table.count_per_race, 4) AS share_of_buyer,
       add_table.count_of_bayer_and_payer_for_race,
       ROUND(add_table.count_of_bayer_and_payer_for_race::numeric/second_table.count_of_bayer_for_race, 4) AS share_of_payer,
       ROUND(third_table.qty_purchase_for_race::numeric/second_table.count_of_bayer_for_race, 2) AS avg_qty_purchase,
       third_table.avg_amount_per_user,
       fourth_table.avg_sum_amount
FROM all_count_per_race AS first_table
JOIN count_of_buyer AS second_table USING(race)
JOIN buyer_and_payer as add_table USING(race)
JOIN qty_for_race AS third_table USING(race)
JOIN avg_sum_amount_per_race AS fourth_table USING(race)
ORDER BY avg_sum_amount DESC, avg_amount_per_user DESC

-- Задача 2: Частота покупок
--Вычислим интервал для каждой транзакции на каждого пользователя, где сумма покупки больше нуля
WITH table_of_intervals as (
SELECT transaction_id,
       id,
       LEAD(events_date) OVER(partition by id
                                order by events_date) - events_date as interval_between_transaction,
       amount                      
FROM (                             
SELECT transaction_id,
       id,
       date::date AS events_date,
       amount
FROM fantasy.events
) AS date_table
    where amount > 0
    ORDER BY id
),
--Вычислим общее количество покупок для каждого пользователя и среднее время между транзакциями.
--Для покупателей, у которых совершена только одна покупка - присвоим значения интервала 0. 
table_of_avg_interval as (
select id,
       COUNT(transaction_id) as transactions_count,
       case 
       when COUNT(transaction_id) > 1 then AVG(interval_between_transaction)
       else '0'
       end as avg_interval_between_transaction
from table_of_intervals
group by id 
order by avg_interval_between_transaction 
),
--Вот здесь возникает у меня проблема, если изначально брать время в днях, вылетают транзакции пользователей, которые совершали две и более покупок в один день, 
--а их терять нельзя, это те самые наши очень активные игроки. 
--Но в получавшейся таблице есть игроки, у которых среднее время между транзациями в днях ноль, но количество покупок у них отлично от 1, то есть есть доля игроков, которые 
--покупают чаще, чем раз в день в среднем. Их интервалы я оставляю в днях, как просят в задании, но теперь возьмем таблицу, в которой уберу игроков с количеством покупок меньше 25.
--И разбиваем пользователей на три группы
table_wirh_rank as (
select *,
       NTILE(3) over() as number_of_group
from (       
select *
from table_of_avg_interval
where transactions_count >= 25
order by avg_interval_between_transaction, transactions_count DESC 
) as table_of_active_users
),
--Называем категории пользователей
table_of_groups_name as (
select id,
       transactions_count,
       avg_interval_between_transaction,
       case
	       when number_of_group = 1 then 'высокая частота'
	       when number_of_group = 2 then 'умеренная частота'
	       when number_of_group = 3 then 'низкая частота'
	       else ' '
	       end as name_of_group
from table_wirh_rank	       
),
--Выичслим число покупателей и суммарное количество в каждой категории, а также среднее количество дней между покупками
table_of_buyers as (
select name_of_group,
       COUNT(id) as buyers_count,
       SUM(transactions_count)  as sum_count_of_purchases,
       AVG(avg_interval_between_transaction) as avg_interval_for_group
from table_of_groups_name
group BY name_of_group 
),
--Вычислим число платящих игроков (покупатели с нулевой стоимость покупки были исключены выше)
table_of_payers as (
select table_of_groups_name.name_of_group,
       COUNT(table_of_groups_name.id) as payers_count
from table_of_groups_name 
left join fantasy.users u USING(id)
where u.payer = 1
group by name_of_group
)
--Собираем данные в таблицу, вычисляем долю платящих игроков и среднее количество покупок на игрока
select first_table.name_of_group,
       first_table.buyers_count,
       second_table.payers_count,
       ROUND(second_table.payers_count::numeric/first_table.buyers_count, 4) as payers_share,
       ROUND(first_table.sum_count_of_purchases/first_table.buyers_count, 2) as avg_count_of_purchases,
       ROUND(first_table.avg_interval_for_group, 2)
from table_of_buyers as first_table
join table_of_payers as second_table USING(name_of_group)
order by avg_interval_for_group
