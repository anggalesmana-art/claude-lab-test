declare vdt_id date default @vdt_id;
--- Temp MTD
CREATE OR REPLACE TABLE `data-bi-prd-935c.bi_mart`.rgs_m1s_{{ vdt_id }} AS
SELECT site_id, channel_grp,
sum(CASE WHEN a.msisdn = c.msisdn THEN 1 ELSE 0 END) subs
FROM `data-bi-prd-935c.bi_mart`.rgs_ga_90d_dly_govt a
LEFT JOIN `data-bi-prd-935c.bi_mart`.rgs_ga_channel_mth_govt b  
ON a.msisdn = b.msisdn AND b.month_id = date_trunc(vdt_id-interval 1 month,month) -- M-1
LEFT JOIN `data-bi-prd-935c.bi_mart`.rgs_mtd_govt c
on a.msisdn = c.msisdn AND c.dt_id = vdt_id
WHERE a.dt_id between date_trunc(vdt_id-interval 1 month,month) and date(date_trunc(vdt_id,month) - interval 1 day)-- M-1
  AND (churn_back = 'NO' or recycled = 'YES')
GROUP BY 1, 2 ;

CREATE OR REPLACE TABLE `data-bi-prd-935c.bi_mart`.rgs_m2s_{{ vdt_id }} AS
SELECT site_id, channel_grp,
sum(CASE WHEN a.msisdn = c.msisdn THEN 1 ELSE 0 END) subs
FROM `data-bi-prd-935c.bi_mart`.rgs_ga_90d_dly_govt a
LEFT JOIN `data-bi-prd-935c.bi_mart`.rgs_ga_channel_mth_govt b  
ON a.msisdn = b.msisdn AND b.month_id = date_trunc(vdt_id-interval 2 month,month) -- M-2
LEFT JOIN `data-bi-prd-935c.bi_mart`.rgs_mtd_govt c
on a.msisdn = c.msisdn AND c.dt_id = vdt_id
WHERE a.dt_id between date_trunc(vdt_id-interval 2 month,month) and date(date_trunc(vdt_id-interval 1 month,month) - interval 1 day)  -- M-2
  AND (churn_back = 'NO' or recycled = 'YES')
GROUP BY 1, 2 ;

CREATE OR REPLACE TABLE `data-bi-prd-935c.bi_mart`.rgs_rc_{{ vdt_id }} AS
SELECT b.site_id,
CASE WHEN ifnull(a.mtd_imei,'') = '' THEN '3.No IMEI'
     WHEN a.mtd_imei like '%000000000000%' THEN '3.No IMEI'
--   WHEN a.mtd_imei = d.imei THEN '2.Old IMEI'
     WHEN substr(a.mtd_imei,1,14) = d.imei THEN '2.Old IMEI'
ELSE '1.New IMEI' END channel_grp, count(1) subs
FROM `data-bi-prd-935c.bi_mart`.rgs_ga_imei_govt a
/*( SELECT msisdn, dt_id,
  COALESCE(mtd_imei,srs_imei,ga_imei) mtd_imei
  FROM `data-bi-prd-935c.bi_mart`.rgs_ga_imei_govt
) a*/
LEFT JOIN `data-bi-prd-935c.bi_mart`.rgs_ga_90d_dly_govt b  
ON a.msisdn = b.msisdn 
AND b.dt_id BETWEEN date_trunc(vdt_id,month) AND vdt_id
LEFT JOIN 
( SELECT DISTINCT substr(imei,1,14) imei
  FROM `data-bi-prd-935c.bi_mart`.all_imei_last_6_mth
  WHERE mth_id = date_trunc(vdt_id-interval 1 month,month) -- M-1
    AND lower(flag) = 'prepaid'
) d
ON substr(a.mtd_imei,1,14) = d.imei
WHERE a.dt_id = vdt_id
GROUP BY 1, 2 ;

--- Insert
DELETE FROM `data-bi-prd-935c.bi_mart`.rgs_m1s_m2s_mtd_smy where dt_id = vdt_id;
INSERT INTO `data-bi-prd-935c.bi_mart`.rgs_m1s_m2s_mtd_smy 
SELECT 'M1S' kpi, site_id, channel_grp, subs,
timestamp(current_datetime('+7')) ppn_dttm, vdt_id dt_id FROM `data-bi-prd-935c.bi_mart`.rgs_m1s_{{ vdt_id }}
UNION ALL
SELECT 'M2S' kpi, site_id, channel_grp, subs,
timestamp(current_datetime('+7')) ppn_dttm, vdt_id dt_id FROM `data-bi-prd-935c.bi_mart`.rgs_m2s_{{ vdt_id }}
UNION ALL
SELECT 'Rot Churn' kpi, site_id, channel_grp, subs,
timestamp(current_datetime('+7')) ppn_dttm, vdt_id dt_id FROM `data-bi-prd-935c.bi_mart`.rgs_rc_{{ vdt_id }}
;

--- Drop Temp
DROP TABLE `data-bi-prd-935c.bi_mart`.rgs_m1s_{{ vdt_id }} ;
DROP TABLE `data-bi-prd-935c.bi_mart`.rgs_m2s_{{ vdt_id }} ;
DROP TABLE `data-bi-prd-935c.bi_mart`.rgs_rc_{{ vdt_id }} ;
