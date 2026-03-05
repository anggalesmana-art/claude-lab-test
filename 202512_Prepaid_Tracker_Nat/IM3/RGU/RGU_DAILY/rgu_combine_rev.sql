--Script Migrated by Indra Maulana Ikhsan 20241120

-- Combine All Revenues
DROP TABLE IF EXISTS `data-bi-prd-935c.bi_mart`.tmp_rgu_union_{{ vdt_id }} ;
create table `data-bi-prd-935c.bi_mart`.tmp_rgu_union_{{ vdt_id }}  as
select msisdn
	, sum(rev_voice) rev_voice
	, sum(rev_sms) rev_sms
	, sum(rev_data) rev_data
	, sum(rev_vas) rev_vas
	, sum(rev_mobo) rev_mobo
	, sum(rev_fdv) rev_fdv
	, sum(rev_sms_voucher) rev_sms_voucher
	, sum(rev_loan_balance) rev_loan_balance
	, sum(rev_sp_data) rev_sp_data
	, sum(rev_vori) rev_vori
	, sum(rev_edu) rev_edu
	, sum(rev_pgi) rev_pgi
from
(
	--voice
	select msisdn, rev_voice, 0 rev_sms, 0 rev_data, 0 rev_vas, 0 rev_mobo, 0 rev_fdv, 0 rev_sms_voucher, 0 rev_loan_balance, 0 rev_sp_data, 0 rev_vori, 0 rev_edu, 0 rev_pgi
	from `data-bi-prd-935c.bi_mart`.tmp_rgu_usg_organic_{{ vdt_id }}
	where rev_voice>0
	union all
	--sms
	select msisdn, 0 rev_voice, rev_sms, 0 rev_data, 0 rev_vas, 0 rev_mobo, 0 rev_fdv, 0 rev_sms_voucher, 0 rev_loan_balance, 0 rev_sp_data, 0 rev_vori, 0 rev_edu, 0 rev_pgi
	from `data-bi-prd-935c.bi_mart`.tmp_rgu_usg_organic_{{ vdt_id }}
	where rev_sms>0
	union all
	--data
	select msisdn, 0 rev_voice, 0 rev_sms, rev_data, 0 rev_vas, 0 rev_mobo, 0 rev_fdv, 0 rev_sms_voucher, 0 rev_loan_balance, 0 rev_sp_data, 0 rev_vori, 0 rev_edu, 0 rev_pgi
	from `data-bi-prd-935c.bi_mart`.tmp_rgu_usg_organic_{{ vdt_id }}
	where rev_data>0
	union all
	--vas
	select msisdn, 0 rev_voice, 0 rev_sms, 0 rev_data, rev_vas, 0 rev_mobo, 0 rev_fdv, 0 rev_sms_voucher, 0 rev_loan_balance, 0 rev_sp_data, 0 rev_vori, 0 rev_edu, 0 rev_pgi
	from `data-bi-prd-935c.bi_mart`.tmp_rgu_usg_organic_{{ vdt_id }}
	where rev_vas>0
	union all
	--- mobo
	select msisdn, 0 rev_voice, 0 rev_sms, 0 rev_data, 0 rev_vas, rev_mobo, 0 rev_fdv, 0 rev_sms_voucher, 0 rev_loan_balance, 0 rev_sp_data, 0 rev_vori, 0 rev_edu, 0 rev_pgi
	from `data-bi-prd-935c.bi_mart`.tmp_rgu_mobo_{{ vdt_id }}
	union all
	--- fdv
	select msisdn, 0 rev_voice, 0 rev_sms, 0 rev_data, 0 rev_vas, 0 rev_mobo, rev_fdv, 0 rev_sms_voucher, 0 rev_loan_balance, 0 rev_sp_data, 0 rev_vori, 0 rev_edu, 0 rev_pgi
	from `data-bi-prd-935c.bi_mart`.tmp_rgu_fdv_{{ vdt_id }}
	union all
	--- sms voucher
	select msisdn, 0 rev_voice, 0 rev_sms, 0 rev_data, 0 rev_vas, 0 rev_mobo, 0 rev_fdv, rev_sms_voucher, 0 rev_loan_balance, 0 rev_sp_data, 0 rev_vori, 0 rev_edu, 0 rev_pgi
	from `data-bi-prd-935c.bi_mart`.tmp_rgu_sms_voucher_{{ vdt_id }}
	union all
	--- loan balance
	select msisdn, 0 rev_voice, 0 rev_sms, 0 rev_data, 0 rev_vas, 0 rev_mobo, 0 rev_fdv, 0 rev_sms_voucher, rev_loan_balance, 0 rev_sp_data, 0 rev_vori, 0 rev_edu, 0 rev_pgi
	from `data-bi-prd-935c.bi_mart`.tmp_rgu_loan_balance_{{ vdt_id }}
	union all
	--- sp data
	select msisdn, 0 rev_voice, 0 rev_sms, 0 rev_data, 0 rev_vas, 0 rev_mobo, 0 rev_fdv, 0 rev_sms_voucher, 0 rev_loan_balance, rev_sp_data, 0 rev_vori, 0 rev_edu, 0 rev_pgi
	from `data-bi-prd-935c.bi_mart`.tmp_rgu_sp_data_{{ vdt_id }}
	union all
	--- voucher ori
	select msisdn, 0 rev_voice, 0 rev_sms, 0 rev_data, 0 rev_vas, 0 rev_mobo, 0 rev_fdv, 0 rev_sms_voucher, 0 rev_loan_balance, 0 rev_sp_data, rev_vori, 0 rev_edu, 0 rev_pgi
	from `data-bi-prd-935c.bi_mart`.tmp_rgu_vori_{{ vdt_id }}
	/*
	--- edu
	select msisdn, 0 rev_voice, 0 rev_sms, 0 rev_data, 0 rev_vas, 0 rev_mobo, 0 rev_fdv, 0 rev_sms_voucher, 0 rev_loan_balance, 0 rev_sp_data, 0 rev_vori, rev_edu, 0 rev_pgi
	from `data-bi-prd-935c.bi_mart`.tmp_rgu_edu_{{ vdt_id }}
	*/
	union all
	--- PGI
	select msisdn, 0 rev_voice, 0 rev_sms, 0 rev_data, 0 rev_vas, 0 rev_mobo, 0 rev_fdv, 0 rev_sms_voucher, 0 rev_loan_balance, 0 rev_sp_data, 0 rev_vori, 0 rev_edu, rev_pgi
	from `data-bi-prd-935c.bi_mart`.tmp_rgu_pgi_{{ vdt_id }}
) a
GROUP BY msisdn
;