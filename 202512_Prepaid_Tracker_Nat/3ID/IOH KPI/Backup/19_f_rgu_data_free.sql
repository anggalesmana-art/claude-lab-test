declare vdt_id date default @vdt_id;

----------RGS30 Days Zero Rated
drop table if exists `data-bi-prd-935c.bi_stg`.tmp_ales_cvmstg1daily;

create table `data-bi-prd-935c.bi_stg`.tmp_ales_cvmstg1daily as
		select a.sbscrptn_ek_id,b.sbscrptn_msisdn,b.product_id
		from `data-dtptechm-prd-c7ca.dwh`.rgs_subs_detail a left join `data-dtptechm-prd-c7ca.dwh`.sbscrptn_attribs b on a.sbscrptn_ek_id =b.sbscrptn_ek_id
		where 
        CAST(load_dt_sk_id AS DATE) = vdt_id
		--load_dt_sk_id between to_char(vdt_id::text::date-0,'yyyymmdd')::integer and vdt_idand 
		AND a.rgs_all_ex_sp and a.tool_of_trade_ind='N' 
		group by 1,2,3
; 

delete from `data-bi-prd-935c.bi_mart`.project_ioh_kpi_daily_tracker_national_wise
where CAST(load_dt_sk_id AS DATE) = vdt_id
and kpi_code in ('rgu_data_free','rgu_data_free_prepaid' , 'rgu_data_free_postpaid' );

INSERT INTO `data-bi-prd-935c.bi_mart`.project_ioh_kpi_daily_tracker_national_wise
SELECT cast(vdt_id as timestamp)
    , 'H3I' AS entity
    , CASE 
        WHEN product_id = 8 THEN 'rgu_data_free_prepaid' 
        ELSE 'rgu_data_free_postpaid' 
      END AS definition
    , 'IOH' AS definition
    , CAST(vdt_id AS DATE) AS v_date
    , COUNT(DISTINCT sbscrptn_ek_id) 
FROM (
    SELECT a.* 
    FROM (
        SELECT x.sbscrptn_ek_id, sbscrptn_msisdn, product_id 
        FROM `data-bi-prd-935c.bi_stg`.tmp_ales_cvmstg1daily x
    ) a
    LEFT JOIN `data-bi-prd-935c.bi_dm.project_ioh_dgpcr_flag` b 
        ON a.sbscrptn_msisdn = b.service_msisdn 
    WHERE b.service_msisdn IS NOT NULL
) z 
GROUP BY 1, 2, 3, 4, 5;

INSERT INTO `data-bi-prd-935c.bi_mart`.project_ioh_kpi_daily_tracker_national_wise
SELECT cast(vdt_id as timestamp)
    , 'H3I' AS entity
    , 'rgu_data_free' 
    , 'IOH' AS definition
    , CAST(vdt_id AS DATE) AS v_date
    , COUNT(DISTINCT sbscrptn_ek_id) 
FROM (
    SELECT a.* 
    FROM (
        SELECT x.sbscrptn_ek_id, sbscrptn_msisdn, product_id 
        FROM `data-bi-prd-935c.bi_stg`.tmp_ales_cvmstg1daily x
    ) a
    LEFT JOIN `data-bi-prd-935c.bi_dm.project_ioh_dgpcr_flag` b 
        ON a.sbscrptn_msisdn = b.service_msisdn 
    WHERE b.service_msisdn IS NOT NULL
) z 
GROUP BY 1, 2, 3, 4, 5;