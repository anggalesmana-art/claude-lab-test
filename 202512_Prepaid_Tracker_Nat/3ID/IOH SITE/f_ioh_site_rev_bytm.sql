DECLARE vdt_id DATE DEFAULT @vdt_id;


delete from `data-bi-prd-935c.bi_mart.project_ioh_kpi_daily_tracker_site` where CAST(load_dt_sk_id AS DATE) = vdt_id  and kpi_code in ('rev_organic','rev_mobo','rev_nondata');
 
insert into `data-bi-prd-935c.bi_mart.project_ioh_kpi_daily_tracker_site`
 select load_dt_sk_id, entity, kpi_code, definition,dt, site_id, sum(rev) as rev, remark,dtm 
 from
 (
select dt_id as load_dt_sk_id, 'H3I' as entity, 'rev_mobo' as kpi_code, 'IOH' as definition, dt_id as dt,
site_id,
sum(case when (revenue_flg = 'PREPAID' or revenue_flg is null) then 
(coalesce(mobo_sp_data_rev,0)+
coalesce(fdv_data_rev,0)+ 
coalesce(voucher_forfeit_revenue,0)+
coalesce(mobo_rita_data_rev,0)+
coalesce(mobo_evc_rev,0))/1.11
else 
(coalesce(mobo_sp_data_rev,0)+
coalesce(fdv_data_rev,0)+ 
coalesce(voucher_forfeit_revenue,0)+
coalesce(mobo_rita_data_rev,0)+
coalesce(mobo_evc_rev,0))
end) as rev,
'' as remark, 
current_timestamp() as dtm
from `data-dtptechm-prd-c7ca.dwh.h3i_revenue_per_site_extended`
where dt_id = vdt_id 
group by 1,2,3,4,5,6,8,9

union all

select cast(dt_id as date) as load_dt_sk_id, 'H3I' as entity, 'rev_mobo' as kpi_code, 'IOH' as definition, cast(dt_id as date) as dt,
physical_site_id,
sum(case when (revenue_flag = 'PREPAID' or revenue_flag is null) then revenue/1.11 else revenue end) as rev,
'' as remark, 
current_timestamp() as dtm
from `data-dtptechm-prd-c7ca.dwh.h3i_revenue_per_site_extended_others_detail` a
where dt_id is not null and date(dt_id) = vdt_id 
and process_nm in ('RITA_P3PRICE_AMORT')
group by 1,2,3,4,5,6,8,9 
 ) a
 group by 1,2,3,4,5,6,8,9;

insert into `data-bi-prd-935c.bi_mart.project_ioh_kpi_daily_tracker_site`
 select load_dt_sk_id, entity, kpi_code, definition, dt , site_id, sum(rev) as rev, remark, dtm 
 from
 (
select dt_id as load_dt_sk_id, 'H3I' as entity, 'rev_organic' as kpi_code, 'IOH' as definition, dt_id as dt,
site_id,
sum(case when (revenue_flg = 'PREPAID' or revenue_flg is null) then 
(coalesce(ccn_data_revenue,0) + coalesce(loan_package_revenue,0))/1.11 
else coalesce(ccn_data_revenue,0) + coalesce(loan_package_revenue,0) end) as rev,
'' as remark, 
current_timestamp() as dtm
from `data-dtptechm-prd-c7ca.dwh.h3i_revenue_per_site_extended`
where dt_id = vdt_id 
group by 1,2,3,4,5,6,8,9
 ) a
 group by 1,2,3,4,5,6,8,9;

insert into `data-bi-prd-935c.bi_mart.project_ioh_kpi_daily_tracker_site`
 select load_dt_sk_id , entity, kpi_code, definition, dt, site_id, sum(rev) as rev, remark, dtm 
 from
 (
select dt_id as load_dt_sk_id, 'H3I' as entity, 'rev_nondata' as kpi_code, 'IOH' as definition, dt_id as dt,
site_id,
sum(
case when (revenue_flg = 'PREPAID' or revenue_flg is null) then
(
coalesce(loan_balance_fee,0)+
coalesce(balance_transfer_revenue,0)+
coalesce(ccn_vas_revenue,0)+
coalesce(mobo_sp_vas_rev,0)+
coalesce(mobo_rita_vas_rev,0)+
coalesce(ccn_sms_revenue,0)+
coalesce(fdv_sms_rev,0)+
coalesce(mobo_sp_sms_rev,0)+
coalesce(mobo_rita_sms_rev,0)+
coalesce(other_mms_revenue,0)+
coalesce(mobo_sp_voice_rev,0)+
coalesce(fdv_voice_rev,0)+
coalesce(mobo_rita_voice_rev,0)+
coalesce(ccn_voice_revenue,0)+
coalesce(ccn_voice_rev_ppu_roaming,0)+
coalesce(ccn_sms_rev_ppu_roaming,0)+
coalesce(mobo_evc_roaming_rev,0)+
coalesce(other_roaming_rev,0))/1.11
--coalesce(other_payu_revenue,0))/1.11 --Move to "Organic + PGI" and "Non Data" using table dwh.h3i_revenue_per_site_extended_others_detail
else
(
coalesce(loan_balance_fee,0)+
coalesce(balance_transfer_revenue,0)+
coalesce(ccn_vas_revenue,0)+
coalesce(mobo_sp_vas_rev,0)+
coalesce(mobo_rita_vas_rev,0)+
coalesce(ccn_sms_revenue,0)+
coalesce(fdv_sms_rev,0)+
coalesce(mobo_sp_sms_rev,0)+
coalesce(mobo_rita_sms_rev,0)+
coalesce(other_mms_revenue,0)+
coalesce(mobo_sp_voice_rev,0)+
coalesce(fdv_voice_rev,0)+
coalesce(mobo_rita_voice_rev,0)+
coalesce(ccn_voice_revenue,0)+
coalesce(ccn_voice_rev_ppu_roaming,0)+
coalesce(ccn_sms_rev_ppu_roaming,0)+
coalesce(mobo_evc_roaming_rev,0)+
coalesce(other_roaming_rev,0)
--coalesce(other_payu_revenue,0) --Move to "Organic + PGI" and "Non Data" using table dwh.h3i_revenue_per_site_extended_others_detail
)
end ) as rev,
'' as remark, 
current_timestamp() as dtm
from `data-dtptechm-prd-c7ca.dwh.h3i_revenue_per_site_extended`
where dt_id = vdt_id 
group by 1,2,3,4,5,6,8,9

union all

select cast(dt_id as date) as load_dt_sk_id, 'H3I' as entity, 'rev_nondata' as kpi_code, 'IOH' as definition, cast(dt_id as date) as dt,
physical_site_id as site_id,
sum(case when (revenue_flag = 'PREPAID' or revenue_flag is null) then revenue/1.11 else revenue end) as rev,
'' as remark, 
current_timestamp() as dtm
from `data-dtptechm-prd-c7ca.dwh.h3i_revenue_per_site_extended_others_detail` a
where dt_id is not null and date(dt_id) = vdt_id 
--and service_type = 'ROAMING'
and process_nm in ('EVC MARKUP',
'MARKUP_RITA',
'MARKUP_UNLOCK',
'BIMA MARKUP'
) and service_type <> 'ROAMING' --exclude roaming because has been counted on other_roaming_rev
group by 1,2,3,4,5,6,8,9
 
union all

select cast(dt_id as date) as load_dt_sk_id, 'H3I' as entity, 'rev_nondata' as kpi_code, 'IOH' as definition, cast(dt_id as date) as dt,
physical_site_id as site_id,
sum(case when (revenue_flag = 'PREPAID' or revenue_flag is null) then revenue/1.11 else revenue end) as rev,
'' as remark, 
current_timestamp() as dtm
from `data-dtptechm-prd-c7ca.dwh.h3i_revenue_per_site_extended_others_detail` a
where dt_id is not null and date(dt_id) = vdt_id 
and service_type = 'OTHER_VAS' 
and process_nm in ('ONE-OFF CDR') --'TOPUP'
group by 1,2,3,4,5,6,8,9

union all

select cast(dt_id as date) as load_dt_sk_id, 'H3I' as entity, 'rev_nondata' as kpi_code, 'IOH' as definition, cast(dt_id as date) as dt,
physical_site_id as site_id,
sum(case when (revenue_flag = 'PREPAID' or revenue_flag is null) then revenue/1.11 else revenue end) as rev,
'' as remark, 
current_timestamp() as dtm
from `data-dtptechm-prd-c7ca.dwh.h3i_revenue_per_site_extended_others_detail` a
where dt_id is not null and date(dt_id) = vdt_id 
and process_nm in ('ADDON_PULSA', 'CEPEK AMORTIZATION', 'MAIN_BALANCE_OTHERS_ADJUSTMENT', 'RITA_TOPUP', 'TOPUP', 'UNTAGGED_COMMISSION')
and service_type_detail in ('BROADBAND', 'VAS_PARTNER', 'OTHERS')
group by 1,2,3,4,5,6,8,9

union all


--Add this start 01 Jun 2025 onwards

select cast(dt_id as date) as load_dt_sk_id, 'H3I' as entity, 'rev_nondata' as kpi_code, 'IOH' as definition, cast(dt_id as date) as dt,
physical_site_id,
sum(case when (revenue_flag = 'PREPAID' or revenue_flag is null) then revenue/1.11 else revenue end) as rev,
'' as remark, 
current_timestamp() as dtm
from `data-dtptechm-prd-c7ca.dwh.h3i_revenue_per_site_extended_others_detail` a
where date(dt_id) = vdt_id 
and service_type = 'OTHER_PAYU' and service_type_detail in ('GPRS','GPRS_PACKAGE') and process_nm in ('EVC MARKUP', 'MARKUP_RITA', 'MARKUP_UNLOCK', 'BIMA MARKUP')
group by 1,2,3,4,5,6,8,9

 ) a
 group by 1,2,3,4,5,6,8,9;