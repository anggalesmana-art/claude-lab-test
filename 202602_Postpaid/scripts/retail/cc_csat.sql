with kpi_rev as (
	select 
		left(a.dt_id, 6) as mth_id,
		a.store_code, 
		a.brand,
		sum(case when a.kpi_name='csat_delivered' then a.value end) as responden_delivered,
		sum(case when a.kpi_name='csat_respond' then a.value end) as responden_feedback,
		sum(case when a.kpi_name='csat_happy' then a.value end) as happy,
		sum(case when a.kpi_name='csat_respond_rate' then a.value end) as responden_rate,
		sum(case when a.kpi_name='csat_score' then a.value end) as csat_score
	  from `data-bi-prd-935c.bi_snd.rtl_raw_master_kpi_mtd` as a
	  where a.kpi_name in (
							'csat_delivered',
							'csat_happy',
							'csat_respond',
							'csat_respond_rate', 
							'csat_score'
	  					)
	   and a.level in ('store') 
	   and a.dt_id='{dt_id}'
 group by all
)
select
	b.mth_id,
	b.store_code,
	a.store_name,
	a.circle,
	a.region,
	b.responden_delivered,
	b.responden_feedback,
	b.happy,
	b.responden_rate,
	b.csat_score,
	case when b.responden_rate>=0.03 then 'Valid' else 'Not Valid' end as status,
	b.brand,
	case when b.responden_rate>=0.03 and b.csat_score>=0.98 then 1 else 0 end as csat_flag
from `data-nationalslsdist-prd-986g`.retail.ref_storelist as a
	left join kpi_rev as b 
		on a.store_code=b.store_code 
	where (lower(a.status_2) like '%gerai%im3%' or lower(a.status_2) like '%3store%')
			and a.mth_id=left('{dt_id}',6)
			and a.store_code not in ('FCBE','JGLM');