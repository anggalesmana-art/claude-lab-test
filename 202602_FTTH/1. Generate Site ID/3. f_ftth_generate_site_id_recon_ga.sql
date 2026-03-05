CREATE OR REPLACE PROCEDURE `data-bi-prd-935c.bi_dm.f_ftth_generate_site_id_recon_ga`(IN observation_date DATE)
OPTIONS (strict_mode=false)
BEGIN
  -- DECLARE observation_date DATE DEFAULT DATE_SUB(CURRENT_DATE(), INTERVAL 1 DAY);
  DECLARE start_current_month DATE DEFAULT DATE_TRUNC(observation_date, MONTH);
  DECLARE eop_previous_month DATE DEFAULT DATE_SUB(observation_date, INTERVAL 1 MONTH);
  DECLARE start_previous_month DATE DEFAULT DATE_TRUNC(eop_previous_month, MONTH);

  -- Masukkan data baru
  CREATE OR REPLACE TABLE `data-bi-prd-935c.bi_dm.ftth_ga_temp` AS
  WITH RAWGA AS (
    SELECT
      customer_id,
      CAST(billing_account AS STRING) billing_account,
      product_name,
      DATE(order_in_progress_date) so_date,
      DATE(gross_add_date) pa_date,
      DATE(order_in_progress_date) dt_id
    FROM `data-dtptechm-prd-c7ca.ioh_ftth.ftth_customer_funneling_complete_vw`
    WHERE dt_id BETWEEN start_current_month AND observation_date
    AND LENGTH(CAST(billing_account AS STRING)) != 10
    AND DATE(gross_add_date) BETWEEN start_current_month AND observation_date
  ),
  CABAID AS (
    SELECT DISTINCT ca_id, ba_id, CONCAT(ca_id, "-", ba_id) as ca_ba_id, ac_refr FROM `data-dtp-prd-aa1a.stg.stg_catalist_dly_ba`
    WHERE dt_id BETWEEN TIMESTAMP(DATE_SUB(start_current_month, INTERVAL 3 month)) and TIMESTAMP(observation_date)
    AND ac_refr in (SELECT billing_account FROM RAWGA)
  ),
  SAADDR AS (
    SELECT DISTINCT 
      ca_id, 
      ba_id, 
      CONCAT(ca_id, "-", ba_id) as ca_ba_id, 
      sa_addr, 
      ftth_partnername, 
      REGEXP_EXTRACT(ftth_deviceid, r'#(.*)') as device_id,
      ftth_deviceid hpid,
      ast_nm customer_name 
    FROM `data-dtp-prd-aa1a.stg.stg_catalist_dly_ordr`
    WHERE pd_cgy = 'FTTH'
    AND sa_addr IS NOT NULL
    AND ftth_deviceid IS NOT NULL
    AND ast_nm IS NOT NULL
    AND sa_addr <> ""
    AND ftth_deviceid <> ""
    AND ast_nm <> ''
    AND dt_id BETWEEN TIMESTAMP(DATE_SUB(start_current_month, INTERVAL 3 month)) AND TIMESTAMP(observation_date)
    AND CONCAT(ca_id, "-", ba_id) IN (SELECT ca_ba_id FROM CABAID)
  ),
  GAWITHCABA AS (
    SELECT a.*,
    b.ca_ba_id
    FROM RAWGA a
    LEFT JOIN CABAID b
    ON a.billing_account = b.ac_refr
  ),
  GADATA AS (
      SELECT DISTINCT
      a.customer_id,
      a.billing_account,
      CONCAT(a.customer_id, "-", a.billing_account) cust_bill_id,
      b.ca_id,
      b.ba_id,
      b.ca_ba_id,
      b.customer_name,
      a.product_name,
      a.so_date,
      a.pa_date,
      b.sa_addr,
      coalesce(c.device_id, b.device_id) device_id,
      coalesce(c.HOMEPASS_ID, b.hpid) hpid,
      b.ftth_partnername as partner_name,
      SPLIT(b.sa_addr, '-')[SAFE_OFFSET(0)] as sa_addr_a,
      REGEXP_REPLACE(SPLIT(b.sa_addr, '-')[SAFE_OFFSET(1)], '-$', '') as sa_addr_b,
      dt_id
      FROM GAWITHCABA a
      LEFT JOIN SAADDR b 
      ON a.ca_ba_id = b.ca_ba_id
	  LEFT JOIN (
      select CUSTOMER_ID billing_account, REGEXP_EXTRACT(HOMEPASS_ID, r'#(.*)') device_id, HOMEPASS_ID
      from `data-dtp-prd-aa1a.stg.ftth_toms_homepass`
      where DT_ID = observation_date
    ) c
	on a.billing_account = c.billing_account
  ),
  NOTCOVEREDGA AS (
    SELECT a.* FROM GADATA a
    LEFT JOIN (
      SELECT * FROM `data-bi-prd-935c.bi_dm.tysg_ast_reference_recon`
      WHERE dt_id BETWEEN start_previous_month AND observation_date
    ) b
    ON a.billing_account = b.billing_account
    LEFT JOIN `data-bi-prd-935c.bi_dm.tysg_ftth_ast` c
    ON a.billing_account = c.billing_account
    LEFT JOIN `data-bi-prd-935c.bi_dm.ftth_sa_temp` d
    ON a.billing_account = d.billing_account
    where b.billing_account IS NULL
    AND c.billing_account IS NULL
    AND d.billing_account IS NULL
  ),
  FINALDATA AS (
    SELECT DISTINCT
    a.customer_id,
    a.billing_account,
    a.ca_id,
    a.ba_id,
    a.customer_name,
    a.product_name,
    a.so_date,
    a.device_id,
    a.partner_name,
    a.sa_addr,
    COALESCE(CONCAT(d.cluster_commercial_name, "-", d.cluster_name, '-'), CONCAT(d.building_tower_commercial_name, "-", d.building_tower_name,'-')) sa_addr_2,
    COALESCE(d.siteid, c.site_id, b.ft_site_id) site_id,
    b.ft_site_id check_site_id,
    COALESCE(d.homepass_latitude, c.homepass_latitude) customer_lat,
    COALESCE(d.homepass_longitude, c.homepass_longitude) customer_long,
    a.dt_id
    FROM NOTCOVEREDGA a
    LEFT JOIN `data-bi-prd-935c.bi_dm.tysg_ftth_ast` b
    ON UPPER(TRIM(a.sa_addr)) = UPPER(TRIM(b.site_sitac_catalist))
    LEFT JOIN `data-bi-prd-935c.bi_dm.tysg_ftth_hpm_v2` c
    ON UPPER(TRIM(a.sa_addr)) = UPPER(TRIM(c.sa_addr))
    LEFT JOIN `data-bi-prd-935c.bi_dm.ftth_hpm` d
    ON trim(a.hpid) = trim(d.hpid)
  )
  SELECT * EXCEPT(rk) FROM (
    SELECT
      DISTINCT
      CONCAT(a.customer_id, "-", a.billing_account) mix,
      a.customer_id,
      a.billing_account,
      a.ca_id customer_account_id,
      a.ba_id billing_account_id,
      CONCAT(a.ca_id,"-",a.ba_id) ca_ba_id,
      a.customer_name,
      CAST(a.customer_lat AS numeric) customer_lat,
      CAST(a.customer_long AS numeric) customer_long,
      a.product_name,
      CASE
        WHEN check_site_id IS NULL THEN a.sa_addr_2
        ELSE a.sa_addr
      END AS site_sitac_catalist,
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
      CAST(b.ft_lat AS numeric) ft_lat,
      CAST(b.ft_long AS numeric) ft_long,
      b.ft_fiber_type,
      b.ft_scope_of_work,
      CASE
        WHEN UPPER (b.ft_vendor) LIKE '%ASIANET%' THEN 'ASIANET'
        WHEN UPPER (b.ft_vendor) LIKE '%IFORTE%' THEN 'IFORTE'
        ELSE b.ft_vendor
      END AS ft_vendor,
      b.ft_site_type,
      DATE(b.ft_hprfs_af) AS ft_hprfs_af,
      CAST(b.hp_final AS numeric) hp_final,
      DATE(a.so_date) so_date,
      DATE(null) preactive_date,
      DATE(null) fp_date,
      DATE(null) pa_date,
      DATE(null) churn_date,
      'Y' is_anomaly,
      DATE(a.dt_id) dt_id,
      ROW_NUMBER() OVER(PARTITION BY a.billing_account ORDER BY DATE(a.dt_id) DESC) AS rk
    FROM FINALDATA a
    left join (
      select * from `data-bi-prd-935c.bi_dm.tysg_master_homepass_rfs` 
      where dt_id = (select max(dt_id) from `data-bi-prd-935c.bi_dm.tysg_master_homepass_rfs`)
    ) b
    on a.site_id = b.ft_site_id
  ) a
  WHERE rk = 1;
END;