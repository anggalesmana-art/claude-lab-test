declare vdt_id date default @vdt_id;
delete from `data-bi-prd-935c.bi_mart`.kpi_national_tracker_dly where dt_id = vdt_id and brand = 'IM3' and kpi_id in (
'REV0008',
'REV0004',
'REV0005',
'REV0002',
'REV0003',
'REV0009',
'REV0001',
'REV0006',
'REV0007');

insert into `data-bi-prd-935c.bi_mart`.kpi_national_tracker_dly
with rev as (
select 
    date(dt_id) dt_id
    , cast(sum(coalesce(mobo_data_rev,0) + coalesce(fdv_data_rev,0) + coalesce(sp_data_rev,0) + coalesce(sp_fdv_data_rev,0))/1.11 as numeric) as mobo
    , cast(sum(coalesce(ccn_data_revenue,0) - coalesce(ccn_org_combo_addon_voice_rev,0) - coalesce(ccn_org_combo_addon_sms_rev,0))/1.11 as numeric) as organic
    , cast(sum(coalesce(ccn_voice_revenue,0) + coalesce(ccn_org_combo_addon_voice_rev,0) + coalesce(mobo_voice_rev,0) + coalesce(fdv_voice_rev,0))/1.11 as numeric) as voice
    , cast(sum(coalesce(ccn_sms_revenue,0) + coalesce(ccn_org_combo_addon_sms_rev,0) + coalesce(mobo_sms_rev,0) + coalesce(fdv_sms_rev,0) + coalesce(voucher_revenue,0))/1.11 as numeric) as sms
    --, cast(sum((coalesce(ccn_vas_revenue,0) * im3_share_total))/1.11 as numeric) as vas
    , cast(sum( (coalesce(ccn_vas_revenue,0)-coalesce(vas_rev_google,0)) + (coalesce(vas_rev_google,0)*0.15) )/1.11 as numeric) as vas -- VAS
    , cast(sum((coalesce(loan_package_revenue,0) * 1.1) + coalesce(loan_balance_revenue,0) + loan_balance_fee)/1.11 as numeric) as loan_balance
    , cast(sum(
        coalesce(myim3_rev,0) + coalesce(other_rev,0) +
        coalesce(ewallet_ovo_revenue,0) + coalesce(ewallet_gopay_revenue,0) + coalesce(ewallet_shopeepay_revenue,0) +
        coalesce(ewallet_dana_revenue,0) + coalesce(ewallet_imkas_revenue,0) + coalesce(ewallet_linkaja_revenue,0) + coalesce(ewallet_other_revenue,0)
    )/1.11 as numeric) as pgi
from `data-dtp-prd-aa1a.smy.revenue_per_site_extended` a
--left join biadm.ref_vas_share b
    --on left(a.dt_id,6)=b.mth_id
where date(a.dt_id) between vdt_id and vdt_id
group by 1)
select 'IM3' brand, '' kpi_code, 'DLY' flag, mobo as metric, timestamp(current_datetime('+7')) process_dt, 'REV0003' kpi_id, dt_id from rev where mobo>0
union all
select 'IM3' brand, '' kpi_code, 'DLY' flag, organic as metric, timestamp(current_datetime('+7')) process_dt, 'REV0004' kpi_id, dt_id from rev where organic>0
union all
select 'IM3' brand, '' kpi_code, 'DLY' flag, voice as metric, timestamp(current_datetime('+7')) process_dt, 'REV0005' kpi_id, dt_id from rev where voice>0
union all
select 'IM3' brand, '' kpi_code, 'DLY' flag, sms as metric, timestamp(current_datetime('+7')) process_dt, 'REV0006' kpi_id, dt_id from rev where sms>0
union all
select 'IM3' brand, '' kpi_code, 'DLY' flag, vas as metric, timestamp(current_datetime('+7')) process_dt, 'REV0007' kpi_id, dt_id from rev where vas>0
union all
select 'IM3' brand, '' kpi_code, 'DLY' flag, loan_balance as metric, timestamp(current_datetime('+7')) process_dt, 'REV0008' kpi_id, dt_id from rev where loan_balance>0
union all
select 'IM3' brand, '' kpi_code, 'DLY' flag, pgi as metric, timestamp(current_datetime('+7')) process_dt, 'REV0009' kpi_id, dt_id from rev where pgi>0
union all
-- total Data
select 'IM3' brand, '' kpi_code, 'DLY' flag, mobo+organic+pgi as metric, timestamp(current_datetime('+7')) process_dt, 'REV0002' kpi_id, dt_id from rev where mobo+organic+pgi>0
union all
-- total rev
select 'IM3' brand, '' kpi_code, 'DLY' flag, mobo+organic+pgi+voice+sms+vas+loan_balance as metric, timestamp(current_datetime('+7')) process_dt, 'REV0001' kpi_id, dt_id from rev where mobo+organic+pgi+voice+sms+vas+loan_balance>0
;
 