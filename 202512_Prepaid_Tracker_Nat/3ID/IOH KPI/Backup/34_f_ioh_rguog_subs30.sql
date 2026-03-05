declare vdt_id date default @vdt_id;

delete from `data-bi-prd-935c.bi_mart.project_ioh_rguog_subs_fin_30` where load_dt_sk_id= vdt_id;

INSERT INTO `data-bi-prd-935c.bi_mart.project_ioh_rguog_subs_fin_30`
-- create table `data-bi-prd-935c.bi_mart.project_ioh_rguog_subs_fin_30` as
SELECT 
    CAST(vdt_id as DATE) AS load_dt_sk_id, 
    CASE 
        WHEN b.product_id = 8 THEN 'prepaid' 
        ELSE 'postpaid' 
    END AS prepaid_flag,
    CASE 
        WHEN ctgry_ref_chld = '3 BUSINESS' THEN 'B2B' 
        ELSE 'B2C' 
    END AS b2b_flag,
    cast(b.mp3_channel_sk_id as string),
    ctgry_ref_chld AS home30_branch,
    CAST(a.sbscrptn_ek_id as string)
FROM (
    SELECT 
        sbscrptn_ek_id
    FROM `data-bi-prd-935c.bi_mart.project_rguog_subs_detail` a
    WHERE a.load_dt_sk_id <= vdt_id
      AND a.load_dt_sk_id >= DATE_SUB(vdt_id, INTERVAL 29 DAY)
    GROUP BY 1
) a
LEFT JOIN `data-dtptechm-prd-c7ca.dwh.sbscrptn_attribs` b 
    ON a.sbscrptn_ek_id = b.sbscrptn_ek_id
JOIN `data-bi-prd-935c.bi_dm.project_ioh_dgpcr_flag_20220103` c 
    ON b.sbscrptn_msisdn = c.service_msisdn
LEFT JOIN `data-dtptechm-prd-c7ca.dwh.channel_dim` cd 
    ON b.mp3_channel_sk_id = cd.channel_sk_id
LEFT JOIN `data-dtptechm-prd-c7ca.dwh.rprt_fltr_ref_ctgry` cat 
    ON cat.ref_type_cd = 'MP3' 
    AND cd.channel_id = cat.ref_cd;

