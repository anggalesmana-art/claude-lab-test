   declare vdt_id date default @vdt_id;

    -- ========== SURV_M2 and GA_M2 KPIs ==========
    DELETE FROM `data-bi-prd-935c.bi_dev`.ioh_snd_master_kpi_detail
    WHERE kpi IN ('surv_m2', 'ga_m2') AND dt_id = vdt_id and brand = '3ID';


INSERT INTO `data-bi-prd-935c.bi_dev`.ioh_snd_master_kpi_detail   
    SELECT '3ID' as brand,
    'site_id' level,
    site_id level_value,
    sum(value),
    'mtd' time_flag,
    CURRENT_TIMESTAMP() insert_date,
    CASE WHEN kpi_code = 'M2S_MTD' THEN 'surv_m2' ELSE 'ga_m2' END kpi,
    load_dt_sk_id dt_id 
    FROM
(
select vdt_id as load_dt_sk_id, 'H3I' as entity, 'M2S_MTD' as kpi_code, 'IOH' as definition,
vdt_id as dt, b.site_id, count(distinct a.sbscrptn_ek_id) as value, 'SITE ROLLING 90' as remark, current_date as created_dtm
from 
(
select distinct a.sbscrptn_ek_id
from `data-bi-prd-935c.bi_mart.fct_rgu_ioh_NIK_mstr` a
where tag = 'rgu_daily'
and dt >= DATE_TRUNC(vdt_id, MONTH) and dt <= vdt_id
union distinct
select distinct a.sbscrptn_ek_id
from `data-bi-prd-935c.bi_mart.fct_ioh_rgu_daily_NIK_add` a --changes start on 23 May 2022 (add the daily RGU from this table)
where tag = 'rgu_daily'
and dt >= DATE_TRUNC(vdt_id, MONTH) and dt <= vdt_id
 
union distinct
 
select distinct a.sbscrptn_ek_id
from `data-bi-prd-935c.bi_mart.fct_inc_voice_offnet` a --changes start on 10 Dec 2024 (add the daily RGU from this table)
where dt >= DATE_TRUNC(vdt_id, MONTH) and dt <= vdt_id
) a
join 
(
--Change start 01 Mar 2022 onwards
select distinct sbscrptn_ek_id, site_id
from `data-bi-prd-935c.bi_mart.fct_ga_site_id`
where DATE_TRUNC(dt, MONTH) = DATE_TRUNC(DATE_SUB(vdt_id, INTERVAL 2 MONTH), MONTH)
) b on a.sbscrptn_ek_id = b.sbscrptn_ek_id
group by 1,2,3,4,5,6,8,9
union all 
select vdt_id as laod_dt_sk_id, 'H3I' as entity, 'GA_M2S_MTD' as kpi_code, 'IOH' as definition,
vdt_id as dt, a.site_id, count(distinct a.sbscrptn_ek_id) as value, 'SITE ROLLING 90' as remark, current_date as created_dtm
from 
(
select distinct sbscrptn_ek_id, site_id
from `data-bi-prd-935c.bi_mart.fct_ga_site_id`
where DATE_TRUNC(dt, MONTH) = DATE_TRUNC(DATE_SUB(vdt_id, INTERVAL 2 MONTH), MONTH)
) a
group by 1,2,3,4,5,6,8,9
) b
   GROUP BY 1,2,3,5,7,8;
   
   


    
    
    -- ========== ACQUISITION REVENUE KPI ==========
    DELETE FROM `data-bi-prd-935c.bi_dev`.ioh_snd_master_kpi_detail
    WHERE kpi IN ('acquisition_revenue') AND dt_id = vdt_id and brand = '3ID';
    
    INSERT INTO `data-bi-prd-935c.bi_dev`.ioh_snd_master_kpi_detail   
    SELECT '3ID' as brand,
    'site_id' level,
    site_id level_value,
    CAST(ROUND(SUM(COALESCE(b.rev, 0))) AS NUMERIC) value,
    'mtd' time_flag,
    CURRENT_TIMESTAMP() insert_date,
    'acquisition_revenue' kpi,
    vdt_id dt_id 
    FROM `data-bi-prd-935c.bi_mart.fct_ga_site_id` a 
    LEFT JOIN (
        SELECT DATE_TRUNC(trx_dt_sk_id, MONTH) as mth, 
               sbscrptn_ek_id, 
               SUM(revenue) as rev
        FROM `data-bi-prd-935c.bi_mart.fct_cwn_rev_detail_fnl`
        WHERE trx_dt_sk_id BETWEEN DATE_TRUNC(vdt_id, MONTH) AND vdt_id
        GROUP BY 1,2
    ) b ON DATE_TRUNC(a.dt, MONTH) = b.mth AND a.sbscrptn_ek_id = b.sbscrptn_ek_id
    WHERE a.dt BETWEEN DATE_TRUNC(vdt_id, MONTH) AND vdt_id
    GROUP BY 1,2,3,5,7,8;
    
    -- ========== SDP LIVE KPI ==========
    DELETE FROM `data-bi-prd-935c.bi_dev`.ioh_snd_master_kpi_detail
    WHERE kpi IN ('sdp_live') AND dt_id = vdt_id and brand = '3ID';
    
    INSERT INTO `data-bi-prd-935c.bi_dev`.ioh_snd_master_kpi_detail   
    SELECT '3ID' as brand,
    'partner' level,
    partner level_value,
    1 value,
    'mtd' time_flag,
    CURRENT_TIMESTAMP() insert_date,
    'sdp_live' kpi,
    vdt_id dt_id 
    FROM `data-bi-prd-935c.bi_snd.pre_ref_hirarki_territory_ioh`
    WHERE UPPER(partner) LIKE '%KIOSK%' and brand = '3ID'
      AND parse_date('%Y%m',cast(mth as string)) = DATE_TRUNC(vdt_id, MONTH) 
    GROUP BY 1,2,3,5,7,8;
    
    -- ========== SDP TRX KPI ==========
    DELETE FROM `data-bi-prd-935c.bi_dev`.ioh_snd_master_kpi_detail
    WHERE kpi IN ('sdp_trx') AND dt_id = vdt_id and brand = '3ID';
    
    INSERT INTO `data-bi-prd-935c.bi_dev`.ioh_snd_master_kpi_detail   
    SELECT '3ID' as brand,
    'partner' level,
    partner_id level_value,
    1 value,
    'mtd' time_flag,
    CURRENT_TIMESTAMP() insert_date,
    'sdp_trx' kpi,
    vdt_id dt_id 
    FROM (
        -- First part: Secondary transactions
        SELECT partner_id 
        FROM (
            SELECT DATE_TRUNC(dt_id, MONTH) xmth,
                   dt_id xdt_id, 
                   COALESCE(kabkot_nm,'null') xkabupaten,
                   COALESCE(kecamatan_nm,'null') xkecamatan,
                   kpi_name xkpi_name, 
                   SUM(a.value) xkpi_value
            FROM `data-bi-prd-935c.bi_dev.mis_snd_prisec_detail` a
            LEFT JOIN (
                SELECT ret_qr_cd, site_id 
                FROM (
                    SELECT dt, ret_qr_cd, site_id, 
                           ROW_NUMBER() OVER (PARTITION BY ret_qr_cd ORDER BY dt DESC) rnk
                    FROM `data-bi-prd-935c.bi_mart.stg_v_map_tgt_ret_details_hist`
                    WHERE site_id <> ''
                      AND DATE_TRUNC(dt, MONTH) = DATE_TRUNC(vdt_id, MONTH)
                ) x 
                WHERE rnk = 1
            ) c ON a.qr_code = c.ret_qr_cd
            LEFT JOIN `data-bi-prd-935c.bi_mart.ref_site_h3i` refsite ON c.site_id = refsite.site_id
            WHERE kpi_name = 'secondary'
              AND dt_id = vdt_id 
            GROUP BY 1,2,3,4,5
        ) a 
        LEFT JOIN (
            SELECT parse_date('%Y%m',cast(mth as string)) mth_id, split(kecamatan,'|')[offset(0)] kecamatan, split(kecamatan,'|')[offset(1)] kabkot, partner partner_id
            FROM `data-bi-prd-935c.bi_snd.pre_ref_hirarki_territory_ioh`
            WHERE UPPER(partner) LIKE '%KIOSK%' and brand = '3ID'
              AND parse_date('%Y%m',cast(mth as string)) = DATE_TRUNC(vdt_id, MONTH) 
            GROUP BY 1,2,3,4
        ) b ON a.xkabupaten = b.kabkot AND a.xkecamatan = b.kecamatan
        WHERE b.partner_id IS NOT NULL 
          AND xkpi_value > 0
        GROUP BY 1 
        
        UNION ALL 
        
        -- Second part: Primary transactions
        SELECT b.mp3_id 
        FROM `data-bi-prd-935c.bi_dev.mis_snd_prisec_detail` b
        LEFT JOIN (
            SELECT partner partner_id
            FROM `data-bi-prd-935c.bi_snd.pre_ref_hirarki_territory_ioh`
            WHERE UPPER(partner) LIKE '%KIOSK%' and brand = '3ID'
              AND parse_date('%Y%m',cast(mth as string)) = DATE_TRUNC(vdt_id, MONTH) 
            GROUP BY 1 
        ) c ON b.mp3_id = c.partner_id
        WHERE kpi_name = 'primary'
          AND partner_id IS NOT NULL  
          AND value > 0
          AND dt_id = vdt_id
        GROUP BY 1 
    ) x
    GROUP BY 1,2,3,5,7,8;

    -- ========== SDP 50 SEC KPI ==========
    DELETE FROM `data-bi-prd-935c.bi_dev`.ioh_snd_master_kpi_detail
    WHERE kpi IN ('sdp_50_sec') AND dt_id = vdt_id and brand = '3ID';
    
    INSERT INTO `data-bi-prd-935c.bi_dev`.ioh_snd_master_kpi_detail   
    SELECT '3ID' as brand,
    'partner' level,
    partner_id level_value,
    1 value,
    'mtd' time_flag,
    CURRENT_TIMESTAMP() insert_date,
    'sdp_50_sec' kpi,
    vdt_id dt_id 
    FROM (
        SELECT DATE_TRUNC(dt_id, MONTH) xmth,
               dt_id xdt_id, 
               COALESCE(kabkot_nm,'null') xkabupaten,
               COALESCE(kecamatan_nm,'null') xkecamatan,
               kpi_name xkpi_name, 
               SUM(a.value) xkpi_value
        FROM `data-bi-prd-935c.bi_dev.mis_snd_prisec_detail` a
        LEFT JOIN (
            SELECT ret_qr_cd, site_id 
            FROM (
                SELECT dt, ret_qr_cd, site_id, 
                       ROW_NUMBER() OVER (PARTITION BY ret_qr_cd ORDER BY dt DESC) rnk
                FROM `data-bi-prd-935c.bi_mart.stg_v_map_tgt_ret_details_hist`
                WHERE site_id <> ''
                  AND DATE_TRUNC(dt, MONTH) = DATE_TRUNC(vdt_id, MONTH)
            ) x 
            WHERE rnk = 1
        ) c ON a.qr_code = c.ret_qr_cd
        LEFT JOIN `data-bi-prd-935c.bi_mart.ref_site_h3i` refsite ON c.site_id = refsite.site_id
        WHERE kpi_name = 'secondary'
          AND dt_id = vdt_id
        GROUP BY 1,2,3,4,5
    ) a 
    LEFT JOIN (
        SELECT parse_date('%Y%m',cast(mth as string)) mth_id, split(kecamatan,'|')[offset(0)] kecamatan, split(kecamatan,'|')[offset(1)] kabkot, partner partner_id
        FROM `data-bi-prd-935c.bi_snd.pre_ref_hirarki_territory_ioh`
        WHERE UPPER(partner) LIKE '%KIOSK%' and brand = '3ID'
          AND parse_date('%Y%m',cast(mth as string)) = DATE_TRUNC(vdt_id, MONTH) 
        GROUP BY 1,2,3,4
    ) b ON a.xkabupaten = b.kabkot AND a.xkecamatan = b.kecamatan
    WHERE b.partner_id IS NOT NULL 
      AND xkpi_value >= 50000000 
    GROUP BY 1,2,3,5,7,8;

    -- ========== SDP 350 GA KPI ==========
    DELETE FROM `data-bi-prd-935c.bi_dev`.ioh_snd_master_kpi_detail
    WHERE kpi IN ('sdp_350_ga') AND dt_id = vdt_id and brand = '3ID';
    
    INSERT INTO `data-bi-prd-935c.bi_dev`.ioh_snd_master_kpi_detail  
    SELECT '3ID' as brand,
    'partner' level,
    partner level_value,
    1 value,
    'mtd' time_flag,
    CURRENT_TIMESTAMP() insert_date,
    'sdp_350_ga',
    vdt_id dt_id 
    FROM `data-bi-prd-935c.bi_mart.fct_ga_site_id_v3` a
    LEFT JOIN `data-bi-prd-935c.bi_mart.ref_site_h3i` b ON a.site_id = b.site_id 
    JOIN `data-bi-prd-935c.bi_snd.pre_ref_hirarki_territory_ioh` c ON (b.kecamatan_nm||'|'||b.kabkot_nm) = c.kecamatan 
                                      AND LOWER(c.partner) LIKE '%kiosk%' and brand = '3ID' 
                                      AND parse_date('%Y%m',cast(c.mth as string)) = DATE_TRUNC(dt, MONTH)
    WHERE dt >= DATE_TRUNC(vdt_id, MONTH) AND dt <= vdt_id
      AND CASE
            WHEN channel LIKE 'CIRCLE%' THEN 'RGUGA_Trade'
            WHEN channel = 'DOH POOL' THEN 'RGUGA_Trade'
            WHEN channel LIKE '%FWA%' THEN 'RGUGA-FWA'
            WHEN channel IN ('DOH MODERN CHANNEL','DOH TRI OFFICIAL STORE','DOH DVM','DOH THREE STORE') 
                THEN 'RGUGA-Digital-Modern'
            WHEN channel IN ('DOH SAHABAT VIRTUAL') THEN 'RGUGA-Digital-Online'
            WHEN channel IN ('DOH SIM ONLINE') THEN 'RGUGA-Digital-OLA'
            ELSE 'RGUGA_Trade'
          END = 'RGUGA_Trade'
    GROUP BY 1,2,3,5,7,8 
    HAVING COUNT(*) >= 350;

    -- ========== TOTAL OUTLET KPI ==========
    DELETE FROM `data-bi-prd-935c.bi_dev`.ioh_snd_master_kpi_detail
    WHERE kpi IN ('total_outlet') AND dt_id = vdt_id and brand = '3ID';
    
    INSERT INTO `data-bi-prd-935c.bi_dev`.ioh_snd_master_kpi_detail   
    SELECT '3ID' as brand,
    'outlet' level,
    a.retailer_qrcode level_value,
    1 value,
    'mtd' time_flag,
    CURRENT_TIMESTAMP() insert_date,
    'total_outlet' kpi,
    periode_data dt_id 
    FROM  `data-dtptechm-prd-c7ca.dwh`.retailer_hierarchy a 
    JOIN  `data-dtptechm-prd-c7ca.dwh`.angie_hrchy_dim b ON a.retailer_qrcode = b.partner_qr_cd AND b.hrchy_type = 'Retailer' 
    LEFT JOIN (SELECT * FROM  `data-dtptechm-prd-c7ca.dwh`.angie_hrchy_dim WHERE hrchy_type = 'RSH') c ON b.rsh_id = c.rsh_id 
    WHERE periode_data = vdt_id 
      AND trx_type = 'Owner'
      AND LOWER(retailer_outlet_name) NOT LIKE '%dsf%'
      AND c.rsh_name NOT IN ('POOL RSH','EDWIN WAHYUDIN','RSHLIVE','RSH CIGNIFY','RSH TEST','RSH FWA') 
    GROUP BY 1,2,3,5,7,8;

    -- ========== TOTAL PJP OUTLET KPI ==========
    DELETE FROM `data-bi-prd-935c.bi_dev`.ioh_snd_master_kpi_detail
    WHERE kpi IN ('total_pjp_outlet') AND dt_id = vdt_id and brand = '3ID';
    
    INSERT INTO `data-bi-prd-935c.bi_dev`.ioh_snd_master_kpi_detail   
    SELECT '3ID' as brand,
    'outlet' level,
    a.retailer_qrcode level_value,
    1 value,
    'mtd' time_flag,
    CURRENT_TIMESTAMP() insert_date,
    'total_pjp_outlet' kpi,
    vdt_id dt_id 
    FROM `data-bi-prd-935c.bi_snd.pre_ref_outlet_mapping_3id` a 
    WHERE parse_date('%Y%m',cast(mth_id as string)) = DATE_TRUNC(vdt_id, MONTH)
    GROUP BY 1,2,3,5,7,8;

    -- ========== URO PJP and SSO PJP KPIs ==========
    DELETE FROM `data-bi-prd-935c.bi_dev`.ioh_snd_master_kpi_detail
    WHERE kpi IN ('sso_pjp') AND dt_id = vdt_id and brand = '3ID';
    
    -- SSO PJP
    INSERT INTO `data-bi-prd-935c.bi_dev`.ioh_snd_master_kpi_detail   
    SELECT '3ID' as brand,
    'site_id' level,
    x.site_id level_value,
    COUNT(DISTINCT a.partner_qr_cd) value,
    'mtd' time_flag,
    CURRENT_TIMESTAMP() insert_date,
    'sso_pjp' kpi,
    vdt_id dt_id 
    FROM `data-bi-prd-935c.bi_mart.fct_ga_site_id_v3` a 
    INNER JOIN (
        SELECT 
            parse_date('%Y%m',cast(mth_id as string)) AS mth_id,
            retailer_qrcode AS qr_code,
            mp3_name AS partner_name,
            branch,
            se_partnerid AS dse_code
        FROM `data-bi-prd-935c.bi_snd.pre_ref_outlet_mapping_3id` b
        WHERE parse_date('%Y%m',cast(mth_id as string)) = DATE_TRUNC(vdt_id, MONTH)
    ) b ON DATE_TRUNC(a.dt, MONTH) = b.mth_id AND a.partner_qr_cd = b.qr_code
    LEFT JOIN `data-bi-prd-935c.bi_mart.stg_v_map_tgt_ret_details_hist` x ON a.dt = x.dt AND a.partner_qr_cd = x.ret_qr_cd  
    WHERE a.dt >= DATE_TRUNC(vdt_id, MONTH) AND a.dt <= vdt_id
    GROUP BY 1,2,3,5,7,8;

 -- SSO PJP
    INSERT INTO `data-bi-prd-935c.bi_dev`.ioh_snd_master_kpi_detail   
    SELECT '3ID' as brand,
    'outlet' level,
    a.partner_qr_cd level_value,
    COUNT(DISTINCT a.partner_qr_cd) value,
    'mtd' time_flag,
    CURRENT_TIMESTAMP() insert_date,
    'sso_pjp' kpi,
    vdt_id dt_id 
    FROM `data-bi-prd-935c.bi_mart.fct_ga_site_id_v3` a 
    INNER JOIN (
        SELECT 
            parse_date('%Y%m',cast(mth_id as string)) AS mth_id,
            retailer_qrcode AS qr_code,
            mp3_name AS partner_name,
            branch,
            se_partnerid AS dse_code
        FROM `data-bi-prd-935c.bi_snd.pre_ref_outlet_mapping_3id` b
        WHERE parse_date('%Y%m',cast(mth_id as string)) = DATE_TRUNC(vdt_id, MONTH)
    ) b ON DATE_TRUNC(a.dt, MONTH) = b.mth_id AND a.partner_qr_cd = b.qr_code
    LEFT JOIN `data-bi-prd-935c.bi_mart.stg_v_map_tgt_ret_details_hist` x ON a.dt = x.dt AND a.partner_qr_cd = x.ret_qr_cd  
    WHERE a.dt >= DATE_TRUNC(vdt_id, MONTH) AND a.dt <= vdt_id
    GROUP BY 1,2,3,5,7,8;



DELETE FROM `data-bi-prd-935c.bi_dev`.ioh_snd_master_kpi_detail
    WHERE kpi IN ('mobo_rev_trad') AND dt_id = vdt_id and brand = '3ID';
    
    INSERT INTO `data-bi-prd-935c.bi_dev`.ioh_snd_master_kpi_detail  
    SELECT '3ID' as brand,
    'kecamatan' level,
    kab_kec_favloc level_value,
    cast(round(sum(netrevenue)*1.11) as NUMERIC) value,
    'mtd' time_flag,
    CURRENT_TIMESTAMP() insert_date,
    'mobo_rev_trad',vdt_id
from 
`data-analytics-prd-1b95.analytics.mkt_product_next_level_report_final_v3` where 
case when kpi_3 in ('EVC_BROADBAND') then 'MOBO-NON TRADE'
	when channel_wise in ('RITA') then 'MOBO-TRADE'
	when channel_wise in ('SP/SIM') then 'MOBO-TRADE'
	when channel_wise in ('VOUCHER/SPV') then 'MOBO-TRADE'
	else 'ORGANIC' end ='MOBO-TRADE'  
and trx_dt_sk_id between DATE_TRUNC(vdt_id, MONTH) and vdt_id
        GROUP BY 1,2,3,5,7,8  ;

  DELETE FROM `data-bi-prd-935c.bi_dev`.ioh_snd_master_kpi_detail
    WHERE kpi IN ('sso_all') AND dt_id = vdt_id and brand = '3ID';
  
    INSERT INTO `data-bi-prd-935c.bi_dev`.ioh_snd_master_kpi_detail   
    SELECT '3ID' as brand,
    'site_id' level,
    x.site_id level_value,
    COUNT(DISTINCT a.partner_qr_cd) value,
    'mtd' time_flag,
    CURRENT_TIMESTAMP() insert_date,
    'sso_all' kpi,
    vdt_id dt_id 
    FROM `data-bi-prd-935c.bi_mart.fct_ga_site_id_v3` a 
    LEFT JOIN `data-bi-prd-935c.bi_mart.stg_v_map_tgt_ret_details_hist` x ON a.dt = x.dt AND a.partner_qr_cd = x.ret_qr_cd  
    WHERE a.dt >= DATE_TRUNC(vdt_id, MONTH) AND a.dt <= vdt_id
    GROUP BY 1,2,3,5,7,8;

 -- SSO PJP
    INSERT INTO `data-bi-prd-935c.bi_dev`.ioh_snd_master_kpi_detail   
    SELECT '3ID' as brand,
    'outlet' level,
    a.partner_qr_cd level_value,
    COUNT(DISTINCT a.partner_qr_cd) value,
    'mtd' time_flag,
    CURRENT_TIMESTAMP() insert_date,
    'sso_all' kpi,
    vdt_id dt_id 
    FROM `data-bi-prd-935c.bi_mart.fct_ga_site_id_v3` a 
    LEFT JOIN `data-bi-prd-935c.bi_mart.stg_v_map_tgt_ret_details_hist` x ON a.dt = x.dt AND a.partner_qr_cd = x.ret_qr_cd  
    WHERE a.dt  >= DATE_TRUNC(vdt_id, MONTH) AND a.dt <= vdt_id
    GROUP BY 1,2,3,5,7,8;
    
    


DELETE FROM `data-bi-prd-935c.bi_dev`.ioh_snd_master_kpi_detail
WHERE kpi IN
(
'site_3qsso_new'
) 
 AND dt_id = vdt_id and brand = '3ID';


    INSERT INTO `data-bi-prd-935c.bi_dev`.ioh_snd_master_kpi_detail 
-- This CTE first calculates the number of gross adds (GAGA) for each outlet for the month.
WITH outlet_monthly_gaga AS (
    SELECT
       coalesce(a.book_qrcode_final, a.partner_qr_cd) partner_qr_cd, --  a.partner_qr_cd,
        count(DISTINCT a.sbscrptn_ek_id) AS gaga_count
    FROM `data-bi-prd-935c.bi_mart.snd_rgu_ga_new_detail` a
    INNER JOIN (
        SELECT DISTINCT retailer_qrcode, parse_date('%Y%m',cast(mth_id as string)) mth_id
        FROM `data-bi-prd-935c.bi_snd.pre_ref_outlet_mapping_3id`
        WHERE parse_date('%Y%m',cast(mth_id as string)) = DATE_TRUNC(vdt_id, MONTH)
    ) b ON CAST(b.retailer_qrcode AS STRING) = CAST(coalesce(a.book_qrcode_final, a.partner_qr_cd)AS STRING)
    WHERE
        a.load_dt_sk_id BETWEEN DATE_TRUNC(vdt_id, MONTH) AND vdt_id
    GROUP BY coalesce(a.book_qrcode_final, a.partner_qr_cd)
),
-- This CTE identifies all outlets that are "qualified" (gaga_count >= 3) and gets their site_id.
qualified_outlets_with_site AS (
    SELECT
        a.partner_qr_cd,
        c.site_id
    FROM outlet_monthly_gaga a
    LEFT JOIN `data-bi-prd-935c.bi_stg.tmp_nbs` c ON a.partner_qr_cd = c.ret_qr_cd
    WHERE a.gaga_count >= 3
),
-- This CTE counts the number of qualified outlets for each site.
sites_with_qualified_outlet_counts AS (
    SELECT
        site_id,
        count(DISTINCT partner_qr_cd) AS qualified_outlet_count
    FROM qualified_outlets_with_site
    GROUP BY site_id
),
-- This CTE gets the list of all "addressable sites" for the month.
addressable_sites AS (
    SELECT DISTINCT
        coalesce(site_id, site_id_old) AS site_id
    FROM `data-bi-prd-935c.bi_snd.pre_ref_nshim3_addrsite_gtm_mth`
    WHERE
        parse_date('%Y%m',cast(mth as string)) = DATE_TRUNC(vdt_id, MONTH)
        AND addressable_type = 'ADDRESSABLE SITE' and list_3id='Y'
)
-- The final SELECT inserts a row for each site that meets all criteria:
-- it's addressable, and it has at least 3 qualified outlets.
SELECT DISTINCT
    '3ID' AS brand_id,
    'site_id' AS level_id,
    coalesce(qsoc.site_id, 'null') AS level_value,
    1 AS kpi_value,
    'mtd' AS period_type,
    CURRENT_TIMESTAMP() AS uVDate_dttm,
    'site_3qsso_new' AS kpi_name,
    vdt_id AS dt_id
FROM sites_with_qualified_outlet_counts qsoc
INNER JOIN addressable_sites ads ON qsoc.site_id = ads.site_id
WHERE qsoc.qualified_outlet_count >= 3;


 DELETE FROM `data-bi-prd-935c.bi_dev`.ioh_snd_master_kpi_detail
    WHERE kpi IN ('sso_all_dly') AND dt_id = vdt_id and brand = '3ID';
    
  
 
  -- SSO PJP
    INSERT INTO `data-bi-prd-935c.bi_dev`.ioh_snd_master_kpi_detail   
    SELECT '3ID' as brand,
    'site_id' level,
    x.site_id level_value,
    COUNT(DISTINCT a.partner_qr_cd) value,
    'dly' time_flag,
    CURRENT_TIMESTAMP() insert_date,
    'sso_all_dly' kpi,
    vdt_id dt_id 
    FROM `data-bi-prd-935c.bi_mart.fct_ga_site_id_v3` a 
    LEFT JOIN `data-bi-prd-935c.bi_mart.stg_v_map_tgt_ret_details_hist` x ON a.dt = x.dt AND a.partner_qr_cd = x.ret_qr_cd  
    WHERE a.dt= vdt_id
    GROUP BY 1,2,3,5,7,8;

 -- SSO PJP
    INSERT INTO `data-bi-prd-935c.bi_dev`.ioh_snd_master_kpi_detail   
    SELECT '3ID' as brand,
    'outlet' level,
    a.partner_qr_cd level_value,
    COUNT(DISTINCT a.partner_qr_cd) value,
    'dly' time_flag,
    CURRENT_TIMESTAMP() insert_date,
    'sso_all_dly' kpi,
    vdt_id dt_id 
    FROM `data-bi-prd-935c.bi_mart.fct_ga_site_id_v3` a 
    LEFT JOIN `data-bi-prd-935c.bi_mart.stg_v_map_tgt_ret_details_hist` x ON a.dt = x.dt AND a.partner_qr_cd = x.ret_qr_cd  
    WHERE  a.dt= vdt_id
    GROUP BY 1,2,3,5,7,8;


   
    -- ========== SURV_M2 and GA_M2 KPIs ==========
    DELETE FROM `data-bi-prd-935c.bi_dev`.ioh_snd_master_kpi_detail
    WHERE kpi IN ('surv_m2_trad') AND dt_id = vdt_id and brand = '3ID';
	
	INSERT INTO `data-bi-prd-935c.bi_dev`.ioh_snd_master_kpi_detail   
    SELECT '3ID' as brand,
    'site_id' level,
    site_id level_value,
    sum(value),
    'mtd' time_flag,
    CURRENT_TIMESTAMP() insert_date,
    CASE WHEN kpi_code = 'M2S_MTD' THEN 'surv_m2_trad' ELSE 'ga_m2' END kpi,
    load_dt_sk_id dt_id 
    FROM
(

select vdt_id as load_dt_sk_id, 'H3I' as entity, 'M2S_MTD' as kpi_code, 'IOH' as definition,
vdt_id as dt, b.site_id, count(distinct a.sbscrptn_ek_id) as value, 'SITE ROLLING 90' as remark, current_date as created_dtm
from 
(
 select distinct a.sbscrptn_ek_id
 from `data-bi-prd-935c.bi_mart.fct_rgu_ioh_NIK_mstr` a
 where tag = 'rgu_daily'
 and dt >= DATE_TRUNC(vdt_id, MONTH) and dt <= vdt_id

 union distinct

 select distinct a.sbscrptn_ek_id
 from `data-bi-prd-935c.bi_mart.fct_ioh_rgu_daily_NIK_add` a --changes start on 23 May 2022 (add the daily RGU from this table)
 where tag = 'rgu_daily'
 and dt >= DATE_TRUNC(vdt_id, MONTH) and dt <= vdt_id
) a
join 
(
 --Change start 01 Mar 2022 onwards
 select distinct sbscrptn_ek_id, site_id
 from `data-bi-prd-935c.bi_mart.fct_ga_site_id_v3`
 where DATE_TRUNC(dt, MONTH) = DATE_TRUNC(DATE_SUB(vdt_id, INTERVAL 2 MONTH), MONTH)
and 
CASE
        WHEN channel LIKE 'CIRCLE%' THEN 'RGUGA_Trade'
        WHEN channel = 'DOH POOL' THEN 'RGUGA_Trade'
        WHEN channel LIKE '%FWA%' THEN 'RGUGA-FWA'
        WHEN channel IN ('DOH MODERN CHANNEL','DOH TRI OFFICIAL STORE','DOH DVM','DOH THREE STORE') 
            THEN 'RGUGA-Digital-Modern'
        WHEN channel IN ('DOH SAHABAT VIRTUAL') THEN 'RGUGA-Digital-Online'
        WHEN channel IN ('DOH SIM ONLINE') THEN 'RGUGA-Digital-OLA'
        ELSE 'RGUGA_Trade'
    end ='RGUGA_Trade' 
 
 ) b on a.sbscrptn_ek_id = b.sbscrptn_ek_id
group by 1,2,3,4,5,6,8,9
) b
   GROUP BY 1,2,3,5,7,8; 


    -- ========== SURV_M2 and GA_M2 KPIs ==========
    DELETE FROM `data-bi-prd-935c.bi_dev`.ioh_snd_master_kpi_detail
    WHERE kpi IN ('surv_m2_nontrad') AND dt_id = vdt_id and brand = '3ID';
    
  INSERT INTO `data-bi-prd-935c.bi_dev`.ioh_snd_master_kpi_detail   
    SELECT '3ID' as brand,
    'site_id' level,
    site_id level_value,
    sum(value),
    'mtd' time_flag,
    CURRENT_TIMESTAMP() insert_date,
    CASE WHEN kpi_code = 'M2S_MTD' THEN 'surv_m2_nontrad' ELSE 'ga_m2' END kpi,
    load_dt_sk_id dt_id 
    FROM
(

select vdt_id as load_dt_sk_id, 'H3I' as entity, 'M2S_MTD' as kpi_code, 'IOH' as definition,
vdt_id as dt, b.site_id, count(distinct a.sbscrptn_ek_id) as value, 'SITE ROLLING 90' as remark, current_date as created_dtm
from 
(
 select distinct a.sbscrptn_ek_id
 from `data-bi-prd-935c.bi_mart.fct_rgu_ioh_NIK_mstr` a
 where tag = 'rgu_daily'
 and dt >= DATE_TRUNC(vdt_id, MONTH) and dt <= vdt_id

 union distinct

 select distinct a.sbscrptn_ek_id
 from `data-bi-prd-935c.bi_mart.fct_ioh_rgu_daily_NIK_add` a --changes start on 23 May 2022 (add the daily RGU from this table)
 where tag = 'rgu_daily'
 and dt >= DATE_TRUNC(vdt_id, MONTH) and dt <= vdt_id
 
) a
join 
(
 --Change start 01 Mar 2022 onwards
 select distinct sbscrptn_ek_id, site_id
 from `data-bi-prd-935c.bi_mart.fct_ga_site_id_v3`
 where DATE_TRUNC(dt, MONTH) = DATE_TRUNC(DATE_SUB(vdt_id, INTERVAL 2 MONTH), MONTH)
and 
CASE
        WHEN channel LIKE 'CIRCLE%' THEN 'RGUGA_Trade'
        WHEN channel = 'DOH POOL' THEN 'RGUGA_Trade'
        WHEN channel LIKE '%FWA%' THEN 'RGUGA-FWA'
        WHEN channel IN ('DOH MODERN CHANNEL','DOH TRI OFFICIAL STORE','DOH DVM','DOH THREE STORE') 
            THEN 'RGUGA-Digital-Modern'
        WHEN channel IN ('DOH SAHABAT VIRTUAL') THEN 'RGUGA-Digital-Online'
        WHEN channel IN ('DOH SIM ONLINE') THEN 'RGUGA-Digital-OLA'
        ELSE 'RGUGA_Trade'
    end <>'RGUGA_Trade' 
 
 ) b on a.sbscrptn_ek_id = b.sbscrptn_ek_id
group by 1,2,3,4,5,6,8,9
) b
   GROUP BY 1,2,3,5,7,8; 


-- ========== ACQUISITION REVENUE KPI - TRADE ==========
        DELETE FROM `data-bi-prd-935c.bi_dev`.ioh_snd_master_kpi_detail
        WHERE kpi IN ('ga_m2_trad') AND dt_id =vdt_id and brand = '3ID';

        -- Daily rgu_ga by site_id (general) - TRADE
        INSERT INTO `data-bi-prd-935c.bi_dev`.ioh_snd_master_kpi_detail
        SELECT 
            brand,
            level,
            level_value,
            SUM(values),
            'mtd' AS time_flag,
            CURRENT_TIMESTAMP(),
            'ga_m2_trad',
            vdt_id  AS dt_id
        FROM `data-bi-prd-935c.bi_dev`.ioh_snd_master_kpi_detail
        WHERE time_flag = 'mtd'
            AND dt_id = LAST_DAY(DATE_SUB(vdt_id, INTERVAL 2 MONTH), MONTH)
            AND level = 'site_id'
            AND kpi = 'RGUGA_Trade' and brand = '3ID'
        GROUP BY brand, level, level_value, kpi;
 
 
 DELETE FROM `data-bi-prd-935c.bi_dev`.ioh_snd_master_kpi_detail
        WHERE kpi IN ('ga_m2_nontrad') AND dt_id = vdt_id and brand = '3ID';

        -- Daily rgu_ga by site_id (general) - NON-TRADE
        INSERT INTO `data-bi-prd-935c.bi_dev`.ioh_snd_master_kpi_detail
        SELECT 
            brand,
            level,
            level_value,
            SUM(values),
            'mtd' AS time_flag,
            CURRENT_TIMESTAMP(),
            'ga_m2_nontrad' AS kpi,
            vdt_id AS dt_id
        FROM `data-bi-prd-935c.bi_dev`.ioh_snd_master_kpi_detail
        WHERE time_flag = 'mtd'
            AND dt_id = LAST_DAY(DATE_SUB(vdt_id, INTERVAL 2 MONTH), MONTH)
            AND level = 'site_id'
            AND kpi IN ('RGUGA-FWA', 'RGUGA-Digital-Modern', 'RGUGA-Digital-Online', 'RGUGA-Digital-OLA') and brand = '3ID'
        GROUP BY brand, level, level_value;

