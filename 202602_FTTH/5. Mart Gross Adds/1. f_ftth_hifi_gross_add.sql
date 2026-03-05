CREATE OR REPLACE PROCEDURE `data-bi-prd-935c.bi_dm.f_ftth_hifi_gross_add`(IN starts_date DATE, IN observation_date DATE)
BEGIN
  -- DECLARE observation_date DATE DEFAULT '2024-01-01';
  DECLARE end_of_month DATE;
  DECLARE eop_previous_month DATE;
  DECLARE start_prev_month DATE;
  DECLARE start_current_month DATE;
  DECLARE yday_date DATE;
  DECLARE today_date DATE;

  SET end_of_month = LAST_DAY(observation_date, MONTH);
  SET eop_previous_month = LAST_DAY(DATE_SUB(observation_date, INTERVAL 1 MONTH));
  SET start_prev_month = DATE_TRUNC(eop_previous_month, MONTH);
  SET start_current_month = DATE_TRUNC(observation_date, MONTH);
  -- SET yday_date = date(DATE_SUB(date(starts_date), interval 1 day));

  WHILE starts_date <= observation_date DO
    SET yday_date = date(DATE_SUB(date(starts_date), interval 1 day));
    SET today_date = DATE(DATE_ADD(DATE(starts_date), interval 1 DAY));


    delete from `data-bi-prd-935c.bi_dm.ftth_cst_gross_add_v1`
    where dt_id = starts_date
    and flag_customer = "HIFI";

    insert into `data-bi-prd-935c.bi_dm.ftth_cst_gross_add_v1`
    with GA AS (
      select
        distinct
        *,
        'GA' flag_subs
      from `data-dtptechm-prd-c7ca.ioh_ftth.ftth_customer_funneling_complete_vw`
      where date(dt_id) between start_current_month and starts_date
      and length(cast(billing_account as string)) != 10
    ),
    eop_closing as (
      SELECT
        *,
        concat(customer_id, '-', billing_account) cust_bill_id,
        concat(customer_account_id, '-', billing_account_id) ca_ba_id
      FROM `data-bi-prd-935c.bi_dm.ftth_cumulative_subs`
      WHERE date(dt_id) = date(eop_previous_month)
      and flag_account not in ('Terminate')
      AND flag_account IN ('Active','Suspension-Bucket 1')
      and length(cast(billing_account as string)) != 10
    ),
    tday_closing as ( -- closing des
      SELECT
        *,
        concat(customer_id, '-', billing_account) cust_bill_id,
        concat(customer_account_id, '-', billing_account_id) ca_ba_id
      FROM `data-bi-prd-935c.bi_dm.ftth_cumulative_subs`
      WHERE date(dt_id) = date(starts_date)
      and flag_account not in ('Terminate')
      AND flag_account IN ('Active','Suspension-Bucket 1')
      and length(cast(billing_account as string)) != 10
    ),
    yday_closing as ( -- closing des
      SELECT
        *,
        concat(customer_id, '-', billing_account) cust_bill_id,
        concat(customer_account_id, '-', billing_account_id) ca_ba_id
      FROM `data-bi-prd-935c.bi_dm.ftth_cumulative_subs`
      WHERE date(dt_id) = date(yday_date)
      and flag_account not in ('Terminate')
      AND flag_account IN ('Active','Suspension-Bucket 1')
      and length(cast(billing_account as string)) != 10
    ),

    subs_mtd_refix as (
      select
        a.*,
        coalesce(b.flag_subs, 'Existing') as flag_subs
      from tday_closing a
      left join GA b
      on a.billing_account = cast(b.billing_account as string)
    ),
    ONTMAC AS (
      select * from (
        select 
          customer_id billing_account,
          ONT_SERIAL_NUMBER serial_number,
          ONT_MAC_ADDRESS ont_mac, 
          export_date dt_id, 
          row_number() over(partition by customer_id order by date(export_date) desc) rk
      from `data-network-prd-t7nb.cxe.exz_ftth_hpdb_ref_native`
      where date(export_date) between start_current_month and today_date
      ) a
      where rk = 1
    ),
    
    GAMTD AS (
      select * except(flag_subs)
      from (
        select
          '2. GROSS ADD (EOP)' flag,
          'HIFI' flag_customer,
          a.customer_account_id,
          a.billing_account_id,
          a.customer_id,
          a.billing_account,
          a.so_date,
          a.sa_date,
          a.pa_date,
          a.product_after package_nm,
          a.speed_current,
          a.contract_type,
          a.current_package_date,
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
          c.serial_number,
          c.ont_mac,
          CONCAT(a.billing_account, '@hifi.ioh.co.id') nai,
          starts_date dt_id,
          CASE
            when a.flag_subs = 'GA' then 'GA'
            when date(a.pa_date) >= start_current_month then 'GA'
            else 'Rejoiner'
          end as flag_subs 
        from subs_mtd_refix a
        left join eop_closing b
        ON a.billing_account = b.billing_account
        left join ONTMAC c
        on a.billing_account = c.billing_account
        WHERE b.billing_account IS NULL
      ) a
      where flag_subs = 'GA'
    ),
    GADLY AS (
      select * except(flag_subs)
      from (
        select
          '1. GROSS ADD (DAILY)' flag,
          'HIFI' flag_customer,
          a.customer_account_id,
          a.billing_account_id,
          a.customer_id,
          a.billing_account,
          a.so_date,
          a.sa_date,
          a.pa_date,
          a.product_after package_nm,
          a.speed_current,
          a.contract_type,
          a.current_package_date,
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
          c.serial_number,
          c.ont_mac,
          CONCAT(a.billing_account, '@hifi.ioh.co.id') nai,
          starts_date dt_id,
          CASE
            when a.flag_subs = 'GA' then 'GA'
            when date(a.pa_date) >= start_current_month then 'GA'
            else 'Rejoiner'
          end as flag_subs 
        from subs_mtd_refix a
        left join yday_closing b
        ON a.billing_account = b.billing_account
        left join ONTMAC c
        on a.billing_account = c.billing_account
        WHERE b.billing_account IS NULL
      ) a
      where flag_subs = 'GA'
    )
    select * from GAMTD
    union all
    select * from GADLY;
    SET starts_date = DATE_ADD(starts_date, INTERVAL 1 DAY);
  END WHILE;
END;