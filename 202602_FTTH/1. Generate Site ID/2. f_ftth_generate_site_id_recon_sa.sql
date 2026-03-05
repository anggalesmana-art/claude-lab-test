CREATE OR REPLACE PROCEDURE `data-bi-prd-935c.bi_dm.f_ftth_generate_site_id_recon_sa`(IN observation_date DATE)
BEGIN
  -- DECLARE observation_date DATE DEFAULT DATE_SUB(CURRENT_DATE(), INTERVAL 1 DAY);
  DECLARE start_current_month DATE DEFAULT DATE_TRUNC(observation_date, MONTH);
  DECLARE eop_previous_month DATE DEFAULT DATE_SUB(observation_date, INTERVAL 1 MONTH);
  DECLARE start_previous_month DATE DEFAULT DATE_TRUNC(eop_previous_month, MONTH);

  -- Masukkan data baru
  CREATE OR REPLACE TABLE `data-bi-prd-935c.bi_dm.ftth_sa_temp` AS
  WITH RAWSA AS (
    SELECT * FROM (
      SELECT
        customer_id,
        CAST(billing_account AS STRING) AS billing_account,
        CONCAT(customer_id, "-", billing_account) AS cust_bill_id,
        customer_account_id AS ca_id,
        fat_id hpid,
        product_name,
        billing_account_id ba_id,
        FORMAT_DATE("%Y-%m-%d", order_in_progress_date) AS so_date,
        FORMAT_DATE("%Y-%m-%d", order_complete_date) AS sa_date,
        FORMAT_DATE("%Y-%m-%d", order_in_progress_date) AS dt_id,
        ROW_NUMBER() OVER(PARTITION BY billing_account ORDER BY order_complete_date DESC) AS rk
      FROM `data-dtp-prd-aa1a.dm.ftth_subscriber_order_history`
      WHERE dt_id BETWEEN TIMESTAMP(start_current_month) AND TIMESTAMP(observation_date)
        AND FORMAT_DATE('%Y-%m', order_complete_date) = FORMAT_DATE('%Y-%m', observation_date)
        AND order_complete_date IS NOT NULL
        AND dwh_lifecycle_type = 'New Activation'
        AND customer_id IS NOT NULL
        AND billing_account IS NOT NULL
    ) a
    WHERE rk = 1
  ),
  CABAID AS (
    SELECT DISTINCT ca_id, ba_id, CONCAT(ca_id, "-", ba_id) AS ca_ba_id, ac_refr 
    FROM `data-dtp-prd-aa1a.stg.stg_catalist_dly_ba`
    WHERE dt_id BETWEEN TIMESTAMP(DATE_SUB(start_current_month, INTERVAL 3 MONTH)) AND TIMESTAMP(observation_date)
    AND ac_refr IN (SELECT DISTINCT billing_account FROM RAWSA)
  ),
  SAADDR AS (
    SELECT DISTINCT 
      ca_id, ba_id, CONCAT(ca_id, "-", ba_id) AS ca_ba_id, sa_addr, ftth_partnername, 
      REGEXP_EXTRACT(ftth_deviceid, r'#(.*)') AS device_id,ftth_deviceid hpid,
      ast_nm AS customer_name 
    FROM `data-dtp-prd-aa1a.stg.stg_catalist_dly_ordr`
    WHERE pd_cgy = 'FTTH'
      AND sa_addr IS NOT NULL AND sa_addr <> ''
      AND ftth_deviceid IS NOT NULL AND ftth_deviceid <> ''
      AND ast_nm IS NOT NULL AND ast_nm <> ''
      AND dt_id BETWEEN TIMESTAMP(DATE_SUB(start_current_month, INTERVAL 3 MONTH)) AND TIMESTAMP(observation_date)
      AND CONCAT(ca_id, "-", ba_id) IN (SELECT DISTINCT ca_ba_id FROM CABAID)
  ),
  SAWITHCABA AS (
    SELECT a.*, b.ca_ba_id
    FROM RAWSA a
    LEFT JOIN CABAID b
    ON a.billing_account = b.ac_refr
  ),
  SADATA AS (
    SELECT DISTINCT
      a.customer_id, a.billing_account, CONCAT(a.customer_id, "-", a.billing_account) AS cust_bill_id,
      b.ca_id, b.ba_id, b.ca_ba_id, b.customer_name, a.product_name,
      a.so_date, a.sa_date, b.sa_addr, coalesce(c.device_id, b.device_id) device_id,
      coalesce(c.HOMEPASS_ID, b.hpid) hpid, b.ftth_partnername AS partner_name,
      SPLIT(b.sa_addr, '-')[SAFE_OFFSET(0)] AS sa_addr_a,
      REGEXP_REPLACE(SPLIT(b.sa_addr, '-')[SAFE_OFFSET(1)], '-$', '') AS sa_addr_b,
      a.dt_id
    FROM SAWITHCABA a
    LEFT JOIN SAADDR b ON a.ca_ba_id = b.ca_ba_id
    LEFT JOIN (
      select CUSTOMER_ID billing_account, REGEXP_EXTRACT(HOMEPASS_ID, r'#(.*)') device_id, HOMEPASS_ID
      from `data-dtp-prd-aa1a.stg.ftth_toms_homepass`
      where DT_ID = observation_date
    ) c
    on a.billing_account = c.billing_account
  ),
  NOTCOVEREDSA AS (
    SELECT a.* FROM SADATA a
    LEFT JOIN `data-bi-prd-935c.bi_dm.tysg_ast_reference_recon` b
      ON a.billing_account = b.billing_account
      AND b.dt_id BETWEEN start_previous_month AND observation_date
    LEFT JOIN `data-bi-prd-935c.bi_dm.tysg_ftth_ast` c
      ON a.billing_account = c.billing_account
    WHERE b.billing_account IS NULL AND c.billing_account IS NULL
  ),
  FINALDATA AS (
    select * from (
      SELECT DISTINCT
        a.customer_id, a.billing_account, a.ca_id, a.ba_id, a.customer_name, a.product_name,
        a.so_date, coalesce(d.homepass_id_partner, a.device_id) device_id, a.partner_name, a.sa_addr,
        COALESCE(
          CONCAT(d.cluster_commercial_name, "-", d.cluster_name, '-'),
          CONCAT(d.building_tower_commercial_name, "-", d.building_tower_name,'-')
        ) AS sa_addr_2,
        COALESCE(d.siteid, c.site_id ,b.ft_site_id) AS site_id,
        b.ft_site_id AS check_site_id,
        COALESCE(d.homepass_latitude, c.homepass_latitude) AS customer_lat,
        COALESCE(d.homepass_longitude, c.homepass_longitude) AS customer_long,
        a.dt_id, 
        'Y' is_anomaly,
        ROW_NUMBER() OVER(PARTITION BY a.billing_account ORDER BY a.dt_id DESC) AS rk
      FROM NOTCOVEREDSA a
      LEFT JOIN `data-bi-prd-935c.bi_dm.tysg_ftth_ast` b ON UPPER(TRIM(a.sa_addr)) = UPPER(TRIM(b.site_sitac_catalist))
      LEFT JOIN `data-bi-prd-935c.bi_dm.tysg_ftth_hpm_v2` c ON UPPER(TRIM(a.sa_addr)) = UPPER(TRIM(c.sa_addr))
      left join (
          select * from `data-bi-prd-935c.bi_dm.ftth_hpm`
          where prc_dt = (select max(prc_dt) from `data-bi-prd-935c.bi_dm.ftth_hpm`)
        ) d
        on trim(a.hpid) = trim(d.hpid)
      ) a
    where rk = 1
  )
  select * except(rk) from (
    select
      DISTINCT
		  concat(a.customer_id, "-", a.billing_account) mix,
		  a.customer_id,
		  a.billing_account,
		  a.ca_id customer_account_id,
		  a.ba_id billing_account_id,
		  concat(a.ca_id,"-",a.ba_id) ca_ba_id,
		  a.customer_name,
      cast(a.customer_lat as numeric) customer_lat,
      cast(a.customer_long as numeric) customer_long,
      a.product_name,
      case
        when check_site_id is null then a.sa_addr_2
        else a.sa_addr
      end as site_sitac_catalist,
      a.device_id,
      b.system_key,
      b.ft_region,
      a.site_id as ft_site_id,
      b.ft_site_name,
      b.ft_site_address,
      CASE
        WHEN UPPER(b.ft_province) like '%SUMATRA%' THEN REGEXP_REPLACE(UPPER(b.ft_province), "SUMATRA", "SUMATERA")
        ELSE UPPER(b.ft_province)
      END AS ft_province,
      CASE
        WHEN UPPER(b.ft_dati_ii) like '%SUMATRA%' THEN REGEXP_REPLACE(UPPER(b.ft_dati_ii), "KOTA ADM. ", "")
        WHEN UPPER(b.ft_dati_ii) like '%SUMATRA%' THEN REGEXP_REPLACE(UPPER(b.ft_dati_ii), "KAB. ", "")
        ELSE UPPER(b.ft_dati_ii)
      END AS ft_dati_ii,
      UPPER(b.ft_kecamatan) ft_kecamatan,
      UPPER(b.ft_kelurahan) ft_kelurahan,
      b.ft_kode_pos,
      cast(b.ft_lat as numeric) ft_lat,
      cast(b.ft_long as numeric) ft_long,
      b.ft_fiber_type,
      b.ft_scope_of_work,
      CASE
      WHEN UPPER (b.ft_vendor) like '%ASIANET%' THEN 'ASIANET'
      WHEN UPPER (b.ft_vendor) like '%IFORTE%' THEN 'IFORTE'
      ELSE b.ft_vendor
      end as ft_vendor,
      b.ft_site_type,
      date(b.ft_hprfs_af) as ft_hprfs_af,
      cast(b.hp_final as numeric) hp_final,
      date(a.so_date) so_date,
      date(null) preactive_date,
      date(null) fp_date,
      date(null) pa_date,
      date(null) churn_date,
      'Y' is_anomaly,
      observation_date dt_id,
      row_number() over(partition by billing_account order by observation_date desc) rk
    from FINALDATA a
    left join (
      select * from `data-bi-prd-935c.bi_dm.tysg_master_homepass_rfs` 
      where dt_id = (select max(dt_id) from `data-bi-prd-935c.bi_dm.tysg_master_homepass_rfs`)
    ) b
    on a.site_id = b.ft_site_id
  ) a
  where rk = 1;  
END;