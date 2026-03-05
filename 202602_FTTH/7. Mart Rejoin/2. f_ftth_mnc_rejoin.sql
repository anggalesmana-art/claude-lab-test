CREATE OR REPLACE PROCEDURE `data-bi-prd-935c.bi_dm.f_ftth_mnc_rejoin`(IN starts_date DATE, IN observation_date DATE)
BEGIN
  -- DECLARE observation_date DATE DEFAULT '2024-01-01';
  DECLARE end_of_month DATE;
  DECLARE eop_previous_month DATE;
  DECLARE start_prev_month DATE;
  DECLARE start_current_month DATE;
  DECLARE yday_date DATE;

  SET end_of_month = LAST_DAY(observation_date, MONTH);
  SET eop_previous_month = LAST_DAY(DATE_SUB(observation_date, INTERVAL 1 MONTH));
  SET start_prev_month = DATE_TRUNC(eop_previous_month, MONTH);
  SET start_current_month = DATE_TRUNC(observation_date, MONTH);
  -- SET yday_date = date(DATE_SUB(date(start_date), interval 1 day));

  WHILE starts_date <= observation_date DO
    SET yday_date = date(DATE_SUB(date(starts_date), interval 1 day));

    delete from `data-bi-prd-935c.bi_dm.ftth_cst_rejoin_v1`
    where dt_id = starts_date
    and flag_customer = "MNC";

    INSERT INTO `data-bi-prd-935c.bi_dm.ftth_cst_rejoin_v1`
    WITH PREPARATIONMNC AS (
      select
        'MNC' flag_customer,
        customer_id,
        billing_account,
        flag_account current_status,
        churn_date ac_st_dt,
        ac_st_rsn,
        so_date,
        sa_date,
        pa_date,
        product_name,
        partner_name,
        site_id,
        dt_id
      from `data-bi-prd-935c.bi_dm.tysg_mnc_hist_rejoin_v1` 
      where dt_id = starts_date    
    ),
    REJOINMTD AS (
      select
        '2. REJOIN (EOP)' flag,
        'MNC' flag_customer,
        b.customer_account_id,
        b.billing_account_id,
        b.customer_id,
        a.billing_account,
        a.current_status,
        a.ac_st_rsn,
        b.ac_st_dt,
        b.so_date,
        b.sa_date,
        b.pa_date,
        starts_date rejoin_date,
        a.product_name package_nm,
        b.speed_current,
        b.contract_type,
        date(b.current_package_date) current_package_date,
        b.asset_name,
        b.address,
        b.email,
        b.phone_num,
        b.phone_num_2,
        b.partner_name,
        b.site_id,
        b.kota,
        b.kecamatan,
        b.kelurahan,
        b.serial_number,
        b.ont_mac,
        b.nai,
        starts_date dt_id
      from PREPARATIONMNC a 
      left join (
        select * from `data-bi-prd-935c.bi_dm.ftth_cumulative_subs`
        where dt_id = starts_date
        and flag_customer = 'MNC'
      ) b
      on a.billing_account = b.billing_account
    ),
    SUBSM0 AS (
      select *
      from `data-bi-prd-935c.bi_dm.ftth_cumulative_subs`
      where dt_id = yday_date
      and flag_account in ('Active', 'Suspension-Bucket 1') 
      and flag_customer = 'MNC'
    ),
    SUBSM1 AS (
      select * 
      from `data-bi-prd-935c.bi_dm.ftth_cumulative_subs`
      where dt_id = starts_date
      and flag_account in ('Active', 'Suspension-Bucket 1') 
      and flag_customer = 'MNC'
    ),
    REJOINDAILY AS (
      select
        '1. REJOIN (DAILY)' flag,
        'MNC' flag_customer,
        a.customer_account_id,
        a.billing_account_id,
        a.customer_id,
        a.billing_account,
        c.flag_account current_status,
        c.ac_st_rsn,
        c.churn_date ac_st_dt,
        a.so_date,
        a.sa_date,
        a.pa_date,
        starts_date rejoin_date,
        a.product_after package_nm,
        a.speed_current,
        a.contract_type,
        date(a.current_package_date) current_package_date,
        a.asset_name,
        a.address,
        a.email,
        a.phone_num,
        a.phone_num_2,
        a.partner_name,
        a.site_id,
        a.kota,
        a.kecamatan,
        a.kelurahan,
        a.serial_number,
        a.ont_mac,
        a.nai,
        starts_date dt_id
      from SUBSM1 a 
      left join SUBSM0 b 
      on a.billing_account = b.billing_account
      left join (
        select * from `data-bi-prd-935c.bi_dm.tysg_mnc_hist_rejoin_v1`
        where dt_id = starts_date
      ) c
      on a.billing_account = c.billing_account
      where b.billing_account is null
      and a.pa_date < start_current_month 
    ),
    REJOINMTDFINAL AS ( 
      select
          distinct
          a.flag,
          a.flag_customer,
          coalesce(a.customer_account_id, b.customer_account_id) customer_account_id,
          coalesce(a.billing_account_id, b.billing_account_id) billing_account_id,
          coalesce(a.customer_id, b.customer_id) customer_id,
          coalesce(a.billing_account, b.billing_account) billing_account,
          coalesce(a.current_status, b.current_status) current_status,
          coalesce(a.ac_st_rsn, b.ac_st_rsn) ac_st_rsn,
          coalesce(a.ac_st_dt, b.ac_st_dt) ac_st_dt,
          coalesce(a.so_date, b.so_date) so_date,
          coalesce(a.sa_date, b.sa_date) sa_date,
          coalesce(a.pa_date, b.pa_date) pa_date,
          coalesce(b.rejoin_date,starts_date) rejoin_date,
          coalesce(a.package_nm, b.package_nm) package_nm,
          coalesce(a.speed_current, b.speed_current) speed_current,
          coalesce(a.contract_type, b.contract_type) contract_type,
          coalesce(a.current_package_date, b.current_package_date) current_package_date,
          coalesce(a.asset_name, b.asset_name) asset_name,
          coalesce(a.address, b.address) address,
          coalesce(a.email, b.email) email,
          coalesce(a.phone_num, b.phone_num) phone_num,
          coalesce(a.phone_num_2, b.phone_num_2) phone_num_2,
          coalesce(a.partner_name, b.partner_name) partner_name,
          coalesce(a.site_id, b.site_id) site_id,
          coalesce(a.kota, b.kota) kota,
          coalesce(a.kecamatan, b.kecamatan) kecamatan,
          coalesce(a.kelurahan, b.kelurahan) kelurahan,
          coalesce(a.serial_number, b.serial_number) serial_number,
          coalesce(a.ont_mac, b.ont_mac) ont_mac,
          coalesce(a.nai, b.nai) nai,
          starts_date dt_id
      from REJOINMTD a 
      left join (
        select * from `data-bi-prd-935c.bi_dm.ftth_cst_rejoin_v1`
        where dt_id = yday_date
        and flag like '%2%'
        and flag_customer = 'MNC'
      ) b
      on a.billing_account = b.billing_account
    )
    select * from REJOINMTDFINAL
    union all
    select * from REJOINDAILY;
    SET starts_date = DATE_ADD(starts_date, INTERVAL 1 DAY);
  END WHILE;
END;