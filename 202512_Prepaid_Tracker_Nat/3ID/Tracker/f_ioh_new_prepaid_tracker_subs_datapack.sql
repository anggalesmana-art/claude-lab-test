DECLARE vdt_id DATE DEFAULT @vdt_id;

DELETE
FROM
  `data-bi-prd-935c.bi_mart.rev_product_hit_channel`
WHERE
  trx_dt_sk_id = vdt_id ;

INSERT INTO
  `data-bi-prd-935c.bi_mart.rev_product_hit_channel`
SELECT
  CAST(load_date AS date) AS trx_dt_sk_id,
  cast(sbscrptn_ek_id as string) sbscrptn_ek_id,
  transaction_id,
  source_system_id,
  source_channel,
  mp3_name,
  UPPER(service_type_name) service_type_name,
  CASE
    WHEN UPPER(COALESCE(service_type,'BROADBAND')) IN ('BROADBAND') AND (process_nm IN ('SIM_DEMAND', 'SIM_FORFEIT', 'ADDON_FORFEIT', 'ADDON', 'ADDON_PULSA', 'ADDON_REDEEM') OR process_nm LIKE 'FRC%') THEN 'SIM Broadband'
    WHEN UPPER(COALESCE(service_type,'BROADBAND')) IN ('BROADBAND')
  AND process_nm IN ('VOUCHER_DEMAND',
    'UNLOCK_P3PRICE_AMORT',
    'UNLOCK_BALLOON_HOKI_DEMAND') THEN 'Unlock Data'
    WHEN UPPER(COALESCE(service_type,'BROADBAND')) IN ('BROADBAND') AND process_nm IN ('RITA', 'RITA_PULSA', 'CLIP_COMMISSION', 'RITA_P3PRICE_AMORT', 'RITA_BALLOON_HOKI_DEMAND', 'STARS COMMISSION') THEN 'RITA'
    WHEN UPPER(COALESCE(service_type,'BROADBAND'))IN ('BROADBAND')
  AND ( (process_nm IN ('EVC MARKUP',
        'MARKUP_UNLOCK',
        'MARKUP_RITA'))
    OR (revenue_src_ctgry = 'Ret'
      AND process_nm IN ('RITA_TOPUP',
        'UNTAGGED_COMMISSION'))
    OR (revenue_src_ctgry = 'Subs') ) THEN 'USSD'
    ELSE 'OTHERS'
END
  AS category,
  process_nm,
  PRODUCT_NAME,
  --,Substr(revenue_category,1,position('|' in revenue_category)-1 ),
  cast(SUM(netrevenue) as bignumeric) AS netrevenue
FROM (
  SELECT
    *,
    COALESCE(CASE
        WHEN service_type IN ('GPRS', 'GPRS_PACKAGE') THEN 'GPRS'
        WHEN service_type IN ('NA',
        'NON_VMS',
        'OTHERS') THEN 'OTHERS'
        WHEN service_type IN ('SMS', 'SMS_PACKAGE') THEN 'SMS'
        WHEN service_type IN ('VOICE',
        'VOICE_PACKAGE',
        'VOIP') THEN 'VOICE'
        ELSE service_type
    END
      ,'OTHERS') AS service_type_name,
    CASE
      WHEN revenue_src_ctgry='Subs' THEN 'USSD'
      WHEN revenue_src_ctgry<>'Subs' THEN
    CASE
      WHEN (process_nm IN ('SIM_DEMAND', 'SIM_FORFEIT', 'ADDON', 'ADDON_PULSA', 'ADDON_REDEEM') OR process_nm LIKE 'FRC%') THEN 'SIM BROADBAND'
      WHEN process_nm IN ('UNLOCK',
      'UNLOCK_PULSA') THEN 'Unlock Data (Inc.NG)'
      WHEN process_nm IN ('BALANCE TRANSFER', 'CLIP_COMMISSION', 'RITA', 'RITA_P3PRICE_AMORT', 'STARS COMMISSION') THEN 'RITA'
      WHEN process_nm IN ('RITA_TOPUP',
      'UNTAGGED_COMMISSION',
      'EVC MARKUP',
      'MARKUP_RITA',
      'MARKUP_UNLOCK') THEN 'USSD'
      ELSE 'OTHERS'
  END
  END
    AS rowname
  FROM (
    SELECT
      load_date,
      sbscrptn_ek_id,
      transaction_id,
      source_system_id,
      source_channel,
      mp3_location AS mp3_name,
      fct.service_type,
      Revenue_Type AS Revenue_Type,
      process_nm AS process_nm,
      product_nm AS PRODUCT_NAME,
      revenue_src_ctgry,
      0 AS GrossRev,
      SUM(COALESCE(Amort,0)) new_other_amortization,
      SUM(COALESCE(Amort,0)) * -1 AS NetRevenue
    FROM (
      SELECT
        CAST(fct.trx_dt_sk_id AS date) load_date,
        sbscrptn_ek_id,
        transaction_id,
        source_system_id,
        source_channel,
        COALESCE(CASE
            WHEN rprt.ctgry_ref_chld= 'NA' THEN 'Central West North Jkt'
            ELSE rprt.ctgry_ref_chld
        END
          ,'Central West North Jkt') AS mp3_location,
        COALESCE(fct.service_type,'BROADBAND') AS service_type,
        pd.product_type AS Revenue_Type,
        fct.process_nm,
        CASE
          WHEN COALESCE(pd.product_rpt_nm,'NA') <> 'NA' THEN pd.product_rpt_nm
          WHEN COALESCE(pd.product_src_nm,'NA') <> 'NA' THEN pd.product_src_nm
          WHEN COALESCE(pd.product_rpt_nm_alt,'NA') <> 'NA' THEN pd.product_rpt_nm_alt
          ELSE pd.product_primary_ref
      END
        AS product_nm,
        fct.revenue_src_ctgry,
        SUM(CASE
            WHEN product_id = 8 THEN commission/1.11
            WHEN product_id <> 8 THEN commission
        END
          ) AS Amort
      FROM
        `data-dtptechm-prd-c7ca.dwh.revenue_base` fct
      LEFT JOIN
        `data-dtptechm-prd-c7ca.dwh.product_dim` pd
      ON
        pd.product_sk_id=fct.product_sk_id
      LEFT OUTER JOIN
        `data-dtptechm-prd-c7ca.dwh.channel_dim` cd
      ON
        fct.demand_mp3_channel_sk_id = cd.channel_sk_id
      LEFT OUTER JOIN
        `data-dtptechm-prd-c7ca.dwh.rprt_fltr_ref_ctgry` rprt
      ON
        rprt.ref_cd=cd.channel_id
        AND ref_type_cd='MP3'
      JOIN `data-dtptechm-prd-c7ca.dwh.demand_revenue_base_filter` AS drbf
							ON fct.process_nm = drbf.process_nm
							AND fct.revenue_src_ctgry = drbf.revenue_src_ctgry
						WHERE drbf.net_amort_incl = 'Y'and 
        CAST(fct.trx_dt_sk_id AS date) = vdt_id
        --  and cast(fct.trx_dt_sk_id as date) <= '2020-05-18'
        AND revenue_book_incl_ind='INCLUDE'
        AND fct.tool_of_trade_ind='N'
      GROUP BY
        1,
        2,
        3,
        4,
        5,
        6,
        7,
        8,
        9,
        10,
        11 ) FCT
    GROUP BY
      1,
      2,
      3,
      4,
      5,
      6,
      7,
      8,
      9,
      10,
      11
    UNION ALL
    SELECT
      CAST(fct.trx_dt_sk_id AS date) load_date,
      sbscrptn_ek_id,
      transaction_id,
      source_system_id,
      source_channel,
      COALESCE(CASE
          WHEN rprt.ctgry_ref_chld= 'NA' THEN 'Central West North Jkt'
          ELSE rprt.ctgry_ref_chld
      END
        ,'Central West North Jkt') AS mp3_location,
      COALESCE(fct.service_type,'BROADBAND') AS service_type,
      pd.product_type AS Revenue_Type,
      fct.process_nm AS process_nm,
      CASE
        WHEN source_channel='TARIFF_ADJUSTED' THEN source_channel
        WHEN COALESCE(pd.product_rpt_nm,'NA') <> 'NA' THEN pd.product_rpt_nm
        WHEN COALESCE(pd.product_src_nm,'NA') <> 'NA' THEN pd.product_src_nm
        WHEN COALESCE(pd.product_rpt_nm_alt,'NA') <> 'NA' THEN pd.product_rpt_nm_alt
        ELSE pd.product_primary_ref
    END
      AS product_nm,
      fct.revenue_src_ctgry,
      SUM(CASE
          WHEN fct.product_id = 8 THEN gross_revenue/1.11
          WHEN fct.product_id <> 8 THEN gross_revenue
      END
        ) AS GrossRev,
      SUM(CASE
          WHEN fct.product_id = 8 THEN fct.commission/1.11
          WHEN fct.product_id <> 8 THEN fct.commission
          ELSE 0
      END
        ) AS Amort,
      SUM(CASE
          WHEN fct.product_id = 8 THEN net_revenue/1.11
          WHEN fct.product_id <> 8 THEN net_revenue
      END
        ) AS NetRevenue
    FROM
      `data-dtptechm-prd-c7ca.dwh.revenue_base` fct
    LEFT JOIN
      `data-dtptechm-prd-c7ca.dwh.product_dim` pd
    ON
      pd.product_sk_id=fct.product_sk_id
    LEFT OUTER JOIN
      `data-dtptechm-prd-c7ca.dwh.channel_dim` cd
    ON
      fct.demand_mp3_channel_sk_id = cd.channel_sk_id
    LEFT OUTER JOIN
      `data-dtptechm-prd-c7ca.dwh.rprt_fltr_ref_ctgry` rprt
    ON
      rprt.ref_cd=cd.channel_id
      AND ref_type_cd='MP3'
    JOIN `data-dtptechm-prd-c7ca.dwh.demand_revenue_base_filter` AS drbf
							ON fct.process_nm = drbf.process_nm
							AND fct.revenue_src_ctgry = drbf.revenue_src_ctgry
						WHERE drbf.net_revenue_incl = 'Y'and 
      cast(fct.trx_dt_sk_id as date) = vdt_id
      --and fct.trx_dt_sk_id <= 20200517
      AND COALESCE(fct.gl_cd,'') NOT IN (
      SELECT
        ref_cd
      FROM
        `data-dtptechm-prd-c7ca.dwh.rprt_fltr_ref_ctgry`
      WHERE
        ref_type_cd = 'ACCRUAL_GL_CODE')
      AND fct.tool_of_trade_ind='N'
    GROUP BY
      1,
      2,
      3,
      4,
      5,
      6,
      7,
      8,
      9,
      10,
      11 ) tab )A --left join dwh.sbscrptn_topup_base b
  --on A.to_char(load_date,'YYYYMMDD')=b.topup_dt_sk_id
  --and A.sbscrptn_Ek_id=b.sbscrptn_Ek_id
  --and A.source_system_id=b.voucher_id
  --where upper(service_type_name)='BROADBAND'
  --and process_nm ='TOPUP'
  --and A.PRODUCT_NAME is null
GROUP BY
  1,
  2,
  3,
  4,
  5,
  6,
  7,
  8,
  9,
  10
  --order by 1,2'
  ;
  -- erase
  
DELETE
FROM
  `data-bi-prd-935c.bi_mart.kpi_national_tracker_dly`
WHERE
brand = 'TRI' and
  dt_id = vdt_id
  AND kpi_id IN ('DAT0028',
    'DAT0029',
    'DAT0030');
  -- pack revenue  DAT0030


INSERT INTO
  `data-bi-prd-935c.bi_mart.kpi_national_tracker_dly`
SELECT
  'TRI' brand,
  ''kpi_code,
  'MTD' flag,
  SUM(netrevenue)  -- value
  ,
  current_timestamp(),
  'DAT0030' kpi_id,
  cast(vdt_id as date)
FROM
  `data-bi-prd-935c.bi_mart.rev_product_hit_channel`
WHERE
  trx_Dt_sk_id = vdt_id
  AND process_nm IN ('RITA',
    'SIM_DEMAND',
    'VOUCHER_DEMAND',
    'DATA_BB_BASE',
    'TOPUP' )
  AND netrevenue>30
GROUP BY
  1,
  2,
  3,
  5,
  6,
  7;
  --**
  --Prepare data for DAT0028
  --**
DELETE
FROM
  `data-bi-prd-935c.bi_mart.fact_datapack_msisdn`
WHERE
  dt = vdt_id;
  --'PLAN_FB_FLEX_ZERO' (max. 35MB per day) is split from 'PLAN_WALLED_GARDEN' (this is unlimmited) --> start 03 Nov 2022
INSERT INTO
  `data-bi-prd-935c.bi_mart.fact_datapack_msisdn`
SELECT
  DISTINCT cast(edr_dt_sk_id as date) AS dt,
  msisdn
FROM
  `data-dtptechm-prd-c7ca.dwh.pcrf_dly_summary` a
WHERE
  a.quota_usage > 0
  AND CAST(a.edr_dt_sk_id AS date) = vdt_id
  AND triggertype <> 16
  AND UPPER(CASE
      WHEN a.service_nm <> '' THEN a.service_nm
      ELSE a.quota_nm
  END
    ) NOT IN ( 'PLAN_CAP11DEF',
    'PLAN_CAP11DEF_CAL',
    'PLAN_PAKET11',
    'PLAN_PAKET11_JANETPLUS',
    'PLAN_SUSNGHT_FU',
    'PLAN_SUSREG_FU',
    'PLAN_WALLED_GARDEN',
    'PLAN_WA_250MBPERD',
    'PLAN_OTTCALL_100MB_FUP',
    'PLAN_CHATTINGOTT_50MBFUP',
    'PLAN_BIMAPLUS',
    'PLAN_FB_FLEX_ZERO',
    'PLAN_CVM_SEEDING',
    --modified on May 2023
    'PLAN_WA_SPECIAL_PERDAY',
    'PLAN_YOUTUBE_SPECIAL_PERDAY',
    'PLAN_FB_SPECIAL_PERDAY',
    'PLAN_CVM_ATTACK',
    'PLAN_500MB_DAILY_1D',
    --just to know on 26 Jun 2023, that this quota name is categorized as free quota since a long time ago
    'PLAN_CVM_SPECIAL_OW',
    --add on 07 Sep 2023, this is modular plan name (can be paid or free). But i decided to exclude this
    'PLAN_CI2SUTA_500MB_1D' --add on 01 Jan 2024, one of the reason is this plan name used for free 1GB per day for all IOH
    );
  --- subs pack DAT0028
INSERT INTO
  `data-bi-prd-935c.bi_mart.kpi_national_tracker_dly`
SELECT
  'TRI' brand,
  ''kpi_code,
  'MTD' flag,
  COUNT(DISTINCT msisdn)  -- value
  ,
  current_timestamp(),
  'DAT0028' kpi_id,
  cast(vdt_id as date)
FROM
  `data-bi-prd-935c.bi_mart.fact_datapack_msisdn`
WHERE
  dt = vdt_id
GROUP BY
  1,
  2,
  3,
  5,
  6,
  7;
  --- sold pack DAT0029
INSERT INTO
  `data-bi-prd-935c.bi_mart.kpi_national_tracker_dly`
SELECT
  brand,
  kpi_Code,
  flag,
  SUM(value),
  current_timestamp(),
  kpi_id,
  cast(vdt_id as date)
FROM (
  SELECT
    'TRI' brand,
    ''kpi_code,
    'MTD' flag,
    COUNT(DISTINCT hits_id) value,
    current_timestamp() dt,
    'DAT0029' kpi_id,
    cast(vdt_id as date) dt_id
  FROM (
    SELECT
      CASE
        WHEN process_nm IN ('RITA', 'ADDON_FORFEIT', 'ADDON_REDEEM', 'SIM_DEMAND', 'SIM_FORFEIT' ) THEN transaction_id
        WHEN process_nm IN ('VOUCHER_DEMAND',
        'DATA_BB_BASE',
        'TOPUP' ) THEN source_system_id
    END
      AS hits_id
    FROM
      `data-bi-prd-935c.bi_mart.rev_product_hit_channel`
    WHERE
      trx_Dt_sk_id = vdt_id
      AND category='SIM Broadband'
      AND process_nm='SIM_DEMAND'
      AND netrevenue>30 )x
  GROUP BY
    1,
    2,
    3,
    5,
    6,
    7
  UNION ALL
  SELECT
    'TRI' brand,
    ''kpi_code,
    'MTD' flag,
    COUNT(DISTINCT hits_id),
    current_timestamp(),
    'DAT0029' kpi_id,
    cast(vdt_id as date)
  FROM (
    SELECT
      CASE
        WHEN process_nm IN ('RITA', 'ADDON_FORFEIT', 'ADDON_REDEEM', 'SIM_DEMAND', 'SIM_FORFEIT' ) THEN transaction_id
        WHEN process_nm IN ('VOUCHER_DEMAND',
        'DATA_BB_BASE',
        'TOPUP' ) THEN source_system_id
    END
      AS hits_id
    FROM
      `data-bi-prd-935c.bi_mart.rev_product_hit_channel`
    WHERE
      trx_Dt_sk_id = vdt_id
      AND process_nm IN ( 'RITA',
        'TOPUP',
        'DATA_BB_BASE' )
      AND netrevenue>30 )x
  GROUP BY
    1,
    2,
    3,
    5,
    6,
    7
  UNION ALL
  SELECT
    'TRI' brand,
    ''kpi_code,
    'MTD' flag,
    COUNT(DISTINCT hits_id),
    current_timestamp(),
    'DAT0029' kpi_id,
    cast(vdt_id as date)
  FROM (
    SELECT
      CASE
        WHEN process_nm IN ('RITA', 'ADDON_FORFEIT', 'ADDON_REDEEM', 'SIM_DEMAND', 'SIM_FORFEIT' ) THEN transaction_id
        WHEN process_nm IN ('VOUCHER_DEMAND',
        'DATA_BB_BASE',
        'TOPUP' ) THEN source_system_id
    END
      AS hits_id
    FROM
      `data-bi-prd-935c.bi_mart.rev_product_hit_channel`
    WHERE
      trx_Dt_sk_id = vdt_id
      AND process_nm IN ( 'VOUCHER_DEMAND' )
      AND netrevenue>30 )x
  GROUP BY
    1,
    2,
    3,
    5,
    6,
    7 )x
GROUP BY
  1,
  2,
  3,
  5,
  6,
  7;