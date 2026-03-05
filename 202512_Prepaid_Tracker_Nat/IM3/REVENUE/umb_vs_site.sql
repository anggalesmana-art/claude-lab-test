declare vdt_id date default @vdt_id;

--- Temp Table 1
CREATE or replace TABLE `data-bi-prd-935c.bi_stg`.umb_v_site_{{ vdt_id }}  AS
SELECT a.dt_id, b.site_id, level_1, 'Voice' svc_typ,
CASE WHEN tnr <= 30 THEN 'a.<= 1 Mth'
     WHEN tnr <= 90 THEN 'b.1 - 3 Mth'
	 WHEN tnr <= 180 THEN 'c.3 - 6 Mth'
	 WHEN tnr <= 360 THEN 'd.6 - 12 Mth'
	 WHEN tnr > 360 THEN 'e.> 12 Mth'
END tenure,
Sum(usg_hits) hits, Sum(voice_rev) rev
FROM `data-bi-prd-935c.bi_mart`.voice_addon_dly a
LEFT JOIN 
( SELECT * FROM `data-dtp-prd-aa1a.sor`.subs_fav_loc_dly_carry_fwd --`data-bi-prd-935c.bi_mart`.rk_all_90d_fav_loc_dly 
  WHERE date(dt_id) = vdt_id ) b
ON a.msisdn = b.msisdn  
WHERE a.voice_rev > 0 AND a.dt_id = vdt_id
GROUP BY a.dt_id, b.site_id, level_1, tenure ;				

--- Temp Table 2
CREATE or replace TABLE `data-bi-prd-935c.bi_stg`.umb_s_site_{{ vdt_id }}  AS
SELECT a.dt_id, b.site_id, level_1, 'SMS' svc_typ,
CASE WHEN tnr <= 30 THEN 'a.<= 1 Mth'
     WHEN tnr <= 90 THEN 'b.1 - 3 Mth'
	 WHEN tnr <= 180 THEN 'c.3 - 6 Mth'
	 WHEN tnr <= 360 THEN 'd.6 - 12 Mth'
	 WHEN tnr > 360 THEN 'e.> 12 Mth'
END tenure,
Sum(usg_hits) hits, Sum(sms_rev) rev
FROM `data-bi-prd-935c.bi_mart`.sms_addon_dly a
LEFT JOIN 
( SELECT * FROM `data-dtp-prd-aa1a.sor`.subs_fav_loc_dly_carry_fwd --`data-bi-prd-935c.bi_mart`.rk_all_90d_fav_loc_dly 
  WHERE date(dt_id) = vdt_id ) b
ON a.msisdn = b.msisdn  
WHERE a.sms_rev > 0 AND a.dt_id = vdt_id
GROUP BY a.dt_id, b.site_id, level_1, tenure ;			

--- Insert Into 
delete from `data-bi-prd-935c.bi_mart`.umb_vs_site where dt_id = vdt_id ;
INSERT into `data-bi-prd-935c.bi_mart`.umb_vs_site
SELECT site_id, level_1, svc_typ, hits, rev, tenure, timestamp(current_datetime('+7')) AS ppn_dttm, dt_id
FROM 
( SELECT * FROM `data-bi-prd-935c.bi_stg`.umb_v_site_{{ vdt_id }} 
  UNION ALL 
  SELECT * FROM `data-bi-prd-935c.bi_stg`.umb_s_site_{{ vdt_id }} ) a ;

--- Drop Temp Table
DROP TABLE `data-bi-prd-935c.bi_stg`.umb_v_site_{{ vdt_id }} ;
DROP TABLE `data-bi-prd-935c.bi_stg`.umb_s_site_{{ vdt_id }} ;
