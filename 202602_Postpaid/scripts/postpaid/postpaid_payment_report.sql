insert into `data-nationalslsdist-prd-986g`.postpaid.raw_monthly_payment
with bill as (
	SELECT 
		distinct
		format_date('%Y%m', DATETIME(a.actual_bill_dtm,'Asia/Jakarta')) as bill_mth,
		a.account_num, 
		a.invoice_num,
		format_date('%Y%m%d', DATETIME(a.actual_bill_dtm,'Asia/Jakarta')) as act_bill_dt,
		a.bill_rev_mny as bill_amt,
		a.event_seq, 
		a.bill_seq,
		format_date('%Y%m%d', DATETIME(a.payment_due_dat,'Asia/Jakarta')) as payment_due_date
	FROM `data-dtp-prd-aa1a.sor.rbm_bill_smy` as a
		WHERE dt_id>='2024-01-01'
		and a.bill_rev_mny>0
	-- and account_num='80869471'
	order by 2, 1
),
dm_bill as (
select * from (
	select 
		a.*, 
		b.activation_date, 
		concat('M', row_number() over(partition by a.account_num order by cast(act_bill_dt as int64) asc, bill_seq)) pymt_mth_cat
	from bill as a
	inner join (
			select account_num, activation_date from (
				select
					account_num, 
					activation_date,
					row_number() over(partition by account_num order by cast(activation_date as int64) desc) rnk
				from `data-nationalslsdist-prd-986g`.postpaid.raw_daily_ga
					where activation_date>='20240101'
						and tenure=1
				) as x where x.rnk=1		
		) as b
			on a.account_num = b.account_num and cast(act_bill_dt as int64)>cast(activation_date as int64)
) as x
	where x.pymt_mth_cat in ('M1', 'M2', 'M3', 'M4', 'M5')
		-- and bill_mth=left('{dt_id}',6)
), 
payment as (
	select * from (
	select 
		format_date('%Y%m%d', DATETIME(payment_dtm,'Asia/Jakarta')) pymt_dt, 
		account_num, 
		invoice_num,
		SPLIT(account_payment_txt, '|')[SAFE_OFFSET(1)] pymt_point, 
		SPLIT(account_payment_txt, '|')[SAFE_OFFSET(2)] pymt_cnl,
		row_number() over(partition by account_num, invoice_num order by payment_dtm desc, allocation_mny desc) as rnk,
		1 as pymt_flag
	from `data-dtp-prd-aa1a.sor.rbm_bill_pymt`
		where dt_id >= '2024-01-01'
			and allocation_mny>0
			and lower(invoice_num) not like '%deposit%'
			and format_date('%Y%m', DATETIME(payment_dtm,'Asia/Jakarta'))=left('{dt_id}',6)
			and format_date('%Y%m%d', DATETIME(payment_dtm,'Asia/Jakarta'))<='{dt_id}'
	) as x 
		where x.rnk=1
	order by account_num, pymt_dt
),
dm_payment as (
	select
		a.*,
		b.pymt_dt,
		b.pymt_point,
		b.pymt_cnl, 
		'PAYING' as status_payment,
		case when b.pymt_dt<=a.payment_due_date then 'Due Payment'
			else 'Overdue Payment' end as flag_payment 
	from dm_bill as a
	inner join payment as b
		on a.account_num = b.account_num and a.invoice_num=b.invoice_num
	union all 
	select
		a.*,
		b.pymt_dt,
		b.pymt_point,
		b.pymt_cnl, 
		'NOT YET PAYING' as status_payment,
		'Not Yet Paying' as flag_payment 
	from dm_bill as a
	left join payment as b
		on a.account_num = b.account_num and a.invoice_num=b.invoice_num
	where b.pymt_dt is null
		and a.bill_mth = left('{dt_id}',6)
		and a.invoice_num is not null
		and a.invoice_num <> ''
), 
ga as (
	select
		left(a.activation_date,6) as act_mth, 
		a.activation_date, 
		a.msisdn, 
		a.account_num as ac_num, 
		a.order_type, 
		a.package_rev , 
		a.dealer_id , 
		a.store_code_rev ,  
		a.agent_type , 
		a.nik_sales , 
		a.channel_rev ,  
		a.store_name_rev, 
		b.circle as circle, 
		b.region as region_circle,
		cast(a.guaranteed_revenue_mio as float64)*(1000000) as gua_rev, 
		case 
				when a.package_rev like '%Lines%' then 'Monthly - Family' 
				else 'Monthly - Non Family' end family_flag, 
		case when RIGHT(TRIM(a.package_rev), 1)='P' then 'Parent' 
			when RIGHT(TRIM(a.package_rev), 1)='C' then 'Child' 
			else null end as status_family,
		case when a.package_rev like '%Lines%' then cast(REGEXP_EXTRACT(a.package_rev, ' - (\\d+) Lines', 1) as int)
		else 1 end as num_lines
	from (
		select
			*,
			row_number() over(partition by account_num order by cast(activation_date as int64) desc) rnk
		from `data-nationalslsdist-prd-986g`.postpaid.raw_daily_ga
			where activation_date>='20240101'
				and tenure=1
		) as a 
	left join (
			select * from (
				select 
					* ,
					row_number() over(partition by store_code order by updated_dt desc) rnk
				from `data-nationalslsdist-prd-986g`.postpaid.ref_storelist_base
				-- where updated_dt = (select max(updated_dt) from `data-nationalslsdist-prd-986g`.postpaid.ref_storelist_base)
				) as x where x.rnk=1
		) as b
			on case when lower(a.agent_type)='outcall' then upper(a.nik_sales) else upper(a.store_code_rev) end=upper(b.store_code)
	where a.rnk=1
), 
dm_all as (
	select 
		ga.activation_date,
		ga.msisdn, 
		ga.ac_num, 
		ga.order_type, 
		ga.package_rev, 
		ga.dealer_id, 
		ga.store_code_rev, 
		ga.agent_type, 
		ga.nik_sales, 
		ga.channel_rev, 
		ga.store_name_rev, 
		ga.circle, 
		ga.region_circle, 
		ga.gua_rev, 
		ga.family_flag, 
		ga.status_family, 
		ga.num_lines,
		pyt.pymt_dt, 
		pyt.pymt_point, 
		pyt.pymt_cnl, 
		cast(case when pyt.status_payment='PAYING' then pyt.bill_amt else null end as float64)/ga.num_lines as pymt_amt,  
		pyt.invoice_num,
		pyt.pymt_mth_cat, 
		pyt.act_bill_dt as bill_dt, 
		pyt.bill_amt/ga.num_lines as bill_amt, 
		pyt.payment_due_date, 
		pyt.flag_payment, 
	    pyt.status_payment, 
		left(pyt.pymt_dt,6) as pymt_mth,
		ga.act_mth as activation_mth, 
		left(pyt.act_bill_dt,6) as bill_mth
	from dm_payment as pyt
		left join ga
		on ga.ac_num = pyt.account_num
	-- where pyt.status_payment='PAYING'
) 
select 
	a.*,
	coalesce(b.day_vlr_attach,0) day_vlr_attach,
	coalesce(c.deposit_amt,0) deposit_amt, 
	case when c.deposit_amt is not null then 'Y' 
				else 'N' end as deposit_flag, 
	left('{dt_id}',6) as mth_id,
	PARSE_DATE('%Y%m%d', '{dt_id}') as dt_id
from dm_all as a
left join (
	SELECT 
			left(`date`,6) as mth_id,
			msisdn, 
			count(distinct `date`) day_vlr_attach
	FROM `data-bi-prd-935c.bi_dm.vlr_site_wise` 
	  WHERE date(dt_id) between date(SUBSTR('{dt_id}',1,4) || '-' || SUBSTR('{dt_id}',5,2) || '-01')
	                           AND PARSE_DATE('%Y%m%d', '{dt_id}') 
	group by 1, 2
) as b
	on a.msisdn=b.msisdn 
left join (
	select * from (
		select
			distinct
				format_date('%Y%m',PARSE_TIMESTAMP('%d/%m/%Y %H:%M:%S', transaction_date)) as mth_id,
				customer_msisdn, 
				cast(service_amount_collected as float64) as deposit_amt,  
				row_number() over(partition by customer_msisdn order by PARSE_TIMESTAMP('%d/%m/%Y %H:%M:%S', transaction_date) desc,
									cast(service_amount_collected as float64) desc) as rnk
		from `data-nationalslsdist-prd-986g`.retail.raw_ipos_nonps_trx rint 
		where lower(product_name) like '%lines_deposit%' 
			and cast(service_amount_collected as float64)>0
		) as x where x.rnk=1
) as c 
	on a.msisdn=c.customer_msisdn and a.activation_mth=c.mth_id
;