declare vdt_id date default @vdt_id;

-- create table biadm.hg_stdy_cs5_data_1_${var:dt_id} stored as parquet as
CREATE OR REPLACE TABLE `data-bi-prd-935c.bi_mart.temp_hg_stdy_cs5_data_1_{{ vdt_id }}` AS
WITH base_data AS (
    SELECT 
        msisdn,
        usg_svc_class_cd,
        CASE 
            WHEN usg_promo_pkg_cd = '' THEN 'NA'
            ELSE usg_promo_pkg_cd 
        END AS usg_promo_pkg_cd,
        rtg_grp,
        CAST(rat_tp AS INT64) AS rat_tp,
        apn,
        acm_id,
        acm_id_2,
        COALESCE(da1_rev_code, ma_rev_code) AS rev_code,
        CASE 
            WHEN COALESCE(ma_da_ac_1, '') = '' THEN 'REGULER' 
            ELSE ma_da_ac_1 
        END AS mada,
        COALESCE(data_rev, 0) AS data_rev,
        COALESCE(vol_of_usg, 0) AS data_vol,
        CASE 
            WHEN b.level_7 = 'DATA REG' THEN COALESCE(usg_hits, 0) 
            ELSE 0 
        END AS usg_hits,
        b.level_5,
        b.level_7
    FROM 
        `data-dtp-prd-aa1a.smy.cst_usg_dly_smy` a
    INNER JOIN 
        `data-dtp-prd-aa1a.sor.ref_revcode` b
    ON 
        COALESCE(da1_rev_code, ma_rev_code) = b.rev_code
    WHERE 
        date(dt_id) = vdt_id
        AND UPPER(svc_usg_tp_rev) = 'DATA'
        AND b.svc_usg_tp = 'DATA'
)
SELECT 
    msisdn,
    usg_svc_class_cd,
    usg_promo_pkg_cd,
    rtg_grp,
    rat_tp,
    apn,
    CASE 
        WHEN (mada = 'REGULER' AND data_rev > 0) 
             OR (mada = 'REGULER' AND data_rev = 0 AND COALESCE(acm_id, '') = '' AND COALESCE(acm_id_2, '') = '') 
             THEN 'REGULER'
        WHEN mada = 'REGULER' AND data_rev = 0 AND COALESCE(acm_id, '') != '' 
             THEN acm_id
        ELSE mada 
    END AS daid,
    level_5,
    level_7,
    rev_code,
    SUM(data_rev) AS data_rev,
    SUM(data_vol) AS data_vol,
    SUM(usg_hits) AS usg_hits
FROM 
    base_data
GROUP BY 
    msisdn, usg_svc_class_cd, usg_promo_pkg_cd, rtg_grp, rat_tp, apn, daid, level_5, level_7, rev_code;

-- step 1
DELETE FROM `data-bi-prd-935c.bi_mart.usage_data_revcode_cs5_new`
WHERE daydate = vdt_id;

-- step 2
-- refresh biadm.hg_stdy_cs5_data_1_${var:dt_id};
INSERT INTO `data-bi-prd-935c.bi_mart.usage_data_revcode_cs5_new`
SELECT
    msisdn,
    usg_svc_class_cd,
    CASE 
        WHEN usg_promo_pkg_cd = 'NA' THEN ''
        ELSE usg_promo_pkg_cd 
    END AS usg_promo_pkg_cd,
    rtg_grp,
    CAST(rat_tp AS STRING) AS rat_tp,
    apn,
    daid,
    level_5,
    level_7,
    CASE
        WHEN daid = 'REGULER' OR data_vol_rev = 'Yes' THEN 'Yes'
        WHEN data_vol_rev IS NULL THEN 'No'
        ELSE data_vol_rev
    END AS data_vol_revenue,
    CASE
        WHEN level_7 = 'DATA REG' THEN NULL
        WHEN daid = 'REGULER' OR LOWER(data_vol_traffic) IN ('all', 'billable') OR IFNULL(data_vol_traffic, '') = '' THEN 'Billable'
        WHEN LOWER(data_vol_traffic) IN ('no', 'unbillable') THEN 'Unbillable'
        ELSE 'Billable Promo'
    END AS data_vol_traffic,
    CASE 
        WHEN level_7 = 'DATA REG' THEN rev_code 
        ELSE NULL 
    END AS rev_code,
    CAST(data_rev AS FLOAT64) AS data_rev,
    CAST(data_vol AS FLOAT64) AS data_vol,
    CAST(usg_hits AS FLOAT64) AS usg_hits,
    CURRENT_TIMESTAMP() AS ppn_dttm,
    vdt_id AS daydate
FROM 
    `data-bi-prd-935c.bi_mart.temp_hg_stdy_cs5_data_1_{{ vdt_id }}` a
LEFT JOIN (
    SELECT 
        *,
        CASE 
            WHEN promo_pkg_code = '' THEN 'NA'
            ELSE promo_pkg_code 
        END AS promo_pkg_cd
    FROM 
        `data-dtp-prd-aa1a.sor.ref_ma_da`
    WHERE 
        eff_dt <= format_date('%Y%m%d',vdt_id)
        AND end_dt >= format_date('%Y%m%d',vdt_id)
) b
ON 
    a.usg_promo_pkg_cd = b.promo_pkg_cd 
    AND a.daid = b.account1;

-- step 3
DROP TABLE `data-bi-prd-935c.bi_mart.temp_hg_stdy_cs5_data_1_{{ vdt_id }}`;