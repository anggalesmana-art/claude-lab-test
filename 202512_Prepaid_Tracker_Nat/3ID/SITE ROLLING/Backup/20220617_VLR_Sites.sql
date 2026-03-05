
-- Prepare Tables

select CURRENT_TIMESTAMP() as start_time;

declare vdt_id date default '2024-06-30';

-- drop table if exists temp_20230206_dt1;
-- create table temp_20230206_dt1 as
-- select null::integer as dt limit 0;
-- insert into temp_20230206_dt1 values (:vtgl);

-- Drop the table if it exists
DROP TABLE IF EXISTS `data-bi-prd-935c.bi_dm.temp_20230206_vdt_id`;

-- Create the temporary table
CREATE TABLE `data-bi-prd-935c.bi_dm.temp_20230206_vdt_id` AS
SELECT CAST(NULL AS INT64) AS dt
WHERE FALSE;  -- Equivalent to LIMIT 0

-- Insert the value into the temporary table
INSERT INTO `data-bi-prd-935c.bi_dm.temp_20230206_vdt_id` (dt)
VALUES (CAST(:vtgl AS INT64));




-- DO $$
-- DECLARE
-- p_dateid integer ;

-- begin
-- select into p_dateid dt from temp_20230206_dt1;

-- 	execute  'ALTER TABLE mis.fct_vlr_sites DROP PARTITION IF EXISTS "'||p_dateid||'"';
-- 	execute  'ALTER TABLE mis.fct_vlr_sites ADD PARTITION "'||p_dateid||'" VALUES('||p_dateid||') WITH (appendonly=true, compresslevel =3, orientation=column, compresstype=zlib,OIDS=FALSE)';
  
  
-- END $$;

-- Get the value from temp_20230206_dt1 and store it in a variable
WITH p_dateid AS (
  SELECT dt FROM `data-bi-prd-935c.bi_dm.temp_20230206_vdt_id`
)
-- Execute the partition drop and add commands
EXECUTE IMMEDIATE (
  SELECT FORMAT('
    ALTER TABLE mis.fct_vlr_sites DROP PARTITION IF EXISTS "%s";
    ALTER TABLE mis.fct_vlr_sites ADD PARTITION "%s" VALUES(%s) 
    WITH (appendonly=true, compresslevel=3, orientation=column, compresstype=zlib, OIDS=FALSE);', 
    dt, dt, dt)
  FROM p_dateid
);


select CURRENT_TIMESTAMP() as table_create;

drop table `data-bi-prd-935c.bi_dm.temp_20230206_vdt_id`;  
   
	truncate table `data-bi-prd-935c.bi_dm.stg_gci_site`;

INSERT INTO `data-bi-prd-935c.bi_dm.stg_gci_site`(gci, site_id, gladiator_branch, tech, tag, created_dtm)
SELECT DISTINCT
    c.egci,
    c.site_id,
    UPPER(c.gladiator_branch),
    SUBSTRING(c.system, 1, 2) AS g_type,
    3::INTEGER AS tag,
    CURRENT_DATE() AS created_dtm
FROM `data-bi-prd-935c.bi_dm.site_ref_dim` c
WHERE c.mth_sk_id IN (
    SELECT MAX(mth_sk_id)
    FROM `data-bi-prd-935c.bi_dm.site_ref_dim`
    WHERE mth_sk_id <= CASE
        WHEN vdt_id <= 20220131 THEN 202112  -- January/February 2021
        WHEN vdt_id <= 20220331 THEN 202201  -- January/February 2022
        ELSE vdt_Id / 100::INTEGER           -- For other months, extract the year and month part
    END
);

	
	-- priority 3 >> MOCN List
	/*
	insert into stg_gci_site
	select globalcellidafter as gci, newsiteid as site_id, UPPER(poc) as gladiator_branch, a.tech, 1::integer as tag, CURRENT_TIMESTAMP()::timestamp as created_dtm 
	from dim_mocn_site_ref a
	left outer join stg_gci_site2 b ON b.gci = a.globalcellidafter 
	where 
	---to_date(execution_start_dt,'yyyy-mm-dd') <= 20220615::text::date and 
	operator <> 'Operator (Network)'
	and b.site_id is null;
	*/
	
	truncate table `data-bi-prd-935c.bi_dm.stg_pcrf_site`;
	truncate table `data-bi-prd-935c.bi_dm.ari_temp_gprs_stg`;
	--truncate table ari_temp_cem_stg;
	truncate table `data-bi-prd-935c.bi_dm.ari_temp_gprs_stg2`;
	truncate table `data-bi-prd-935c.bi_dm.ari_temp_cem_stg2`;
	truncate table `data-bi-prd-935c.bi_dm.stg_ggsn_vlr_1`;
	delete from `data-bi-prd-935c.bi_dm.project_mis_profile_subs_sites` where tag in ('VLR') and load_dt_sk_id = vdt_id;
	
	
	--- 01. STAGE 1 >> DUMP SOURCE DATA
	--- 01.1. gprs/ggsn


	-- insert into ari_temp_gprs_stg(created_dt_sk_id, sbscrptn_msisdn, site_id, calling_cell_id, rat_type, sitefound_flag, usage_mb, session_dur, created_dtm, ggsn_record_close_dtm)
	-- select 
	-- created_dt_sk_id, 
	-- sbscrptn_msisdn, 
	-- site_id,
	-- calling_cell_id, 
	-- rat_type,
	-- case when site.egci is not null then 1 else 0 end as sitefound_flag,
	-- (sum(coalesce(uplink_vol,0)+coalesce(downlink_vol,0))/1024^2)::numeric(12,6) as usage_mb,
	-- sum(session_duration) as session_dur,
	-- CURRENT_TIMESTAMP() as created_dtm,
	-- max(ggsn_record_close_dtm) as max_ggsn_record_close_dtm ---> v1.3.1 Digunakan untuk sorting the latest bisa usage per site sama 
	-- from dwh.gprs_usage_fct_1_prt_:vtgl a
	-- left outer join site_ref_dim site ON a.calling_cell_id = site.egci and mth_sk_id = :vmth
	-- group by 1,2,3,4,5,6; 

INSERT INTO `data-bi-prd-935c.bi_dm.stg_ggsn_vlr_1` (
    created_dt_sk_id, 
    sbscrptn_msisdn, 
    site_id, 
    calling_cell_id, 
    rat_type, 
    sitefound_flag, 
    usage_mb, 
    session_dur, 
    created_dtm, 
    ggsn_record_close_dtm
)
SELECT 
    created_dt_sk_id, 
    sbscrptn_msisdn, 
    NULL AS site_id,
    calling_cell_id, 
    rat_type,
    CAST(NULL AS INT64) AS sitefound_flag,
    CAST(SUM(COALESCE(uplink_vol, 0) + COALESCE(downlink_vol, 0)) / 1024 / 1024 AS NUMERIC) AS usage_mb,
    SUM(session_duration) AS session_dur,
    CURRENT_TIMESTAMP() AS created_dtm,
    MAX(ggsn_record_close_dtm) AS ggsn_record_close_dtm
FROM `data-bi-prd-935c.bi_dm.gprs_usage_fct_1_prt_vdt_id`
GROUP BY created_dt_sk_id, sbscrptn_msisdn, calling_cell_id, rat_type;


	insert into `data-bi-prd-935c.bi_dm.stg_ggsn_vlr_2` (created_dt_sk_id, sbscrptn_msisdn, site_id, calling_cell_id, rat_type, sitefound_flag, usage_mb, session_dur, created_dtm, ggsn_record_close_dtm)
	select 
	a.created_dt_sk_id, 
	a.sbscrptn_msisdn, 
	null ,
	a.calling_cell_id, 
	a.rat_type,
	null::integer as  sitefound_flag,
	(sum(coalesce(a.uplink_vol,0)+coalesce(a.downlink_vol,0))/1024^2)::numeric(12,6) as usage_mb,
	sum(a.session_duration) as session_dur,
	CURRENT_TIMESTAMP() as created_dtm,
	max(a.ggsn_record_close_dtm) as max_ggsn_record_close_dtm ---> v1.3.1 Digunakan untuk sorting the latest bisa usage per site sama 
	from `data-bi-prd-935c.bi_dm.`gprs_usage_fct_1_prt_vdt_id a
	left join stg_ggsn_vlr_1 b on a.sbscrptn_msisdn=b.sbscrptn_msisdn where b.sbscrptn_msisdn is null
	group by 1,2,3,4,5,6;

insert into `data-bi-prd-935c.bi_dm.stg_ggsn_vlr_1`
select * from `data-bi-prd-935c.bi_dm.stg_ggsn_vlr_2`;
select CURRENT_TIMESTAMP() as stg_ggsn_vlr_1;

INSERT INTO `data-bi-prd-935c.bi_dm.ari_temp_gprs_stg` (
    created_dt_sk_id, 
    sbscrptn_msisdn, 
    site_id, 
    calling_cell_id, 
    rat_type, 
    sitefound_flag, 
    usage_mb, 
    session_dur, 
    created_dtm, 
    ggsn_record_close_dtm
)
SELECT 
    a.created_dt_sk_id, 
    a.sbscrptn_msisdn, 
    sites.site_id AS site_id,
    a.calling_cell_id, 
    a.rat_type,
    CASE WHEN sites.egci IS NOT NULL THEN 1 ELSE 0 END AS sitefound_flag,
    a.usage_mb,
    a.session_dur,
    a.created_dtm,
    a.ggsn_record_close_dtm
FROM `data-bi-prd-935c.bi_dm.stg_ggsn_vlr_1` a
LEFT JOIN `data-bi-prd-935c.bi_dm.site_ref_dim` sites 
    ON a.calling_cell_id = sites.egci 
    AND sites.mth_sk_id = <replace_with_vmth>
GROUP BY 
    a.created_dt_sk_id, 
    a.sbscrptn_msisdn, 
    sites.site_id, 
    a.calling_cell_id, 
    a.rat_type, 
    sitefound_flag, 
    a.usage_mb, 
    a.session_dur, 
    a.created_dtm, 
    a.ggsn_record_close_dtm;


select CURRENT_TIMESTAMP() as ari_temp_gprs_stg;

INSERT INTO `data-bi-prd-935c.bi_dm.ari_tmp_cem_stg`
SELECT
    load_dt_sk_id,
    msisdn,
    b.site_id,
    b.system AS system,
    SUM(COALESCE(volume_in, 0) + COALESCE(volume_out, 0)) AS usg,
    MAX(date_sk_id) AS max_date_sk_id  -- digunakan untuk sorting. Pilihan tercepat adalah max instead of rank
FROM 
    `data-bi-prd-935c.dwh.cem_location_pattern_daily_fct_1_prt_` AS a  -- change to D-2 (vtgl2)
JOIN (
    SELECT DISTINCT
        CASE
            -- when system in ('4GNE','4G') then '510-'||substring(egci,5,2)||'-'||tac||'-'||enodebid||'-'||cellnumber
            WHEN system IN ('4GNE', '4G') THEN '510-' || SUBSTRING(egci, 16, 1) || SUBSTRING(egci, 15, 1) || '-' || tac || '-' || enodebid || '-' || cellnumber
            ELSE '510-' || SUBSTRING(egci, 5, 2) || '-' || lac || '-' || ci
        END AS location_id,
        site_id,
        CASE WHEN system IN ('2G', '3G', '4G') THEN system || 'NE' ELSE system END AS system
    FROM 
        `data-bi-prd-935c.bi_dm.site_ref_dim`
    WHERE 
        mth_sk_id = vdt_id
) AS b 
ON a.location = b.location_id
GROUP BY 
    load_dt_sk_id, msisdn, site_id, system;

	
	--- stage 2. Sorting based on System (4G -> 3G -> 2G) and highest usage

select CURRENT_TIMESTAMP() as ari_tmp_cem_stg;

INSERT INTO `data-bi-prd-935c.bi_dm.ari_temp_cem_stg2` (load_dt_sk_id, seqno, msisdn, site_id, system, usage_subs)
SELECT 
    load_dt_sk_id,
    ROW_NUMBER() OVER(
        PARTITION BY msisdn 
        ORDER BY system DESC NULLS LAST, usg DESC NULLS LAST, max_date_sk_id DESC NULLS LAST
    ) AS seqno,
    msisdn,
    site_id,
    system,
    usg AS usage_mb
FROM 
    `data-bi-prd-935c.bi_dm.ari_tmp_cem_stg`
WHERE 
    load_dt_sk_id = vdt_id;

	-- [VLR Site] Staging2 Sorting ggsn

select CURRENT_TIMESTAMP() as ari_temp_cem_stg2;

INSERT INTO `data-bi-prd-935c.bi_dm.ari_temp_gprs_stg2`
SELECT 
    ROW_NUMBER() OVER (
        PARTITION BY sbscrptn_msisdn 
        ORDER BY system DESC, usage DESC, ggsn_record_close_dtm DESC NULLS LAST
    ) AS seqno,  -- v1.3.1 additional sorting
    SUM(usage) OVER (PARTITION BY sbscrptn_msisdn) AS usage_subs,
    created_dt_sk_id,
    sbscrptn_msisdn,
    site_id,
    system,
    usage
FROM (
    SELECT 
        created_dt_sk_id, 
        sbscrptn_msisdn, 
        COALESCE(site_id, calling_cell_id) AS site_id, 
        CASE 
            WHEN COALESCE(rat_type, '-2') = '6' THEN '4GNE'
            WHEN COALESCE(rat_type, '-2') IN ('1', '5') THEN '3GNE'
            WHEN COALESCE(rat_type, '-2') = '2' THEN '2GNE'
            ELSE '-2'
        END AS system,
        SUM(usage_mb) AS usage,
        MAX(ggsn_record_close_dtm) AS ggsn_record_close_dtm  -- v1.3.1
    FROM 
        `data-bi-prd-935c.bi_dm.ari_temp_gprs_stg`
    WHERE 
        sitefound_flag = 1
    GROUP BY 
        created_dt_sk_id, 
        sbscrptn_msisdn, 
        COALESCE(site_id, calling_cell_id),
        CASE 
            WHEN COALESCE(rat_type, '-2') = '6' THEN '4GNE'
            WHEN COALESCE(rat_type, '-2') IN ('1', '5') THEN '3GNE'
            WHEN COALESCE(rat_type, '-2') = '2' THEN '2GNE'
            ELSE '-2'
        END
) a;


select CURRENT_TIMESTAMP() as ari_temp_gprs_stg2;

	--- 02.b Add source PCRF to version 1.2

INSERT INTO `data-bi-prd-935c.bi_dm.stg_pcrf_site`(seqno, edr_dt_sk_id, msisdn, site_id, system, quota_usage_mb, pcrf_created_dtm)
SELECT 
    ROW_NUMBER() OVER (
        PARTITION BY msisdn 
        ORDER BY system DESC NULLS LAST, quota_usage_mb DESC NULLS LAST, pcrf_created_dtm DESC NULLS LAST
    ) AS seqno,
    a.*
FROM (
    SELECT 
        edr_dt_sk_id,
        msisdn,
        site_id,
        system,
        SUM(quota_usage_mb) AS quota_usage_mb,
        MAX(created_dtm) AS pcrf_created_dtm
    FROM (
        SELECT 
            edr_dt_sk_id,
            msisdn,  -- sai, tai, ecgi
            CASE 
                WHEN sai IS NOT NULL THEN 
                    COALESCE(LTRIM(SUBSTR(sai, 6, 5), '0'), '') || '-' || COALESCE(LTRIM(SUBSTR(sai, 11, 5), '0'), '')
                ELSE 
                    COALESCE(LTRIM(SUBSTR(tai, 6, 5), '0'), '') || '-' ||
                    CASE 
                        WHEN LTRIM(SUBSTR(ecgi, 6, 9), '0') = '' THEN '1' 
                        ELSE COALESCE(CAST(FLOOR(CAST(LTRIM(SUBSTR(ecgi, 6, 9), '0') AS INT64) / 256) AS STRING), '') 
                    END || '-' ||
                    CASE 
                        WHEN LTRIM(SUBSTR(ecgi, 6, 9), '0') = '' THEN '1' 
                        ELSE COALESCE(CAST(MOD(CAST(LTRIM(SUBSTR(ecgi, 6, 9), '0') AS INT64), 256) AS STRING), '') 
                    END
            END AS gci_dec,
            (COALESCE(quota_usage, 0) / 1024) AS quota_usage_mb,
            created_dtm
        FROM `data-bi-prd-935c.bi_dm.pcrf_edr_activation_fct_1_prt_` || vdt_id  -- limit 10 -- change to D-2
        WHERE triggertype NOT IN (16, 109, 111) 
            AND mcc_mnc = '51089'  -- and quota_usage > 0
    ) tmp0
    LEFT OUTER JOIN (
        SELECT DISTINCT
            CASE 
                WHEN system IN ('4GNE', '4G') THEN tac || '-' || enodebid || '-' || cellnumber 
                ELSE lac || '-' || ci 
            END AS gci_dec,
            -- *        --> v1.2.1 -- remove due to avoid double counting in usage  
            site_id,     -- v1.2.1
            system       -- v1.2.1
        FROM `data-bi-prd-935c.bi_dm.site_ref_dim`
        WHERE mth_sk_id = cdt_id
    ) site ON tmp0.gci_dec = site.gci_dec
    GROUP BY edr_dt_sk_id, msisdn, site_id, system
) a;


select CURRENT_TIMESTAMP() as stg_pcrf_site;	
	-- [VLR Site] Final Table
	
INSERT INTO `data-bi-prd-935c.bi_dm.fct_vlr_sites` (load_dt_sk_id, siteid_nm, msisdn, cem_system, cem_siteid, cem_usage_mb, ggsn_system, ggsn_siteid, ggsn_usage_mb,
                                                   vlr_system, site_id_vlr, pcrf_system, pcrf_siteid, pcrf_usg_mb, egci, created_dtm)
SELECT 
    load_dt,
    CASE
        -- 01. GGSN as first priority
        WHEN c.system = '4GNE' THEN c.site_id  -- GGSN
        WHEN c.system IN ('3GNE', '2GNE') THEN c.site_id  -- GGSN
        -- 02. CEM as second priority
        WHEN b.system = '4GNE' THEN b.site_id  -- CEM
        -- 03. VLR as third priority
        WHEN d.site_id IS NOT NULL THEN d.site_id  -- VLR (master Cell ID)
        -- 04. PCRF as fourth priority
        WHEN e.system IN ('4GNE', '3GNE', '2GNE') THEN e.site_id  -- version 1.2 --> PCRF
    END AS siteid_nm,
    a.msisdn,
    b.system AS cem_system,
    b.site_id AS cem_siteid,
    (COALESCE(b.usage, 0) / POW(1024, 2)) AS cem_usage_mb, 
    c.system AS ggsn_system,
    c.site_id AS ggsn_siteid,
    c.usage AS ggsn_usage_mb,
    CONCAT(d.tech, 'NE') AS vlr_system,  
    d.site_id AS site_id_vlr,
    e.system AS pcrf_system,
    e.site_id AS pcrf_siteid,
    e.quota_usage_mb AS pcrf_usage_mb,
    a.gci,
    CURRENT_TIMESTAMP() AS created_dtm
FROM `data-bi-prd-935c.bi_dm.fct_vlr_daily_1_prt_` || vdt_id a
LEFT OUTER JOIN (SELECT * FROM `data-bi-prd-935c.bi_dm.ari_temp_cem_stg2` WHERE seqno = 1) b ON a.msisdn = b.msisdn 
LEFT OUTER JOIN (SELECT * FROM `data-bi-prd-935c.bi_dm.ari_temp_gprs_stg2` WHERE seqno = 1) c ON a.msisdn = c.sbscrptn_msisdn
LEFT OUTER JOIN `data-bi-prd-935c.bi_dm.stg_gci_site` d
    ON CONCAT(SUBSTR(a.gci, 1, 3), 'F', SUBSTR(REPLACE(UPPER(a.gci), '-', ''), 4, 16)) = d.gci
LEFT OUTER JOIN (SELECT * FROM `data-bi-prd-935c.bi_dm.stg_pcrf_site` WHERE seqno = 1) e ON a.msisdn = e.msisdn;  -- version 1.2

				
select CURRENT_TIMESTAMP() as fct_vlr_sites;	

--   analyze mis.fct_vlr_sites_1_prt_:vtgl;

select CURRENT_TIMESTAMP() as fct_vlr_sites_analyze;	        
	-- [VLR Site] Aggregate Table
	
-- Inserting data into dm_vlr_sites table
INSERT INTO `data-bi-prd-935c.bi_dm.dm_vlr_sites` (load_dt_sk_id, siteid_nm, vlrsubs, created_dtm)
SELECT 
    load_dt_sk_id, 
    siteid_nm, 
    COUNT(DISTINCT msisdn) AS vlrsubs, 
    CURRENT_TIMESTAMP() AS created_dtm
FROM 
    `data-bi-prd-935c.bi_dm.fct_vlr_sites`
WHERE 
    load_dt_sk_id = :vtgl
GROUP BY 
    load_dt_sk_id, 
    siteid_nm;

-- Deleting data from project_mis_profile_subs_sites with specific conditions
DELETE FROM `data-bi-prd-935c.mis.project_mis_profile_subs_sites`
WHERE 
    load_dt_sk_id = vdt_id
    AND tag = 'VLR';

-- Inserting data into project_mis_profile_subs_sites table
INSERT INTO `data-bi-prd-935c.mis.project_mis_profile_subs_sites` (load_dt_sk_id, site_id, tag, amount, uom, created_dt)
SELECT 
    load_dt_sk_id AS dt,
    siteid_nm AS site_id,
    'VLR' AS tag,
    COUNT(DISTINCT msisdn) AS amount,
    'units' AS uom,
    CURRENT_TIMESTAMP() AS created_dt
FROM 
    `data-bi-prd-935c.bi_dm.fct_vlr_sites`
WHERE 
    load_dt_sk_id = vdt_id
GROUP BY 
    load_dt_sk_id, 
    siteid_nm;


	select CURRENT_TIMESTAMP() as finish_time;
 