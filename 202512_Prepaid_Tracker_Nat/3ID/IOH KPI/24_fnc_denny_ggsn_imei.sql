DECLARE vdt_id DATE DEFAULT @vdt_id;

delete from `data-bi-prd-935c.bi_mart.fct_ggsn_imei` where dt = vdt_id;

insert into `data-bi-prd-935c.bi_mart.fct_ggsn_imei`
select cast(dt as date) as dt, cast(sbscrptn_ek_id as string), sbscrptn_msisdn, imei
from
(
 select distinct created_dt_sk_id as dt, sbscrptn_ek_id, sbscrptn_msisdn, served_imeisv as imei, row_number() over(partition by sbscrptn_ek_id order by served_imeisv) as seq
 from `data-dtptechm-prd-c7ca.dwh.daily_gprs_msisdn_summary` a
 where created_dt_sk_id = vdt_id  and 
 --and (lower(apn_for_gprs_nm) like '%3gprs%' or lower(apn_for_gprs_nm) like '%3data%') and 
gprs_rating_grp_nm <> '0'
) a
where a.seq = 1;
