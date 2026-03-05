-- mtd agent
select
	'{dt_id}' as dt_id,
	'csat_delivered' as kpi_name,
	'agent' as level, 
	upper(agent_id) agent_id, 
	store_code, 
	'IM3' as brand, 
	sum(delivered) as value
from `data-nationalslsdist-prd-986g`.retail.raw_im3_csat
	where 1=1
		and left(dt_id,6)=left('{dt_id}',6)
		and dt_id<='{dt_id}'
group by 1, 2, 3, 4, 5, 6
union all
select
	'{dt_id}' as dt_id,
	'csat_respond' as kpi_name,
	'agent' as level, 
	upper(agent_id) agent_id, 
	store_code, 
	'IM3' as brand, 
	sum(respond) as value
from `data-nationalslsdist-prd-986g`.retail.raw_im3_csat
	where 1=1
		and left(dt_id,6)=left('{dt_id}',6)
		and dt_id<='{dt_id}'
group by 1, 2, 3, 4, 5, 6
union all
select
	'{dt_id}' as dt_id,
	'csat_happy' as kpi_name,
	'agent' as level, 
	upper(agent_id) agent_id, 
	store_code, 
	'IM3' as brand, 
	sum(happy) as value
from `data-nationalslsdist-prd-986g`.retail.raw_im3_csat
	where 1=1
		and left(dt_id,6)=left('{dt_id}',6)
		and dt_id<='{dt_id}'
group by 1, 2, 3, 4, 5, 6
union all
select
	'{dt_id}' as dt_id,
	'csat_respond_rate' as kpi_name,
	'agent' as level, 
	upper(agent_id) agent_id, 
	store_code, 
	'IM3' as brand, 
	SAFE_DIVIDE(sum(respond),sum(delivered)) as value
from `data-nationalslsdist-prd-986g`.retail.raw_im3_csat
	where 1=1
		and left(dt_id,6)=left('{dt_id}',6)
		and dt_id<='{dt_id}'
group by 1, 2, 3, 4, 5, 6
union all
select
	'{dt_id}' as dt_id,
	'csat_score' as kpi_name,
	'agent' as level, 
	upper(agent_id) agent_id, 
	store_code, 
	'IM3' as brand, 
	SAFE_DIVIDE(sum(happy),sum(respond)) as value
from `data-nationalslsdist-prd-986g`.retail.raw_im3_csat
	where 1=1
		and left(dt_id,6)=left('{dt_id}',6)
		and dt_id<='{dt_id}'
group by 1, 2, 3, 4, 5, 6
union all
-- mtd store
select
	'{dt_id}' as dt_id,
	'csat_delivered' as kpi_name,
	'store' as level, 
	cast(null as string) as agent_id, 
	store_code, 
	'IM3' as brand, 
	sum(delivered) as value
from `data-nationalslsdist-prd-986g`.retail.raw_im3_csat
	where 1=1
		and left(dt_id,6)=left('{dt_id}',6)
		and dt_id<='{dt_id}'
group by 1, 2, 3, 4, 5, 6
union all
select
	'{dt_id}' as dt_id,
	'csat_respond' as kpi_name,
	'store' as level, 
	cast(null as string) as agent_id, 
	store_code, 
	'IM3' as brand, 
	sum(respond) as value
from `data-nationalslsdist-prd-986g`.retail.raw_im3_csat
	where 1=1
		and left(dt_id,6)=left('{dt_id}',6)
		and dt_id<='{dt_id}'
group by 1, 2, 3, 4, 5, 6
union all
select
	'{dt_id}' as dt_id,
	'csat_happy' as kpi_name,
	'store' as level, 
	cast(null as string) as agent_id, 
	store_code, 
	'IM3' as brand, 
	sum(happy) as value
from `data-nationalslsdist-prd-986g`.retail.raw_im3_csat
	where 1=1
		and left(dt_id,6)=left('{dt_id}',6)
		and dt_id<='{dt_id}'
group by 1, 2, 3, 4, 5, 6
union all
select
	'{dt_id}' as dt_id,
	'csat_respond_rate' as kpi_name,
	'store' as level, 
	cast(null as string) as agent_id, 
	store_code, 
	'IM3' as brand, 
	SAFE_DIVIDE(sum(respond),sum(delivered)) as value
from `data-nationalslsdist-prd-986g`.retail.raw_im3_csat
	where 1=1
		and left(dt_id,6)=left('{dt_id}',6)
		and dt_id<='{dt_id}'
group by 1, 2, 3, 4, 5, 6
union all
select
	'{dt_id}' as dt_id,
	'csat_score' as kpi_name,
	'store' as level, 
	cast(null as string) as agent_id, 
	store_code, 
	'IM3' as brand, 
	SAFE_DIVIDE(sum(happy),sum(respond)) as value
from `data-nationalslsdist-prd-986g`.retail.raw_im3_csat
	where 1=1
		and left(dt_id,6)=left('{dt_id}',6)
		and dt_id<='{dt_id}'
group by 1, 2, 3, 4, 5, 6;