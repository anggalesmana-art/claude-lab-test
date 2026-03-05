declare vdt_id date default @vdt_id;

drop table if exists `data-bi-prd-935c.bi_stg.temp_rld_sms_kpi_circle`;
create table `data-bi-prd-935c.bi_stg.temp_rld_sms_kpi_circle` as
select
  date(dt_id) as dt_id,
  msisdn,
  lac_id,
  cell_id,
  sum(cast(rld_amt as float64) / 100) as rld_amt,
  count(1) as hits
from `data-dtp-prd-aa1a.stg.stg_map_gw_rechrg`
where date(dt_id) = vdt_id
  and lower(reload_channel) not like '%ssp%'
  and upper(reload_channel) not like '%PPSR%'
  and rld_amt > 0
group by 1, 2, 3, 4;

drop table if exists `data-bi-prd-935c.bi_stg.temp_rld_sms_kpi_circle_final`;
create table `data-bi-prd-935c.bi_stg.temp_rld_sms_kpi_circle_final` as
with base as (
  select
    date(dt_id) as dt_id,
    case
      when substr(msisdn, 1, 2) <> '62' then concat('62', msisdn) else msisdn end as msisdn,
    case when lac_id = '' or lac_id = '0' or (lac_id != '0' and cell_id = '0') then null else lac_id end lac_id,
    case when cell_id = '' or cell_id = '0' or (cell_id != '0' and lac_id = '0') then null else cell_id end cell_id,
    rld_amt,
    hits
  from `data-bi-prd-935c.bi_stg.temp_rld_sms_kpi_circle`
),
favloc as (
  select
    date(dt_id) as dt_id,
    msisdn,
    split(lacci, '-')[safe_offset(0)] AS lac,
    split(lacci, '-')[safe_offset(1)] AS ci
  from `data-dtp-prd-aa1a.sor.subs_fav_loc_dly_carry_fwd`
  where date(dt_id) = vdt_id
),
final as (
  select date(a.dt_id) as dt_id,
    a.msisdn,
    a.rld_amt,
    a.hits,
    c.site_id
  from base a
    left join favloc b on a.msisdn = b.msisdn
    and date(a.dt_id) = date(b.dt_id)
    left join `data-dtp-prd-aa1a.sor.ref_data_lacci_com_bi` c 
    on ifnull(a.lac_id, b.lac) = c.lac_dec and ifnull(a.cell_id, b.ci) = c.ci_dec
)
select date(a.dt_id) as dt_id,
  a.msisdn,
  b.circle,
  b.region_circle,
  rld_amt as rev,
  hits
from final a
  left join (select distinct(site_id) as site_id, circle, region_circle from `data-bi-prd-935c.bi_mart.ref_site`) b 
    on a.site_id = b.site_id;

drop table if exists `data-bi-prd-935c.bi_stg.temp_final_sms_report_circle_rld`;
create table `data-bi-prd-935c.bi_stg.temp_final_sms_report_circle_rld` as
select
  date(dt_id) as `date`,
  circle,
  region_circle,
  sum(cast(rev as float64)) as value,
  date(dt_id) as dt_id,
  'IO' as entity,
  'IO' as definition,
  'RLD0001' as kpi_id,
  'rld_rev_daily' kpi_code,
  date(dt_id) as prt_dt
from `data-bi-prd-935c.bi_stg.temp_rld_sms_kpi_circle_final`
group by 1, 2, 3
union all
select 
  date(dt_id) as `date`,
  circle,
  region_circle,
  count(distinct msisdn) value,
  date(dt_id) as dt_id,
  'IO' as entity,
  'IO' as definition,
  'RLD0002' as kpi_id,
  'rld_uu_daily' kpi_code,
  date(dt_id) as prt_dt
from `data-bi-prd-935c.bi_stg.temp_rld_sms_kpi_circle_final`
group by 1, 2, 3
union all
select 
  date(dt_id) as `date`,
  circle,
  region_circle,
  sum(cast(hits as float64)) value,
  date(dt_id) as dt_id,
  'IO' as entity,
  'IO' as definition,
  'RLD0003' as kpi_id,
  'rld_hits_daily' kpi_code,
  date(dt_id) as prt_dt
from `data-bi-prd-935c.bi_stg.temp_rld_sms_kpi_circle_final`
group by 1, 2, 3;


-- final mart
delete from `data-bi-prd-935c.bi_mart.sms_report_circle` 
where brand = 'IM3' and date(dt_id) = vdt_id
and kpi_code like 'rld_%';

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
  date(vdt_id) as dt_id
from `data-bi-prd-935c.bi_stg.temp_final_sms_report_circle_rld`
where dt_id = date(vdt_id)
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
  date(vdt_id) as dt_id
from `data-bi-prd-935c.bi_stg.temp_final_sms_report_circle_rld`
where dt_id = date_sub(vdt_id, interval 1 day)
group by 1, 2, 3, 4, 5, 6, dt_id
union all
select entity,
  definition,
  kpi_id,
  case when kpi_id = 'DAT0003' then 'traffic_data' else kpi_code end kpi_code,
  circle,
  region_circle,
  'D-7' flag,
  sum(value) metric,
  'IM3' brand,
  date(vdt_id) as dt_id
from `data-bi-prd-935c.bi_stg.temp_final_sms_report_circle_rld`
where dt_id = date_sub(vdt_id, interval 7 day)
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
 from(
    select entity,
      definition,
      kpi_id,
      case when kpi_id = 'DAT0003' then 'traffic_data' else kpi_code end kpi_code,
      circle,
      region_circle,
      'MTD' flag,
      value,
      'IM3' brand,
      date(vdt_id) as dt_id
    from `data-bi-prd-935c.bi_stg.temp_final_sms_report_circle_rld`
    where dt_id between date_trunc(vdt_id, month) and vdt_id
)a
group by 1,
  2,
  3,
  4,
  5,
  6,
  7,
  9,
  10
union all --Add LMTD By Indra Maulana Ikhsan 20241210
select entity,
  definition,
  kpi_id,
  kpi_code,
  circle,
  region_circle,
  'LMTD' flag,
  metric,
  'IM3' brand,
  date(vdt_id) as dt_id
from `data-bi-prd-935c.bi_mart.sms_report_circle`
where dt_id = date_sub(vdt_id, interval 1 month)
and brand = 'IM3' and flag = 'MTD' and kpi_code like 'rld_%';