delete from `data-nationalslsdist-prd-986g`.retail.raw_im3_rev_cash_in
	where left(dt_id,6)=left('{dt_id}',6)
	and dt_id<='{dt_id}'
;

insert into `data-nationalslsdist-prd-986g`.retail.raw_im3_rev_cash_in
select 
	format_date('%Y%m%d',PARSE_TIMESTAMP('%d/%m/%Y %H:%M:%S', a.transaction_date)) as dt_id,
	a.organization_ref_code as store_code, 
	a.username as agent_id, 
	CASE
	    -- Postpaid
	    WHEN service_type IN (
	      'Add Postpaid','Change Plan','Contract Renewal','Package Change',
	      'Postpaid CVM Offer','Postpaid Registration','Postpaid SIM Reactivation',
	      'Postpaid SIM Replacement','Postpaid To Prepaid Migration',
	      'Pre to Post SIM Reactivation','Prepaid To Postpaid Migration',
	      'Prepaid SAMU'
	    )
	    OR (service_type = 'Sales' AND product_category IN ('Postpaid Package','Postpaid MSISDN','Vanity Tertiary Sale'))
	    THEN 'trx_sp_postpaid'
	    -- Prepaid
	    WHEN service_type IN (
	      'Prepaid CVM Offer','Prepaid Registration','Prepaid SIM Replacement',
	      'Prepaid SIM Replacement for SDP'
	    )
	    OR (service_type = 'Sales' AND product_category IN ('SIMCARD','Starter Pack'))
	    THEN 'trx_sp_prepaid'
	    -- Data package
	    WHEN (service_type = 'Sales' AND product_category = 'CVM Prepaid')
	      OR service_type = 'Topup Package'
	    THEN 'trx_data_package'
	    -- Top Up
	    WHEN service_type = 'Topup Recharge' THEN 'trx_top_up'
	    -- HiFi
	    WHEN service_type = 'FTTH Registration'
	      OR (service_type = 'Sales' AND product_category = 'Modem')
	    THEN 'trx_hifi'
	    -- Merchandise
	    WHEN service_type = 'Sales' AND product_category IN ('Merchandise','Accesoris')
	    THEN 'trx_merchandise'
	    -- Billing
	    WHEN service_type = 'Bill Payment' THEN 'trx_billing_payment'
	    -- Others
	    ELSE 'trx_others'
	  END AS trx_category,
	sum(CAST(service_amount_collected AS FLOAT64)) rev_cash_in,
	sum(CAST(product_qty AS FLOAT64)) as qty
FROM
	`data-nationalslsdist-prd-986g`.retail.raw_ipos_nonps_trx as a 
WHERE
	-- `status` = 'Success'
	(`status` in ('Success', '') or `status` is null)
	and format_date('%Y%m',PARSE_TIMESTAMP('%d/%m/%Y %H:%M:%S', transaction_date)) = left('{dt_id}',6)
	and format_date('%Y%m%d',PARSE_TIMESTAMP('%d/%m/%Y %H:%M:%S', transaction_date)) <='{dt_id}'
group by 1, 2, 3, 4
;

-- mtd value
select
	'{dt_id}' as dt_id,
	'rev_cash_in' as kpi_name,
	'agent' as level, 
	agent_id, 
	store_code, 
	'IM3' as brand, 
	sum(rev_cash_in) as value
from `data-nationalslsdist-prd-986g`.retail.raw_im3_rev_cash_in
	where left(dt_id,6)=left('{dt_id}',6)
		and dt_id<='{dt_id}'
group by 1, 2, 3, 4, 5, 6
union all
select
	'{dt_id}' as dt_id,
	'rev_cash_in' as kpi_name,
	'store' as level, 
	cast(null as string) as agent_id, 
	store_code, 
	'IM3' as brand, 
	sum(rev_cash_in) as value
from `data-nationalslsdist-prd-986g`.retail.raw_im3_rev_cash_in
	where left(dt_id,6)=left('{dt_id}',6)
		and dt_id<='{dt_id}'
group by 1, 2, 3, 4, 5, 6
union all
select
	'{dt_id}' as dt_id,
	concat(trx_category,'_rev') as kpi_name,
	'agent' as level, 
	agent_id, 
	store_code, 
	'IM3' as brand, 
	sum(rev_cash_in) as value
from `data-nationalslsdist-prd-986g`.retail.raw_im3_rev_cash_in
	where left(dt_id,6)=left('{dt_id}',6)
		and dt_id<='{dt_id}'
group by 1, 2, 3, 4, 5, 6
union all
select
	'{dt_id}' as dt_id,
	concat(trx_category,'_rev') as kpi_name,
	'store' as level, 
	cast(null as string) as agent_id, 
	store_code, 
	'IM3' as brand, 
	sum(rev_cash_in) as value
from `data-nationalslsdist-prd-986g`.retail.raw_im3_rev_cash_in
	where left(dt_id,6)=left('{dt_id}',6)
		and dt_id<='{dt_id}'
group by 1, 2, 3, 4, 5, 6
union all
select
	'{dt_id}' as dt_id,
	trx_category as kpi_name,
	'agent' as level, 
	agent_id, 
	store_code, 
	'IM3' as brand, 
	sum(qty) as value
from `data-nationalslsdist-prd-986g`.retail.raw_im3_rev_cash_in
	where left(dt_id,6)=left('{dt_id}',6)
		and dt_id<='{dt_id}'
group by 1, 2, 3, 4, 5, 6
union all
select
	'{dt_id}' as dt_id,
	trx_category as kpi_name,
	'store' as level, 
	cast(null as string) as agent_id, 
	store_code, 
	'IM3' as brand, 
	sum(qty) as value
from `data-nationalslsdist-prd-986g`.retail.raw_im3_rev_cash_in
	where left(dt_id,6)=left('{dt_id}',6)
		and dt_id<='{dt_id}'
group by 1, 2, 3, 4, 5, 6;

-- dly value
select
	dt_id,
	'rev_cash_in' as kpi_name,
	'agent' as level, 
	agent_id, 
	store_code, 
	'IM3' as brand, 
	sum(rev_cash_in) as value
from `data-nationalslsdist-prd-986g`.retail.raw_im3_rev_cash_in
	where left(dt_id,6)=left('{dt_id}',6)
		and dt_id<='{dt_id}'
group by 1, 2, 3, 4, 5, 6
union all
select
	dt_id,
	'rev_cash_in' as kpi_name,
	'store' as level, 
	cast(null as string) as agent_id, 
	store_code, 
	'IM3' as brand, 
	sum(rev_cash_in) as value
from `data-nationalslsdist-prd-986g`.retail.raw_im3_rev_cash_in
	where left(dt_id,6)=left('{dt_id}',6)
		and dt_id<='{dt_id}'
group by 1, 2, 3, 4, 5, 6
union all
select
	dt_id,
	concat(trx_category,'_rev') as kpi_name,
	'agent' as level, 
	agent_id, 
	store_code, 
	'IM3' as brand, 
	sum(rev_cash_in) as value
from `data-nationalslsdist-prd-986g`.retail.raw_im3_rev_cash_in
	where left(dt_id,6)=left('{dt_id}',6)
		and dt_id<='{dt_id}'
group by 1, 2, 3, 4, 5, 6
union all
select
	dt_id,
	concat(trx_category,'_rev') as kpi_name,
	'store' as level, 
	cast(null as string) as agent_id, 
	store_code, 
	'IM3' as brand, 
	sum(rev_cash_in) as value
from `data-nationalslsdist-prd-986g`.retail.raw_im3_rev_cash_in
	where left(dt_id,6)=left('{dt_id}',6)
		and dt_id<='{dt_id}'
group by 1, 2, 3, 4, 5, 6
union all
select
	dt_id,
	trx_category as kpi_name,
	'agent' as level, 
	agent_id, 
	store_code, 
	'IM3' as brand, 
	sum(qty) as value
from `data-nationalslsdist-prd-986g`.retail.raw_im3_rev_cash_in
	where left(dt_id,6)=left('{dt_id}',6)
		and dt_id<='{dt_id}'
group by 1, 2, 3, 4, 5, 6
union all
select
	dt_id,
	trx_category as kpi_name,
	'store' as level, 
	cast(null as string) as agent_id, 
	store_code, 
	'IM3' as brand, 
	sum(qty) as value
from `data-nationalslsdist-prd-986g`.retail.raw_im3_rev_cash_in
	where left(dt_id,6)=left('{dt_id}',6)
		and dt_id<='{dt_id}'
group by 1, 2, 3, 4, 5, 6;