delete from `data-bi-prd-935c.bi_snd.rtl_raw_master_kpi_mtd`
	where kpi_name in ('conversion_rate', 'conversion_rate_all')
		and brand='3ID'
		and dt_id='{dt_id}';

insert into `data-bi-prd-935c.bi_snd.rtl_raw_master_kpi_mtd`
select 
	'{dt_id}' as dt_id,
 	'conversion_rate_all' as kpi_name,
 	'agent' as level,
 	coalesce(a.agent_id, b.agent_id) as agent_id,
 	coalesce(a.store_code, b.store_code) as store_code,
 	'3ID' as brand,
-- 	sum(coalesce(a.value, 0)) as visitor,
-- 	sum(coalesce(b.value,0)) as ga,
 	coalesce(safe_divide(sum(coalesce(b.value, 0)), sum(coalesce(a.value,0))),1) as value, 
 	CURRENT_TIMESTAMP() as insert_dt,
	current_date() as prt_dt
from(
		select *
		from `data-bi-prd-935c.bi_snd.rtl_raw_master_kpi_mtd` 
		where kpi_name in ('traffic_visitor', 'traffic_visitor_dvm')
			and level='agent'
			and brand='3ID' 
			and dt_id='{dt_id}'
	)as a
	-- full outer join
	left join
	(
		select *
		from `data-bi-prd-935c.bi_snd.rtl_raw_master_kpi_mtd` 
		where kpi_name in ('ga_prepaid', 'ga_prepaid_dvm')
			and level='agent'
			and brand='3ID' 
			and dt_id='{dt_id}'
	)as b
		on a.agent_id=b.agent_id 
			and a.store_code=b.store_code
group by all
union all 
select 
	'{dt_id}' as dt_id,
 	'conversion_rate' as kpi_name,
 	'agent' as level,
 	coalesce(a.agent_id, b.agent_id) as agent_id,
 	coalesce(a.store_code, b.store_code) as store_code,
 	'3ID' as brand,
-- 	sum(coalesce(a.value, 0)) as visitor,
-- 	sum(coalesce(b.value,0)) as ga,
 	coalesce(safe_divide(sum(coalesce(b.value, 0)), sum(coalesce(a.value,0))),1) as value, 
 	CURRENT_TIMESTAMP() as insert_dt,
	current_date() as prt_dt
from(
		select *
		from `data-bi-prd-935c.bi_snd.rtl_raw_master_kpi_mtd` 
		where kpi_name in ('traffic_visitor')
			and level='agent'
			and brand='3ID' 
			and dt_id='{dt_id}'
	)as a
	-- full outer join
	left join 
	(
		select *
		from `data-bi-prd-935c.bi_snd.rtl_raw_master_kpi_mtd` 
		where kpi_name in ('ga_prepaid')
			and level='agent'
			and brand='3ID' 
			and dt_id='{dt_id}'
	)as b
		on a.agent_id=b.agent_id 
			and a.store_code=b.store_code
group by all
union all
select 
	'{dt_id}' as dt_id,
 	'conversion_rate_all' as kpi_name,
 	'store' as level,
 	cast(null as string) as agent_id,
 	coalesce(a.store_code, b.store_code) as store_code,
 	'3ID' as brand,
-- 	sum(coalesce(a.value, 0)) as visitor,
-- 	sum(coalesce(b.value,0)) as ga,
 	coalesce(safe_divide(sum(coalesce(b.value, 0)), sum(coalesce(a.value,0))),1) as value, 
 	CURRENT_TIMESTAMP() as insert_dt,
	current_date() as prt_dt
from(
		select *
		from `data-bi-prd-935c.bi_snd.rtl_raw_master_kpi_mtd` 
		where kpi_name in ('traffic_visitor', 'traffic_visitor_dvm')
			and level in ('dvm_store', 'store')
			and brand='3ID' 
			and dt_id='{dt_id}'
	)as a
	-- full outer join
	left join 
	(
		select *
		from `data-bi-prd-935c.bi_snd.rtl_raw_master_kpi_mtd` 
		where kpi_name in ('ga_prepaid', 'ga_prepaid_dvm')
			and level in ('dvm_store', 'store')
			and brand='3ID' 
			and dt_id='{dt_id}'
	)as b
		on a.store_code=b.store_code
group by all
union all 
select 
	'{dt_id}' as dt_id,
 	'conversion_rate' as kpi_name,
 	'store' as level,
 	cast(null as string) as agent_id,
 	coalesce(a.store_code, b.store_code) as store_code,
 	'3ID' as brand,
-- 	sum(coalesce(a.value, 0)) as visitor,
-- 	sum(coalesce(b.value,0)) as ga,
 	coalesce(safe_divide(sum(coalesce(b.value, 0)), sum(coalesce(a.value,0))),1) as value, 
 	CURRENT_TIMESTAMP() as insert_dt,
	current_date() as prt_dt
from(
		select *
		from `data-bi-prd-935c.bi_snd.rtl_raw_master_kpi_mtd` 
		where kpi_name in ('traffic_visitor')
			and level in ('dvm_store', 'store')
			and brand='3ID' 
			and dt_id='{dt_id}'
	)as a
	-- full outer join
	left join
	(
		select *
		from `data-bi-prd-935c.bi_snd.rtl_raw_master_kpi_mtd` 
		where kpi_name in ('ga_prepaid')
			and level in ('dvm_store', 'store')
			and brand='3ID' 
			and dt_id='{dt_id}'
	)as b
		on a.store_code=b.store_code
group by all
;



-- select 
-- 	'{dt_id}' as dt_id,
--  	'conversion_rate_all' as kpi_name,
--  	'agent' as level,
--  	coalesce(a.agent_id, b.agent_id) as agent_id,
--  	coalesce(a.store_code, b.store_code) as store_code,
--  	'3ID' as brand,
-- -- 	sum(a.value) as visitor,
-- -- 	sum(b.value) as ga,
--  	safe_divide(sum(b.value), sum(a.value)) as value, 
--  	CURRENT_TIMESTAMP() as insert_dt,
-- 	current_date() as prt_dt
-- from `data-bi-prd-935c.bi_snd.rtl_raw_master_kpi_mtd` as a
-- 	full outer join `data-bi-prd-935c.bi_snd.rtl_raw_master_kpi_mtd` as b
-- 		on a.dt_id=b.dt_id and a.agent_id=b.agent_id 
-- 			and a.store_code=b.store_code and a.brand=b.brand
-- where a.kpi_name in ('traffic_visitor', 'traffic_visitor_dvm') 
-- 	and b.kpi_name in ('ga_prepaid', 'ga_prepaid_dvm')
-- 	and a.level='agent'
-- 	and b.level='agent'
-- 	and a.brand='3ID' 
-- 	and a.dt_id='{dt_id}'
-- group by 1, 2, 3, 4, 5, 6, 8, 9
-- union all  
-- select 
-- 	'{dt_id}' as dt_id,
--  	'conversion_rate' as kpi_name,
--  	'agent' as level,
--  	coalesce(a.agent_id, b.agent_id) as agent_id,
--  	coalesce(a.store_code, b.store_code) as store_code,
--  	'3ID' as brand,
-- -- 	sum(a.value) as visitor,
-- -- 	sum(b.value) as ga,
--  	safe_divide(sum(b.value), sum(a.value)) as value, 
--  	CURRENT_TIMESTAMP() as insert_dt,
-- 	current_date() as prt_dt
-- from `data-bi-prd-935c.bi_snd.rtl_raw_master_kpi_mtd` as a
-- 	full outer join `data-bi-prd-935c.bi_snd.rtl_raw_master_kpi_mtd` as b
-- 		on a.dt_id=b.dt_id and a.agent_id=b.agent_id 
-- 			and a.store_code=b.store_code and a.brand=b.brand
-- where a.kpi_name in ('traffic_visitor') 
-- 	and b.kpi_name in ('ga_prepaid')
-- 	and a.level='agent'
-- 	and b.level='agent'
-- 	and a.brand='3ID' 
-- 	and a.dt_id='{dt_id}'
-- group by 1, 2, 3, 4, 5, 6, 8, 9
-- union all
-- select 
-- 	'{dt_id}' as dt_id,
--  	'conversion_rate_all' as kpi_name,
--  	'store' as level,
--  	cast(null as string) as agent_id,
--  	coalesce(a.store_code, b.store_code) as store_code,
--  	'3ID' as brand,
-- -- 	sum(a.value) as visitor,
-- -- 	sum(b.value) as ga,
--  	safe_divide(sum(b.value), sum(a.value)) as value, 
--  	CURRENT_TIMESTAMP() as insert_dt,
-- 	current_date() as prt_dt
-- from `data-bi-prd-935c.bi_snd.rtl_raw_master_kpi_mtd` as a
-- 	full outer join `data-bi-prd-935c.bi_snd.rtl_raw_master_kpi_mtd` as b
-- 		on a.dt_id=b.dt_id 
-- 			and a.store_code=b.store_code and a.brand=b.brand
-- where a.kpi_name in ('traffic_visitor', 'traffic_visitor_dvm') 
-- 	and b.kpi_name in ('ga_prepaid', 'ga_prepaid_dvm')
-- 	and a.level in ('dvm_store', 'store')
-- 	and b.level in ('dvm_store', 'store')
-- 	and a.brand='3ID' 
-- 	and a.dt_id='{dt_id}'
-- group by 1, 2, 3, 4, 5, 6, 8, 9
-- union all  
-- select 
-- 	'{dt_id}' as dt_id,
--  	'conversion_rate' as kpi_name,
--  	'store' as level,
--  	cast(null as string) as agent_id,
--  	coalesce(a.store_code, b.store_code) as store_code,
--  	'3ID' as brand,
-- -- 	sum(a.value) as visitor,
-- -- 	sum(b.value) as ga,
--  	safe_divide(sum(b.value), sum(a.value)) as value, 
--  	CURRENT_TIMESTAMP() as insert_dt,
-- 	current_date() as prt_dt
-- from `data-bi-prd-935c.bi_snd.rtl_raw_master_kpi_mtd` as a
-- 	full outer join `data-bi-prd-935c.bi_snd.rtl_raw_master_kpi_mtd` as b
-- 		on a.dt_id=b.dt_id 
-- 			and a.store_code=b.store_code and a.brand=b.brand
-- where a.kpi_name in ('traffic_visitor') 
-- 	and b.kpi_name in ('ga_prepaid')
-- 	and a.level in ('dvm_store', 'store')
-- 	and b.level in ('dvm_store', 'store')
-- 	and a.brand='3ID' 
-- 	and a.dt_id='{dt_id}'
-- group by 1, 2, 3, 4, 5, 6, 8, 9
-- ;