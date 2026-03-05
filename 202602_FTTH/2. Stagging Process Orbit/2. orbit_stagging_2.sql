CREATE OR REPLACE TABLE `data-bi-prd-935c.bi_dm.tysg_temp_cpp_order` as
select
  distinct
  ca_id,
  ba_id,
  ordr_id,
  ordr_num,
  ordr_tp,
  date(FORMAT_TIMESTAMP('%Y-%m-%d', PARSE_TIMESTAMP('%d-%m-%Y %H:%M:%S', ordr_crt_dt))) po_date,
  date(FORMAT_TIMESTAMP('%Y-%m-%d', PARSE_TIMESTAMP('%d-%m-%Y %H:%M:%S', ordr_submission_dt))) so_date,
  date(FORMAT_TIMESTAMP('%Y-%m-%d', PARSE_TIMESTAMP('%d-%m-%Y %H:%M:%S', ordr_compl_dt))) cpp_date
from `data-dtp-prd-aa1a.stg.stg_catalist_dly_ordr`
where date(dt_id) between "2024-10-22" and DATE_SUB(CURRENT_DATE("Asia/Jakarta"), Interval 1 day)
and ordr_tp = "Change Package"
and ordr_st = "Complete"
and ordr_compl_dt <> ""
and date(FORMAT_TIMESTAMP('%Y-%m-%d', PARSE_TIMESTAMP('%d-%m-%Y %H:%M:%S', ordr_compl_dt))) between "2024-10-22" and DATE_SUB(CURRENT_DATE("Asia/Jakarta"), Interval 1 day)
and pd_cgy = "FTTH";


CREATE OR REPLACE TABLE `data-bi-prd-935c.bi_dm.tysg_temp_cpp_products` as
select 
  a.*,
  b.pd_tp,
  MAX(CASE WHEN b.ast_st = 'Active' THEN b.pd_id END) AS pd_id_after,
  MAX(CASE WHEN b.ast_st = 'Active' THEN b.pd_nm END) AS package_after,
  MAX(CASE WHEN b.ast_st = 'Inactive' THEN b.pd_id END) AS pd_id_before,
  MAX(CASE WHEN b.ast_st = 'Inactive' THEN b.pd_nm END) AS package_before
from `data-bi-prd-935c.bi_dm.tysg_temp_cpp_order` a
inner join `data-dtp-prd-aa1a.stg.stg_catalist_dly_ast` b
on a.ba_id = b.ba_id and date(a.cpp_date) = date(b.dt_id)
where date(b.dt_id) between "2024-10-22" and DATE_SUB(CURRENT_DATE("Asia/Jakarta"), Interval 1 day)
-- where date(b.dt_id) = DATE_SUB(CURRENT_DATE("Asia/Jakarta"), Interval 1 day)
and b.pd_tp = "Plan"
group by 1,2,3,4,5,6,7,8,9
order by ba_id, cpp_date;


CREATE OR REPLACE TABLE `data-bi-prd-935c.bi_dm.tysg_temp_subs_orbit` as
with PRODUCTSPEED as (
  select * except(rk) 
  from (
    select
      *,
      row_number() over(partition by ba_id, dt_id order by current_package desc) rk
    from `data-bi-prd-935c.bi_dm.tysg_ftth_stg_orbit_subs`
    -- where dt_id = DATE_SUB(current_date("Asia/Jakarta"), Interval 1 day)
  ) a
  where rk = 1
),
SPEEDETAIL AS (
  select
    dt_id,
    ba_id,
    billing_account,
    legacy_package,
    current_package_price,
    current_package_date,
    concat(coalesce(up_to_speed_legacy, gbps_speed_legacy, first_speed_legacy), " Mbps") as speed_legacy,
    current_package,
    concat(coalesce(up_to_speed_now, gbps_speed_now, first_speed_now), " Mbps") as speed_current,
  from (
    select 
      *,
      CAST(
            REGEXP_EXTRACT_ALL(upper(legacy_package), r'UP TO\s(\d+)\s?MBPS')[SAFE_OFFSET(ARRAY_LENGTH(REGEXP_EXTRACT_ALL(legacy_package, r'UP TO\s(\d+)\s?MBPS')) - 1)] AS INT64
        ) AS up_to_speed_legacy,
        -- Ekstrak angka pertama di teks
        CAST(REGEXP_EXTRACT(upper(legacy_package), r'(\d+)\s?MBPS') AS INT64) AS first_speed_legacy,
        -- Cek apakah teks mengandung "1 GBPS" dan set nilai ke 1000
        CASE
          WHEN REGEXP_CONTAINS(legacy_package, r'(?i)1\s?GBPS') THEN 1000
          ELSE NULL
        END AS gbps_speed_legacy,
      CAST(
            REGEXP_EXTRACT_ALL(upper(current_package), r'UP TO\s(\d+)\s?MBPS')[SAFE_OFFSET(ARRAY_LENGTH(REGEXP_EXTRACT_ALL(current_package, r'UP TO\s(\d+)\s?MBPS')) - 1)] AS INT64
        ) AS up_to_speed_now,
        -- Ekstrak angka pertama di teks
        CAST(REGEXP_EXTRACT(upper(current_package), r'(\d+)\s?MBPS') AS INT64) AS first_speed_now,
        -- Cek apakah teks mengandung "1 GBPS" dan set nilai ke 1000
        CASE
          WHEN REGEXP_CONTAINS(current_package, r'(?i)1\s?GBPS') THEN 1000
          ELSE NULL
        END AS gbps_speed_now
    from PRODUCTSPEED
  ) a
)
select * from SPEEDETAIL;