DECLARE vdt_id DATE DEFAULT @vdt_id;


	delete from 
		`data-bi-prd-935c.bi_mart.mart_sales_productivity`
		where flag like '%primary%'
		and trx_dt_sk_id = vdt_id ;

		insert into
		`data-bi-prd-935c.bi_mart.mart_sales_productivity`		
		select cast(snp_dt_sk_id as date),
		'primary_opt' as flag 
		, ''
		,fct.partner_id
		,'' site_id,
		sum(case when kpi_name = 'Transfer to MP3' and fct.partner_type = 'ROH' then kpi_value else 0 end)
		+sum(case when kpi_name = 'Return to ROH'and fct.partner_type = 'ROH' and category_1 = 'AD' then kpi_value else 0 end)+
		+sum(case when kpi_name = 'Purchase from OPT' and fct.partner_type = 'MP3' then kpi_value else 0 end)+
		+sum(case when kpi_name = 'ODP_CUANWEB' and fct.partner_type = 'MP3' then kpi_value else 0 end) 
		as value,0
		from `data-dtptechm-prd-c7ca.dwh.prt_daily_channel_movement_fct` fct
		left join `data-dtptechm-prd-c7ca.dwh.angie_hrchy_dim` ng on fct.partner_id = ng.partner_id
		---left join dwh.RPRT_FLTR_REF_CTGRY flt on flt.ref_type_cd = 'Filter for Test MSISDN' and flt.ref_cd = ng.canvasser_id
		where date(snp_dt_sk_id) = vdt_id
		and ng.mp3_location is not null 
		and upper(coalesce(ng.mp3_location,'NA'))not in ('3 BUSINESS','3 STORE','ADVCREDIT','CIGNIFY','FUT ANGIE 2.0','NA','POOL','SOUTH JAKARTA TEST BM','DVM BM','SIM ONLINE','HO NON BRANCH')
		and upper(coalesce(ng.ret_hierarchy_type,'NA')) = 'ANGIE'
		and
		kpi_name in 
		('Transfer to MP3','Return to ROH','Purchase from OPT' ,'ODP_CUANWEB')
		group by 1 ,2,3,4,5;
 
		insert into
		`data-bi-prd-935c.bi_mart.mart_sales_productivity`
		select cast(dt_sk_id as date)
						,'primary_cuanweb' as flag 
						,canvasser_id
						,dtl.partner_qr_cd
						,'' site_id
						,value as amount 
						,kpi_cnt as hit
						from 
						`data-bi-prd-935c.bi_mart.project_ioh_primary_outlet` dtl
						left join `data-dtptechm-prd-c7ca.dwh.angie_hrchy_dim` hd on hd.partner_mobile = dtl.msisdn --and hd.ret_hierarchy_type = 'ANGIE'
						--and hd.hrchy_type = 'Retailer'
						where primary_type in ('PRT_CUANWEB') 
						and dt_sk_id = vdt_id ;
	


				
		delete from `data-bi-prd-935c.bi_mart.mart_sales_productivity_mtd`
		where flag like '%primary%'
		and trx_dt_sk_id = vdt_id;
			
		insert into `data-bi-prd-935c.bi_mart.mart_sales_productivity_mtd`
		select cast(vdt_id as date) as trx_dt_sk_id,flag,canvasser_id,qr_code,site_id,sum(amount)amount,sum(hit)hit from 
		`data-bi-prd-935c.bi_mart.mart_sales_productivity`
		where trx_dt_sk_id
		between DATE_TRUNC(vdt_id, MONTH) and vdt_id
		and flag like '%primary%' group by 1,2,3,4,5;
				
		delete from `data-bi-prd-935c.bi_mart`.dm_mart_snd_mp3_performance
		where kpi_name like '%primary%'
		and dt = vdt_id ;

			
		insert into `data-bi-prd-935c.bi_mart`.dm_mart_snd_mp3_performance 
		select cast(vdt_id as date) as dt,branch,'primary' kpi_name,sum(kpi_value) kpi_value,cast(null as string) as bm_id,cast(null as string) as mp3_id
		from (
		select cast(vdt_id as date),'primary_opt'
		,upper(hd.mp3_location)branch
		,sum(amount)kpi_value
		from `data-bi-prd-935c.bi_mart.mart_sales_productivity` a 
		left join 
		`data-dtptechm-prd-c7ca.dwh.angie_hrchy_dim` hd on hd.partner_id= a.qr_code --and hd.ret_hierarchy_type = 'ANGIE'
		where flag='primary_opt'
		and cast(trx_dt_sk_id as date) between DATE_TRUNC(vdt_id, MONTH) and vdt_id
		and hd.mp3_location is not null 
		and upper(coalesce(hd.mp3_location,'NA'))not in ('3 BUSINESS','3 STORE','ADVCREDIT','CIGNIFY','FUT ANGIE 2.0','NA','POOL','SOUTH JAKARTA TEST BM','DVM BM','SIM ONLINE','HO NON BRANCH')
		and upper(coalesce(hd.ret_hierarchy_type,'NA')) = 'ANGIE'
		group by 1,2,3
		union all 
		select cast(vdt_id as date),'primary_cuanweb'
		,upper(hd.mp3_location)branch
		,sum(amount)kpi_value
		from `data-bi-prd-935c.bi_mart.mart_sales_productivity` a 
		left join 
		`data-dtptechm-prd-c7ca.dwh.angie_hrchy_dim` hd on hd.partner_qr_cd= a.qr_code --and hd.ret_hierarchy_type = 'ANGIE'
		where flag='primary_cuanweb'
		and cast(trx_dt_sk_id as date) between DATE_TRUNC(vdt_id, MONTH) and vdt_id group by 1,2,3) a
		group by 1,2,3;