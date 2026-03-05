select 
 left(a.dt_id, 6) as mth_id,
 b.circle,
 b.region as region_circle,
 b.store_name, 
 a.store_code,
 a.agent_id,
 a.level as agent_category,
 a.ga_dvm,
 a.visitor_dvm,
 a.ga_store, 
 a.visitor_store,
 a.ga,
 a.visitor, 
 a.conversion_rate, 
 a.brand,
 case when a.conversion_rate >= 0.1 then 1 else 0 end as agent_productivity
from (
 select 
  '{dt_id}' as dt_id,
   a.level,
   a.agent_id as agent_id,
   a.store_code as store_code,
   a.brand,
   sum(case when b.kpi_name='traffic_visitor' then b.value else 0 end) as visitor_store,
   sum(case when b.kpi_name='traffic_visitor_dvm' then b.value else 0 end) as visitor_dvm,
   sum(case when b.kpi_name='ga_prepaid' then b.value else 0 end) as ga_store,
   sum(case when b.kpi_name='ga_prepaid_dvm' then b.value else 0 end) as ga_dvm,
   sum(case when b.kpi_name in ('traffic_visitor', 'traffic_visitor_dvm') then b.value else 0 end) as visitor,
   sum(case when b.kpi_name in ('ga_prepaid', 'ga_prepaid_dvm') then b.value else 0 end) as ga,
   coalesce(safe_divide(sum(case when b.kpi_name in ('ga_prepaid', 'ga_prepaid_dvm') then b.value else 0 end), 
   	sum(case when b.kpi_name in ('traffic_visitor', 'traffic_visitor_dvm') then b.value else 0 end)),1) as conversion_rate 
 from(
  select 
  	distinct
  	level,
  	agent_id,
  	store_code,
  	brand
  from `data-bi-prd-935c.bi_snd.rtl_raw_master_kpi_mtd` 
  where kpi_name in ('traffic_visitor', 'traffic_visitor_dvm')
   and level='agent' 
   and dt_id='{dt_id}'
   and brand='3ID'
  )as a
  -- full outer join 
  left join 
  (
  select *
  from `data-bi-prd-935c.bi_snd.rtl_raw_master_kpi_mtd` 
  where kpi_name in ('traffic_visitor', 'traffic_visitor_dvm','ga_prepaid', 'ga_prepaid_dvm')
   and level='agent'
   and dt_id='{dt_id}'
   and brand='3ID'
  )as b
   on a.agent_id=b.agent_id 
    and a.store_code=b.store_code
    and a.brand=b.brand
 group by all
) as a
 left join `data-nationalslsdist-prd-986g`.retail.ref_storelist as b
  on a.store_code = b.store_code and b.mth_id=left('{dt_id}',6)
 where lower(b.status_2) like '%3store%'
 union all
 select 
 left(a.dt_id, 6) as mth_id,
 b.circle,
 b.region as region_circle,
 b.store_name, 
 a.store_code,
 a.agent_id,
 a.level as agent_category,
 a.ga_dvm,
 a.visitor_dvm,
 a.ga_store, 
 a.visitor_store,
 a.ga,
 a.visitor, 
 a.conversion_rate, 
 a.brand,
 case when a.conversion_rate >= 0.1 then 1 else 0 end as agent_productivity
from (
 select 
  '{dt_id}' as dt_id,
   a.level,
   a.agent_id as agent_id,
   a.store_code as store_code,
   a.brand,
   sum(case when b.kpi_name='traffic_visitor' then b.value else 0 end) as visitor_store,
   sum(case when b.kpi_name='traffic_visitor_dvm' then b.value else 0 end) as visitor_dvm,
   sum(case when b.kpi_name='ga_postpaid' then b.value else 0 end) as ga_store,
   sum(case when b.kpi_name='ga_postpaid_dvm' then b.value else 0 end) as ga_dvm,
   sum(case when b.kpi_name in ('traffic_visitor', 'traffic_visitor_dvm') then b.value else 0 end) as visitor,
   sum(case when b.kpi_name in ('ga_postpaid', 'ga_postpaid_dvm') then b.value else 0 end) as ga,
   coalesce(safe_divide(sum(case when b.kpi_name in ('ga_postpaid', 'ga_postpaid_dvm') then b.value else 0 end), 
   	sum(case when b.kpi_name in ('traffic_visitor', 'traffic_visitor_dvm') then b.value else 0 end)),1) as conversion_rate 
 from(
  select 
  	distinct
  	level,
  	agent_id,
  	store_code,
  	brand
  from `data-bi-prd-935c.bi_snd.rtl_raw_master_kpi_mtd` 
  where kpi_name in ('traffic_visitor', 'traffic_visitor_dvm')
   and level='agent' 
   and dt_id='{dt_id}'
   and brand='IM3'
  )as a
  -- full outer join 
  left join 
  (
  select *
  from `data-bi-prd-935c.bi_snd.rtl_raw_master_kpi_mtd` 
  where kpi_name in ('traffic_visitor', 'traffic_visitor_dvm','ga_postpaid', 'ga_postpaid_dvm')
   and level='agent'
   and dt_id='{dt_id}'
   and brand='IM3'
  )as b
   on a.agent_id=b.agent_id 
    and a.store_code=b.store_code
    and a.brand=b.brand
 group by all
) as a
 left join `data-nationalslsdist-prd-986g`.retail.ref_storelist as b
  on a.store_code = b.store_code and b.mth_id=left('{dt_id}',6)
 where lower(b.status_2) like '%gerai%im3%'
 ;