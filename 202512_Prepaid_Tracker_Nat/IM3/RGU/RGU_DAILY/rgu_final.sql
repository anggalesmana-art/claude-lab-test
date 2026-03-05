--Script Migrated by Indra Maulana Ikhsan 20241120
--Refresh Temp Table
declare vdt_id date default @vdt_id;

--- Insert to master table
delete from  `data-bi-prd-935c.bi_mart`.rgs_nogovt_dly where dt_id = vdt_id;
insert into `data-bi-prd-935c.bi_mart`.rgs_nogovt_dly 
with rev as (
  select *
    , case when coalesce(rev_voice,0) > 0 then 'V' else NULL end vox_flag
    , case when coalesce(rev_sms,0) > 0 then 'S' else NULL end sms_flag
    , case when coalesce(rev_data,0) > 0 then 'D' else NULL end dat_flag
    , case when coalesce(rev_vas,0) > 0 then 'A' else NULL end vas_flag
    , case when coalesce(rev_mobo,0) > 0 then 'M' else NULL end mob_flag
    , case when coalesce(rev_fdv,0) > 0 or coalesce(rev_vori,0) > 0 then 'F' else NULL end fdv_flag
    , case when coalesce(rev_sms_voucher,0) > 0 then 'O' else NULL end smsvou_flag
    , case when coalesce(rev_loan_balance,0) > 0 then 'L' else NULL end loanbal_flag
    , case when coalesce(rev_sp_data,0) > 0 then 'P' else NULL end spdat_flag
    , case when coalesce(rev_edu,0) > 0 then 'E' else NULL end edu_flag
    , case when coalesce(rev_pgi,0) > 0 then 'Y' else NULL end pgi_flag
  from `data-bi-prd-935c.bi_mart`.tmp_rgu_union_{{ vdt_id }}
),
incoming as (
  select *, 'I' inc_flag
  from `data-bi-prd-935c.bi_mart`.tmp_rgu_msc_{{ vdt_id }}
),
outgoing as (
  select msisdn, 'G' sge_flag
  from `data-bi-prd-935c.bi_mart`.tmp_rgu_usg_organic_{{ vdt_id }}
  where voice_dur+sms_hits+data_vol+vas_hits>0
),
final as (
  select a.msisdn
    , date(a.actvn_dt) actvn_dt
    , a.flag_status
    , 'NO' flag_a2p
    , a.svc_class_code
    , concat( coalesce(vox_flag,''), coalesce(sms_flag,''), coalesce(dat_flag,''), coalesce(vas_flag,'')
      , coalesce(mob_flag,''), coalesce(inc_flag,''), coalesce(fdv_flag,''), coalesce(smsvou_flag,''), coalesce(loanbal_flag,'')
      , coalesce(spdat_flag,''), coalesce(edu_flag,''), coalesce(pgi_flag,''), coalesce(sge_flag,'')
    ) usg_flag
    , coalesce(rev_voice,0) rev_voice
    , coalesce(rev_sms,0) rev_sms
    , coalesce(rev_data,0) rev_data
    , coalesce(rev_vas,0) rev_vas
    , coalesce(rev_mobo,0) rev_mobo
    , coalesce(rev_fdv,0) rev_fdv
    , coalesce(rev_sms_voucher,0) rev_sms_voucher
    , coalesce(rev_loan_balance,0) rev_loan_balance
    , coalesce(rev_sp_data,0) rev_sp_data
    , coalesce(rev_vori,0) rev_vori
    , coalesce(rev_edu,0) rev_edu
    , coalesce(rev_pgi,0) rev_pgi
  from `data-bi-prd-935c.bi_mart`.tmp_rgu_sdp_{{ vdt_id }} a
  left join outgoing b
    on a.msisdn=b.msisdn
  left join rev c
    on a.msisdn=c.msisdn
  left join incoming d
    on a.msisdn=d.msisdn
)
select msisdn, actvn_dt, usg_flag
  , (rev_voice+rev_sms+rev_data+rev_vas+rev_mobo+rev_fdv+rev_sms_voucher+rev_loan_balance+rev_sp_data+rev_vori+rev_edu+rev_pgi) total_rev
  , timestamp(current_datetime('+7')) ppn_dttm
	, rev_voice, rev_sms, rev_data, rev_vas, rev_mobo, rev_fdv, rev_sms_voucher, rev_loan_balance, rev_sp_data, rev_vori, rev_edu
	, flag_status
	, flag_a2p
	, svc_class_code
	, rev_pgi
	, vdt_id dt_id
from final
where coalesce(usg_flag,'')!=''
;


--- drop temp table
drop table IF EXISTS `data-bi-prd-935c.bi_mart`.tmp_rgu_usg_organic_{{ vdt_id }};
drop table IF EXISTS `data-bi-prd-935c.bi_mart`.tmp_rgu_mobo_{{ vdt_id }};
drop table IF EXISTS `data-bi-prd-935c.bi_mart`.tmp_rgu_fdv_{{ vdt_id }};
drop table IF EXISTS `data-bi-prd-935c.bi_mart`.tmp_rgu_vori_{{ vdt_id }};
drop table IF EXISTS `data-bi-prd-935c.bi_mart`.tmp_rgu_sp_data_{{ vdt_id }};
drop table IF EXISTS `data-bi-prd-935c.bi_mart`.tmp_rgu_loan_balance_{{ vdt_id }};
drop table IF EXISTS `data-bi-prd-935c.bi_mart`.tmp_rgu_sms_voucher_{{ vdt_id }};
--drop table IF EXISTS `data-bi-prd-935c.bi_mart`.tmp_rgu_edu_{{ vdt_id }};
drop table IF EXISTS `data-bi-prd-935c.bi_mart`.tmp_rgu_pgi_{{ vdt_id }};
drop table IF EXISTS `data-bi-prd-935c.bi_mart`.tmp_rgu_union_{{ vdt_id }};
drop table if exists `data-bi-prd-935c.bi_mart`.tmp_rgu_sdp_{{ vdt_id }};
drop table if exists `data-bi-prd-935c.bi_mart`.tmp_rgu_msc_{{ vdt_id }};