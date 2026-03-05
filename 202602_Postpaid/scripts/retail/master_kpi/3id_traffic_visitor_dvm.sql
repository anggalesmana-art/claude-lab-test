-- mtd
select
	'{dt_id}' as dt_id,
	'traffic_visitor_dvm' as kpi_name,
	buv_source as level, 
	agent_id, 
	store_code, 
	'3ID' as brand, 
	sum(visitor) as value
from (
		select
		    DATE_FORMAT(T1.date_trx, "%Y%m%d") as dt_id, 
		    case 
				when T2.dvm_code is not null then 'dvm_store'
				else 'dvm_standalone'
			  	end  buv_source, 
		    trim(T2.dvm_code) AS agent_id,
			coalesce(T2.store_code, trim(T1.terminal_code)) as store_code,
		    count(distinct T1.customerid) as visitor
		FROM cockpit_archieve.raw_3db_trx T1
			left join cockpit.dvm_mapping T2
					on trim(T1.terminal_code)=trim(T2.dvm_code)
		where 1=1 
			and T1.result = 'success'
			and DATE_FORMAT(T1.date_trx, "%Y%m%d") <= '{dt_id}'
			and DATE_FORMAT(T1.date_trx, "%Y%m")=left('{dt_id}',6)
		group by 1, 2, 3, 4
) as a
	where buv_source in ('dvm_store', 'dvm_standalone')
		and left(dt_id,6)=left('{dt_id}',6)
		and dt_id<='{dt_id}'
group by 1, 2, 3, 4, 5, 6;

-- daily
select
	dt_id,
	'traffic_visitor_dvm' as kpi_name,
	buv_source as level, 
	agent_id, 
	store_code, 
	'3ID' as brand, 
	sum(visitor) as value
from (
		select
		    DATE_FORMAT(T1.date_trx, "%Y%m%d") as dt_id, 
		    case 
				when T2.dvm_code is not null then 'dvm_store'
				else 'dvm_standalone'
			  	end  buv_source, 
		    trim(T2.dvm_code) AS agent_id,
			coalesce(T2.store_code, trim(T1.terminal_code)) as store_code,
		    count(distinct T1.customerid) as visitor
		FROM cockpit_archieve.raw_3db_trx T1
			left join cockpit.dvm_mapping T2
					on trim(T1.terminal_code)=trim(T2.dvm_code)
		where 1=1 
			and T1.result = 'success'
			and DATE_FORMAT(T1.date_trx, "%Y%m%d") <= '{dt_id}'
			and DATE_FORMAT(T1.date_trx, "%Y%m")=left('{dt_id}',6)
		group by 1, 2, 3, 4
) as a
	where buv_source in ('dvm_store', 'dvm_standalone')
		and left(dt_id,6)=left('{dt_id}',6)
		and dt_id<='{dt_id}'
group by 1, 2, 3, 4, 5, 6;