--Migrate by Indra Maulana Ikhsan 20241121
/*------------------*/
/* RGS 90D HVC Govt */
/*------------------*/

/*
insert into `data-bi-prd-935c.bi_mart`.rgs_all_nogovt_dly 
select * from `data-bi-prd-935c.bi_mart`.rgs_all_nogovt_dly
where dt_id between '20240101' and '20240330'
;

create OR REPLACE table `data-bi-prd-935c.bi_mart`.rgs_90d_govt like `data-bi-prd-935c.bi_mart`.rgs_90d_govt;
create OR REPLACE table `data-bi-prd-935c.bi_mart`.rgs_30d_govt like `data-bi-prd-935c.bi_mart`.rgs_30d_govt;

create OR REPLACE table `data-bi-prd-935c.bi_mart`.rgs_90d_govt_bak AS
select * from `data-bi-prd-935c.bi_mart`.rgs_90d_govt
where dt_id between '20240401' and '20240531'
;

create OR REPLACE table `data-bi-prd-935c.bi_mart`.rgs_30d_govt_bak AS
select * from `data-bi-prd-935c.bi_mart`.rgs_30d_govt
where dt_id between '20240401' and '20240531'
;
*/

--REFRESH `data-bi-prd-935c.bi_mart`.rk_all_90d_fav_loc_dly ;
--REFRESH `data-bi-prd-935c.bi_mart`.rk_rgu_90d_fav_loc_dly_v2 ;

--- Create Table
/*
CREATE OR REPLACE TABLE IF NOT EXISTS `data-bi-prd-935c.bi_mart`.rgs_90d_govt
(
site_id    STRING,
subs_l3m   INT,
arpu       STRING,
subs       DOUBLE,
tot_rev_m0 DOUBLE,
tot_rev_m1 DOUBLE,
tot_rev_m2 DOUBLE,
tenure     STRING,
flag       STRING,
ppn_dttm   TIMESTAMP
)
partitioned BY (dt_id STRING)
stored AS parquet ;
*/
declare vdt_id date default @vdt_id;
--- Temp 1
CREATE OR REPLACE TABLE `data-bi-prd-935c.bi_mart`.tmp_rgs_90d_30d_govt_{{ vdt_id }} AS
with rev_30 as (
  SELECT msisdn
    , sum(case when dt_id=vdt_id then rev_30 else 0 end) rev_m0
    , sum(case when dt_id=date(vdt_id-interval 30 day) then rev_30 else 0 end) rev_m1
    , sum(case when dt_id=date(vdt_id-interval 60 day) then rev_30 else 0 end) rev_m2
  FROM `data-bi-prd-935c.bi_mart`.rgs_all_nogovt_dly
  WHERE flag LIKE '%K%' -- Base 30D
    and dt_id IN (
      vdt_id,
      date(vdt_id-interval 30 day),
      date(vdt_id-interval 60 day)
    )
  group by 1
)
SELECT a.msisdn, a.flag, a.site_id_90, a.site_id_30, a.svc_class_code,
  coalesce(b.rev_m0,0) tot_rev_m0, coalesce(b.rev_m1,0) tot_rev_m1, coalesce(b.rev_m2,0) tot_rev_m2
FROM `data-bi-prd-935c.bi_mart`.rgs_all_nogovt_dly a
LEFT JOIN rev_30 b
  on a.msisdn=b.msisdn
WHERE a.dt_id = vdt_id
  AND (
    flag LIKE '%A%' -- Base 90D
    or
    flag LIKE '%K%' -- Base 90D
  )
;

--- 90D
delete from `data-bi-prd-935c.bi_mart`.rgs_90d_govt where dt_id = vdt_id;
INSERT into `data-bi-prd-935c.bi_mart`.rgs_90d_govt 
SELECT site_id_90, subs_l3m,
  CASE WHEN subs_l3m = 0 THEN 'd.Non RGE'
    WHEN tot_l3m_rev/subs_l3m <= 30000  THEN 'c.<=30K'
    WHEN tot_l3m_rev/subs_l3m <= 100000 THEN 'b.30K-100K'
    WHEN tot_l3m_rev/subs_l3m >  100000 THEN 'a.>100K'
  END arpu,
  count(1) subs,
  sum(tot_rev_m0) tot_rev_m0, sum(tot_rev_m1) tot_rev_m1, sum(tot_rev_m2) tot_rev_m2,
  CASE
    WHEN c.first_rgu >= vdt_id - interval 90 day THEN 'Inflow'
    WHEN c.first_rgu <  vdt_id - interval 90 day THEN 'Base'
  END tenure,
CASE WHEN x.svc_class_code = d.svc_class_code THEN 'B2B' ELSE 'B2C' END flag,
timestamp(current_datetime('+7')) AS ppn_dttm, vdt_id AS dt_id
FROM (
  SELECT a.*,
    (tot_rev_m0+tot_rev_m1+tot_rev_m2) tot_l3m_rev,
    ( (CASE WHEN tot_rev_m0 > 0 THEN 1 ELSE 0 END) +
      (CASE WHEN tot_rev_m1 > 0 THEN 1 ELSE 0 END) +
      (CASE WHEN tot_rev_m2 > 0 THEN 1 ELSE 0 END)
    ) subs_l3m
  FROM `data-bi-prd-935c.bi_mart`.tmp_rgs_90d_30d_govt_{{ vdt_id }} a
  where flag like '%A%'
) x
LEFT JOIN (
  SELECT msisdn, first_rgu
    --datediff(from_unixtime(unix_timestamp(vdt_id, 'yyyyMMdd')),
    --         from_unixtime(unix_timestamp(first_rgu, 'yyyyMMdd'))) AS tnr
  --FROM `data-bi-prd-935c.bi_mart`.first_rgs_govt
  FROM `data-bi-prd-935c.bi_mart`.first_rgs_govt
  WHERE date(mth_id) = date_trunc(vdt_id,month)
) c
  ON x.msisdn = c.msisdn
LEFT JOIN `data-bi-prd-935c.bi_mart`.ref_sc_b2b d
  ON x.svc_class_code = d.svc_class_code
GROUP BY 1, 2, 3, 8, 9 ;

--- 30D
delete from `data-bi-prd-935c.bi_mart`.rgs_30d_govt where dt_id = vdt_id;
INSERT into `data-bi-prd-935c.bi_mart`.rgs_30d_govt 
SELECT site_id_30, subs_l3m,
  CASE WHEN subs_l3m = 0 THEN 'd.Non RGE'
    WHEN tot_l3m_rev/subs_l3m <= 30000  THEN 'c.<=30K'
    WHEN tot_l3m_rev/subs_l3m <= 100000 THEN 'b.30K-100K'
    WHEN tot_l3m_rev/subs_l3m >  100000 THEN 'a.>100K'
  END arpu,
  count(1) subs,
  sum(tot_rev_m0) tot_rev_m0, sum(tot_rev_m1) tot_rev_m1, sum(tot_rev_m2) tot_rev_m2,
  CASE
    WHEN c.first_rgu >= vdt_id - interval 90 day THEN 'Inflow'
    WHEN c.first_rgu <  vdt_id - interval 90 day THEN 'Base'
  END tenure,
CASE WHEN x.svc_class_code = d.svc_class_code THEN 'B2B' ELSE 'B2C' END flag,
timestamp(current_datetime('+7')) AS ppn_dttm, vdt_id AS dt_id
FROM (
  SELECT a.*,
    (tot_rev_m0+tot_rev_m1+tot_rev_m2) tot_l3m_rev,
    ( (CASE WHEN tot_rev_m0 > 0 THEN 1 ELSE 0 END) +
      (CASE WHEN tot_rev_m1 > 0 THEN 1 ELSE 0 END) +
      (CASE WHEN tot_rev_m2 > 0 THEN 1 ELSE 0 END)
    ) subs_l3m
  FROM `data-bi-prd-935c.bi_mart`.tmp_rgs_90d_30d_govt_{{ vdt_id }} a
  where flag like '%K%'
) x
LEFT JOIN (
  SELECT msisdn, first_rgu
    --datediff(from_unixtime(unix_timestamp(vdt_id, 'yyyyMMdd')),
    --         from_unixtime(unix_timestamp(first_rgu, 'yyyyMMdd'))) AS tnr
  --FROM `data-bi-prd-935c.bi_mart`.first_rgs_govt
  FROM `data-bi-prd-935c.bi_mart`.first_rgs_govt
  WHERE date(mth_id) = date_trunc(vdt_id,month)
) c
  ON x.msisdn = c.msisdn
LEFT JOIN `data-bi-prd-935c.bi_mart`.ref_sc_b2b d
  ON x.svc_class_code = d.svc_class_code
GROUP BY 1, 2, 3, 8, 9 ;

--- Drop Temp Table
DROP TABLE `data-bi-prd-935c.bi_mart`.tmp_rgs_90d_30d_govt_{{ vdt_id }} ;