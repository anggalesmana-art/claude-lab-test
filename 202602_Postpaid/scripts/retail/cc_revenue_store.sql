with kpi_rev as (
	select 
		left(a.dt_id, 6) as periode,
		a.store_code, 
		sum(case when a.kpi_name='rev_cash_in' then a.value end) as revenue_cash_in,
		sum(case when a.kpi_name='rev_service' then a.value end) as revenue_services,
		sum(case when a.kpi_name='rev_cash_in_dvm' then a.value end) as revenue_cash_in_dvm,
		sum(case when a.kpi_name='rev_service_dvm' then a.value end) as revenue_services_dvm,
		sum(a.value) as revenue_store
	  from `data-bi-prd-935c.bi_snd.rtl_raw_master_kpi_mtd` as a
	  where a.kpi_name in ('rev_cash_in',
						'rev_cash_in_dvm',
						'rev_others_ftth',
						'rev_service',
						'rev_service_dvm',
						'rev_billed_postpaid')
	   and a.level in ('store', 'dvm_store') 
	   and a.dt_id='{dt_id}'
 group by all
)
select 
	a.store_code,
	a.store_name,
	a.`type`,
	a.region,
	a.circle,
	cast(a.periode as string) periode,
	a.revenue_tgt as revenue_target, 
	b.revenue_cash_in,
	b.revenue_services, 
	b.revenue_cash_in_dvm,
	b.revenue_services_dvm,
	b.revenue_store, 
	b.revenue_store / a.revenue_tgt as revenue_ach,
	case when b.revenue_store / a.revenue_tgt >= 1 then 1 else 0 end as store_productivity,	
	case when a.type in ('3Store', 'DVM Stand alone') then '3ID'
		when a.type='Gerai' then 'IM3' end as brand
from  `data-nationalslsdist-prd-986g.retail.ref_target_rev_store` as a
	left join kpi_rev as b 
		on a.store_code=b.store_code and cast(a.periode as string)=b.periode
	where a.`type` in ('3Store', 'Gerai')
		and a.periode=cast(left('{dt_id}',6) as int)
        and a.revenue_tgt>0
        and a.revenue_tgt is not null
        and a.store_code not in ('FCBE','JGLM');
