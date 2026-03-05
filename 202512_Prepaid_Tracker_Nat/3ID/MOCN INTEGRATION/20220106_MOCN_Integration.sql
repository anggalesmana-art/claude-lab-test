DECLARE vdt_id DATE DEFAULT @vdt_id;

	truncate table `data-bi-prd-935c.bi_stg.stg_gci_site`;
   
	insert into `data-bi-prd-935c.bi_stg.stg_gci_site`(egci,site_id,gladiator_branch,g_type, tag,created_dtm)
	select distinct c.egci, c.site_id, UPPER(c.gladiator_branch), substring(c.system,1,2) as g_type, '3' as tag, CURRENT_TIMESTAMP() as created_dtm 
	from `data-bi-prd-935c.bi_mart.site_ref_dim` c 
	where CAST(mth_sk_id AS DATE) 
			in (
				select CAST(max(mth_sk_id) AS DATE)
				from `data-bi-prd-935c.bi_mart.site_ref_dim`
				where mth_sk_id <= DATE_TRUNC(vdt_id, MONTH)
			 )
	;

-- 02. populate revenue per branch

	truncate table `data-bi-prd-935c.bi_stg.stg_rev_branch`;

INSERT INTO `data-bi-prd-935c.bi_stg.stg_rev_branch` (dt_sk_id, branch, total_net_revenue, data_revenue, created_dtm, voice_net_revenue)
  SELECT 
    CAST(dt_sk_id AS DATE),
    UPPER(COALESCE(sites.gladiator_branch, 'OTHERS')) AS branch,
    SUM(total_net_revenue) AS total_net_revenue,
    SUM(data_revenue) AS data_revenue,
    CURRENT_TIMESTAMP() AS created_dtm,
    SUM(COALESCE(CAST(voice_net_revenue AS numeric), 0)) AS voice_net_revenue
  FROM
    (
      SELECT 
        a.load_dt_sk_id AS dt_sk_id,
        site_id_90,
        SUM(COALESCE(CAST(total_net_revenue AS numeric), 0)) AS total_net_revenue,
        -- Data net revenue. Already confirmed by Dheerend in WA group
        SUM(COALESCE(CAST(total_ret_data_net_revenue AS numeric), 0) + COALESCE(CAST(data_subs_revenue AS numeric), 0)) AS data_revenue,
        SUM(voice_net_revenue) AS voice_net_revenue
      FROM `data-dtptechm-prd-c7ca.dwh.ioh_sbscriber_daily_usage_revenue_smry` AS a
				LEFT JOIN `data-bi-prd-935c.bi_mart.ioh_subscriber_site_attribs_rolling` AS ss
      ON ss.sbscrptn_ek_id = CAST(a.sbscrptn_ek_id AS STRING) AND ss.dt = CAST(a.load_dt_sk_id AS DATE)
      WHERE CAST(a.load_dt_sk_id AS DATE) = vdt_id and CAST(ss.dt AS DATE) = vdt_id
      GROUP BY 
        1, 2
    ) AS a
  LEFT OUTER JOIN 
    (
      SELECT DISTINCT 
        site_id, 
        gladiator_branch 
      FROM 
        `data-bi-prd-935c.bi_stg.stg_gci_site`
      WHERE 
        site_id NOT IN ('000000', '00#N/A')
    ) AS sites
  ON 
    COALESCE(a.site_id_90, 'NA') = CAST(sites.site_id AS STRING)
  GROUP BY 
    1, 2;

	truncate table `data-bi-prd-935c.bi_stg.stg_voice_traffic`;

  INSERT INTO `data-bi-prd-935c.bi_stg.stg_voice_traffic`
  SELECT 
    CAST(FORMAT_DATE('%Y%m%d',a.charge_start_dt_sk_id) AS int64)
		,a.site_id
		,a.branch
		,CAST(a.dur_min AS NUMERIC)
		,a.subs_cnt
    ,CAST(SUM(dur_min) OVER(PARTITION BY branch, charge_start_dt_sk_id) AS NUMERIC) AS usage_dur_perbranch
  FROM (
    SELECT 
      charge_start_dt_sk_id,
      COALESCE(st.site_id, 'OTHERS') AS site_id,
      UPPER(COALESCE(gladiator_branch, 'OTHERS')) AS branch,
      SUM(usage_dur) / 60 AS dur_min,
      COUNT(DISTINCT sbscrptn_msisdn) AS subs_cnt
    FROM `data-dtptechm-prd-c7ca.dwh.charged_event_fct` a
    LEFT JOIN `data-dtptechm-prd-c7ca.dwh.traffic_dim` td 
      ON a.traffic_sk_id = td.traffic_sk_id
    LEFT JOIN `data-dtptechm-prd-c7ca.dwh.sbscrptn_dim` sd 
      ON a.sbscrptn_sk_id = sd.sbscrptn_sk_id
    LEFT JOIN `data-bi-prd-935c.bi_stg.stg_gci_site` st 
      ON st.egci = a.calling_cell_id 
    WHERE acct_type_cd = 'MAIN'
      AND vas_level_1_ctgry IN ('Voice', 'VOIP')
      AND COALESCE(sd.tool_of_trade_ind, 'N') = 'N'
			AND sd.record_end_dtm > '0001-01-01'
			AND CAST(a.charge_start_dt_sk_id AS DATE) = vdt_id
    GROUP BY 1, 2, 3
  ) a;

	truncate table `data-bi-prd-935c.bi_stg.stg_usg_subs`;

  INSERT INTO `data-bi-prd-935c.bi_stg.stg_usg_subs`
  -- SELECT 
  --   created_dt_sk_id,
  --   a.calling_cell_id AS gci,
  --   a.sbscrptn_ek_id,
  --   CAST((SUM(COALESCE(uplink_vol, 0) + COALESCE(downlink_vol, 0)) / POW(1024, 2)) AS NUMERIC) AS usage_MB,
  --   CAST((SUM(CASE 
  --               WHEN COALESCE(rat_type, 'NA') IN ('2', 'NA') THEN COALESCE(uplink_vol, 0) + COALESCE(downlink_vol, 0) 
  --               ELSE 0 
  --             END) / POW(1024, 2)) AS NUMERIC) AS usg_MB_2g, -- RAT type null is considered 2G
  --   CAST((SUM(CASE 
  --               WHEN rat_type IN ('1', '5') THEN COALESCE(uplink_vol, 0) + COALESCE(downlink_vol, 0) 
  --               ELSE 0 
  --             END) / POW(1024, 2)) AS NUMERIC) AS usg_MB_3g,
  --   CAST((SUM(CASE 
  --               WHEN rat_type = '6' THEN COALESCE(uplink_vol, 0) + COALESCE(downlink_vol, 0) 
  --               ELSE 0 
  --             END) / POW(1024, 2)) AS NUMERIC) AS usg_MB_4g
  -- FROM `data-dtptechm-prd-c7ca.dwh.gprs_usage_fct` a
  -- LEFT JOIN `data-dtptechm-prd-c7ca.dwh.sbscrptn_attribs` sa 
  --   ON a.sbscrptn_ek_id = sa.sbscrptn_ek_id AND sa.rank_ind = 1
  -- WHERE 
  --   COALESCE(sa.tool_of_trade_ind, 'N') = 'N' 
  --   AND (COALESCE(uplink_vol, 0) + COALESCE(downlink_vol, 0)) > 0
	-- 	AND a.created_dt_sk_id = vdt_id
  -- GROUP BY 
  --   created_dt_sk_id, calling_cell_id, a.sbscrptn_ek_id;

SELECT 
  a.created_dt_sk_id,
  a.calling_cell_id AS gci,
  a.sbscrptn_ek_id,
  
  CAST(SUM(COALESCE(a.uplink_vol, 0) + COALESCE(a.downlink_vol, 0)) / POW(1024, 2) AS NUMERIC) AS usage_MB,
  
  CAST(SUM(
    CASE 
      WHEN COALESCE(a.rat_type, 'NA') IN ('2', 'NA') 
        THEN COALESCE(a.uplink_vol, 0) + COALESCE(a.downlink_vol, 0) 
        ELSE 0 
    END
  ) / POW(1024, 2) AS NUMERIC) AS usg_MB_2g,  -- Null RAT = 2G
  
  CAST(SUM(
    CASE 
      WHEN a.rat_type IN ('1', '5') 
        THEN COALESCE(a.uplink_vol, 0) + COALESCE(a.downlink_vol, 0) 
        ELSE 0 
    END
  ) / POW(1024, 2) AS NUMERIC) AS usg_MB_3g,
  
  CAST(SUM(
    CASE 
      WHEN a.rat_type = '6' 
        THEN COALESCE(a.uplink_vol, 0) + COALESCE(a.downlink_vol, 0) 
        ELSE 0 
    END
  ) / POW(1024, 2) AS NUMERIC) AS usg_MB_4g

FROM `data-dtptechm-prd-c7ca.dwh.gprs_usage_fct` a

LEFT JOIN (
  SELECT sbscrptn_ek_id
  FROM `data-dtptechm-prd-c7ca.dwh.sbscrptn_attribs`
  WHERE rank_ind = 1 AND COALESCE(tool_of_trade_ind, 'N') = 'N'
) sa 
  ON a.sbscrptn_ek_id = sa.sbscrptn_ek_id

WHERE 
  (COALESCE(a.uplink_vol, 0) + COALESCE(a.downlink_vol, 0)) > 0
  AND a.created_dt_sk_id = vdt_id

GROUP BY 
  a.created_dt_sk_id, a.calling_cell_id, a.sbscrptn_ek_id; -- tuned 624 GB
  
	truncate table `data-bi-prd-935c.bi_stg.stg_data_traffic`;

	-- create table if not exists `data-bi-prd-935c.bi_stg.stg_data_traffic` as
	insert into `data-bi-prd-935c.bi_stg.stg_data_traffic` 	
	select 
	a.*,
	sum(usage_MB) over(partition by branch,created_dt_sk_id) as usage_MB_perbranch
	FROM
	(
		select 
		created_dt_sk_id,
		UPPER(coalesce(st.site_id,'OTHERS')) as site_id,
		UPPER(coalesce(gladiator_branch,'OTHERS')) as branch,
		sum(usage_MB) as usage_MB,
		sum(usg_MB_4g) as usg_MB_4g,
		sum(usg_MB_3g) as usg_MB_3g,
		sum(usg_MB_2g) as usg_MB_2g,
		count(distinct sbscrptn_ek_id) as subs_cnt
		from `data-bi-prd-935c.bi_stg.stg_usg_subs` a
		left outer join `data-bi-prd-935c.bi_stg.stg_gci_site` st 
		ON st.egci = a.gci 
		where created_dt_sk_id = vdt_id 
		group by created_dt_sk_id,site_id,branch
	) a;

-- aggr revenue and usage

delete from `data-bi-prd-935c.bi_mart.merge_usage_rev_mart` where dt_id = vdt_id ;

INSERT INTO `data-bi-prd-935c.bi_mart.merge_usage_rev_mart`
SELECT 
  dt_id,
  site_id,
  mocn_tag,
  SUM(dur_min) AS dur_min,
  SUM(usage_mb) AS usage_mb,
  SUM(usg_mb_2g) AS usg_mb_2g,
  SUM(usg_mb_3g) AS usg_mb_3g,
  SUM(usg_mb_4g) AS usg_mb_4g,

  SUM(voice_subs_sites) AS voice_subs_sites,
  SUM(data_subs_sites) AS data_subs_sites,

  SUM(voice_rev) AS voice_rev,
  SUM(nondata_rev) AS nondata_rev,
  SUM(data_rev) AS data_rev,
  SUM(data_2g_rev) AS data_2g_rev,
  SUM(data_3g_rev) AS data_3g_rev,
  SUM(data_4g_rev) AS data_4g_rev,
  CURRENT_TIMESTAMP() AS created_dtm
FROM 
  (
    SELECT 
      PARSE_DATE('%Y%m%d',CAST(a.charge_start_dt_sk_Id AS STRING)) AS dt_id,
      a.site_id,
      CASE WHEN st.newsiteid IS NOT NULL THEN 1 ELSE 0 END AS mocn_tag,
      dur_min,
      NULL AS usage_mb,
      NULL AS usg_mb_2g,
      NULL AS usg_mb_3g,
      NULL AS usg_mb_4g,
      subs_cnt AS voice_subs_sites,
      NULL AS data_subs_sites,
      CAST(dur_min * (COALESCE(voice_net_revenue, 0)) / COALESCE(usage_dur_perbranch, 1) AS NUMERIC) AS voice_rev,
      CAST(dur_min * (COALESCE(total_net_revenue, 0) - COALESCE(data_revenue, 0)) / COALESCE(usage_dur_perbranch, 1) AS NUMERIC) AS nondata_rev,
      NULL AS data_rev,
      NULL AS data_2g_rev,
      NULL AS data_3g_rev,
      NULL AS data_4g_rev
    FROM `data-bi-prd-935c.bi_stg.stg_voice_traffic` a
    LEFT OUTER JOIN (
			SELECT DISTINCT newsiteid 
			FROM `data-bi-prd-935c.bi_mart.dim_mocn_site_ref`
			) st 
      ON a.site_id = st.newsiteid
    LEFT OUTER JOIN `data-bi-prd-935c.bi_stg.stg_rev_branch` b 
      ON PARSE_DATE('%Y%m%d',CAST(a.charge_start_dt_sk_Id AS STRING))  = b.dt_sk_id 
			AND a.branch = b.branch
    UNION ALL
    SELECT
      a.created_dt_sk_id AS dt_id,
      a.site_id,
      CASE WHEN st.newsiteid IS NOT NULL THEN 1 ELSE 0 END AS mocn_tag,
      NULL AS dur_min,
      usage_mb,
      usg_mb_2g,
      usg_mb_3g,
      usg_mb_4g,
      NULL AS voice_subs_sites,
      subs_cnt AS data_subs_sites,
      NULL AS voice_rev,
      NULL AS nondata_rev,
      CAST(usage_mb * (COALESCE(data_revenue, 0) / COALESCE(usage_mb_perbranch, 1)) AS NUMERIC) AS data_rev,
      CAST(usg_mb_2g * (COALESCE(data_revenue, 0) / COALESCE(usage_mb_perbranch, 1)) AS NUMERIC) AS data_2g_rev,
      CAST(usg_mb_3g * (COALESCE(data_revenue, 0) / COALESCE(usage_mb_perbranch, 1)) AS NUMERIC) AS data_3g_rev,
      CAST(usg_mb_4g * (COALESCE(data_revenue, 0) / COALESCE(usage_mb_perbranch, 1)) AS NUMERIC) AS data_4g_rev
    FROM `data-bi-prd-935c.bi_stg.stg_data_traffic` a
    LEFT OUTER JOIN (
			SELECT DISTINCT newsiteid 
			FROM `data-bi-prd-935c.bi_mart.dim_mocn_site_ref`
			) st 
      ON a.site_id = st.newsiteid
    LEFT OUTER JOIN `data-bi-prd-935c.bi_stg.stg_rev_branch` b 
      ON CAST(a.created_dt_sk_id AS DATE) = b.dt_sk_id 
			AND a.branch = b.branch
  ) a
GROUP BY 
  dt_id, site_id, mocn_tag;

--- load revenue 
	delete from `data-bi-prd-935c.bi_mart.project_mis_profile_subs_sites` 
	where tag in (
					'total revenue old', 
					'data revenue old', 
					'voice revenue old', 
					'data 2g rev old', 
					'data 3g rev old', 
					'data 4g rev old', 
					'data 2g rev',
					'data 3g rev',
					'data 4g rev',
					'data revenue',
					'others revenue',
					'sms usage',
					'sms revenue',
					'vas revenue',
					'total revenue',
					'voice revenue',
					'voice traffic', 
					'data traffic', 
					'voice subs', 
					'data subs', 
					'usage 2g', 
					'usage 3g', 
					'usage 4g') 
					and CAST(load_dt_sk_id AS DATE) = vdt_id;

INSERT INTO `data-bi-prd-935c.bi_mart.project_mis_profile_subs_sites` (load_dt_sk_id, site_id, tag, amount, uom, created_dt)
SELECT 
  CAST(dt_id AS date),
  site_id,
  tag,
  CAST(SUM(
    CASE 
      WHEN tag = 'total revenue old' THEN total_net_revenue
      WHEN tag = 'data revenue old' THEN data_revenue
      WHEN tag = 'voice revenue old' THEN voice_revenue
      WHEN tag = 'data 2g rev old' THEN data_2g_rev
      WHEN tag = 'data 3g rev old' THEN data_3g_rev
      WHEN tag = 'data 4g rev old' THEN data_4g_rev
      WHEN tag = 'voice traffic' THEN dur_min
      WHEN tag = 'data traffic' THEN usage_mb
      WHEN tag = 'voice subs' THEN voice_subs
      WHEN tag = 'data subs' THEN data_subs
      WHEN tag = 'usage 2g' THEN usg_mb_2g
      WHEN tag = 'usage 3g' THEN usg_mb_3g
      WHEN tag = 'usage 4g' THEN usg_mb_4g
    END
  ) AS FLOAT64) AS amount,
  CASE 
    WHEN tag IN ('total revenue old', 'data revenue old', 'voice revenue old', 'data 2g rev old', 'data 3g rev old', 'data 4g rev old') THEN 'idr'
    WHEN tag = 'voice traffic' THEN 'minutes'
    WHEN tag = 'data traffic' THEN 'MB'
    WHEN tag = 'voice subs' THEN 'units'
    WHEN tag = 'data subs' THEN 'units'
    WHEN tag IN ('usage 2g', 'usage 3g', 'usage 4g') THEN 'MB'
  END AS uom,
  CURRENT_date() AS created_dt
FROM
  (
    SELECT 
      dt_id,
      site_id,
      SUM(COALESCE(nondata_rev, 0) + COALESCE(data_rev, 0)) AS total_net_revenue,
      SUM(COALESCE(data_rev, 0)) AS data_revenue,
      SUM(COALESCE(voice_rev, 0)) AS voice_revenue,
      SUM(COALESCE(data_2g_rev, 0)) AS data_2g_rev,
      SUM(COALESCE(data_3g_rev, 0)) AS data_3g_rev,
      SUM(COALESCE(data_4g_rev, 0)) AS data_4g_rev,
      SUM(COALESCE(dur_min, 0)) AS dur_min,
      SUM(COALESCE(usage_mb, 0)) AS usage_mb,
      SUM(COALESCE(voice_subs_sites, 0)) AS voice_subs,
      SUM(COALESCE(data_subs_sites, 0)) AS data_subs,
      SUM(COALESCE(usg_mb_2g, 0)) AS usg_mb_2g,
      SUM(COALESCE(usg_mb_3g, 0)) AS usg_mb_3g,
      SUM(COALESCE(usg_mb_4g, 0)) AS usg_mb_4g
    FROM `data-bi-prd-935c.bi_mart.merge_usage_rev_mart` 
    WHERE dt_id = vdt_id
    GROUP BY dt_id, site_id
  ) a
LEFT OUTER JOIN UNNEST([
  'total revenue old', 'data revenue old', 'voice revenue old', 
  'data 2g rev old', 'data 3g rev old', 'data 4g rev old', 
  'voice traffic', 'data traffic', 'voice subs', 'data subs', 
  'usage 2g', 'usage 3g', 'usage 4g'
]) AS tag
GROUP BY dt_id, site_id, tag, uom;


-- [16 Jun 2022] dismantile VLR stamping. Using new Rule with JobName: 20220613_VLRSITE

-- ============================================================================================================

-- Adding new tag revenue from table revenue dwh.h3i_revenue_per_site_extended & dwh.h3i_revenue_per_site_extended_others_detail

drop table if exists `data-bi-prd-935c.bi_stg.rev_site`;

  CREATE OR REPLACE TABLE `data-bi-prd-935c.bi_stg.rev_site` AS
  SELECT
    dt_id,
    site_id,
    CASE
      WHEN tag = 'Data Rev' THEN 'Data Revenue'
      WHEN tag = 'Voice Rev' THEN 'Voice Revenue'
      WHEN tag = 'SMS Rev' THEN 'SMS Revenue'
      WHEN tag = 'VAS Rev' THEN 'VAS Revenue'
      WHEN tag = 'Others Rev' THEN 'Others Revenue'
      WHEN tag = 'SMS_usage' THEN 'SMS Usage'
    END AS kpi_nm,
    SUM(
      CASE
        WHEN tag = 'Data Rev' THEN data_rev
        WHEN tag = 'Voice Rev' THEN voice_video_rev
        WHEN tag = 'SMS Rev' THEN sms_mms_rev
        WHEN tag = 'VAS Rev' THEN vas_revenue
        WHEN tag = 'Others Rev' THEN other_rev
        WHEN tag = 'SMS_usage' THEN sms_hits
      END
    ) AS value
  FROM (
    SELECT
      a.dt_id AS dt_id,
      a.site_id,
      SUM(
        COALESCE(ccn_data_revenue, 0) + COALESCE(loan_package_revenue, 0) + 
        COALESCE(mobo_sp_data_rev, 0) + 
        (COALESCE(fdv_data_rev, 0) + COALESCE(voucher_forfeit_revenue, 0)) + 
        COALESCE(mobo_rita_data_rev, 0) + 
        COALESCE(mobo_evc_rev, 0)
      ) AS data_rev,
      SUM(
        COALESCE(mobo_sp_voice_rev, 0) + COALESCE(fdv_voice_rev, 0) + 
        COALESCE(mobo_rita_voice_rev, 0) + COALESCE(ccn_voice_revenue, 0)
      ) AS voice_video_rev,
      SUM(
        COALESCE(ccn_sms_revenue, 0) + COALESCE(fdv_sms_rev, 0) + 
        COALESCE(mobo_sp_sms_rev, 0) + COALESCE(mobo_rita_sms_rev, 0) + 
        COALESCE(other_mms_revenue, 0)
      ) AS sms_mms_rev,
      SUM(
        COALESCE(ccn_vas_revenue, 0) + COALESCE(mobo_sp_vas_rev, 0) + 
        COALESCE(mobo_rita_vas_rev, 0)
      ) AS vas_revenue,
      SUM(
        (COALESCE(ccn_voice_rev_ppu_roaming, 0) + COALESCE(ccn_sms_rev_ppu_roaming, 0) + 
        COALESCE(mobo_evc_roaming_rev, 0) + COALESCE(other_roaming_rev, 0)) +
        (COALESCE(loan_balance_fee, 0) + COALESCE(balance_transfer_revenue, 0)) + 
        COALESCE(other_payu_revenue, 0)
      ) AS other_rev,
      SUM(sms_hits) AS sms_hits
    FROM `data-dtptechm-prd-c7ca.dwh.h3i_revenue_per_site_extended` a
    WHERE CAST(dt_id AS DATE) = vdt_id
    GROUP BY 1, 2
  ) a
  LEFT JOIN UNNEST([
    'Data Rev', 'Voice Rev', 'SMS Rev', 'VAS Rev', 'Others Rev', 'SMS_usage'
  ]) AS tag ON TRUE
  GROUP BY 1, 2, 3
  
  UNION ALL

  -- Others Markup Pulsa
  SELECT
    CAST(a.dt_id AS DATE) AS dt_id,
    a.physical_site_id,
    'Others Revenue' AS kpi_nm,
    SUM(revenue) AS Others_Markup_Pulsa
  FROM `data-dtptechm-prd-c7ca.dwh.h3i_revenue_per_site_extended_others_detail` a
  WHERE CAST(dt_id AS DATE) = vdt_id
  AND process_nm IN ('EVC MARKUP', 'MARKUP_RITA', 'MARKUP_UNLOCK')
  AND service_type <> 'ROAMING'  -- exclude roaming because has been counted on other_roaming_rev
  GROUP BY 1, 2, 3

  UNION ALL

  -- Others Vas Partner
  SELECT
    CAST(a.dt_id AS DATE) AS dt_id,
    a.physical_site_id,
    'Others Revenue' AS kpi_nm,
    SUM(revenue) AS value
  FROM `data-dtptechm-prd-c7ca.dwh.h3i_revenue_per_site_extended_others_detail` a
  WHERE CAST(dt_id AS DATE) = vdt_id
  AND service_type = 'OTHER-VAS'
  AND process_nm IN ('ONE-OFF CDR') -- 'TOPUP'
  GROUP BY 1, 2, 3

  UNION ALL

  -- RITA_P3PRICE_AMORT for MOBO_RITA
  SELECT
    CAST(a.dt_id AS DATE) AS dt_id,
    a.physical_site_id,
    'Data Revenue' AS kpi_nm,
    SUM(revenue) * -1 AS RITA_P3PRICE_AMORT
  FROM `data-dtptechm-prd-c7ca.dwh.h3i_revenue_per_site_extended_others_detail` a
  WHERE CAST(dt_id AS DATE) = vdt_id
  AND process_nm IN ('RITA_P3PRICE_AMORT')
  GROUP BY 1, 2, 3;

insert into `data-bi-prd-935c.bi_mart.project_mis_profile_subs_sites` 
select 
CAST(dt_id AS date) as load_dt_sk_id,
site_id,
lower(kpi_nm) as tag,
CAST(value AS FLOAT64) as amount,
'idr' as UOM,
CURRENT_DATE() as create_dt
from `data-bi-prd-935c.bi_stg.rev_site` where CAST(dt_id AS DATE) = vdt_id;


insert into `data-bi-prd-935c.bi_mart.project_mis_profile_subs_sites` 
select 
CAST(dt_id AS date) as load_dt_sk_id,
site_id,
'total revenue' as tag,
CAST(sum(value) AS FLOAT64) as amount,
'idr' as UOM,
CURRENT_DATE() as create_dt
from `data-bi-prd-935c.bi_stg.rev_site` where CAST(dt_id AS DATE) = vdt_id
group by 1,2;

-- ======================================================================================
delete from `data-bi-prd-935c.bi_mart.project_mis_profile_subs_sites` where CAST(load_dt_sk_id AS DATE) = vdt_id and tag='RGU Daily';


insert into `data-bi-prd-935c.bi_mart.project_mis_profile_subs_sites`
-- select distinct CAST(vdt_id AS date) as dt, 
-- case when length(d.site_id_dly) < 6 then LPAD(d.site_id_dly,6,'0') else d.site_id_dly end as site_id_dly,
-- 'RGU Daily',
-- CAST(count(distinct a.sbscrptn_ek_id) AS FLOAT64),
-- 'SUBS',
-- CURRENT_DATE() as created_dt
-- from `data-dtptechm-prd-c7ca.dwh.rgs_subs_detail` a
-- left outer join `data-dtptechm-prd-c7ca.dwh.sbscrptn_attribs` b on CAST(a.sbscrptn_ek_id AS STRING) = CAST(b.sbscrptn_ek_id AS STRING)
-- join `data-bi-prd-935c.bi_mart.project_ioh_dgpcr_flag` c on b.sbscrptn_msisdn=c.service_msisdn
-- left join `data-bi-prd-935c.bi_mart.ioh_subscriber_site_attribs_rolling` d on CAST(a.sbscrptn_ek_id AS STRING) = CAST(d.sbscrptn_ek_id AS STRING)
-- where CAST(rgs_all_ex_sp AS STRING) = 't' and a.tool_of_trade_ind = 'N' and CAST(a.load_dt_sk_id AS DATE) = vdt_id
-- group by 1,2,3;
with subs as (select * from `data-dtptechm-prd-c7ca.dwh.sbscrptn_attribs`)
SELECT 
  distinct CAST(vdt_id AS date) AS dt,
  
  CASE 
    WHEN LENGTH(d.site_id_dly) < 6 THEN LPAD(d.site_id_dly, 6, '0') 
    ELSE d.site_id_dly 
  END AS site_id_dly,
  
  'RGU Daily' AS source_label,
  CAST(COUNT(DISTINCT a.sbscrptn_ek_id) AS FLOAT64) AS subs_count,
  'SUBS' AS metric_type,
  CURRENT_DATE() AS created_dt

FROM `data-dtptechm-prd-c7ca.dwh.rgs_subs_detail` a

LEFT JOIN subs b 
  ON a.sbscrptn_ek_id = b.sbscrptn_ek_id

JOIN `data-bi-prd-935c.bi_mart.project_ioh_dgpcr_flag` c 
  ON b.sbscrptn_msisdn = c.service_msisdn

LEFT JOIN `data-bi-prd-935c.bi_mart.ioh_subscriber_site_attribs_rolling` d 
  ON SAFE_CAST(a.sbscrptn_ek_id AS string) = SAFE_CAST(d.sbscrptn_ek_id AS string) and d.dt = vdt_id

WHERE 
  a.rgs_all_ex_sp
  AND a.tool_of_trade_ind = 'N'
  AND DATE(a.load_dt_sk_id) = vdt_id

GROUP BY 
  dt, site_id_dly, source_label;-- tuned 961 GB


delete from `data-bi-prd-935c.bi_mart.project_mis_profile_subs_sites` 
where CAST(load_dt_sk_id AS DATE) = vdt_id and tag = 'DATA UU' ; 

insert into `data-bi-prd-935c.bi_mart.project_mis_profile_subs_sites`
-- select 
-- CAST(a.load_dt_sk_id AS date), 
-- case when length(d.site_id_30) < 6 then LPAD(d.site_id_30,6,'0') else d.site_id_30 end as site_id_30,
-- 'DATA UU',
-- CAST(count(distinct a.sbscrptn_ek_id) AS FLOAT64) as subs,
-- 'SUBS',
-- CURRENT_DATE() as created_dt
-- from `data-dtptechm-prd-c7ca.dwh.rgs30_subs_detail` a
-- left join `data-dtptechm-prd-c7ca.dwh.sbscrptn_attribs` att on CAST(a.sbscrptn_ek_id AS STRING) = CAST(att.sbscrptn_ek_id AS STRING)
-- join `data-bi-prd-935c.bi_mart.project_ioh_dgpcr_flag` c on att.sbscrptn_msisdn = c.service_msisdn
-- left join `data-bi-prd-935c.bi_mart.ioh_subscriber_site_attribs_rolling` d on CAST(a.sbscrptn_ek_id AS STRING) = CAST(d.sbscrptn_ek_id AS STRING)
-- where (a.rgs30_datapackage_ex_sp or a.rgs30_gprs_ex_sp or a.rgs30_blackberry_ex_sp)
-- and a.tool_of_trade_ind = 'N' and CAST(a.load_dt_sk_id AS DATE) = vdt_id
-- group by 1,2,3; 
with subs as (select * from `data-dtptechm-prd-c7ca.dwh.sbscrptn_attribs`)
SELECT 
  distinct CAST(vdt_id AS date) AS load_date, 
  
  CASE 
    WHEN LENGTH(d.site_id_30) < 6 THEN LPAD(d.site_id_30, 6, '0') 
    ELSE d.site_id_30 
  END AS site_id_30,
  
  'DATA UU' AS source_label,
  CAST(COUNT(DISTINCT a.sbscrptn_ek_id) AS FLOAT64) AS subs,
  'SUBS' AS metric_type,
  CURRENT_DATE() AS created_dt

FROM `data-dtptechm-prd-c7ca.dwh.rgs30_subs_detail` a

LEFT JOIN subs att 
  ON a.sbscrptn_ek_id = att.sbscrptn_ek_id 

JOIN `data-bi-prd-935c.bi_mart.project_ioh_dgpcr_flag` c 
  ON att.sbscrptn_msisdn = c.service_msisdn

LEFT JOIN `data-bi-prd-935c.bi_mart.ioh_subscriber_site_attribs_rolling` d 
  ON SAFE_CAST(a.sbscrptn_ek_id AS string) = SAFE_CAST(d.sbscrptn_ek_id AS string) and d.dt = vdt_id

WHERE 
  (
    a.rgs30_datapackage_ex_sp = TRUE 
    OR a.rgs30_gprs_ex_sp = TRUE 
    OR a.rgs30_blackberry_ex_sp = TRUE
  )
  AND a.tool_of_trade_ind = 'N'
  AND DATE(a.load_dt_sk_id) =  DATE(vdt_id)

GROUP BY 
  load_date, site_id_30, source_label;-- tuned 964GB


delete from `data-bi-prd-935c.bi_mart.project_mis_profile_subs_sites` where CAST(load_dt_sk_id AS DATE) = vdt_id and tag='DATA GA' ;

insert into `data-bi-prd-935c.bi_mart.project_mis_profile_subs_sites`
-- select 
-- CAST(a.ga_date AS date),
-- case when length(d.site_id_30) < 6 then LPAD(d.site_id_90,6,'0') else d.site_id_90 end as site_id_90,
-- 'DATA GA',
-- CAST(count(distinct a.sbscrptn_ek_id) AS FLOAT64),
-- 'SUBS',
-- CURRENT_DATE()
-- from `data-bi-prd-935c.bi_mart.project_ioh_fu_master_v2` a
-- left join `data-bi-prd-935c.bi_mart`.ioh_subscriber_site_attribs_rolling d on CAST(a.sbscrptn_ek_id AS STRING) = d.sbscrptn_ek_id
--  where CAST(ga_date AS DATE) =vdt_id
-- group by 1,2;

SELECT 
  distinct CAST(vdt_id AS date) AS ga_date,
  
  CASE 
    WHEN LENGTH(d.site_id_30) < 6 THEN LPAD(d.site_id_90, 6, '0') 
    ELSE d.site_id_90 
  END AS site_id_90,

  'DATA GA' AS source_label,
  CAST(COUNT(DISTINCT a.sbscrptn_ek_id) AS FLOAT64) AS subs_count,
  'SUBS' AS metric_type,
  CURRENT_DATE() AS query_date

FROM `data-bi-prd-935c.bi_mart.project_ioh_fu_master_v2` a

LEFT JOIN `data-bi-prd-935c.bi_mart.ioh_subscriber_site_attribs_rolling` d 
  ON CAST(a.sbscrptn_ek_id AS string) = CAST(d.sbscrptn_ek_id AS string) and d.dt = vdt_id

WHERE DATE(a.ga_date) = vdt_id

GROUP BY 
  ga_date, site_id_90;-- tuned 1.4TB

drop table if exists `data-bi-prd-935c.bi_stg.rgs_subs_detail30`;
CREATE table `data-bi-prd-935c.bi_stg.rgs_subs_detail30` as
select 
 sbscrptn_ek_id
from 
`data-dtptechm-prd-c7ca.dwh.rgs_subs_detail`
WHERE 
  DATE(load_dt_sk_id) BETWEEN DATE_SUB(vdt_id , INTERVAL 29 DAY) AND  vdt_id
  AND rgs_all_ex_sp
  AND tool_of_trade_ind = 'N'
  group by 1;

delete from `data-bi-prd-935c.bi_mart.project_mis_profile_subs_sites` where CAST(load_dt_sk_id AS DATE)=vdt_id and tag='RGU30';

drop table if exists `data-bi-prd-935c.bi_stg.tmp_subs_rolling`;

create table `data-bi-prd-935c.bi_stg.tmp_subs_rolling` as
select site_id_30,SAFE_CAST(sbscrptn_ek_id AS string) as sbscrptn_ek_id from `data-bi-prd-935c.bi_mart.ioh_subscriber_site_attribs_rolling` where  dt = vdt_id;

insert into `data-bi-prd-935c.bi_mart.project_mis_profile_subs_sites`
with subs_rolling as
(select * from `data-bi-prd-935c.bi_mart.ioh_subscriber_site_attribs_rolling` where  dt = vdt_id)
SELECT 
  distinct CAST(vdt_id AS date) AS dt,
  CASE 
    WHEN LENGTH(d.site_id_30) < 6 THEN LPAD(d.site_id_30, 6, '0') 
    ELSE d.site_id_30 
  END AS site_id_30,

  'RGU30' AS source_label,
  CAST(COUNT(DISTINCT a.sbscrptn_ek_id) AS FLOAT64) AS subs,
  'SUBS' AS metric_type,
  CURRENT_DATE() AS created_dt

FROM `data-bi-prd-935c.bi_stg.rgs_subs_detail30` a

LEFT JOIN  `data-dtptechm-prd-c7ca.dwh.sbscrptn_attribs` b 
  ON a.sbscrptn_ek_id = b.sbscrptn_ek_id 

JOIN `data-bi-prd-935c.bi_mart.project_ioh_dgpcr_flag` c 
  ON b.sbscrptn_msisdn = c.service_msisdn

LEFT JOIN `data-bi-prd-935c.bi_stg.tmp_subs_rolling` d 
on SAFE_CAST(a.sbscrptn_ek_id AS string) = d.sbscrptn_ek_id
GROUP BY 
  dt, site_id_30, source_label;-- tuned 975GB

drop table if exists `data-bi-prd-935c.bi_stg.rgs_subs_detail30`;


delete from `data-bi-prd-935c.bi_mart.dm_siteprofile` where CAST(period AS DATE) = vdt_id;

INSERT INTO `data-bi-prd-935c.bi_mart.dm_siteprofile`
SELECT 
  CAST(vdt_id AS date) AS period,
  site_id,
  CAST(CASE WHEN b.siteid IS NOT NULL THEN 1 ELSE 0 END AS STRING) AS lowsite_flag,
  CAST(SUM(CASE WHEN tag = 'RGU30' AND CAST(load_dt_sk_id AS DATE) = vdt_id THEN CAST(amount AS numeric) ELSE 0 END) AS FLOAT64) AS rgu30_subs,
  CAST(CEIL(AVG(CASE WHEN tag = 'VLR' THEN CAST(amount AS numeric) END)) AS FLOAT64) AS avg_vlr_subs,
  CAST(SUM(CASE WHEN tag = 'DATA UU' AND CAST(load_dt_sk_id AS DATE) = vdt_id THEN CAST(amount AS numeric) ELSE 0 END) AS FLOAT64) AS data_uu_subs,
  CAST(CEIL(AVG(CASE WHEN tag = 'data subs' THEN CAST(amount AS numeric) END)) AS FLOAT64) AS avg_data_usg_subs,
  CAST(CEIL(AVG(CASE WHEN tag = 'voice subs' THEN CAST(amount AS numeric) END)) AS FLOAT64) AS avg_voice_usg_subs,
  CAST(SUM(CASE WHEN tag = 'voice traffic' THEN CAST(amount AS numeric) ELSE 0 END) AS FLOAT64) AS voice_traffic_rolling,
  CAST(SUM(CASE WHEN tag = 'data traffic' THEN CAST(amount AS numeric) ELSE 0 END) AS FLOAT64) AS data_traffic_rolling,
  CAST(SUM(CASE WHEN tag = 'total revenue' THEN CAST(amount AS numeric) ELSE 0 END) AS FLOAT64) AS total_net_revenue,
  CAST(SUM(CASE WHEN tag = 'data revenue' THEN CAST(amount AS numeric) ELSE 0 END) AS FLOAT64) AS data_net_revenue,
  CAST(SUM(CASE WHEN tag = 'voice revenue' THEN CAST(amount AS numeric) ELSE 0 END) AS FLOAT64) AS voice_net_revenue,
  -- MTD
  CAST(SUM(CASE WHEN tag = 'total revenue' 
           AND CAST(load_dt_sk_id AS DATE) BETWEEN DATE_TRUNC(vdt_id, MONTH) AND vdt_id THEN CAST(amount AS numeric) ELSE 0 END) AS FLOAT64) AS total_netrev_MTD,
  CAST(SUM(CASE WHEN tag = 'data revenue' 
           AND CAST(load_dt_sk_id AS DATE) BETWEEN DATE_TRUNC(vdt_id, MONTH) AND vdt_id THEN CAST(amount AS numeric) ELSE 0 END) AS FLOAT64) AS total_datarev_MTD,
  CAST(SUM(CASE WHEN tag = 'voice traffic' 
           AND CAST(load_dt_sk_id AS DATE) BETWEEN DATE_TRUNC(vdt_id, MONTH) AND vdt_id THEN CAST(amount AS numeric) ELSE 0 END) AS FLOAT64) AS voice_traffic_MTD,
  CAST(SUM(CASE WHEN tag = 'data traffic' 
           AND CAST(load_dt_sk_id AS DATE) BETWEEN DATE_TRUNC(vdt_id, MONTH) AND vdt_id THEN CAST(amount AS numeric) ELSE 0 END) AS FLOAT64) AS data_traffic_MTD
FROM `data-bi-prd-935c.bi_mart.project_mis_profile_subs_sites` a
LEFT OUTER JOIN `data-bi-prd-935c.bi_mart.dim_lowsites` b ON a.site_id = b.siteid 
  AND b.quarter = '1' AND b.year  = format_date('%Y',cast(vdt_id as date)) 
WHERE (CAST(load_dt_sk_id AS DATE) > DATE_SUB(vdt_id, INTERVAL 1 MONTH)
       AND CAST(load_dt_sk_id AS DATE) <= vdt_id)
GROUP BY 1, 2, 3;

drop table if exists `data-bi-prd-935c.bi_stg.tmp_subs_rolling`;
