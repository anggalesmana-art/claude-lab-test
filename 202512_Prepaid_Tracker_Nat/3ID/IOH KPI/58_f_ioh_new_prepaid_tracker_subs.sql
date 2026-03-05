DECLARE vdt_id DATE DEFAULT @vdt_id;

drop table if exists `data-bi-prd-935c.bi_stg.tmp_new_tracker_subs_0`;

CREATE TABLE `data-bi-prd-935c.bi_stg.tmp_new_tracker_subs_0` AS
SELECT DISTINCT 
  sbscrptn_ek_id,
  DATE(
    CAST(
 (
    SELECT MIN(d)
    FROM UNNEST([
      cast(first_usage_dt as date),
      safe.parse_date('%Y%m%d',cast(first_billing_usage_dt_sk_id as string)),
      cast(any_event_first_usage_date as date)
    ]) AS d
    WHERE d IS NOT NULL
  )
    AS STRING)
  ) AS fu_dt
FROM `data-dtptechm-prd-c7ca.dwh.sbscrptn_attribs`;


 --Create table for fu until last EOM
 drop table if exists `data-bi-prd-935c.bi_stg.tmp_new_tracker_subs_prev`;

Create table `data-bi-prd-935c.bi_stg.tmp_new_tracker_subs_prev` as
 select distinct dt as ga_dt, cast(sbscrptn_ek_id as string) as sbscrptn_ek_id
 from `data-bi-prd-935c.bi_mart.fct_ioh_mvmnt_1_detail_dec21`
 where tag = 'rgu90_gross_add' 
 and dt >= '2021-10-01' --tidak usah diubah
 and dt <= '2021-12-31' --tidak usah diubah
 
union distinct
 
 select distinct CAST(ga_date AS DATE) as ga_dt, cast(sbscrptn_ek_id as string) as sbscrptn_ek_id
 from `data-bi-prd-935c.bi_mart.project_ioh_fu_master_v2`
 where ga_date >= '2022-01-01' --tidak usah diubah
 and ga_date <= DATE_SUB(DATE_TRUNC(vdt_id, MONTH), INTERVAL 1 day) --DIUBAH sesuai tanggal data
;

 --*************************
 --Revenue for RGU90 & RGU30
 --*************************
 
 --`data-bi-prd-935c.bi_stg`.tmp_new_tracker_subs_rev_m1
 
 drop table if exists `data-bi-prd-935c.bi_stg.tmp_new_tracker_subs_rev_m1`;

 Create table `data-bi-prd-935c.bi_stg.tmp_new_tracker_subs_rev_m1` as
 select sbscrptn_ek_id, sum(revenue) as revenue
 from `data-bi-prd-935c.bi_mart.fct_cwn_rev_detail_fnl`
 where CAST(trx_dt_sk_id AS DATE) >= (DATE_SUB(vdt_id, INTERVAL 29 DAY))
 and CAST(trx_dt_sk_id AS DATE) <= (vdt_id)
 group by 1
;

 


 --`data-bi-prd-935c.bi_stg`.tmp_new_tracker_subs_rev_m2
 
 drop table if exists `data-bi-prd-935c.bi_stg`.tmp_new_tracker_subs_rev_m2;

 
select CURRENT_TIMESTAMP() as table_tmp_new_tracker_subs_rev_m2;

 Create table `data-bi-prd-935c.bi_stg`.tmp_new_tracker_subs_rev_m2 as
 select sbscrptn_ek_id, sum(revenue) as revenue
 from `data-bi-prd-935c.bi_mart`.fct_cwn_rev_detail_fnl
 where CAST(CAST(trx_dt_sk_id AS STRING) AS DATE) >= (DATE_SUB(vdt_id, INTERVAL 59 DAY))
 and CAST(CAST(trx_dt_sk_id AS STRING) AS DATE) <= (DATE_SUB(vdt_id, INTERVAL 30 DAY))
 group by 1
;

 


 --`data-bi-prd-935c.bi_stg`.tmp_new_tracker_subs_rev_m3
 
 drop table if exists `data-bi-prd-935c.bi_stg`.tmp_new_tracker_subs_rev_m3;

 
select CURRENT_TIMESTAMP() as table_tmp_new_tracker_subs_rev_m3;

 Create table `data-bi-prd-935c.bi_stg`.tmp_new_tracker_subs_rev_m3 as
 select sbscrptn_ek_id, sum(revenue) as revenue
 from `data-bi-prd-935c.bi_mart`.fct_cwn_rev_detail_fnl
 where CAST(CAST(trx_dt_sk_id AS STRING) AS DATE) >= (DATE_SUB(vdt_id, INTERVAL 89 DAY))
 and CAST(CAST(trx_dt_sk_id AS STRING) AS DATE) <= (DATE_SUB(vdt_id, INTERVAL 60 DAY))
 group by 1
;



 --*********
 --**RGU90**
 --*********
 
 --Create table
 drop table if exists `data-bi-prd-935c.bi_stg.tmp_new_tracker_subs`;
 Create table `data-bi-prd-935c.bi_stg.tmp_new_tracker_subs` as
 select 'TRI' as brand, '' as kpi_code, 'MTD' as flag, 
 count(distinct a.sbscrptn_ek_id) as metric,
CURRENT_TIMESTAMP() as process_dt, 
 case when d.ga_dt is not null then
case when DATE_DIFF(CAST(dt AS DATE), cast(d.ga_dt as date),DAY) between 0 and 89 then 'SUB0005' else 'SUB0006' end 
else
 case when DATE_DIFF(CAST(dt AS DATE), cast(e.fu_dt as date),DAY) between 0 and 89 then 'SUB0005' else 'SUB0006' end
 end as kpi_id,
 cast(vdt_id as date) as dt_id 
 from `data-bi-prd-935c.bi_mart.fct_rgu_ioh_nik_mstr` a
 left outer join `data-bi-prd-935c.bi_stg.tmp_new_tracker_subs_prev` d on cast(a.sbscrptn_ek_id as string) = cast(d.sbscrptn_ek_id as string)
 left outer join `data-bi-prd-935c.bi_stg.tmp_new_tracker_subs_0` e on cast(a.sbscrptn_ek_id as string) = cast(e.sbscrptn_ek_id as string)
 where a.tag in ('rgu90') 
 and a.dt = DATE_SUB(vdt_id, INTERVAL 1 DAY)
 group by 1,2,3,5,6,7;

 
 

 --SUB0005, SUB0006
 delete from `data-bi-prd-935c.bi_mart.kpi_national_tracker_dly` where brand = 'TRI' and dt_id = vdt_id and kpi_id in ('SUB0005', 'SUB0006');
																		 
 insert into `data-bi-prd-935c.bi_mart.kpi_national_tracker_dly`
 select * from `data-bi-prd-935c.bi_stg.tmp_new_tracker_subs`;

 


 --SUB0004
 delete from `data-bi-prd-935c.bi_mart.kpi_national_tracker_dly` where brand = 'TRI' and dt_id = vdt_id and kpi_id in ('SUB0004');															 
 insert into `data-bi-prd-935c.bi_mart.kpi_national_tracker_dly`
 select brand, kpi_code, flag, sum(metric) as metric, process_dt, 'SUB0004' as kpi_id, dt_id
 from `data-bi-prd-935c.bi_stg.tmp_new_tracker_subs`
 where dt_id = vdt_id and kpi_id in ('SUB0005', 'SUB0006')
 group by 1,2,3,5,6,7;

 
 --SUB0007
 delete from `data-bi-prd-935c.bi_mart.kpi_national_tracker_dly` where brand = 'TRI' and dt_id = vdt_id and kpi_id in ('SUB0007');
																		 
 insert into `data-bi-prd-935c.bi_mart.kpi_national_tracker_dly`
 select 'TRI' as brand, '' as kpi_code, 'DLY' as flag, count(distinct sbscrptn_ek_id) as metric,CURRENT_TIMESTAMP() as process_dt, 
 'SUB0007' as kpi_id, cast(vdt_id as date) as dt_id
 from `data-bi-prd-935c.bi_mart.project_ioh_fu_master_v2`
 where ga_date = vdt_id
 group by 1,2,3,5,6,7;

 



 --Create table for fu until MTD
 drop table if exists `data-bi-prd-935c.bi_stg.tmp_new_tracker_subs_curr`;

 Create table `data-bi-prd-935c.bi_stg.tmp_new_tracker_subs_curr` as
 select distinct dt as ga_dt, cast(sbscrptn_ek_id as string) sbscrptn_ek_id
 from `data-bi-prd-935c.bi_mart.fct_ioh_mvmnt_1_detail_dec21`
 where tag = 'rgu90_gross_add' 
 and dt >= '2021-10-01' --tidak usah diubah
 and dt <= '2021-12-31' --tidak usah diubah
 
 union distinct
 
 select distinct CAST(ga_date AS DATE) as ga_dt, cast(sbscrptn_ek_id as string) sbscrptn_ek_id
 from `data-bi-prd-935c.bi_mart.project_ioh_fu_master_v2`
 where ga_date >= '2022-01-01' --tidak usah diubah
 and ga_date <= vdt_id
;


 --Create table
 drop table if exists `data-bi-prd-935c.bi_stg.tmp_new_tracker_subs`;


 Create table `data-bi-prd-935c.bi_stg.tmp_new_tracker_subs` as
 select 'TRI' as brand, '' as kpi_code, 'DLY' as flag, 
 count(distinct a.sbscrptn_ek_id) as metric,
CURRENT_TIMESTAMP() as process_dt, 
 case when d.ga_dt is not null then
case when DATE_DIFF(DATE_SUB(CAST(dt AS DATE), INTERVAL 90 DAY) , cast(d.ga_dt as date),DAY) between 0 and 89 then 'SUB0009' else 'SUB0010' end 
 else
case when DATE_DIFF(DATE_SUB(CAST(dt AS DATE), INTERVAL 90 DAY) , cast(e.fu_dt as date),DAY) between 0 and 89 then 'SUB0009' else 'SUB0010' end 
 end as kpi_id,
 cast(vdt_id as date) as dt_id 
 from `data-bi-prd-935c.bi_mart.fct_ioh_rgu_nik_movement` a
 left outer join `data-bi-prd-935c.bi_stg.tmp_new_tracker_subs_curr` d on cast(a.sbscrptn_ek_id as string) = cast(d.sbscrptn_ek_id as string)
 left outer join `data-bi-prd-935c.bi_stg.tmp_new_tracker_subs_0` e on cast(a.sbscrptn_ek_id as string) = cast(e.sbscrptn_ek_id as string)
 where a.tag = 'rgu90_gross_churn' 
 and a.dt = vdt_id
 group by 1,2,3,5,6,7;

 
 

 --SUB0009, SUB0010
 delete from `data-bi-prd-935c.bi_mart.kpi_national_tracker_dly` where brand = 'TRI' and dt_id = vdt_id and kpi_id in ('SUB0009', 'SUB0010');
																 
 insert into `data-bi-prd-935c.bi_mart.kpi_national_tracker_dly`
 select * from `data-bi-prd-935c.bi_stg.tmp_new_tracker_subs`;

 


 --SUB0008
 delete from `data-bi-prd-935c.bi_mart.kpi_national_tracker_dly` where brand = 'TRI' and dt_id = vdt_id and kpi_id in ('SUB0008');
																 
 insert into `data-bi-prd-935c.bi_mart.kpi_national_tracker_dly`
 select brand, kpi_code, flag, sum(metric) as metric, process_dt, 'SUB0008' as kpi_id, dt_id
 from `data-bi-prd-935c.bi_stg.tmp_new_tracker_subs`
 where dt_id = vdt_id and kpi_id in ('SUB0009', 'SUB0010')
 group by 1,2,3,5,6,7;

 



 --Create table
 drop table if exists `data-bi-prd-935c.bi_stg.tmp_new_tracker_subs`;

 Create table `data-bi-prd-935c.bi_stg.tmp_new_tracker_subs` as
 select 'TRI' as brand, '' as kpi_code, 'DLY' as flag, 
 count(distinct a.sbscrptn_ek_id) as metric,
CURRENT_TIMESTAMP() as process_dt, 
 'SUB0013' as kpi_id,
 cast(vdt_id as date) as dt_id 
 from `data-bi-prd-935c.bi_mart.fct_ioh_rgu_nik_movement` a
 where a.tag = 'rgu90_churn_back' 
 and a.dt = vdt_id
 group by 1,2,3,5,6,7;

 
 

 --SUB0012, SUB0013
 delete from `data-bi-prd-935c.bi_mart.kpi_national_tracker_dly` where brand = 'TRI' and dt_id = vdt_id and kpi_id in ('SUB0012', 'SUB0013');
										 
 insert into `data-bi-prd-935c.bi_mart.kpi_national_tracker_dly`
 select * from `data-bi-prd-935c.bi_stg.tmp_new_tracker_subs`;

 


 --SUB0011
 delete from `data-bi-prd-935c.bi_mart.kpi_national_tracker_dly` where brand = 'TRI' and dt_id = vdt_id and kpi_id in ('SUB0011');
			 
 insert into `data-bi-prd-935c.bi_mart.kpi_national_tracker_dly`
 select brand, kpi_code, flag, sum(metric) as metric, process_dt, 'SUB0011' as kpi_id, dt_id
 from `data-bi-prd-935c.bi_stg.tmp_new_tracker_subs`
 where dt_id = vdt_id and kpi_id in ('SUB0012', 'SUB0013')
 group by 1,2,3,5,6,7;

 
 

 --SUB0014, SUB0015, SUB0016
 delete from `data-bi-prd-935c.bi_mart.kpi_national_tracker_dly` where brand = 'TRI' and dt_id = vdt_id and kpi_id in ('SUB0014', 'SUB0015', 'SUB0016');
													 
 insert into `data-bi-prd-935c.bi_mart.kpi_national_tracker_dly`
 select a.brand, a.kpi_code, a.flag, a.metric - coalesce(b.metric,0) as metric, a.process_dt, 'SUB0014' as kpi_id, a.dt_id
 from `data-bi-prd-935c.bi_mart.kpi_national_tracker_dly` a
 join `data-bi-prd-935c.bi_mart.kpi_national_tracker_dly` b on a.dt_id = b.dt_id and b.dt_id = vdt_id and b.kpi_id = 'SUB0011' and a.brand = b.brand
 where a.dt_id = vdt_id and a.kpi_id = 'SUB0008' and a.brand = 'TRI'

 union distinct

 select a.brand, a.kpi_code, a.flag, a.metric - coalesce(b.metric,0) as metric, a.process_dt, 'SUB0015' as kpi_id, a.dt_id
 from `data-bi-prd-935c.bi_mart.kpi_national_tracker_dly` a
 left outer join `data-bi-prd-935c.bi_mart.kpi_national_tracker_dly` b on a.dt_id = b.dt_id and b.dt_id = vdt_id and b.kpi_id = 'SUB0012' and a.brand = b.brand
 where a.dt_id = vdt_id and a.kpi_id = 'SUB0009' and a.brand = 'TRI'
 
 union distinct

 select a.brand, a.kpi_code, a.flag, a.metric - coalesce(b.metric,0) as metric, a.process_dt, 'SUB0016' as kpi_id, a.dt_id
 from `data-bi-prd-935c.bi_mart.kpi_national_tracker_dly` a
 join `data-bi-prd-935c.bi_mart.kpi_national_tracker_dly` b on a.dt_id = b.dt_id and b.dt_id = vdt_id and b.kpi_id = 'SUB0013' and a.brand = b.brand
 where a.dt_id = vdt_id and a.kpi_id = 'SUB0010' and a.brand = 'TRI'
 ;


 --Create table
 drop table if exists `data-bi-prd-935c.bi_stg.tmp_new_tracker_subs`;

 Create table `data-bi-prd-935c.bi_stg.tmp_new_tracker_subs` as
 select 'TRI' as brand, '' as kpi_code, 'MTD' as flag, 
 count(distinct a.sbscrptn_ek_id) as metric,
CURRENT_TIMESTAMP() as process_dt, 
 case when d.ga_dt is not null then
case when date_diff(CAST(dt AS DATE) , cast(d.ga_dt as date), DAY) between 0 and 89 then 'SUB0018' else 'SUB0019' end 
else
 case when date_diff(CAST(dt AS DATE) , cast(e.fu_dt as date), DAY) between 0 and 89 then 'SUB0018' else 'SUB0019' end
 end as kpi_id,
 cast(vdt_id as date) as dt_id 
 from `data-bi-prd-935c.bi_mart.fct_rgu_ioh_nik_mstr`	 a
 left outer join `data-bi-prd-935c.bi_stg.tmp_new_tracker_subs_curr` d on cast(a.sbscrptn_ek_id as string)= cast(d.sbscrptn_ek_id as string)
 left outer join `data-bi-prd-935c.bi_stg.tmp_new_tracker_subs_0` e on cast(a.sbscrptn_ek_id as string) = cast(e.sbscrptn_ek_id as string)
 where a.tag in ('rgu90') 
 and a.dt = vdt_id
 group by 1,2,3,5,6,7;

 
 

 --SUB0018, SUB0019
 delete from `data-bi-prd-935c.bi_mart.kpi_national_tracker_dly` where brand = 'TRI' and dt_id = vdt_id and kpi_id in ('SUB0018', 'SUB0019');
											 
 insert into `data-bi-prd-935c.bi_mart.kpi_national_tracker_dly`
 select * from `data-bi-prd-935c.bi_stg.tmp_new_tracker_subs`;

 


 --SUB0017
 delete from `data-bi-prd-935c.bi_mart.kpi_national_tracker_dly` where brand = 'TRI' and dt_id = vdt_id and kpi_id in ('SUB0017');

														 
 insert into `data-bi-prd-935c.bi_mart.kpi_national_tracker_dly`
 select brand, kpi_code, flag, sum(metric) as metric, process_dt, 'SUB0017' as kpi_id, dt_id
 from `data-bi-prd-935c.bi_stg.tmp_new_tracker_subs`
 where dt_id = vdt_id and kpi_id in ('SUB0018', 'SUB0019')
 group by 1,2,3,5,6,7;

 



 --SUB0020, SUB0021, SUB0022
 delete from `data-bi-prd-935c.bi_mart.kpi_national_tracker_dly` where brand = 'TRI' and dt_id = vdt_id and kpi_id in ('SUB0020', 'SUB0021', 'SUB0022');

															 
 insert into `data-bi-prd-935c.bi_mart.kpi_national_tracker_dly`
 select a.brand, a.kpi_code, a.flag, a.metric - coalesce(b.metric,0) as metric, a.process_dt, 'SUB0020' as kpi_id, a.dt_id
 from `data-bi-prd-935c.bi_mart.kpi_national_tracker_dly` a
 join `data-bi-prd-935c.bi_mart.kpi_national_tracker_dly` b on a.dt_id = b.dt_id and b.dt_id = vdt_id and b.kpi_id = 'SUB0004'and a.brand=b.brand
 where a.dt_id = vdt_id and a.kpi_id = 'SUB0017' and a.brand = 'TRI'

 union distinct

 select a.brand, a.kpi_code, a.flag, a.metric - coalesce(b.metric,0) as metric, a.process_dt, 'SUB0021' as kpi_id, a.dt_id
 from `data-bi-prd-935c.bi_mart.kpi_national_tracker_dly` a
 join `data-bi-prd-935c.bi_mart.kpi_national_tracker_dly` b on a.dt_id = b.dt_id and b.dt_id = vdt_id and b.kpi_id = 'SUB0005' and a.brand=b.brand
 where a.dt_id = vdt_id and a.kpi_id = 'SUB0018' and a.brand = 'TRI'
 
 union distinct

 select a.brand, a.kpi_code, a.flag, a.metric - coalesce(b.metric,0) as metric, a.process_dt, 'SUB0022' as kpi_id, a.dt_id
 from `data-bi-prd-935c.bi_mart.kpi_national_tracker_dly` a
 join `data-bi-prd-935c.bi_mart.kpi_national_tracker_dly` b on a.dt_id = b.dt_id and b.dt_id = vdt_id and b.kpi_id = 'SUB0006' and a.brand=b.brand
 where a.dt_id = vdt_id and a.kpi_id = 'SUB0019' and a.brand = 'TRI'
 ;

--Create temp table
 drop table if exists `data-bi-prd-935c.bi_stg.tmp_new_tracker_subs`;
 
 
 create table `data-bi-prd-935c.bi_stg.tmp_new_tracker_subs` as
  select distinct sbscrptn_ek_id
 from `data-bi-prd-935c.bi_mart.project_rguog_subs_detail`
 where load_dt_sk_id >= DATE_SUB(vdt_id, INTERVAL 89 DAY) and load_dt_sk_id <= vdt_id;

 

 
 --SUB0023
 
 delete from `data-bi-prd-935c.bi_mart.kpi_national_tracker_dly` where brand = 'TRI' and dt_id = vdt_id and kpi_id in ('SUB0023');

                                                                                                                                                  																		   
 insert into `data-bi-prd-935c.bi_mart.kpi_national_tracker_dly`
 select 'TRI' as brand, '' as kpi_code, 'MTD' as flag, count(distinct a.sbscrptn_ek_id) as metric, 
CURRENT_TIMESTAMP() as process_dt, 
 'SUB0023' as kpi_id,  cast(vdt_id as date) as dt_id 
 from  `data-bi-prd-935c.bi_mart.fct_rgu_ioh_NIK_mstr` a
 join `data-bi-prd-935c.bi_stg.tmp_new_tracker_subs` b on a.sbscrptn_ek_id = b.sbscrptn_ek_id
 where tag = 'rgu90' and a.dt = vdt_id
 group by 1,2,3,5,6,7;

 --Create temp table
 drop table if exists `data-bi-prd-935c.bi_stg.tmp_new_tracker_subs`;

 create table `data-bi-prd-935c.bi_stg.tmp_new_tracker_subs` as
 select distinct a.sbscrptn_ek_id, 
 coalesce(b.revenue,0) as rev_m1,
 coalesce(c.revenue,0) as rev_m2,
 coalesce(d.revenue,0) as rev_m3
 from `data-bi-prd-935c.bi_mart.fct_rgu_ioh_NIK_mstr` a
 left outer join `data-bi-prd-935c.bi_stg.tmp_new_tracker_subs_rev_m1` b on a.sbscrptn_ek_id = b.sbscrptn_ek_id
 left outer join `data-bi-prd-935c.bi_stg.tmp_new_tracker_subs_rev_m2` c on a.sbscrptn_ek_id = c.sbscrptn_ek_id
 left outer join `data-bi-prd-935c.bi_stg.tmp_new_tracker_subs_rev_m3` d on a.sbscrptn_ek_id = d.sbscrptn_ek_id
 where a.tag in ('rgu90') 
 and a.dt = vdt_id;

 
 

 --SUB0061, SUB0062, SUB0063
 delete from `data-bi-prd-935c.bi_mart.kpi_national_tracker_dly` where brand = 'TRI' and dt_id = vdt_id and kpi_id in ('SUB0061', 'SUB0062', 'SUB0063');
                                                           
 insert into `data-bi-prd-935c.bi_mart.kpi_national_tracker_dly`
 select 'TRI' as brand, '' as kpi_code, 'DLY' as flag, 
 count(distinct a.sbscrptn_ek_id) as metric,
 CURRENT_TIMESTAMP() as process_dt, 
 case when rev_m1 + rev_m2 + rev_m3 = 0 then 'SUB0063'
     when ((rev_m1 + rev_m2 + rev_m3)/(cnt_m1 + cnt_m2 + cnt_m3)) <> 0 and ((rev_m1 + rev_m2 + rev_m3)/(cnt_m1 + cnt_m2 + cnt_m3)) <= 30000 then 'SUB0063'
     when ((rev_m1 + rev_m2 + rev_m3)/(cnt_m1 + cnt_m2 + cnt_m3)) > 30000 and ((rev_m1 + rev_m2 + rev_m3)/(cnt_m1 + cnt_m2 + cnt_m3)) <= 100000 then 'SUB0062'
     when ((rev_m1 + rev_m2 + rev_m3)/(cnt_m1 + cnt_m2 + cnt_m3)) > 100000 then 'SUB0061'
 else 'N/A' end as kpi_id,
cast(vdt_id as date) as dt_id 
 from 
 (
  select *,
  case when rev_m1 <> 0 then 1 else 0 end as cnt_m1,
  case when rev_m2 <> 0 then 1 else 0 end as cnt_m2,
  case when rev_m3 <> 0 then 1 else 0 end as cnt_m3
  from `data-bi-prd-935c.bi_stg.tmp_new_tracker_subs`
 ) a
 group by 1,2,3,5,6,7;

 --*********
 --**RGU30**
 --*********
 
 --Create temp table
 drop table if exists `data-bi-prd-935c.bi_stg.tmp_new_tracker_subs`;

 
 create table `data-bi-prd-935c.bi_stg.tmp_new_tracker_subs` as
 select 'TRI' as brand, '' as kpi_code, 'MTD' as flag, 
 count(distinct a.sbscrptn_ek_id) as metric,
 CURRENT_TIMESTAMP() as process_dt, 
 case when d.ga_dt is not null then
  case when DATE_DIFF(CAST(a.dt AS DATE) , cast(d.ga_dt as date), DAY) between 0 and 89 then 'SUB0029' else 'SUB0030' end 
  else
   case when DATE_DIFF(CAST(a.dt AS DATE) , cast(e.fu_dt as date), DAY) between 0 and 89 then 'SUB0029' else 'SUB0030' end
 end as kpi_id,
 cast(vdt_id as date) as dt_id 
 from `data-bi-prd-935c.bi_mart.fct_rgu_ioh_NIK_mstr` a
 left outer join `data-bi-prd-935c.bi_stg.tmp_new_tracker_subs_prev` d on a.sbscrptn_ek_id = d.sbscrptn_ek_id
 left outer join `data-bi-prd-935c.bi_stg.tmp_new_tracker_subs_0` e on a.sbscrptn_ek_id = cast(e.sbscrptn_ek_id as string)
 where a.tag in ('rgu30') 
 and a.dt = DATE_SUB(vdt_id, INTERVAL 1 DAY)
 group by 1,2,3,5,6,7;

 
 

 --SUB0029, SUB0030
 delete from `data-bi-prd-935c.bi_mart.kpi_national_tracker_dly` where brand = 'TRI' and dt_id = vdt_id and kpi_id in ('SUB0029', 'SUB0030');
                                                                                                                                                  																		   
 insert into `data-bi-prd-935c.bi_mart.kpi_national_tracker_dly`
 select * from `data-bi-prd-935c.bi_stg.tmp_new_tracker_subs`;

 


 --SUB0028
 delete from `data-bi-prd-935c.bi_mart.kpi_national_tracker_dly` where brand = 'TRI' and dt_id = vdt_id and kpi_id in ('SUB0028');
                                                                                                                                                  																		   
 insert into `data-bi-prd-935c.bi_mart.kpi_national_tracker_dly`
 select brand, kpi_code, flag, sum(metric) as metric, process_dt, 'SUB0028' as kpi_id, dt_id
 from `data-bi-prd-935c.bi_stg.tmp_new_tracker_subs`
 where dt_id = vdt_id and kpi_id in ('SUB0029', 'SUB0030')
 group by 1,2,3,5,6,7;

 


 
 --Create temp table
 drop table if exists `data-bi-prd-935c.bi_stg.tmp_new_tracker_subs`;

 create table `data-bi-prd-935c.bi_stg.tmp_new_tracker_subs` as
 select 'TRI' as brand, '' as kpi_code, 'DLY' as flag, 
 count(distinct a.sbscrptn_ek_id) as metric,
 CURRENT_TIMESTAMP() as process_dt, 
 case when d.ga_dt is not null then
  case when DATE_DIFF(date_sub(CAST(a.dt AS DATE),interval 30 day) , cast(d.ga_dt as date), DAY) between 0 and 89 then 'SUB0033' else 'SUB0034' end 
 else
  case when DATE_DIFF(date_sub(CAST(a.dt AS DATE),interval 30 day) , cast(e.fu_dt as date), DAY) between 0 and 89 then 'SUB0033' else 'SUB0034' end 
 end as kpi_id,
 vdt_id as dt_id 
 from `data-bi-prd-935c.bi_mart.fct_ioh_rgu_NIK_movement` a
 left outer join `data-bi-prd-935c.bi_stg.tmp_new_tracker_subs_curr` d on a.sbscrptn_ek_id = d.sbscrptn_ek_id
 left outer join `data-bi-prd-935c.bi_stg.tmp_new_tracker_subs_0` e on a.sbscrptn_ek_id = cast(e.sbscrptn_ek_id as string)
 where a.tag = 'rgu30_gross_churn' 
 and a.dt = vdt_id
 group by 1,2,3,5,6,7;

 
 

 --SUB0033, SUB0034
  delete from `data-bi-prd-935c.bi_mart.kpi_national_tracker_dly` where brand = 'TRI' and dt_id = vdt_id and kpi_id in ('SUB0033', 'SUB0034');
                                                                                                                                                  																		   
 insert into `data-bi-prd-935c.bi_mart.kpi_national_tracker_dly`
 select * from `data-bi-prd-935c.bi_stg.tmp_new_tracker_subs`;

 


 --SUB0032
 delete from `data-bi-prd-935c.bi_mart.kpi_national_tracker_dly` where brand = 'TRI' and dt_id = vdt_id and kpi_id in ('SUB0032');
                                                                                                                                                  																		   
 insert into `data-bi-prd-935c.bi_mart.kpi_national_tracker_dly`
 select brand, kpi_code, flag, sum(metric) as metric, process_dt, 'SUB0032' as kpi_id, dt_id
 from `data-bi-prd-935c.bi_stg.tmp_new_tracker_subs`
 where dt_id = vdt_id and kpi_id in ('SUB0033', 'SUB0034')
 group by 1,2,3,5,6,7;

--Create table
 drop table if exists `data-bi-prd-935c.bi_stg.tmp_new_tracker_subs`;

 Create table `data-bi-prd-935c.bi_stg.tmp_new_tracker_subs` as
 select 'TRI' as brand, '' as kpi_code, 'DLY' as flag, 
 count(distinct a.sbscrptn_ek_id) as metric,
CURRENT_TIMESTAMP() as process_dt, 
 case when d.ga_dt is not null then
case when DATE_DIFF(CAST(dt AS DATE) , cast(d.ga_dt as date), DAY) between 0 and 89 then 'SUB0036' else 'SUB0037' end 
 else
case when DATE_DIFF(CAST(dt AS DATE) , cast(e.fu_dt as date), DAY) between 0 and 89 then 'SUB0036' else 'SUB0037' end 
 end as kpi_id,
  cast(vdt_id as date) as dt_id 
 from `data-bi-prd-935c.bi_mart.fct_ioh_rgu_nik_movement` a
 left outer join `data-bi-prd-935c.bi_stg.tmp_new_tracker_subs_curr` d on cast(a.sbscrptn_ek_id as string) = cast(d.sbscrptn_ek_id as string)
 left outer join `data-bi-prd-935c.bi_stg.tmp_new_tracker_subs_0` e on cast(a.sbscrptn_ek_id as string) = cast(e.sbscrptn_ek_id as string)
 where a.tag = 'rgu30_churn_back'
 and a.dt = vdt_id
 group by 1,2,3,5,6,7;

 
 

 --SUB0036, SUB0037
 delete from `data-bi-prd-935c.bi_mart.kpi_national_tracker_dly` where brand = 'TRI' and dt_id = vdt_id and kpi_id in ('SUB0036', 'SUB0037');
																 
 insert into `data-bi-prd-935c.bi_mart.kpi_national_tracker_dly`
 select * from `data-bi-prd-935c.bi_stg.tmp_new_tracker_subs`;

 


 --SUB0035
 delete from `data-bi-prd-935c.bi_mart.kpi_national_tracker_dly` where brand = 'TRI' and dt_id = vdt_id and kpi_id in ('SUB0035');
																	 
 insert into `data-bi-prd-935c.bi_mart.kpi_national_tracker_dly`
 select brand, kpi_code, flag, sum(metric) as metric, process_dt, 'SUB0035' as kpi_id, dt_id
 from `data-bi-prd-935c.bi_stg.tmp_new_tracker_subs`
 where dt_id = vdt_id and kpi_id in ('SUB0036', 'SUB0037')
 group by 1,2,3,5,6,7;

 


 --SUB0038, SUB0039, SUB0040
 delete from `data-bi-prd-935c.bi_mart.kpi_national_tracker_dly` where brand = 'TRI' and dt_id = vdt_id and kpi_id in ('SUB0038', 'SUB0039', 'SUB0040');
															 
 insert into `data-bi-prd-935c.bi_mart.kpi_national_tracker_dly`
 select a.brand, a.kpi_code, a.flag, a.metric - coalesce(b.metric,0) as metric, a.process_dt, 'SUB0038' as kpi_id, a.dt_id
 from `data-bi-prd-935c.bi_mart.kpi_national_tracker_dly` a
 join `data-bi-prd-935c.bi_mart.kpi_national_tracker_dly` b on a.dt_id = b.dt_id and b.dt_id = vdt_id and b.kpi_id = 'SUB0035' and a.brand=b.brand
 where a.dt_id = vdt_id and a.kpi_id = 'SUB0032' and a.brand = 'TRI'

 union distinct

 select a.brand, a.kpi_code, a.flag, a.metric - coalesce(b.metric,0) as metric, a.process_dt, 'SUB0039' as kpi_id, a.dt_id
 from `data-bi-prd-935c.bi_mart.kpi_national_tracker_dly` a
 join `data-bi-prd-935c.bi_mart.kpi_national_tracker_dly` b on a.dt_id = b.dt_id and b.dt_id = vdt_id and b.kpi_id = 'SUB0036' and a.brand=b.brand
 where a.dt_id = vdt_id and a.kpi_id = 'SUB0033' and a.brand = 'TRI'
 
 union distinct

 select a.brand, a.kpi_code, a.flag, a.metric - coalesce(b.metric,0) as metric, a.process_dt, 'SUB0040' as kpi_id, a.dt_id
 from `data-bi-prd-935c.bi_mart.kpi_national_tracker_dly` a
 join `data-bi-prd-935c.bi_mart.kpi_national_tracker_dly` b on a.dt_id = b.dt_id and b.dt_id = vdt_id and b.kpi_id = 'SUB0037' and a.brand=b.brand
 where a.dt_id = vdt_id and a.kpi_id = 'SUB0034' and a.brand = 'TRI'
 ;
 

 --Create table
 drop table if exists `data-bi-prd-935c.bi_stg.tmp_new_tracker_subs`;

 Create table `data-bi-prd-935c.bi_stg.tmp_new_tracker_subs` as
 select 'TRI' as brand, '' as kpi_code, 'MTD' as flag, 
 count(distinct a.sbscrptn_ek_id) as metric,
CURRENT_TIMESTAMP() as process_dt, 
 case when d.ga_dt is not null then
case when DATE_DIFF(CAST(dt AS DATE) , cast(d.ga_dt as date), DAY) between 0 and 89 then 'SUB0042' else 'SUB0043' end 
else
 case when DATE_DIFF(CAST(dt AS DATE) , cast(e.fu_dt as date), DAY) between 0 and 89 then 'SUB0042' else 'SUB0043' end
 end as kpi_id,
  cast(vdt_id as date) as dt_id 
 from `data-bi-prd-935c.bi_mart.fct_rgu_ioh_nik_mstr` a
 left outer join `data-bi-prd-935c.bi_stg.tmp_new_tracker_subs_curr` d on cast(a.sbscrptn_ek_id as string) = cast(d.sbscrptn_ek_id as string)
 left outer join `data-bi-prd-935c.bi_stg.tmp_new_tracker_subs_0` e on cast(a.sbscrptn_ek_id as string)= cast(e.sbscrptn_ek_id as string)
 where a.tag in ('rgu30') 
 and a.dt = vdt_id
 group by 1,2,3,5,6,7;

 
 

 --SUB0042, SUB0043
 delete from `data-bi-prd-935c.bi_mart.kpi_national_tracker_dly` where brand = 'TRI' and dt_id = vdt_id and kpi_id in ('SUB0042', 'SUB0043');
																 
 insert into `data-bi-prd-935c.bi_mart.kpi_national_tracker_dly`
 select * from `data-bi-prd-935c.bi_stg.tmp_new_tracker_subs`;

 


 --SUB0041
 delete from `data-bi-prd-935c.bi_mart.kpi_national_tracker_dly` where brand = 'TRI' and dt_id = vdt_id and kpi_id in ('SUB0041');
																	 
 insert into `data-bi-prd-935c.bi_mart.kpi_national_tracker_dly`
 select brand, kpi_code, flag, sum(metric) as metric, process_dt, 'SUB0041' as kpi_id, dt_id
 from `data-bi-prd-935c.bi_stg.tmp_new_tracker_subs`
 where dt_id = vdt_id and kpi_id in ('SUB0042', 'SUB0043')
 group by 1,2,3,5,6,7;

 



 --SUB0044, SUB0045, SUB0046
 delete from `data-bi-prd-935c.bi_mart.kpi_national_tracker_dly` where brand = 'TRI' and dt_id = vdt_id and kpi_id in ('SUB0044', 'SUB0045', 'SUB0046');

																	 
 insert into `data-bi-prd-935c.bi_mart.kpi_national_tracker_dly`
 select a.brand, a.kpi_code, a.flag, a.metric - coalesce(b.metric,0) as metric, a.process_dt, 'SUB0044' as kpi_id, a.dt_id
 from `data-bi-prd-935c.bi_mart.kpi_national_tracker_dly` a
 join `data-bi-prd-935c.bi_mart.kpi_national_tracker_dly` b on a.dt_id = b.dt_id and b.dt_id = vdt_id and b.kpi_id = 'SUB0028' and a.brand=b.brand
 where a.dt_id = vdt_id and a.kpi_id = 'SUB0041' and a.brand = 'TRI'

 union distinct

 select a.brand, a.kpi_code, a.flag, a.metric - coalesce(b.metric,0) as metric, a.process_dt, 'SUB0045' as kpi_id, a.dt_id
 from `data-bi-prd-935c.bi_mart.kpi_national_tracker_dly` a
 join `data-bi-prd-935c.bi_mart.kpi_national_tracker_dly` b on a.dt_id = b.dt_id and b.dt_id = vdt_id and b.kpi_id = 'SUB0029' and a.brand=b.brand
 where a.dt_id = vdt_id and a.kpi_id = 'SUB0042' and a.brand = 'TRI'
 
 union distinct

 select a.brand, a.kpi_code, a.flag, a.metric - coalesce(b.metric,0) as metric, a.process_dt, 'SUB0046' as kpi_id, a.dt_id
 from `data-bi-prd-935c.bi_mart.kpi_national_tracker_dly` a
 join `data-bi-prd-935c.bi_mart.kpi_national_tracker_dly` b on a.dt_id = b.dt_id and b.dt_id = vdt_id and b.kpi_id = 'SUB0030' and a.brand=b.brand
 where a.dt_id = vdt_id and a.kpi_id = 'SUB0043'  and a.brand = 'TRI'
 ;

 
 

 --Create table
 drop table if exists `data-bi-prd-935c.bi_stg.tmp_new_tracker_subs`;

 Create table `data-bi-prd-935c.bi_stg.tmp_new_tracker_subs` as
 select distinct sbscrptn_ek_id
 from `data-bi-prd-935c.bi_mart.project_rguog_subs_detail`
 where cast(load_dt_sk_id as date) >= DATE_SUB(vdt_id, INTERVAL 29 DAY) and load_dt_sk_id <= vdt_id
;

 

 
 --SUB0047
 
 delete from `data-bi-prd-935c.bi_mart.kpi_national_tracker_dly` where brand = 'TRI' and dt_id = vdt_id and kpi_id in ('SUB0047');
																 
 insert into `data-bi-prd-935c.bi_mart.kpi_national_tracker_dly`
 select 'TRI' as brand, '' as kpi_code, 'MTD' as flag, count(distinct a.sbscrptn_ek_id) as metric,CURRENT_TIMESTAMP() as process_dt, 
 'SUB0047' as kpi_id,  cast(vdt_id as date) as dt_id 
 from `data-bi-prd-935c.bi_mart.fct_rgu_ioh_nik_mstr` a
 join `data-bi-prd-935c.bi_stg.tmp_new_tracker_subs` b on a.sbscrptn_ek_id = b.sbscrptn_ek_id
 where tag = 'rgu30' and a.dt = vdt_id
 group by 1,2,3,5,6,7;

 
 
 
 
 --Create table
 drop table if exists `data-bi-prd-935c.bi_stg.tmp_new_tracker_subs`;

 Create table `data-bi-prd-935c.bi_stg.tmp_new_tracker_subs` as
 select distinct a.sbscrptn_ek_id, 
 coalesce(b.revenue,0) as rev_m1,
 coalesce(c.revenue,0) as rev_m2,
 coalesce(d.revenue,0) as rev_m3
 from `data-bi-prd-935c.bi_mart.fct_rgu_ioh_nik_mstr` a
 left outer join `data-bi-prd-935c.bi_stg.tmp_new_tracker_subs_rev_m1` b on cast(a.sbscrptn_ek_id as string) = cast(b.sbscrptn_ek_id as string)
 left outer join `data-bi-prd-935c.bi_stg.tmp_new_tracker_subs_rev_m2` c on cast(a.sbscrptn_ek_id as string) = cast(c.sbscrptn_ek_id as string)
 left outer join `data-bi-prd-935c.bi_stg.tmp_new_tracker_subs_rev_m3` d on cast(a.sbscrptn_ek_id as string)= cast(d.sbscrptn_ek_id as string)
 where a.tag in ('rgu30') 
 and a.dt = vdt_id;

 
 

 --SUB0071, SUB0072, SUB0073
 delete from `data-bi-prd-935c.bi_mart.kpi_national_tracker_dly` where brand = 'TRI' and dt_id = vdt_id and kpi_id in ('SUB0071', 'SUB0072', 'SUB0073');

 insert into `data-bi-prd-935c.bi_mart.kpi_national_tracker_dly`
 select 'TRI' as brand, '' as kpi_code, 'DLY' as flag, 
 count(distinct a.sbscrptn_ek_id) as metric,
CURRENT_TIMESTAMP() as process_dt, 
 case when rev_m1 + rev_m2 + rev_m3 = 0 then 'SUB0073'
 when ((rev_m1 + rev_m2 + rev_m3)/(cnt_m1 + cnt_m2 + cnt_m3)) <> 0 and ((rev_m1 + rev_m2 + rev_m3)/(cnt_m1 + cnt_m2 + cnt_m3)) <= 30000 then 'SUB0073'
 when ((rev_m1 + rev_m2 + rev_m3)/(cnt_m1 + cnt_m2 + cnt_m3)) > 30000 and ((rev_m1 + rev_m2 + rev_m3)/(cnt_m1 + cnt_m2 + cnt_m3)) <= 100000 then 'SUB0072'
 when ((rev_m1 + rev_m2 + rev_m3)/(cnt_m1 + cnt_m2 + cnt_m3)) > 100000 then 'SUB0071'
 else 'N/A' end as kpi_id,
  cast(vdt_id as date) as dt_id
 from 
 (
select *,
case when rev_m1 <> 0 then 1 else 0 end as cnt_m1,
case when rev_m2 <> 0 then 1 else 0 end as cnt_m2,
case when rev_m3 <> 0 then 1 else 0 end as cnt_m3
from `data-bi-prd-935c.bi_stg.tmp_new_tracker_subs`
 ) a
 group by 1,2,3,5,6,7;