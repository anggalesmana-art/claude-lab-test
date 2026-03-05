insert overwrite rdm.postpaid_payment_monthly
partition (mth_id)
with pyt as ( 
	select * from (
		select 
			pay.dt_id pymt_dt, 
			strleft(pay.dt_id,6) as pymt_mth, 
			pay.account_num, 
			pay.pymt_point, 
			pay.pymt_cnl, 
			pay.pymt_amt,
			pay.invoice_num,
			ga.act_mth, 
			concat('M', cast(rank() over(partition by pay.account_num order by pay.dt_id asc, pay.account_payment_seq asc ) as string)) as pymt_mth_cat 
		from (
		select  
			FROM_UNIXTIME(UNIX_TIMESTAMP(CAST(rbp.payment_dtm AS TIMESTAMP)), 'yyyyMMdd') as dt_id, 
			rbp.account_num, 
			SPLIT_PART(rbp.account_payment_txt, '|', 2) as pymt_point, 
			SPLIT_PART(rbp.account_payment_txt, '|', 3) as pymt_cnl, 
			rbp.allocation_mny as pymt_amt, 
			rbp.invoice_num, 
			rbp.invoice_seq, 
			rbp.account_payment_seq
		from sor.rbm_bill_pymt rbp
		) as pay  
		inner join (
			select 
				distinct
				strleft(a.activation_date,6) as act_mth,  
				b.ac_num
			from rdm.dump_daily_ga as a 
				left join smy.ar_cst_pstpaid_rtl as b 
					on a.msisdn=b.msisdn and b.dt_id=strleft(REPLACE(CAST(LAST_DAY(FROM_UNIXTIME(UNIX_TIMESTAMP(a.activation_date, 'yyyyMMdd'), 'yyyy-MM-dd')) AS STRING), '-', ''),8)
			where cast(strleft(a.activation_date ,6) as int) >= 202401  
				and cast(strleft(a.activation_date ,6) as int) <cast(strleft('{dt_id}',6) as int)
				and a.tenure = '1' 
				-- and a.order_type in ('New Registration','Migration')  
		) as ga
			on pay.account_num=ga.ac_num 
				and cast(strleft(pay.dt_id,6) as int)>cast(ga.act_mth as int) 
				and cast(strleft(pay.dt_id,6) as int)<=cast(from_timestamp(add_months(to_timestamp(concat(ga.act_mth,'01'),'yyyyMMdd'),5),'yyyyMM') as int)
		where strleft(pay.dt_id,6)>='202401' and pay.dt_id<='{dt_id}' 
			and lower(pay.invoice_num) not like '%deposit%'
	) as xx where strleft(xx.pymt_dt,6)=strleft('{dt_id}',6)
)
, bill as(
	select  
		FROM_UNIXTIME(UNIX_TIMESTAMP(CAST(rbs.actual_bill_dtm AS TIMESTAMP)), 'yyyyMM') bill_mth, 
		rbs.account_num as ac_num, 
		rbs.invoice_num, 
		FROM_UNIXTIME(UNIX_TIMESTAMP(CAST(rbs.actual_bill_dtm AS TIMESTAMP)), 'yyyyMMdd') act_bill_dt, 
		cast(rbs.bill_rev_mny as double) as bill_amt,
		rbs.event_seq, 
		rank() over(partition by rbs.account_num, rbs.event_seq order by dt_id desc) as rnk,
		FROM_UNIXTIME(UNIX_TIMESTAMP(CAST(rbs.payment_due_dat AS TIMESTAMP)), 'yyyyMMdd') payment_due_date
	from sor.rbm_bill_smy as rbs
) 
, ga as(
	select 
		strleft(a.activation_date,6) as act_mth, 
		a.activation_date, 
		a.msisdn, 
		b.ac_num, 
		a.order_type, 
		a.package_rev , 
		a.dealer_id , 
		a.store_code_rev ,  
		a.agent_type , 
		a.nik_sales , 
		a.channel_rev ,  
		a.store_name_rev, 
		coalesce(c.circle,'Others') as circle, 
		coalesce(c.region_circle,'Others') as region_circle,
		cast(a.guaranteed_revenue_mio as double)*(1000000) as gua_rev, 
		case 
				when a.package_rev like '%Lines%' then 'Monthly - Family' 
				else 'Monthly - Non Family' end family_flag, 
		case when RIGHT(TRIM(a.package_rev), 1)='P' then 'Parent' 
			when RIGHT(TRIM(a.package_rev), 1)='C' then 'Child' 
			else null end as status_family,
		case when a.package_rev like '%Lines%' then cast(REGEXP_EXTRACT(a.package_rev, ' - (\\d+) Lines', 1) as int)
		else 1 end as num_lines
	from rdm.dump_daily_ga as a 
		left join smy.ar_cst_pstpaid_rtl as b 
			on a.msisdn=b.msisdn and b.dt_id=strleft(REPLACE(CAST(LAST_DAY(FROM_UNIXTIME(UNIX_TIMESTAMP(a.activation_date, 'yyyyMMdd'), 'yyyy-MM-dd')) AS STRING), '-', ''),8) 
		left join rdm.storelist as c 
			on a.store_code_rev=c.store_code
	where cast(strleft(a.activation_date ,6) as int) >= 202401  
		and cast(strleft(a.activation_date ,6) as int) <cast(strleft('{dt_id}',6) as int)
		and a.tenure = '1' 
		-- and a.order_type in ('New Registration','Migration')
) 
, paid as (
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
		cast(pyt.pymt_amt as double)/ga.num_lines as pymt_amt,  
		pyt.invoice_num,
		pyt.pymt_mth_cat, 
		bill.act_bill_dt as bill_dt, 
		bill.bill_amt/ga.num_lines as bill_amt, 
		bill.payment_due_date, 
		case when bill.payment_due_date >= pyt.pymt_dt then 'Due Payment'
	    else 'Overdue Payment' end as flag_payment, 
	    'PAYING' as status_payment, 
		pyt.pymt_mth,
		ga.act_mth as activation_mth, 
		strleft('{dt_id}',6) as bill_mth
	from ga 
		inner join pyt
			on ga.ac_num=pyt.account_num and pyt.pymt_mth>ga.act_mth 
		left join bill 
			on pyt.account_num = bill.ac_num
			and pyt.invoice_num=bill.invoice_num 
	where 1=1 
	and pymt_mth_cat in ('M1', 'M2', 'M3', 'M4', 'M5') -- filter only until M5
) 
, not_paid as (
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
		cast(pyt.pymt_amt as double)/ga.num_lines as pymt_amt,  
		bill.invoice_num,
		pyt.pymt_mth_cat, 
		bill.act_bill_dt as bill_dt, 
		bill.bill_amt/ga.num_lines as bill_amt, 
		bill.payment_due_date, 
		'Not Yet Paying' as flag_payment, 
	    'NOT YET PAYING' as status_payment, 
		pyt.pymt_mth,
		ga.act_mth as activation_mth, 
		strleft('{dt_id}',6) as bill_mth
	from ga 
	left join pyt
			on ga.ac_num=pyt.account_num and pyt.pymt_mth>ga.act_mth 
	left join bill 
			on ga.ac_num = bill.ac_num
			and bill.bill_mth=strleft('{dt_id}',6) 
			-- or strleft(bill.payment_due_date, 6)=strleft('{dt_id}',6))
			-- and bill.rnk =1 
			and lower(bill.invoice_num) not like '%deposit%'
	where 1=1 
	and pyt.pymt_amt is null 
	and cast(ga.act_mth as int) between cast(from_timestamp(add_months(to_timestamp('{dt_id}','yyyyMMdd'),-4),'yyyyMM') as int) 
	and cast(from_timestamp(add_months(to_timestamp('{dt_id}','yyyyMMdd'),-1),'yyyyMM') as int)
) 
, paid_all as (
	select  
		paid.*
	from paid
	union all 
	select  
		not_paid.*
	from not_paid
) 
select 
paid_all.*, 
coalesce(vlr.day_vlr_attach,0) day_vlr_attach, 
coalesce(depo.deposit_amt,0) deposit_amt, 
case when depo.deposit_amt is not null then 'Y' 
			else 'N' end as deposit_flag, 
strleft('{dt_id}',6) as mth_id
from paid_all 
left join (
	select  
		strleft(a.dt_id,6) as mth_id,
		a.msisdn, 
		count(distinct a.`date`) day_vlr_attach
	from biadm.vlr_site_wise as a   
	where 1=1 
		and strleft(a.`date`, 6)=strleft('{dt_id}',6)
		group by 1, 2 
) as vlr on paid_all.msisdn=vlr.msisdn 
left join (
	select   
		distinct
		(FROM_UNIXTIME(UNIX_TIMESTAMP(transaction_date, 'dd/MM/yyyy HH:mm'), 'yyyyMM')) as mth_id,
		customer_msisdn, 
		cast(service_amount_collected as double) as deposit_amt,  
		case when cast(service_amount_collected as double)>0 then 'Y' 
			else 'N' end as deposit_flag
	from rdm.ipos_trans_details 
	where lower(product_name) like '%lines_deposit%'
) as depo on paid_all.msisdn = depo.customer_msisdn and paid_all.activation_mth=depo.mth_id
;

select * from rdm.postpaid_payment_monthly where mth_id=strleft('{dt_id}',6);

-- insert overwrite rdm.bai_postpaid_payment 
-- partition (activation_mth, bill_mth)
-- with pyt as ( 
-- 	select 
-- 		pay.dt_id pay_dt, 
-- 		strleft(pay.dt_id,6) as pay_mth, 
-- 		pay.cust_no, 
-- 		pay.pay_point, 
-- 		pay.pymt_cnl, 
-- 		pay.sal_amt as pay_amt, 
-- 		ga.act_mth, 
-- 		concat('M', cast(rank() over(partition by pay.cust_no order by pay.dt_id asc) as string)) as pay_bill_cat
-- 	from smy.payment_dly_smy as pay  
-- 		inner join (
-- 					select 
-- 						distinct
-- 						strleft(a.activation_date,6) as act_mth, 
-- 						--a.msisdn, 
-- 						b.ac_num
-- 					from rdm.dump_daily_ga as a 
-- 						left join smy.ar_cst_pstpaid_rtl as b 
-- 							on a.msisdn=b.msisdn and b.dt_id=strleft(REPLACE(CAST(LAST_DAY(FROM_UNIXTIME(UNIX_TIMESTAMP(a.activation_date, 'yyyyMMdd'), 'yyyy-MM-dd')) AS STRING), '-', ''),8)
-- 					where cast(strleft(a.activation_date ,6) as int) >= 202411  
-- 						and cast(strleft(a.activation_date ,6) as int) <cast(strleft('{dt_id}',6) as int)
-- 						and a.tenure = '1' 
-- 						and a.order_type in ('New Registration','Migration')  
-- 					) as ga
-- 					on pay.cust_no=ga.ac_num 
-- 						and cast(strleft(pay.dt_id,6) as int)>cast(ga.act_mth as int) 
-- 						and cast(strleft(pay.dt_id,6) as int)<=cast(from_timestamp(add_months(to_timestamp(concat(ga.act_mth,'01'),'yyyyMMdd'),5),'yyyyMM') as int)
-- 	where strleft(pay.dt_id,6)=strleft('{dt_id}',6) and pay.dt_id<='{dt_id}'
-- 		and pay.sal_code='Payment'
-- )
-- , bill as(
-- 	select 
-- 		mo,  
-- 		ac_num, 
-- 		max(from_timestamp(act_bill_dt, 'yyyyMMdd')) as act_bill_dt ,
-- 		max(from_timestamp(CAST(DATE_ADD(TO_DATE(act_bill_dt), 20) as DATE), 'yyyyMMdd')) as payment_due_date
-- 	from smy.cst_billing_dtl_dly_smy  
-- 	where mo=strleft('{dt_id}',6)
-- 	group by 1, 2
-- ) 
-- , ga as(
-- 	select 
-- 		strleft(a.activation_date,6) as act_mth, 
-- 		a.activation_date, 
-- 		a.msisdn, 
-- 		b.ac_num, 
-- 		a.order_type, 
-- 		a.package_rev , 
-- 		a.dealer_id , 
-- 		a.store_code_rev ,  
-- 		a.agent_type , 
-- 		a.nik_sales , 
-- 		a.channel_rev ,  
-- 		a.store_name_rev, 
-- 		coalesce(c.circle,'Others') as circle, 
-- 		coalesce(c.region_circle,'Others') as region_circle,
-- 		cast(a.guaranteed_revenue_mio as double)*(1000000) as gua_rev, 
-- 		case 
-- 				when a.package_rev like '%Lines%' then 'Monthly - Family' 
-- 				else 'Monthly - Non Family' end family_flag, 
-- 		case when RIGHT(TRIM(a.package_rev), 1)='P' then 'Parent' 
-- 			when RIGHT(TRIM(a.package_rev), 1)='C' then 'Child' 
-- 			else null end as status_family,
-- 		case when a.package_rev like '%Lines%' then cast(REGEXP_EXTRACT(a.package_rev, ' - (\\d+) Lines', 1) as int)
-- 		else 1 end as num_lines
-- 	from rdm.dump_daily_ga as a 
-- 		left join smy.ar_cst_pstpaid_rtl as b 
-- 			on a.msisdn=b.msisdn and b.dt_id=strleft(REPLACE(CAST(LAST_DAY(FROM_UNIXTIME(UNIX_TIMESTAMP(a.activation_date, 'yyyyMMdd'), 'yyyy-MM-dd')) AS STRING), '-', ''),8) 
-- 		left join rdm.storelist as c 
-- 			on a.store_code_rev=c.store_code
-- 	where cast(strleft(a.activation_date ,6) as int) >= 202411  
-- 		and cast(strleft(a.activation_date ,6) as int) <cast(strleft('{dt_id}',6) as int)
-- 		and a.tenure = '1' 
-- 		and a.order_type in ('New Registration','Migration')
-- ) 
-- select 
-- 	ga.activation_date, 
-- 	ga.msisdn, 
-- 	ga.ac_num, 
-- 	ga.order_type, 
-- 	ga.package_rev, 
-- 	ga.dealer_id, 
-- 	ga.store_code_rev, 
-- 	ga.agent_type, 
-- 	ga.nik_sales, 
-- 	ga.channel_rev, 
-- 	ga.store_name_rev, 
-- 	ga.circle, 
-- 	ga.region_circle, 
-- 	ga.gua_rev, 
-- 	ga.family_flag, 
-- 	ga.status_family, 
-- 	ga.num_lines,
-- 	pyt.pay_dt, 
-- 	pyt.pay_point, 
-- 	pyt.pymt_cnl, 
-- 	cast(pyt.pay_amt as double)/ga.num_lines as sal_amt, 
-- 	pyt.pay_bill_cat as pay_cat_mth, 
-- 	bill.act_bill_dt as bill_dt, 
-- 	bill.payment_due_date, 
-- 	case when bill.payment_due_date >= pyt.pay_dt then 'Due Payment'
--      when bill.payment_due_date < pyt.pay_dt then 'Overdue Payment'
--      else 'Not Yet Paying' end as flag_payment, 
--     case when coalesce(cast(pyt.pay_amt as double),0) > 0 then 'PAYING' 
-- 		else 'NOT YET PAYING' end as status_payment, 
-- 	pyt.pay_mth,
-- 	ga.act_mth as activation_mth, 
-- 	strleft('{dt_id}',6) as bill_mth
-- from ga 
-- 	left join pyt
-- 		on ga.ac_num=pyt.cust_no and pyt.pay_mth>ga.act_mth 
-- 	left join bill 
-- 		on ga.ac_num=bill.ac_num; 

-- select * from rdm.bai_postpaid_payment where bill_mth=strleft('{dt_id}',6);