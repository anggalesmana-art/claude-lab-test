DECLARE vdt_id DATE DEFAULT @vdt_id;

drop table if exists `data-bi-prd-935c.bi_stg`.ari_tmp_0522_VLR30days_daily;

create table `data-bi-prd-935c.bi_stg`.ari_tmp_0522_VLR30days_daily 
 AS 
 select *
 from
 ( 
 select
 row_number() over (partition by msisdn order by load_dt desc) as seqno, 
 msisdn, 
 imei
 from `data-bi-prd-935c.bi_mart.fct_vlr_daily`
 where cast(load_dt as date) >= DATE_SUB(vdt_id, INTERVAL 29 DAY)
 and load_dt <= vdt_id
 and (imei is not null and imei <> '' and imei not like '0%')
 )a
 where seqno = 1;  

drop table if exists `data-bi-prd-935c.bi_stg`.ari_tmp_0522_VLR30days_2_daily;  

create table `data-bi-prd-935c.bi_stg`.ari_tmp_0522_VLR30days_2_daily 
 AS 
 select *
 from
 ( 
 select
 row_number() over (partition by msisdn order by load_dt desc) as seqno, 
 msisdn, 
 imei
 from `data-bi-prd-935c.bi_mart.fct_vlr_daily`
 where cast(load_dt as date) >= DATE_SUB(vdt_id, INTERVAL 29 DAY) 
 and load_dt <= vdt_id
 ) a 
 where seqno = 1;
 
 delete from `data-bi-prd-935c.bi_mart.project_imeiVLR30days_daily`  where dt = vdt_id;

 --create table mis.`data-bi-prd-935c.bi_stg`.project_ImeiVLR30days_daily 
 --WITH (appendonly=true, compresstype=zlib, compresslevel=3, orientation=column) AS 
insert into `data-bi-prd-935c.bi_mart.project_imeiVLR30days_daily` 
-- create table `data-bi-prd-935c.bi_mart.project_imeiVLR30days_daily` as 
 select
 cast(vdt_id as date) as dt,
 case
 when coalesce(b.imei,a.imei) is null or coalesce(b.imei,a.imei) = '' then '01. blank' 
 when coalesce(b.imei,a.imei) like '0%' then '02. invalid' 
 else '03. valid'
 end as flag,
 a.imei as ori_imei, 
 coalesce(b.imei,a.imei) as latest_imei, 
 a.msisdn
 from `data-bi-prd-935c.bi_stg`.ari_tmp_0522_VLR30days_2_daily a 
 left outer join `data-bi-prd-935c.bi_stg`.ari_tmp_0522_VLR30days_daily b ON a.msisdn = b.msisdn;

drop table if exists `data-bi-prd-935c.bi_stg`.ari_tmp_0522_VLR30days_daily;  
 
drop table if exists `data-bi-prd-935c.bi_stg`.ari_tmp_0522_VLR30days_2_daily;