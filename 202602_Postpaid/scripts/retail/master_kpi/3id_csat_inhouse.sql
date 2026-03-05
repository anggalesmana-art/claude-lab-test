select 
	cs.dt_id as dt_id, 
	'CSTOOLS' as source_data,
	cs.agent_id, 
	cs.store_code, 
	count(1) as csat_delivered,
	sum(case when answer is not null then 1 else 0 end) as csat_respond,
	sum(case when answer >= 4 then 1 else 0 end) as csat_happy
from (
	select
		DATE_FORMAT(cs.survey_open_date, '%Y%m') as mth_id, 
		DATE_FORMAT(cs.survey_open_date, '%Y%m%d') as dt_id,
		cs.survey_ref_no,
		-- case when ma.nik is not null then upper(ma.nik)
	    -- 	when left(upper(cs.created_by),4)='MBPS' then UPPER(CONCAT('MBPS-', SUBSTRING(TRIM(REPLACE(REPLACE(cs.created_by, '-', ''), '_', '')), 5)))
	    -- 	when left(upper(cs.created_by),4)='MPBS' then UPPER(CONCAT('MBPS-', SUBSTRING(TRIM(REPLACE(REPLACE(cs.created_by, '-', ''), '_', '')), 5)))
	    -- 	else upper(cs.created_by) end as agent_id,
		cs.created_by as agent_id, 			
	    -- coalesce(ma.store_code ,cs.survey_dealercode, SUBSTRING_INDEX(cs.created_by, '-', 1)) as store_code,
		coalesce(cs.survey_dealercode, SUBSTRING_INDEX(cs.created_by, '-', 1)) as store_code,
		-- coalesce(ma.dealercode ,cs.survey_dealercode, SUBSTRING_INDEX(cs.created_by, '-', 1)) as store_code, 
		avg(sa.answer) answer
	FROM cockpit.csat_survey cs
		left join cockpit.survey_answer sa 
			on sa.reff_no = cs.survey_ref_no and question_id in (23, 24, 25, 36) 
		-- left join cockpit.mapping_agent_nik as ma
		-- 	on case when left(upper(cs.created_by),4)='MPBS' then UPPER(CONCAT('MBPS', SUBSTRING(TRIM(REPLACE(REPLACE(cs.created_by, '-', ''), '_', '')), 5)))
        -- else upper(TRIM(REPLACE(REPLACE(cs.created_by, '-', ''), '_', ''))) end = upper(ma.idx)
	where 1=1
		and DATE_FORMAT(cs.survey_open_date, '%Y%m') = left('{dt_id}', 6)
		and DATE_FORMAT(cs.survey_open_date, '%Y%m%d') <= '{dt_id}'
		and cs.msgStatusText='Delivered' 
		-- and cs.survey_source <> '3Kiosk'
	group by 1, 2, 3, 4, 5
) as cs  
where cs.dt_id<'20251209'
group by 1, 2, 3, 4;

delete from `data-bi-prd-935c.bi_snd.rtl_raw_master_kpi_mtd`
	where kpi_name in (
		'csat_score',
		'csat_happy',
		'csat_respond_rate',
		'csat_respond',
		'csat_delivered'
		)
		and brand='3ID'
		and dt_id='{dt_id}';

insert into `data-bi-prd-935c.bi_snd.rtl_raw_master_kpi_mtd`
with kpi_csat as (
	select 
--	a.*,
	a.dt_id, a.source_data, a.store_code, a.csat_delivered, a.csat_respond, a.csat_happy, 
		case when b.agent_nik is not null then upper(b.agent_nik)
			when left(upper(a.agent_id),5)='MBPS3' then concat('MBPS-3', upper(substring(a.agent_id,6,length(a.agent_id))))
			when left(upper(a.agent_id),5)='MPBS3' then concat('MBPS-3', upper(substring(a.agent_id,6,length(a.agent_id)))) 
			when c.agent_nik is not null then upper(c.agent_nik)
			when split(a.agent_id,'-')[OFFSET(0)]=a.store_code and upper(split(a.agent_id,'-')[SAFE_OFFSET(1)]) is not null then upper(split(a.agent_id,'-')[SAFE_OFFSET(1)])
			else upper(a.agent_id)
		end as agent_id
	from `data-nationalslsdist-prd-986g`.retail.raw_3id_csat as a 
	left join (
				select 
					distinct
					upper(regexp_replace(agent_id, r'[-_#\s]+', '')) id, 
					agent_nik,
					store_code
				from `data-nationalslsdist-prd-986g`.retail.ref_agent_spv 
					where brand='3ID'
						and agent_id is not null 
						and mth_id = (select max(mth_id) from `data-nationalslsdist-prd-986g`.retail.ref_agent_spv)
			) as b on upper(regexp_replace(a.agent_id, r'[-_#\s]+', ''))=b.id and a.store_code=b.store_code
	left join (
				select 
					distinct
					upper(regexp_replace(spv_id, r'[-_#\s]+', '')) id, 
					spv_nik as agent_nik,
					store_code
				from `data-nationalslsdist-prd-986g`.retail.ref_agent_spv 
					where brand='3ID'
						and agent_id is not null 
						and mth_id = (select max(mth_id) from `data-nationalslsdist-prd-986g`.retail.ref_agent_spv)
			) as c on upper(regexp_replace(a.agent_id, r'[-_#\s]+', ''))=c.id and a.store_code=c.store_code
		where date(dt_id) between date_trunc(parse_date('%Y%m%d', '{dt_id}'), month)
			and parse_date('%Y%m%d', '{dt_id}')
	group by all
)
select
	'{dt_id}' as dt_id,
	'csat_delivered' as kpi_name,
	'agent' as level, 
	agent_id, 
	store_code, 
	'3ID' as brand, 
	sum(csat_delivered) as value, 
 	CURRENT_TIMESTAMP() as insert_dt,
	current_date() as prt_dt
from kpi_csat	
group by all
union all
select
	'{dt_id}' as dt_id,
	'csat_respond' as kpi_name,
	'agent' as level, 
	agent_id, 
	store_code, 
	'3ID' as brand, 
	sum(csat_respond) as value, 
 	CURRENT_TIMESTAMP() as insert_dt,
	current_date() as prt_dt
from kpi_csat	
group by all
union all
select
	'{dt_id}' as dt_id,
	'csat_happy' as kpi_name,
	'agent' as level, 
	agent_id, 
	store_code, 
	'3ID' as brand, 
	sum(csat_happy) as value, 
 	CURRENT_TIMESTAMP() as insert_dt,
	current_date() as prt_dt
from kpi_csat	
group by all
union all
select
	'{dt_id}' as dt_id,
	'csat_respond_rate' as kpi_name,
	'agent' as level, 
	agent_id, 
	store_code, 
	'3ID' as brand, 
	safe_divide(sum(csat_respond),sum(csat_delivered)) as value, 
 	CURRENT_TIMESTAMP() as insert_dt,
	current_date() as prt_dt
from kpi_csat	
group by all
union all
select
	'{dt_id}' as dt_id,
	'csat_score' as kpi_name,
	'agent' as level, 
	agent_id, 
	store_code, 
	'3ID' as brand, 
	safe_divide(sum(csat_happy),sum(csat_respond)) as value, 
 	CURRENT_TIMESTAMP() as insert_dt,
	current_date() as prt_dt
from kpi_csat	
group by all
union all
-- mtd store
select
	'{dt_id}' as dt_id,
	'csat_delivered' as kpi_name,
	'store' as level, 
	null as agent_id, 
	store_code, 
	'3ID' as brand, 
	sum(csat_delivered) as value, 
 	CURRENT_TIMESTAMP() as insert_dt,
	current_date() as prt_dt
from kpi_csat	
group by all
union all
select
	'{dt_id}' as dt_id,
	'csat_respond' as kpi_name,
	'store' as level, 
	null as agent_id, 
	store_code, 
	'3ID' as brand, 
	sum(csat_respond) as value, 
 	CURRENT_TIMESTAMP() as insert_dt,
	current_date() as prt_dt
from kpi_csat	
group by all
union all
select
	'{dt_id}' as dt_id,
	'csat_happy' as kpi_name,
	'store' as level, 
	null as agent_id, 
	store_code, 
	'3ID' as brand, 
	sum(csat_happy) as value, 
 	CURRENT_TIMESTAMP() as insert_dt,
	current_date() as prt_dt
from kpi_csat	
group by all
union all
select
	'{dt_id}' as dt_id,
	'csat_respond_rate' as kpi_name,
	'store' as level, 
	null as agent_id, 
	store_code, 
	'3ID' as brand, 
	safe_divide(sum(csat_respond),sum(csat_delivered)) as value, 
 	CURRENT_TIMESTAMP() as insert_dt,
	current_date() as prt_dt
from kpi_csat	
group by all
union all
select
	'{dt_id}' as dt_id,
	'csat_score' as kpi_name,
	'store' as level, 
	null as agent_id, 
	store_code, 
	'3ID' as brand, 
	safe_divide(sum(csat_happy),sum(csat_respond)) as value, 
 	CURRENT_TIMESTAMP() as insert_dt,
	current_date() as prt_dt
from kpi_csat
group by all
;

-- -- CSAT Inhouse
-- drop table if exists cockpit.tmp_kpi_csat; 

-- create table cockpit.tmp_kpi_csat as
-- select 
-- 	cs.mth_id, 
-- 	cs.dt_id as dt_id, 
-- 	cs.agent_id, 
-- 	cs.store_code, 
-- 	count(1) as csat_delivered,
-- 	sum(case when answer is not null then 1 else 0 end) as csat_respond,
-- 	sum(case when answer >= 4 then 1 else 0 end) as csat_happy
-- -- 	cast(sum(case when answer >= 4 then 1 else 0 end)/sum(case when answer is not null then 1 else 0 end) as decimal(10,2)) as csat_score, 
-- -- 	cast(sum(case when answer is not null then 1 else 0 end)/count(1) as decimal(10,2)) as csat_respond_rate
-- from (
-- 	select
-- 		DATE_FORMAT(cs.survey_open_date, '%Y%m') as mth_id, 
-- 		DATE_FORMAT(cs.survey_open_date, '%Y%m%d') as dt_id,
-- 		cs.survey_ref_no,
-- 		case when ma.nik is not null then upper(ma.nik)
-- 	    	when left(upper(cs.created_by),4)='MBPS' then UPPER(CONCAT('MBPS-', SUBSTRING(TRIM(REPLACE(REPLACE(cs.created_by, '-', ''), '_', '')), 5)))
-- 	    	when left(upper(cs.created_by),4)='MPBS' then UPPER(CONCAT('MBPS-', SUBSTRING(TRIM(REPLACE(REPLACE(cs.created_by, '-', ''), '_', '')), 5)))
-- 	    	else upper(cs.created_by) end as agent_id,
-- 		-- cs.created_by as agent_id, 			
-- 	    coalesce(ma.store_code ,cs.survey_dealercode, SUBSTRING_INDEX(cs.created_by, '-', 1)) as store_code,
-- 		-- coalesce(ma.dealercode ,cs.survey_dealercode, SUBSTRING_INDEX(cs.created_by, '-', 1)) as store_code, 
-- 		avg(sa.answer) answer
-- 	FROM cockpit.csat_survey cs
-- 		left join cockpit.survey_answer sa 
-- 			on sa.reff_no = cs.survey_ref_no and question_id in (23, 24, 25, 36) 
-- 		left join cockpit.mapping_agent_nik as ma
-- 			on case when left(upper(cs.created_by),4)='MPBS' then UPPER(CONCAT('MBPS', SUBSTRING(TRIM(REPLACE(REPLACE(cs.created_by, '-', ''), '_', '')), 5)))
--         else upper(TRIM(REPLACE(REPLACE(cs.created_by, '-', ''), '_', ''))) end = upper(ma.idx)
-- 	where 1=1
-- 		and DATE_FORMAT(cs.survey_open_date, '%Y%m') = left('{dt_id}', 6)
-- 		and DATE_FORMAT(cs.survey_open_date, '%Y%m%d') <= '{dt_id}'
-- 		and cs.msgStatusText='Delivered' 
-- 		-- and cs.survey_source <> '3Kiosk'
-- 	group by 1, 2, 3, 4, 5
-- ) as cs 
-- group by 1, 2, 3, 4;

-- -- mtd agent
-- select
-- 	'{dt_id}' as dt_id,
-- 	'csat_delivered' as kpi_name,
-- 	'agent' as level, 
-- 	agent_id, 
-- 	store_code, 
-- 	'3ID' as brand, 
-- 	sum(csat_delivered) as value
-- from cockpit.tmp_kpi_csat
-- 	where 1=1
-- 		and left(dt_id,6)=left('{dt_id}',6)
-- 		and dt_id<='{dt_id}'
-- group by 1, 2, 3, 4, 5, 6
-- union all
-- select
-- 	'{dt_id}' as dt_id,
-- 	'csat_respond' as kpi_name,
-- 	'agent' as level, 
-- 	agent_id, 
-- 	store_code, 
-- 	'3ID' as brand, 
-- 	sum(csat_respond) as value
-- from cockpit.tmp_kpi_csat
-- 	where 1=1
-- 		and left(dt_id,6)=left('{dt_id}',6)
-- 		and dt_id<='{dt_id}'
-- group by 1, 2, 3, 4, 5, 6
-- union all
-- select
-- 	'{dt_id}' as dt_id,
-- 	'csat_happy' as kpi_name,
-- 	'agent' as level, 
-- 	agent_id, 
-- 	store_code, 
-- 	'3ID' as brand, 
-- 	sum(csat_happy) as value
-- from cockpit.tmp_kpi_csat
-- 	where 1=1
-- 		and left(dt_id,6)=left('{dt_id}',6)
-- 		and dt_id<='{dt_id}'
-- group by 1, 2, 3, 4, 5, 6
-- union all
-- select
-- 	'{dt_id}' as dt_id,
-- 	'csat_respond_rate' as kpi_name,
-- 	'agent' as level, 
-- 	agent_id, 
-- 	store_code, 
-- 	'3ID' as brand, 
-- 	sum(csat_respond)/sum(csat_delivered) as value
-- from cockpit.tmp_kpi_csat
-- 	where 1=1
-- 		and left(dt_id,6)=left('{dt_id}',6)
-- 		and dt_id<='{dt_id}'
-- group by 1, 2, 3, 4, 5, 6
-- union all
-- select
-- 	'{dt_id}' as dt_id,
-- 	'csat_score' as kpi_name,
-- 	'agent' as level, 
-- 	agent_id, 
-- 	store_code, 
-- 	'3ID' as brand, 
-- 	sum(csat_happy)/sum(csat_respond) as value
-- from cockpit.tmp_kpi_csat
-- 	where 1=1
-- 		and left(dt_id,6)=left('{dt_id}',6)
-- 		and dt_id<='{dt_id}'
-- group by 1, 2, 3, 4, 5, 6
-- union all
-- -- mtd store
-- select
-- 	'{dt_id}' as dt_id,
-- 	'csat_delivered' as kpi_name,
-- 	'store' as level, 
-- 	null as agent_id, 
-- 	store_code, 
-- 	'3ID' as brand, 
-- 	sum(csat_delivered) as value
-- from cockpit.tmp_kpi_csat
-- 	where 1=1
-- 		and left(dt_id,6)=left('{dt_id}',6)
-- 		and dt_id<='{dt_id}'
-- group by 1, 2, 3, 4, 5, 6
-- union all
-- select
-- 	'{dt_id}' as dt_id,
-- 	'csat_respond' as kpi_name,
-- 	'store' as level, 
-- 	null as agent_id, 
-- 	store_code, 
-- 	'3ID' as brand, 
-- 	sum(csat_respond) as value
-- from cockpit.tmp_kpi_csat
-- 	where 1=1
-- 		and left(dt_id,6)=left('{dt_id}',6)
-- 		and dt_id<='{dt_id}'
-- group by 1, 2, 3, 4, 5, 6
-- union all
-- select
-- 	'{dt_id}' as dt_id,
-- 	'csat_happy' as kpi_name,
-- 	'store' as level, 
-- 	null as agent_id, 
-- 	store_code, 
-- 	'3ID' as brand, 
-- 	sum(csat_happy) as value
-- from cockpit.tmp_kpi_csat
-- 	where 1=1
-- 		and left(dt_id,6)=left('{dt_id}',6)
-- 		and dt_id<='{dt_id}'
-- group by 1, 2, 3, 4, 5, 6
-- union all
-- select
-- 	'{dt_id}' as dt_id,
-- 	'csat_respond_rate' as kpi_name,
-- 	'store' as level, 
-- 	null as agent_id, 
-- 	store_code, 
-- 	'3ID' as brand, 
-- 	sum(csat_respond)/sum(csat_delivered) as value
-- from cockpit.tmp_kpi_csat
-- 	where 1=1
-- 		and left(dt_id,6)=left('{dt_id}',6)
-- 		and dt_id<='{dt_id}'
-- group by 1, 2, 3, 4, 5, 6
-- union all
-- select
-- 	'{dt_id}' as dt_id,
-- 	'csat_score' as kpi_name,
-- 	'store' as level, 
-- 	null as agent_id, 
-- 	store_code, 
-- 	'3ID' as brand, 
-- 	sum(csat_happy)/sum(csat_respond) as value
-- from cockpit.tmp_kpi_csat
-- 	where 1=1
-- 		and left(dt_id,6)=left('{dt_id}',6)
-- 		and dt_id<='{dt_id}'
-- group by 1, 2, 3, 4, 5, 6;