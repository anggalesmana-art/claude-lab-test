declare vdt_id date default @vdt_id;

--- Temp GA & Srs IMEI
CREATE OR REPLACE TABLE `data-bi-prd-935c.bi_mart`.rgs_ga_imei_govt_{{ vdt_id }}_ga AS
SELECT a.msisdn, b.imei AS ga_imei
FROM `data-bi-prd-935c.bi_mart`.rgs_ga_90d_dly_govt a
JOIN 
( SELECT msisdn, date(dt_id) dt_id, max(imei) imei
  FROM `data-dtp-prd-aa1a.smy.ar_cst_dly_smy` 
  WHERE date(dt_id) BETWEEN date_trunc(vdt_id,month) AND vdt_id
    AND imei IS NOT NULL
	AND length(imei) >= 14
    AND imei NOT LIKE '%000000000000%'
  GROUP BY 1, 2
) b
ON a.msisdn = b.msisdn AND a.dt_id = b.dt_id
WHERE a.dt_id BETWEEN date_trunc(vdt_id,month) AND vdt_id 
  AND (churn_back = 'NO' OR recycled = 'YES') ;

CREATE OR REPLACE TABLE `data-bi-prd-935c.bi_mart`.rgs_ga_imei_govt_{{ vdt_id }}_srs AS
SELECT a.msisdn, a.srs_dt, b.imei AS srs_imei, flag_status
FROM `data-bi-prd-935c.bi_mart`.rgs_srs_acq_25mb_govt a
LEFT JOIN 
( SELECT msisdn, date(dt_id) dt_id, max(imei) imei
  FROM `data-dtp-prd-aa1a.smy.ar_cst_dly_smy` 
  WHERE date(dt_id) BETWEEN date_trunc(vdt_id,month) AND vdt_id
    AND imei IS NOT NULL
	AND length(imei) >= 14
    AND imei NOT LIKE '%000000000000%' 
  GROUP BY 1, 2
) b
ON a.msisdn = b.msisdn AND a.srs_dt = b.dt_id
WHERE a.dt_id = vdt_id 
  AND date_trunc(a.ga_dt,month) = date_trunc(a.dt_id,month) ;

--- Insert
delete from `data-bi-prd-935c.bi_mart`.rgs_ga_imei_govt where dt_id = vdt_id;
insert into `data-bi-prd-935c.bi_mart`.rgs_ga_imei_govt
SELECT a.msisdn, a.dt_id AS ga_dt, ga_imei, srs_dt, srs_imei,
d.imei AS mtd_imei, flag_status, timestamp(current_datetime('+7')) AS ppn_dttm, vdt_id AS dt_id 
FROM `data-bi-prd-935c.bi_mart`.rgs_ga_90d_dly_govt a
LEFT JOIN `data-bi-prd-935c.bi_mart`.rgs_ga_imei_govt_{{ vdt_id }}_ga b 
ON a.msisdn = b.msisdn 
LEFT JOIN `data-bi-prd-935c.bi_mart`.rgs_ga_imei_govt_{{ vdt_id }}_srs c
ON a.msisdn = c.msisdn 
LEFT JOIN 
( SELECT msisdn, max(imei) imei
  FROM `data-dtp-prd-aa1a.smy.ar_cst_dly_smy` 
  WHERE date(dt_id) = vdt_id
    AND imei IS NOT NULL
	AND length(imei) >= 14
    AND imei NOT LIKE '%000000000000%'
  GROUP BY 1
) d
ON a.msisdn = d.msisdn
WHERE a.dt_id BETWEEN date_trunc(vdt_id,month) AND vdt_id 
  AND (churn_back = 'NO' OR recycled = 'YES') ;

--- Drop Temp Table
DROP TABLE `data-bi-prd-935c.bi_mart`.rgs_ga_imei_govt_{{ vdt_id }}_ga;
DROP TABLE `data-bi-prd-935c.bi_mart`.rgs_ga_imei_govt_{{ vdt_id }}_srs ;