DECLARE vdt_id DATE DEFAULT @vdt_id;

-- Insert data into dm_usage_subs_site table
INSERT INTO `data-bi-prd-935c.bi_mart.dm_usage_subs_site`
SELECT 
    created_dt_sk_id,
    sbscrptn_ek_id,
    COALESCE(d.newsiteid, b.site_id, a.site_id) AS site_id,
    CAST(SUM(usage) / POW(1024, 2) AS NUMERIC) AS usage
FROM `data-dtptechm-prd-c7ca.dwh.ioh_daily_base_ggsn_site` a
LEFT JOIN (
    SELECT DISTINCT 
        UPPER(c.egci) AS egci,
        c.site_id, 
        UPPER(c.gladiator_branch), 
        3 AS tag, 
        CURRENT_TIMESTAMP() AS created_dtm
    FROM `data-bi-prd-935c.mis.tmp_site_ref_dim_ale` c
) b ON b.egci = a.calling_cell_id
LEFT JOIN `data-bi-prd-935c.bi_mart.dim_mocn_site_ref` d 
    ON a.calling_cell_id = d.globalcellidafter -- ini sitelist mocn
WHERE created_dt_sk_id = vdt_id
GROUP BY 1, 2, 3;

-- Insert data into dm_project_data_site_dly table
INSERT INTO `data-bi-prd-935c.bi_mart.dm_project_data_site_dly`
SELECT
    created_dt_sk_id,
    CAST(sbscrptn_ek_id AS STRING),
    site_id
FROM (
    SELECT 
        created_dt_sk_id,
        sbscrptn_ek_id,
        site_id,
        RANK() OVER(PARTITION BY sbscrptn_ek_id ORDER BY usage DESC, site_id DESC) AS rank_id
    FROM (
        SELECT 
            vdt_id AS created_dt_sk_id,
            COALESCE(d.newsiteid, b.site_id, a.site_id) AS site_id,
            sbscrptn_ek_id,
            SUM(usage) AS usage
        FROM `data-dtptechm-prd-c7ca.dwh.ioh_daily_base_ggsn_site` a
        LEFT JOIN (
            SELECT DISTINCT 
                UPPER(c.egci) AS egci,
                c.site_id, 
                UPPER(c.gladiator_branch), 
                3 AS tag, 
                CURRENT_TIMESTAMP() AS created_dtm
            FROM `data-bi-prd-935c.mis.tmp_site_ref_dim_ale` c
        ) b ON b.egci = a.calling_cell_id
        LEFT JOIN `data-bi-prd-935c.bi_mart.dim_mocn_site_ref` d 
            ON a.calling_cell_id = d.globalcellidafter -- ini sitelist mocn
        WHERE created_dt_sk_id = vdt_id
        -- AND flag_found = 1
        GROUP BY 1, 2, 3
    ) q
) w
WHERE rank_id = 1;

-- Insert data into dm_usage_subs_site
INSERT INTO `data-bi-prd-935c.bi_mart.dm_usage_subs_site`
SELECT 
  created_dt_sk_id,
  sbscrptn_ek_id,
  COALESCE(d.newsiteid, b.site_id, a.site_id) AS site_id,
  (SUM(usage) / POW(1024, 2)) AS usage -- Convert usage to MB
FROM `data-dtptechm-prd-c7ca.dwh.ioh_daily_base_ggsn_site` a
LEFT JOIN (
  SELECT DISTINCT 
    UPPER(c.egci) AS egci, 
    c.site_id, 
    UPPER(c.gladiator_branch) AS gladiator_branch, 
    3 AS tag, 
    CURRENT_TIMESTAMP() AS created_dtm 
  FROM `data-bi-prd-935c.mis.tmp_site_ref_dim_ale` c
) b ON b.egci = a.calling_cell_id
LEFT JOIN `data-bi-prd-935c.bi_mart.dim_mocn_site_ref` d 
  ON a.calling_cell_id = d.globalcellidafter -- Sitelist MOCN
WHERE a.created_dt_sk_id = vdt_id
GROUP BY 1, 2, 3;

-- Insert ranked data into dm_project_data_site_dly
INSERT INTO `data-bi-prd-935c.bi_mart.dm_project_data_site_dly`
SELECT
  created_dt_sk_id,
  CAST(sbscrptn_ek_id AS STRING),
  site_id
FROM (
  SELECT 
    created_dt_sk_id,
    sbscrptn_ek_id,
    site_id,
    RANK() OVER(PARTITION BY sbscrptn_ek_id ORDER BY usage DESC, site_id DESC) AS rank_id
  FROM (
    SELECT 
      vdt_id AS created_dt_sk_id,
      COALESCE(d.newsiteid, b.site_id, a.site_id) AS site_id,
      sbscrptn_ek_id,
      SUM(usage) AS usage
    FROM `data-dtptechm-prd-c7ca.dwh.ioh_daily_base_ggsn_site` a
    LEFT JOIN (
      SELECT DISTINCT 
        UPPER(c.egci) AS egci, 
        c.site_id, 
        UPPER(c.gladiator_branch) AS gladiator_branch, 
        3 AS tag, 
        CURRENT_TIMESTAMP() AS created_dtm 
      FROM `data-bi-prd-935c.mis.tmp_site_ref_dim_ale` c
    ) b ON b.egci = a.calling_cell_id
    LEFT JOIN `data-bi-prd-935c.bi_mart.dim_mocn_site_ref` d
      ON a.calling_cell_id = d.globalcellidafter -- Sitelist MOCN
    WHERE created_dt_sk_id = vdt_id
    GROUP BY 1, 2, 3
  ) q
) w
WHERE rank_id = 1;

-- Truncate the staging table
TRUNCATE TABLE `data-bi-prd-935c.bi_stg.stg_usage_30_90`;

-- Insert data into stg_usage_30_90
INSERT INTO `data-bi-prd-935c.bi_stg.stg_usage_30_90`
SELECT 
  vdt_id AS dt,
  site_id,
  sbscrptn_ek_id,
  SUM(usage_mb) AS usage_mb_90,
  SUM(CASE 
      WHEN created_dt_sk_id BETWEEN DATE_SUB(vdt_id, INTERVAL 29 DAY)
        AND vdt_id THEN usage_mb ELSE 0 
    END) AS usage_mb_30
FROM `data-bi-prd-935c.bi_mart.dm_usage_subs_site`
WHERE created_dt_sk_id BETWEEN DATE_SUB(vdt_id, INTERVAL 89 DAY)
  AND vdt_id
  AND site_id IS NOT NULL
  AND created_dt_sk_id BETWEEN DATE_SUB(vdt_id, INTERVAL 89 DAY) AND vdt_id
GROUP BY site_id, sbscrptn_ek_id;

-- Drop temporary table if exists
DROP TABLE IF EXISTS `data-bi-prd-935c.bi_stg.usg_30`;

-- Create temp table usg_30
CREATE TABLE `data-bi-prd-935c.bi_stg.usg_30` AS
SELECT 
  ROW_NUMBER() OVER(PARTITION BY sbscrptn_ek_id ORDER BY usage_mb_30 DESC, site_id) AS seqno,
  a.*
FROM `data-bi-prd-935c.bi_stg.stg_usage_30_90` a
WHERE usage_mb_30 > 0;

-- Insert top usage data into dm_project_data_site_30
INSERT INTO `data-bi-prd-935c.bi_mart.dm_project_data_site_30`
SELECT
  dt AS created_dt_sk_id,
  CAST(sbscrptn_ek_id AS STRING) AS sbscrptn_ek_id,
  site_id
FROM `data-bi-prd-935c.bi_stg.usg_30`
WHERE seqno = 1;

--========= CHAIN 2

-- Insert data into the project_merged_voice_usg_dly table
INSERT INTO `data-bi-prd-935c.bi_mart.project_merged_voice_usg_dly`
SELECT 
    CAST(charge_start_dt_sk_id AS DATE) AS dt_sk_id,
    -- COALESCE(d.globalcellidafter, b.site_id, calling_cell_id) AS site_id,
    COALESCE(d.newsiteid, b.site_id) AS site_id,
    a.sbscrptn_msisdn,
    CAST(sd.sbscrptn_ek_id AS STRING) AS sbscrptn_ek_id,
    CASE WHEN b.egci IS NOT NULL OR d.globalcellidafter IS NOT NULL THEN 1 ELSE 0 END AS flag_found,
    SUM(usage_dur) AS usage,
		null as upd_dt
FROM `data-dtptechm-prd-c7ca.dwh.charged_event_fct` a
LEFT JOIN (SELECT DISTINCT UPPER(c.egci) AS egci, c.site_id FROM `data-bi-prd-935c.mis.tmp_site_ref_dim_ale` c) b 
    ON b.egci = a.calling_cell_id
LEFT JOIN `data-bi-prd-935c.bi_mart.dim_mocn_site_ref` d 
    ON a.calling_cell_id = d.globalcellidafter  -- Site list MOCN
LEFT JOIN `data-dtptechm-prd-c7ca.dwh.sbscrptn_dim` sd 
    ON a.sbscrptn_sk_id = sd.sbscrptn_sk_id
WHERE CAST(charge_start_dt_sk_id AS DATE) = vdt_id  -- BETWEEN 20210901 AND 20220131 -- 20230204 
  AND acct_type_cd = 'MAIN'
  AND usage_dur > 0
	AND record_end_dtm > '0001-01-01'
GROUP BY 1, 2, 3, 4, 5;

-- Insert data into project_merged_voice_usg_dly_2 table
INSERT INTO `data-bi-prd-935c.bi_mart.project_merged_voice_usg_dly_2`
SELECT
    dt_sk_id,
    site_id,
    sbscrptn_msisdn,
    sbscrptn_ek_id,
    1,
    CAST(usage AS NUMERIC),
    CURRENT_TIMESTAMP() AS now
FROM (
    SELECT
        dt_sk_id,
        sbscrptn_msisdn,
        sbscrptn_ek_id,
        site_id,
        usage,
        RANK() OVER (PARTITION BY dt_sk_id, sbscrptn_ek_id ORDER BY usage DESC, site_id DESC) AS rank_id
    FROM (
        SELECT 
            dt_sk_id,
            site_id,
            sbscrptn_ek_id,
            sbscrptn_msisdn,
            SUM(usage) AS usage
        FROM `data-bi-prd-935c.bi_mart.project_merged_voice_usg_dly`
        WHERE CAST(dt_sk_id AS DATE) = vdt_id
        GROUP BY 1, 2, 3, 4
    ) q
) w
WHERE rank_id = 1;

-- Insert data into project_merged_voice_usg_30 table
INSERT INTO `data-bi-prd-935c.bi_mart.project_merged_voice_usg_30`
SELECT
    dt_sk_id,
    site_id,
    sbscrptn_msisdn,
    sbscrptn_ek_id,
    1,
    usage,
    CURRENT_TIMESTAMP() AS now
FROM (
    SELECT
        dt_sk_id,
        sbscrptn_msisdn,
        sbscrptn_ek_id,
        site_id,
        usage,
        RANK() OVER (PARTITION BY sbscrptn_ek_id ORDER BY usage DESC, site_id DESC) AS rank_id
    FROM (
        SELECT 
            vdt_id AS dt_sk_id,
            site_id,
            sbscrptn_ek_id,
            sbscrptn_msisdn,
            SUM(usage) AS usage
        FROM `data-bi-prd-935c.bi_mart.project_merged_voice_usg_dly`
        WHERE CAST(dt_sk_id AS DATE) BETWEEN DATE_SUB(vdt_id, INTERVAL 29 DAY) 
            AND vdt_id
          AND flag_found = 1
        GROUP BY 1, 2, 3, 4
    ) q
) w
WHERE rank_id = 1;

-- Insert data into project_merged_voice_usg_90 table
INSERT INTO `data-bi-prd-935c.bi_mart.project_merged_voice_usg_90`
SELECT
    dt_sk_id,
    site_id,
    sbscrptn_msisdn,
    sbscrptn_ek_id,
    1,
    usage,
    CURRENT_TIMESTAMP() AS now
FROM (
    SELECT
        dt_sk_id,
        sbscrptn_msisdn,
        sbscrptn_ek_id,
        site_id,
        usage,
        RANK() OVER (PARTITION BY sbscrptn_ek_id ORDER BY usage DESC, site_id DESC) AS rank_id
    FROM (
        SELECT 
            vdt_id AS dt_sk_id,
            site_id,
            sbscrptn_ek_id,
            sbscrptn_msisdn,
            SUM(usage) AS usage
        FROM `data-bi-prd-935c.bi_mart.project_merged_voice_usg_dly`
        WHERE CAST(dt_sk_id AS DATE) BETWEEN DATE_SUB(vdt_id, INTERVAL 89 DAY)
            AND vdt_id
          AND flag_found = 1
        GROUP BY 1, 2, 3, 4
    ) q
) w
WHERE rank_id = 1;

--========= CHAIN 3

TRUNCATE TABLE `data-bi-prd-935c.bi_stg.list_subs_fu`;

TRUNCATE TABLE `data-bi-prd-935c.bi_stg.list_subs_nonfu`;

INSERT INTO `data-bi-prd-935c.bi_stg.list_subs_fu`
                --create table `data-bi-prd-935c.bi_stg.list_subs_fu` as
                SELECT
                vdt_id AS dt,
                CAST(sbscrptn_ek_id AS STRING) AS sbscrptn_ek_id,
                sbscrptn_msisdn,
                LEAST(CAST(sd.first_usage_dt AS DATE),
                      LEAST(PARSE_DATE('%Y%m%d',CAST(sd.first_billing_usage_dt_sk_id AS STRING)), CAST(sd.any_event_first_usage_date AS DATE)))
                      AS fu_dt,
                CAST(activation_dtm AS DATE) AS activation_dtm,
                CAST(termination_dtm AS DATE) AS termination_dtm,
                angie_retailer_name,
                angie_channel_sk_id
                FROM `data-dtptechm-prd-c7ca.dwh.sbscrptn_attribs` sd
                WHERE 
                CAST(activation_dtm AS DATE) <= vdt_id AND 
                CAST(termination_dtm AS DATE) > vdt_id 
                AND
                CAST(sd.sbscrptn_ek_id AS STRING) <> '1113974097' 
                AND 
                LEAST(CAST(sd.first_usage_dt AS DATE),
                      LEAST(PARSE_DATE('%Y%m%d',CAST(sd.first_billing_usage_dt_sk_id AS STRING)), CAST(sd.any_event_first_usage_date AS DATE)))
                                BETWEEN DATE_TRUNC(vdt_id, MONTH)
                                AND vdt_id
                ;

INSERT INTO `data-bi-prd-935c.bi_stg.list_subs_nonfu`
                ---create  table `data-bi-prd-935c.bi_stg.list_subs_nonfu` as
                SELECT
                vdt_id AS dt,
                CAST(sd.sbscrptn_ek_id AS STRING) AS sbscrptn_ek_id,
                sd.sbscrptn_msisdn,
                LEAST(CAST(sd.first_usage_dt AS DATE),
                      LEAST(PARSE_DATE('%Y%m%d',CAST(sd.first_billing_usage_dt_sk_id AS STRING)), CAST(sd.any_event_first_usage_date AS DATE)))
                      AS fu_dt,
                CAST(sd.activation_dtm AS DATE) AS activation_dtm,
                CAST(sd.termination_dtm AS DATE) AS termination_dtm,
                sd.angie_retailer_name,
                sd.angie_channel_sk_id
                FROM `data-dtptechm-prd-c7ca.dwh.sbscrptn_attribs` sd
                LEFT JOIN `data-bi-prd-935c.bi_stg.list_subs_fu` fu 
                    ON CAST(sd.sbscrptn_ek_id AS STRING) = fu.sbscrptn_ek_id
                WHERE CAST(sd.activation_dtm AS DATE) <= vdt_id
                AND CAST(sd.termination_dtm AS DATE) > vdt_id 
                AND fu.sbscrptn_ek_id IS NULL
                AND CAST(sd.sbscrptn_ek_id AS STRING) <> '1113974097'
                ;

INSERT INTO `data-bi-prd-935c.bi_mart.ioh_subscriber_site_attribs_rolling`
                SELECT 
                vdt_id AS dt,
                ls.sbscrptn_ek_id,
                ls.sbscrptn_msisdn,
                ls.activation_dtm,
                ls.termination_dtm,
                ls.angie_retailer_name,
                --dt.site_id as site_data,
                --vc.site_id site_voice,
                --vl.site_id site_vlr,
                --coalesce(qr.site_retailer,e.site_id) as site_retailer,
                --case when fu_dt=20230204 then coalesce(dt.site_id, vc.site_id, vl.site_id,qr.site_retailer,e.site_id)  else '' end as site_id_fu ,
		CASE WHEN fu_dt = vdt_id THEN 
						CASE WHEN LENGTH(COALESCE(dt.site_id, vc.site_id, vl.site_id, qr.site_retailer, e.site_id)) < 6 THEN 
							LPAD(COALESCE(dt.site_id, vc.site_id, vl.site_id, qr.site_retailer, e.site_id), 6, '0')  
						ELSE COALESCE(dt.site_id, vc.site_id, vl.site_id, qr.site_retailer, e.site_id) 
						END	
		ELSE '' END AS site_id_fu ,		
                --coalesce('') as site_id_30,
                --coalesce('') as site_id_90
                CASE WHEN LENGTH(COALESCE(dt3.site_id, vc3.site_id, vl3.site_id, qr.site_retailer, e.site_id)) < 6 THEN 
                        LPAD(COALESCE(dt3.site_id, vc3.site_id, vl3.site_id, qr.site_retailer, e.site_id), 6, '0') 
                        ELSE COALESCE(dt3.site_id, vc3.site_id, vl3.site_id, qr.site_retailer, e.site_id) 
                END AS site_id_30,
                CASE WHEN LENGTH(COALESCE(dt2.site_id, vc2.site_id, vl2.site_id, qr.site_retailer, e.site_id)) < 6 THEN 
                        LPAD(COALESCE(dt2.site_id, vc2.site_id, vl2.site_id, qr.site_retailer, e.site_id), 6, '0') 
                        ELSE COALESCE(dt2.site_id, vc2.site_id, vl2.site_id, qr.site_retailer, e.site_id) 
                END AS site_id_90,
                CASE WHEN LENGTH(COALESCE(dt4.site_id, vc4.site_id, vl4.site_id, qr.site_retailer, e.site_id)) < 6 THEN 
                        LPAD(COALESCE(dt4.site_id, vc4.site_id, vl4.site_id, qr.site_retailer, e.site_id), 6, '0') 
                        ELSE COALESCE(dt4.site_id, vc4.site_id, vl4.site_id, qr.site_retailer, e.site_id) 
                END AS site_id_dly
                --case when coalesce(dt.site_id, vc.site_id, vl.site_id,qr.site_retailer,e.site_id) is null 
                --          or coalesce(dt.site_id, vc.site_id, vl.site_id,qr.site_retailer,e.site_id) ='' 
                --              then 'not found'
                --else 'found' end as site_tag
                FROM `data-bi-prd-935c.bi_stg.list_subs_fu` ls
                LEFT JOIN (SELECT created_dt_sk_id, sbscrptn_ek_id, site_id FROM `data-bi-prd-935c.bi_mart.dm_project_data_site_dly` WHERE created_dt_sk_id = vdt_id) dt 
                    ON ls.sbscrptn_ek_id = dt.sbscrptn_ek_id AND fu_dt = dt.created_Dt_sk_id
                LEFT JOIN (SELECT dt_sk_id, site_id, sbscrptn_msisdn, sbscrptn_ek_id, flag_found, usage FROM `data-bi-prd-935c.bi_mart.project_merged_voice_usg_dly` WHERE dt_sk_id = vdt_id) vc
                    ON ls.sbscrptn_ek_id = vc.sbscrptn_ek_id AND fu_dt = vc.Dt_sk_id
                LEFT JOIN (SELECT dt_sk_id, sbscrptn_msisdn, site_id, nod, flag_found FROM `data-bi-prd-935c.bi_mart.project_vlr_subs_dly` WHERE dt_sk_id = vdt_id) vl 
                    ON ls.sbscrptn_msisdn = vl.sbscrptn_msisdn 
                    AND fu_dt = vl.Dt_sk_id
                LEFT JOIN (SELECT created_dt_sk_id, sbscrptn_ek_id, site_id FROM `data-bi-prd-935c.bi_mart.dm_project_data_site_30` WHERE created_dt_sk_id = vdt_id) dt3 
                    ON ls.sbscrptn_ek_id = dt3.sbscrptn_ek_id ---and dt=dt3.created_Dt_sk_id
                LEFT JOIN (SELECT dt_sk_id, site_id, sbscrptn_msisdn, sbscrptn_ek_id, flag_found, usage FROM `data-bi-prd-935c.bi_mart.project_merged_voice_usg_30` WHERE dt_sk_id = vdt_id) vc3 
                    ON ls.sbscrptn_ek_id = vc3.sbscrptn_ek_id ---and dt=vc3.Dt_sk_id
                LEFT JOIN (SELECT dt_sk_id, sbscrptn_msisdn, site_id, nod, flag_found FROM `data-bi-prd-935c.bi_mart.project_vlr_subs_30` WHERE dt_sk_id = vdt_id) vl3 
                    ON ls.sbscrptn_msisdn = vl3.sbscrptn_msisdn --and dt=vl3.Dt_sk_id
                LEFT JOIN (SELECT created_dt_sk_id, sbscrptn_ek_id, site_id FROM `data-bi-prd-935c.bi_mart.dm_project_data_site_90` WHERE created_dt_sk_id = vdt_id) dt2 
                    ON ls.sbscrptn_ek_id = dt2.sbscrptn_ek_id --and dt=dt2.created_Dt_sk_id
                LEFT JOIN (SELECT dt_sk_id, site_id, sbscrptn_msisdn, sbscrptn_ek_id, flag_found, usage FROM `data-bi-prd-935c.bi_mart.project_merged_voice_usg_90` WHERE dt_sk_id = vdt_id) vc2 
                    ON ls.sbscrptn_ek_id = vc2.sbscrptn_ek_id --and dt=vc2.Dt_sk_id
                LEFT JOIN (SELECT dt_sk_id, sbscrptn_msisdn, site_id, nod, flag_found FROM `data-bi-prd-935c.bi_mart.project_vlr_subs_90` WHERE dt_sk_id = vdt_id) vl2 
                    ON ls.sbscrptn_msisdn = vl2.sbscrptn_msisdn ---and dt=vl2.Dt_sk_id
                LEFT JOIN (SELECT created_dt_sk_id, sbscrptn_ek_id, site_id FROM `data-bi-prd-935c.bi_mart.dm_project_data_site_dly` where created_dt_sk_id = vdt_id) dt4 
                    ON ls.sbscrptn_ek_id = dt4.sbscrptn_ek_id --and dt=dt4.created_Dt_sk_id
                LEFT JOIN (SELECT dt_sk_id, site_id, sbscrptn_msisdn, sbscrptn_ek_id, flag_found, usage FROM `data-bi-prd-935c.bi_mart.project_merged_voice_usg_dly` WHERE dt_sk_id = vdt_id) vc4 
                    ON ls.sbscrptn_ek_id = vc4.sbscrptn_ek_id --and dt=vc4.Dt_sk_id
                LEFT JOIN (SELECT dt_sk_id, sbscrptn_msisdn, site_id, nod, flag_found FROM `data-bi-prd-935c.bi_mart.project_vlr_subs_dly` WHERE dt_sk_id = vdt_id) vl4 
                    ON ls.sbscrptn_msisdn = vl4.sbscrptn_msisdn --and dt=vl4.Dt_sk_id
             --   left join subscriber_site_retailer qr on ls.sbscrptn_ek_id = qr.sbscrptn_ek_id 
                  LEFT OUTER JOIN (SELECT DISTINCT ret_qr_cd, 
                                    CASE WHEN LENGTH(site_id) < 6 THEN LPAD(site_id, 6, '0') ELSE site_id END AS site_retailer FROM `data-dtptechm-prd-c7ca.stg.stg_v_map_tgt_ret_details`) qr 
                    ON qr.ret_qr_cd = ls.angie_retailer_name 
               LEFT JOIN `data-bi-prd-935c.bi_mart.param_site_qr_mc_v2` e 
                    ON ls.angie_retailer_name = e.qr_code;
			   
-- Insert into ioh_subscriber_site_attribs_rolling
INSERT INTO `data-bi-prd-935c.bi_mart.ioh_subscriber_site_attribs_rolling`
SELECT 
    vdt_id AS dt,
    ls.sbscrptn_ek_id,
    ls.sbscrptn_msisdn,
    ls.activation_dtm,
    ls.termination_dtm,
    ls.angie_retailer_name,
    COALESCE('') AS site_id_fu,
    CASE 
        WHEN LENGTH(COALESCE(dt.site_id, vc.site_id, vl.site_id, qr.site_retailer, e.site_id)) < 6 
        THEN LPAD(COALESCE(dt.site_id, vc.site_id, vl.site_id, qr.site_retailer, e.site_id), 6, '0') 
        ELSE COALESCE(dt.site_id, vc.site_id, vl.site_id, qr.site_retailer, e.site_id) 
    END AS site_id_30,
    CASE 
        WHEN LENGTH(COALESCE(dt2.site_id, vc2.site_id, vl2.site_id, qr.site_retailer, e.site_id)) < 6 
        THEN LPAD(COALESCE(dt2.site_id, vc2.site_id, vl2.site_id, qr.site_retailer, e.site_id), 6, '0') 
        ELSE COALESCE(dt2.site_id, vc2.site_id, vl2.site_id, qr.site_retailer, e.site_id) 
    END AS site_id_90,
    CASE 
        WHEN LENGTH(COALESCE(dt3.site_id, vc3.site_id, vl3.site_id, qr.site_retailer, e.site_id)) < 6 
        THEN LPAD(COALESCE(dt3.site_id, vc3.site_id, vl3.site_id, qr.site_retailer, e.site_id), 6, '0') 
        ELSE COALESCE(dt3.site_id, vc3.site_id, vl3.site_id, qr.site_retailer, e.site_id) 
    END AS site_id_dly
FROM `data-bi-prd-935c.bi_stg.list_subs_nonfu` ls
                LEFT JOIN (SELECT created_dt_sk_id, sbscrptn_ek_id, site_id FROM `data-bi-prd-935c.bi_mart.dm_project_data_site_dly` WHERE created_dt_sk_id = vdt_id) dt 
                    ON ls.sbscrptn_ek_id = dt.sbscrptn_ek_id AND fu_dt = dt.created_Dt_sk_id
                LEFT JOIN (SELECT dt_sk_id, site_id, sbscrptn_msisdn, sbscrptn_ek_id, flag_found, usage FROM `data-bi-prd-935c.bi_mart.project_merged_voice_usg_dly` WHERE dt_sk_id = vdt_id) vc
                    ON ls.sbscrptn_ek_id = vc.sbscrptn_ek_id AND fu_dt = vc.Dt_sk_id
                LEFT JOIN (SELECT dt_sk_id, sbscrptn_msisdn, site_id, nod, flag_found FROM `data-bi-prd-935c.bi_mart.project_vlr_subs_dly` WHERE dt_sk_id = vdt_id) vl 
                    ON ls.sbscrptn_msisdn = vl.sbscrptn_msisdn 
                    AND fu_dt = vl.Dt_sk_id
                LEFT JOIN (SELECT created_dt_sk_id, sbscrptn_ek_id, site_id FROM `data-bi-prd-935c.bi_mart.dm_project_data_site_30` WHERE created_dt_sk_id = vdt_id) dt3 
                    ON ls.sbscrptn_ek_id = dt3.sbscrptn_ek_id ---and dt=dt3.created_Dt_sk_id
                LEFT JOIN (SELECT dt_sk_id, site_id, sbscrptn_msisdn, sbscrptn_ek_id, flag_found, usage FROM `data-bi-prd-935c.bi_mart.project_merged_voice_usg_30` WHERE dt_sk_id = vdt_id) vc3 
                    ON ls.sbscrptn_ek_id = vc3.sbscrptn_ek_id ---and dt=vc3.Dt_sk_id
                LEFT JOIN (SELECT dt_sk_id, sbscrptn_msisdn, site_id, nod, flag_found FROM `data-bi-prd-935c.bi_mart.project_vlr_subs_30` WHERE dt_sk_id = vdt_id) vl3 
                    ON ls.sbscrptn_msisdn = vl3.sbscrptn_msisdn --and dt=vl3.Dt_sk_id
                LEFT JOIN (SELECT created_dt_sk_id, sbscrptn_ek_id, site_id FROM `data-bi-prd-935c.bi_mart.dm_project_data_site_90` WHERE created_dt_sk_id = vdt_id) dt2 
                    ON ls.sbscrptn_ek_id = dt2.sbscrptn_ek_id --and dt=dt2.created_Dt_sk_id
                LEFT JOIN (SELECT dt_sk_id, site_id, sbscrptn_msisdn, sbscrptn_ek_id, flag_found, usage FROM `data-bi-prd-935c.bi_mart.project_merged_voice_usg_90` WHERE dt_sk_id = vdt_id) vc2 
                    ON ls.sbscrptn_ek_id = vc2.sbscrptn_ek_id --and dt=vc2.Dt_sk_id
                LEFT JOIN (SELECT dt_sk_id, sbscrptn_msisdn, site_id, nod, flag_found FROM `data-bi-prd-935c.bi_mart.project_vlr_subs_90` WHERE dt_sk_id = vdt_id) vl2 
                    ON ls.sbscrptn_msisdn = vl2.sbscrptn_msisdn ---and dt=vl2.Dt_sk_id
                LEFT JOIN (SELECT created_dt_sk_id, sbscrptn_ek_id, site_id FROM `data-bi-prd-935c.bi_mart.dm_project_data_site_dly` where created_dt_sk_id = vdt_id) dt4 
                    ON ls.sbscrptn_ek_id = dt4.sbscrptn_ek_id --and dt=dt4.created_Dt_sk_id
                LEFT JOIN (SELECT dt_sk_id, site_id, sbscrptn_msisdn, sbscrptn_ek_id, flag_found, usage FROM `data-bi-prd-935c.bi_mart.project_merged_voice_usg_dly` WHERE dt_sk_id = vdt_id) vc4 
                    ON ls.sbscrptn_ek_id = vc4.sbscrptn_ek_id --and dt=vc4.Dt_sk_id
                LEFT JOIN (SELECT dt_sk_id, sbscrptn_msisdn, site_id, nod, flag_found FROM `data-bi-prd-935c.bi_mart.project_vlr_subs_dly` WHERE dt_sk_id = vdt_id) vl4 
                    ON ls.sbscrptn_msisdn = vl4.sbscrptn_msisdn --and dt=vl4.Dt_sk_id
             --   left join subscriber_site_retailer qr on ls.sbscrptn_ek_id = qr.sbscrptn_ek_id 
                  LEFT OUTER JOIN (SELECT DISTINCT ret_qr_cd, 
                                    CASE WHEN LENGTH(site_id) < 6 THEN LPAD(site_id, 6, '0') ELSE site_id END AS site_retailer FROM `data-dtptechm-prd-c7ca.stg.stg_v_map_tgt_ret_details`) qr 
                    ON qr.ret_qr_cd = ls.angie_retailer_name 
               LEFT JOIN `data-bi-prd-935c.bi_mart.param_site_qr_mc_v2` e 
                    ON ls.angie_retailer_name = e.qr_code;

-- Insert into ioh_subscriber_site_attribs_rolling_cfwd
INSERT INTO `data-bi-prd-935c.bi_mart.ioh_subscriber_site_attribs_rolling_cfwd` (dt,sbscrptn_ek_id,sbscrptn_msisdn,activation_dtm,termination_dtm,angie_retailer_name,site_id_fu,site_id_30,site_id_90,site_id_dly,site_id_dly_tag)
SELECT 
    vdt_id AS dt,
    CAST(ls.sbscrptn_ek_id AS INT64),
    ls.sbscrptn_msisdn,
    CAST(FORMAT_DATE('%Y%m%d',ls.activation_dtm) AS INT64),
    CAST(FORMAT_DATE('%Y%m%d',ls.termination_dtm) AS INT64),
    ls.angie_retailer_name,
    ls.site_id_fu,
    ls.site_id_30,
    ls.site_id_90,
    ls.site_id_dly,
    CASE 
        WHEN (dt4.site_id = ls.site_id_dly OR LPAD(dt4.site_id, 6, '0') = ls.site_id_dly) THEN 'data_site'
        WHEN (vc4.site_id = ls.site_id_dly OR LPAD(vc4.site_id, 6, '0') = ls.site_id_dly) THEN 'voice_site'
        WHEN (vl4.site_id = ls.site_id_dly OR LPAD(vl4.site_id, 6, '0') = ls.site_id_dly) THEN 'vlr_site'
        WHEN ls.site_id_dly IS NULL THEN 'null_site'
        ELSE 'retailer_site'
    END AS site_id_dly_tag
FROM `data-bi-prd-935c.bi_mart.ioh_subscriber_site_attribs_rolling` ls
LEFT JOIN (SELECT created_dt_sk_id, sbscrptn_ek_id, site_id FROM `data-bi-prd-935c.bi_mart.dm_project_data_site_dly` WHERE created_dt_sk_id = vdt_id) dt4 
    ON ls.sbscrptn_ek_id = dt4.sbscrptn_ek_id
LEFT JOIN (SELECT dt_sk_id, site_id, sbscrptn_msisdn, sbscrptn_ek_id, flag_found, usage FROM `data-bi-prd-935c.bi_mart.project_merged_voice_usg_dly` WHERE dt_sk_id = vdt_id) vc4 
    ON ls.sbscrptn_ek_id = vc4.sbscrptn_ek_id
LEFT JOIN (SELECT dt_sk_id, sbscrptn_msisdn, site_id, nod, flag_found FROM `data-bi-prd-935c.bi_mart.project_vlr_subs_dly` WHERE dt_sk_id = vdt_id) vl4 
    ON ls.sbscrptn_msisdn = vl4.sbscrptn_msisdn
WHERE dt = vdt_id;