-- Prepare Tables
DECLARE vdt_id DATE DEFAULT @vdt_id;

delete from `data-bi-prd-935c.bi_mart.project_ioh_kpi_daily_tracker_national_wise`
where load_dt_sk_id = vdt_id 
and definition = 'IOH'
and kpi_code in ('vlr_daily','vlr_daily_5g','vlr_daily_4g','vlr_daily_3g','vlr_daily_2g','vlr_daily_other');


insert into `data-bi-prd-935c.bi_mart.project_ioh_kpi_daily_tracker_national_wise`
WITH tmp_ggsn_band_daily
as
(select *
from (select sbscrptn_msisdn, band, row_number() over(partition by sbscrptn_msisdn order by case when band is null then '0G' else band end desc, dt_sk_id desc, substring(served_imeisv,1,14)) rank
from `data-bi-prd-935c.bi_mart.project_ioh_data_imei_usage` a
   left join (select tac, case when final_device_band_type like 'LTE%' then '4G' 
    else substring(final_device_band_type,1,2)
       end band
from `data-bi-prd-935c.bi_mart.ioh_tac_dim_extd`
where final_device_band_type <> 'N'
group by 1,2) b on substring(a.served_imeisv,1,8) = b.tac
where a.dt_sk_id = vdt_id 
) a
where rank = 1),
tmp_ggsn_usage_daily as (
with subs as (select * from `data-dtptechm-prd-c7ca.dwh.sbscrptn_attribs`)
select dt_sk_id, 
       b.sbscrptn_msisdn,
       case when product_id = 8 then 'prepaid' else 'postpaid' end prepaid_flag,
      SUM(case when rat_type = '6' THEN (coalesce(usage,0)) ELSE 0 END)/(1024*1024*1024) as LTE_Usage,                                       
      SUM(case when rat_type IN ('1','5') THEN (coalesce(usage,0)) ELSE 0 END)/(1024*1024*1024) as USAGE_3G,                           
      SUM(case when rat_type = '2' THEN (coalesce(usage,0)) ELSE 0 END)/(1024*1024*1024) as USAGE_2G,
      sum(usage) usage,
      SUM(case when gprs_rating_grp_nm in ('Normal GPRS Modifier','Pay as you go - GPPEK') THEN (coalesce(usage,0)) ELSE 0 END) as USAGE_PYU,
      SUM(case when coalesce(gprs_rating_grp_nm,'') not in ('GPRS Default Modifier','Pay as you go - GPPEK') THEN (coalesce(usage,0)) ELSE 0 END) as USAGE_package
from `data-bi-prd-935c.bi_mart.project_ioh_data_imei_usage` a 
left join subs b on a.sbscrptn_ek_id = b.sbscrptn_ek_id 
where
dt_sk_id = vdt_id and 
tool_of_trade_ind = 'N'
and apn_for_gprs_nm in  ('3data','3gprs','black')
group by 1,2,3
)
select cast(vdt_id as date) load_dt_sk_id, 
       'H3I',
       'vlr_daily_'||
       lower(case when vlr.band = '5G' then '4G' /* mom 5 jan 22 redirect to 4g due to not yet implement 5g*/
    when ggsn.band = '5G' then '4G'
    when vlr.band = '4G' then '4G'
    when ggsn.band = '4G' then '4G'
    when LTE_Usage > 0 then '4G'
    when vlr.band = '3G' then '3G'
    when ggsn.band = '3G' then '3G'
    when USAGE_3G > 0 then '3G'
    when vlr.band = '2G' then '2G'
    when ggsn.band = '2G' then '2G'
    when USAGE_2G > 0 then '2G'
    else 'Other'
       end),
       'IOH',
       cast(vdt_id as date),
       count(1)
from (
with subs as (select * from `data-dtptechm-prd-c7ca.dwh.sbscrptn_attribs`)
select msisdn, band, row_number() over(partition by msisdn order by load_dt desc, substring(imei,1,14)) rank
from `data-bi-prd-935c.bi_mart.fct_vlr_daily` a
left join (select tac, case when final_device_band_type like 'LTE%' then '4G' 
    else substring(final_device_band_type,1,2)
       end band
from `data-bi-prd-935c.bi_mart`.ioh_tac_dim_extd
where final_device_band_type <> 'N' 
group by 1,2) b on substring(a.imei,1,8) = b.tac
left join 
subs c on a.msisdn = c.sbscrptn_msisdn and c.rank_ind =1 
where c.tool_of_trade_ind = 'N'
and a.load_dt = vdt_id 
) vlr
left join tmp_ggsn_band_daily ggsn on vlr.msisdn = ggsn.sbscrptn_msisdn
left join tmp_ggsn_usage_daily usage on vlr.msisdn = usage.sbscrptn_msisdn
where vlr.rank = 1
group by 1,2,3,4,5;


insert into `data-bi-prd-935c.bi_mart.project_ioh_kpi_daily_tracker_national_wise`
select cast(load_dt_sk_id as date), entity, 'vlr_daily' kpi_code, definition, date, sum(value)
from `data-bi-prd-935c.bi_mart.project_ioh_kpi_daily_tracker_national_wise`
where cast(load_dt_sk_id as date)= vdt_id  and definition = 'IOH'and kpi_code in ('vlr_daily_5g','vlr_daily_4g','vlr_daily_3g','vlr_daily_2g','vlr_daily_other')
group by 1,2,3,4,5;

delete from `data-bi-prd-935c.bi_mart`.project_ioh_vlr where dt_sk_id = vdt_id ;

insert into `data-bi-prd-935c.bi_mart`.project_ioh_vlr
with subs as (select * from `data-dtptechm-prd-c7ca.dwh.sbscrptn_attribs`)
select load_dt, 
       vlr.msisdn,
       vlr.sbscrptn_ek_id,
       cast(null as string),
       gci
from (select load_dt, msisdn, sbscrptn_ek_id, gci
from `data-bi-prd-935c.bi_mart.fct_vlr_daily` a
left join 
subs c on a.msisdn = c.sbscrptn_msisdn and c.rank_ind =1 
where c.tool_of_trade_ind = 'N'
and load_dt = vdt_id  
) vlr;

