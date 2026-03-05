--Script Migrated by Indra Maulana Ikhsan 20241120
--- Flexible Data Voucher (FDV)
declare vdt_id date default @vdt_id;
create or replace table `data-bi-prd-935c.bi_mart`.tmp_rgu_fdv_{{ vdt_id }}  as
select case when substr(pm_red_msisdn,1,2)!='62' then concat('62',pm_red_msisdn) else pm_red_msisdn end msisdn, sum(mobo_inj_sales_price) rev_fdv
from `data-dtp-prd-aa1a.sor.fdv_mobo_pm_join_match`
where pm_voucher_status='U'
	and date(transactiondate) = vdt_id
	and category = 'MOBO'
	and mobo_inj_sales_price>0
	and substring(concat('62',pm_red_msisdn), 1,5) in ('62857','62858','62856','62815','62816','62855','62814')
	--and substr(case when substr(pm_red_msisdn,1,2)!='62' then concat('62',pm_red_msisdn) else pm_red_msisdn end,1,5) in ('62857','62858','62856','62815','62816','62855','62814')
group by 1
;