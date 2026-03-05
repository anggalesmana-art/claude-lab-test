declare vdt_id date default @vdt_id;

 --VLR Daily

 delete from `data-bi-prd-935c.bi_dev`.ioh_snd_master_kpi_detail where brand = '3ID' and dt_id = vdt_id and kpi in ('vlr_subs_less_90d', 'vlr_subs_90d_180d', 'vlr_subs_more_180d');



 
 insert into `data-bi-prd-935c.bi_dev`.ioh_snd_master_kpi_detail
 select '3ID' as brand, 
 'site_id',
 site_id,
 sum(subs),
 'dly',
 current_timestamp,
 case when tenure = 'a.<=90D' then 'vlr_subs_less_90d'
      when tenure = 'b.91D - 180D' then 'vlr_subs_90d_180d'
      when tenure = 'c.>=181D' then 'vlr_subs_more_180d'
 end,
 dt_id
 from `data-bi-prd-935c.bi_mart`.vlr_site_activity a
 where dt_id = vdt_id
 and dt_id not in ('2024-01-01','2024-01-02','2024-01-20','2024-01-28') -- takeout incomplete data
 group by 1,2,3,5,6,7,8;





 delete from `data-bi-prd-935c.bi_dev`.ioh_snd_master_kpi_detail where brand = '3ID' and dt_id = vdt_id and kpi in ('vlr_subs');



 
 insert into `data-bi-prd-935c.bi_dev`.ioh_snd_master_kpi_detail
 select brand, 
 level,
 level_value,
 sum(values),
 time_flag,
 current_timestamp,
 'vlr_subs',
 dt_id
 from `data-bi-prd-935c.bi_dev`.ioh_snd_master_kpi_detail a
 where kpi in ('vlr_subs_less_90d', 'vlr_subs_90d_180d', 'vlr_subs_more_180d') and brand = '3ID'
 and dt_id not in ('2024-01-01','2024-01-02','2024-01-20','2024-01-28') -- takeout incomplete data
 and dt_id = vdt_id
 group by 1,2,3,5,6,7,8;

                        
                         --******************
--Revenue by Service
--******************

--ORGANIC

 delete from `data-bi-prd-935c.bi_dev`.ioh_snd_master_kpi_detail where brand = '3ID' and kpi in ('tot_rev_organic', 'tot_rev_mobo', 'tot_rev_loan', 
 'tot_rev_vas', 'tot_rev_sms', 'tot_rev_voice', 'tot_rev_others')
 and time_flag = 'dly'
 and dt_id = vdt_id;

 


 insert into `data-bi-prd-935c.bi_dev`.ioh_snd_master_kpi_detail
 select '3ID' as brand, 
 'site_id' as level,
 a.site_id as level_value,
 sum(rev) as values,
 'dly' as time_flag,
 current_timestamp as insert_date,
 'tot_rev_organic' as kpi_id,
 a.dt_id
 from
 (
  select date(dt_id) dt_id, site_id,
  sum(case when (revenue_flg = 'PREPAID' or revenue_flg is null) then 
  (coalesce(ccn_data_revenue,0) + coalesce(loan_package_revenue,0))/1.11 
  else coalesce(ccn_data_revenue,0) + coalesce(loan_package_revenue,0) end) as rev
  from `data-dtptechm-prd-c7ca.dwh`.h3i_revenue_per_site_extended
  where date(dt_id) = vdt_id
  group by 1,2
 ) a
 group by 1,2,3,5,6,7,8;

 



--MOBO

 insert into `data-bi-prd-935c.bi_dev`.ioh_snd_master_kpi_detail
 select '3ID' as brand, 
 'site_id' as level,
 a.site_id as level_value,
 cast(sum(rev) as numeric) as rec,
 'dly' as time_flag,
 current_timestamp as insert_date,
 'tot_rev_mobo' as kpi_id,
 a.dt_id
 from
 (
  select date(dt_id) dt_id, site_id,
  sum(case when (revenue_flg = 'PREPAID' or revenue_flg is null) then 
  (
   coalesce(mobo_sp_data_rev,0)+
   coalesce(fdv_data_rev,0)+ 
   coalesce(voucher_forfeit_revenue,0)+ --this has included (service_type = 'OTHER_VOUCHER_FORFEIT' and service_type_detail = 'PAYU')
   coalesce(mobo_rita_data_rev,0)+
   coalesce(mobo_evc_rev,0)
  )/1.11
   else 
  (
   coalesce(mobo_sp_data_rev,0)+
   coalesce(fdv_data_rev,0)+ 
   coalesce(voucher_forfeit_revenue,0)+ --this has included (service_type = 'OTHER_VOUCHER_FORFEIT' and service_type_detail = 'PAYU')
   coalesce(mobo_rita_data_rev,0)+
   coalesce(mobo_evc_rev,0)
   )
   end
  ) as rev
  from `data-dtptechm-prd-c7ca.dwh`.h3i_revenue_per_site_extended
  where date(dt_id) = vdt_id
  group by 1,2

  union all

  select date(dt_id) as dt, physical_site_id as site_id,
  sum(case when (revenue_flag = 'PREPAID' or revenue_flag is null) then revenue/1.11 else revenue end) as rev
  from `data-dtptechm-prd-c7ca.dwh`.h3i_revenue_per_site_extended_others_detail a
  where date(dt_id) = vdt_id
  and process_nm in ('RITA_P3PRICE_AMORT')
  group by 1,2 
 ) a
 group by 1,2,3,5,6,7,8;

 



--LOAN

 insert into `data-bi-prd-935c.bi_dev`.ioh_snd_master_kpi_detail
 select '3ID' as brand, 
 'site_id' as level,
 a.site_id as level_value,
 sum(case when (revenue_flg = 'PREPAID' or revenue_flg is null) then (coalesce(loan_balance_fee,0)+coalesce(balance_transfer_revenue,0))/1.11 else (coalesce(loan_balance_fee,0)+coalesce(balance_transfer_revenue,0)) end) as values,
 'dly' as time_flag,
 current_timestamp as insert_date,
 'tot_rev_loan' as kpi_id,
 date(a.dt_id)
 from `data-dtptechm-prd-c7ca.dwh`.h3i_revenue_per_site_extended a
 where date(dt_id) = vdt_id
 group by 1,2,3,5,6,7,8;

 



--VAS

 insert into `data-bi-prd-935c.bi_dev`.ioh_snd_master_kpi_detail
 select '3ID' as brand, 
 'site_id' as level,
 a.site_id as level_value,
 sum(case when (revenue_flg = 'PREPAID' or revenue_flg is null) then (coalesce(ccn_vas_revenue,0)+coalesce(mobo_sp_vas_rev,0)+coalesce(mobo_rita_vas_rev,0))/1.11 else (coalesce(ccn_vas_revenue,0)+coalesce(mobo_sp_vas_rev,0)+coalesce(mobo_rita_vas_rev,0)) end) as values,
 'dly' as time_flag,
 current_timestamp as insert_date,
 'tot_rev_vas' as kpi_id,
 date(a.dt_id) dt_id
 from `data-dtptechm-prd-c7ca.dwh`.h3i_revenue_per_site_extended a
 where date(dt_id) = vdt_id
 group by 1,2,3,5,6,7,8;

 



--SMS

 insert into `data-bi-prd-935c.bi_dev`.ioh_snd_master_kpi_detail
 select '3ID' as brand, 
 'site_id' as level,
 a.site_id as level_value,
 sum(case when (revenue_flg = 'PREPAID' or revenue_flg is null) then (coalesce(ccn_sms_revenue,0)+
 coalesce(fdv_sms_rev,0)+
 coalesce(mobo_sp_sms_rev,0)+
 coalesce(mobo_rita_sms_rev,0)+
 coalesce(other_mms_revenue,0))/1.11 
 else
 (coalesce(ccn_sms_revenue,0)+
 coalesce(fdv_sms_rev,0)+
 coalesce(mobo_sp_sms_rev,0)+
 coalesce(mobo_rita_sms_rev,0)+
 coalesce(other_mms_revenue,0))
 end
 ) as values,
 'dly' as time_flag,
 current_timestamp as insert_date,
 'tot_rev_sms' as kpi_id,
 date(a.dt_id)
 from `data-dtptechm-prd-c7ca.dwh`.h3i_revenue_per_site_extended a
 where date(dt_id) = vdt_id
 group by 1,2,3,5,6,7,8;

 

 

--VOICE

 insert into `data-bi-prd-935c.bi_dev`.ioh_snd_master_kpi_detail
 select '3ID' as brand, 
 'site_id' as level,
 a.site_id as level_value,
 sum(case when (revenue_flg = 'PREPAID' or revenue_flg is null) then 
 (coalesce(mobo_sp_voice_rev,0)+
 coalesce(fdv_voice_rev,0)+
 coalesce(mobo_rita_voice_rev,0)+
 coalesce(ccn_voice_revenue,0))/1.11
 else
 (coalesce(mobo_sp_voice_rev,0)+
 coalesce(fdv_voice_rev,0)+
 coalesce(mobo_rita_voice_rev,0)+
 coalesce(ccn_voice_revenue,0))
 end
 ) as values,
 'dly' as time_flag,
 current_timestamp as insert_date,
 'tot_rev_voice' as kpi_id,
 date(a.dt_id)
 from `data-dtptechm-prd-c7ca.dwh`.h3i_revenue_per_site_extended a
 where date(dt_id) = vdt_id
 group by 1,2,3,5,6,7,8;

 



--OTHERS

 insert into `data-bi-prd-935c.bi_dev`.ioh_snd_master_kpi_detail
 select '3ID' as brand, 
 'site_id' as level,
 a.site_id as level_value,
 cast(sum(rev) as numeric) as values,
 'dly' as time_flag,
 current_timestamp as insert_date,
 'tot_rev_others' as kpi_id,
 a.dt_id
 from 
 (
  select date(dt_id) dt_id, site_id,
  sum(case when (revenue_flg = 'PREPAID' or revenue_flg is null) then (coalesce(ccn_voice_rev_ppu_roaming,0)+
  coalesce(ccn_sms_rev_ppu_roaming,0)+
  coalesce(mobo_evc_roaming_rev,0)+
  coalesce(other_roaming_rev,0))/1.11 
  else (coalesce(ccn_voice_rev_ppu_roaming,0)+
  coalesce(ccn_sms_rev_ppu_roaming,0)+
  coalesce(mobo_evc_roaming_rev,0)+
  coalesce(other_roaming_rev,0)) --include markup roaming inside
  end) as rev
  from `data-dtptechm-prd-c7ca.dwh`.h3i_revenue_per_site_extended a
  where date(dt_id) = vdt_id
  group by 1,2

  union all

  select date(dt_id) dt_id, physical_site_id as site_id,
  sum(case when (revenue_flag = 'PREPAID' or revenue_flag is null) then revenue/1.11 else revenue end) as rev
  from `data-dtptechm-prd-c7ca.dwh`.h3i_revenue_per_site_extended_others_detail a
  where date(dt_id) = vdt_id
  --and service_type = 'ROAMING'
  and process_nm in ('EVC MARKUP',
  'MARKUP_RITA',
  'MARKUP_UNLOCK',
  'BIMA MARKUP'
  ) and service_type <> 'ROAMING' --exclude roaming because has been counted on other_roaming_rev
  group by 1,2
 
  union all

  select date(dt_id), physical_site_id as site_id,
  sum(case when (revenue_flag = 'PREPAID' or revenue_flag is null) then revenue/1.11 else revenue end) as rev
  from `data-dtptechm-prd-c7ca.dwh`.h3i_revenue_per_site_extended_others_detail a
  where date(dt_id) =vdt_id
  and service_type = 'OTHER_VAS' 
  and process_nm in ('ONE-OFF CDR') --'TOPUP'
  group by 1,2
  
  union all

  select date(dt_id), physical_site_id as site_id,
  sum(case when (revenue_flag = 'PREPAID' or revenue_flag is null) then revenue/1.11 else revenue end) as rev
  from `data-dtptechm-prd-c7ca.dwh`.h3i_revenue_per_site_extended_others_detail a
  where date(dt_id) = vdt_id
  and process_nm in ('ADDON_PULSA', 'CEPEK AMORTIZATION', 'MAIN_BALANCE_OTHERS_ADJUSTMENT', 'RITA_TOPUP', 'TOPUP', 'UNTAGGED_COMMISSION')
  and service_type_detail in ('BROADBAND', 'VAS_PARTNER', 'OTHERS')
  group by 1,2
  
  union all
  
  --Add this start 01 Jun 2025 onwards
  
  select date(dt_id), physical_site_id,
  sum(case when (revenue_flag = 'PREPAID' or revenue_flag is null) then revenue/1.11 else revenue end) as rev
  from `data-dtptechm-prd-c7ca.dwh`.h3i_revenue_per_site_extended_others_detail a
  where date(dt_id) = vdt_id
  and service_type = 'OTHER_PAYU' and service_type_detail in ('GPRS','GPRS_PACKAGE') and process_nm in ('EVC MARKUP', 'MARKUP_RITA', 'MARKUP_UNLOCK', 'BIMA MARKUP')
  group by 1,2
 ) a
 group by 1,2,3,5,6,7,8;

 



 
 --***
 --MTD
 --***
 
 delete from `data-bi-prd-935c.bi_dev`.ioh_snd_master_kpi_detail where brand = '3ID' and kpi in 
 ( 
  'tot_rev_loan',
  'tot_rev_mobo',
  'tot_rev_organic',
  'tot_rev_others',
  'tot_rev_sms',
  'tot_rev_vas',
  'tot_rev_voice'
 )
 and time_flag = 'mtd' 
 and dt_id = vdt_id and level = 'site_id';

 

 

 insert into `data-bi-prd-935c.bi_dev`.ioh_snd_master_kpi_detail
 select brand, level, level_value, sum(values), 
 'mtd' time_flag, timestamp(current_datetime('+7')), kpi, 
 vdt_id as dt_id
 from `data-bi-prd-935c.bi_dev`.ioh_snd_master_kpi_detail
 where dt_id between date_trunc(vdt_id,month) and vdt_id
 and kpi in 
 (
  'tot_rev_loan',
  'tot_rev_mobo',
  'tot_rev_organic',
  'tot_rev_others',
  'tot_rev_sms',
  'tot_rev_vas',
  'tot_rev_voice'
 ) and brand = '3ID'
 and time_flag = 'dly' 
 group by 1,2,3,5,7,8;
 
 


 
 delete from `data-bi-prd-935c.bi_dev`.ioh_snd_master_kpi_detail where brand = '3ID' and kpi in 
 ( 
  'tot_rev',
  'tot_rev_data',
  'tot_rev_non_data',
  'tot_rev_data_30',
  'tot_rev_30'
 )
 and time_flag = 'mtd'
 and dt_id = vdt_id and level = 'site_id';

 
 insert into `data-bi-prd-935c.bi_dev`.ioh_snd_master_kpi_detail
 select brand, level, level_value, sum(values), 
 'mtd' time_flag, timestamp(current_datetime('+7')), kpi, 
 vdt_id as dt_id
 from `data-bi-prd-935c.bi_dev`.ioh_snd_master_kpi_detail
 where dt_id between date_trunc(vdt_id,month) and vdt_id
 and kpi in 
 (
  'tot_rev',
  'tot_rev_data',
  'tot_rev_non_data' )
 and time_flag = 'dly' and brand = '3ID'
 group by 1,2,3,5,7,8;

 


 insert into `data-bi-prd-935c.bi_dev`.ioh_snd_master_kpi_detail
 select brand, level, level_value, 
 sum(values),
 'mtd',
 timestamp(current_datetime('+7')),
 kpi||'_30',
 vdt_id
 from `data-bi-prd-935c.bi_dev`.ioh_snd_master_kpi_detail
 where kpi in ('tot_rev_data', 'tot_rev') and time_flag = 'dly' and brand = '3ID'
 and dt_id between vdt_id - interval 29 day and vdt_id
 group by 1,2,3,5,6,7,8;


                                                                                                                                   



--**********************
--Acq_Rev_Excl_VchrGames 
--**********************

 create or replace table `data-bi-prd-935c.bi_stg`.tmp_ga_games as
 select date(trx_dt_sk_id) as dt, cast(sbscrptn_ek_id as string) sbscrptn_ek_id, service_type_category_2, 
 sum(case when product_id = 8 then net_revenue/1.11 else net_revenue end) as net_revenue
 from `data-dtptechm-prd-c7ca.dwh`.revenue_base fct
 where date(trx_dt_sk_id) between date_trunc(vdt_id,month) and vdt_id
 and service_type like '%VAS%'
 AND       
 (struct(fct.process_nm,fct.revenue_src_ctgry) in ( select struct(process_nm,revenue_src_ctgry) from `data-dtptechm-prd-c7ca.dwh`.demand_revenue_base_filter where net_revenue_incl = 'Y') 
 )and coalesce(fct.gl_cd,'NA') not in (select ref_cd from `data-dtptechm-prd-c7ca.dwh`.rprt_fltr_ref_ctgry where ref_type_cd = 'ACCRUAL_GL_CODE')
 and tool_of_trade_ind = 'N'
 group by 1,2,3;

 


 create or replace table `data-bi-prd-935c.bi_stg`.tmp_ga_acq_rev as
 select date_trunc(trx_dt_sk_id,month) as mth, sbscrptn_ek_id, sum(revenue) as revenue
 from `data-bi-prd-935c.bi_mart`.fct_cwn_rev_detail_fnl a
 where (trx_dt_sk_id between date_trunc(vdt_id,month) and  vdt_id)
 group by 1,2;

 

 
 delete from `data-bi-prd-935c.bi_dev`.ioh_snd_master_kpi_detail where brand = '3ID' and kpi = 'Acq_Rev_Excl_VchrGames' 
 and time_flag = 'dly'
 and dt_id = vdt_id;
 

 insert into `data-bi-prd-935c.bi_dev`.ioh_snd_master_kpi_detail
 select '3ID' as brand, 
 'site_id' as level,
 a.site_id as level_value,
 cast(sum(coalesce(c.revenue,0) - coalesce(e.games_rev,0)) as numeric) as values,
 'dly' as time_flag,
 timestamp(current_datetime('+7')) as insert_date,
 'Acq_Rev_Excl_VchrGames' as kpi_id,
 vdt_id
 from `data-bi-prd-935c.bi_mart`.fct_ga_site_id a
 left outer join `data-bi-prd-935c.bi_stg`.tmp_ga_acq_rev c on a.sbscrptn_ek_id = c.sbscrptn_ek_id and date_trunc(a.dt,month) = c.mth
 left outer join
 (
  select mth, sbscrptn_ek_id, sum(games_rev) as games_rev
  from
  (
   select mth, sbscrptn_ek_id, sum(rev) as games_rev
   from 
   (
    select date_trunc(dt,month) as mth, sbscrptn_ek_id, service_type_category_2, sum(net_revenue) as rev
    from `data-bi-prd-935c.bi_stg`.tmp_ga_games
    where (dt between date_trunc(vdt_id,month) and vdt_id)
    group by 1,2,3
   )  a
   join `data-bi-prd-935c.bi_mart`.ref_vas_games_prd b on a.service_type_category_2 = b.vas_prod
   group by 1,2
 
   union all
 
   select mth, sbscrptn_ek_id, sum(rev) as games_rev
   from 
   (
    select date_trunc(dt,month) as mth, sbscrptn_ek_id, service_type_category_2, sum(net_revenue) as rev
    from `data-bi-prd-935c.bi_stg`.tmp_ga_games
    where (dt between date_trunc(vdt_id,month) and vdt_id)
    group by 1,2,3
   ) a
   where a.service_type_category_2 in 
   (
    'OTHERS|0771|', 'OTHERS|0773|', 'OTHERS|0774|', 'OTHERS|0775|', 'OTHERS|0776|', 'OTHERS|0777|', 'OTHERS|0778|', 
    'OTHERS|0779|', 'OTHERS|0780|', 'OTHERS|0762|', 'OTHERS|0763|', 'OTHERS|0764|', 'OTHERS|0765|', 'OTHERS|0771|', 
    'OTHERS|0772|', 'OTHERS|0781|', 'Nuon|0763|Nuon Voucher Games', '313|1111111111-994331|994331', 'OTHERS|0770|',
    'OTHERS|0677|','OTHERS|0743|', 'OTHERS|0747|', 'OTHERS|0752|', 'OTHERS|0756|', 'OTHERS|0757|', 'OTHERS|0758|',
    'OTHERS|0769|', 'OTHERS|0782|', 'OTHERS|0783|', 'OTHERS|0784|', 'OTHERS|0788|', 'OTHERS|0791|', 'OTHERS|0792|',
    'OTHERS|0793|', 'OTHERS|0798|', 'OTHERS|9870|', 'OTHERS|0794|', 'OTHERS|0795|', 'OTHERS|0796|', 'OTHERS|0797|',
    'OTHERS|0623|', 'OTHERS|0800|', 'OTHERS|0801|', 'OTHERS|0802|'
   )
   group by 1,2
  ) a
  group by 1,2
 ) e on a.sbscrptn_ek_id = e.sbscrptn_ek_id and date_trunc(a.dt,month) = e.mth
 where a.dt between date_trunc(vdt_id,month) and  vdt_id
 group by 1,2,3,5,6,7,8;

 



--***************************
--Acq_Rev_VchrGames (Revenue)
--***************************

 delete from `data-bi-prd-935c.bi_dev`.ioh_snd_master_kpi_detail where brand = '3ID' and kpi = 'Acq_Rev_VchrGames' 
 and time_flag = 'dly'
 and dt_id = vdt_id;
 
 
 insert into `data-bi-prd-935c.bi_dev`.ioh_snd_master_kpi_detail
 select '3ID' as brand, 
 'site_id' as level,
 a.site_id as level_value,
 cast(sum(coalesce(e.games_rev,0)) as numeric) as values,
 'dly' as time_flag,
 timestamp(current_datetime('+7')) as insert_date,
 'Acq_Rev_VchrGames' as kpi_id,
 vdt_id
 from `data-bi-prd-935c.bi_mart`.fct_ga_site_id a
 --left outer join `data-bi-prd-935c.bi_stg`.tmp_ga_acq_rev c on a.sbscrptn_ek_id = c.sbscrptn_ek_id and date_trunc(a.dt,month) = c.mth
 left outer join
 (
  select mth, sbscrptn_ek_id, sum(games_rev) as games_rev
  from
  (
   select mth, sbscrptn_ek_id, sum(rev) as games_rev
   from 
   (
    select date_trunc(dt,month) as mth, sbscrptn_ek_id, service_type_category_2, sum(net_revenue) as rev
    from `data-bi-prd-935c.bi_stg`.tmp_ga_games
    where (dt between date_trunc(vdt_id,month) and vdt_id)
    group by 1,2,3
   )  a
   join `data-bi-prd-935c.bi_mart`.ref_vas_games_prd b on a.service_type_category_2 = b.vas_prod
   group by 1,2
 
   union all
 
   select mth, sbscrptn_ek_id, sum(rev) as games_rev
   from 
   (
    select date_trunc(dt,month) as mth, sbscrptn_ek_id, service_type_category_2, sum(net_revenue) as rev
    from `data-bi-prd-935c.bi_stg`.tmp_ga_games
    where (dt between date_trunc(vdt_id,month) and vdt_id)
    group by 1,2,3
   ) a
   where a.service_type_category_2 in 
   (
    'OTHERS|0771|', 'OTHERS|0773|', 'OTHERS|0774|', 'OTHERS|0775|', 'OTHERS|0776|', 'OTHERS|0777|', 'OTHERS|0778|', 
    'OTHERS|0779|', 'OTHERS|0780|', 'OTHERS|0762|', 'OTHERS|0763|', 'OTHERS|0764|', 'OTHERS|0765|', 'OTHERS|0771|', 
    'OTHERS|0772|', 'OTHERS|0781|', 'Nuon|0763|Nuon Voucher Games', '313|1111111111-994331|994331', 'OTHERS|0770|',
    'OTHERS|0677|','OTHERS|0743|', 'OTHERS|0747|', 'OTHERS|0752|', 'OTHERS|0756|', 'OTHERS|0757|', 'OTHERS|0758|',
    'OTHERS|0769|', 'OTHERS|0782|', 'OTHERS|0783|', 'OTHERS|0784|', 'OTHERS|0788|', 'OTHERS|0791|', 'OTHERS|0792|',
    'OTHERS|0793|', 'OTHERS|0798|', 'OTHERS|9870|', 'OTHERS|0794|', 'OTHERS|0795|', 'OTHERS|0796|', 'OTHERS|0797|',
    'OTHERS|0623|', 'OTHERS|0800|', 'OTHERS|0801|', 'OTHERS|0802|'
   )
   group by 1,2
  ) a
  group by 1,2
 ) e on a.sbscrptn_ek_id = e.sbscrptn_ek_id and date_trunc(a.dt,month) = e.mth
 where a.dt between date_trunc(vdt_id,month) and  vdt_id
 group by 1,2,3,5,6,7,8;

 


--*******************
--ga_VchrGames (Subs)
--*******************

 delete from `data-bi-prd-935c.bi_dev`.ioh_snd_master_kpi_detail where brand = '3ID' and kpi = 'ga_VchrGames' 
 and time_flag = 'dly'
 and dt_id = vdt_id;

 
 insert into `data-bi-prd-935c.bi_dev`.ioh_snd_master_kpi_detail
 select '3ID' as brand, 
 'site_id' as level,
 a.site_id as level_value,
 count(distinct case when coalesce(e.games_rev,0) > 0 then a.sbscrptn_ek_id end) as values,
 'dly' as time_flag,
 current_timestamp as insert_date,
 'ga_VchrGames' as kpi_id,
 vdt_id
 from `data-bi-prd-935c.bi_mart`.fct_ga_site_id a
 --left outer join `data-bi-prd-935c.bi_stg`.tmp_ga_acq_rev c on a.sbscrptn_ek_id = c.sbscrptn_ek_id and date_trunc(a.dt,month) = c.mth
 left outer join
 (
  select mth, sbscrptn_ek_id, sum(games_rev) as games_rev
  from
  (
   select mth, sbscrptn_ek_id, sum(rev) as games_rev
   from 
   (
    select date_trunc(dt,month) as mth, sbscrptn_ek_id, service_type_category_2, sum(net_revenue) as rev
    from `data-bi-prd-935c.bi_stg`.tmp_ga_games
    where (dt between date_trunc(vdt_id,month) and vdt_id)
    group by 1,2,3
   )  a
   join `data-bi-prd-935c.bi_mart`.ref_vas_games_prd b on a.service_type_category_2 = b.vas_prod
   group by 1,2
 
   union all
 
   select mth, sbscrptn_ek_id, sum(rev) as games_rev
   from 
   (
    select date_trunc(dt,month) as mth, sbscrptn_ek_id, service_type_category_2, sum(net_revenue) as rev
    from `data-bi-prd-935c.bi_stg`.tmp_ga_games
    where (dt between date_trunc(vdt_id,month) and vdt_id)
    group by 1,2,3
   ) a
   where a.service_type_category_2 in 
   (
    'OTHERS|0771|', 'OTHERS|0773|', 'OTHERS|0774|', 'OTHERS|0775|', 'OTHERS|0776|', 'OTHERS|0777|', 'OTHERS|0778|', 
    'OTHERS|0779|', 'OTHERS|0780|', 'OTHERS|0762|', 'OTHERS|0763|', 'OTHERS|0764|', 'OTHERS|0765|', 'OTHERS|0771|', 
    'OTHERS|0772|', 'OTHERS|0781|', 'Nuon|0763|Nuon Voucher Games', '313|1111111111-994331|994331', 'OTHERS|0770|',
    'OTHERS|0677|','OTHERS|0743|', 'OTHERS|0747|', 'OTHERS|0752|', 'OTHERS|0756|', 'OTHERS|0757|', 'OTHERS|0758|',
    'OTHERS|0769|', 'OTHERS|0782|', 'OTHERS|0783|', 'OTHERS|0784|', 'OTHERS|0788|', 'OTHERS|0791|', 'OTHERS|0792|',
    'OTHERS|0793|', 'OTHERS|0798|', 'OTHERS|9870|', 'OTHERS|0794|', 'OTHERS|0795|', 'OTHERS|0796|', 'OTHERS|0797|',
    'OTHERS|0623|', 'OTHERS|0800|', 'OTHERS|0801|', 'OTHERS|0802|'
   )
   group by 1,2
  ) a
  group by 1,2
 ) e on a.sbscrptn_ek_id = e.sbscrptn_ek_id and date_trunc(a.dt,month) = e.mth
 where a.dt between date_trunc(vdt_id,month) and  vdt_id
 group by 1,2,3,5,6,7,8;

 
 


--***********************
--GA Subs (above IDR 35k) 
--GA Subs (below IDR 35k)
--Acq Rev (above IDR 35k)  
--Acq Rev (below IDR 35k)
--***********************


 create or replace table `data-bi-prd-935c.bi_stg`.tmp_ga_35k_ori as
 (
  select distinct dt, a.sbscrptn_ek_id, site_id, promo_desc as sp, coalesce(c.revenue,0) as revenue
  from `data-bi-prd-935c.bi_mart`.fct_ga_site_id a
  left outer join `data-dtptechm-prd-c7ca.dwh`.sbscrptn_attribs b on a.sbscrptn_ek_id = cast(b.sbscrptn_ek_id as string)
  left outer join `data-bi-prd-935c.bi_stg`.tmp_ga_acq_rev c on a.sbscrptn_ek_id = c.sbscrptn_ek_id and date_trunc(a.dt,month) = c.mth --the table `data-bi-prd-935c.bi_stg`.tmp_ga_acq_rev is created on f_new_dashboard_load_c
  where a.dt between date_trunc(vdt_id,month) and vdt_id
 );

 

 delete from `data-bi-prd-935c.bi_dev`.ioh_snd_master_kpi_detail where brand = '3ID' and kpi in ('GA Subs (above IDR 35k)', 'GA Subs (below IDR 35k)', 'Acq Rev (above IDR 35k)',  'Acq Rev (below IDR 35k)')
 and time_flag = 'dly'
 and dt_id = vdt_id;

 
 insert into `data-bi-prd-935c.bi_dev`.ioh_snd_master_kpi_detail
 select '3ID' as brand, 
 'site_id' as level,
 a.site_id as level_value,
 count(distinct a.sbscrptn_ek_id) as values,
 'dly' as time_flag,
 current_timestamp as insert_date,
 case when upper(sp) like 'SP HAPPY 3GB 30D%' or upper(sp) in
 (
 'SP HAPPY 500GB 180D OS ESIM',
 'SP HAPPY 250GB 90D OS ESIM',
 'SP HAPPY M',
 'SP HAPPY M V2',
 'SP HAPPY 100K',
 'SP HAPPY XL',
 'SP HAPPY XL V2',
 'SP HAPPY 25K',
 'SP HAPPY LRS 42GB',
 'SP HAPPY 30K',
 'SP Happy LRS 42GB 28D',
 'SP FWA S2 ORI',
 'SP Happy LRS 42GB DS',
 'SP HAPPY 50K',
 'SP HAPPY L',
 'SP FWA S1 ORI',
 '3BIZ DATA1 PREPAID',
 'SP HAPPY L V2',
 'SP HAPPY XXL EJBN',
 'SP HAPPY M V2 TS',
 'SP HAPPY M TS',
 'SP HAPPY 9GB DS',
 'TRI IBADAH UNLIMITED',
 'SP HAJI 24GB',
 'SP FWA S1',
 'SP HAPPY 9GB 28D DS',
 'SP HAPPY 150GB 5GB PER D',
 'SP HAPPY 9GB PO',
 'SP HAPPY 300GB 30D',
 'SP Happy M OS',
 'SP HAPPY TRAVEL 30GB',
 'SP HAPPY 150K',
 'SP HAPPY 30GB 1GB PER D',
 'SP HAPPY M V2 ESIM',
 'SP HAPPY XXL KALSUL',
 'SP HAPPY 9GB 28D PO',
 'SP-TRI-IBADAH-10-DAYS',
 'SP HAPPY XL TS',
 'SP HAPPY M DVM',
 'SP HAPPY XL V2 TS',
 'SP HAPPY M OS ESIM',
 'GOLD VANITY',
 'SP HAPPY L V2 ESIM',
 'PLATINUM VANITY',
 'SP HAPPY LRS 42GB V2',
 'SP Happy L OS',
 'SP Happy 250GB TS',
 'SP HAPPY 30GB 1GB PER D PO',
 'SP HAPPY M ESIM',
 'SP HAPPY M V2 OS',
 'SP HAPPY M V2 DVM',
 'SP HAPPY 60GB 2GB PER D',
 'SP HAPPY XL V2 ESIM',
 'SP HAPPY M V2 OS ESIM',
 'SP HAPPY 300GB 30D PO',
 'SP HAPPY 60GB 2GB PER D PO',
 'SP HAJI 6GB',
 'SP HAPPY L ESIM',
 'SP HAPPY L OS ESIM',
 'SP HAPPY XL ESIM',
 'SP HAPPY 150GB 5GB PER D PO',
 'SP HAJI 14GB',
 'SP FWA S4 ORI',
 'SP HAPPY L V2 OS',
 'SP HAPPY XXL SUMATERA',
 'SP HAJI 19GB',
 'SP FWA S3 ORI',
 'SP HAPPY 75GB',
 'SP HAPPY 300GB 30D TS',
 'SP HAPPY L V2 OS ESIM',
 'SP HAPPY L TS',
 'SP HAPPY XXL JABODETABEK',
 'SP-PMAX-4GB-2018',
 'SP HAPPY L V2 TS',
 'SP HAPPY L V2 DVM',
 'SP HAPPY 30GB 1GB PER D DVM',
 'SP HAPPY 30GB 1GB PER D OS',
 'SP HAPPY XXL CWJ',
 'SP-PMAX-8GB-2017',
 'SP Tourist 149K',
 'SP HAPPY 150GB 5GB PER D TS',
 'SP HAPPY L DVM',
 'SP HAPPY 150K DS',
 'SP HAPPY 30GB 1GB PER D TS',
 'SP HAPPY 60GB 2GB PER D TS',
 'SP HAPPY 100K DS',
 'SP HAPPY 60GB 2GB PER D OS ES',
 'SP HAPPY 30GB 1GB PER D OS ES',
 'SP HAPPY 12GB TS',
 'SP Haji 24GB TS',
 'SP HAPPY 60GB 2GB PER D ESIM',
 'SP HAPPY 50K DS',
 'SP HAPPY S PLUS V2 BK ESIM',
 'SP HAPPY 30GB 1GB PER D ESIM',
 'SP HAPPY 150GB 5GB PER D MO',
 'SP Happy LRS 42GB OS',
 'SP HAPPY TRAVEL 30GB TS'
 ) then 'GA Subs (above IDR 35k)' else 'GA Subs (below IDR 35k)' end as kpi,
 vdt_id
 from `data-bi-prd-935c.bi_stg`.tmp_ga_35k_ori a
 where a.dt = vdt_id
 group by 1,2,3,5,6,7,8;
 
 


 insert into `data-bi-prd-935c.bi_dev`.ioh_snd_master_kpi_detail
 select '3ID' as brand, 
 'site_id' as level,
 a.site_id as level_value,
 cast(sum(revenue) as numeric) as values,
 'dly' as time_flag,
 current_timestamp as insert_date,
 case when upper(sp) like 'SP HAPPY 3GB 30D%' or upper(sp) in
 (
 'SP HAPPY 500GB 180D OS ESIM',
 'SP HAPPY 250GB 90D OS ESIM',    
 'SP HAPPY M',
 'SP HAPPY M V2',
 'SP HAPPY 100K',
 'SP HAPPY XL',
 'SP HAPPY XL V2',
 'SP HAPPY 25K',
 'SP HAPPY LRS 42GB',
 'SP HAPPY 30K',
 'SP Happy LRS 42GB 28D',
 'SP FWA S2 ORI',
 'SP Happy LRS 42GB DS',
 'SP HAPPY 50K',
 'SP HAPPY L',
 'SP FWA S1 ORI',
 '3BIZ DATA1 PREPAID',
 'SP HAPPY L V2',
 'SP HAPPY XXL EJBN',
 'SP HAPPY M V2 TS',
 'SP HAPPY M TS',
 'SP HAPPY 9GB DS',
 'TRI IBADAH UNLIMITED',
 'SP HAJI 24GB',
 'SP FWA S1',
 'SP HAPPY 9GB 28D DS',
 'SP HAPPY 150GB 5GB PER D',
 'SP HAPPY 9GB PO',
 'SP HAPPY 300GB 30D',
 'SP Happy M OS',
 'SP HAPPY TRAVEL 30GB',
 'SP HAPPY 150K',
 'SP HAPPY 30GB 1GB PER D',
 'SP HAPPY M V2 ESIM',
 'SP HAPPY XXL KALSUL',
 'SP HAPPY 9GB 28D PO',
 'SP-TRI-IBADAH-10-DAYS',
 'SP HAPPY XL TS',
 'SP HAPPY M DVM',
 'SP HAPPY XL V2 TS',
 'SP HAPPY M OS ESIM',
 'GOLD VANITY',
 'SP HAPPY L V2 ESIM',
 'PLATINUM VANITY',
 'SP HAPPY LRS 42GB V2',
 'SP Happy L OS',
 'SP Happy 250GB TS',
 'SP HAPPY 30GB 1GB PER D PO',
 'SP HAPPY M ESIM',
 'SP HAPPY M V2 OS',
 'SP HAPPY M V2 DVM',
 'SP HAPPY 60GB 2GB PER D',
 'SP HAPPY XL V2 ESIM',
 'SP HAPPY M V2 OS ESIM',
 'SP HAPPY 300GB 30D PO',
 'SP HAPPY 60GB 2GB PER D PO',
 'SP HAJI 6GB',
 'SP HAPPY L ESIM',
 'SP HAPPY L OS ESIM',
 'SP HAPPY XL ESIM',
 'SP HAPPY 150GB 5GB PER D PO',
 'SP HAJI 14GB',
 'SP FWA S4 ORI',
 'SP HAPPY L V2 OS',
 'SP HAPPY XXL SUMATERA',
 'SP HAJI 19GB',
 'SP FWA S3 ORI',
 'SP HAPPY 75GB',
 'SP HAPPY 300GB 30D TS',
 'SP HAPPY L V2 OS ESIM',
 'SP HAPPY L TS',
 'SP HAPPY XXL JABODETABEK',
 'SP-PMAX-4GB-2018',
 'SP HAPPY L V2 TS',
 'SP HAPPY L V2 DVM',
 'SP HAPPY 30GB 1GB PER D DVM',
 'SP HAPPY 30GB 1GB PER D OS',
 'SP HAPPY XXL CWJ',
 'SP-PMAX-8GB-2017',
 'SP Tourist 149K',
 'SP HAPPY 150GB 5GB PER D TS',
 'SP HAPPY L DVM',
 'SP HAPPY 150K DS',
 'SP HAPPY 30GB 1GB PER D TS',
 'SP HAPPY 60GB 2GB PER D TS',
 'SP HAPPY 100K DS',
 'SP HAPPY 60GB 2GB PER D OS ES',
 'SP HAPPY 30GB 1GB PER D OS ES',
 'SP HAPPY 12GB TS',
 'SP Haji 24GB TS',
 'SP HAPPY 60GB 2GB PER D ESIM',
 'SP HAPPY 50K DS',
 'SP HAPPY S PLUS V2 BK ESIM',
 'SP HAPPY 30GB 1GB PER D ESIM',
 'SP HAPPY 150GB 5GB PER D MO',
 'SP Happy LRS 42GB OS',
 'SP HAPPY TRAVEL 30GB TS'
 ) then 'Acq Rev (above IDR 35k)' else 'Acq Rev (below IDR 35k)' end as kpi,
 vdt_id
 from `data-bi-prd-935c.bi_stg`.tmp_ga_35k_ori a
 group by 1,2,3,5,6,7,8;

 


 --***
 --MTD
 --***

 delete from `data-bi-prd-935c.bi_dev`.ioh_snd_master_kpi_detail
 where kpi in ('GA Subs (above IDR 35k)', 'GA Subs (below IDR 35k)', 'Acq Rev (above IDR 35k)', 'Acq Rev (below IDR 35k)', 'Acq_Rev_Excl_VchrGames', 'Acq_Rev_VchrGames',  'ga_VchrGames')
 and time_flag = 'mtd' 
 and dt_id = vdt_id and level = 'site_id' and brand = '3ID';


 insert into `data-bi-prd-935c.bi_dev`.ioh_snd_master_kpi_detail
 select brand, level, level_value, sum(values),
 'mtd' time_flag,
 timestamp(current_datetime('+7')),
 kpi,
 vdt_id AS dt_id
 from `data-bi-prd-935c.bi_dev`.ioh_snd_master_kpi_detail
 where dt_id between DATE_TRUNC(vdt_id,month) and vdt_id
 and kpi in ('GA Subs (above IDR 35k)', 'GA Subs (below IDR 35k)') and brand = '3ID'
 and time_flag = 'dly' 
 group by 1,2,3,5,7,8;

 

 insert into `data-bi-prd-935c.bi_dev`.ioh_snd_master_kpi_detail
 select brand, level, level_value, sum(values),
 'mtd' time_flag,
 timestamp(current_datetime('+7')),
 kpi,
 vdt_id AS dt_id
 from `data-bi-prd-935c.bi_dev`.ioh_snd_master_kpi_detail
 where dt_id = vdt_id
 and kpi in ('Acq Rev (above IDR 35k)',  'Acq Rev (below IDR 35k)', 'Acq_Rev_Excl_VchrGames', 'Acq_Rev_VchrGames', 'ga_VchrGames') and brand = '3ID'
 and time_flag = 'dly' 
 group by 1,2,3,5,7,8;

 



 --************
 --New GA & Acq
 --************
 
create or replace table `data-bi-prd-935c.bi_stg`.tmp_ga_35k as
 select distinct vdt_id as dt, a.sbscrptn_ek_id, site_id, 
 case when upper(promo_desc) like 'SP HAPPY 3GB 30D%' then 'GA Subs 35K and Above (35K)'
 when upper(promo_desc) in
 (
 'SP HAPPY 500GB 180D OS ESIM',
 'SP HAPPY 250GB 90D OS ESIM',   
 'SP HAPPY M',
 'SP HAPPY M V2',
 'SP HAPPY 100K',
 'SP HAPPY XL',
 'SP HAPPY XL V2',
 'SP HAPPY 25K',
 'SP HAPPY LRS 42GB',
 'SP HAPPY 30K',
 'SP Happy LRS 42GB 28D',
 'SP FWA S2 ORI',
 'SP Happy LRS 42GB DS',
 'SP HAPPY 50K',
 'SP HAPPY L',
 'SP FWA S1 ORI',
 '3BIZ DATA1 PREPAID',
 'SP HAPPY L V2',
 'SP HAPPY XXL EJBN',
 'SP HAPPY M V2 TS',
 'SP HAPPY M TS',
 'SP HAPPY 9GB DS',
 'TRI IBADAH UNLIMITED',
 'SP HAJI 24GB',
 'SP FWA S1',
 'SP HAPPY 9GB 28D DS',
 'SP HAPPY 150GB 5GB PER D',
 'SP HAPPY 9GB PO',
 'SP HAPPY 300GB 30D',
 'SP Happy M OS',
 'SP HAPPY TRAVEL 30GB',
 'SP HAPPY 150K',
 'SP HAPPY 30GB 1GB PER D',
 'SP HAPPY M V2 ESIM',
 'SP HAPPY XXL KALSUL',
 'SP HAPPY 9GB 28D PO',
 'SP-TRI-IBADAH-10-DAYS',
 'SP HAPPY XL TS',
 'SP HAPPY M DVM',
 'SP HAPPY XL V2 TS',
 'SP HAPPY M OS ESIM',
 'GOLD VANITY',
 'SP HAPPY L V2 ESIM',
 'PLATINUM VANITY',
 'SP HAPPY LRS 42GB V2',
 'SP Happy L OS',
 'SP Happy 250GB TS',
 'SP HAPPY 30GB 1GB PER D PO',
 'SP HAPPY M ESIM',
 'SP HAPPY M V2 OS',
 'SP HAPPY M V2 DVM',
 'SP HAPPY 60GB 2GB PER D',
 'SP HAPPY XL V2 ESIM',
 'SP HAPPY M V2 OS ESIM',
 'SP HAPPY 300GB 30D PO',
 'SP HAPPY 60GB 2GB PER D PO',
 'SP HAJI 6GB',
 'SP HAPPY L ESIM',
 'SP HAPPY L OS ESIM',
 'SP HAPPY XL ESIM',
 'SP HAPPY 150GB 5GB PER D PO',
 'SP HAJI 14GB',
 'SP FWA S4 ORI',
 'SP HAPPY L V2 OS',
 'SP HAPPY XXL SUMATERA',
 'SP HAJI 19GB',
 'SP FWA S3 ORI',
 'SP HAPPY 75GB',
 'SP HAPPY 300GB 30D TS',
 'SP HAPPY L V2 OS ESIM',
 'SP HAPPY L TS',
 'SP HAPPY XXL JABODETABEK',
 'SP-PMAX-4GB-2018',
 'SP HAPPY L V2 TS',
 'SP HAPPY L V2 DVM',
 'SP HAPPY 30GB 1GB PER D DVM',
 'SP HAPPY 30GB 1GB PER D OS',
 'SP HAPPY XXL CWJ',
 'SP-PMAX-8GB-2017',
 'SP Tourist 149K',
 'SP HAPPY 150GB 5GB PER D TS',
 'SP HAPPY L DVM',
 'SP HAPPY 150K DS',
 'SP HAPPY 30GB 1GB PER D TS',
 'SP HAPPY 60GB 2GB PER D TS',
 'SP HAPPY 100K DS',
 'SP HAPPY 60GB 2GB PER D OS ES',
 'SP HAPPY 30GB 1GB PER D OS ES',
 'SP HAPPY 12GB TS',
 'SP Haji 24GB TS',
 'SP HAPPY 60GB 2GB PER D ESIM',
 'SP HAPPY 50K DS',
 'SP HAPPY S PLUS V2 BK ESIM',
 'SP HAPPY 30GB 1GB PER D ESIM',
 'SP HAPPY 150GB 5GB PER D MO',
 'SP Happy LRS 42GB OS',
 'SP HAPPY TRAVEL 30GB TS'
 ) then 'GA Subs 35K and Above (Non 35K)' else 'GA Subs (below 35k)' end as SP_Group, 
 coalesce(c.revenue,0) as acq_rev, 
 coalesce(d.games_rev,0) as games_rev
 from `data-bi-prd-935c.bi_mart`.fct_ga_site_id a
 left outer join `data-dtptechm-prd-c7ca.dwh`.sbscrptn_attribs b on a.sbscrptn_ek_id = cast(b.sbscrptn_ek_id as string)
 left outer join `data-bi-prd-935c.bi_stg`.tmp_ga_acq_rev c on a.sbscrptn_ek_id = c.sbscrptn_ek_id and date_trunc(a.dt,month) = c.mth
 left outer join
 (
  select mth, sbscrptn_ek_id, sum(games_rev) as games_rev
  from
  (
   select mth, sbscrptn_ek_id, sum(rev) as games_rev
   from 
   (
    select date_trunc(dt,month) as mth, sbscrptn_ek_id, service_type_category_2, sum(net_revenue) as rev
    from `data-bi-prd-935c.bi_stg`.tmp_ga_games
    where (dt between date_trunc(vdt_id,month) and vdt_id)
    group by 1,2,3
   ) a
   join `data-bi-prd-935c.bi_mart`.ref_vas_games_prd b on a.service_type_category_2 = b.vas_prod
   group by 1,2
 
   union all
 
   select mth, sbscrptn_ek_id, sum(rev) as games_rev
   from 
   (
    select date_trunc(dt,month) as mth, sbscrptn_ek_id, service_type_category_2, sum(net_revenue) as rev
    from `data-bi-prd-935c.bi_stg`.tmp_ga_games
    where (dt between date_trunc(vdt_id,month) and vdt_id)
    group by 1,2,3
   ) a
   where a.service_type_category_2 in 
   (
    'OTHERS|0771|', 'OTHERS|0773|', 'OTHERS|0774|', 'OTHERS|0775|', 'OTHERS|0776|', 'OTHERS|0777|', 'OTHERS|0778|', 
    'OTHERS|0779|', 'OTHERS|0780|', 'OTHERS|0762|', 'OTHERS|0763|', 'OTHERS|0764|', 'OTHERS|0765|', 'OTHERS|0771|', 
    'OTHERS|0772|', 'OTHERS|0781|', 'Nuon|0763|Nuon Voucher Games', '313|1111111111-994331|994331', 'OTHERS|0770|',
    'OTHERS|0677|','OTHERS|0743|', 'OTHERS|0747|', 'OTHERS|0752|', 'OTHERS|0756|', 'OTHERS|0757|', 'OTHERS|0758|',
    'OTHERS|0769|', 'OTHERS|0782|', 'OTHERS|0783|', 'OTHERS|0784|', 'OTHERS|0788|', 'OTHERS|0791|', 'OTHERS|0792|',
    'OTHERS|0793|', 'OTHERS|0798|', 'OTHERS|9870|', 'OTHERS|0794|', 'OTHERS|0795|', 'OTHERS|0796|', 'OTHERS|0797|',
    'OTHERS|0623|', 'OTHERS|0800|', 'OTHERS|0801|', 'OTHERS|0802|'
   )
   group by 1,2
  ) a
  group by 1,2
 ) d on a.sbscrptn_ek_id = d.sbscrptn_ek_id and date_trunc(a.dt,month) = d.mth
 where a.dt between date_trunc(vdt_id,month) and vdt_id;
 



 delete from `data-bi-prd-935c.bi_dev`.ioh_snd_master_kpi_detail where brand = '3ID' and kpi in 
 (
  'GA Subs 35K and Above',
  'GA Subs 35K and Above (35K)',
  'GA Subs 35K and Above (Non 35K)',
  'GA Subs (below 35k)',
  'GA Subs Games',
  'GA Subs Games (35K)',
  'GA Subs Games (Non 35K)',
  'Acq Rev 35K and Above',
  'Acq Rev 35K and Above (35K)',
  'Acq Rev 35K and Above (Non 35K)',
  'Acq Rev (below 35k)',
  'Acq Rev Games',
  'Acq Rev Games (35K)',
  'Acq Rev Games (Non 35K)' 
 ) 
 and time_flag = 'mtd'
 and dt_id = vdt_id;

 


 --Non Games
 
 insert into `data-bi-prd-935c.bi_dev`.ioh_snd_master_kpi_detail
 select '3ID' as brand, 
 'site_id' as level,
 a.site_id as level_value,
 count(distinct a.sbscrptn_ek_id) as values,
 'mtd' as time_flag,
 current_timestamp as insert_date,
 a.sp_group,
 vdt_id
 from
 (
  select *, case when games_rev > (acq_rev - games_rev) then 'GA Games' else 'GA Non Games' end as GA_tag
  from `data-bi-prd-935c.bi_stg`.tmp_ga_35k a
 ) a
 where a.GA_Tag = 'GA Non Games' 
 and a.sp_group in ('GA Subs 35K and Above (35K)', 'GA Subs 35K and Above (Non 35K)', 'GA Subs (below 35k)') 
 and a.dt = vdt_id
 group by 1,2,3,5,6,7,8;

 

 insert into `data-bi-prd-935c.bi_dev`.ioh_snd_master_kpi_detail
 select '3ID' as brand, 
 'site_id' as level,
 a.site_id as level_value,
 cast(sum(a.acq_rev) as numeric) as values,
 'mtd' as time_flag,
 current_timestamp as insert_date,
 case when a.sp_group = 'GA Subs 35K and Above (35K)' then 'Acq Rev 35K and Above (35K)'
      when a.sp_group = 'GA Subs 35K and Above (Non 35K)' then 'Acq Rev 35K and Above (Non 35K)'
 else 'Acq Rev (below 35k)' end as sp_group,
 vdt_id
 from
 (
  select *, case when games_rev > (acq_rev - games_rev) then 'GA Games' else 'GA Non Games' end as GA_tag
  from `data-bi-prd-935c.bi_stg`.tmp_ga_35k a
 ) a
 where a.GA_Tag = 'GA Non Games' 
 and a.sp_group in ('GA Subs 35K and Above (35K)', 'GA Subs 35K and Above (Non 35K)', 'GA Subs (below 35k)') 
 and a.dt = vdt_id
 group by 1,2,3,5,6,7,8;

 



 --Games
 
 insert into `data-bi-prd-935c.bi_dev`.ioh_snd_master_kpi_detail
 select '3ID' as brand, 
 'site_id' as level,
 a.site_id as level_value,
 count(distinct a.sbscrptn_ek_id) as values,
 'mtd' as time_flag,
 current_timestamp as insert_date,
 case when a.sp_group = 'GA Subs 35K and Above (35K)' then 'GA Subs Games (35K)'
 else 'GA Subs Games (Non 35K)' end as sp_group,
 vdt_id
 from
 (
  select *, case when games_rev > (acq_rev - games_rev) then 'GA Games' else 'GA Non Games' end as GA_tag
  from `data-bi-prd-935c.bi_stg`.tmp_ga_35k a
 ) a
 where a.GA_Tag = 'GA Games' 
 and a.sp_group in ('GA Subs 35K and Above (35K)', 'GA Subs 35K and Above (Non 35K)', 'GA Subs (below 35k)')
 and a.dt = vdt_id
 group by 1,2,3,5,6,7,8;

 

 insert into `data-bi-prd-935c.bi_dev`.ioh_snd_master_kpi_detail
 select '3ID' as brand, 
 'site_id' as level,
 a.site_id as level_value,
 cast(sum(a.acq_rev) as numeric) as values,
 'mtd' as time_flag,
 current_timestamp as insert_date,
 case when a.sp_group = 'GA Subs 35K and Above (35K)' then 'Acq Rev Games (35K)'
 else 'Acq Rev Games (Non 35K)' end as sp_group,
 vdt_id
 from
 (
  select *, case when games_rev > (acq_rev - games_rev) then 'GA Games' else 'GA Non Games' end as GA_tag
  from `data-bi-prd-935c.bi_stg`.tmp_ga_35k a
 ) a
 where a.GA_Tag = 'GA Games' 
 and a.sp_group in ('GA Subs 35K and Above (35K)', 'GA Subs 35K and Above (Non 35K)', 'GA Subs (below 35k)') 
 and a.dt = vdt_id
 group by 1,2,3,5,6,7,8;

 


 --Non Games & Games Parents

 insert into `data-bi-prd-935c.bi_dev`.ioh_snd_master_kpi_detail
 select brand, 
 level,
 level_value,
 sum(values) as values,
 time_flag,
 current_timestamp as insert_date,
 case when kpi in ('GA Subs 35K and Above (35K)', 'GA Subs 35K and Above (Non 35K)') then 'GA Subs 35K and Above'
 when kpi in ('GA Subs Games (35K)', 'GA Subs Games (Non 35K)') then 'GA Subs Games'
 when kpi in ('Acq Rev 35K and Above (35K)', 'Acq Rev 35K and Above (Non 35K)') then 'Acq Rev 35K and Above'
 when kpi in ('Acq Rev Games (35K)', 'Acq Rev Games (Non 35K)') then 'Acq Rev Games'
 else 'N/A' end as kpi,
 vdt_id
 from `data-bi-prd-935c.bi_dev`.ioh_snd_master_kpi_detail
 where dt_id = vdt_id		
 and time_flag = 'mtd'
 and kpi in ('GA Subs 35K and Above (35K)', 'GA Subs 35K and Above (Non 35K)', 'GA Subs Games (35K)', 'GA Subs Games (Non 35K)',
 'Acq Rev 35K and Above (35K)', 'Acq Rev 35K and Above (Non 35K)', 'Acq Rev Games (35K)', 'Acq Rev Games (Non 35K)') and brand = '3ID'
 group by 1,2,3,5,6,7,8;


-- f_new_dashboard_load_add

 
delete from `data-bi-prd-935c.bi_dev`.ioh_snd_master_kpi_detail where brand = '3ID' and kpi = 'tot_rev_arpu' and dt_id = vdt_id;

insert into `data-bi-prd-935c.bi_dev`.ioh_snd_master_kpi_detail
select '3ID',
level,
level_value,
cast(sum((val/days)*30) as numeric),
'mtd',
timestamp(current_datetime('+7')),
'tot_rev_arpu',
vdt_id
from
(
 select vdt_id as dt_id, cast(right(cast(vdt_id as string),2) as integer) as days, level, level_value, sum(values) as val
 from `data-bi-prd-935c.bi_dev`.ioh_snd_master_kpi_detail
 where kpi in ('tot_rev') and brand = '3ID' and time_flag = 'dly'
 and dt_id between date_trunc(vdt_id,month) and vdt_id
 group by 1,2,3,4
) a
group by 1,2,3,5,6,7,8;


create or replace table `data-bi-prd-935c.bi_stg`.tmp_tot_rev_avg_site AS
select distinct vdt_id as dt_id, site_id
from `data-bi-prd-935c.bi_mart`.fct_RGU30_Aging_Circle
where dt in (date_trunc( vdt_id,month) - interval 1 day, vdt_id);

delete from `data-bi-prd-935c.bi_dev`.ioh_snd_master_kpi_detail where brand = '3ID' and kpi = 'pre_rgu_30d_arpu' and dt_id =  vdt_id ;

insert into `data-bi-prd-935c.bi_dev`.ioh_snd_master_kpi_detail
select '3ID',
'site_id',
site_id,
cast(sum(subs/2) as numeric),
'mtd',
timestamp(current_datetime('+7')),
'pre_rgu_30d_arpu',
vdt_id
from
(
 select a.*, sum(subs) as subs
 from `data-bi-prd-935c.bi_stg`.tmp_tot_rev_avg_site a
 left outer join
 (
  select site_id, count(distinct sbscrptn_ek_id) as subs
  from `data-bi-prd-935c.bi_mart`.fct_RGU30_Aging_Circle
  where dt = vdt_id
  group by 1
 ) b on a.site_id = b.site_id
 group by 1,2

 union all

 select a.*, sum(subs) as subs
 from `data-bi-prd-935c.bi_stg`.tmp_tot_rev_avg_site a
 left outer join
 (
  select site_id, count(distinct sbscrptn_ek_id) as subs
  from `data-bi-prd-935c.bi_mart`.fct_RGU30_Aging_Circle
  where dt = date_trunc( vdt_id,month) - interval 1 day
  group by 1
 ) b on a.site_id = b.site_id
 group by 1,2
) a
group by 1,2,3,5,6,7,8;

--*************
--RGU90 by Site
--*************


create or replace table `data-bi-prd-935c.bi_stg`.tmp_tot_rev_avg_site AS
select distinct vdt_id as dt_id, site_id
from `data-bi-prd-935c.bi_mart`.fct_RGU90_Aging_Circle
where dt in (date_trunc( vdt_id,month) - interval 1 day,
vdt_id);



delete from `data-bi-prd-935c.bi_dev`.ioh_snd_master_kpi_detail where brand = '3ID' and kpi = 'pre_rgu_90d_arpu' and dt_id = vdt_id;



insert into `data-bi-prd-935c.bi_dev`.ioh_snd_master_kpi_detail
select '3ID',
'site_id',
site_id,
cast(sum(subs/2) as numeric),
'mtd',
timestamp(current_datetime('+7')),
'pre_rgu_90d_arpu',
vdt_id
from
(
 select a.*, sum(subs) as subs
 from `data-bi-prd-935c.bi_stg`.tmp_tot_rev_avg_site a
 left outer join
 (
  select site_id, count(distinct sbscrptn_ek_id) as subs
  from `data-bi-prd-935c.bi_mart`.fct_RGU90_Aging_Circle
  where dt = vdt_id
  group by 1
 ) b on a.site_id = b.site_id
 group by 1,2

 union all

 select a.*, sum(subs) as subs
 from `data-bi-prd-935c.bi_stg`.tmp_tot_rev_avg_site a
 left outer join
 (
  select site_id, count(distinct sbscrptn_ek_id) as subs
  from `data-bi-prd-935c.bi_mart`.fct_RGU90_Aging_Circle
  where dt = date_trunc( vdt_id,month) - interval 1 day
  group by 1
 ) b on a.site_id = b.site_id
 group by 1,2
) a
group by 1,2,3,5,6,7,8; 