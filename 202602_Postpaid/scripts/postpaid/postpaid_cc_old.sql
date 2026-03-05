-- ALL KPI
-- create or replace table `data-nationalslsdist-prd-986g`.postpaid.dm_cc_monthly as
insert into `data-nationalslsdist-prd-986g`.postpaid.dm_cc_monthly
with rce_mapping as (
	select distinct
		x.tenure,
		x.circle,
		x.region,
		x.store_code,
		upper(x.store_name) store_name,
		x.channel_group,
		upper(trim(x.rce_nik)) as rce_nik,
		upper(trim(x.rce)) rce,
		coalesce(y.rce_title, z.rce_flag) rce_title
	from 
				(
				select * from (
		        	select 
		        		ROUND(
							  DATE_DIFF(
							    SAFE.PARSE_DATE('%Y%m%d', '{dt_id}'),
							    SAFE.PARSE_DATE('%Y%m%d', registered_date),
							    MONTH
							  ), 
							  0
							) AS tenure,
		        		*, row_number() over(partition by store_code order by updated_dt desc) as rnk
		        	from `data-nationalslsdist-prd-986g`.postpaid.ref_storelist_base rsb
		        	where mth_id=left('{dt_id}',6) 
		        		and updated_dt = (select max(updated_dt) from `data-nationalslsdist-prd-986g`.postpaid.ref_storelist_base where mth_id=left('{dt_id}',6))
		        ) as x where rnk=1
		        ) as x 
	left join (
					select * from (
					select
		        		*, row_number() over(partition by upper(trim(rce_name)) order by updated_dt desc) as rnk
		        	from `data-nationalslsdist-prd-986g`.postpaid.ref_is_mapping rsb
		        	where mth_id=left('{dt_id}',6)
		        	) x where rnk=1
	) as y 
		-- on upper(x.rce_nik)=upper(y.rce_nik)
		on upper(trim(x.rce))=upper(trim(y.rce_name))
	left join (
				select 
					-- rce_nik, 
					rce,
						CASE 
						    WHEN SUM(CASE WHEN LOWER(channel_group) LIKE '%direct%' THEN 1 ELSE 0 END)
						       >= SUM(CASE WHEN LOWER(channel_group) LIKE '%partner%' THEN 1 ELSE 0 END)
						    THEN 'RCE DS'
						    ELSE 'RCE PS'
						  END AS rce_flag
						from (
					        	select 
					        		ROUND(
										  DATE_DIFF(
										    SAFE.PARSE_DATE('%Y%m%d', '{dt_id}'),
										    SAFE.PARSE_DATE('%Y%m%d', registered_date),
										    MONTH
										  ), 
										  0
										) AS tenure,
					        		*, row_number() over(partition by store_code order by updated_dt desc) as rnk
					        	from `data-nationalslsdist-prd-986g`.postpaid.ref_storelist_base rsb
					        		where mth_id=left('{dt_id}',6)
					        			and updated_dt = (select max(updated_dt) from `data-nationalslsdist-prd-986g`.postpaid.ref_storelist_base where mth_id=left('{dt_id}',6))  
					        ) as x where rnk=1
			group by 1
	) as z 
		-- on upper(x.rce_nik)=upper(z.rce_nik)
		on upper(trim(x.rce))=upper(trim(z.rce))
		where 1=1
)
, ga_contract as(
	select  
        coalesce(b.circle, a.circle) as circle,
        coalesce(b.region, a.region_new_2024) as region,
        b.rce_nik as nik_rce,
        b.rce as name_rce,
        case when lower(a.agent_type) like '%outcall%' and a.nik_sales is not null and a.nik_sales not in ('')
        		then upper(a.nik_sales) else upper(a.store_code_rev) end as store_code,
        b.rce_title,
        case when upper(b.rce_title) like '%PS' then 'PARTNER STORE' 
        	when upper(b.rce_title) like '%DS' then 'DIRECT SALES'
        	when upper(b.rce_title) like '%SMB' then 'SMB'
        	when upper(b.rce_title) like '%GERAI' then 'GERAI'
        	end as channel_group,
        left('{dt_id}',6) as mth_id,
        '{dt_id}' as dt_id,
        -- belum ditambahkan pengakuan setelah pembayaran ke 3
        count(distinct 
        			case when upper(b.channel_group) like '%PARTNER%STORE' and a.tenure=1 then null
        				when upper(b.channel_group) like '%DIRECT%SALES' and a.tenure=1 then null
        				else a.msisdn end ) ga,
        sum(case when upper(b.channel_group) like '%PARTNER%STORE' and a.tenure=1 then 0
        				when upper(b.channel_group) like '%DIRECT%SALES' and a.tenure=1 then 0
        				else (cast(a.guaranteed_revenue_mio as float64)*1000000) end) gua_rev
    from `data-nationalslsdist-prd-986g`.postpaid.raw_daily_ga as a 
    left join rce_mapping as b
        	on case when lower(a.agent_type) like '%outcall%' and a.nik_sales is not null and a.nik_sales not in ('')
        		then upper(a.nik_sales) else upper(a.store_code_rev) end=upper(b.store_code)
        where 1=1 
        	and left(a.activation_date,6)=left('{dt_id}',6)
        	and a.order_type in ('New Registration','Migration')
    group by 1,2,3,4,5,6,7,8,9
	order by 1
)
, ga_monthly as (
	select  
        coalesce(b.circle, a.circle) as circle,
        coalesce(b.region, a.region_circle) as region,
        b.rce_nik as nik_rce,
        b.rce as name_rce,
        case when lower(a.agent_type) like '%outcall%' and a.nik_sales is not null and a.nik_sales not in ('')
        		then upper(a.nik_sales) else upper(a.store_code_rev) end as store_code,
        b.rce_title,
        case when upper(b.rce_title) like '%PS' then 'PARTNER STORE' 
        	when upper(b.rce_title) like '%DS' then 'DIRECT SALES'
        	when upper(b.rce_title) like '%SMB' then 'SMB'
        	when upper(b.rce_title) like '%GERAI' then 'GERAI'
        	end as channel_group,
        left('{dt_id}',6) as mth_id,
        '{dt_id}' as dt_id,
        count(distinct a.msisdn) ga,
        sum(a.gua_rev) as gua_rev        
    from `data-nationalslsdist-prd-986g`.postpaid.raw_monthly_payment as a 
    left join rce_mapping as b
        	on case when lower(a.agent_type) like '%outcall%' and a.nik_sales is not null and a.nik_sales not in ('')
        		then upper(a.nik_sales) else upper(a.store_code_rev) end=upper(b.store_code)
        where 1=1 
        	and a.pymt_mth = left('{dt_id}',6)
			and cast(a.activation_date as int64)>=20250801 -- tanggal policy diterapkan since agustus
			and a.pymt_mth_cat = 'M3'
        	and a.order_type in ('New Registration','Migration')
        	and (upper(b.channel_group) like '%DIRECT%SALES'
        		or lower(a.agent_type) like '%outcall%')
    group by 1,2,3,4,5,6,7,8,9
	order by 1
)
, ga_base as (
	select 
		a.circle,
		a.region,
		a.nik_rce,
		a.name_rce,
		a.store_code,
		a.rce_title,
		a.channel_group,
		a.mth_id,
		a.dt_id,
		sum(a.ga) ga,
		sum(a.gua_rev) gua_rev
	from (
		select
			*
		from ga_contract
		union all 
		select
			* 
		from ga_monthly
	) as a
	group by 1, 2, 3, 4, 5, 6, 7, 8, 9
)
, ga as (
select 
		a.circle,
		a.region,
		a.nik_rce,
		a.name_rce,
		cast(null as string) as store_code,
		a.rce_title as store_name,
		a.channel_group,
		sum(a.ga) as value_mtd,
		null as value_lmtd,
		a.mth_id,
		a.dt_id,
		'GA' as kpi_name
from ga_base as a
group by 1, 2, 3, 4, 5, 6, 7, 9, 10, 11, 12
)
, productivity as (
	select  
        coalesce(b.circle, a.circle) as circle,
        coalesce(b.region, a.region) as region,
        b.rce_nik as nik_rce,
        b.rce as name_rce,
        a.store_code as store_code,
        b.rce_title as rce_title,
        case when upper(b.rce_title) like '%PS' then 'PARTNER STORE' 
        	when upper(b.rce_title) like '%DS' then 'DIRECT SALES'
        	when upper(b.rce_title) like '%SMB' then 'SMB'
        	when upper(b.rce_title) like '%GERAI' then 'GERAI'
        	end as channel_group,
        a.ga,
        case when b.tenure<= 1 and a.ga >=1 then 1
        	when b.tenure= 2 and a.ga >=2 then 1
        	when a.ga >=3 then 1
        	else 0 end as store_productivity, 
        case when c.target_productivity is not null then least(a.ga/cast(c.target_productivity as float64), 1.5)
	        when b.tenure<= 1 then least(a.ga/15, 1.5)
        	when b.tenure= 2 then least(a.ga/30, 1.5)
        	else least(a.ga/40,1.5) end as agent_productivity 
    from ga_base as a 
    left join rce_mapping as b
        	on upper(a.store_code)=upper(b.store_code)
    left join (
    	SELECT  
			distinct 
			  store_code_rev,
			  pom as target_productivity
			FROM `data-nationalslsdist-prd-986g.postpaid.ref_target_store`
			where pom is not null
				and format_date('%Y%m', PARSE_TIMESTAMP('%Y-%m-%d %H:%M:%S', date))=left('{dt_id}',6)
    )	as c
    		on upper(a.store_code)=upper(c.store_code_rev)
)
, sales_revenue as (
	select 
		a.circle,
		a.region,
		a.nik_rce,
		a.name_rce,
		cast(null as string) as store_code,
		a.rce_title as store_name,
		a.channel_group,
		sum(a.gua_rev) as value_mtd,
		null as value_lmtd,
		a.mth_id,
		a.dt_id,
		'Sales Revenue' as kpi_name
from ga_base as a
group by 1, 2, 3, 4, 5, 6, 7, 9, 10, 11, 12
),
productivity_all as (
	select
			a.circle,
			a.region,
	        a.nik_rce,
	        a.name_rce,
	        cast(null as string) store_code,
	        a.rce_title as store_name,
			a.channel_group,
	        sum(store_productivity) value_mtd,
	        null as value_lmtd,
	        left('{dt_id}',6) as mth_id,
	        '{dt_id}' as dt_id,
	        'Store Productivity' as kpi_name
	from productivity as a
	group by 1, 2, 3, 4, 5, 6, 7, 9, 10, 11, 12
	union all
	select
			a.circle,
			a.region,
	        a.nik_rce,
	        a.name_rce,
	        cast(null as string) as store_code,
	        a.rce_title as store_name,
			a.channel_group,
	        avg(agent_productivity) value_mtd,
	        null as value_lmtd,
	        left('{dt_id}',6) as mth_id,
	        '{dt_id}' as dt_id,
	        'Agent Productivity %' as kpi_name
	from productivity as a
	group by 1, 2, 3, 4, 5, 6, 7, 9, 10, 11, 12
),
m3s as (
	select
		x.circle,
		x.region_new_2024,
		x.store_code_rev,
		x.store_name_rev,
		count(distinct x.msisdn) ga,
		sum(x.ast_st) m3s
	from (
		select
			distinct
				a.msisdn,
				a.activation_date,
				a.circle, 
				a.region_new_2024,
				case when lower(a.agent_type) like '%outcall%' and a.nik_sales is not null and a.nik_sales not in ('')
					then upper(a.nik_sales) else upper(a.store_code_rev) end store_code_rev,
				a.store_name_rev, 
				case when b.msisdn is not null then 1 else 0 end as ast_st
		from `data-nationalslsdist-prd-986g`.postpaid.raw_daily_ga as a
			left join (
					select 
						distinct
						msisdn
					FROM `data-bi-prd-935c.bi_dm.rk_cst_pstpaid_rtl_v1` 
						WHERE DATE(dt_id) >= DATE_TRUNC(PARSE_DATE('%Y%m%d', '{dt_id}'), MONTH)
		  							AND DATE(dt_id) < DATE_ADD(DATE_TRUNC(PARSE_DATE('%Y%m%d', '{dt_id}'), MONTH), INTERVAL 1 MONTH)
							and upper(ast_st) = 'ACTIVE'
		  					-- and upper(ac_st) = 'ACTIVE'
			) as b
				on a.msisdn=b.msisdn
			where 1=1 
		    	and left(a.activation_date,6)=FORMAT_DATE('%Y%m', DATE_SUB(PARSE_DATE('%Y%m%d', '{dt_id}'),INTERVAL 3 MONTH))
		    	and a.order_type in ('New Registration','Migration')
		    	and a.tenure=1
		    	) as x
	group by 1, 2, 3, 4
),
m3s_final as (
	select  
	        coalesce(b.circle, a.circle) as circle,
	        coalesce(b.region, a.region_new_2024) as region,
	        b.rce_nik as nik_rce,
	        b.rce as name_rce,
	        cast(null as string) as store_code,
	        b.rce_title as store_name,
	        case when upper(b.rce_title) like '%PS' then 'PARTNER STORE' 
	        	when upper(b.rce_title) like '%DS' then 'DIRECT SALES'
	        	when upper(b.rce_title) like '%SMB' then 'SMB'
	        	when upper(b.rce_title) like '%GERAI' then 'GERAI'
	        	end as channel_group,
	        sum(a.m3s)/sum(a.ga) as value_mtd,
	        null as value_lmtd,
	        left('{dt_id}',6) as mth_id,
	        '{dt_id}' as dt_id,
	        'M3S %' as kpi_name
	from m3s as a 
	left join rce_mapping as b
	    	on upper(a.store_code_rev)=upper(b.store_code)
	group by 1,2,3,4,5,6,7,9,10,11,12
	order by 1
)
select 
	a.*
from ga as a
union all
select
	b.*
from sales_revenue as b
union all
select
	c.*
from productivity_all as c
union all
select
	d.*
from m3s_final as d
order by 12, 3;