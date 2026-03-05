DECLARE vdt_id DATE DEFAULT @vdt_id;


drop table if exists `data-bi-prd-935c.bi_stg`.ari_tmp_0522_vlr30days_daily_ggsn; 

 create table `data-bi-prd-935c.bi_stg`.ari_tmp_0522_vlr30days_daily_ggsn 
 AS 
 select *
 from
 ( 
 select
 row_number() over (partition by sbscrptn_msisdn order by dt desc) as seqno, 
 sbscrptn_msisdn, 
 imei
 from `data-dtptechm-prd-c7ca.dwh.fct_ggsn_imei`
 where cast(dt as date) >= DATE_SUB(vdt_id, INTERVAL 29 DAY)
 and dt <= vdt_id
 and (imei is not null and imei <> '' and imei not like '0%')
 )a
 where seqno = 1;

 drop table if exists `data-bi-prd-935c.bi_stg`.ari_tmp_0522_vlr30days_2_daily_ggsn; 
 
 select CURRENT_TIMESTAMP() as table_ari_tmp_0522_vlr30days_2_daily_ggsn;

 create table `data-bi-prd-935c.bi_stg`.ari_tmp_0522_vlr30days_2_daily_ggsn 
 AS 
 select *
 from
 ( 
 select
 row_number() over (partition by sbscrptn_msisdn order by dt desc) as seqno, 
 sbscrptn_msisdn, 
 imei
 from `data-dtptechm-prd-c7ca.dwh.fct_ggsn_imei`
 where cast(dt as date) >= DATE_SUB(vdt_id, INTERVAL 29 DAY)
 and dt <= vdt_id
 ) a 
 where seqno = 1; 
 

 delete from `data-bi-prd-935c.bi_mart.project_imeivlr30days_daily_ggsn` where dt = vdt_id; 
 
 --create table mis.project_Imeivlr30days_daily_ggsn 
 --WITH (appendonly=true, compresstype=zlib, compresslevel=3, orientation=column) AS 
 insert into `data-bi-prd-935c.bi_mart.project_imeivlr30days_daily_ggsn`
 select
 cast(vdt_id as date) as dt,
 case
 when coalesce(b.imei,a.imei) is null or coalesce(b.imei,a.imei) = '' then '01. blank' 
 when coalesce(b.imei,a.imei) like '0%' then '02. invalid' 
 else '03. valid'
 end as flag,
 a.imei as ori_imei, 
 coalesce(b.imei,a.imei) as latest_imei, 
 a.sbscrptn_msisdn
 from `data-bi-prd-935c.bi_stg`.ari_tmp_0522_vlr30days_2_daily_ggsn a 
 left outer join `data-bi-prd-935c.bi_stg`.ari_tmp_0522_vlr30days_daily_ggsn b ON a.sbscrptn_msisdn = b.sbscrptn_msisdn; 
 
drop table if exists `data-bi-prd-935c.bi_stg`.ari_tmp_0522_vlr30days_daily_ggsn; 
 
 drop table if exists `data-bi-prd-935c.bi_stg`.ari_tmp_0522_vlr30days_2_daily_ggsn; 
