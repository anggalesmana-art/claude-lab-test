insert into `data-nationalslsdist-prd-986g`.retail.raw_im3_interaction_revenue
SELECT
	-- concat(substr(transaction_date, 7, 4), substr(transaction_date, 4, 2), left(transaction_date, 2)) dt_id,
	format_date('%Y%m%d',PARSE_TIMESTAMP('%d/%m/%Y %H:%M:%S', transaction_date)) as dt_id,
	cast(NULL as string) activity_type,
	organization_ref_code store_code,
	service_type,
	cast(NULL as string) issue_group,
	cast(NULL as string) issue_sub,
	cast(NULL as string) issue_desc,
	count(1) cnt,
	count(DISTINCT customer_msisdn) cnt_msisdn,
	sum(CAST(service_amount_collected AS FLOAT64)) invoice_amount, 
	TIMESTAMP(PARSE_DATE('%Y%m%d', concat(substr(transaction_date, 7, 4), substr(transaction_date, 4, 2), left(transaction_date, 2)))) dates	
FROM
	`data-nationalslsdist-prd-986g`.retail.raw_ipos_nonps_trx rint 
WHERE
	(`status` in ('Success', '') or `status` is null)
	-- AND concat(substr(transaction_date, 7, 4), substr(transaction_date, 4, 2)) >= left('{dt_id}',6)
	and format_date('%Y%m',PARSE_TIMESTAMP('%d/%m/%Y %H:%M:%S', transaction_date)) = left('{dt_id}',6)
GROUP BY
	1, 2, 3, 4, 5, 6, 7, 11
union all
SELECT
	cast(format_date('%Y%m%d',dt_id) as string) as dt_id,
	activity_type,
	left(creator_location,4) store_code,
	ticket_type,
	issue_group,
	issue_sub,
	issue_desc,
	count(1) cnt,
	count(DISTINCT msisdn) cnt_msisdn,
	0 invoice_amount, 
	TIMESTAMP(PARSE_DATE('%Y%m%d',cast(format_date('%Y%m%d',dt_id) as string))) as dates
FROM
	`data-dtp-prd-aa1a.stg.stg_siebel_dly_intrctn`
WHERE
	activity_type IN ('Walk In', 'Appointment')
	and format_date('%Y%m', dt_id)=left('{dt_id}',6) 
	and dt_id<=TIMESTAMP(PARSE_DATE('%Y%m%d', '{dt_id}'))
GROUP BY
	1, 2, 3, 4, 5, 6, 7, 11;

insert into `data-nationalslsdist-prd-986g`.retail.raw_im3_traffic_visitor
SELECT
	concat(substr(transaction_date, 7, 4), substr(transaction_date, 4, 2), left(transaction_date, 2)) dt_id,
	organization_ref_code store_code,
	count(DISTINCT transaction_id) cnt_msisdn,
	TIMESTAMP(PARSE_DATE('%Y%m%d', concat(substr(transaction_date, 7, 4), substr(transaction_date, 4, 2), left(transaction_date, 2)))) dates
FROM
	`data-nationalslsdist-prd-986g`.retail.raw_ipos_nonps_trx rint 
WHERE
	`status` = 'Success'
	AND concat(substr(transaction_date, 7, 4), substr(transaction_date, 4, 2)) = left('{dt_id}',6)
GROUP BY
	1, 2, 4;