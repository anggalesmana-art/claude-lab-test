DECLARE vdt_id DATE DEFAULT @vdt_id;
-- DECLARE vdt_id DATE DEFAULT @vdt_id;

delete from `data-bi-prd-935c.bi_mart.project_ioh_kpi_daily_tracker_national_wise` where CAST(load_dt_sk_id AS DATE) = vdt_id and kpi_code in 
('prepaid_30d_data_user_2g_b2b',
					'prepaid_30d_data_user_2g_b2c',
					'prepaid_30d_data_user_3g_b2b',
					'prepaid_30d_data_user_3g_b2c',
					'prepaid_30d_data_user_4g_b2b',
					'prepaid_30d_data_user_4g_b2c',
					'prepaid_daily_data_user_2g_b2b',
					'prepaid_daily_data_user_2g_b2c',
					'prepaid_daily_data_user_3g_b2b',
					'prepaid_daily_data_user_3g_b2c',
					'prepaid_daily_data_user_4g_b2b',
					'prepaid_daily_data_user_4g_b2c',
					'prepaid_30_mo_b2c',
					'prepaid_daily_mo_b2b',
					'prepaid_daily_mo_b2c',
					'prepaid_30_mo_b2b');

INSERT INTO `data-bi-prd-935c.bi_mart.project_ioh_kpi_daily_tracker_national_wise`
				select CAST(load_dt_sk_id AS date), 
				 'H3I' entity, 
				 case when tec = 'unknown' then 'prepaid_daily_data_user_4g_' || lower(b2b_flag) 
					else 'prepaid_daily_data_user_'||lower(tec)||'_'||lower(b2b_flag)
				 end kpi_code, 
				 'IOH' definition, 
				 CAST(load_dt_sk_id AS DATE) date,
				 count(1) VALUE
				from `data-bi-prd-935c.bi_mart.project_ioh_data_user_daily` a
				left join `data-bi-prd-935c.bi_mart.project_ioh_rgu_daily_list_adj` b 
on a.load_dt_sk_id = b.dt and a.sbscrptn_ek_id = b.sbscrptn_ek_id
				where load_dt_sk_id = vdt_id
				--and b2b_flag = 'B2B'
				and b.sbscrptn_ek_id is null
				group by 1,2,3,4,5
				union all
				select CAST(a.load_dt_sk_id AS date),
				 'H3I' entity,
				 case when tec = 'unknown' then 'prepaid_30d_data_user_4g_' || lower(b2b_flag) 
					else 'prepaid_30d_data_user_'||lower(tec)||'_'||lower(b2b_flag)
				 end kpi_code, 
				 'IOH' definition, 
				 CAST(load_dt_sk_id AS DATE) date,
				 count(1) VALUE
				from `data-bi-prd-935c.bi_mart.project_ioh_data_user_30` a
				left join `data-bi-prd-935c.bi_mart.project_ioh_rgu30_list_adj` b 
on a.load_dt_sk_id = b.dt and a.sbscrptn_ek_id = b.sbscrptn_ek_id
				where load_dt_sk_id = vdt_id
				-- and b2b_flag = 'B2B'
				and b.sbscrptn_ek_id is null
				group by 1,2,3,4,5
				union all
				select CAST(load_dt_sk_id AS date), 'H3I', 'prepaid_daily_mo_'||lower(b2b_flag), 'IOH', CAST(load_dt_sk_id AS DATE), count(1)
				from `data-bi-prd-935c.bi_mart.project_ioh_rguog_subs_fin_daily`
				where b2b_flag ='B2B'
				and load_dt_sk_id = vdt_id
				group by 1,2,3,4,5
				union all
				select CAST(a.load_dt_sk_id AS date), 'H3I', 'prepaid_daily_mo_b2c', 'IOH', CAST(a.load_dt_sk_id AS DATE), value - cnt
				from (select load_dt_sk_id, 'Daily' tag, b2b_flag, count(1) cnt
				from `data-bi-prd-935c.bi_mart.project_ioh_rguog_subs_fin_daily`
				where b2b_flag ='B2B'
				and load_dt_sk_id = vdt_id
				group by 1,3
				) a
				left join 
				(
				select load_dt_sk_id,value
				from `data-bi-prd-935c.bi_mart.project_ioh_kpi_daily_tracker_national_wise` a
				join `data-dtptechm-prd-c7ca`.dwh.ioh_datamar_kpi_dim b on a.kpi_code = b.kpi_code
				where CAST(load_dt_sk_id AS DATE) = vdt_id
				and definition = 'IOH'
				and a.kpi_code like 'swe_daily%'
				) b on a.load_dt_sk_id = CAST(b.load_dt_sk_id AS DATE)
				union all
				select CAST(a.load_dt_sk_id AS date), 'H3I', 'prepaid_30_mo_'||lower(b2b_flag), 'IOH', CAST(load_dt_sk_id AS DATE), count(1)
				from `data-bi-prd-935c.bi_mart`.project_ioh_rguog_subs_fin_30 a
				where load_dt_sk_id = vdt_id
				group by 1,3
;