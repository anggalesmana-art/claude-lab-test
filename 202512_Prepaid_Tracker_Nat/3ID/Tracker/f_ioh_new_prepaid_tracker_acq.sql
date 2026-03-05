 DECLARE vdt_id DATE DEFAULT @vdt_id;
--  DECLARE vdt_id DATE DEFAULT @vdt_id;

 drop table if exists `data-bi-prd-935c.bi_stg.tmp_new_tracker_acq_1`;

 create table `data-bi-prd-935c.bi_stg.tmp_new_tracker_acq_1` as
 with subs as (select * from `data-dtptechm-prd-c7ca.dwh.sbscrptn_attribs`)
 select distinct cast(sbscrptn_ek_id as string) as sbscrptn_ek_id, 
 upper(call_plan_desc) as cp, 
 upper(promo_desc) as sp,
 segment,
 angie_retailer_name, 
 coalesce(ret_hierarchy_type, 'N/A') as ret_hierarchy_type,
 case 
  when coalesce(ret_hierarchy_type, 'N/A') in ('TRI OFFICIAL STORE','DVM') then 
   case when angie_retailer_name = '00240190' then 'MOCHAN ONLINE' else '3 STORE' end
  when upper(call_plan_desc) like '%MOCHAN%' then 'MOCHAN OFFLINE' --> semua SP AON MOCHAN belong to MOCHAN
  when coalesce(ret_hierarchy_type,'NA') = 'ANGIE' THEN 'TRADITIONAL RETAILER'
  when coalesce(ret_hierarchy_type,'NA') = 'SAHABAT' then '3 BUSINESS'
 else ret_hierarchy_type end as Channel
 from  subs a
 left outer join `data-dtptechm-prd-c7ca.dwh.angie_hrchy_dim` b ON a.angie_retailer_name = b.partner_qr_cd
 left outer join `data-bi-prd-935c.bi_mart.ref_callplan_hvc_mvc_lvc` c on a.call_plan_desc = c.call_plan and parse_date('%Y%m%d',cast(c.start_date as string)) <= vdt_id and parse_date('%Y%m%d',cast(c.end_date as string)) >= vdt_id
 ;

  --`data-bi-prd-935c.bi_stg.tmp_new_tracker_acq_2`
 
 drop table if exists `data-bi-prd-935c.bi_stg.tmp_new_tracker_acq_2`;

 create table `data-bi-prd-935c.bi_stg.tmp_new_tracker_acq_2` as
 select date_trunc(trx_dt_sk_id,month) as mth, cast(sbscrptn_ek_id as string) as sbscrptn_ek_id, sum(revenue) as rev
 from `data-bi-prd-935c.bi_mart.fct_cwn_rev_detail_fnl`
 where trx_dt_sk_id >= date_trunc(vdt_id,month)
 and trx_dt_sk_id <= vdt_id
 group by 1,2
;



 --`data-bi-prd-935c.bi_stg.tmp_new_tracker_acq_3`
 
 drop table if exists `data-bi-prd-935c.bi_stg.tmp_new_tracker_acq_3`;

 


 create table `data-bi-prd-935c.bi_stg.tmp_new_tracker_acq_3` as
 select distinct date_trunc(dt,month) as mth, cast(sbscrptn_ek_id as string) as sbscrptn_ek_id
 from `data-bi-prd-935c.bi_mart.dm_rgs30_subs_movement_detail`
 where dt = vdt_id
 and flag_rotation = 'New New';

 --fct_sim_demand_hist

delete from `data-bi-prd-935c.bi_mart.fct_sim_demand_hist` where dt = vdt_id;


insert into `data-bi-prd-935c.bi_mart.fct_sim_demand_hist`
 select cast(trx_dt_sk_id as date) as dt, cast(a.sbscrptn_ek_id as string) sbscrptn_ek_id,
 sum(case when service_type_category_1 <> 'FRC' then gross_revenue else 0 end) as kpk_price,
 sum(case when service_type_category_1 = 'FRC' then gross_revenue else 0 end) as injection,
 sum(gross_revenue) as total_sim
 from `data-dtptechm-prd-c7ca.dwh.revenue_base` a
 where process_nm = 'SIM_DEMAND' and revenue_book_incl_ind = 'INCLUDE'
 and cast(trx_dt_sk_id as date) = vdt_id
 group by 1,2;

 


 --`data-bi-prd-935c.bi_stg.tmp_new_tracker_acq_4`
 
 drop table if exists `data-bi-prd-935c.bi_stg.tmp_new_tracker_acq_4`;

--  create table `data-bi-prd-935c.bi_stg.tmp_new_tracker_acq_4` as
--  select distinct a.*, 
--  case when b.channel = 'TRADITIONAL RETAILER' then 'Trade' else 'Non Trade' end as Trade_Tag,
--  coalesce(b.segment, 'LVC') as segment,
--  case when c.retailer_qrcode is not null then 'DSF' else 'Non DSF' end as DSF_Tag,
--  case when d.sbscrptn_ek_id is not null then 'New' else 'Old' end as Rotate_Tag
--  from
--  (
--   select distinct ga_date, cast(sbscrptn_ek_id as string) as sbscrptn_ek_id
--   from `data-bi-prd-935c.bi_mart.project_ioh_fu_master_v2`
--   where ga_date = vdt_id
--  ) a
--  left outer join `data-bi-prd-935c.bi_stg.tmp_new_tracker_acq_1` b on a.sbscrptn_ek_id = b.sbscrptn_ek_id
--  left outer join
--  (
--   select distinct retailer_qrcode, parse_date('%Y%m%d',cast(coalesce(activation_time,19000101) as string)) as ret_active_date
--   from `data-bi-prd-935c.bi_mart.dsf_list_reference_phy`
--  ) c on b.angie_retailer_name = c.retailer_qrcode and a.ga_date >= c.ret_active_date
--  left outer join `data-bi-prd-935c.bi_stg.tmp_new_tracker_acq_3` d on date_trunc(a.ga_date,month) = d.mth and a.sbscrptn_ek_id = d.sbscrptn_ek_id;



create table `data-bi-prd-935c.bi_stg.tmp_new_tracker_acq_4` as
 select distinct a.*, 
 case when b.channel = 'TRADITIONAL RETAILER' then 'Trade' else 'Non Trade' end as Trade_Tag,
 case when a.total_sim is null then coalesce(b.segment,'MVC')
      when a.total_sim <= 10000 then 'LVC'
      when a.total_sim <= 35000 then 'MVC'
      when a.total_sim > 35000 then 'HVC'
 end segment, --new logic that apply on 01 Jul 2024 onwards
 case when c.retailer_qrcode is not null then 'DSF' else 'Non DSF' end as DSF_Tag,
 case when d.sbscrptn_ek_id is not null then 'New' else 'Old' end as Rotate_Tag
 from
 (
  select ga_date, sbscrptn_ek_id, total_sim, row_number()over(partition by sbscrptn_ek_id order by dt_sim desc) as seq
  from
  (
   select distinct a.ga_date, a.sbscrptn_ek_id, b.total_sim, b.dt as dt_sim
   from `data-bi-prd-935c.bi_mart.project_ioh_fu_master_v2` a
   left outer join `data-bi-prd-935c.bi_mart.fct_sim_demand_hist` b on a.sbscrptn_ek_id = b.sbscrptn_ek_id and a.ga_date >= b.dt
   where ga_date = vdt_id
  ) a
 ) a
 left outer join `data-bi-prd-935c.bi_stg.tmp_new_tracker_acq_1` b on a.sbscrptn_ek_id = b.sbscrptn_ek_id
 left outer join
 (
  select distinct retailer_qrcode, parse_date('%Y%m%d',cast(coalesce(activation_time,19000101) as string))  as ret_active_date
  from `data-bi-prd-935c.bi_mart.dsf_list_reference_phy`
 ) c on b.angie_retailer_name = c.retailer_qrcode and a.ga_date >= c.ret_active_date
 left outer join `data-bi-prd-935c.bi_stg.tmp_new_tracker_acq_3` d on date_trunc(a.ga_date,month) = d.mth  and a.sbscrptn_ek_id = d.sbscrptn_ek_id
 where a.seq = 1; -- revamped by Indra by Mas Denny Request 20240722


--`data-bi-prd-935c.bi_stg.tmp_new_tracker_acq_5`
 
 drop table if exists `data-bi-prd-935c.bi_stg.tmp_new_tracker_acq_5`;

 create table `data-bi-prd-935c.bi_stg.tmp_new_tracker_acq_5` as
 select distinct a.*, 
 case when b.channel = 'TRADITIONAL RETAILER' then 'Trade' else 'Non Trade' end as Trade_Tag,
 coalesce(b.segment, 'MVC') as segment,
 case when c.retailer_qrcode is not null then 'DSF' else 'Non DSF' end as DSF_Tag,
 coalesce(d.rev,0) as revenue,
 case when e.sbscrptn_ek_id is not null then 'New' else 'Old' end as Rotate_Tag
 from
 (
  select distinct cast(vdt_id as date) as ga_date, cast(sbscrptn_ek_id as string) as sbscrptn_ek_id
  from `data-bi-prd-935c.bi_mart.project_ioh_fu_master_v2`
  where ga_date >= date_trunc(vdt_id,month)
  and ga_date <= vdt_id 
 ) a
 left outer join `data-bi-prd-935c.bi_stg.tmp_new_tracker_acq_1` b on a.sbscrptn_ek_id = b.sbscrptn_ek_id
 left outer join
 (
  select distinct retailer_qrcode, parse_date('%Y%m%d',cast(coalesce(activation_time,19000101) as string)) as ret_active_date
  from `data-bi-prd-935c.bi_mart.dsf_list_reference_phy`
 ) c on b.angie_retailer_name = c.retailer_qrcode and a.ga_date >= c.ret_active_date
 left outer join `data-bi-prd-935c.bi_stg.tmp_new_tracker_acq_2` d on date_trunc(a.ga_date,month) = d.mth and a.sbscrptn_ek_id = d.sbscrptn_ek_id
 left outer join `data-bi-prd-935c.bi_stg.tmp_new_tracker_acq_3` e on date_trunc(a.ga_date,month) = e.mth and a.sbscrptn_ek_id = e.sbscrptn_ek_id;

 


 --`data-bi-prd-935c.bi_stg.tmp_new_tracker_acq_6`
 
 drop table if exists `data-bi-prd-935c.bi_stg.tmp_new_tracker_acq_6`;

 


 create table `data-bi-prd-935c.bi_stg.tmp_new_tracker_acq_6` as
 select distinct service_msisdn
 from `data-bi-prd-935c.bi_mart.project_ioh_dgpcr_flag_hist`
 where dt_sk_id=vdt_id and x_dgpcr_flag in ('Y', 'A');

 drop table if exists `data-bi-prd-935c.bi_stg.tmp_new_tracker_acq_6a`;

 create table `data-bi-prd-935c.bi_stg.tmp_new_tracker_acq_6a` as
  select distinct cast(load_dt_sk_id as date) load_dt_sk_id, cast(a.sbscrptn_ek_id as string) sbscrptn_ek_id, a.sbscrptn_msisdn
  from `data-dtptechm-prd-c7ca.dwh.ioh_sales_distribution_kpi_subs_detail` a
  where heading_tag = 'ACQUISITION'
  and month_kpi_tag = 'M-0'
  and cast(load_dt_sk_id as date) = vdt_id;

 --`data-bi-prd-935c.bi_stg.tmp_new_tracker_acq_7`
 
 drop table if exists `data-bi-prd-935c.bi_stg.tmp_new_tracker_acq_7`;

 create table `data-bi-prd-935c.bi_stg.tmp_new_tracker_acq_7` as
 select distinct a.*, 
 case when b.channel = 'TRADITIONAL RETAILER' then 'Trade' else 'Non Trade' end as Trade_Tag,
 coalesce(b.segment, 'MVC') as segment,
 case when c.retailer_qrcode is not null then 'DSF' else 'Non DSF' end as DSF_Tag
 from `data-bi-prd-935c.bi_stg.tmp_new_tracker_acq_6a` a
 left outer join `data-bi-prd-935c.bi_stg.tmp_new_tracker_acq_1` b on a.sbscrptn_ek_id = b.sbscrptn_ek_id
 left outer join
 (
  select distinct retailer_qrcode, parse_date('%Y%m%d',cast(coalesce(activation_time,19000101) as string)) as ret_active_date
  from `data-bi-prd-935c.bi_mart.dsf_list_reference_phy`
 ) c on b.angie_retailer_name = c.retailer_qrcode and a.load_dt_sk_id >= c.ret_active_date
 join `data-bi-prd-935c.bi_stg.tmp_new_tracker_acq_6` d on a.sbscrptn_msisdn = d.service_msisdn;

 


 --`data-bi-prd-935c.bi_stg.tmp_new_tracker_acq_8`
 
 drop table if exists `data-bi-prd-935c.bi_stg.tmp_new_tracker_acq_8`;


 create table `data-bi-prd-935c.bi_stg.tmp_new_tracker_acq_8` as
 select distinct tag, ga_date, cast(sbscrptn_ek_id as string) as sbscrptn_ek_id, m_date
 from `data-bi-prd-935c.bi_mart.fct_ga_m1s_m2s_detail`
 where tag in ('M1S', 'M2S') and m_date = vdt_id;

 
--select * from `data-bi-prd-935c.bi_stg.tmp_new_tracker_acq_9` limit 11
 
 drop table if exists `data-bi-prd-935c.bi_stg.tmp_new_tracker_acq_9`;

 
 create table `data-bi-prd-935c.bi_stg.tmp_new_tracker_acq_9` as
 select distinct a.*, 
 case when b.channel = 'TRADITIONAL RETAILER' then 'Trade' else 'Non Trade' end as Trade_Tag,
 coalesce(b.segment, 'MVC') as segment,
 case when c.retailer_qrcode is not null then 'DSF' else 'Non DSF' end as DSF_Tag
 from `data-bi-prd-935c.bi_stg.tmp_new_tracker_acq_8` a
 left outer join `data-bi-prd-935c.bi_stg.tmp_new_tracker_acq_1` b on a.sbscrptn_ek_id = b.sbscrptn_ek_id
 left outer join
 (
  select distinct retailer_qrcode, parse_date('%Y%m%d',cast(coalesce(activation_time,19000101) as string)) as ret_active_date
  from `data-bi-prd-935c.bi_mart.dsf_list_reference_phy`
 ) c on b.angie_retailer_name = c.retailer_qrcode and a.m_date >= c.ret_active_date
 ;
 
 --`data-bi-prd-935c.bi_stg.tmp_new_tracker_acq_10`
 
 drop table if exists `data-bi-prd-935c.bi_stg.tmp_new_tracker_acq_10`;

--  create table `data-bi-prd-935c.bi_stg.tmp_new_tracker_acq_10` as
--  select distinct cast(sbscrptn_ek_id as string) as sbscrptn_ek_id
--  from `data-dtptechm-prd-c7ca.dwh.cem_top_apps_master_fct`
--  where application_name = 'Facebook'
--  and cast(load_date_sk_id as date) >= date_trunc(vdt_id,month) 
--  and cast(load_date_sk_id as date) <= vdt_id;

  drop table if exists `data-bi-prd-935c.bi_stg.tmp_new_tracker_acq_10`;
create table `data-bi-prd-935c.bi_stg.tmp_new_tracker_acq_10` as
with subs as (select * from `data-dtptechm-prd-c7ca.dwh.sbscrptn_attribs`)
 select distinct sbscrptn_ek_id
 from `data-dtp-prd-aa1a.stg.stg_nio_appsrtgout` a 
 left join subs b 
 on a.msisdn = b.sbscrptn_msisdn and b.rank_ind = 1 
 where application_name = 'Facebook'
 and date(a.dt_id) >= date_trunc(cast(vdt_id as date),month)
 and date(a.dt_id) <= cast(vdt_id as date);


 
 drop table if exists `data-bi-prd-935c.bi_stg.tmp_new_tracker_acq_11`;

 

-- select * from `data-bi-prd-935c.bi_stg.tmp_new_tracker_acq_11` limit 11
 create table `data-bi-prd-935c.bi_stg.tmp_new_tracker_acq_11` as
 select distinct a.*, 
 case when b.channel = 'TRADITIONAL RETAILER' then 'Trade' else 'Non Trade' end as Trade_Tag,
 coalesce(b.segment, 'MVC') as segment,
 case when c.retailer_qrcode is not null then 'DSF' else 'Non DSF' end as DSF_Tag
 from 
 (
  select distinct cast(vdt_id as date) as ga_date, cast(sbscrptn_ek_id as string) as sbscrptn_ek_id
  from `data-bi-prd-935c.bi_mart.project_ioh_fu_master_v2`
  where ga_date >= date_trunc(vdt_id,month)
  and ga_date <= vdt_id
 ) a
 left outer join `data-bi-prd-935c.bi_stg.tmp_new_tracker_acq_1` b on a.sbscrptn_ek_id = b.sbscrptn_ek_id
 left outer join
 (
  select distinct retailer_qrcode, parse_date('%Y%m%d',cast(coalesce(activation_time,19000101) as string)) as ret_active_date
  from `data-bi-prd-935c.bi_mart.dsf_list_reference_phy`
 ) c on b.angie_retailer_name = c.retailer_qrcode and a.ga_date >= c.ret_active_date
 join `data-bi-prd-935c.bi_stg.tmp_new_tracker_acq_10` d on cast(a.sbscrptn_ek_id as string) = cast(d.sbscrptn_ek_id as string)
 ;

 
 
 
 --ACQ0003, ACQ0004, ACQ0005, ACQ0006
 delete from `data-bi-prd-935c.bi_mart.kpi_national_tracker_dly` where brand = 'TRI' and dt_id = vdt_id and kpi_id in ('ACQ0003', 'ACQ0004', 'ACQ0005', 'ACQ0006');

 
                                                                                                                                                  																		   
 insert into `data-bi-prd-935c.bi_mart.kpi_national_tracker_dly`
 select 'TRI' as brand, '' as kpi_code, 'DLY' as flag, 
 count(distinct a.sbscrptn_ek_id) as metric,
 current_timestamp() as process_dt, 
 'ACQ0003' as kpi_id,
 cast(vdt_id as date) as dt_id 
 from `data-bi-prd-935c.bi_stg.tmp_new_tracker_acq_4` a
 group by 1,2,3,5,6,7

 union all  

 select 'TRI' as brand, '' as kpi_code, 'DLY' as flag, 
 count(distinct a.sbscrptn_ek_id) as metric,
 current_timestamp() as process_dt, 
 case when upper(segment) = 'HVC' then 'ACQ0004'
 when upper(segment) = 'MVC' then 'ACQ0005'
 when upper(segment) = 'LVC' then 'ACQ0006'
 else 'ACQ0000' end as kpi_id,
 cast(vdt_id as date) as dt_id 
 from `data-bi-prd-935c.bi_stg.tmp_new_tracker_acq_4` a
 group by 1,2,3,5,6,7;

 


 --ACQ0007, ACQ0008, ACQ0009
 delete from `data-bi-prd-935c.bi_mart.kpi_national_tracker_dly` where brand = 'TRI' and dt_id = vdt_id and kpi_id in ('ACQ0007', 'ACQ0008', 'ACQ0009');

 
                                                                                                                                                  																		   
 insert into `data-bi-prd-935c.bi_mart.kpi_national_tracker_dly`
 select 'TRI' as brand, '' as kpi_code, 'DLY' as flag, 
 count(distinct a.sbscrptn_ek_id) as metric,
 current_timestamp() as process_dt, 
 case when Trade_Tag = 'Trade' then 'ACQ0007' else 'ACQ0009' end as kpi_id,
 cast(vdt_id as date) as dt_id 
 from `data-bi-prd-935c.bi_stg.tmp_new_tracker_acq_4` a
 group by 1,2,3,5,6,7

 union all 

 select 'TRI' as brand, '' as kpi_code, 'DLY' as flag, 
 count(distinct a.sbscrptn_ek_id) as metric,
 current_timestamp() as process_dt, 
 'ACQ0008' as kpi_id,
 cast(vdt_id as date) as dt_id 
 from `data-bi-prd-935c.bi_stg.tmp_new_tracker_acq_4` a
 where Trade_Tag = 'Trade' and DSF_Tag = 'DSF'
 group by 1,2,3,5,6,7;

 



 --ACQ0011 until ACQ0016
 delete from `data-bi-prd-935c.bi_mart.kpi_national_tracker_dly` where brand = 'TRI' and dt_id = vdt_id and kpi_id in ('ACQ0011', 'ACQ0012', 'ACQ0013', 'ACQ0014', 'ACQ0015', 'ACQ0016');

 
                                                                                                                                                  																		   
 insert into `data-bi-prd-935c.bi_mart.kpi_national_tracker_dly`
 select 'TRI' as brand, '' as kpi_code, 'MTD' as flag, 
 sum(a.revenue) as metric,
 current_timestamp() as process_dt, 
 'ACQ0011' as kpi_id,
 cast(vdt_id as date) as dt_id 
 from `data-bi-prd-935c.bi_stg.tmp_new_tracker_acq_5` a
 group by 1,2,3,5,6,7

 union all  

 select 'TRI' as brand, '' as kpi_code, 'MTD' as flag, 
 sum(a.revenue) as metric,
 current_timestamp() as process_dt, 
 'ACQ0013' as kpi_id,
 cast(vdt_id as date) as dt_id 
 from `data-bi-prd-935c.bi_stg.tmp_new_tracker_acq_5` a
 group by 1,2,3,5,6,7

 union all  

 select 'TRI' as brand, '' as kpi_code, 'MTD' as flag, 
 sum(a.revenue) as metric,
 current_timestamp() as process_dt, 
 case when upper(segment) = 'HVC' then 'ACQ0014'
 when upper(segment) = 'MVC' then 'ACQ0015'
 when upper(segment) = 'LVC' then 'ACQ0016'
 else 'ACQ0000' end as kpi_id,
 cast(vdt_id as date) as dt_id 
 from `data-bi-prd-935c.bi_stg.tmp_new_tracker_acq_5` a
 group by 1,2,3,5,6,7;

 


 --ACQ0017 until ACQ0019
 delete from `data-bi-prd-935c.bi_mart.kpi_national_tracker_dly` where brand = 'TRI' and dt_id = vdt_id and kpi_id in ('ACQ0017', 'ACQ0018', 'ACQ0019');

 
                                                                                                                                                  																		   
 insert into `data-bi-prd-935c.bi_mart.kpi_national_tracker_dly`
 select 'TRI' as brand, '' as kpi_code, 'MTD' as flag, 
 sum(a.revenue) as metric,
 current_timestamp() as process_dt, 
 case when Trade_Tag = 'Trade' then 'ACQ0017' else 'ACQ0019' end as kpi_id,
 cast(vdt_id as date) as dt_id 
 from `data-bi-prd-935c.bi_stg.tmp_new_tracker_acq_5` a
 group by 1,2,3,5,6,7

 union all 

 select 'TRI' as brand, '' as kpi_code, 'MTD' as flag, 
 sum(a.revenue) as metric,
 current_timestamp() as process_dt, 
 'ACQ0018' as kpi_id,
 cast(vdt_id as date) as dt_id 
 from `data-bi-prd-935c.bi_stg.tmp_new_tracker_acq_5` a
 where Trade_Tag = 'Trade' and DSF_Tag = 'DSF'
 group by 1,2,3,5,6,7;

 


 --ACQ0021
 delete from `data-bi-prd-935c.bi_mart.kpi_national_tracker_dly` where brand = 'TRI' and dt_id = vdt_id and kpi_id in ('ACQ0021');

 
                                                                                                                                                  																		   
 insert into `data-bi-prd-935c.bi_mart.kpi_national_tracker_dly`
 select 'TRI' as brand, '' as kpi_code, 'MTD' as flag, 
 count(distinct a.sbscrptn_ek_id) as metric,
 current_timestamp() as process_dt, 
 'ACQ0021' as kpi_id,
 cast(vdt_id as date) as dt_id 
 from `data-bi-prd-935c.bi_stg.tmp_new_tracker_acq_5` a
 where Rotate_Tag = 'Old'
 group by 1,2,3,5,6,7;

 --ACQ0022 until AC0026
 delete from `data-bi-prd-935c.bi_mart.kpi_national_tracker_dly` where brand = 'TRI' and dt_id = vdt_id and kpi_id in ('ACQ0022', 'ACQ0023', 'ACQ0024', 'ACQ0025', 'ACQ0026');
                																		   
 insert into `data-bi-prd-935c.bi_mart.kpi_national_tracker_dly`
 select 'TRI' as brand, '' as kpi_code, 'MTD' as flag, 
 a.metric/b.metric as metric,
 current_timestamp() as process_dt, 
 'ACQ0022' as kpi_id,
 cast(vdt_id as date) as dt_id 
 from `data-bi-prd-935c.bi_mart.kpi_national_tracker_dly` a
 left outer join
 (
  select cast(vdt_id as date) as dt_id, sum(metric) as metric
  from `data-bi-prd-935c.bi_mart.kpi_national_tracker_dly`
  where dt_id >= date_trunc(vdt_id,month ) and dt_id <= vdt_id 
  and kpi_id = 'ACQ0003' and brand= 'TRI'
  group by 1
 ) b on a.dt_id = b.dt_id
 where a.dt_id = vdt_id and kpi_id = 'ACQ0011' and a.brand= 'TRI'

 union all  

 select 'TRI' as brand, '' as kpi_code, 'MTD' as flag, 
 a.metric/b.metric as metric,
 current_timestamp() as process_dt, 
 'ACQ0023' as kpi_id,
 cast(vdt_id as date) as dt_id 
 from `data-bi-prd-935c.bi_mart.kpi_national_tracker_dly` a
 left outer join
 (
  select cast(vdt_id as date) as dt_id, sum(metric) as metric
  from `data-bi-prd-935c.bi_mart.kpi_national_tracker_dly`
  where dt_id >= date_trunc(vdt_id,month) and dt_id <= vdt_id 
  and kpi_id = 'ACQ0007'and brand= 'TRI'
  group by 1
 ) b on a.dt_id = b.dt_id
 where a.dt_id = vdt_id and kpi_id = 'ACQ0017' and a.brand= 'TRI'

 union all  

 select 'TRI' as brand, '' as kpi_code, 'MTD' as flag, 
 a.metric/b.metric as metric,
 current_timestamp() as process_dt, 
 'ACQ0024' as kpi_id,
 cast(vdt_id as date) as dt_id 
 from `data-bi-prd-935c.bi_mart.kpi_national_tracker_dly` a
 left outer join
 (
  select cast(vdt_id as date) as dt_id, sum(metric) as metric
  from `data-bi-prd-935c.bi_mart.kpi_national_tracker_dly`
  where dt_id >= date_trunc(vdt_id,month) and dt_id <= vdt_id 
  and kpi_id = 'ACQ0008' and brand= 'TRI'
  group by 1
 ) b on a.dt_id = b.dt_id
 where a.dt_id = vdt_id and kpi_id = 'ACQ0018' and a.brand= 'TRI'
 
 union all  

 select 'TRI' as brand, '' as kpi_code, 'MTD' as flag, 
 a.metric/b.metric as metric,
 current_timestamp() as process_dt, 
 'ACQ0025' as kpi_id,
 cast(vdt_id as date) as dt_id 
 from `data-bi-prd-935c.bi_mart.kpi_national_tracker_dly` a
 left outer join
 (
  select cast(vdt_id as date) as dt_id, sum(metric) as metric
  from `data-bi-prd-935c.bi_mart.kpi_national_tracker_dly`
  where dt_id >= date_trunc(vdt_id,month) and dt_id <= vdt_id 
  and kpi_id = 'ACQ0009' and brand= 'TRI'
  group by 1
 ) b on a.dt_id = b.dt_id
 where a.dt_id = vdt_id and kpi_id = 'ACQ0019' and a.brand= 'TRI'
 ;

 

 
 --ACQ0027 until AC0030
 delete from `data-bi-prd-935c.bi_mart.kpi_national_tracker_dly` where brand = 'TRI' and dt_id = vdt_id and kpi_id in ('ACQ0027', 'ACQ0028', 'ACQ0029', 'ACQ0030');

 

 insert into `data-bi-prd-935c.bi_mart.kpi_national_tracker_dly`
 select 'TRI' as brand, '' as kpi_code, 'MTD' as flag, 
 count(distinct a.sbscrptn_ek_id) as metric,
 current_timestamp() as process_dt, 
 'ACQ0027' as kpi_id,
 cast(vdt_id as date) as dt_id 
 from `data-bi-prd-935c.bi_stg.tmp_new_tracker_acq_7` a
 group by 1,2,3,5,6,7

 union all 
 
 select 'TRI' as brand, '' as kpi_code, 'MTD' as flag, 
 count(distinct a.sbscrptn_ek_id) as metric,
 current_timestamp() as process_dt, 
 case when Trade_Tag = 'Trade' then 'ACQ0028' else 'ACQ0030' end as kpi_id,
 cast(vdt_id as date) as dt_id 
 from `data-bi-prd-935c.bi_stg.tmp_new_tracker_acq_7` a
 group by 1,2,3,5,6,7

 union all 

 select 'TRI' as brand, '' as kpi_code, 'MTD' as flag, 
 count(distinct a.sbscrptn_ek_id) as metric,
 current_timestamp() as process_dt, 
 'ACQ0029' as kpi_id,
 cast(vdt_id as date) as dt_id 
 from `data-bi-prd-935c.bi_stg.tmp_new_tracker_acq_7` a
 where Trade_Tag = 'Trade' and DSF_Tag = 'DSF'
 group by 1,2,3,5,6,7;

  


 --ACQ0032 until AC0035
 delete from `data-bi-prd-935c.bi_mart.kpi_national_tracker_dly` where brand = 'TRI' and dt_id = vdt_id and kpi_id in ('ACQ0032', 'ACQ0033', 'ACQ0034', 'ACQ0035');

 

 insert into `data-bi-prd-935c.bi_mart.kpi_national_tracker_dly`
 select 'TRI' as brand, '' as kpi_code, 'MTD' as flag, 
 count(distinct a.sbscrptn_ek_id) as metric,
 current_timestamp() as process_dt, 
 'ACQ0032' as kpi_id,
 cast(vdt_id as date) as dt_id 
 from `data-bi-prd-935c.bi_stg.tmp_new_tracker_acq_9` a
 where tag = 'M1S'
 group by 1,2,3,5,6,7

 union all 
 
 select 'TRI' as brand, '' as kpi_code, 'MTD' as flag, 
 count(distinct a.sbscrptn_ek_id) as metric,
 current_timestamp() as process_dt, 
 case when Trade_Tag = 'Trade' then 'ACQ0033' else 'ACQ0035' end as kpi_id,
 cast(vdt_id as date) as dt_id 
 from `data-bi-prd-935c.bi_stg.tmp_new_tracker_acq_9` a
 where tag = 'M1S'
 group by 1,2,3,5,6,7

 union all 

 select 'TRI' as brand, '' as kpi_code, 'MTD' as flag, 
 count(distinct a.sbscrptn_ek_id) as metric,
 current_timestamp() as process_dt, 
 'ACQ0034' as kpi_id,
 cast(vdt_id as date) as dt_id 
 from `data-bi-prd-935c.bi_stg.tmp_new_tracker_acq_9` a
 where tag = 'M1S' and Trade_Tag = 'Trade' and DSF_Tag = 'DSF'
 group by 1,2,3,5,6,7;

   


 --ACQ0037 until AC0040
 delete from `data-bi-prd-935c.bi_mart.kpi_national_tracker_dly` where brand = 'TRI' and dt_id = vdt_id and kpi_id in ('ACQ0037', 'ACQ0038', 'ACQ0039', 'ACQ0040');

 

 insert into `data-bi-prd-935c.bi_mart.kpi_national_tracker_dly`
 select 'TRI' as brand, '' as kpi_code, 'MTD' as flag, 
 count(distinct a.sbscrptn_ek_id) as metric,
 current_timestamp() as process_dt, 
 'ACQ0037' as kpi_id,
 cast(vdt_id as date) as dt_id 
 from `data-bi-prd-935c.bi_stg.tmp_new_tracker_acq_9` a
 where tag = 'M2S'
 group by 1,2,3,5,6,7

 union all 
 
 select 'TRI' as brand, '' as kpi_code, 'MTD' as flag, 
 count(distinct a.sbscrptn_ek_id) as metric,
 current_timestamp() as process_dt, 
 case when Trade_Tag = 'Trade' then 'ACQ0038' else 'ACQ0040' end as kpi_id,
 cast(vdt_id as date) as dt_id 
 from `data-bi-prd-935c.bi_stg.tmp_new_tracker_acq_9` a
 where tag = 'M2S'
 group by 1,2,3,5,6,7

 union all 

 select 'TRI' as brand, '' as kpi_code, 'MTD' as flag, 
 count(distinct a.sbscrptn_ek_id) as metric,
 current_timestamp() as process_dt, 
 'ACQ0039' as kpi_id,
 cast(vdt_id as date) as dt_id 
 from `data-bi-prd-935c.bi_stg.tmp_new_tracker_acq_9` a
 where tag = 'M2S' and Trade_Tag = 'Trade' and DSF_Tag = 'DSF'
 group by 1,2,3,5,6,7;

 


 --ACQ0042 until AC0045
 delete from `data-bi-prd-935c.bi_mart.kpi_national_tracker_dly` where brand = 'TRI' and dt_id = vdt_id and kpi_id in ('ACQ0042', 'ACQ0043', 'ACQ0044', 'ACQ0045');

 

 insert into `data-bi-prd-935c.bi_mart.kpi_national_tracker_dly`
 select 'TRI' as brand, '' as kpi_code, 'MTD' as flag, 
 count(distinct a.sbscrptn_ek_id) as metric,
 current_timestamp() as process_dt, 
 'ACQ0042' as kpi_id,
 cast(vdt_id as date) as dt_id 
 from `data-bi-prd-935c.bi_stg.tmp_new_tracker_acq_11` a
 group by 1,2,3,5,6,7

 union all 
 
 select 'TRI' as brand, '' as kpi_code, 'MTD' as flag, 
 count(distinct a.sbscrptn_ek_id) as metric,
 current_timestamp() as process_dt, 
 case when Trade_Tag = 'Trade' then 'ACQ0043' else 'ACQ0045' end as kpi_id,
 cast(vdt_id as date) as dt_id 
 from `data-bi-prd-935c.bi_stg.tmp_new_tracker_acq_11` a
 group by 1,2,3,5,6,7

 union all 

 select 'TRI' as brand, '' as kpi_code, 'MTD' as flag, 
 count(distinct a.sbscrptn_ek_id) as metric,
 current_timestamp() as process_dt, 
 'ACQ0044' as kpi_id,
 cast(vdt_id as date) as dt_id 
 from `data-bi-prd-935c.bi_stg.tmp_new_tracker_acq_11` a
 where Trade_Tag = 'Trade' and DSF_Tag = 'DSF'
 group by 1,2,3,5,6,7;
