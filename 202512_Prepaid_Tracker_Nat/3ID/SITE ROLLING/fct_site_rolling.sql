 DECLARE vdt_id DATE DEFAULT @vdt_id;

 drop table if exists `data-bi-prd-935c.bi_stg.stg_ioh_daily_base_ggsn_site`;

 CREATE TABLE `data-bi-prd-935c.bi_stg.stg_ioh_daily_base_ggsn_site` AS
 select created_dt_sk_id,sbscrptn_ek_id,site_id,usage,calling_cell_id
 from `data-dtptechm-prd-c7ca.dwh.ioh_daily_base_ggsn_site`
 WHERE CAST(created_dt_sk_id AS DATE) = vdt_id;

	 
delete from `data-bi-prd-935c.bi_mart.dm_usage_subs_site` where cast(created_dt_sk_id as date)= vdt_id;
INSERT INTO `data-bi-prd-935c.bi_mart.dm_usage_subs_site`
WITH site_ref_filtered AS (
  SELECT DISTINCT 
    UPPER(c.egci) AS egci, 
    c.site_id, 
    UPPER(c.gladiator_branch) AS gladiator_branch
  FROM `data-bi-prd-935c.bi_mart.site_ref_dim` c
  WHERE mth_sk_id >= DATE_TRUNC(DATE_SUB(vdt_id, INTERVAL 1 MONTH), MONTH)
    AND mth_sk_id <= vdt_id
),
filtered_base AS (
  SELECT * FROM `data-bi-prd-935c.bi_stg.stg_ioh_daily_base_ggsn_site`
  --FROM `data-dtptechm-prd-c7ca.dwh.ioh_daily_base_ggsn_site`
  --WHERE CAST(created_dt_sk_id AS DATE) = vdt_id
),
joined_data AS (
  SELECT 
    CAST(a.created_dt_sk_id AS DATE) AS created_dt,
    a.sbscrptn_ek_id,
    COALESCE(d.newsiteid, b.site_id, a.site_id) AS site_id,
    a.usage
  FROM filtered_base a
  LEFT JOIN site_ref_filtered b 
    ON UPPER(a.calling_cell_id) = b.egci
  LEFT JOIN `data-bi-prd-935c.bi_mart.dim_mocn_site_ref` d 
    ON a.calling_cell_id = d.globalcellidafter
)
SELECT 
  created_dt AS created_dt_sk_id,
  sbscrptn_ek_id,
  site_id,
  SUM(usage) / (1024 * 1024) AS usage
FROM joined_data
GROUP BY 1, 2, 3;

			
			delete from `data-bi-prd-935c.bi_mart.dm_project_data_site_dly` where created_dt_sk_id=vdt_id;
			insert into `data-bi-prd-935c.bi_mart.dm_project_data_site_dly`
			select
			cast(created_dt_sk_id as date) created_dt_sk_id,
			cast(sbscrptn_ek_id as string) sbscrptn_ek_id,
			site_id
			from
			(select 
			created_dt_sk_id,
			sbscrptn_ek_id,
			site_id,
			rank() over(partition by sbscrptn_ek_id order by usage desc, site_id desc) as rank_id
			from 
			(select 
			cast(vdt_id as date) as created_dt_sk_id,
			coalesce(d.newsiteid,b.site_id,a.site_id) as site_id,
			sbscrptn_ek_id,
			sum(usage) as usage
			--from `data-dtptechm-prd-c7ca.dwh.ioh_daily_base_ggsn_site` a
			from `data-bi-prd-935c.bi_stg.stg_ioh_daily_base_ggsn_site` a
			left outer join (select distinct UPPER(c.egci) egci, c.site_id, UPPER(c.gladiator_branch) from `data-bi-prd-935c.bi_mart.site_ref_dim` c where mth_sk_id>=date_trunc(date_sub(vdt_id,interval 1 month),month) and mth_sk_id<=vdt_id
			) b ON b.egci = a.calling_cell_id
			left outer join `data-bi-prd-935c.bi_mart.dim_mocn_site_ref` d ON a.calling_cell_id = d.globalcellidafter --- ini sitelist mocn
			where cast(created_dt_sk_id as date)= vdt_id
			--and flag_found = 1
			group by 1,2,3) q)w
			where rank_id = 1;

      	drop table if exists`data-bi-prd-935c.bi_stg.stg_usage_30_90` ;
	
CREATE TABLE `data-bi-prd-935c.bi_stg.stg_usage_30_90` AS
	select 
	cast(vdt_id as date) as dt,
	site_id,
	sbscrptn_ek_id,
	sum(usage_mb) as usage_mb_90,
	sum(case when created_dt_sk_id between date_sub(vdt_id,interval 29 day) and vdt_id then usage_mb else 0 end) as usage_mb_30
	from `data-bi-prd-935c.bi_mart.dm_usage_subs_site` 
	where created_dt_sk_id between date_sub(vdt_id,interval 89 day) and vdt_id
	and site_id is not null
	group by site_id,sbscrptn_ek_id;

-- WITH base_date AS (
--   SELECT  cast(vdt_id as date) AS target_date
-- ),
-- filtered_usage AS (
--   SELECT
--     created_dt_sk_id,
--     site_id,
--     sbscrptn_ek_id,
--     usage_mb
--   FROM `data-bi-prd-935c.bi_mart.dm_usage_subs_site`,
--       base_date
--   WHERE created_dt_sk_id BETWEEN DATE_SUB(target_date, INTERVAL 89 DAY) AND target_date
--     AND site_id IS NOT NULL
-- )
-- SELECT
--   (SELECT target_date FROM base_date) AS dt,
--   site_id,
--   sbscrptn_ek_id,
--   SUM(usage_mb) AS usage_mb_90,
--   SUM(
--     CASE 
--       WHEN created_dt_sk_id BETWEEN DATE_SUB((SELECT target_date FROM base_date), INTERVAL 29 DAY)
--                                 AND (SELECT target_date FROM base_date)
--       THEN usage_mb 
--       ELSE 0 
--     END
--   ) AS usage_mb_30
-- FROM filtered_usage
-- GROUP BY site_id, sbscrptn_ek_id;-- Tuning 21 TB



	drop table if exists `data-bi-prd-935c.bi_stg.usg_30`;
	
			create table `data-bi-prd-935c.bi_stg.usg_30` as
			select 
			row_number()over(partition by sbscrptn_ek_id order by usage_mb_30 desc, site_id) as seqno,
			a.*
			from `data-bi-prd-935c.bi_stg.stg_usage_30_90` a
			where usage_mb_30 > 0;	

	delete from `data-bi-prd-935c.bi_mart.dm_project_data_site_30` where cast(created_dt_sk_id as date)=vdt_id;
	insert into `data-bi-prd-935c.bi_mart.dm_project_data_site_30`
	SELECT
	cast(dt as date) as created_dt_sk_id,
	cast(sbscrptn_ek_id as string) as sbscrptn_ek_id,
	site_id
	FROM `data-bi-prd-935c.bi_stg.usg_30`
	WHERE seqno = 1;


	drop table if exists `data-bi-prd-935c.bi_stg.usg_90`;
	
			create table `data-bi-prd-935c.bi_stg.usg_90` as
			select 
			row_number()over(partition by sbscrptn_ek_id order by usage_mb_30 desc, site_id) as seqno,
			a.*
			from `data-bi-prd-935c.bi_stg.stg_usage_30_90` a
			where usage_mb_90 > 0;


delete from `data-bi-prd-935c.bi_mart.dm_project_data_site_90` where cast(created_dt_sk_id as date) =vdt_id;
	insert into `data-bi-prd-935c.bi_mart.dm_project_data_site_90`
	SELECT
	cast(dt as date) as created_dt_sk_id,
	cast(sbscrptn_ek_id as string),
	site_id
	FROM `data-bi-prd-935c.bi_stg.usg_90` a
	WHERE seqno = 1;


--========= CHAIN 2

	delete from `data-bi-prd-935c.bi_mart.project_merged_voice_usg_dly` where cast(dt_sk_id as date) =vdt_id;
	INSERT INTO `data-bi-prd-935c.bi_mart.project_merged_voice_usg_dly` 
	SELECT 
	cast(charge_start_dt_sk_id as date) as dt_sk_id,
	--coalesce(d.globalcellidafter,b.site_id,calling_cell_id) as site_id,
	coalesce(d.newsiteid,b.site_id) as site_id,
	a.sbscrptn_msisdn,
	cast(sd.sbscrptn_ek_id as string),
	case when b.egci is not null or d.globalcellidafter is not null then 1 else 0 end flag_found,
	sum(usage_dur) as usage,
	current_timestamp()
	FROM `data-dtptechm-prd-c7ca.dwh.charged_event_fct` a
	left outer join (select distinct UPPER(c.egci) egci, c.site_id from `data-bi-prd-935c.bi_mart.site_ref_dim` c  where mth_sk_id>=date_trunc(date_sub(vdt_id,interval 1 month),month) and mth_sk_id<=vdt_id
	) b ON b.egci = a.calling_cell_id
	left outer join `data-bi-prd-935c.bi_mart.dim_mocn_site_ref` d ON a.calling_cell_id = d.globalcellidafter --- ini sitelist mocn
	left join `data-dtptechm-prd-c7ca.dwh.sbscrptn_dim` sd on a.sbscrptn_sk_id = sd.sbscrptn_sk_id and sd.rank_ind=1 
	where cast(record_end_dtm as date)<='9999-12-31' and cast(charge_start_dt_sk_id as date) =vdt_id --between 20210901 and 20220131 --20230204 
	and acct_type_cd = 'MAIN'
	and usage_dur > 0
	group by 1,2,3,4,5;
 
 delete from `data-bi-prd-935c.bi_mart.project_merged_voice_usg_dly_2` where cast(dt_sk_id as date)=vdt_id;
	insert into `data-bi-prd-935c.bi_mart.project_merged_voice_usg_dly_2`
	select
	dt_sk_id,
	site_id,
	sbscrptn_msisdn,
	sbscrptn_ek_id,
	1,
	cast(usage as numeric)
	,current_timestamp()
	from
	(

		select
		dt_sk_id,
		sbscrptn_msisdn,
		sbscrptn_ek_id,
		site_id,
		usage,
		rank() over(partition by dt_sk_id,sbscrptn_ek_id order by usage desc, site_id desc) as rank_id
		from 
		(
		select dt_sk_id,
		site_id,
		sbscrptn_ek_id,
		sbscrptn_msisdn,
		sum(usage) as usage
		 from 
		`data-bi-prd-935c.bi_mart.project_merged_voice_usg_dly`
	where cast(dt_sk_id as date)=vdt_id
		group by 1,2,3,4
	)
	q) w
	where rank_id = 1;
	
	  delete from `data-bi-prd-935c.bi_mart.project_merged_voice_usg_30` where cast(dt_sk_id as date) =vdt_id;
	
	INSERT INTO `data-bi-prd-935c.bi_mart.project_merged_voice_usg_30` 
	select
	cast(dt_sk_id as date),
	site_id,
	sbscrptn_msisdn,
	sbscrptn_ek_id,
	1,
	cast(usage as numeric)
	,current_timestamp()
	from
	(select
	dt_sk_id,
	sbscrptn_msisdn,
	sbscrptn_ek_id,
	site_id,
	usage,
	rank() over(partition by sbscrptn_ek_id order by usage desc, site_id desc) as rank_id
	from
	(select 
	cast(vdt_id as date) as dt_sk_id,
	site_id,
	sbscrptn_ek_id,
	sbscrptn_msisdn,
	sum(usage) as usage
	from `data-bi-prd-935c.bi_mart.project_merged_voice_usg_dly` 
	where cast(dt_sk_id as date) between date_sub(vdt_id,interval 29 day)
	and vdt_id
	and flag_found = 1
	group by 1,2,3,4) q) w
	where rank_id = 1;


 delete from `data-bi-prd-935c.bi_mart.project_merged_voice_usg_90` where cast(dt_sk_id as date)=vdt_id;
	
	INSERT INTO `data-bi-prd-935c.bi_mart.project_merged_voice_usg_90` 
	select
	cast(dt_sk_id as date),
	site_id,
	sbscrptn_msisdn,
	sbscrptn_ek_id,
	1,
	cast(usage as numeric)
	,current_timestamp()
	from
	(select
	dt_sk_id,
	sbscrptn_msisdn,
	sbscrptn_ek_id,
	site_id,
	usage,
	rank() over(partition by sbscrptn_ek_id order by usage desc, site_id desc) as rank_id
	from
	(select 
	cast(vdt_id as date) as dt_sk_id,
	site_id,
	sbscrptn_ek_id,
	sbscrptn_msisdn,
	sum(usage) as usage
	from `data-bi-prd-935c.bi_mart.project_merged_voice_usg_dly`
	where cast(dt_sk_id as date) between date_sub(vdt_id,interval 89 day)
	and vdt_id
	and flag_found = 1
	group by 1,2,3,4) q) w
	where rank_id = 1;


	DROP TABLE IF EXISTS `data-bi-prd-935c.bi_stg.vlr_stgdly`;

	create table `data-bi-prd-935c.bi_stg.vlr_stgdly` as
	select load_dt, msisdn sbscrptn_msisdn, '510F89'||UPPER(substring(replace(trim(a.gci),'-',''),6,30)) gci
	from `data-bi-prd-935c.bi_mart.fct_vlr_daily` a 
	where load_Dt between date_sub(vdt_id,interval 29 day) and vdt_id
	and gci <> '51089--';

	delete from `data-bi-prd-935c.bi_mart.project_vlr_subs_dly` where cast(dt_sk_id as date)=vdt_id;
	INSERT INTO `data-bi-prd-935c.bi_mart.project_vlr_subs_dly`
	select dt_sk_id, sbscrptn_msisdn, site_id, nod,null
	FROM 
	(
	select 
	row_number()over(partition by sbscrptn_msisdn order by nod desc) as seqno,
	*
	FROM
		(
			select 
			cast(vdt_id as date) as dt_sk_id,
			coalesce(b.newsiteid,b1.site_id) as site_id,
			sbscrptn_msisdn,
			count(distinct load_dt) as nod
			from `data-bi-prd-935c.bi_stg.vlr_stgdly` a 
		left outer join (select egci,site_id from `data-bi-prd-935c.bi_mart.site_ref_dim`  where mth_sk_id>=date_trunc(date_sub(vdt_id,interval 1 month),month) and mth_sk_id<=vdt_id) b1 ON a.gci = b1.egci
		left outer join `data-bi-prd-935c.bi_mart.dim_mocn_site_ref` b ON a.gci = b.globalcellidafter 
			where cast(load_Dt as date) = vdt_id
			group by 1,2,3
		) a
	) aa
	where seqno = 1;


 drop table if exists `data-bi-prd-935c.bi_stg.vlr_stg30`;
	create table `data-bi-prd-935c.bi_stg.vlr_stg30` as
	select load_dt,sbscrptn_msisdn,gci from 
	(
	select load_dt, msisdn sbscrptn_msisdn, '510F89'||UPPER(substring(replace(trim(a.gci),'-',''),6,30)) gci
	,row_number() over (partition by msisdn order by load_dt desc) as seqno  
	from `data-bi-prd-935c.bi_mart.fct_vlr_daily` a 
	where cast(load_Dt as date) between date_sub(vdt_id,interval 29 day) and vdt_id
	and gci <> '51089--'
	) x where seqno=1;



	delete from `data-bi-prd-935c.bi_mart.project_vlr_subs_30` where cast(dt_sk_id as date) = vdt_id;
	INSERT INTO `data-bi-prd-935c.bi_mart.project_vlr_subs_30`
	select dt_sk_id, sbscrptn_msisdn, site_id, nod,null
	FROM 
	(
	select 
	row_number()over(partition by sbscrptn_msisdn order by nod desc) as seqno,
	*
	FROM
		(
			select 
			 cast(vdt_id as date) dt_sk_id,
			coalesce(b.newsiteid,b1.site_id) as site_id,
			sbscrptn_msisdn,
			cast(count(distinct load_dt) as string) as nod
			from `data-bi-prd-935c.bi_stg.vlr_stg30` a 
		left outer join (Select site_id,egci from `data-bi-prd-935c.bi_mart.site_ref_dim` where mth_sk_id>=date_trunc(date_sub(vdt_id,interval 1 month),month) and mth_sk_id<=vdt_id) b1 ON a.gci = b1.egci
		left outer join `data-bi-prd-935c.bi_mart.dim_mocn_site_ref` b ON a.gci = b.globalcellidafter 
			where cast(load_Dt as date) between date_sub(vdt_id,interval 29 day) and vdt_id
			group by 1,2,3
		) a
	) aa
	where seqno = 1;

	
	DROP TABLE IF EXISTS `data-bi-prd-935c.bi_stg.vlr_stg90`;
	

	
	create table `data-bi-prd-935c.bi_stg.vlr_stg90` as
	select load_dt,sbscrptn_msisdn,gci from 
	(
	select load_dt, msisdn sbscrptn_msisdn, '510F89'||UPPER(substring(replace(trim(a.gci),'-',''),6,30)) gci
	,row_number() over (partition by msisdn order by load_dt desc) as seqno  
	from `data-bi-prd-935c.bi_mart.fct_vlr_daily` a 
	where load_Dt between date_sub(vdt_id,interval 89 day) and vdt_id
	and gci <> '51089--'
	) x where seqno=1;


 delete from `data-bi-prd-935c.bi_mart.project_vlr_subs_90` where cast(dt_sk_id as date) = vdt_id;
	INSERT INTO `data-bi-prd-935c.bi_mart.project_vlr_subs_90`
	select dt_sk_id, sbscrptn_msisdn, site_id, cast(nod as string),null
	FROM 
	(
	select 
	row_number()over(partition by sbscrptn_msisdn order by nod desc) as seqno,
	*
	FROM
		(
			select 
			 cast(vdt_id as date) as dt_sk_id,
			coalesce(b.newsiteid,b1.site_id) as site_id,
			sbscrptn_msisdn,
			count(distinct load_dt) as nod
			from `data-bi-prd-935c.bi_stg.vlr_stg90` a 
		left outer join (select egci,site_id from `data-bi-prd-935c.bi_mart.site_ref_dim` where mth_sk_id>=date_trunc(date_sub(vdt_id,interval 1 month),month) and mth_sk_id<=vdt_id) b1 ON a.gci = b1.egci
		left outer join `data-bi-prd-935c.bi_mart.dim_mocn_site_ref` b ON a.gci = b.globalcellidafter 
			where load_Dt between date_sub(vdt_id,Interval 89 day) and vdt_id
			group by 1,2,3
		) a
	) aa
	where seqno = 1;
	

--========= CHAIN 3

	DROP TABLE IF EXISTS `data-bi-prd-935c.bi_stg.list_subs_fu`;
	DROP TABLE IF EXISTS `data-bi-prd-935c.bi_stg.list_subs_nonfu`;

	create table `data-bi-prd-935c.bi_stg.list_subs_fu` as
 select
 cast(vdt_id as date) as dt,
 cast(sbscrptn_ek_id as string) as sbscrptn_ek_id,
 sbscrptn_msisdn,
 (
    SELECT MIN(d)
    FROM UNNEST([
      cast(first_usage_dt as date),
      safe.parse_date('%Y%m%d',cast(first_billing_usage_dt_sk_id as string)),
      cast(any_event_first_usage_date as date)
    ]) AS d
    WHERE d IS NOT NULL
  ) as fu_dt,
 --LEAST(cast(sd.first_usage_dt as date), parse_date('%Y%m%d',cast(sd.first_billing_usage_dt_sk_id as string)),cast(sd.any_event_first_usage_date as date)) as fu_dt,
 cast(activation_dtm as date) activation_dtm,
 cast(termination_dtm as date) termination_dtm,
 angie_retailer_name,
 angie_channel_sk_id
 from `data-dtptechm-prd-c7ca.dwh.sbscrptn_attribs` sd
 where cast(activation_dtm as date) <= vdt_id 
 and cast(termination_dtm as date) > vdt_id 
				and cast(sd.sbscrptn_ek_id as string) <>'1113974097'
 --and LEAST(cast(sd.first_usage_dt as date), parse_date('%Y%m%d',cast(sd.first_billing_usage_dt_sk_id as string)),cast(sd.any_event_first_usage_date as date)) 
 and (
    SELECT MIN(d)
    FROM UNNEST([
      cast(first_usage_dt as date),
      safe.parse_date('%Y%m%d',cast(first_billing_usage_dt_sk_id as string)),
      cast(any_event_first_usage_date as date)
    ]) AS d
    WHERE d IS NOT NULL
  )
 between date_trunc(vdt_id,MONTH) and vdt_id;

create table `data-bi-prd-935c.bi_stg.list_subs_nonfu` as
 with subs as (select * from `data-dtptechm-prd-c7ca.dwh.sbscrptn_attribs`)
 select
 cast(vdt_id as date) as dt,
cast(sd.sbscrptn_ek_id as string) as sbscrptn_ek_id,
 sd.sbscrptn_msisdn,
 --LEAST(cast(sd.first_usage_dt as date), parse_date('%Y%m%d',cast(sd.first_billing_usage_dt_sk_id as string)),cast(sd.any_event_first_usage_date as date)) as fu_dt,
 (
    SELECT MIN(d)
    FROM UNNEST([
      cast(sd.first_usage_dt as date),
      safe.parse_date('%Y%m%d',cast(sd.first_billing_usage_dt_sk_id as string)),
      cast(sd.any_event_first_usage_date as date)
    ]) AS d
    WHERE d IS NOT NULL
  ) as fu_dt,
 cast(sd.activation_dtm as date) activation_dtm,
 cast(sd.termination_dtm as date) termination_dtm,
 sd.angie_retailer_name,
 sd.angie_channel_sk_id
 from subs sd
 left outer join `data-bi-prd-935c.bi_stg.list_subs_fu` fu ON cast(sd.sbscrptn_ek_id as string)= cast(fu.sbscrptn_ek_id as string) 
 where cast(sd.activation_dtm as date) <= vdt_id
 and cast(sd.termination_dtm as date) > vdt_id 
 and fu.sbscrptn_ek_id is null
and cast(sd.sbscrptn_ek_id as string) <>'1113974097';
	

 delete from `data-bi-prd-935c.bi_mart.ioh_subscriber_site_attribs_rolling` where dt=vdt_id;
	insert into `data-bi-prd-935c.bi_mart.ioh_subscriber_site_attribs_rolling`
 select 
 cast(vdt_id as date) as dt,
 ls.sbscrptn_ek_id,
 ls.sbscrptn_msisdn,
 ls.activation_dtm,
 ls.termination_dtm,
 ls.angie_retailer_name,

		case when fu_dt=vdt_id then 
						case when length(coalesce(dt.site_id, vc.site_id, vl.site_id,qr.site_retailer,e.site_id))<6 then LPAD(coalesce(dt.site_id, vc.site_id, vl.site_id,qr.site_retailer,e.site_id),6,'0') 
						else coalesce(dt.site_id, vc.site_id, vl.site_id,qr.site_retailer,e.site_id) end	
		else '' end as site_id_fu ,		
 case when length(coalesce(dt3.site_id, vc3.site_id, vl3.site_id,qr.site_retailer,e.site_id) )<6 then LPAD(coalesce(dt3.site_id, vc3.site_id, vl3.site_id,qr.site_retailer,e.site_id),6,'0') else coalesce(dt3.site_id, vc3.site_id, vl3.site_id,qr.site_retailer,e.site_id) end as site_id_30,
 case when length(coalesce(dt2.site_id, vc2.site_id, vl2.site_id,qr.site_retailer,e.site_id) )<6 then LPAD(coalesce(dt2.site_id, vc2.site_id, vl2.site_id,qr.site_retailer,e.site_id),6,'0') else coalesce(dt2.site_id, vc2.site_id, vl2.site_id,qr.site_retailer,e.site_id) end as site_id_90,
 case when length(coalesce(dt4.site_id, vc4.site_id, vl4.site_id,qr.site_retailer,e.site_id) )<6 then LPAD(coalesce(dt4.site_id, vc4.site_id, vl4.site_id,qr.site_retailer,e.site_id),6,'0') else coalesce(dt4.site_id, vc4.site_id, vl4.site_id,qr.site_retailer,e.site_id) end as site_id_dly

 from `data-bi-prd-935c.bi_stg.list_subs_fu` ls
 left join `data-bi-prd-935c.bi_mart.dm_project_data_site_dly` dt on cast(ls.sbscrptn_ek_id as string) = cast(dt.sbscrptn_ek_id as string) and fu_dt=dt.created_Dt_sk_id
 left join `data-bi-prd-935c.bi_mart.project_merged_voice_usg_dly_2` vc on cast(ls.sbscrptn_ek_id as string) = cast(vc.sbscrptn_ek_id as string) and fu_dt=vc.Dt_sk_id
 left join `data-bi-prd-935c.bi_mart.project_vlr_subs_dly` vl on ls.sbscrptn_msisdn = vl.sbscrptn_msisdn and fu_dt=vl.Dt_sk_id

 left join `data-bi-prd-935c.bi_mart.dm_project_data_site_30` dt3 on cast(ls.sbscrptn_ek_id as string)= cast(dt3.sbscrptn_ek_id as string) and ls.dt=dt3.created_Dt_sk_id
 left join `data-bi-prd-935c.bi_mart.project_merged_voice_usg_30` vc3 on cast(ls.sbscrptn_ek_id as string)= cast(vc3.sbscrptn_ek_id as string) and ls.dt=vc3.Dt_sk_id
 left join `data-bi-prd-935c.bi_mart.project_vlr_subs_30` vl3 on cast(ls.sbscrptn_msisdn as string) = cast(vl3.sbscrptn_msisdn as string) and ls.dt=vl3.Dt_sk_id

 left join `data-bi-prd-935c.bi_mart.dm_project_data_site_90` dt2 on cast(ls.sbscrptn_ek_id as string) = cast(dt2.sbscrptn_ek_id as string) and ls.dt=dt2.created_Dt_sk_id
 left join `data-bi-prd-935c.bi_mart.project_merged_voice_usg_90` vc2 on cast(ls.sbscrptn_ek_id as string)= cast(vc2.sbscrptn_ek_id as string) and ls.dt=vc2.Dt_sk_id
 left join `data-bi-prd-935c.bi_mart.project_vlr_subs_90` vl2 on cast(ls.sbscrptn_msisdn as string) = cast(vl2.sbscrptn_msisdn as string) and ls.dt=vl2.Dt_sk_id

 left join `data-bi-prd-935c.bi_mart.dm_project_data_site_dly` dt4 on cast(ls.sbscrptn_ek_id as string)= cast(dt4.sbscrptn_ek_id as string) and ls.dt=dt4.created_Dt_sk_id
 left join `data-bi-prd-935c.bi_mart.project_merged_voice_usg_dly_2` vc4 on cast(ls.sbscrptn_ek_id as string) = cast(vc4.sbscrptn_ek_id as string) and ls.dt=vc4.Dt_sk_id
 left join `data-bi-prd-935c.bi_mart.project_vlr_subs_dly` vl4 on cast(ls.sbscrptn_msisdn as string) = cast(vl4.sbscrptn_msisdn as string) and ls.dt=vl4.Dt_sk_id

 left outer join (select distinct ret_qr_cd, case when length(site_id) <6 then LPAD(site_id,6,'0') else site_id end site_retailer from `data-dtptechm-prd-c7ca.stg.stg_v_map_tgt_ret_details`) qr ON qr.ret_qr_cd = ls.angie_retailer_name 
 
  left join `data-bi-prd-935c.bi_mart.param_site_qr_mc_v2` e on ls.angie_retailer_name=e.qr_code;

CREATE OR REPLACE TABLE `data-bi-prd-935c.bi_stg.site_ndb` AS
	SELECT ret_qr_cd as qr_code,site_id FROM (
	SELECT
	vdt_id AS dt,
	ret_msisdn,
	ret_qr_cd,
	site_id,
	distance,
	load_id,
	ROW_NUMBER() OVER (PARTITION BY ret_qr_cd ORDER BY dt DESC) AS rnk
	FROM `data-bi-prd-935c.bi_mart.stg_v_map_tgt_ret_details_hist`
	WHERE dt <= vdt_id
	) a
	WHERE rnk = 1;


			  
	insert into `data-bi-prd-935c.bi_mart.ioh_subscriber_site_attribs_rolling` 
 select 
 cast(vdt_id as date) as dt,
 cast(ls.sbscrptn_ek_id as string),
 ls.sbscrptn_msisdn,
 ls.activation_dtm,
 ls.termination_dtm,
 ls.angie_retailer_name,
 coalesce('') as site_id_fu,
 case when length(coalesce(dt.site_id, vc.site_id, vl.site_id,qr.site_retailer,e.site_id) )<6 then LPAD(coalesce(dt.site_id, vc.site_id, vl.site_id,qr.site_retailer,e.site_id),6,'0') else coalesce(dt.site_id, vc.site_id, vl.site_id,qr.site_retailer,e.site_id) end as site_id_30,
 case when length(coalesce(dt2.site_id, vc2.site_id, vl2.site_id,qr.site_retailer,e.site_id) )<6 then LPAD(coalesce(dt2.site_id, vc2.site_id, vl2.site_id,qr.site_retailer,e.site_id),6,'0') else coalesce(dt2.site_id, vc2.site_id, vl2.site_id,qr.site_retailer,e.site_id) end as site_id_90,
		case when length(coalesce(dt3.site_id, vc3.site_id, vl3.site_id,qr.site_retailer,e.site_id) )<6 then LPAD(coalesce(dt3.site_id, vc3.site_id, vl3.site_id,qr.site_retailer,e.site_id),6,'0') else coalesce(dt3.site_id, vc3.site_id, vl3.site_id,qr.site_retailer,e.site_id) end as site_id_dly
 from `data-bi-prd-935c.bi_stg.list_subs_nonfu` ls
 left join `data-bi-prd-935c.bi_mart.dm_project_data_site_30` dt on cast(ls.sbscrptn_ek_Id as string) = cast(dt.sbscrptn_ek_Id as string) and ls.dt=dt.created_Dt_sk_id
 left join `data-bi-prd-935c.bi_mart.project_merged_voice_usg_30` vc on cast(ls.sbscrptn_ek_Id as string)= cast(vc.sbscrptn_ek_Id as string) and ls.dt=vc.Dt_sk_id
 left join `data-bi-prd-935c.bi_mart.project_vlr_subs_30` vl on cast(ls.sbscrptn_msisdn as string)= cast(vl.sbscrptn_msisdn as string) and ls.dt=vl.Dt_sk_id
 left join `data-bi-prd-935c.bi_mart.dm_project_data_site_90` dt2 on cast(ls.sbscrptn_ek_Id as string) = cast(dt2.sbscrptn_ek_Id as string) and ls.dt=dt2.created_Dt_sk_id
 left join `data-bi-prd-935c.bi_mart.project_merged_voice_usg_90` vc2 on cast(ls.sbscrptn_ek_Id as string)= cast(vc2.sbscrptn_ek_Id as string) and ls.dt=vc2.Dt_sk_id
 left join `data-bi-prd-935c.bi_mart.project_vlr_subs_90` vl2 on cast(ls.sbscrptn_msisdn as string) = cast(vl2.sbscrptn_msisdn as string) and ls.dt=vl2.Dt_sk_id

 left join `data-bi-prd-935c.bi_mart.dm_project_data_site_dly` dt3 on cast(ls.sbscrptn_ek_id as string) = cast(dt3.sbscrptn_ek_id as string) and ls.dt=dt3.created_Dt_sk_id
 left join `data-bi-prd-935c.bi_mart.project_merged_voice_usg_dly_2` vc3 on cast(ls.sbscrptn_ek_id as string)= cast(vc3.sbscrptn_ek_id as string) and ls.dt=vc3.Dt_sk_id
 left join `data-bi-prd-935c.bi_mart.project_vlr_subs_dly` vl3 on cast(ls.sbscrptn_msisdn as string) = cast(vl3.sbscrptn_msisdn as string) and fu_dt=vl3.Dt_sk_id

 left outer join (select distinct ret_qr_cd, case when length(site_id) <6 then LPAD(site_id,6,'0') else site_id end site_retailer from `data-dtptechm-prd-c7ca.stg.stg_v_map_tgt_ret_details`) qr ON qr.ret_qr_cd = ls.angie_retailer_name 
 left join `data-bi-prd-935c.bi_stg.site_ndb` e on ls.angie_retailer_name=e.qr_code;


    