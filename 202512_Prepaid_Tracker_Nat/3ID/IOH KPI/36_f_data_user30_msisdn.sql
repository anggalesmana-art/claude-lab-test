DECLARE vdt_id DATE DEFAULT @vdt_id;

  delete from `data-bi-prd-935c.bi_mart.project_ioh_data_user_30` 
  where load_dt_sk_id= vdt_id;

  insert into `data-bi-prd-935c.bi_mart.project_ioh_data_user_30`
			with subs as (select * from `data-dtptechm-prd-c7ca.dwh.sbscrptn_attribs`)
			 select cast(vdt_id as date) load_dt_sk_id, 
				cast(a.sbscrptn_ek_id as string) as sbscrptn_ek_id, 
				case when LTE_Usage > 0 then '4g'
				    when Usage_3g > 0 then '3g'
				    when Usage_2g > 0 then '2g'
				    else 'unknown'
			       end tec, 
			       case when x.product_id = 8 then 'prepaid' else 'postpaid' end prepaid_flag,
			       case when ctgry_ref_chld = '3 BUSINESS' then 'B2B' else 'B2C' end b2b_flag,
			       cast(x.mp3_channel_sk_id as string),
			       cast(ctgry_ref_chld as string) home30_branch,NULL,NULL
			from (select sbscrptn_ek_id
			     from `data-dtptechm-prd-c7ca.dwh.rgs_subs_detail` a
			     where CAST(a.load_dt_sk_id AS DATE) <=vdt_id
			        and CAST(a.load_dt_sk_id AS DATE) >= DATE_SUB(vdt_id, INTERVAL 29 DAY)
				and (a.rgs_datapackage_ex_sp or a.rgs_gprs_ex_sp or a.rgs_blackberry_ex_sp)
				and a.tool_of_trade_ind = 'N' 
				and a.product_id = 8
			     group by 1
			     ) a
			left join `data-bi-prd-935c.bi_stg.tmp_usage_data30` b on a.sbscrptn_ek_id = b.sbscrptn_ek_id
			left join `data-dtptechm-prd-c7ca.dwh.rgs30_subs_detail` x on CAST(x.load_dt_sk_id AS DATE) =vdt_id and a.sbscrptn_ek_id = x.sbscrptn_ek_id
			left join subs att on a.sbscrptn_ek_id = att.sbscrptn_ek_id 
			    left join `data-dtptechm-prd-c7ca.dwh.channel_dim` cd on x.mp3_channel_sk_id = cd.channel_sk_id
	    left join `data-dtptechm-prd-c7ca.dwh.rprt_fltr_ref_ctgry` cat on cat.ref_type_cd = 'MP3' and cd.channel_id = cat.ref_cd;