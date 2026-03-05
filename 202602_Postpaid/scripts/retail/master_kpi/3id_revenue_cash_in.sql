-- Revenue (union 3 table) -------------------------------------------------------------------------------------------------------------------------------
drop table if exists cockpit.tmp_kpi_revenue_cash_in;

create table cockpit.tmp_kpi_revenue_cash_in as
SELECT 
		DATE_FORMAT(buv.salesdate, "%Y%m%d") AS dt_id
		, 'POSS' AS buv_source
		, case when ma.nik is not null then upper(ma.nik)
	    	when left(upper(buv.AgentName),4)='MBPS' then UPPER(CONCAT('MBPS-', SUBSTRING(TRIM(REPLACE(REPLACE(buv.AgentName, '-', ''), '_', '')), 5)))
	    	when left(upper(buv.AgentName),4)='MPBS' then UPPER(CONCAT('MBPS-', SUBSTRING(TRIM(REPLACE(REPLACE(buv.AgentName, '-', ''), '_', '')), 5)))
	    	else upper(buv.AgentName) end as agent_id
		-- , AgentName AS agent_id
		, buv.DealerCode AS store_code 
		, case when lower(buv.ProductName) like 'sp %'
		            or lower(buv.ProductName) like 'perdana %'
		            or lower(buv.ProductName) like 'elite%'
		            	then 'trx_sp_prepaid'
		       when lower(buv.ProductName) like '%voucher%elc%'
		       		or lower(buv.ProductName) like '%pulsa%'
		       		or buv.ProductName like 'Rp %'
		       		or buv.ItemCode like 'VO-PHY-%K%' 
		       			then 'trx_top_up'
		       	when buv.ItemCode like 'VO-PHY-%GB%'
		       		or lower(buv.ProductName) like 'happy%gb%'
		       		or lower(buv.ProductName) like 'aon%gb%'
		       		or lower(buv.ProductName) like '%puas%nelpon%'
		       		or lower(buv.ProductName) like '%rahmat%'
		       		or lower(buv.ProductName) like '%countri%roam%'
		       		or lower(buv.ProductName) like '%tri%ibadah%'
		       			then 'trx_data_package'
		       	when lower(buv.ProductName) like '%hifi%air%'
		       			then 'trx_hifi'
		       	when buv.ItemType='Non Serialized'
		       		and lower(buv.ProductName) not like '%voucher%'
		       		and lower(buv.ProductName) not like '%hifi%air%'
		       			then 'trx_merchandise'
		       	else 'trx_others' end as trx_category
			, buv.ProductName AS product_name
			, SUM(buv.Quantity) AS qty
			, SUM(COALESCE(buv.TotalAmount, 0)) as rev_total
	FROM cockpit.raw_poss buv 
	left join cockpit.mapping_agent_nik as ma
			on case when left(upper(buv.AgentName),4)='MPBS' then UPPER(CONCAT('MBPS', SUBSTRING(TRIM(REPLACE(REPLACE(buv.AgentName, '-', ''), '_', '')), 5)))
        else upper(TRIM(REPLACE(REPLACE(buv.AgentName, '-', ''), '_', ''))) end = upper(ma.idx)
	WHERE 1=1
    	and DATE_FORMAT(buv.SalesDate, '%Y%m') = left('{dt_id}',6) 
    	and DATE_FORMAT(buv.SalesDate, '%Y%m%d')<='{dt_id}'
    	-- and buv.ItemCode not like 'SP-PR%'
		-- and buv.ItemCode not like 'SP-RPLC%' 
		AND buv.ProductName not like 'SP-PR%' 
		and buv.TotalAmount > 0
	GROUP BY 1,2,3,4,5,6
	UNION ALL
	SELECT 
		date_format(substring(T1.date_trx,1,10),'%Y%m%d') as dt_id
		, case 
			when T2.dvm_code is not null then 'dvm_store'
			else 'dvm_standalone'
		  end  buv_source 
		, trim(T2.dvm_code) AS agent_id
		, coalesce(T2.store_code, trim(T1.terminal_code)) as store_code
		, case when lower(product_code) like '%perdana%' then 'trx_sp_prepaid'
			when product_code = 'H3I_THREE' then 'trx_top_up'
			when product_code in ('H3I_THREE_BEBI', 'H3I_THREE_DATA', 'H3I_THREE_OVERSEAS', 'H3I_THREE_ROAMING') then 'trx_data_package'
			when lower(product_code) like '%t%shirt%'
				or lower(product_code) like '%hat%'
				or lower(product_code) like '%mug%'
				or lower(product_code) like '%lanyard%'
				or lower(product_code) like '%notebook%'
				or lower(product_code) like '%tumbler%'
					then 'trx_merchandise'
		       	else 'trx_others' end as trx_category
		, T1.product_name as product_name
		, count(*) as qty
		, sum(payment_value) as rev_total
	FROM cockpit_archieve.raw_3db_trx T1
		left join cockpit.dvm_mapping T2
			on trim(T1.terminal_code)=trim(T2.dvm_code)
	Where result = 'success'
		and product_code NOT IN ('THREE_CHANGE_CARD','THREE_REGPRABAYAR','THREE_SIMCARD4G', 'THREE_CHANGE_CARD_O2O', 'Upgrade 4G O2O', 'VALIDITY_KTP')
	    and DATE_FORMAT(T1.date_trx, "%Y%m") = left('{dt_id}',6) 
	    and  DATE_FORMAT(T1.date_trx, "%Y%m%d")<='{dt_id}'
	GROUP BY 1,2,3,4,5,6
	union all
	SELECT 
		DATE_FORMAT(buv.document_date, "%Y%m%d") AS dt_id
		, 'POSTPAID PAYMENT' AS buv_source
		, case when ma.nik is not null then upper(ma.nik)
	    	when left(upper(buv.created_by),4)='MBPS' then UPPER(CONCAT('MBPS-', SUBSTRING(TRIM(REPLACE(REPLACE(buv.created_by, '-', ''), '_', '')), 5)))
	    	when left(upper(buv.created_by),4)='MPBS' then UPPER(CONCAT('MBPS-', SUBSTRING(TRIM(REPLACE(REPLACE(buv.created_by, '-', ''), '_', '')), 5)))
	    	else upper(buv.created_by) end as agent_id
		, dealercode AS store_code
		, 'trx_billing_payment' as trx_category
		, 'Postpaid' AS product_name
		, count(document_no) AS qty
		, SUM(COALESCE(buv.amount, 0)) AS rev_total
	FROM cockpit.raw_post_payment buv
		left join cockpit.mapping_agent_nik as ma
			on case when left(upper(buv.created_by),4)='MPBS' then UPPER(CONCAT('MBPS', SUBSTRING(TRIM(REPLACE(REPLACE(buv.created_by, '-', ''), '_', '')), 5)))
        else upper(TRIM(REPLACE(REPLACE(buv.created_by, '-', ''), '_', ''))) end = upper(ma.idx)
	WHERE buv.amount > 0
    	AND DATE_FORMAT(buv.document_date, '%Y%m') = left('{dt_id}',6) 
    	and DATE_FORMAT(buv.document_date, '%Y%m%d')<='{dt_id}'
	GROUP BY 1,2,3,4,5,6	
;



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
	'rev_cash_in_dvm' as kpi_name,
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
group by 1, 2, 3, 4, 5, 6
;

-- daily value -----------------------------------------------------------------------------------------------------------------------------------------
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
	'rev_cash_in_dvm' as kpi_name,
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


-- mtd transaction category
select
	'{dt_id}' as dt_id,
	trx_category as kpi_name,
	'agent' as level, 
	agent_id, 
	store_code, 
	'3ID' as brand, 
	sum(qty) as value
from cockpit.tmp_kpi_revenue_cash_in
	where 1=1
		and left(dt_id,6)=left('{dt_id}',6)
		and dt_id<='{dt_id}'
		and buv_source not in ('dvm_store', 'dvm_standalone')
group by 1, 2, 3, 4, 5, 6
union all
select
	'{dt_id}' as dt_id,
	trx_category as kpi_name,
	'store' as level, 
	null as agent_id, 
	store_code, 
	'3ID' as brand, 
	sum(qty) as value
from cockpit.tmp_kpi_revenue_cash_in
	where 1=1
		and left(dt_id,6)=left('{dt_id}',6)
		and dt_id<='{dt_id}'
		and buv_source not in ('dvm_store', 'dvm_standalone')
group by 1, 2, 3, 4, 5, 6
union all
select
	'{dt_id}' as dt_id,
	concat(trx_category,'_rev') as kpi_name,
	'agent' as level, 
	agent_id, 
	store_code, 
	'3ID' as brand, 
	sum(rev_total) as value
from cockpit.tmp_kpi_revenue_cash_in
	where 1=1
		and left(dt_id,6)=left('{dt_id}',6)
		and dt_id<='{dt_id}'
		and buv_source not in ('dvm_store', 'dvm_standalone')
group by 1, 2, 3, 4, 5, 6
union all
select
	'{dt_id}' as dt_id,
	concat(trx_category,'_rev') as kpi_name,
	'store' as level, 
	null as agent_id, 
	store_code, 
	'3ID' as brand, 
	sum(rev_total) as value
from cockpit.tmp_kpi_revenue_cash_in
	where 1=1
		and left(dt_id,6)=left('{dt_id}',6)
		and dt_id<='{dt_id}'
		and buv_source not in ('dvm_store', 'dvm_standalone')
group by 1, 2, 3, 4, 5, 6
union all
select
	'{dt_id}' as dt_id,
	concat(trx_category, '_dvm') as kpi_name,
	buv_source as level,
	agent_id, 
	store_code, 
	'3ID' as brand, 
	sum(qty) as value
from cockpit.tmp_kpi_revenue_cash_in
	where 1=1
		and left(dt_id,6)=left('{dt_id}',6)
		and dt_id<='{dt_id}'
		and buv_source in ('dvm_store', 'dvm_standalone')
group by 1, 2, 3, 4, 5, 6
union all 
select
	'{dt_id}' as dt_id,
	concat(trx_category,'_rev_dvm') as kpi_name,
	buv_source as level,
	agent_id, 
	store_code, 
	'3ID' as brand, 
	sum(rev_total) as value
from cockpit.tmp_kpi_revenue_cash_in
	where 1=1
		and left(dt_id,6)=left('{dt_id}',6)
		and dt_id<='{dt_id}'
		and buv_source in ('dvm_store', 'dvm_standalone')
group by 1, 2, 3, 4, 5, 6;

-- dly transaction category
select
	dt_id,
	trx_category as kpi_name,
	'agent' as level, 
	agent_id, 
	store_code, 
	'3ID' as brand, 
	sum(qty) as value
from cockpit.tmp_kpi_revenue_cash_in
	where 1=1
		and left(dt_id,6)=left('{dt_id}',6)
		and dt_id<='{dt_id}'
		and buv_source not in ('dvm_store', 'dvm_standalone')
group by 1, 2, 3, 4, 5, 6
union all
select
	dt_id,
	trx_category as kpi_name,
	'store' as level, 
	null as agent_id, 
	store_code, 
	'3ID' as brand, 
	sum(qty) as value
from cockpit.tmp_kpi_revenue_cash_in
	where 1=1
		and left(dt_id,6)=left('{dt_id}',6)
		and dt_id<='{dt_id}'
		and buv_source not in ('dvm_store', 'dvm_standalone')
group by 1, 2, 3, 4, 5, 6
union all
select
	dt_id,
	concat(trx_category,'_rev') as kpi_name,
	'agent' as level, 
	agent_id, 
	store_code, 
	'3ID' as brand, 
	sum(rev_total) as value
from cockpit.tmp_kpi_revenue_cash_in
	where 1=1
		and left(dt_id,6)=left('{dt_id}',6)
		and dt_id<='{dt_id}'
		and buv_source not in ('dvm_store', 'dvm_standalone')
group by 1, 2, 3, 4, 5, 6
union all
select
	dt_id,
	concat(trx_category,'_rev') as kpi_name,
	'store' as level, 
	null as agent_id, 
	store_code, 
	'3ID' as brand, 
	sum(rev_total) as value
from cockpit.tmp_kpi_revenue_cash_in
	where 1=1
		and left(dt_id,6)=left('{dt_id}',6)
		and dt_id<='{dt_id}'
		and buv_source not in ('dvm_store', 'dvm_standalone')
group by 1, 2, 3, 4, 5, 6
union all
select
	dt_id,
	concat(trx_category, '_dvm') as kpi_name,
	buv_source as level,
	agent_id, 
	store_code, 
	'3ID' as brand, 
	sum(qty) as value
from cockpit.tmp_kpi_revenue_cash_in
	where 1=1
		and left(dt_id,6)=left('{dt_id}',6)
		and dt_id<='{dt_id}'
		and buv_source in ('dvm_store', 'dvm_standalone')
group by 1, 2, 3, 4, 5, 6
union all 
select
	dt_id,
	concat(trx_category,'_rev_dvm') as kpi_name,
	buv_source as level,
	agent_id, 
	store_code, 
	'3ID' as brand, 
	sum(rev_total) as value
from cockpit.tmp_kpi_revenue_cash_in
	where 1=1
		and left(dt_id,6)=left('{dt_id}',6)
		and dt_id<='{dt_id}'
		and buv_source in ('dvm_store', 'dvm_standalone')
group by 1, 2, 3, 4, 5, 6;

-- backup
-- SELECT 
-- 		DATE_FORMAT(buv.salesdate, "%Y%m%d") AS dt_id
-- 		, 'POSS' AS buv_source
-- 		, case when ma.nik is not null then upper(ma.nik)
-- 	    	when left(upper(buv.AgentName),4)='MBPS' then UPPER(CONCAT('MBPS-', SUBSTRING(TRIM(REPLACE(REPLACE(buv.AgentName, '-', ''), '_', '')), 5)))
-- 	    	when left(upper(buv.AgentName),4)='MPBS' then UPPER(CONCAT('MBPS-', SUBSTRING(TRIM(REPLACE(REPLACE(buv.AgentName, '-', ''), '_', '')), 5)))
-- 	    	else upper(buv.AgentName) end as agent_id
-- 		-- , AgentName AS agent_id
-- 		, buv.DealerCode AS store_code
-- 		, buv.ProductName AS product_name
-- 		, SUM(COALESCE(buv.TotalAmount, 0)) AS rev_total
-- 	FROM cockpit.raw_poss buv  
-- 		left join cockpit.mapping_agent_nik as ma
-- 			on case when left(upper(buv.AgentName),4)='MPBS' then UPPER(CONCAT('MBPS', SUBSTRING(TRIM(REPLACE(REPLACE(buv.AgentName, '-', ''), '_', '')), 5)))
--         else upper(TRIM(REPLACE(REPLACE(buv.AgentName, '-', ''), '_', ''))) end = upper(ma.idx)
-- 	WHERE buv.TotalAmount > 0
-- 		AND buv.ProductName not like 'SP-PR%' 
--     	AND DATE_FORMAT(buv.SalesDate, '%Y%m') = left('{dt_id}',6) 
--     	and DATE_FORMAT(buv.SalesDate, '%Y%m%d')<='{dt_id}'
-- 	GROUP BY 1,2,3,4,5
-- UNION ALL
-- 	SELECT 
-- 		DATE_FORMAT(buv.document_date, "%Y%m%d") AS dt_id
-- 		, 'POSTPAID PAYMENT' AS buv_source
-- 		, case when ma.nik is not null then upper(ma.nik)
-- 	    	when left(upper(buv.created_by),4)='MBPS' then UPPER(CONCAT('MBPS-', SUBSTRING(TRIM(REPLACE(REPLACE(buv.created_by, '-', ''), '_', '')), 5)))
-- 	    	when left(upper(buv.created_by),4)='MPBS' then UPPER(CONCAT('MBPS-', SUBSTRING(TRIM(REPLACE(REPLACE(buv.created_by, '-', ''), '_', '')), 5)))
-- 	    	else upper(buv.created_by) end as agent_id
--         -- , created_by AS agent_id
-- 		, dealercode AS store_code
-- 		, 'Postpaid' AS product_name
-- 		, SUM(COALESCE(buv.amount, 0)) AS rev_total
-- 	FROM cockpit.raw_post_payment buv
-- 		left join cockpit.mapping_agent_nik as ma
-- 			on case when left(upper(buv.created_by),4)='MPBS' then UPPER(CONCAT('MBPS', SUBSTRING(TRIM(REPLACE(REPLACE(buv.created_by, '-', ''), '_', '')), 5)))
--         else upper(TRIM(REPLACE(REPLACE(buv.created_by, '-', ''), '_', ''))) end = upper(ma.idx)
-- 	WHERE buv.amount > 0
--     	AND DATE_FORMAT(buv.document_date, '%Y%m') = left('{dt_id}',6) 
--     	and DATE_FORMAT(buv.document_date, '%Y%m%d')<='{dt_id}'
-- 	GROUP BY 1,2,3,4,5	
-- UNION ALL
-- 	SELECT 
-- 	date_format(substring(T1.date_trx,1,10),'%Y%m%d') as dt_id
-- 	, case 
-- 		when T2.dvm_code is not null then 'dvm_store'
-- 		else 'dvm_standalone'
-- 	  end  buv_source 
-- 	, trim(T2.dvm_code) AS agent_id
-- 	, coalesce(T2.store_code, trim(T1.terminal_code)) as store_code
-- 	, T1.product_name as product_name
-- 	, sum(payment_value) as rev_total
-- 	FROM cockpit_archieve.raw_3db_trx T1
-- 		left join cockpit.dvm_mapping T2
-- 			on trim(T1.terminal_code)=trim(T2.dvm_code)
-- 	Where result = 'success'
-- 		and product_code NOT IN ('THREE_CHANGE_CARD','THREE_REGPRABAYAR','THREE_SIMCARD4G', 'THREE_CHANGE_CARD_O2O', 'Upgrade 4G O2O', 'VALIDITY_KTP')
-- 	    and DATE_FORMAT(T1.date_trx, "%Y%m") = left('{dt_id}',6) 
-- 	    and  DATE_FORMAT(T1.date_trx, "%Y%m%d")<='{dt_id}'
-- 	GROUP BY 1,2,3,4,5; 