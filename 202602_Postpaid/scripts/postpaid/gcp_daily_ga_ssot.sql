insert into `data-nationalslsdist-prd-986g`.postpaid.raw_daily_ga
with ga_bi as (
	select
		a.msisdn,
		b.activation_date,
		a.order_type,
		a.dealer_id,
		a.salesperson,
		a.submitted_by,
		a.pkg_nm
	from (
			select
		 	* 
		 	from(
				select 
					msisdn,
					flag,
					order_type,
					dealer_id,
					salesperson,
					submitted_by,
					pkg_nm,
					row_number() over(partition by msisdn order by dt_id desc) as rnk
				-- from `data-bi-prd-935c.bi_dm.rk_cst_pstpaid_ga_v1`
				from `data-bi-prd-935c.bi_mart.cst_pstpaid_ga_v1`
					where date(dt_id)=PARSE_DATE('%Y%m%d', '{dt_id}')
					-- where date(dt_id)between date(SUBSTR('{dt_id}',1,4) || '-' || SUBSTR('{dt_id}',5,2) || '-01') 
					-- and PARSE_DATE('%Y%m%d', '{dt_id}')
						and flag like '2%'
			) as x where x.rnk=1
		) as a
		left join (
			select * from (
			select
				msisdn,
				format_date('%Y%m%d',dt_id) as activation_date,
				row_number() over(partition by msisdn order by dt_id desc) as rnk
			-- from `data-bi-prd-935c.bi_dm.rk_cst_pstpaid_ga_v1`
			from `data-bi-prd-935c.bi_mart.cst_pstpaid_ga_v1`
				where date(dt_id)between date(SUBSTR('{dt_id}',1,4) || '-' || SUBSTR('{dt_id}',5,2) || '-01') 
					and PARSE_DATE('%Y%m%d', '{dt_id}')
					and flag like '1%'
			) as y where y.rnk=1
		) as b
		on a.msisdn=b.msisdn
),
ga_verf as(
	select * from (
  SELECT 
  format_date('%Y%m%d',SAFE.PARSE_DATE('%m/%d/%Y', LEFT(activation_date, 10))) AS activation_date,
  REPLACE(account_num, '\\', '') AS account_num,
    REPLACE(msisdn, '\\', '') AS msisdn,
    CONCAT(cust_first_name, cust_last_name) AS cust_name,
    SAFE_CAST(package_name AS STRING) AS package_name,
    name AS order_type,
    LEFT(galeri_name, 4) AS dealerid,
    SUBSTR(galeri_name, 6, 50) AS store,
    REPLACE(id_number, '\\', '') AS id_number,
    salesperson_nm,
    `comment` AS comment_text,
    order_created_by AS created,
    outlet_code,
    outlet_name,
    galeri_name,
    branch_name,
    region_name,
    LEFT(galeri_name, 4) AS store_code,
    IF(ARRAY_LENGTH(SPLIT(order_created_by, '-')) > 0, SPLIT(order_created_by, '-')[OFFSET(ARRAY_LENGTH(SPLIT(order_created_by, '-')) - 1)], NULL) AS sales_name,
    CASE 
      WHEN ARRAY_LENGTH(SPLIT(order_created_by, '-')) = 2 THEN SPLIT(order_created_by, '-')[OFFSET(0)]
      WHEN ARRAY_LENGTH(SPLIT(order_created_by, '-')) = 3 THEN CONCAT(SPLIT(order_created_by, '-')[OFFSET(0)], '-', SPLIT(order_created_by, '-')[OFFSET(1)])
      WHEN ARRAY_LENGTH(SPLIT(order_created_by, '-')) = 4 THEN CONCAT(SPLIT(order_created_by, '-')[OFFSET(0)], '-', SPLIT(order_created_by, '-')[OFFSET(1)], '-', SPLIT(order_created_by, '-')[OFFSET(2)])
    END AS nik_sales,
  row_number() over(partition by msisdn order by format_date('%Y%m%d',SAFE.PARSE_DATE('%m/%d/%Y', LEFT(activation_date, 10))) desc) as rnk
  FROM `data-nationalslsdist-prd-986g`.postpaid.raw_new_verification as a
  WHERE SAFE.PARSE_DATE('%m/%d/%Y', SUBSTR(a.activation_date, 1, 10)) <= PARSE_DATE('%Y%m%d', '{dt_id}')
  	AND FORMAT_DATE('%Y%m', SAFE.PARSE_DATE('%m/%d/%Y', SUBSTR(a.activation_date, 1, 10))) = SUBSTR('{dt_id}', 1, 6)
	) as x where x.rnk=1	
),
ga_new as(
select
	coalesce(ga_bi.activation_date, ga_verf.activation_date, subs.activation_date) as activation_date,
	coalesce(ga_verf.account_num, subs.account_num) as account_num, 
	ga_bi.msisdn,
	coalesce(ga_verf.cust_name, subs.cust_name) as cust_name,
	coalesce(ga_bi.pkg_nm, ga_verf.package_name, subs.package_name) as package_name, 
	ga_bi.order_type, 
	coalesce(ga_bi.dealer_id, ga_verf.dealerid) as dealerid,
	ga_verf.store, 
	coalesce(ga_verf.id_number, subs.id_number) as id_number,
	coalesce(ga_bi.salesperson, ga_verf.salesperson_nm) as salesperson_nm,
	ga_verf.comment_text,
	case when ga_bi.submitted_by <>'SADMIN' then ga_bi.submitted_by
		else ga_verf.created end as created,
	ga_verf.outlet_code,
    ga_verf.outlet_name,
    ga_verf.galeri_name,
    coalesce(ga_verf.branch_name, subs.branch_name) as branch_name,
    coalesce(ga_verf.region_name, subs.region_name) as region_name,
    ga_verf.store_code,
    ga_verf.sales_name,
    ga_verf.nik_sales
from ga_bi
	left join ga_verf
		on ga_bi.msisdn=ga_verf.msisdn
	left join (
		select a.* from (
			select 
				format_date('%Y%m%d', a.actvn_dt) as activation_date,
				a.ac_num as account_num,
				a.msisdn,
				a.ac_nm as cust_name, 
				a.pkg_nm as package_name,
				a.iccid as id_number,
				a.hlr_region as region_name,
				a.hlr_branch as branch_name, 
				row_number() over(partition by a.msisdn order by a.dt_id desc) rnk
			from `data-dtp-prd-aa1a.smy.ar_cst_pstpaid_rtl` as a
			where date(a.dt_id) between date(SUBSTR('{dt_id}',1,4) || '-' || SUBSTR('{dt_id}',5,2) || '-01')
				and PARSE_DATE('%Y%m%d', '{dt_id}')
				and a.ac_st='Active'
		) as a where a.rnk=1
	) subs
		on ga_bi.msisdn=subs.msisdn
)
-- , ga_cpp as(
-- 	select * from (
-- 		select
-- 			-- format_date('%Y%m%d', DATETIME(a.completiondate,'Asia/Jakarta')) as activation_date, 
-- 			format_date('%Y%m%d', a.completiondate) as activation_date, 
-- 			a.account_num, 
-- 			a.msisdn,
-- 			a.cst_nm as cust_name, 
-- 			a.main_package as package_name, 
-- 			a.order_type, 
-- 			case when (a.dealer_id = '' or a.dealer_id is null) then a.salesperson 
-- 				when a.dealer_id like 'SMB0%' and ARRAY_LENGTH(SPLIT(a.dealer_id, '-')) = 2 then SPLIT(a.dealer_id, '-')[OFFSET(0)]
-- 				else left(a.dealer_id, 4) end as dealerid,
-- 			CASE 
--       			WHEN ARRAY_LENGTH(SPLIT(a.dealer_id, '-')) = 2 THEN SPLIT(a.dealer_id, '-')[OFFSET(1)]
--       		end as store,
-- 			a.asset_num as id_number,
-- 			a.salesperson as salesperson_nm,
-- 			a.channel as comment_text, 
-- 			a.created_by as created,
-- 			a.outlet as outlet_code,
-- 			a.outlet as outlet_name, 
-- 			CASE WHEN ARRAY_LENGTH(SPLIT(a.dealer_id, '-')) = 2 THEN SPLIT(a.dealer_id, '-')[OFFSET(1)]
--       			end as galeri_name,
-- 			a.hlr_branch as branch_name,
-- 			a.hlr_region as region_name,
-- 			case when (a.dealer_id = '' or a.dealer_id is null) then a.salesperson
-- 				else left(a.dealer_id, 4) end as store_code,
-- 			case when (a.salesperson ='' or a.salesperson is null) and not regexp_contains(lower(a.created_by),r'admin|user|eai') then a.created_by
-- 				else a.salesperson end as sales_name, 
-- 			case when (a.salesperson ='' or a.salesperson is null) and not regexp_contains(lower(a.nik),r'admin|user') then a.nik
-- 				else a.salesperson end as nik_sales, 
-- 			row_number() over(partition by a.msisdn order by a.completiondate desc) as idx
-- 		from `data-dtp-prd-aa1a.smy.ar_change_pkg_pstpaid_rtl` as a 
-- 			where 1=1 
-- 			and a.dt_id>=TIMESTAMP_SUB(TIMESTAMP(PARSE_DATE('%Y%m%d', '{dt_id}')), INTERVAL 45 DAY)			
-- 			and format_date('%Y%m', a.completiondate)=left('{dt_id}',6)
-- 			and format_date('%Y%m%d', a.completiondate)<='{dt_id}'
-- 	) as x where x.idx=1 
-- )
, ga_cpp_new as (
select * from (
	select 
				format_date('%Y%m%d', a.completion_date) as activation_date, 
				a.account_num, 
				a.msisdn,
				a.assetname as cust_name, 
				a.main_package as package_name, 
				a.order_type, 
				case when (a.dealer_id = '' or a.dealer_id is null) then a.salesperson 
					when a.dealer_id like 'SMB0%' and ARRAY_LENGTH(SPLIT(a.dealer_id, '-')) = 2 then SPLIT(a.dealer_id, '-')[OFFSET(0)]
					else left(a.dealer_id, 4) end as dealerid,
				CASE 
	      			WHEN ARRAY_LENGTH(SPLIT(a.dealer_id, '-')) = 2 THEN SPLIT(a.dealer_id, '-')[OFFSET(1)]
	      		end as store,
				cast(null as string) as id_number,
				a.salesperson as salesperson_nm,
				a.channel as comment_text, 
				a.created_by as created,
				cast(null as string) as outlet_code,
				cast(null as string) as outlet_name, 
				CASE WHEN ARRAY_LENGTH(SPLIT(a.dealer_id, '-')) = 2 THEN SPLIT(a.dealer_id, '-')[OFFSET(1)]
	      			end as galeri_name,
				cast(null as string) as branch_name,
				cast(null as string) as region_name,
				case when (a.dealer_id = '' or a.dealer_id is null) then a.salesperson
					else left(a.dealer_id, 4) end as store_code,
				case when (a.salesperson ='' or a.salesperson is null) and not regexp_contains(lower(a.created_by),r'admin|user|eai') then a.created_by
					else a.salesperson end as sales_name, 
				case when (a.salesperson ='' or a.salesperson is null) and not regexp_contains(lower(a.nik),r'admin|user') then a.nik
					else a.salesperson end as nik_sales, 
				row_number() over(partition by a.msisdn order by a.completion_date desc) as idx
	from `data-dtp-prd-aa1a.stg.stg_siebel_dly_ordr` as a
--	left join  `data-nationalslsdist-prd-986g`.postpaid.raw_daily_ga as b
--			on a.msisdn=b.msisdn and b.activation_date>='20250901' 
--	left join  `data-nationalslsdist-prd-986g`.postpaid.raw_daily_ga as c
--			on a.msisdn=c.msisdn and c.activation_date>='20250901'
	 left join (
		select a.* from (
				select 
					a.ac_num as account_num,
					a.msisdn,
					a.ac_st,
					a.ast_st,
					a.dt_id,
					row_number() over(partition by a.msisdn order by a.dt_id desc) rnk
				from `data-dtp-prd-aa1a.smy.ar_cst_pstpaid_rtl` as a
				where date(a.dt_id) between date(SUBSTR('{dt_id}',1,4) || '-' || SUBSTR('{dt_id}',5,2) || '-01')
					and PARSE_DATE('%Y%m%d', '{dt_id}')
--				where date(a.dt_id)=PARSE_DATE('%Y%m%d', '{dt_id}')
			) as a where a.rnk=1
				-- and a.ac_st not in ('Inactive', 'Suspended', 'Hard-Blocked', 'Soft-Blocked') 
				and a.ast_st = 'Active'
	) as y
		on a.msisdn=y.msisdn
	where date(a.dt_id) between date(SUBSTR('{dt_id}',1,4) || '-' || SUBSTR('{dt_id}',5,2) || '-01')
		and PARSE_DATE('%Y%m%d', '{dt_id}')
		and format_date('%Y%m', DATETIME(a.completion_date,'Asia/Jakarta'))=left('{dt_id}',6)
		and format_date('%Y%m%d', DATETIME(a.completion_date,'Asia/Jakarta'))<='{dt_id}'
		and a.order_type='Change Postpaid Plan'
		and a.order_status='Complete'
		and a.product_type = 'Package'
		and a.`action`='Add'
		-- and b.msisdn is null
) as x 
	where x.idx=1 
	and (lower(x.package_name) like '%prime%' or lower(x.package_name) like '%platinum%')
--	and msisdn = '628155002662'
)
, ga_base as (
	select
		a.activation_date, 
		a.account_num,
		a.msisdn, 
		a.cust_name, 
		a.package_name,
		a.order_type, 
		a.dealerid as dealer_id, 
		cast(a.store as string) store,
		cast(a.id_number as string) id_number,
		a.salesperson_nm, 
		a.comment_text,  
		a.created,
		a.outlet_code,
		a.outlet_name,
		a.galeri_name, 
		a.branch_name,
		a.region_name, 
		a.store_code, 
		a.sales_name, 
		a.nik_sales
	from ga_new as a 
	-- where lower(a.package_name) like '%prime%' or lower(a.package_name) like '%platinum%'
	union all
	select 
		b.activation_date, 
		b.account_num,
		b.msisdn, 
		b.cust_name, 
		b.package_name,
		b.order_type, 
		b.dealerid as dealer_id, 
		cast(b.store as string) store,
		cast(b.id_number as string) id_number,
		b.salesperson_nm, 
		b.comment_text, 
		b.created,
		cast(b.outlet_code as string) outlet_code,
		cast(b.outlet_name as string) outlet_name,
		cast(b.galeri_name as string) galeri_name, 
		cast(b.branch_name as string) branch_name,
		cast(b.region_name as string) region_name, 
		b.store_code, 
		b.sales_name, 
		b.nik_sales
	-- from ga_cpp as b
	from ga_cpp_new as b
	where lower(b.package_name) like '%prime%' or lower(b.package_name) like '%platinum%'
)
, ga_store as(
select * from(
select 
	a.activation_date,
	a.account_num,
	a.msisdn, 
	a.cust_name,
	a.package_name,
	a.order_type, 
	coalesce(b.contract_status, c.package_type) as package_type, 
	coalesce(b.tenure, c.tenure) as tenure, 
	a.dealer_id, 
	a.store, 
	case when a.dealer_id ='DC11' then 'Partner Store' 
		when a.dealer_id like 'DS%' then 'Direct Sales'
		when a.dealer_id like 'OLA%' or a.dealer_id like 'MYM3%' then 'OLA'
		when a.dealer_id='FCPR' then 'JV'
		when a.store like 'MPC%' then 'MPC'
		when a.store like 'TP%' then 'Thirdparty'
		when a.dealer_id='TLS1' then 'Telesales'
		when a.dealer_id='JKBB' then 'Others'
		when a.dealer_id<>'' and a.dealer_id is not null then 'Gerai'
		else cast(null as string) end as channel, 
	a.region_name as region,
	a.branch_name as area,
	a.id_number, 
	a.salesperson_nm,
	a.comment_text, 
	a.created, 
	a.outlet_code, 
	a.outlet_name, 
	a.galeri_name, 
	a.branch_name, 
	a.region_name, 
	a.sales_name,
	a.nik_sales,
	case when a.salesperson_nm in 
				(select distinct store_code  from `data-nationalslsdist-prd-986g`.postpaid.ref_storelist_base rsb 
				where lower(channel_group) like 'partner store%' and (closed_date is null or closed_date='')) 
				and a.dealer_id='DC11' then a.salesperson_nm
		when a.dealer_id in ('ALTC','DC11','DCCS','JKBB','JKBA','OLA1') 
				and (d.store_code is not null or e.store_code is not null or f.store_code is not null) 
				-- and coalesce(d.store_code,e.store_code,f.store_code) is not null 
				and (d.store_code is null or d.store_code<>'IMO01') then coalesce(d.store_code,e.store_code,f.store_code) 
		when a.dealer_id not in ('ALTC','DC11','DCCS','JKBB','JKBA','OLA1', 'SMB0') then a.dealer_id 
		when a.dealer_id ='DCCS' and d.store_code is null and e.store_code is null and f.store_code is null then 'MYIM3OLA' 
		when a.dealer_id='SMB0' and a.galeri_name like 'SMB%' then left(a.galeri_name,6)
		when a.dealer_id is null or a.dealer_id='' or a.salesperson_nm='MYM3-CVM' then 'MYIM3OLA'
		when a.dealer_id = 'MYM3-CVM' then 'MYIM3OLA' 
		when d.store_code='IMO01' then d.username
		when a.dealer_id in ('OLA1','ESEP','JKBB','JKBA') then a.dealer_id
		when d.store_code is not null or e.store_code is not null or f.store_code is not null then coalesce(d.store_code,e.store_code, f.store_code)
		when a.dealer_id='DC11' and d.store_code is null and e.store_code is null and f.store_code is null then 'Others'
		end as store_code_rev,
	row_number() over(partition by a.msisdn order by case when a.order_type='New Registration' then 1
		when a.order_type='Migration' then 2
		when a.order_type='Port In Migration' then 3
		when a.order_type='Change Package Plan' then 4
		when a.order_type='Change Postpaid Plan' then 5
		when a.order_type='Change Ownership' then 6
		else 7
		end asc
		-- , activation_date asc
		) as rnk, 
	d.invoice_number,
	case when a.order_type='New Registration' then 1
		when a.order_type='Migration' then 2
		when a.order_type='Port In Migration' then 3
		when a.order_type='Change Package Plan' then 4
		when a.order_type='Change Postpaid Plan' then 5
		when a.order_type='Change Ownership' then 6
		else 7 end as order_seq
from ga_base as a
	left join `data-nationalslsdist-prd-986g`.postpaid.ref_package_plan as b
		on lower(a.package_name)=lower(b.new_plan) or lower(a.package_name)=lower(b.orig_plan)
	left join `data-nationalslsdist-prd-986g`.postpaid.ref_package_price as c
		-- on lower(a.package_name)=lower(c.package_name)
		on lower(REGEXP_REPLACE(a.package_name, r'[\s\xA0]+', ''))=lower(REGEXP_REPLACE(c.package_name, r'[\s\xA0]+', ''))
	left join (
			select * from (
				select 
					customer_msisdn as msisdn, 
					organization_ref_code as store_code, 
					invoice_number,
					username,
					row_number() over(partition by customer_msisdn order by case when status='Success' then 1 else 2 end asc, PARSE_TIMESTAMP('%d/%m/%Y %H:%M:%S', approved_date) desc, 
							PARSE_TIMESTAMP('%d/%m/%Y %H:%M:%S',transaction_date) desc) as idx
				from `data-nationalslsdist-prd-986g`.postpaid.raw_ipos_ps_trx
					where (lower(product_name) like '%platinum%' or lower(product_name) like '%prime%')
					-- and PARSE_TIMESTAMP('%d/%m/%Y %H:%M:%S', approved_date)>=TIMESTAMP_SUB(TIMESTAMP(PARSE_DATE('%Y%m%d', '{dt_id}')), INTERVAL 45 DAY)
					and (PARSE_TIMESTAMP('%d/%m/%Y %H:%M:%S', approved_date)>=TIMESTAMP_SUB(TIMESTAMP(PARSE_DATE('%Y%m%d', '{dt_id}')), INTERVAL 45 DAY)
					or PARSE_TIMESTAMP('%d/%m/%Y %H:%M:%S', transaction_date)>=TIMESTAMP_SUB(TIMESTAMP(PARSE_DATE('%Y%m%d', '{dt_id}')), INTERVAL 45 DAY)
					)
					-- and status='Success'
			) as x where x.idx=1
	) as d
		on a.msisdn=d.msisdn
	left join (
			select * from (
				select 
					customer_msisdn as msisdn, 
					organization_ref_code as store_code, 
					row_number() over(partition by customer_msisdn order by PARSE_TIMESTAMP('%d/%m/%Y %H:%M:%S',payment_date) desc, PARSE_TIMESTAMP('%d/%m/%Y %H:%M:%S',transaction_date) desc) as idx
				from `data-nationalslsdist-prd-986g`.retail.raw_ipos_nonps_trx
					where (lower(product_name) like '%platinum%' or lower(product_name) like '%prime%')
					and PARSE_TIMESTAMP('%d/%m/%Y %H:%M:%S', payment_date)>=TIMESTAMP_SUB(TIMESTAMP(PARSE_DATE('%Y%m%d', '{dt_id}')), INTERVAL 45 DAY)
					and status='Success'
			) as x where x.idx=1 -- and msisdn='628156019696'
	) as e
		on a.msisdn=e.msisdn
	left join (
						select * from (
							select 
							sitd.customer_msisdn as msisdn, 
							sitd.user_name as store_code, 
								row_number() over(partition by sitd.customer_msisdn order by SAFE.PARSE_DATE('%Y-%m-%d', SUBSTR(sitd.transactiondatetime, 1, 10)) desc) as idx
							from `data-dtp-prd-aa1a`.stg.stg_ipos_transaction_detail sitd 
							where load_dt >= TIMESTAMP(DATE_SUB(PARSE_DATE('%Y%m%d', '{dt_id}'), INTERVAL 3 MONTH))
								and FORMAT_DATE('%Y%m', SAFE.PARSE_DATE('%Y-%m-%d', SUBSTR(sitd.transactiondatetime, 1, 10))) = FORMAT_DATE('%Y%m',DATE_SUB(PARSE_DATE('%Y%m%d', '{dt_id}'), INTERVAL 2 MONTH))
								and (lower(product_ref_code3) like '%platinum%' or lower(product_ref_code3) like '%prime%')
							) as xx where xx.idx=1
	) as f
		on a.msisdn=f.msisdn
) as x where x.rnk=1 
) 
, daily_ga as (
	select
	a.*, 
	coalesce(store.region,b.region_circle,store_only.region) as region_rev, 
	coalesce(branch.area,b.area) as area_rev, 
	coalesce(branch.area,b.sales_area) as sales_area_rev, 
	case when coalesce(store.channel_group,b.channel_group) in ('Partner Store ERA','Partner Store Non-ERA') then 'PARTNER STORE' 
		else coalesce(store.channel_group,b.channel_group) end as channel_rev,
	coalesce(store.store_name,b.store_name) as store_name_rev, 
	case when coalesce(store.channel_group,b.channel_group)='FRANCHISE' then coalesce(store.channel_detail,b.channel_detail)
		when coalesce(store.channel_group,b.channel_group) in ('Partner Store ERA','Partner Store Non-ERA') then coalesce(store.channel_group,b.channel_group)
		else '-' end as channel_partner_store_group, 
	coalesce(store.channel_detail,b.channel_detail) as channel_partner_store_detail, 
	case when coalesce(c.store_code, a.nik_sales) not in ('Administrator', 'EAIUSER') and a.dealer_id not in ('MYM3-CVM', 'TLS1')
		then coalesce(c.store_code, a.nik_sales) end as nik_sales_rev, 
	case when a.dealer_id not in ('MYM3-CVM', 'TLS1') then e.full_name end as sales_name_rev, 
	cast(null as string) as no_imkas_sales,
	cast(null as string) as npwp_sales,
	cast(null as string) as alamat_sales,
	cast(null as string) as nik_pelanggan,
	dsa.spv_name as spv_name,
	dsa.spv_nik as nik_spv,
	cast(null as string) as no_imkas_spv,
	cast(null as string) as no_npwp_spv,
	cast(null as string) as alamat_spv,
	cast(null as string) as team_leader_name,
	cast(null as string) as nik_team_leader,
	cast(null as string) as no_imkas_team_leader,
	cast(null as string) as no_npwp_team_leader,
	cast(null as string) as alamat_team_leader,
	cast(null as string) as remarks,
	cast(null as string) as package_group,
	cast(null as string) as verification_status,
	row_number() over(partition by a.msisdn order by a.order_seq asc, a.activation_date asc) as check_duplicate, 
	FORMAT_DATE('%d/%m/%Y', CURRENT_DATE()) as check_query, 
	right(a.activation_date,2) as days, 
	cast(null as string) as invoice_number_myretail, 
	'Regular' as tactical_regular, 
	f.package_rev, 
	f.acq_rev/1000000 as acq_rev, 
	f.gua_rev_exc_tax/1000000 as gua_rev_exc_tax, 
	f.gua_rev_inc_tax/1000000 as gua_rev, 
	coalesce(store.rce, d.rce) as rce, 
	prom.promotor_name as promotor,
	coalesce(store.branch, d.bsm) as bsm, 
	coalesce(store.region, d.region_circle, upper(dsa.region), store_only.region) as region_circle,
	coalesce(store.circle, d.circle, dsa.circle, store_only.circle) as circle_new,
	cast(null as string) as detail_reason_category, 
	cast(null as string) as status_sr, 
	case
		when a.tenure = 1  then 1
		when a.tenure = 3  then 4
		when a.tenure = 6  then 12
		when a.tenure = 12 then 24
		when a.tenure = 24 then 60
		else 0
	  end point,
	case when b.channel_group='Direct Sales' or a.channel='Direct Sales' then 'Outcall'
		when b.channel_group in ('OWN GERAI', 'FRANCHISE') then 'In Store Agent' 
		else null end as agent_type
	from ga_store as a
	left join (
		select 
			* 
		from `data-nationalslsdist-prd-986g`.postpaid.ref_storelist
		where update_dt = (select max(update_dt) from `data-nationalslsdist-prd-986g`.postpaid.ref_storelist)
	) as b 
		on upper(a.store_code_rev)=upper(b.store_code)
	left join (
			select * from (
				select 
					customer_msisdn as msisdn, 
					username as store_code, 
					row_number() over(partition by customer_msisdn order by case when status='Success' then 1 else 2 end asc, PARSE_TIMESTAMP('%d/%m/%Y %H:%M:%S',payment_date) desc, PARSE_TIMESTAMP('%d/%m/%Y %H:%M:%S',transaction_date) desc) as idx
				from `data-nationalslsdist-prd-986g`.retail.raw_ipos_nonps_trx
					where (lower(product_name) like '%platinum%' or lower(product_name) like '%prime%')
					and PARSE_TIMESTAMP('%d/%m/%Y %H:%M:%S', payment_date)>=TIMESTAMP_SUB(TIMESTAMP(PARSE_DATE('%Y%m%d', '{dt_id}')), INTERVAL 45 DAY)
					-- and status='Success'
			) as x where x.idx=1
	) as c
		on a.msisdn=c.msisdn -- and a.channel='Direct Sales'
	left join (
		select * from (
			select 
				* , 
				row_number() over(partition by store_code order by cast(update_dt as int64) desc) as rnk
			from `data-nationalslsdist-prd-986g`.postpaid.ref_storelist
			-- where update_dt = (select max(update_dt) from `data-nationalslsdist-prd-986g`.postpaid.ref_storelist)
		) as x where x.rnk=1
	) as d
		on case when a.channel='Direct Sales' then upper(c.store_code) else upper(a.store_code_rev) end=upper(d.store_code) 
	left join `data-nationalslsdist-prd-986g`.retail.raw_ipos_user_details as e 
		on upper(coalesce(c.store_code, a.nik_sales)) = upper(e.user_name) and e.user_name is not null and e.user_name<>'' 
	left join `data-nationalslsdist-prd-986g`.postpaid.ref_package_price as f 
		-- on lower(a.package_name)=lower(f.package_name)
		on lower(REGEXP_REPLACE(a.package_name, r'[\s\xA0]+', ''))=lower(REGEXP_REPLACE(f.package_name, r'[\s\xA0]+', ''))
	left join (
		select * from (
					select 
					*,
					row_number() over(partition by store_code order by updated_dt desc) as rnk
					from `data-nationalslsdist-prd-986g`.postpaid.ref_promotor_mapping 
					-- where updated_dt = (select max(updated_dt) from `data-nationalslsdist-prd-986g`.postpaid.ref_promotor_mapping)
					) as x where x.rnk=1
				) as prom
		on upper(a.store_code_rev) = upper(prom.store_code)
	left join (
		select * from (
				select 
					*,
					row_number() over(partition by dsa_nik order by updated_dt desc) as rnk
				from `data-nationalslsdist-prd-986g`.postpaid.ref_dsa_mapping 
				-- where updated_dt = (select max(updated_dt) from `data-nationalslsdist-prd-986g`.postpaid.ref_dsa_mapping)
				) as x where x.rnk=1
				) as dsa
		on upper(coalesce(c.store_code, a.nik_sales)) = upper(dsa.dsa_nik)
	left join (
		select * from (
			select 
				* ,
				row_number() over(partition by store_code order by updated_dt desc) rnk
			from `data-nationalslsdist-prd-986g`.postpaid.ref_storelist_base
			-- where updated_dt = (select max(updated_dt) from `data-nationalslsdist-prd-986g`.postpaid.ref_storelist_base)
			) as x where x.rnk=1
	) as store
		on case when lower(a.channel)='direct sales' then upper(coalesce(c.store_code, a.nik_sales)) else upper(a.store_code_rev) end=upper(store.store_code) 
	left join (
		select * from (
			select 
				*, 
				row_number() over(partition by branch order by updated_dt desc) rnk
			from `data-nationalslsdist-prd-986g`.postpaid.ref_branch_mapping
			-- where updated_dt = (select max(updated_dt) from `data-nationalslsdist-prd-986g`.postpaid.ref_branch_mapping)
		) as x where x.rnk=1
		) as branch
		on store.branch=branch.branch
	left join (
		select * from (
			select 
					*,
					row_number() over(partition by store_code order by updated_dt desc) as rnk
				from `data-nationalslsdist-prd-986g`.postpaid.ref_dsa_mapping 
				-- where updated_dt = (select max(updated_dt) from `data-nationalslsdist-prd-986g`.postpaid.ref_dsa_mapping)
			) as x where x.rnk=1
	) as store_only
		on upper(a.store_code_rev)=upper(store_only.store_code)
)
, final_ga as(
	select 
		ga.activation_date,
		ga.account_num,
		ga.msisdn,
		ga.cust_name,
		ga.package_name,
		ga.order_type,
		ga.package_type,
		ga.tenure,
		ga.dealer_id,
		ga.store,
		ga.channel,
		ga.region,
		ga.area,
		ga.id_number,
		ga.salesperson_nm,
		ga.comment_text,
		ga.created,
		ga.outlet_code,
		ga.outlet_name,
		ga.galeri_name,
		ga.branch_name,
		ga.region_name,
		ga.store_code_rev,
		ga.region_rev,
		ga.area_rev,
		ga.sales_area_rev as sales_area,
		ga.channel_rev,
		ga.store_name_rev,
		ga.channel_partner_store_group,
		ga.channel_partner_store_detail,
		ga.circle_new as circle,
		ga.region_circle as region_new_2024,
		ga.rce as rcm,
		ga.sales_name_rev as sales_name,
		ga.nik_sales_rev as nik_sales,
		ga.no_imkas_sales,
		ga.npwp_sales,
		ga.alamat_sales,
		ga.nik_pelanggan,
		ga.spv_name,
		ga.nik_spv,
		ga.no_imkas_spv,
		ga.no_npwp_spv,
		ga.alamat_spv,
		ga.team_leader_name,
		ga.nik_team_leader,
		ga.no_imkas_team_leader,
		ga.no_npwp_team_leader,
		ga.alamat_team_leader,
		ga.remarks,
		ga.package_group,
		ga.verification_status,
		ga.check_duplicate,
		ga.check_query,
		cast(ga.days as int64) as days,
		ga.invoice_number as invoice_no_ipos,
		cast(null as string) as invoice_no_myretail,
		ga.tactical_regular,
		ga.package_rev,
		ga.acq_rev as acq_revenue_mio,
		ga.gua_rev_exc_tax as guaranteed_ravenue_excl_vat_mio,
		ga.gua_rev as guaranteed_revenue_mio,
		ga.promotor as promotor,
		ga.bsm,
		ga.detail_reason_category,
		ga.status_sr,
		ga.point,
		ga.agent_type
	from daily_ga ga
		where ga.check_duplicate=1
		-- and ga.circle_new is null
		-- and store_code_rev like 'DS%'
)
select
*
from final_ga
; 


-- 01. Update SMB
update `data-nationalslsdist-prd-986g`.postpaid.raw_daily_ga as a 
	set 
		channel=b.channel,
		store_code_rev=b.store_code_rev,
		channel_rev=b.channel_rev,
		store_name_rev=b.store_name_rev,
		sales_name=b.sales_name,
		nik_sales=b.nik_sales,
		region_rev=b.region_rev,
		sales_area=b.sales_area,
		area_rev=b.area_rev,
		channel_partner_store_group=b.channel_partner_store_group,
		channel_partner_store_detail=b.channel_partner_store_detail,
		circle=b.circle,
		rcm=b.rcm,
		bsm=b.bsm,
		package_name=b.package_name,
		package_rev=b.package_rev,
		acq_revenue_mio=b.acq_revenue_mio,
		guaranteed_ravenue_excl_vat_mio=b.guaranteed_ravenue_excl_vat_mio,
		guaranteed_revenue_mio=b.guaranteed_revenue_mio,
		agent_type=b.agent_type
from (
	select
		a.activation_date as act_dt,
		a.msisdn,
		'SMB' as channel,
		b.dealer_code as store_code_rev, 
		'SMB' as channel_rev, 
		d.store_name as store_name_rev, 
		b.sales_name as sales_name, 
		b.nik_sales as nik_sales, 
		coalesce(c.region, d.region) as region_rev, 
		coalesce(c.branch, d.branch) as sales_area,
		coalesce(c.branch, d.branch) as area_rev, 
		'-' as channel_partner_store_group,
		'-' as channel_partner_store_detail, 
		coalesce(c.circle, d.circle) as circle, 
		coalesce(c.rce, d.rce) as rcm, 
		coalesce(c.branch, d.branch) as bsm, 
		b.package_name, 
		e.package_rev, 
		e.acq_rev/1000000 as acq_revenue_mio, 
		e.gua_rev_exc_tax/1000000 as guaranteed_ravenue_excl_vat_mio,
		e.gua_rev_inc_tax/1000000 as guaranteed_revenue_mio, 
		'Outcall' as agent_type 
		-- b.*
	from `data-nationalslsdist-prd-986g`.postpaid.raw_daily_ga as a
		inner join `advisoryhub-ic-prd-wt4b`.external.tbl_smb_ide_platinum_hub_activation as b
			on a.msisdn=b.msisdn 
				and left(a.activation_date,6)=format_date('%Y%m',date(b.activation_date))
		left join (
			select * from (
					select 
						* ,
						row_number() over(partition by store_code order by updated_dt desc) rnk
					from `data-nationalslsdist-prd-986g`.postpaid.ref_storelist_base
						where mth_id=left('{dt_id}', 6)
				) as x where x.rnk=1
		) as c 
			on b.nik_sales=c.store_code
		left join (
			select * from (
					select 
						* ,
						row_number() over(partition by store_code order by updated_dt desc) rnk
					from `data-nationalslsdist-prd-986g`.postpaid.ref_storelist_base
						where mth_id=left('{dt_id}', 6)
							and lower(channel_group) like '%smb%'
				) as x where x.rnk=1
		) as d 
			on b.dealer_code=d.store_code
		left join `data-nationalslsdist-prd-986g`.postpaid.ref_package_price as e
			on lower(REGEXP_REPLACE(b.package_name, r'[\s\xA0]+', ''))=lower(REGEXP_REPLACE(e.package_name, r'[\s\xA0]+', ''))
	where date(b.activation_date) between date(SUBSTR('{dt_id}',1,4) || '-' || SUBSTR('{dt_id}',5,2) || '-01') 
						and PARSE_DATE('%Y%m%d', '{dt_id}')
) as b
	where a.msisdn=b.msisdn and a.activation_date=b.act_dt
;

-- 02. Update Partner Store
update `data-nationalslsdist-prd-986g`.postpaid.raw_daily_ga as a 
	set store_code_rev=b.store_code, 
	store_name_rev=b.store_name,
	sales_area=b.branch, 
	region_new_2024=b.region,
	circle=b.circle,
	rcm=b.rce,
	bsm=b.branch,
	channel_partner_store_detail=b.channel_detail
from (
	with ps_trx as (
		select * from (
			select 
				customer_msisdn as msisdn, 
				organization_ref_code as store_code, 
				row_number() over(partition by customer_msisdn order by case when status='Success' then 1 else 2 end asc, PARSE_TIMESTAMP('%d/%m/%Y %H:%M:%S', approved_date) desc, 
						PARSE_TIMESTAMP('%d/%m/%Y %H:%M:%S',transaction_date) desc) as idx
			from `data-nationalslsdist-prd-986g`.postpaid.raw_ipos_ps_trx
				where (lower(product_name) like '%platinum%' or lower(product_name) like '%prime%')
					and status='Success'
					and format_date('%Y%m',PARSE_TIMESTAMP('%d/%m/%Y %H:%M:%S', transaction_date))=left('{dt_id}',6)		
		) as x where x.idx=1
	)
	, ref_store as (
		select * from (
			select 
				* ,
				row_number() over(partition by store_code order by updated_dt desc) rnk
			from `data-nationalslsdist-prd-986g`.postpaid.ref_storelist_base
		) as x where x.rnk=1
	)
	, ref_promotor as (
		select * from (
			select 
			*,
			row_number() over(partition by store_code order by updated_dt desc) as rnk
			from `data-nationalslsdist-prd-986g`.postpaid.ref_promotor_mapping 
		) as x where x.rnk=1
	)
	select 
		d.activation_date,
		a.msisdn,
		a.store_code,
		b.store_name, 
		b.branch,
		b.region,
		b.circle,
		b.channel_group,
		b.channel_detail,
		b.rce, 
		c.promotor_name
	from ps_trx as a 
		left join ref_store as b
			on upper(a.store_code)=upper(b.store_code)
		left join ref_promotor as c
			on upper(a.store_code)=upper(c.store_code)
		inner join `data-nationalslsdist-prd-986g`.postpaid.raw_daily_ga as d
			on left(d.activation_date,6)=left('{dt_id}',6) and d.dealer_id='DC11'
				and d.msisdn=a.msisdn and d.store_code_rev<>a.store_code
) as b
where a.msisdn=b.msisdn and a.activation_date=b.activation_date
;

-- 03. Update direct sales based on data user mapping ipos
update `data-nationalslsdist-prd-986g`.postpaid.raw_daily_ga as a
set nik_sales = b.user_name,
sales_name = b.full_name
from (
					select 
						--b.*,
						--a.* 
						distinct
						a.msisdn,
						a.activation_date,
						b.full_name,
						b.user_name
						from `data-nationalslsdist-prd-986g`.postpaid.raw_daily_ga as a
						inner join  (
											select * from (
											-- select * , row_number() over(partition by user_name order by updated_dt desc) as rnk
											select * , row_number() over(partition by full_name order by updated_dt desc) as rnk
											from `data-nationalslsdist-prd-986g`.retail.raw_ipos_user_details
											) as x where x.rnk=1
										) as b
							-- on a.salesperson_nm = b.user_name
							on a.salesperson_nm = b.full_name
						where 
							left(a.activation_date,6)=left('{dt_id}',6)
							and (lower(a.agent_type)='outcall' or lower(a.channel_rev)='direct sales')
							and (a.nik_sales is null or a.nik_sales='')
				) as b
where a.msisdn = b.msisdn
	and a.activation_date=b.activation_date
	and left(a.activation_date,6)=left('{dt_id}',6)
	and (lower(a.agent_type)='outcall' or lower(a.channel_rev)='direct sales')
	and (a.nik_sales is null or a.nik_sales='')
	;

-- 04. Update direct sales based on data mapping using user id
update `data-nationalslsdist-prd-986g`.postpaid.raw_daily_ga as a
set nik_sales = b.user_name,
sales_name = b.full_name
from (
					select 
						distinct
						a.msisdn,
						a.activation_date,
						b.full_name,
						b.user_name
						from `data-nationalslsdist-prd-986g`.postpaid.raw_daily_ga as a
						inner join  (
											select * from (
											select * , row_number() over(partition by user_name order by updated_dt desc) as rnk
											from `data-nationalslsdist-prd-986g`.retail.raw_ipos_user_details
											) as x where x.rnk=1
										) as b
							on a.salesperson_nm = b.user_name
							-- on a.salesperson_nm = b.full_name
						where 
							left(a.activation_date,6)=left('{dt_id}',6)
							and (lower(a.agent_type)='outcall' or lower(a.channel_rev)='direct sales')
							and (a.nik_sales is null or a.nik_sales='')
				) as b
where a.msisdn = b.msisdn
	and a.activation_date=b.activation_date
	and left(a.activation_date,6)=left('{dt_id}',6)
	and (lower(a.agent_type)='outcall' or lower(a.channel_rev)='direct sales')
	and (a.nik_sales is null or a.nik_sales='')
;

-- 05. Update direct sales based on ipos trx
update `data-nationalslsdist-prd-986g`.postpaid.raw_daily_ga as a
set nik_sales = b.username,
sales_name = b.full_name
from (
		select
		b.msisdn,
		b.store_code,
		b.username,
		c.full_name
		from 
				(
							select * from (
								select 
									customer_msisdn as msisdn, 
									organization_ref_code as store_code, 
									username,
									row_number() over(partition by customer_msisdn order by PARSE_TIMESTAMP('%d/%m/%Y %H:%M:%S',payment_date) desc, PARSE_TIMESTAMP('%d/%m/%Y %H:%M:%S',transaction_date) desc) as idx
								from `data-nationalslsdist-prd-986g`.retail.raw_ipos_nonps_trx
									where (lower(product_name) like '%platinum%' or lower(product_name) like '%prime%')
									and PARSE_TIMESTAMP('%d/%m/%Y %H:%M:%S', payment_date)>=TIMESTAMP_SUB(TIMESTAMP(PARSE_DATE('%Y%m%d', '{dt_id}')), INTERVAL 180 DAY)
									and status='Success'
							) as x where x.idx=1 
				) as b 
				left join (
					select * from (
					select * , row_number() over(partition by user_name order by updated_dt desc) as rnk
					from `data-nationalslsdist-prd-986g`.retail.raw_ipos_user_details
					) as x where x.rnk=1
				) as c on b.username=c.user_name
) as b
where a.msisdn=b.msisdn 
	and a.store_code_rev = b.store_code
	and left(a.activation_date,6)=left('{dt_id}',6)
	and (lower(a.agent_type)='outcall' or lower(a.channel_rev)='direct sales')
	and (a.nik_sales is null or a.nik_sales='')
;

-- 06. Update nik sales instore agent 
update `data-nationalslsdist-prd-986g`.postpaid.raw_daily_ga as a
set nik_sales = b.username,
sales_name = b.full_name
from (
		select
		b.msisdn,
		b.store_code,
		b.username,
		c.full_name
		from 
				(
							select * from (
								select 
									customer_msisdn as msisdn, 
									organization_ref_code as store_code, 
									username,
									row_number() over(partition by customer_msisdn order by PARSE_TIMESTAMP('%d/%m/%Y %H:%M:%S',payment_date) desc, PARSE_TIMESTAMP('%d/%m/%Y %H:%M:%S',transaction_date) desc) as idx
								from `data-nationalslsdist-prd-986g`.retail.raw_ipos_nonps_trx
									where (lower(product_name) like '%platinum%' or lower(product_name) like '%prime%')
									and PARSE_TIMESTAMP('%d/%m/%Y %H:%M:%S', payment_date)>=TIMESTAMP_SUB(TIMESTAMP(PARSE_DATE('%Y%m%d', '{dt_id}')), INTERVAL 180 DAY)
									and status='Success'
							) as x where x.idx=1 
				) as b 
				left join (
					select * from (
					select * , row_number() over(partition by user_name order by updated_dt desc) as rnk
					from `data-nationalslsdist-prd-986g`.retail.raw_ipos_user_details
					) as x where x.rnk=1
				) as c on b.username=c.user_name
) as b
where a.msisdn=b.msisdn 
	and a.store_code_rev = b.store_code
	and left(a.activation_date,6)=left('{dt_id}',6)
	and lower(a.channel_rev) in ('franchise', 'own gerai')
	and (a.nik_sales is null or a.nik_sales='');

-- 07. update storelist ps
update `data-nationalslsdist-prd-986g`.postpaid.raw_daily_ga as a 
	set store_code_rev=b.store_code,
		store_name_rev=b.store_name, 
		circle=b.circle,
		region_new_2024=b.region,
		rcm=b.rce
from (
	select 
		a.msisdn,
		b.store_code,
		b.store_name,
		b.circle,
		b.region,
		b.rce, 
		b.activation_date
	from `data-nationalslsdist-prd-986g`.postpaid.raw_daily_ga as a 
		inner join 
		(
			select a.*,
				b.store_name, 
				b.circle,
				b.region,
				b.rce
			from (
			select * from (
					select 
						format_date('%Y%m%d', PARSE_TIMESTAMP('%d/%m/%Y %H:%M:%S', approved_date)) activation_date,
						customer_msisdn as msisdn, 
						organization_ref_code as store_code, 
						username,
						row_number() over(partition by customer_msisdn order by case when status='Success' then 1 else 2 end asc, PARSE_TIMESTAMP('%d/%m/%Y %H:%M:%S', approved_date) desc, 
								PARSE_TIMESTAMP('%d/%m/%Y %H:%M:%S',transaction_date) desc) as idx
					from `data-nationalslsdist-prd-986g`.postpaid.raw_ipos_ps_trx
						where (lower(product_name) like '%platinum%' or lower(product_name) like '%prime%')
						-- and PARSE_TIMESTAMP('%d/%m/%Y %H:%M:%S', approved_date)>=TIMESTAMP_SUB(TIMESTAMP(PARSE_DATE('%Y%m%d', '{dt_id}')), INTERVAL 45 DAY)
						and (PARSE_TIMESTAMP('%d/%m/%Y %H:%M:%S', approved_date)>=TIMESTAMP_SUB(TIMESTAMP(PARSE_DATE('%Y%m%d', '{dt_id}')), INTERVAL 45 DAY)
						or PARSE_TIMESTAMP('%d/%m/%Y %H:%M:%S', transaction_date)>=TIMESTAMP_SUB(TIMESTAMP(PARSE_DATE('%Y%m%d', '{dt_id}')), INTERVAL 45 DAY)
						)
						and status='Success'
				) as x where x.idx=1
			) as a 	
			inner join (
				select * from (
					select 
						store_code,
						store_name, 
						region,
						circle,
						rce,
						row_number() over(partition by store_code order by updated_dt) rnk
					from `data-nationalslsdist-prd-986g`.postpaid.ref_storelist_base 
						where mth_id=left('{dt_id}',6)
						) as x where x.rnk=1
			) as b
				on a.store_code=b.store_code
		)
		as b
			on a.msisdn=b.msisdn and a.activation_date=b.activation_date and a.store_code_rev<>b.store_code 
		where left(a.activation_date,6)=left('{dt_id}',6)
		and dealer_id='DC11'
) as b
	where a.msisdn=b.msisdn
		and a.activation_date=b.activation_date
		and dealer_id='DC11'
		;

-- 08. Update instore agent flagging
update `data-nationalslsdist-prd-986g`.postpaid.raw_daily_ga
set agent_type='In Store Agent'
where lower(channel_rev) in ('franchise', 'own gerai')
 and and left(activation_date,6)=left('{dt_id}',6);

-- 09. update nik sales direct sales
update `data-nationalslsdist-prd-986g`.postpaid.raw_daily_ga as a
	set nik_sales = b.username,
		sales_name = b.full_name,
		agent_type='Outcall', 
		channel_rev='DIRECT SALES', 
		rcm = b.rce
from (
		select
		b.dt_id,
		b.msisdn,
		b.store_code,
		b.username,
		c.full_name, 
		d.rce
--		a.nik_sales as niks,
--		a.store_code_rev as stores,
--		a.*
			from `data-nationalslsdist-prd-986g`.postpaid.raw_daily_ga as a
				inner join  
				(
							-- select * from (
								select 
									distinct
									format_date('%Y%m%d',PARSE_TIMESTAMP('%d/%m/%Y %H:%M:%S',payment_date)) dt_id,
									customer_msisdn as msisdn, 
									organization_ref_code as store_code, 
									username
									-- row_number() over(partition by customer_msisdn order by PARSE_TIMESTAMP('%d/%m/%Y %H:%M:%S',payment_date) desc, PARSE_TIMESTAMP('%d/%m/%Y %H:%M:%S',transaction_date) desc) as idx
								from `data-nationalslsdist-prd-986g`.retail.raw_ipos_nonps_trx
									where (lower(product_name) like '%platinum%' or lower(product_name) like '%prime%')
									and PARSE_TIMESTAMP('%d/%m/%Y %H:%M:%S', payment_date)>=TIMESTAMP_SUB(TIMESTAMP(PARSE_DATE('%Y%m%d', '{dt_id}')), INTERVAL 180 DAY)
									and status='Success'
							-- ) as x where x.idx=1 
				) as b
					on a.msisdn=b.msisdn 
						and a.activation_date = b.dt_id
						and a.nik_sales <> b.username 
						and a.store_code_rev = b.store_code 
				left join (
					select * from (
					select * , row_number() over(partition by user_name order by updated_dt desc) as rnk
					from `data-nationalslsdist-prd-986g`.retail.raw_ipos_user_details
					) as x where x.rnk=1
				) as c on b.username=c.user_name
				left join(
						select * from (
									select 
										* ,
										row_number() over(partition by store_code order by updated_dt desc) rnk
									from `data-nationalslsdist-prd-986g`.postpaid.ref_storelist_base
										where mth_id = left('{dt_id}',6)
									) as x where x.rnk=1
				) as d
					on b.username=d.store_code
				where b.store_code like 'DS%'
				and left(a.activation_date,6)=left('{dt_id}',6)
) as b
where a.msisdn=b.msisdn 
	and a.store_code_rev = b.store_code
	and a.activation_date=b.dt_id
;

-- 10. update nik sales non direct sales
update `data-nationalslsdist-prd-986g`.postpaid.raw_daily_ga as a
	set nik_sales = b.username,
		sales_name = b.full_name,
		agent_type='In Store Agent', 
--		channel_rev='DIRECT SALES', 
		rcm = b.rce
from (
		select
		b.dt_id,
		b.msisdn,
		b.store_code,
		b.username,
		c.full_name, 
		d.rce
--		,a.nik_sales as niks,
--		a.store_code_rev as stores,
--		a.*
			from `data-nationalslsdist-prd-986g`.postpaid.raw_daily_ga as a
				inner join  
				(
							-- select * from (
								select 
									distinct
									format_date('%Y%m%d',PARSE_TIMESTAMP('%d/%m/%Y %H:%M:%S',payment_date)) dt_id,
									customer_msisdn as msisdn, 
									organization_ref_code as store_code, 
									username
									-- row_number() over(partition by customer_msisdn order by PARSE_TIMESTAMP('%d/%m/%Y %H:%M:%S',payment_date) desc, PARSE_TIMESTAMP('%d/%m/%Y %H:%M:%S',transaction_date) desc) as idx
								from `data-nationalslsdist-prd-986g`.retail.raw_ipos_nonps_trx
									where (lower(product_name) like '%platinum%' or lower(product_name) like '%prime%')
									and PARSE_TIMESTAMP('%d/%m/%Y %H:%M:%S', payment_date)>=TIMESTAMP_SUB(TIMESTAMP(PARSE_DATE('%Y%m%d', '{dt_id}')), INTERVAL 180 DAY)
									and status='Success'
							-- ) as x where x.idx=1 
				) as b
					on a.msisdn=b.msisdn 
						and a.activation_date = b.dt_id
						and a.nik_sales <> b.username 
						and a.store_code_rev = b.store_code 
				left join (
					select * from (
					select * , row_number() over(partition by user_name order by updated_dt desc) as rnk
					from `data-nationalslsdist-prd-986g`.retail.raw_ipos_user_details
					) as x where x.rnk=1
				) as c on b.username=c.user_name
				left join(
						select * from (
									select 
										* ,
										row_number() over(partition by store_code order by updated_dt desc) rnk
									from `data-nationalslsdist-prd-986g`.postpaid.ref_storelist_base
										where mth_id = left('{dt_id}',6)
									) as x where x.rnk=1
				) as d
					on b.store_code=d.store_code
				where b.store_code not like 'DS%'
				and and left(a.activation_date,6)=left('{dt_id}',6)
) as b
where a.msisdn=b.msisdn 
	and a.store_code_rev = b.store_code
	and a.activation_date=b.dt_id
;

-- 11. delete nik sales partner store
UPDATE `data-nationalslsdist-prd-986g`.postpaid.raw_daily_ga 
	set nik_sales = null,
		sales_name = null
where dealer_id='DC11'
	and nik_sales is not null
	and nik_sales <>''
	and left(activation_date,6)=left('{dt_id}',6);

-- 12. check grouping partner store
UPDATE `data-nationalslsdist-prd-986g`.postpaid.raw_daily_ga
	set channel_rev = 'PARTNER STORE',
		channel_partner_store_group='Partner Store ERA'
	where channel_rev='PARTNER STORE ERA'
		and left(activation_date,6)=left('{dt_id}',6);

-- 13. update channel rev
UPDATE `data-nationalslsdist-prd-986g`.postpaid.raw_daily_ga
	set channel_rev = upper(channel_rev)
where left(activation_date,6)=left('{dt_id}',6);

-- 14. update channel partner store detail
update `data-nationalslsdist-prd-986g`.postpaid.raw_daily_ga
	set channel_partner_store_detail='-'
where channel_rev<>'PARTNER STORE'
	and left(activation_date,6)=left('{dt_id}',6);

-- update `data-nationalslsdist-prd-986g`.postpaid.raw_daily_ga as a
-- set nik_sales = b.username,
-- sales_name = b.full_name
-- from (
-- 		select
-- 		b.msisdn,
-- 		b.store_code,
-- 		b.username,
-- 		c.full_name
-- 		from 
-- 				(
-- 							select * from (
-- 								select 
-- 									customer_msisdn as msisdn, 
-- 									organization_ref_code as store_code, 
-- 									username,
-- 									row_number() over(partition by customer_msisdn order by PARSE_TIMESTAMP('%d/%m/%Y %H:%M:%S',payment_date) desc, PARSE_TIMESTAMP('%d/%m/%Y %H:%M:%S',transaction_date) desc) as idx
-- 								from `data-nationalslsdist-prd-986g`.retail.raw_ipos_nonps_trx
-- 									where (lower(product_name) like '%platinum%' or lower(product_name) like '%prime%')
-- 									and PARSE_TIMESTAMP('%d/%m/%Y %H:%M:%S', payment_date)>=TIMESTAMP_SUB(TIMESTAMP(PARSE_DATE('%Y%m%d', '{dt_id}')), INTERVAL 180 DAY)
-- 									and status='Success'
-- 							) as x where x.idx=1 
-- 				) as b 
-- 				left join (
-- 					select * from (
-- 					select * , row_number() over(partition by user_name order by updated_dt desc) as rnk
-- 					from `data-nationalslsdist-prd-986g`.retail.raw_ipos_user_details
-- 					) as x where x.rnk=1
-- 				) as c on b.username=c.user_name
-- ) as b
-- where a.msisdn=b.msisdn 
-- 	and a.store_code_rev = b.store_code
-- 	and left(a.activation_date,6)=left('{dt_id}',6)
-- 	and (lower(a.agent_type)='outcall' or lower(a.channel_rev)='direct sales')
-- 	and (a.nik_sales is null or a.nik_sales='');

-- update `data-nationalslsdist-prd-986g`.postpaid.raw_daily_ga as a
-- set nik_sales = b.username,
-- sales_name = b.full_name
-- from (
-- 		select
-- 		b.msisdn,
-- 		b.store_code,
-- 		b.username,
-- 		c.full_name
-- 		from 
-- 				(
-- 							select * from (
-- 								select 
-- 									customer_msisdn as msisdn, 
-- 									organization_ref_code as store_code, 
-- 									username,
-- 									row_number() over(partition by customer_msisdn order by PARSE_TIMESTAMP('%d/%m/%Y %H:%M:%S',payment_date) desc, PARSE_TIMESTAMP('%d/%m/%Y %H:%M:%S',transaction_date) desc) as idx
-- 								from `data-nationalslsdist-prd-986g`.retail.raw_ipos_nonps_trx
-- 									where (lower(product_name) like '%platinum%' or lower(product_name) like '%prime%')
-- 									and PARSE_TIMESTAMP('%d/%m/%Y %H:%M:%S', payment_date)>=TIMESTAMP_SUB(TIMESTAMP(PARSE_DATE('%Y%m%d', '{dt_id}')), INTERVAL 180 DAY)
-- 									and status='Success'
-- 							) as x where x.idx=1 
-- 				) as b 
-- 				left join (
-- 					select * from (
-- 					select * , row_number() over(partition by user_name order by updated_dt desc) as rnk
-- 					from `data-nationalslsdist-prd-986g`.retail.raw_ipos_user_details
-- 					) as x where x.rnk=1
-- 				) as c on b.username=c.user_name
-- ) as b
-- where a.msisdn=b.msisdn 
-- 	and a.store_code_rev = b.store_code
-- 	and left(a.activation_date,6)=left('{dt_id}',6)
-- 	and lower(a.channel_rev) in ('franchise', 'own gerai')
-- 	and (a.nik_sales is null or a.nik_sales='');

