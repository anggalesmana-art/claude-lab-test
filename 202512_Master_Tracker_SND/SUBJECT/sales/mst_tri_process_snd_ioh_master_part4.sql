declare vdt_id date default @vdt_id;

    
    -- ========== TERTIARY NON-TRADE KPI - SITE LEVEL DAILY ==========
    DELETE FROM `data-bi-prd-935c.bi_dev`.ioh_snd_master_kpi_detail
    WHERE brand = '3ID' and kpi = 'tertiary_nontrad' AND dt_id = vdt_id 
      AND level = 'site_id' AND time_flag = 'dly';
    
    INSERT INTO `data-bi-prd-935c.bi_dev`.ioh_snd_master_kpi_detail
    SELECT '3ID',
    'site_id',
    siteid_bnum,
    SUM(COALESCE(a.amount, 0)),
    'dly',
    timestamp(current_datetime('+7')),
    'tertiary_nontrad',
    dt_sk_id 
    FROM `data-bi-prd-935c.bi_mart`.project_ioh_tertiary_outlet a    
    LEFT JOIN `data-bi-prd-935c.bi_mart`.angie_hrchy_dim_hst b ON b.partner_qr_cd = a.dealer_id AND date_trunc(a.dt_sk_id,month) = b.mth
    WHERE a.dt_sk_id = vdt_id
      AND source_nm <> '3AS'
    GROUP BY 1,2,3,5,6,7,8;

    -- ========== TERTIARY NON-TRADE KPI - SITE LEVEL MTD ==========
    DELETE FROM `data-bi-prd-935c.bi_dev`.ioh_snd_master_kpi_detail
    WHERE brand = '3ID' and kpi = 'tertiary_nontrad' AND dt_id = vdt_id 
      AND level = 'site_id' AND time_flag = 'mtd';
    
    INSERT INTO `data-bi-prd-935c.bi_dev`.ioh_snd_master_kpi_detail
    SELECT '3ID',
    'site_id',
    siteid_bnum,
    SUM(COALESCE(a.amount, 0)),
    'mtd',
    timestamp(current_datetime('+7')),
    'tertiary_nontrad',
    vdt_id 
    FROM `data-bi-prd-935c.bi_mart`.project_ioh_tertiary_outlet a    
    LEFT JOIN `data-bi-prd-935c.bi_mart`.angie_hrchy_dim_hst b ON b.partner_qr_cd = a.dealer_id AND date_trunc(a.dt_sk_id,month) = b.mth
    WHERE a.dt_sk_id BETWEEN date_trunc(vdt_id,month) AND vdt_id
      AND source_nm <> '3AS'
    GROUP BY 1,2,3,5,6,7,8;