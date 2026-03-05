DECLARE  vdt_id DATE DEFAULT @vdt_id;

drop table if exists `data-bi-prd-935c.bi_stg.stg_daily_fav_site_dim`;

create table `data-bi-prd-935c.bi_stg.stg_daily_fav_site_dim` as 
select * from `data-dtptechm-prd-c7ca.dwh.daily_fav_site_dim`
where cast(dt_id as date) = vdt_id 
;


delete from `data-bi-prd-935c.bi_mart.mart_evc` where topup_dt_sk_id =  vdt_id;
delete from `data-bi-prd-935c.bi_mart.dm_snd_demand_frc` where dt =  vdt_id;
 
	insert into `data-bi-prd-935c.bi_mart.dm_snd_demand_frc`
	with subs as (select * from `data-dtptechm-prd-c7ca.dwh.sbscrptn_attribs`)
	select 
	cast(stock_out_dtm as date) as dt
	,fct.angie_hrchy_sk_id
	,ng.partner_qr_cd
	,fct.ret_msisdn
	,'DEMAND' as sd_type
	,'FRC '||fct.service_type as report_rowname 
	,site_id_dly as siteid_bnum ---> untuk SIM menggunakan favloc fu  
	,count(distinct sim||'.'||fct.sbscrptn_msisdn) as hits_sim_msisdn
	,cast(sum(case when fct.service_type = 'BROADBAND' and parse_date('%Y%m%d',cast(fct.angie_activation_dt_sk_id as string)) < '2019-07-01' and tarif_adjusted is not null then (tarif_adjusted * coalesce(pct,1)) 
		 else (coalesce(gross_revenue,0))
	end) as NUMERIC) as gross_revenue
	,cast(sum(case when fct.service_type = 'BROADBAND' and parse_date('%Y%m%d',cast(fct.angie_activation_dt_sk_id as string)) < '2019-07-01' and tarif_adjusted is not null then (tarif_adjusted * coalesce(pct,1)) 
		 else (coalesce(gross_revenue,0) - (coalesce(comm_3as,0) + coalesce(comm_3as_bonus,0)) + coalesce(p3_cashback,0) )
	end) as NUMERIC) as net_revenue
	from `data-dtptechm-prd-c7ca.dwh.frc_stock` fct
	left outer join `data-bi-prd-935c.bi_stg.stg_daily_fav_site_dim` fav 
				ON fav.sbscrptn_ek_id = fct.sbscrptn_ek_id AND cast(fct.stock_out_dtm as date) = cast(fav.dt_id as date) 
	left join `data-dtptechm-prd-c7ca.dwh.angie_hrchy_dim` ng on fct.angie_hrchy_sk_id = ng.angie_hrchy_sk_id 
							 --left outer join `data-dtptechm-prd-c7ca.dwh.channel_dim` CD2 ON (CD2.channel_sk_id=fct.mp3_channel_sk_id) 
							 --left outer join `data-dtptechm-prd-c7ca.dwh.rprt_fltr_ref_ctgry` REF2 ON (ref2.ref_cd=CD2.channel_id and REF2.ref_type_cd = 'MP3')
							 left join `data-dtptechm-prd-c7ca.dwh.product_dim` pd ON pd.product_sk_id=fct.product_sk_id 
	 LEFT OUTER JOIN subs sa ON cast(sa.sbscrptn_ek_id as string)=  cast(fct.sbscrptn_ek_id as string) --and rank_ind = 1 
					 left join `data-dtptechm-prd-c7ca.dwh.channel_dim` cd on cd.channel_sk_id=sa.mp3_Channel_sk_id
					 left join `data-dtptechm-prd-c7ca.dwh.rprt_fltr_ref_ctgry` rprt on cd.channel_id=rprt.ref_cd and rprt.ref_type_cd='MP3' 
	 where
	 cast(stock_out_dtm as date) =  vdt_id
	 AND revenue_incl_ind = 'INCLUDE' 
	 -- AND stock_status = 'STOCK_OUT'
	 AND (stock_out_reason not like '%TERMINATE%' 
		 and stock_out_reason <> 'SWAP')---Neither SWAPPED nor FORFEITED must mean it has gone to DEMAND
	-- and fct.service_type ='BROADBAND'
	group by 1,2,3,4,5,6,7;
	
-- 	-- append supply
	INSERT INTO `data-bi-prd-935c.bi_mart.dm_snd_demand_frc`
	select 
	cast(stock_in_dtm as date) as dt
	,fct.angie_hrchy_sk_id
	,ng.partner_qr_cd
	,fct.ret_msisdn
	,'SUPPLY' as sd_type
	,'FRC '||fct.service_type as report_rowname 
	,cast(null as string) siteid_bnum 
	,count(distinct sim||'.'||fct.sbscrptn_msisdn) as hits_sim_msisdn
	,cast(sum(case when fct.service_type = 'BROADBAND' and parse_date('%Y%m%d',cast(fct.angie_activation_dt_sk_id as string)) < '2019-07-01' 
			and tarif_adjusted is not null then (tarif_adjusted * coalesce(pct,1)) 
		 else (coalesce(gross_revenue,0))
	end) as NUMERIC) as gross_revenue,
	cast(sum(case when fct.service_type = 'BROADBAND' and parse_date('%Y%m%d',cast(fct.angie_activation_dt_sk_id as string)) < '2019-07-01' 
			and tarif_adjusted is not null then (tarif_adjusted * coalesce(pct,1)) + coalesce(p3_cashback,0) 
		 else (coalesce(gross_revenue,0) - (coalesce(comm_3as,0) + coalesce(comm_3as_bonus,0)) + coalesce(p3_cashback,0))
	end) as NUMERIC) as net_revenue
	from `data-dtptechm-prd-c7ca.dwh.frc_stock` fct 
	left join `data-dtptechm-prd-c7ca.dwh.angie_hrchy_dim` ng on fct.angie_hrchy_sk_id = ng.angie_hrchy_sk_id 
							 left outer join `data-dtptechm-prd-c7ca.dwh.channel_dim` CD2 ON (CD2.channel_sk_id=fct.mp3_channel_sk_id) 
							 left outer join `data-dtptechm-prd-c7ca.dwh.rprt_fltr_ref_ctgry` REF2 ON (ref2.ref_cd=CD2.channel_id and REF2.ref_type_cd = 'MP3')
							 left join `data-dtptechm-prd-c7ca.dwh.product_dim` pd ON pd.product_sk_id=fct.product_sk_id 
	where
	cast(stock_in_dtm as date) = vdt_id
	AND revenue_incl_ind = 'INCLUDE' 
	--and (coalesce(fct.service_type,'BROADBAND') ='BROADBAND' 
	--	or upper(product_rpt_nm) like '%RP%1%')
	GROUP BY 1,2,3,4,5,6,7;
	
	drop table if exists `data-bi-prd-935c.bi_stg.stg_topup`;
	
	create table `data-bi-prd-935c.bi_stg.stg_topup` as
	select distinct cast(topup_dt_sk_id as date) topup_dt_sk_id, voucher_id, site_id_dly 
	from `data-dtptechm-prd-c7ca.dwh.topup_fct` a
	left outer join `data-bi-prd-935c.bi_stg.stg_daily_fav_site_dim` fav 
				ON fav.sbscrptn_ek_id = a.sbscrptn_ek_id AND cast(topup_dt_sk_id as date) = cast(fav.dt_id as date)
	where topup_status_desc = 'SUCCESS'
	and cast(topup_dt_sk_id as date) =  vdt_id;
	
-- 	-- 01. VOUCHER SPECIAL
	delete FROM `data-bi-prd-935c.bi_mart.dm_snd_voucher` where dt =  vdt_id;

-- 	-- [SND Funnel - SPV0 DEMAND]
	
	
	INSERT INTO `data-bi-prd-935c.bi_mart.dm_snd_voucher`
	SELECT
	 cast(inuse_dtm as date) dt 
	 ,'DEMAND' as sd_type
	 ,pd.product_type as package_type
	 ,pd.service_type
	 --'UNLOCK' as package_type
	 ,fct.voucher_type	
	 ,fct.product_id
	 ,cast(fct.angie_hrchy_sk_id as string)
	 ,COALESCE(SPLIT(ret_detail_info, ';')[OFFSET(1)], ng.partner_qr_cd) as qr_cd
	 ,site_id_dly as siteid_bnum---> untuk voucher menggunakan favloc 90 days (sesuai disksi dengan mas rohman)
	 ,count(1) as hits 
	 ,count(distinct sid_number) as hits_sidnum
	 ,cast(sum( 
			 coalesce( 
			 normalized_revenue, 
			 tariff_adjusted,
			 tariff_not_adjusted,
			 (coalesce(gross_revenue,0)) 
			 ) --coalesce
			 + coalesce(p3_cashback,0) 
	 ) as BIGNUMERIC)as Gross_revenue
	 ,cast(sum( 
			 coalesce( 
			 normalized_revenue, 
			 tariff_adjusted,
			 tariff_not_adjusted,
			 ( 
					 ( 
					 coalesce(gross_revenue,0) - (coalesce(comm_3as,0) + coalesce(comm_3as_bonus,0)) - coalesce(pulsa,0) 
					 ) 
			 ) 
			 ) --coalesce
			 + coalesce(p3_cashback,0) 
	 ) as BIGNUMERIC) as net_revenue
	 from `data-dtptechm-prd-c7ca.dwh.vms_voucher_status_dim` fct
	 left outer join `data-bi-prd-935c.bi_stg.stg_topup` topup ON topup.voucher_id = fct.sid_number
	 left join `data-dtptechm-prd-c7ca.dwh.angie_hrchy_dim` ng on fct.angie_hrchy_sk_id = ng.angie_hrchy_sk_id
							 left outer join `data-dtptechm-prd-c7ca.dwh.channel_dim` CD2 ON (CD2.channel_sk_id=ng.mp3_channel_sk_id) 
							 left outer join `data-dtptechm-prd-c7ca.dwh.rprt_fltr_ref_ctgry` REF2 ON (ref2.ref_cd=CD2.channel_id and REF2.ref_type_cd = 'MP3') 
							 left join `data-dtptechm-prd-c7ca.dwh.product_dim` pd ON pd.product_sk_id=fct.product_sk_id
	-- left join (select sbscrptn_ek_id,voucher_idfrom dwh.topup_fct where topup_dt_sk_id = 20220101 and topup_status_desc='SUCCESS') subs 
	--			on fct.sid_number =subs.voucher_id
	-- LEFT OUTER JOIN dwh.sbscrptn_attribs sa ON sa.sbscrptn_ek_id = subs.sbscrptn_ek_id --and rank_ind = 1 
	-- left join `data-dtptechm-prd-c7ca.dwh.channel_dim` cd on cd.channel_sk_id=sa.mp3_Channel_sk_id 
	-- left join `data-dtptechm-prd-c7ca.dwh.rprt_fltr_ref_ctgry` rprt on cd.channel_id=rprt.ref_cd and rprt.ref_type_cd='MP3'
	 where 
	 cast(lock_status_change_dtm as date) <=  vdt_id
	 and (case when fct.Lock_status_id = 'CST01' then 'Locked' 
					 when fct.Lock_status_id = 'CST02' then 'Unlocked' 
					 else fct.lock_status_id 
			 end 
			 ) = 'Unlocked'
	 and ( 
			 case
					 when fct.Scrap_Status_id = 'CST01' then 'Scrapped'
					 when fct.Scrap_Status_id = 'CST02' then 'Unscrapped'
					 else fct.scrap_status_id
			 end 
			 ) <> 'Scrapped' --Not Terminated/Forfeited
	 and ( 
			 case
					 when fct.Serial_status_id = 'SRS01' then 'Generated'
					 when fct.Serial_status_id = 'SRS02' then 'Tagged'
					 when fct.Serial_status_id = 'SRS03' then 'Billed' 
					 when fct.Serial_status_id = 'SRS05' then 'Used' 
					 else fct.Serial_status_id 
			 end 
			 ) = 'Used'--used or TOPUP DONE as DEMAND
	 and cast(inuse_dtm as date) = vdt_id
	 and pd.product_type in ('UNLOCK')
	 ---and pd.service_type ='BROADBAND'
	 and coalesce(pd.category_2,'NA') <> 'PULSA'
	 group by 1,2,3,4,5,6,7,8,9;
	 
-- 	 -- [SND Funnel - SPV0 SUPPLY]
	 
	 INSERT INTO `data-bi-prd-935c.bi_mart.dm_snd_voucher`
	select 
	 cast(lock_status_change_dtm as date) date_id
	 ,'SUPPLY' as sd_type 
	 ,pd.product_type as package_type
	 ,pd.service_type
	 --,'UNLOCK' package_type	
	 ,fct.voucher_type
	 ,fct.product_id 
	 ,CAST(fct.angie_hrchy_sk_id as string)
	 ,COALESCE(SPLIT(ret_detail_info, ';')[OFFSET(1)], ng.partner_qr_cd) as qr_cd
	 ,cast(null as string) 
	 ,count(1) as hits 
	 ,count(distinct sid_number) as hits_sidnum
	 ,cast(sum(coalesce(normalized_revenue,tariff_adjusted,tariff_not_adjusted,((coalesce(gross_revenue,0)))) + coalesce(p3_cashback,0)) as BIGNUMERIC) as Gross_revenue 
	 ,cast(sum(coalesce(normalized_revenue,tariff_adjusted,tariff_not_adjusted,((coalesce(gross_revenue,0) - (coalesce(comm_3as,0) + coalesce(comm_3as_bonus,0)) - coalesce(pulsa,0)))) + coalesce(p3_cashback,0)) as BIGNUMERIC) as net_revenue 
	from `data-dtptechm-prd-c7ca.dwh.vms_voucher_status_dim` fct
	left join `data-dtptechm-prd-c7ca.dwh.angie_hrchy_dim` ng on fct.angie_hrchy_sk_id = ng.angie_hrchy_sk_id 
							 left outer join `data-dtptechm-prd-c7ca.dwh.channel_dim` CD2 ON (CD2.channel_sk_id=ng.mp3_channel_sk_id)
							 left outer join `data-dtptechm-prd-c7ca.dwh.rprt_fltr_ref_ctgry` REF2 ON (ref2.ref_cd=CD2.channel_id and REF2.ref_type_cd = 'MP3')
							 left join `data-dtptechm-prd-c7ca.dwh.product_dim` pd ON pd.product_sk_id=fct.product_sk_id 
	where
	cast(lock_status_change_dtm as date) =  vdt_id
	and (case when fct.Lock_status_id = 'CST01' then 'Locked'
					 when fct.Lock_status_id = 'CST02' then 'Unlocked'
					 else fct.lock_status_id
			 end
			 ) = 'Unlocked' 
	and
	pd.product_type in ('UNLOCK')
	---and pd.service_type ='BROADBAND'
	and coalesce(pd.category_2,'NA') <> 'PULSA'
	group by 1,2,3,4,5,6,7,8,9;

		
-- 	-- [SND Funnel - RITA]
	
	
	INSERT INTO `data-bi-prd-935c.bi_mart.dm_snd_voucher`
	SELECT 
	cast(trx_dt_sk_id as date),
	'DEMAND' as sd_type,
	'RITA' as package_type,
	cast(null as string),
	'E TOP UP' as voucher_type,
	cast(product_sk_id as string),
	cast(angie_channel_sk_id as string),
	retailer_qr_cd,
	site_id_dly as siteid_bnum,---> untuk voucher menggunakan favloc 90 days (sesuai disksi dengan mas rohman)
	count(1),
	count(distinct case when process_nm = 'RITA' then transaction_id end) as hit_trxid,
	SUM(gross_revenue) as gross_revenue,
	SUM(net_revenue) net_revenue
	FROM
	(
		SELECT
			trx_dt_sk_id,
			fct.angie_channel_sk_id,
			hd.partner_qr_cd as retailer_qr_cd,
			transaction_id,
			fct.process_nm,
			fct.product_sk_id,
			fct.sbscrptn_ek_id,
			SUM(case when upper(COALESCE(service_type,'BROADBAND')) IN ('BROADBAND') AND COALESCE(product_id,8) = 8 THEN gross_revenue
					when upper(COALESCE(service_type,'BROADBAND')) IN ('BROADBAND') AND COALESCE(product_id,8) <> 8 THEN gross_revenue end) as gross_revenue,
			SUM(case when upper(COALESCE(service_type,'BROADBAND')) IN ('BROADBAND') AND COALESCE(product_id,8) = 8 THEN net_revenue
					when upper(COALESCE(service_type,'BROADBAND')) IN ('BROADBAND') AND COALESCE(product_id,8) <> 8 THEN net_revenue end) as net_revenue
		FROM `data-dtptechm-prd-c7ca.dwh.revenue_base` fct
			LEFT JOIN `data-dtptechm-prd-c7ca.dwh.angie_hrchy_dim` hd ON hd.angie_hrchy_sk_id=fct.angie_channel_sk_id
		JOIN `data-dtptechm-prd-c7ca.dwh.demand_revenue_base_filter` AS drbf
							ON fct.process_nm = drbf.process_nm
							AND fct.revenue_src_ctgry = drbf.revenue_src_ctgry
		WHERE 
		cast(fct.trx_dt_sk_id as date)=  vdt_id
		and drbf.net_revenue_incl = 'Y'
		AND fct.process_nm = 'RITA'
		-- AND (
		-- 	(fct.process_nm,fct.revenue_src_ctgry) in 
		-- 	( select process_nm,revenue_src_ctgry from dwh.demand_revenue_base_filter where net_revenue_incl = 'Y')
		-- 	)
		and gl_cd not in (select ref_cd from `data-dtptechm-prd-c7ca.dwh.rprt_fltr_ref_ctgry` where ref_type_cd = 'ACCRUAL_GL_CODE')
		and upper(COALESCE(service_type,'BROADBAND')) IN ('BROADBAND')
		group by 1,2,3,4,5,6,7
	) fct
	LEFT OUTER JOIN `data-bi-prd-935c.bi_stg.stg_daily_fav_site_dim` fav 
				ON fav.sbscrptn_ek_id= fct.sbscrptn_ek_id AND cast(fct.trx_dt_sk_id as date) = cast(fav.dt_id as date)
	WHERE transaction_id <> '-2' ---> asumsi transaksi yang sampai ke customer jika ada transaction_id
	GROUP BY 1,2,3,4,5,6,7,8,9;
	
	-- [SND Funnel - UNLOCK PULSA SUPPLY]
	
	INSERT INTO `data-bi-prd-935c.bi_mart.dm_snd_voucher`
	SELECT 
	cast(trx_dt_sk_id as date)
	,'SUPPLY' as sd_type
	,'UNLOCK' as report_rowname
	,cast(NULL as string)
	,'UNLOCK PULSA' as voucher_type
	,cast(product_sk_id as string)
	,cast(angie_channel_sk_id as string)
	,partner_qr_cd
	,cast(site_id_dly as string)
	,count(1)
	,count(distinct case when unlock_pulsa > 0 then transaction_id end) hits--> trx hanya dihitung bila ada transaksi unlock pulsa
	,sum(coalesce(unlock_pulsa,0)+coalesce(markup_unlock,0)+coalesce(p3_price_unlock,0)) gross_revenue
	,sum(coalesce(unlock_pulsa,0)+coalesce(markup_unlock,0)+coalesce(p3_price_unlock,0)) net_revenue
	FROM 
	(
		SELECT 
		a.trx_dt_sk_id
		,a.product_sk_id
		,a.transaction_id
		,a.angie_channel_sk_id 
		,b.partner_qr_cd
		,null site_id_dly
		,sum(case when process_nm ='UNLOCK_PULSA' then unearned else 0 end )unlock_pulsa
		,sum(case when process_nm ='MARKUP_UNLOCK' then markup else 0 end )markup_unlock
		,sum(case when process_nm ='UNLOCK_P3PRICE_AMORT' then markup else 0 end )p3_price_unlock
		FROM `data-dtptechm-prd-c7ca.dwh.revenue_base` a
			--LEFT OUTER JOIN mis.ioh_subscriber_site_attribs_rolling fav 
			--	ON fav.sbscrptn_msisdn = a.sbscrptn_msisdn AND a.trx_dt_sk_id = fav.dt 
			---left join `data-dtptechm-prd-c7ca.dwh.product_dim` pd ON a.product_sk_id=pd.product_sk_id 
			left join `data-dtptechm-prd-c7ca.dwh.angie_hrchy_dim` b on a.angie_channel_sk_id=b.angie_hrchy_sk_id
			---left outer join `data-dtptechm-prd-c7ca.dwh.channel_dim` CD2 ON (CD2.channel_sk_id=b.mp3_channel_sk_id) 
			---left outer join `data-dtptechm-prd-c7ca.dwh.rprt_fltr_ref_ctgry` REF2 ON (ref2.ref_cd=CD2.channel_id and REF2.ref_type_cd = 'MP3')
		where cast(a.trx_dt_sk_id as date) =  vdt_id 
		and a.process_nm in 
		(
		 'UNLOCK_P3PRICE_AMORT', 
		 'MARKUP_UNLOCK',
		 'UNLOCK_PULSA' 
		)
		--and service_type='Regular' 
		and a.tool_of_trade_ind = 'N'
		--and product_id = 8 
		group by 1,2,3,4,5
	) x 
	group by 1,2,3,4,5,6,7,8,9;
	
-- 	-- [SND Funnel - UNLOCK PULSA DEMAND]
	
	INSERT INTO `data-bi-prd-935c.bi_mart.dm_snd_voucher`
	SELECT 
	cast(topup_dt_sk_id as date)
	,'DEMAND'
	,'UNLOCK' as package_type
	,cast(NULL as string)
	,UPPER(topup_group)||' PULSA' as topup_type
	,topup.recharge_package_id
	,cast(vsd.angie_hrchy_sk_id as string)
	,COALESCE(hd.partner_qr_cd, SPLIT(vsd.ret_detail_info, ';')[OFFSET(0)]) retailer_qr_cd
	,site_id_dly
	,count(1) as instances
	,count(distinct voucher_id) as Qty
	,sum(coalesce(topup.pulsa,0)) as gross_amount 
	,sum(coalesce(topup.pulsa,0) - coalesce(topup.comm_3as,0) - coalesce(topup.comm_3as_bonus,0)) net_amount
	FROM `data-dtptechm-prd-c7ca.dwh.sbscrptn_topup_base` topup
		LEFT OUTER JOIN `data-bi-prd-935c.bi_stg.stg_daily_fav_site_dim` fav 
				ON fav.sbscrptn_ek_id = topup.sbscrptn_ek_id AND cast(topup.topup_dt_sk_id as date)= cast(fav.dt_id as date)
		left join `data-dtptechm-prd-c7ca.dwh.vms_voucher_status_dim` vsd ON vsd.sid_number=topup.voucher_id
		left join `data-dtptechm-prd-c7ca.dwh.angie_hrchy_dim` hd ON hd.angie_hrchy_sk_id=vsd.angie_hrchy_sk_id
				 left outer join `data-dtptechm-prd-c7ca.dwh.channel_dim` CD2 ON (CD2.channel_sk_id=hd.mp3_channel_sk_id) 
				 left outer join `data-dtptechm-prd-c7ca.dwh.rprt_fltr_ref_ctgry` REF2 ON (ref2.ref_cd=CD2.channel_id and REF2.ref_type_cd = 'MP3')
	where cast(topup.topup_dt_sk_id as date) =  vdt_id 
	and upper(topup.category_1)='REGULAR'
	and coalesce(topup.tool_of_trade_ind,'N') = 'N'
	and upper(topup.topup_group)='PHYSICAL'
	and topup.recharge_package_id not like '%ETOPUP%'
	GROUP BY 1,2,3,4,5,6,7,8,9;
	
-- 	-- [SND Funnel - RITA PULSA DEMAND]
	
	INSERT INTO `data-bi-prd-935c.bi_mart.dm_snd_voucher`
	SELECT 
	cast(trx_dt_sk_id as date)
	,'DEMAND' as sd_type
	,'RITA' as report_rowname
	,cast(NULL as string)
	,'RITA PULSA'
	,cast(product_sk_id as string)
	,cast(angie_channel_sk_id as string)
	,partner_qr_cd
	,cast(site_id_dly as string)
	,count(1) as instances
	,count(distinct case when rita_pulsa > 0 then transaction_id end) hits--> trx hanya dihitung bila ada transaksi unlock pulsa
	,sum(coalesce(rita_pulsa,0)) gross_revenue --> angka ini cocok bila dicompare dengan table topup_base untuk RITA PULSA
	,sum(coalesce(rita_pulsa,0)+coalesce(markup_rita,0)+coalesce(p3_price_rita,0)) net_revenue
	FROM 
	(
		SELECT 
		a.trx_dt_sk_id
		,a.product_sk_id
		,a.transaction_id 
		,a.angie_channel_sk_id
		,b.partner_qr_cd
		,site_id_dly
		,sum(case when process_nm ='RITA_TOPUP' then unearned else 0 end )rita_pulsa
		,sum(case when process_nm ='MARKUP_RITA' then markup else 0 end )markup_rita
		,sum(case when process_nm ='RITA_P3PRICE_AMORT' then markup else 0 end )p3_price_rita
		FROM `data-dtptechm-prd-c7ca.dwh.revenue_base` a
			LEFT OUTER JOIN `data-bi-prd-935c.bi_stg.stg_daily_fav_site_dim` fav 
				ON fav.sbscrptn_ek_id = a.sbscrptn_ek_id AND cast(a.trx_dt_sk_id as date) = cast(fav.dt_id as date)
			---left join `data-dtptechm-prd-c7ca.dwh.product_dim` pd ON a.product_sk_id=pd.product_sk_id 
			left join `data-dtptechm-prd-c7ca.dwh.angie_hrchy_dim` b on a.angie_channel_sk_id=b.angie_hrchy_sk_id
			---left outer join `data-dtptechm-prd-c7ca.dwh.channel_dim` CD2 ON (CD2.channel_sk_id=b.mp3_channel_sk_id) 
			---left outer join `data-dtptechm-prd-c7ca.dwh.rprt_fltr_ref_ctgry` REF2 ON (ref2.ref_cd=CD2.channel_id and REF2.ref_type_cd = 'MP3')
		where cast(a.trx_dt_sk_id as date)=  vdt_id 
		and a.process_nm in 
		(
			'RITA_P3PRICE_AMORT',
			'MARKUP_RITA',
			'RITA_TOPUP' 
		)
		--and service_type='Regular' 
		and a.tool_of_trade_ind = 'N'
		--and product_id = 8 
		group by 1,2,3,4,5,6
	) x 
	group by 1,2,3,4,5,6,7,8,9;
	
	
-- 	-- [SND Funnel - ADDON & FORFEIT]
	
	DELETE FROM `data-bi-prd-935c.bi_mart.dm_snd_addon_forfeit` WHERE trx_dt_sk_id =  vdt_id;
	
	INSERT INTO `data-bi-prd-935c.bi_mart.dm_snd_addon_forfeit`
SELECT
  cast(fct.trx_dt_sk_id as date),
  cast(fct.angie_channel_sk_id as string) AS angie_hrchy_sk_id,
  ng.partner_qr_cd,
  fct.ret_trx_msisdn,
  fct.process_nm,
  fct.sbscrptn_msisdn,
  fct.transaction_id,
  cast(fct.product_sk_id as string),
  fav.site_id_dly,
  SUM(cast(fct.unearned as numeric)) AS unearned,
  SUM(cast(fct.gross_revenue as numeric)) AS gross_revenue,
  SUM(cast(fct.net_revenue as numeric))  AS net_revenue,
  SUM(
    CASE
      WHEN STRUCT(fct.process_nm, fct.revenue_src_ctgry) IN (
             SELECT AS STRUCT process_nm, revenue_src_ctgry
             FROM `data-dtptechm-prd-c7ca.dwh.demand_revenue_base_filter`
             WHERE net_amort_incl = 'Y'
           )
           AND fct.revenue_book_incl_ind = 'INCLUDE'
      THEN -1 * cast(fct.commission as numeric)
      ELSE 0
    END
  ) AS additional_amort,
  CURRENT_TIMESTAMP() AS created_dtm
FROM `data-dtptechm-prd-c7ca.dwh.revenue_base` fct
LEFT JOIN `data-dtptechm-prd-c7ca.dwh.angie_hrchy_dim` ng
  ON fct.angie_channel_sk_id = ng.angie_hrchy_sk_id
LEFT JOIN `data-bi-prd-935c.bi_stg.stg_daily_fav_site_dim` fav
  ON fav.sbscrptn_ek_id = fct.sbscrptn_ek_id
 AND  cast(fct.trx_dt_sk_id as date)   = cast(fav.dt_id as date)
WHERE
 cast(fct.trx_dt_sk_id as date)  = vdt_id and
  (
    (
      STRUCT(fct.process_nm, fct.revenue_src_ctgry) IN (
        SELECT AS STRUCT process_nm, revenue_src_ctgry
        FROM `data-dtptechm-prd-c7ca.dwh.demand_revenue_base_filter`
        WHERE net_revenue_incl = 'Y'
      )
      AND fct.gl_cd NOT IN (
        SELECT ref_cd
        FROM `data-dtptechm-prd-c7ca.dwh.rprt_fltr_ref_ctgry`
        WHERE ref_type_cd = 'ACCRUAL_GL_CODE'
      )
    )
    OR (
      STRUCT(fct.process_nm, fct.revenue_src_ctgry) IN (
        SELECT AS STRUCT process_nm, revenue_src_ctgry
        FROM `data-dtptechm-prd-c7ca.dwh.demand_revenue_base_filter`
        WHERE net_amort_incl = 'Y'
      )
      AND fct.revenue_book_incl_ind = 'INCLUDE'
    )
  )
  AND fct.process_nm IN ('SIM_FORFEIT','ADDON_REDEEM','ADDON_FORFEIT','ADDON_PULSA')
  AND fct.revenue_src_ctgry = 'Ret'
GROUP BY 1,2,3,4,5,6,7,8,9;

	-- [SND Funnel - FINAL TABLE]
	
	DELETE FROM `data-bi-prd-935c.bi_mart.project_ioh_tertiary_outlet`  where dt_sk_Id =  vdt_id;
	
	INSERT INTO `data-bi-prd-935c.bi_mart.project_ioh_tertiary_outlet` (dt_sk_id,dealer_sk_id,dealer_id,siteid_bnum,tertiary_category,tertiary_type,
			hits,main_price,amount,mth_id,created_dtm, source_nm)
	select 
	dt,
	angie_hrchy_sk_Id,
	partner_qr_cd,
	siteid_bnum,
	case 
		when package_type = 'RITA' then 'SALDO'
		else package_type
	end as tertiary_category,
	case
		when voucher_type = 'RITA PULSA' then 'RITA PULSA'
		when voucher_type = 'E TOP UP' then 'RITA SPV'
		when voucher_type = 'PHYSICAL PULSA' then 'UNLOCK PULSA'
		when package_type = 'UNLOCK' and voucher_type <> 'PHYSICAL PULSA' then 'UNLOCK SPV'
		when service_type = 'FRC BROADBAND' then 'SP DATA'
		when service_type <> 'FRC BROADBAND' then 'SP NON DATA'
		else 'NA'
	end as tertiary_type ,
	sum(instances),
	cast(sum(main_price) as numeric),
	cast(sum(amount) as numeric),
	date_trunc(dt, month) as mthid,
	current_timestamp(),
	'3AS'
	FROM 
	(
		select dt, cast(angie_hrchy_sk_Id as string)angie_hrchy_sk_Id, qr_cd as partner_qr_cd, siteid_bnum, sd_type, package_type, service_type, voucher_type, 
		hits_sidnum as instances, gross_revenue as main_price, net_revenue as amount
		from `data-bi-prd-935c.bi_mart.dm_snd_voucher` where sd_type = 'DEMAND' and dt =  vdt_id
		UNION ALL
		select dt, cast(angie_hrchy_sk_Id as string), partner_qr_cd,siteid_bnum, sd_type, 'FRC', report_rowname, null, 
		hits_sim_msisdn as instances, gross_revenue as main_price, net_revenue as amount 
		from `data-bi-prd-935c.bi_mart.dm_snd_demand_frc` where sd_type = 'DEMAND' and dt =  vdt_id
	) a
	group by 1,2,3,4,5,6;
	
-- 	--dump to secondary
	
	delete from `data-bi-prd-935c.bi_mart.project_ioh_secondary_outlet` where dt_sk_id =  vdt_id and secondary_category in ('FRC','UNLOCK');
	
	insert into `data-bi-prd-935c.bi_mart.project_ioh_secondary_outlet` (dt_sk_id,partner_type,msisdn,
	angie_hrchy_sk_id,partner_qr_cd,secondary_category,secondary_type,kpi_cnt)
	select 
	dt,
	'Ret',
	ret_msisdn,
	angie_hrchy_sk_Id,
	partner_qr_cd,
	package_type as secondary_category,
	case
		when voucher_type = 'PHYSICAL PULSA' then 'UNLOCK PULSA'
		when package_type = 'UNLOCK' and voucher_type <> 'PHYSICAL PULSA' then 'UNLOCK SPV'
		when service_type = 'FRC BROADBAND' then 'SP DATA'
		when service_type <> 'FRC BROADBAND' then 'SP NON DATA'
		else 'NA'
	end as secondary_type,
	sum(instances) as kpi_cnt
	FROM
	(
		select dt, angie_hrchy_sk_Id, qr_cd as partner_qr_cd, null ret_msisdn, siteid_bnum, sd_type, package_type, service_type, voucher_type, 
		hits_sidnum as instances, gross_revenue as main_price, net_revenue as amount
		from `data-bi-prd-935c.bi_mart.dm_snd_voucher` where sd_type = 'SUPPLY' AND package_type = 'UNLOCK' and dt =  vdt_id
		UNION ALL
		select dt, cast(angie_hrchy_sk_Id as string), partner_qr_cd, ret_msisdn, siteid_bnum, sd_type, 'FRC', report_rowname, null, 
		hits_sim_msisdn as instances, gross_revenue as main_price, net_revenue as amount 
		from `data-bi-prd-935c.bi_mart.dm_snd_demand_frc` where sd_type = 'SUPPLY' and dt =  vdt_id
	) a
	group by 1,2,3,4,5,6,7;
	
	
-- -- APPEND FOR FORFEIT AND ADDON to tertiary

	
	INSERT INTO `data-bi-prd-935c.bi_mart.project_ioh_tertiary_outlet` (dt_sk_id,dealer_sk_id,dealer_id,siteid_bnum,tertiary_category,tertiary_type,
			hits,main_price,amount,mth_id,created_dtm, source_nm)
	select 
	trx_dt_sk_id,
	angie_hrchy_sk_Id,
	partner_qr_cd,
	site_id_90 siteid_bnum,
	case 
		when process_nm IN ('ADDON_REDEEM','ADDON_FORFEIT','SIM_FORFEIT') then 'FRC'
		when process_nm = 'ADDON_PULSA' THEN 'SALDO'
	end as tertiary_category,
	process_nm as tertiary_type ,
	count(distinct transaction_id),
	sum(case when process_nm = 'ADDON_PULSA' THEN unearned else gross_revenue end) main_price,
	sum(case when process_nm = 'ADDON_PULSA' THEN unearned else coalesce(net_revenue,0) - coalesce(additional_amort,0) end) as amount,
	date_trunc(trx_dt_sk_id,month) as mthid,
	current_timestamp(),
	'3AS'
	FROM `data-bi-prd-935c.bi_mart.dm_snd_addon_forfeit` -- select * from `data-bi-prd-935c.bi_mart.dm_snd_addon_forfeit` limit 10 
	WHERE trx_dt_sk_id =  vdt_id 
	group by 1,2,3,4,5,6;
	
-- 	-- [SND Funnel - EVC]
	
	INSERT INTO `data-bi-prd-935c.bi_mart.mart_evc`
	SELECT 
	cast(a.topup_dt_sk_id as date),
	a.topup_source,
	a.topup_type,
	a.voucher_id,
	a.category_1,
	a.revenue_category,
	/*
	--- ternyata untuk topup_type = 'NG' ada yg BANK untuk Non PULSA
	case when a.topup_type = 'BANKING' then bank.evc_bank_sk_id else b.evc_dealer_sk_Id end as evc_dealer_sk_Id,
	case when a.topup_type = 'BANKING' then institution_id else c.hp_no end as dealer_id,
	case when a.topup_type = 'BANKING' then bank.institution_name else c.dealer_name end as dealer_nm,
	*/
	case when bank.serial_number is not null and bank.evc_bank_sk_id <> -2 AND topup_type in ('BANKING','NG','EAD') then bank.evc_bank_sk_id else b.evc_dealer_sk_Id end as evc_dealer_sk_Id,
	case when bank.serial_number is not null and bank.evc_bank_sk_id <> -2 AND topup_type in ('BANKING','NG','EAD') then bank.institution_id else c.hp_no end as dealer_id,
	case when bank.serial_number is not null and bank.evc_bank_sk_id <> -2 AND topup_type in ('BANKING','NG','EAD') then bank.institution_name else c.dealer_name end as dealer_nm,


	a.sbscrptn_msisdn,
	cast(a.sbscrptn_ek_id as string),
	fav.site_id_dly,
	sum(gross_revenue) as gross_revenue,
	sum(coalesce(comm_3as,0)+coalesce(comm_3as_bonus,0)) as comm_3as,
	sum(net_revenue) as net_revenue,
	sum(pulsa) as pulsa,
	sum(src_value) as src_value,

	--- broadband
	sum(case when coalesce(revenue_type,'NA') = 'BROADBAND' then gross_revenue else 0 end) as Broadband_gross_rev,
	sum(case when coalesce(revenue_type,'NA') = 'BROADBAND' then coalesce(comm_3as,0)+coalesce(comm_3as_bonus,0) else 0 end) as Broadband_comm_3as,
	sum(case when coalesce(revenue_type,'NA') = 'BROADBAND' then net_revenue else 0 end) as Broadband_net_rev,

	count(1) record_cnt,
	current_timestamp() as created_dtm, 
	case 
	when bank.serial_number is not null AND topup_type in ('BANKING','NG') then 'BANK' 
	when b.product_serial_no is not null then topup_type else 'OTHERS'
	end as source_nm
	--a.*, b.src_value, b.*, c.*
	FROM `data-dtptechm-prd-c7ca.dwh.sbscrptn_topup_base` a
	left outer join `data-bi-prd-935c.bi_stg.stg_daily_fav_site_dim` fav 
				ON fav.sbscrptn_ek_id = a.sbscrptn_ek_id ---AND a.topup_dt_sk_id = fav.dt 
	left outer join `data-dtptechm-prd-c7ca.dwh.evc_dealer_recharge_fct` b ON a.voucher_id = b.product_serial_no and cast(b.recharge_dt_sk_id as date)= cast(a.topup_dt_sk_id as date) and cast(b.recharge_dt_sk_id as date)= vdt_id 
	left outer join `data-dtptechm-prd-c7ca.dwh.evc_dealer_dim` c ON b.evc_dealer_sk_id = c.evc_dealer_sk_id 
		left outer join (
			select distinct serial_number, evc_bank_sk_id, institution_id, institution_name
			from `data-dtptechm-prd-c7ca.dwh.evc_recharge_bank_fct` a
					left outer join `data-dtptechm-prd-c7ca.dwh.evc_h2h_institution_dim` b ON a.evc_bank_sk_id = b.evc_h2h_institution_sk_Id 
		 where cast(a.transaction_dt_sk_id as date) = vdt_id
		) bank ON bank.serial_number = a.voucher_id
	where cast(a.topup_dt_sk_id as date) = vdt_id 
	--and upper(a.category_1)<>'REGULAR'
	and upper(a.topup_group)<>'PHYSICAL'
	group by 1,2,3,4,5,6,7,8,9,10,11,12,23;
	
-- 	-- [SND Funnel - EVC Tertiary]
	
	delete from `data-bi-prd-935c.bi_mart.project_ioh_tertiary_outlet`  where dt_sk_id =  vdt_id AND source_nm in ('VTRI','BANKING');
	
	INSERT INTO `data-bi-prd-935c.bi_mart.project_ioh_tertiary_outlet` (dt_sk_id,dealer_sk_id,dealer_id,siteid_bnum,tertiary_category,tertiary_type,hits,main_price,amount,mth_id,created_dtm, source_nm)
	SELECT 
	topup_dt_sk_id, 
	cast(evc_dealer_sk_id as string),
	dealer_id,
	site_id_90 as siteid_bnum,
	case when source_nm = 'BANK' THEN source_nm ELSE 'SALDO V3' end as tertiary_category,
	'ETOPUP '||case when category_1 = 'Regular' then 'PULSA' else 'NON PULSA' end as tertiary_category,
	count(distinct voucher_id) as hits,
	cast(sum(case when category_1 = 'Regular' then pulsa else gross_revenue end) as numeric) as gross_rev,
	cast(sum(case when category_1 = 'Regular' then 
			case when source_nm = 'BANK' then pulsa else src_value end
		else net_revenue end) as numeric) as net_revenue,
	date_trunc(topup_dt_sk_id, month),
	current_timestamp(),
	source_nm
	FROM `data-bi-prd-935c.bi_mart.mart_evc` a
	WHERE topup_dt_sk_id =  vdt_id 
	and ((topup_source not in ('ETOPUP-NG','ETOPUP-ODP','ETOPUP-RITA','RITA Adjustment','ETOPUP-ADDON')
		and source_nm <> 'BANK') 
			or source_nm = 'BANK')
	GROUP BY 1,2,3,4,5,6,12;
	
-- 	-- [SND Funnel - BANK Secondary]
	delete from `data-bi-prd-935c.bi_mart.project_ioh_secondary_outlet` where dt_sk_id =  vdt_id and secondary_category in ('BANK');
	
	INSERT INTO `data-bi-prd-935c.bi_mart.project_ioh_secondary_outlet`(dt_sk_id,partner_type,msisdn,
	angie_hrchy_sk_id,partner_qr_cd,secondary_category,secondary_type,value)
	SELECT 
	topup_dt_sk_id, 
	'Ret',
	cast(null as string),
	cast(evc_dealer_sk_id as string),
	dealer_id,
	'BANK' as secondary_category,
	'ETOPUP'||case when category_1 = 'Regular' then 'PULSA' else 'NON PULSA' end as secondary_type,
	cast(sum(case when category_1 = 'Regular' then 
			case when source_nm = 'BANK' then pulsa else src_value end
		else net_revenue end) as bignumeric) as value
	FROM `data-bi-prd-935c.bi_mart.mart_evc` a
	WHERE topup_dt_sk_id =  vdt_id
	AND source_nm = 'BANK'
	GROUP BY 1,2,3,4,5,6,7;
	
-- 	-- [SND Funnel - BANK Primary]
	
	delete from `data-bi-prd-935c.bi_mart.project_ioh_primary_outlet` where dt_sk_id =  vdt_id AND primary_category = 'BANK';
	insert into `data-bi-prd-935c.bi_mart.project_ioh_primary_outlet` (dt_sk_id,partner_type,kpi_name,msisdn,angie_hrchy_sk_id,partner_qr_cd,primary_category,primary_type,hierarchy_type, value)
	select 
	dt_sk_id,
	partner_type,
	kpi_name,
	msisdn,
	angie_hrchy_sk_id,
	partner_qr_cd,
	secondary_category primary_category,
	secondary_type primary_type,
	hierarchy_type, 
	value
	from `data-bi-prd-935c.bi_mart.project_ioh_secondary_outlet` fct
	where dt_sk_id =  vdt_id AND secondary_category in ('BANK');
	
-- 	--[SND Funnel - Primary KPK & Blank Voucher]
	
	delete from `data-bi-prd-935c.bi_mart.project_ioh_primary_outlet` where dt_sk_id =  vdt_id AND hierarchy_type like '%-ERP';
	
	insert into `data-bi-prd-935c.bi_mart.project_ioh_primary_outlet` (dt_sk_id,partner_type,kpi_name,msisdn,partner_qr_cd,primary_category,primary_type,hierarchy_type, value)
	select 
	do_date, 
	SPLIT(mp3_name, '_')[OFFSET(ARRAY_LENGTH(SPLIT(mp3_name, '_')) - 1)]
partner_type,
	cast(null as string),
	cast(null as string),
	mp3_number,
	'FRC',
	'KPK',
	(CASE WHEN SPLIT(mp3_name, '_')[OFFSET(ARRAY_LENGTH(SPLIT(mp3_name, '_')) - 1)]
 = 'MP3' 
			then 'ANGIE' else 'OTHERS' end)||'-'||'ERP' as hierarchy_type,
	count(distinct SIM||msisdn) as qty
	FROM `data-dtptechm-prd-c7ca.dwh.erp_sp_fct_new`
	where do_date =  vdt_id
	group by 1,2,3,4,5,6,7,8;


	insert into `data-bi-prd-935c.bi_mart.project_ioh_primary_outlet`(dt_sk_id,partner_type,kpi_name,msisdn,partner_qr_cd,primary_category,primary_type,hierarchy_type, value)
	select 
	do_date, 
	SPLIT(mp3_name, '_')[OFFSET(ARRAY_LENGTH(SPLIT(mp3_name, '_')) - 1)]
partner_type,
	cast(null as string),
	cast(null as string),
	mp3_number,
	'UNLOCK',
	'BLANK VOUCHER',
	(CASE WHEN SPLIT(mp3_name, '_')[OFFSET(ARRAY_LENGTH(SPLIT(mp3_name, '_')) - 1)]
 = 'MP3' 
			then 'ANGIE' else 'OTHERS' end)||'-'||'ERP' as hierarchy_type,
	count(1) as qty ---> angka ini masih belum benar
	FROM `data-dtptechm-prd-c7ca.dwh.erp_vouchers_fct_new`
	where do_date =  vdt_id
	group by 1,2,3,4,5,6,7,8;

