declare vdt_id date default @vdt_id;



create or replace table 
`data-bi-prd-935c.bi_stg`.tmp_ref_region_circle as 
select * 
								from	(
											select circle, region_circle, site_id, gladiator_branch, gladiator_branch_id, kabupaten, kecamatan, cnt, row_number() over (partition by site_id order by cnt desc) rnk 
											from	(
														select circle, region_circle, site_id, gladiator_branch, gladiator_branch_id, kabkot_nm kabupaten, kecamatan_nm kecamatan, count(*) cnt						
														from `data-bi-prd-935c.bi_mart`.ref_site_h3i_mth
														where mth_id = date_trunc(vdt_id,month)
														group by 1,2,3,4,5,6,7
													) x
										) y 
								where rnk = 1  ;											

create or replace table 
`data-bi-prd-935c.bi_stg`.tmp_ref_branch_circle as 
	
							select distinct circle,site_id, gladiator_branch, gladiator_branch_id, kabupaten, kecamatan, cnt, rnk
							from `data-bi-prd-935c.bi_stg`.tmp_ref_region_circle;											
			


create or replace table 
`data-bi-prd-935c.bi_stg`.tmp_angie as 

							select * 
							from `data-bi-prd-935c.bi_mart`.angie_hrchy_dim_hst b
							where mth = date_trunc(vdt_id,month);





--- 'trade_supply', 'dsas','m1s_mtd','ga_m1s_mtd' 

-- ========== SURV_M2 and GA_M2 KPIs ==========

 

DELETE FROM `data-bi-prd-935c.bi_dev`.ioh_snd_master_kpi_detail
WHERE brand = '3ID' and lower(kpi) IN ( 'dsas','m1s_mtd','ga_m1s_mtd','organic_rev') AND dt_id = vdt_id;

INSERT INTO `data-bi-prd-935c.bi_dev`.ioh_snd_master_kpi_detail   
    SELECT '3ID' as brand,
    'site_id' level,
    site_id level_value,
    cast(sum(value) as numeric),
    'mtd' time_flag,
    timestamp(current_datetime('+7')) insert_date,
    CASE WHEN kpi_code = 'M1S_MTD' THEN 'm1s_mtd' ELSE lower(kpi_code) END kpi,
    load_dt_sk_id dt_id 
    FROM `data-bi-prd-935c.bi_mart`.project_ioh_kpi_daily_tracker_site -- select * From project_ioh_kpi_daily_tracker_site limit 10 
    WHERE load_dt_sk_id = vdt_id
      AND kpi_code   IN ( 'dsas','M1S_MTD','GA_M1S_MTD','organic_rev') 
    GROUP BY 1,2,3,5,7,8;



DELETE FROM `data-bi-prd-935c.bi_dev`.ioh_snd_master_kpi_detail
    WHERE kpi in 
    (
'uro'
-- 'secondary_150k_outletcnt', Not Used Anymore
-- 'secondary_200k_outletcnt'
) 
AND dt_id = vdt_id AND level = 'site_id' AND time_flag = 'mtd';
    -- 
    INSERT INTO `data-bi-prd-935c.bi_dev`.ioh_snd_master_kpi_detail
    SELECT '3ID',
    'site_id',
    case when length(site_id)<6 then lpad(site_id,6,'0') else site_id end as site_id,
   cast(count(distinct dtl.partner_qr_cd) as numeric),
    'mtd',
    timestamp(current_datetime('+7')),
    'uro' kpi ,
    trx_dt_sk_id dt_id 
			from `data-bi-prd-935c.bi_mart.ret_uro_quro_indicator_dly` dtl
			left join `data-dtptechm-prd-c7ca.stg.stg_v_map_tgt_ret_details` ret_map on ret_map.ret_qr_cd = dtl.partner_qr_cd
			left join `data-dtptechm-prd-c7ca.dwh.angie_hrchy_dim` hd on hd.partner_qr_cd = dtl.partner_qr_cd and hd.partner_status in ('Active','Suspended') and hd.ret_hierarchy_type = 'ANGIE' and hd.hrchy_type = 'Retailer'
			where trx_dt_sk_id = vdt_id
			and ret_uro_ind='Y' group by 1,2,3,5,6,7,8;

--   in      (
-- 'uro',
-- 'secondary_150k_outletcnt',
-- 'secondary_200k_outletcnt'
-- ) 
--     GROUP BY 1,2,3,5,6,7,8;

DELETE FROM `data-bi-prd-935c.bi_dev`.ioh_snd_master_kpi_detail
WHERE brand = '3ID' and lower(kpi) IN ('site_30_rguga_trad') AND dt_id = vdt_id;
 
INSERT INTO `data-bi-prd-935c.bi_dev`.ioh_snd_master_kpi_detail
    SELECT '3ID',
    'site_id',
    level_value,
    count(distinct level_value),
    'mtd',
    timestamp(current_datetime('+7')),
    'site_30_rguga_trad' ,
    dt_id 
    FROM `data-bi-prd-935c.bi_dev`.ioh_snd_master_kpi_detail a 
inner join	
	(
	select distinct parse_date('%Y%m',cast(mth as string)) mth, 
	coalesce(site_id, site_id_old) new_site_id, 
	addressable_type
	from `data-bi-prd-935c.bi_snd.pre_ref_nshim3_addrsite_gtm_mth` asg 
	where parse_date('%Y%m',cast(mth as string)) = date_trunc(vdt_id,month) and list_3id = 'Y'
	and addressable_type = 'ADDRESSABLE SITE'
)b 										
on b.new_site_id = a.level_value			
where values >= 30
     and dt_id = vdt_id AND kpi ='RGUGA_Trade' 
and level='site_id' and time_flag='mtd' and brand = '3ID'
GROUP BY 1,2,3,5,6,7,8;


DELETE FROM `data-bi-prd-935c.bi_dev`.ioh_snd_master_kpi_detail
WHERE brand = '3ID' and lower(kpi) IN ('site_30_rguga') AND dt_id = vdt_id;

INSERT INTO `data-bi-prd-935c.bi_dev`.ioh_snd_master_kpi_detail
    SELECT '3ID',
    'site_id',
    level_value,
    count(distinct level_value),
    'mtd',
    timestamp(current_datetime('+7')),
    'site_30_rguga' ,
    dt_id 
    FROM `data-bi-prd-935c.bi_dev`.ioh_snd_master_kpi_detail a 
inner join	
	(
	select distinct parse_date('%Y%m',cast(mth as string)) mth, 
	coalesce(site_id, site_id_old) new_site_id, 
	addressable_type
	from `data-bi-prd-935c.bi_snd.pre_ref_nshim3_addrsite_gtm_mth` asg 
	where parse_date('%Y%m',cast(mth as string)) = date_trunc(vdt_id,month) and list_3id = 'Y'
	and addressable_type = 'ADDRESSABLE SITE'
)b 										
on b.new_site_id = a.level_value			
where values >= 30
     and dt_id = vdt_id AND kpi ='rgu_ga'  and brand = '3ID'
and level='site_id' and time_flag='mtd'    GROUP BY 1,2,3,5,6,7,8;


--Waiting marketing.bai_3id_ritaapp_rev from Mas Arenzy
-- DELETE FROM `data-bi-prd-935c.bi_dev`.ioh_snd_master_kpi_detail
-- WHERE brand = '3ID' and lower(kpi) IN (
-- 'rita_rev'
-- ) 
--  AND dt_id = vdt_id;


-- INSERT INTO `data-bi-prd-935c.bi_dev`.ioh_snd_master_kpi_detail 
-- SELECT
--     '3ID' AS brand_id,
--     'site_id' AS level_id,
--     coalesce(a.site_id_bnum, 'null') AS level_value,
--     sum(a.revenue) / 1.11 AS kpi_value,
--     'mtd' AS period_type,
--     timestamp(current_datetime('+7')) AS uVDate_dttm,
--     'rita_rev' AS kpi_name,
--     vdt_id AS dt_id
-- FROM marketing.bai_3id_ritaapp_rev a
-- WHERE
--     a.trx_dt_sk_id BETWEEN date_trunc( vdt_id,month) AND vdt_id
-- GROUP BY 
--     dt_id,
--     coalesce(a.site_id_bnum, 'null');




create or replace table 
`data-bi-prd-935c.bi_stg`.tmp_nbs		as
						
					        select ret_qr_cd,site_id 
					        from
					            (
					                select dt,ret_qr_cd,site_id,row_number() over (partition by ret_qr_cd order by dt desc) rnk
					                from `data-bi-prd-935c.bi_mart`.stg_v_map_tgt_ret_details_hist
					                where  site_id <> ''
					                and date_trunc(dt,month) = date_trunc(vdt_id,month)
					            ) x 
					        where rnk=1;


DELETE FROM `data-bi-prd-935c.bi_dev`.ioh_snd_master_kpi_detail
WHERE brand = '3ID' and lower(kpi) IN (
'outlet_productivity'
) 
 AND dt_id = vdt_id;

INSERT INTO `data-bi-prd-935c.bi_dev`.ioh_snd_master_kpi_detail 
-- This CTE first calculates the monthly total 'SALDO' revenue for each outlet
-- and joins it with the site information.
WITH outlet_monthly_revenue AS (
    SELECT
        vdt_id AS xdt_id,
        nbs.site_id,
        a.partner_qr_cd,
        SUM(coalesce(a.value, 0)) AS total_monthly_revenue
    FROM `data-bi-prd-935c.bi_mart`.project_ioh_secondary_outlet a
    INNER JOIN (
        SELECT DISTINCT retailer_qrcode, parse_date('%Y%m%d',concat(cast(mth_id as string),'01')) mth_id
        FROM `data-bi-prd-935c.bi_snd.pre_ref_outlet_mapping_3id`
        WHERE parse_date('%Y%m%d',concat(cast(mth_id as string),'01')) = date_trunc(vdt_id,month)
    ) b ON b.retailer_qrcode = a.partner_qr_cd
    LEFT JOIN `data-bi-prd-935c.bi_stg`.tmp_nbs nbs ON a.partner_qr_cd = nbs.ret_qr_cd
    WHERE
        a.dt_sk_id between date_trunc(vdt_id,month) AND vdt_id
        AND a.secondary_category = 'SALDO'
        AND a.hierarchy_type = 'ANGIE'
        AND a.secondary_type IN ('Purchase from CAN')
    GROUP BY
       xdt_id,
        nbs.site_id,
        a.partner_qr_cd
)
-- The final SELECT counts the number of productive outlets (revenue >= 200,000)
-- for each site.
SELECT
    '3ID' AS brand_id,
    'site_id' AS level_id,
    coalesce(site_id, 'null') AS level_value,
    COUNT(DISTINCT partner_qr_cd) AS kpi_value,
    'mtd' AS period_type,
    timestamp(current_datetime('+7')) AS uVDate_dttm,
    'outlet_productivity' AS kpi_name,
    xdt_id AS dt_id
FROM outlet_monthly_revenue
WHERE total_monthly_revenue >= 200000
GROUP BY
    xdt_id,
    coalesce(site_id, 'null');



DELETE FROM `data-bi-prd-935c.bi_dev`.ioh_snd_master_kpi_detail
WHERE brand = '3ID' and lower(kpi) IN (
'q_uro'
) 
 AND dt_id = vdt_id;


 

INSERT INTO `data-bi-prd-935c.bi_dev`.ioh_snd_master_kpi_detail 
with q_uro_main as (
    select trx_dt_sk_id dt_id,partner_qr_cd ret_qrcode,'q_uro' kpi_name,count(distinct partner_qr_cd) kpi_value
    from `data-bi-prd-935c.bi_mart.ret_uro_quro_indicator_dly`
    where trx_dt_sk_id=vdt_id
    and ret_quro_ind='Y'
group by 1,2,3
)
SELECT
    '3ID' AS brand_id,
    'site_id' AS level_id,
    coalesce(c.site_id, 'null') AS level_value,
    cast(SUM(a.kpi_value) as numeric) AS kpi_value,
    'daily' AS period_type,
    timestamp(current_datetime('+7')) AS uVDate_dttm,
    'q_uro' AS kpi_name,
    vdt_id AS dt_id
FROM q_uro_main a
INNER JOIN (
    SELECT DISTINCT retailer_qrcode, parse_date('%Y%m%d',concat(cast(mth_id as string),'01')) mth_id
    FROM `data-bi-prd-935c.bi_snd.pre_ref_outlet_mapping_3id`
    WHERE parse_date('%Y%m%d',concat(cast(mth_id as string),'01')) = date_trunc(vdt_id,month)
) b ON b.retailer_qrcode = a.ret_qrcode
LEFT JOIN `data-bi-prd-935c.bi_stg`.tmp_nbs c
    ON a.ret_qrcode = c.ret_qr_cd
WHERE
    trim(lower(a.kpi_name)) = 'q_uro'
    AND a.dt_id = vdt_id
GROUP BY
    a.dt_id,
    coalesce(c.site_id, 'null');



DELETE FROM `data-bi-prd-935c.bi_dev`.ioh_snd_master_kpi_detail
WHERE brand = '3ID' and lower(kpi) IN (
'site_5quro'
) 
 AND dt_id = vdt_id;



INSERT INTO `data-bi-prd-935c.bi_dev`.ioh_snd_master_kpi_detail 
-- This CTE first calculates the monthly Q_URO for each outlet and gets the corresponding site_id
WITH monthly_q_uro_per_site AS (
    SELECT
        a.dt_id,
        c.site_id,
        SUM(a.kpi_value) AS total_q_uro
    FROM 
    (
        select trx_dt_sk_id dt_id,partner_qr_cd ret_qrcode,'q_uro' kpi_name,count(distinct partner_qr_cd) kpi_value
    from `data-bi-prd-935c.bi_mart.ret_uro_quro_indicator_dly`
    where trx_dt_sk_id=vdt_id
    and ret_quro_ind='Y'
    group by 1,2,3
    ) a
    INNER JOIN (
        SELECT DISTINCT retailer_qrcode, parse_date('%Y%m%d',concat(cast(mth_id as string),'01')) mth_id
        FROM `data-bi-prd-935c.bi_snd.pre_ref_outlet_mapping_3id`
        WHERE parse_date('%Y%m%d',concat(cast(mth_id as string),'01')) = date_trunc(vdt_id,month)
    ) b ON b.retailer_qrcode = a.ret_qrcode
    LEFT JOIN `data-bi-prd-935c.bi_stg`.tmp_nbs c ON a.ret_qrcode = c.ret_qr_cd
    WHERE
        trim(lower(a.kpi_name)) = 'q_uro'
        AND a.dt_id  = vdt_id
    GROUP BY
        a.dt_id,
        c.site_id
),
-- This CTE gets the list of all "addressable sites" for the month
addressable_sites AS (
    SELECT DISTINCT
        coalesce(site_id, site_id_old) AS new_site_id
    FROM `data-bi-prd-935c.bi_snd.pre_ref_nshim3_addrsite_gtm_mth`
    WHERE
        parse_date('%Y%m',cast(mth as string)) = date_trunc(vdt_id,month) and list_3id = 'Y'
        AND addressable_type = 'ADDRESSABLE SITE'
)
-- The final SELECT inserts a row for each site that is addressable and has >= 5 Q_URO
SELECT DISTINCT
    '3ID' AS brand_id,
    'site_id' AS level_id,
    coalesce(q_uro.site_id, 'null') AS level_value,
    1 AS kpi_value,
    'mtd' AS period_type,
    timestamp(current_datetime('+7')) AS uVDate_dttm,
    'site_5quro' AS kpi_name,
    q_uro.dt_id AS dt_id
FROM monthly_q_uro_per_site q_uro
INNER JOIN addressable_sites ads ON ads.new_site_id = q_uro.site_id
WHERE q_uro.total_q_uro >= 5;



DELETE FROM `data-bi-prd-935c.bi_dev`.ioh_snd_master_kpi_detail
WHERE brand = '3ID' and lower(kpi) IN (
'addressable_site'
) 
 AND dt_id = vdt_id;


INSERT INTO `data-bi-prd-935c.bi_dev`.ioh_snd_master_kpi_detail 
SELECT
    '3ID' AS brand_id,
    'site_id' AS level_id,
    coalesce(site_id, site_id_old) AS level_value,
    1 AS kpi_value,
    'mtd' AS period_type,
    timestamp(current_datetime('+7')) AS uVDate_dttm,
    'addressable_site' AS kpi_name,
    vdt_id AS dt_id
FROM `data-bi-prd-935c.bi_snd.pre_ref_nshim3_addrsite_gtm_mth`
WHERE
    parse_date('%Y%m',cast(mth as string)) = date_trunc(vdt_id,month) and list_3id = 'Y'
    AND addressable_type = 'ADDRESSABLE SITE';


--Waiting Mas Andy marketing.tmp_rev_new_with_channel
-- DELETE FROM `data-bi-prd-935c.bi_dev`.ioh_snd_master_kpi_detail
-- WHERE brand = '3ID' and lower(kpi) IN (
-- 'm2_recharge'
-- ) 
--  AND dt_id = vdt_id;

--     INSERT INTO `data-bi-prd-935c.bi_dev`.ioh_snd_master_kpi_detail 
-- -- This CTE identifies all subscribers acquired two months prior to the current month,
-- -- along with their site_id.
-- WITH acquired_subs AS (
--     SELECT
--         sbscrptn_ek_id,
--         site_id
--     FROM `data-bi-prd-935c.bi_mart`.snd_rgu_ga_new_detail
--     WHERE date_trunc(load_dt_sk_id,month)= date_trunc(vdt_id,month) - interval 2 month
-- ),
-- -- This CTE identifies all subscribers who have recharged in the current month.
-- recharged_subs AS (
--     SELECT
--         sbscrptn_ek_id
--     FROM marketing.tmp_rev_new_with_channel
--     WHERE
--         service_type_name = 'BROADBAND'
--         AND trx_dt_sk_id BETWEEN date_trunc( vdt_id,month) AND vdt_id
--         AND (
--             CASE
--                 WHEN source_mapping IN ('CUST_DIRECT_AUTO_RENEWAL', 'CUST_DIRECT', 'CUST_DIRECT_BONSTRI_REDEEM', 'CUST_DIRECT_CHATBOT', 'CUST_DIRECT_LOAN', 'CUST_DIRECT_SMS') THEN 'ORGANIC OTHERS'
--                 WHEN source_mapping IN ('CUST_DIRECT_UMB_MENU') THEN 'ORGANIC USSD'
--                 WHEN source_mapping IN ('CUST_DIRECT_BIMA') THEN 'ORGANIC BIMA'
--                 WHEN source_mapping IN ('CUST_DIRECT_CVM') THEN 'ORGANIC CVM'
--                 WHEN source_mapping IN ('EVC_BROADBAND') THEN 'EVC'
--                 WHEN source_mapping = 'RITA' THEN 'RITA'
--                 WHEN source_mapping = 'SPV' THEN 'SPV'
--                 WHEN source_mapping = 'SIM_BROADBAND' THEN 'SIM'
--             END
--         ) IS NOT NULL
--     GROUP BY sbscrptn_ek_id
--     HAVING SUM(hit) > 0
-- )
-- -- The final SELECT counts the number of subscribers who appear in both CTEs,
-- -- grouped by site_id.
-- SELECT
--     '3ID' AS brand_id,
--     'site_id' AS level_id,
--     coalesce(a.site_id, 'null') AS level_value,
--     count(DISTINCT a.sbscrptn_ek_id) AS kpi_value,
--     'mtd' AS period_type,
--     timestamp(current_datetime('+7')) AS uVDate_dttm,
--     'm2_recharge' AS kpi_name,
--     vdt_id AS dt_id
-- FROM acquired_subs a
-- INNER JOIN recharged_subs b
--     ON a.sbscrptn_ek_id = b.sbscrptn_ek_id
-- GROUP BY
--     a.site_id;


-- Waiting for mkt_temp_pau_tracking
DELETE FROM `data-bi-prd-935c.bi_dev`.ioh_snd_master_kpi_detail
WHERE brand = '3ID' and lower(kpi) IN (
'pack_subs'
) 
 AND dt_id = vdt_id;



INSERT INTO `data-bi-prd-935c.bi_dev`.ioh_snd_master_kpi_detail 
-- This CTE first calculates the site_id and row number for each subscriber's transaction
-- within the month. The row number identifies the most recent transaction.
WITH latest_pau_transactions AS (
    SELECT
        sbscrptn_ek_id,
        coalesce(coalesce(a.site_id_90, a.site_id_30), a.site_id_dly) AS site_id,
        vdt_id,
        trx_dt_sk_id, -- Add by Indra Maulana Ikhsan because of error job
        row_number() OVER (PARTITION BY sbscrptn_ek_id, date_trunc(trx_dt_sk_id,month) ORDER BY trx_dt_sk_id DESC) AS rown
    FROM `data-analytics-prd-1b95.analytics`.mkt_temp_pau_tracking a
    WHERE
        trx_dt_sk_id BETWEEN date_trunc( vdt_id,month) AND vdt_id
)
-- The final SELECT counts the number of distinct subscribers whose latest transaction
-- in the month occurred on the current date, grouped by site_id.
SELECT
    '3ID' AS brand_id,
    'site_id' AS level_id,
    coalesce(site_id, 'null') AS level_value,
    count(DISTINCT sbscrptn_ek_id) AS kpi_value,
    'mtd' AS period_type,
    timestamp(current_datetime('+7')) AS uVDate_dttm,
    'pack_subs' AS kpi_name,
    vdt_id AS dt_id
FROM latest_pau_transactions
WHERE
    rown = 1
    AND trx_dt_sk_id = vdt_id
GROUP BY
    site_id,vdt_id;



DELETE FROM `data-bi-prd-935c.bi_dev`.ioh_snd_master_kpi_detail
WHERE brand = '3ID' and lower(kpi) IN (
'm2_revenue'
) 
 AND dt_id = vdt_id;



INSERT INTO `data-bi-prd-935c.bi_dev`.ioh_snd_master_kpi_detail 
-- This CTE identifies all subscribers acquired two months prior to the current month,
-- along with their site_id.
WITH acquired_subs AS (
    SELECT
        sbscrptn_ek_id,
        site_id
    FROM `data-bi-prd-935c.bi_mart`.snd_rgu_ga_new_detail
    WHERE date_trunc(load_dt_sk_id,month)= date_trunc(vdt_id,month) - interval 2 month
),
-- This CTE calculates the total revenue for each subscriber in the current month.
monthly_revenue AS (
    SELECT
        sbscrptn_ek_id,
        sum(revenue) AS total_revenue
    FROM `data-bi-prd-935c.bi_mart`.fct_cwn_rev_detail_fnl
    WHERE
        trx_dt_sk_id BETWEEN date_trunc( vdt_id,month) AND vdt_id
    GROUP BY sbscrptn_ek_id
)
-- The final SELECT joins the two CTEs to get the revenue from the M-2 cohort
-- and aggregates it by site_id.
SELECT
    '3ID' AS brand_id,
    'site_id' AS level_id,
    coalesce(a.site_id, 'null') AS level_value,
    cast(sum(b.total_revenue) as numeric) AS kpi_value,
    'mtd' AS period_type,
    timestamp(current_datetime('+7')) AS uVDate_dttm,
    'm2_revenue' AS kpi_name,
   vdt_id AS dt_id
FROM acquired_subs a
INNER JOIN monthly_revenue b
    ON a.sbscrptn_ek_id = b.sbscrptn_ek_id
GROUP BY
    a.site_id;


-- Waiting Mas Arenzy for marketing.bai_3id_rita_app_rev_view and marketing.bai_tbl_retailer_dim_v1
-- DELETE FROM `data-bi-prd-935c.bi_dev`.ioh_snd_master_kpi_detail
-- WHERE brand = '3ID' and lower(kpi) IN (
-- 'rita_trx_user'
-- ) 
--  AND dt_id = vdt_id;



-- INSERT INTO `data-bi-prd-935c.bi_dev`.ioh_snd_master_kpi_detail 
-- -- This CTE first identifies all outlets that had a RITA transaction in the current month.
-- WITH rita_transacting_outlets AS (
--     SELECT DISTINCT
--         org_id AS outlet_id
--     FROM marketing.bai_3id_rita_app_rev_view
--     WHERE
--         dt_id BETWEEN date_trunc( vdt_id,month) AND vdt_id
-- ),
-- -- This CTE gets the latest site_id mapping for each outlet from a historical table.
-- outlet_site_mapping AS (
--     SELECT
--         ret_qr_cd AS outlet_id,
--         site_id
--     FROM (
--         SELECT
--             dt,
--             ret_qr_cd,
--             site_id,
--             row_number() OVER (PARTITION BY ret_qr_cd ORDER BY dt DESC) AS rnk
--         FROM `data-bi-prd-935c.bi_mart`.stg_v_map_tgt_ret_details_hist
--         WHERE
--             site_id <> ''
--             AND date_trunc(dt,month) = date_trunc(vdt_id,month)
--     ) x
--     WHERE rnk = 1
-- )
-- -- The final SELECT joins the two CTEs to count the number of unique transacting outlets per site.
-- SELECT
--     '3ID' AS brand_id,
--     'site_id' AS level_id,
--     coalesce(osm.site_id, 'null') AS level_value,
--     count(DISTINCT rto.outlet_id) AS kpi_value,
--     'mtd' AS period_type,
--     timestamp(current_datetime('+7')) AS uVDate_dttm,
--     'rita_trx_user' AS kpi_name,
--    vdt_id AS dt_id
-- FROM rita_transacting_outlets rto
-- INNER JOIN outlet_site_mapping osm ON rto.outlet_id = osm.outlet_id
-- GROUP BY
--     coalesce(osm.site_id, 'null');

-- DELETE FROM `data-bi-prd-935c.bi_dev`.ioh_snd_master_kpi_detail
-- WHERE brand = '3ID' and lower(kpi) IN (
-- 'rita_login_user'
-- ) 
--  AND dt_id = vdt_id;



--     INSERT INTO `data-bi-prd-935c.bi_dev`.ioh_snd_master_kpi_detail 
-- -- This CTE first identifies all outlets that had a RITA login in the current month.
-- WITH rita_logins AS (
--     SELECT DISTINCT
--         qr_code AS outlet_id
--     FROM marketing.bai_tbl_retailer_dim_v1
--     WHERE
--         dt_id / 100 = date_trunc(vdt_id,month)
--         AND last_login_formatted BETWEEN date_trunc( vdt_id,month) AND vdt_id
-- ),
-- -- This CTE gets the latest site_id mapping for each outlet from a historical table.
-- outlet_site_mapping AS (
--     SELECT
--         ret_qr_cd AS outlet_id,
--         site_id
--     FROM (
--         SELECT
--             dt,
--             ret_qr_cd,
--             site_id,
--             row_number() OVER (PARTITION BY ret_qr_cd ORDER BY dt DESC) AS rnk
--         FROM `data-bi-prd-935c.bi_mart`.stg_v_map_tgt_ret_details_hist
--         WHERE
--             site_id <> ''
--             AND date_trunc(dt,month) = date_trunc(vdt_id,month)
--     ) x
--     WHERE rnk = 1
-- )
-- -- The final SELECT joins the two CTEs to count the number of unique logged-in outlets per site.
-- SELECT
--     '3ID' AS brand_id,
--     'site_id' AS level_id,
--     coalesce(osm.site_id, 'null') AS level_value,
--     count(DISTINCT rl.outlet_id) AS kpi_value,
--     'mtd' AS period_type,
--     timestamp(current_datetime('+7')) AS uVDate_dttm,
--     'rita_login_user' AS kpi_name,
--     vdt_id AS dt_id
-- FROM rita_logins rl
-- INNER JOIN outlet_site_mapping osm ON rl.outlet_id = osm.outlet_id
-- GROUP BY
--     coalesce(osm.site_id, 'null');



DELETE FROM `data-bi-prd-935c.bi_dev`.ioh_snd_master_kpi_detail
WHERE brand = '3ID' and lower(kpi) IN (
'outlet_demand','outlet_supply'
) 
 AND dt_id = vdt_id;


    INSERT INTO `data-bi-prd-935c.bi_dev`.ioh_snd_master_kpi_detail 
-- This CTE joins the outlet data with their corresponding site IDs for a single day,
-- and filters for the relevant KPIs.
    SELECT '3ID' as brand,
    'site_id' level,
    coalesce(site_id, 'N/A') level_value,
    count(distinct partner_qr_cd) val,
    'daily' time_flag,
    timestamp(current_datetime('+7')) insert_date,
    'outlet_supply' kpi,
    vdt_id dt_id
    FROM
    (
        --- 1. Trade Supply Voucher (UNLOCK REGULAR_VOUCHER SUPPLY)
        SELECT vdt_id dt ,partner_qr_cd,site_id,sum(net_Revenue) net
        FROM `data-bi-prd-935c.bi_mart`.dm_snd_voucher a
        LEFT JOIN (SELECT * from `data-bi-prd-935c.bi_mart`.angie_hrchy_dim_hst where hrchy_type='Retailer' and partner_Status='Active' and mth=date_trunc(vdt_id,month) ) b on a.qr_Cd=b.partner_qr_cd
        LEFT OUTER JOIN
        (
            SELECT ret_qr_cd,site_id
            FROM (SELECT dt,ret_qr_cd,site_id,row_number() over (partition by ret_qr_cd order by dt desc) rnk
            FROM `data-bi-prd-935c.bi_mart`.stg_v_map_tgt_ret_details_hist
            WHERE site_id <>'' and dt<=vdt_id) x WHERE rnk=1
        ) c on a.qr_Cd=c.ret_qr_cd
        WHERE sd_type='SUPPLY'
        AND package_type='UNLOCK'
        AND voucher_type in ('REGULAR_VOUCHER','ORI_VOUCHER')
        AND a.dt = vdt_id
        AND upper(bm_location ) NOT IN
        (
            'DVM BM','3 BUSINESS','SIM ONLINE','NA','POOL','3 STORE',
            'SOUTH JAKARTA TEST BM','BSM TRI OFFICIAL STORE'
        )
        GROUP BY 1,2,3

        UNION ALL

        --- 2. Trade Supply RITA (E TOP UP DEMAND/Top Up)
        SELECT vdt_id dt ,a.qr_cd,site_id,sum(net_Revenue)
        FROM `data-bi-prd-935c.bi_mart`.dm_snd_voucher a
        LEFT JOIN (SELECT * from `data-bi-prd-935c.bi_mart`.angie_hrchy_dim_hst where hrchy_type='Retailer' and partner_Status='Active' and mth=date_trunc(vdt_id,month) ) b on a.qr_Cd=b.partner_qr_cd
        LEFT OUTER JOIN
        (
            SELECT ret_qr_cd,site_id
            FROM (SELECT dt,ret_qr_cd,site_id,row_number() over (partition by ret_qr_cd order by dt desc) rnk
            FROM `data-bi-prd-935c.bi_mart`.stg_v_map_tgt_ret_details_hist
            WHERE site_id <>'' and dt<=vdt_id) x WHERE rnk=1
        ) c on a.qr_Cd=c.ret_qr_cd
        WHERE sd_type='DEMAND'
        AND package_type='RITA'
        AND voucher_type='E TOP UP'
        AND a.dt = vdt_id
        AND upper(bm_location ) NOT IN
        (
            'DVM BM','3 BUSINESS','SIM ONLINE','NA','POOL','3 STORE',
            'SOUTH JAKARTA TEST BM','BSM TRI OFFICIAL STORE'
        )
        GROUP BY 1,2,3

        UNION ALL

        --- 3. Trade Supply FRC
        SELECT vdt_id dt ,a.partner_qr_cd,site_id,sum(net_Revenue)
        FROM `data-bi-prd-935c.bi_mart`.dm_snd_demand_frc a
        LEFT JOIN (SELECT * from `data-bi-prd-935c.bi_mart`.angie_hrchy_dim_hst where hrchy_type='Retailer' and partner_Status='Active' and mth=date_trunc(vdt_id,month) ) b on a.partner_qr_cd=b.partner_qr_cd
        LEFT OUTER JOIN
        (
            SELECT ret_qr_cd,site_id
            FROM (SELECT dt,ret_qr_cd,site_id,row_number() over (partition by ret_qr_cd order by dt desc) rnk
            FROM `data-bi-prd-935c.bi_mart`.stg_v_map_tgt_ret_details_hist
            WHERE site_id <>'' and dt<=vdt_id) x WHERE rnk=1
        ) c on a.partner_qr_cd=c.ret_qr_cd
        WHERE sd_type='SUPPLY'
        AND a.dt = vdt_id
        AND upper(bm_location ) NOT IN
        (
            'DVM BM','3 BUSINESS','SIM ONLINE','NA','POOL','3 STORE',
            'SOUTH JAKARTA TEST BM','BSM TRI OFFICIAL STORE'
        )
        GROUP BY 1,2,3
    ) supply
    GROUP BY 1,2,3,5,7,8
    union all 
    SELECT '3ID',
    'site_id',
    site_id ,
    count(distinct dealer_id) kpi_value,
    'daily',
    timestamp(current_datetime('+7')),
    'outlet_demand',
    vdt_id dt_id
    FROM `data-bi-prd-935c.bi_mart`.project_ioh_tertiary_outlet a
    LEFT JOIN `data-bi-prd-935c.bi_mart`.angie_hrchy_dim_hst b ON b.partner_qr_cd = a.dealer_id AND date_trunc(a.dt_sk_id,month) = b.mth
    LEFT JOIN
    (
        SELECT ret_qr_cd,site_id
        FROM
        (
            SELECT dt,ret_qr_cd,site_id,row_number() over (partition by ret_qr_cd order by dt desc) rnk
            FROM `data-bi-prd-935c.bi_mart`.stg_v_map_tgt_ret_details_hist
            WHERE date_trunc(dt,month) = date_trunc(vdt_id,month) AND site_id <>''
        ) x WHERE rnk=1
    ) c ON a.dealer_id=c.ret_qr_cd
    WHERE dt_sk_id =  vdt_id
    AND tertiary_category IN ('SALDO','FRC','UNLOCK') AND length(dealer_id) < 10
    AND upper(mp3_location) NOT IN
    (
        'POOL',
        'DVM BM',
        'SIM ONLINE',
        'BSM TRI OFFICIAL STORE',
        '3 STORE',
        'SOUTH JAKARTA TEST BM'
    )
    AND tertiary_type NOT LIKE '%PULSA%'
    GROUP BY 1,2,3,5,6,7,8
    -- ;
    -- SELECT
    --     a.dt_id,
    --     a.ret_qrcode,
    --     a.kpi_name,
    --     c.site_id
    -- FROM `data-bi-prd-935c.bi_mart`.outletwise_smy a
    -- LEFT JOIN `data-bi-prd-935c.bi_stg`.tmp_nbs c ON a.ret_qrcode = c.ret_qr_cd
    -- WHERE
    --     a.dt_id = vdt_id
    --     AND trim(lower(a.kpi_name)) IN ('trade_demand', 'trade_supply')
;

DELETE FROM `data-bi-prd-935c.bi_dev`.ioh_snd_master_kpi_detail
WHERE brand = '3ID' and kpi IN
(
'ATL_Outlet',
'ATL_Revenue',
'ATL_Sachet_Outlet',
'ATL_Sachet_Revenue',
'CVM_Outlet',
'CVM_Revenue',
'CVM_Sachet_Outlet',
'CVM_Sachet_Revenue'
) 
 AND dt_id = vdt_id;



-- Waiting permission `data-analytics-prd-1b95.analytics.mkt_cvm_rita_details`
INSERT INTO `data-bi-prd-935c.bi_dev`.ioh_snd_master_kpi_detail 
-- This CTE gets the latest site ID mapping for each outlet.
WITH outlet_site_mapping AS (
    SELECT
        ret_qr_cd,
        site_id
    FROM (
        SELECT
            ret_qr_cd,
            site_id,
            row_number() OVER (PARTITION BY ret_qr_cd ORDER BY dt DESC) AS rnk
        FROM `data-bi-prd-935c.bi_mart`.stg_v_map_tgt_ret_details_hist
        WHERE
            site_id <> ''
            AND date_trunc(dt,month) = date_trunc(vdt_id,month)
    ) x
    WHERE rnk = 1
),
-- This CTE consolidates the raw transaction data and joins with the site mapping.
base_data AS (
    SELECT
        vdt_id AS dt_id,
        CASE WHEN a.rita_cvm = 1 THEN 'CVM' ELSE 'ATL' END AS category,
        a.parent_qr_cd AS qr_code,
        CASE
            WHEN validity.validity_days <= 4 THEN 'Sachet'
            WHEN validity.validity_days <= 20 THEN 'Weekly'
            WHEN validity.validity_days > 20 THEN 'Monthly'
            ELSE 'Unknown'
        END AS validity_grp,
        osm.site_id,
        cast(sum(a.gross_revenue) as numeric) gross_revenue    
    FROM `data-analytics-prd-1b95.analytics.mkt_cvm_rita_details` a
    LEFT JOIN (
        SELECT DISTINCT product_sk_id, validity_days
        FROM `data-dtptechm-prd-c7ca.dwh`.ioh_calendarization_validity_dim_v3
        WHERE current_indicator = 'Y'
    ) validity ON a.product_sk_id = validity.product_sk_id
    LEFT JOIN outlet_site_mapping osm ON osm.ret_qr_cd = a.parent_qr_cd
    WHERE
        a.trx_dt_sk_id BETWEEN date_trunc(vdt_id,month) AND vdt_id
        AND a.service_type = 'BROADBAND'
    GROUP BY
        1, 2, 3, 4, 5
)
-- UNION ALL to generate separate rows for all 8 KPIs
SELECT * FROM (
    -- ATL_Outlet
    SELECT '3ID', 'site_id', coalesce(site_id, 'null'), count(DISTINCT qr_code), 'mtd', timestamp(current_datetime('+7')), 'ATL_Outlet', dt_id FROM base_data WHERE category = 'ATL' GROUP BY dt_id, site_id
    UNION ALL
    -- ATL_Revenue
    SELECT '3ID', 'site_id', coalesce(site_id, 'null'), sum(gross_revenue), 'mtd', timestamp(current_datetime('+7')), 'ATL_Revenue', dt_id FROM base_data WHERE category = 'ATL' GROUP BY dt_id, site_id
    UNION ALL
    -- ATL_Sachet_Outlet
    SELECT '3ID', 'site_id', coalesce(site_id, 'null'), count(DISTINCT qr_code), 'mtd', timestamp(current_datetime('+7')), 'ATL_Sachet_Outlet', dt_id FROM base_data WHERE category = 'ATL' AND validity_grp = 'Sachet' GROUP BY dt_id, site_id
    UNION ALL
    -- ATL_Sachet_Revenue
    SELECT '3ID', 'site_id', coalesce(site_id, 'null'), sum(gross_revenue), 'mtd', timestamp(current_datetime('+7')), 'ATL_Sachet_Revenue', dt_id FROM base_data WHERE category = 'ATL' AND validity_grp = 'Sachet' GROUP BY dt_id, site_id
    UNION ALL
    -- CVM_Outlet
    SELECT '3ID', 'site_id', coalesce(site_id, 'null'), count(DISTINCT qr_code), 'mtd', timestamp(current_datetime('+7')), 'CVM_Outlet', dt_id FROM base_data WHERE category = 'CVM' GROUP BY dt_id, site_id
    UNION ALL
    -- CVM_Revenue
    SELECT '3ID', 'site_id', coalesce(site_id, 'null'), sum(gross_revenue), 'mtd', timestamp(current_datetime('+7')), 'CVM_Revenue', dt_id FROM base_data WHERE category = 'CVM' GROUP BY dt_id, site_id
    UNION ALL
    -- CVM_Sachet_Outlet
    SELECT '3ID', 'site_id', coalesce(site_id, 'null'), count(DISTINCT qr_code), 'mtd', timestamp(current_datetime('+7')), 'CVM_Sachet_Outlet', dt_id FROM base_data WHERE category = 'CVM' AND validity_grp = 'Sachet' GROUP BY dt_id, site_id
    UNION ALL
    -- CVM_Sachet_Revenue
    SELECT '3ID', 'site_id', coalesce(site_id, 'null'), sum(gross_revenue), 'mtd', timestamp(current_datetime('+7')), 'CVM_Sachet_Revenue', dt_id FROM base_data WHERE category = 'CVM' AND validity_grp = 'Sachet' GROUP BY dt_id, site_id
) AS combined_results;

    
DELETE FROM `data-bi-prd-935c.bi_dev`.ioh_snd_master_kpi_detail
WHERE brand = '3ID' and lower(kpi) IN ('rev_organic') AND dt_id = vdt_id;

INSERT INTO `data-bi-prd-935c.bi_dev`.ioh_snd_master_kpi_detail   
      SELECT '3ID' as brand,
    'site_id' level,
    site_id level_value,
    cast(sum(value) as numeric),
    'mtd' time_flag,
    timestamp(current_datetime('+7')) insert_date,
    CASE WHEN kpi_code = 'M1S_MTD' THEN 'm1s_mtd' ELSE lower(kpi_code) END kpi,
    vdt_id dt_id 
    FROM `data-bi-prd-935c.bi_mart`.project_ioh_kpi_daily_tracker_site -- select * From project_ioh_kpi_daily_tracker_site limit 10 
    WHERE load_dt_sk_id  BETWEEN date_trunc(vdt_id,month) AND vdt_id
      AND kpi_code   IN ('rev_organic')  
    GROUP BY 1,2,3,5,7,8;



 
DELETE FROM `data-bi-prd-935c.bi_dev`.ioh_snd_master_kpi_detail
WHERE brand = '3ID' and lower(kpi) IN ('site_0_rguga_trad') AND dt_id = vdt_id;



INSERT INTO `data-bi-prd-935c.bi_dev`.ioh_snd_master_kpi_detail
    SELECT '3ID',
    'site_id',
    new_site_id,
    1 value,
    'mtd',
    timestamp(current_datetime('+7')),
    'site_0_rguga_trad' ,
    vdt_id 
from 	(
	select distinct parse_date('%Y%m',cast(mth as string)) mth, 
	coalesce(site_id, site_id_old) new_site_id, 
	addressable_type
	from `data-bi-prd-935c.bi_snd.pre_ref_nshim3_addrsite_gtm_mth` asg 
	where parse_date('%Y%m',cast(mth as string)) = date_trunc(vdt_id,month) and list_3id = 'Y'
	and addressable_type = 'ADDRESSABLE SITE'
)b left join `data-bi-prd-935c.bi_dev`.ioh_snd_master_kpi_detail a 										
on b.new_site_id = a.level_value and a.dt_id =	vdt_id and kpi='RGUGA_Trade' and level='site_id' and time_flag='mtd' and brand = '3ID'	 	
where a.level_value is null 
    GROUP BY 1,2,3,5,6,7,8;


    
DELETE FROM `data-bi-prd-935c.bi_dev`.ioh_snd_master_kpi_detail
WHERE brand = '3ID' and lower(kpi) IN ('outlet_0_rguga_trad') AND dt_id = vdt_id;



 INSERT INTO `data-bi-prd-935c.bi_dev`.ioh_snd_master_kpi_detail   
    SELECT '3ID' as brand,
    'outlet' level,
    b.retailer_qrcode level_value,
    1 value,
    'mtd' time_flag,
    timestamp(current_datetime('+7')) insert_date,
    'outlet_0_rguga_trad' kpi,
    vdt_id dt_id 
    FROM `data-bi-prd-935c.bi_snd.pre_ref_outlet_mapping_3id` b  
    left join `data-bi-prd-935c.bi_dev`.ioh_snd_master_kpi_detail a 
    on b.retailer_qrcode=a.level_value and a.dt_id = vdt_id 
    and kpi='RGUGA_Trade' and level='outlet' and time_flag='mtd' 	  
    WHERE parse_date('%Y%m%d',concat(cast(mth_id as string),'01')) = date_trunc(vdt_id,month)
    and a.level_value is null 
    GROUP BY 1,2,3,5,7,8 
    ;
    
DELETE FROM `data-bi-prd-935c.bi_dev`.ioh_snd_master_kpi_detail
WHERE brand = '3ID' and lower(kpi) IN ('tertiary_trad_inner','tertiary_trad_outer') AND dt_id = vdt_id;

INSERT INTO `data-bi-prd-935c.bi_dev`.ioh_snd_master_kpi_detail 
    WITH ref_region_circle AS (
        SELECT circle, region_circle, site_id, gladiator_branch, gladiator_branch_id, 
               kabkot_nm as kabupaten, kecamatan_nm as kecamatan, cnt, rnk
        FROM (
            SELECT circle, region_circle, site_id, gladiator_branch, gladiator_branch_id, 
                   kabkot_nm, kecamatan_nm, count(*) cnt,
                   ROW_NUMBER() OVER (PARTITION BY site_id ORDER BY count(*) DESC) rnk 
            FROM `data-bi-prd-935c.bi_mart`.ref_site_h3i_mth
            WHERE mth_id = date_trunc(vdt_id,month)
            GROUP BY circle, region_circle, site_id, gladiator_branch, gladiator_branch_id, kabkot_nm, kecamatan_nm
        ) x
        WHERE rnk = 1
    ),

    ref_branch_circle AS (
        SELECT DISTINCT circle, site_id, gladiator_branch, gladiator_branch_id, kabupaten, kecamatan
        FROM ref_region_circle
    ),

    nbs_data AS (
        SELECT ret_qr_cd, site_id 
        FROM (
            SELECT dt, ret_qr_cd, site_id, 
                   ROW_NUMBER() OVER (PARTITION BY ret_qr_cd ORDER BY dt DESC) rnk
            FROM `data-bi-prd-935c.bi_mart`.stg_v_map_tgt_ret_details_hist
            WHERE site_id != ''
            AND date_trunc(dt,month) = date_trunc(vdt_id,month)
        ) x 
        WHERE rnk = 1
    ),

    angie_data AS (
        SELECT partner_qr_cd, mp3_location
        FROM `data-bi-prd-935c.bi_mart`.angie_hrchy_dim_hst 
        WHERE mth = date_trunc(vdt_id,month)
    ),

    tertiary_data AS (
        SELECT vdt_id as dt_id, 
               a.dealer_id,
               --COALESCE(a.siteid_bnum, c.site_id) as site_id,
               a.siteid_bnum as site_id,
               SUM(COALESCE(a.amount, 0)) amount
        FROM `data-bi-prd-935c.bi_mart`.project_ioh_tertiary_outlet a
        LEFT JOIN angie_data b ON b.partner_qr_cd = a.dealer_id
        LEFT JOIN nbs_data c ON a.dealer_id = c.ret_qr_cd 
        WHERE a.dt_sk_id >=  date_trunc(vdt_id,month)
        AND a.dt_sk_id <=  vdt_id
        AND a.tertiary_category IN ('SALDO', 'FRC', 'UNLOCK') 
        AND LENGTH(a.dealer_id) < 10
        AND UPPER(b.mp3_location) NOT IN ('POOL', 'DVM BM', 'SIM ONLINE', 'BSM TRI OFFICIAL STORE', '3 BUSINESS', '3 STORE', 'SOUTH JAKARTA TEST BM')
        GROUP BY 1,2,3
    )


 SELECT '3ID',
           'site_id',
           a.site_id,
           sum(case when refa.gladiator_branch_id = refb.gladiator_branch_id then amount else 0 end) AS kpi_value,
           'mtd',
           current_timestamp,
           'tertiary_trad_inner' kpi ,
           vdt_id
    FROM tertiary_data a
    LEFT JOIN ref_branch_circle refa ON a.site_id = refa.site_id 
    LEFT JOIN nbs_data nbs ON a.dealer_id = nbs.ret_qr_cd
    LEFT JOIN ref_branch_circle refb ON refb.site_id = nbs.site_id
--    WHERE --a.site_id IS NOT NULL
    --AND 
   -- a.amount > 0
      group by 1,2,3,5,6,7,8 
    union all     
           
 SELECT '3ID',
           'site_id',
           a.site_id,
           sum(a.amount) - sum(case when refa.gladiator_branch_id = refb.gladiator_branch_id then amount else 0 end) kpi_value,
           'mtd',
           current_timestamp,
           'tertiary_trad_outer' kpi ,
           vdt_id
    FROM tertiary_data a
    LEFT JOIN ref_branch_circle refa ON a.site_id = refa.site_id 
    LEFT JOIN nbs_data nbs ON a.dealer_id = nbs.ret_qr_cd
    LEFT JOIN ref_branch_circle refb ON refb.site_id = nbs.site_id
   -- WHERE --a.site_id IS NOT NULL
   -- AND 
   -- a.amount > 0
    group by 1,2,3,5,6,7,8 
;    
    
    
--Waiting Mas Teguh about ioh_snd_master_kpi_detail_ga_dsf ?    
--   		-- Daily rgu_ga by site_id (with channel breakdown)
--     INSERT INTO `data-bi-prd-935c.bi_dev`.ioh_snd_master_kpi_detail_ga_dsf  
--     SELECT '3ID' as brand,
--     'site_id' level,
--     a.site_id level_value,
--     COUNT(*) value,
--     'dly' time_flag,
--     timestamp(current_datetime('+7')) insert_date,
--         CASE
--                 WHEN a.channel LIKE 'CIRCLE%' THEN
--                     CASE
--                         WHEN b.ret_type = 'D' THEN 'RGUGA-Trad-DSF'
--                         ELSE 'RGUGA-Trad-Outlet'
--                     END
--                 WHEN a.channel = 'DOH POOL' THEN	
--                     CASE
--                         WHEN b.ret_type = 'D' THEN 'RGUGA-Trad-DSF'
--                         ELSE 'RGUGA-Trad-Outlet'
--                     END
--                 WHEN a.channel LIKE '%FWA%' THEN 'RGUGA-FWA'
--                 WHEN a.channel IN ('DOH MODERN CHANNEL', 'DOH TRI OFFICIAL STORE', 'DOH DVM', 'DOH THREE STORE') THEN 'RGUGA-Digital-Modern'
--                 WHEN a.channel IN ('DOH SAHABAT VIRTUAL') THEN 'RGUGA-Digital-Online'
--                 WHEN a.channel IN ('DOH SIM ONLINE') THEN 'RGUGA-Digital-OLA'
--                 ELSE 'RGUGA-Trad-Outlet'
--     END    
-- 	kpi,
--     dt dt_id 
--     FROM fct_ga_site_id_v3 a
-- 	LEFT JOIN (
--         SELECT DISTINCT retailer_qrcode, ret_type
--         FROM `data-dtptechm-prd-c7ca.dwh`.retailer_hierarchy
--         WHERE periode_data = vdt_id
--     ) b ON a.partner_qr_cd = b.retailer_qrcode
	
--     WHERE dt = vdt_id 
-- 	 AND (
--             CASE
--                 WHEN a.channel LIKE 'CIRCLE%' THEN
--                     CASE
--                         WHEN b.ret_type = 'D' THEN 'RGUGA-Trad-DSF'
--                         ELSE 'RGUGA-Trad-Outlet'
--                     END
--                 WHEN a.channel = 'DOH POOL' THEN	
--                     CASE
--                         WHEN b.ret_type = 'D' THEN 'RGUGA-Trad-DSF'
--                         ELSE 'RGUGA-Trad-Outlet'
--                     END
--                 WHEN a.channel LIKE '%FWA%' THEN 'RGUGA-FWA'
--                 WHEN a.channel IN ('DOH MODERN CHANNEL', 'DOH TRI OFFICIAL STORE', 'DOH DVM', 'DOH THREE STORE') THEN 'RGUGA-Digital-Modern'
--                 WHEN a.channel IN ('DOH SAHABAT VIRTUAL') THEN 'RGUGA-Digital-Online'
--                 WHEN a.channel IN ('DOH SIM ONLINE') THEN 'RGUGA-Digital-OLA'
--                 ELSE 'RGUGA-Trad-Outlet'
--             END
--         ) IN ('RGUGA-Trad-Outlet', 'RGUGA-Trad-DSF')
--     GROUP BY 1,2,3,5,7,8;
    
--     -- Daily rgu_ga by outlet (with channel breakdown)
--     INSERT INTO `data-bi-prd-935c.bi_dev`.ioh_snd_master_kpi_detail_ga_dsf   
--     SELECT '3ID' as brand,
--     'outlet' level,
--     partner_qr_cd level_value,
--     COUNT(*) value,
--     'dly' time_flag,
--     timestamp(current_datetime('+7')) insert_date,
--         CASE
--                 WHEN a.channel LIKE 'CIRCLE%' THEN
--                     CASE
--                         WHEN b.ret_type = 'D' THEN 'RGUGA-Trad-DSF'
--                         ELSE 'RGUGA-Trad-Outlet'
--                     END
--                 WHEN a.channel = 'DOH POOL' THEN	
--                     CASE
--                         WHEN b.ret_type = 'D' THEN 'RGUGA-Trad-DSF'
--                         ELSE 'RGUGA-Trad-Outlet'
--                     END
--                 WHEN a.channel LIKE '%FWA%' THEN 'RGUGA-FWA'
--                 WHEN a.channel IN ('DOH MODERN CHANNEL', 'DOH TRI OFFICIAL STORE', 'DOH DVM', 'DOH THREE STORE') THEN 'RGUGA-Digital-Modern'
--                 WHEN a.channel IN ('DOH SAHABAT VIRTUAL') THEN 'RGUGA-Digital-Online'
--                 WHEN a.channel IN ('DOH SIM ONLINE') THEN 'RGUGA-Digital-OLA'
--                 ELSE 'RGUGA-Trad-Outlet'
--     END    
-- 	kpi,
--     dt dt_id 
--     FROM fct_ga_site_id_v3 a
-- 	LEFT JOIN (
--         SELECT DISTINCT retailer_qrcode, ret_type
--         FROM `data-dtptechm-prd-c7ca.dwh`.retailer_hierarchy
--         WHERE periode_data = vdt_id
--     ) b ON a.partner_qr_cd = b.retailer_qrcode 
--  WHERE dt = vdt_id  
--   AND (
--             CASE
--                 WHEN a.channel LIKE 'CIRCLE%' THEN
--                     CASE
--                         WHEN b.ret_type = 'D' THEN 'RGUGA-Trad-DSF'
--                         ELSE 'RGUGA-Trad-Outlet'
--                     END
--                 WHEN a.channel = 'DOH POOL' THEN	
--                     CASE
--                         WHEN b.ret_type = 'D' THEN 'RGUGA-Trad-DSF'
--                         ELSE 'RGUGA-Trad-Outlet'
--                     END
--                 WHEN a.channel LIKE '%FWA%' THEN 'RGUGA-FWA'
--                 WHEN a.channel IN ('DOH MODERN CHANNEL', 'DOH TRI OFFICIAL STORE', 'DOH DVM', 'DOH THREE STORE') THEN 'RGUGA-Digital-Modern'
--                 WHEN a.channel IN ('DOH SAHABAT VIRTUAL') THEN 'RGUGA-Digital-Online'
--                 WHEN a.channel IN ('DOH SIM ONLINE') THEN 'RGUGA-Digital-OLA'
--                 ELSE 'RGUGA-Trad-Outlet'
--             END
--         ) IN ('RGUGA-Trad-Outlet', 'RGUGA-Trad-DSF')
--     GROUP BY 1,2,3,5,7,8;
    
	
	
-- 	-- MTD rgu_ga by site_id (with channel breakdown)
--     INSERT INTO `data-bi-prd-935c.bi_dev`.ioh_snd_master_kpi_detail_ga_dsf  
--     SELECT '3ID' as brand,
--     'site_id' level,
--     a.site_id level_value,
--     COUNT(*) value,
--     'mtd' time_flag,
--     timestamp(current_datetime('+7')) insert_date,
--         CASE
--                 WHEN a.channel LIKE 'CIRCLE%' THEN
--                     CASE
--                         WHEN b.ret_type = 'D' THEN 'RGUGA-Trad-DSF'
--                         ELSE 'RGUGA-Trad-Outlet'
--                     END
--                 WHEN a.channel = 'DOH POOL' THEN	
--                     CASE
--                         WHEN b.ret_type = 'D' THEN 'RGUGA-Trad-DSF'
--                         ELSE 'RGUGA-Trad-Outlet'
--                     END
--                 WHEN a.channel LIKE '%FWA%' THEN 'RGUGA-FWA'
--                 WHEN a.channel IN ('DOH MODERN CHANNEL', 'DOH TRI OFFICIAL STORE', 'DOH DVM', 'DOH THREE STORE') THEN 'RGUGA-Digital-Modern'
--                 WHEN a.channel IN ('DOH SAHABAT VIRTUAL') THEN 'RGUGA-Digital-Online'
--                 WHEN a.channel IN ('DOH SIM ONLINE') THEN 'RGUGA-Digital-OLA'
--                 ELSE 'RGUGA-Trad-Outlet'
--     END    
-- 	kpi,
--     vdt_id dt_id 
--     FROM fct_ga_site_id_v3 a
-- 		LEFT JOIN (
--         SELECT DISTINCT retailer_qrcode, ret_type
--         FROM `data-dtptechm-prd-c7ca.dwh`.retailer_hierarchy
--         WHERE periode_data = vdt_id
--     ) b ON a.partner_qr_cd = b.retailer_qrcode 

--     WHERE dt >= TO_CHAR(DATE_TRUNC('month', vdt_id::TEXT::DATE)::DATE, 'yyyymmdd')::INTEGER AND dt <= vdt_id
--  AND (
--             CASE
--                 WHEN a.channel LIKE 'CIRCLE%' THEN
--                     CASE
--                         WHEN b.ret_type = 'D' THEN 'RGUGA-Trad-DSF'
--                         ELSE 'RGUGA-Trad-Outlet'
--                     END
--                 WHEN a.channel = 'DOH POOL' THEN	
--                     CASE
--                         WHEN b.ret_type = 'D' THEN 'RGUGA-Trad-DSF'
--                         ELSE 'RGUGA-Trad-Outlet'
--                     END
--                 WHEN a.channel LIKE '%FWA%' THEN 'RGUGA-FWA'
--                 WHEN a.channel IN ('DOH MODERN CHANNEL', 'DOH TRI OFFICIAL STORE', 'DOH DVM', 'DOH THREE STORE') THEN 'RGUGA-Digital-Modern'
--                 WHEN a.channel IN ('DOH SAHABAT VIRTUAL') THEN 'RGUGA-Digital-Online'
--                 WHEN a.channel IN ('DOH SIM ONLINE') THEN 'RGUGA-Digital-OLA'
--                 ELSE 'RGUGA-Trad-Outlet'
--             END
--         ) IN ('RGUGA-Trad-Outlet', 'RGUGA-Trad-DSF')
--     GROUP BY 1,2,3,5,7,8;
  
    
--     -- MTD rgu_ga by outlet (with channel breakdown)
--     INSERT INTO `data-bi-prd-935c.bi_dev`.ioh_snd_master_kpi_detail_ga_dsf   
--     SELECT '3ID' as brand,
--     'outlet' level,
--     partner_qr_cd level_value,
--     COUNT(*) value,
--     'mtd' time_flag,
--     timestamp(current_datetime('+7')) insert_date,
--         CASE
--                 WHEN a.channel LIKE 'CIRCLE%' THEN
--                     CASE
--                         WHEN b.ret_type = 'D' THEN 'RGUGA-Trad-DSF'
--                         ELSE 'RGUGA-Trad-Outlet'
--                     END
--                 WHEN a.channel = 'DOH POOL' THEN	
--                     CASE
--                         WHEN b.ret_type = 'D' THEN 'RGUGA-Trad-DSF'
--                         ELSE 'RGUGA-Trad-Outlet'
--                     END
--                 WHEN a.channel LIKE '%FWA%' THEN 'RGUGA-FWA'
--                 WHEN a.channel IN ('DOH MODERN CHANNEL', 'DOH TRI OFFICIAL STORE', 'DOH DVM', 'DOH THREE STORE') THEN 'RGUGA-Digital-Modern'
--                 WHEN a.channel IN ('DOH SAHABAT VIRTUAL') THEN 'RGUGA-Digital-Online'
--                 WHEN a.channel IN ('DOH SIM ONLINE') THEN 'RGUGA-Digital-OLA'
--                 ELSE 'RGUGA-Trad-Outlet'
--     END    
-- 	kpi,
--     vdt_id dt_id 
--     FROM fct_ga_site_id_v3 a
-- 		LEFT JOIN (
--         SELECT DISTINCT retailer_qrcode, ret_type
--         FROM `data-dtptechm-prd-c7ca.dwh`.retailer_hierarchy
--         WHERE periode_data = vdt_id
--     ) b ON a.partner_qr_cd = b.retailer_qrcode 
--  WHERE dt >= TO_CHAR(DATE_TRUNC('month', vdt_id::TEXT::DATE)::DATE, 'yyyymmdd')::INTEGER AND dt <= vdt_id
--  AND (
--             CASE
--                 WHEN a.channel LIKE 'CIRCLE%' THEN
--                     CASE
--                         WHEN b.ret_type = 'D' THEN 'RGUGA-Trad-DSF'
--                         ELSE 'RGUGA-Trad-Outlet'
--                     END
--                 WHEN a.channel = 'DOH POOL' THEN	
--                     CASE
--                         WHEN b.ret_type = 'D' THEN 'RGUGA-Trad-DSF'
--                         ELSE 'RGUGA-Trad-Outlet'
--                     END
--                 WHEN a.channel LIKE '%FWA%' THEN 'RGUGA-FWA'
--                 WHEN a.channel IN ('DOH MODERN CHANNEL', 'DOH TRI OFFICIAL STORE', 'DOH DVM', 'DOH THREE STORE') THEN 'RGUGA-Digital-Modern'
--                 WHEN a.channel IN ('DOH SAHABAT VIRTUAL') THEN 'RGUGA-Digital-Online'
--                 WHEN a.channel IN ('DOH SIM ONLINE') THEN 'RGUGA-Digital-OLA'
--                 ELSE 'RGUGA-Trad-Outlet'
--             END
--         ) IN ('RGUGA-Trad-Outlet', 'RGUGA-Trad-DSF')
--     GROUP BY 1,2,3,5,7,8;