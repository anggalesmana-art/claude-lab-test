declare vdt_id date default @vdt_id;

delete from `data-bi-prd-935c.bi_mart`.project_ioh_kpi_daily_tracker_national_wise where CAST(load_dt_sk_id AS DATE) = vdt_id and definition = 'IOH' 
 and kpi_code in ('rgu30_data', 'rgu30_data_5g', 'rgu30_data_4g', 'rgu30_data_3g', 'rgu30_data_2g','rgu30_data_unknown', 'rgu30_data_prepaid', 'rgu30_data_postpaid', 'rgu30_data_25mb', 'rgu30_data_payu', 'rgu30_data_pack');
 
drop table if exists `data-bi-prd-935c.bi_stg`.RGS_data30;

CREATE TABLE `data-bi-prd-935c.bi_stg`.RGS_data30
AS
SELECT 
sbscrptn_ek_id, 
vdt_id AS load_dt_sk_id
FROM `data-dtptechm-prd-c7ca.dwh`.rgs_subs_detail a
WHERE CAST(a.load_dt_sk_id AS DATE) <= vdt_id
AND CAST(a.load_dt_sk_id AS DATE) >= DATE_SUB(CAST(vdt_id AS DATE), INTERVAL 29 DAY)
AND (a.rgs_datapackage_ex_sp OR a.rgs_gprs_ex_sp OR a.rgs_blackberry_ex_sp)
AND a.tool_of_trade_ind = 'N'
AND a.product_id = 8
GROUP BY sbscrptn_ek_id;

INSERT INTO `data-bi-prd-935c.bi_mart`.project_ioh_kpi_daily_tracker_national_wise
WITH tmp_mst AS 
(
SELECT 
CASE 
WHEN LTE_Usage > 0 THEN '4g'
WHEN Usage_3g > 0 THEN '3g'
WHEN Usage_2g > 0 THEN '2g'
ELSE 'unknown'
END AS tec, 
CASE 
WHEN product_id = 8 THEN 'prepaid' 
ELSE 'postpaid' 
END AS pre_pos,
USAGE_PYU,
USAGE_package,
usage,
a.sbscrptn_ek_id
FROM `data-bi-prd-935c.bi_stg`.RGS_data30 a
LEFT JOIN `data-bi-prd-935c.bi_stg`.tmp_usage_data30 b
ON a.sbscrptn_ek_id = b.sbscrptn_ek_id
LEFT JOIN `data-dtptechm-prd-c7ca.dwh`.sbscrptn_attribs att 
ON a.sbscrptn_ek_id = att.sbscrptn_ek_id 
--JOIN mis.project_ioh_dgpcr_flag c ON att.sbscrptn_msisdn = c.service_msisdn
GROUP BY 1,2,3,4,5,6
)
SELECT 
cast(vdt_id as timestamp) AS load_dt_sk_id, 
'H3I' AS entity, 
CONCAT('rgu30_data_', tec) AS definition, 
'IOH' AS source, 
CAST(vdt_id AS date) AS  v_date, 
COUNT(1) AS count_1
FROM tmp_mst
GROUP BY 1,2,3,4,5

UNION ALL

SELECT 
cast(vdt_id as timestamp) AS load_dt_sk_id, 
'H3I' AS entity, 
CONCAT('rgu30_data_', pre_pos) AS definition, 
'IOH' AS source, 
CAST(vdt_id AS date) AS v_date, 
COUNT(1) AS count_1
FROM tmp_mst
GROUP BY 1,2,3,4,5

UNION ALL

SELECT 
cast(vdt_id as timestamp) AS load_dt_sk_id, 
'H3I' AS entity, 
'rgu30_data_payu' AS definition, 
'IOH' AS source, 
CAST(vdt_id AS date) AS v_date, 
COUNT(1) AS count_1
FROM tmp_mst
WHERE USAGE_PYU > 0
GROUP BY 1,2,3,4,5

UNION ALL

SELECT 
cast(vdt_id as timestamp) AS load_dt_sk_id, 
'H3I' AS entity, 
'rgu30_data_pack' AS definition, 
'IOH' AS source, 
CAST(vdt_id AS date) AS v_date, 
COUNT(1) AS count_1
FROM tmp_mst
WHERE USAGE_package > 0
GROUP BY 1,2,3,4,5

UNION ALL

SELECT 
cast(vdt_id as timestamp) AS load_dt_sk_id, 
'H3I' AS entity, 
'rgu30_data_25mb' AS definition, 
'IOH' AS source, 
CAST(vdt_id AS date) AS v_date, 
COUNT(1) AS count_1
FROM tmp_mst
WHERE usage / POWER(1024, 2) >= 25
GROUP BY 1,2,3,4,5;

insert into `data-bi-prd-935c.bi_mart`.project_ioh_kpi_daily_tracker_national_wise
select load_dt_sk_id, entity, 'rgu30_data',definition, date, sum(value) 
from `data-bi-prd-935c.bi_mart`.project_ioh_kpi_daily_tracker_national_wise
where CAST(load_dt_sk_id AS DATE) = vdt_id 
and kpi_code in ('rgu30_data_prepaid','rgu30_data_postpaid')
and entity = 'H3I'
and definition = 'IOH'
group by 1,2,3,4,5;