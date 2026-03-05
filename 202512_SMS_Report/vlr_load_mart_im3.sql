declare vdt_id date default @vdt_id;

drop table if exists `data-bi-prd-935c.bi_stg.temp_final_sms_report_circle_vlr`;

create table `data-bi-prd-935c.bi_stg.temp_final_sms_report_circle_vlr` as
with `5g_uu` as (
  select distinct(date(dt_id)) as dt_id, msisdn
  from `data-dtp-prd-aa1a.stg.stg_nio_appsrtgout_5g`
  where date(dt_id) = parse_date('%Y%m%d', vdt_id)
    and (volume_in + volume_out) > 0
),
final_source as (
  select
    date(a.dt_id) as dt_id,
    a.msisdn as msisdn,
    a.site_id as site_id,
    technology
  from (
    select 
      date(a.dt_id) as dt_id,
      a.msisdn as msisdn,
      a.site_id as site_id,
      case
        when c.msisdn is not null then '5G'
        when technology is null then '4G'
        else technology
      end as technology,
      row_number() over (partition by a.msisdn order by technology desc) as rn
    from `data-bi-prd-935c.bi_dm.vlr_site_wise` a
    join `data-dtp-prd-aa1a.smy.ar_cst_dly_smy` b
      on a.msisdn = b.msisdn and date(a.dt_id) = date(b.dt_id)
    left join `5g_uu` c on a.msisdn = c.msisdn
    where date(a.dt_id) = parse_date('%Y%m%d', vdt_id)
    and date(b.dt_id) = parse_date('%Y%m%d', vdt_id)
  ) a
  where rn = 1
)
select
  date(a.dt_id) as `date`,
  b.circle,
  b.region_circle,
  count(distinct(a.msisdn)) as `value`,
  date(a.dt_id) as dt_id,
  'IO' as entity,
  'IO' as definition,
  case
    when technology = '5G' then 'SUB0007'
    when technology = '4G' then 'SUB0008'
    when technology = '3G' then 'SUB0009'
    when technology = '2G' then 'SUB0010'
  end kpi_id,
  case
    when technology = '5G' then 'vlr_daily_5g'
    when technology = '4G' then 'vlr_daily_4g'
    when technology = '3G' then 'vlr_daily_3g'
    when technology = '2G' then 'vlr_daily_2g'
  end kpi_code,
  date(a.dt_id) as prt_dt
from final_source a
  left join (
    select distinct(site_id) as site_id, circle, region_circle 
    from `data-bi-prd-935c.bi_mart.ref_site`
  ) b on a.site_id = b.site_id
group by 1, 2, 3, 8, 9
union all
select date(a.dt_id) as `date`,
  b.circle,
  b.region_circle,
  count(distinct(a.msisdn)) as value,
  date(a.dt_id) as dt_id,
  'IO' as entity,
  'IO' definition,
  'SUB0006' kpi_id,
  'vlr_daily' kpi_code,
  date(a.dt_id) as prt_dt
from `data-bi-prd-935c.bi_dm.vlr_site_wise` a
  left join (
    select distinct(site_id) as site_id, circle, region_circle 
    from `data-bi-prd-935c.bi_mart.ref_site`
  ) b on a.site_id = b.site_id
  join `data-dtp-prd-aa1a.smy.ar_cst_dly_smy` c 
    on a.msisdn = c.msisdn and date(a.dt_id) = date(c.dt_id)
where date(a.dt_id) = parse_date('%Y%m%d', vdt_id)
and date(c.dt_id) = parse_date('%Y%m%d', vdt_id)
group by 1, 2, 3;

delete from `data-bi-prd-935c.bi_mart.sms_report_circle`
where kpi_id in (select distinct(kpi_id) from `data-bi-prd-935c.bi_stg.temp_final_sms_report_circle_vlr`)
and dt_id in (select distinct(dt_id) from `data-bi-prd-935c.bi_stg.temp_final_sms_report_circle_vlr`)
and brand = 'IM3';

insert into `data-bi-prd-935c.bi_mart.sms_report_circle`
select entity,
  definition,
  kpi_id,
  case
    when kpi_id = 'DAT0003' then 'traffic_data'
    else kpi_code
  end kpi_code,
  circle,
  region_circle,
  'D-1' flag,
  sum(value) metric,
  'IM3' brand,
  parse_date('%Y%m%d', vdt_id) as dt_id
from `data-bi-prd-935c.bi_stg.temp_final_sms_report_circle_vlr`
where date(dt_id) = parse_date('%Y%m%d', vdt_id)
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
  'D-2' flag,
  sum(value) metric,
  'IM3' brand,
  parse_date('%Y%m%d', vdt_id) as dt_id
from `data-bi-prd-935c.bi_stg.temp_final_sms_report_circle_vlr`
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
  'D-7' flag,
  sum(value) metric,
  'IM3' brand,
  parse_date('%Y%m%d', vdt_id) as dt_id
from `data-bi-prd-935c.bi_stg.temp_final_sms_report_circle_vlr`
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
  case 
    when kpi_code like '%vlr%' or kpi_code like '%uu%' then avg(value) 
  else sum(value) end metric,
  brand,
  dt_id
 from(
    select entity,
      definition,
      kpi_id,
      case
        when kpi_id = 'DAT0003' then 'traffic_data'
        else kpi_code
      end kpi_code,
      circle,
      region_circle,
      'MTD' flag,
      value,
      'IM3' brand,
      parse_date('%Y%m%d', vdt_id)  dt_id
    from `data-bi-prd-935c.bi_stg.temp_final_sms_report_circle_vlr`
    where dt_id between date_trunc(parse_date('%Y%m%d', vdt_id), month) and parse_date('%Y%m%d', vdt_id)
) a
group by 1, 2, 3, 4, 5, 6, 7, 9, 10
union all --add LMTD By Indra Maulana Ikhsan 20241210
select entity,
  definition,
  kpi_id,
  kpi_code,
  circle,
  region_circle,
  'LMTD' flag,
  metric,
  'IM3' brand,
  parse_date('%Y%m%d', vdt_id) as dt_id
from `data-bi-prd-935c.bi_mart.sms_report_circle`
where date(dt_id) = date_sub(parse_date('%Y%m%d', vdt_id), interval 1 month)
and brand = 'IM3' and flag = 'MTD';