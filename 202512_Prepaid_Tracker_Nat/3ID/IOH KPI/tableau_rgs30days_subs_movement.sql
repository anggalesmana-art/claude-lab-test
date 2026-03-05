declare vdt_id date default @vdt_id;

delete from `data-bi-prd-935c.bi_mart.dm_project_rgs30days_movement`  where cast(dt as date)=vdt_id;
delete from `data-bi-prd-935c.bi_mart.tableau_rgs30days_subs_movement` where cast(dt as date)=vdt_id;

drop table if exists `data-bi-prd-935c.bi_stg.ari_Project_VLRDistinct30days_CMTD`;

create table `data-bi-prd-935c.bi_stg.ari_Project_VLRDistinct30days_CMTD` as
 SELECT a.msisdn, substr(a.imei,1,14) as imei,current_date() as date
 FROM
 ( 
 select distinct msisdn, imei from `data-bi-prd-935c.bi_mart.fct_vlr_daily`
 where 
 cast(load_dt as date) between DATE_SUB(DATE(vdt_id), INTERVAL 29 DAY) and vdt_id 
 and (imei not like '0%' and imei is not null and imei <> '') 
 )a;

drop table if exists `data-bi-prd-935c.bi_stg.ales_fct_vlr_daily_20190310_ioh`;
create table `data-bi-prd-935c.bi_stg.ales_fct_vlr_daily_20190310_ioh` as
select distinct msisdn, imei from `data-bi-prd-935c.bi_mart.dm_rgs30days_imei_eir_vlr`
 where FORMAT_DATE('%Y%m',load_dt_sk_id) between FORMAT_DATE('%Y%m',DATE_SUB(DATE(vdt_id), interval 6 month))
 and FORMAT_DATE('%Y%m',vdt_id)
 and (imei <> msisdn and imei not like '0%' and imei is not null and imei <> '');

insert into `data-bi-prd-935c.bi_mart.dm_project_rgs30days_movement`
with subs as (select * from `data-dtptechm-prd-c7ca.dwh.sbscrptn_attribs`)
 select
 cast(vdt_id as date) as dt, 
 cast(a.sbscrptn_ek_id as string), 
 c.sbscrptn_msisdn,
 c.activation_dtm, 
 case when b.sbscrptn_ek_id is not null then '01. Existing' else '02. New' end as flag1, 
 cast(null as string) as flag2,
 imei latest_imei,
 d.flag_imei as imeiFlag, 
cast(FORMAT_DATE('%Y%m%d',cast(vdt_id as date)) as int64) as scr_dt 
 FROM
 ( 
 select sbscrptn_ek_id from `data-dtptechm-prd-c7ca.dwh.rgs_subs_detail` 
 where 
cast(load_dt_sk_id as date) between DATE_SUB(DATE(vdt_id), INTERVAL 29 DAY) and vdt_id  
 and rgs_all_ex_sp 
 and tool_of_trade_ind = 'N'group by 1
 ) a 
 left outer join 
 ( 
 select sbscrptn_ek_id from `data-dtptechm-prd-c7ca.dwh.rgs_subs_detail` 
 where 
 cast(load_dt_sk_id as date)between
 DATE_TRUNC(DATE_SUB(DATE(vdt_id), INTERVAL 30 DAY),MONTH)
 and 
  DATE_TRUNC(DATE_SUB(DATE(vdt_id), INTERVAL 1 DAY),MONTH)
 and rgs_all_ex_sp 
 and tool_of_trade_ind = 'N'
 group by 1
 ) b ON a.sbscrptn_ek_id = b.sbscrptn_ek_id
 left outer join subs c ON cast(c.sbscrptn_ek_id as string) = cast(a.sbscrptn_ek_id as string) and rank_ind = 1 
 left outer join `data-bi-prd-935c.bi_mart.dm_rgs30days_imei_eir_vlr` d ON cast(c.sbscrptn_ek_id as string) = cast(d.sbscrptn_ek_id as string) AND cast(d.load_dt_sk_id as date) = vdt_id;


  INSERT INTO `data-bi-prd-935c.bi_mart.dm_project_rgs30days_movement`
  with subs as (select * from `data-dtptechm-prd-c7ca.dwh.sbscrptn_attribs`)
 select
 cast(vdt_id as date), 
 cast(a.sbscrptn_ek_id as string), 
 c.sbscrptn_msisdn,
 c.activation_dtm, 
 '03. Churn' as flag1, 
 cast(null as string) as flag2,
 imei latest_imei,
 d.flag_imei as imeiFlag, 
 cast(FORMAT_DATE('%Y%m%d',cast(vdt_id as date)) as int64) as scr_dt 
 FROM
 ( 
 select sbscrptn_ek_id from `data-dtptechm-prd-c7ca.dwh.rgs_subs_detail`
 where 
 cast(load_dt_sk_id as date)  between
  DATE_TRUNC(DATE_SUB(DATE(vdt_id), INTERVAL 30 DAY),MONTH) and 
  DATE_TRUNC(DATE_SUB(DATE(vdt_id), INTERVAL 1 DAY),MONTH)
 and rgs_all_ex_sp 
 and tool_of_trade_ind = 'N'group by 1
 ) a 
 left outer join 
 ( 
 select sbscrptn_ek_id from `data-dtptechm-prd-c7ca.dwh.rgs_subs_detail`
 where 
 cast(load_dt_sk_id as date)  between DATE_SUB(DATE(vdt_id), INTERVAL 29 DAY)  and vdt_id 
 and rgs_all_ex_sp 
 and tool_of_trade_ind = 'N' 
 ) b ON a.sbscrptn_ek_id = b.sbscrptn_ek_id
 left outer join subs c ON cast(c.sbscrptn_ek_id as string) = cast(a.sbscrptn_ek_id  as string)and rank_ind = 1 
 left outer join `data-bi-prd-935c.bi_mart.dm_rgs30days_imei_eir_vlr` d ON cast(c.sbscrptn_ek_id as string) = cast(d.sbscrptn_ek_id as string) AND cast(d.load_dt_sk_id as date) = DATE_TRUNC(DATE_SUB(DATE(vdt_id), INTERVAL 1 DAY),MONTH)
 where b.sbscrptn_ek_id is null;


UPDATE `data-bi-prd-935c.bi_mart.dm_project_rgs30days_movement` AS a
SET flag2 = 'Existing Imei'
WHERE a.flag1 = '02. New'
  AND a.dt = vdt_id
  AND a.imeiflag = '03. valid'
  AND a.latest_imei IN (
    SELECT DISTINCT latest_imei
    FROM `data-bi-prd-935c.bi_mart.dm_project_rgs30days_movement`
    WHERE flag1 IN ('01. Existing', '03. Churn')
      AND dt = vdt_id
      AND imeiflag = '03. valid'
  );

UPDATE `data-bi-prd-935c.bi_mart.dm_project_rgs30days_movement` AS a
SET a.flag2 = 'Idle Imei last 6 mth'
WHERE a.flag1 = '02. New'
  AND a.dt = vdt_id
  AND a.imeiflag = '03. valid'
  AND a.flag2 IS NULL
  AND a.latest_imei IN (
    SELECT DISTINCT a.imei
    FROM `data-bi-prd-935c.bi_stg.ales_fct_vlr_daily_20190310_ioh` AS a
    LEFT JOIN (
      SELECT DISTINCT CONCAT(sbscrptn_msisdn, latest_imei) AS sbscrptn_msisdn
      FROM `data-bi-prd-935c.bi_mart.dm_project_rgs30days_movement`
      WHERE flag1 <> '03. Churn'
        AND dt = vdt_id
    ) AS b
    ON CONCAT(a.msisdn, a.imei) = b.sbscrptn_msisdn
    WHERE b.sbscrptn_msisdn IS NULL
  );


UPDATE `data-bi-prd-935c.bi_mart.dm_project_rgs30days_movement`  AS a
SET a.flag2 = 'IMEI still RGS'
WHERE a.flag1 = '03. Churn'
  AND a.dt = vdt_id
  AND a.latest_imei IN (
    SELECT DISTINCT b.latest_imei
    FROM `data-bi-prd-935c.bi_mart.dm_project_rgs30days_movement`  AS b
    WHERE b.flag1 IN ('02. New', '01. Existing')
      AND b.dt = vdt_id
      AND b.imeiflag = '03. valid'
  );

UPDATE `data-bi-prd-935c.bi_mart.dm_project_rgs30days_movement` AS a
SET a.flag2 = 'Idle IMEI'
WHERE a.flag1 = '03. Churn'
  AND a.dt = vdt_id
  AND a.flag2 IS NULL
  AND a.latest_imei IN (
    SELECT DISTINCT a.imei
    FROM `data-bi-prd-935c.bi_stg.ari_Project_VLRDistinct30days_CMTD` AS a
    LEFT JOIN (
      SELECT latest_imei 
      FROM `data-bi-prd-935c.bi_mart.dm_project_rgs30days_movement`
      WHERE dt = vdt_id 
        AND flag1 IN ('01. Existing', '02. New') 
        AND imeiflag = '03. valid'
    ) AS b 
    ON a.imei = b.latest_imei
    WHERE b.latest_imei IS NULL
  );

insert into `data-bi-prd-935c.bi_mart.tableau_rgs30days_subs_movement` 
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
 `data-bi-prd-935c.bi_mart.dm_project_rgs30days_movement` a 
 LEFT OUTER JOIN `data-dtptechm-prd-c7ca.dwh.sbscrptn_dim_vlr_hist` b1 ON cast(b1.sbscrptn_ek_id as string) = cast(a.sbscrptn_ek_id as string) and b1.rank_ind = 1 and cast(b1.bkp_dt_sk_id as date) = vdt_id
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
  with subs as (select * from `data-dtptechm-prd-c7ca.dwh.sbscrptn_attribs`)
 select dt, rprt1.ctgry_ref_chld as home30,
 case when(
    SELECT MIN(d)
    FROM UNNEST([
      cast(first_usage_dt as date),
      safe.parse_date('%Y%m%d',cast(first_billing_usage_dt_sk_id as string))
    ]) AS d
    WHERE d IS NOT NULL
  )
 between DATE_SUB(vdt_id, INTERVAL 29 DAY) and vdt_id or 
 FORMAT_DATE('%Y%m',(
    SELECT MIN(d)
    FROM UNNEST([
      cast(first_usage_dt as date),
      safe.parse_date('%Y%m%d',cast(first_billing_usage_dt_sk_id as string))
    ]) AS d
    WHERE d IS NOT NULL
  )) = FORMAT_DATE('%Y%m', DATE(vdt_id))
 then 'Y' else 'N' end as flag_new_acq 
 ,case when flag2 is null then 'NEW Subs' else 'Rotational Subs' end as flag_rotation,count(*) as subs 
from 
 `data-bi-prd-935c.bi_mart.dm_project_rgs30days_movement` a 
 left join subs sa on cast(a.sbscrptn_ek_id as string)=cast(sa.sbscrptn_ek_id as string) 
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
with subs as (select * from `data-dtptechm-prd-c7ca.dwh.sbscrptn_attribs`)
 select dt,rprt1.ctgry_ref_chld as home30, 
'N'as flag_new_acq 
 ,'Stay' as flag_rotation,count(*) as subs 
from 
 `data-bi-prd-935c.bi_mart.dm_project_rgs30days_movement` a 
 LEFT OUTER JOIN subs b1 ON cast(b1.sbscrptn_ek_id as string) = cast(a.sbscrptn_ek_id as string) and b1.rank_ind = 1 
 left join `data-dtptechm-prd-c7ca.dwh.channel_dim` cd1 on cd1.channel_sk_id=b1.mp3_Channel_sk_id 
 left join `data-dtptechm-prd-c7ca.dwh.rprt_fltr_ref_ctgry` rprt1 on cd1.channel_id=rprt1.ref_cd and rprt1.ref_type_cd='MP3'
 where dt in ( vdt_id) 
 and flag1='01. Existing'
 group by 1,2,3,4
 ) x 