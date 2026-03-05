declare vdt_id date default @vdt_id;
--- IMEI Prepaid
CREATE OR REPLACE TABLE `data-bi-prd-935c.bi_mart`.all_imei_{{ vdt_id }}_pre AS
SELECT imei, min(date(dt_id)) dt_min, max(date(dt_id)) dt_max, count(distinct msisdn) subs
FROM `data-dtp-prd-aa1a.smy`.ar_cst_dly_smy
WHERE date(dt_id) between date_trunc(vdt_id,month) and vdt_id
  AND imei IS NOT NULL
--  AND lower(brand_sc_name) IN ( 'im3', 'mentari' )
GROUP BY imei ;

--- IMEI Postpaid
CREATE OR REPLACE TABLE `data-bi-prd-935c.bi_mart`.all_imei_{{ vdt_id }}_post AS
SELECT imei, min(date(dt_id)) dt_min, max(date(dt_id)) dt_max, count(distinct msisdn) subs
FROM `data-dtp-prd-aa1a.smy`.ar_cst_pstpaid_rtl
WHERE date(dt_id) between date_trunc(vdt_id,month) and vdt_id
  AND imei IS NOT NULL
GROUP BY imei ;

--- Insert
delete from `data-bi-prd-935c.bi_mart`.all_imei_prepaid_mly where mth_id = date_trunc(vdt_id,month);
INSERT into `data-bi-prd-935c.bi_mart`.all_imei_prepaid_mly
SELECT imei, dt_min, dt_max, subs,
timestamp(current_datetime('+7')) AS ppn_dttm, date_trunc(vdt_id,month) AS mth_id 
FROM `data-bi-prd-935c.bi_mart`.all_imei_{{ vdt_id }}_pre ;

delete from `data-bi-prd-935c.bi_mart`.all_imei_postpaid_mly where mth_id = date_trunc(vdt_id,month);
INSERT into `data-bi-prd-935c.bi_mart`.all_imei_postpaid_mly
SELECT imei, dt_min, dt_max, subs,
timestamp(current_datetime('+7')) AS ppn_dttm, date_trunc(vdt_id,month) AS mth_id 
FROM `data-bi-prd-935c.bi_mart`.all_imei_{{ vdt_id }}_post ;

DROP TABLE `data-bi-prd-935c.bi_mart`.all_imei_{{ vdt_id }}_post;
DROP TABLE `data-bi-prd-935c.bi_mart`.all_imei_{{ vdt_id }}_pre