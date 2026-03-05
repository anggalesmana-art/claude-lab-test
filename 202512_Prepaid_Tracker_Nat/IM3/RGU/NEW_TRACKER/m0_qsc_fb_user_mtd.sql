declare vdt_id date default @vdt_id;

--- Temp MTD
CREATE OR REPLACE TABLE `data-bi-prd-935c.bi_stg`.rgs_m0_qsc_{{ vdt_id }} AS
SELECT mtd_site site_id, channel_grp, count(1) subs
FROM `data-bi-prd-935c.bi_mart`.rgs_srs_acq_25mb_govt a
LEFT JOIN `data-bi-prd-935c.bi_mart`.rgs_ga_channel_mth_govt b
ON a.msisdn = b.msisdn AND b.month_id = date_trunc(vdt_id,month)
WHERE a.dt_id = vdt_id
  AND date_trunc(a.ga_dt,month) = date_trunc(a.dt_id,month)
  AND flag_status = 'Active 2'
GROUP BY 1, 2 ;

CREATE OR REPLACE TABLE `data-bi-prd-935c.bi_stg`.rgs_m0_fb_{{ vdt_id }} AS	
SELECT site_id, channel_grp, 
sum(CASE WHEN a.msisdn = c.msisdn THEN 1 ELSE 0 END) subs
FROM `data-bi-prd-935c.bi_mart`.rgs_ga_90d_dly_govt a
LEFT JOIN `data-bi-prd-935c.bi_mart`.rgs_ga_channel_mth_govt b  
ON a.msisdn = b.msisdn AND b.month_id = date_trunc(vdt_id,month)
LEFT JOIN `data-bi-prd-935c.bi_mart`.niofb_mtd c
ON a.msisdn = c.msisdn AND c.dt_id = vdt_id
WHERE a.dt_id BETWEEN date_trunc(vdt_id,month) AND vdt_id
  AND (churn_back = 'NO' or recycled = 'YES')
GROUP BY 1, 2 ;

--- Insert
delete from `data-bi-prd-935c.bi_mart`.rgs_m0_qsc_fb_user_mtd_smy where dt_id = vdt_id;
INSERT into `data-bi-prd-935c.bi_mart`.rgs_m0_qsc_fb_user_mtd_smy 
SELECT 'M0 QSC' kpi, site_id, channel_grp, subs,
timestamp(current_datetime('+7')) ppn_dttm, vdt_id dt_id FROM `data-bi-prd-935c.bi_stg`.rgs_m0_qsc_{{ vdt_id }}
UNION ALL
SELECT 'M0 FB User' kpi, site_id, channel_grp, subs,
timestamp(current_datetime('+7')) ppn_dttm, vdt_id dt_id FROM `data-bi-prd-935c.bi_stg`.rgs_m0_fb_{{ vdt_id }}
;
--INVALIDATE METADATA `data-bi-prd-935c.bi_mart`.rgs_m0_qsc_fb_user_mtd_smy ;

--- Drop Temp
DROP TABLE `data-bi-prd-935c.bi_stg`.rgs_m0_qsc_{{ vdt_id }} ;
DROP TABLE `data-bi-prd-935c.bi_stg`.rgs_m0_fb_{{ vdt_id }} ;
