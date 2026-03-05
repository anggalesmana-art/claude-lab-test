-- Revenue (union 3 table)
drop table if exists cockpit.tmp_kpi_revenue_cash_in;

create table cockpit.tmp_kpi_revenue_cash_in as
SELECT 
		DATE_FORMAT(buv.salesdate, "%Y%m%d") AS dt_id
		, 'POSS' AS buv_source
		, AgentName AS agent_id
		, buv.DealerCode AS store_code
		, buv.ProductName AS product_name
		, SUM(COALESCE(buv.TotalAmount, 0)) AS rev_total
	FROM cockpit.raw_poss buv 
	WHERE buv.TotalAmount > 0
		AND buv.ProductName not like 'SP-PR%' 
    	AND DATE_FORMAT(buv.SalesDate, '%Y%m') = left('{dt_id}',6) 
    	and DATE_FORMAT(buv.SalesDate, '%Y%m%d')<='{dt_id}'
	GROUP BY 1,2,3,4,5
UNION ALL
	SELECT 
		DATE_FORMAT(buv.document_date, "%Y%m%d") AS dt_id
		, 'POSTPAID PAYMENT' AS buv_source
		-- , agent_id AS agent_id 
        , created_by AS agent_id
		, dealercode AS store_code
		, 'Postpaid' AS product_name
		, SUM(COALESCE(buv.amount, 0)) AS rev_total
	FROM cockpit.raw_post_payment buv
	WHERE buv.amount > 0
    	AND DATE_FORMAT(buv.document_date, '%Y%m') = left('{dt_id}',6) 
    	and DATE_FORMAT(buv.document_date, '%Y%m%d')<='{dt_id}'
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
	, sum(payment_value) as rev_total
	FROM cockpit_archieve.raw_3db_trx T1
		left join cockpit.dvm_mapping T2
			on trim(T1.terminal_code)=trim(T2.dvm_code)
	Where result = 'success'
		and product_code NOT IN ('THREE_CHANGE_CARD','THREE_REGPRABAYAR','THREE_SIMCARD4G', 'THREE_CHANGE_CARD_O2O', 'Upgrade 4G O2O', 'VALIDITY_KTP')
	    and DATE_FORMAT(T1.date_trx, "%Y%m") = left('{dt_id}',6) 
	    and  DATE_FORMAT(T1.date_trx, "%Y%m%d")<='{dt_id}'
	GROUP BY 1,2,3,4,5; 

-- mtd value
select
	'{dt_id}' as dt_id,
	'rev_cash_in' as kpi_name,
	'agent' as level, 
	agent_id, 
	store_code, 
	'3ID' as brand, 
	sum(rev_total) as value
from cockpit.tmp_kpi_revenue_cash_in
	where buv_source not in ('dvm_store', 'dvm_standalone')
		and left(dt_id,6)=left('{dt_id}',6)
		and dt_id<='{dt_id}'
group by 1, 2, 3, 4, 5, 6
union all
select
	'{dt_id}' as dt_id,
	'rev_cash_in' as kpi_name,
	'store' as level, 
	null as agent_id, 
	store_code, 
	'3ID' as brand, 
	sum(rev_total) as value
from cockpit.tmp_kpi_revenue_cash_in
	where buv_source not in ('dvm_store', 'dvm_standalone')
		and left(dt_id,6)=left('{dt_id}',6)
		and dt_id<='{dt_id}'
group by 1, 2, 3, 4, 5, 6
union all
select
	'{dt_id}' as dt_id,
	'rev_cash_in' as kpi_name,
	buv_source as level, 
	agent_id, 
	store_code, 
	'3ID' as brand, 
	sum(rev_total) as value
from cockpit.tmp_kpi_revenue_cash_in
	where buv_source in ('dvm_store', 'dvm_standalone')
		and left(dt_id,6)=left('{dt_id}',6)
		and dt_id<='{dt_id}'
group by 1, 2, 3, 4, 5, 6
union all
select
	'{dt_id}' as dt_id,
	'rev_cash_in_poss' as kpi_name,
	'agent' as level, 
	agent_id, 
	store_code, 
	'3ID' as brand, 
	sum(rev_total) as value
from cockpit.tmp_kpi_revenue_cash_in
	where buv_source='POSS'
		and left(dt_id,6)=left('{dt_id}',6)
		and dt_id<='{dt_id}'
group by 1, 2, 3, 4, 5, 6
union all
select
	'{dt_id}' as dt_id,
	'rev_cash_in_poss' as kpi_name,
	'store' as level, 
	null agent_id, 
	store_code, 
	'3ID' as brand, 
	sum(rev_total) as value
from cockpit.tmp_kpi_revenue_cash_in
	where buv_source='POSS'
		and left(dt_id,6)=left('{dt_id}',6)
		and dt_id<='{dt_id}'
group by 1, 2, 3, 4, 5, 6
union all
select
	'{dt_id}' as dt_id,
	'rev_cash_in_postpaid' as kpi_name,
	'agent' as level, 
	agent_id, 
	store_code, 
	'3ID' as brand, 
	sum(rev_total) as value
from cockpit.tmp_kpi_revenue_cash_in
	where buv_source='POSTPAID PAYMENT'
		and left(dt_id,6)=left('{dt_id}',6)
		and dt_id<='{dt_id}'
group by 1, 2, 3, 4, 5, 6
union all
select
	'{dt_id}' as dt_id,
	'rev_cash_in_postpaid' as kpi_name,
	'store' as level, 
	null agent_id, 
	store_code, 
	'3ID' as brand, 
	sum(rev_total) as value
from cockpit.tmp_kpi_revenue_cash_in
	where buv_source='POSTPAID PAYMENT'
		and left(dt_id,6)=left('{dt_id}',6)
		and dt_id<='{dt_id}'
group by 1, 2, 3, 4, 5, 6;

-- daily value
select
	dt_id,
	'rev_cash_in' as kpi_name,
	'agent' as level, 
	agent_id, 
	store_code, 
	'3ID' as brand, 
	sum(rev_total) as value
from cockpit.tmp_kpi_revenue_cash_in
	where buv_source not in ('dvm_store', 'dvm_standalone')
		and left(dt_id,6)=left('{dt_id}',6)
		and dt_id<='{dt_id}'
group by 1, 2, 3, 4, 5, 6
union all
select
	dt_id,
	'rev_cash_in' as kpi_name,
	'store' as level, 
	null as agent_id, 
	store_code, 
	'3ID' as brand, 
	sum(rev_total) as value
from cockpit.tmp_kpi_revenue_cash_in
	where buv_source not in ('dvm_store', 'dvm_standalone')
		and left(dt_id,6)=left('{dt_id}',6)
		and dt_id<='{dt_id}'
group by 1, 2, 3, 4, 5, 6
union all
select
	dt_id,
	'rev_cash_in' as kpi_name,
	buv_source as level, 
	agent_id, 
	store_code, 
	'3ID' as brand, 
	sum(rev_total) as value
from cockpit.tmp_kpi_revenue_cash_in
	where buv_source in ('dvm_store', 'dvm_standalone')
		and left(dt_id,6)=left('{dt_id}',6)
		and dt_id<='{dt_id}'
group by 1, 2, 3, 4, 5, 6
union all
select
	dt_id,
	'rev_cash_in_poss' as kpi_name,
	'agent' as level, 
	agent_id, 
	store_code, 
	'3ID' as brand, 
	sum(rev_total) as value
from cockpit.tmp_kpi_revenue_cash_in
	where buv_source='POSS'
		and left(dt_id,6)=left('{dt_id}',6)
		and dt_id<='{dt_id}'
group by 1, 2, 3, 4, 5, 6
union all
select
	dt_id,
	'rev_cash_in_poss' as kpi_name,
	'store' as level, 
	null agent_id, 
	store_code, 
	'3ID' as brand, 
	sum(rev_total) as value
from cockpit.tmp_kpi_revenue_cash_in
	where buv_source='POSS'
		and left(dt_id,6)=left('{dt_id}',6)
		and dt_id<='{dt_id}'
group by 1, 2, 3, 4, 5, 6
union all
select
	dt_id,
	'rev_cash_in_postpaid' as kpi_name,
	'agent' as level, 
	agent_id, 
	store_code, 
	'3ID' as brand, 
	sum(rev_total) as value
from cockpit.tmp_kpi_revenue_cash_in
	where buv_source='POSTPAID PAYMENT'
		and left(dt_id,6)=left('{dt_id}',6)
		and dt_id<='{dt_id}'
group by 1, 2, 3, 4, 5, 6
union all
select
	dt_id,
	'rev_cash_in_postpaid' as kpi_name,
	'store' as level, 
	null agent_id, 
	store_code, 
	'3ID' as brand, 
	sum(rev_total) as value
from cockpit.tmp_kpi_revenue_cash_in
	where buv_source='POSTPAID PAYMENT'
		and left(dt_id,6)=left('{dt_id}',6)
		and dt_id<='{dt_id}'
group by 1, 2, 3, 4, 5, 6;