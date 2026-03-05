DECLARE column_list STRING;
DECLARE merge_cpp STRING;

CREATE OR REPLACE TABLE `data-bi-prd-935c.bi_dm.tysg_temp_change_product_dev` as
WITH base AS (
  select
     *,
    CAST(
        REGEXP_EXTRACT_ALL(upper(product_before), r'UP TO\s(\d+)\s?MBPS')[SAFE_OFFSET(ARRAY_LENGTH(REGEXP_EXTRACT_ALL(product_before, r'UP TO\s(\d+)\s?MBPS')) - 1)] AS INT64
    ) AS up_to_speed_before,
    -- Ekstrak angka pertama di teks
    CAST(REGEXP_EXTRACT(upper(product_before), r'(\d+)\s?MBPS') AS INT64) AS first_speed_before,
    -- Cek apakah teks mengandung "1 GBPS" dan set nilai ke 1000
    CASE
      WHEN REGEXP_CONTAINS(product_before, r'(?i)1\s?GBPS') THEN 1000
      ELSE NULL
    END AS gbps_speed_before
  from (
    SELECT
      billing_account,
      ba_id,
      DATE(dt_id) AS tanggal,
      current_package,
      speed_legacy,
      speed_current,
      LAG(current_package) OVER (PARTITION BY billing_account ORDER BY DATE(dt_id)) AS product_before
    FROM `data-bi-prd-935c.bi_dm.tysg_temp_subs_orbit`
  )
),
changes_only AS (
  SELECT
    billing_account,
    ba_id,
    tanggal AS change_date,
    product_before,
    current_package AS product_after,
    CASE
      when product_before = "Bundlingtvinet-G300K AP3 Family Pack + Up To 10" then "10 Mbps"
      when product_before = "Bundlingtvinet-Fighting Pack + Up to 20 Mpbs" then "20 Mbps"
      when product_before = "Bundlingtvinet-HOT20 Pack" then "20 Mbps"
      when product_before = "Bundlingtvinet-G300K AP3 Family Pack + Up To 20" then "20 Mbps"
      else concat(coalesce(up_to_speed_before, gbps_speed_before, first_speed_before), " Mbps") 
    end as speed_before,
    case
      when product_before = "Bundlingtvinet-G300K AP3 Family Pack + Up To 10" then "10 Mbps"
      when product_before = "Bundlingtvinet-Fighting Pack + Up to 20 Mpbs" then "20 Mbps"
      when product_before = "Bundlingtvinet-HOT20 Pack" then "20 Mbps"
      when product_before = "Bundlingtvinet-G300K AP3 Family Pack + Up To 20" then "20 Mbps"
      else speed_legacy
    end as speed_legacy,
    speed_current,
  FROM base
  WHERE product_before IS DISTINCT FROM current_package  -- hanya ambil yang berubah
),
CPPCOMPLETE AS (
  select 
    billing_account,
    ba_id,
    product_before,
    speed_before,
    product_after,
    speed_current,
    current_package_date,
    status_package,
    ordr_tp order_type
  from (
  SELECT
    a.*,
    package_after,
    coalesce(cpp_date, change_date) current_package_date,
    case
      when (
        lower(a.product_before) not like '%hifi%'
        and lower(product_after) like '%hifi%'
        and ordr_tp is null
        and speed_current = speed_legacy
      ) then "EXISITING NORMALIZE"
      when (
        (
          lower(a.product_before) like '%hifi%' 
          and lower(product_after) like '%hifi%' 
          and product_before!=product_after 
          and ordr_tp is null
        )
        or
          (
            speed_current != speed_legacy
            and ordr_tp is null
            and package_after is null
          )
      ) then "MASSLOADER CPP"
      else upper(b.ordr_tp) 
    end as status_package,
    upper(b.ordr_tp) ordr_tp
  FROM changes_only a
  left join `data-bi-prd-935c.bi_dm.tysg_temp_cpp_products` b
  on a.ba_id = b.ba_id and a.change_date = b.cpp_date
  ORDER BY billing_account, change_date
  ) a
  where a.change_date != "2024-10-22"
  and product_after != product_before
)
select *
from CPPCOMPLETE;

SET column_list = (
  SELECT STRING_AGG(CONCAT("cpp.", column_name, " = tp.", column_name), ', ')
  FROM `data-bi-prd-935c.bi_dm.INFORMATION_SCHEMA.COLUMNS`
  WHERE table_name = 'tysg_ftth_cpp_orbit'
  AND column_name NOT IN ('prc_dt')
);

SET merge_cpp = CONCAT (
  "MERGE `data-bi-prd-935c.bi_dm.tysg_ftth_cpp_orbit` cpp ",
  "USING (SELECT *, timestamp(DATETIME(CURRENT_TIMESTAMP(), 'Asia/Jakarta')) as prc_dt FROM `data-bi-prd-935c.bi_dm.tysg_temp_change_product_dev` WHERE current_package_date = DATE_SUB(current_date('Asia/Jakarta'), Interval 1 Day)) tp ",
  "ON cpp.billing_account = tp.billing_account AND cpp.current_package_date = DATE(tp.current_package_date) ",
  "WHEN MATCHED THEN UPDATE SET ", column_list, " ",
  "WHEN NOT MATCHED THEN INSERT ROW;"
);
EXECUTE IMMEDIATE merge_cpp;