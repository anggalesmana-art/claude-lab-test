with ga_base as (
	select
	    a.activation_date as dt_id,
	    a.store_code_rev as store_code,
	    a.nik_sales as agent_id,
	    count(distinct a.msisdn) as ga
	from `data-nationalslsdist-prd-986g`.postpaid.raw_daily_ga as a
	        where left(a.activation_date,6)=left('{dt_id}',6)
	    and a.activation_date <= '{dt_id}'
	    and lower(a.agent_type) not like '%outcall%' 
	    and a.nik_sales is not null and a.nik_sales <>'' and a.nik_sales <> '-'
	    and (lower(a.channel_rev) like '%gerai%' or lower(a.channel_rev) like '%franchise%')
	    and lower(a.order_type) in ('migration', 'new registration', 'port in migration')
	group by 1, 2, 3
) 
-- mtd
select
	'{dt_id}' as dt_id,
	'ga_postpaid' as kpi_name,
	'agent' as level, 
	agent_id, 
	store_code, 
	'IM3' as brand, 
	sum(ga) as value
from ga_base
	where left(dt_id,6)=left('{dt_id}',6)
		and dt_id<='{dt_id}'
group by 1, 2, 3, 4, 5, 6
union all
select
	'{dt_id}' as dt_id,
	'ga_postpaid' as kpi_name,
	'store' as level, 
	cast(null as string) as agent_id, 
	store_code, 
	'IM3' as brand, 
	sum(ga) as value
from ga_base
	where left(dt_id,6)=left('{dt_id}',6)
		and dt_id<='{dt_id}'
group by 1, 2, 3, 4, 5, 6;

with ga_base as (
	select
	    a.activation_date as dt_id,
	    a.store_code_rev as store_code,
	    a.nik_sales as agent_id,
	    count(distinct a.msisdn) as ga
	from `data-nationalslsdist-prd-986g`.postpaid.raw_daily_ga as a
	        where left(a.activation_date,6)=left('{dt_id}',6)
	    and a.activation_date <= '{dt_id}'
	    and lower(a.agent_type) not like '%outcall%' 
	    and a.nik_sales is not null and a.nik_sales <>'' and a.nik_sales <> '-'
	    and (lower(a.channel_rev) like '%gerai%' or lower(a.channel_rev) like '%franchise%')
	    and lower(a.order_type) in ('migration', 'new registration', 'port in migration')
	group by 1, 2, 3
) 
-- dly
select
	dt_id,
	'ga_postpaid' as kpi_name,
	'agent' as level, 
	agent_id, 
	store_code, 
	'IM3' as brand, 
	sum(ga) as value
from ga_base
	where left(dt_id,6)=left('{dt_id}',6)
		and dt_id<='{dt_id}'
group by 1, 2, 3, 4, 5, 6
union all
select
	dt_id,
	'ga_postpaid' as kpi_name,
	'store' as level, 
	cast(null as string) as agent_id, 
	store_code, 
	'IM3' as brand, 
	sum(ga) as value
from ga_base
	where left(dt_id,6)=left('{dt_id}',6)
		and dt_id<='{dt_id}'
group by 1, 2, 3, 4, 5, 6;