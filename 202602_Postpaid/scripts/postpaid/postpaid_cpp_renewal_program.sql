insert into `data-nationalslsdist-prd-986g`.postpaid.raw_cpp_renewal_program
-- create or replace table `data-nationalslsdist-prd-986g`.postpaid.raw_cpp_renewal_program as
with cpp as (
select * from (
		select
			a.*, 
			row_number() over(partition by a.msisdn order by a.completiondate desc) as idx
		from `data-dtp-prd-aa1a.smy.ar_change_pkg_pstpaid_rtl` as a 
			where 1=1 
			and a.dt_id>=TIMESTAMP_SUB(TIMESTAMP(PARSE_DATE('%Y%m%d', '{dt_id}')), INTERVAL 45 DAY)
			and (
					(format_date('%Y%m', a.completiondate)=left('{dt_id}',6) 
					and format_date('%Y%m%d', a.completiondate)<='{dt_id}')
			-- case july that GCP need to adjust to Asia Jakarta to meet utc like in hadoop
			 or 
			 		(format_date('%Y%m', DATETIME(a.completiondate,'Asia/Jakarta'))=left('{dt_id}',6)
			 		and format_date('%Y%m%d', DATETIME(a.completiondate,'Asia/Jakarta'))<='{dt_id}'))
	) as x where x.idx=1 
),
postpaid_basic as (
	select distinct msisdn, 
		main_package, 
		origin_main_package
		from (
			select
				a.*, 
				row_number() over(partition by a.msisdn order by a.completiondate desc) as idx
			from `data-dtp-prd-aa1a.smy.ar_change_pkg_pstpaid_rtl` as a 
				inner join cpp as b
					on a.msisdn=b.msisdn
				where 1=1 
				-- and a.dt_id>=TIMESTAMP_SUB(TIMESTAMP(PARSE_DATE('%Y%m%d', '{dt_id}')), INTERVAL 360 DAY)
				and a.dt_id>='2022-01-01'
		) as x 
		where x.idx=2 
		-- and lower(x.main_package) ='postpaid basic'
),
dm_cpp as (
	select 
		a.msisdn, 
		a.order_id,
		a.ordernum,
		a.order_type, 
		a.account_num,
		b.package_name as cpp_renewal_package,
		b.package_type as cpp_renewal_group,
		a.origin_main_package, 
		case 
					when a.origin_main_package='Postpaid Basic' then 'Postpaid Basic'
--					when coalesce(c.contract_status, d.package_type) is not null then coalesce(c.contract_status, d.package_type)	
					when (lower(a.origin_main_package) like '%prime%' or lower(a.origin_main_package) like '%platinum%') and (lower(a.origin_main_package) like '%contract%' or lower(a.origin_main_package) like '%bundling%') then 'Contract'
					when (lower(a.origin_main_package) like '%prime%' or lower(a.origin_main_package) like '%platinum%') and lower(a.origin_main_package) not like '%contract%' and lower(a.origin_main_package) not like '%bundling%' then 'Non Contract'
				else 'Legacy Monthly'	
				end origin_group,
		b.tenure as cpp_renewal_tenure,
		b.guaranteed_revenue_mio as cpp_renewal_gua_rev,
		b.activation_date as cpp_renewal_date,
		b.dealer_id as cpp_renewal_dealer_id, 
		b.store_code_rev as cpp_renewal_store_code_rev,
		b.sales_name as cpp_renewal_sales_name,
		b.nik_sales as cpp_renewal_nik_sales,
		b.circle as cpp_renewal_circle,
		b.region_new_2024 as cpp_renewal_region, 
		c.origin_main_package as before_postpaid_basic
	from cpp as a 
		inner join `data-nationalslsdist-prd-986g`.postpaid.raw_daily_ga as b
			on a.msisdn = b.msisdn and left(b.activation_date,6)=left('{dt_id}',6) and b.order_type='Change Postpaid Plan'
		left join postpaid_basic as c
			on a.msisdn = c.msisdn
--		left join `data-nationalslsdist-prd-986g`.postpaid.ref_package_plan as c
--			on lower(a.origin_main_package)=lower(c.new_plan) or lower(a.origin_main_package)=lower(c.orig_plan)
--		left join `data-nationalslsdist-prd-986g`.postpaid.ref_package_price as d
--			on lower(a.origin_main_package)=lower(d.package_name)
), 
renewal as (
select * from (
		select
			a.*, 
			row_number() over(partition by a.msisdn order by a.completiondate asc) as idx
		from `data-dtp-prd-aa1a.smy.ar_change_pkg_pstpaid_rtl` as a 
			where 1=1 
			and a.dt_id>=TIMESTAMP_SUB(TIMESTAMP(PARSE_DATE('%Y%m%d', '{dt_id}')), INTERVAL 120 DAY)
	) as x 
		where x.idx=1 
		and (
					(format_date('%Y%m', x.completiondate)=left('{dt_id}',6) 
					and format_date('%Y%m%d', x.completiondate)<='{dt_id}')
			-- case july that GCP need to adjust to Asia Jakarta to meet utc like in hadoop
			 or 
			 		(format_date('%Y%m', DATETIME(x.completiondate,'Asia/Jakarta'))=left('{dt_id}',6)
			 		and format_date('%Y%m%d', DATETIME(x.completiondate,'Asia/Jakarta'))<='{dt_id}'))
		and x.order_status = 'Complete'
		and x.order_type='Change Postpaid Plan'
		and (lower(x.main_package) like '%platinum%' or lower(x.main_package) like '%prime%')
), 
dm_renewal_3m as (
select 
distinct
	a.activation_date,
	a.msisdn
	-- b.completiondate
from (
		select
			* 
		from `data-nationalslsdist-prd-986g`.postpaid.raw_daily_ga as a
		where 1=1
			and a.order_type in ('New Registration','Migration') 
			and (
				  SUBSTR(a.activation_date,1,6) >= FORMAT_DATE('%Y%m', DATE_SUB(PARSE_DATE('%Y%m%d', '{dt_id}'), INTERVAL 3 MONTH))
				  and a.activation_date <= FORMAT_DATE('%Y%m%d', DATE_SUB(PARSE_DATE('%Y%m%d', '{dt_id}'), INTERVAL 1 MONTH))
				)
			and  a.tenure=3
	) as a
inner join renewal as b
	on a.msisdn=b.msisdn
), 
dm_final as (
	select
		a.*, 
		c.gua_rev_inc_tax/1000000 as origin_gua_rev,
		coalesce(c.tenure, cast(REGEXP_EXTRACT(a.origin_main_package , r'(\d+)\s+Bulan') as int64)) as origin_tenure,
		case when b.msisdn is not null then 'Yes'
			else 'No' end as eligible_program_3m_renewal,
		case when a.cpp_renewal_tenure=1 and lower(a.cpp_renewal_package) not like '%satu%' then 'Not Eligible'
			-- postpaid basic
			when lower(a.origin_main_package)='postpaid basic' 
				and upper(a.cpp_renewal_package)=upper(a.before_postpaid_basic) then 'Eligible - Not Upgrade'
			when lower(a.origin_main_package)='postpaid basic' 
				and a.cpp_renewal_tenure=coalesce(d.tenure, cast(REGEXP_EXTRACT(a.before_postpaid_basic, r'(\d+)\s+Bulan') as int64)) then 'Eligible - Not Upgrade'
			when lower(a.origin_main_package)='postpaid basic'
				and a.cpp_renewal_group ='Contract' and lower(a.before_postpaid_basic) not like '%bundling%' 
				and lower(a.before_postpaid_basic) not like '%contract%' then 'Eligible - Upgrade'
			when lower(a.origin_main_package)='postpaid basic'
				and a.cpp_renewal_tenure>coalesce(d.tenure, cast(REGEXP_EXTRACT(a.before_postpaid_basic, r'(\d+)\s+Bulan') as int64)) then 'Eligible - Upgrade'
			when lower(a.origin_main_package)='postpaid basic'
				and a.cpp_renewal_gua_rev>(d.gua_rev_inc_tax/1000000) then 'Eligible - Upgrade'
			-- non postpaid basic
			when upper(a.cpp_renewal_package)=upper(a.origin_main_package) then 'Eligible - Not Upgrade'
			when a.cpp_renewal_tenure=coalesce(c.tenure, cast(REGEXP_EXTRACT(a.origin_main_package, r'(\d+)\s+Bulan') as int64)) then 'Eligible - Not Upgrade'
			when a.cpp_renewal_group ='Contract' and a.origin_group <> 'Contract' then 'Eligible - Upgrade'
			when a.cpp_renewal_tenure>coalesce(c.tenure, cast(REGEXP_EXTRACT(a.origin_main_package, r'(\d+)\s+Bulan') as int64)) then 'Eligible - Upgrade'
			when a.cpp_renewal_gua_rev>(c.gua_rev_inc_tax/1000000) then 'Eligible - Upgrade'
			else 'Elgible - Not Upgrade' end as eligible_program_cpp_renewal, 
			row_number() over(partition by a.msisdn order by c.gua_rev_inc_tax desc, c.tenure desc) as rnk
	from dm_cpp as a
		left join dm_renewal_3m as b
			on a.msisdn=b.msisdn
		left join `data-nationalslsdist-prd-986g`.postpaid.ref_package_price as c
			on lower(a.origin_main_package)=lower(c.package_name)
		left join `data-nationalslsdist-prd-986g`.postpaid.ref_package_price as d
			on lower(a.before_postpaid_basic)=lower(d.package_name) and a.before_postpaid_basic is not null
)
select
*
from dm_final
where rnk=1
;
-- insert into `data-nationalslsdist-prd-986g`.postpaid.raw_cpp_renewal_program
-- with cpp as (
-- select * from (
-- 		select
-- 			a.*, 
-- 			row_number() over(partition by a.msisdn order by a.completiondate desc) as idx
-- 		from `data-dtp-prd-aa1a.smy.ar_change_pkg_pstpaid_rtl` as a 
-- 			where 1=1 
-- 			and a.dt_id>=TIMESTAMP_SUB(TIMESTAMP(PARSE_DATE('%Y%m%d', '{dt_id}')), INTERVAL 45 DAY)
-- 			and (
-- 					(format_date('%Y%m', a.completiondate)=left('{dt_id}',6) 
-- 					and format_date('%Y%m%d', a.completiondate)<='{dt_id}')
-- 			-- case july that GCP need to adjust to Asia Jakarta to meet utc like in hadoop
-- 			 or 
-- 			 		(format_date('%Y%m', DATETIME(a.completiondate,'Asia/Jakarta'))=left('{dt_id}',6)
-- 			 		and format_date('%Y%m%d', DATETIME(a.completiondate,'Asia/Jakarta'))<='{dt_id}'))
-- 	) as x where x.idx=1 
-- ),
-- dm_cpp as (
-- 	select 
-- 		a.msisdn, 
-- 		a.order_id,
-- 		a.ordernum,
-- 		a.order_type, 
-- 		a.account_num,
-- 		b.package_name as cpp_renewal_package,
-- 		b.package_type as cpp_renewal_group,
-- 		a.origin_main_package, 
-- 		case 
-- 					when a.origin_main_package='Postpaid Basic' then 'Postpaid Basic'
-- --					when coalesce(c.contract_status, d.package_type) is not null then coalesce(c.contract_status, d.package_type)	
-- 					when (lower(a.origin_main_package) like '%prime%' or lower(a.origin_main_package) like '%platinum%') and (lower(origin_main_package) like '%contract%' or lower(origin_main_package) like '%bundling%') then 'Contract'
-- 					when (lower(a.origin_main_package) like '%prime%' or lower(a.origin_main_package) like '%platinum%') and lower(origin_main_package) not like '%contract%' and lower(origin_main_package) not like '%bundling%' then 'Non Contract'
-- 				else 'Legacy Monthly'	
-- 				end origin_group,
-- 		b.tenure as cpp_renewal_tenure,
-- 		b.guaranteed_revenue_mio as cpp_renewal_gua_rev,
-- 		b.activation_date as cpp_renewal_date,
-- 		b.dealer_id as cpp_renewal_dealer_id, 
-- 		b.store_code_rev as cpp_renewal_store_code_rev,
-- 		b.sales_name as cpp_renewal_sales_name,
-- 		b.nik_sales as cpp_renewal_nik_sales,
-- 		b.circle as cpp_renewal_circle,
-- 		b.region_new_2024 as cpp_renewal_region
-- 	from cpp as a 
-- 		inner join `data-nationalslsdist-prd-986g`.postpaid.raw_daily_ga as b
-- 			on a.msisdn = b.msisdn and left(b.activation_date,6)=left('{dt_id}',6) and b.order_type='Change Postpaid Plan' 
-- --		left join `data-nationalslsdist-prd-986g`.postpaid.ref_package_plan as c
-- --			on lower(a.origin_main_package)=lower(c.new_plan) or lower(a.origin_main_package)=lower(c.orig_plan)
-- --		left join `data-nationalslsdist-prd-986g`.postpaid.ref_package_price as d
-- --			on lower(a.origin_main_package)=lower(d.package_name)
-- ), 
-- renewal as (
-- select * from (
-- 		select
-- 			a.*, 
-- 			row_number() over(partition by a.msisdn order by a.completiondate asc) as idx
-- 		from `data-dtp-prd-aa1a.smy.ar_change_pkg_pstpaid_rtl` as a 
-- 			where 1=1 
-- 			and a.dt_id>=TIMESTAMP_SUB(TIMESTAMP(PARSE_DATE('%Y%m%d', '{dt_id}')), INTERVAL 120 DAY)
-- 	) as x 
-- 		where x.idx=1 
-- 		and (
-- 					(format_date('%Y%m', x.completiondate)=left('{dt_id}',6) 
-- 					and format_date('%Y%m%d', x.completiondate)<='{dt_id}')
-- 			-- case july that GCP need to adjust to Asia Jakarta to meet utc like in hadoop
-- 			 or 
-- 			 		(format_date('%Y%m', DATETIME(x.completiondate,'Asia/Jakarta'))=left('{dt_id}',6)
-- 			 		and format_date('%Y%m%d', DATETIME(x.completiondate,'Asia/Jakarta'))<='{dt_id}'))
-- 		and x.order_status = 'Complete'
-- 		and x.order_type='Change Postpaid Plan'
-- 		and (lower(x.main_package) like '%platinum%' or lower(x.main_package) like '%prime%')
-- ), 
-- dm_renewal_3m as (
-- select 
-- distinct
-- 	a.activation_date,
-- 	a.msisdn
-- 	-- b.completiondate
-- from (
-- 		select
-- 			* 
-- 		from `data-nationalslsdist-prd-986g`.postpaid.raw_daily_ga as a
-- 		where 1=1
-- 			and a.order_type in ('New Registration','Migration') 
-- 			and (
-- 				  SUBSTR(a.activation_date,1,6) >= FORMAT_DATE('%Y%m', DATE_SUB(PARSE_DATE('%Y%m%d', '{dt_id}'), INTERVAL 3 MONTH))
-- 				  and a.activation_date <= FORMAT_DATE('%Y%m%d', DATE_SUB(PARSE_DATE('%Y%m%d', '{dt_id}'), INTERVAL 1 MONTH))
-- 				)
-- 			and  a.tenure=3
-- 	) as a
-- inner join renewal as b
-- 	on a.msisdn=b.msisdn
-- ), 
-- dm_final as (
-- 	select
-- 		a.*, 
-- 		c.gua_rev_inc_tax/1000000 as origin_gua_rev,
-- 		coalesce(c.tenure, cast(REGEXP_EXTRACT(package_name, r'(\d+)\s+Bulan') as int64)) as origin_tenure,
-- 		case when b.msisdn is not null then 'Yes'
-- 			else 'No' end as eligible_program_3m_renewal,
-- 		case when a.cpp_renewal_tenure=1 and lower(a.cpp_renewal_package) not like '%satu%' then 'Not Eligible'
-- 			when upper(a.cpp_renewal_package)=upper(a.origin_main_package) then 'Eligible - Not Upgrade'
-- 			when a.cpp_renewal_tenure=coalesce(c.tenure, cast(REGEXP_EXTRACT(package_name, r'(\d+)\s+Bulan') as int64)) then 'Eligible - Not Upgrade'
-- 			when a.cpp_renewal_group ='Contract' and a.origin_group <> 'Contract' then 'Eligible - Upgrade'
-- 			when a.cpp_renewal_tenure>coalesce(c.tenure, cast(REGEXP_EXTRACT(package_name, r'(\d+)\s+Bulan') as int64)) then 'Eligible - Upgrade'
-- 			when a.cpp_renewal_gua_rev>(c.gua_rev_inc_tax/1000000) then 'Eligible - Upgrade'
-- 			else 'Elgible - Not Upgrade' end as eligible_program_cpp_renewal
-- 	from dm_cpp as a
-- 		left join dm_renewal_3m as b
-- 			on a.msisdn=b.msisdn
-- 		left join `data-nationalslsdist-prd-986g`.postpaid.ref_package_price as c
-- 			on lower(a.origin_main_package)=lower(c.package_name)
-- )
-- select
-- *
-- from dm_final;		