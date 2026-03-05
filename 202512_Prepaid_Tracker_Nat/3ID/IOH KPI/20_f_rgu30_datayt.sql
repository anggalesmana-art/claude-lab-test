declare vdt_id date default @vdt_id;

delete from `data-bi-prd-935c.bi_mart`.project_ioh_kpi_daily_tracker_national_wise
where kpi_code in ('rgu30_data_fb','rgu30_data_yt')
and load_dt_sk_id=vdt_id ;

drop table if exists `data-bi-prd-935c.bi_stg.tmp_stg_yt`;

CREATE TABLE `data-bi-prd-935c.bi_stg.tmp_stg_yt` AS
SELECT sbscrptn_ek_id
FROM `data-dtptechm-prd-c7ca.dwh.gprs_dly_summary` a
WHERE 
  CAST(created_dt_sk_id AS DATE) BETWEEN DATE_SUB(vdt_id, INTERVAL 29 DAY) AND vdt_id
  AND gprs_rating_grp_nm IN ('3', '31', '54', '76', '81', '82')
  AND (uplink_vol + downlink_vol) > 0
GROUP BY sbscrptn_ek_id;

INSERT INTO `data-bi-prd-935c.bi_mart.project_ioh_kpi_daily_tracker_national_wise`
SELECT 
  cast(vdt_id as date),
  'H3I' AS entity,
  'rgu30_data_fb' AS definition,
  'IOH' AS definition_type,
  DATE(vdt_id) AS date,
  COUNT(DISTINCT a.sbscrptn_ek_id) AS distinct_count
FROM `data-bi-prd-935c.bi_stg.tmp_stg_yt` a
GROUP BY 1, 2, 3, 4, 5;

drop table if exists `data-bi-prd-935c.bi_stg.tmp_stg_yt`;

CREATE TABLE `data-bi-prd-935c.bi_stg.tmp_stg_yt` AS
SELECT sbscrptn_ek_id
FROM `data-dtptechm-prd-c7ca.dwh.gprs_dly_summary` a
WHERE CAST(created_dt_sk_id AS DATE) BETWEEN DATE_SUB(vdt_id, INTERVAL 29 DAY) AND vdt_id
AND a.gprs_rating_grp_nm IN ('5', '73', '75', '77', '81', '220', '221')
AND (uplink_vol + downlink_vol) > 0
GROUP BY 1;

INSERT INTO `data-bi-prd-935c.bi_mart.project_ioh_kpi_daily_tracker_national_wise`
SELECT 
    cast(vdt_id as date),
    'H3I' AS entity,
    'rgu30_data_yt' AS definition,
    'IOH' AS definition,
    CAST(vdt_id AS DATE),
    COUNT(DISTINCT a.sbscrptn_ek_id)
FROM `data-bi-prd-935c.bi_stg.tmp_stg_yt` a
GROUP BY 1, 2, 3, 4, 5;