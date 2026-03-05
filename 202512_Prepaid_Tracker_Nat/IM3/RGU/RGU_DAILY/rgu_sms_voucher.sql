--Script Migrated by Indra Maulana Ikhsan 20241120
--- SMS Voucher
declare vdt_id date default @vdt_id;
create or replace table `data-bi-prd-935c.bi_mart`.tmp_rgu_sms_voucher_{{ vdt_id }}  as
select msisdn, sum(TOT_RECHRG_IDR_VAL) as rev_sms_voucher
from `data-dtp-prd-aa1a.smy.cst_rechrg_dly_smy`
where date(dt_id) = vdt_id
	and rechrg_pymt_svc_tp='SMS'
	and TOT_RECHRG_IDR_VAL>0
group by 1;