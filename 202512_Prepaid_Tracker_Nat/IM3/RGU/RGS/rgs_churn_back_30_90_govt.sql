--migrate by Indra Maulana Ikhsan 20241122

--- Create Table
/*
CREATE TABLE IF NOT EXISTS `data-bi-prd-935c.bi_mart`.rgs_churn_back_90d_govt
(
msisdn    string,
actvn_dt  string,
usg_flag  string,
total_rev double,
svc_class_code string,
site_id   string,
first_usg string,
last_usg  string,
churn_dt string,
total_rev_m4 double,
total_rev_m5 double,
total_rev_m6 double,
ppn_dttm  timestamp 
)
partitioned BY (dt_id string)
stored AS parquet ;
*/
--- Collect historical data

--- Create Table
/*
CREATE TABLE IF NOT EXISTS `data-bi-prd-935c.bi_mart`.rgs_churn_back_30d_govt
(
msisdn    string,
actvn_dt  string,
usg_flag  string,
total_rev double,
svc_class_code string,
site_id   string,
first_usg string,
last_usg  string,
churn_dt string,
total_rev_m2 double,
total_rev_m3 double,
total_rev_m4 double,
ppn_dttm  timestamp 
)
partitioned BY (dt_id string)
stored AS parquet ;
*/
declare vdt_id date default @vdt_id;
delete from `data-bi-prd-935c.bi_mart`.rgs_churn_back_90d_govt where dt_id = vdt_id;
insert into `data-bi-prd-935c.bi_mart`.rgs_churn_back_90d_govt 
with churn as (
  select * from (
    SELECT *, row_number() over (PARTITION BY msisdn ORDER BY dt_id DESC) AS rk  
    FROM `data-bi-prd-935c.bi_mart`.rgs_churn_90d_dly_govt
    where dt_id between vdt_id - interval 90 day
      and vdt_id - interval 1 day
  ) x
  where rk=1
)
SELECT a.msisdn, a.actvn_dt, a.usg_flag, coalesce(a.total_rev,0) total_rev, a.svc_class_code, a.site_id,
  b.first_usg, b.last_usg,
  b.dt_id AS churn_dt,
  coalesce(b.total_rev_m4,0) total_rev_m4, coalesce(b.total_rev_m5,0) total_rev_m5, coalesce(b.total_rev_m6,0) total_rev_m6,
  timestamp(current_datetime('+7')) AS ppn_dttm, a.dt_id
FROM `data-bi-prd-935c.bi_mart`.rgs_ga_90d_dly_govt a
LEFT JOIN churn b
ON a.msisdn = b.msisdn
WHERE a.dt_id = vdt_id
  AND churn_back = 'YES' AND recycled = 'NO'
;

delete from `data-bi-prd-935c.bi_mart`.rgs_churn_back_30d_govt where dt_id = vdt_id;
insert into `data-bi-prd-935c.bi_mart`.rgs_churn_back_30d_govt 
with
ga as (
  SELECT a.*
  FROM `data-bi-prd-935c.bi_mart`.rgs_all_nogovt_dly a
  LEFT JOIN (
    SELECT msisdn  
    FROM `data-bi-prd-935c.bi_mart`.rgs_all_nogovt_dly
    WHERE dt_id = vdt_id AND flag LIKE '%B%' -- GA 90D
  ) b
    ON a.msisdn = b.msisdn
  WHERE a.dt_id = vdt_id
    AND flag LIKE '%L%' -- GA 30D
    AND b.msisdn IS NULL
)
SELECT a.msisdn, a.actvn_dt, a.usg_flag, coalesce(a.rev_30,0) rev_30, a.svc_class_code, a.site_id_30,
  b.first_usg, b.last_usg,
  b.dt_id AS churn_dt,
  coalesce(b.total_rev_m2,0) total_rev_m2, coalesce(b.total_rev_m3,0) total_rev_m3, coalesce(b.total_rev_m4,0) total_rev_m4,
  timestamp(current_datetime('+7')) AS ppn_dttm, a.dt_id
from ga a
LEFT JOIN (
  select * from (
    SELECT *, row_number() over (PARTITION BY msisdn ORDER BY dt_id DESC) AS rk  
    FROM `data-bi-prd-935c.bi_mart`.rgs_churn_30d_dly_govt
    where dt_id between vdt_id - interval 60 day and 
      vdt_id - interval 1 day
  ) x
  where rk=1
) b
  on a.msisdn=b.msisdn
;