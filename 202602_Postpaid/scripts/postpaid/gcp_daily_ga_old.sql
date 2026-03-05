-- Insert new GA
insert into `data-nationalslsdist-prd-986g`.postpaid.raw_daily_ga
with ga_new as(
  SELECT DISTINCT 
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
    END AS nik_sales
  FROM `data-nationalslsdist-prd-986g`.postpaid.raw_new_verification as a
  WHERE SAFE.PARSE_DATE('%m/%d/%Y', SUBSTR(a.activation_date, 1, 10)) <= PARSE_DATE('%Y%m%d', '{dt_id}')
  	AND FORMAT_DATE('%Y%m', SAFE.PARSE_DATE('%m/%d/%Y', SUBSTR(a.activation_date, 1, 10))) = SUBSTR('{dt_id}', 1, 6)
)
, ga_cpp as(
	select * from (
		select
			format_date('%Y%m%d', a.completiondate) as activation_date, 
			a.account_num, 
			a.msisdn,
			a.cst_nm as cust_name, 
			a.main_package as package_name, 
			a.order_type, 
			left(a.dealer_id, 4) as dealerid, 
			null as store,
			null as id_number,
			a.salesperson as salesperson_nm,
			a.channel as comment_text, 
			a.created_by as created,
			null as outlet_code,
			null as outlet_name, 
			null as galeri_name,
			null as branch_name,
			null as region_name,
			left(a.dealer_id, 4) as store_code,
			a.salesperson as sales_name, 
			a.salesperson as nik_sales, 
			row_number() over(partition by a.msisdn order by a.completiondate desc) as idx
		from `data-dtp-prd-aa1a.smy.ar_change_pkg_pstpaid_rtl` as a 
			where format_date('%Y%m', a.dt_id)=left('{dt_id}',6) 
			and a.dt_id<=TIMESTAMP(PARSE_DATE('%Y%m%d', '{dt_id}'))
			and format_date('%Y%m', a.completiondate)=left('{dt_id}',6)
			and a.completiondate<=TIMESTAMP(PARSE_DATE('%Y%m%d', '{dt_id}'))
	) as x where x.idx=1
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
	where lower(a.package_name) like '%prime%' or lower(a.package_name) like '%platinum%'
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
	from ga_cpp as b
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
		when a.dealer_id like 'OLA%' then 'OLA'
		when a.dealer_id='FCPR' then 'JV'
		when a.store like 'MPC%' then 'MPC'
		when a.store like 'TP%' then 'Thirdparty'
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
	case when a.dealer_id in ('ALTC','DC11','DCCS','JKBB','JKBA','OLA1') and (d.store_code is not null or e.store_code is not null) then coalesce(d.store_code,e.store_code) 
		when a.dealer_id not in ('ALTC','DC11','DCCS','JKBB','JKBA','OLA1') then a.dealer_id 
		when a.dealer_id ='DCCS' and d.store_code is null and e.store_code is null then 'MYIM3OLA' 
		when a.dealer_id='SMB0' and a.galeri_name like 'SMB%' then left(a.galeri_name,6)
		when a.dealer_id is null or a.dealer_id='' or a.salesperson_nm='MYM3-CVM' then 'MYIM3OLA'
		when a.dealer_id in ('OLA1','ESEP','JKBB','JKBA') then a.dealer_id
		when d.store_code is not null or e.store_code is not null then coalesce(d.store_code,e.store_code)
		when a.dealer_id='DC11' and d.store_code is null and e.store_code is null then 'Others'
		end as store_code_rev,
	row_number() over(partition by a.msisdn order by case when a.order_type='New Registration' then 1
		when a.order_type='Migration' then 2
		when a.order_type='Change Package Plan' then 3
		when a.order_type='Change Postpaid Plan' then 3
		when a.order_type='Port In Migration' then 4
		when a.order_type='Change Ownership' then 5
		else 6
		end asc, activation_date asc) as rnk, 
	d.invoice_number,
	case when a.order_type='New Registration' then 1
		when a.order_type='Migration' then 2
		when a.order_type='Change Package Plan' then 3
		when a.order_type='Change Postpaid Plan' then 3
		when a.order_type='Port In Migration' then 4
		when a.order_type='Change Ownership' then 5
		else 6 end as order_seq
from ga_base as a
	left join `data-nationalslsdist-prd-986g`.postpaid.ref_package_plan as b
		on lower(a.package_name)=lower(b.new_plan) or lower(a.package_name)=lower(b.orig_plan)
	left join `data-nationalslsdist-prd-986g`.postpaid.ref_package_price as c
		on lower(a.package_name)=lower(c.package_name)
	left join (
			select * from (
				select 
					customer_msisdn as msisdn, 
					organization_ref_code as store_code, 
					invoice_number,
					row_number() over(partition by customer_msisdn order by approved_date desc, transaction_date desc) as idx
				from `data-nationalslsdist-prd-986g`.postpaid.raw_ipos_ps_trx
					where (lower(product_name) like '%platinum%' or lower(product_name) like '%prime%')
					and status='Success'
			) as x where x.idx=1
	) as d
		on a.msisdn=d.msisdn
	left join (
			select * from (
				select 
					customer_msisdn as msisdn, 
					organization_ref_code as store_code, 
					row_number() over(partition by customer_msisdn order by payment_date desc, transaction_date desc) as idx
				from `data-nationalslsdist-prd-986g`.retail.raw_ipos_nonps_trx
					where (lower(product_name) like '%platinum%' or lower(product_name) like '%prime%')
					and status='Success'
			) as x where x.idx=1
	) as e
		on a.msisdn=e.msisdn
) as x where x.rnk=1 
) 
, daily_ga as (
	select
	a.*, 
	b.region_circle as region_rev, 
	b.area as area_rev, 
	b.sales_area as sales_area_rev, 
	b.channel_group as channel_rev, 
	b.store_name as store_name_rev, 
	b.channel_group as channel_partner_store_group, 
	b.channel_detail as channel_partner_store_detail, 
	coalesce(c.store_code, a.nik_sales) as nik_sales_rev, 
	e.full_name as sales_name_rev, 
	cast(null as string) as no_imkas_sales,
	cast(null as string) as npwp_sales,
	cast(null as string) as alamat_sales,
	cast(null as string) as nik_pelanggan,
	cast(null as string) as spv_name,
	cast(null as string) as nik_spv,
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
	d.rce, 
	d.bsm, 
	d.region_circle,
	d.circle as circle_new,
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
	case when b.channel_group='Direct Sales' or a.channel='Direct Sales' then 'Outlcall'
		when b.channel_group in ('OWN GERAI', 'FRANCHISE') then 'In Store Agent' 
		else null end as agent_type
	from ga_store as a
	left join (
		select 
			* 
		from `data-nationalslsdist-prd-986g`.postpaid.ref_storelist
		where update_dt = (select max(update_dt) from `data-nationalslsdist-prd-986g`.postpaid.ref_storelist)
	) as b 
		on a.store_code_rev=b.store_code
	left join (
			select * from (
				select 
					customer_msisdn as msisdn, 
					username as store_code, 
					row_number() over(partition by customer_msisdn order by payment_date desc, transaction_date desc) as idx
				from `data-nationalslsdist-prd-986g`.retail.raw_ipos_nonps_trx
					where (lower(product_name) like '%platinum%' or lower(product_name) like '%prime%')
					and status='Success'
			) as x where x.idx=1
	) as c
		on a.msisdn=c.msisdn and a.channel='Direct Sales'
	left join (
		select 
			* 
		from `data-nationalslsdist-prd-986g`.postpaid.ref_storelist
		where update_dt = (select max(update_dt) from `data-nationalslsdist-prd-986g`.postpaid.ref_storelist)
	) as d
		on case when a.channel='Direct Sales' then c.store_code else a.store_code_rev end=d.store_code 
	left join `data-nationalslsdist-prd-986g`.retail.raw_ipos_user_details as e 
		on coalesce(c.store_code, a.nik_sales) = e.user_name and e.user_name is not null and e.user_name<>'' 
	left join `data-nationalslsdist-prd-986g`.postpaid.ref_package_price as f 
		on lower(a.package_name)=lower(f.package_name)
)
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
	cast(null as string) as promotor,
	ga.bsm,
	ga.detail_reason_category,
	ga.status_sr,
	ga.point,
	ga.agent_type
from daily_ga ga
	where ga.check_duplicate=1
; 