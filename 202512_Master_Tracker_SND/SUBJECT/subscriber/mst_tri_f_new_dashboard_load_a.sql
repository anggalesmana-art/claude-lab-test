declare vdt_id date default @vdt_id;


create or replace table `data-bi-prd-935c.bi_stg`.tmp_uu_fu as
 select sbscrptn_ek_id , case when fu_dt = '9999-12-31' then null else fu_dt end fu_dt from(
 select distinct cast(sbscrptn_ek_id as string) sbscrptn_ek_id,
 least(coalesce(date(first_usage_dt),'9999-12-31'), least(coalesce(parse_date('%Y%m%d',cast(first_billing_usage_dt_sk_id as string)),'9999-12-31'), coalesce(date(any_event_first_usage_date),'9999-12-31'))) as fu_dt
 from `data-dtptechm-prd-c7ca.dwh`.sbscrptn_attribs)a;

 

create or replace table `data-bi-prd-935c.bi_stg`.tmp_uu_ga as
select distinct dt as ga_dt, cast(sbscrptn_ek_id as string) sbscrptn_ek_id
 from `data-bi-prd-935c.bi_mart`.fct_ioh_mvmnt_1_detail_dec21
 where tag = 'rgu30_gross_add' and dt between date('2021-10-01') and date('2021-12-31')
 union distinct
 select distinct ga_date as ga_dt, sbscrptn_ek_id
 from `data-bi-prd-935c.bi_mart`.project_ioh_fu_master_v2
 where ga_date >= '2022-01-01' and ga_date <= vdt_id;





 --
 --Data UU daily (with tenure)
 --

delete from `data-bi-prd-935c.bi_dev`.ioh_snd_master_kpi_detail where brand ='3ID' and dt_id = vdt_id and kpi in ('data_uu_less_90d', 'data_uu_90d_180d', 'data_uu_more_180d');

 
insert into `data-bi-prd-935c.bi_dev`.ioh_snd_master_kpi_detail
 select '3ID' as brand, 
 'site_id',
 site_id,
 count(distinct sbscrptn_ek_id),
 'dly',
 current_timestamp,
 case when aging_days is null then 'data_uu_more_180d'
      when aging_days <= 89 then 'data_uu_less_90d'
      when aging_days >= 90 and aging_days <= 179 then 'data_uu_90d_180d'
 else 'data_uu_more_180d' end,
 mth
 from
 (
  select distinct load_dt_sk_id as mth,
  date_diff(a.load_dt_sk_id, coalesce(c.ga_dt, d.fu_dt),day) as aging_days,
  a.sbscrptn_ek_id,
  b.site_id
  from `data-bi-prd-935c.bi_mart`.project_ioh_data_user_daily a
  left outer join
  (
   select distinct date(dt_id) dt_id, cast(sbscrptn_ek_id as string) sbscrptn_ek_id, site_id_dly as site_id
   from `data-dtptechm-prd-c7ca.dwh`.daily_fav_site_dim
   where date(dt_id) = vdt_id
  ) b on a.load_dt_sk_id = b.dt_id and a.sbscrptn_ek_id = b.sbscrptn_ek_id
  left outer join `data-bi-prd-935c.bi_stg`.tmp_uu_ga c on a.sbscrptn_ek_id = c.sbscrptn_ek_id
  left outer join `data-bi-prd-935c.bi_stg`.tmp_uu_fu d on a.sbscrptn_ek_id = d.sbscrptn_ek_id
  where a.load_dt_sk_id = vdt_id
 ) a
 group by 1,2,3,5,6,7,8;
 




delete from `data-bi-prd-935c.bi_dev`.ioh_snd_master_kpi_detail where brand ='3ID' and dt_id = vdt_id and kpi in ('data_uu');




insert into `data-bi-prd-935c.bi_dev`.ioh_snd_master_kpi_detail
 select brand, level, level_value, 
 sum(values),
 time_flag,
 current_timestamp,
 'data_uu',
 dt_id
 from `data-bi-prd-935c.bi_dev`.ioh_snd_master_kpi_detail
 where kpi in ('data_uu_less_90d', 'data_uu_90d_180d', 'data_uu_more_180d') and brand = '3ID'
 and dt_id = vdt_id
 group by 1,2,3,5,6,7,8;


  


 --
 --Data UU 30 (with tenure)
 --

delete from `data-bi-prd-935c.bi_dev`.ioh_snd_master_kpi_detail where brand ='3ID' and dt_id = vdt_id and kpi in ('data_uu30_less_90d', 'data_uu30_90d_180d', 'data_uu30_more_180d');



 
insert into `data-bi-prd-935c.bi_dev`.ioh_snd_master_kpi_detail
 select '3ID' as brand, 
 'site_id',
 site_id,
 count(distinct sbscrptn_ek_id),
 'mtd',
 current_timestamp,
 case when aging_days is null then 'data_uu30_more_180d'
      when aging_days <= 89 then 'data_uu30_less_90d'
      when aging_days >= 90 and aging_days <= 179 then 'data_uu30_90d_180d'
 else 'data_uu30_more_180d' end,
 mth
 from
 (
  select distinct mth,
  date_diff(a.mth,coalesce(a.ga_dt, a.fu_dt),day) as aging_days,
  a.sbscrptn_ek_id,
  a.site_id
  from 
  (
   select a.*,
   c.ga_dt, 
   d.fu_dt,   
   case when length(coalesce(b.site_id_30, b.site_id_90)) <= 5 then LPAD(coalesce(b.site_id_30, b.site_id_90),6,'0') else coalesce(b.site_id_30, b.site_id_90) end as site_id
   from
   (
    select distinct vdt_id as mth, a.sbscrptn_ek_id
    from `data-bi-prd-935c.bi_mart`.project_ioh_data_user_daily a
    where (load_dt_sk_id between vdt_id - interval 29 day and vdt_id)
   ) a
   left outer join
   (
    select distinct a.sbscrptn_ek_id,
    case when length(trim(site_id_30)) < 6 then LPAD(trim(site_id_30),6,'0') else trim(site_id_30) end as site_id_30,
    case when length(trim(site_id_90)) < 6 then LPAD(trim(site_id_90),6,'0') else trim(site_id_90) end as site_id_90
    from `data-bi-prd-935c.bi_mart`.ioh_subscriber_site_attribs_rolling a
    where a.dt = vdt_id
   ) b on a.sbscrptn_ek_id = b.sbscrptn_ek_id
   left outer join `data-bi-prd-935c.bi_stg`.tmp_uu_ga c on a.sbscrptn_ek_id = c.sbscrptn_ek_id
   left outer join `data-bi-prd-935c.bi_stg`.tmp_uu_fu d on a.sbscrptn_ek_id = d.sbscrptn_ek_id
  ) a
 ) a
 group by 1,2,3,5,6,7,8;
 




delete from `data-bi-prd-935c.bi_dev`.ioh_snd_master_kpi_detail where brand ='3ID' and dt_id = vdt_id and kpi in ('data_uu_30d');




insert into `data-bi-prd-935c.bi_dev`.ioh_snd_master_kpi_detail
 select brand, level, level_value, 
 sum(values),
 time_flag,
 current_timestamp,
 'data_uu_30d',
 dt_id
 from `data-bi-prd-935c.bi_dev`.ioh_snd_master_kpi_detail
 where kpi in ('data_uu30_less_90d', 'data_uu30_90d_180d', 'data_uu30_more_180d') and brand = '3ID'
 and dt_id = vdt_id
 group by 1,2,3,5,6,7,8;





 --
 --Prepaid RGU 30D 
 --
 
delete from `data-bi-prd-935c.bi_dev`.ioh_snd_master_kpi_detail where brand ='3ID' and dt_id = vdt_id and kpi in ('pre_rgu_30d_less_90d', 'pre_rgu_30d_90d_180d', 'pre_rgu_30d_more_180d');



 
insert into `data-bi-prd-935c.bi_dev`.ioh_snd_master_kpi_detail
 select '3ID' as brand, 
 'site_id',
 site_id,
 count(distinct sbscrptn_ek_id),
 'mtd',
 current_timestamp,
 case when aging_days is null then 'pre_rgu_30d_more_180d'
     when aging_days <= 89 then 'pre_rgu_30d_less_90d'
     when aging_days >= 90 and aging_days <= 179 then 'pre_rgu_30d_90d_180d'
 else 'pre_rgu_30d_more_180d' end,
 vdt_id
 from `data-bi-prd-935c.bi_mart`.fct_RGU30_Aging_Circle a
 where a.dt = vdt_id
 group by 1,2,3,5,6,7,8;
 




delete from `data-bi-prd-935c.bi_dev`.ioh_snd_master_kpi_detail where brand ='3ID' and dt_id = vdt_id and kpi in ('pre_rgu_30d');




insert into `data-bi-prd-935c.bi_dev`.ioh_snd_master_kpi_detail
 select brand, level, level_value, 
 sum(values),
 time_flag,
 current_timestamp,
 'pre_rgu_30d',
 dt_id
 from `data-bi-prd-935c.bi_dev`.ioh_snd_master_kpi_detail
 where kpi in ('pre_rgu_30d_less_90d', 'pre_rgu_30d_90d_180d', 'pre_rgu_30d_more_180d') and brand = '3ID'
 and dt_id = vdt_id
 group by 1,2,3,5,6,7,8;




 

 --
 --Subscribers on a Data Pack 
 --


create or replace table `data-bi-prd-935c.bi_stg`.tmp_data_pack_subs as
 select vdt_id as mth_id, msisdn
 from `data-bi-prd-935c.bi_mart`.fct_pcrf_datapack_msisdn
 where dt between date_trunc(vdt_id,month) and vdt_id;



create or replace table `data-bi-prd-935c.bi_stg`.tmp_data_pack_subs_2 as
 select a.mth_id, a.msisdn, cast(b.sbscrptn_ek_id as string) sbscrptn_ek_id
 from `data-bi-prd-935c.bi_stg`.tmp_data_pack_subs a
 left outer join `data-dtptechm-prd-c7ca.dwh`.sbscrptn_attribs b on a.msisdn = b.sbscrptn_msisdn and b.rank_ind = 1;




delete from `data-bi-prd-935c.bi_dev`.ioh_snd_master_kpi_detail where brand ='3ID' and dt_id = vdt_id and kpi in ('subs_data_pack');




insert into `data-bi-prd-935c.bi_dev`.ioh_snd_master_kpi_detail
 select '3ID' as brand, 
 'site_id',
 case when length(coalesce(b.site_id_30, b.site_id_90)) <= 5 then LPAD(coalesce(b.site_id_30, b.site_id_90),6,'0') else coalesce(b.site_id_30, b.site_id_90) end,
 count(distinct a.msisdn),
 'mtd',
 current_timestamp,
 'subs_data_pack',
 mth_id
 from `data-bi-prd-935c.bi_stg`.tmp_data_pack_subs_2 a
 left outer join
 (
  select distinct sbscrptn_ek_id, site_id_30, site_id_90
  from `data-bi-prd-935c.bi_mart`.ioh_subscriber_site_attribs_rolling
  where dt = vdt_id
 ) b on a.sbscrptn_ek_id = b.sbscrptn_ek_id
 where a.mth_id = vdt_id
 group by 1,2,3,5,6,7,8;





 --
 --Data Traffic
 --

delete from `data-bi-prd-935c.bi_dev`.ioh_snd_master_kpi_detail where brand ='3ID' and dt_id = vdt_id and kpi in ('data_traffic');




insert into `data-bi-prd-935c.bi_dev`.ioh_snd_master_kpi_detail
 select '3ID' as brand, 
 'site_id',
 site_id,
cast(sum(a.value)/1024 as numeric),
 'dly',
 current_timestamp,
 'data_traffic',
 vdt_id
 from `data-bi-prd-935c.bi_mart`.project_ioh_kpi_daily_tracker_site a
 where kpi_code in ('data traffic')
 and load_dt_sk_id = vdt_id
 group by 1,2,3,5,6,7,8;





 --
 --Gross Churn - Abs
 --
 
delete from `data-bi-prd-935c.bi_dev`.ioh_snd_master_kpi_detail where brand ='3ID' and dt_id = vdt_id and kpi in ('churn_less_90d', 'churn_90d_180d', 'churn_more_180d');




insert into `data-bi-prd-935c.bi_dev`.ioh_snd_master_kpi_detail
 select '3ID' as brand, 
 'site_id',
 site_id,
 count(distinct a.sbscrptn_ek_id),
 'dly',
 current_timestamp,
 case when aon_slab in ('a.<=30D', 'b.<=60D', 'c.<=90D') then 'churn_less_90d' 
      when aon_slab in ('d.<=120D', 'e.<=180D') then 'churn_90d_180d'
      when aon_slab in ('f.>180D') then 'churn_more_180d'
 else 'churn_more_180d' end,
 vdt_id
 from `data-bi-prd-935c.bi_mart`.fct_gc_aon_rev_3 a
 where a.dt = vdt_id
 group by 1,2,3,5,6,7,8;


 


delete from `data-bi-prd-935c.bi_dev`.ioh_snd_master_kpi_detail where brand ='3ID' and dt_id = vdt_id and kpi in ('churn');




insert into `data-bi-prd-935c.bi_dev`.ioh_snd_master_kpi_detail
 select brand, level, level_value, 
 sum(values),
 time_flag,
 current_timestamp,
 'churn',
 dt_id
 from `data-bi-prd-935c.bi_dev`.ioh_snd_master_kpi_detail
 where kpi in ('churn_less_90d', 'churn_90d_180d', 'churn_more_180d') and brand = '3ID'
 and dt_id = vdt_id
 group by 1,2,3,5,6,7,8;





 --
 --Churn Back - Abs
 --

delete from `data-bi-prd-935c.bi_dev`.ioh_snd_master_kpi_detail where brand ='3ID' and dt_id = vdt_id and kpi in ('churn_back_90d_180d', 'churn_back_more_180d');




insert into `data-bi-prd-935c.bi_dev`.ioh_snd_master_kpi_detail
 select '3ID' as brand, 
 'site_id',
 site_id,
 count(distinct a.sbscrptn_ek_id),
 'dly',
 current_timestamp,
 case when aon_slab in ('a.<=30D', 'b.<=60D', 'c.<=90D', 'd.<=120D', 'e.<=180D') then 'churn_back_90d_180d' --because for churn back, the slab is >90D 
      when aon_slab in ('f.>180D') then 'churn_back_more_180d'
 else 'churn_back_more_180d' end,
 vdt_id
 from `data-bi-prd-935c.bi_mart`.fct_cb_aon_rev a
 where a.dt = vdt_id
 group by 1,2,3,5,6,7,8;





delete from `data-bi-prd-935c.bi_dev`.ioh_snd_master_kpi_detail where brand ='3ID' and dt_id = vdt_id and kpi in ('churn_back');




insert into `data-bi-prd-935c.bi_dev`.ioh_snd_master_kpi_detail
 select brand, level, level_value, 
 sum(values),
 time_flag,
 current_timestamp,
 'churn_back',
 dt_id
 from `data-bi-prd-935c.bi_dev`.ioh_snd_master_kpi_detail
 where kpi in ('churn_back_90d_180d', 'churn_back_more_180d') and brand = '3ID'
 and dt_id = vdt_id
 group by 1,2,3,5,6,7,8;





 --
 --Closing Subs
 --

delete from `data-bi-prd-935c.bi_dev`.ioh_snd_master_kpi_detail where brand ='3ID' and dt_id = vdt_id and kpi in ('pre_rgu_90d_less_90d', 'pre_rgu_90d_90d_180d', 'pre_rgu_90d_more_180d');




insert into `data-bi-prd-935c.bi_dev`.ioh_snd_master_kpi_detail
 select '3ID' as brand, 
 'site_id',
 site_id,
 count(distinct a.sbscrptn_ek_id),
 'mtd',
 current_timestamp,
 case when aging_days is null then 'pre_rgu_90d_more_180d'
      when aging_days <= 89 then 'pre_rgu_90d_less_90d'
      when aging_days >= 90 and aging_days <= 179 then 'pre_rgu_90d_90d_180d'
 else 'pre_rgu_90d_more_180d' end,
 vdt_id
 from `data-bi-prd-935c.bi_mart`.fct_RGU90_Aging_Circle a
 where a.dt = vdt_id
 group by 1,2,3,5,6,7,8;





delete from `data-bi-prd-935c.bi_dev`.ioh_snd_master_kpi_detail where brand ='3ID' and dt_id = vdt_id and kpi in ('pre_rgu_90d');




insert into `data-bi-prd-935c.bi_dev`.ioh_snd_master_kpi_detail
 select brand, level, level_value, 
 sum(values),
 time_flag,
 current_timestamp,
 'pre_rgu_90d',
 dt_id
 from `data-bi-prd-935c.bi_dev`.ioh_snd_master_kpi_detail
 where kpi in ('pre_rgu_90d_less_90d', 'pre_rgu_90d_90d_180d', 'pre_rgu_90d_more_180d') and brand = '3ID'
 and dt_id = vdt_id
 group by 1,2,3,5,6,7,8;





 --
 --Data Rev
 --

delete from `data-bi-prd-935c.bi_dev`.ioh_snd_master_kpi_detail where brand ='3ID' and dt_id = vdt_id and kpi in ('tot_rev_data','tot_rev_non_data') 
and time_flag ='dly';


insert into `data-bi-prd-935c.bi_dev`.ioh_snd_master_kpi_detail
SELECT '3ID' as brand,
    'site_id' level,
    site_id level_value,
    cast(sum(value) as numeric),
    'dly' time_flag,
    timestamp(current_datetime('+7')) insert_date,
    CASE WHEN kpi_code = 'rev_nondata' THEN 'tot_rev_non_data' ELSE 'tot_rev_data' END kpi,
    load_dt_sk_id dt_id 
    FROM
(
 select load_dt_sk_id, entity, kpi_code, definition, dt, site_id, sum(rev) as value, remark, dtm
 from
 (
  select dt_id as load_dt_sk_id, 'H3I' as entity, 'rev_nondata' as kpi_code, 'IOH' as definition, date(dt_id) as dt,
  site_id,
  sum(
  case when (revenue_flg = 'PREPAID' or revenue_flg is null) then
  (
  coalesce(loan_balance_fee,0)+
  coalesce(balance_transfer_revenue,0)+
  coalesce(ccn_vas_revenue,0)+
  coalesce(mobo_sp_vas_rev,0)+
  coalesce(mobo_rita_vas_rev,0)+
  coalesce(ccn_sms_revenue,0)+
  coalesce(fdv_sms_rev,0)+
  coalesce(mobo_sp_sms_rev,0)+
  coalesce(mobo_rita_sms_rev,0)+
  coalesce(other_mms_revenue,0)+
  coalesce(mobo_sp_voice_rev,0)+
  coalesce(fdv_voice_rev,0)+
  coalesce(mobo_rita_voice_rev,0)+
  coalesce(ccn_voice_revenue,0)+
  coalesce(ccn_voice_rev_ppu_roaming,0)+
  coalesce(ccn_sms_rev_ppu_roaming,0)+
  coalesce(mobo_evc_roaming_rev,0)+
  coalesce(other_roaming_rev,0))/1.11
  --coalesce(other_payu_revenue,0))/1.11 --Move to "Organic + PGI" and "Non Data" using table `data-dtptechm-prd-c7ca.dwh`.h3i_revenue_per_site_extended_others_detail
  else
  (
  coalesce(loan_balance_fee,0)+
  coalesce(balance_transfer_revenue,0)+
  coalesce(ccn_vas_revenue,0)+
  coalesce(mobo_sp_vas_rev,0)+
  coalesce(mobo_rita_vas_rev,0)+
  coalesce(ccn_sms_revenue,0)+
  coalesce(fdv_sms_rev,0)+
  coalesce(mobo_sp_sms_rev,0)+
  coalesce(mobo_rita_sms_rev,0)+
  coalesce(other_mms_revenue,0)+
  coalesce(mobo_sp_voice_rev,0)+
  coalesce(fdv_voice_rev,0)+
  coalesce(mobo_rita_voice_rev,0)+
  coalesce(ccn_voice_revenue,0)+
  coalesce(ccn_voice_rev_ppu_roaming,0)+
  coalesce(ccn_sms_rev_ppu_roaming,0)+
  coalesce(mobo_evc_roaming_rev,0)+
  coalesce(other_roaming_rev,0)
  --coalesce(other_payu_revenue,0) --Move to "Organic + PGI" and "Non Data" using table `data-dtptechm-prd-c7ca.dwh`.h3i_revenue_per_site_extended_others_detail
  )
  end ) as rev,
  '' as remark, 
  current_timestamp as dtm
  from `data-dtptechm-prd-c7ca.dwh`.h3i_revenue_per_site_extended
  where date(dt_id) = vdt_id
  group by 1,2,3,4,5,6,8,9

  union all

  select date(dt_id) as load_dt_sk_id, 'H3I' as entity, 'rev_nondata' as kpi_code, 'IOH' as definition, date(dt_id) as dt,
  physical_site_id as site_id,
  sum(case when (revenue_flag = 'PREPAID' or revenue_flag is null) then revenue/1.11 else revenue end) as rev,
  '' as remark, 
  current_timestamp as dtm
  from `data-dtptechm-prd-c7ca.dwh`.h3i_revenue_per_site_extended_others_detail a
  where date(dt_id) = vdt_id
  --and service_type = 'ROAMING'
  and process_nm in ('EVC MARKUP',
  'MARKUP_RITA',
  'MARKUP_UNLOCK',
  'BIMA MARKUP'
  ) and service_type <> 'ROAMING' --exclude roaming because has been counted on other_roaming_rev
  group by 1,2,3,4,5,6,8,9
 
  union all

  select date(dt_id) as load_dt_sk_id, 'H3I' as entity, 'rev_nondata' as kpi_code, 'IOH' as definition, date(dt_id) as dt,
  physical_site_id as site_id,
  sum(case when (revenue_flag = 'PREPAID' or revenue_flag is null) then revenue/1.11 else revenue end) as rev,
  '' as remark, 
  current_timestamp as dtm
  from `data-dtptechm-prd-c7ca.dwh`.h3i_revenue_per_site_extended_others_detail a
  where date(dt_id) = vdt_id
  and service_type = 'OTHER_VAS' 
  and process_nm in ('ONE-OFF CDR') --'TOPUP'
  group by 1,2,3,4,5,6,8,9
  
  union all

  select date(dt_id) as load_dt_sk_id, 'H3I' as entity, 'rev_nondata' as kpi_code, 'IOH' as definition, date(dt_id) as dt,
  physical_site_id as site_id,
  sum(case when (revenue_flag = 'PREPAID' or revenue_flag is null) then revenue/1.11 else revenue end) as rev,
  '' as remark, 
  current_timestamp as dtm
  from `data-dtptechm-prd-c7ca.dwh`.h3i_revenue_per_site_extended_others_detail a
  where date(dt_id) = vdt_id
  and process_nm in ('ADDON_PULSA', 'CEPEK AMORTIZATION', 'MAIN_BALANCE_OTHERS_ADJUSTMENT', 'RITA_TOPUP', 'TOPUP', 'UNTAGGED_COMMISSION')
  --and process_nm in ('ADDON_PULSA', 'CEPEK AMORTIZATION', 'RITA_TOPUP', 'TOPUP', 'UNTAGGED_COMMISSION')
  and service_type_detail in ('BROADBAND', 'VAS_PARTNER', 'OTHERS')
  group by 1,2,3,4,5,6,8,9
  
  union all
  
  --Add this start 01 Jun 2025 onwards
  
  select date(dt_id) as load_dt_sk_id, 'H3I' as entity, 'rev_nondata' as kpi_code, 'IOH' as definition, date(dt_id) as dt,
  physical_site_id,
  sum(case when (revenue_flag = 'PREPAID' or revenue_flag is null) then revenue/1.11 else revenue end) as rev,
  '' as remark, 
  current_timestamp as dtm
  from `data-dtptechm-prd-c7ca.dwh`.h3i_revenue_per_site_extended_others_detail a
  where date(dt_id) = vdt_id
  and service_type = 'OTHER_PAYU' and service_type_detail in ('GPRS','GPRS_PACKAGE') and process_nm in ('EVC MARKUP', 'MARKUP_RITA', 'MARKUP_UNLOCK', 'BIMA MARKUP')
  group by 1,2,3,4,5,6,8,9
 ) a
 group by 1,2,3,4,5,6,8,9
 union all 
  select load_dt_sk_id, entity, kpi_code, definition, dt, site_id, sum(rev) as rev, remark, dtm
 from
 (
  select date(dt_id) as load_dt_sk_id, 'H3I' as entity, 'rev_organic' as kpi_code, 'IOH' as definition, date(dt_id) as dt,
  site_id,
  sum(case when (revenue_flg = 'PREPAID' or revenue_flg is null) then 
  (coalesce(ccn_data_revenue,0) + coalesce(loan_package_revenue,0))/1.11 
  else coalesce(ccn_data_revenue,0) + coalesce(loan_package_revenue,0) end) as rev,
  '' as remark, 
  current_timestamp as dtm
  from `data-dtptechm-prd-c7ca.dwh`.h3i_revenue_per_site_extended
  where date(dt_id) = vdt_id
  group by 1,2,3,4,5,6,8,9 
 ) a
 group by 1,2,3,4,5,6,8,9
 union all 
  select load_dt_sk_id, entity, kpi_code, definition, dt, site_id, sum(rev) as rev, remark, dtm
 from
 (
  select date(dt_id) as load_dt_sk_id, 'H3I' as entity, 'rev_mobo' as kpi_code, 'IOH' as definition, date(dt_id) as dt,
  site_id,
  sum(case when (revenue_flg = 'PREPAID' or revenue_flg is null) then 
  (coalesce(mobo_sp_data_rev,0)+
  coalesce(fdv_data_rev,0)+ 
  coalesce(voucher_forfeit_revenue,0)+ --this has included (service_type = 'OTHER_VOUCHER_FORFEIT' and service_type_detail = 'PAYU')
  coalesce(mobo_rita_data_rev,0)+
  coalesce(mobo_evc_rev,0))/1.11
  else 
  (coalesce(mobo_sp_data_rev,0)+
  coalesce(fdv_data_rev,0)+ 
  coalesce(voucher_forfeit_revenue,0)+ --this has included (service_type = 'OTHER_VOUCHER_FORFEIT' and service_type_detail = 'PAYU')
  coalesce(mobo_rita_data_rev,0)+
  coalesce(mobo_evc_rev,0))
  end) as rev,
  '' as remark, 
  current_timestamp as dtm
  from `data-dtptechm-prd-c7ca.dwh`.h3i_revenue_per_site_extended
  where date(dt_id) = vdt_id
  group by 1,2,3,4,5,6,8,9

  union all

  select date(dt_id) as load_dt_sk_id, 'H3I' as entity, 'rev_mobo' as kpi_code, 'IOH' as definition, date(dt_id) as dt,
  physical_site_id,
  sum(case when (revenue_flag = 'PREPAID' or revenue_flag is null) then revenue/1.11 else revenue end) as rev,
  '' as remark, 
  current_timestamp as dtm
  from `data-dtptechm-prd-c7ca.dwh`.h3i_revenue_per_site_extended_others_detail a
  where date(dt_id) = vdt_id
  and process_nm in ('RITA_P3PRICE_AMORT')
  group by 1,2,3,4,5,6,8,9 
 ) a
 group by 1,2,3,4,5,6,8,9
 


) b
   GROUP BY 1,2,3,5,7,8; 



 --Total Revenue

delete from `data-bi-prd-935c.bi_dev`.ioh_snd_master_kpi_detail where brand ='3ID' and dt_id = vdt_id and kpi in ('tot_rev') and time_flag ='dly';




insert into `data-bi-prd-935c.bi_dev`.ioh_snd_master_kpi_detail
 select brand, level, level_value, 
 sum(values),
 time_flag,
 current_timestamp,
 'tot_rev',
 dt_id
 from `data-bi-prd-935c.bi_dev`.ioh_snd_master_kpi_detail
 where kpi in ('tot_rev_data', 'tot_rev_non_data') and brand = '3ID'
 and dt_id = vdt_id and time_flag ='dly'
 group by 1,2,3,5,6,7,8;





 --
 --Data Traffic (MTD)
 --

delete from `data-bi-prd-935c.bi_dev`.ioh_snd_master_kpi_detail where brand ='3ID' and dt_id = vdt_id and kpi in ('data_traffic_mtd');




insert into `data-bi-prd-935c.bi_dev`.ioh_snd_master_kpi_detail
 select brand, level, level_value, 
 cast(sum(values) as numeric),
 'mtd',
 current_timestamp,
 concat(kpi,'_mtd'),
 vdt_id
 from `data-bi-prd-935c.bi_dev`.ioh_snd_master_kpi_detail
 where kpi in ('data_traffic') and brand = '3ID'
 and dt_id between date_trunc(vdt_id,month) and vdt_id and time_flag ='dly'
 group by 1,2,3,5,6,7,8;





 --
 --Gross Churn - Abs (MTD)
 --
 
delete from `data-bi-prd-935c.bi_dev`.ioh_snd_master_kpi_detail where brand ='3ID' and dt_id = vdt_id and kpi in ('churn_mtd', 'churn_less_90d_mtd', 'churn_90d_180d_mtd', 'churn_more_180d_mtd');




insert into `data-bi-prd-935c.bi_dev`.ioh_snd_master_kpi_detail
 select brand, level, level_value, 
 sum(values),
 'mtd',
 current_timestamp,
 concat(kpi,'_mtd'),
 vdt_id
 from `data-bi-prd-935c.bi_dev`.ioh_snd_master_kpi_detail
 where kpi in ('churn', 'churn_less_90d', 'churn_90d_180d', 'churn_more_180d') and brand = '3ID'
 and dt_id between date_trunc(vdt_id,month) and vdt_id
 group by 1,2,3,5,6,7,8;


 


 --
 --Churn Back - Abs (MTD)
 --

delete from `data-bi-prd-935c.bi_dev`.ioh_snd_master_kpi_detail where brand ='3ID' and dt_id = vdt_id and kpi in ('churn_back_mtd', 'churn_back_90d_180d_mtd', 'churn_back_more_180d_mtd');




insert into `data-bi-prd-935c.bi_dev`.ioh_snd_master_kpi_detail
 select brand, level, level_value, 
 sum(values),
 'mtd',
 current_timestamp,
 concat(kpi,'_mtd'),
 vdt_id
 from `data-bi-prd-935c.bi_dev`.ioh_snd_master_kpi_detail
 where kpi in ('churn_back', 'churn_back_90d_180d', 'churn_back_more_180d') and brand = '3ID'
 and dt_id between date_trunc(vdt_id,month) and vdt_id
 group by 1,2,3,5,6,7,8;





 --
 --Data Rev (MTD)
 --

delete from `data-bi-prd-935c.bi_dev`.ioh_snd_master_kpi_detail where brand ='3ID' and dt_id = vdt_id and kpi in ('tot_rev_data_mtd');




insert into `data-bi-prd-935c.bi_dev`.ioh_snd_master_kpi_detail
 select brand, level, level_value, 
 sum(values),
 'mtd',
 current_timestamp,
 concat(kpi,'_mtd'),
 vdt_id
 from `data-bi-prd-935c.bi_dev`.ioh_snd_master_kpi_detail
 where kpi in ('tot_rev_data') and brand = '3ID'
 and dt_id between date_trunc(vdt_id,month) and vdt_id
 and time_flag ='dly' and time_flag ='dly'
 group by 1,2,3,5,6,7,8;





 --
 --Non Data Rev (MTD)
 --

delete from `data-bi-prd-935c.bi_dev`.ioh_snd_master_kpi_detail where brand ='3ID' and dt_id = vdt_id and kpi in ('tot_rev_non_data_mtd');




insert into `data-bi-prd-935c.bi_dev`.ioh_snd_master_kpi_detail
 select brand, level, level_value, 
 sum(values),
 'mtd',
 current_timestamp,
 concat(kpi,'_mtd'),
 vdt_id
 from `data-bi-prd-935c.bi_dev`.ioh_snd_master_kpi_detail
 where kpi in ('tot_rev_non_data') and brand = '3ID'
 and dt_id between date_trunc(vdt_id,month) and vdt_id
 and time_flag ='dly'
 group by 1,2,3,5,6,7,8;





 --Total Revenue (MTD)

delete from `data-bi-prd-935c.bi_dev`.ioh_snd_master_kpi_detail where brand ='3ID' and dt_id = vdt_id and kpi in ('tot_rev_mtd');




insert into `data-bi-prd-935c.bi_dev`.ioh_snd_master_kpi_detail
 select brand, level, level_value, 
 sum(values),
 'mtd',
 current_timestamp,
 concat(kpi,'_mtd'),
 vdt_id
 from `data-bi-prd-935c.bi_dev`.ioh_snd_master_kpi_detail
 where kpi in ('tot_rev') and brand = '3ID'
 and dt_id between date_trunc(vdt_id,month) and vdt_id and time_flag ='dly' and  level='site_id'
 group by 1,2,3,5,6,7,8;




 --RGU90 Opening

delete from `data-bi-prd-935c.bi_dev`.ioh_snd_master_kpi_detail where brand = '3ID' and kpi in('pre_rgu_90d_90d_180d_m1', 'pre_rgu_90d_more_180d_m1', 'pre_rgu_90d_less_90d_m1') and dt_id = vdt_id;


 
 
insert into `data-bi-prd-935c.bi_dev`.ioh_snd_master_kpi_detail
 select brand, level, level_value, values, time_flag, timestamp(current_datetime('+7')),
 case when kpi = 'pre_rgu_90d_more_180d' then 'pre_rgu_90d_more_180d_m1'
      when kpi = 'pre_rgu_90d_less_90d' then 'pre_rgu_90d_less_90d_m1'
      when kpi = 'pre_rgu_90d_90d_180d' then 'pre_rgu_90d_90d_180d_m1'
 end as kpi, 
 vdt_id
 from `data-bi-prd-935c.bi_dev`.ioh_snd_master_kpi_detail a
 where kpi in ('pre_rgu_90d_90d_180d', 'pre_rgu_90d_more_180d', 'pre_rgu_90d_less_90d') and brand = '3ID'
 and level = 'site_id'
 and lower(time_flag) = 'mtd'
 and dt_id = date_trunc(vdt_id,month) - interval 1 day;



 

delete from `data-bi-prd-935c.bi_dev`.ioh_snd_master_kpi_detail where brand = '3ID' and kpi in('pre_rgu_90d_m1') and dt_id = vdt_id;




insert into `data-bi-prd-935c.bi_dev`.ioh_snd_master_kpi_detail
 select brand, level, level_value, values, time_flag, timestamp(current_datetime('+7')),
 'pre_rgu_90d_m1',
 vdt_id
 from `data-bi-prd-935c.bi_dev`.ioh_snd_master_kpi_detail a 
 where kpi in ('pre_rgu_90d') and brand = '3ID'
 and level = 'site_id'
 and lower(time_flag) = 'mtd'
 and dt_id = date_trunc(vdt_id,month) - interval 1 day;
                                                                                                                                        

