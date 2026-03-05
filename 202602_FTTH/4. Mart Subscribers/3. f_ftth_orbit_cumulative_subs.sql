CREATE OR REPLACE PROCEDURE `data-bi-prd-935c.bi_dm.f_ftth_orbit_cumulative_subs`(IN start_date DATE, IN observation_date DATE)
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
  -- SET yday_date = date(DATE_SUB(date(start_date), interval 1 day));

  WHILE start_date <= observation_date DO
    SET yday_date = date(DATE_SUB(date(start_date), interval 1 day));
    SET today_date = DATE(DATE_ADD(DATE(start_date), INTERVAL 1 DAY));

    delete from `data-bi-prd-935c.bi_dm.ftth_cumulative_subs`
    where dt_id = start_date
    and flag_customer = "MNC";

    INSERT INTO `data-bi-prd-935c.bi_dm.ftth_cumulative_subs`
    WITH PREPARATIONMNC AS (
      select * except(rk) from (
        select
          a.customer_id,
          a.billing_account,
          a.ba_id billing_account_id,
          a.ca_id customer_account_id,
          so_date,
          sa_date,
          pa_date,
          flag_account,
          coalesce(
            case
              when consolidated_site_id like '%AMT%' then 'ASIANET'
              when consolidated_site_id like '%IFT%' then 'IFORTE'
            end,
            case
              when a.vendor like '%ASIANET%' then 'ASIANET'
              when a.vendor like '%IFORTE%' then 'IFORTE' 
            end
          ) partner_name,
          consolidated_site_id site_id,
          start_date dt_id,
          ROW_NUMBER() OVER (PARTITION BY a.billing_account ORDER BY a.dt_id DESC) rk
        from (
          select * from `data-bi-prd-935c.bi_dm.tysg_ftth_orbit_cumulative_subs`
          where date(dt_id) = start_date
          and length(billing_account) = 10
          and flag_account != 'Terminate'
        ) a
        left join `data-bi-prd-935c.bi_dm.ftth_billing_ref_site` b
        on a.billing_account = b.billing_account
      ) a
      where rk = 1
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
    ETLPROCESS_1 AS (
      select
        a.customer_id,
        a.billing_account,
        a.so_date,
        a.sa_date,
        a.pa_date,
        a.flag_account,
        a.partner_name,
        a.site_id,    
        a.customer_account_id,
        a.billing_account_id,
        d.ac_st_dt ac_st_dt,
        case
          when a.flag_account in ("Active", "Suspension-Bucket 1") then DATE_DIFF(date(a.dt_id), date(a.pa_date), MONTH)
          when a.flag_account not in ("Active", "Suspension-Bucket 1") then DATE_DIFF(date(DATE_ADD(date(d.ac_st_dt), interval 30 day)), date(a.pa_date), MONTH)
        end as tenure_month,
        case
          when a.flag_account in ("Active", "Suspension-Bucket 1") then DATE_DIFF(date(a.dt_id), date(a.pa_date), DAY)
          when a.flag_account not in ("Active", "Suspension-Bucket 1") then DATE_DIFF(date(DATE_ADD(date(d.ac_st_dt), interval 30 day)), date(a.pa_date), DAY)
        end as tenure_day,
        e.asset_name asset_name,
        e.address,
        -- concat(upper(jalan), ', NO. ', upper(nomor_rumah), ', RW. 0', rw, ', RT. 0', rt) address,
        e.email email,
        e.phone_num,
        e.phone_num_2,
        -- mobile_phone1 phone_num,
        -- mobile_phone2 phone_num_2,
        d.legacy_package,
        d.package_before,
        d.current_package,
        -- coalesce(current_package, a.product_name) product_after,
        CASE
          WHEN upper(coalesce(d.current_package)) like '%SUPER 3 -%' THEN '3-month'
          WHEN upper(coalesce(d.current_package)) like '%AP3%' THEN '3-month'
          WHEN upper(coalesce(d.current_package)) like '%AP4%' THEN '4-month'
          WHEN upper(coalesce(d.current_package)) like '%SUPER 6 -%' THEN '6-month'
          WHEN upper(coalesce(d.current_package)) like '%AP6%' THEN '6-month'
          WHEN upper(coalesce(d.current_package)) like '%AP7%' THEN '7-month'
          WHEN upper(coalesce(d.current_package)) like '%SUPER 12 -%' THEN '12-month'
          WHEN upper(coalesce(d.current_package)) like '%AP12%' THEN '12-month'
          WHEN upper(coalesce(d.current_package)) is null  THEN 'Unknown'
          ELSE '1-month'
        END as contract_type,
        -- e.contract_type,
        d.current_package_price,
        CAST(
            REGEXP_EXTRACT_ALL(upper(d.package_before), r'UP TO\s(\d+)\s?MBPS')[SAFE_OFFSET(ARRAY_LENGTH(REGEXP_EXTRACT_ALL(d.package_before, r'UP TO\s(\d+)\s?MBPS')) - 1)] AS INT64
        ) AS up_to_speed_before,
        -- Ekstrak angka pertama di teks
        CAST(REGEXP_EXTRACT(upper(d.package_before), r'(\d+)\s?MBPS') AS INT64) AS first_speed_before,
        -- Cek apakah teks mengandung "1 GBPS" dan set nilai ke 1000
        CASE
          WHEN REGEXP_CONTAINS(d.package_before, r'(?i)1\s?GBPS') THEN 1000
          ELSE NULL
        END AS gbps_speed_before,
        d.current_package_date,
        CAST(
            REGEXP_EXTRACT_ALL(upper(d.current_package), r'UP TO\s(\d+)\s?MBPS')[SAFE_OFFSET(ARRAY_LENGTH(REGEXP_EXTRACT_ALL(d.current_package, r'UP TO\s(\d+)\s?MBPS')) - 1)] AS INT64
        ) AS up_to_speed_after,
        -- Ekstrak angka pertama di teks
        CAST(REGEXP_EXTRACT(upper(d.current_package), r'(\d+)\s?MBPS') AS INT64) AS first_speed_after,
        -- Cek apakah teks mengandung "1 GBPS" dan set nilai ke 1000
        CASE
          WHEN REGEXP_CONTAINS(d.current_package, r'(?i)1\s?GBPS') THEN 1000
          ELSE NULL
        END AS gbps_speed_after,
        coalesce (
          case
            when d.current_package != e.product_after then e.total_cpp + 1
            else e.total_cpp
          end,0
        ) as total_cpp,
        upper(e.kota) kota,
        upper(e.kecamatan) kecamatan,
        upper(e.kelurahan) kelurahan,
        coalesce(f.serial_number, e.serial_number) serial_number,
        coalesce(f.ont_mac, e.ont_mac) ont_mac
        -- REGEXP_REPLACE(lower(e.macaddress), r'(.{4})(.{4})(.{4})', r'\1.\2.\3') AS ont_mac
      from PREPARATIONMNC a
      left join (
        select
          distinct
          ca_id, ba_id, ac_refr, ac_st_dt, ac_nm, concat(adr, " ", adr_line_2) address, email, mbl_no phone_num, day_ph_num phone_num_2
        from `data-dtp-prd-aa1a.stg.stg_catalist_dly_ba`
        where dt_id = "2024-10-31"
        and cr_clss = "FTTH Customer"
      ) c
      on a.billing_account = c.ac_refr
      left join (
        select * from `data-bi-prd-935c.bi_dm.tysg_ftth_orbit_cumulative_subs`
        where date(dt_id) = start_date
      ) d
      on a.billing_account = d.billing_account AND a.dt_id = date(d.dt_id)
      left join (
        select * 
        from `data-bi-prd-935c.bi_dm.ftth_cumulative_subs` 
        where dt_id = yday_date
      ) e 
      on a.billing_account = e.billing_account
      left join ONTMAC f
      on a.billing_account = f.billing_account
    )
    select
      'MNC' flag_customer,
      customer_account_id,
      billing_account_id,
      customer_id,
      billing_account,
      date(ac_st_dt) ac_st_dt,
      tenure_day,
      CASE
        WHEN tenure_month <= 1 THEN '<= 1 month'
        WHEN tenure_month <= 3 THEN '<= 3 months'
        WHEN tenure_month <= 6 THEN '<= 6 months'
        WHEN tenure_month <= 12 THEN '<= 12 months'
        ELSE '12+ months'
      END AS aon_category,
      so_date,
      sa_date,
      pa_date,
      date(current_package_date) current_package_date,
      flag_account,
      legacy_package,
      package_before product_before,
      current_package product_after,
      CASE
        when package_before = "Bundlingtvinet-G300K AP3 Family Pack + Up To 10" then "10 Mbps"
        when package_before = "Bundlingtvinet-Fighting Pack + Up to 20 Mpbs" then "20 Mbps"
        when package_before = "Bundlingtvinet-HOT20 Pack" then "20 Mbps"
        when package_before = "Bundlingtvinet-G300K AP3 Family Pack + Up To 20" then "20 Mbps"
        else concat(coalesce(up_to_speed_before, gbps_speed_before, first_speed_before), " Mbps") 
      end as speed_before,
      case
        when current_package = "Bundlingtvinet-G300K AP3 Family Pack + Up To 10" then "10 Mbps"
        when current_package = "Bundlingtvinet-Fighting Pack + Up to 20 Mpbs" then "20 Mbps"
        when current_package = "Bundlingtvinet-HOT20 Pack" then "20 Mbps"
        when current_package = "Bundlingtvinet-G300K AP3 Family Pack + Up To 20" then "20 Mbps"
        else concat(coalesce(up_to_speed_after, gbps_speed_after, first_speed_after), " Mbps") 
      end as speed_current,
      contract_type,
      cast(current_package_price as numeric) current_package_price,
      cast(total_cpp as numeric) total_cpp,
      asset_name,
      address,
      email,
      phone_num,
      phone_num_2,
      partner_name,
      site_id,
      kota,
      kecamatan,
      kelurahan,
      serial_number,
      ont_mac,
      CONCAT(billing_account, '@hifi.ioh.co.id') nai,
      start_date dt_id
    from ETLPROCESS_1;    
    SET start_date = DATE_ADD(start_date, INTERVAL 1 DAY);
  END WHILE;
END;