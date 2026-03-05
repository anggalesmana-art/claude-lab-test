DECLARE vdt_id DATE DEFAULT @vdt_id;


  delete from `data-bi-prd-935c.bi_mart.project_ioh_kpi_daily_tracker_national_wise` where load_dt_sk_id = vdt_id and definition = 'IOH'and kpi_code = 'swe_daily';

  insert into `data-bi-prd-935c.bi_mart.project_ioh_kpi_daily_tracker_national_wise`
		with subs as (select * from `data-dtptechm-prd-c7ca.dwh.sbscrptn_attribs`)
		 select load_dt_sk_id, 'H3I', 'swe_daily', 'IOH', CAST(CAST(load_dt_sk_id AS STRING) AS DATE), count(1)
			from `data-bi-prd-935c.bi_mart.project_rguog_subs_detail` a
			left join subs b on cast(a.sbscrptn_ek_id as string) = cast(b.sbscrptn_ek_id as string) 
			join `data-bi-prd-935c.bi_mart.project_ioh_dgpcr_flag` c on b.sbscrptn_msisdn = c.service_msisdn
			where load_dt_sk_id = vdt_id
			and tool_of_trade_ind = 'N'
			group by 1;