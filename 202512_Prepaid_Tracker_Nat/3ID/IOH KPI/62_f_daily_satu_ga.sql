DECLARE vdt_id DATE DEFAULT @vdt_id;

--masuk ke part3
DELETE from `data-bi-prd-935c.bi_mart.project_ioh_kpi_daily_tracker_site`
where kpi_code in
(
'dsf_count_region',
'dsf_count_branch',
'sa_cnt_branch',
'dsf_ga_cnt',
'dsf_ga_rev',
'sa_cnt_region',
'dsf_gahv_cnt'
) and LOAD_dT_SK_ID=vdt_id ;


 

--ini masuk part2
delete From `data-bi-prd-935c.bi_mart.tmp_ga_rev`
where dt_sk_id=vdt_id ;


insert into  `data-bi-prd-935c.bi_mart.tmp_ga_rev`
select
cast(rb.trx_dt_sk_id as date) as dt_sk_id,
rb.sbscrptn_ek_id,
sum(net_revenue) as revenue
from `data-dtptechm-prd-c7ca.dwh.revenue_base` rb
where date(rb.trx_dt_sk_id) = vdt_id
and 
(
  rb.process_nm in ( select process_nm from `data-dtptechm-prd-c7ca.dwh.demand_revenue_base_filter` where net_revenue_incl = 'Y') and 
    rb.revenue_src_ctgry in ( select process_nm from `data-dtptechm-prd-c7ca.dwh.demand_revenue_base_filter` where net_revenue_incl = 'Y') 
)
and coalesce(rb.gl_cd,'NA') not in (select ref_cd from `data-dtptechm-prd-c7ca.dwh.rprt_fltr_ref_ctgry` where ref_type_cd = 'ACCRUAL_GL_CODE')
and rb.sbscrptn_ek_id is not null
and cast(rb.product_sk_id AS STRING) not in (select CAST(product_sk_id AS STRING) from `data-dtptechm-prd-c7ca.dwh.product_dim`
where product_primary_ref IN ('R34P100','R34P10','R34P20','R34P50','R67P10','RHP34','RHP67')
and product_type='RITA')
group by 1,2;
--Command BY Indra
		-- insert into`data-bi-prd-935c.bi_mart`.project_ioh_kpi_daily_tracker_site
		-- selectvdt_id load_Dt_Sk_id
		-- ,'H3I',
		-- case when b.DSF_Tag = 1 then 'dsf_ga_rev'
		--when b.ret_hierarchy_type = 'ANGIE' then 'trad_ga_rev'
		-- else 'nontrad_ga_rev' end as channel
		-- ,'acquisition revenue'
		-- , vdt_id date,
		-- a.site_id
		-- ,sum(coalesce(d.revenue,0)) as revenue
		-- ,'acquisition revenue'
		-- ,CURRENT_TIMESTAMP()
		-- --segment, 
		-- --coalesce(c.area, 'Others') as area, 
		-- --count(distinct a.sbscrptn_ek_id) as subs,
		-- from (select site_id,sbscrptn_ek_id from `data-bi-prd-935c.bi_mart.fct_ga_site_id` where dt >= CAST(FORMAT_DATE('%Y%m%d',DATE_TRUNC(vdt_id, MONTH)) AS INT64) and dt <=vdt_id group by 1,2 ) 
		-- a
		-- left outer join
		-- (
		--select distinct sbscrptn_ek_id, segment, c.ret_hierarchy_type, case when d.partner_qr_cd is null then 0 else 1 end as DSF_Tag
		--from `data-dtptechm-prd-c7ca.dwh.sbscrptn_attribs` a
		--left outer join `data-bi-prd-935c.bi_mart.ref_callplan_hvc_mvc_lvc` b on a.call_plan_desc = b.call_plan
		--left outer join `data-dtptechm-prd-c7ca.dwh.angie_hrchy_dim` c on a.angie_retailer_name = c.partner_qr_cd
		--left outer join
		--(
		-- select distinct partner_qr_cd 
		-- from `data-dtptechm-prd-c7ca.dwh.angie_hrchy_dim` 
		-- where partner_qr_cd in 
		-- (
		--select distinct retailer_qrcode
		--from `data-bi-prd-935c.bi_mart.dsf_reference_list`
		-- )
		--) d on a.angie_retailer_name = d.partner_qr_cd
		-- ) b on a.sbscrptn_ek_id = b.sbscrptn_ek_id
		-- ---left outer join
		-- --(
		-- -- -select case when length(site_id) <= 5 then LPAD(site_id,6,'0') else site_id end as site_id, area,
		-- -- row_number()over(partition by case when length(site_id) <= 5 then LPAD(site_id,6,'0') else site_id end order by site_nm) as seq
		-- -- from ioh_biadm.ref_site_h3i
		-- --) c on case when length(a.site_id) <= 5 then LPAD(a.site_id,6,'0') else a.site_id end = c.site_id and c.seq = 1
		-- left outer join 
		-- (
		--selectvdt_idmth, sbscrptn_ek_id, sum(revenue) as revenue
		--from `data-bi-prd-935c.bi_stg`.tmp_ga_rev
		--where dt_sk_id >= CAST(FORMAT_DATE('%Y%m%d',DATE_TRUNC(vdt_id, MONTH)) AS INT64) and dt_sk_id <= vdt_id 
		--group by 1,2
		-- ) d ona.sbscrptn_ek_id = d.sbscrptn_ek_id
		-- group by 1,2,3,4,5,6,8,9	
	-- ;
--masuk ke part3
		insert into`data-bi-prd-935c.bi_mart.project_ioh_kpi_daily_tracker_site`
select cast(vdt_id as date) load_Dt_Sk_id
		,'H3I',
		case when b.DSF_Tag = 1 then 'dsf_ga_cnt'
		 when b.ret_hierarchy_type = 'ANGIE' then 'trad_ga_cnt'
		else 'nontrad_ga_cnt' end as channel
		,'acquisition revenue'
		, cast(vdt_id as date) date,
		a.site_id
		,count(distinct a.sbscrptn_ek_id) as subs
		,'acquisition revenue'
		,CURRENT_TIMESTAMP()
		--segment, 
		--coalesce(c.area, 'Others') as area, 
		--count(distinct a.sbscrptn_ek_id) as subs,
		from (select site_id,sbscrptn_ek_id from `data-bi-prd-935c.bi_mart.fct_ga_site_id` where dt >= DATE_TRUNC(vdt_id, MONTH) and dt <=CAST(vdt_id AS date) group by 1,2 ) 
		a
		left outer join
		(
		with subs as (select * from `data-dtptechm-prd-c7ca.dwh.sbscrptn_attribs`)
		 select distinct sbscrptn_ek_id, segment, c.ret_hierarchy_type, case when d.partner_qr_cd is null then 0 else 1 end as DSF_Tag
		 from subs a
		 left outer join `data-bi-prd-935c.bi_mart.ref_callplan_hvc_mvc_lvc` b on a.call_plan_desc = b.call_plan 
		 left outer join `data-dtptechm-prd-c7ca.dwh.angie_hrchy_dim` c on a.angie_retailer_name = c.partner_qr_cd
		 left outer join
		 (
		select distinct partner_qr_cd 
		from `data-dtptechm-prd-c7ca.dwh.angie_hrchy_dim` 
		where partner_qr_cd in 
		(
		 select distinct retailer_qrcode
		 from `data-bi-prd-935c.bi_mart.dsf_reference_list`
		)
		 ) d on a.angie_retailer_name = d.partner_qr_cd
		) b on cast(a.sbscrptn_ek_id as string) = cast(b.sbscrptn_ek_id as string)
		---left outer join
		--(
		-- -select case when length(site_id) <= 5 then LPAD(site_id,6,'0') else site_id end as site_id, area,
		-- row_number()over(partition by case when length(site_id) <= 5 then LPAD(site_id,6,'0') else site_id end order by site_nm) as seq
		-- from ioh_biadm.ref_site_h3i
		--) c on case when length(a.site_id) <= 5 then LPAD(a.site_id,6,'0') else a.site_id end = c.site_id and c.seq = 1
		left outer join 
		(
		 select vdt_id mth, sbscrptn_ek_id, sum(revenue) as revenue
		 from  `data-bi-prd-935c.bi_mart.tmp_ga_rev`
		 where dt_sk_id >= DATE_TRUNC(vdt_id, MONTH) and dt_sk_id <= CAST(vdt_id AS DATE) 
		 group by 1,2
		) d on cast(a.sbscrptn_ek_id as string) = cast(d.sbscrptn_ek_id as string)
		group by 1,2,3,4,5,6,8,9	
	;

insert into`data-bi-prd-935c.bi_mart.project_ioh_kpi_daily_tracker_site`
		select cast(vdt_id as date) load_Dt_Sk_id
		,'H3I',
		'dsf_count_region'
		,'acquisition revenue'
		,cast(vdt_id as date) date,
		case when upper(coalesce(mp3_location, 'N/A')) in ('ACEH', 'LHOKSEUMAWE', 'MEDAN', 'DELI SERDANG', 'KISARAN',
		 'SIANTAR', 'BATAM', 'PADANG', 'PEKANBARU', 'BENGKULU LAMPUNG','BENGKULU - LAMPUNG', 'JAMBI', 'PALEMBANG') then 'SUMATERA'
		 when upper(coalesce(mp3_location, 'N/A')) in ('CENTRAL WEST NORTH JKT', 'EAST SOUTH JKT DEPOK', 'TANGERANG', 'BEKASI', 'BOGOR', 'SERANG','KARAWANG') then 'JBRO'
		 when upper(coalesce(mp3_location, 'N/A')) in ('BANDUNG', 'TASIKMALAYA', 'CIREBON','BANDUNG OUTER','BANDUNG INNER','BSM CIANJUR','CIANJUR','CIANJUR SUKABUMI') then 'CWJ'
		 when upper(coalesce(mp3_location, 'N/A')) in ('BALIKPAPAN', 'BANJARMASIN', 'PONTIANAK', 'MAKASSAR INNER', 'MAKASSAR OUTER','MAKASSAR', 'MANADO') then 'KALISULA'
		 when upper(coalesce(mp3_location, 'N/A')) in ('PURWOKERTO', 'SEMARANG INNER','SEMARANG', 'YOGYAKARTA', 'SOLO','SEMARANG OUTER','TEGAL','BSM TEGAL') then 'CWJ'
		 when upper(coalesce(mp3_location, 'N/A')) in ('MALANG', 'BLITAR', 'KEDIRI', 'SURABAYA', 'SIDOARJO', 'GRESIK', 'MOJOKERTO', 'JEMBER', 'BALI', 'LOMBOK', 'MADIUN', 'PONOROGO') then 'EJBN'
		 when upper(coalesce(mp3_location, 'N/A')) in ('3 BUSINESS') then '3BISNIS'
		 when upper(coalesce(mp3_location, 'N/A')) in ('3 STORE') then '3STORE'
		 else upper(coalesce(mp3_location, 'n/a')) end as region
		,count(*) as revenue
		,'dsf count'
		,CURRENT_TIMESTAMP()
		--segment, 
		--coalesce(c.area, 'Others') as area, 
		--count(distinct a.sbscrptn_ek_id) as subs,
from 
`data-dtptechm-prd-c7ca.dwh.angie_hrchy_dim` 
where partner_type='DSF'
and ret_hierarchy_type='ANGIE'
and partner_status='Active' and mp3_location 
not in 
('POOL','DVM BM','SIM ONLINE','BSM TRI OFFICIAL STORE','3 BUSINESS','3 STORE','SOUTH JAKARTA TEST BM')
AND 
CAST(ret_active_date AS date) >= '2022-08-01'
and CAST(ret_active_date AS date)<=CAST(vdt_id AS date)
AND mp3_location NOT LIKE '%KIOSK%'
		group by 1,2,3,4,5,6,8,9
		union all 

select cast(vdt_id as date) load_Dt_Sk_id
		,'H3I',
		'dsf_count_branch'
		,'acquisition revenue'
		,cast(vdt_id as date) date,
		mp3_location
		,count(*) as revenue
		,'dsf count'
		,CURRENT_TIMESTAMP()
		--segment, 
		--coalesce(c.area, 'Others') as area, 
		--count(distinct a.sbscrptn_ek_id) as subs,
from 
`data-dtptechm-prd-c7ca.dwh.angie_hrchy_dim` 
where partner_type='DSF'
and ret_hierarchy_type='ANGIE'
and partner_status='Active' 
and mp3_location 
not in 
('POOL','DVM BM','SIM ONLINE','BSM TRI OFFICIAL STORE','3 BUSINESS','3 STORE','SOUTH JAKARTA TEST BM')
and CAST(ret_active_date AS date) >= '2022-08-01'
AND mp3_location NOT LIKE '%KIOSK%'
and CAST(ret_active_date AS date)<=vdt_id

		group by 1,2,3,4,5,6,8,9
;


--yang dibutuhkan part2 
delete from 
`data-bi-prd-935c.bi_mart.cse_1` where mth=vdt_id ;

insert into `data-bi-prd-935c.bi_mart.cse_1`
	select 
	--date_trunc(vdt_id,month) as mth,
	cast(vdt_id as date) as mth,
cast(vdt_id as date) as dt_sk_id
	,can_id sales 
	, qr_code
	,sum(receiver_credit_amount) amount 
	from 
		(
	select trx_dt_sk_id ,sender_msisdn,receiver_msisdn,c.qr_code,c.created,c.last_upd,b.par_row_id as can_id, c.par_row_id as ret_id
	,sum(CAST(receiver_credit_amount AS INT64)) receiver_credit_amount,sum(cnt)cnt from 
	(
	select trx_dt_sk_id,sender_msisdn,receiver_msisdn,count(*) as cnt
	,sum(CAST(sender_debit_amount AS INT64)),sum(CAST(receiver_credit_amount AS INT64))receiver_credit_amount,sum(CAST(transfer_amount AS INT64))
	from `data-dtptechm-prd-c7ca.dwh.pretaps_channel_transaction_fct` fct
	WHERE cast(fct.trx_dt_sk_id as date) between DATE_TRUNC(vdt_id, MONTH) and CAST(vdt_id AS date)
	and sender_category ='CAN' and receiver_category='RET' 
	and transfer_ctgry ='TRF'
	---and CAST(receiver_credit_amount AS INT64) >=50000
	group by 1 ,2,3
	) a left join 
	(
	--canvasser
	select cast(created as date)  created ,
	case when status in ('Active','Suspended') then '9999-12-31' 
	else cast(last_upd as date)  end as last_upd,
	row_id,par_row_id,name,partner_type,qr_code from
	`data-dtptechm-prd-c7ca.stg.stg_cx_angie_msisdn`
	where partner_type ='Canvasser'
	---and name in ('089688715680','08993594882')
		and status in 
		(	
	'Terminated',
	'Suspended',
	'Active'
		) 
		group by 1,2,3,4,5,6,7
	) b on a.sender_msisdn=b.name and cast(a.trx_dt_sk_id as date)>= cast(b.created as date) and cast(a.trx_dt_sk_id as date) <= cast(b.last_upd as date) 
	left join 
	(
	---retailer
	select CAST(created AS date) created ,
	case when status in ('Active','Suspended') then '9999-12-31'
	else cast(last_upd as date)   end as last_upd
	, row_id
	,par_row_id
	,name
	,partner_type
	,qr_code from
		`data-dtptechm-prd-c7ca.stg.stg_cx_angie_msisdn`
		where partner_type ='Retailer'
		and status in 
		(	
	'Terminated',
	'Suspended',
	'Active'
		) 
		--and name in ('08979372919' )
		group by 1,2,3,4,5,6,7
	) c on a.receiver_msisdn=c.name and cast(a.trx_dt_sk_id as date) >= cast(c.created as date) and cast(a.trx_dt_sk_id as date)<=cast(c.last_upd as date) 
	group by 1
	,2,3,4,5,6,7,8
	) a 
		group by 1,2 ,3,4;

--sampai sini

insert into `data-bi-prd-935c.bi_mart.project_ioh_kpi_daily_tracker_site`
select mth,'H3I','sa_cnt_branch','IOH',CAST(mth AS DATE),mp3_location,count(distinct sales),'SA Count branch',CURRENT_TIMESTAMP() from 
`data-bi-prd-935c.bi_mart.cse_1` a left join 
`data-dtptechm-prd-c7ca.dwh.angie_hrchy_dim` b on a.sales=b.row_id
where mp3_location not like '%KIOSK%'
and mth =vdt_id 
group by 1,2,3,4,6,8,9;

insert into `data-bi-prd-935c.bi_mart.project_ioh_kpi_daily_tracker_site`
select mth
,'H3I'
,'sa_cnt_region'
,'IOH'
,CAST(mth AS DATE),
case when upper(coalesce(mp3_location, 'N/A')) in ('ACEH', 'LHOKSEUMAWE', 'MEDAN', 'DELI SERDANG', 'KISARAN',
		 'SIANTAR', 'BATAM', 'PADANG', 'PEKANBARU', 'BENGKULU LAMPUNG','BENGKULU - LAMPUNG', 'JAMBI', 'PALEMBANG') then 'SUMATERA'
		 when upper(coalesce(mp3_location, 'N/A')) in ('CENTRAL WEST NORTH JKT', 'EAST SOUTH JKT DEPOK', 'TANGERANG', 'BEKASI', 'BOGOR', 'SERANG','KARAWANG') then 'JBRO'
		 when upper(coalesce(mp3_location, 'N/A')) in ('BANDUNG','BANDUNG INNER' ,'TASIKMALAYA', 'CIREBON','BANDUNG OUTER','BANDUNG INNER','BSM CIANJUR','CIANJUR','CIANJUR SUKABUMI') then 'CWJ'
		 when upper(coalesce(mp3_location, 'N/A')) in ('BALIKPAPAN', 'BANJARMASIN', 'PONTIANAK', 'MAKASSAR INNER', 'MAKASSAR OUTER','MAKASSAR', 'MANADO') then 'KALISULA'
		 when upper(coalesce(mp3_location, 'N/A')) in ('PURWOKERTO', 'SEMARANG','SEMARANG INNER', 'YOGYAKARTA', 'SOLO','SEMARANG OUTER','TEGAL','BSM TEGAL') then 'CWJ'
		 when upper(coalesce(mp3_location, 'N/A')) in ('MALANG', 'BLITAR', 'KEDIRI', 'SURABAYA', 'SIDOARJO', 'GRESIK', 'MOJOKERTO', 'JEMBER', 'BALI', 'LOMBOK', 'MADIUN', 'PONOROGO') then 'EJBN'
		 when upper(coalesce(mp3_location, 'N/A')) in ('3 BUSINESS') then '3BISNIS'
		 when upper(coalesce(mp3_location, 'N/A')) in ('3 STORE') then '3STORE'
		 else upper(coalesce(mp3_location, 'n/a')) end as region,
count(distinct sales)QA
,'SA Count Region'
,CURRENT_TIMESTAMP() from 
`data-bi-prd-935c.bi_mart.cse_1` a left join 
`data-dtptechm-prd-c7ca.dwh.angie_hrchy_dim` b on a.sales=b.row_id where mp3_location not like '%KIOSK%' 
and mth = vdt_id --- and vdt_id ||' 
group by 1,2,3,4,6,8,9; 

		insert into`data-bi-prd-935c.bi_mart.project_ioh_kpi_daily_tracker_site`
		select cast(vdt_id as date) load_Dt_Sk_id
		,'H3I',
		case when b.DSF_Tag = 1 then 'dsf_gahv_cnt'
		 when b.ret_hierarchy_type = 'ANGIE' then 'trad_gahv_cnt'
		else 'nontrad_gahv_cnt' end as channel
		,'acquisition revenue'
		, cast(vdt_id as date) date,
		a.site_id
		,count(distinct a.sbscrptn_ek_id) as subs
		,'acquisition revenue'
		,CURRENT_TIMESTAMP()
		--segment, 
		--coalesce(c.area, 'Others') as area, 
		--count(distinct a.sbscrptn_ek_id) as subs,
		from (select site_id,sbscrptn_ek_id from `data-bi-prd-935c.bi_mart.fct_ga_site_id` where dt >=DATE_TRUNC(vdt_id, MONTH) and dt <=vdt_id group by 1,2 ) 
		a
		left outer join
		(
		with subs as (select * from `data-dtptechm-prd-c7ca.dwh.sbscrptn_attribs`)	
		 select distinct sbscrptn_ek_id, upper(promo_desc)promo_desc, c.ret_hierarchy_type, case when d.partner_qr_cd is null then 0 else 1 end as DSF_Tag
		 from subs a
		 left outer join `data-bi-prd-935c.bi_mart.ref_callplan_hvc_mvc_lvc` b on a.call_plan_desc = b.call_plan 
		 left outer join `data-dtptechm-prd-c7ca.dwh.angie_hrchy_dim` c on a.angie_retailer_name = c.partner_qr_cd
		 left outer join
		 (
		select distinct partner_qr_cd 
		from `data-dtptechm-prd-c7ca.dwh.angie_hrchy_dim` 
		where partner_qr_cd in 
		(
		 select distinct retailer_qrcode
		 from `data-bi-prd-935c.bi_mart.dsf_reference_list`
		)
		 ) d on a.angie_retailer_name = d.partner_qr_cd
		) b on cast(a.sbscrptn_ek_id as string) = cast(b.sbscrptn_ek_id as string)
		---left outer join
		--(
		-- -select case when length(site_id) <= 5 then LPAD(site_id,6,'0') else site_id end as site_id, area,
		-- row_number()over(partition by case when length(site_id) <= 5 then LPAD(site_id,6,'0') else site_id end order by site_nm) as seq
		-- from ioh_biadm.ref_site_h3i
		--) c on case when length(a.site_id) <= 5 then LPAD(a.site_id,6,'0') else a.site_id end = c.site_id and c.seq = 1
		left outer join 
		(
		 select vdt_id mth, sbscrptn_ek_id, sum(revenue) as revenue
		 from  `data-bi-prd-935c.bi_mart.tmp_ga_rev`
		 where dt_sk_id >= DATE_TRUNC(vdt_id, MONTH) and dt_sk_id <= vdt_id 
		 group by 1,2
		) d on cast(a.sbscrptn_ek_id as string)= cast(d.sbscrptn_ek_id as string)
		where upper(promo_desc) in (
 'SP HP52',
 'SP HP9',
 'SP-PMAX-4GB-2018',
 'KEPO9',
 'SP BM9X',
 'SP HAPPY 52GB',
 'AON22 SPECIAL',
 'AON52 SPECIAL',
 'HAPPY 7',
 'MINI 1GB',
 'SP MINI 1GB',
 'SP_MINI 1GB C2028',
 'SP BM3X',
 'MINI 1GB C2028',
 'SP-PMAX-4GB-2018',
 'SP-PMAX-4GB',
 'PACUAN MAX 4GB',
 'SP HP52',
 'SP HAPPY 52GB',
 'PACUAN 4GB',
 'PM22SP',
 'SP BM9X',
 'MINI 3GB',
 'SP_MINI 3GB'
) 

		group by 1,2,3,4,5,6,8,9	
	;