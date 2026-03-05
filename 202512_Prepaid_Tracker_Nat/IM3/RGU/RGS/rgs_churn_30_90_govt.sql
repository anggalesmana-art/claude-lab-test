--Migrate by  Indra Maulana Ikhsan 20241121
/*
--- Create OR REPLACE Table
CREATE OR REPLACE TABLE IF NOT EXISTS `data-bi-prd-935c.bi_mart`.rgs_churn_30d_dly_govt
(
msisdn    STRING,
actvn_dt  STRING,
svc_class_code STRING,
first_usg STRING,
last_usg  STRING,
total_rev_m2 DOUBLE,
total_rev_m3 DOUBLE,
total_rev_m4 DOUBLE,
site_id      STRING,
ppn_dttm     TIMESTAMP
)
partitioned BY (dt_id STRING)
stored AS parquet ;
*/
declare vdt_id date default @vdt_id;

CREATE OR REPLACE TABLE `data-bi-prd-935c.bi_mart`.tmp_rgs_churn_govt_rev_{{ vdt_id }} AS
with churn as (
  SELECT dt_id, msisdn, flag, actvn_dt, svc_class_code, site_id_90, site_id_30, max_dt last_usg
  FROM `data-bi-prd-935c.bi_mart`.rgs_all_nogovt_dly
  WHERE dt_id = vdt_id
    AND (
      flag LIKE '%C%' -- Churn 90D
      or
      flag LIKE '%M%' -- Churn 30D
    )
),
churn_rev as (
  SELECT a.msisdn, coalesce(a.rev_30,0) total_rev, a.dt_id rev_dt
  FROM `data-bi-prd-935c.bi_mart`.rgs_all_nogovt_dly a
  inner join churn b
    on a.msisdn=b.msisdn
  WHERE a.dt_id IN (
      date(vdt_id-interval 30 day),
      date(vdt_id-interval 60 day),
      date(vdt_id-interval 90 day),
      date(vdt_id-interval 120 day),
      date(vdt_id-interval 150 day)
    )
    AND a.flag LIKE '%K%' -- Base 30D
)
select a.*, c.first_rgu, b.rev_30, b.rev_60, b.rev_90, b.rev_120, b.rev_150
from churn a
left join (
  select msisdn
    , sum(case when rev_dt=date(vdt_id-interval 30 day) then total_rev else 0 end) rev_30
    , sum(case when rev_dt=date(vdt_id-interval 60 day) then total_rev else 0 end) rev_60
    , sum(case when rev_dt=date(vdt_id-interval 90 day) then total_rev else 0 end) rev_90
    , sum(case when rev_dt=date(vdt_id-interval 120 day) then total_rev else 0 end) rev_120
    , sum(case when rev_dt=date(vdt_id-interval 150 day) then total_rev else 0 end) rev_150
  from churn_rev
  group by 1
) b
  on a.msisdn=b.msisdn
left join `data-bi-prd-935c.bi_mart`.first_rgs_govt c
  on a.msisdn=c.msisdn and c.mth_id = date_trunc(date(vdt_id-interval 1 month),month)
;

-- Churn 90
delete from `data-bi-prd-935c.bi_mart`.rgs_churn_90d_dly_govt where dt_id = vdt_id;
insert into `data-bi-prd-935c.bi_mart`.rgs_churn_90d_dly_govt 
SELECT msisdn, actvn_dt, svc_class_code, first_rgu first_usg, last_usg,
  coalesce(rev_90,0) rev_90, coalesce(rev_120,0) rev_120, coalesce(rev_150,0) rev_150,
  site_id_90, timestamp(current_datetime('+7')) AS ppn_dttm, dt_id
from `data-bi-prd-935c.bi_mart`.tmp_rgs_churn_govt_rev_{{ vdt_id }}
where flag like '%C%'
;

-- Churn 30
delete from `data-bi-prd-935c.bi_mart`.rgs_churn_30d_dly_govt where dt_id = vdt_id;
insert into `data-bi-prd-935c.bi_mart`.rgs_churn_30d_dly_govt 
SELECT msisdn, actvn_dt, svc_class_code, first_rgu first_usg, last_usg,
  coalesce(rev_30,0) rev_30, coalesce(rev_60,0) rev_60, coalesce(rev_90,0) rev_90,
  site_id_30, timestamp(current_datetime('+7')) AS ppn_dttm, dt_id
from `data-bi-prd-935c.bi_mart`.tmp_rgs_churn_govt_rev_{{ vdt_id }}
where flag like '%M%'
;

DROP TABLE IF EXISTS `data-bi-prd-935c.bi_mart`.tmp_rgs_churn_govt_rev_{{ vdt_id }};