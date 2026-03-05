CREATE OR REPLACE PROCEDURE `data-bi-prd-935c.bi_dm.f_ftth_hifi_cumulative_subs`(IN starts_date DATE, IN observation_date DATE)
BEGIN
  DECLARE end_of_month DATE;
  DECLARE eop_previous_month DATE;
  DECLARE start_prev_month DATE;
  DECLARE start_current_month DATE;
  DECLARE yday_date DATE;
  DECLARE today_date DATE;

  -- ✅ variable lokal untuk loop (parameter starts_date tetap ada & tidak diubah)
  DECLARE run_date DATE DEFAULT starts_date;

  SET end_of_month = LAST_DAY(observation_date, MONTH);
  SET eop_previous_month = LAST_DAY(DATE_SUB(observation_date, INTERVAL 1 MONTH));
  SET start_prev_month = DATE_TRUNC(eop_previous_month, MONTH);
  SET start_current_month = DATE_TRUNC(observation_date, MONTH);

  WHILE run_date <= observation_date DO
    SET yday_date = DATE(DATE_SUB(DATE(run_date), INTERVAL 1 DAY));
    SET today_date = DATE(DATE_ADD(DATE(run_date), INTERVAL 1 DAY));

    DELETE FROM `data-bi-prd-935c.bi_dm.ftth_cumulative_subs`
    WHERE dt_id = run_date
      AND flag_customer = "HIFI";

    -- ✅ CPP temp: end_date dibuat NON-OVERLAP (di-clip pakai next cpp_date)
    CREATE OR REPLACE TABLE `data-bi-prd-935c.bi_dm.cpp_order_complete_temp` AS
    WITH base AS (
      SELECT
        *,
        cpp_date AS start_date,
        SAFE_CAST(
          REGEXP_EXTRACT(product_after, r'(?i)\b(?:AP|SUPER)\s*(\d+)\s*-')
          AS INT64
        ) AS contract_months,
        LEAD(cpp_date) OVER (PARTITION BY billing_account ORDER BY cpp_date) AS next_cpp_date,
        ROW_NUMBER() OVER (PARTITION BY billing_account ORDER BY cpp_date) AS cpp_number
      FROM `data-bi-prd-935c.bi_dm.ftth_cpp_order_complete`
    ),
    typed AS (
      SELECT
        *,
        CASE WHEN contract_months IS NOT NULL THEN 'CONTRACT' ELSE 'MONTHLY' END AS contract_type_cpp,
        CASE
          WHEN contract_months IS NOT NULL THEN
            DATE_SUB(DATE_ADD(DATE(start_date), INTERVAL contract_months MONTH), INTERVAL 1 DAY)
          ELSE
            DATE '2099-01-01'
        END AS natural_end_date
      FROM base
    )
    SELECT
      * EXCEPT(natural_end_date),
      CASE
        WHEN next_cpp_date IS NULL THEN natural_end_date
        ELSE LEAST(natural_end_date, DATE_SUB(DATE(next_cpp_date), INTERVAL 1 DAY))
      END AS end_date
    FROM typed
    ORDER BY billing_account, cpp_number;

    INSERT INTO `data-bi-prd-935c.bi_dm.ftth_cumulative_subs`
    WITH PREPARATIONHIFI AS (
      select * except(rk) from (
        select
          a.customer_id,
          a.billing_account,
          a.billing_account_id,
          a.customer_account_id,
          date(order_in_progress_date) so_date,
          date(order_in_progress_date) sa_date,
          date(coalesce(date(gross_add_date), date(activation_date))) pa_date,
          flag_account,
          coalesce(
            case
              when consolidated_site_id like '%AMT%' then 'ASIANET'
              when consolidated_site_id like '%IFT%' then 'IFORTE'
            end,
            case
              when ftth_partnername like '%ASIANET%' then 'ASIANET'
              when ftth_partnername like '%IFORTE%' then 'IFORTE' 
            end
          ) partner_name,
          consolidated_site_id site_id,
          run_date dt_id,
          ROW_NUMBER() OVER (PARTITION BY a.billing_account ORDER BY a.dt_id DESC) rk
        from (
          select * from `data-dtptechm-prd-c7ca.ioh_ftth.ftth_subscriber_vw`
          where date(dt_id) = run_date
          and length(billing_account) = 8
        ) a
        left join `data-bi-prd-935c.bi_dm.ftth_billing_ref_site` b
        on a.billing_account = b.billing_account
      ) a
      where rk = 1
    ),    
    ASSET AS (
      SELECT * EXCEPT(rk)
      FROM (
        SELECT
          ba_id,
          pd_nm,
          ROW_NUMBER() OVER(
            PARTITION BY ba_id
            ORDER BY DATE(FORMAT_TIMESTAMP('%Y-%m-%d', PARSE_TIMESTAMP('%d-%m-%Y %H:%M:%S',
              COALESCE(NULLIF(TRIM(actvn_dt), ''), last_udt_dt)
            ))) DESC
          ) rk
        FROM `data-dtp-prd-aa1a.stg.stg_catalist_dly_ast`
        WHERE DATE(dt_id) = run_date
          AND pd_tp = 'Plan'
          AND ast_st = 'Active'
          AND UPPER(pd_nm) LIKE '%HIF%'
      ) a
      WHERE rk = 1
    ),
    ASSETAC AS (
      SELECT
        DISTINCT
        a.ba_id,
        a.ac_refr,
        a.ac_st_dt,
        a.ac_nm,
        CONCAT(adr, " ", adr_line_2) address,
        email,
        mbl_no phone_num,
        day_ph_num phone_num_2,
        b.pd_nm
      FROM `data-dtp-prd-aa1a.stg.stg_catalist_dly_ba` a
      LEFT JOIN ASSET b
        ON a.ba_id = b.ba_id
      WHERE DATE(dt_id) = run_date
        AND cr_clss = "FTTH Customer"
        and a.ba_id != '2-7LHDJ3R6'
    ),
    CPPORDER AS (
      SELECT * FROM `data-bi-prd-935c.bi_dm.cpp_order_complete_temp`
    ),
    CARRYFWD AS (
      SELECT
        billing_account,
        product_after AS prev_product_after,
        current_package_date AS prev_current_package_date
      FROM `data-bi-prd-935c.bi_dm.ftth_cumulative_subs`
      WHERE dt_id = yday_date
        AND flag_customer = "HIFI"
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
      SELECT
        a.*,
        DATE(FORMAT_TIMESTAMP('%Y-%m-%d', PARSE_TIMESTAMP('%d-%m-%Y %H:%M:%S', c.ac_st_dt))) ac_st_dt,
        CASE
          WHEN flag_account IN ("Active", "Suspension-Bucket 1")
            THEN DATE_DIFF(DATE(a.dt_id), DATE(pa_date), MONTH)
          ELSE DATE_DIFF(DATE(DATE_ADD(DATE(FORMAT_TIMESTAMP('%Y-%m-%d', PARSE_TIMESTAMP('%d-%m-%Y %H:%M:%S', c.ac_st_dt))), INTERVAL 30 DAY)), DATE(pa_date), MONTH)
        END AS tenure_month,
        CASE
          WHEN flag_account IN ("Active", "Suspension-Bucket 1")
            THEN DATE_DIFF(DATE(a.dt_id), DATE(pa_date), DAY)
          ELSE DATE_DIFF(DATE(DATE_ADD(DATE(FORMAT_TIMESTAMP('%Y-%m-%d', PARSE_TIMESTAMP('%d-%m-%Y %H:%M:%S', c.ac_st_dt))), INTERVAL 30 DAY)), DATE(pa_date), DAY)
        END AS tenure_day,
        c.ac_nm asset_name,
        c.address,
        c.email,
        c.phone_num,
        c.phone_num_2,

        -- ✅ COALESCE anti-whitespace
        COALESCE(NULLIF(TRIM(d.product_before), ''), c.pd_nm) AS product_before,
        COALESCE(NULLIF(TRIM(d.product_after),  ''), c.pd_nm) AS product_after,

        CASE
          WHEN UPPER(COALESCE(NULLIF(TRIM(d.product_after), ''), c.pd_nm)) LIKE '%SUPER 3 -%' THEN '3-month'
          WHEN UPPER(COALESCE(NULLIF(TRIM(d.product_after), ''), c.pd_nm)) LIKE '%AP3%' THEN '3-month'
          WHEN UPPER(COALESCE(NULLIF(TRIM(d.product_after), ''), c.pd_nm)) LIKE '%AP4%' THEN '4-month'
          WHEN UPPER(COALESCE(NULLIF(TRIM(d.product_after), ''), c.pd_nm)) LIKE '%SUPER 6 -%' THEN '6-month'
          WHEN UPPER(COALESCE(NULLIF(TRIM(d.product_after), ''), c.pd_nm)) LIKE '%AP6%' THEN '6-month'
          WHEN UPPER(COALESCE(NULLIF(TRIM(d.product_after), ''), c.pd_nm)) LIKE '%AP7%' THEN '7-month'
          WHEN UPPER(COALESCE(NULLIF(TRIM(d.product_after), ''), c.pd_nm)) LIKE '%SUPER 12 -%' THEN '12-month'
          WHEN UPPER(COALESCE(NULLIF(TRIM(d.product_after), ''), c.pd_nm)) LIKE '%AP12%' THEN '12-month'
          WHEN UPPER(COALESCE(NULLIF(TRIM(d.product_after), ''), c.pd_nm)) IS NULL THEN 'Unknown'
          ELSE '1-month'
        END AS contract_type,

        e.Monthly_Price current_package_price,

        CAST(
          REGEXP_EXTRACT_ALL(
            UPPER(COALESCE(NULLIF(TRIM(d.product_before), ''), c.pd_nm)),
            r'UP TO\s(\d+)\s?MBPS'
          )[SAFE_OFFSET(
            ARRAY_LENGTH(REGEXP_EXTRACT_ALL(
              COALESCE(NULLIF(TRIM(d.product_before), ''), c.pd_nm),
              r'UP TO\s(\d+)\s?MBPS'
            )) - 1
          )] AS INT64
        ) AS up_to_speed_before,
        CAST(REGEXP_EXTRACT(UPPER(COALESCE(NULLIF(TRIM(d.product_before), ''), c.pd_nm)), r'(\d+)\s?MBPS') AS INT64) AS first_speed_before,
        CASE
          WHEN REGEXP_CONTAINS(COALESCE(NULLIF(TRIM(d.product_before), ''), c.pd_nm), r'(?i)1\s?GBPS') THEN 1000
          ELSE NULL
        END AS gbps_speed_before,

        CASE
          -- (1) kalau kecatat CPP -> pakai cpp_date (ini pasti stabil)
          WHEN d.cpp_date IS NOT NULL THEN DATE(d.cpp_date)

          -- (3) kalau ga ada CPP tapi produk berubah hari ini -> set dt_id (HANYA di hari pertama perubahan)
          WHEN prevs.prev_product_after IS NOT NULL
          AND REGEXP_REPLACE(UPPER(COALESCE(NULLIF(TRIM(d.product_after), ''), c.pd_nm)), r'\s+', '') !=
              REGEXP_REPLACE(UPPER(NULLIF(TRIM(prevs.prev_product_after), '')), r'\s+', '')
            THEN DATE(a.dt_id)

          -- (2) kalau ga ada CPP dan tidak ada perubahan -> carry forward tanggal kemarin
          WHEN prevs.prev_current_package_date IS NOT NULL THEN DATE(prevs.prev_current_package_date)

          -- fallback kalau hari pertama dan belum ada prev
          ELSE a.pa_date
        END AS current_package_date,

        CAST(
          REGEXP_EXTRACT_ALL(
            UPPER(COALESCE(NULLIF(TRIM(d.product_after), ''), c.pd_nm)),
            r'UP TO\s(\d+)\s?MBPS'
          )[SAFE_OFFSET(
            ARRAY_LENGTH(REGEXP_EXTRACT_ALL(
              COALESCE(NULLIF(TRIM(d.product_after), ''), c.pd_nm),
              r'UP TO\s(\d+)\s?MBPS'
            )) - 1
          )] AS INT64
        ) AS up_to_speed_after,
        CAST(REGEXP_EXTRACT(UPPER(COALESCE(NULLIF(TRIM(d.product_after), ''), c.pd_nm)), r'(\d+)\s?MBPS') AS INT64) AS first_speed_after,
        CASE
          WHEN REGEXP_CONTAINS(COALESCE(NULLIF(TRIM(d.product_after), ''), c.pd_nm), r'(?i)1\s?GBPS') THEN 1000
          ELSE NULL
        END AS gbps_speed_after,

        IFNULL(cpp_number, 0) AS total_cpp,
        UPPER(ft_dati_ii) kota,
        UPPER(ft_kecamatan) kecamatan,
        UPPER(ft_kelurahan) kelurahan,


        g.serial_number,
        g.ont_mac
      FROM PREPARATIONHIFI a
      LEFT JOIN (
        SELECT DISTINCT ca_id, ca_refr
        FROM `data-dtp-prd-aa1a.stg.stg_catalist_dly_ca`
        WHERE DATE(dt_id) = run_date
          AND bsn_line = "FTTH Customer"
      ) b
        ON a.customer_id = b.ca_refr
      LEFT JOIN ASSETAC c
        ON a.billing_account = c.ac_refr
      LEFT JOIN (
        SELECT ft_site_id, ft_dati_ii, ft_kecamatan, ft_kelurahan
        FROM `data-bi-prd-935c.bi_dm.tysg_master_homepass_rfs`
        WHERE DATE(dt_id) = (SELECT MAX(DATE(dt_id)) FROM `data-bi-prd-935c.bi_dm.tysg_master_homepass_rfs`)
      ) f
        ON a.site_id = f.ft_site_id

      -- ✅ JOIN CPP: range join biasa, end_date udah rapi & non-overlap
      LEFT JOIN CPPORDER d
        ON a.billing_account = d.billing_account
       AND a.dt_id BETWEEN DATE(d.start_date) AND DATE(d.end_date)

      -- ✅ join catalog pakai product_after yang sudah anti-whitespace
      LEFT JOIN `data-bi-prd-935c.bi_dm.mlg_ftth_product_catalog` e
        ON REGEXP_REPLACE(COALESCE(NULLIF(TRIM(d.product_after), ''), c.pd_nm), " ", "") = REGEXP_REPLACE(e.Product_Name, " ", "")

      left join ONTMAC g
        on a.billing_account = g.billing_account
      
      LEFT JOIN CARRYFWD prevs
      ON a.billing_account = prevs.billing_account
    )
    SELECT
      DISTINCT
      'HIFI' flag_customer,
      a.customer_account_id,
      a.billing_account_id,
      a.customer_id,
      a.billing_account,
      ac_st_dt,
      tenure_day,
      CASE
        WHEN tenure_month <= 1 THEN '<= 1 month'
        WHEN tenure_month <= 3 THEN '<= 3 months'
        WHEN tenure_month <= 6 THEN '<= 6 months'
        WHEN tenure_month <= 12 THEN '<= 12 months'
        ELSE '12+ months'
      END AS aon_category,
      a.so_date,
      sa_date,
      pa_date,
      current_package_date,
      flag_account,
      CAST(NULL AS STRING) legacy_package,
      a.product_before,
      a.product_after,
      CONCAT(COALESCE(up_to_speed_before, gbps_speed_before, first_speed_before), " Mbps") AS speed_before,
      CONCAT(COALESCE(up_to_speed_after, gbps_speed_after, first_speed_after), " Mbps") AS speed_after,
      contract_type,
      CAST(current_package_price AS NUMERIC) current_package_price,
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
      CONCAT(a.billing_account, '@hifi.ioh.co.id') nai,
      run_date dt_id
    FROM ETLPROCESS_1 a;

    DROP TABLE `data-bi-prd-935c.bi_dm.cpp_order_complete_temp`;

    -- ✅ increment loop date (tanpa ubah parameter starts_date)
    SET run_date = DATE_ADD(run_date, INTERVAL 1 DAY);
  END WHILE;
END;