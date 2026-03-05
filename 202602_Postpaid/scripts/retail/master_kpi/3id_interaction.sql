-- COCKPIT
-- drop table if exists cockpit.tmp_kpi_interaction
delete from cockpit.tmp_kpi_interaction
where left(dt_id,6)=left('{dt_id}',6)
		and dt_id<='{dt_id}';

-- create table cockpit.tmp_kpi_interaction as
-- 04-3ID Interaction (3Store, 3Kiosk, 3Kiosk Online)
insert into cockpit.tmp_kpi_interaction
select 
	-- substring(opened_time, 1, 10) period
	left(replace(substring(a.opened_time, 1, 10),'-',''),8) dt_id
	, a.source source_data
	, case when ma.nik is not null then upper(ma.nik)
    	when left(upper(a.opened_by),4)='MBPS' then UPPER(CONCAT('MBPS-', SUBSTRING(TRIM(REPLACE(REPLACE(a.opened_by, '-', ''), '_', '')), 5)))
    	when left(upper(a.opened_by),4)='MPBS' then UPPER(CONCAT('MBPS-', SUBSTRING(TRIM(REPLACE(REPLACE(a.opened_by, '-', ''), '_', '')), 5)))
    	else upper(a.opened_by) end as agent_id
    , case when a.source in ('3Kiosk','3Kiosk Online') then SUBSTRING_INDEX(a.opened_by, '-', 1)
    	else ma.store_code end as store_code
	, a.intent
	, a.usecase
	, case when a.intent = 'Transaction' then 'Transaction' else 'Non Transaction' end as intent_type
	, case 
		when a.intent = 'Complaint' and (ref_id is null or ref_id ='') then 'Complaint FCR' 
	  	when a.intent = 'Complaint' and (ref_id is not null or ref_id <>'') then 'Complaint Escalated' 
	  	else "" 
	  end as FCR_Flag
	, count(distinct a.user_contact) TotalTrx
from cockpit_archieve.cstools_raw_tickets as a
	left join cockpit.mapping_agent_nik ma
		on  case when left(upper(a.opened_by),4)='MPBS' then UPPER(CONCAT('MBPS', SUBSTRING(TRIM(REPLACE(REPLACE(a.opened_by, '-', ''), '_', '')), 5)))
        else upper(TRIM(REPLACE(REPLACE(a.opened_by, '-', ''), '_', ''))) end = upper(ma.idx)
where left(replace(substring(a.opened_time, 1, 10),'-',''),6) = left('{dt_id}',6) and left(replace(substring(a.opened_time, 1, 10),'-',''),8)<='{dt_id}'
	and a.source in ('3Store','3Kiosk','3Kiosk Online')
group by 1,2,3,4,5,6,7,8
union all
-- 03-3ID DVM Interaction
select 
	-- substring(date_trx,1,10) as period
	left(replace(substring(date_trx, 1, 10),'-',''),8) as dt_id
	, case 
		when T2.dvm_code is not null then 'dvm_store'
		else 'dvm_standalone'
	  end  source_data
	, trim(T2.dvm_code) AS agent_id
	, coalesce(T2.store_code, trim(T1.terminal_code)) as store_code
	, case when product_code IN ('THREE_CHANGE_CARD','THREE_REGPRABAYAR','THREE_SIMCARD4G') then 'Service Request' else 'Transaction' end as intent
	, product_code as usecase
	, case when product_code IN ('THREE_CHANGE_CARD','THREE_REGPRABAYAR','THREE_SIMCARD4G') then 'Non Transaction' else 'Transaction' end as intent_type
	, product_name as FCR_Flag
	, count(trxid) as TotalTrx
from  cockpit_archieve.raw_3db_trx as T1
	left join cockpit.dvm_mapping T2
			on trim(T1.terminal_code)=trim(T2.dvm_code)
WHERE result = 'Success'
	and left(replace(substring(date_trx, 1, 10),'-',''),6) = left('{dt_id}',6) 
		and left(replace(substring(date_trx, 1, 10),'-',''),8)<='{dt_id}'
group by 1,2,3,4,5,6,7,8; 

-- GCP
delete from `data-nationalslsdist-prd-986g`.retail.raw_3id_interactions
	WHERE format_date('%Y%m', dt_id) = left('{dt_id}',6)
    and source_data like '%ICARE%';

insert into `data-nationalslsdist-prd-986g`.retail.raw_3id_interactions
select * from (
select  
	a.dt_id, 
	'ICARE' as source_data,
	coalesce(b.agent_nik, c.agent_nik, a.creator) as agent_id,
	a.branch as store_code,
	case when a.ticket_type like '%Inquiry%' then 'Inquiry'
		when a.ticket_type like '%Service%' then 'Service Request'
		when a.ticket_type like '%Complaint%' then 'Complaint'
		else a.ticket_type end as intent,
	a.issue_desc as usecase,
	'Non Transaction' as intent_type, 
	'' fcr_flag,
	count(*) as totaltrx
from `data-nationalslsdist-prd-986g`.retail.raw_3id_siebel_interaction as a
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
		) as b on upper(regexp_replace(a.creator,r'[-_#\s]+', ''))=b.id and a.branch=b.store_code
left join (
	select 
		distinct
		upper(regexp_replace(agent_name, r'[-_#\s]+', '')) id, 
		agent_nik,
		store_code
	from `data-nationalslsdist-prd-986g`.retail.ref_agent_spv 
		where brand='3ID'
			and agent_name is not null 
			and mth_id = (select max(mth_id) from `data-nationalslsdist-prd-986g`.retail.ref_agent_spv)
) as c on upper(regexp_replace(a.creatorname, r'[-_#\s]+', ''))=c.id and a.branch=c.store_code
where a.dt_id between date_trunc(parse_date('%Y%m%d', '{dt_id}'), month)
			and parse_date('%Y%m%d', '{dt_id}')
group by all
union all
select  
	a.dt_id, 
	'ICARE ORDER' as source_data,
	coalesce(b.agent_nik, c.agent_nik, a.nik) as agent_id,
	a.dealer as store_code,
	'Service Request' as intent,
	a.order_name as usecase,
	'Non Transaction' as intent_type, 
	'' fcr_flag,
	count(*) as totaltrx
from `data-nationalslsdist-prd-986g`.retail.raw_3id_siebel_order as a
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
		) as b on upper(regexp_replace(a.nik,r'[-_#\s]+', ''))=b.id and a.dealer=b.store_code
left join (
	select 
		distinct
		upper(regexp_replace(agent_name, r'[-_#\s]+', '')) id, 
		agent_nik,
		store_code
	from `data-nationalslsdist-prd-986g`.retail.ref_agent_spv 
		where brand='3ID'
			and agent_name is not null 
			and mth_id = (select max(mth_id) from `data-nationalslsdist-prd-986g`.retail.ref_agent_spv)
) as c on upper(regexp_replace(a.creator, r'[-_#\s]+', ''))=c.id and a.dealer=c.store_code
left join `data-nationalslsdist-prd-986g`.retail.raw_3id_siebel_interaction as d 
	on a.msisdn=d.service_num and a.dealer=d.branch and a.dt_id=d.dt_id and a.nik=d.creator
where a.channel='Walk In'
		and a.dt_id between date_trunc(parse_date('%Y%m%d', '{dt_id}'), month)
			and parse_date('%Y%m%d', '{dt_id}')
		and d.srnumber is null
group by all
);

-- GCP
delete from `data-bi-prd-935c.bi_snd.rtl_raw_master_kpi_mtd`
	where kpi_name in ('interaction', 'interaction_dvm')
		and brand='3ID'
		and dt_id='{dt_id}';  

insert into `data-bi-prd-935c.bi_snd.rtl_raw_master_kpi_mtd`
select
	'{dt_id}' as dt_id,
	'interaction' as kpi_name,
	'agent' as level, 
	agent_id, 
	store_code, 
	'3ID' as brand, 
	sum(TotalTrx) as value, 
 	CURRENT_TIMESTAMP() as insert_dt,
	current_date() as prt_dt
from `data-nationalslsdist-prd-986g`.retail.raw_3id_interactions
	where source_data not in ('dvm_store', 'dvm_standalone')
		and format_date('%Y%m', dt_id)=left('{dt_id}',6)
		and format_date('%Y%m%d', dt_id)<='{dt_id}'
group by all
union all
select
	'{dt_id}' as dt_id,
	'interaction' as kpi_name,
	'store' as level, 
	null as agent_id, 
	store_code, 
	'3ID' as brand, 
	sum(TotalTrx) as value, 
 	CURRENT_TIMESTAMP() as insert_dt,
	current_date() as prt_dt
from `data-nationalslsdist-prd-986g`.retail.raw_3id_interactions
	where source_data not in ('dvm_store', 'dvm_standalone')
		and format_date('%Y%m', dt_id)=left('{dt_id}',6)
		and format_date('%Y%m%d', dt_id)<='{dt_id}'
group by all
union all
select
	'{dt_id}' as dt_id,
	'interaction_dvm' as kpi_name,
	source_data as level, 
	agent_id, 
	store_code, 
	'3ID' as brand, 
	sum(TotalTrx) as value, 
 	CURRENT_TIMESTAMP() as insert_dt,
	current_date() as prt_dt
from `data-nationalslsdist-prd-986g`.retail.raw_3id_interactions
	where source_data in ('dvm_store', 'dvm_standalone')
		and format_date('%Y%m', dt_id)=left('{dt_id}',6)
		and format_date('%Y%m%d', dt_id)<='{dt_id}'
group by all;

delete from `data-bi-prd-935c.bi_snd.rtl_raw_master_kpi_dly`
	where kpi_name in ('interaction', 'interaction_dvm')
		and brand='3ID'
		and left(dt_id,6)=left('{dt_id}',6)
 		and dt_id<='{dt_id}';  

insert into `data-bi-prd-935c.bi_snd.rtl_raw_master_kpi_dly`
select
	format_date('%Y%m%d', dt_id) as dt_id,
	'interaction' as kpi_name,
	'agent' as level, 
	agent_id, 
	store_code, 
	'3ID' as brand, 
	sum(TotalTrx) as value, 
 	CURRENT_TIMESTAMP() as insert_dt,
	current_date() as prt_dt
from `data-nationalslsdist-prd-986g`.retail.raw_3id_interactions
	where source_data not in ('dvm_store', 'dvm_standalone')
		and format_date('%Y%m', dt_id)=left('{dt_id}',6)
		and format_date('%Y%m%d', dt_id)<='{dt_id}'
group by all
union all
select
	format_date('%Y%m%d', dt_id) as dt_id,
	'interaction' as kpi_name,
	'store' as level, 
	null as agent_id, 
	store_code, 
	'3ID' as brand, 
	sum(TotalTrx) as value, 
 	CURRENT_TIMESTAMP() as insert_dt,
	current_date() as prt_dt
from `data-nationalslsdist-prd-986g`.retail.raw_3id_interactions
	where source_data not in ('dvm_store', 'dvm_standalone')
		and format_date('%Y%m', dt_id)=left('{dt_id}',6)
		and format_date('%Y%m%d', dt_id)<='{dt_id}'
group by all
union all
select
	format_date('%Y%m%d', dt_id) as dt_id,
	'interaction_dvm' as kpi_name,
	source_data as level, 
	agent_id, 
	store_code, 
	'3ID' as brand, 
	sum(TotalTrx) as value, 
 	CURRENT_TIMESTAMP() as insert_dt,
	current_date() as prt_dt
from `data-nationalslsdist-prd-986g`.retail.raw_3id_interactions
	where source_data in ('dvm_store', 'dvm_standalone')
		and format_date('%Y%m', dt_id)=left('{dt_id}',6)
		and format_date('%Y%m%d', dt_id)<='{dt_id}'
group by all;

-- -- mtd value
-- select
-- 	'{dt_id}' as dt_id,
-- 	'interaction' as kpi_name,
-- 	'agent' as level, 
-- 	agent_id, 
-- 	store_code, 
-- 	'3ID' as brand, 
-- 	sum(TotalTrx) as value
-- from cockpit.tmp_kpi_interaction
-- 	where source_data not in ('dvm_store', 'dvm_standalone')
-- 		and left(dt_id,6)=left('{dt_id}',6)
-- 		and dt_id<='{dt_id}'
-- group by 1, 2, 3, 4, 5, 6
-- union all
-- select
-- 	'{dt_id}' as dt_id,
-- 	'interaction' as kpi_name,
-- 	'store' as level, 
-- 	null as agent_id, 
-- 	store_code, 
-- 	'3ID' as brand, 
-- 	sum(TotalTrx) as value
-- from cockpit.tmp_kpi_interaction
-- 	where source_data not in ('dvm_store', 'dvm_standalone')
-- 		and left(dt_id,6)=left('{dt_id}',6)
-- 		and dt_id<='{dt_id}'
-- group by 1, 2, 3, 4, 5, 6
-- union all
-- select
-- 	'{dt_id}' as dt_id,
-- 	'interaction_dvm' as kpi_name,
-- 	source_data as level, 
-- 	agent_id, 
-- 	store_code, 
-- 	'3ID' as brand, 
-- 	sum(TotalTrx) as value
-- from cockpit.tmp_kpi_interaction
-- 	where source_data in ('dvm_store', 'dvm_standalone')
-- 		and left(dt_id,6)=left('{dt_id}',6)
-- 		and dt_id<='{dt_id}'
-- group by 1, 2, 3, 4, 5, 6;

-- -- daily value 
-- select
-- 	dt_id,
-- 	'interaction' as kpi_name,
-- 	'agent' as level, 
-- 	agent_id, 
-- 	store_code, 
-- 	'3ID' as brand, 
-- 	sum(TotalTrx) as value
-- from cockpit.tmp_kpi_interaction
-- 	where source_data not in ('dvm_store', 'dvm_standalone')
-- 		and left(dt_id,6)=left('{dt_id}',6)
-- 		and dt_id<='{dt_id}'
-- group by 1, 2, 3, 4, 5, 6
-- union all
-- select
-- 	dt_id,
-- 	'interaction' as kpi_name,
-- 	'store' as level, 
-- 	null as agent_id, 
-- 	store_code, 
-- 	'3ID' as brand, 
-- 	sum(TotalTrx) as value
-- from cockpit.tmp_kpi_interaction
-- 	where source_data not in ('dvm_store', 'dvm_standalone')
-- 		and left(dt_id,6)=left('{dt_id}',6)
-- 		and dt_id<='{dt_id}'
-- group by 1, 2, 3, 4, 5, 6
-- union all
-- select
-- 	dt_id,
-- 	'interaction_dvm' as kpi_name,
-- 	source_data as level, 
-- 	agent_id, 
-- 	store_code, 
-- 	'3ID' as brand, 
-- 	sum(TotalTrx) as value
-- from cockpit.tmp_kpi_interaction
-- 	where source_data in ('dvm_store', 'dvm_standalone')
-- 		and left(dt_id,6)=left('{dt_id}',6)
-- 		and dt_id<='{dt_id}'
-- group by 1, 2, 3, 4, 5, 6; 