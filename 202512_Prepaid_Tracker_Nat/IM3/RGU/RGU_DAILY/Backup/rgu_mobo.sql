--Script Migrated by Indra Maulana Ikhsan 20241120
--- MOBO
declare vdt_id date default @vdt_id;
DROP TABLE IF EXISTS `data-bi-prd-935c.bi_mart`.tmp_rgu_mobo_{{ vdt_id }} ;
create table `data-bi-prd-935c.bi_mart`.tmp_rgu_mobo_{{ vdt_id }}  as
select b_msisdn msisdn, sum(amount_debit) rev_mobo
from `data-dtp-prd-aa1a.sor.mobo_revenue`
where revenue_date = '{{ vdt_id }}'
	and date(prc_dt) <= date_sub(vdt_id, interval 1 day)
	and amount_debit>0
	-- and revenue_trigger not in ('Y4','Y4EXP')
	and revenue_trigger in ('Y2','Y3')
	-- and (flag like 'Y2%' or flag like 'Y3%' or flag like 'Y5%')
group by 1
;