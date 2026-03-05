delete from `data-nationalslsdist-prd-986g`.retail.raw_3id_change_card
	where source_channel='ICARE'
		and left(dt_id, 6)=left('{dt_id}',6); 

insert into `data-nationalslsdist-prd-986g`.retail.raw_3id_change_card
select * except(rnk)
from(
	select 
		a.msisdn, 	
		coalesce(b.agent_nik, c.agent_nik, upper(regexp_replace(a.nik,r'[-_#\s]+', ''))) agent_nik,
		a.dealer as store_code,
		a.order_name as category,
		'ICARE' as source_channel,
		format_date('%Y%m%d', a.dt_id) as dt_id,
		a.dt_id as prt_dt,
		row_number() over(partition by a.msisdn order by a.dt_id desc) rnk
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
	where lower(a.order_name)='change sim card attributes'
		and a.channel='Walk In'
		and a.dt_id between date_trunc(parse_date('%Y%m%d', '{dt_id}'), month)
			and parse_date('%Y%m%d', '{dt_id}')
) as x where x.rnk=1
;

delete from `data-bi-prd-935c.bi_snd.rtl_raw_master_kpi_mtd`
	where kpi_name in ('change_card', 'change_card_dvm')
		and brand='3ID'
		and dt_id='{dt_id}';

-- mtd
insert into `data-bi-prd-935c.bi_snd.rtl_raw_master_kpi_mtd`
 select
 	'{dt_id}' as dt_id,
 	'change_card' as kpi_name,
 	'agent' as level, 
 	agent_id, 
 	store_code, 
 	'3ID' as brand, 
 	count(distinct msisdn) as value, 
 	CURRENT_TIMESTAMP() as insert_dt,
	current_date() as prt_dt
 from `data-nationalslsdist-prd-986g`.retail.raw_3id_change_card
 	where 1=1
 		-- and category='Replacement SIM Card'
 		and lower(source_channel) in ('siebel', 'cstools', 'icare')
 		and left(dt_id,6)=left('{dt_id}',6)
 		and dt_id<='{dt_id}'
 group by all
 union all
 select
 	'{dt_id}' as dt_id,
 	'change_card' as kpi_name,
 	'store' as level, 
 	null as agent_id, 
 	store_code, 
 	'3ID' as brand, 
 	count(distinct msisdn) as value, 
 	CURRENT_TIMESTAMP() as insert_dt,
	current_date() as prt_dt
 from `data-nationalslsdist-prd-986g`.retail.raw_3id_change_card
 	where 1=1
 		-- and category='Replacement SIM Card'
 		and lower(source_channel) in ('siebel', 'cstools', 'icare')
 		and left(dt_id,6)=left('{dt_id}',6)
 		and dt_id<='{dt_id}'
 group by all
 union all
 select
 	'{dt_id}' as dt_id,
 	'change_card_dvm' as kpi_name,
 	source_channel as level, 
 	agent_id as agent_id, 
 	store_code, 
 	'3ID' as brand, 
 	count(distinct msisdn) as value, 
 	CURRENT_TIMESTAMP() as insert_dt,
	current_date() as prt_dt
 from `data-nationalslsdist-prd-986g`.retail.raw_3id_change_card
 	where lower(source_channel) in ('dvm_store', 'dvm_standalone')
 		and left(dt_id,6)=left('{dt_id}',6)
 		and dt_id<='{dt_id}'
 group by all;


delete from `data-bi-prd-935c.bi_snd.rtl_raw_master_kpi_dly`
	where kpi_name in ('change_card', 'change_card_dvm')
		and brand='3ID'
		and left(dt_id,6)=left('{dt_id}',6)
 		and dt_id<='{dt_id}';

 -- dly
insert into `data-bi-prd-935c.bi_snd.rtl_raw_master_kpi_dly`
 select
 	dt_id,
 	'change_card' as kpi_name,
 	'agent' as level, 
 	agent_id, 
 	store_code, 
 	'3ID' as brand, 
 	count(distinct msisdn) as value, 
 	CURRENT_TIMESTAMP() as insert_dt,
	current_date() as prt_dt
 from `data-nationalslsdist-prd-986g`.retail.raw_3id_change_card
 	where 1=1
 		-- and category='Replacement SIM Card'
 		and lower(source_channel) in ('siebel', 'cstools', 'icare')
 		and left(dt_id,6)=left('{dt_id}',6)
 		and dt_id<='{dt_id}'
 group by all
 union all
 select
 	dt_id,
 	'change_card' as kpi_name,
 	'store' as level, 
 	cast(null as string) as agent_id, 
 	store_code, 
 	'3ID' as brand, 
 	count(distinct msisdn) as value, 
 	CURRENT_TIMESTAMP() as insert_dt,
	current_date() as prt_dt
 from `data-nationalslsdist-prd-986g`.retail.raw_3id_change_card
 	where 1=1
 		-- and category='Replacement SIM Card'
 		and lower(source_channel) in ('siebel', 'cstools', 'icare')
 		and left(dt_id,6)=left('{dt_id}',6)
 		and dt_id<='{dt_id}'
 group by all
 union all
 select
 	dt_id,
 	'change_card_dvm' as kpi_name,
 	source_channel as level, 
 	agent_id as agent_id, 
 	store_code, 
 	'3ID' as brand, 
 	count(distinct msisdn) as value, 
 	CURRENT_TIMESTAMP() as insert_dt,
	current_date() as prt_dt
 from `data-nationalslsdist-prd-986g`.retail.raw_3id_change_card
 	where  lower(source_channel) in ('dvm_store', 'dvm_standalone')
 		and left(dt_id,6)=left('{dt_id}',6)
 		and dt_id<='{dt_id}'
 group by all;