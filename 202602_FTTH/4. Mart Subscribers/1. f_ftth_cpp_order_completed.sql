CREATE OR REPLACE PROCEDURE `data-bi-prd-935c.bi_dm.f_ftth_cpp_order_completed`(IN start_date DATE, IN observation_date DATE)
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

  WHILE start_date <= observation_date DO

    delete from `data-bi-prd-935c.bi_dm.ftth_cpp_order_complete`
    where cpp_date = start_date;

    INSERT INTO `data-bi-prd-935c.bi_dm.ftth_cpp_order_complete`
    WITH CPPORDER AS (
      select 
        ca_id customer_account_id,
        ba_id billing_account_id,
        coalesce(SAFE_CAST(DATE(PARSE_DATETIME('%d-%m-%Y %H:%M:%S', ordr_crt_dt)) AS DATE), null) po_date,
        coalesce(SAFE_CAST(DATE(PARSE_DATETIME('%d-%m-%Y %H:%M:%S', ordr_submission_dt)) AS DATE), null) so_date,
        coalesce(SAFE_CAST(DATE(PARSE_DATETIME('%d-%m-%Y %H:%M:%S', ordr_compl_dt)) AS DATE), null) cpp_date,
        MAX(CASE WHEN actn = 'Add' THEN pd_id END) AS pd_id_after,
        MAX(CASE WHEN actn = 'Add' THEN pd_nm END) AS package_after,
        MAX(CASE WHEN actn = 'Delete' THEN pd_id END) AS pd_id_before,
        MAX(CASE WHEN actn = 'Delete' THEN pd_nm END) AS package_before    
      from `data-dtp-prd-aa1a.stg.stg_catalist_dly_ordr`
      where date(dt_id) = start_date
      and ordr_tp = 'Change Package'
      and ordr_st = 'Complete'
      and pd_tp = 'Plan'  
      and upper(pd_nm) like '%HIF%'
      group by 1,2,3,4,5
    ),
    CPPCA AS (
      select
        a.customer_account_id,
        a.billing_account_id,
        b.ca_refr customer_id,
        po_date,
        so_date,
        cpp_date,    
        pd_id_before,
        package_before,
        pd_id_after,
        package_after,
      from CPPORDER a
      left join `data-dtp-prd-aa1a.stg.stg_catalist_dly_ca` b 
      on a.customer_account_id = b.ca_id
      where date(b.dt_id) = start_date
    ),
    CPPBA AS (
      select
        a.customer_account_id,
        a.billing_account_id,
        a.customer_id,
        b.ac_refr billing_account,
        po_date,
        so_date,
        cpp_date,
        pd_id_before,
        package_before,
        pd_id_after,
        package_after
      from CPPCA a
      left join `data-dtp-prd-aa1a.stg.stg_catalist_dly_ba` b 
      on a.billing_account_id = b.ba_id
      where date(b.dt_id) = start_date
    ),
    CPPASSET AS (
      select 
        a.customer_account_id,
        a.billing_account_id,
        a.customer_id,
        a.billing_account,
        a.po_date,
        a.so_date,
        a.cpp_date,
        a.pd_id_before,
        a.package_before,
        a.pd_id_after,
        b.pd_id,
        -- coalesce(b.pd_id, a.pd_id_after) pd_id_after,
        a.package_after,
        b.pd_nm,
        -- coalesce(b.pd_nm, a.package_after) package_after,
        row_number() over(partition by ba_id order by date(FORMAT_TIMESTAMP('%Y-%m-%d', PARSE_TIMESTAMP('%d-%m-%Y %H:%M:%S', actvn_dt))) desc) rk
      from CPPBA a
      inner join `data-dtp-prd-aa1a.stg.stg_catalist_dly_ast` b
      on a.billing_account_id = b.ba_id and date(a.cpp_date) = date(b.dt_id)
      where date(b.dt_id) between start_date and start_date
      -- where date(b.dt_id) = DATE_SUB(CURRENT_DATE("Asia/Jakarta"), Interval 1 day)
      and b.pd_tp = "Plan"
      and ast_st = 'Active'
      order by billing_account_id, cpp_date
    )
    select
      CASE
        when length(billing_account) = 10 then "MNC"
        else "HIFI"
      end as flag,
      customer_account_id,
      billing_account_id,
      customer_id,
      billing_account,
      package_before product_before,
      package_after product_after,
      po_date,
      so_date,
      cpp_date,
      "CHANGE PACKAGE" status_package,
      "CHANGE PACKAGE" order_type,
      current_timestamp() prc_dt
    from CPPASSET
    where rk = 1;
    SET start_date = DATE_ADD(start_date, INTERVAL 1 DAY);
  END WHILE;
END;