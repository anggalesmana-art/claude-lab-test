DECLARE vdt_id DATE DEFAULT @vdt_id;

-- DECLARE vdt_id DATE DEFAULT @vdt_id;

-- Prepare Tables

DELETE FROM `data-bi-prd-935c.bi_mart.project_ioh_bima_daily_subs`
WHERE dt = vdt_id;

insert into `data-bi-prd-935c.bi_mart.project_ioh_bima_daily_subs`
			select cast(vdt_id as date) as dt, sbscrptn_msisdn from (
	select    
			case    when replace(replace(replace(trim(subscriber_msisdn),' ',''),'+',''),'-','') like '089%' then '62' || substring(subscriber_msisdn,2,length(subscriber_msisdn))
				when replace(replace(replace(trim(subscriber_msisdn),' ',''),'+',''),'-','') like 'O89%' then '62' || substring(subscriber_msisdn,2,length(subscriber_msisdn))
				when replace(replace(replace(trim(subscriber_msisdn),' ',''),'+',''),'-','') like '89%' then '62' || subscriber_msisdn
				else replace(replace(replace(trim(subscriber_msisdn),' ',''),'+',''),'-','')
			end as sbscrptn_msisdn
		from `data-bi-prd-935c.bi_mart.bima_log_fct`
		where load_dt_sk_id = vdt_id and
			coalesce(trim(subscriber_msisdn),'N/A') <> 'N/A'
			and trim(subscriber_msisdn) <> ''
			and upper(controller_class) <> 'LOGIN'
			) x
group by 1,2;	

delete from `data-bi-prd-935c.bi_mart.project_ioh_bima_monthly_subs`
WHERE dt = vdt_id;

insert into `data-bi-prd-935c.bi_mart.project_ioh_bima_monthly_subs`
SELECT 
  cast(vdt_id as date) AS dt, 
  sbscrptn_msisdn
FROM `data-bi-prd-935c.bi_mart`.project_ioh_bima_daily_subs
WHERE dt <= vdt_id
  AND dt >= DATE_SUB(vdt_id, INTERVAL 30 DAY)
GROUP BY dt, sbscrptn_msisdn;
  
delete from `data-bi-prd-935c.bi_mart.project_ioh_kpi_daily_tracker_national_wise`
where kpi_code in (
'actvn_myim3_bima',
'dau_myim3_bima',
'ins_myim3_bima',
'mau_myim3_bima',
'rev_myim3_bima'
)
and load_dt_sk_id=vdt_id;


insert into `data-bi-prd-935c.bi_mart.project_ioh_kpi_daily_tracker_national_wise`
select 
cast(trx_dt_sk_id as date) trx_dt_sk_id
,'H3I' as entity 
,case when type = 'acq' then 'actvn_myim3_bima' 
      when type = 'monthly' then 'mau_myim3_bima'
      when type = 'daily' then 'dau_myim3_bima'
      when type = 'Revenue' then 'rev_myim3_bima'
      when type ='install' then 'ins_myim3_bima'
      end as type
,'IOH' as definition
,cast(vdt_id as date)
,sum(metric) 
FROM
(
select cast(trx_dt_sk_id as date) as trx_dt_sk_id, 'Revenue' type,  sum(amount) as metric
from `data-dtptechm-prd-c7ca.dwh.odp_trx_merge_dly_fct` trx 
where cast(trx_dt_sk_id as date) = vdt_id 
-- and source_ctgry_2 in ('TRX_SUBSCRIBER_PURCHASE','TRX_POSTPAID_PAYMENT') and 
  and trx_status = 'Success'
  and trx_type_1 <> 'Unsubscribe' -- Total Buying
  group by 1
union all
select cast(dt as date) as dt, 'monthly', count(distinct sbscrptn_msisdn)
from `data-bi-prd-935c.bi_mart.project_ioh_bima_monthly_subs`
where dt = vdt_id
group by 1
union all
select cast(dt as date) as dt, 'daily', count(distinct sbscrptn_msisdn)
from `data-bi-prd-935c.bi_mart.project_ioh_bima_daily_subs`
where dt = vdt_id
group by 1
union all 
select cast(dt as date) as dt, 'install', count(1)
from
(
select CAST(updated_at AS date) dt, msisdn, row_number() over(partition by msisdn order by updated_at) rank
from `data-dtptechm-prd-c7ca.stg.stg_subcriber_app_version`
) a
where rank = 1
and dt = vdt_id
group by 1
order by 1
) x 
group by 1,2,3,4,5;

