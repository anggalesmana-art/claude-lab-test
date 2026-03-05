declare vdt_id date default @vdt_id;


delete from `data-bi-prd-935c.bi_mart.dm_project_rgs30_movement` where dt = vdt_id;
delete from `data-bi-prd-935c.bi_mart.tableau_rgs30_subs_movement` where dt= vdt_id;


TRUNCATE TABLE `data-bi-prd-935c.bi_stg.Project_VLRDistinct30_CMTD`;

 INSERT INTO `data-bi-prd-935c.bi_stg.Project_VLRDistinct30_CMTD`
 SELECT a.msisdn, substr(a.imei,1,14) as imei,current_date()
 FROM
 ( 
 select distinct msisdn, imei from `data-bi-prd-935c.bi_mart.fct_vlr_daily` 
 where 
 load_dt between DATE_SUB(DATE(vdt_id), INTERVAL 30 DAY) and vdt_id 
 and (imei not like '0%' and imei is not null and imei <> '')
 ) a;


truncate table `data-bi-prd-935c.bi_stg.fct_vlr_daily_20190310_ioh`; 
 
insert into `data-bi-prd-935c.bi_stg.fct_vlr_daily_20190310_ioh`
select distinct msisdn, imei from `data-bi-prd-935c.bi_mart.dm_rgs30_imei_eir_vlr` 
where load_dt_sk_id between DATE_SUB(DATE(vdt_id), INTERVAL 6 month) 
and DATE_SUB(DATE(vdt_id), INTERVAL 1 month) 
 and (imei <> msisdn and imei not like '0%' and imei is not null and imei <> ''); 


insert into `data-bi-prd-935c.bi_mart.dm_project_rgs30_movement` 
 select
 cast(vdt_id as date), 
 a.sbscrptn_ek_id, 
 c.sbscrptn_msisdn,
 c.activation_dtm, 
 case when b.sbscrptn_ek_id is not null then '01. Existing' else '02. New' end as flag1, 
 cast(null as string) as flag2,
 imei latest_imei,
 d.flag_imei as imeiFlag, 
 CAST(FORMAT_DATE('%Y%m%d', a.load_dt_sk_id) AS INT64)  as scr_dt 
 FROM
 ( 
 select * from `data-dtptechm-prd-c7ca.dwh.rgs30_subs_detail` 
 where
 cast(load_dt_sk_id as date) =vdt_id and
 rgs30_all_ex_sp 
 and tool_of_trade_ind = 'N' 
 ) a 
 left outer join 
 ( 
 select * from `data-dtptechm-prd-c7ca.dwh.rgs30_subs_detail`
 where 
 cast(load_dt_sk_id as date)= DATE_SUB(DATE_TRUNC(DATE(vdt_id), Month), INTERVAL 1 day)
 and rgs30_all_ex_sp 
 and tool_of_trade_ind = 'N' 
 ) b ON a.sbscrptn_ek_id = b.sbscrptn_ek_id
 left outer join `data-dtptechm-prd-c7ca.dwh.sbscrptn_attribs` c ON c.sbscrptn_ek_id = a.sbscrptn_ek_id and rank_ind = 1
 left outer join `data-bi-prd-935c.bi_mart.dm_rgs30_imei_eir_vlr` d ON c.sbscrptn_ek_id = d.sbscrptn_ek_id AND 
 cast(d.load_dt_sk_id as date)= vdt_id;

INSERT INTO `data-bi-prd-935c.bi_mart.dm_project_rgs30_movement`
 select 
 cast(vdt_id as date), 
 a.sbscrptn_ek_id,
 c.sbscrptn_msisdn, 
 c.activation_dtm,
 '03. Churn' as flag1, 
 cast(null as string) as flag2,
 imei latest_imei,
 d.flag_imei as imeiFlag,
CAST(FORMAT_DATE('%Y%m%d', a.load_dt_sk_id) AS INT64)  as scr_dt 
 FROM
 ( 
select * from `data-dtptechm-prd-c7ca.dwh.rgs30_subs_detail` 
where 
cast(load_dt_sk_id as date) = DATE_SUB(DATE_TRUNC(DATE(vdt_id), Month), INTERVAL 1 day)
and rgs30_all_ex_sp
and tool_of_trade_ind = 'N'
 ) a 
 left outer join
 ( 
select * from `data-dtptechm-prd-c7ca.dwh.rgs30_subs_detail` 
where 
 cast(load_dt_sk_id as date) =vdt_id and
rgs30_all_ex_sp
and tool_of_trade_ind = 'N'
 ) b ON a.sbscrptn_ek_id = b.sbscrptn_ek_id
 left outer join `data-dtptechm-prd-c7ca.dwh.sbscrptn_attribs` c ON c.sbscrptn_ek_id = a.sbscrptn_ek_id and rank_ind = 1
 left outer join `data-bi-prd-935c.bi_mart.dm_rgs30_imei_eir_vlr` d ON c.sbscrptn_ek_id = d.sbscrptn_ek_id AND 
 cast(d.load_dt_sk_id as date) = DATE_TRUNC(DATE_SUB(DATE(vdt_id), INTERVAL 1 day), Month)
 where b.sbscrptn_ek_id is null;


 --03. UPDATE RULES 
 -- CURRENT MONTH 
 --01. NEW
 --01.1. Existing Imei adalah new Imei exist on churn subs on oas of 31 days

 
UPDATE `data-bi-prd-935c.bi_mart.dm_project_rgs30_movement` a
set flag2 = 'Existing Imei'
FROM (
--- apakah imei new ini ada di msisdn yg churn on as of last 31 days. Jika ada maka diflag menjadi "existing Imei"
SELECT distinct latest_imei from `data-bi-prd-935c.bi_mart.dm_project_rgs30_movement` WHERE flag1 in ('01. Existing','03. Churn')
 AND dt = vdt_id 
 AND imeiflag = '03. valid'
) b
WHERE 
a.latest_imei = b.latest_imei
AND a.flag1 = '02. New' 
AND a.dt = vdt_id
AND a.imeiflag = '03. valid'; 

 --01.2. Idle Imei Last 6 month adalah new Imei that not exist on churn subs on as of 31 days but available on VLR last 6 month
UPDATE `data-bi-prd-935c.bi_mart.dm_project_rgs30_movement` a--
set flag2 = 'Idle Imei last 6 mth'
FROM (
select distinct imei from `data-bi-prd-935c.bi_stg.fct_vlr_daily_20190310_ioh` a 
 left outer join (
 -- RGS30 on period
 select distinct sbscrptn_msisdn||latest_imei as sbscrptn_msisdn from `data-bi-prd-935c.bi_mart.dm_project_rgs30_movement` where flag1 <> ('03. Churn')
 AND dt = vdt_id 
 ) b ON a.msisdn||imei = b.sbscrptn_msisdn
 where b.sbscrptn_msisdn is null 
 --and load_mth between to_char(date_trunc('month', (vdt_id::text::date - interval'6 month')::date)::date,'YYYYMM')::integer
 --and to_char(date_trunc('month', (vdt_id::text::date - interval'0 month')::date)::date,'YYYYMM')::integer
) b
WHERE a.latest_imei = b.imei
AND a.flag1 = '02. New' 
AND a.dt = vdt_id
AND a.imeiflag = '03. valid' 
AND a.flag2 is null;

 --- 02. CHURN 
 --- 02.1. Imei Still RGS:

UPDATE `data-bi-prd-935c.bi_mart.dm_project_rgs30_movement` a
set flag2 = 'IMEI still RGS' 
FROM (
--- check apakah msisdn churn ini imeinya muncul lagi pada RGS bulan berikutnya, dalam hal ini RGS30 as of period Data
SELECT distinct latest_imei from `data-bi-prd-935c.bi_mart.dm_project_rgs30_movement` WHERE flag1 in ( '02. New','01. Existing') 
 AND dt = vdt_id 
 AND imeiflag = '03. valid'
) b
WHERE 
a.latest_imei = b.latest_imei
AND a.flag1 = '03. Churn' 
 AND a.dt = vdt_id
 ;
 
 
 --- 02.2. Idle Imei (imei not rgs but exist in VLR last 31 days):


UPDATE `data-bi-prd-935c.bi_mart.dm_project_rgs30_movement` a
set flag2 = 'Idle IMEI' 
FROM (
 select distinct a.imei from `data-bi-prd-935c.bi_stg.Project_VLRDistinct30_CMTD` a
 left outer join `data-bi-prd-935c.bi_mart.dm_project_rgs30_movement` b ON a.imei = b.latest_imei 
AND b.dt = vdt_id 
AND flag1 IN ('01. Existing','02. New') AND imeiflag = '03. valid'
 where b.sbscrptn_msisdn is null 
) b
WHERE 
a.latest_imei = b.imei 
AND a.flag1 = '03. Churn' 
AND a.dt = vdt_id
AND a.flag2 is null;

delete from `data-bi-prd-935c.bi_mart.tableau_rgs30_subs_movement` where dt= vdt_id;

 insert into `data-bi-prd-935c.bi_mart.tableau_rgs30_subs_movement`
 select dt ,'03. Churn' flag1 ,home30, flag_rotation flag2
,subs from 
 ( 
 select dt, rprt1.ctgry_ref_chld home30, 
 rprt1.category_2,
case
when flag2 = 'Idle IMEI' then 'Not RGS but VLR'
when flag2 = 'IMEI still RGS' then 'Churn Rotational Subs' else 'Not RGS' end as flag_rotation 
,count(*) as subs
 from 
 `data-bi-prd-935c.bi_mart.dm_project_rgs30_movement` a
 LEFT OUTER JOIN `data-dtptechm-prd-c7ca.dwh.sbscrptn_dim_vlr_hist` b1 ON b1.sbscrptn_ek_id = a.sbscrptn_ek_id 
 --and date_trunc(b1.bkp_dt_sk_id,month)='2023-11-01' -- and b1.rank_ind = 1-- ganti bulan 
and date_trunc(date(b1.bkp_dt_sk_id),month) = date_trunc(date_sub(date_sub(vdt_id, interval 25 month), interval 1 day),month)
left join `data-dtptechm-prd-c7ca.dwh.channel_dim` cd1 on cd1.channel_sk_id=b1.mp3_Channel_sk_id
left join `data-dtptechm-prd-c7ca.dwh.rprt_fltr_ref_ctgry` rprt1 on cd1.channel_id=rprt1.ref_cd and rprt1.ref_type_cd='MP3' 
 where dt in ( vdt_id)--,20190531,20190630,20190731)
 and flag1='03. Churn' 
 group by 1,2,3,4 
 ) x 
 union all
 select dt ,'01. New' flag1 ,home30,case when flag_new_acq='Y' and flag_rotation ='NEW Subs' then 'New New'
 when flag_new_acq='Y' and flag_rotation <>'NEW Subs' then 'New Rotational'
 else 'Intermitten'
 end as flag 
,subs from 
 ( 
 select dt, rprt1.ctgry_ref_chld as home30,
case when --least(cast(first_usage_dt as date),parse_date('%Y%m%d',cast(first_billing_usage_dt_sk_id as string))) 
(
    SELECT MIN(d)
    FROM UNNEST([
      cast(first_usage_dt as date),
      safe.parse_date('%Y%m%d',cast(first_billing_usage_dt_sk_id as string))
    ]) AS d
    WHERE d IS NOT NULL
  )
between DATE_SUB(DATE(vdt_id), INTERVAL 30 DAY) and vdt_id -- and ::text:date 
--to_char(vdt_id::text::date-30,'YYYYMMDD')::integer 
then 'Y' else 'N' end as flag_new_acq
,case when flag2 is null then 'NEW Subs' else 'Rotational Subs' end as flag_rotation,count(*) as subs 
 from 
 `data-bi-prd-935c.bi_mart.dm_project_rgs30_movement` a
 left join `data-dtptechm-prd-c7ca.dwh.sbscrptn_attribs` sa on a.sbscrptn_ek_id=sa.sbscrptn_ek_id 
left join `data-dtptechm-prd-c7ca.dwh.channel_dim` cd1 on cd1.channel_sk_id=sa.mp3_Channel_sk_id
left join `data-dtptechm-prd-c7ca.dwh.rprt_fltr_ref_ctgry` rprt1 on cd1.channel_id=rprt1.ref_cd and rprt1.ref_type_cd='MP3' 
 where dt in ( vdt_id)--,20190531,20190630,20190731)
 and flag1='02. New' 
 group by 1,2,3,4 
 ) x 
 union all
 select dt ,'01. Existing' flag1 ,home30, 'Stay'
 as flag
,subs from 
 ( 
 select dt,rprt1.ctgry_ref_chld as home30,
'N'as flag_new_acq 
,'Stay' as flag_rotation,count(*) as subs 
 from 
 `data-bi-prd-935c.bi_mart.dm_project_rgs30_movement` a
 LEFT OUTER JOIN `data-dtptechm-prd-c7ca.dwh.sbscrptn_attribs` b1 ON b1.sbscrptn_ek_id = a.sbscrptn_ek_id -- and b1.rank_ind = 1-- ganti bulan 
left join `data-dtptechm-prd-c7ca.dwh.channel_dim` cd1 on cd1.channel_sk_id=b1.mp3_Channel_sk_id
left join `data-dtptechm-prd-c7ca.dwh.rprt_fltr_ref_ctgry` rprt1 on cd1.channel_id=rprt1.ref_cd and rprt1.ref_type_cd='MP3' 
 where 
 dt in ( vdt_id)and 
 flag1='01. Existing' 
 group by 1,2,3,4 
 ) x ;


--=====================================

/*
select 
dt,flag1,flag2,count(1),count(distinct sbscrptn_ek_id), current_datetime()
from `data-bi-prd-935c.bi_mart.dm_project_rgs30_movement` 
where dt = vdt_id group by 1,2,3 order by 1,2,3;


select 
dt,flag1,flag2,sum(subs) 
from `data-bi-prd-935c.bi_mart.tableau_rgs30_subs_movement` where dt= vdt_id group by 1,2,3 order by 1,2,3;




 select cast(load_dt_sk_id as date),count(1),count(distinct sbscrptn_ek_id) 
 from`data-dtptechm-prd-c7ca.dwh.rgs30_subs_detail` 
 where cast(load_dt_sk_id as date) in ('2025-08-30',vdt_id) 
 and
  rgs30_all_ex_sp 
 and tool_of_trade_ind = 'N' 
 group by 1 order by 1
 */