declare vdt_id date default @vdt_id;

--- Temp

CREATE OR REPLACE TABLE `data-bi-prd-935c.bi_stg`.all_imei_{{ vdt_id }}_tmp1 AS
SELECT imei, min(dt_min) dt_min, max(dt_max) dt_max, sum(subs) subs
FROM `data-bi-prd-935c.bi_mart`.all_imei_prepaid_mly
WHERE mth_id between date_trunc(vdt_id - interval 5 month,month) and date_trunc(vdt_id,month)
GROUP BY imei ;

CREATE OR REPLACE TABLE `data-bi-prd-935c.bi_stg`.all_imei_{{ vdt_id }}_tmp2 AS
SELECT imei, min(dt_min) dt_min, max(dt_max) dt_max, sum(subs) subs
FROM `data-bi-prd-935c.bi_mart`.all_imei_postpaid_mly
WHERE mth_id between date_trunc(vdt_id - interval 5 month,month) and date_trunc(vdt_id,month)
GROUP BY imei ;

--- Insert
delete from `data-bi-prd-935c.bi_mart`.all_imei_last_6_mth  where mth_id = date_trunc(vdt_id,month);
insert into `data-bi-prd-935c.bi_mart`.all_imei_last_6_mth 
SELECT imei,dt_min,dt_max,subs,timestamp(current_datetime('+7')) ppn_dttm,'prepaid' flag, date_trunc(vdt_id,month) mth_id
FROM `data-bi-prd-935c.bi_stg`.all_imei_{{ vdt_id }}_tmp1
UNION ALL
SELECT imei,dt_min,dt_max,subs,timestamp(current_datetime('+7')) ppn_dttm, 'postpaid' flag, date_trunc(vdt_id,month) mth_id
FROM `data-bi-prd-935c.bi_stg`.all_imei_{{ vdt_id }}_tmp2 ;



--- Drop Table
DROP TABLE `data-bi-prd-935c.bi_stg`.all_imei_{{ vdt_id }}_tmp1;
DROP TABLE `data-bi-prd-935c.bi_stg`.all_imei_{{ vdt_id }}_tmp2;

