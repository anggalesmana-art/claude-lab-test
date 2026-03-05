--Migrated Script to GCP By Indra Maulana Ikhsan 20241203
declare vdt_id date default @vdt_id;
--- Temp Table 0
CREATE OR REPLACE TABLE `data-bi-prd-935c.bi_mart`.umr_umb_data_site2_{{ vdt_id }}_tmp0 AS
SELECT a.msisdn, rev_code, a.level_1, usg_hits hits, data_rev rev
, upper(c.channel) channel, b.site_id, upper(pkg_reg_channel) pkg_reg_channel
FROM `data-bi-prd-935c.bi_mart`.data_addon_dly a
LEFT JOIN 
( SELECT * FROM `data-dtp-prd-aa1a.sor`.subs_fav_loc_dly_carry_fwd --`data-bi-prd-935c.bi_mart`.rk_all_90d_fav_loc_dly 
  WHERE date(dt_id) = vdt_id
) b
ON a.msisdn = b.msisdn  
LEFT JOIN
( SELECT level_1, max(channel) channel 
  FROM `data-cvm-prd-c324.sor.im3_ref_organic` 
  GROUP BY 1
) c
ON a.level_1 = c.level_1
WHERE (a.data_rev > 0 OR a.data_rev < 0)
  AND a.dt_id = vdt_id ;

--- Temp Table 1
CREATE OR REPLACE TABLE `data-bi-prd-935c.bi_mart`.umr_umb_data_site2_{{ vdt_id }}_tmp1 AS
SELECT a.*,
CASE WHEN ifnull(channel,'') != '' THEN channel
     WHEN pkg_reg_channel IN ('AVATAR','BAT','CAPTIVE_PTL','CHATBOTWA','DRMTRG',
                              'IVR','MDP','P2P','PGI','RTL','UMB') THEN pkg_reg_channel
     WHEN pkg_reg_channel = 'CRTAVTR' THEN 'AVATAR'
     WHEN pkg_reg_channel = 'LMS' THEN 'IMPOINT'
     WHEN pkg_reg_channel IN ('LTS','V2MYIM3') THEN 'MYIM3'
     WHEN pkg_reg_channel IN ('MRTM','SIFTRTM') THEN 'CVM'
	 WHEN pkg_reg_channel IN ('RENEWAL','SDP','SMEDASHPRE','SMS') THEN 'UMB'
     WHEN pkg_reg_channel = 'PTLFB' THEN 'FB'
	 WHEN pkg_reg_channel = 'PULSASOS' THEN 'LOAN BALANCE'
	 WHEN pkg_reg_channel = 'SALMOBO' THEN 'MOBO'
     WHEN pkg_reg_channel IN ('MILLOM','SMPPGW') AND UPPER(level_1) LIKE '%ORGANIC%' THEN 'UMB'
	 WHEN pkg_reg_channel IN ('MILLOM','SMPPGW') AND UPPER(level_1) LIKE '%MYIM3%' THEN 'MYIM3'
     WHEN pkg_reg_channel IN ('MILLOM','SMPPGW') THEN 'CVM'
ELSE pkg_reg_channel END channel1
FROM `data-bi-prd-935c.bi_mart`.umr_umb_data_site2_{{ vdt_id }}_tmp0 a ;

--- Temp Table 2
CREATE OR REPLACE TABLE `data-bi-prd-935c.bi_mart`.umr_umb_data_site2_{{ vdt_id }}_tmp2 AS
select msisdn, provisioned_offerid, total_hit, gross_rev from 
(
	select msisdn,taker_date,provisioned_offerid,sum(hit) total_hit,sum(gross_rev) gross_rev
	from 
	(
		--MSISDN & OFFER_ID level
		select msisdn,taker_date,provisioned_offerid,price,hit,(hit*price) gross_rev from
		(
		select a.msisdn,
		parse_date('%Y%m%d',a.reward_sent_date) taker_date,
		a.provisioned_offerid,a.price,count(distinct rwdkey) hit
		from `data-partnercomv-prd-xz5r.comv.cvm_mrtm_transaction_fact_smy` a--cvm_mrtm_transaction_smy_new_fact_smy --cvm_mrtm_transaction_smy_new_fact
		where target_group='1' and taker_group='1'
		and provisioned_offerid not in ('null')
		and campaign_id in (select distinct campaign_id from `data-partnercomv-prd-xz5r.comv`.campaign_reference --dm.run_campaign_ref 
		                    where upper(campaign_category) in ('PAID') 
							  and upper(channel) in ('MRTM') 
							  and upper(campaign_group) like ('%MYIM3%'))
		and parse_date('%Y%m%d',a.reward_sent_date) = vdt_id
		and dt_id between timestamp(DATE_SUB(vdt_id, INTERVAL 7 DAY)) and timestamp(DATE_ADD(vdt_id, INTERVAL 1 DAY))
		group by 1,2,3,4
		) a
	) a 
	group by 1,2,3 --order by 1,2,3
) a ;

--- Temp Table 2b
CREATE OR REPLACE TABLE `data-bi-prd-935c.bi_mart`.umr_umb_data_site2_{{ vdt_id }}_tmp2b AS
select msisdn, provisioned_offerid, total_hit, gross_rev from 
(
	select msisdn,taker_date,provisioned_offerid,sum(hit) total_hit,sum(gross_rev) gross_rev
	from 
	(
		--MSISDN & OFFER_ID level
		select msisdn,taker_date,provisioned_offerid,price,hit,(hit*price) gross_rev from
		(
		select a.msisdn,
		parse_date('%Y%m%d',a.reward_sent_date) taker_date,
		a.provisioned_offerid,a.price,count(distinct rwdkey) hit
		from `data-partnercomv-prd-xz5r.comv.cvm_mrtm_transaction_fact_smy` a--cvm_mrtm_transaction_smy_new_fact_smy a --cvm_mrtm_transaction_smy_new_fact
		where target_group='1' and taker_group='1'
		and provisioned_offerid not in ('null')
		and campaign_id in (select distinct campaign_id from `data-partnercomv-prd-xz5r.comv.campaign_reference` --dm.run_campaign_ref 
		                    where upper(campaign_category) in ('PAID') 
							  and upper(channel) in ('MRTM') 
							  and upper(campaign_group) in ('WACHATBOT'))
		and parse_date('%Y%m%d',a.reward_sent_date) = vdt_id
		and dt_id between timestamp(DATE_SUB(vdt_id, INTERVAL 7 DAY)) and timestamp(DATE_ADD(vdt_id, INTERVAL 1 DAY))
		group by 1,2,3,4
		) a
	) a 
	group by 1,2,3 --order by 1,2,3
) a ;

--- Temp Table CVM
CREATE OR REPLACE TABLE `data-bi-prd-935c.bi_mart`.umr_umb_data_site2_{{ vdt_id }}_tmp3 AS
SELECT a.*,
CASE 
  WHEN a.msisdn = b.msisdn THEN 'MYIM3 of CVM'
  WHEN a.msisdn = c.msisdn THEN 'CHATBOTWA of CVM'
  --WHEN b.msisdn is null THEN 
  ELSE 'UMB of CVM' 
END channel2
FROM `data-bi-prd-935c.bi_mart`.umr_umb_data_site2_{{ vdt_id }}_tmp1 a
LEFT JOIN 
( SELECT DISTINCT msisdn FROM `data-bi-prd-935c.bi_mart`.umr_umb_data_site2_{{ vdt_id }}_tmp2 --dm.run_taker_paid_myim3
  --WHERE taker_date = '${var:dtid2}'
) b
ON a.msisdn = b.msisdn
LEFT JOIN 
( SELECT DISTINCT msisdn FROM `data-bi-prd-935c.bi_mart`.umr_umb_data_site2_{{ vdt_id }}_tmp2b
) c
ON a.msisdn = c.msisdn
WHERE a.channel1 = 'CVM' ;

--- Insert Into 
delete from `data-bi-prd-935c.bi_mart`.umb_data_site where dt_id = vdt_id;
insert into `data-bi-prd-935c.bi_mart`.umb_data_site 
SELECT msisdn, rev_code, level_1, hits, rev, channel, site_id
, channel1 AS channel2, timestamp(current_datetime('+7')) ppn_dttm, pkg_reg_channel, vdt_id dt_id
FROM `data-bi-prd-935c.bi_mart`.umr_umb_data_site2_{{ vdt_id }}_tmp1 a 
WHERE channel1 <> 'CVM' OR channel1 IS NULL
UNION ALL
SELECT msisdn, rev_code, level_1, hits, rev, channel, site_id
, channel2, timestamp(current_datetime('+7')) ppn_dttm, pkg_reg_channel, vdt_id dt_id
FROM `data-bi-prd-935c.bi_mart`.umr_umb_data_site2_{{ vdt_id }}_tmp3 b
;

--- Drop Temp Table
DROP TABLE `data-bi-prd-935c.bi_mart`.umr_umb_data_site2_{{ vdt_id }}_tmp0;
DROP TABLE `data-bi-prd-935c.bi_mart`.umr_umb_data_site2_{{ vdt_id }}_tmp1;
DROP TABLE `data-bi-prd-935c.bi_mart`.umr_umb_data_site2_{{ vdt_id }}_tmp2;
DROP TABLE `data-bi-prd-935c.bi_mart`.umr_umb_data_site2_{{ vdt_id }}_tmp2b;
DROP TABLE `data-bi-prd-935c.bi_mart`.umr_umb_data_site2_{{ vdt_id }}_tmp3;
