drop table if exists cockpit.tmp_kpi_ga; 

create table cockpit.tmp_kpi_ga as
SELECT 
		DATE_FORMAT(buv.salesdate, "%Y%m%d") AS dt_id
		, 'POSS' AS buv_source
		, case when ma.nik is not null then upper(ma.nik)
	    	when left(upper(buv.AgentName),4)='MBPS' and UPPER(CONCAT('MBPS-', SUBSTRING(TRIM(REPLACE(REPLACE(buv.AgentName, '-', ''), '_', '')), 5))) is not null then UPPER(CONCAT('MBPS-', SUBSTRING(TRIM(REPLACE(REPLACE(buv.AgentName, '-', ''), '_', '')), 5)))
	    	when left(upper(buv.AgentName),4)='MPBS' and UPPER(CONCAT('MBPS-', SUBSTRING(TRIM(REPLACE(REPLACE(buv.AgentName, '-', ''), '_', '')), 5))) is not null then UPPER(CONCAT('MBPS-', SUBSTRING(TRIM(REPLACE(REPLACE(buv.AgentName, '-', ''), '_', '')), 5)))
	    	else upper(buv.AgentName) end as agent_id
		-- , AgentName AS agent_id
		, buv.DealerCode AS store_code
		, buv.ProductName AS product_name
		, SUM(buv.Quantity) AS ga
	FROM cockpit.raw_poss buv 
	left join cockpit.mapping_agent_nik as ma
			on case when left(upper(buv.AgentName),4)='MPBS' then UPPER(CONCAT('MBPS', SUBSTRING(TRIM(REPLACE(REPLACE(buv.AgentName, '-', ''), '_', '')), 5)))
        else upper(TRIM(REPLACE(REPLACE(buv.AgentName, '-', ''), '_', ''))) end = upper(ma.idx)
	WHERE (lower(buv.ProductName) like 'sp %'
            or lower(buv.ProductName) like 'perdana %'
            or lower(buv.ProductName) like 'elite%')
            and buv.ItemCode not like 'SP-PR%'
            and buv.ItemCode not like 'SP-RPLC%'
    	AND DATE_FORMAT(buv.SalesDate, '%Y%m') = left('{dt_id}',6) 
    	and DATE_FORMAT(buv.SalesDate, '%Y%m%d')<='{dt_id}'
	GROUP BY 1,2,3,4,5
UNION ALL
	SELECT 
	date_format(substring(T1.date_trx,1,10),'%Y%m%d') as dt_id
	, case 
		when T2.dvm_code is not null then 'dvm_store'
		else 'dvm_standalone'
	  end  buv_source 
	, trim(T2.dvm_code) AS agent_id
	, coalesce(T2.store_code, trim(T1.terminal_code)) as store_code
	, T1.product_name as product_name
	, count(customerid) as ga
	FROM cockpit_archieve.raw_3db_trx T1
		left join cockpit.dvm_mapping T2
			on trim(T1.terminal_code)=trim(T2.dvm_code)
	Where result = 'success'
		and product_code NOT IN ('THREE_CHANGE_CARD','THREE_REGPRABAYAR','THREE_SIMCARD4G', 'THREE_CHANGE_CARD_O2O', 'Upgrade 4G O2O', 'VALIDITY_KTP')
	    and DATE_FORMAT(T1.date_trx, "%Y%m") = left('{dt_id}',6) 
	    and  DATE_FORMAT(T1.date_trx, "%Y%m%d")<='{dt_id}'
	    and lower(product_code) like '%perdana%'
	GROUP BY 1,2,3,4,5; 

-- mtd
select
	'{dt_id}' as dt_id,
	'ga_prepaid' as kpi_name,
	'agent' as level, 
	agent_id, 
	store_code, 
	'3ID' as brand, 
	sum(ga) as value
from cockpit.tmp_kpi_ga
	where buv_source not in ('dvm_store', 'dvm_standalone')
		and left(dt_id,6)=left('{dt_id}',6)
		and dt_id<='{dt_id}'
group by 1, 2, 3, 4, 5, 6
union all
select
	'{dt_id}' as dt_id,
	'ga_prepaid' as kpi_name,
	'store' as level, 
	null as agent_id, 
	store_code, 
	'3ID' as brand, 
	sum(ga) as value
from cockpit.tmp_kpi_ga
	where buv_source not in ('dvm_store', 'dvm_standalone')
		and left(dt_id,6)=left('{dt_id}',6)
		and dt_id<='{dt_id}'
group by 1, 2, 3, 4, 5, 6
union all
select
	'{dt_id}' as dt_id,
	'ga_prepaid_dvm' as kpi_name,
	buv_source as level, 
	agent_id, 
	store_code, 
	'3ID' as brand, 
	sum(ga) as value
from cockpit.tmp_kpi_ga
	where buv_source in ('dvm_store', 'dvm_standalone')
		and left(dt_id,6)=left('{dt_id}',6)
		and dt_id<='{dt_id}'
group by 1, 2, 3, 4, 5, 6;

-- daily data
select
	dt_id,
	'ga_prepaid' as kpi_name,
	'agent' as level, 
	agent_id, 
	store_code, 
	'3ID' as brand, 
	sum(ga) as value
from cockpit.tmp_kpi_ga
	where buv_source not in ('dvm_store', 'dvm_standalone')
		and left(dt_id,6)=left('{dt_id}',6)
		and dt_id<='{dt_id}'
group by 1, 2, 3, 4, 5, 6
union all
select
	dt_id,
	'ga_prepaid' as kpi_name,
	'store' as level, 
	null as agent_id, 
	store_code, 
	'3ID' as brand, 
	sum(ga) as value
from cockpit.tmp_kpi_ga
	where buv_source not in ('dvm_store', 'dvm_standalone')
		and left(dt_id,6)=left('{dt_id}',6)
		and dt_id<='{dt_id}'
group by 1, 2, 3, 4, 5, 6
union all
select
	dt_id,
	'ga_prepaid_dvm' as kpi_name,
	buv_source as level, 
	agent_id, 
	store_code, 
	'3ID' as brand, 
	sum(ga) as value
from cockpit.tmp_kpi_ga
	where buv_source in ('dvm_store', 'dvm_standalone')
		and left(dt_id,6)=left('{dt_id}',6)
		and dt_id<='{dt_id}'
group by 1, 2, 3, 4, 5, 6;