--Script Migrated by Indra Maulana Ikhsan 20241120
--- Organic Revenue and Traffic
declare vdt_id date default @vdt_id;
create or replace table `data-bi-prd-935c.bi_mart`.tmp_rgu_usg_organic_{{ vdt_id }}  as
select msisdn, sum(VOICE_REV) rev_voice, sum(SMS_REV) rev_sms, sum(DATA_REV) rev_data, sum(VAS_REV) rev_vas
	, sum(case when svc_usg_tp_rev='SMS' then usg_hits else 0 end) sms_hits
	, sum(case when svc_usg_tp_rev='VAS' then usg_hits else 0 end) vas_hits
	, sum(case when svc_usg_tp_rev='DATA' then vol_of_usg else 0 end) data_vol
	, sum(case when svc_usg_tp_rev='VOICE' then drtn_of_usg else 0 end) voice_dur
from `data-dtp-prd-aa1a.smy.cst_usg_dly_smy`
where date(dt_id)=vdt_id
group by 1
;