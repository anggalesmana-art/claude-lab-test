--Migrated Script to GCP By Indra Maulana Ikhsan 20241203
--Updated CVM logic by Gahtan Syarif Nahdi 20260121
declare vdt_id date default @vdt_id;
--- Temp Table 0
CREATE OR REPLACE TABLE `data-bi-prd-935c.bi_mart`.umr_umb_data_site2_{{ vdt_id }}_tmp0 AS
SELECT a.msisdn, rev_code, a.level_1, usg_hits hits, data_rev rev
, upper(c.channel) channel, b.site_id, upper(pkg_reg_channel) pkg_reg_channel, tdr.attr_buytid, comv_ref.campaign_group
FROM `data-bi-prd-935c.bi_mart`.data_addon_dly a
LEFT JOIN `data-dtp-prd-aa1a.stg.tdr_completion_combined` tdr 
ON a.pkg_ngssp_transaction_id = tdr.transid and date(tdr.prc_dt) = vdt_id
LEFT JOIN 
	( 
		SELECT DISTINCT *, vdt_id dt_id
			FROM (SELECT 
						campaign_id,
            campaign_group,
						row_number() OVER ( partition BY campaign_id ORDER BY insert_date DESC, campaign_id DESC, campaign_group DESC) ranking
        		FROM `data-partnercomv-prd-xz5r.comv`.campaign_reference
        		WHERE campaign_category IN ( 'Paid' )
        		AND channel IN ('MRTM')) a2
			WHERE ranking = 1 
		) comv_ref
ON IF(REGEXP_CONTAINS(tdr.attr_campaign_id, r'(_[^_]+){3}$'),REGEXP_REPLACE(tdr.attr_campaign_id, r'(_[^_]+){3}$', ''),tdr.attr_campaign_id) = comv_ref.campaign_id
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
SELECT a.* EXCEPT (attr_buytid, campaign_group),
CASE WHEN ifnull(channel,'') != '' AND channel != 'CVM' THEN channel
	 when channel = 'CVM' and attr_buytid like 'SUP%' then 'MYIM3 of CVM'
		 when channel = 'CVM' and upper(campaign_group) like '%MYIM3%' then 'MYIM3 of CVM' 
		 when channel = 'CVM' and upper(campaign_group) = 'WACHATBOT' then 'CHATBOTWA of CVM'
		 --when channel = 'CVM' and upper(campaign_group) = 'MDP' then 'MDP of CVM'
		 when channel = 'CVM' then 'UMB of CVM'
		 WHEN pkg_reg_channel IN ('AVATAR','BAT','CAPTIVE_PTL','CHATBOTWA','DRMTRG',
                              'IVR','MDP','P2P','PGI','RTL','UMB') THEN pkg_reg_channel
     WHEN pkg_reg_channel = 'CRTAVTR' THEN 'AVATAR'
     WHEN pkg_reg_channel = 'LMS' THEN 'IMPOINT'
     WHEN pkg_reg_channel IN ('LTS','V2MYIM3') THEN 'MYIM3'
		 when upper(pkg_reg_channel) in ('MRTM', 'SIFTRTM') and attr_buytid like 'SUP%' then 'MYIM3 of CVM'
		 when upper(pkg_reg_channel) in ('MRTM', 'SIFTRTM') and upper(campaign_group) like '%MYIM3%' then 'MYIM3 of CVM' 
		 when upper(pkg_reg_channel) in ('MRTM', 'SIFTRTM') and upper(campaign_group) = 'WACHATBOT' then 'CHATBOTWA of CVM'
		 --when upper(pkg_reg_channel) in ('MRTM', 'SIFTRTM') and upper(campaign_group) = 'MDP' then 'MDP of CVM'
		 when upper(pkg_reg_channel) in ('MRTM', 'SIFTRTM') then 'UMB of CVM'
	 WHEN pkg_reg_channel IN ('RENEWAL','SDP','SMEDASHPRE','SMS') THEN 'UMB'
     WHEN pkg_reg_channel = 'PTLFB' THEN 'FB'
	 WHEN pkg_reg_channel = 'PULSASOS' THEN 'LOAN BALANCE'
	 WHEN pkg_reg_channel = 'SALMOBO' THEN 'MOBO'
     WHEN pkg_reg_channel IN ('MILLOM','SMPPGW') AND UPPER(level_1) LIKE '%ORGANIC%' THEN 'UMB'
	 WHEN pkg_reg_channel IN ('MILLOM','SMPPGW') AND UPPER(level_1) LIKE '%MYIM3%' THEN 'MYIM3'
     WHEN pkg_reg_channel IN ('MILLOM','SMPPGW') THEN 'UMB of CVM'
ELSE pkg_reg_channel END channel1
FROM `data-bi-prd-935c.bi_mart`.umr_umb_data_site2_{{ vdt_id }}_tmp0 a ;


--- Insert Into 
delete from `data-bi-prd-935c.bi_mart`.umb_data_site where dt_id = vdt_id;
insert into `data-bi-prd-935c.bi_mart`.umb_data_site 
SELECT msisdn, rev_code, level_1, hits, rev, channel, site_id
, channel1 AS channel2, timestamp(current_datetime('+7')) ppn_dttm, pkg_reg_channel, vdt_id dt_id
FROM `data-bi-prd-935c.bi_mart`.umr_umb_data_site2_{{ vdt_id }}_tmp1 a 
;

--- Drop Temp Table
DROP TABLE `data-bi-prd-935c.bi_mart`.umr_umb_data_site2_{{ vdt_id }}_tmp0;
DROP TABLE `data-bi-prd-935c.bi_mart`.umr_umb_data_site2_{{ vdt_id }}_tmp1;