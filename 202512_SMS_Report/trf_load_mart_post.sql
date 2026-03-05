declare vdt_id date default @vdt_id;

drop table if exists `data-bi-prd-935c.bi_stg.temp_postpaid_sms_report_traffic`;

create table `data-bi-prd-935c.bi_stg.temp_postpaid_sms_report_traffic` as with main_traffic as (
  select date(a.recordopeningtime) as dt_id,
    a.msisdn,
    SUM(a.volume_uplink + a.volume_downlink) as vol
  from `data-dtp-prd-aa1a.smy.ggsn_hourly_summary` a
    left join `data-dtp-prd-aa1a.smy.ar_cst_dly_smy` c on a.msisdn = c.msisdn
    and DATE(c.dt_id) = DATE(a.recordopeningtime)
  where date(a.recordopeningtime) = vdt_id
    and DATE(c.dt_id) = vdt_id
    and (a.volume_downlink + a.volume_uplink) > 0
    and a.rating_group not in ('23111', '55003', '70091')
    and c.msisdn is null
  group by a.recordopeningtime,
    a.msisdn
),
favloc_90 as (
  select msisdn,
    site_id
  from `data-bi-prd-935c.bi_mart.all_90d_fav_loc_dly`
  where dt_id = vdt_id
)
select a.dt_id as `date`,
  c.circle,
  c.region_circle,
  round(sum(vol) /(1024 * 1024 * 1024 * 1024)) as value,
  a.dt_id,
  'IO' as entity,
  'IO' as definition,
  'DAT0003' as kpi_id,
  'traffic_data' as kpi_code,
  date(a.dt_id) as prt_dt
from main_traffic a
  left join favloc_90 b on a.msisdn = b.msisdn
  left join (
    select distinct site_id,
      circle,
      region_circle
    from `data-bi-prd-935c.bi_mart.ref_site`
  ) c on b.site_id = c.site_id
group by 1,
  2,
  3;

delete from `data-bi-prd-935c.bi_stg.stg_postpaid_sms_report`
where dt_id in (
    select distinct(prt_dt)
    from `data-bi-prd-935c.bi_stg.temp_postpaid_sms_report_traffic`
  )
  and kpi_code in (
    select distinct(kpi_code)
    from `data-bi-prd-935c.bi_stg.temp_postpaid_sms_report_traffic`
  );

insert into `data-bi-prd-935c.bi_stg.stg_postpaid_sms_report`
select *
from `data-bi-prd-935c.bi_stg.temp_postpaid_sms_report_traffic`;

delete from `data-bi-prd-935c.bi_mart.postpaid_sms_report`
where dt_id in (
    select distinct(dt_id)
    from `data-bi-prd-935c.bi_stg.stg_postpaid_sms_report`
  );

insert into `data-bi-prd-935c.bi_mart.postpaid_sms_report`
select entity,
  definition,
  kpi_id,
  case
    when kpi_id = 'DAT0003' then 'traffic_data'
    else kpi_code
  end as kpi_code,
  circle,
  region_circle,
  'D-1' as flag,
  sum(value) as metric,
  'POSTPAID' as brand,
  vdt_id as dt_id
from `data-bi-prd-935c.bi_stg.stg_postpaid_sms_report`
where dt_id = vdt_id
group by 1,
  2,
  3,
  4,
  5,
  6,
  dt_id
union all
select entity,
  definition,
  kpi_id,
  case
    when kpi_id = 'DAT0003' then 'traffic_data'
    else kpi_code
  end as kpi_code,
  circle,
  region_circle,
  'D-2' as flag,
  sum(value) as metric,
  'POSTPAID' as brand,
  vdt_id as dt_id
from `data-bi-prd-935c.bi_stg.stg_postpaid_sms_report`
where dt_id = date_sub(vdt_id, interval 1 day)
group by 1,
  2,
  3,
  4,
  5,
  6,
  dt_id
union all
select entity,
  definition,
  kpi_id,
  case
    when kpi_id = 'DAT0003' then 'traffic_data'
    else kpi_code
  end as kpi_code,
  circle,
  region_circle,
  'D-7' as flag,
  sum(value) as metric,
  'POSTPAID' as brand,
  vdt_id as dt_id
from `data-bi-prd-935c.bi_stg.stg_postpaid_sms_report`
where dt_id = date_sub(vdt_id, interval 7 day)
group by 1,
  2,
  3,
  4,
  5,
  6,
  dt_id
union all
select entity,
  definition,
  kpi_id,
  case
    when kpi_id = 'DAT0003' then 'traffic_data'
    else kpi_code
  end as kpi_code,
  circle,
  region_circle,
  'MTD' as flag,
  sum(value) as metric,
  'POSTPAID' as brand,
  vdt_id as dt_id
from `data-bi-prd-935c.bi_stg.stg_postpaid_sms_report`
where dt_id between date_trunc(vdt_id, month)
  and vdt_id
group by 1,
  2,
  3,
  4,
  5,
  6,
  dt_id
union all
select entity,
  definition,
  kpi_id,
  case
    when kpi_id = 'DAT0003' then 'traffic_data'
    else kpi_code
  end as kpi_code,
  circle,
  region_circle,
  'LMTD' as flag,
  metric,
  'POSTPAID' as brand,
  vdt_id as dt_id
from `data-bi-prd-935c.bi_mart.postpaid_sms_report`
where dt_id = date_sub(vdt_id, interval 1 month)
  and brand = 'POSTPAID'
  and flag = 'MTD';