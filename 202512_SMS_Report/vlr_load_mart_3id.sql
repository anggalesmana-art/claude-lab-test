declare vdt_id date default @vdt_id;

delete from `data-bi-prd-935c.bi_stg.circle_tri_sms_report_kpi`
where date(dt_id) between date_trunc(parse_date('%Y%m%d', vdt_id), month) and parse_date('%Y%m%d', vdt_id)
and kpi_code like 'vlr_%';

insert into `data-bi-prd-935c.bi_stg.circle_tri_sms_report_kpi`
select load_dt_sk_id as dt_id,
  'H3I' as entity,
  'IOH' as definition,
  'SUB0006' kpi_id,
  'vlr_daily' as kpi_code,
  count(distinct msisdn) as value,
  concat('H3I_IO_', cast(format_datetime('%Y%m%d%H%M%S', current_datetime('UTC+7')) as string), '_JID_1') as jobid,
  load_dt_sk_id load_dt,
  b.circle,
  b.region_circle
from `data-dtptechm-prd-c7ca.mis.fct_vlr_sites` a
  left outer join (select distinct site_id,circle,region_circle from `data-dtptechm-prd-c7ca.ioh_biadm.ref_site_h3i`) b on case
    when length(a.siteid_nm) < 6 then LPAD(trim(a.siteid_nm), 6, '0') else a.siteid_nm
  end = case
    when length(b.site_id) < 6 then LPAD(trim(b.site_id), 6, '0') else b.site_id
  end
where date(load_dt_sk_id) between date_trunc(parse_date('%Y%m%d', vdt_id), month) and parse_date('%Y%m%d', vdt_id)
group by 1, 9, 10
union all
select load_dt_sk_id as dt_id,
  'H3I' entity,
  'IOH' definition,
  case
    when substring(coalesce(ggsn_system, cem_system, vlr_system, pcrf_system), 1, 2) = '5G' then 'SUB0007'
    when substring(coalesce(ggsn_system, cem_system, vlr_system, pcrf_system), 1, 2) = '4G' then 'SUB0008'
    when substring(coalesce(ggsn_system, cem_system, vlr_system, pcrf_system), 1, 2) = '3G' then 'SUB0009'
    when substring(coalesce(ggsn_system, cem_system, vlr_system, pcrf_system), 1, 2) = '2G' then 'SUB0010'
    else 'SUB0008'
  end kpi_id,
  case
    when substring(coalesce(ggsn_system, cem_system, vlr_system, pcrf_system), 1, 2) = '5G' then 'vlr_daily_5g'
    when substring(coalesce(ggsn_system, cem_system, vlr_system, pcrf_system), 1, 2) = '4G' then 'vlr_daily_4g'
    when substring(coalesce(ggsn_system, cem_system, vlr_system, pcrf_system), 1, 2) = '3G' then 'vlr_daily_3g'
    when substring(coalesce(ggsn_system, cem_system, vlr_system, pcrf_system), 1, 2) = '2G' then 'vlr_daily_2g'
    else 'vlr_daily_4g'
  end kpi_code,
  count(distinct msisdn) as value,
  concat('H3I_IO_', cast(format_datetime('%Y%m%d%H%M%S', current_datetime('UTC+7')) as string), '_JID_1') as jobid,
  load_dt_sk_id load_dt,
  b.circle,
  b.region_circle
from `data-dtptechm-prd-c7ca.mis.fct_vlr_sites` a
  left outer join (select distinct site_id, circle, region_circle from `data-dtptechm-prd-c7ca.ioh_biadm.ref_site_h3i`) b on case
    when length(a.siteid_nm) < 6 then LPAD(trim(a.siteid_nm), 6, '0')
    else a.siteid_nm
  end = case
    when length(b.site_id) < 6 then LPAD(trim(b.site_id), 6, '0')
    else b.site_id
  end
where date(load_dt_sk_id) between date_trunc(parse_date('%Y%m%d', vdt_id), month) and parse_date('%Y%m%d', vdt_id)
group by 1, 4, 5, 9, 10;

-- Merging into main datamart
delete from `data-bi-prd-935c.bi_mart.sms_report_circle`
where brand = 'TRI' and date(dt_id) = parse_date('%Y%m%d', vdt_id)
and kpi_code like 'vlr_%' and brand = 'TRI';

insert into `data-bi-prd-935c.bi_mart.sms_report_circle`
select entity,
  definition,
  kpi_id,
  kpi_code,
  circle,
  region_circle,
  'D-1' flag,
  sum(value) metric,
  'TRI' brand,
  date(parse_date('%Y%m%d', vdt_id)) as dt_id
from `data-bi-prd-935c.bi_stg.circle_tri_sms_report_kpi`
where date(dt_id) = parse_date('%Y%m%d', vdt_id)
and kpi_code like 'vlr_%'
group by 1, 2, 3, 4, 5, 6, dt_id
union all
select entity,
  definition,
  kpi_id,
  kpi_code,
  circle,
  region_circle,
  'D-2' flag,
  sum(value) metric,
  'TRI' brand,
  date(parse_date('%Y%m%d', vdt_id)) as dt_id
from `data-bi-prd-935c.bi_stg.circle_tri_sms_report_kpi`
where date(dt_id) = date_sub(parse_date('%Y%m%d', vdt_id), interval 1 day)
and kpi_code like 'vlr_%'
group by 1, 2, 3, 4, 5, 6, dt_id
union all
select entity,
  definition,
  kpi_id,
  kpi_code,
  circle,
  region_circle,
  'D-7' flag,
  sum(value) metric,
  'TRI' brand,
  date(parse_date('%Y%m%d', vdt_id)) as dt_id
from `data-bi-prd-935c.bi_stg.circle_tri_sms_report_kpi`
where date(dt_id) = date_sub(parse_date('%Y%m%d', vdt_id), interval 7 day)
and kpi_code like 'vlr_%'
group by 1, 2, 3, 4, 5, 6, dt_id
union all
select entity,
  definition,
  kpi_id,
  kpi_code,
  circle,
  region_circle,
  'MTD' flag,
  case when (kpi_code like '%vlr%' or kpi_code like '%uu%') then avg(value) else sum(value) end metric,
  'TRI' brand,
  date(parse_date('%Y%m%d', vdt_id)) as dt_id
from `data-bi-prd-935c.bi_stg.circle_tri_sms_report_kpi`
where dt_id between date_trunc(parse_date('%Y%m%d', vdt_id), month) and parse_date('%Y%m%d', vdt_id)
and kpi_code like 'vlr_%'
group by 1, 2, 3, 4, 5, 6, dt_id
union all
select entity,
  definition,
  kpi_id,
  kpi_code,
  circle,
  region_circle,
  'LMTD' flag,
  metric,
  'TRI' brand,
  date(parse_date('%Y%m%d', vdt_id)) as dt_id
from `data-bi-prd-935c.bi_mart.sms_report_circle`
where date(dt_id) = date_sub(parse_date('%Y%m%d', vdt_id), interval 1 month)
and kpi_code like 'vlr_%'
and brand = 'TRI' and flag = 'MTD';