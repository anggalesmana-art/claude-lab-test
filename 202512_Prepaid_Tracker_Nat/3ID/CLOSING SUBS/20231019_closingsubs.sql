declare vdt_id date default @vdt_id;


DROP TABLE IF EXISTS `data-bi-prd-935c.bi_stg.tmp_main_bal`;

CREATE TABLE `data-bi-prd-935c.bi_stg.tmp_main_bal` AS
SELECT *
FROM (
  SELECT 
    a.*, 
    sbscrptn_ek_id,
    ROW_NUMBER() OVER(PARTITION BY sbscrptn_ek_id ORDER BY record_end_dtm DESC) AS seqno  
  FROM `data-dtptechm-prd-c7ca.dwh.cust_acct_bal_fct` a
  LEFT JOIN `data-dtptechm-prd-c7ca.dwh.sbscrptn_dim` sd 
		ON a.sbscrptn_sk_id = sd.sbscrptn_sk_id
	WHERE sd.record_end_dtm > '0001-01-01' 
	and CAST(a.load_dt_sk_id AS DATE) = vdt_id 
) 
WHERE seqno = 1;

DROP TABLE IF EXISTS `data-bi-prd-935c.bi_stg.tmp_quota_balance`;

-- Create a temporary table and populate it with aggregated quota balances, filtering out certain service names
CREATE TABLE `data-bi-prd-935c.bi_stg.tmp_quota_balance` AS
SELECT 
  created_dt_sk_id AS dt, 
  sbscrptn_ek_id, 
  subscriberidentifier AS msisdn, 
  SUM(CAST(quota_balance AS FLOAT64)) AS quota_balance
FROM 
  `data-dtptechm-prd-c7ca.dwh.pcrf_quota_balance_new` a
WHERE 
  UPPER(CASE WHEN a.servicename <> '' THEN a.servicename ELSE a.quota_name END) NOT IN (
    'PLAN_CAP11DEF', 'PLAN_CAP11DEF_CAL', 'PLAN_PAKET11', 'PLAN_PAKET11_JANETPLUS', 
    'PLAN_SUSNGHT_FU', 'PLAN_SUSREG_FU', 'PLAN_WALLED_GARDEN', 'PLAN_WA_250MBPERD', 
    'PLAN_OTTCALL_100MB_FUP', 'PLAN_CHATTINGOTT_50MBFUP', 'PLAN_BIMAPLUS', 'PLAN_FB_FLEX_ZERO'
  )
	AND CAST(created_dt_sk_id AS DATE) = vdt_id
GROUP BY dt, sbscrptn_ek_id, msisdn;

delete from `data-bi-prd-935c.bi_mart.dm_closingsubs` where load_dt = vdt_id;

INSERT INTO `data-bi-prd-935c.bi_mart.dm_closingsubs`(load_dt,angie,home30,mp3_channel_sk_id,angie_channel_sk_id,sbscrptn_ek_id,sbscrptn_msisdn,activation_dtm,sbscrptn_status,
			promo_cd_sk_id,first_usage_dt,first_billing_usage_dt_sk_id,created_dtm,product_id,acct_balance_amt,quota_balance)                                                                                                                                                                  
 SELECT
 cast(vdt_id as date),      
 rprt2.ctgry_ref_chld,  
 rprt.ctgry_ref_chld,   
 sd.mp3_Channel_sk_id,  
 sd.angie_channel_sk_id,
 cast(sd.sbscrptn_ek_id as string),
 sd.sbscrptn_msisdn,
 sd.activation_dtm,
 sd.sbscrptn_status,
 sd.promo_cd_sk_id,
 sd.first_usage_dt,
 sd.first_billing_usage_dt_sk_id,
 current_date() as created_dtm,
 CAST(sd.product_id AS STRING),
 CAST(coalesce(b.acct_balance_amt,0) AS NUMERIC) as acct_balance_amt,
 CAST(coalesce(c.quota_balance,0) AS INT64) as quota_balance     
 FROM `data-dtptechm-prd-c7ca.dwh.sbscrptn_attribs` sd 
         left join `data-dtptechm-prd-c7ca.dwh.channel_dim` cd on cd.channel_sk_id=sd.mp3_Channel_sk_id
         left join `data-dtptechm-prd-c7ca.dwh.rprt_fltr_ref_ctgry` rprt on cd.channel_id=rprt.ref_cd and rprt.ref_type_cd='MP3'
				 LEFT OUTER JOIN `data-dtptechm-prd-c7ca.dwh.angie_hrchy_dim` an ON an.angie_hrchy_sk_id = sd.angie_channel_sk_id
				 LEFT OUTER JOIN `data-dtptechm-prd-c7ca.dwh.channel_dim` cd2 ON an.mp3_channel_sk_id = cd2.channel_sk_id -- v1.1
				 LEFT JOIN `data-dtptechm-prd-c7ca.dwh.rprt_fltr_ref_ctgry` rprt2 on CAST(cd2.channel_id AS STRING)=rprt2.ref_cd and rprt2.ref_type_cd='MP3'    -- v1.1
				 left outer join `data-bi-prd-935c.bi_stg.tmp_main_bal` b ON sd.sbscrptn_ek_id = b.sbscrptn_ek_id and CAST(b.sbscrptn_ek_id AS STRING) <>'-2' and CAST(b.load_dt_sk_id AS date) = vdt_id 	--v1.2.1
				 left outer join `data-bi-prd-935c.bi_stg.tmp_quota_balance` c ON sd.sbscrptn_ek_id = c.sbscrptn_ek_id and CAST(c.sbscrptn_ek_id AS STRING) <> '-2' and CAST(c.dt AS date) = vdt_id		--v1.2.1									
 WHERE IFNULL(CAST(termination_dtm AS DATE),CAST('1999-09-31' AS DATE)) > vdt_id
 and CAST(activation_dtm AS DATE) <= vdt_id   --->[18 Sep] tambahan kriteria bila dump data dilakukan backdate. Ini memfilter subs yg activation melewati tanggal cut off / snapshot data  
 and tool_of_trade_ind = 'N'
 ;

--02. Postpaid

delete from `data-bi-prd-935c.bi_mart.master_postpaid_closing_subs` where dt = vdt_id;

-- Insert into the master_postpaid_closing_subs table
INSERT INTO `data-bi-prd-935c.bi_mart.master_postpaid_closing_subs`
SELECT 
  load_dt,
  CAST(sbscrptn_ek_id AS STRING),
  sbscrptn_msisdn,
  product_id,
  activation_dtm,
  CURRENT_TIMESTAMP() AS process_dt
FROM 
  `data-bi-prd-935c.bi_mart.dm_closingsubs`
WHERE 
  product_id <> '8';

