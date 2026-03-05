 DECLARE vdt_id DATE DEFAULT @vdt_id;

   drop table if exists `data-bi-prd-935c.bi_stg.stg_gci_site`;
  create table `data-bi-prd-935c.bi_stg.stg_gci_site` as
	select distinct c.egci, c.site_id, UPPER(c.gladiator_branch) as gladiator_branch, substring(c.system,1,2) as g_type, '3' as tag,  current_timestamp() as created_dtm 
	from `data-bi-prd-935c.bi_mart.site_ref_dim` c 
	where mth_sk_id = date_trunc(vdt_id,Month)
	;
	

  drop table if exists `data-bi-prd-935c.bi_stg.stg_ggsn_vlr_1`;
  create table `data-bi-prd-935c.bi_stg.stg_ggsn_vlr_1` as
	select 
	cast(created_dt_sk_id as date) as created_dt_sk_id, 
	sbscrptn_msisdn, 
	cast(null as string) as site_id ,
	calling_cell_id, 
	rat_type,
	cast(null as integer) as  sitefound_flag,
	cast((sum(coalesce(uplink_vol,0)+coalesce(downlink_vol,0))/(1024*1024))as numeric) as usage_mb,
	sum(session_duration) as session_dur,
	current_timestamp() as created_dtm,
	max(ggsn_record_close_dtm) as ggsn_record_close_dtm ---> v1.3.1 Digunakan untuk sorting the latest bisa usage per site sama 
	from `data-dtptechm-prd-c7ca.dwh.gprs_usage_fct` where created_dt_sk_id = vdt_id
	group by 1,2,3,4,5,6;

	drop table if exists `data-bi-prd-935c.bi_stg.stg_ggsn_vlr_2`;
  	create table `data-bi-prd-935c.bi_stg.stg_ggsn_vlr_2` as
	select 
	cast(a.created_dt_sk_id as date) as created_dt_sk_id, 
	a.sbscrptn_msisdn, 
	cast(null as string) as site_id ,
	a.calling_cell_id, 
	a.rat_type,
	cast(null as integer) as  sitefound_flag,
	cast((sum(coalesce(uplink_vol,0)+coalesce(downlink_vol,0))/(1024*1024))as numeric) as usage_mb,
	sum(a.session_duration) as session_dur,
	current_timestamp() as created_dtm,
	max(a.ggsn_record_close_dtm) as ggsn_record_close_dtm ---> v1.3.1 Digunakan untuk sorting the latest bisa usage per site sama 
	from (select * from `data-dtptechm-prd-c7ca.dwh.gprs_usage_fct` a where a.created_dt_sk_id = date_sub(vdt_id,interval 1 day)) a
	left join `data-bi-prd-935c.bi_stg.stg_ggsn_vlr_1` b on a.sbscrptn_msisdn=b.sbscrptn_msisdn where b.sbscrptn_msisdn is null
	group by 1,2,3,4,5,6;

	insert into `data-bi-prd-935c.bi_stg.stg_ggsn_vlr_1`
	select * from `data-bi-prd-935c.bi_stg.stg_ggsn_vlr_2`;

	

 /* insert into `data-bi-prd-935c.bi_mart.stg_ggsn_vlr_2`
	select 
	cast(a.created_dt_sk_id as date) as created_dt_sk_id, 
	a.sbscrptn_msisdn, 
	cast(null as string) as site_id ,
	a.calling_cell_id, 
	a.rat_type,
	cast(null as string) as  sitefound_flag,
	cast((sum(coalesce(uplink_vol,0)+coalesce(downlink_vol,0))/(1024*1024))as numeric) as usage_mb,
	cast(sum(a.session_duration) as BIGNUMERIC) as session_dur,
	current_timestamp() as created_dtm,
	max(a.ggsn_record_close_dtm) as ggsn_record_close_dtm ---> v1.3.1 Digunakan untuk sorting the latest bisa usage per site sama 
	from (select * from `data-dtptechm-prd-c7ca.dwh.gprs_usage_fct` a where a.created_dt_sk_id = date_sub(vdt_id,interval 1 day)) a
	left join `data-bi-prd-935c.bi_stg.stg_ggsn_vlr_1` b on a.sbscrptn_msisdn=b.sbscrptn_msisdn where b.sbscrptn_msisdn is null
	group by 1,2,3,4,5,6;
	


insert into `data-bi-prd-935c.bi_stg.stg_ggsn_vlr_1`
select  
	created_dt_sk_id, 
	sbscrptn_msisdn, 
	cast(null as string) as site_id ,
	calling_cell_id, 
	rat_type,
	cast(sitefound_flag as int64),
	cast(usage_mb as numeric),
	session_dur,
	created_dtm,
	ggsn_record_close_dtm
 from `data-bi-prd-935c.bi_mart.stg_ggsn_vlr_2`;

 */

  drop table if exists `data-bi-prd-935c.bi_stg.temp_gprs_stg`;
  create table `data-bi-prd-935c.bi_stg.temp_gprs_stg` as
	select 
	cast(created_dt_sk_id as date) as created_dt_sk_id, 
	sbscrptn_msisdn, 
	sites.site_id site_id ,
	calling_cell_id, 
	rat_type,
	case when sites.egci is not null then 1 else 0 end as sitefound_flag,
	usage_mb,
	session_dur,
	created_dtm,
	ggsn_record_close_dtm
	from
	`data-bi-prd-935c.bi_stg.stg_ggsn_vlr_1` a
	left outer join `data-bi-prd-935c.bi_mart.site_ref_dim` sites ON a.calling_cell_id = sites.egci and mth_sk_id = date_trunc(vdt_id,month)
	group by 1,2,3,4,5,6,7,8,9,10; 

  
  truncate table `data-bi-prd-935c.bi_stg.tmp_cem_stg` ;

--   drop table if exists `data-bi-prd-935c.bi_stg.tmp_cem_stg`;
--   create table `data-bi-prd-935c.bi_stg.tmp_cem_stg` as
-- 				select
-- 				cast(load_dt_sk_id as date) as load_dt_sk_id,
-- 				msisdn,
-- 				b.site_id,
-- 				b.system as system,	
-- 				sum(coalesce(volume_in,0)+coalesce(volume_out,0)) as usg,
-- 				max(date_sk_id) max_date_sk_id  ---> digunakan untuk sorting. Pilihan tercepat adalah max instead of rank
-- 				FROM `data-dtptechm-prd-c7ca.dwh.cem_location_pattern_daily_fct` a -- change to D-2 (vtgl2)
-- 				JOIN (
-- 							select 
-- 							distinct 
-- 							----- egci,  -> v1.2.1 remove egci ada potensi duplikasi
-- 							case 
-- 							-- when system in ('4GNE','4G') then '510-'||substring(egci,5,2)||'-'||tac||'-'||enodebid||'-'||cellnumber
-- 							when system in ('4GNE','4G') then '510-'||substring(egci,16,1)||substring(egci,15,1)||'-'||tac||'-'||enodebid||'-'||cellnumber
-- 							else '510-'||substring(egci,5,2)||'-'||lac||'-'||ci
-- 							end as location_id,
-- 							site_id,
-- 							case when system in ('2G','3G','4G') then system||'NE' else system end as system
-- 							from `data-bi-prd-935c.bi_mart.site_ref_dim` where mth_sk_id = date_trunc(vdt_id,month)
-- 					) b ON cast(a.load_dt_sk_id as date)=vdt_id and a.location = b.location_id

-- 				group by load_dt_sk_id, msisdn, site_id, system;
	
	--- stage 2. Sorting based on System (4G -> 3G -> 2G) and highest usage

  drop table if exists `data-bi-prd-935c.bi_stg.temp_cem_stg2`;
  create table `data-bi-prd-935c.bi_stg.temp_cem_stg2` as
	-- insert into ari_temp_cem_stg2(load_dt_sk_id,seqno,msisdn,site_id,system,usage_subs)
	select 
	cast(load_dt_sk_id as date) as load_dt_sk_id,
	row_number()over(partition by msisdn order by system desc nulls last, usg desc nulls last, max_date_sk_id desc nulls last) as seqno,
	msisdn,
	site_id,
	system,
	usg as usage_mb
	from `data-bi-prd-935c.bi_stg.tmp_cem_stg`
	where load_dt_sk_id = vdt_id;
	-- [VLR Site] Staging2 Sorting ggsn


  drop table if exists `data-bi-prd-935c.bi_stg.temp_gprs_stg2`;
  create table `data-bi-prd-935c.bi_stg.temp_gprs_stg2` as
	select 
	row_number()over(partition by sbscrptn_msisdn order by system desc, usage desc, ggsn_record_close_dtm desc nulls last) as seqno, --> v1.3.1 tambahan sorting 
	sum(usage) over(partition by sbscrptn_msisdn) as usage_subs,
	cast(created_dt_sk_id as date) as created_dt_sk_id,
	sbscrptn_msisdn,
	site_id,
	system,
	usage 
	from 
		(
		select created_dt_sk_id, 
		sbscrptn_msisdn, 
		coalesce(site_id,calling_cell_id) as site_id, 
		case 
		when coalesce(rat_type,'-2') = '6' then '4GNE'
		when coalesce(rat_type,'-2') IN ('1','5') then '3GNE'
		when coalesce(rat_type,'-2') = '2' then '2GNE'
		else '-2'
		end as system,
		sum(usage_mb) as usage,
		max(ggsn_record_close_dtm) as ggsn_record_close_dtm ---> v1.3.1 
		from `data-bi-prd-935c.bi_stg.temp_gprs_stg`
		where sitefound_flag = 1
		group by 1,2,3,4
		) a
	;


	--- 02.b Add source PCRF to version 1.2

	-- INSERT INTO stg_pcrf_site(seqno,edr_dt_sk_id,msisdn,site_id, system, quota_usage_mb, pcrf_created_dtm)

  drop table if exists `data-bi-prd-935c.bi_stg.stg_pcrf_site`;
  create table `data-bi-prd-935c.bi_stg.stg_pcrf_site` as
	SELECT 
	row_number()over(partition by msisdn order by system desc nulls last, quota_usage_mb desc nulls last, pcrf_created_dtm desc nulls last ) as seqno,
	a.*
	FROM
	(
	SELECT 
		cast(edr_dt_sk_id as date) as edr_dt_sk_id,
		msisdn,
		site_id,
		system,
		sum(quota_usage_mb) quota_usage_mb,
		max(created_dtm) as pcrf_created_dtm 
		from 
		(
			select 
			edr_dt_sk_id,
			msisdn,--sai,tai,ecgi,
			case when sai is not null then 
			coalesce(ltrim(substr(sai,6,5),'0'),'')||'-'||coalesce(ltrim(substr(sai,11,5),'0'),'')
			else 
			coalesce(ltrim(substr(tai,6,5),'0'),'')||'-'||
			case when ltrim(substr(ecgi,6,9),'0')='' then '1' else coalesce(cast(floor(cast(ltrim(substr(ecgi,6,9),'0') as bigint)/256) as string),'') end||'-'||
			case when ltrim(substr(ecgi,6,9),'0')='' then '1' else coalesce(cast(mod(cast(ltrim(substr(ecgi,6,9),'0') as bigint),256) as string),'') end
			end gci_dec,
			cast((coalesce(quota_usage,0))/1024 as numeric) as quota_usage_mb,
			created_dtm
			from `data-dtptechm-prd-c7ca.dwh.pcrf_edr_activation_fct`  --limit 10 -- change to D-2
			where date(edr_dt_sk_id)=vdt_id and triggertype not in (16,109,111) and mcc_mnc = '51089' ----and quota_usage > 0 	
		)tmp0
		LEFT OUTER JOIN (
			select distinct
			case when system in('4GNE','4G') then tac||'-'||enodebid||'-'||cellnumber else lac||'-'||ci end as gci_dec,
			--- *       	--> v1.2.1 -- remove due to avoid double counting in usage  
			site_id,    	--> v1.2.1
			system 		--> v1.2.1
			from `data-bi-prd-935c.bi_mart.site_ref_dim` where mth_sk_id = date_trunc(vdt_id,month)
			) site ON tmp0.gci_dec = site.gci_dec
		group by 1,2,3,4
	) a;

	-- [VLR Site] Final Table
	
	-- insert into fct_vlr_sites(load_dt_sk_id, siteid_nm, msisdn, cem_system, cem_siteid, cem_usage_mb, ggsn_system, ggsn_siteid, ggsn_usage_mb,
	-- 					vlr_system, site_id_vlr, pcrf_system, pcrf_siteid, pcrf_usg_mb, egci, created_dtm)

  delete from `data-bi-prd-935c.bi_mart.fct_vlr_sites`  where load_dt_sk_id=vdt_id;
  insert into `data-bi-prd-935c.bi_mart.fct_vlr_sites`  (load_dt_sk_id, siteid_nm, msisdn, cem_system, cem_siteid, cem_usage_mb, ggsn_system, ggsn_siteid, ggsn_usage_mb,
						vlr_system, site_id_vlr, pcrf_system, pcrf_siteid, pcrf_usg_mb, egci, created_dtm)
		select 
		cast(a.load_dt as date) as load_dt_sk_id,
		case
		---01. ggsn as first priority
		when c.system = '4GNE' then c.site_id -- > GGSN
		when c.system in ('3GNE','2GNE') then c.site_id -- > GGSN
		---02. ggsn as 2nd priority
		when b.system = '4GNE' then b.site_id --> CEM ()
		---03. ggsn as 3nd priority
		when d.site_id is not null then d.site_id  --> VLR (master Cell ID)
		---04. pfrc as 4th priority
		when e.system in ('4GNE','3GNE','2GNE') then e.site_id 	--- version 1.2 --> PCRF
		end as siteid_nm,
		a.msisdn,
		b.system as cem_system,
		b.site_id as cem_siteid,
		cast((coalesce(b.usage_mb,0)/(1024*1024)) as numeric) as cem_usage_mb, 
		c.system as ggsn_system,
		c.site_id as ggsn_siteid,
		c.usage as ggsn_usage_mb,
		d.site_id as site_id_VLR,
		d.g_type||'NE' as vlr_system,  
		
		e.system as pcrf_system,
		e.site_id as pcrf_siteid,
		e.quota_usage_mb as pcrf_usage_mb,
		a.gci as egci,
		current_timestamp() created_dtm
		from `data-bi-prd-935c.bi_mart.fct_vlr_daily` a
			left outer join (select * from `data-bi-prd-935c.bi_stg.temp_cem_stg2` where seqno =1 ) b ON a.msisdn = b.msisdn 
			left outer join (select * from `data-bi-prd-935c.bi_stg.temp_gprs_stg2` where seqno = 1 ) c ON a.msisdn = c.sbscrptn_msisdn
			left outer join `data-bi-prd-935c.bi_stg.stg_gci_site` d
				ON substring(a.gci,1,3)||'F'||substring(replace(UPPER(a.gci),'-',''),4,16) = d.egci
			left outer join (select * from `data-bi-prd-935c.bi_stg.stg_pcrf_site` where seqno = 1) e ON a.msisdn = e.msisdn  --- version 1.2
      where load_dt=vdt_id
	;
       
	-- [VLR Site] Aggregate Table
	
  delete from `data-bi-prd-935c.bi_mart.dm_vlr_sites` where load_dt_sk_id=vdt_id;
	insert into `data-bi-prd-935c.bi_mart.dm_vlr_sites`
	select load_dt_sk_id, siteid_nm, count(distinct msisdn) as vlrsubs, current_date() created_dtm from `data-bi-prd-935c.bi_mart.fct_vlr_sites`
	where load_dt_sk_id = vdt_id
	group by 1,2;

	
	delete from `data-bi-prd-935c.bi_mart.project_mis_profile_subs_sites` where load_dt_sk_id=vdt_id and tag='VLR';
	insert into `data-bi-prd-935c.bi_mart.project_mis_profile_subs_sites` (load_dt_sk_id,site_id,tag,amount,uom,created_dt)
	select 
	load_dt_sk_id dt,
	siteid_nm,
	'VLR',
	count(distinct msisdn) as msisdn,
	'units',
	current_date('Asia/Jakarta') as created_dt
	from `data-bi-prd-935c.bi_mart.fct_vlr_sites`
	where load_dt_sk_id = vdt_id
	group by 1,2;