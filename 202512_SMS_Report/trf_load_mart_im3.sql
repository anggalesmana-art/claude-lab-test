declare vdt_id date default @vdt_id;

delete from `data-bi-prd-935c.bi_stg.circle_im3_sms_report_kpi`
where date(dt_id) between date_trunc(parse_date('%Y%m%d', vdt_id), month) and parse_date('%Y%m%d', vdt_id)
  and (kpi_id like 'DAT%' or kpi_id like 'REV%');

insert into `data-bi-prd-935c.bi_stg.circle_im3_sms_report_kpi` 
with revenue_data as (
    select date(dt_id) as dt_id, * except (dt_id)
    from `data-dtp-prd-aa1a.smy.revenue_per_site_extended`
    where date(dt_id) = parse_date('%Y%m%d', vdt_id) 
    and ccn_vas_revenue >= -3000000000
  ),
  mart as (
    select dt_id,
      'REV0002' kpi_id,
      'rev_organic' kpi_code,
      site_id,
      sum(ccn_data_revenue - ccn_org_combo_addon_voice_rev - ccn_org_combo_addon_sms_rev + myim3_rev + ewallet_ovo_revenue + ewallet_gopay_revenue + ewallet_shopeepay_revenue + ewallet_dana_revenue + ewallet_imkas_revenue + ewallet_linkaja_revenue + ewallet_other_revenue) / 1.11 as rev_net
    from revenue_data
    group by 1,
      4
    union all
    select dt_id,
      'REV0007' kpi_id,
      'rev_loan' kpi_code,
      site_id,
      sum((loan_package_revenue * 1.1) + loan_balance_revenue + loan_balance_fee) / 1.11 as rev_net
    from revenue_data
    group by 1,
      4
    union all
    select dt_id,
      'REV0001' kpi_id,
      'rev_mobo' kpi_code,
      site_id,
      sum(mobo_data_rev + fdv_data_rev + sp_data_rev + sp_fdv_data_rev) / 1.11 as rev_net
    from revenue_data
    group by 1,
      4
    union all
    select dt_id,
      'REV0003' kpi_id,
      'rev_vas' as kpi_code,
      site_id,
      -- sum (ccn_vas_revenue * 0.442907977) / 1.11 as vas_rev
      sum( (coalesce(ccn_vas_revenue,0) - coalesce(vas_rev_google,0)) + (coalesce(vas_rev_google,0)*0.15) ) / 1.11 as vas_rev
    from revenue_data
    group by 1,
      4
    union all
    select dt_id,
      'REV0004' kpi_id,
      'rev_voice' as kpi_code,
      site_id,
      sum(ccn_voice_revenue + ccn_org_combo_addon_voice_rev + mobo_voice_rev + fdv_voice_rev) / 1.11 as voice_rev
    from revenue_data
    group by 1,
      4
    union all
    select dt_id,
      'REV0005' kpi_id,
      'rev_sms' as kpi_code,
      site_id,
      sum(ccn_sms_revenue + ccn_org_combo_addon_sms_rev + mobo_sms_rev + fdv_sms_rev + voucher_revenue) / 1.11 as sms_rev
    from revenue_data
    group by 1,
      4
    union all
    select dt_id,
      'REV0006' kpi_id,
      'rev_other' as kpi_code,
      site_id,
      sum(other_rev) / 1.11 as other_rev
    from revenue_data
    group by 1,
      4
    union all
    select dt_id,
      'DAT0001' kpi_id,
      'traffic_voice' kpi_code,
      site_id,
      sum(voice_dur) voice_dur
    from revenue_data
    group by 1,
      4
    union all
    select dt_id,
      'DAT0002' kpi_id,
      'traffic_sms' kpi_code,
      site_id,
      sum(sms_hits) sms_hits
    from revenue_data
    group by 1,
      4
    union all
    select dt_id,
      'DAT0003' kpi_id,
      'traffic_data' kpi_code,
      site_id,
      sum(ggsn_data_volume) /(1024 * 1024 * 1024 * 1024) data_vol_tb
    from revenue_data
    group by 1,
      4
  )
select dt_id as `date`,
  circle,
  region_circle,
  sum(rev_net) as `value`,
  date(dt_id) as dt_id,
  'IO' as entity,
  'IO' definition,
  kpi_id,
  kpi_code,
  dt_id as prt_dt
from mart a
  left join (
    select distinct(site_id) as site_id, circle, region_circle
    from `data-bi-prd-935c.bi_dm.ref_site`
  ) b on a.site_id = b.site_id
group by 1, 2, 3, 8, 9;



-- Merging into main datamart
delete from `data-bi-prd-935c.bi_mart.sms_report_circle`
where brand = "IM3" and date(dt_id) = parse_date('%Y%m%d', vdt_id);

insert into `data-bi-prd-935c.bi_mart.sms_report_circle` 
select entity,
  definition,
  kpi_id,
  case
    when kpi_id = "DAT0003" then "traffic_data"
    else kpi_code
  end as kpi_code,
  circle,
  region_circle,
  "D-1" flag,
  sum(value) as metric,
  "IM3" brand,
  date(parse_date('%Y%m%d', vdt_id)) as dt_id
from `data-bi-prd-935c.bi_stg.circle_im3_sms_report_kpi`
where date(dt_id) = parse_date('%Y%m%d', vdt_id)
group by 1, 2, 3, 4, 5, 6, dt_id
union all
select entity,
  definition,
  kpi_id,
  case
    when kpi_id = "DAT0003" then "traffic_data"
    else kpi_code
  end kpi_code,
  circle,
  region_circle,
  "D-2" flag,
  sum(value) metric,
  "IM3" brand,
  date(parse_date('%Y%m%d', vdt_id)) as dt_id
from `data-bi-prd-935c.bi_stg.circle_im3_sms_report_kpi`
where date(dt_id) = date_sub(parse_date('%Y%m%d', vdt_id), interval 1 day)
group by 1, 2, 3, 4, 5, 6, dt_id
union all
select entity,
  definition,
  kpi_id,
  case
    when kpi_id = 'DAT0003' then 'traffic_data'
    else kpi_code
  end kpi_code,
  circle,
  region_circle,
  "D-7" flag,
  sum(value) metric,
  "IM3" brand,
  date(parse_date('%Y%m%d', vdt_id)) as dt_id
from `data-bi-prd-935c.bi_stg.circle_im3_sms_report_kpi`
where date(dt_id) = date_sub(parse_date('%Y%m%d', vdt_id), interval 7 day)
group by 1, 2, 3, 4, 5, 6, dt_id
union all
select 
  entity,
  definition,
  kpi_id,
  kpi_code,
  circle,
  region_circle,
  flag,
  case when kpi_code like '%vlr%' or kpi_code like '%uu%' then avg(value) else sum(value) end metric,
  brand,
  dt_id
from (
  select entity,
    definition,
    kpi_id,
    case
      when kpi_id = 'DAT0003' then 'traffic_data'
      else kpi_code
    end kpi_code,
    circle,
    region_circle,
    "MTD" flag,
    value,
    "IM3" brand,
    date(parse_date('%Y%m%d', vdt_id)) as dt_id
  from `data-bi-prd-935c.bi_stg.circle_im3_sms_report_kpi`
  where dt_id between date_trunc(parse_date('%Y%m%d', vdt_id), month) and parse_date('%Y%m%d', vdt_id)
) a
group by 1, 2, 3, 4, 5, 6, 7, 9, 10
union all
select entity,
  definition,
  kpi_id,
  kpi_code,
  circle,
  region_circle,
  "LMTD" flag,
  metric,
  "IM3" as brand,
  parse_date('%Y%m%d', vdt_id) as dt_id
from `data-bi-prd-935c.bi_mart.sms_report_circle`
where date(dt_id) = date_sub(parse_date('%Y%m%d', vdt_id), interval 1 month)
and brand = "IM3" and flag = "MTD";