
    declare vdt_id date default @vdt_id;   

DELETE FROM `data-bi-prd-935c.bi_dev`.ioh_snd_master_kpi_detail
WHERE lower(kpi) IN (
'rgu_ga_trad_noinj',
'rgu_ga_trad_lvc',
'rgu_ga_trad_mvc',
'rgu_ga_trad_hvc',
'rgu_ga_trad_spdemo',
'rgu_ga_trad_sp3gb'
) 
 AND dt_id = vdt_id AND brand = '3ID';


INSERT INTO `data-bi-prd-935c.bi_dev`.ioh_snd_master_kpi_detail 
WITH rgu_ga_trad_data AS (
    SELECT
        vdt_id,
        coalesce(a.site_id, 'null') AS site_id,
        a.flag_type,
        a.call_plan,
        a.channel,
        b.ret_type,
        a.sbscrptn_ek_id
    FROM `data-bi-prd-935c.bi_mart.snd_rgu_ga_new_detail` a
    LEFT JOIN (
        SELECT DISTINCT retailer_qrcode, ret_type
        FROM `data-dtptechm-prd-c7ca.dwh.retailer_hierarchy`
        WHERE periode_data = vdt_id
    ) b ON a.partner_qr_cd = b.retailer_qrcode
    WHERE
        a.load_dt_sk_id BETWEEN DATE_TRUNC(vdt_id, MONTH) AND vdt_id
        AND (
            CASE
                WHEN a.channel LIKE 'CIRCLE%' THEN
                    CASE
                        WHEN b.ret_type = 'D' THEN 'RGUGA-Trad-DSF'
                        ELSE 'RGUGA-Trad-Outlet'
                    END
                WHEN a.channel = 'DOH POOL' THEN	
                    CASE
                        WHEN b.ret_type = 'D' THEN 'RGUGA-Trad-DSF'
                        ELSE 'RGUGA-Trad-Outlet'
                    END
                WHEN a.channel LIKE '%FWA%' THEN 'RGUGA-FWA'
                WHEN a.channel IN ('DOH MODERN CHANNEL', 'DOH TRI OFFICIAL STORE', 'DOH DVM', 'DOH THREE STORE') THEN 'RGUGA-Digital-Modern'
                WHEN a.channel IN ('DOH SAHABAT VIRTUAL') THEN 'RGUGA-Digital-Online'
                WHEN a.channel IN ('DOH SIM ONLINE') THEN 'RGUGA-Digital-OLA'
                ELSE 'RGUGA-Trad-Outlet'
            END
        ) IN ('RGUGA-Trad-Outlet', 'RGUGA-Trad-DSF')
)
SELECT * FROM (
    -- rgu_ga_trad_noinj
    SELECT
        '3ID' AS brand_id,
        'site_id' AS level_id,
        site_id AS level_value,
        COUNT(DISTINCT CASE WHEN flag_type = 'NO INJ' THEN sbscrptn_ek_id END) AS kpi_value,
        'mtd' AS period_type,
        CURRENT_TIMESTAMP() AS uVDate_dttm,
        'rgu_ga_trad_noinj' AS kpi_name,
        vdt_id AS dt_id
    FROM rgu_ga_trad_data
    GROUP BY dt_id, site_id
    
    UNION ALL

    -- rgu_ga_trad_lvc
    SELECT
        '3ID' AS brand_id,
        'site_id' AS level_id,
        site_id AS level_value,
        COUNT(DISTINCT CASE WHEN flag_type = 'LVC' THEN sbscrptn_ek_id END) AS kpi_value,
        'mtd' AS period_type,
        CURRENT_TIMESTAMP() AS uVDate_dttm,
        'rgu_ga_trad_lvc' AS kpi_name,
        vdt_id AS dt_id
    FROM rgu_ga_trad_data
    GROUP BY dt_id, site_id
    
    UNION ALL

    -- rgu_ga_trad_mvc
    SELECT
        '3ID' AS brand_id,
        'site_id' AS level_id,
        site_id AS level_value,
        COUNT(DISTINCT CASE WHEN flag_type = 'MVC' THEN sbscrptn_ek_id END) AS kpi_value,
        'mtd' AS period_type,
        CURRENT_TIMESTAMP() AS uVDate_dttm,
        'rgu_ga_trad_mvc' AS kpi_name,
        vdt_id AS dt_id
    FROM rgu_ga_trad_data
    GROUP BY dt_id, site_id
    
    UNION ALL

    -- rgu_ga_trad_hvc
    SELECT
        '3ID' AS brand_id,
        'site_id' AS level_id,
        site_id AS level_value,
        COUNT(DISTINCT CASE WHEN flag_type = 'HVC' THEN sbscrptn_ek_id END) AS kpi_value,
        'mtd' AS period_type,
        CURRENT_TIMESTAMP() AS uVDate_dttm,
        'rgu_ga_trad_hvc' AS kpi_name,
        vdt_id AS dt_id
    FROM rgu_ga_trad_data
    GROUP BY dt_id, site_id
    
    UNION ALL

    -- rgu_ga_trad_spdemo
    SELECT
        '3ID' AS brand_id,
        'site_id' AS level_id,
        site_id AS level_value,
        COUNT(DISTINCT CASE WHEN trim(upper(call_plan)) = 'SP DEMO' THEN sbscrptn_ek_id END) AS kpi_value,
        'mtd' AS period_type,
        CURRENT_TIMESTAMP() AS uVDate_dttm,
        'rgu_ga_trad_spdemo' AS kpi_name,
        vdt_id AS dt_id
    FROM rgu_ga_trad_data
    GROUP BY dt_id, site_id
    
    UNION ALL

    -- rgu_ga_trad_sp3gb
    SELECT
        '3ID' AS brand_id,
        'site_id' AS level_id,
        site_id AS level_value,
        COUNT(DISTINCT CASE WHEN trim(upper(call_plan)) LIKE 'SP HAPPY 3GB 30D%' THEN sbscrptn_ek_id END) AS kpi_value,
        'mtd' AS period_type,
        CURRENT_TIMESTAMP() AS uVDate_dttm,
        'rgu_ga_trad_sp3gb' AS kpi_name,
        vdt_id AS dt_id
    FROM rgu_ga_trad_data
    GROUP BY dt_id, site_id

) AS combined_results;



DELETE FROM `data-bi-prd-935c.bi_dev`.ioh_snd_master_kpi_detail
WHERE lower(kpi) IN ('rgu_ga_new_noinj','rgu_ga_new_lvc','rgu_ga_new_mvc','rgu_ga_new_hvc','rgu_ga_new_sp_happy') AND dt_id = vdt_id AND brand = '3ID';




INSERT INTO `data-bi-prd-935c.bi_dev`.ioh_snd_master_kpi_detail 
SELECT * FROM (
    -- rgu_ga_new_noinj
    SELECT
        '3ID' AS brand_id,
        'site_id' AS level_id,
        coalesce(site_id, 'null') AS level_value,
        SUM(CASE WHEN flag_type = 'NO INJ' THEN 1 ELSE 0 END) AS kpi_value,
        'mtd' AS period_type,
        CURRENT_TIMESTAMP() AS uVDate_dttm,
        'rgu_ga_new_noinj' AS kpi_name,
        vdt_id AS dt_id
    FROM `data-bi-prd-935c.bi_mart.snd_rgu_ga_new_detail`
    WHERE load_dt_sk_id BETWEEN DATE_TRUNC(vdt_id, MONTH) AND vdt_id
        GROUP BY dt_id, site_id

    UNION ALL

    -- rgu_ga_new_lvc
    SELECT
        '3ID' AS brand_id,
        'site_id' AS level_id,
        coalesce(site_id, 'null') AS level_value,
        SUM(CASE WHEN flag_type = 'LVC' THEN 1 ELSE 0 END) AS kpi_value,
        'mtd' AS period_type,
        CURRENT_TIMESTAMP() AS uVDate_dttm,
        'rgu_ga_new_lvc' AS kpi_name,
        vdt_id AS dt_id
    FROM `data-bi-prd-935c.bi_mart.snd_rgu_ga_new_detail`
    WHERE load_dt_sk_id BETWEEN DATE_TRUNC(vdt_id, MONTH) AND vdt_id
        GROUP BY dt_id, site_id

    UNION ALL

    -- rgu_ga_new_mvc
    SELECT
        '3ID' AS brand_id,
        'site_id' AS level_id,
        coalesce(site_id, 'null') AS level_value,
        SUM(CASE WHEN flag_type = 'MVC' THEN 1 ELSE 0 END) AS kpi_value,
        'mtd' AS period_type,
        CURRENT_TIMESTAMP() AS uVDate_dttm,
        'rgu_ga_new_mvc' AS kpi_name,
        vdt_id AS dt_id
    FROM `data-bi-prd-935c.bi_mart.snd_rgu_ga_new_detail`
    WHERE load_dt_sk_id BETWEEN DATE_TRUNC(vdt_id, MONTH) AND vdt_id
        GROUP BY dt_id, site_id
    
    UNION ALL

    -- rgu_ga_new_hvc
    SELECT
        '3ID' AS brand_id,
        'site_id' AS level_id,
        coalesce(site_id, 'null') AS level_value,
        SUM(CASE WHEN flag_type = 'HVC' THEN 1 ELSE 0 END) AS kpi_value,
        'mtd' AS period_type,
        CURRENT_TIMESTAMP() AS uVDate_dttm,
        'rgu_ga_new_hvc' AS kpi_name,
        vdt_id AS dt_id
    FROM `data-bi-prd-935c.bi_mart.snd_rgu_ga_new_detail`
    WHERE load_dt_sk_id BETWEEN DATE_TRUNC(vdt_id, MONTH) AND vdt_id
        GROUP BY dt_id, site_id
    
    UNION ALL

    -- rgu_ga_new_sp_happy
    SELECT
        '3ID' AS brand_id,
        'site_id' AS level_id,
        coalesce(site_id, 'null') AS level_value,
        SUM(CASE WHEN trim(upper(call_plan)) = 'SP HAPPY PLUS' THEN 1 ELSE 0 END) AS kpi_value,
        'mtd' AS period_type,
        CURRENT_TIMESTAMP() AS uVDate_dttm,
        'rgu_ga_new_sp_happy' AS kpi_name,
        vdt_id AS dt_id
    FROM `data-bi-prd-935c.bi_mart.snd_rgu_ga_new_detail`
    WHERE load_dt_sk_id BETWEEN DATE_TRUNC(vdt_id, MONTH) AND vdt_id
        GROUP BY dt_id, site_id
)x ;


--Running in subscriber load_b
-- DELETE FROM `data-bi-prd-935c.bi_dev`.ioh_snd_master_kpi_detail
-- where kpi in ('GA Subs (above IDR 35k)', 'GA Subs (below IDR 35k)', 'Acq Rev (above IDR 35k)',  'Acq Rev (below IDR 35k)','Acq_Rev_Excl_VchrGames')
-- and time_flag ='mtd' 
-- AND dt_id = vdt_id and level='site_id' and brand = '3ID';
   

-- insert into `data-bi-prd-935c.bi_dev`.ioh_snd_master_kpi_detail
-- select brand
-- ,level
-- ,level_value
-- ,sum(values)
-- ,'mtd' time_flag
-- ,CURRENT_TIMESTAMP()
-- ,kpi ,
-- vdt_id AS dt_id
-- from `data-bi-prd-935c.bi_dev`.ioh_snd_master_kpi_detail
-- WHERE dt_id >= DATE_TRUNC(vdt_id, MONTH) AND dt_id <= vdt_id
-- and kpi in ('GA Subs (above IDR 35k)', 'GA Subs (below IDR 35k)', 'Acq Rev (above IDR 35k)',  'Acq Rev (below IDR 35k)','Acq_Rev_Excl_VchrGames')
-- and time_flag ='dly' 
--  GROUP BY 1,2,3,5,7,8;
