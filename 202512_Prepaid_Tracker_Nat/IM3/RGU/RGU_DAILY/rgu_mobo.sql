--Script Migrated by Indra Maulana Ikhsan 20241120
--- MOBO
declare vdt_id date default @vdt_id;
create or replace table `data-bi-prd-935c.bi_mart`.tmp_rgu_mobo_{{ vdt_id }}  as
select b_msisdn msisdn, sum(amount_debit) rev_mobo
from `data-dtp-prd-aa1a.sor.mobo_revenue`
where parse_date('%Y%m%d',revenue_date) = vdt_id
	and date(prc_dt) = date(vdt_id + interval 1 day)
	and amount_debit>0
	-- and revenue_trigger not in ('Y4','Y4EXP')
	and revenue_trigger in ('Y2','Y3','Y5')
	-- and (flag like 'Y2%' or flag like 'Y3%' or flag like 'Y5%')
	and substring(b_msisdn, 1,5) in ('62857','62858','62856','62815','62816','62855','62814') -- add filter prefix at 8 feb 2026
group by 1
union all
select msisdn, sum(cast(net_final as numeric))*1.11 rev_kpk
from `data-dtp-prd-aa1a.stg.sp_zero_revenue`
where date(dt_id) = vdt_id
	and cast(gross_price_amount as numeric) > 0
group by 1
;