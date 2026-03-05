-- Delete temp KPI
delete from `data-nationalslsdist-prd-986g`.retail.raw_qmatic_visitor
	where dt_id between date(SUBSTR('{dt_id}',1,4) || '-' || SUBSTR('{dt_id}',5,2) || '-01') 
		and PARSE_DATE('%Y%m%d', '{dt_id}');

-- Insert temp KPI
insert into `data-nationalslsdist-prd-986g`.retail.raw_qmatic_visitor (dt_id, store_code, store_name, agent_id,
agent_name, brand, visitor)
select 
	DATE(DATETIME(a.dt_id, "Asia/Jakarta")) dt_id, 
	a.store_code, 
	a.store_name,
	-- a.agent_id,
	REGEXP_REPLACE(UPPER(a.agent_id), r"^MBPS(.*)", "MBPS-\\1") AS agent_id,
	a.agent_name,
	a.brand,
	-- count(distinct msisdn) as visitor
	count(distinct concat(ticket_id, coalesce(a.msisdn,''))) as visitor
from `data-nationalslsdist-prd-986g`.retail.raw_qmatic_customer_detail as a 
where DATE(DATETIME(a.dt_id, "Asia/Jakarta")) between date(SUBSTR('{dt_id}',1,4) || '-' || SUBSTR('{dt_id}',5,2) || '-01') 
		and PARSE_DATE('%Y%m%d', '{dt_id}')
group by 1, 2, 3, 4, 5, 6;

-- Update step 1 standard with nik and store code is same
update `data-nationalslsdist-prd-986g`.retail.raw_qmatic_visitor as x 
	set agent_nik_rev= y.agent_nik,
		store_code_rev=y.store_code
from (
	select 
		a.agent_id,
		b.agent_nik,
		b.store_code,
		a.dt_id
	from `data-nationalslsdist-prd-986g`.retail.raw_qmatic_visitor as a
		inner join (
		select
			id_norm,
			agent_nik,
			store_code,
			row_number() over(partition by upper(REGEXP_REPLACE(id_norm, r'[-,`!$%#]', '')) order by mth_id desc) as idx
		from `data-nationalslsdist-prd-986g`.retail.ref_agent_spv 
		unpivot(
			id_norm for cat_id in (
				agent_id,
				agent_cstool,
				agent_smartcare,
				agent_qmatic,
				agent_monthly_quiz,
				agent_ftth
			)
		)
		) as b 
			on upper(REGEXP_REPLACE(a.agent_id, r'[-,`!$%#]', ''))= upper(REGEXP_REPLACE(b.id_norm, r'[-,`!$%#]', ''))
				and a.store_code = b.store_code
	where b.idx=1
) as y
where upper(REGEXP_REPLACE(x.agent_id, r'[-,`!$%#]', '')) = upper(REGEXP_REPLACE(y.agent_id, r'[-,`!$%#]', ''))
	and x.dt_id=y.dt_id
	and x.store_code=y.store_code
	and format_date('%Y%m',x.dt_id)=left('{dt_id}',6)
;

-- Update step 2 with nik match only
update `data-nationalslsdist-prd-986g`.retail.raw_qmatic_visitor as x 
	set agent_nik_rev= y.agent_nik,
		store_code_rev=y.store_code
from (
	select 
		distinct
		a.agent_id,
		b.agent_nik,
		b.store_code,
		a.dt_id
	from `data-nationalslsdist-prd-986g`.retail.raw_qmatic_visitor as a
		inner join (
		select
			id_norm,
			agent_nik,
			store_code,
			row_number() over(partition by upper(REGEXP_REPLACE(id_norm, r'[-,`!$%#]', '')) order by mth_id desc) as idx
		from `data-nationalslsdist-prd-986g`.retail.ref_agent_spv 
		unpivot(
			id_norm for cat_id in (
				agent_id,
				agent_cstool,
				agent_smartcare,
				agent_qmatic,
				agent_monthly_quiz,
				agent_ftth
			)
		)
		) as b 
			on upper(REGEXP_REPLACE(a.agent_id, r'[-,`!$%#]', ''))= upper(REGEXP_REPLACE(b.id_norm, r'[-,`!$%#]', ''))
	where b.idx=1
) as y
where upper(REGEXP_REPLACE(x.agent_id, r'[-,`!$%#]', '')) = upper(REGEXP_REPLACE(y.agent_id, r'[-,`!$%#]', ''))
	and x.dt_id=y.dt_id
	and format_date('%Y%m',x.dt_id)=left('{dt_id}',6)
	and x.agent_nik_rev is null
;

-- Update step 3 match name and store code
update `data-nationalslsdist-prd-986g`.retail.raw_qmatic_visitor as x 
	set agent_nik_rev= y.agent_nik,
		store_code_rev=y.store_code
from (
	select 
		a.agent_id,
		a.agent_name,
		b.agent_nik,
		b.store_code,
		a.dt_id
	from `data-nationalslsdist-prd-986g`.retail.raw_qmatic_visitor as a
		inner join (
		select
			agent_name,
			agent_nik,
			store_code,
			row_number() over(partition by upper(REGEXP_REPLACE(agent_name, r'[-,`!$%#]', '')) order by mth_id desc) as idx
		from `data-nationalslsdist-prd-986g`.retail.ref_agent_spv 
		) as b 
			on upper(REGEXP_REPLACE(a.agent_name, r'[-,`!$%#]', ''))= upper(REGEXP_REPLACE(b.agent_name, r'[-,`!$%#]', ''))
				and a.store_code=b.store_code
	where b.idx=1
) as y
where upper(REGEXP_REPLACE(x.agent_name, r'[-,`!$%#]', '')) = upper(REGEXP_REPLACE(y.agent_name, r'[-,`!$%#]', ''))
	and upper(REGEXP_REPLACE(x.agent_id, r'[-,`!$%#]', '')) = upper(REGEXP_REPLACE(y.agent_id, r'[-,`!$%#]', ''))
	and x.store_code=y.store_code
	and x.dt_id=y.dt_id
	and format_date('%Y%m',x.dt_id)=left('{dt_id}',6)
	and x.agent_nik_rev is null
;

-- Update step 4 match name only
update `data-nationalslsdist-prd-986g`.retail.raw_qmatic_visitor as x 
	set agent_nik_rev= y.agent_nik,
		store_code_rev=y.store_code
from (
	select 
		distinct
		a.agent_id,
		a.agent_name,
		b.agent_nik,
		b.store_code,
		a.dt_id
	from `data-nationalslsdist-prd-986g`.retail.raw_qmatic_visitor as a
		inner join (
		select
			agent_name,
			agent_nik,
			store_code,
			row_number() over(partition by upper(REGEXP_REPLACE(agent_name, r'[-,`!$%#]', '')) order by mth_id desc) as idx
		from `data-nationalslsdist-prd-986g`.retail.ref_agent_spv 
		) as b 
			on upper(REGEXP_REPLACE(a.agent_name, r'[-,`!$%#]', ''))= upper(REGEXP_REPLACE(b.agent_name, r'[-,`!$%#]', ''))
	where b.idx=1
) as y
where upper(REGEXP_REPLACE(x.agent_name, r'[-,`!$%#]', '')) = upper(REGEXP_REPLACE(y.agent_name, r'[-,`!$%#]', ''))
	and upper(REGEXP_REPLACE(x.agent_id, r'[-,`!$%#]', '')) = upper(REGEXP_REPLACE(y.agent_id, r'[-,`!$%#]', ''))
	and x.dt_id=y.dt_id
	and format_date('%Y%m',x.dt_id)=left('{dt_id}',6)
	and x.agent_nik_rev is null
;

-- Update step 5 old
-- update `data-nationalslsdist-prd-986g`.retail.raw_qmatic_visitor as x 
-- 	set agent_nik_rev= y.agent_nik,
-- 		store_code_rev=y.store_code
-- from (
-- 	select * from (
-- select 
-- 	distinct
-- 		a.agent_id,
-- 		b.agent_nik,
-- 		b.store_code,
-- 		row_number() over(partition by a.agent_id, b.agent_nik 
-- 			order by case when a.store_code=b.store_code then 1 else 2 end asc, mth_id desc, b.store_code desc) as idx
-- 	from `data-nationalslsdist-prd-986g`.retail.raw_qmatic_visitor as a
-- 	-- inner join `data-nationalslsdist-prd-986g`.retail.ref_agent_store as b
-- 	inner join `data-nationalslsdist-prd-986g`.retail.ref_agent_spv as b
-- 			on upper(REGEXP_REPLACE(a.agent_id, r'[-,`!$%#]', ''))= upper(REGEXP_REPLACE(b.agent_nik, r'[-,`!$%#]', ''))
-- 				and a.store_code=b.store_code
-- 	) as x where x.idx=1
-- ) as y
-- where x.agent_id = y.agent_id
-- 	and x.agent_nik_rev is null
select 1;

-- Update step 6 old
-- update `data-nationalslsdist-prd-986g`.retail.raw_qmatic_visitor as x 
-- 	set agent_nik_rev= y.agent_nik,
-- 		store_code_rev=y.store_code
-- from (
-- 	select * from (
-- select 
-- 	distinct
-- 		a.agent_id,
-- 		b.spv_nik as agent_nik,
-- 		b.store_code,
-- 		row_number() over(partition by b.spv_nik 
-- 			order by case when a.store_code=b.store_code then 1 else 2 end asc, mth_id desc, b.store_code desc) as idx
-- 	from `data-nationalslsdist-prd-986g`.retail.raw_qmatic_visitor as a
-- 	-- inner join `data-nationalslsdist-prd-986g`.retail.ref_agent_store as b
-- 	inner join `data-nationalslsdist-prd-986g`.retail.ref_agent_spv as b
-- 			on upper(REGEXP_REPLACE(a.agent_id, r'[-,`!$%#]', ''))= upper(REGEXP_REPLACE(b.spv_nik, r'[-,`!$%#]', ''))
-- 				and a.store_code=b.store_code
-- 	) as x where x.idx=1
-- ) as y
-- where x.agent_id = y.agent_id
-- 	and x.agent_nik_rev is null
select 1;

-- Update step 7 
update `data-nationalslsdist-prd-986g`.retail.raw_qmatic_visitor as x 
	set agent_nik_rev= y.agent_nik,
		store_code_rev=y.store_code
from (
	select * from (
select 
	distinct
		a.agent_id,
		b.agent_nik,
		b.store_code,
		row_number() over(partition by a.agent_id, b.agent_nik 
			order by case when a.store_code=b.store_code then 1 else 2 end asc, b.store_code desc) as idx
	from `data-nationalslsdist-prd-986g`.retail.raw_qmatic_visitor as a
	inner join (
			select
				distinct
				id as agent_id,
				store_code,
				nik as agent_nik,
			from `data-nationalslsdist-prd-986g`.retail.ref_3id_agent_nik
	) as b
			on upper(REGEXP_REPLACE(a.agent_id, r'[-,`!$%#]', ''))= upper(REGEXP_REPLACE(b.agent_id, r'[-,`!$%#]', ''))
				and a.store_code=b.store_code
	) as x where x.idx=1
) as y
where x.agent_id = y.agent_id
	and x.agent_nik_rev is null
;

-- Update step 8
update `data-nationalslsdist-prd-986g`.retail.raw_qmatic_visitor as x 
	set agent_nik_rev= y.agent_nik,
		store_code_rev=y.store_code
from (
	select * from (
select 
	distinct
		a.agent_id,
		b.agent_nik,
		b.store_code,
		row_number() over(partition by a.agent_id, b.agent_nik 
			order by case when a.store_code=b.store_code then 1 else 2 end asc, b.store_code desc) as idx
	from `data-nationalslsdist-prd-986g`.retail.raw_qmatic_visitor as a
	inner join (
			select
				distinct
				id as agent_id,
				store_code,
				nik as agent_nik,
			from `data-nationalslsdist-prd-986g`.retail.ref_3id_agent_nik
	) as b
			on upper(REGEXP_REPLACE(a.agent_id, r'[-,`!$%#]', ''))= upper(REGEXP_REPLACE(b.agent_nik, r'[-,`!$%#]', ''))
				and a.store_code=b.store_code
	) as x where x.idx=1
) as y
where x.agent_id = y.agent_id
	and x.agent_nik_rev is null
;

-- Update step 9
update `data-nationalslsdist-prd-986g`.retail.raw_qmatic_visitor as x 
	set agent_nik_rev= y.agent_nik,
		store_code_rev=y.store_code
from (
	select * from (
select 
	distinct
		a.agent_id,
		b.agent_nik,
		b.store_code,
		row_number() over(partition by a.agent_id, b.agent_nik 
			order by case when a.store_code=b.store_code then 1 else 2 end asc, b.store_code desc) as idx
	from `data-nationalslsdist-prd-986g`.retail.raw_qmatic_visitor as a
	inner join (
			select
				distinct
				name as agent_name,
				store_code,
				nik as agent_nik
			from `data-nationalslsdist-prd-986g`.retail.ref_3id_agent_nik
	) as b
			on upper(a.agent_name)= upper(b.agent_name)
				and a.store_code=b.store_code
	) as x where x.idx=1
) as y
where x.agent_id = y.agent_id
	and x.agent_nik_rev is null
;

-- mtd KPI 
select
	'{dt_id}' as dt_id,
	'traffic_qmatic' as kpi_name,
	'agent' as level, 
	-- case when left(agent_id,5)='MBPS-' then upper(agent_id)
	-- 	else coalesce(upper(agent_nik_rev), upper(agent_id)) end as agent_id, 
	coalesce(upper(agent_nik_rev), upper(agent_id)) as agent_id,
	coalesce(store_code_rev, store_code) as store_code, 
    brand, 
	sum(visitor) as value
from `data-nationalslsdist-prd-986g`.retail.raw_qmatic_visitor
	where format_date('%Y%m', dt_id)=left('{dt_id}',6)
		and format_date('%Y%m%d', dt_id)<='{dt_id}'
group by 1, 2, 3, 4, 5, 6
union all
select
	'{dt_id}' as dt_id,
	'traffic_qmatic' as kpi_name,
	'store' as level, 
	cast(null as string) as agent_id, 
	coalesce(store_code_rev, store_code) as store_code, 
    brand, 
	sum(visitor) as value
from `data-nationalslsdist-prd-986g`.retail.raw_qmatic_visitor
	where format_date('%Y%m', dt_id)=left('{dt_id}',6)
		and format_date('%Y%m%d', dt_id)<='{dt_id}'
group by 1, 2, 3, 4, 5, 6;

-- dly kpi
select
	format_date('%Y%m%d', dt_id) as dt_id,
	'traffic_qmatic' as kpi_name,
	'agent' as level, 
	coalesce(upper(agent_nik_rev), upper(agent_id)) as agent_id,
	coalesce(store_code_rev, store_code) as store_code, 
    brand, 
	sum(visitor) as value
from `data-nationalslsdist-prd-986g`.retail.raw_qmatic_visitor
	where format_date('%Y%m', dt_id)=left('{dt_id}',6)
		and format_date('%Y%m%d', dt_id)<='{dt_id}'
group by all
union all
select
	format_date('%Y%m%d', dt_id) as dt_id,
	'traffic_qmatic' as kpi_name,
	'store' as level, 
	cast(null as string) as agent_id, 
	coalesce(store_code_rev, store_code) as store_code, 
    brand, 
	sum(visitor) as value
from `data-nationalslsdist-prd-986g`.retail.raw_qmatic_visitor
	where format_date('%Y%m', dt_id)=left('{dt_id}',6)
		and format_date('%Y%m%d', dt_id)<='{dt_id}'
group by all;