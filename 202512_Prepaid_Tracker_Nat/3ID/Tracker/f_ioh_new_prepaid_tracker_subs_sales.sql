DECLARE vdt_id DATE DEFAULT @vdt_id;

    
    delete from `data-bi-prd-935c.bi_mart.kpi_national_tracker_dly` 
	where brand = 'TRI' and kpi_id in 
	(
	'SLS0001'
	) and dt_id =vdt_id  ;
 


 
	insert into `data-bi-prd-935c.bi_mart.kpi_national_tracker_dly` 
	select 
	'TRI' brand
	,''kpi_code
	,'MTD' flag
	,sum(amount)-- value
	,current_timestamp()
	,'SLS0001' kpi_id
	,trx_dt_Sk_id
	from 
	`data-bi-prd-935c.bi_mart.mart_sales_productivity`
		where flag like '%primary%'
		and trx_dt_sk_id =vdt_id
group by  1,2,3,5,6,7 ; 
 


	---- secondary 
 
	delete from `data-bi-prd-935c.bi_mart.kpi_national_tracker_dly` 
	where brand = 'TRI' and kpi_id in 
	(
	'SLS0002'
	) and dt_id =vdt_id  ;
 

 
	insert into `data-bi-prd-935c.bi_mart.kpi_national_tracker_dly` 
	select 
	'TRI' brand
	,''kpi_code
	,'MTD' flag
	,sum(coalesce(value,0)) kpi_value -- value
	,current_timestamp()
	,'SLS0002' kpi_id
	,cast(vdt_id as date)

from `data-bi-prd-935c.bi_mart.project_ioh_secondary_outlet` a
left join `data-dtptechm-prd-c7ca.dwh.angie_hrchy_dim` b 
on b.partner_qr_cd = a.partner_qr_cd --and b.ret_hierarchy_type = 'ANGIE' and b.hrchy_type = 'Retailer'
left join 
(select ret_qr_cd,site_id from 
(
select dt,ret_qr_cd,site_id,row_number() over (partition by ret_qr_cd order by dt desc) rnk
from `data-bi-prd-935c.bi_mart.stg_v_map_tgt_ret_details_hist`
where  site_id <>''
) x where rnk=1
) c on a.partner_qr_cd=c.ret_qr_cd 
where dt_sk_id=vdt_id
and secondary_category='SALDO'
and a.hierarchy_type='ANGIE'
and secondary_type in ('PRT_CUANWEB','Purchase from CAN','Purchase from MP3')
---and upper(mp3_location) not in ('POOL','DVM BM','SIM ONLINE','BSM TRI OFFICIAL STORE','3 BUSINESS','3 STORE','SOUTH JAKARTA TEST BM')
group by  1,2,3,5,6,7 ; 





	---- tertiary all 
 
	delete from `data-bi-prd-935c.bi_mart.kpi_national_tracker_dly` 
	where brand = 'TRI' and kpi_id in 
	(
	'SLS0003'
	) and dt_id =vdt_id  ;
 

 
	insert into `data-bi-prd-935c.bi_mart.kpi_national_tracker_dly` 
	select 
	'TRI' brand
	,''kpi_code
	,'MTD' flag
	,sum(amount)-- value
	,current_timestamp()
	,'SLS0003' kpi_id
	,cast(vdt_id as date)
	from `data-bi-prd-935c.bi_mart.project_ioh_tertiary_outlet` a 
			left join 
			`data-dtptechm-prd-c7ca.dwh.angie_hrchy_dim` hd on a.dealer_id = hd.partner_qr_cd
			where coalesce(upper(hd.mp3_location),'CENTRAL WEST NORTH JKT') NOT IN ('DVM BM','3 STORE','NA','POOL','SIM ONLINE','SOUTH JAKARTA TEST BM','ADVCREDIT','FUT ANGIE 2.0','MODCHAN','BSM TRI OFFICIAL STORE')
			and dt_sk_id  		= vdt_id

			group by  1,2,3,5,6,7 ; 




	---- tertiarytraditional
 
	delete from `data-bi-prd-935c.bi_mart.kpi_national_tracker_dly` 
	where brand = 'TRI' and kpi_id in 
	(
	'SLS0004'
	) and dt_id =vdt_id  ;
 

 
	insert into `data-bi-prd-935c.bi_mart.kpi_national_tracker_dly` 
	select 
	'TRI' brand
	,''kpi_code
	,'MTD' flag
	,sum(amount)-- value
	,current_timestamp()
	,'SLS0004' kpi_id
	,cast(vdt_id as date)
	from `data-bi-prd-935c.bi_mart.project_ioh_tertiary_outlet` a 
			left join 
			`data-dtptechm-prd-c7ca.dwh.angie_hrchy_dim` hd on a.dealer_id = hd.partner_qr_cd
			where coalesce(upper(hd.mp3_location),'CENTRAL WEST NORTH JKT') NOT IN ('DVM BM','3 STORE','NA','POOL','SIM ONLINE','SOUTH JAKARTA TEST BM','ADVCREDIT','FUT ANGIE 2.0','MODCHAN','BSM TRI OFFICIAL STORE')
			and dt_sk_id  		= vdt_id
and source_nm='3AS'
			group by  1,2,3,5,6,7 ; 




	---- tertiarytraditional
 
	delete from `data-bi-prd-935c.bi_mart.kpi_national_tracker_dly` 
	where brand = 'TRI' and kpi_id in 
	(
	'SLS0005'
	) and dt_id =vdt_id  ;
 

 
	insert into `data-bi-prd-935c.bi_mart.kpi_national_tracker_dly` 
	select 
	'TRI' brand
	,''kpi_code
	,'MTD' flag
	,sum(amount)-- value
	,current_timestamp()
	,'SLS0005' kpi_id
	,cast(vdt_id as date)
	from `data-bi-prd-935c.bi_mart.project_ioh_tertiary_outlet` a 
			left join 
			`data-dtptechm-prd-c7ca.dwh.angie_hrchy_dim` hd on a.dealer_id = hd.partner_qr_cd
			where coalesce(upper(hd.mp3_location),'CENTRAL WEST NORTH JKT') NOT IN ('DVM BM','3 STORE','NA','POOL','SIM ONLINE','SOUTH JAKARTA TEST BM','ADVCREDIT','FUT ANGIE 2.0','MODCHAN','BSM TRI OFFICIAL STORE')
			and dt_sk_id  		= vdt_id
and source_nm<>'3AS'
			group by  1,2,3,5,6,7 ; 


-- tartiary traditional
 
	delete from `data-bi-prd-935c.bi_mart.kpi_national_tracker_dly` 
	where brand = 'TRI' and kpi_id in 
	(
	'SLS0006'
	) and dt_id =vdt_id  ;
 

 
	insert into `data-bi-prd-935c.bi_mart.kpi_national_tracker_dly` 
	select 
	'TRI' brand
	,''kpi_code
	,'MTD' flag
	,sum(amount)-- value
	,current_timestamp()
	,'SLS0006' kpi_id
	,cast(vdt_id as date)
	from `data-bi-prd-935c.bi_mart.project_ioh_tertiary_outlet` a 
			left join 
			`data-dtptechm-prd-c7ca.dwh.angie_hrchy_dim` hd on a.dealer_id = hd.partner_qr_cd
			where coalesce(upper(hd.mp3_location),'CENTRAL WEST NORTH JKT') NOT IN ('DVM BM','3 STORE','NA','POOL','SIM ONLINE','SOUTH JAKARTA TEST BM','ADVCREDIT','FUT ANGIE 2.0','MODCHAN','BSM TRI OFFICIAL STORE')
			and dt_sk_id  		= vdt_id
and source_nm='3AS'
			group by  1,2,3,5,6,7 ; 




-- tartiary traditional pulsa
 
	delete from `data-bi-prd-935c.bi_mart.kpi_national_tracker_dly` 
	where brand = 'TRI' and kpi_id in 
	(
	'SLS0007'
	) and dt_id =vdt_id  ;
 

 
	insert into `data-bi-prd-935c.bi_mart.kpi_national_tracker_dly` 
	select 
	'TRI' brand
	,''kpi_code
	,'MTD' flag
	,sum(amount)-- value
	,current_timestamp()
	,'SLS0007' kpi_id
	,cast(vdt_id as date)
	from `data-bi-prd-935c.bi_mart.project_ioh_tertiary_outlet` a 
			left join 
			`data-dtptechm-prd-c7ca.dwh.angie_hrchy_dim` hd on a.dealer_id = hd.partner_qr_cd
			where coalesce(upper(hd.mp3_location),'CENTRAL WEST NORTH JKT') NOT IN ('DVM BM','3 STORE','NA','POOL','SIM ONLINE','SOUTH JAKARTA TEST BM','ADVCREDIT','FUT ANGIE 2.0','MODCHAN','BSM TRI OFFICIAL STORE')
			and dt_sk_id  		= vdt_id
and source_nm='3AS' and tertiary_type like '%PULSA%'
			group by  1,2,3,5,6,7 ; 



-- tartiary traditional non pulsa
 
	delete from `data-bi-prd-935c.bi_mart.kpi_national_tracker_dly` 
	where brand = 'TRI' and kpi_id in 
	(
	'SLS0008'
	) and dt_id =vdt_id  ;
 

 
	insert into `data-bi-prd-935c.bi_mart.kpi_national_tracker_dly` 
	select 
	'TRI' brand
	,''kpi_code
	,'MTD' flag
	,sum(amount)-- value
	,current_timestamp()
	,'SLS0008' kpi_id
	,cast(vdt_id as date)
	from `data-bi-prd-935c.bi_mart.project_ioh_tertiary_outlet` a 
			left join 
			`data-dtptechm-prd-c7ca.dwh.angie_hrchy_dim` hd on a.dealer_id = hd.partner_qr_cd
			where coalesce(upper(hd.mp3_location),'CENTRAL WEST NORTH JKT') NOT IN ('DVM BM','3 STORE','NA','POOL','SIM ONLINE','SOUTH JAKARTA TEST BM','ADVCREDIT','FUT ANGIE 2.0','MODCHAN','BSM TRI OFFICIAL STORE')
			and dt_sk_id  		= vdt_id
and source_nm='3AS' and tertiary_type not like '%PULSA%'
			group by  1,2,3,5,6,7 ; 



-- tartiary bank
 
	delete from `data-bi-prd-935c.bi_mart.kpi_national_tracker_dly` 
	where brand = 'TRI' and kpi_id in 
	(
	'SLS0010'
	) and dt_id =vdt_id  ;
 

 
	insert into `data-bi-prd-935c.bi_mart.kpi_national_tracker_dly` 
	select 
	'TRI' brand
	,''kpi_code
	,'MTD' flag
	,sum(amount)-- value
	,current_timestamp()
	,'SLS0010' kpi_id
	,cast(vdt_id as date)
	from `data-bi-prd-935c.bi_mart.project_ioh_tertiary_outlet` a 
			left join 
			`data-dtptechm-prd-c7ca.dwh.angie_hrchy_dim` hd on a.dealer_id = hd.partner_qr_cd
			where coalesce(upper(hd.mp3_location),'CENTRAL WEST NORTH JKT') NOT IN ('DVM BM','3 STORE','NA','POOL','SIM ONLINE','SOUTH JAKARTA TEST BM','ADVCREDIT','FUT ANGIE 2.0','MODCHAN','BSM TRI OFFICIAL STORE')
			and dt_sk_id  		= vdt_id
and tertiary_category ='BANK' --- not like '%PULSA%'
			group by  1,2,3,5,6,7 ; 



-- tartiary bank pulsa
 
	delete from `data-bi-prd-935c.bi_mart.kpi_national_tracker_dly` 
	where brand = 'TRI' and kpi_id in 
	(
	'SLS0011'
	) and dt_id =vdt_id  ;
 

 
	insert into `data-bi-prd-935c.bi_mart.kpi_national_tracker_dly` 
	select 
	'TRI' brand
	,''kpi_code
	,'MTD' flag
	,sum(amount)-- value
	,current_timestamp()
	,'SLS0011' kpi_id
	,cast(vdt_id as date)
	from `data-bi-prd-935c.bi_mart.project_ioh_tertiary_outlet` a 
			left join 
			`data-dtptechm-prd-c7ca.dwh.angie_hrchy_dim` hd on a.dealer_id = hd.partner_qr_cd
			where coalesce(upper(hd.mp3_location),'CENTRAL WEST NORTH JKT') NOT IN ('DVM BM','3 STORE','NA','POOL','SIM ONLINE','SOUTH JAKARTA TEST BM','ADVCREDIT','FUT ANGIE 2.0','MODCHAN','BSM TRI OFFICIAL STORE')
			and dt_sk_id  		= vdt_id
and tertiary_category ='BANK'  and tertiary_type='ETOPUP PULSA'  
			group by  1,2,3,5,6,7 ; 



-- tartiary bank non  pulsa
 
	delete from `data-bi-prd-935c.bi_mart.kpi_national_tracker_dly` 
	where brand = 'TRI' and kpi_id in 
	(
	'SLS0012'
	) and dt_id =vdt_id  ;
 


 
	insert into `data-bi-prd-935c.bi_mart.kpi_national_tracker_dly` 
	select 
	'TRI' brand
	,''kpi_code
	,'MTD' flag
	,sum(amount)-- value
	,current_timestamp()
	,'SLS0012' kpi_id
	,cast(vdt_id as date)
	from `data-bi-prd-935c.bi_mart.project_ioh_tertiary_outlet` a 
			left join 
			`data-dtptechm-prd-c7ca.dwh.angie_hrchy_dim` hd on a.dealer_id = hd.partner_qr_cd
			where coalesce(upper(hd.mp3_location),'CENTRAL WEST NORTH JKT') NOT IN ('DVM BM','3 STORE','NA','POOL','SIM ONLINE','SOUTH JAKARTA TEST BM','ADVCREDIT','FUT ANGIE 2.0','MODCHAN','BSM TRI OFFICIAL STORE')
			and dt_sk_id  		= vdt_id
and tertiary_category ='BANK'  and tertiary_type='ETOPUP NON PULSA'  
			group by  1,2,3,5,6,7 ; 

-- stock trisakti mp3 
 
	delete from `data-bi-prd-935c.bi_mart.kpi_national_tracker_dly` 
	where brand = 'TRI' and kpi_id in 
	(
	'SLS0030'
	) and dt_id =vdt_id  ;
 


 
	insert into `data-bi-prd-935c.bi_mart.kpi_national_tracker_dly` 
	select 
	'TRI' brand
	,''kpi_code
	,'MTD' flag
	,sum(kpi_value)-- value
	,current_timestamp()
	,'SLS0030' kpi_id
	,cast(snp_dt_sk_id as date)
from `data-dtptechm-prd-c7ca.dwh.prt_daily_channel_movement_fct`			
where kpi_name like 'DB Closing Balance'			
and partner_type in ('MP3') 			
and cast(snp_dt_sk_id as date)  =vdt_id
			group by  1,2,3,5,6,7 ; 




-- stock retailer 
 
	delete from `data-bi-prd-935c.bi_mart.kpi_national_tracker_dly` 
	where brand = 'TRI' and kpi_id in 
	(
	'SLS0031'
	) and dt_id =vdt_id  ;
 


 
select 
	'TRI' brand
	,''kpi_code
	,'MTD' flag
	,sum(kpi_value)-- value
	,current_timestamp()
	,'SLS0031' kpi_id
	,cast(vdt_id as date)
 from 
(
-- Stock 3sakti retailer 
select sum(kpi_value)kpi_value  from 			
`data-dtptechm-prd-c7ca.dwh.prt_daily_channel_movement_fct`			
	where kpi_name like 'DB Closing Balance'
	and partner_type='Retailer'			
	and cast(snp_dt_sk_id as date) =vdt_id
	union all 
	--- stock phyiscal  retailer
	select		
	 sum(netnetrevenue) --  as netnetrevenue				
	from `data-dtptechm-prd-c7ca.dwh_olap.revenue_base_special_summary` 				
	where cast(trx_dt_sk_id as date) =vdt_id  ----(20220131,20220228,20220331,20220430,20220531,20220630,20220731,20220831,20220930,20221031,20221130,20221231,20230131, 20230228 )				
	  and report_tabname = 'Stock'				
	-- and service_type_name = 'BROADBAND'				
)stock
			group by  1,2,3,5,6,7 ; 

	delete from `data-bi-prd-935c.bi_mart.kpi_national_tracker_dly` 
	where brand = 'TRI' and kpi_id in 
	(
	'SLS0032'
	) and dt_id =vdt_id  ;
 

insert into `data-bi-prd-935c.bi_mart.kpi_national_tracker_dly` 
	select 
	'TRI' brand
	,''kpi_code
	,'MTD' flag
,sum(stock)/(sum(demand)/31) 
	,current_timestamp()
	,'SLS0032'
	,cast(vdt_id as date)
from 
(
	select  sum(netnetrevenue)as stock,0 as demand
	from `data-dtptechm-prd-c7ca.dwh_olap.revenue_base_special_summary` 
	where cast(trx_dt_sk_id as date) in (vdt_id) 
	and report_tabname = 'Stock'
	-- and service_type_name = 'BROADBAND'
	and report_rowname ='SIM'
	union all 
	--- demand sp 30 days
	select 0 as stock,	sum(net_revenue)as demand			
	from `data-dtptechm-prd-c7ca.dwh.revenue_base_summary`			
	where  cast(month_sk_id as date)<='9999-12-31' and
	parse_date('%Y%m%d',cast(dt_sk_id as string)) between date_sub(vdt_id, interval 30 day) and vdt_id  

	--  and report_tabname = 'Demand'			
	-- and service_type_name = 'BROADBAND'			
	and process_nm in 			
	(			
	'SIM_DEMAND')--,'SIM_FORFEIT') 		
	--'RITA',			
	--'VOUCHER_DEMAND','VOUCHER_FORFEIT'			
	 --and tool_of_trade_ind='N' 			
	and product_id=8			
) x
group by  1,2,3,5,6,7  ;

delete from `data-bi-prd-935c.bi_mart.kpi_national_tracker_dly` 
	where brand = 'TRI' and kpi_id in 
	(
	'SLS0033'
	) and dt_id =vdt_id  ;
 


insert into `data-bi-prd-935c.bi_mart.kpi_national_tracker_dly` 
	select 
	'TRI' brand
	,''kpi_code
	,'MTD' flag
,sum(stock)/(sum(demand)/31) 
	,current_timestamp()
	,'SLS0033'
	,cast(vdt_id as date)

from
(
select  sum(netnetrevenue)as stock,0 as demand
	from `data-dtptechm-prd-c7ca.dwh_olap.revenue_base_special_summary` 
	where cast(trx_dt_sk_id as date) in (vdt_id) 
	and report_tabname = 'Stock'
	-- and service_type_name = 'BROADBAND'
	and report_rowname ='VOUCHER'
	union all 
	--- demand sp 30 days
	select 0 as stock,	sum(net_revenue)as demand			
	from `data-dtptechm-prd-c7ca.dwh.revenue_base_summary`			
	where  cast(month_sk_id as date) <='9999-12-01' and
	parse_date('%Y%m%d',cast(dt_sk_id as string)) between date_sub(vdt_id,interval 30 day) and vdt_id 

	--  and report_tabname = 'Demand'			
	-- and service_type_name = 'BROADBAND'			
	and process_nm in 			
	(			
			
	'RITA',			
	'VOUCHER_DEMAND' ) 			
	 --and tool_of_trade_ind='N' 			
	and product_id=8		
	union all  --stock retailer 3 sakti 
	select  sum(kpi_value)  as stock , 0  as demand  from 				
	`data-dtptechm-prd-c7ca.dwh.prt_daily_channel_movement_fct`				
	where kpi_name like 'DB Closing Balance'				
	and partner_type in ('Retailer') 				
	and cast(snp_dt_sk_id as date)  in (vdt_id)
	-- pulsa 
union all 	select 		0 as stock, 
	sum(case when process_nm='BFF_CASHBACK_AMORTIZATION' and service_type_category_1='Regular' then coalesce(commission,0)		
	when service_type_category_1='Regular' THEN coalesce(unearned,0)-coalesce(commission,0)		
	else coalesce(net_revenue,0) end)/1.11  
	as demand		
	from `data-dtptechm-prd-c7ca.dwh.revenue_base_summary` rb		
	where cast(month_sk_id as date) <='9999-12-01' and parse_date('%Y%m%d',cast(dt_sk_id as string))  between date_sub(vdt_id,interval 30 day) and vdt_id 		
	and process_nm IN ('BFF_CASHBACK_AMORTIZATION' ,'UNBOOKED_RECHARGE','TOPUP','RITA')		
	--and rb.tool_of_trade_ind='N'		
	and rb.product_id = 8 		
	and service_type_category_1='Regular' --limit 10 		
	and revenue_source_indicator in 		
	(		
	'RITA',		
	'RITA Adjustment'				
	)		
) x 
;

delete from 
`data-bi-prd-935c.bi_mart.dm_vtri_modchan`
where recharge_dt_sk_id =vdt_id; 

insert into 
`data-bi-prd-935c.bi_mart.dm_vtri_modchan`	
---WITH (appendonly=true, compresstype=zlib, compresslevel=3) AS	
select	
cast(recharge_dt_sk_id as date) as recharge_dt_sk_id,	
 refr.category,	
 (case when prd.ref_cd is not null then 'Non Pulsa' Else 'Pulsa' end) as product_type,	
 count(1) as Stock_Out_Count,	
 sum(fct.src_value) as Stock_Aggregation_IDR	
  from  `data-dtptechm-prd-c7ca.dwh.evc_dealer_recharge_fct`  fct	
  join  `data-dtptechm-prd-c7ca.dwh.rprt_fltr_ref_ctgry`  rfrc on (fct.evc_acct_rec_stock_sk_id = rfrc.rprt_fltr_ref_ctgry_sk_id 	
 and ref_type_cd = 'EVC ACCT TRA ERP STOCK DIM'	
 and category = 'VO-ELC')	
join `data-dtptechm-prd-c7ca.dwh.evc_dealer_dim`  edd  on (fct.evc_dealer_sk_id = edd.evc_dealer_sk_id	
 and edd.evc_model_sk_id = 5) ----retailer	
  join  `data-dtptechm-prd-c7ca.dwh.evc_dealer_dim`edd_dc on edd_dc.evc_dealer_sk_id = edd.dc_sk_id  	
  left join (select distinct ctgry_ref_prnt	
from `data-dtptechm-prd-c7ca.dwh.rprt_fltr_ref_ctgry` where ref_type_cd = 'EVC Modern Channel') refmod 	
  on edd_dc.dc_hp_no = refmod.ctgry_ref_prnt 	
  join  `data-dtptechm-prd-c7ca.dwh.date_dim` dt  on dt.date_sk_id<>-2 and (cast(fct.recharge_dt_sk_id as date) = parse_date('%Y%m%d',cast(dt.date_sk_id as string)))	
  left join `data-dtptechm-prd-c7ca.dwh.rprt_fltr_ref_ctgry` prd on prd.ref_type_cd = 'EVC VTRI Package Denom' and prd.ref_cd = cast(fct.src_value as string)	
  left join (select distinct ctgry_ref_prnt, category	
from `data-dtptechm-prd-c7ca.dwh.rprt_fltr_ref_ctgry` where ref_type_cd = 'EVC Modern Channel') refr on refr.ctgry_ref_prnt = edd.dc_hp_no	
  where fct.stat_code = 0	
 and fct.response_code = '00000'	
 and cast(fct.recharge_dt_sk_id as date) =vdt_id 
 and (refmod.ctgry_ref_prnt is not null or upper(edd_dc.dealer_name) like '%MODERN%')	
group by	
  1,2,3	;

 

-- tartiary online all 
 
delete from `data-bi-prd-935c.bi_mart.kpi_national_tracker_dly` 
	where brand = 'TRI' and kpi_id in 
	(
	'SLS0018'
	) and dt_id =vdt_id  ;

 

 

insert into `data-bi-prd-935c.bi_mart.kpi_national_tracker_dly` 
	select 
	'TRI' brand
	,''kpi_code
	,'MTD' flag
	, sum(stock_aggregation_idr) -- value
	,current_timestamp()
	,'SLS0018' kpi_id ---all
	,cast(vdt_id as date) from 
	`data-bi-prd-935c.bi_mart.dm_vtri_modchan`
	where recharge_dt_sk_id 
	= vdt_id
	and category='Mochan Online'
	group by  1,2,3,5,6,7 ; 

 


 
-- tartiary online all 
	delete from `data-bi-prd-935c.bi_mart.kpi_national_tracker_dly` 
	where brand = 'TRI' and kpi_id in 
	(
	'SLS0019'
	) and dt_id =vdt_id  ;

 

 
	insert into `data-bi-prd-935c.bi_mart.kpi_national_tracker_dly` 
	select 
	'TRI' brand
	,''kpi_code
	,'MTD' flag
	, sum(stock_aggregation_idr) -- value
	,current_timestamp()
	,'SLS0019' kpi_id --pulsa 
 	,cast(vdt_id as date) from 
	`data-bi-prd-935c.bi_mart.dm_vtri_modchan`
	where recharge_dt_sk_id = vdt_id
	and category='Mochan Online' and product_type='Pulsa'
	group by  1,2,3,5,6,7 ;

 
 
 
-- tartiary online all 
	delete from `data-bi-prd-935c.bi_mart.kpi_national_tracker_dly` 
	where brand = 'TRI' and kpi_id in 
	(
	'SLS0020'
	) and dt_id =vdt_id  ;




	insert into `data-bi-prd-935c.bi_mart.kpi_national_tracker_dly` 
	select 
	'TRI' brand
	,''kpi_code
	,'MTD' flag
	, sum(stock_aggregation_idr) -- value
	,current_timestamp()
	,'SLS0020' kpi_id --pulsa 
 	,cast(vdt_id as date) from 
	`data-bi-prd-935c.bi_mart.dm_vtri_modchan`
	where recharge_dt_sk_id 
	= vdt_id
	and category='Mochan Online' and product_type<>'Pulsa'
	group by  1,2,3,5,6,7;
  




-- tartiary online all 
 
	delete from `data-bi-prd-935c.bi_mart.kpi_national_tracker_dly` 
	where brand = 'TRI' and kpi_id in 
	(
	'SLS0015'
	) and dt_id =vdt_id;



insert into `data-bi-prd-935c.bi_mart.kpi_national_tracker_dly` 
	select 
	'TRI' brand
	,''kpi_code
	,'MTD' flag
	,sum(amt)-- value
	,current_timestamp()
	,'SLS0015' kpi_id
	,cast(vdt_id as date)
		from
		(
		select sum(amount)amt
			from `data-bi-prd-935c.bi_mart.project_ioh_tertiary_outlet` a 
					left join 
					`data-bi-prd-935c.bi_mart.angie_hrchy_dim_202303` hd on a.dealer_id = hd.partner_qr_cd
					where coalesce(upper(hd.mp3_location),'CENTRAL WEST NORTH JKT') NOT IN ('DVM BM','3 STORE','NA','POOL','SIM ONLINE','SOUTH JAKARTA TEST BM','ADVCREDIT','FUT ANGIE 2.0','MODCHAN','BSM TRI OFFICIAL STORE')
					and dt_sk_id  		= vdt_id
		and source_nm<>'3AS' and tertiary_type='ETOPUP PULSA'  
		union all 
		select sum(metric) *-1  from 
		`data-bi-prd-935c.bi_mart.kpi_national_tracker_dly`
		where kpi_id in ('SLS0019','SLS0011') and brand = 'TRI'
		and dt_id=vdt_id
		) x 
					group by  1,2,3,5,6,7 ;
  


 
	delete from `data-bi-prd-935c.bi_mart.kpi_national_tracker_dly` 
	where brand = 'TRI' and kpi_id in 
	(
	'SLS0016'
	) and dt_id =vdt_id  ;

 


 
	insert into `data-bi-prd-935c.bi_mart.kpi_national_tracker_dly` 
	select 
	'TRI' brand
	,''kpi_code
	,'MTD' flag
	,sum(amt)-- value
	,current_timestamp()
	,'SLS0016' kpi_id
	,cast(vdt_id as date)
		from
		(
		select sum(amount)amt
			from `data-bi-prd-935c.bi_mart.project_ioh_tertiary_outlet` a 
					left join 
					`data-bi-prd-935c.bi_mart.angie_hrchy_dim_202303` hd on a.dealer_id = hd.partner_qr_cd
					where coalesce(upper(hd.mp3_location),'CENTRAL WEST NORTH JKT') NOT IN ('DVM BM','3 STORE','NA','POOL','SIM ONLINE','SOUTH JAKARTA TEST BM','ADVCREDIT','FUT ANGIE 2.0','MODCHAN','BSM TRI OFFICIAL STORE')
					and dt_sk_id  		= vdt_id
		and source_nm<>'3AS' and tertiary_type='ETOPUP NON PULSA'  
		union all 
		select sum(metric) *-1  from 
		`data-bi-prd-935c.bi_mart.kpi_national_tracker_dly`
		where kpi_id in ('SLS0020','SLS0012')  and brand = 'TRI'
		and dt_id=vdt_id
		) x 
					group by  1,2,3,5,6,7 ; 




 
	delete from `data-bi-prd-935c.bi_mart.kpi_national_tracker_dly` 
	where brand = 'TRI' and kpi_id in 
	(
	'SLS0014'
	) and dt_id =vdt_id;


 

 
	insert into `data-bi-prd-935c.bi_mart.kpi_national_tracker_dly` 
	select 
	'TRI' brand
	,''kpi_code
	,'MTD' flag
	,sum(amt)-- value
	,current_timestamp()
	,'SLS0014' kpi_id
	,cast(vdt_id as date)
		from
		(
		select sum(metric)  amt from 
		`data-bi-prd-935c.bi_mart.kpi_national_tracker_dly`
		where kpi_id in ('SLS0015','SLS0016')  and brand = 'TRI'
		and dt_id=vdt_id
		) x 
					group by  1,2,3,5,6,7; 


 



-- stock retailer 
 
	delete from `data-bi-prd-935c.bi_mart.kpi_national_tracker_dly` 
	where brand = 'TRI' and kpi_id in 
	(
	'SLS0031'
	) and dt_id =vdt_id  ;
 


 
	insert into `data-bi-prd-935c.bi_mart.kpi_national_tracker_dly` 
select 
	'TRI' brand
	,''kpi_code
	,'MTD' flag
	,sum(kpi_value)-- value
	,current_timestamp()
	,'SLS0031' kpi_id
	,cast(vdt_id as date)
 from 
(
-- Stock 3sakti retailer 
select sum(kpi_value)kpi_value  from 			
`data-dtptechm-prd-c7ca.dwh.prt_daily_channel_movement_fct`			
	where kpi_name like 'DB Closing Balance'
	and partner_type='Retailer'			
	and cast(snp_dt_sk_id as date)  =vdt_id
	union all 
	--- stock phyiscal  retailer
	select		
	 sum(netnetrevenue) --  as netnetrevenue				
	from `data-dtptechm-prd-c7ca.dwh_olap.revenue_base_special_summary` 				
	where cast(trx_dt_sk_id as date)=vdt_id  ----(20220131,20220228,20220331,20220430,20220531,20220630,20220731,20220831,20220930,20221031,20221130,20221231,20230131, 20230228 )				
	  and report_tabname = 'Stock'				
	-- and service_type_name = 'BROADBAND'				
)stock
			group by  1,2,3,5,6,7 ; 
