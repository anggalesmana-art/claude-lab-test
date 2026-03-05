--Script Migrated by Indra Maulana Ikhsan 20241120
--- Loan
declare vdt_id date default @vdt_id;
create or replace table `data-bi-prd-935c.bi_mart`.tmp_rgu_loan_balance_{{ vdt_id }}  as
select msisdn, sum(rev_loan_balance) rev_loan_balance
from
(
	-- -- Pulsa Outdate
	-- select msisdn, total_amount as rev_loan_balance
	-- from `data-dtp-prd-aa1a.sor.rev_non_usg`
	-- where date(transaction_date)=vdt_id
	-- 	and revenue_code='OUTPAYMENTDA24007030'
    -- and total_amount > 0
	-- union all
	-- Package
	select msisdn, da_value*1.1 as rev_loan_balance
	from `data-dtp-prd-aa1a.stg.loanpackage_msisdn_wise`
	where date(dt_id)=vdt_id
    and da_value > 0
  union all
  -- Fee
  select msisdn, revenue as rev_loan_balance
  from `data-dtp-prd-aa1a.stg.lbs_svc_fee_aljabor`
  where date(dt_id)=vdt_id
    and revenue>0
) x
group by 1;