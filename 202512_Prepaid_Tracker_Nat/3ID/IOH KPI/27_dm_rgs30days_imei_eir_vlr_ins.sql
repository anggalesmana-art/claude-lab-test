declare vdt_id date default @vdt_id;


drop table if exists `data-bi-prd-935c.bi_stg`.dm_rgs30_imei_eir_vlr_tmp_2; 

delete from `data-bi-prd-935c.bi_mart.dm_rgs30_imei_eir_vlr` where cast(load_dt_sk_id as date)=vdt_id; 

CREATE TABLE `data-bi-prd-935c.bi_stg.dm_rgs30_imei_eir_vlr_tmp_2`
AS
SELECT 
    a.*, 
    b.final_imei AS imei_eir, 
    CASE 
        WHEN b.final_imei IS NULL THEN 'eir not found' 
        ELSE 'eir found' 
    END AS flag_eir,
    c.latest_imei AS imei_ggsn, 
    CASE 
        WHEN c.latest_imei IS NULL THEN 'ggsn not found' 
        ELSE 'ggsn found' 
    END AS flag_ggsn
FROM (
    -- insert into mis.dm_rgs30days_imei_daily
    SELECT 
        a.load_dt_sk_id,
        a.sbscrptn_ek_id,
        b.sbscrptn_msisdn,
        CASE 
            WHEN c.msisdn IS NULL THEN 'vlr not found' 
            ELSE 'found' 
        END AS cek_vlr,
        latest_imei AS imei_vlr,
        c.flag AS flag_imei_vlr
    FROM (
        SELECT 
            cast(vdt_id as date) AS load_dt_sk_id,
            sbscrptn_ek_id
        FROM `data-dtptechm-prd-c7ca.dwh.rgs30_subs_detail` a
        WHERE cast(a.load_dt_sk_id as date) =vdt_id
            AND a.tool_of_trade_ind = 'N'
            AND rgs30_all_ex_sp
        GROUP BY 1, 2
    ) a
    LEFT JOIN `data-dtptechm-prd-c7ca.dwh.sbscrptn_attribs` b 
        ON a.sbscrptn_ek_id = b.sbscrptn_ek_id 
    LEFT JOIN `data-bi-prd-935c.bi_mart.project_imeiVLR30days_daily` c 
        ON b.sbscrptn_msisdn = c.msisdn 
        AND cast(a.load_dt_sk_id as date) = cast(c.dt as date)
) a
LEFT JOIN `data-dtptechm-prd-c7ca.dwh.subscribers_handset_capability_mstr` b 
    ON a.sbscrptn_ek_id = b.sbscrptn_ek_id
LEFT JOIN (
    SELECT * 
    FROM `data-bi-prd-935c.bi_mart.project_imeivlr30days_daily_ggsn`
    WHERE dt = vdt_id
) c 
    ON a.sbscrptn_msisdn = c.sbscrptn_msisdn;

update `data-bi-prd-935c.bi_stg.dm_rgs30_imei_eir_vlr_tmp_2` set imei_eir =null where imei_eir ='';

update `data-bi-prd-935c.bi_stg.dm_rgs30_imei_eir_vlr_tmp_2` set imei_vlr =null where imei_vlr ='';

update `data-bi-prd-935c.bi_stg.dm_rgs30_imei_eir_vlr_tmp_2` set imei_ggsn =null where imei_ggsn ='';

INSERT INTO `data-bi-prd-935c.bi_mart.dm_rgs30_imei_eir_vlr`
SELECT 
    cast(load_dt_sk_id as date),
    sbscrptn_msisdn AS msisdn,
    sbscrptn_ek_id,
    COALESCE(imei_vlr, imei_ggsn, imei_eir) AS imei,
    CASE
        WHEN COALESCE(imei_vlr, imei_ggsn, imei_eir) IS NULL 
             OR COALESCE(imei_vlr, imei_ggsn, imei_eir) = '' 
             OR COALESCE(imei_vlr, imei_ggsn, imei_eir) = sbscrptn_msisdn THEN '01. blank'
        WHEN COALESCE(imei_vlr, imei_ggsn, imei_eir) LIKE '0%' 
             OR LENGTH(COALESCE(imei_vlr, imei_ggsn, imei_eir)) < 14 THEN '02. invalid'
        ELSE '03. valid'
    END AS flag_imei
FROM 
    `data-bi-prd-935c.bi_stg.dm_rgs30_imei_eir_vlr_tmp_2` a
WHERE 
    load_dt_sk_id = vdt_id;

update `data-bi-prd-935c.bi_mart.dm_rgs30_imei_eir_vlr` set imei =substr(imei,1,14) where cast(load_dt_sk_id as date) = vdt_id;
