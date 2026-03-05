declare vdt_id date default @vdt_id;

    -- ================================
    -- Modified DSE Meet GA Target KPI Processing
    -- (Individual DSE Level with Binary Flag)
    -- ================================

    -- Clean up existing DSE Meet GA Target data
    DELETE FROM `data-bi-prd-935c.bi_dev`.ioh_snd_master_kpi_detail
    WHERE brand = '3ID' and kpi IN ('dse_meet_ga_tgt') 
      AND dt_id = vdt_id;

    -- Insert DSE Meet GA Target data (individual DSE level with binary flag)
    INSERT INTO `data-bi-prd-935c.bi_dev`.ioh_snd_master_kpi_detail   
    SELECT 
        '3ID' AS brand,
        'dse_code' AS level,
        dse_code AS level_value,
        CASE 
            WHEN cnt >= 350 THEN 1 
            ELSE 0 
        END AS value,
        'mtd' AS time_flag,
        timestamp(current_datetime('+7')) AS insert_date,
        'dse_meet_ga_tgt' AS kpi,
        vdt_id AS dt_id 
    FROM (
        SELECT 
            dse_code,
            cluster_nm_3id,
            COUNT(*) cnt
        FROM `data-bi-prd-935c.bi_mart`.fct_ga_site_id_v3 a 
        INNER JOIN (
            SELECT 
                parse_date('%Y%m',cast(mth_id as string)) AS mth_id,
                retailer_qrcode AS qr_code,
                mp3_name AS partner_name,
                branch,
                se_partnerid AS dse_code
            FROM `data-bi-prd-935c.bi_snd.pre_ref_outlet_mapping_3id` b
            WHERE parse_date('%Y%m',cast(mth_id as string)) = date_trunc(vdt_id,month)
        ) b ON date_trunc(a.dt,month) = mth_id
           AND a.partner_qr_cd = b.qr_code
        LEFT JOIN (
            SELECT 
                se_partnerid,
                cluster_nm_3id
            FROM (			
                SELECT * 
                FROM (
                    SELECT 
                        *, 
                        ROW_NUMBER() OVER (
                            PARTITION BY se_partnerid 
                            ORDER BY cnt DESC
                        ) AS rank_by_partner
                    FROM ( 
                        SELECT 
                            y.kecamatan_nm,
                            y.kabkot_nm,    
                            se_partnerid,
                            COUNT(*) AS cnt
                        FROM `data-bi-prd-935c.bi_snd.pre_ref_outlet_mapping_3id` a
                        LEFT JOIN `data-bi-prd-935c.bi_mart`.stg_v_map_tgt_ret_details_hist x 
                            ON a.retailer_qrcode = x.ret_qr_cd 
                            AND x.dt = vdt_id 
                        LEFT JOIN `data-bi-prd-935c.bi_mart`.ref_site_h3i y 
                            ON x.site_id = y.site_id
                        WHERE parse_date('%Y%m',cast(a.mth_id as string)) = date_trunc(vdt_id,month) 
                        GROUP BY 1, 2, 3
                    ) a 
                ) a   
                WHERE rank_by_partner = 1
            ) a 
            LEFT JOIN (
                SELECT   
                    kecamatan_nm,
                    kabkot_nm,
                    cluster_nm_3id  
                FROM `data-bi-prd-935c.bi_mart`.ref_site_h3i
                GROUP BY 1, 2, 3
            ) b ON UPPER(a.kecamatan_nm) = UPPER(b.kecamatan_nm)
               AND UPPER(a.kabkot_nm) = UPPER(b.kabkot_nm) 
            GROUP BY 1, 2 
        ) c ON b.dse_code = c.se_partnerid 
        WHERE dt between date_trunc(vdt_id,month) 
          AND vdt_id
        GROUP BY 1, 2 
    ) x 
    GROUP BY 1, 2, 3,4, 5, 7, 8;

    -- ================================
    -- Modified DSE Meet Secondary Target KPI Processing
    -- (Individual DSE Level with Binary Flag)
    -- ================================

    -- Clean up existing DSE Meet Secondary Target data
    DELETE FROM `data-bi-prd-935c.bi_dev`.ioh_snd_master_kpi_detail
    WHERE brand = '3ID' and kpi IN ('dse_meet_sec_tgt') 
      AND dt_id = vdt_id;

    -- Insert DSE Meet Secondary Target data (individual DSE level with binary flag)
    INSERT INTO `data-bi-prd-935c.bi_dev`.ioh_snd_master_kpi_detail   
    SELECT 
        '3ID' AS brand,
        'dse_code' AS level,
        dse_code AS level_value,
        CASE 
            WHEN xkpi_value >= 50000000 THEN 1 
            ELSE 0 
        END AS value,
        'mtd' AS time_flag,
        timestamp(current_datetime('+7')) AS insert_date,
        'dse_meet_sec_tgt' AS kpi,
        vdt_id AS dt_id 
    FROM (
        SELECT 	
            dse_code,
            SUM(a.value) AS xkpi_value
        FROM `data-bi-prd-935c.bi_dev.mis_snd_prisec_detail` a
        INNER JOIN (
            SELECT 
                parse_date('%Y%m',cast(mth_id as string)) AS mth_id,
                retailer_qrcode AS qr_code,
                mp3_name AS partner_name,
                branch,
                se_partnerid AS dse_code
            FROM `data-bi-prd-935c.bi_snd.pre_ref_outlet_mapping_3id` b
            WHERE parse_date('%Y%m',cast(mth_id as string)) = date_trunc(vdt_id,month)
        ) b ON date_trunc(a.dt_id,month) = b.mth_id
           AND a.qr_code = b.qr_code
        WHERE kpi_name = 'secondary'
          AND dt_id = vdt_id 
        GROUP BY 1
    ) a 
    -- Mapping DSE to cluster using NBS 
    LEFT JOIN (
        SELECT 
            se_partnerid,
            cluster_nm_3id
        FROM (
            SELECT * 
            FROM (
                SELECT 
                    *,
                    ROW_NUMBER() OVER (
                        PARTITION BY se_partnerid 
                        ORDER BY cnt DESC
                    ) AS rank_by_partner
                FROM ( 
                    SELECT 
                        y.kecamatan_nm,
                        y.kabkot_nm,    
                        se_partnerid,
                        COUNT(*) AS cnt
                    FROM `data-bi-prd-935c.bi_snd.pre_ref_outlet_mapping_3id` a
                    LEFT JOIN `data-bi-prd-935c.bi_mart`.stg_v_map_tgt_ret_details_hist x 
                        ON a.retailer_qrcode = x.ret_qr_cd 
                        AND x.dt = vdt_id 
                    LEFT JOIN `data-bi-prd-935c.bi_mart`.ref_site_h3i y 
                        ON x.site_id = y.site_id
                    WHERE parse_date('%Y%m',cast(mth_id as string)) = date_trunc(vdt_id,month) 
                    GROUP BY 
                        y.kecamatan_nm,
                        y.kabkot_nm,
                        se_partnerid
                ) a 
            ) a   
            WHERE rank_by_partner = 1
        ) a
        LEFT JOIN (
            SELECT   
                kecamatan_nm,
                kabkot_nm,
                cluster_nm_3id  
            FROM `data-bi-prd-935c.bi_mart`.ref_site_h3i
            GROUP BY 
                kecamatan_nm,
                kabkot_nm,
                cluster_nm_3id
        ) b ON UPPER(a.kecamatan_nm) = UPPER(b.kecamatan_nm)
           AND UPPER(a.kabkot_nm) = UPPER(b.kabkot_nm) 
        GROUP BY 
            se_partnerid,
            cluster_nm_3id
    ) c ON a.dse_code = c.se_partnerid 
    GROUP BY 1, 2, 3,4, 5, 7, 8;


    DELETE FROM `data-bi-prd-935c.bi_dev`.ioh_snd_master_kpi_detail
    WHERE brand = '3ID' and kpi IN ('dse_trx') 
      AND dt_id = vdt_id;

    -- Insert DSE Meet Secondary Target data (individual DSE level with binary flag)
    INSERT INTO `data-bi-prd-935c.bi_dev`.ioh_snd_master_kpi_detail   
    SELECT 
        '3ID' AS brand,
        'dse_code' AS level,
        dse_code AS level_value,
        CASE 
            WHEN xkpi_value > 0 THEN 1 
            ELSE 0 
        END AS value,
        'mtd' AS time_flag,
        timestamp(current_datetime('+7')) AS insert_date,
        'dse_trx' AS kpi,
        vdt_id AS dt_id 
    FROM (
        SELECT 	
            dse_code,
            SUM(a.value) AS xkpi_value
        FROM `data-bi-prd-935c.bi_dev.mis_snd_prisec_detail` a
        INNER JOIN (
            SELECT 
                parse_date('%Y%m',cast(mth_id as string)) AS mth_id,
                retailer_qrcode AS qr_code,
                mp3_name AS partner_name,
                branch,
                se_partnerid AS dse_code
            FROM `data-bi-prd-935c.bi_snd.pre_ref_outlet_mapping_3id` b
            WHERE parse_date('%Y%m',cast(b.mth_id as string)) = date_trunc(vdt_id,month)
        ) b ON date_trunc(a.dt_id,month) = b.mth_id
           AND a.qr_code = b.qr_code
        WHERE kpi_name = 'secondary'
          AND dt_id = vdt_id 
        GROUP BY 1
    ) a 
    -- Mapping DSE to cluster using NBS 
    LEFT JOIN (
        SELECT 
            se_partnerid,
            cluster_nm_3id
        FROM (
            SELECT * 
            FROM (
                SELECT 
                    *,
                    ROW_NUMBER() OVER (
                        PARTITION BY se_partnerid 
                        ORDER BY cnt DESC
                    ) AS rank_by_partner
                FROM ( 
                    SELECT 
                        y.kecamatan_nm,
                        y.kabkot_nm,    
                        se_partnerid,
                        COUNT(*) AS cnt
                    FROM `data-bi-prd-935c.bi_snd.pre_ref_outlet_mapping_3id` a
                    LEFT JOIN `data-bi-prd-935c.bi_mart`.stg_v_map_tgt_ret_details_hist x 
                        ON a.retailer_qrcode = x.ret_qr_cd 
                        AND x.dt = vdt_id 
                    LEFT JOIN `data-bi-prd-935c.bi_mart`.ref_site_h3i y 
                        ON x.site_id = y.site_id
                    WHERE parse_date('%Y%m',cast(mth_id as string)) = date_trunc(vdt_id,month) 
                    GROUP BY 
                        y.kecamatan_nm,
                        y.kabkot_nm,
                        se_partnerid
                ) a 
            ) a   
            WHERE rank_by_partner = 1
        ) a
        LEFT JOIN (
            SELECT   
                kecamatan_nm,
                kabkot_nm,
                cluster_nm_3id  
            FROM `data-bi-prd-935c.bi_mart`.ref_site_h3i
            GROUP BY 
                kecamatan_nm,
                kabkot_nm,
                cluster_nm_3id
        ) b ON UPPER(a.kecamatan_nm) = UPPER(b.kecamatan_nm)
           AND UPPER(a.kabkot_nm) = UPPER(b.kabkot_nm) 
        GROUP BY 
            se_partnerid,
            cluster_nm_3id
    ) c ON a.dse_code = c.se_partnerid 
    GROUP BY 1, 2, 3,4, 5, 7, 8;



DELETE FROM `data-bi-prd-935c.bi_dev`.ioh_snd_master_kpi_detail
    WHERE kpi IN ('dse_cnt') and brand = '3ID'
      AND dt_id = vdt_id;

    -- Insert DSE Meet GA Target data (individual DSE level with binary flag)
    INSERT INTO `data-bi-prd-935c.bi_dev`.ioh_snd_master_kpi_detail   
    SELECT 
        '3ID' AS brand,
        'dse_code' AS level,
        se_partnerid AS level_value,
        1 value,
        'mtd' AS time_flag,
        timestamp(current_datetime('+7')) AS insert_date,
        'dse_cnt' AS kpi,
        vdt_id AS dt_id 
               FROM `data-bi-prd-935c.bi_snd.pre_ref_outlet_mapping_3id` b
            WHERE parse_date('%Y%m',cast(mth_id as string)) = date_trunc(vdt_id,month) 
                GROUP BY 1, 2, 3,4, 5 ,6, 7, 8;