with rce_mapping as (
	select distinct
		x.tenure,
		x.circle,
		x.region,
		x.store_code,
		upper(x.store_name) store_name,
		x.channel_group,
		case when lower(x.rce) not like '%vacant%' and lower(x.rce) not like '%no%rce%' 
			then upper(trim(x.rce_nik))
		else null end as rce_nik,
		case when lower(x.rce) not like '%vacant%' and lower(x.rce) not like '%no%rce%'
			then upper(trim(x.rce)) 
		else null end as rce,
		upper(coalesce(y.rce_title, z.rce_flag)) rce_title
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
		        		and rsb.updated_dt = (select max(updated_dt) from `data-nationalslsdist-prd-986g`.postpaid.ref_is_mapping where mth_id=left('{dt_id}',6))
		        	) x where rnk=1
	) as y 
		-- on upper(x.rce_nik)=upper(y.rce_nik)
		on upper(trim(x.rce))=upper(trim(y.rce_name))
	left join (
				select 
					-- rce_nik, 
					rce,
						CASE 
							WHEN SUM(CASE WHEN LOWER(channel_group) LIKE '%gerai%' or LOWER(channel_group) LIKE '%franchise%' THEN 1 ELSE 0 END) >=1 
								THEN 'RCE GERAI'
							WHEN SUM(CASE WHEN LOWER(channel_group) LIKE '%smb%' then 1 else 0 end) >= 1
								THEN 'RCE SMB'
						    WHEN SUM(CASE WHEN LOWER(channel_group) LIKE '%direct%' THEN 1 ELSE 0 END)
						       >= SUM(CASE WHEN LOWER(channel_group) LIKE '%partner%' THEN 1 ELSE 0 END)
						    	THEN 'RCE DS'
						    WHEN SUM(CASE WHEN LOWER(channel_group) LIKE '%partner%' THEN 1 ELSE 0 END)
						       > SUM(CASE WHEN LOWER(channel_group) LIKE '%direct%' THEN 1 ELSE 0 END)
						    	THEN 'RCE PS'
						    ELSE null
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
, m3s as (
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
					-- where date(dt_id) between date(SUBSTR('{dt_id}',1,4) || '-' || SUBSTR('{dt_id}',5,2) || '-01')
						-- and PARSE_DATE('%Y%m%d', '{dt_id}')
					WHERE DATE(dt_id) >= DATE_TRUNC(PARSE_DATE('%Y%m%d', '{dt_id}'), MONTH)
		  					AND DATE(dt_id) < DATE_ADD(DATE_TRUNC(PARSE_DATE('%Y%m%d', '{dt_id}'), MONTH), INTERVAL 1 MONTH)
							and upper(ast_st) = 'ACTIVE'
		  					-- and upper(ac_st) = 'ACTIVE'
			) as b
				on a.msisdn=b.msisdn
			where 1=1 
		    	and left(a.activation_date,6)=FORMAT_DATE('%Y%m', DATE_SUB(PARSE_DATE('%Y%m%d', '{dt_id}'),INTERVAL 3 MONTH))
		    	and a.order_type in ('New Registration','Migration')
		    	and (a.tenure=1 or a.tenure=3)
		    	) as x
	group by 1, 2, 3, 4
),
m3s_final as (
	select  
			left('{dt_id}',6) as mth_id,
	        '{dt_id}' as dt_id,
	        'M3S %' as kpi_name,
	        coalesce(b.circle, a.circle) as circle,
	        coalesce(b.region, a.region_new_2024) as region,
	        b.rce_nik as nik_rce,
	        b.rce as name_rce,
	        a.store_code_rev as store_code,
	        -- a.store_name_rev as store_name,
	        b.rce_title as store_name,
	        case when upper(b.rce_title) like '%PS' then 'PARTNER STORE' 
	        	when upper(b.rce_title) like '%DS' then 'DIRECT SALES'
	        	when upper(b.rce_title) like '%SMB' then 'SMB'
	        	when upper(b.rce_title) like '%GERAI' then 'GERAI'
	        	end as channel_group,
	        sum(a.ga) as ga,
	        sum(a.m3s) as m3s,
	        sum(a.m3s)/sum(a.ga) as m3s_prctg
	from m3s as a 
	left join rce_mapping as b
	    	on upper(a.store_code_rev)=upper(b.store_code)
	group by all
	order by 1
)
select
	a.*
from m3s_final as a
order by 12, 3;