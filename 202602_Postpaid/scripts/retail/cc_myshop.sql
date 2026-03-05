with kpi_rev as (
	select 
		left(a.dt_id, 6) as mth_id,
		a.store_code, 
		a.brand,
		sum(case when a.kpi_name='mystery_shopper' then a.value end) as mystery_shopper
	  from `data-bi-prd-935c.bi_snd.rtl_raw_master_kpi_mtd` as a
	  where a.kpi_name in (
							'mystery_shopper'
	  					)
	   and a.level in ('store') 
	   and a.dt_id='{dt_id}'
 group by all
)
select
	FORMAT_DATE('%Y%m', DATE_SUB(PARSE_DATE('%Y%m', CAST(b.mth_id AS STRING)), INTERVAL 1 MONTH)) periode,
	a.store_name,
	b.store_code,
	a.status_2 as channel,
	a.circle,
	a.region,
	b.mystery_shopper  as score,
	b.mth_id as mth_cal,
	b.brand,
	case when b.mystery_shopper>=90 then 1 else 0 end as myshop_flag
from `data-nationalslsdist-prd-986g`.retail.ref_storelist as a
	left join kpi_rev as b 
		on a.store_code=b.store_code 
	where (lower(a.status_2) like '%gerai%im3%' or lower(a.status_2) like '%3store%')
			and a.mth_id=left('{dt_id}',6)
			and a.store_code not in ('FCBE','JGLM');