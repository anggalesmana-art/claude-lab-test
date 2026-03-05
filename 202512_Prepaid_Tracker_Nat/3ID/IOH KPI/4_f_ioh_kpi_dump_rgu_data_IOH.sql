DECLARE vdt_id DATE DEFAULT @vdt_id;


delete from `data-bi-prd-935c.bi_mart.project_ioh_kpi_daily_tracker_national_wise` where load_dt_sk_id = vdt_id  and definition = 'IOH' 
 and kpi_code in ('rgu_data', 'rgu_data_5g', 'rgu_data_4g', 'rgu_data_3g', 'rgu_data_unknown', 'rgu_data_2g', 'rgu_data_prepaid', 'rgu_data_postpaid' , 'rgu_data_25mb', 'rgu_data_pack', 'rgu_data_payu');

insert into `data-bi-prd-935c.bi_mart.project_ioh_kpi_daily_tracker_national_wise`
with subs as (select * from `data-dtptechm-prd-c7ca.dwh.sbscrptn_attribs`)
	select cast(load_dt_sk_id as date), 'H3I', 'rgu_data_'|| case when LTE_Usage > 0 then '4g'
	when Usage_3g > 0 then '3g'
	when Usage_2g > 0 then '2g'
	else 'unknown'
	 end tec, 'IOH', cast(load_dt_sk_id as date), count(1)
	from `data-dtptechm-prd-c7ca.dwh.rgs_subs_detail` a
	left join (
	with subs as (select * from `data-dtptechm-prd-c7ca.dwh.sbscrptn_attribs`)
	select dt_sk_id, 
	 a.sbscrptn_ek_id,
	 case when product_id = 8 then 'prepaid' else 'postpaid' end prepaid_flag,
	SUM(case when rat_type = '6' THEN (coalesce(usage,0)) ELSE 0 END)/1024*1024*1024 as LTE_Usage, 
	SUM(case when rat_type IN ('1','5') THEN (coalesce(usage,0)) ELSE 0 END)/1024*1024*1024 as USAGE_3G, 
	SUM(case when rat_type = '2' THEN (coalesce(usage,0)) ELSE 0 END)/1024*1024*1024 as USAGE_2G,
	sum(usage) usage,
	SUM(case when gprs_rating_grp_nm in ('Normal GPRS Modifier','Pay as you go - GPPEK') THEN (coalesce(usage,0)) ELSE 0 END) as USAGE_PYU,
	SUM(case when coalesce(gprs_rating_grp_nm,'') not in ('GPRS Default Modifier','Pay as you go - GPPEK') THEN (coalesce(usage,0)) ELSE 0 END) as USAGE_package
	from `data-bi-prd-935c.bi_mart.project_ioh_data_imei_usage` a 
	left join subs b on a.sbscrptn_ek_id = b.sbscrptn_ek_id 
	where 
    dt_sk_id = vdt_id and 
	tool_of_trade_ind = 'N'
	and apn_for_gprs_nm in('3data','3gprs','black')
	group by 1,2,3
	) b on a.sbscrptn_ek_id = b.sbscrptn_ek_id
	left join subs att on a.sbscrptn_ek_id = att.sbscrptn_ek_id 
	--join mis.project_ioh_dgpcr_flag c on att.sbscrptn_msisdn = c.service_msisdn
	where 
    cast(a.load_dt_sk_id as date)= vdt_id and
	 (a.rgs_datapackage_ex_sp or a.rgs_gprs_ex_sp or a.rgs_blackberry_ex_sp)
	and a.tool_of_trade_ind = 'N'
	and a.product_id = 8
	group by 1,2,3,4,5;

    insert into `data-bi-prd-935c.bi_mart.project_ioh_kpi_daily_tracker_national_wise`
	with subs as (select * from `data-dtptechm-prd-c7ca.dwh.sbscrptn_attribs`)
	 select cast(load_dt_sk_id as date), 'H3I', 'rgu_data_'|| case when a.product_id = 8 then 'prepaid' else 'postpaid' end, 
	 'IOH', cast(load_dt_sk_id as date), count(1)
	from `data-dtptechm-prd-c7ca.dwh.rgs_subs_detail`  a
	left join subs att on a.sbscrptn_ek_id = att.sbscrptn_ek_id 
	--join mis.project_ioh_dgpcr_flag c on att.sbscrptn_msisdn = c.service_msisdn
	where 
    cast(a.load_dt_sk_id as date) = vdt_id  and 
	(a.rgs_datapackage_ex_sp or a.rgs_gprs_ex_sp or a.rgs_blackberry_ex_sp)
	and a.tool_of_trade_ind = 'N'
	and a.product_id = 8
	group by 1,2,3,4,5;

	insert into `data-bi-prd-935c.bi_mart.project_ioh_kpi_daily_tracker_national_wise`
	select cast(load_dt_sk_id as date), entity, 'rgu_data',definition, date, sum(value) 
	from `data-bi-prd-935c.bi_mart.project_ioh_kpi_daily_tracker_national_wise`
	where cast(load_dt_sk_id as date) = vdt_id  
	and kpi_code in ('rgu_data_prepaid','rgu_data_postpaid')
	and entity = 'H3I'
	and definition = 'IOH'
	group by 1,2,3,4,5;


	insert into `data-bi-prd-935c.bi_mart.project_ioh_kpi_daily_tracker_national_wise`
	with subs as (select * from `data-dtptechm-prd-c7ca.dwh.sbscrptn_attribs`)
	 select cast(load_dt_sk_id as date), 'H3I', 'rgu_data_payu', 'IOH', cast(load_dt_sk_id as date), count(1)
	from `data-dtptechm-prd-c7ca.dwh.rgs_subs_detail` a
	left join (
	with subs as (select * from `data-dtptechm-prd-c7ca.dwh.sbscrptn_attribs`)
	select dt_sk_id, 
	 a.sbscrptn_ek_id,
	 case when product_id = 8 then 'prepaid' else 'postpaid' end prepaid_flag,
	SUM(case when rat_type = '6' THEN (coalesce(usage,0)) ELSE 0 END)/1024*1024*1024 as LTE_Usage, 
	SUM(case when rat_type IN ('1','5') THEN (coalesce(usage,0)) ELSE 0 END)/1024*1024*1024 as USAGE_3G, 
	SUM(case when rat_type = '2' THEN (coalesce(usage,0)) ELSE 0 END)/1024*1024*1024 as USAGE_2G,
	sum(usage) usage,
	SUM(case when gprs_rating_grp_nm in ('Normal GPRS Modifier','Pay as you go - GPPEK') THEN (coalesce(usage,0)) ELSE 0 END) as USAGE_PYU,
	SUM(case when coalesce(gprs_rating_grp_nm,'') not in ('GPRS Default Modifier','Pay as you go - GPPEK') THEN (coalesce(usage,0)) ELSE 0 END) as USAGE_package
	from `data-bi-prd-935c.bi_mart.project_ioh_data_imei_usage` a 
	left join subs b on a.sbscrptn_ek_id = b.sbscrptn_ek_id 
	where 
    dt_sk_id = vdt_id  and 
	tool_of_trade_ind = 'N'
	and apn_for_gprs_nm in('3data','3gprs','black')
	group by 1,2,3
	) b on a.sbscrptn_ek_id = b.sbscrptn_ek_id
	left join subs att on a.sbscrptn_ek_id = att.sbscrptn_ek_id
	where 
    cast(a.load_dt_sk_id as date)= vdt_id and 
	(a.rgs_datapackage_ex_sp or a.rgs_gprs_ex_sp or a.rgs_blackberry_ex_sp)
	and a.tool_of_trade_ind = 'N'
	and a.product_id = 8
	and USAGE_PYU > 0
	group by 1,2,3,4,5;


	insert into `data-bi-prd-935c.bi_mart.project_ioh_kpi_daily_tracker_national_wise`
	with subs as (select * from `data-dtptechm-prd-c7ca.dwh.sbscrptn_attribs`)
	 select cast(dt_sk_id as date), 'H3I', 'rgu_data_pack', 'IOH', cast(dt_sk_id as date), count(1)
	from `data-dtptechm-prd-c7ca.dwh.rgs_subs_detail` a
	left join (
	with subs as (select * from `data-dtptechm-prd-c7ca.dwh.sbscrptn_attribs`)
	select dt_sk_id, 
	 a.sbscrptn_ek_id,
	 case when product_id = 8 then 'prepaid' else 'postpaid' end prepaid_flag,
	SUM(case when rat_type = '6' THEN (coalesce(usage,0)) ELSE 0 END)/1024*1024*1024 as LTE_Usage, 
	SUM(case when rat_type IN ('1','5') THEN (coalesce(usage,0)) ELSE 0 END)/1024*1024*1024 as USAGE_3G, 
	SUM(case when rat_type = '2' THEN (coalesce(usage,0)) ELSE 0 END)/1024*1024*1024 as USAGE_2G,
	sum(usage) usage,
	SUM(case when gprs_rating_grp_nm in ('Normal GPRS Modifier','Pay as you go - GPPEK') THEN (coalesce(usage,0)) ELSE 0 END) as USAGE_PYU,
	SUM(case when coalesce(gprs_rating_grp_nm,'') not in ('GPRS Default Modifier','Pay as you go - GPPEK') THEN (coalesce(usage,0)) ELSE 0 END) as USAGE_package
	from `data-bi-prd-935c.bi_mart.project_ioh_data_imei_usage` a 
	left join subs b on a.sbscrptn_ek_id = b.sbscrptn_ek_id 
	where 
    dt_sk_id = vdt_id and 
	b.tool_of_trade_ind = 'N'
	and apn_for_gprs_nm in('3data','3gprs','black')
	group by 1,2,3
	) b on a.sbscrptn_ek_id = b.sbscrptn_ek_id
	left join subs att on a.sbscrptn_ek_id = att.sbscrptn_ek_id
	--join mis.project_ioh_dgpcr_flag c on att.sbscrptn_msisdn = c.service_msisdn
	where 
    cast(a.load_dt_sk_id as date) = vdt_id and 
	(a.rgs_datapackage_ex_sp or a.rgs_gprs_ex_sp or a.rgs_blackberry_ex_sp)
	and a.tool_of_trade_ind = 'N'
	and USAGE_package > 0
	and a.product_id = 8
	group by 1,2,3,4,5;

	insert into `data-bi-prd-935c.bi_mart.project_ioh_kpi_daily_tracker_national_wise`
	with subs as (select * from `data-dtptechm-prd-c7ca.dwh.sbscrptn_attribs`)
	 select cast(load_dt_sk_id as date), 'H3I', 'rgu_data_25mb', 'IOH', cast(load_dt_sk_id as date), count(1)
	from `data-dtptechm-prd-c7ca.dwh.rgs_subs_detail` a
	left join (
	with subs as (select * from `data-dtptechm-prd-c7ca.dwh.sbscrptn_attribs`)
	select dt_sk_id, 
	 a.sbscrptn_ek_id,
	 case when product_id = 8 then 'prepaid' else 'postpaid' end prepaid_flag,
	SUM(case when rat_type = '6' THEN (coalesce(usage,0)) ELSE 0 END)/1024*1024*1024 as LTE_Usage, 
	SUM(case when rat_type IN ('1','5') THEN (coalesce(usage,0)) ELSE 0 END)/1024*1024*1024 as USAGE_3G, 
	SUM(case when rat_type = '2' THEN (coalesce(usage,0)) ELSE 0 END)/1024*1024*1024 as USAGE_2G,
	sum(usage) usage,
	SUM(case when gprs_rating_grp_nm in ('Normal GPRS Modifier','Pay as you go - GPPEK') THEN (coalesce(usage,0)) ELSE 0 END) as USAGE_PYU,
	SUM(case when coalesce(gprs_rating_grp_nm,'') not in ('GPRS Default Modifier','Pay as you go - GPPEK') THEN (coalesce(usage,0)) ELSE 0 END) as USAGE_package
	from `data-bi-prd-935c.bi_mart.project_ioh_data_imei_usage` a 
	left join subs b on a.sbscrptn_ek_id = b.sbscrptn_ek_id 
	where 
    dt_sk_id = vdt_id  and 
	tool_of_trade_ind = 'N'
	and apn_for_gprs_nm in('3data','3gprs','black')
	group by 1,2,3
	) b on a.sbscrptn_ek_id = b.sbscrptn_ek_id
	left join subs att on a.sbscrptn_ek_id = att.sbscrptn_ek_id 
	--join mis.project_ioh_dgpcr_flag c on att.sbscrptn_msisdn = c.service_msisdn
	where 
    cast(a.load_dt_sk_id as date)= vdt_id  and 
	(a.rgs_datapackage_ex_sp or a.rgs_gprs_ex_sp or a.rgs_blackberry_ex_sp)
	and a.tool_of_trade_ind = 'N'
	and usage/(1024*1024) >= 25
	and a.product_id = 8
	group by 1,2,3,4,5;

