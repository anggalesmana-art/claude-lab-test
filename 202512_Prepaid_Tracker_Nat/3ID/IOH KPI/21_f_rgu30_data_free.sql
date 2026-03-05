declare vdt_id date default @vdt_id;

----------RGS30 Days Zero Rated
drop table if exists `data-bi-prd-935c.bi_stg.tmp_ales_cvmstg1`; 

CREATE TABLE `data-bi-prd-935c.bi_stg.tmp_ales_cvmstg1` AS
with subs as (select * from `data-dtptechm-prd-c7ca.dwh.sbscrptn_attribs`)
SELECT 
a.sbscrptn_ek_id,
b.sbscrptn_msisdn,
b.product_id
FROM 
`data-dtptechm-prd-c7ca.dwh.rgs_subs_detail` a
LEFT JOIN 
subs b 
ON a.sbscrptn_ek_id = b.sbscrptn_ek_id 
WHERE 
cast(a.load_dt_sk_id as date) BETWEEN DATE_SUB(vdt_id, INTERVAL 29 DAY)
AND vdt_id
AND a.rgs_all_ex_sp
AND a.tool_of_trade_ind = 'N'
GROUP BY 
1, 2, 3;

delete from `data-bi-prd-935c.bi_mart.project_ioh_kpi_daily_tracker_national_wise`
where CAST(load_dt_sk_id AS DATE) =vdt_id
and kpi_code in ('rgu30_data_free','rgu30_data_free_prepaid' , 'rgu30_data_free_postpaid' ); 

INSERT INTO `data-bi-prd-935c.bi_mart.project_ioh_kpi_daily_tracker_national_wise`
SELECT 
CAST(vdt_id AS date),
'H3I' AS entity,
CASE 
WHEN product_id = 8 THEN 'rgu30_data_free_prepaid'
ELSE 'rgu30_data_free_postpaid'
END,
'IOH' AS definition,
CAST(vdt_id AS DATE) AS vdt_date,
COUNT(DISTINCT sbscrptn_ek_id)
FROM (
SELECT 
z.*
FROM (
SELECT 
a.sbscrptn_ek_id,
a.sbscrptn_msisdn,
a.product_id
FROM 
`data-bi-prd-935c.bi_stg.tmp_ales_cvmstg1` a
LEFT JOIN `data-bi-prd-935c.bi_mart.project_ioh_dgpcr_flag` b
ON a.sbscrptn_msisdn = b.service_msisdn
WHERE b.service_msisdn IS NOT NULL
) z
GROUP BY 1,2,3) 
group by 1,2,3,4,5;

INSERT INTO `data-bi-prd-935c.bi_mart.project_ioh_kpi_daily_tracker_national_wise`
SELECT 
CAST(vdt_id AS date),
'H3I' AS entity,
'rgu30_data_free' AS product_type,
'IOH' AS definition,
CAST(vdt_id AS DATE) AS vdt_date,
COUNT(DISTINCT sbscrptn_ek_id)
FROM (
SELECT 
z.*
FROM (
SELECT 
a.sbscrptn_ek_id,
a.sbscrptn_msisdn,
a.product_id
FROM `data-bi-prd-935c.bi_stg.tmp_ales_cvmstg1` a
LEFT JOIN `data-bi-prd-935c.bi_mart.project_ioh_dgpcr_flag` b
ON a.sbscrptn_msisdn = b.service_msisdn
WHERE b.service_msisdn IS NOT NULL
) z
GROUP BY 1,2,3
)GROUP BY 1,2,3,4,5;