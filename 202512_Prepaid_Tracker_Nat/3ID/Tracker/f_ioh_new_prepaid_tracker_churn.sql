  DECLARE vdt_id DATE DEFAULT @vdt_id;
 

 --************--
 --RGU90-GC Rev 
 --************--


 --`data-bi-prd-935c.bi_stg.tmp_new_tracker_churn_0`
 
 drop table if exists `data-bi-prd-935c.bi_stg.tmp_new_tracker_churn_0`;

 create table `data-bi-prd-935c.bi_stg.tmp_new_tracker_churn_0` as
 select distinct cast(sbscrptn_ek_id as string) as sbscrptn_ek_id,
 (least(cast(first_usage_dt as date), least(parse_date('%Y%m%d',cast(first_billing_usage_dt_sk_id as string)), cast(any_event_first_usage_date as date)))) as fu_dt
 from `data-dtptechm-prd-c7ca.dwh.sbscrptn_attribs`;

  --`data-bi-prd-935c.bi_stg.tmp_new_tracker_churn_1`
 
 drop table if exists `data-bi-prd-935c.bi_stg.tmp_new_tracker_churn_1`;

 create table `data-bi-prd-935c.bi_stg.tmp_new_tracker_churn_1` as
 select cast(sbscrptn_ek_id as string) as sbscrptn_ek_id, sum(revenue) as revenue
 from `data-bi-prd-935c.bi_mart.fct_cwn_rev_detail_fnl`
 where cast(trx_dt_sk_id as date) >= date_sub(vdt_id,interval 119 day)
 and cast(trx_dt_sk_id as date)<= date_sub(vdt_id,interval 90 day)
 group by 1;


 --`data-bi-prd-935c.bi_stg.tmp_new_tracker_churn_2`
 
 drop table if exists `data-bi-prd-935c.bi_stg.tmp_new_tracker_churn_2`;

 


 create table `data-bi-prd-935c.bi_stg.tmp_new_tracker_churn_2` as
 select cast(sbscrptn_ek_id as string) as sbscrptn_ek_id, sum(revenue) as revenue
 from `data-bi-prd-935c.bi_mart.fct_cwn_rev_detail_fnl`
 where cast(trx_dt_sk_id as date) >= date_sub(vdt_id,interval 149 day)
 and cast(trx_dt_sk_id as date) <= date_sub(vdt_id,interval 120 day)
 group by 1;

 


 --`data-bi-prd-935c.bi_stg.tmp_new_tracker_churn_3`
 
 drop table if exists `data-bi-prd-935c.bi_stg.tmp_new_tracker_churn_3`;

 


 create table `data-bi-prd-935c.bi_stg.tmp_new_tracker_churn_3` as
 select cast(sbscrptn_ek_id as string) as sbscrptn_ek_id, sum(revenue) as revenue
 from `data-bi-prd-935c.bi_mart.fct_cwn_rev_detail_fnl`
 where cast(trx_dt_sk_id as date) >= date_sub(vdt_id,interval 179 day)
 and cast(trx_dt_sk_id as date) <= date_sub(vdt_id,interval 150 day)
 group by 1;

 --`data-bi-prd-935c.bi_stg.tmp_new_tracker_churn_4`
 
 drop table if exists `data-bi-prd-935c.bi_stg.tmp_new_tracker_churn_4`;

 

 create table `data-bi-prd-935c.bi_stg.tmp_new_tracker_churn_4` as
 select distinct dt as ga_dt, cast(sbscrptn_ek_id as string) as sbscrptn_ek_id
 from `data-bi-prd-935c.bi_mart.fct_ioh_mvmnt_1_detail_dec21`
 where tag = 'rgu90_gross_add'
 and dt >= '2021-10-01' --tidak usah diubah
 and dt <= '2021-12-31' --tidak usah diubah
 
 union all
 
 select distinct ga_date as ga_dt, cast(sbscrptn_ek_id as string) as sbscrptn_ek_id
 from `data-bi-prd-935c.bi_mart.project_ioh_fu_master_v2`
 where ga_date >= '2022-01-01' --tidak usah diubah
 and ga_date <= vdt_id;

 --`data-bi-prd-935c.bi_stg.tmp_new_tracker_churn_5`
 
 drop table if exists `data-bi-prd-935c.bi_stg.tmp_new_tracker_churn_5`;

 create table `data-bi-prd-935c.bi_stg.tmp_new_tracker_churn_5` as
 select a.dt, a.tag, a.inflow_base, cast(a.sbscrptn_ek_id as string) as sbscrptn_ek_id, a.last_rgu_dt, sum(coalesce(b.revenue,0)) as rev_m1
 from 
 ( 
  select distinct cast(vdt_id as date) as dt,
  a.tag, 
  case when d.ga_dt is not null then
   case when date_diff(date_sub(a.dt ,interval 90 day) , d.ga_dt,day) between 0 and 89 then 'Inflow' else 'Base' end 
  else
   case when date_diff(date_sub(a.dt ,interval 90 day) , e.fu_dt,day) between 0 and 89 then 'Inflow' else 'Base' end 
  end as inflow_base,
  a.sbscrptn_ek_id,
  date_sub(a.dt ,interval 90 day) as last_rgu_dt
  from `data-bi-prd-935c.bi_mart.fct_ioh_rgu_nik_movement` a
  left outer join `data-bi-prd-935c.bi_stg.tmp_new_tracker_churn_4` d on cast(a.sbscrptn_ek_id as string) = d.sbscrptn_ek_id
  left outer join `data-bi-prd-935c.bi_stg.tmp_new_tracker_churn_0` e on cast(a.sbscrptn_ek_id as string) = e.sbscrptn_ek_id
  where a.tag = 'rgu90_gross_churn'
  and a.dt = vdt_id
 ) a
 left outer join `data-bi-prd-935c.bi_stg.tmp_new_tracker_churn_1` b on cast(a.sbscrptn_ek_id as string) = b.sbscrptn_ek_id
 group by 1,2,3,4,5;

 


 --`data-bi-prd-935c.bi_stg.tmp_new_tracker_churn_6`
 
 drop table if exists `data-bi-prd-935c.bi_stg.tmp_new_tracker_churn_6`;

 


 create table `data-bi-prd-935c.bi_stg.tmp_new_tracker_churn_6` as
 select a.*, sum(coalesce(b.revenue,0)) as rev_m2
 from `data-bi-prd-935c.bi_stg.tmp_new_tracker_churn_5` a
 left outer join `data-bi-prd-935c.bi_stg.tmp_new_tracker_churn_2` b on a.sbscrptn_ek_id = b.sbscrptn_ek_id
 where a.dt = vdt_id
 group by 1,2,3,4,5,6;

 


 --`data-bi-prd-935c.bi_stg.tmp_new_tracker_churn_7`
 
 drop table if exists `data-bi-prd-935c.bi_stg.tmp_new_tracker_churn_7`;

 


 create table `data-bi-prd-935c.bi_stg.tmp_new_tracker_churn_7` as
 select a.*, sum(coalesce(b.revenue,0)) as rev_m3
 from `data-bi-prd-935c.bi_stg.tmp_new_tracker_churn_6` a
 left outer join `data-bi-prd-935c.bi_stg.tmp_new_tracker_churn_3` b on a.sbscrptn_ek_id = b.sbscrptn_ek_id
 where a.dt = vdt_id
 group by 1,2,3,4,5,6,7;

 


 --CRN0005 s/d CRN0007 + CRN0020 s/d CRN0022 + CRN0030 s/d CRN0032
 delete from `data-bi-prd-935c.bi_mart.kpi_national_tracker_dly` where brand = 'TRI' and dt_id = vdt_id and kpi_id in ('CRN0005', 'CRN0006', 'CRN0007',
 'CRN0020', 'CRN0021', 'CRN0022', 'CRN0030', 'CRN0031', 'CRN0032');

 

 insert into `data-bi-prd-935c.bi_mart.kpi_national_tracker_dly`
 select 'TRI' as brand, '' as kpi_code, 'DLY' as flag, 
 count(distinct a.sbscrptn_ek_id) as metric,
 current_timestamp() as process_dt, 
 case when rev_m1 + rev_m2 + rev_m3 = 0 then 'CRN0007'
     when ((rev_m1 + rev_m2 + rev_m3)/(cnt_m1 + cnt_m2 + cnt_m3)) <> 0 and ((rev_m1 + rev_m2 + rev_m3)/(cnt_m1 + cnt_m2 + cnt_m3)) <= 30000 then 'CRN0007'
     when ((rev_m1 + rev_m2 + rev_m3)/(cnt_m1 + cnt_m2 + cnt_m3)) > 30000 and ((rev_m1 + rev_m2 + rev_m3)/(cnt_m1 + cnt_m2 + cnt_m3)) <= 100000 then 'CRN0006'
     when ((rev_m1 + rev_m2 + rev_m3)/(cnt_m1 + cnt_m2 + cnt_m3)) > 100000 then 'CRN0005'
 else 'N/A' end as kpi_id,
 cast(vdt_id as date) as dt_id 
 from 
 (
  select *,
  case when rev_m1 <> 0 then 1 else 0 end as cnt_m1,
  case when rev_m2 <> 0 then 1 else 0 end as cnt_m2,
  case when rev_m3 <> 0 then 1 else 0 end as cnt_m3
  from `data-bi-prd-935c.bi_stg.tmp_new_tracker_churn_7`
  where tag = 'rgu90_gross_churn'
 ) a
 group by 1,2,3,5,6,7

 union all

 select 'TRI' as brand, '' as kpi_code, 'DLY' as flag, 
 sum(case when (rev_m1 + rev_m2 + rev_m3) = 0 then 0 else (rev_m1 + rev_m2 + rev_m3)/(cnt_m1 + cnt_m2 + cnt_m3) end) as metric,
 current_timestamp() as process_dt, 
 'CRN0020' as kpi_id,
 cast(vdt_id as date) as dt_id 
 from
 (
  select *,
  case when rev_m1 <> 0 then 1 else 0 end as cnt_m1,
  case when rev_m2 <> 0 then 1 else 0 end as cnt_m2,
  case when rev_m3 <> 0 then 1 else 0 end as cnt_m3
  from `data-bi-prd-935c.bi_stg.tmp_new_tracker_churn_7`
  where tag = 'rgu90_gross_churn'
 ) a
 group by 1,2,3,5,6,7

 union all

 select 'TRI' as brand, '' as kpi_code, 'DLY' as flag, 
 sum(case when (rev_m1 + rev_m2 + rev_m3) = 0 then 0 else (rev_m1 + rev_m2 + rev_m3)/(cnt_m1 + cnt_m2 + cnt_m3) end) as metric,
 current_timestamp() as process_dt, 
 case when inflow_base = 'Inflow' then 'CRN0021' else 'CRN0022' end as kpi_id,
 cast(vdt_id as date) as dt_id
 from
 (
  select *,
  case when rev_m1 <> 0 then 1 else 0 end as cnt_m1,
  case when rev_m2 <> 0 then 1 else 0 end as cnt_m2,
  case when rev_m3 <> 0 then 1 else 0 end as cnt_m3
  from `data-bi-prd-935c.bi_stg.tmp_new_tracker_churn_7`
  where tag = 'rgu90_gross_churn'
 ) a
 group by 1,2,3,5,6,7
 
 union all

 select 'TRI' as brand, '' as kpi_code, 'DLY' as flag, 
 sum(case when (rev_m1 + rev_m2 + rev_m3) = 0 then 0 else (rev_m1 + rev_m2 + rev_m3)/(cnt_m1 + cnt_m2 + cnt_m3) end) as metric,
 current_timestamp() as process_dt, 
 case when rev_m1 + rev_m2 + rev_m3 = 0 then 'CRN0032'
     when ((rev_m1 + rev_m2 + rev_m3)/(cnt_m1 + cnt_m2 + cnt_m3)) <> 0 and ((rev_m1 + rev_m2 + rev_m3)/(cnt_m1 + cnt_m2 + cnt_m3)) <= 30000 then 'CRN0032'
     when ((rev_m1 + rev_m2 + rev_m3)/(cnt_m1 + cnt_m2 + cnt_m3)) > 30000 and ((rev_m1 + rev_m2 + rev_m3)/(cnt_m1 + cnt_m2 + cnt_m3)) <= 100000 then 'CRN0031'
     when ((rev_m1 + rev_m2 + rev_m3)/(cnt_m1 + cnt_m2 + cnt_m3)) > 100000 then 'CRN0030'
 else 'N/A' end as kpi_id,
 cast(vdt_id as date) as dt_id 
 from 
 (
  select *,
  case when rev_m1 <> 0 then 1 else 0 end as cnt_m1,
  case when rev_m2 <> 0 then 1 else 0 end as cnt_m2,
  case when rev_m3 <> 0 then 1 else 0 end as cnt_m3
  from `data-bi-prd-935c.bi_stg.tmp_new_tracker_churn_7`
  where tag = 'rgu90_gross_churn'
 ) a
 group by 1,2,3,5,6,7
 ;


 --************--
 --RGU30-GC Rev 
 --************--
 
 --`data-bi-prd-935c.bi_stg.tmp_new_tracker_churn_1`
 
 drop table if exists `data-bi-prd-935c.bi_stg.tmp_new_tracker_churn_1`;

 


 create table `data-bi-prd-935c.bi_stg.tmp_new_tracker_churn_1` as
 select cast(sbscrptn_ek_id as string) as sbscrptn_ek_id, sum(revenue) as revenue
 from `data-bi-prd-935c.bi_mart.fct_cwn_rev_detail_fnl`
 where trx_dt_sk_id >= date_sub(vdt_id,interval 59 day)
 and trx_dt_sk_id <= date_sub(vdt_id,interval 30 day)
 group by 1;

 


 --`data-bi-prd-935c.bi_stg.tmp_new_tracker_churn_2`
 
 drop table if exists `data-bi-prd-935c.bi_stg.tmp_new_tracker_churn_2`;

 


 create table `data-bi-prd-935c.bi_stg.tmp_new_tracker_churn_2` as
 select cast(sbscrptn_ek_id as string) as sbscrptn_ek_id, sum(revenue) as revenue
 from `data-bi-prd-935c.bi_mart.fct_cwn_rev_detail_fnl`
 where trx_dt_sk_id >= date_sub(vdt_id,interval 89 day)
 and trx_dt_sk_id <= date_sub(vdt_id,interval 60 day)
 group by 1;

 


 --`data-bi-prd-935c.bi_stg.tmp_new_tracker_churn_3`
 
 drop table if exists `data-bi-prd-935c.bi_stg.tmp_new_tracker_churn_3`;

 


 create table `data-bi-prd-935c.bi_stg.tmp_new_tracker_churn_3` as
 select cast(sbscrptn_ek_id as string) as sbscrptn_ek_id, sum(revenue) as revenue
 from `data-bi-prd-935c.bi_mart.fct_cwn_rev_detail_fnl`
 where trx_dt_sk_id >= date_sub(vdt_id , interval 119 day)
 and trx_dt_sk_id <= date_sub(vdt_id , interval 90 day)
 group by 1;
 
 --`data-bi-prd-935c.bi_stg.tmp_new_tracker_churn_5`
 
 drop table if exists `data-bi-prd-935c.bi_stg.tmp_new_tracker_churn_5`;

 create table `data-bi-prd-935c.bi_stg.tmp_new_tracker_churn_5` as
 select a.dt, a.tag, a.inflow_base, cast(a.sbscrptn_ek_id as string) as sbscrptn_ek_id, a.last_rgu_dt, sum(coalesce(b.revenue,0)) as rev_m1
 from 
 ( 
  select distinct cast(vdt_id as date) as dt,
  a.tag, 
  case when d.ga_dt is not null then
   case when date_diff(date_sub(a.dt, interval 30 day) , d.ga_dt, day) between 0 and 89 then 'Inflow' else 'Base' end 
  else
   case when date_diff(date_sub(a.dt, interval 30 day) , e.fu_dt, day) between 0 and 89 then 'Inflow' else 'Base' end 
  end as inflow_base,
  a.sbscrptn_ek_id,
  date_sub(a.dt, interval 30 day) as last_rgu_dt
  from `data-bi-prd-935c.bi_mart.fct_ioh_rgu_nik_movement` a
  left outer join `data-bi-prd-935c.bi_stg.tmp_new_tracker_churn_4` d on cast(a.sbscrptn_ek_id as string)= d.sbscrptn_ek_id
  left outer join `data-bi-prd-935c.bi_stg.tmp_new_tracker_churn_0` e on cast(a.sbscrptn_ek_id as string)= e.sbscrptn_ek_id
  where a.tag = 'rgu30_gross_churn'
  and a.dt = vdt_id
 ) a
 left outer join `data-bi-prd-935c.bi_stg.tmp_new_tracker_churn_1` b on cast(a.sbscrptn_ek_id as string) = b.sbscrptn_ek_id
 group by 1,2,3,4,5;

 


 --`data-bi-prd-935c.bi_stg.tmp_new_tracker_churn_6`
 
 drop table if exists `data-bi-prd-935c.bi_stg.tmp_new_tracker_churn_6`;

 


 create table `data-bi-prd-935c.bi_stg.tmp_new_tracker_churn_6` as
 select a.*, sum(coalesce(b.revenue,0)) as rev_m2
 from `data-bi-prd-935c.bi_stg.tmp_new_tracker_churn_5` a
 left outer join `data-bi-prd-935c.bi_stg.tmp_new_tracker_churn_2` b on a.sbscrptn_ek_id = b.sbscrptn_ek_id
 where a.dt = vdt_id
 group by 1,2,3,4,5,6;

 


 --`data-bi-prd-935c.bi_stg.tmp_new_tracker_churn_7`
 
 drop table if exists `data-bi-prd-935c.bi_stg.tmp_new_tracker_churn_7`;

 


 create table `data-bi-prd-935c.bi_stg.tmp_new_tracker_churn_7` as
 select a.*, sum(coalesce(b.revenue,0)) as rev_m3
 from `data-bi-prd-935c.bi_stg.tmp_new_tracker_churn_6` a
 left outer join `data-bi-prd-935c.bi_stg.tmp_new_tracker_churn_3` b on a.sbscrptn_ek_id = b.sbscrptn_ek_id
 where a.dt = vdt_id
 group by 1,2,3,4,5,6,7;

 


 --CRN0045 s/d CRN0047 + CRN0060 s/d CRN0062 + CRN0070 s/d CRN0072
 delete from `data-bi-prd-935c.bi_mart.kpi_national_tracker_dly` where brand = 'TRI' and dt_id = vdt_id and kpi_id in ('CRN0045', 'CRN0046', 'CRN0047',
 'CRN0060', 'CRN0061', 'CRN0062', 'CRN0070', 'CRN0071', 'CRN0072');

 

 insert into `data-bi-prd-935c.bi_mart.kpi_national_tracker_dly`
 select 'TRI' as brand, '' as kpi_code, 'DLY' as flag, 
 count(distinct a.sbscrptn_ek_id) as metric,
 current_timestamp() as process_dt, 
 case when rev_m1 + rev_m2 + rev_m3 = 0 then 'CRN0047'
     when ((rev_m1 + rev_m2 + rev_m3)/(cnt_m1 + cnt_m2 + cnt_m3)) <> 0 and ((rev_m1 + rev_m2 + rev_m3)/(cnt_m1 + cnt_m2 + cnt_m3)) <= 30000 then 'CRN0047'
     when ((rev_m1 + rev_m2 + rev_m3)/(cnt_m1 + cnt_m2 + cnt_m3)) > 30000 and ((rev_m1 + rev_m2 + rev_m3)/(cnt_m1 + cnt_m2 + cnt_m3)) <= 100000 then 'CRN0046'
     when ((rev_m1 + rev_m2 + rev_m3)/(cnt_m1 + cnt_m2 + cnt_m3)) > 100000 then 'CRN0045'
 else 'N/A' end as kpi_id,
 cast(vdt_id as date) as dt_id 
 from 
 (
  select *,
  case when rev_m1 <> 0 then 1 else 0 end as cnt_m1,
  case when rev_m2 <> 0 then 1 else 0 end as cnt_m2,
  case when rev_m3 <> 0 then 1 else 0 end as cnt_m3
  from `data-bi-prd-935c.bi_stg.tmp_new_tracker_churn_7`
  where tag = 'rgu30_gross_churn'
 ) a
 group by 1,2,3,5,6,7

 union all

 select 'TRI' as brand, '' as kpi_code, 'DLY' as flag, 
 sum(case when (rev_m1 + rev_m2 + rev_m3) = 0 then 0 else (rev_m1 + rev_m2 + rev_m3)/(cnt_m1 + cnt_m2 + cnt_m3) end) as metric,
 current_timestamp() as process_dt, 
 'CRN0060' as kpi_id,
 cast(vdt_id as date) as dt_id 
 from
 (
  select *,
  case when rev_m1 <> 0 then 1 else 0 end as cnt_m1,
  case when rev_m2 <> 0 then 1 else 0 end as cnt_m2,
  case when rev_m3 <> 0 then 1 else 0 end as cnt_m3
  from `data-bi-prd-935c.bi_stg.tmp_new_tracker_churn_7`
  where tag = 'rgu30_gross_churn'
 ) a
 group by 1,2,3,5,6,7

 union all

 select 'TRI' as brand, '' as kpi_code, 'DLY' as flag, 
 sum(case when (rev_m1 + rev_m2 + rev_m3) = 0 then 0 else (rev_m1 + rev_m2 + rev_m3)/(cnt_m1 + cnt_m2 + cnt_m3) end) as metric,
 current_timestamp() as process_dt, 
 case when inflow_base = 'Inflow' then 'CRN0061' else 'CRN0062' end as kpi_id,
 cast(vdt_id as date) as dt_id
 from
 (
  select *,
  case when rev_m1 <> 0 then 1 else 0 end as cnt_m1,
  case when rev_m2 <> 0 then 1 else 0 end as cnt_m2,
  case when rev_m3 <> 0 then 1 else 0 end as cnt_m3
  from `data-bi-prd-935c.bi_stg.tmp_new_tracker_churn_7`
  where tag = 'rgu30_gross_churn'
 ) a
 group by 1,2,3,5,6,7
 
 union all

 select 'TRI' as brand, '' as kpi_code, 'DLY' as flag, 
 sum(case when (rev_m1 + rev_m2 + rev_m3) = 0 then 0 else (rev_m1 + rev_m2 + rev_m3)/(cnt_m1 + cnt_m2 + cnt_m3) end) as metric,
 current_timestamp() as process_dt, 
 case when rev_m1 + rev_m2 + rev_m3 = 0 then 'CRN0072'
     when ((rev_m1 + rev_m2 + rev_m3)/(cnt_m1 + cnt_m2 + cnt_m3)) <> 0 and ((rev_m1 + rev_m2 + rev_m3)/(cnt_m1 + cnt_m2 + cnt_m3)) <= 30000 then 'CRN0072'
     when ((rev_m1 + rev_m2 + rev_m3)/(cnt_m1 + cnt_m2 + cnt_m3)) > 30000 and ((rev_m1 + rev_m2 + rev_m3)/(cnt_m1 + cnt_m2 + cnt_m3)) <= 100000 then 'CRN0071'
     when ((rev_m1 + rev_m2 + rev_m3)/(cnt_m1 + cnt_m2 + cnt_m3)) > 100000 then 'CRN0070'
 else 'N/A' end as kpi_id,
 cast(vdt_id as date) as dt_id 
 from 
 (
  select *,
  case when rev_m1 <> 0 then 1 else 0 end as cnt_m1,
  case when rev_m2 <> 0 then 1 else 0 end as cnt_m2,
  case when rev_m3 <> 0 then 1 else 0 end as cnt_m3
  from `data-bi-prd-935c.bi_stg.tmp_new_tracker_churn_7`
  where tag = 'rgu30_gross_churn'
 ) a
 group by 1,2,3,5,6,7
 ;

 

 

 --************--
 --RGU90-CB Rev 
 --************--

 --`data-bi-prd-935c.bi_stg.tmp_new_tracker_churn_1`
 
 drop table if exists `data-bi-prd-935c.bi_stg.tmp_new_tracker_churn_1`;

 


 create table `data-bi-prd-935c.bi_stg.tmp_new_tracker_churn_1` as
 select sbscrptn_ek_id, sum(revenue) as revenue
 from `data-bi-prd-935c.bi_mart.fct_cwn_rev_detail_fnl`
 where trx_dt_sk_id = vdt_id
 group by 1;

--`data-bi-prd-935c.bi_stg.tmp_new_tracker_churn_5`
 
 drop table if exists `data-bi-prd-935c.bi_stg.tmp_new_tracker_churn_5`;

 create table `data-bi-prd-935c.bi_stg.tmp_new_tracker_churn_5` as
 select distinct cast(vdt_id as date) as dt,
 a.tag, 
 case when a.tag = 'rgu90_churn_back' then 'Base'
 else
  case when d.ga_dt is not null then
   case when date_diff(a.dt , d.ga_dt , day) between 0 and 89 then 'Inflow' else 'Base' end
  else
   case when date_diff(a.dt , e.fu_dt, day) between 0 and 89 then 'Inflow' else 'Base' end
  end 
 end as inflow_base,
 a.sbscrptn_ek_id,
 coalesce(f.revenue,0) as rev
 from `data-bi-prd-935c.bi_mart.fct_ioh_rgu_nik_movement` a
 left outer join `data-bi-prd-935c.bi_stg.tmp_new_tracker_churn_4` d on cast(a.sbscrptn_ek_id as string) = d.sbscrptn_ek_id
 left outer join `data-bi-prd-935c.bi_stg.tmp_new_tracker_churn_0` e on cast(a.sbscrptn_ek_id as string) = e.sbscrptn_ek_id
 left outer join `data-bi-prd-935c.bi_stg.tmp_new_tracker_churn_1` f on cast(a.sbscrptn_ek_id as string) = f.sbscrptn_ek_id
 where a.tag in ('rgu90_churn_back', 'rgu30_churn_back') 
 and a.dt = vdt_id
 ;

 


 --CRN0009 s/d CRN0011 + CRN0023 s/d CRN0025 + CRN0034 s/d CRN0036
 delete from `data-bi-prd-935c.bi_mart.kpi_national_tracker_dly` where brand = 'TRI' and dt_id = vdt_id and kpi_id in ('CRN0009', 'CRN0010', 'CRN0011',
 'CRN0023', 'CRN0024', 'CRN0025', 'CRN0034', 'CRN0035', 'CRN0036');

 

 insert into `data-bi-prd-935c.bi_mart.kpi_national_tracker_dly`
 select 'TRI' as brand, '' as kpi_code, 'DLY' as flag, 
 count(distinct a.sbscrptn_ek_id) as metric,
 current_timestamp() as process_dt, 
 case when rev <= 30000 then 'CRN0011'
     when rev > 30000 and rev <= 100000 then 'CRN0010'
     when rev > 100000 then 'CRN0009'
 else 'CRN0000' end as kpi_id,
 cast(vdt_id as date) as dt_id 
 from `data-bi-prd-935c.bi_stg.tmp_new_tracker_churn_5` a
 where tag = 'rgu90_churn_back'
 group by 1,2,3,5,6,7

 union all

 select 'TRI' as brand, '' as kpi_code, 'DLY' as flag, 
 sum(rev) as metric,
 current_timestamp() as process_dt, 
 'CRN0023' as kpi_id,
 cast(vdt_id as date) as dt_id 
 from `data-bi-prd-935c.bi_stg.tmp_new_tracker_churn_5` a
 where tag = 'rgu90_churn_back'
 group by 1,2,3,5,6,7

 union all

 select 'TRI' as brand, '' as kpi_code, 'DLY' as flag, 
 sum(rev) as metric,
 current_timestamp() as process_dt, 
 case when inflow_base = 'Inflow' then 'CRN0024' else 'CRN0025' end as kpi_id,
 cast(vdt_id as date) as dt_id 
 from `data-bi-prd-935c.bi_stg.tmp_new_tracker_churn_5` a
 where tag = 'rgu90_churn_back'
 group by 1,2,3,5,6,7

 union all

 select 'TRI' as brand, '' as kpi_code, 'DLY' as flag, 
 sum(rev) as metric,
 current_timestamp() as process_dt, 
 case when rev <= 30000 then 'CRN0036'
     when rev > 30000 and rev <= 100000 then 'CRN0035'
     when rev > 100000 then 'CRN0034'
 else 'CRN0000' end as kpi_id,
 cast(vdt_id as date) as dt_id 
 from `data-bi-prd-935c.bi_stg.tmp_new_tracker_churn_5` a
 where tag = 'rgu90_churn_back'
 group by 1,2,3,5,6,7
 ;

  


 --************--
 --RGU30-CB Rev 
 --************--

 --CRN0049 s/d CRN0051 + CRN0063 s/d CRN0065 + CRN0074 s/d CRN0076
 delete from `data-bi-prd-935c.bi_mart.kpi_national_tracker_dly` where brand = 'TRI' and dt_id = vdt_id and kpi_id in ('CRN0049', 'CRN0050', 'CRN0051',
 'CRN0063', 'CRN0064', 'CRN0065', 'CRN0074', 'CRN0075', 'CRN0076');

 

 insert into `data-bi-prd-935c.bi_mart.kpi_national_tracker_dly`
 select 'TRI' as brand, '' as kpi_code, 'DLY' as flag, 
 count(distinct a.sbscrptn_ek_id) as metric,
 current_timestamp() as process_dt, 
 case when rev <= 30000 then 'CRN0051'
     when rev > 30000 and rev <= 100000 then 'CRN0050'
     when rev > 100000 then 'CRN0049'
 else 'CRN0000' end as kpi_id,
 cast(vdt_id as date) as dt_id 
 from `data-bi-prd-935c.bi_stg.tmp_new_tracker_churn_5` a
 where tag = 'rgu30_churn_back'
 group by 1,2,3,5,6,7

 union all

 select 'TRI' as brand, '' as kpi_code, 'DLY' as flag, 
 sum(rev) as metric,
 current_timestamp() as process_dt, 
 'CRN0063' as kpi_id,
 cast(vdt_id as date) as dt_id 
 from `data-bi-prd-935c.bi_stg.tmp_new_tracker_churn_5` a
 where tag = 'rgu30_churn_back'
 group by 1,2,3,5,6,7

 union all

 select 'TRI' as brand, '' as kpi_code, 'DLY' as flag, 
 sum(rev) as metric,
 current_timestamp() as process_dt, 
 case when inflow_base = 'Inflow' then 'CRN0064' else 'CRN0065' end as kpi_id,
 cast(vdt_id as date) as dt_id 
 from `data-bi-prd-935c.bi_stg.tmp_new_tracker_churn_5` a
 where tag = 'rgu30_churn_back'
 group by 1,2,3,5,6,7

 union all

 select 'TRI' as brand, '' as kpi_code, 'DLY' as flag, 
 sum(rev) as metric,
 current_timestamp() as process_dt, 
 case when rev <= 30000 then 'CRN0076'
     when rev > 30000 and rev <= 100000 then 'CRN0075'
     when rev > 100000 then 'CRN0074'
 else 'CRN0000' end as kpi_id,
 cast(vdt_id as date) as dt_id 
 from `data-bi-prd-935c.bi_stg.tmp_new_tracker_churn_5` a
 where tag = 'rgu30_churn_back'
 group by 1,2,3,5,6,7
 ;

 


 --*********--
 --Net Churn
 --*********--

 --CRN0013, CRN0014, CRN0015, CRN0026, CRN0027, CRN0028, CRN0038, CRN0039, CRN0040

 delete from `data-bi-prd-935c.bi_mart.kpi_national_tracker_dly` where brand = 'TRI' and dt_id = vdt_id and kpi_id in 
 ('CRN0013', 'CRN0014', 'CRN0015', 
 'CRN0026', 'CRN0027', 'CRN0028',
 'CRN0038', 'CRN0039', 'CRN0040',
 'CRN0053', 'CRN0054', 'CRN0055',
 'CRN0066', 'CRN0067', 'CRN0068',
 'CRN0078', 'CRN0079', 'CRN0080');

 

 insert into `data-bi-prd-935c.bi_mart.kpi_national_tracker_dly`
 select 'TRI' as brand, '' as kpi_code, 'DLY' as flag, 
 a.metric - coalesce(b.metric,0) as metric,
 current_timestamp() as process_dt, 
 'CRN0013' as kpi_id,
 cast(vdt_id as date) as dt_id 
 from `data-bi-prd-935c.bi_mart.kpi_national_tracker_dly` a
 left outer join `data-bi-prd-935c.bi_mart.kpi_national_tracker_dly` b on a.dt_id = b.dt_id and b.kpi_id = 'CRN0009' and a.brand=b.brand
 where a.dt_id = vdt_id and a.kpi_id = 'CRN0005' and a.brand='TRI'
 
 union all

 select 'TRI' as brand, '' as kpi_code, 'DLY' as flag, 
 a.metric - coalesce(b.metric,0) as metric,
 current_timestamp() as process_dt, 
 'CRN0014' as kpi_id,
 cast(vdt_id as date) as dt_id 
 from `data-bi-prd-935c.bi_mart.kpi_national_tracker_dly` a
 left outer join `data-bi-prd-935c.bi_mart.kpi_national_tracker_dly` b on a.dt_id = b.dt_id and b.kpi_id = 'CRN0010' and a.brand = b.brand
 where a.dt_id = vdt_id and a.kpi_id = 'CRN0006' and a.brand='TRI'
  
 union all

 select 'TRI' as brand, '' as kpi_code, 'DLY' as flag, 
 a.metric - coalesce(b.metric,0) as metric,
 current_timestamp() as process_dt, 
 'CRN0015' as kpi_id,
 cast(vdt_id as date) as dt_id 
 from `data-bi-prd-935c.bi_mart.kpi_national_tracker_dly` a
 left outer join `data-bi-prd-935c.bi_mart.kpi_national_tracker_dly` b on a.dt_id = b.dt_id and b.kpi_id = 'CRN0011' and a.brand = b.brand
 where a.dt_id = vdt_id and a.kpi_id = 'CRN0007' and a.brand='TRI'
  
 union all

 select 'TRI' as brand, '' as kpi_code, 'DLY' as flag, 
 a.metric - coalesce(b.metric,0) as metric,
 current_timestamp() as process_dt, 
 'CRN0026' as kpi_id,
 cast(vdt_id as date) as dt_id 
 from `data-bi-prd-935c.bi_mart.kpi_national_tracker_dly` a
 left outer join `data-bi-prd-935c.bi_mart.kpi_national_tracker_dly` b on a.dt_id = b.dt_id and b.kpi_id = 'CRN0023' and a.brand = b.brand
 where a.dt_id = vdt_id and a.kpi_id = 'CRN0020' and a.brand='TRI'
 
 union all

 select 'TRI' as brand, '' as kpi_code, 'DLY' as flag, 
 a.metric - coalesce(b.metric,0) as metric,
 current_timestamp() as process_dt, 
 'CRN0027' as kpi_id,
 cast(vdt_id as date) as dt_id 
 from `data-bi-prd-935c.bi_mart.kpi_national_tracker_dly` a
 left outer join `data-bi-prd-935c.bi_mart.kpi_national_tracker_dly` b on a.dt_id = b.dt_id and b.kpi_id = 'CRN0024' and a.brand = b.brand
 where a.dt_id = vdt_id and a.kpi_id = 'CRN0021' and a.brand='TRI'
  
 union all

 select 'TRI' as brand, '' as kpi_code, 'DLY' as flag, 
 a.metric - coalesce(b.metric,0) as metric,
 current_timestamp() as process_dt, 
 'CRN0028' as kpi_id,
 cast(vdt_id as date) as dt_id 
 from `data-bi-prd-935c.bi_mart.kpi_national_tracker_dly` a
 left outer join `data-bi-prd-935c.bi_mart.kpi_national_tracker_dly` b on a.dt_id = b.dt_id and b.kpi_id = 'CRN0025' and a.brand=b.brand
 where a.dt_id = vdt_id and a.kpi_id = 'CRN0022' and a.brand='TRI'
  
 union all

 select 'TRI' as brand, '' as kpi_code, 'DLY' as flag, 
 a.metric - coalesce(b.metric,0) as metric,
 current_timestamp() as process_dt, 
 'CRN0038' as kpi_id,
 cast(vdt_id as date) as dt_id 
 from `data-bi-prd-935c.bi_mart.kpi_national_tracker_dly` a
 left outer join `data-bi-prd-935c.bi_mart.kpi_national_tracker_dly` b on a.dt_id = b.dt_id and b.kpi_id = 'CRN0034' and a.brand=b.brand
 where a.dt_id = vdt_id and a.kpi_id = 'CRN0030' and a.brand='TRI'
  
 union all

 select 'TRI' as brand, '' as kpi_code, 'DLY' as flag, 
 a.metric - coalesce(b.metric,0) as metric,
 current_timestamp() as process_dt, 
 'CRN0039' as kpi_id,
 cast(vdt_id as date) as dt_id 
 from `data-bi-prd-935c.bi_mart.kpi_national_tracker_dly` a
 left outer join `data-bi-prd-935c.bi_mart.kpi_national_tracker_dly` b on a.dt_id = b.dt_id and b.kpi_id = 'CRN0035' and a.brand=b.brand
 where a.dt_id = vdt_id and a.kpi_id = 'CRN0031' and a.brand='TRI'
  
 union all

 select 'TRI' as brand, '' as kpi_code, 'DLY' as flag, 
 a.metric - coalesce(b.metric,0) as metric,
 current_timestamp() as process_dt, 
 'CRN0040' as kpi_id,
 cast(vdt_id as date) as dt_id 
 from `data-bi-prd-935c.bi_mart.kpi_national_tracker_dly` a
 left outer join `data-bi-prd-935c.bi_mart.kpi_national_tracker_dly` b on a.dt_id = b.dt_id and b.kpi_id = 'CRN0036' and a.brand=b.brand
 where a.dt_id = vdt_id and a.kpi_id = 'CRN0032' and a.brand='TRI'

 union all

 select 'TRI' as brand, '' as kpi_code, 'DLY' as flag, 
 a.metric - coalesce(b.metric,0) as metric,
 current_timestamp() as process_dt, 
 'CRN0053' as kpi_id,
 cast(vdt_id as date) as dt_id 
 from `data-bi-prd-935c.bi_mart.kpi_national_tracker_dly` a
 left outer join `data-bi-prd-935c.bi_mart.kpi_national_tracker_dly` b on a.dt_id = b.dt_id and b.kpi_id = 'CRN0049' and a.brand=b.brand
 where a.dt_id = vdt_id and a.kpi_id = 'CRN0045' and a.brand='TRI'
  
 union all

 select 'TRI' as brand, '' as kpi_code, 'DLY' as flag, 
 a.metric - coalesce(b.metric,0) as metric,
 current_timestamp() as process_dt, 
 'CRN0054' as kpi_id,
 cast(vdt_id as date) as dt_id 
 from `data-bi-prd-935c.bi_mart.kpi_national_tracker_dly` a
 left outer join `data-bi-prd-935c.bi_mart.kpi_national_tracker_dly` b on a.dt_id = b.dt_id and b.kpi_id = 'CRN0050' and a.brand=b.brand
 where a.dt_id = vdt_id and a.kpi_id = 'CRN0046' and a.brand='TRI'
  
 union all

 select 'TRI' as brand, '' as kpi_code, 'DLY' as flag, 
 a.metric - coalesce(b.metric,0) as metric,
 current_timestamp() as process_dt, 
 'CRN0055' as kpi_id,
 cast(vdt_id as date) as dt_id 
 from `data-bi-prd-935c.bi_mart.kpi_national_tracker_dly` a
 left outer join `data-bi-prd-935c.bi_mart.kpi_national_tracker_dly` b on a.dt_id = b.dt_id and b.kpi_id = 'CRN0051' and a.brand=b.brand
 where a.dt_id = vdt_id and a.kpi_id = 'CRN0047' and a.brand='TRI'
 
 union all

 select 'TRI' as brand, '' as kpi_code, 'DLY' as flag, 
 a.metric - coalesce(b.metric,0) as metric,
 current_timestamp() as process_dt, 
 'CRN0066' as kpi_id,
 cast(vdt_id as date) as dt_id 
 from `data-bi-prd-935c.bi_mart.kpi_national_tracker_dly` a
 left outer join `data-bi-prd-935c.bi_mart.kpi_national_tracker_dly` b on a.dt_id = b.dt_id and b.kpi_id = 'CRN0063' and a.brand=b.brand
 where a.dt_id = vdt_id and a.kpi_id = 'CRN0060' and a.brand='TRI'
 
 union all

 select 'TRI' as brand, '' as kpi_code, 'DLY' as flag, 
 a.metric - coalesce(b.metric,0) as metric,
 current_timestamp() as process_dt, 
 'CRN0067' as kpi_id,
 cast(vdt_id as date) as dt_id 
 from `data-bi-prd-935c.bi_mart.kpi_national_tracker_dly` a
 left outer join `data-bi-prd-935c.bi_mart.kpi_national_tracker_dly` b on a.dt_id = b.dt_id and b.kpi_id = 'CRN0064' and a.brand=b.brand
 where a.dt_id = vdt_id and a.kpi_id = 'CRN0061' and a.brand='TRI'
  
 union all

 select 'TRI' as brand, '' as kpi_code, 'DLY' as flag, 
 a.metric - coalesce(b.metric,0) as metric,
 current_timestamp() as process_dt, 
 'CRN0068' as kpi_id,
 cast(vdt_id as date) as dt_id 
 from `data-bi-prd-935c.bi_mart.kpi_national_tracker_dly` a
 left outer join `data-bi-prd-935c.bi_mart.kpi_national_tracker_dly` b on a.dt_id = b.dt_id and b.kpi_id = 'CRN0065' and a.brand=b.brand
 where a.dt_id = vdt_id and a.kpi_id = 'CRN0062' and a.brand='TRI'
  
 union all

 select 'TRI' as brand, '' as kpi_code, 'DLY' as flag, 
 a.metric - coalesce(b.metric,0) as metric,
 current_timestamp() as process_dt, 
 'CRN0078' as kpi_id,
 cast(vdt_id as date) as dt_id 
 from `data-bi-prd-935c.bi_mart.kpi_national_tracker_dly` a
 left outer join `data-bi-prd-935c.bi_mart.kpi_national_tracker_dly` b on a.dt_id = b.dt_id and b.kpi_id = 'CRN0074' and a.brand=b.brand
 where a.dt_id = vdt_id and a.kpi_id = 'CRN0070' and a.brand='TRI'
  
 union all

 select 'TRI' as brand, '' as kpi_code, 'DLY' as flag, 
 a.metric - coalesce(b.metric,0) as metric,
 current_timestamp() as process_dt, 
 'CRN0079' as kpi_id,
 cast(vdt_id as date) as dt_id 
 from `data-bi-prd-935c.bi_mart.kpi_national_tracker_dly` a
 left outer join `data-bi-prd-935c.bi_mart.kpi_national_tracker_dly` b on a.dt_id = b.dt_id and b.kpi_id = 'CRN0075' and a.brand=b.brand
 where a.dt_id = vdt_id and a.kpi_id = 'CRN0071' and a.brand='TRI'
  
 union all

 select 'TRI' as brand, '' as kpi_code, 'DLY' as flag, 
 a.metric - coalesce(b.metric,0) as metric,
 current_timestamp() as process_dt, 
 'CRN0080' as kpi_id,
 cast(vdt_id as date) as dt_id 
 from `data-bi-prd-935c.bi_mart.kpi_national_tracker_dly` a
 left outer join `data-bi-prd-935c.bi_mart.kpi_national_tracker_dly` b on a.dt_id = b.dt_id and b.kpi_id = 'CRN0076' and a.brand=b.brand
 where a.dt_id = vdt_id and a.kpi_id = 'CRN0072' and a.brand='TRI'
 ;


 