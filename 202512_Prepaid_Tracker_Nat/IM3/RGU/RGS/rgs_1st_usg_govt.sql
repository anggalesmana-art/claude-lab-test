--Migrate by Indra Maulana Ikhsan 20241121
/*
CREATE TABLE IF NOT EXISTS `data-bi-prd-935c.bi_mart`.first_rgs_govt
(
msisdn    string,
actvn_dt  string,
first_rgu string,
last_rgu  string,
ppn_dttm  timestamp
)
partitioned BY (mth_id string)
stored AS parquet ;
*/


/*
--- Collect historical data
INSERT overwrite TABLE `data-bi-prd-935c.bi_mart`.first_rgs_govt partition(mth_id)
SELECT * FROM `data-bi-prd-935c.bi_mart`.first_rgs
WHERE mth_id = '202205' ;
*/
declare vdt_id date default @vdt_id;
--- Update MTD
CREATE OR REPLACE TABLE `data-bi-prd-935c.bi_mart`.all_rgs_govt_{{ vdt_id }}_tmp1 as 
SELECT msisdn, actvn_dt,
min(dt_min) AS dt_min, max(dt_max) AS dt_max
FROM
( SELECT msisdn, actvn_dt,
  first_rgu dt_min, last_rgu dt_max
  --FROM `data-bi-prd-935c.bi_mart`.first_rgs_govt
  FROM `data-bi-prd-935c.bi_mart`.first_rgs_govt
  WHERE mth_id = date_trunc(vdt_id - interval 1 month, month)
  UNION ALL
  SELECT msisdn, actvn_dt, dt_min, dt_max
  --FROM `data-bi-prd-935c.bi_mart`.rgs_mtd_govt
  FROM `data-bi-prd-935c.bi_mart`.rgs_mtd_govt
  WHERE dt_id = vdt_id
) a
GROUP BY msisdn, actvn_dt ;

--- Update MTD Distinct
CREATE OR REPLACE TABLE `data-bi-prd-935c.bi_mart`.all_rgs_govt_{{ vdt_id }}_tmp2 as 
SELECT * FROM
( SELECT a.*,
  row_number() OVER (PARTITION BY msisdn order BY actvn_dt DESC) ranks
  FROM `data-bi-prd-935c.bi_mart`.all_rgs_govt_{{ vdt_id }}_tmp1 a
) b
WHERE b.ranks = 1 ;

--- Insert Into
--INSERT overwrite TABLE `data-bi-prd-935c.bi_mart`.first_rgs_govt partition(mth_id)
delete from `data-bi-prd-935c.bi_mart`.first_rgs_govt where mth_id = date_trunc(vdt_id, month);
INSERT INTO `data-bi-prd-935c.bi_mart`.first_rgs_govt
SELECT msisdn, actvn_dt, dt_min AS first_rgu, dt_max AS last_rgu,
  timestamp(current_datetime('+7')) AS ppn_dttm,
  date_trunc(vdt_id, month) mth_id
FROM `data-bi-prd-935c.bi_mart`.all_rgs_govt_{{ vdt_id }}_tmp2
;

--- Drop Table
DROP TABLE `data-bi-prd-935c.bi_mart`.all_rgs_govt_{{ vdt_id }}_tmp1;
DROP TABLE `data-bi-prd-935c.bi_mart`.all_rgs_govt_{{ vdt_id }}_tmp2;