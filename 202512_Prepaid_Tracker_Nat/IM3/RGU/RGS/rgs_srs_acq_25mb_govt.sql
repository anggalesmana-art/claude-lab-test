--REFRESH `data-bi-prd-935c.bi_mart`.umr_rgs_srs_cust_25mb_govt ;
--REFRESH `data-bi-prd-935c.bi_mart`.umr_rgs_mtd_govt ;
--REFRESH `data-bi-prd-935c.bi_mart`.all_90d_fav_loc_dly ;

declare vdt_id date default @vdt_id;
declare bgndt date;
declare dtid2 date;

set bgndt = DATE_TRUNC(vdt_id, MONTH);
set dtid2 = DATE_SUB(vdt_id, INTERVAL 360 DAY);

--- Create OR REPLACE Table
/*
CREATE OR REPLACE TABLE IF NOT EXISTS `data-bi-prd-935c.bi_mart`.umr_rgs_srs_acq_25mb_govt2
(
ppn_dttm TIMESTAMP,
msisdn   STRING,
actvn_dt STRING,
svc_class_code STRING,
ga_dt    STRING,
ga_site  STRING,
srs_dt   STRING,
srs_site STRING,
`25mb_dt`   STRING,
`25mb_site` STRING,
mtd_site STRING,
acq_rev  DOUBLE,
acq_dly_rev  DOUBLE,
datavol  DOUBLE,
inject_dt    STRING,
flag_sp      STRING,
product_name STRING,
flag_quality STRING,
flag_acm     STRING,
main_price   DOUBLE, 
sp_price     DOUBLE, 
main_price_acm2 DOUBLE,
`1st_rdm`      STRING,
channel      STRING, 
organization_id STRING,
product_type STRING,
flag_status STRING
)
partitioned BY (dt_id STRING)
stored AS parquet ;
*/
--- Collect historical data
/*
INSERT overwrite TABLE `data-bi-prd-935c.bi_mart`.umr_rgs_srs_acq_25mb_govt2 partition(dt_id)
SELECT ppn_dttm, msisdn, actvn_dt, svc_class_code, ga_dt, ga_site, srs_dt, srs_site,
'' `25mb_dt`, '' `25mb_site`, mtd_site, acq_rev, acq_dly_rev, datavol,
inject_dt, flag_sp, product_name, flag_quality, flag_acm, main_price, sp_price,
main_price_acm2, `1st_rdm`, channel, organization_id, product_type, flag_status, dt_id
FROM `data-bi-prd-935c.bi_mart`.umr_rgs_srs_acq_25mb_govt 
WHERE dt_id >= '20230401' AND dt_id < '20230601' ;

ALTER TABLE `data-bi-prd-935c.bi_mart`.umr_rgs_srs_acq_25mb_govt RENAME TO `data-bi-prd-935c.bi_mart`.umr_rgs_srs_acq_25mb_govt_bak_20230616 ;
ALTER TABLE `data-bi-prd-935c.bi_mart`.umr_rgs_srs_acq_25mb_govt2 RENAME TO `data-bi-prd-935c.bi_mart`.umr_rgs_srs_acq_25mb_govt ;
*/
--- Temp Table

CREATE OR REPLACE TABLE `data-bi-prd-935c.bi_mart`.rgs_srs_acq_govt_{{ vdt_id }}_tmp1 AS
SELECT a.*, ifnull(b.total_rev,0) AS acq_rev, coalesce(c.site_id, srs_site) AS mtd_site
, ifnull(d.total_rev,0) AS acq_dly_rev, ifnull(x.d_vol,0) AS datavol, `25mb_dt`, `25mb_site`
FROM `data-bi-prd-935c.bi_mart.rgs_srs_cust_25mb_govt` a
LEFT JOIN 
( SELECT msisdn, total_rev FROM `data-bi-prd-935c.bi_mart.rgs_mtd_govt`
  WHERE dt_id = vdt_id
) b
ON a.msisdn = b.msisdn 
LEFT JOIN 
( SELECT msisdn, max(d_vol) d_vol FROM `data-bi-prd-935c.bi_mart.voice_data_user_mtd`
  WHERE dt_id = vdt_id
  GROUP BY 1
) x
ON a.msisdn = x.msisdn 
LEFT JOIN 
( SELECT msisdn, total_rev FROM `data-bi-prd-935c.bi_mart.rgs_nogovt_dly` --hg_ioh_rgs_dly
  WHERE dt_id = vdt_id
   AND (flag_status = 'Active 2' OR ifnull(total_rev,0)>0)
) d
ON a.msisdn = d.msisdn
LEFT JOIN 
( SELECT concat(msisdn, ga_dt) cust_id, dt_id AS `25mb_dt`, `25mb_site`
  FROM `data-bi-prd-935c.bi_mart.rgs_srs_site_25mb_govt`
  WHERE dt_id >= bgndt AND dt_id <= vdt_id
) y
ON concat(a.msisdn,a.ga_dt) = y.cust_id
LEFT JOIN 
( SELECT * FROM `data-bi-prd-935c.bi_mart`.all_90d_fav_loc_dly WHERE dt_id = vdt_id ) c
ON a.msisdn = c.msisdn 
WHERE a.dt_id >= bgndt AND a.dt_id <= vdt_id ;

CREATE OR REPLACE TABLE `data-bi-prd-935c.bi_mart.rgs_srs_acq_govt_{{ vdt_id }}_tmp2` AS
SELECT timestamp(current_datetime('+7')) AS ppn_dttm, msisdn, a.actvn_dt, a.svc_class_code, ga_dt, ga_site
, dt_id AS srs_dt, srs_site, `25mb_dt`, `25mb_site`, mtd_site, acq_rev, acq_dly_rev, datavol
, inject_dt, flag_sp, product_name, flag_quality, flag_acm, main_price, sp_price, main_price_acm2
, CASE WHEN flag_quality IS NULL THEN 'NO'
       WHEN (acq_rev/main_price_acm2) >= 0.79 THEN 'YES'
       WHEN product_name LIKE '%000%' THEN 'YES'
	   WHEN upper(product_name) LIKE '%PULSA%' THEN 'YES'
  ELSE 'NO'	   
  END `1st_rdm`
, channel, organization_id, product_type
FROM `data-bi-prd-935c.bi_mart.rgs_srs_acq_govt_{{ vdt_id }}_tmp1` a 
LEFT JOIN
( SELECT concat(msisdn, ga_dt) cust_id, flag_quality, flag_acm, inject_dt, flag_sp,
  CASE WHEN flag_sp LIKE 'SP Data%GB' THEN flag_sp
       WHEN flag_sp LIKE 'SP IM3%GB' THEN flag_sp
       ELSE coalesce(product_name,CAST(rld_denom AS string),flag_sp) 
  END product_name, main_price, sp_price, main_price_acm2, channel, organization_id,
  CASE WHEN flag_sp LIKE 'SP Data%GB' THEN 'SPDATA'
       WHEN flag_sp LIKE 'SP IM3%GB' THEN 'SPDATA'
       WHEN act_type IS NULL AND rld_denom >= 10000 THEN 'RLD'
  ELSE act_type END product_type
  FROM `data-bi-prd-935c.bi_mart.rgu_ga_channel_mth_new_act2b`
  WHERE ga_dt >= dtid2 AND ga_dt < '2021-10-01'
  UNION ALL
  SELECT concat(msisdn, ga_dt) cust_id, flag_quality, flag_acm, inject_dt, flag_sp,
  CASE WHEN flag_sp LIKE 'SP Data%GB' THEN flag_sp
       WHEN flag_sp LIKE 'SP IM3%GB' THEN flag_sp
       ELSE coalesce(product_name,CAST(rld_denom AS string),flag_sp) 
  END product_name, main_price, sp_price, main_price_acm2, channel, organization_id,
  CASE WHEN flag_sp LIKE 'SP Data%GB' THEN 'SPDATA'
       WHEN flag_sp LIKE 'SP IM3%GB' THEN 'SPDATA'
       WHEN act_type IS NULL AND rld_denom >= 10000 THEN 'RLD'
  ELSE act_type END product_type
  FROM `data-bi-prd-935c.bi_mart.rgs_ga_channel_mth_govt`
  WHERE ga_dt >= '2021-10-01' AND ga_dt <= vdt_id
) b
ON concat(a.msisdn, a.ga_dt) = b.cust_id ; 

--- Insert
-- REFRESH `data-bi-prd-935c.bi_mart`.umr_rgs_srs_acq_25mb_govt ;

-- INSERT overwrite TABLE `data-bi-prd-935c.bi_mart.rgs_srs_acq_25mb_govt` partition(dt_id)
-- SELECT p.*, flag_status, vdt_id AS dt_id 
-- FROM `data-bi-prd-935c.bi_mart.rgs_srs_acq_govt_20241015` p
-- LEFT JOIN
-- ( SELECT a.msisdn,
--   CASE WHEN b.offer_id = 4444 THEN 'Active 1'
--        WHEN b.offer_id = 4443 THEN 'Unpair'
-- 	   ELSE 'Active 2' END flag_status 
--   FROM `data-bi-prd-935c.smy.ar_cst_dly_smy` a
--   LEFT JOIN 
--   ( SELECT msisdn, offer_id 
--     FROM 
--     ( SELECT concat('62',account_id) msisdn, offer_id,
--       row_number() over(PARTITION BY concat('62',account_id) ORDER BY CASE WHEN offer_id = 4443 THEN 1 ELSE 2 END) rk 
--       FROM `data-bi-prd-935c.bi_mart.stg_sdp_ofr`
--       WHERE offer_id in (4444,4443) AND dt_id =vdt_id
--     ) x 
--     WHERE rk = 1 AND length(msisdn) >= 10
--   ) b
--   ON a.msisdn = b.msisdn 
--   WHERE dt_id = vdt_id --AND lower(brand_sc_name) IN ('im3','mentari')
-- ) q
-- ON p.msisdn = q.msisdn ;

DELETE FROM `data-bi-prd-935c.bi_mart.rgs_srs_acq_25mb_govt`
WHERE dt_id = vdt_id;

INSERT INTO `data-bi-prd-935c.bi_mart.rgs_srs_acq_25mb_govt`
SELECT p.*, 
       flag_status, 
       vdt_id AS dt_id
FROM `data-bi-prd-935c.bi_mart.rgs_srs_acq_govt_{{ vdt_id }}_tmp2` p
LEFT JOIN
(
    SELECT a.msisdn,
           CASE 
               WHEN b.offer_id = 4444 THEN 'Active 1'
               WHEN b.offer_id = 4443 THEN 'Unpair'
               ELSE 'Active 2'
           END AS flag_status
    FROM `data-dtp-prd-aa1a.smy.ar_cst_dly_smy` a
    LEFT JOIN
    (
        SELECT msisdn, offer_id
        FROM
        (
            SELECT CONCAT('62', account_id) AS msisdn, 
                   offer_id,
                   ROW_NUMBER() OVER(PARTITION BY CONCAT('62', account_id) ORDER BY 
                                     CASE WHEN offer_id = 4443 THEN 1 ELSE 2 END NULLS Last) AS rk
            FROM `data-dtp-prd-aa1a.stg.stg_sdp_ofr`
            WHERE offer_id IN (4444, 4443) 
              AND date(dt_id) = vdt_id
        ) x
        WHERE rk = 1 
          AND LENGTH(msisdn) >= 10
    ) b
    ON a.msisdn = b.msisdn
    WHERE date(dt_id) = vdt_id
) q
ON p.msisdn = q.msisdn;

--- Drop Temp Table
DROP TABLE `data-bi-prd-935c.bi_mart.rgs_srs_acq_govt_{{ vdt_id }}_tmp1`;
DROP TABLE `data-bi-prd-935c.bi_mart.rgs_srs_acq_govt_{{ vdt_id }}_tmp2`;