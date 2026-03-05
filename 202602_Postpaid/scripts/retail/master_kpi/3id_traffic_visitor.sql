-- Traffic
drop table if exists cockpit.tmp_kpi_visitor;

create table cockpit.tmp_kpi_visitor as
select 
	a.dt_id, 
	a.agent_id,
	a.store_code,
	sum(a.visitor) as visitor
from (
select
    DATE_FORMAT(qms.DateTimeCustQue, '%Y%m%d') as dt_id,
    case when ma.nik is not null then upper(ma.nik)
    	when left(upper(qms.AgentName),4)='MBPS' then UPPER(CONCAT('MBPS-', SUBSTRING(TRIM(REPLACE(REPLACE(qms.AgentName, '-', ''), '_', '')), 5)))
    	when left(upper(qms.AgentName),4)='MPBS' then UPPER(CONCAT('MBPS-', SUBSTRING(TRIM(REPLACE(REPLACE(qms.AgentName, '-', ''), '_', '')), 5)))
    	else upper(qms.AgentName) end as agent_id,
    ma.store_code as store_code, 
    count(distinct Msisdn) as visitor
FROM cockpit.raw_qms_detil as qms
    left join cockpit.mapping_agent_nik ma
        on  case when left(upper(qms.AgentName),4)='MPBS' then UPPER(CONCAT('MBPS', SUBSTRING(TRIM(REPLACE(REPLACE(qms.AgentName, '-', ''), '_', '')), 5)))
        else upper(TRIM(REPLACE(REPLACE(qms.AgentName, '-', ''), '_', ''))) end = upper(ma.idx)
    WHERE DATE_FORMAT(qms.DateTimeCustQue, '%Y%m') = left('{dt_id}',6)
    	and DATE_FORMAT(qms.DateTimeCustQue, '%Y%m%d') <= '{dt_id}'
    	-- and ma.store_code is null
group by 1, 2, 3 
union all 
select 
	x.dt_id, 
	case when ma.nik is not null then upper(ma.nik)
    	when left(upper(x.agent_id),4)='MBPS' then UPPER(CONCAT('MBPS-', SUBSTRING(TRIM(REPLACE(REPLACE(x.agent_id, '-', ''), '_', '')), 5)))
    	when left(upper(x.agent_id),4)='MPBS' then UPPER(CONCAT('MBPS-', SUBSTRING(TRIM(REPLACE(REPLACE(x.agent_id, '-', ''), '_', '')), 5)))
    	else upper(x.agent_id) end as agent_id,
	-- agent_id, 
	coalesce(x.dealercode, ma.store_code) as store_code, 
	count(distinct user_contact) visitor 
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
group by 1, 2, 3
) as a
group by 1, 2, 3;


drop table if exists cockpit.tmp_kpi_visitor_all;

create table cockpit.tmp_kpi_visitor_all as
select 
	a.dt_id,
	a.agent_id,
	a.store_code,
	a.visitor
from cockpit.tmp_kpi_visitor as a
union all
select 
	x.dt_id, 
	x.agent_id,
	x.store_code,
	x.visitor
from (
select
        DATE_FORMAT(buv.salesdate, "%Y%m%d") AS dt_id,
        case when ma.nik is not null then upper(ma.nik)
	    	when left(upper(buv.AgentName),4)='MBPS' then UPPER(CONCAT('MBPS-', SUBSTRING(TRIM(REPLACE(REPLACE(buv.AgentName, '-', ''), '_', '')), 5)))
	    	when left(upper(buv.AgentName),4)='MPBS' then UPPER(CONCAT('MBPS-', SUBSTRING(TRIM(REPLACE(REPLACE(buv.AgentName, '-', ''), '_', '')), 5)))
	    	else upper(buv.AgentName) end as agent_id,
        buv.DealerCode AS store_code,
        count(distinct InvoiceNumber) AS visitor
    from cockpit.raw_poss buv
    left join cockpit.mapping_agent_nik ma
		on  case when left(upper(buv.AgentName),4)='MPBS' then UPPER(CONCAT('MBPS', SUBSTRING(TRIM(REPLACE(REPLACE(buv.AgentName, '-', ''), '_', '')), 5)))
        else upper(TRIM(REPLACE(REPLACE(buv.AgentName, '-', ''), '_', ''))) end = upper(ma.idx)
    where 1=1
        and DATE_FORMAT(buv.SalesDate, '%Y%m') = left('{dt_id}',6)
        and DATE_FORMAT(buv.SalesDate, '%Y%m%d') <= '{dt_id}'
    group by 1, 2, 3
) as x 
	left join cockpit.tmp_kpi_visitor as y
		on x.dt_id = y.dt_id and x.agent_id = y.agent_id and x.store_code=y.store_code
where y.agent_id is null
 ;

-- mtd
select
	'{dt_id}' as dt_id,
	'traffic_visitor' as kpi_name,
	'agent' as level, 
	agent_id, 
	store_code, 
	'3ID' as brand, 
	sum(visitor) as value
from cockpit.tmp_kpi_visitor_all
	where 1=1
		and left(dt_id,6)=left('{dt_id}',6)
		and dt_id<='{dt_id}'
group by 1, 2, 3, 4, 5, 6
union all
select
	'{dt_id}' as dt_id,
	'traffic_visitor' as kpi_name,
	'store' as level, 
	null as agent_id, 
	store_code, 
	'3ID' as brand, 
	sum(visitor) as value
from cockpit.tmp_kpi_visitor_all
	where 1=1
		and left(dt_id,6)=left('{dt_id}',6)
		and dt_id<='{dt_id}'
group by 1, 2, 3, 4, 5, 6;

-- daily data
select
	dt_id,
	'traffic_visitor' as kpi_name,
	'agent' as level, 
	agent_id, 
	store_code, 
	'3ID' as brand, 
	sum(visitor) as value
from cockpit.tmp_kpi_visitor_all
	where 1=1
		and left(dt_id,6)=left('{dt_id}',6)
		and dt_id<='{dt_id}'
group by 1, 2, 3, 4, 5, 6
union all
select
	dt_id,
	'traffic_visitor' as kpi_name,
	'store' as level, 
	null as agent_id, 
	store_code, 
	'3ID' as brand, 
	sum(visitor) as value
from cockpit.tmp_kpi_visitor_all
	where 1=1
		and left(dt_id,6)=left('{dt_id}',6)
		and dt_id<='{dt_id}'
group by 1, 2, 3, 4, 5, 6;
 