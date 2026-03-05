DECLARE vdt_id DATE DEFAULT @vdt_id;


		delete from 
		`data-bi-prd-935c.bi_mart.h3i_project_ioh_kpi_daily_tracker_site` 
		where load_Dt_Sk_id = vdt_id
		and kpi_code='scm0_35';

		insert into `data-bi-prd-935c.bi_mart.h3i_project_ioh_kpi_daily_tracker_site`
		with subs as  
		(
		 select distinct a.sbscrptn_ek_id
		 from `data-dtptechm-prd-c7ca.dwh.ioh_sales_distribution_kpi_subs_detail` a
		 where cast(load_dt_sk_id as date) = vdt_id
		 and heading_tag = 'ACQUISITION'
		 and month_kpi_tag = 'M-0'
		),
		ga as 
		(
			select * from `data-bi-prd-935c.bi_mart.fct_ga_site_id` b where date_trunc(b.dt,MONTH)= DATE_TRUNC(vdt_id,MONTH)
		)
		select * from 
		(
		select cast(vdt_id as date) as load_dt_sk_id,
		'H3I' as entity,
		'scm0_35' as kpi_code,
		'IOH' as definition,
		cast(vdt_id as date), 
		b.site_id, 
		count(distinct a.sbscrptn_ek_id) as value, 
		'SCM0 >35= Subs', 
		current_timestamp
		from subs a
		left outer join ga b on cast(a.sbscrptn_ek_id as string) = cast(b.sbscrptn_ek_id as string) 
		group by 1,2,3,4,5,6,8,9
		) x where value >=35 ;

		delete from 
		`data-bi-prd-935c.bi_mart.h3i_project_ioh_kpi_daily_tracker_site` 
		where load_Dt_Sk_id=vdt_id
		and kpi_code='qsso' ;
	 

-- QSSO

		insert into `data-bi-prd-935c.bi_mart.h3i_project_ioh_kpi_daily_tracker_site`
		select dt as dt_sk_id
		,'H3I'
		,'qsso'
		,'IOH'
		,CAST(dt AS DATE)
		,case when length(ret_site_id)<6 then lpad(ret_site_id,6,'0') else ret_site_id end as site_id 
		,sum(qsso) cnt 
		,'QSSO >=3'
		,CURRENT_TIMESTAMP()
		from 
		`data-bi-prd-935c.bi_mart.subs_ret_qsso_detail_3` 
		where dt=vdt_id
		group by 1 ,2,3,4,5,6,8,9;
		 

	

		
		delete from 
		`data-bi-prd-935c.bi_mart.h3i_project_ioh_kpi_daily_tracker_site` 
		where load_Dt_Sk_id=vdt_id
		and kpi_code='hvc';

		insert into `data-bi-prd-935c.bi_mart.h3i_project_ioh_kpi_daily_tracker_site`
		select dt as dt_sk_id
		,'H3I'
		,'hvc'
		,'IOH'
		,CAST(dt AS DATE)
		,case when length(site_id_90)<6 then lpad(site_id_90,6,'0') else site_id_90 end as site_id 
		,sum(gross_add) 
		,'hvc'
		,CURRENT_TIMESTAMP()
		from
		`data-bi-prd-935c.bi_mart.gross_add_b2c_satu_hv_site`
		where dt = vdt_id 
		group by 1 ,2,3,4,5,6,8,9;

		delete from 
		`data-bi-prd-935c.bi_mart.h3i_project_ioh_kpi_daily_tracker_site` 
		where load_Dt_Sk_id = vdt_id
		and kpi_code='scm0_any';

insert into `data-bi-prd-935c.bi_mart.h3i_project_ioh_kpi_daily_tracker_site`
with subs as 
(
 select distinct a.sbscrptn_ek_id
 from `data-dtptechm-prd-c7ca.dwh.ioh_sales_distribution_kpi_subs_detail` a
 where cast(load_dt_sk_id as date) = vdt_id
 and heading_tag = 'ACQUISITION'
 and month_kpi_tag = 'M-0'
),
ga as
(
	select * from `data-bi-prd-935c.bi_mart.fct_ga_site_id` b where date_trunc(b.dt,month) = date_trunc(vdt_id,month)
)
select * from 
(
select cast(vdt_id as date) as load_dt_sk_id, 'H3I' as entity, 'scm0_any' as kpi_code, 'IOH' as definition,
cast(vdt_id as date), b.site_id, count(distinct a.sbscrptn_ek_id) as value, 'SCM0 Any', current_timestamp
from subs a
left outer join ga b on cast(a.sbscrptn_ek_id as string) = cast(b.sbscrptn_ek_id as string) 
group by 1,2,3,4,5,6,8,9
) x;

		--having count(*) >=35
--qsso_any 
		
		delete from 
		`data-bi-prd-935c.bi_mart.h3i_project_ioh_kpi_daily_tracker_site` 
		where load_Dt_Sk_id=vdt_id
		and kpi_code='qsso_any';

		
		insert into `data-bi-prd-935c.bi_mart.h3i_project_ioh_kpi_daily_tracker_site`
		select dt as dt_sk_id
		,'H3I'
		,'qsso_any'
		,'IOH'
		,CAST(dt AS DATE)
		,case when length(ret_site_id)<6 then lpad(ret_site_id,6,'0') else ret_site_id end as site_id 
		,count(distinct retailer_qrcode) cnt 
		,'QSSO Any'
		,CURRENT_TIMESTAMP()
		from 
		(
				select dt,ret_site_id,retailer_qrcode,ret_branch,count(distinct sbscrptn_ek_id) as subs from 
				`data-bi-prd-935c.bi_mart.subs_ret_qsso_detail_2` 
				where 
				dt=vdt_id
				 group by 1,2,3,4 
				having count(*) >=3 
		)x
		where dt=vdt_id
		group by 1 ,2,3,4,5,6,8,9;

		delete from 
		`data-bi-prd-935c.bi_mart.h3i_project_ioh_kpi_daily_tracker_site` 
		where load_Dt_Sk_id=vdt_id
		and kpi_code='sso_any';

insert into `data-bi-prd-935c.bi_mart.h3i_project_ioh_kpi_daily_tracker_site`
		
		select dt_sk_id as dt_sk_id
		,'H3I'
		,'sso_any'
		,'IOH'
		,dt_sk_id
		,case when length(site_id)<6 then lpad(site_id,6,'0') else site_id end as site_id 
		,sum(cnt) cnt 
		,'sso_any_sim_demand'
		,CURRENT_TIMESTAMP()
		from 
		(
		select dt_sk_id
		,site_id
		,cnt From 
		(
		with subs as (select * from `data-bi-prd-935c.bi_mart.sbscrptn_attribs_hist7` where dt_id = date_add( vdt_id, Interval 1 day))	
		select cast(vdt_id as date) as dt_sk_id,site_id, count(distinct angie_retailer_name) cnt from `data-dtptechm-prd-c7ca.dwh.revenue_base` a 
		left join subs b on cast(a.sbscrptn_ek_id as string)=cast(b.sbscrptn_ek_id as string) 
		left join(select * from `data-bi-prd-935c.bi_mart.stg_v_map_tgt_ret_details_hist` where dt=vdt_id) c 
		on b.angie_retailer_name=c.ret_qr_cd 
		where cast(trx_dt_sk_id as date) between DATE_TRUNC(vdt_id, month) and vdt_id 
		and process_nm='SIM_DEMAND' and service_type_category_1 ='FRC'
		 group by 1 ,2		) x --where cnt >=5
		)f
		group by 1 ,2,3,4,5,6,8,9;


		delete from 
		`data-bi-prd-935c.bi_mart.h3i_project_ioh_kpi_daily_tracker_site` 
		where load_Dt_Sk_id=vdt_id
		and kpi_code='sso_any_sim_demand';
		 

insert into `data-bi-prd-935c.bi_mart.h3i_project_ioh_kpi_daily_tracker_site`
		select dt_sk_id as dt_sk_id
		,'H3I'
		,'sso_any_sim_demand'
		,'IOH'
		,dt_sk_id
		,case when length(site_id)<6 then lpad(site_id,6,'0') else site_id end as site_id 
		,sum(cnt) cnt 
		,'sso_any_sim_demand'
		,CURRENT_TIMESTAMP()
		from 
		(
		select dt_sk_id
		,site_id
		,cnt From 
		(
		with subs as (select * from `data-bi-prd-935c.bi_mart.sbscrptn_attribs_hist7` where dt_id = date_add( vdt_id, Interval 1 day))
		select cast(vdt_id as date) dt_sk_id,site_id, count(distinct angie_retailer_name) cnt from `data-dtptechm-prd-c7ca.dwh.revenue_base` a 
		left join subs b on cast(a.sbscrptn_ek_id as string)=cast(b.sbscrptn_ek_id as string)  
		left join(select * from `data-bi-prd-935c.bi_mart.stg_v_map_tgt_ret_details_hist` where dt=vdt_id) c 
		on b.angie_retailer_name=c.ret_qr_cd 
		where cast(trx_dt_sk_id as date) between DATE_TRUNC(vdt_id, month) and vdt_id 
		and process_nm='SIM_DEMAND' 
		and service_type_category_1 ='FRC'
		and net_revenue>1 group by 1 ,2		) x --where cnt >=5
		)f
		group by 1,2,3,4,5,6,8,9;

		delete from 
		`data-bi-prd-935c.bi_mart.h3i_project_ioh_kpi_daily_tracker_site` 
		where load_Dt_Sk_id = vdt_id
		and kpi_code='sso_any_3sp';
	
insert into `data-bi-prd-935c.bi_mart.h3i_project_ioh_kpi_daily_tracker_site`
		select dt_sk_id as dt_sk_id
		,'H3I'
		,'sso_any_3sp'
		,'IOH'
		,dt_sk_id
		,case when length(site_id)<6 then lpad(site_id,6,'0') else site_id end as site_id 
		,count(distinct angie_retailer_name ) cnt 
		,'sso_any_3sp'
		,CURRENT_TIMESTAMP()
		from 
		(
		select dt_sk_id
		,site_id
		,angie_retailer_name
		,cnt From 
		(
			with subs as (select * from `data-bi-prd-935c.bi_mart.sbscrptn_attribs_hist7` where dt_id = date_add( vdt_id, Interval 1 day))
			select cast(vdt_id as date) dt_sk_id,site_id, angie_retailer_name ,count(a.sbscrptn_ek_id) cnt from `data-dtptechm-prd-c7ca.dwh.revenue_base` a 
			left join subs b on cast(a.sbscrptn_ek_id as string)=cast(b.sbscrptn_ek_id as string) 
			left join(select * from `data-bi-prd-935c.bi_mart.stg_v_map_tgt_ret_details_hist` where dt=vdt_id) c 
			on b.angie_retailer_name=c.ret_qr_cd 
			where cast(trx_dt_sk_id as date) between DATE_TRUNC(vdt_id, month) and vdt_id 
			and process_nm='SIM_DEMAND' and service_type_category_1 ='FRC'
			and net_revenue > 1 group by 1,2,3
		) x 
			where cnt >=3
		)f
		group by 1,2,3,4,5,6,8,9;
				 

		
		delete from 
		`data-bi-prd-935c.bi_mart.ret_uro_quro_indicator_dly` 
		where trx_dt_sk_id=vdt_id
		;
		

	 INSERT INTO `data-bi-prd-935c.bi_mart.ret_uro_quro_indicator_dly`
	select
	AB.trx_dt_sk_id,
	cast(AB.angie_hrchy_sk_id as string),
	hd.partner_qr_cd,
	(CASE WHEN ret_uro_amt >= 20000 THEN 'Y' ELSE 'N' END) as RET_URO_IND,
	(CASE WHEN RET_QURO_CNT >= 5 THEN 'Y' ELSE 'N' END) as RET_QURO_IND,
	ret_uro_amt,
	CURRENT_DATETIME() as created_dtm
	FROM
	(
	select
	trx_dt_sk_id,
	angie_hrchy_sk_id,
	SUM(ret_uro_amt) ret_uro_amt,
	SUM(CASE WHEN ret_quro_amt >= 5000 THEN 1 ELSE 0 END) as RET_QURO_CNT
	FROM
	(
		select
		cast(vdt_id as date)as trx_dt_sk_id,
		angie_hrchy_sk_id,
		transaction_id,
		sum(case when category in ('FRC','FRC_PULSA','ADDON_PULSA','ADDON','RITA_PULSA','RITA_TOPUP','MARKUP_RITA','RITA','RITA_VAS_VOUCHER_GAMES','VOUCHER')
		then gross_revenue else 0 end) as ret_uro_amt,
		sum(case when category in ('RITA_PULSA','RITA_TOPUP','MARKUP_RITA','RITA','RITA_VAS_VOUCHER_GAMES','VOUCHER')
		then gross_revenue else 0 end) as ret_quro_amt
		from (
		select
		cast(trx_dt_sk_id as date) as trx_dt_sk_id,
		rb.angie_channel_sk_id as angie_hrchy_sk_id,
		process_nm as category,
		transaction_id,
		SUM(CASE WHEN process_nm IN ('FRC_PULSA','ADDON_PULSA','RITA_TOPUP','RITA_PULSA','UNLOCK_PULSA') THEN unearned
		ELSE gross_revenue
		END) as gross_revenue
		from `data-dtptechm-prd-c7ca.dwh.revenue_base` rb
		where cast(trx_dt_sk_id as date) >= DATE_TRUNC(vdt_id,MONTH)
		and cast(trx_dt_sk_id as date) <= vdt_id 
		and rb.revenue_src_ctgry = 'Ret'
		and process_nm IN ('FRC','FRC_PULSA','ADDON_PULSA','ADDON',
			'RITA_PULSA','RITA_TOPUP','MARKUP_RITA','RITA',
			'UNLOCK_PULSA','UNLOCK','MARKUP_UNLOCK','RITA_VAS_VOUCHER_GAMES')
		group by 1,2,3,4
		UNION ALL
		select
		cast(vdt_id as date) as trx_dt_sk_id,
		coalesce(ori.angie_hrchy_sk_id,vms.angie_hrchy_sk_id) angie_hrchy_sk_id,
		'VOUCHER' as category,
		sid_number,
		sum(case when coalesce(vms.pulsa,0) > 0 then (vms.gross_revenue - vms.pulsa) + vms.pulsa + vms.markup
		else coalesce(vms.gross_revenue,0) + coalesce(vms.markup,0)
		end) as gross_revenue
		from `data-dtptechm-prd-c7ca.dwh.vms_voucher_status_dim` vms
		left join 
		(
			select serial_no,angie_hrchy_sk_id From 
			`data-dtptechm-prd-c7ca.dwh.ori_product_datamart` a 
			left join 
			`data-dtptechm-prd-c7ca.dwh.angie_hrchy_dim`b on a.retailer_id=b.partner_id 
			where REGEXP_CONTAINS(distribution_type, 'Sold from')
			and 
				inventory_position = 'Retailer'
				and cast(date_id as date) <= vdt_id
			--	and date_id <= 20230131
			group by 1,2 
		)ori on vms.sid_number=ori.serial_no
		where create_dtm<='9999-12-01' and serial_status_id='SRS05'
		and CAST(inuse_dtm AS DATE) >= DATE_TRUNC(vdt_id,MONTH)
		and CAST(inuse_dtm AS DATE) <= vdt_id 
		group by 1,2,3,4)A
		group by 1,2,3
	)XX
	group by 1,2
	) AB
	LEFT JOIN `data-dtptechm-prd-c7ca.dwh.angie_hrchy_dim` hd ON hd.angie_hrchy_sk_id = AB.angie_hrchy_sk_id;
		 
		
		
		delete from 
		`data-bi-prd-935c.bi_mart.h3i_project_ioh_kpi_daily_tracker_site` 
		where load_Dt_Sk_id=vdt_id
		and kpi_code='uro_amt_any' ;
	
insert into `data-bi-prd-935c.bi_mart.h3i_project_ioh_kpi_daily_tracker_site`
SELECT 
cast(dt_sk_id as date) as dt_sk_id
,'H3I' AS entity
,'uro_amt_any' as kpi_cd
,'IOH' as definition
,cast(dt_sk_id as date) as date
,case when length(site_id)<6 then lpad(site_id,6,'0') else site_id end as site_id 
,cast(sum(ret_uro_amt) as numeric) ret_uro_amt
,'URO Amount any' as remark
,CURRENT_TIMESTAMP() as created_dtm
FROM 
(
 select dt_sk_id
 ,site_id
 ,cnt
 ,ret_uro_amt 
 From 
 (
 select 
 trx_dt_sk_id as dt_sk_id,
 ret_map.site_id, 
 count(distinct dtl.partner_qr_cd) cnt,
 sum(ret_uro_amt) as ret_uro_amt
 from `data-bi-prd-935c.bi_mart.ret_uro_quro_indicator_dly` dtl
--left outer join `data-bi-prd-935c.bi_mart.ret_uro_quro_indicator_dly` rch ON rch.partner_qr_cd = dtl.partner_qr_cd and dtl.dt_sk_id=rch.trx_dt_sk_id
 --- left join `data-dtptechm-prd-c7ca.stg.stg_v_map_tgt_ret_details` ret_map on ret_map.ret_qr_cd = dtl.partner_qr_cd--> ini untuk current period
 left join `data-bi-prd-935c.bi_mart.stg_v_map_tgt_ret_details_hist` ret_map on ret_map.ret_qr_cd = dtl.partner_qr_cd AND ret_map.dt = dtl.trx_dt_sk_id
 left join `data-dtptechm-prd-c7ca.dwh.angie_hrchy_dim` hd on hd.partner_qr_cd = dtl.partner_qr_cd and hd.partner_status in ('Active','Suspended') and hd.ret_hierarchy_type = 'ANGIE' and hd.hrchy_type = 'Retailer'
 where trx_dt_sk_id in (vdt_id) 
 --and dt_sk_id <= dwh.get_cycle_date_sk_id('ETL_DAILY_LOAD')
 and dtl.ret_uro_ind='Y' group by 1,2 
 ) x --where cnt >=5
)f
group by 1,2,3,4,5,6;


		delete from 
		`data-bi-prd-935c.bi_mart.h3i_project_ioh_kpi_daily_tracker_site` 
		where load_Dt_Sk_id=vdt_id
		and kpi_code='quro_any';

--quro any 
		
insert into `data-bi-prd-935c.bi_mart.h3i_project_ioh_kpi_daily_tracker_site`
		select dt_sk_id as dt_sk_id
		,'H3I'
		,'quro_any'
		,'IOH'
		,dt_sk_id
		,case when length(site_id)<6 then lpad(site_id,6,'0') else site_id end as site_id 
		,sum(cnt) cnt 
		,'QURO any'
		,CURRENT_TIMESTAMP()
		from 
		(
		select trx_dt_sk_id as dt_Sk_id
		,site_id
		,cnt From 
		(
			select trx_dt_sk_id,ret_map.site_id, count(distinct dtl.partner_qr_cd) cnt
			from `data-bi-prd-935c.bi_mart.ret_uro_quro_indicator_dly` dtl
			left join `data-dtptechm-prd-c7ca.stg.stg_v_map_tgt_ret_details` ret_map on ret_map.ret_qr_cd = dtl.partner_qr_cd
			left join `data-dtptechm-prd-c7ca.dwh.angie_hrchy_dim` hd on hd.partner_qr_cd = dtl.partner_qr_cd and hd.partner_status in ('Active','Suspended') and hd.ret_hierarchy_type = 'ANGIE' and hd.hrchy_type = 'Retailer'
			where trx_dt_sk_id =vdt_id
			--and dt_sk_id <= dwh.get_cycle_date_sk_id('ETL_DAILY_LOAD')
			and ret_quro_ind='Y'group by 1,2 
		) x --where cnt >=5
		)f
		group by 1 ,2,3,4,5,6,8,9;
				 



		delete from 
		`data-bi-prd-935c.bi_mart.h3i_project_ioh_kpi_daily_tracker_site` 
		where load_Dt_Sk_id=vdt_id
		and kpi_code='uro_any';

--uro any 		

insert into `data-bi-prd-935c.bi_mart.h3i_project_ioh_kpi_daily_tracker_site`
		select dt_sk_id as dt_sk_id
		,'H3I'
		,'uro_any'
		,'IOH'
		,dt_sk_id
		,case when length(site_id)<6 then lpad(site_id,6,'0') else site_id end as site_id 
		,sum(cnt) cnt 
		,'URO any'
		,CURRENT_TIMESTAMP()
		from 
		(
		select trx_dt_sk_id as dt_sk_id
		,site_id
		,cnt From 
		(
			select trx_dt_sk_id,ret_map.site_id, count(distinct dtl.partner_qr_cd) cnt
			from `data-bi-prd-935c.bi_mart.ret_uro_quro_indicator_dly`dtl
			left join `data-dtptechm-prd-c7ca.stg.stg_v_map_tgt_ret_details` ret_map on ret_map.ret_qr_cd = dtl.partner_qr_cd
			left join `data-dtptechm-prd-c7ca.dwh.angie_hrchy_dim` hd on hd.partner_qr_cd = dtl.partner_qr_cd and hd.partner_status in ('Active','Suspended') and hd.ret_hierarchy_type = 'ANGIE' and hd.hrchy_type = 'Retailer'
			where trx_dt_sk_id =vdt_id
			--and dt_sk_id <= dwh.get_cycle_date_sk_id('ETL_DAILY_LOAD')
			and ret_uro_ind='Y'group by 1,2 
		) x --where cnt >=5
		)f
		group by 1 ,2,3,4,5,6,8,9;
		 




---quro

		
		delete from 
		`data-bi-prd-935c.bi_mart.h3i_project_ioh_kpi_daily_tracker_site` 
		where load_Dt_Sk_id=vdt_id
		and kpi_code='quro';

		insert into `data-bi-prd-935c.bi_mart.h3i_project_ioh_kpi_daily_tracker_site`
		select dt_sk_id as dt_sk_id
		,'H3I'
		,'quro'
		,'IOH'
		,dt_sk_id
		,case when length(site_id)<6 then lpad(site_id,6,'0') else site_id end as site_id 
		,sum(cnt) cnt 
		,'QURO >=5'
		,CURRENT_TIMESTAMP()
		from 
		(
		select dt_sk_id
		,site_id
		,cnt From 
		(
			select trx_dt_sk_id dt_sk_id,ret_map.site_id, count(distinct dtl.partner_qr_cd) cnt
			from `data-bi-prd-935c.bi_mart.ret_uro_quro_indicator_dly` dtl
			left join `data-bi-prd-935c.bi_mart.stg_v_map_tgt_ret_details_hist` ret_map on ret_map.ret_qr_cd = dtl.partner_qr_cd
			left join `data-dtptechm-prd-c7ca.dwh.angie_hrchy_dim` hd on hd.partner_qr_cd = dtl.partner_qr_cd and hd.partner_status in ('Active','Suspended') and hd.ret_hierarchy_type = 'ANGIE' and hd.hrchy_type = 'Retailer'
			where trx_dt_sk_id =vdt_id 
			--and dt_sk_id <= dwh.get_cycle_date_sk_id('ETL_DAILY_LOAD')
			and ret_quro_ind='Y'group by 1,2 
		) x where cnt >=5
		)f
		group by 1 ,2,3,4,5,6,8,9;
		 

--##
--M0SC_MTD
--##

delete from `data-bi-prd-935c.bi_mart.h3i_project_ioh_kpi_daily_tracker_site` where load_dt_sk_id = vdt_id and kpi_code = 'M0SC_MTD';

insert into `data-bi-prd-935c.bi_mart.h3i_project_ioh_kpi_daily_tracker_site`
select cast(vdt_id as date) as load_dt_sk_id, 'H3I' as entity, 'M0SC_MTD' as kpi_code, 'IOH' as definition,
cast(vdt_id as date), b.site_id, count(distinct a.sbscrptn_ek_id) as value, 'SITE ROLLING 90', current_timestamp
from 
(
 select distinct a.sbscrptn_ek_id
 from `data-dtptechm-prd-c7ca.dwh.ioh_sales_distribution_kpi_subs_detail` a
 where cast(load_dt_sk_id as date) = vdt_id
 and heading_tag = 'ACQUISITION'
 and month_kpi_tag = 'M-0'
) a
left outer join `data-bi-prd-935c.bi_mart.fct_ga_site_id` b on cast(a.sbscrptn_ek_id as string) = cast(b.sbscrptn_ek_id as string) and date_trunc(b.dt,MONTH) = date_trunc(vdt_id,MONTH)
group by 1,2,3,4,5,6,8,9;


--##
--HV_M0SC_MTD
--##

delete from `data-bi-prd-935c.bi_mart.h3i_project_ioh_kpi_daily_tracker_site` where cast(load_dt_sk_id as date) = vdt_id 
and kpi_code = 'HV_M0SC_MTD';

insert into `data-bi-prd-935c.bi_mart.h3i_project_ioh_kpi_daily_tracker_site`
select cast(vdt_id as date) as load_dt_sk_id, 'H3I' as entity, 'HV_M0SC_MTD' as kpi_code, 'IOH' as definition,
cast(vdt_id as date), b.site_id, count(distinct a.sbscrptn_ek_id) as value, 'SITE ROLLING 90', current_timestamp
from 
(
with subs as (select * from `data-bi-prd-935c.bi_mart.sbscrptn_attribs_hist7` where dt_id = date_add( vdt_id, Interval 1 day))
 select distinct a.sbscrptn_ek_id
 from `data-dtptechm-prd-c7ca.dwh.ioh_sales_distribution_kpi_subs_detail` a
 left outer join subs b on cast(a.sbscrptn_ek_id as string)= cast(b.sbscrptn_ek_id as string)
 join `data-bi-prd-935c.bi_mart.ref_callplan_hvc_mvc_lvc` c on upper(b.call_plan_desc) = upper(c.call_plan) and c.segment = 'HVC'
 where cast(load_dt_sk_id as date) = vdt_id
 and heading_tag = 'ACQUISITION'
 and month_kpi_tag = 'M-0'
) a
left outer join `data-bi-prd-935c.bi_mart.fct_ga_site_id` b on cast(a.sbscrptn_ek_id as string)= cast(b.sbscrptn_ek_id as string) and date_trunc(b.dt,MONTH) = date_trunc(vdt_id,MONTH)
group by 1,2,3,4,5,6,8,9;


--##
--QSC
--##

delete from `data-bi-prd-935c.bi_mart.h3i_project_ioh_kpi_daily_tracker_site` where load_dt_sk_id = vdt_id and kpi_code = 'QSC';

insert into `data-bi-prd-935c.bi_mart.h3i_project_ioh_kpi_daily_tracker_site`
select cast(vdt_id as date) as load_dt_sk_id, 'H3I' as entity, 'QSC' as kpi_code, 'IOH' as definition,
cast(vdt_id as date), coalesce(c.site_id, 'N/A') as site_id, count(distinct a.sbscrptn_ek_id) as value, 'SITE ROLLING 90', current_timestamp
from `data-dtptechm-prd-c7ca.dwh.ioh_sales_distribution_kpi_subs_detail` a
join
(
 select distinct sbscrptn_ek_id
 from `data-bi-prd-935c.bi_mart.project_ioh_dgpcr_flag_hist`
 where dt_sk_id=vdt_id and x_dgpcr_flag in ('Y', 'A')
) b on cast(a.sbscrptn_ek_id as string) = cast(b.sbscrptn_ek_id as string)
left outer join `data-bi-prd-935c.bi_mart.fct_ga_site_id` c on cast(a.sbscrptn_ek_id as string)= cast(c.sbscrptn_ek_id as string) and date_trunc(cast(a.load_dt_sk_id as date),MONTH) = date_trunc(c.dt,MONTH)
where month_kpi_tag = 'M-0'
and heading_tag = 'ACQUISITION'
and cast(a.load_dt_sk_id as date)  = vdt_id
group by 1,2,3,4,5,6,8,9;


--##
--QSC_250MB
--##

delete from `data-bi-prd-935c.bi_mart.fct_qsc_250mb` where dt = vdt_id;

insert into `data-bi-prd-935c.bi_mart.fct_qsc_250mb`
with dgpcr as 
(
 select distinct sbscrptn_ek_id
 from `data-bi-prd-935c.bi_mart.project_ioh_dgpcr_flag_hist`
 where dt_sk_id=vdt_id and x_dgpcr_flag in ('Y', 'A')
),
usage_ggsn as 
(
select created_dt_sk_id,sbscrptn_ek_id,gprs_uplink_vol_free_url , gprs_downlink_vol_free_url , data_uplink_vol_free_url , data_downlink_vol_free_url , gprs_uplink_vol_Dongle , gprs_downlink_vol_Dongle , data_uplink_vol_Dongle , data_downlink_vol_Dongle ,
 gprs_uplink_vol_PUG , gprs_downlink_vol_PUG , bb_downlink_vol , bb_uplink_vol from `data-dtptechm-prd-c7ca.dwh.broadband_usage_dly_summary`
where cast(created_dt_sk_id as date) <= vdt_id
),
base as 
(
	select * from `data-bi-prd-935c.bi_mart.fct_ga_site_id` b where date_trunc(b.dt,month) = date_trunc(vdt_id,month)
),
usage as 
(
	 select a.sbscrptn_ek_id,
 sum(gprs_uplink_vol_free_url + gprs_downlink_vol_free_url + data_uplink_vol_free_url + data_downlink_vol_free_url +
 gprs_uplink_vol_Dongle + gprs_downlink_vol_Dongle + data_uplink_vol_Dongle + data_downlink_vol_Dongle + 
 gprs_uplink_vol_PUG + gprs_downlink_vol_PUG + bb_downlink_vol + bb_uplink_vol)/(1024*1024) as usage_mb
 from usage_ggsn a
 join base b on cast(a.sbscrptn_ek_id as string) = cast(b.sbscrptn_ek_id as string)  
 where cast(created_dt_sk_id as date)>= b.dt --count the broadband usage start from ga_date 
 group by 1 having  sum(gprs_uplink_vol_free_url + gprs_downlink_vol_free_url + data_uplink_vol_free_url + data_downlink_vol_free_url +
 gprs_uplink_vol_Dongle + gprs_downlink_vol_Dongle + data_uplink_vol_Dongle + data_downlink_vol_Dongle + 
 gprs_uplink_vol_PUG + gprs_downlink_vol_PUG + bb_downlink_vol + bb_uplink_vol)/(1024*1024) >= 250
),
subs as (select * from `data-bi-prd-935c.bi_mart.sbscrptn_attribs_hist7` where dt_id = date_add( vdt_id, Interval 1 day))
select cast(vdt_id as date) as dt, 
coalesce(c.site_id, 'N/A') as site_id,
coalesce(e.angie_retailer_name, 'N/A') as retailer_qrcode,
coalesce(e.call_plan_desc, 'N/A') as call_plan,
coalesce(f.region, 'N/A') as region, 
coalesce(f.area, 'N/A') as area,
coalesce(f.sales_area, 'N/A') as sales_area,
coalesce(f.sales_cluster, 'N/A') as sales_cluster,
coalesce(f.micro_cluster, 'N/A') as micro_cluster,
coalesce(f.gladiator_branch, 'N/A') as gladiator_branch,
count(distinct a.sbscrptn_ek_id) as value
from `data-dtptechm-prd-c7ca.dwh.ioh_sales_distribution_kpi_subs_detail` a
join dgpcr b on cast(a.sbscrptn_ek_id as string) = cast(b.sbscrptn_ek_id as string)
left outer join base c on cast(a.sbscrptn_ek_id as string) = cast(c.sbscrptn_ek_id as string) and date_TRUNC(CAST(a.load_dt_sk_id as date),MONTH) = DATE_TRUNC(c.dt,MONTH)
join usage d on cast(a.sbscrptn_ek_id as string) = cast(d.sbscrptn_ek_id as string)
left outer join subs e on cast(a.sbscrptn_ek_id as string)= cast(e.sbscrptn_ek_id as string) 
left outer join
(
 select distinct case when length(site_id) <= 5 then LPAD(site_id,6,'0') else site_id end as site_id, region, area, sales_area, sales_cluster, micro_cluster, gladiator_branch,
 row_number()over(partition by case when length(site_id) <= 5 then LPAD(site_id,6,'0') else site_id end order by site_nm) as seq
 from `data-bi-prd-935c.bi_mart.ref_site_h3i`
) f on case when length(c.site_id) <= 5 then LPAD(c.site_id,6,'0') else c.site_id end = f.site_id and f.seq = 1
where month_kpi_tag = 'M-0'
and heading_tag = 'ACQUISITION'
and cast(a.load_dt_sk_id as date) = vdt_id
group by 1,2,3,4,5,6,7,8,9,10;

delete from `data-bi-prd-935c.bi_mart.h3i_project_ioh_kpi_daily_tracker_site` where load_dt_sk_id = vdt_id 
and kpi_code = 'QSC_250MB';

insert into `data-bi-prd-935c.bi_mart.h3i_project_ioh_kpi_daily_tracker_site`
select cast(vdt_id as date) as load_dt_sk_id, 'H3I' as entity, 'QSC_250MB' as kpi_code, 'IOH' as definition,
cast(vdt_id as date), coalesce(a.site_id, 'N/A') as site_id, sum(a.value) as value, 'SITE ROLLING 90', current_timestamp
from `data-bi-prd-935c.bi_mart.fct_qsc_250mb` a
where a.dt = vdt_id
group by 1,2,3,4,5,6,8,9;

--##
--QSC_100MB
--##

delete from `data-bi-prd-935c.bi_mart.h3i_project_ioh_kpi_daily_tracker_site` where load_dt_sk_id = vdt_id 
and kpi_code = 'QSC_100MB';

insert into `data-bi-prd-935c.bi_mart.h3i_project_ioh_kpi_daily_tracker_site`
select cast(vdt_id as date) as load_dt_sk_id, 'H3I' as entity, 'QSC_100MB' as kpi_code, 'IOH' as definition,
cast(vdt_id as date), coalesce(c.site_id, 'N/A') as site_id, count(distinct a.sbscrptn_ek_id) as value, 'SITE ROLLING 90', current_timestamp
from `data-dtptechm-prd-c7ca.dwh.ioh_sales_distribution_kpi_subs_detail` a
join
(
 select distinct sbscrptn_ek_id
 from `data-bi-prd-935c.bi_mart.project_ioh_dgpcr_flag_hist`
 where dt_sk_id=vdt_id and x_dgpcr_flag in ('Y', 'A')
) b on cast(a.sbscrptn_ek_id as string)= cast(b.sbscrptn_ek_id as string)
left outer join `data-bi-prd-935c.bi_mart.fct_ga_site_id` c on cast(a.sbscrptn_ek_id as string)= cast(c.sbscrptn_ek_id as string) and date_trunc(cast(a.load_dt_sk_id as date),MONTH) = date_trunc(c.dt,MONTH)
join
(
 select a.sbscrptn_ek_id,
 sum(gprs_uplink_vol_free_url + gprs_downlink_vol_free_url + data_uplink_vol_free_url + data_downlink_vol_free_url +
 gprs_uplink_vol_Dongle + gprs_downlink_vol_Dongle + data_uplink_vol_Dongle + data_downlink_vol_Dongle + 
 gprs_uplink_vol_PUG + gprs_downlink_vol_PUG + bb_downlink_vol + bb_uplink_vol)/(1024*1024) as usage_mb
 from `data-dtptechm-prd-c7ca.dwh.broadband_usage_dly_summary` a
 join `data-bi-prd-935c.bi_mart.fct_ga_site_id` b on cast(a.sbscrptn_ek_id as string) = cast(b.sbscrptn_ek_id as string) and date_trunc(b.dt,MONTH) = DATE_TRUNC(vdt_id,MONTH)
 where cast(created_dt_sk_id as date) >= b.dt --count the broadband usage start from ga_date 
 and cast(created_dt_sk_id as date) <= vdt_id
 group by 1
) d on a.sbscrptn_ek_id = d.sbscrptn_ek_id
where month_kpi_tag = 'M-0'
and heading_tag = 'ACQUISITION'
and cast(a.load_dt_sk_id as date) = vdt_id
and d.usage_mb >= 100
group by 1,2,3,4,5,6,8,9;

--##
--Site_25m0sc
--##

delete from `data-bi-prd-935c.bi_mart.h3i_project_ioh_kpi_daily_tracker_site` where load_dt_sk_id = vdt_id 
and kpi_code = 'Site_25m0sc';

insert into `data-bi-prd-935c.bi_mart.h3i_project_ioh_kpi_daily_tracker_site`
with addr_sites as 
(
select case when length(oldsiteid)=5 then CAST(CONCAT('0',oldsiteid) AS STRING) else oldsiteid end oldsiteid
, case when length(newsiteid)<9 then NULL else newsiteid end newsiteid,
	branch
from `data-bi-prd-935c.bi_mart.dm_phy_addressable_sites` a
left join `data-bi-prd-935c.bi_mart.ref_site_h3i` b on b.site_id=a.oldsiteid
left join `data-bi-prd-935c.bi_mart.ref_site_h3i` c on c.site_id=a.newsiteid
where mth = (select max(mth) from `data-bi-prd-935c.bi_mart.dm_phy_addressable_sites`  
                    where mth <= DATE_TRUNC(DATE_SUB(vdt_id, INTERVAL 1 MONTH), MONTH))
and upper(addressablesites) = 'ADDRESSABLE SITE'
),
base as 
(
select * from `data-bi-prd-935c.bi_mart.h3i_project_ioh_kpi_daily_tracker_site` b
where b.load_dt_sk_id = vdt_id
and b.kpi_code in ('M0SC_MTD')
and b.site_id is not null
)
select cast(load_dt_sk_id as date),
'h3i',
'Site_25m0sc',
'IOH',
cast(load_dt_sk_id as date)
,addrsite site_id
,count(1) 
,'site with scmo 25',CURRENT_TIMESTAMP() From 
(
select cast(vdt_id as date) load_dt_sk_id,
coalesce(newsiteid,oldsiteid) addrsite,
sum(value) kpi_value
from addr_sites a
left join base b
on (b.site_id=a.oldsiteid or b.site_id =a.newsiteid) 
group by 1,2
) x
where kpi_value>=25 group by 1,2,3,4,5,6,8,9;


--##
--Site_50m0sc
--##

delete from `data-bi-prd-935c.bi_mart.h3i_project_ioh_kpi_daily_tracker_site` where load_dt_sk_id = vdt_id 
and kpi_code = 'Site_50m0sc';

insert into `data-bi-prd-935c.bi_mart.h3i_project_ioh_kpi_daily_tracker_site`
with addr_sites as 
(
 select case when length(oldsiteid) = 5 then CAST(CONCAT('0',oldsiteid) AS STRING) else oldsiteid end oldsiteid, 
 case when length(newsiteid) < 9 then NULL else newsiteid end newsiteid, branch
 from `data-bi-prd-935c.bi_mart.dm_phy_addressable_sites` a
 left join `data-bi-prd-935c.bi_mart.ref_site_h3i` b on b.site_id=a.oldsiteid
 left join `data-bi-prd-935c.bi_mart.ref_site_h3i` c on c.site_id=a.newsiteid
 where mth = (select max(mth) from `data-bi-prd-935c.bi_mart.dm_phy_addressable_sites`  
                    where mth <= DATE_TRUNC(DATE_SUB(vdt_id, INTERVAL 1 MONTH), MONTH))
 and upper(addressablesites) = 'ADDRESSABLE SITE'
),
base as
(
select * from `data-bi-prd-935c.bi_mart.h3i_project_ioh_kpi_daily_tracker_site`  b
where b.load_dt_sk_id = vdt_id
and b.kpi_code in ('M0SC_MTD')
and value >= 50
and b.site_id is not null
)
select cast(vdt_id as date) as load_dt_sk_id, 'H3I' as entity, 'Site_50m0sc' as kpi_code, 'IOH' as definition,
cast(vdt_id as date), coalesce(b.site_id, 'N/A') as site_id, count(1) as value, 'SITE ROLLING 90', current_timestamp
from addr_sites a
left join base b on (b.site_id = a.oldsiteid or b.site_id = a.newsiteid) 
group by 1,2,3,4,5,6,8,9;

-- New SSO QSSO
 
		delete from 
		`data-bi-prd-935c.bi_mart.h3i_project_ioh_kpi_daily_tracker_site` 
		where load_Dt_Sk_id=vdt_id
		and kpi_code='qsso' ;

-- QSSO

		insert into `data-bi-prd-935c.bi_mart.h3i_project_ioh_kpi_daily_tracker_site`
		select dt as dt_sk_id
		,'H3I'
		,'qsso'
		,'IOH'
		,CAST(dt AS DATE)
		,case when length(ret_site_id)<6 then lpad(ret_site_id,6,'0') else ret_site_id end as site_id 
		,sum(qsso) cnt 
		,'QSSO >=3'
		,CURRENT_TIMESTAMP()
		from 
		`data-bi-prd-935c.bi_mart.subs_ret_qsso_detail_3` 
		where dt=vdt_id
		group by 1 ,2,3,4,5,6,8,9;

--qsso_any 

		delete from 
		`data-bi-prd-935c.bi_mart.h3i_project_ioh_kpi_daily_tracker_site` 
		where load_Dt_Sk_id=vdt_id
		and kpi_code='qsso_any';
	
		insert into `data-bi-prd-935c.bi_mart.h3i_project_ioh_kpi_daily_tracker_site`
		select dt as dt_sk_id
		,'H3I'
		,'qsso_any'
		,'IOH'
		,CAST(dt AS DATE)
		,case when length(ret_site_id)<6 then lpad(ret_site_id,6,'0') else ret_site_id end as site_id 
		,count(distinct retailer_qrcode) cnt 
		,'QSSO Any'
		,CURRENT_TIMESTAMP()
		from 
		(
				select dt,ret_site_id,retailer_qrcode,ret_branch,count(distinct sbscrptn_ek_id) as subs from 
				`data-bi-prd-935c.bi_mart.subs_ret_qsso_detail_2` 
				where 
				 dt=vdt_id
				 group by 1,2,3,4 
				having count(*) >=3 
		)x
		where dt=vdt_id
		group by 1 ,2,3,4,5,6,8,9;

		delete from 
		`data-bi-prd-935c.bi_mart.h3i_project_ioh_kpi_daily_tracker_site` 
		where load_Dt_Sk_id=vdt_id
		and kpi_code='sso_any';

insert into `data-bi-prd-935c.bi_mart.h3i_project_ioh_kpi_daily_tracker_site`
		select cast(dt_sk_id as date)as dt_sk_id
		,'H3I'
		,'sso_any'
		,'IOH'
		,cast(dt_sk_id as date)
		,case when length(site_id)<6 then lpad(site_id,6,'0') else site_id end as site_id 
		,sum(cnt) cnt 
		,'sso_any_sim_demand'
		,CURRENT_TIMESTAMP()
		from 
		(
		select dt_sk_id
		,site_id
		,cnt From 
		(
			SELECT 
				dt_sk_id,
				site_id,
				cnt 
			FROM (
				with subs as (select * from `data-bi-prd-935c.bi_mart.sbscrptn_attribs_hist7` where dt_id = date_add( vdt_id, Interval 1 day))
				SELECT 
					vdt_id AS dt_sk_id,
					site_id,
					COUNT(DISTINCT a.angie_retailer_name) AS cnt
				FROM subs a
				LEFT JOIN (
					SELECT * 
					FROM `data-bi-prd-935c.bi_mart.stg_v_map_tgt_ret_details_hist`
					WHERE dt = vdt_id
				) c ON a.angie_retailer_name = c.ret_qr_cd 
				LEFT OUTER JOIN `data-dtptechm-prd-c7ca.dwh.channel_dim` CD2 
					ON CD2.channel_sk_id = a.mp3_channel_sk_id
				LEFT OUTER JOIN `data-dtptechm-prd-c7ca.dwh.rprt_fltr_ref_ctgry` REF2 
					ON REF2.ref_cd = CD2.channel_id 
					AND REF2.ref_type_cd = 'MP3'
				WHERE  (
    SELECT MIN(d)
    FROM UNNEST([
      cast(first_usage_dt as date),
      safe.parse_date('%Y%m%d',cast(first_billing_usage_dt_sk_id as string)),
      cast(any_event_first_usage_date as date)
    ]) AS d
    WHERE d IS NOT NULL
  ) 
					BETWEEN DATE_TRUNC(vdt_id, MONTH)
						AND vdt_id
					AND partition_flag <> 'A'
					AND COALESCE(product_id, 8) = 8
					AND COALESCE(tool_of_trade_ind, 'N') = 'N'
				GROUP BY 1, 2
			) x 
			-- WHERE cnt >= 5
		)
		)f
		group by 1 ,2,3,4,5,6,8,9;
 
		delete from 
		`data-bi-prd-935c.bi_mart.h3i_project_ioh_kpi_daily_tracker_site` 
		where load_Dt_Sk_id = vdt_id
		and kpi_code='sso_any_sim_demand';

insert into `data-bi-prd-935c.bi_mart.h3i_project_ioh_kpi_daily_tracker_site`
		select cast(dt_sk_id as date) as dt_sk_id
		,'H3I'
		,'sso_any_sim_demand'
		,'IOH'
		,cast(dt_sk_id as date)
		,case when length(site_id)<6 then lpad(site_id,6,'0') else site_id end as site_id 
		,sum(cnt) cnt 
		,'sso_any_sim_demand'
		,CURRENT_TIMESTAMP()
		from 
		(
			SELECT 
				dt_sk_id,
				site_id,
				cnt
			FROM (
				with subs as (select * from `data-bi-prd-935c.bi_mart.sbscrptn_attribs_hist7` where dt_id = date_add( vdt_id, Interval 1 day))
				SELECT 
					vdt_id AS dt_sk_id,
					site_id,
					COUNT(DISTINCT a.angie_retailer_name) AS cnt
				FROM subs a
				LEFT JOIN (
					SELECT * 
					FROM `data-bi-prd-935c.bi_mart.stg_v_map_tgt_ret_details_hist`
					WHERE dt = vdt_id
				) c
				ON a.angie_retailer_name = c.ret_qr_cd 
				LEFT OUTER JOIN `data-dtptechm-prd-c7ca.dwh.channel_dim` CD2 
				ON CD2.channel_sk_id = a.mp3_channel_sk_id
				LEFT OUTER JOIN `data-dtptechm-prd-c7ca.dwh.rprt_fltr_ref_ctgry` REF2 
				ON REF2.ref_cd = CD2.channel_id 
				AND REF2.ref_type_cd = 'MP3'
				WHERE L (
    SELECT MIN(d)
    FROM UNNEST([
      cast(first_usage_dt as date),
      safe.parse_date('%Y%m%d',cast(first_billing_usage_dt_sk_id as string)),
      cast(any_event_first_usage_date as date)
    ]) AS d
    WHERE d IS NOT NULL
  )  BETWEEN SAFE_CAST(FORMAT_TIMESTAMP('%Y%m%d', TIMESTAMP(DATE_TRUNC(vdt_id, MONTH))) AS INT64)
						AND SAFE_CAST(FORMAT_TIMESTAMP('%Y%m%d', TIMESTAMP(vdt_id)) AS INT64)
				AND partition_flag <> 'A'
				AND COALESCE(product_id, 8) = 8
				AND COALESCE(tool_of_trade_ind, 'N') = 'N'
				GROUP BY dt_sk_id, site_id
						) x --where cnt >=5
		)f
		group by 1 ,2,3,4,5,6,8,9;
--

		delete from 
		`data-bi-prd-935c.bi_mart.h3i_project_ioh_kpi_daily_tracker_site` 
		where load_Dt_Sk_id=vdt_id
		and kpi_code='sso_any_3sp';

insert into `data-bi-prd-935c.bi_mart.h3i_project_ioh_kpi_daily_tracker_site`
		select cast(dt_sk_id as date) as dt_sk_id
		,'H3I'
		,'sso_any_3sp'
		,'IOH'
		,cast(dt_sk_id as date)
		,case when length(site_id)<6 then lpad(site_id,6,'0') else site_id end as site_id 
		,count(distinct angie_retailer_name ) cnt 
		,'sso_any_3sp'
		,CURRENT_TIMESTAMP()
		from 
		(
		select dt_sk_id
		,site_id
		,angie_retailer_name
		,cnt From 
		(
			with subs as (select * from `data-bi-prd-935c.bi_mart.sbscrptn_attribs_hist7` where dt_id = date_add( vdt_id, Interval 1 day))
			SELECT 
				vdt_id AS dt_sk_id,
				site_id,
				angie_retailer_name,
				COUNT(a.sbscrptn_ek_id) AS cnt
			FROM subs a
			LEFT JOIN (
				SELECT * 
				FROM `data-bi-prd-935c.bi_mart.stg_v_map_tgt_ret_details_hist` 
				WHERE dt = vdt_id
			) c
			ON a.angie_retailer_name = c.ret_qr_cd 
			LEFT OUTER JOIN `data-dtptechm-prd-c7ca.dwh.channel_dim` CD2 
			ON CD2.channel_sk_id = a.mp3_channel_sk_id
			LEFT OUTER JOIN `data-dtptechm-prd-c7ca.dwh.rprt_fltr_ref_ctgry` REF2 
			ON REF2.ref_cd = CD2.channel_id 
			AND REF2.ref_type_cd = 'MP3'
			WHERE  (
    SELECT MIN(d)
    FROM UNNEST([
      cast(first_usage_dt as date),
      safe.parse_date('%Y%m%d',cast(first_billing_usage_dt_sk_id as string)),
      cast(any_event_first_usage_date as date)
    ]) AS d
    WHERE d IS NOT NULL
  ) BETWEEN SAFE_CAST(FORMAT_TIMESTAMP('%Y%m%d', TIMESTAMP(DATE_TRUNC(vdt_id, MONTH))) AS INT64)
					AND SAFE_CAST(FORMAT_TIMESTAMP('%Y%m%d', TIMESTAMP(vdt_id)) AS INT64)
			AND partition_flag <> 'A'
			AND COALESCE(product_id, 8) = 8
			AND COALESCE(tool_of_trade_ind, 'N') = 'N'
			GROUP BY dt_sk_id, site_id, angie_retailer_name
		) x 
			where cnt >=3
		)f
		group by 1 ,2,3,4,5,6,8,9;

-- ****************--
-- Site_25QSC_250MB
-- ****************--

delete from `data-bi-prd-935c.bi_mart.h3i_project_ioh_kpi_daily_tracker_site` where load_dt_sk_id = vdt_id 
and kpi_code = 'Site_25QSC_250MB';

insert into `data-bi-prd-935c.bi_mart.h3i_project_ioh_kpi_daily_tracker_site`
with addres_site as 
(
       SELECT 
          CASE 
          WHEN LENGTH(oldsiteid) = 5 THEN CONCAT('0', oldsiteid) 
          ELSE oldsiteid 
          END AS oldsiteid,
          CASE 
          WHEN LENGTH(newsiteid) < 9 THEN NULL 
          ELSE newsiteid 
          END AS newsiteid,
          branch
        FROM `data-bi-prd-935c.bi_mart.dm_phy_addressable_sites` a
        LEFT JOIN `data-bi-prd-935c.bi_mart.ref_site_h3i` b 
          ON b.site_id = a.oldsiteid
        LEFT JOIN `data-bi-prd-935c.bi_mart.ref_site_h3i` c 
          ON c.site_id = a.newsiteid
        WHERE mth = (select max(mth) from `data-bi-prd-935c.bi_mart.dm_phy_addressable_sites`  
                    where mth <= DATE_TRUNC(DATE_SUB(vdt_id, INTERVAL 1 MONTH), MONTH))
          AND UPPER(addressablesites) = 'ADDRESSABLE SITE'
),
base as 
(
select * from `data-bi-prd-935c.bi_mart.h3i_project_ioh_kpi_daily_tracker_site` b
          where b.load_dt_sk_id = vdt_id
          AND b.kpi_code IN ('QSC_250MB')
        and b.site_id IS NOT NULL
)
select 
*
from
(
select
cast(vdt_id as date),
'h3i',
'Site_25QSC_250MB',
'IOH',
cast(vdt_id as date)
,site_id site_id
,count(1) KPI_Value
,'site with 25 QSC 250',CURRENT_TIMESTAMP() From 
      (

        SELECT 
        a.oldsiteid, 
        a.newsiteid,
        b.site_id
        FROM addres_site a
        LEFT JOIN base b
        ON (b.site_id = a.oldsiteid OR b.site_id = a.newsiteid)
        GROUP BY 1, 2, 3
    ) x group by 1,2,3,4,5,6,8,9
)
where kpi_value>=25 ;