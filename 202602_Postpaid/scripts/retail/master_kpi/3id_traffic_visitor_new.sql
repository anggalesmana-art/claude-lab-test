select
    DATE_FORMAT(qms.DateTimeCustQue, '%Y%m%d') as dt_id,
    'QMS' as source_data,
    case when ma.nik is not null then upper(ma.nik)
    	when left(upper(qms.AgentName),4)='MBPS' then UPPER(CONCAT('MBPS-', SUBSTRING(TRIM(REPLACE(REPLACE(qms.AgentName, '-', ''), '_', '')), 5)))
    	when left(upper(qms.AgentName),4)='MPBS' then UPPER(CONCAT('MBPS-', SUBSTRING(TRIM(REPLACE(REPLACE(qms.AgentName, '-', ''), '_', '')), 5)))
    	else upper(qms.AgentName) end as agent_id,
    ma.store_code as store_code, 
    Msisdn as visitor
FROM cockpit.raw_qms_detil as qms
    left join cockpit.mapping_agent_nik ma
        on  case when left(upper(qms.AgentName),4)='MPBS' then UPPER(CONCAT('MBPS', SUBSTRING(TRIM(REPLACE(REPLACE(qms.AgentName, '-', ''), '_', '')), 5)))
        else upper(TRIM(REPLACE(REPLACE(qms.AgentName, '-', ''), '_', ''))) end = upper(ma.idx)
    WHERE DATE_FORMAT(qms.DateTimeCustQue, '%Y%m') = left('{dt_id}',6)
    	and DATE_FORMAT(qms.DateTimeCustQue, '%Y%m%d') <= '{dt_id}'
    	-- and ma.store_code is null
group by 1, 2, 3, 4, 5 
union all 
select 
	x.dt_id, 
	'CSTOOLS' as source_data,
	case when ma.nik is not null then upper(ma.nik)
    	when left(upper(x.agent_id),4)='MBPS' then UPPER(CONCAT('MBPS-', SUBSTRING(TRIM(REPLACE(REPLACE(x.agent_id, '-', ''), '_', '')), 5)))
    	when left(upper(x.agent_id),4)='MPBS' then UPPER(CONCAT('MBPS-', SUBSTRING(TRIM(REPLACE(REPLACE(x.agent_id, '-', ''), '_', '')), 5)))
    	else upper(x.agent_id) end as agent_id,
	-- agent_id, 
	coalesce(x.dealercode, ma.store_code) as store_code, 
	user_contact as visitor 
	from(
	        select 
	            distinct
	            DATE_FORMAT(a.opened_time, '%Y%m') as mth_id
	            , DATE_FORMAT(a.opened_time, '%Y%m%d') as dt_id
	            , a.opened_by as agent_id
	            , ma.dealercode
	            , a.user_contact
	        from cockpit_archieve.cstools_raw_tickets as a
	            left join cockpit.master_agent ma
	                on a.opened_by = ma.siebel_id
	            left join (
	                select
	                    distinct
	                    DATE_FORMAT(qms.DateTimeCustQue, '%Y%m') as mth_id,
	                    DATE_FORMAT(qms.DateTimeCustQue, '%Y%m%d') as dt_id,
	                    qms.AgentName as agent_id,
	                    ma.dealercode,
	                    qms.Msisdn as visitor
	                FROM cockpit.raw_qms_detil as qms
	                left join cockpit.master_agent ma
	                    on qms.AgentName = ma.siebel_id
	                    WHERE DATE_FORMAT(qms.DateTimeCustQue, '%Y%m') = left('{dt_id}',6)
    							and DATE_FORMAT(qms.DateTimeCustQue, '%Y%m%d') <= '{dt_id}'
	                ) as b
	            on a.user_contact=b.visitor and DATE_FORMAT(a.opened_time, '%Y%m%d')=b.dt_id
	        where DATE_FORMAT(a.opened_time, '%Y%m')= left('{dt_id}',6)
		        and DATE_FORMAT(a.opened_time, '%Y%m%d') <= '{dt_id}'
		        and a.source in ('3Store')
		        and b.visitor is null
) x
	left join cockpit.mapping_agent_nik ma
		on  case when left(upper(x.agent_id),4)='MPBS' then UPPER(CONCAT('MBPS', SUBSTRING(TRIM(REPLACE(REPLACE(x.agent_id, '-', ''), '_', '')), 5)))
        else upper(TRIM(REPLACE(REPLACE(x.agent_id, '-', ''), '_', ''))) end = upper(ma.idx)
group by 1, 2, 3, 4, 5
;

-- mtd KPI 
with trf_visitor as 
(
	select
		'{dt_id}' as dt_id,
		'traffic_visitor' as kpi_name,
		'agent' as level, 
		case when left(agent_id,5)='MBPS-' then upper(agent_id)
		else coalesce(upper(agent_nik_rev), upper(agent_id)) end as agent_id, 
		store_code,
		brand, 
		'qmatic' as source,
		sum(visitor) as visitor
	from `data-nationalslsdist-prd-986g`.retail.raw_qmatic_visitor
		where format_date('%Y%m', dt_id)=left('{dt_id}',6)
			and format_date('%Y%m%d', dt_id)<='{dt_id}'
			and brand='3ID'
	group by 1, 2, 3, 4, 5, 6, 7
	union all 
	select
		'{dt_id}' as dt_id,
		'traffic_visitor' as kpi_name,
		'agent' as level, 
		a.agent_id, 
		a.store_code,
		'3ID' as brand, 
		'qms' as source,
		count(distinct a.visitor) as value
	from `data-nationalslsdist-prd-986g`.retail.raw_qms_visitor as a
		left join ( 
				select 
					distinct store_code
					-- ,coalesce(upper(agent_nik_rev), upper(agent_id)) as agent_id
				from `data-nationalslsdist-prd-986g`.retail.raw_qmatic_visitor
				where format_date('%Y%m', dt_id)=left('{dt_id}',6)
					and format_date('%Y%m%d', dt_id)<='{dt_id}'
					and brand='3ID' 
		
		) as b 
		on a.store_code = b.store_code -- and a.agent_id=b.agent_id
		where left(a.dt_id,6)=left('{dt_id}',6)
			and a.dt_id<='{dt_id}' 
			and b.store_code is null
			-- and b.agent_id is null
	group by 1, 2, 3, 4, 5, 6, 7
)
select
	'{dt_id}' as dt_id,
	'traffic_qmatic' as kpi_name,
	'agent' as level, 
	case when left(agent_id,5)='MBPS-' then upper(agent_id)
		else coalesce(upper(agent_nik_rev), upper(agent_id)) end as agent_id, 
	store_code,
    brand, 
	sum(visitor) as value
from `data-nationalslsdist-prd-986g`.retail.raw_qmatic_visitor
	where format_date('%Y%m', dt_id)=left('{dt_id}',6)
		and format_date('%Y%m%d', dt_id)<='{dt_id}'
		and brand='3ID'
group by 1, 2, 3, 4, 5, 6
union all 
select
	'{dt_id}' as dt_id,
	'traffic_qms' as kpi_name,
	'agent' as level, 
	a.agent_id, 
	a.store_code,
    '3ID' as brand, 
	count(distinct a.visitor) as value
from `data-nationalslsdist-prd-986g`.retail.raw_qms_visitor as a
	where left(a.dt_id,6)=left('{dt_id}',6)
		and a.dt_id<='{dt_id}' 
group by 1, 2, 3, 4, 5, 6 
union all
select
	'{dt_id}' as dt_id,
	'traffic_visitor' as kpi_name,
	'agent' as level, 
	agent_id, 
	store_code,
    brand, 
	sum(visitor) as value
from trf_visitor
group by 1, 2, 3, 4, 5, 6
union all 
select
	'{dt_id}' as dt_id,
	'traffic_qmatic' as kpi_name,
	'store' as level, 
	cast(null as string) as agent_id, 
	-- coalesce(store_code_rev, store_code) as store_code, 
	store_code,
    brand, 
	sum(visitor) as value
from `data-nationalslsdist-prd-986g`.retail.raw_qmatic_visitor
	where format_date('%Y%m', dt_id)=left('{dt_id}',6)
		and format_date('%Y%m%d', dt_id)<='{dt_id}'
		and brand='3ID'
group by 1, 2, 3, 4, 5, 6
union all 
select
	'{dt_id}' as dt_id,
	'traffic_qms' as kpi_name,
	'store' as level, 
	cast(null as string) as agent_id, 
	a.store_code,
    '3ID' as brand, 
	count(distinct a.visitor) as value
from `data-nationalslsdist-prd-986g`.retail.raw_qms_visitor as a
	where left(a.dt_id,6)=left('{dt_id}',6)
		and a.dt_id<='{dt_id}' 
group by 1, 2, 3, 4, 5, 6
union all 
select
	'{dt_id}' as dt_id,
	'traffic_visitor' as kpi_name,
	'store' as level, 
	cast(null as string) as agent_id, 
	store_code,
    brand, 
	sum(visitor) as value
from trf_visitor
group by 1, 2, 3, 4, 5, 6
;