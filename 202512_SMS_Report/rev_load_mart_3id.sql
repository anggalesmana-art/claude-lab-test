declare vdt_id date default @vdt_id;

delete from `data-bi-prd-935c.bi_stg.circle_tri_sms_report_kpi`
where date(dt_id) between date_trunc(parse_date('%Y%m%d', vdt_id), month) and parse_date('%Y%m%d', vdt_id)
and (kpi_id like 'REV%' or kpi_id like 'DAT%');

insert into `data-bi-prd-935c.bi_stg.circle_tri_sms_report_kpi` with tmp_extended as (
  select date(dt_id) as dt_id, * except(dt_id)
  from `data-dtptechm-prd-c7ca.dwh.h3i_revenue_per_site_extended`
  where date(dt_id) between date_trunc(parse_date('%Y%m%d', vdt_id), month) and parse_date('%Y%m%d', vdt_id)
), tmp_extended_others as (
  select date(dt_id) as dt_id, * except(dt_id)
  from `data-dtptechm-prd-c7ca.dwh.h3i_revenue_per_site_extended_others_detail`
  where date(dt_id) between date_trunc(parse_date('%Y%m%d', vdt_id), month) and parse_date('%Y%m%d', vdt_id)
)
select dt_id,
  'H3I' entity,
  'IOH' definition,
  kpi_id,
  kpi_code,
  sum(rev) as value,
  concat('H3I_IO_', cast(format_datetime('%Y%m%d%H%M%S', current_datetime("UTC+7")) as string), '_JID_1') as Jobid,
  dt_id load_dt,
  b.circle,
  b.region_circle
from (
    select dt_id,
      'REV0001' kpi_id,
      'rev_mobo' as kpi_code,
      site_id,
      sum(coalesce(mobo_sp_data_rev, 0) + coalesce(fdv_data_rev, 0) + coalesce(voucher_forfeit_revenue, 0) + coalesce(mobo_rita_data_rev, 0) + coalesce(mobo_evc_rev, 0)) / 1.11 as rev
    from tmp_extended
    group by 1, 4
    union all
    select dt_id,
      'REV0001' kpi_id,
      'rev_mobo' as kpi_code,
      physical_site_id as site_id,
      (sum(revenue) * -1) / 1.11 as rev
    from tmp_extended_others a
    where process_nm in ('RITA_P3PRICE_AMORT')
    group by 1, 4
    union all
    select dt_id,
      'REV0002' kpi_id,
      'rev_organic' as kpi_code,
      site_id,
      sum(coalesce(ccn_data_revenue, 0) + coalesce(loan_package_revenue, 0)) / 1.11 as rev
    from tmp_extended
    group by 1, 4
    union all
    select dt_id,
      'REV0007' kpi_id,
      'rev_loan' as kpi_code,
      site_id,
      sum(coalesce(loan_balance_fee, 0) + coalesce(balance_transfer_revenue, 0)) / 1.11 as rev
    from tmp_extended
    group by 1, 4
    union all
    select dt_id,
      'REV0006' kpi_id,
      'rev_other' as kpi_code,
      site_id,
      sum(coalesce(ccn_voice_rev_ppu_roaming, 0) + coalesce(ccn_sms_rev_ppu_roaming, 0) + coalesce(mobo_evc_roaming_rev, 0) + coalesce(other_roaming_rev, 0)) / 1.11 as rev
    from tmp_extended
    group by 1, 4
    union all
    select dt_id,
      'REV0006' kpi_id,
      'rev_other' as kpi_code,
      physical_site_id as site_id,
      sum(revenue) / 1.11 as rev
    from tmp_extended_others a
    where process_nm in ('EVC MARKUP', 'MARKUP_RITA', 'MARKUP_UNLOCK')
      and service_type <> 'ROAMING' --exclude roaming because has been counted on other_roaming_rev	
    group by 1, 4
    union all
    select dt_id,
      'REV0006' kpi_id,
      'rev_other' as kpi_code,
      physical_site_id as site_id,
      sum(revenue) / 1.11 as rev
    from tmp_extended_others a
    where service_type in ('OTHER-VAS', 'OTHER_VAS')
      and process_nm in ('ONE-OFF CDR') --'TOPUP'	
    group by 1, 4
    union all
    select dt_id,
      'REV0003' kpi_id,
      'rev_vas' as kpi_code,
      site_id,
      SUM(coalesce(ccn_vas_revenue, 0) + coalesce(mobo_sp_vas_rev, 0) + coalesce(mobo_rita_vas_rev, 0)) / 1.11 as rev
    from tmp_extended a
    group by 1, 4
    union all
    select dt_id,
      'REV0004' kpi_id,
      'rev_voice' as kpi_code,
      site_id,
      SUM(coalesce(mobo_sp_voice_rev, 0) + coalesce(fdv_voice_rev, 0) + coalesce(mobo_rita_voice_rev, 0) + coalesce(ccn_voice_revenue, 0)) / 1.11 as rev
    from tmp_extended a
    group by 1, 4
    union all
    select dt_id,
      'REV0005' kpi_id,
      'rev_sms' as kpi_code,
      site_id,
      SUM(coalesce(ccn_sms_revenue, 0) + coalesce(fdv_sms_rev, 0) + coalesce(mobo_sp_sms_rev, 0) + coalesce(mobo_rita_sms_rev, 0) + coalesce(other_mms_revenue, 0)) / 1.11 as rev
    from tmp_extended a
    group by 1, 4
    union all
    select dt_id as dt,
      'DAT0001' as kpi_id,
      'traffic_voice' as kpi_code,
      site_id,
      sum(voice_dur) / 60 as voice_dur
    from tmp_extended
    group by 1, 4
    union all
    select dt_id as dt,
      'DAT0002' as kpi_id,
      'traffic_sms' as kpi_code,
      site_id,
      sum(sms_hits) as sms_hits
    from tmp_extended
    group by 1, 4
    union all
    select dt_id,
      'DAT0003' as kpi_id,
      'traffic_data' as kpi_code,
      site_id,
      (sum(ggsn_data_volume) / 1024) as data_vol
    from tmp_extended
    group by 1, 4
  ) a
  left outer join (
    select distinct site_id,
      circle,
      region_circle
    from `data-dtptechm-prd-c7ca.ioh_biadm.ref_site_h3i`
  ) b on case
    when length(a.site_id) < 6 then LPAD(trim(a.site_id), 6, '0')
    else a.site_id
  end = case
    when length(b.site_id) < 6 then LPAD(trim(b.site_id), 6, '0')
    else b.site_id
  end
group by 1, 4, 5, 9, 10;


-- Merging into main datamart
delete from `data-bi-prd-935c.bi_mart.sms_report_circle`
where brand = "TRI" and date(dt_id) = parse_date('%Y%m%d', vdt_id);

insert into `data-bi-prd-935c.bi_mart.sms_report_circle`
select entity,
  definition,
  kpi_id,
  kpi_code,
  circle,
  region_circle,
  "D-1" flag,
  sum(value) metric,
  "TRI" brand,
  date(parse_date('%Y%m%d', vdt_id)) as dt_id
from `data-bi-prd-935c.bi_stg.circle_tri_sms_report_kpi`
where date(dt_id) = parse_date('%Y%m%d', vdt_id)
group by 1, 2, 3, 4, 5, 6, dt_id
union all
select entity,
  definition,
  kpi_id,
  kpi_code,
  circle,
  region_circle,
  "D-2" flag,
  sum(value) metric,
  "TRI" brand,
  date(parse_date('%Y%m%d', vdt_id)) as dt_id
from `data-bi-prd-935c.bi_stg.circle_tri_sms_report_kpi`
where date(dt_id) = date_sub(parse_date('%Y%m%d', vdt_id), interval 1 day)
group by 1, 2, 3, 4, 5, 6, dt_id
union all
select entity,
  definition,
  kpi_id,
  kpi_code,
  circle,
  region_circle,
  "D-7" flag,
  sum(value) metric,
  "TRI" brand,
  date(parse_date('%Y%m%d', vdt_id)) as dt_id
from `data-bi-prd-935c.bi_stg.circle_tri_sms_report_kpi`
where date(dt_id) = date_sub(parse_date('%Y%m%d', vdt_id), interval 7 day)
group by 1, 2, 3, 4, 5, 6, dt_id
union all
select entity,
  definition,
  kpi_id,
  kpi_code,
  circle,
  region_circle,
  "MTD" flag,
  case when (kpi_code like '%vlr%' or kpi_code like '%uu%') then avg(value) else sum(value) end metric,
  "TRI" brand,
  date(parse_date('%Y%m%d', vdt_id)) as dt_id
from `data-bi-prd-935c.bi_stg.circle_tri_sms_report_kpi`
where dt_id between date_trunc(parse_date('%Y%m%d', vdt_id), month) and parse_date('%Y%m%d', vdt_id)
group by 1, 2, 3, 4, 5, 6, dt_id
union all
select entity,
  definition,
  kpi_id,
  kpi_code,
  circle,
  region_circle,
  "LMTD" flag,
  metric,
  "TRI" brand,
  date(parse_date('%Y%m%d', vdt_id)) as dt_id
from `data-bi-prd-935c.bi_mart.sms_report_circle`
where date(dt_id) = date_sub(parse_date('%Y%m%d', vdt_id), interval 1 month)
and brand = "TRI" and flag = "MTD";