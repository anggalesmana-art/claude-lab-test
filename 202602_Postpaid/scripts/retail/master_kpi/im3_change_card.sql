delete from `data-nationalslsdist-prd-986g`.retail.raw_im3_change_card
	where format_date('%Y%m', dt_id)=left('{dt_id}',6)
	and format_date('%Y%m%d', dt_id)<='{dt_id}'
;

insert into `data-nationalslsdist-prd-986g`.retail.raw_im3_change_card
select 
	DATE(PARSE_TIMESTAMP('%d/%m/%Y %H:%M:%S', a.transaction_date)) as dt_id,
	customer_msisdn as msisdn,
	a.organization_ref_code as store_code, 
	a.username as agent_id, 
	a.service_type,
	sum(CAST(service_amount_collected AS FLOAT64)) rev_cash_in,
	sum(CAST(product_qty AS FLOAT64)) as qty
FROM
	`data-nationalslsdist-prd-986g`.retail.raw_ipos_nonps_trx as a 
WHERE
	(`status` in  ('Success', '') or `status` is null)
	and lower(service_type) like '%sim%replacement%'
	and format_date('%Y%m',PARSE_TIMESTAMP('%d/%m/%Y %H:%M:%S', transaction_date)) = left('{dt_id}',6)
	and format_date('%Y%m%d',PARSE_TIMESTAMP('%d/%m/%Y %H:%M:%S', transaction_date)) <='{dt_id}'
group by 1, 2, 3, 4, 5
;

-- mtd
select
	'{dt_id}' as dt_id,
	'change_card' as kpi_name,
	'agent' as level, 
	agent_id, 
	store_code, 
	'IM3' as brand, 
	count(distinct msisdn) as value
from `data-nationalslsdist-prd-986g`.retail.raw_im3_change_card
	where format_date('%Y%m', dt_id)=left('{dt_id}',6)
	and format_date('%Y%m%d', dt_id)<='{dt_id}'
group by 1, 2, 3, 4, 5, 6
union all
select
	'{dt_id}' as dt_id,
	'change_card' as kpi_name,
	'store' as level, 
	cast(null as string) agent_id, 
	store_code, 
	'IM3' as brand, 
	count(distinct msisdn) as value
from `data-nationalslsdist-prd-986g`.retail.raw_im3_change_card
	where format_date('%Y%m', dt_id)=left('{dt_id}',6)
	and format_date('%Y%m%d', dt_id)<='{dt_id}'
group by 1, 2, 3, 4, 5, 6;

-- dly
select
	format_date('%Y%m%d', dt_id) as dt_id,
	'change_card' as kpi_name,
	'agent' as level, 
	agent_id, 
	store_code, 
	'IM3' as brand, 
	count(distinct msisdn) as value
from `data-nationalslsdist-prd-986g`.retail.raw_im3_change_card
	where format_date('%Y%m', dt_id)=left('{dt_id}',6)
	and format_date('%Y%m%d', dt_id)<='{dt_id}'
group by 1, 2, 3, 4, 5, 6
union all
select
	format_date('%Y%m%d', dt_id) as dt_id,
	'change_card' as kpi_name,
	'store' as level, 
	cast(null as string) agent_id, 
	store_code, 
	'IM3' as brand, 
	count(distinct msisdn) as value
from `data-nationalslsdist-prd-986g`.retail.raw_im3_change_card
	where format_date('%Y%m', dt_id)=left('{dt_id}',6)
	and format_date('%Y%m%d', dt_id)<='{dt_id}'
group by 1, 2, 3, 4, 5, 6;