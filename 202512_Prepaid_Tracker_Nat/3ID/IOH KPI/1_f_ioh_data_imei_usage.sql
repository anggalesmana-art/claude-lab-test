DECLARE vdt_id DATE DEFAULT @vdt_id;

delete from `data-bi-prd-935c.bi_mart.project_ioh_data_imei_usage`
where dt_sk_id = vdt_id;

insert into `data-bi-prd-935c.bi_mart.project_ioh_data_imei_usage`
SELECT 
  created_dt_sk_id,
  sbscrptn_msisdn, 
  sbscrptn_ek_id,
  served_imeisv, 
  gprs_rating_grp_nm,
  rat_type,
  SUBSTRING(apn_for_gprs_nm, 1, 5) AS apn_prefix,
  SUM(COALESCE(uplink_vol, 0) + COALESCE(downlink_vol, 0)) AS total_volume
FROM 
  `data-dtptechm-prd-c7ca.dwh.gprs_usage_fct` where created_dt_sk_id = vdt_id
GROUP BY 
  created_dt_sk_id, sbscrptn_msisdn, sbscrptn_ek_id, served_imeisv, gprs_rating_grp_nm, rat_type, apn_prefix;