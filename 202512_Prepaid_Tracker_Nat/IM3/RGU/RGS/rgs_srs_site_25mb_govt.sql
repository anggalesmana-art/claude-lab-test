declare vdt_id date default @vdt_id;
declare dtid1 date;

set dtid1 = DATE_TRUNC(vdt_id, MONTH);

--- Create OR REPLACE Table
/*
CREATE OR REPLACE TABLE IF NOT EXISTS biadm.umr_rgs_srs_site_25mb_govt
(
ppn_dttm TIMESTAMP,
msisdn   STRING,
actvn_dt STRING,
svc_class_code STRING,
ga_dt    STRING,
ga_site  STRING,
srs_dt STRING,
srs_site STRING,
`25mb_site` STRING,
vol_mb DOUBLE,
total_rev  DOUBLE
)
partitioned BY (dt_id STRING)
stored AS parquet ;
*/
--- Temp Table

CREATE OR REPLACE TABLE `data-bi-prd-935c.bi_stg.rgs_srs_site_govt_{{ vdt_id }}_tmp1` AS
SELECT a.*, (d_vol/1024/1024) vol_mb
FROM `data-bi-prd-935c.bi_mart.rgs_srs_cust_25mb_govt` a
JOIN 
( SELECT msisdn, max(d_vol) d_vol FROM `data-bi-prd-935c.bi_mart.voice_data_user_mtd`
  WHERE dt_id = vdt_id
  GROUP BY 1
) b
ON a.msisdn = b.msisdn
WHERE a.dt_id >= dtid1 AND a.dt_id <= vdt_id 
  AND d_vol >= (25*1024*1024) ;

-- REFRESH biadm.umr_rgs_srs_site_25mb_govt ;

CREATE OR REPLACE TABLE `data-bi-prd-935c.bi_stg.rgs_srs_site_govt_{{ vdt_id }}_tmp2` AS
SELECT a.*, c.site_id AS `25mb_site`
FROM `data-bi-prd-935c.bi_stg.rgs_srs_site_govt_{{ vdt_id }}_tmp1` a  
LEFT JOIN 
( SELECT concat(msisdn, ga_dt) cust_id
  FROM `data-bi-prd-935c.bi_mart.rgs_srs_site_25mb_govt`
  WHERE dt_id >= dtid1 AND dt_id < vdt_id
) b
ON concat(a.msisdn,a.ga_dt) = b.cust_id
LEFT JOIN 
( SELECT * FROM `data-bi-prd-935c.bi_mart.all_90d_fav_loc_dly` WHERE dt_id = vdt_id ) c
ON a.msisdn = c.msisdn 
WHERE b.cust_id IS NULL ;

--- Insert
-- INSERT overwrite TABLE `data-bi-prd-935c.bi_stg.rgs_srs_site_25mb_govt` partition(dt_id)
-- SELECT CURRENT_DATE() AS ppn_dttm, msisdn, actvn_dt, svc_class_code
-- , ga_dt, ga_site, dt_id srs_dt, coalesce(srs_site,ga_site) srs_site--, srs_site
-- , `25mb_site` , vol_mb, total_rev, vdt_id AS dt_id 
-- FROM `data-bi-prd-935c.bi_stg.rgs_srs_site_govt_{{ vdt_id }}` ; 

DELETE FROM `data-bi-prd-935c.bi_mart.rgs_srs_site_25mb_govt`
WHERE dt_id = vdt_id;

INSERT INTO `data-bi-prd-935c.bi_mart.rgs_srs_site_25mb_govt`
SELECT timestamp(current_datetime('+7')) AS ppn_dttm, 
       msisdn, 
       actvn_dt, 
       svc_class_code,
       ga_dt, 
       ga_site, 
       dt_id AS srs_dt, 
       COALESCE(srs_site, ga_site) AS srs_site,
       `25mb_site`, 
       vol_mb, 
       total_rev, 
       vdt_id AS dt_id 
FROM `data-bi-prd-935c.bi_stg.rgs_srs_site_govt_{{ vdt_id }}_tmp2`;

--- Drop Temp Table
DROP TABLE `data-bi-prd-935c.bi_stg.rgs_srs_site_govt_{{ vdt_id }}_tmp1`;
DROP TABLE `data-bi-prd-935c.bi_stg.rgs_srs_site_govt_{{ vdt_id }}_tmp2`;
