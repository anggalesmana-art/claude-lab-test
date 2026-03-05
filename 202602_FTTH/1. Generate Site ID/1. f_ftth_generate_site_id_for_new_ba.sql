CREATE OR REPLACE PROCEDURE `data-bi-prd-935c.bi_dm.f_ftth_generate_site_id_for_new_ba`(IN observation_date DATE)
BEGIN
  -- DECLARE observation_date DATE DEFAULT CURRENT_DATE();
  DECLARE start_current_month DATE DEFAULT DATE_TRUNC(observation_date, MONTH);
  
  delete from `data-bi-prd-935c.bi_dm.tysg_ast_reference_recon`
  where dt_id = observation_date;

  INSERT INTO `data-bi-prd-935c.bi_dm.tysg_ast_reference_recon`
  WITH SALESORDER AS (
    SELECT 
    distinct
    *
    from (
    select
    customer_id,
    cast(billing_account as string) as billing_account,
    concat(customer_id, "-", billing_account) as cust_bill_id,
    case
      when length(cast(billing_account as string)) = 10 then "Orbit-Migration"
      else "New-SO"
    end as flag_subs,
    product_name,
    site_sitac,
    format_date("%Y-%m-%d", order_in_progress_date) as so_date,
    site_sitac,
    REGEXP_EXTRACT(fat_id, r'#(.*)') as device_id,
    fat_id hpid,
    row_number() over(partition by billing_account order by order_in_progress_date desc) as rk
    FROM `data-dtp-prd-aa1a.dm.ftth_customer_funneling_in_progress`
    WHERE TIMESTAMP_TRUNC(dt_id, DAY) between TIMESTAMP(observation_date) and TIMESTAMP(observation_date)
    and TIMESTAMP_TRUNC(order_in_progress_date, DAY) between DATE(start_current_month) and DATE(observation_date)
    and order_in_progress_date is not null
    and customer_id is not null
    and billing_account is not null
    ) a
    where rk=1
  ),
  CABAID AS (
    select distinct ca_id, ba_id, concat(ca_id, "-", ba_id) as ca_ba_id, ac_refr, ac_nm from `data-dtp-prd-aa1a.stg.stg_catalist_dly_ba`
    where dt_id between TIMESTAMP(start_current_month) and TIMESTAMP(observation_date)
    and ac_refr in (select billing_account from SALESORDER)
  ),
  SAADDR AS (
    select distinct ca_id, ba_id, concat(ca_id, "-", ba_id) as ca_ba_id, sa_addr, ftth_partnername, ast_nm, REGEXP_EXTRACT(ftth_deviceid, r'#(.*)') as device_id, ftth_deviceid hpid
    from `data-dtp-prd-aa1a.stg.stg_catalist_dly_ordr`
    where pd_cgy = 'FTTH'
    and sa_addr is not null
    and ast_nm is not null
    and ast_nm <> ""
    and sa_addr <> ""
    and ftth_deviceid <> ""
    and dt_id between TIMESTAMP(start_current_month) and TIMESTAMP(observation_date)
    and concat(ca_id, "-", ba_id) in (select ca_ba_id from CABAID)
  ),
  SOWITHCABA as (
    select a.*,
    b.ca_ba_id,
    b.ac_nm
    from SALESORDER a
    left join CABAID b
    on a.billing_account = b.ac_refr
  ),
  SODATA AS (
    select
    distinct
    a.customer_id,
    a.billing_account,
    coalesce(a.ac_nm, b.ast_nm) customer_name,
    concat(a.customer_id, "-", a.billing_account) cust_bill_id,
    b.ca_id,
    b.ba_id,
    b.ca_ba_id,
    a.product_name,
    a.flag_subs,
    a.so_date,
    b.sa_addr,
    coalesce(c.device_id, b.device_id, a.device_id) device_id,
    coalesce(c.HOMEPASS_ID, b.hpid, a.hpid) hpid,
    b.ftth_partnername as partner_name,
    SPLIT(b.sa_addr, '-')[SAFE_OFFSET(0)] as sa_addr_a,
    REGEXP_REPLACE(SPLIT(b.sa_addr, '-')[SAFE_OFFSET(1)], '-$', '') as sa_addr_b,
    from SOWITHCABA a
    left join SAADDR b 
    on a.ca_ba_id = b.ca_ba_id
	LEFT JOIN (
      select CUSTOMER_ID billing_account, REGEXP_EXTRACT(HOMEPASS_ID, r'#(.*)') device_id, HOMEPASS_ID
      from `data-dtp-prd-aa1a.stg.ftth_toms_homepass`
      where DT_ID = observation_date
    ) c
    on a.billing_account = c.billing_account
  ),
  FINALDATA AS (
    select
    distinct
    a.customer_id,
    a.billing_account,
    a.customer_name,
    a.product_name,
    a.ca_id,
    a.ba_id,
    a.so_date,
    a.device_id,
    a.partner_name,
    a.sa_addr,
    coalesce(concat(d.cluster_commercial_name, "-", d.cluster_name, '-'), concat(d.building_tower_commercial_name, "-", d.building_tower_name,'-')) sa_addr_2,
    coalesce(d.siteid, c.site_id, b.ft_site_id) site_id,
    b.ft_site_id check_site_id,
    coalesce(d.homepass_latitude, c.homepass_latitude) customer_lat,
    coalesce(d.homepass_longitude, c.homepass_longitude) customer_long,
    from SODATA a
    left join `data-bi-prd-935c.bi_dm.tysg_ftth_ast` b
    on upper(trim(a.sa_addr)) = upper(trim(b.site_sitac_catalist))
    left join `data-bi-prd-935c.bi_dm.tysg_ftth_hpm_v2` c
    on upper(trim(a.sa_addr)) = upper(trim(c.sa_addr))
    left join (
      select * from `data-bi-prd-935c.bi_dm.ftth_hpm`
      where prc_dt = (select max(prc_dt) from `data-bi-prd-935c.bi_dm.ftth_hpm`)
    ) d
    on trim(a.hpid) = trim(d.hpid)
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
      'N' is_anomaly,
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