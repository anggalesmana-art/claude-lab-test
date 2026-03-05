--new gcp
delete from `data-bi-prd-935c.bi_snd.rtl_raw_master_kpi_mtd`
	where kpi_name in ('sr_total', 'sr_ontime', 'sr_closed', 'fcr', 'sr_tt')
		and brand='3ID'
		and dt_id='{dt_id}'; 

insert into `data-bi-prd-935c.bi_snd.rtl_raw_master_kpi_mtd`
with raw_sr_update as (
	select * from (
	select 
	a.* except (status), 
		b.status_rpa,
		a.status as status_initial,
		case when b.status_rpa in ('Closed', 'Cancelled') then b.status_rpa
			else a.status end as status
	from `data-nationalslsdist-prd-986g`.retail.raw_3id_siebel_sr_tt as a
	left join (
		select * from (
			select 
				sr, status as status_rpa,
				row_number() over(partition by sr order by ins_dt desc) as rnk
			from `data-nationalslsdist-prd-986g`.retail.raw_3id_siebel_sr_rpa
		) as x where x.rnk=1
	) as b
		on a.srnumber = b.sr
	where a.status not in ('Cancelled')
		and date(a.dt_id) between date_trunc(parse_date('%Y%m%d', '{dt_id}'), month)
		and parse_date('%Y%m%d', '{dt_id}')
		and a.creator<>a.owner
		and ticket_type in ('24-Complaint', '23-Service Request')
		and a.issue_subgroup <> 'prepaid reg/unreg issue' 
		) as a where a.status <> 'Cancelled'
)
, sr_data as (
	select  
		a.dt_id, 
		'ICARE' as source_data,
		coalesce(b.agent_nik, c.agent_nik, a.creator) as agent_id,
		a.branch as store_code,
		'sr_total' as kpi_name,
		count(distinct srnumber) as value
	-- from `data-nationalslsdist-prd-986g`.retail.raw_3id_siebel_sr_tt as a 
	from raw_sr_update as a
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
		'ICARE' as source_data,
		coalesce(b.agent_nik, c.agent_nik, a.creator) as agent_id,
		a.branch as store_code,
		'sr_closed' as kpi_name,
		count(distinct srnumber) as value
	-- from `data-nationalslsdist-prd-986g`.retail.raw_3id_siebel_sr_tt as a
	from raw_sr_update as a
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
		and a.status='Closed'
	group by all
	union all
	select  
		a.dt_id, 
		'ICARE' as source_data,
		coalesce(b.agent_nik, c.agent_nik, a.creator) as agent_id,
		a.branch as store_code,
		'sr_ontime' as kpi_name,
		count(distinct case when a.closedate<=a.duedate then srnumber end) as value
	-- from `data-nationalslsdist-prd-986g`.retail.raw_3id_siebel_sr_tt as a
	from raw_sr_update as a
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
		and a.status='Closed'
	group by all
)
-- mtd value
select 
	'{dt_id}' as dt_id,
	'fcr' as kpi_name,
	'agent' as level, 
	a.agent_id, 
	a.store_code, 
	'3ID' as brand, 
	safe_divide(a.value, (a.value+coalesce(b.value,0))) as value, 
 	CURRENT_TIMESTAMP() as insert_dt,
	current_date() as prt_dt
from (
	select
		agent_id, 
		store_code, 
		sum(TotalTrx) as value
	from `data-nationalslsdist-prd-986g`.retail.raw_3id_interactions
		where source_data not in ('dvm_store', 'dvm_standalone')
			and format_date('%Y%m', dt_id)=left('{dt_id}',6)
		and format_date('%Y%m%d', dt_id)<='{dt_id}'
	group by all
	) as a 
left join (
	select
		agent_id, 
		store_code, 
		sum(value) as value
	from sr_data
		where format_date('%Y%m', dt_id)=left('{dt_id}',6)
		and format_date('%Y%m%d', dt_id)<='{dt_id}'
			and kpi_name='sr_total'
	group by 1, 2
	) as b
		on a.agent_id = b.agent_id
union all
select 
	'{dt_id}' as dt_id,
	'fcr' as kpi_name,
	'store' as level, 
	cast(null as string) as agent_id, 
	a.store_code, 
	'3ID' as brand, 
	safe_divide(a.value,(a.value+coalesce(b.value,0))) as value, 
 	CURRENT_TIMESTAMP() as insert_dt,
	current_date() as prt_dt
from (
	select
		store_code, 
		sum(TotalTrx) as value
	from `data-nationalslsdist-prd-986g`.retail.raw_3id_interactions
		where source_data not in ('dvm_store', 'dvm_standalone')
			and format_date('%Y%m', dt_id)=left('{dt_id}',6)
		and format_date('%Y%m%d', dt_id)<='{dt_id}'
	group by 1
	) as a 
left join (
	select
		store_code, 
		sum(value) as value
	from sr_data
		where format_date('%Y%m', dt_id)=left('{dt_id}',6)
		and format_date('%Y%m%d', dt_id)<='{dt_id}'
			and kpi_name='sr_total'
	group by 1
	) as b
		on a.store_code = b.store_code
union all
select
		'{dt_id}' as dt_id,
		kpi_name,
		'agent' as level, 
		agent_id, 
		store_code, 
		'3ID' as brand, 
		sum(value) as value, 
 	CURRENT_TIMESTAMP() as insert_dt,
	current_date() as prt_dt
from sr_data
	where kpi_name in ('sr_total', 'sr_ontime', 'sr_closed')
		and format_date('%Y%m', dt_id)=left('{dt_id}',6)
		and format_date('%Y%m%d', dt_id)<='{dt_id}'
group by all
union all
select
		'{dt_id}' as dt_id,
		'sr_tt' as kpi_name,
		'agent' as level, 
		a.agent_id, 
		a.store_code, 
		'3ID' as brand,
		-- sum(case when kpi_name='sr_closed' then value else 0 end)/sum(case when kpi_name='sr_total' then value else 0 end) as value
		ifnull(safe_divide(sum(case when kpi_name='sr_closed' then value else 0 end),sum(case when kpi_name='sr_total' then value else 0 end)),1) as value, 
 	CURRENT_TIMESTAMP() as insert_dt,
	current_date() as prt_dt
from (
	select distinct
	store_code,
	agent_id
from (
	select
		distinct
		store_code,
		agent_id
	from `data-nationalslsdist-prd-986g`.retail.raw_3id_interactions
	where source_data not in ('dvm_store', 'dvm_standalone')
		and format_date('%Y%m', dt_id)=left('{dt_id}',6)
		and format_date('%Y%m%d', dt_id)<='{dt_id}'
	union all 
	select
		distinct
		store_code,
		agent_id
	from sr_data
	) as x
) as a
left join (
	select *
	from sr_data
		where kpi_name in ('sr_total', 'sr_closed')
			and format_date('%Y%m', dt_id)=left('{dt_id}',6)
			and format_date('%Y%m%d', dt_id)<='{dt_id}'
) as b
	on a.store_code=b.store_code and a.agent_id=b.agent_id
group by all
union all
select
		'{dt_id}' as dt_id,
		kpi_name,
		'store' as level, 
		cast(null as string) as agent_id, 
		store_code, 
		'3ID' as brand, 
		sum(value) as value, 
 	CURRENT_TIMESTAMP() as insert_dt,
	current_date() as prt_dt
from sr_data
	where kpi_name in ('sr_total', 'sr_ontime', 'sr_closed')
		and format_date('%Y%m', dt_id)=left('{dt_id}',6)
		and format_date('%Y%m%d', dt_id)<='{dt_id}'
group by all
union all
select
		'{dt_id}' as dt_id,
		'sr_tt' as kpi_name,
		'store' as level, 
		cast(null as string) as agent_id, 
		a.store_code, 
		'3ID' as brand,
		-- sum(case when kpi_name='sr_closed' then value else 0 end)/sum(case when kpi_name='sr_total' then value else 0 end) as value
		ifnull(safe_divide(sum(case when kpi_name='sr_closed' then value else 0 end),sum(case when kpi_name='sr_total' then value else 0 end)),1) as value, 
 	CURRENT_TIMESTAMP() as insert_dt,
	current_date() as prt_dt
from (
	select distinct
		store_code
	from (
		select
			distinct
			store_code
		from `data-nationalslsdist-prd-986g`.retail.raw_3id_interactions
		where source_data not in ('dvm_store', 'dvm_standalone')
			and format_date('%Y%m', dt_id)=left('{dt_id}',6)
			and format_date('%Y%m%d', dt_id)<='{dt_id}'
		union all 
		select
			distinct
			store_code
		from sr_data
		) as x
) as a
left join (
	select *
	from sr_data
		where kpi_name in ('sr_total', 'sr_closed')
			and format_date('%Y%m', dt_id)=left('{dt_id}',6)
			and format_date('%Y%m%d', dt_id)<='{dt_id}'
) as b
	on a.store_code = b.store_code
group by all;


-- drop table if exists cockpit.tmp_kpi_fcr_sr; 

-- create table cockpit.tmp_kpi_fcr_sr as
-- 	select  
-- 		DATE_FORMAT(tt.Opened, "%Y%m%d") as dt_id,
-- 		case when ma.nik is not null then upper(ma.nik)
-- 	    	when left(upper(tt.CreatedBy),4)='MBPS' then UPPER(CONCAT('MBPS-', SUBSTRING(TRIM(REPLACE(REPLACE(tt.CreatedBy, '-', ''), '_', '')), 5)))
-- 	    	when left(upper(tt.CreatedBy),4)='MPBS' then UPPER(CONCAT('MBPS-', SUBSTRING(TRIM(REPLACE(REPLACE(tt.CreatedBy, '-', ''), '_', '')), 5)))
-- 	    	else upper(tt.CreatedBy) end as agent_id,
-- 		tt.DealerCode as store_code,  
-- 		'sr_total' as kpi_name,  
-- 		count(distinct tt.TicketId) as value
-- 	from cenos_dtmart.tt_siebel_tmp tt 
-- 	left join cockpit.mapping_agent_nik ma
-- 		on  case when left(upper(tt.CreatedBy),4)='MPBS' then UPPER(CONCAT('MBPS', SUBSTRING(TRIM(REPLACE(REPLACE(tt.CreatedBy, '-', ''), '_', '')), 5)))
--         	else upper(TRIM(REPLACE(REPLACE(tt.CreatedBy, '-', ''), '_', ''))) end = upper(ma.idx)
-- 	where DATE_FORMAT(tt.Opened, "%Y%m") = left('{dt_id}',6) 
-- 		and  DATE_FORMAT(tt.Opened, "%Y%m%d")<='{dt_id}'
-- 		and tt.Intent='Complaint' 
-- 		and tt.source = 'WIC'  
-- 		and tt.createdby NOT IN ('kanda', 'edwinw', 'ades')
-- 		and LTRIM(RTRIM(tt.msisdn)) NOT IN ('62895415499177', '628979169620')
-- 		and tt.usecase <> 'CEM Usage'
-- 		and year(tt.DueDate) > 1970
-- 	group by 1, 2, 3
-- 	union all
-- 	select  
-- 		DATE_FORMAT(tt.Closed, "%Y%m%d") as dt_id,
-- 		case when ma.nik is not null then upper(ma.nik)
-- 	    	when left(upper(tt.CreatedBy),4)='MBPS' then UPPER(CONCAT('MBPS-', SUBSTRING(TRIM(REPLACE(REPLACE(tt.CreatedBy, '-', ''), '_', '')), 5)))
-- 	    	when left(upper(tt.CreatedBy),4)='MPBS' then UPPER(CONCAT('MBPS-', SUBSTRING(TRIM(REPLACE(REPLACE(tt.CreatedBy, '-', ''), '_', '')), 5)))
-- 	    	else upper(tt.CreatedBy) end as agent_id,
-- 		tt.DealerCode as store_code,  
-- 		'sr_closed' as kpi_name,   
-- 	count(distinct tt.TicketId) as value
-- 	from cenos_dtmart.tt_siebel_tmp tt 
-- 	left join cockpit.mapping_agent_nik ma
-- 		on  case when left(upper(tt.CreatedBy),4)='MPBS' then UPPER(CONCAT('MBPS', SUBSTRING(TRIM(REPLACE(REPLACE(tt.CreatedBy, '-', ''), '_', '')), 5)))
--         	else upper(TRIM(REPLACE(REPLACE(tt.CreatedBy, '-', ''), '_', ''))) end = upper(ma.idx)
-- 	where DATE_FORMAT(tt.Closed, "%Y%m") = left('{dt_id}',6) 
-- 		and  DATE_FORMAT(tt.Closed, "%Y%m%d")<='{dt_id}'
-- 		and tt.Intent='Complaint' 
-- 		and tt.source = 'WIC'  
-- 		and tt.Status = 'Closed'
-- 		and tt.createdby NOT IN ('kanda', 'edwinw', 'ades')
-- 		and LTRIM(RTRIM(tt.msisdn)) NOT IN ('62895415499177', '628979169620')
-- 		and tt.usecase <> 'CEM Usage'
-- 		and year(tt.DueDate) > 1970
-- 	group by 1, 2, 3
-- 	union all	
-- 	select  
-- 		DATE_FORMAT(tt.Closed, "%Y%m%d") as dt_id,
-- 		case when ma.nik is not null then upper(ma.nik)
-- 	    	when left(upper(tt.CreatedBy),4)='MBPS' then UPPER(CONCAT('MBPS-', SUBSTRING(TRIM(REPLACE(REPLACE(tt.CreatedBy, '-', ''), '_', '')), 5)))
-- 	    	when left(upper(tt.CreatedBy),4)='MPBS' then UPPER(CONCAT('MBPS-', SUBSTRING(TRIM(REPLACE(REPLACE(tt.CreatedBy, '-', ''), '_', '')), 5)))
-- 	    	else upper(tt.CreatedBy) end as agent_id,
-- 		tt.DealerCode as store_code,  
-- 		'sr_ontime' as kpi_name,   
-- 	count(distinct case when tt.Closed <= tt.DueDate then tt.TicketId end) as value
-- 	from cenos_dtmart.tt_siebel_tmp tt 
-- 	left join cockpit.mapping_agent_nik ma
-- 		on  case when left(upper(tt.CreatedBy),4)='MPBS' then UPPER(CONCAT('MBPS', SUBSTRING(TRIM(REPLACE(REPLACE(tt.CreatedBy, '-', ''), '_', '')), 5)))
--         	else upper(TRIM(REPLACE(REPLACE(tt.CreatedBy, '-', ''), '_', ''))) end = upper(ma.idx)
-- 	where DATE_FORMAT(tt.Closed, "%Y%m") = left('{dt_id}',6) 
-- 		and  DATE_FORMAT(tt.Closed, "%Y%m%d")<='{dt_id}'
-- 		and tt.Intent='Complaint' 
-- 		and tt.source = 'WIC'  
-- 		and tt.Status = 'Closed'
-- 		and tt.createdby NOT IN ('kanda', 'edwinw', 'ades')
-- 		and LTRIM(RTRIM(tt.msisdn)) NOT IN ('62895415499177', '628979169620')
-- 		and tt.usecase <> 'CEM Usage'
-- 		and year(tt.DueDate) > 1970
-- 	group by 1, 2, 3 ; 


-- -- mtd value
-- select 
-- 	'{dt_id}' as dt_id,
-- 	'fcr' as kpi_name,
-- 	'agent' as level, 
-- 	a.agent_id, 
-- 	a.store_code, 
-- 	'3ID' as brand, 
-- 	a.value/(a.value+coalesce(b.value,0)) as value
-- from (
-- 	select
-- 		agent_id, 
-- 		store_code, 
-- 		sum(TotalTrx) as value
-- 	from cockpit.tmp_kpi_interaction
-- 		where source_data not in ('dvm_store', 'dvm_standalone')
-- 			and left(dt_id,6)=left('{dt_id}',6)
-- 			and dt_id<='{dt_id}'
-- 	group by 1, 2
-- 	) as a 
-- left join (
-- 	select
-- 		agent_id, 
-- 		store_code, 
-- 		sum(value) as value
-- 	from cockpit.tmp_kpi_fcr_sr
-- 		where left(dt_id,6)=left('{dt_id}',6)
-- 			and dt_id<='{dt_id}'
-- 			and kpi_name='sr_total'
-- 	group by 1, 2
-- 	) as b
-- 		on a.agent_id = b.agent_id
-- union all
-- select 
-- 	'{dt_id}' as dt_id,
-- 	'fcr' as kpi_name,
-- 	'store' as level, 
-- 	null as agent_id, 
-- 	a.store_code, 
-- 	'3ID' as brand, 
-- 	a.value/(a.value+coalesce(b.value,0)) as value
-- from (
-- 	select
-- 		store_code, 
-- 		sum(TotalTrx) as value
-- 	from cockpit.tmp_kpi_interaction
-- 		where source_data not in ('dvm_store', 'dvm_standalone')
-- 			and left(dt_id,6)=left('{dt_id}',6)
-- 			and dt_id<='{dt_id}'
-- 	group by 1
-- 	) as a 
-- left join (
-- 	select
-- 		store_code, 
-- 		sum(value) as value
-- 	from cockpit.tmp_kpi_fcr_sr
-- 		where left(dt_id,6)=left('{dt_id}',6)
-- 			and dt_id<='{dt_id}'
-- 			and kpi_name='sr_total'
-- 	group by 1
-- 	) as b
-- 		on a.store_code = b.store_code
-- union all
-- select
-- 		'{dt_id}' as dt_id,
-- 		kpi_name,
-- 		'agent' as level, 
-- 		agent_id, 
-- 		store_code, 
-- 		'3ID' as brand, 
-- 		sum(value) as value
-- from cockpit.tmp_kpi_fcr_sr
-- 	where kpi_name in ('sr_total', 'sr_ontime', 'sr_closed')
-- 		and left(dt_id,6)=left('{dt_id}',6)
-- 		and dt_id<='{dt_id}'
-- group by 1, 2, 3, 4, 5, 6
-- union all
-- select
-- 		'{dt_id}' as dt_id,
-- 		'sr_tt' as kpi_name,
-- 		'agent' as level, 
-- 		a.agent_id, 
-- 		a.store_code, 
-- 		'3ID' as brand,
-- 		-- sum(case when kpi_name='sr_closed' then value else 0 end)/sum(case when kpi_name='sr_total' then value else 0 end) as value
-- 		ifnull(sum(case when kpi_name='sr_closed' then value else 0 end)/sum(case when kpi_name='sr_total' then value else 0 end),1) as value
-- from (
-- 	select distinct
-- 	store_code,
-- 	agent_id
-- from (
-- 	select
-- 		distinct
-- 		store_code,
-- 		agent_id
-- 	from cockpit.tmp_kpi_interaction
-- 	union all 
-- 	select
-- 		distinct
-- 		store_code,
-- 		agent_id
-- 	from cockpit.tmp_kpi_fcr_sr
-- 	) as x
-- ) as a
-- left join (
-- 	select *
-- 	from cockpit.tmp_kpi_fcr_sr
-- 		where kpi_name in ('sr_total', 'sr_closed')
-- 			and left(dt_id,6)=left('{dt_id}',6)
-- 			and dt_id<='{dt_id}'
-- ) as b
-- 	on a.store_code=b.store_code and a.agent_id=b.agent_id
-- group by 1, 2, 3, 4, 5, 6
-- union all
-- select
-- 		'{dt_id}' as dt_id,
-- 		kpi_name,
-- 		'store' as level, 
-- 		null as agent_id, 
-- 		store_code, 
-- 		'3ID' as brand, 
-- 		sum(value) as value
-- from cockpit.tmp_kpi_fcr_sr
-- 	where kpi_name in ('sr_total', 'sr_ontime', 'sr_closed')
-- 		and left(dt_id,6)=left('{dt_id}',6)
-- 		and dt_id<='{dt_id}'
-- group by 1, 2, 3, 4, 5, 6
-- union all
-- select
-- 		'{dt_id}' as dt_id,
-- 		'sr_tt' as kpi_name,
-- 		'store' as level, 
-- 		null as agent_id, 
-- 		a.store_code, 
-- 		'3ID' as brand,
-- 		-- sum(case when kpi_name='sr_closed' then value else 0 end)/sum(case when kpi_name='sr_total' then value else 0 end) as value
-- 		ifnull(sum(case when kpi_name='sr_closed' then value else 0 end)/sum(case when kpi_name='sr_total' then value else 0 end),1) as value
-- from (
-- 	select distinct
-- 		store_code
-- 	from (
-- 		select
-- 			distinct
-- 			store_code
-- 		from cockpit.tmp_kpi_interaction
-- 		union all 
-- 		select
-- 			distinct
-- 			store_code
-- 		from cockpit.tmp_kpi_fcr_sr
-- 		) as x
-- ) as a
-- left join (
-- 	select *
-- 	from cockpit.tmp_kpi_fcr_sr
-- 		where kpi_name in ('sr_total', 'sr_closed')
-- 			and left(dt_id,6)=left('{dt_id}',6)
-- 			and dt_id<='{dt_id}'
-- ) as b
-- 	on a.store_code = b.store_code
-- group by 1, 2, 3, 4, 5, 6;