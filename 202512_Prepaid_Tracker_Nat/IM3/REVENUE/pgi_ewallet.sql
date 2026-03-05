--Migrated Script to GCP By Indra Maulana Ikhsan 20241203
declare vdt_id date default @vdt_id;
 
--- Temp Table PGI
CREATE OR REPLACE TABLE `data-bi-prd-935c.bi_stg`.pgi_ewallet_{{ vdt_id }}_pgi as
SELECT a.msisdn, 
CASE WHEN upper(sof) IN ('CC/DC') THEN 'CARD'
     WHEN upper(sof) IN ('GOPAY','OVO','SHOPEEPAY','IMKAS','DANA') THEN 'WALLET'
	 WHEN upper(sof) LIKE 'VA%' THEN 'TRANSFERS'	
END channel, 
upper(sof) AS merchant, a.product_id, d.product_name,
CAST(amount AS numeric) rev, 
CASE WHEN a.msisdn = c.msisdn THEN 'Prepaid'
END subs_flag, svc_class_code, site_id
FROM `data-dtp-prd-aa1a.stg`.myim3_payment_aj_report a
LEFT JOIN 
( SELECT msisdn, site_id FROM `data-dtp-prd-aa1a.sor`.subs_fav_loc_dly_carry_fwd  
  WHERE date(dt_id) = vdt_id
) b
ON a.msisdn = b.msisdn 
LEFT JOIN 
( SELECT msisdn, svc_class_code FROM `data-dtp-prd-aa1a.smy`.ar_cst_dly_smy
  WHERE date(dt_id) = vdt_id
) c
ON a.msisdn = c.msisdn 
LEFT JOIN 
( SELECT DISTINCT revenue_code, product_name 
  FROM `data-cvm-prd-c324.sor.im3_ref_pgi` --coreprop.rls_pgireff
) d
ON a.product_id = d.revenue_code
WHERE date(a.dt_id) = vdt_id
  AND lower(jenis_transaksi) = 'package' 
  AND lower(status_fulfillment) = 'success'
  AND CAST(amount as numeric) > 0 ;

--- Temp Table eWallet
CREATE OR REPLACE TABLE `data-bi-prd-935c.bi_stg`.pgi_ewallet_{{ vdt_id }}_wlt as
SELECT a.msisdn, esb_channel channel, target merchant,
product_id, product_name, CAST(amount AS numeric) rev, 
CASE WHEN a.msisdn = c.msisdn THEN 'Prepaid'
END subs_flag, svc_class_code, site_id
FROM `data-dtp-prd-aa1a.sor`.transactiondaily_esb a
LEFT JOIN 
( SELECT msisdn, site_id FROM `data-dtp-prd-aa1a.sor`.subs_fav_loc_dly_carry_fwd  
  WHERE date(dt_id) = vdt_id
) b
ON a.msisdn = b.msisdn 
LEFT JOIN 
( SELECT msisdn, svc_class_code FROM `data-dtp-prd-aa1a.smy`.ar_cst_dly_smy
  WHERE date(dt_id) = vdt_id
) c
ON a.msisdn = c.msisdn 
left join (
  select *, '${var:dtid}' dt_id from `data-bi-prd-935c.revenue.rmcs_ref_drop` where type = 'E-Wallet'
) ref_drop
ON upper(trim(a.product_name))=upper(trim(ref_drop.rev_code))
WHERE date(a.dt_id) = vdt_id
AND payment_type = 'Push to Pay (PTP)'
AND status IN ('1 - Payment Successful', '00 - Success', '200 - Transaction Successful', '00 - Transaction Successful','3-Transaction Successful')
AND esb_channel in ('CHATBOTWA','DPP-CHATBOTWAIM3','DPP-DSDP','HIFIAIRPWA','MILLOM','MRTM','UMB','V2MYIM3')
AND lower(product_name) not like '%top%up%'
AND lower(product_name) not like '%billpayment%' 
and ref_drop.rev_code is null;

--- Insert Into 
delete from `data-bi-prd-935c.bi_mart`.pgi_ewallet_site where dt_id = vdt_id;
INSERT into `data-bi-prd-935c.bi_mart`.pgi_ewallet_site
SELECT a.*, 'PGI' flag, timestamp(current_datetime('+7')) ppn_dttm, vdt_id dt_id
FROM `data-bi-prd-935c.bi_stg`.pgi_ewallet_{{ vdt_id }}_pgi a 
UNION ALL
SELECT b.*, 'EWALLET' flag, timestamp(current_datetime('+7')) ppn_dttm, vdt_id dt_id
FROM `data-bi-prd-935c.bi_stg`.pgi_ewallet_{{ vdt_id }}_wlt b
;

--- Drop Temp Table
DROP TABLE `data-bi-prd-935c.bi_stg`.pgi_ewallet_{{ vdt_id }}_pgi;
DROP TABLE `data-bi-prd-935c.bi_stg`.pgi_ewallet_{{ vdt_id }}_wlt;
