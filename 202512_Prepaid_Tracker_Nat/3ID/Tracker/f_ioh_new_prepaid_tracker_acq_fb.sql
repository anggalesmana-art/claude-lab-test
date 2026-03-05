 DECLARE vdt_id DATE DEFAULT @vdt_id;

drop table if exists `data-bi-prd-935c.bi_stg.new_tracker_acq_1`;
create table `data-bi-prd-935c.bi_stg.new_tracker_acq_1` as
with subs as (select * from `data-dtptechm-prd-c7ca.dwh.sbscrptn_attribs`)
 select distinct sbscrptn_ek_id, 
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
 from subs a
 left outer join `data-dtptechm-prd-c7ca.dwh.angie_hrchy_dim` b ON a.angie_retailer_name = b.partner_qr_cd 
 left outer join `data-bi-prd-935c.bi_mart.ref_callplan_hvc_mvc_lvc` c on 
 a.call_plan_desc = c.call_plan and parse_date('%Y%m%d',cast(c.start_date as string)) <= cast(vdt_id as date) and parse_date('%Y%m%d',cast(c.end_date as string)) >= cast(vdt_id as date);



 drop table if exists `data-bi-prd-935c.bi_stg.new_tracker_acq_10`;
create table `data-bi-prd-935c.bi_stg.new_tracker_acq_10` as
with subs as (select * from `data-dtptechm-prd-c7ca.dwh.sbscrptn_attribs`)
 select distinct sbscrptn_ek_id
 from `data-dtp-prd-aa1a.stg.stg_nio_appsrtgout` a 
 left join subs b 
 on a.msisdn = b.sbscrptn_msisdn and b.rank_ind = 1 
 where application_name = 'Facebook'
 and date(a.dt_id) >= date_trunc(cast(vdt_id as date),month)
 and date(a.dt_id) <= cast(vdt_id as date);
 

 drop table if exists `data-bi-prd-935c.bi_stg.new_tracker_acq_11`;
 create table `data-bi-prd-935c.bi_stg.new_tracker_acq_11` as
 select distinct a.*, 
 case when b.channel = 'TRADITIONAL RETAILER' then 'Trade' else 'Non Trade' end as Trade_Tag,
 coalesce(b.segment, 'MVC') as segment,
 case when c.retailer_qrcode is not null then 'DSF' else 'Non DSF' end as DSF_Tag
 from 
 (
  select distinct cast(vdt_id as date) as ga_date, sbscrptn_ek_id
  from `data-bi-prd-935c.bi_mart.project_ioh_fu_master_v2`
  where ga_date >= date_trunc(cast(vdt_id as date),month)
  and ga_date <= cast(vdt_id as date)
 ) a
 left outer join `data-bi-prd-935c.bi_stg.new_tracker_acq_1` b on cast(a.sbscrptn_ek_id as string) = cast(b.sbscrptn_ek_id as string)
 left outer join
 (
  select distinct retailer_qrcode, activation_time as ret_active_date
  from `data-bi-prd-935c.bi_mart.dsf_list_reference_phy`
 ) c on b.angie_retailer_name = c.retailer_qrcode and a.ga_date >= parse_date('%Y%m%d',cast(coalesce(c.ret_active_date,19000101) as string))
 join `data-bi-prd-935c.bi_stg.new_tracker_acq_10` d on cast(a.sbscrptn_ek_id as string) = cast(d.sbscrptn_ek_id as string)
 ;
 

--ACQ0042 until AC0045
 delete from `data-bi-prd-935c.bi_mart.kpi_national_tracker_dly` where dt_id = vdt_id and kpi_id in ('ACQ0042', 'ACQ0043', 'ACQ0044', 'ACQ0045');

 

insert into `data-bi-prd-935c.bi_mart.kpi_national_tracker_dly`
 select 'TRI' as brand, '' as kpi_code, 'MTD' as flag, 
 count(distinct a.sbscrptn_ek_id) as metric,
current_timestamp() as process_dt, 
 'ACQ0042' as kpi_id,
 cast(vdt_id as date)  as dt_id 
 from `data-bi-prd-935c.bi_stg.new_tracker_acq_11` a
 group by 1,2,3,5,6,7

 union all
 
 select 'TRI' as brand, '' as kpi_code, 'MTD' as flag, 
 count(distinct a.sbscrptn_ek_id) as metric,
current_timestamp() as process_dt, 
 case when Trade_Tag = 'Trade' then 'ACQ0043' else 'ACQ0045' end as kpi_id,
 cast(vdt_id as date) as dt_id 
 from `data-bi-prd-935c.bi_stg.new_tracker_acq_11` a
 group by 1,2,3,5,6,7

 union all

 select 'TRI' as brand, '' as kpi_code, 'MTD' as flag, 
 count(distinct a.sbscrptn_ek_id) as metric,
current_timestamp() as process_dt, 
 'ACQ0044' as kpi_id,
 cast(vdt_id as date) as dt_id 
 from `data-bi-prd-935c.bi_stg.new_tracker_acq_11` a
 where Trade_Tag = 'Trade' and DSF_Tag = 'DSF'
 group by 1,2,3,5,6,7;