delete from `data-bi-prd-935c.bi_snd.rtl_raw_master_kpi_mtd`
	where kpi_name in ('ga_prepaid_dvm', 'rev_service_dvm', 'rev_cash_in_dvm', 'change_card_dvm', 'traffic_visitor_dvm', 'interaction_dvm')
		and level='agent'
		and brand='3ID'
		and dt_id='{dt_id}';

insert into `data-bi-prd-935c.bi_snd.rtl_raw_master_kpi_mtd`
with avg_agent as (
	select 
		'{dt_id}' as dt_id,
	 	a.kpi_name,
	 	a.store_code,
	 	safe_divide(sum(a.value), max(num_agent)) avg_value
	from `data-bi-prd-935c.bi_snd.rtl_raw_master_kpi_mtd` as a
		left join (
			select 
				store_code,
				kpi_name,
				count(distinct agent_id) as num_agent
			from `data-bi-prd-935c.bi_snd.rtl_raw_master_kpi_mtd`
			where dt_id='{dt_id}'
				and level='agent'
				and kpi_name in ('ga_prepaid', 'rev_service', 'rev_cash_in', 'change_card', 'traffic_visitor', 'interaction')
				and brand='3ID'
			group by 1, 2
		) 
			 as b
			on a.store_code=b.store_code and a.kpi_name=concat(b.kpi_name, '_dvm')
	where a.kpi_name in ('ga_prepaid_dvm', 'rev_service_dvm', 'rev_cash_in_dvm', 'change_card_dvm', 'traffic_visitor_dvm', 'interaction_dvm') 
		and a.level='dvm_store'
		and a.brand='3ID' 
		and a.dt_id='{dt_id}'
	group by 1, 2, 3
)
select 
	'{dt_id}' as dt_id,
	b.kpi_name,
	a.level,
	a.agent_id,
	a.store_code,
	a.brand,
	coalesce(b.avg_value,0) as value,
	CURRENT_TIMESTAMP() as insert_dt,
	current_date() as prt_dt
from `data-bi-prd-935c.bi_snd.rtl_raw_master_kpi_mtd` as a
	left join avg_agent as b
		on a.store_code = b.store_code and concat(a.kpi_name, '_dvm') = b.kpi_name
where a.dt_id='{dt_id}'
		and a.level='agent'
		and a.kpi_name in ('ga_prepaid', 'rev_service', 'rev_cash_in', 'change_card', 'traffic_visitor', 'interaction')
		and a.brand='3ID'
		and b.kpi_name is not null
order by a.store_code, b.kpi_name
;