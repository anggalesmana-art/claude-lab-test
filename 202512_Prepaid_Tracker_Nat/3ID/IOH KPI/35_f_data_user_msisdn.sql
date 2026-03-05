declare vdt_id date default @vdt_id;

delete from `data-bi-prd-935c.bi_mart.project_ioh_data_user_daily` where load_dt_sk_id= vdt_id;


insert into `data-bi-prd-935c.bi_mart.project_ioh_data_user_daily`
			with subs as (select * from `data-dtptechm-prd-c7ca.dwh.sbscrptn_attribs`)
			 select cast(load_dt_sk_id as date),
				cast(a.sbscrptn_ek_id as string), 
				case when LTE_Usage > 0 then '4g'
				when Usage_3g > 0 then '3g'
				when Usage_2g > 0 then '2g'
				else 'unknown'
			 end tec, 
			 case when a.product_id = 8 then 'prepaid' else 'postpaid' end prepaid_flag,
			 case when ctgry_ref_chld = '3 BUSINESS' then 'B2B' else 'B2C' end b2b_flag,
			 cast(a.mp3_channel_sk_id as string),
			 ctgry_ref_chld home30_branch
			from `data-dtptechm-prd-c7ca.dwh.rgs_subs_detail` a
			left join (
				with subs as (select * from `data-dtptechm-prd-c7ca.dwh.sbscrptn_attribs`)
				select cast(dt_sk_id as date) as dt_sk_id, 
				 a.sbscrptn_ek_id,
				 case when product_id = 8 then 'prepaid' else 'postpaid' end prepaid_flag,
				SUM(case when rat_type = '6' THEN (coalesce(usage,0)) ELSE 0 END)/(1024*1024*1024) as LTE_Usage, 
				SUM(case when rat_type IN ('1','5') THEN (coalesce(usage,0)) ELSE 0 END)/(1024*1024*1024) as USAGE_3G, 
				SUM(case when rat_type = '2' THEN (coalesce(usage,0)) ELSE 0 END)/(1024*1024*1024) as USAGE_2G,
				sum(usage) usage,
				SUM(case when gprs_rating_grp_nm in ('Normal GPRS Modifier','Pay as you go - GPPEK') THEN (coalesce(usage,0)) ELSE 0 END) as USAGE_PYU,
				SUM(case when coalesce(gprs_rating_grp_nm,'') not in ('GPRS Default Modifier','Pay as you go - GPPEK') THEN (coalesce(usage,0)) ELSE 0 END) as USAGE_package
				from `data-bi-prd-935c.bi_mart.project_ioh_data_imei_usage` a 
				left join subs b on a.sbscrptn_ek_id = b.sbscrptn_ek_id 
				where cast(dt_sk_id as date) = vdt_id and 
                tool_of_trade_ind = 'N'
				and apn_for_gprs_nm in('3data','3gprs','black')
				group by 1,2,3
			) b on a.sbscrptn_ek_id = b.sbscrptn_ek_id
			left join subs att on a.sbscrptn_ek_id = att.sbscrptn_ek_id 
			left join `data-dtptechm-prd-c7ca.dwh.channel_dim` cd on a.mp3_channel_sk_id = cd.channel_sk_id
	left join `data-dtptechm-prd-c7ca.dwh.rprt_fltr_ref_ctgry` cat on cat.ref_type_cd = 'MP3' and cd.channel_id = cat.ref_cd
			where cast(a.load_dt_sk_id as date)= vdt_id and 
            (a.rgs_datapackage_ex_sp or a.rgs_gprs_ex_sp or a.rgs_blackberry_ex_sp)
			and a.tool_of_trade_ind = 'N' 
			and a.product_id = 8;
