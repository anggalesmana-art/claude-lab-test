declare vdt_id date default @vdt_id;

delete from `data-bi-prd-935c.bi_mart.project_ioh_rguog_subs_fin_daily` where load_dt_sk_id= vdt_id;

-- insert into `data-bi-prd-935c.bi_mart.`project_ioh_rguog_subs_fin_daily
-- 			 select load_dt_sk_id, 
-- 			 case when b.product_id = 8 then 'prepaid' else 'postpaid' end prepaid_flag,
-- 			 case when ctgry_ref_chld = '3 BUSINESS' then 'B2B' else 'B2C' end b2b_flag,
-- 			 b.mp3_channel_sk_id,
-- 			 ctgry_ref_chld home30_branch,
-- 			 a.sbscrptn_ek_id
-- 			from `data-bi-prd-935c.bi_mart.`project_rguog_subs_detail a
-- 			left join `data-bi-prd-935c.bi_mart.`sbscrptn_attribs b on a.sbscrptn_ek_id = b.sbscrptn_ek_id
-- 			--left join dwh.sbscrptn_dim_vlr_hist_1_prt_202201 b on a.sbscrptn_ek_id = b.sbscrptn_ek_id
-- 			join mis.project_ioh_dgpcr_flag_hist c on b.sbscrptn_msisdn= c.service_msisdn and c.dt_sk_id = a.load_dt_sk_id
-- 			left join `data-bi-prd-935c.bi_mart.`channel_dim cd on b.mp3_channel_sk_id = cd.channel_sk_id
-- 				left join `data-bi-prd-935c.bi_mart.`rprt_fltr_ref_ctgry cat on cat.ref_type_cd = 'MP3' and cd.channel_id = cat.ref_cd
-- 			where load_dt_sk_id = vdt_id
-- 			and tool_of_trade_ind = 'N';

INSERT INTO `data-bi-prd-935c.bi_mart.project_ioh_rguog_subs_fin_daily`
with subs as (select * from `data-dtptechm-prd-c7ca.dwh.sbscrptn_attribs`)
SELECT 
    load_dt_sk_id, 
    CASE 
        WHEN b.product_id = 8 THEN 'prepaid' 
        ELSE 'postpaid' 
    END AS prepaid_flag,
    CASE 
        WHEN ctgry_ref_chld = '3 BUSINESS' THEN 'B2B' 
        ELSE 'B2C' 
    END AS b2b_flag,
    b.mp3_channel_sk_id,
    ctgry_ref_chld AS home30_branch,
    cast(a.sbscrptn_ek_id as string)
FROM `data-bi-prd-935c.bi_mart.project_rguog_subs_detail` a
LEFT JOIN subs b 
    ON cast(a.sbscrptn_ek_id as string) = cast(b.sbscrptn_ek_id as string) 
JOIN `data-bi-prd-935c.bi_mart.project_ioh_dgpcr_flag_hist` c 
    ON b.sbscrptn_msisdn = c.service_msisdn 
    AND c.dt_sk_id = a.load_dt_sk_id
LEFT JOIN `data-dtptechm-prd-c7ca.dwh.channel_dim` cd 
    ON b.mp3_channel_sk_id = cd.channel_sk_id
LEFT JOIN `data-dtptechm-prd-c7ca.dwh.rprt_fltr_ref_ctgry` cat 
    ON cat.ref_type_cd = 'MP3' 
    AND cd.channel_id = cat.ref_cd
WHERE load_dt_sk_id = vdt_id
  AND tool_of_trade_ind = 'N';