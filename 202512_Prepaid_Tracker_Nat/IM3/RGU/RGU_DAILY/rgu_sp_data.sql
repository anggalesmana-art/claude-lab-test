--Script Migrated by Indra Maulana Ikhsan 20241120
--- SP Data
declare vdt_id date default @vdt_id;
create or replace table `data-bi-prd-935c.bi_mart`.tmp_rgu_sp_data_{{ vdt_id }}  as
select msisdn, sum(rev_sp_data) rev_sp_data
from (
  select msisdn, cast(amount_debit as numeric) rev_sp_data
  from `data-dtp-prd-aa1a.sor.sp_data_revenue`
  where date(revenue_date) = vdt_id
    and cast(amount_debit as numeric)>0
    and flag not like 'Y4%'
  -- union all
  -- select msisdn, cast(amount_debit as numeric) rev_sp_data
  -- from `data-dtp-prd-aa1a.sor.sp_data_revenue_b2b`
  -- where date(revenue_date) = vdt_id
  --   and cast(amount_debit as numeric)>0
  union all
  select msisdn,cast(amount_debit as numeric) rev from `data-dtp-prd-aa1a.stg.sp_fwa_revenue`
  where date(dt_id) = vdt_id
  and cast(amount_debit as numeric)>0  -- Update by Indra Maulana Ikhsan 20250803
) x
group by 1
;