--Migrated Script to GCP By Indra Maulana Ikhsan 20241203
declare vdt_id date default @vdt_id;
--- Temp 1
CREATE OR REPLACE TABLE `data-bi-prd-935c.bi_mart`.data_addon2_{{ vdt_id }}_tmp1 as
SELECT msisdn, dt_id, subs_brand_sc_name, ifnull(a.ma_rev_code,a.da1_rev_code) rev_code, usg_svc_class_cd
, b.level_5, b.level_1, b.level_9, usg_hits, data_rev, subs_actvn_dt AS actvn_dt, subs_tnr AS tnr
, pkg_original_price, pkg_sid, pkg_reg_channel, pkg_pvrid, pkg_ngssp_transaction_id, pkg_commercial_name
FROM `data-dtp-prd-aa1a.smy`.cst_usg_dly_smy a
INNER JOIN `data-dtp-prd-aa1a.sor`.ref_revcode b 
ON ifnull(a.ma_rev_code,a.da1_rev_code) = b.rev_code 
WHERE date(dt_id) = vdt_id
  AND SVC_USG_TP_REV = 'DATA'
  AND b.level_7 = 'DATA REG' ;
  
--- Insert
delete from `data-bi-prd-935c.bi_mart`.data_addon_dly  where dt_id = vdt_id;
INSERT into `data-bi-prd-935c.bi_mart`.data_addon_dly
SELECT msisdn, subs_brand_sc_name AS brnd_id, tnr, usg_svc_class_cd AS svc_class_code
, rev_code, level_1, usg_hits, data_rev, pkg_original_price, pkg_sid, pkg_reg_channel
, pkg_pvrid, pkg_ngssp_transaction_id, pkg_commercial_name, timestamp(current_datetime('+7')) AS ppn_dttm, date(dt_id) dt_id 
FROM `data-bi-prd-935c.bi_mart`.data_addon2_{{ vdt_id }}_tmp1 ;

--- Drop Temp Table
DROP TABLE `data-bi-prd-935c.bi_mart`.data_addon2_{{ vdt_id }}_tmp1;  
