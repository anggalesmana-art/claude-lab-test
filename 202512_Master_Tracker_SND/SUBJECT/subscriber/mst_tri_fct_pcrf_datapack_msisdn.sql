declare vdt_id date default @vdt_id;

delete from `data-bi-prd-935c.bi_mart`.fct_pcrf_datapack_msisdn where dt = vdt_id;


--'PLAN_FB_FLEX_ZERO' (max. 35MB per day) is split from 'PLAN_WALLED_GARDEN' (this is unlimmited) --> start 03 Nov 2022	
insert into `data-bi-prd-935c.bi_mart`.fct_pcrf_datapack_msisdn
select distinct date(edr_dt_sk_id) as dt, msisdn
from `data-dtptechm-prd-c7ca.dwh.pcrf_dly_summary` a
where edr_dt_sk_id = timestamp(vdt_id) and a.quota_usage > 0
and triggertype <> 16
and upper(case when a.service_nm <> '' then a.service_nm else a.quota_nm end) not in 
(
'PLAN_CAP11DEF', 'PLAN_CAP11DEF_CAL', 'PLAN_PAKET11',  'PLAN_PAKET11_JANETPLUS', 'PLAN_SUSNGHT_FU', 'PLAN_SUSREG_FU', 
'PLAN_WALLED_GARDEN', 'PLAN_WA_250MBPERD', 'PLAN_OTTCALL_100MB_FUP', 'PLAN_CHATTINGOTT_50MBFUP', 'PLAN_BIMAPLUS',
'PLAN_FB_FLEX_ZERO',
'PLAN_CVM_SEEDING', --modified on May 2023
'PLAN_WA_SPECIAL_PERDAY',
'PLAN_YOUTUBE_SPECIAL_PERDAY',
'PLAN_FB_SPECIAL_PERDAY',
'PLAN_CVM_ATTACK',
'PLAN_500MB_DAILY_1D', --just to know on 26 Jun 2023, that this quota name is categorized as free quota since a long time ago
'PLAN_CVM_SPECIAL_OW', --add on 07 Sep 2023, this is modular plan name (can be paid or free). But i decided to exclude this
'PLAN_CI2SUTA_500MB_1D' --add on 01 Jan 2024, one of the reason is this plan name used for free 1GB per day for all IOH subs
);