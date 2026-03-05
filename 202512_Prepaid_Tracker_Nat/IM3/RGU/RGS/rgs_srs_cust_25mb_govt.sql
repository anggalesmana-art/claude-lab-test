--REFRESH biadm.umr_rgu_ga_90d_dly_act2b ;
--REFRESH biadm.umr_rgs_ga_90d_dly ;
--REFRESH biadm.umr_rgs_mtd ;

declare vdt_id date default @vdt_id;
declare bgndt date;

set bgndt = DATE_SUB(vdt_id, INTERVAL 1 YEAR);

--- Create Table
/*
CREATE OR REPLACE TABLE IF NOT EXISTS biadm.umr_rgs_srs_cust_25mb_govt
(
ppn_dttm TIMESTAMP,
msisdn   STRING,
actvn_dt STRING,
svc_class_code STRING,
ga_dt    STRING,
ga_site  STRING,
srs_site STRING,
total_rev  DOUBLE
)
partitioned BY (dt_id STRING)
stored AS parquet ;
*/
--- Collect historical data
/*
INSERT overwrite TABLE biadm.umr_rgs_srs_cust_25mb_govt partition(dt_id)
SELECT * FROM biadm.umr_rgs_srs_cust_25mb 
WHERE dt_id >= '20210501' AND dt_id < '20220601' ;

*/
--- Temp Table

CREATE OR REPLACE TABLE `data-bi-prd-935c.bi_stg.rgs_srs_cust_govt_{{ vdt_id }}_tmp1` AS
SELECT a.msisdn, a.actvn_dt, svc_class_code, a.dt_id ga_dt, a.site_id ga_site, b.total_rev
FROM 
( SELECT msisdn, actvn_dt, dt_id, site_id, svc_class_code FROM `data-bi-prd-935c.bi_mart.rgu_ga_90d_dly_act2b` a
  WHERE a.dt_id >= '2021-05-01' AND a.dt_id < '2021-10-01' 
    AND (churn_back = 'NO' OR recycled = 'YES')
  UNION ALL 
  SELECT msisdn, actvn_dt, dt_id, site_id, svc_class_code FROM `data-bi-prd-935c.bi_mart.rgs_ga_90d_dly` b
  WHERE b.dt_id >= '2021-10-01' AND b.dt_id < '2022-06-01' 
    AND (churn_back = 'NO' OR recycled = 'YES')
  UNION ALL 
  SELECT msisdn, actvn_dt, dt_id, site_id, svc_class_code FROM `data-bi-prd-935c.bi_mart.rgs_ga_90d_dly_govt` c
  WHERE c.dt_id >= '2022-06-01' 
    AND (churn_back = 'NO' OR recycled = 'YES')	
) a  
JOIN 
( SELECT msisdn, total_rev FROM `data-bi-prd-935c.bi_mart.rgs_mtd_govt` --umr_rgs_mtd
  WHERE dt_id = vdt_id
    AND total_rev > 0
) b   
ON a.msisdn = b.msisdn 
WHERE a.dt_id >= bgndt AND a.dt_id <= vdt_id ;

--REFRESH biadm.all_90d_fav_loc_dly --rgu_90d_fav_loc_dly_v2 ;
-- REFRESH biadm.umr_rgs_srs_cust_25mb_govt ;

CREATE OR REPLACE TABLE `data-bi-prd-935c.bi_stg.rgs_srs_cust_govt_{{ vdt_id }}_tmp2` AS
SELECT a.*, c.site_id AS srs_site
FROM `data-bi-prd-935c.bi_stg.rgs_srs_cust_govt_{{ vdt_id }}_tmp1` a  
LEFT JOIN 
( SELECT concat(msisdn, ga_dt) cust_id
  FROM `data-bi-prd-935c.bi_mart.rgs_srs_cust_25mb_govt`
  WHERE dt_id >= bgndt AND dt_id < vdt_id
) b
ON concat(a.msisdn, a.ga_dt) = b.cust_id
LEFT JOIN 
( SELECT * FROM `data-bi-prd-935c.bi_mart.all_90d_fav_loc_dly` WHERE dt_id = vdt_id ) c
ON a.msisdn = c.msisdn 
WHERE b.cust_id IS NULL ;

--- Insert
-- INSERT overwrite TABLE `data-bi-prd-935c.bi_mart.rgs_srs_cust_25mb_govt` partition(dt_id)
-- SELECT CURRENT_DATE() AS ppn_dttm, msisdn, actvn_dt, svc_class_code
-- , ga_dt, ga_site, coalesce(srs_site,ga_site) srs_site--, srs_site
-- , total_rev, 'vdt_id' AS dt_id 
-- FROM `data-bi-prd-935c.bi_stg.rgs_srs_cust_govt_{{ vdt_id }}`;

DELETE FROM `data-bi-prd-935c.bi_mart.rgs_srs_cust_25mb_govt`
WHERE dt_id = vdt_id;

INSERT INTO `data-bi-prd-935c.bi_mart.rgs_srs_cust_25mb_govt`
SELECT timestamp(current_datetime('+7')) AS ppn_dttm, 
       msisdn, 
       actvn_dt, 
       svc_class_code,
       ga_dt, 
       ga_site, 
       COALESCE(srs_site, ga_site) AS srs_site, 
       total_rev, 
       vdt_id AS dt_id 
FROM `data-bi-prd-935c.bi_stg.rgs_srs_cust_govt_{{ vdt_id }}_tmp2`;

--- Drop Temp Table
DROP TABLE `data-bi-prd-935c.bi_stg.rgs_srs_cust_govt_{{ vdt_id }}_tmp1`;
DROP TABLE `data-bi-prd-935c.bi_stg.rgs_srs_cust_govt_{{ vdt_id }}_tmp2`;
