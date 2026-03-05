--  IM3
-- 01. Agent Productivity
insert overwrite rdm.retail_champion_club 
partition (kpi_name, mth_id)
with siebel_data as
(
	select
		distinct
	    a.dt_id as dt_id,
		REGEXP_EXTRACT(a.creator_location , '^(.*?)-', 1) AS store_code,
		creator_login as creator_id,
		creator_name,
		a.msisdn
	from
		stg.stg_siebel_dly_intrctn as a
	where
		a.status = 'Closed'
		and ((strleft(a.dt_id,6)=strleft('{dt_id}',6) and a.dt_id<='{dt_id}') 
	        or  (strleft(a.dt_id,6)=from_timestamp(add_months(to_timestamp('{dt_id}','yyyyMMdd'),-1),'yyyyMM') and a.dt_id<=from_timestamp(add_months(to_timestamp('{dt_id}','yyyyMMdd'),-1),'yyyyMMdd')))
)
,ipos_data as
(
	select
		distinct
        (FROM_UNIXTIME(UNIX_TIMESTAMP(a.transaction_date,'dd/MM/yyyy HH:mm'),'yyyyMMdd')) as dt_id,
		organization_ref_code as store_code,
		a.username as creator_id,
		concat(a.username, '-', a.organization_name) creator_name,
		customer_msisdn as msisdn
	from
		rdm.ipos_trans_details as a
	where
		((FROM_UNIXTIME(UNIX_TIMESTAMP(a.transaction_date,'dd/MM/yyyy HH:mm'),'yyyyMM') = strleft('{dt_id}',6) and FROM_UNIXTIME(UNIX_TIMESTAMP(a.transaction_date,'dd/MM/yyyy HH:mm'),'yyyyMMdd') <='{dt_id}') 
            or (FROM_UNIXTIME(UNIX_TIMESTAMP(a.transaction_date,'dd/MM/yyyy HH:mm'),'yyyyMM') = from_timestamp(add_months(to_timestamp('{dt_id}','yyyyMMdd'),-1),'yyyyMM') and FROM_UNIXTIME(UNIX_TIMESTAMP(a.transaction_date,'dd/MM/yyyy HH:mm'),'yyyyMMdd') <=from_timestamp(add_months(to_timestamp('{dt_id}','yyyyMMdd'),-1),'yyyyMMdd'))) 
		and status = 'Success'
)
, data_interactions as (
	select
		'siebel' as source,
		a.dt_id,
		a.store_code,
		a.creator_id,
		count(distinct a.msisdn) as interactions
	from
		siebel_data as a
	group by
		1, 2, 3, 4
	union all
	select
		'ipos' as source,
		b.dt_id,
		b.store_code,
		b.creator_id,
		count(distinct b.msisdn) as interactions
	from
		(
		select
			x.*
		from
			ipos_data as x
		where
			concat(strleft(x.dt_id, 6), x.store_code, x.msisdn) not in (
			select
				distinct concat(strleft(a.dt_id, 6), a.store_code, a.msisdn)
			from
				siebel_data as a)
	)as b
	group by
		1, 2, 3,4),
		itrx as (
		select
			a.dt_id,
			a.store_code,
			a.creator_id,
			sum(interactions) as interactions
		from
			data_interactions as a
		group by
			1, 2, 3
)
, rgu_ga as (
	select
		a.activation_date as dt_id,
		a.store_code_rev as store_code,
		a.nik_sales as creator_id,
		b.circle,
		b.region_circle,
		b.area,
		b.sales_area,
		upper(b.store_name) store_name,
		b.channel_group,
		count(distinct case when lower(a.order_type) in ('migration', 'new registration') then a.msisdn end) as rgu_ga_only,
		count(distinct case when lower(a.order_type) in ('migration', 'change postpaid plan', 'new registration') then a.msisdn end) as rgu_ga
	from
		rdm.dump_daily_ga as a
	inner join rdm.storelist as b
	on
		a.store_code_rev = b.store_code
	where
		(lower(b.channel_group) like '%gerai%'
			or lower(b.channel_group) like '%franchise%')
		-- and cast(strleft(a.activation_date,6) as int) = cast(strleft('{dt_id}',6) as int)
        and ((strleft(a.activation_date,6)=strleft('{dt_id}',6) and a.activation_date<='{dt_id}') 
	        or  (strleft(a.activation_date,6)=from_timestamp(add_months(to_timestamp('{dt_id}','yyyyMMdd'),-1),'yyyyMM') and a.activation_date<=from_timestamp(add_months(to_timestamp('{dt_id}','yyyyMMdd'),-1),'yyyyMMdd')))
    group by
		1, 2, 3, 4, 5, 6, 7, 8, 9
)
, db_itrx as (
	select
		b.dt_id,
		a.store_code,
		a.creator_id
	from
		(
		select
			distinct creator_id,
			store_code
		from
			rgu_ga) as a
	cross join
	(
		select
			distinct dt_id
		from
			rgu_ga
	) as b
)
, ga_combine as (
	select
		a.dt_id,
		a.store_code,
		a.creator_id,
		coalesce(b.rgu_ga,
		0) rgu_ga,
		coalesce(b.rgu_ga_only,
		0) rgu_ga_only
	from
		db_itrx as a
	left join rgu_ga as b
	on
		a.dt_id = b.dt_id
		and a.store_code = b.store_code
		and a.creator_id = b.creator_id
)
,sum_ga as (
	select
		a.dt_id,
		b.circle,
		b.region_circle,
		b.area,
		b.sales_area,
		upper(b.store_name) store_name,
		b.channel_group,
		a.store_code,
		a.creator_id,
		a.rgu_ga,
		a.rgu_ga_only
	from
		ga_combine as a
	left join rdm.storelist as b
	on
		a.store_code = b.store_code
)
, final_result as (
	select
		a.dt_id,
		FROM_UNIXTIME(UNIX_TIMESTAMP(a.dt_id,
		'yyyyMMdd'),
		'yyyy-MM-dd') as trx_date,
		strleft(a.dt_id,
		6) as mth_id,
		a.circle,
		a.region_circle,
		a.area,
		a.sales_area,
		a.store_name,
		a.channel_group,
		a.store_code,
		a.creator_id,
		a.rgu_ga,
		a.rgu_ga_only,
		coalesce(b.interactions,
		0) unique_visitors
	from
		sum_ga as a
	left join itrx as b
	on
		a.store_code = b.store_code
		and a.dt_id = b.dt_id
		and a.creator_id = b.creator_id
)
, result_agent AS  (
	select
		a.mth_id,
		'{dt_id}' as dt_id,
		a.circle,
		a.region_circle,
		a.area,
		a.sales_area,
		a.store_name,
		a.channel_group,
		a.store_code,
		a.creator_id,
		sum(a.rgu_ga) as rgu_ga,
		sum(a.rgu_ga_only) as rgu_ga_only,
		sum(unique_visitors) as unique_visitors,
		round((sum(a.rgu_ga)/ sum(unique_visitors)), 2) as conversion_rate_ga,
		round((sum(a.rgu_ga_only)/ sum(unique_visitors)), 2) as conversion_rate_ga_only
	from
		final_result as a
	-- join to data agent to get only agent instore
	left join rdm.user_detail_report_ipos as b 
		on a.creator_id=b.username
	where b.agent_category='Agent Instore' and b.status='Active' 
	group by
		1, 2, 3, 4, 5, 6, 7, 8, 9, 10
)
, pop_agent as (
	select  
    mth_id,
	circle, 
	region_circle, 
	count(distinct username) as num_agent
	from rdm.user_detail_report_ipos as a 
	left join rdm.storelist s  
		on a.organization_ref_code=s.store_code
	where a.agent_category='Agent Instore' and a.status='Active'  
	and s.channel_group in ('FRANCHISE', 'OWN GERAI')
	group by 1, 2, 3
	order by 1
)
select   
	a.dt_id,
	a.circle, 
	a.region_circle,   
	'IM3' as brand, 
	max(case when a.mth_id=strleft('{dt_id}',6) then b.num_agent end) as mtd_value, 
    max(case when a.mth_id=from_timestamp(add_months(to_timestamp('{dt_id}','yyyyMMdd'),-1),'yyyyMM') then b.num_agent end) as lmtd_value, 
    'total_agent' as kpi_name, 
	strleft(a.dt_id,6) as mth_id
from result_agent as a 
	left join pop_agent as b 
		on a.region_circle=b.region_circle and a.mth_id=b.mth_id
group by 1, 2, 3, 4, 7, 8
order by 1 
union all 
select 
	a.dt_id,
	a.circle, 
	a.region_circle,   
	'IM3' as brand, 
	count(distinct case when a.conversion_rate_ga_only>=0.1 and a.mth_id=strleft('{dt_id}',6) then a.creator_id end) as mtd_value, 
    count(distinct case when a.conversion_rate_ga_only>=0.1 and a.mth_id=from_timestamp(add_months(to_timestamp('{dt_id}','yyyyMMdd'),-1),'yyyyMM') then a.creator_id end) as lmtd_value, 
	'total_agent_achieve' as kpi_name, 
    strleft(a.dt_id,6) as mth_id
from result_agent as a 
group by 1, 2, 3, 4, 7, 8 
order by 1 
union all 
select   
	a.dt_id,
	a.circle, 
	a.region_circle,   
	'IM3' as brand, 
	count(distinct case when a.conversion_rate_ga_only>=0.1 and a.mth_id=strleft('{dt_id}',6) then a.creator_id end)/max(case when a.mth_id=strleft('{dt_id}',6) then b.num_agent end) as mtd_value, 
    count(distinct case when a.conversion_rate_ga_only>=0.1 and a.mth_id=from_timestamp(add_months(to_timestamp('{dt_id}','yyyyMMdd'),-1),'yyyyMM') then a.creator_id end)/max(case when a.mth_id=from_timestamp(add_months(to_timestamp('{dt_id}','yyyyMMdd'),-1),'yyyyMM') then b.num_agent end) as lmtd_value, 
    'agent_productivity' as kpi_name, 
    strleft(a.dt_id,6) as mth_id
from result_agent as a 
	left join pop_agent as b 
		on a.region_circle=b.region_circle and a.mth_id=b.mth_id
group by 1, 2, 3, 4, 7, 8
order by 1
; 

-- 02. Store Productivity 
insert overwrite rdm.retail_champion_club 
partition (kpi_name, mth_id)
with mtd_sim as(
	select 
		-- x1.msisdn, 
		-- x1.organization_name, 
		x1.store_code, 
		-- x1.event_type_main, 
		-- x1.month_id, 
		-- 'mtd' as flag_rev,
		sum(t2.rev_30) rev_sim_replacement
	from (
		select t1.* from
		(
				select 
				a.*, 
				row_number() over(partition by msisdn order by month_id desc, store_code) idx 
		       	from (
			       	select distinct 
					    customer_msisdn msisdn, 
					    organization_name, 
					    organization_ref_code store_code, 
					    service_type event_type_main, 
					    from_timestamp(to_timestamp(transaction_date,'dd/MM/yyyy HH:mm:ss'),'yyyyMM') month_id
					from rdm.ipos_trans_details 
					where status = 'Success'
						and service_type in ('Prepaid SIM Replacement','Postpaid SIM Replacement','Postpaid Sim Replacement New','Postpaid SIM Replacement New')
						and from_timestamp(to_timestamp(transaction_date,'dd/MM/yyyy HH:mm:ss'),'yyyyMMdd')<='{dt_id}'
						and from_timestamp(to_timestamp(transaction_date,'dd/MM/yyyy HH:mm:ss'),'yyyyMM')>=from_timestamp(add_months(to_timestamp('{dt_id}','yyyyMMdd'),-2),'yyyyMM') 
		       	) a
		        where month_id in (from_timestamp(last_day(add_months(to_timestamp(CONCAT(strleft('{dt_id}',6),'01'),'yyyyMMdd'),-2)),'yyyyMM'),
		        	from_timestamp(last_day(add_months(to_timestamp(CONCAT(strleft('{dt_id}',6),'01'),'yyyyMMdd'),-1)),'yyyyMM'),
		        	from_timestamp(last_day(to_timestamp(CONCAT(strleft('{dt_id}',6), '01'), 'yyyyMMdd')), 'yyyyMM'))
		) t1
		where idx=1 
	) x1 
	inner join 
	(
		select 
			msisdn, 
			sum(rev_30) rev_30, 
			strleft(dt_id,6) rev_month
		from biadm.hg_rgs_all_nogovt_dly
		where dt_id='{dt_id}'
		group by 1,3
	) t2
	on x1.msisdn=t2.msisdn 
	group by 1 
)
,lmtd_sim as(
	select 
		-- x1.msisdn, 
		-- x1.organization_name, 
		x1.store_code, 
		-- x1.event_type_main, 
		-- x1.month_id, 
		-- 'lmtd' as flag_rev,
		sum(t2.rev_30) rev_sim_replacement
	from (
		select t1.* from
		(
				select 
				a.*, 
				row_number() over(partition by msisdn order by month_id desc, store_code) idx 
		       	from (
			       	select distinct 
					    customer_msisdn msisdn, 
					    organization_name, 
					    organization_ref_code store_code, 
					    service_type event_type_main, 
					    from_timestamp(to_timestamp(transaction_date,'dd/MM/yyyy HH:mm:ss'),'yyyyMM') month_id
					from rdm.ipos_trans_details 
					where status = 'Success'
						and service_type in ('Prepaid SIM Replacement','Postpaid SIM Replacement','Postpaid Sim Replacement New','Postpaid SIM Replacement New')
						and from_timestamp(to_timestamp(transaction_date,'dd/MM/yyyy HH:mm:ss'),'yyyyMMdd')<=from_timestamp(add_months(to_timestamp('{dt_id}','yyyyMMdd'),-1),'yyyyMMdd')
						and from_timestamp(to_timestamp(transaction_date,'dd/MM/yyyy HH:mm:ss'),'yyyyMM')>=from_timestamp(add_months(to_timestamp('{dt_id}','yyyyMMdd'),-3),'yyyyMM') 
		       	) a
		        where month_id in (from_timestamp(last_day(add_months(to_timestamp(CONCAT(strleft('{dt_id}',6),'01'),'yyyyMMdd'),-3)),'yyyyMM'),
		        	from_timestamp(last_day(add_months(to_timestamp(CONCAT(strleft('{dt_id}',6),'01'),'yyyyMMdd'),-2)),'yyyyMM'),
		        	from_timestamp(last_day(add_months(to_timestamp(CONCAT(strleft('{dt_id}',6),'01'),'yyyyMMdd'),-1)),'yyyyMM'))
		) t1
		where idx=1 
	) x1 
	inner join 
	(
		select 
			msisdn, 
			sum(rev_30) rev_30, 
			strleft(dt_id,6) rev_month
		from biadm.hg_rgs_all_nogovt_dly
		where dt_id=from_timestamp(add_months(to_timestamp('{dt_id}','yyyyMMdd'),-1),'yyyyMMdd')
		group by 1,3
	) t2
	on x1.msisdn=t2.msisdn 
	group by 1
) 
, mtd_cash as(
	SELECT
		FROM_UNIXTIME(UNIX_TIMESTAMP(transaction_date, 'dd/MM/yyyy HH:mm'), 'yyyyMM') as mth_id,
		organization_ref_code store_code,
		sum(CAST(service_amount_collected AS DOUBLE)) rev_cash_in
	FROM
		rdm.ipos_trans_details
	WHERE
		`status` = 'Success'
		AND FROM_UNIXTIME(UNIX_TIMESTAMP(transaction_date, 'dd/MM/yyyy HH:mm'), 'yyyyMM')=strleft('{dt_id}',6) 
		and FROM_UNIXTIME(UNIX_TIMESTAMP(transaction_date, 'dd/MM/yyyy HH:mm'), 'yyyyMM') <='{dt_id}'
	GROUP BY
		1, 2
)
, lmtd_cash as (
	SELECT
		FROM_UNIXTIME(UNIX_TIMESTAMP(transaction_date, 'dd/MM/yyyy HH:mm'), 'yyyyMM') as mth_id,
		organization_ref_code store_code,
		sum(CAST(service_amount_collected AS DOUBLE)) rev_cash_in
	FROM
		rdm.ipos_trans_details
	WHERE
		`status` = 'Success'
		AND FROM_UNIXTIME(UNIX_TIMESTAMP(transaction_date, 'dd/MM/yyyy HH:mm'), 'yyyyMM')=from_timestamp(add_months(to_timestamp('{dt_id}','yyyyMMdd'),-1),'yyyyMM') 
		AND FROM_UNIXTIME(UNIX_TIMESTAMP(transaction_date, 'dd/MM/yyyy HH:mm'), 'yyyyMMdd')<=from_timestamp(add_months(to_timestamp('{dt_id}','yyyyMMdd'),-1),'yyyyMMdd')
	GROUP BY
		1, 2
) 
, result_region as (
select 
	'{dt_id}' as dt_id, 
	store.circle, 
	-- store.region_circle,  
	store.region_new as region_circle,
	store.store_code,
	'IM3' as brand,
	sum(coalesce(mtd_sim.rev_sim_replacement,0)+coalesce(mtd_cash.rev_cash_in,0)) as mtd_value, 
	sum(coalesce(lmtd_sim.rev_sim_replacement,0)+coalesce(lmtd_cash.rev_cash_in,0)) as lmtd_value, 
	'store_productivity_rev_ach' as kpi_name, 
	strleft('{dt_id}', 6) as mth_id
-- change ref from target 
from rdm.retail_store_target as store
-- from  rdm.storelist as store  
	-- adding join to max 100% prod 
	-- inner join rdm.retail_store_target as tgt 
		-- on store.store_code=tgt.store_code
	left join mtd_sim
		on store.store_code=mtd_sim.store_code 
	left join mtd_cash 
		on store.store_code=mtd_cash.store_code 
	left join lmtd_sim
		on store.store_code=lmtd_sim.store_code 
	left join lmtd_cash 
		on store.store_code=lmtd_cash.store_code
where 1=1 
-- and store.channel_group in ('FRANCHISE', 'OWN GERAI')	
-- and (store.closed_date is null or store.closed_date ='')
group by 1, 2, 3, 4, 5, 8, 9  
)  
, cal_result_region as (
	select  
		a.dt_id, 
		a.circle, 
		a.region_circle, 
		a.brand, 
		a.store_code, 
		case when (a.mtd_value/b.mtd_target)>=1 then 1 else 0 end as mtd_value, 
		case when (a.lmtd_value/b.lmtd_target)>=1 then 1 else 0 end as lmtd_value, 
		a.kpi_name, 
		a.mth_id
	from result_region as a  
		left join 
			(
			select 
			store_code, 
			max(case when mth_id=strleft('{dt_id}',6) then kpi_value end) mtd_target, 
			max(case when mth_id=from_timestamp(add_months(to_timestamp('{dt_id}','yyyyMMdd'),-1),'yyyyMM') then kpi_value end) lmtd_target
			from rdm.retail_store_target 
			where kpi_target='revenue_all'
			group by 1
			) as b  
		 on a.store_code = b.store_code
)
, cal_target as(
	select  
			a.circle, 
			a.region_new, 
			count(distinct case when a.mth_id=strleft('{dt_id}',6) then a.store_code end) as mtd_value, 
			count(distinct case when a.mth_id=from_timestamp(add_months(to_timestamp('{dt_id}','yyyyMMdd'),-1),'yyyyMM') then a.store_code end) as lmtd_value
		from rdm.retail_store_target as a 
		where a.kpi_target='revenue_all' 
		group by 1, 2
)
select  
	a.dt_id, 
	a.circle, 
	a.region_circle, 
	a.brand, 
	sum(a.mtd_value)/max(b.mtd_value) as mtd_value, 
	sum(a.lmtd_value)/max(b.lmtd_value ) as lmtd_value, 
	a.kpi_name, 
	a.mth_id
from cal_result_region as a 
left join cal_target as b 
	on a.region_circle = b.region_new 
group by 1, 2, 3, 4, 7, 8 
union all
select  
	a.dt_id, 
	a.circle, 
	a.region_circle, 
	a.brand, 
	sum(a.mtd_value) as mtd_value, 
	sum(a.lmtd_value) as lmtd_value, 
	'store_productivity_rev_count' kpi_name, 
	a.mth_id
from cal_result_region as a 
left join cal_target as b 
	on a.region_circle = b.region_new 
group by 1, 2, 3, 4, 7, 8 
union all 
select  
	a.dt_id, 
	a.circle, 
	a.region_circle, 
	a.brand, 
	max(b.mtd_value) as mtd_value, 
	max(b.lmtd_value ) as lmtd_value, 
	'store_productivity_rev_tgt' as kpi_name, 
	a.mth_id
from cal_result_region as a 
left join cal_target as b 
	on a.region_circle = b.region_new 
group by 1, 2, 3, 4, 7, 8
;   

-- 03. GADs IM3 Platinum
insert overwrite rdm.retail_champion_club 
partition (kpi_name, mth_id)
with ga as ( 
	select 
	'{dt_id}' as report_dt, 
	'GA' as kpi_name,
	c.circle, 
	c.region_circle,   
	count(distinct case when (strleft(a.activation_date,6)=strleft('{dt_id}',6) and a.activation_date<='{dt_id}') then a.msisdn else null end) mtd, 
	count(distinct case when (strleft(a.activation_date,6)=from_timestamp(add_months(to_timestamp('{dt_id}','yyyyMMdd'),-1),'yyyyMM') and a.activation_date<=from_timestamp(add_months(to_timestamp('{dt_id}','yyyyMMdd'),-1),'yyyyMMdd')) then a.msisdn else null end) lmtd
	from rdm.dump_daily_ga as a
	left join rdm.storelist as c 
				on upper(a.store_code_rev)=upper(c.store_code)
	where 1=1
	and ((strleft(a.activation_date,6)=strleft('{dt_id}',6) and a.activation_date<='{dt_id}') 
		or  (strleft(a.activation_date,6)=from_timestamp(add_months(to_timestamp('{dt_id}','yyyyMMdd'),-1),'yyyyMM') and a.activation_date<=from_timestamp(add_months(to_timestamp('{dt_id}','yyyyMMdd'),-1),'yyyyMMdd')))
	and a.order_type in ('New Registration','Migration')
	group by 1, 2, 3, 4 
) 
, tgt as(
	select 
		s.circle, 
		s.region_circle, 
		sum(case when FROM_UNIXTIME(UNIX_TIMESTAMP(a.dates, 'yyyy-MM-dd HH:mm'), 'yyyyMM')=strleft('{dt_id}',6) 
			then round(a.total_ga,0) end) as mtd_target,
		sum(case when FROM_UNIXTIME(UNIX_TIMESTAMP(a.dates, 'yyyy-MM-dd HH:mm'), 'yyyyMM')=from_timestamp(add_months(to_timestamp('{dt_id}','yyyyMMdd'),-1),'yyyyMM') 
			then round(a.total_ga,0) end) as lmtd_target
		from rdm.target_postpaid as a 
		left join rdm.storelist as s
			on a.store_code_rev=s.store_code
		group by 1, 2
)
select   
	'{dt_id}' as dt_id,
	tgt.circle, 
	tgt.region_circle, 
	'IM3' as brand, 
	ga.mtd/tgt.mtd_target as mtd_value, 
	ga.lmtd/tgt.lmtd_target as lmtd_value, 
	'ga_postpaid_ach' as kpi_name, 
	strleft('{dt_id}', 6) as mth_id
from ga 
left join tgt 
	on tgt.region_circle = ga.region_circle 
union all 
select   
	'{dt_id}' as dt_id,
	ga.circle, 
	ga.region_circle, 
	'IM3' as brand, 
	ga.mtd as mtd_value, 
	ga.lmtd as lmtd_value, 
	'ga_postpaid' as kpi_name, 
	strleft('{dt_id}', 6) as mth_id
from ga 
union all 
select   
	'{dt_id}' as dt_id,
	tgt.circle, 
	tgt.region_circle, 
	'IM3' as brand, 
	tgt.mtd_target as mtd_value, 
	tgt.lmtd_target as lmtd_value, 
	'ga_postpaid_tgt' as kpi_name, 
	strleft('{dt_id}', 6) as mth_id
from tgt
;  

-- 04. Store Revenue  
insert overwrite rdm.retail_champion_club 
partition (kpi_name, mth_id)
with mtd_sim as(
	select 
		-- x1.msisdn, 
		-- x1.organization_name, 
		x1.store_code, 
		-- x1.event_type_main, 
		-- x1.month_id, 
		-- 'mtd' as flag_rev,
		sum(t2.rev_30) rev_sim_replacement
	from (
		select t1.* from
		(
				select 
				a.*, 
				row_number() over(partition by msisdn order by month_id desc, store_code) idx 
		       	from (
			       	select distinct 
					    customer_msisdn msisdn, 
					    organization_name, 
					    organization_ref_code store_code, 
					    service_type event_type_main, 
					    from_timestamp(to_timestamp(transaction_date,'dd/MM/yyyy HH:mm:ss'),'yyyyMM') month_id
					from rdm.ipos_trans_details 
					where status = 'Success'
						and service_type in ('Prepaid SIM Replacement','Postpaid SIM Replacement','Postpaid Sim Replacement New','Postpaid SIM Replacement New')
						and from_timestamp(to_timestamp(transaction_date,'dd/MM/yyyy HH:mm:ss'),'yyyyMMdd')<='{dt_id}'
						and from_timestamp(to_timestamp(transaction_date,'dd/MM/yyyy HH:mm:ss'),'yyyyMM')>=from_timestamp(add_months(to_timestamp('{dt_id}','yyyyMMdd'),-2),'yyyyMM') 
		       	) a
		        where month_id in (from_timestamp(last_day(add_months(to_timestamp(CONCAT(strleft('{dt_id}',6),'01'),'yyyyMMdd'),-2)),'yyyyMM'),
		        	from_timestamp(last_day(add_months(to_timestamp(CONCAT(strleft('{dt_id}',6),'01'),'yyyyMMdd'),-1)),'yyyyMM'),
		        	from_timestamp(last_day(to_timestamp(CONCAT(strleft('{dt_id}',6), '01'), 'yyyyMMdd')), 'yyyyMM'))
		) t1
		where idx=1 
	) x1 
	inner join 
	(
		select 
			msisdn, 
			sum(rev_30) rev_30, 
			strleft(dt_id,6) rev_month
		from biadm.hg_rgs_all_nogovt_dly
		where dt_id='{dt_id}'
		group by 1,3
	) t2
	on x1.msisdn=t2.msisdn 
	group by 1 
)
,lmtd_sim as(
	select 
		-- x1.msisdn, 
		-- x1.organization_name, 
		x1.store_code, 
		-- x1.event_type_main, 
		-- x1.month_id, 
		-- 'lmtd' as flag_rev,
		sum(t2.rev_30) rev_sim_replacement
	from (
		select t1.* from
		(
				select 
				a.*, 
				row_number() over(partition by msisdn order by month_id desc, store_code) idx 
		       	from (
			       	select distinct 
					    customer_msisdn msisdn, 
					    organization_name, 
					    organization_ref_code store_code, 
					    service_type event_type_main, 
					    from_timestamp(to_timestamp(transaction_date,'dd/MM/yyyy HH:mm:ss'),'yyyyMM') month_id
					from rdm.ipos_trans_details 
					where status = 'Success'
						and service_type in ('Prepaid SIM Replacement','Postpaid SIM Replacement','Postpaid Sim Replacement New','Postpaid SIM Replacement New')
						and from_timestamp(to_timestamp(transaction_date,'dd/MM/yyyy HH:mm:ss'),'yyyyMMdd')<=from_timestamp(add_months(to_timestamp('{dt_id}','yyyyMMdd'),-1),'yyyyMMdd')
						and from_timestamp(to_timestamp(transaction_date,'dd/MM/yyyy HH:mm:ss'),'yyyyMM')>=from_timestamp(add_months(to_timestamp('{dt_id}','yyyyMMdd'),-3),'yyyyMM') 
		       	) a
		        where month_id in (from_timestamp(last_day(add_months(to_timestamp(CONCAT(strleft('{dt_id}',6),'01'),'yyyyMMdd'),-3)),'yyyyMM'),
		        	from_timestamp(last_day(add_months(to_timestamp(CONCAT(strleft('{dt_id}',6),'01'),'yyyyMMdd'),-2)),'yyyyMM'),
		        	from_timestamp(last_day(add_months(to_timestamp(CONCAT(strleft('{dt_id}',6),'01'),'yyyyMMdd'),-1)),'yyyyMM'))
		) t1
		where idx=1 
	) x1 
	inner join 
	(
		select 
			msisdn, 
			sum(rev_30) rev_30, 
			strleft(dt_id,6) rev_month
		from biadm.hg_rgs_all_nogovt_dly
		where dt_id=from_timestamp(add_months(to_timestamp('{dt_id}','yyyyMMdd'),-1),'yyyyMMdd')
		group by 1,3
	) t2
	on x1.msisdn=t2.msisdn 
	group by 1
) 
, mtd_cash as(
	SELECT
		FROM_UNIXTIME(UNIX_TIMESTAMP(transaction_date, 'dd/MM/yyyy HH:mm'), 'yyyyMM') as mth_id,
		organization_ref_code store_code,
		sum(CAST(service_amount_collected AS DOUBLE)) rev_cash_in
	FROM
		rdm.ipos_trans_details
	WHERE
		`status` = 'Success'
		AND FROM_UNIXTIME(UNIX_TIMESTAMP(transaction_date, 'dd/MM/yyyy HH:mm'), 'yyyyMM')=strleft('{dt_id}',6) 
		and FROM_UNIXTIME(UNIX_TIMESTAMP(transaction_date, 'dd/MM/yyyy HH:mm'), 'yyyyMM') <='{dt_id}'
	GROUP BY
		1, 2
)
, lmtd_cash as (
	SELECT
		FROM_UNIXTIME(UNIX_TIMESTAMP(transaction_date, 'dd/MM/yyyy HH:mm'), 'yyyyMM') as mth_id,
		organization_ref_code store_code,
		sum(CAST(service_amount_collected AS DOUBLE)) rev_cash_in
	FROM
		rdm.ipos_trans_details
	WHERE
		`status` = 'Success'
		AND FROM_UNIXTIME(UNIX_TIMESTAMP(transaction_date, 'dd/MM/yyyy HH:mm'), 'yyyyMM')=from_timestamp(add_months(to_timestamp('{dt_id}','yyyyMMdd'),-1),'yyyyMM') 
		AND FROM_UNIXTIME(UNIX_TIMESTAMP(transaction_date, 'dd/MM/yyyy HH:mm'), 'yyyyMMdd')<=from_timestamp(add_months(to_timestamp('{dt_id}','yyyyMMdd'),-1),'yyyyMMdd')
	GROUP BY
		1, 2
) 
, result_region as (
select 
	'{dt_id}' as dt_id, 
	store.circle, 
	store.region_circle, 
	'IM3' as brand,
	sum(coalesce(mtd_sim.rev_sim_replacement,0)+coalesce(mtd_cash.rev_cash_in,0)) as mtd_value, 
	sum(coalesce(lmtd_sim.rev_sim_replacement,0)+coalesce(lmtd_cash.rev_cash_in,0)) as lmtd_value, 
	'store_revenue_ach' as kpi_name, 
	strleft('{dt_id}', 6) as mth_id
from  rdm.storelist as store  
	left join mtd_sim
		on store.store_code=mtd_sim.store_code 
	left join mtd_cash
		on store.store_code=mtd_cash.store_code 
	left join lmtd_sim
		on store.store_code=lmtd_sim.store_code 
	left join lmtd_cash 
		on store.store_code=lmtd_cash.store_code
where 1=1 
and store.channel_group in ('FRANCHISE', 'OWN GERAI')	
and (store.closed_date is null or store.closed_date ='')
group by 1, 2, 3, 4, 7, 8  
)  
, cal_target as(
	select  
			a.circle, 
			a.region_new, 
			sum(case when a.mth_id=strleft('{dt_id}',6) then a.kpi_value end) as mtd_value, 
			sum(case when a.mth_id=from_timestamp(add_months(to_timestamp('{dt_id}','yyyyMMdd'),-1),'yyyyMM') then a.kpi_value end) as lmtd_value
		from rdm.retail_store_target as a 
		where a.kpi_target='revenue_all' 
		group by 1, 2
)
select  
	a.dt_id, 
	a.circle, 
	a.region_circle, 
	a.brand, 
	sum(a.mtd_value)/sum(b.mtd_value) as mtd_value, 
	sum(a.lmtd_value)/sum(b.lmtd_value ) as lmtd_value, 
	a.kpi_name, 
	a.mth_id
from result_region as a 
left join cal_target as b 
	on a.region_circle = b.region_new 
group by 1, 2, 3, 4, 7, 8 
union all
select  
	a.dt_id, 
	a.circle, 
	a.region_circle, 
	a.brand, 
	sum(a.mtd_value) as mtd_value, 
	sum(a.lmtd_value) as lmtd_value, 
	'store_revenue' as kpi_name, 
	a.mth_id
from result_region as a 
left join cal_target as b 
	on a.region_circle = b.region_new 
group by 1, 2, 3, 4, 7, 8 
union all 
select  
	a.dt_id, 
	a.circle, 
	a.region_circle, 
	a.brand, 
	sum(b.mtd_value) as mtd_value, 
	sum(b.lmtd_value ) as lmtd_value, 
	'store_revenue_tgt' as kpi_name, 
	a.mth_id
from result_region as a 
left join cal_target as b 
	on a.region_circle = b.region_new 
group by 1, 2, 3, 4, 7, 8 
; 

-- 05. Mystery Shopper
insert overwrite rdm.retail_champion_club 
partition (kpi_name, mth_id)
select
'{dt_id}' as dt_id, 
store.circle, 
store.region_circle, 
'IM3' as brand, 
sum(mtd) as mtd_value,
sum(lmtd) as lmtd_value, 
'myshopp_count' as kpi_name,
strleft('{dt_id}',6) as mth_id
from  rdm.storelist as store   
	left join (
		select 
		store_code, 
		sum(case when mth_id=from_timestamp(add_months(to_timestamp('{dt_id}','yyyyMMdd'),-1),'yyyyMM')
			and myshopp_score >= 90 then 1 else 0 end) as mtd, 
		sum(case when mth_id=from_timestamp(add_months(to_timestamp('{dt_id}','yyyyMMdd'),-2),'yyyyMM')
			and myshopp_score >= 90 then 1 else 0 end) as lmtd	
		from rdm.retail_myshopp  
		group by 1
	)as ms 
		on store.store_code = ms.store_code
where 1=1 
	and store.channel_group in ('FRANCHISE', 'OWN GERAI')	
	and (store.closed_date is null or store.closed_date ='')
group by 1, 2, 3, 4, 7, 8
union all 
select
'{dt_id}' as dt_id, 
store.circle, 
store.region_circle, 
'IM3' as brand, 
count(distinct store.store_code) as mtd_value,
count(distinct store.store_code) as lmtd_value, 
'myshopp_tgt' as kpi_name,
strleft('{dt_id}',6) as mth_id
from  rdm.storelist as store   
	left join (
		select 
		store_code, 
		sum(case when mth_id=from_timestamp(add_months(to_timestamp('{dt_id}','yyyyMMdd'),-1),'yyyyMM')
			and myshopp_score >= 90 then 1 else 0 end) as mtd, 
		sum(case when mth_id=from_timestamp(add_months(to_timestamp('{dt_id}','yyyyMMdd'),-2),'yyyyMM')
			and myshopp_score >= 90 then 1 else 0 end) as lmtd	
		from rdm.retail_myshopp  
		group by 1
	)as ms 
		on store.store_code = ms.store_code
where 1=1 
	and store.channel_group in ('FRANCHISE', 'OWN GERAI')	
	and (store.closed_date is null or store.closed_date ='')
group by 1, 2, 3, 4, 7, 8
union all 
select
'{dt_id}' as dt_id, 
store.circle, 
store.region_circle, 
'IM3' as brand, 
sum(mtd)/count(distinct store.store_code) as mtd_value,
sum(lmtd)/count(distinct store.store_code) as lmtd_value, 
'myshopp_ach' as kpi_name,
strleft('{dt_id}',6) as mth_id
from  rdm.storelist as store   
	left join (
		select 
		store_code, 
		sum(case when mth_id=from_timestamp(add_months(to_timestamp('{dt_id}','yyyyMMdd'),-1),'yyyyMM')
			and myshopp_score >= 90 then 1 else 0 end) as mtd, 
		sum(case when mth_id=from_timestamp(add_months(to_timestamp('{dt_id}','yyyyMMdd'),-2),'yyyyMM')
			and myshopp_score >= 90 then 1 else 0 end) as lmtd	
		from rdm.retail_myshopp  
		group by 1
	)as ms 
		on store.store_code = ms.store_code
where 1=1 
	and store.channel_group in ('FRANCHISE', 'OWN GERAI')	
	and (store.closed_date is null or store.closed_date ='')
group by 1, 2, 3, 4, 7, 8;   

-- 06. CSAT GERAI IM3 
insert overwrite rdm.retail_champion_club 
partition (kpi_name, mth_id)
with csat_score as(
	select  
		circle, 
		region,  
		mth_id,  
		store_code, 
		channel, 
		sum(delivered) as delivered, 
		sum(respond) as respond, 
		sum(happy) as happy,
		sum(happy)/sum(respond) as csat, 
		sum(respond)/sum(delivered) as respond_rate
	from rdm.retail_csat_im3 
	where ((mth_id=strleft('{dt_id}',6) and dt_id<='{dt_id}') or 
			(mth_id=from_timestamp(add_months(to_timestamp('{dt_id}','yyyyMMdd'),-1),'yyyyMM') and dt_id<=from_timestamp(add_months(to_timestamp('{dt_id}','yyyyMMdd'),-1),'yyyyMMdd')))
	and lower(channel) like 'gerai%'
	group by 1, 2, 3, 4, 5
)
, csat_cal as(
	select  
		'{dt_id}' as dt_id,
		a.circle, 
		a.region as region_circle, 
		'IM3' as brand,
		sum(case when (csat>=0.99 and respond_rate>=0.1) and mth_id=strleft('{dt_id}',6) then 1 else 0 end) as mtd_value, 
		sum(case when (csat>=0.99 and respond_rate>=0.1) and mth_id=from_timestamp(add_months(to_timestamp('{dt_id}','yyyyMMdd'),-1),'yyyyMM') then 1 else 0 end) as lmtd_value, 
		'csat_gerai_cnt' as kpi_name, 
		strleft('{dt_id}',6) as mth_id
	from csat_score as a
	group by 1, 2, 3, 4, 7, 8
)
, store_cal as(
	select  
	'{dt_id}' as dt_id, 
	s.circle, 
	s.region_circle, 
	'IM3' as brand, 
	count(distinct s.store_code) as mtd_value,
	count(distinct s.store_code) as lmtd_value, 
	'csat_gerai_tgt' as kpi_name,
	strleft('{dt_id}',6) as mth_id
	from rdm.storelist s  
	where 1=1 
		and s.channel_group in ('FRANCHISE', 'OWN GERAI')	
		and (s.closed_date is null or s.closed_date ='') 
	group by 1, 2, 3, 4, 7, 8 
)
select  
	'{dt_id}' as dt_id,
	s.circle, 
	s.region_circle, 
	'IM3' as brand,
	a.mtd_value/s.mtd_value as mtd_value, 
	a.lmtd_value/s.lmtd_value as lmtd_value, 
	'csat_gerai_ach' as kpi_name, 
	strleft('{dt_id}',6) as mth_id
from store_cal as s  
	left join csat_cal as a
	on a.region_circle=s.region_circle 
union all 
select 
* 
from csat_cal 
union all 
select 
*
from store_cal
;   

-- 07. CSAT SDP IM3 
insert overwrite rdm.retail_champion_club 
partition (kpi_name, mth_id)
with csat_score as(
	select  
		circle, 
		region,  
		mth_id,  
		store_code, 
		channel, 
		sum(delivered) as delivered, 
		sum(respond) as respond, 
		sum(happy) as happy,
		sum(happy)/sum(respond) as csat, 
		sum(respond)/sum(delivered) as respond_rate
	from rdm.retail_csat_im3 
	where ((mth_id=strleft('{dt_id}',6) and dt_id<='{dt_id}') or 
			(mth_id=from_timestamp(add_months(to_timestamp('{dt_id}','yyyyMMdd'),-1),'yyyyMM') and dt_id<=from_timestamp(add_months(to_timestamp('{dt_id}','yyyyMMdd'),-1),'yyyyMMdd')))
	and lower(channel) not like 'gerai%'
	group by 1, 2, 3, 4, 5
)
, csat_cal as(
	select  
		'{dt_id}' as dt_id,
		a.circle, 
		a.region as region_circle, 
		'IM3' as brand,
		sum(case when (csat>=0.98 and respond_rate>=0.1) and mth_id=strleft('{dt_id}',6) then 1 else 0 end) as mtd_value, 
		sum(case when (csat>=0.98 and respond_rate>=0.1) and mth_id=from_timestamp(add_months(to_timestamp('{dt_id}','yyyyMMdd'),-1),'yyyyMM') then 1 else 0 end) as lmtd_value, 
		'csat_sdp_cnt' as kpi_name, 
		strleft('{dt_id}',6) as mth_id
	from csat_score as a
	group by 1, 2, 3, 4, 7, 8
)
, store_cal as(
	select  
	'{dt_id}' as dt_id, 
	s.circle, 
	s.region as region_circle, 
	'IM3' as brand, 
	count(distinct s.sdp_code) as mtd_value,
	count(distinct s.sdp_code) as lmtd_value, 
	'csat_sdp_tgt' as kpi_name,
	strleft('{dt_id}',6) as mth_id
	from rdm.rtl_sce_sdp s  
	where 1=1 
		and s.status='Live Service'
	group by 1, 2, 3, 4, 7, 8 
)
select  
	'{dt_id}' as dt_id,
	s.circle, 
	s.region_circle, 
	'IM3' as brand,
	a.mtd_value/s.mtd_value as mtd_value, 
	a.lmtd_value/s.lmtd_value as lmtd_value, 
	'csat_sdp_ach' as kpi_name, 
	strleft('{dt_id}',6) as mth_id
from store_cal as s  
	left join csat_cal as a
	on a.region_circle=s.region_circle 
union all 
select 
* 
from csat_cal 
union all 
select 
*
from store_cal
;

select * from rdm.retail_champion_club where mth_id=strleft('{dt_id}',6);