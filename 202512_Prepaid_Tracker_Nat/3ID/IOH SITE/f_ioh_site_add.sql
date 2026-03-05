DECLARE vdt_id DATE DEFAULT @vdt_id;


-- datauu30'

	  delete from `data-bi-prd-935c.bi_mart.project_ioh_kpi_daily_tracker_site` where CAST(load_dt_sk_id AS DATE) = vdt_id and kpi_code in ('rgu30_data_4g','rgu30_data');
	  

	  insert into `data-bi-prd-935c.bi_mart.project_ioh_kpi_daily_tracker_site`
				select CAST(load_dt_sk_id AS date), 'H3I', 'rgu30_data_4g','IOH',CAST(load_dt_sk_id AS date), b.site_id_30, /*b.site_id_90,*/
				       CAST(count(1) AS numeric),'SITE ROLLING 30',current_timestamp()
				from `data-bi-prd-935c.bi_mart.project_ioh_data_user_30` a
				  left join `data-bi-prd-935c.bi_mart.ioh_subscriber_site_attribs_rolling` b on cast(a.sbscrptn_ek_id as string) = cast(b.sbscrptn_ek_id as string) and b.dt = CAST(a.load_dt_sk_id AS DATE)
				where CAST(load_dt_sk_id AS DATE) = vdt_id
				and tec in ('unknown','4g')
				group by 1,2,3,4,5,6;

	  

	  insert into `data-bi-prd-935c.bi_mart.project_ioh_kpi_daily_tracker_site`
				select CAST(load_dt_sk_id AS date), 'H3I', 'rgu30_data','IOH',CAST(load_dt_sk_id AS date), b.site_id_30, /*b.site_id_90,*/
				       CAST(count(1) AS numeric),'SITE ROLLING 30',current_timestamp()
				from `data-bi-prd-935c.bi_mart.project_ioh_data_user_30` a
				  left join `data-bi-prd-935c.bi_mart.ioh_subscriber_site_attribs_rolling` b on a.sbscrptn_ek_id = b.sbscrptn_ek_id and b.dt = CAST(a.load_dt_sk_id AS DATE)
				where CAST(load_dt_sk_id AS DATE) = vdt_id
				group by 1,2,3,4,5,6; 

--datavoice

	  delete from `data-bi-prd-935c.bi_mart.project_ioh_kpi_daily_tracker_site` where CAST(load_dt_sk_id AS DATE) = vdt_id and kpi_code in ('data traffic','voice traffic');
	  

	  insert into `data-bi-prd-935c.bi_mart.project_ioh_kpi_daily_tracker_site`
				select CAST(load_dt_sk_id AS date), 'H3I', tag,'IOH',CAST(load_dt_sk_id AS date), site_id,
				       SUM(CAST(amount AS numeric)),'SITE BASED ON TRAFFIC', current_timestamp() 
				from `data-bi-prd-935c.bi_mart.project_mis_profile_subs_sites` a
				where CAST(load_dt_sk_id AS DATE) = vdt_id
				and tag in ('data traffic','voice traffic')
				group by 1,2,3,4,5,6; 

-- vlr

	  delete from `data-bi-prd-935c.bi_mart.project_ioh_kpi_daily_tracker_site` where CAST(load_dt_sk_id AS DATE) = vdt_id and kpi_code = 'vlr_daily' ;

		insert into `data-bi-prd-935c.bi_mart.project_ioh_kpi_daily_tracker_site`
			 select CAST(load_dt_sk_id AS date) as load_dt, 'H3I','vlr_daily','IOH',CAST(load_dt_sk_id AS date),  siteid_nm as site_id, count(distinct msisdn) ,'SITE BASED ON VLR',current_timestamp()
				from `data-bi-prd-935c.bi_mart.fct_vlr_sites` a
				where load_dt_sk_id is not null and CAST(load_dt_sk_id AS DATE) = vdt_id
				group by 1,2,3,5,6;

-- secondary 

	  delete from `data-bi-prd-935c.bi_mart.project_ioh_kpi_daily_tracker_site` where CAST(load_dt_sk_id AS DATE) = vdt_id and kpi_code in ('secondary');
	  

	  insert into `data-bi-prd-935c.bi_mart.project_ioh_kpi_daily_tracker_site`
				select CAST(dt_sk_id AS date), 'H3I', 'secondary','IOH',CAST(dt_sk_id AS date), site_id,
				       sum(value) ,secondary_type,current_timestamp()
				from `data-bi-prd-935c.bi_mart.project_ioh_secondary_outlet` a
				  left join `data-dtptechm-prd-c7ca.stg.stg_v_map_tgt_ret_details` b on a.partner_qr_cd = b.ret_qr_cd
				  --left join ioh_biadm.hg_ref_site_h3i c on b.site_id = c.site_id
				where dt_sk_id = vdt_id
				group by 1,2,3,4,5,6,8;

-- tertiary

	  delete from `data-bi-prd-935c.bi_mart.project_ioh_kpi_daily_tracker_site` where CAST(load_dt_sk_id AS DATE) = vdt_id and kpi_code in ('tertiary');
	  

	  insert into `data-bi-prd-935c.bi_mart.project_ioh_kpi_daily_tracker_site`
				select CAST(dt_sk_id AS date), 'H3I', 'tertiary','IOH',CAST(dt_sk_id AS date), site_id,
				       sum(amount),tertiary_type,current_timestamp()
				from `data-bi-prd-935c.bi_mart.project_ioh_tertiary_outlet` a
				  left join `data-dtptechm-prd-c7ca.stg.stg_v_map_tgt_ret_details` b on a.dealer_id = b.ret_qr_cd
				  --left join ioh_biadm.hg_ref_site_h3i c on b.site_id = c.site_id
				where dt_sk_id is not null and CAST(dt_sk_id AS DATE) = vdt_id
				group by 1,2,3,4,5,6,8;  