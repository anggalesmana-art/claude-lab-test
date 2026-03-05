declare vdt_id date default @vdt_id;

drop table if exists `data-bi-prd-935c.bi_stg.tmp_sms_report_circle_uu`;
create table `data-bi-prd-935c.bi_stg.tmp_sms_report_circle_uu` as
select 
  a.dt_id,
  a.subscriber msisdn,
  case
    when a.rat_tp = 1 then '3G'
    when a.rat_tp = 6 then '4G'
    when a.rat_tp not in (1, 6) then '2G'
    else '4G'
  end technology
from `data-bi-prd-935c.bi_dm.traffic_ggsn` a
  join `data-dtp-prd-aa1a.smy.ar_cst_dly_smy` b 
    on a.subscriber = b.msisdn and date(b.dt_id) = vdt_id
where date(a.dt_id) = vdt_id and (downlink + uplink) > 0
  and rating_group not in ('23111', '55003', '70091');

drop table if exists `data-bi-prd-935c.bi_stg.tmp_final_sms_report_circle_uu`;
create table `data-bi-prd-935c.bi_stg.tmp_final_sms_report_circle_uu` as 
with _5g_uu as (
  select distinct(dt_id) as dt_id , msisdn
  from `data-dtp-prd-aa1a.stg.stg_nio_appsrtgout_5g`
  where date(dt_id) = vdt_id and (volume_in + volume_out) > 0
),
final_source as (
  select date(a.dt_id) as dt_id,
    a.msisdn,
    a.technology
  from (
      select date(a.dt_id) as dt_id,
        a.msisdn,
        a.technology,
        row_number() over (partition by msisdn order by technology desc) as rn
      from (
          select 
            date(a.dt_id) as dt_id,
            a.msisdn,
            case when b.msisdn is not null then '5G' else technology end technology
          from `data-bi-prd-935c.bi_stg.tmp_sms_report_circle_uu` a
            left join _5g_uu b on a.msisdn = b.msisdn
        ) a
    ) a
  where rn = 1
)
select date(a.dt_id) as `date`,
  c.circle as circle,
  c.region_circle as region_circle,
  count(distinct a.msisdn) as value,
  date(a.dt_id) as dt_id,
  'IO' as entity,
  'IO' as definition,
  case
    when technology = '5G' then 'SUB0002'
    when technology = '4G' then 'SUB0003'
    when technology = '3G' then 'SUB0004'
    when technology = '2G' then 'SUB0005'
  end kpi_id,
  case
    when technology = '5G' then 'uu_daily_5g'
    when technology = '4G' then 'uu_daily_4g'
    when technology = '3G' then 'uu_daily_3g'
    when technology = '2G' then 'uu_daily_2g'
  end kpi_code,
  date(a.dt_id) prt_dt
from final_source a
  left join `data-bi-prd-935c.bi_mart.max_fav_loc_dly` b 
    on a.msisdn = b.msisdn and date(b.dt_id) = vdt_id and priority = '1. GGSN'
  left join (select distinct(site_id) as site_id, circle, region_circle from `data-bi-prd-935c.bi_mart.ref_site`) c 
    on c.site_id = b.site_id
where date(a.dt_id) = vdt_id
group by dt_id, c.circle, c.region_circle, technology
union all
select date(a.dt_id) as `date`,
  c.circle,
  c.region_circle,
  count(distinct(a.msisdn)) as value,
  date(a.dt_id) as dt_id,
  'IO' as entity,
  'IO' as definition,
  'SUB0001' as kpi_id,
  'uu_daily' as kpi_code,
  date(a.dt_id) as prt_dt
from `data-bi-prd-935c.bi_stg.tmp_sms_report_circle_uu` a
  left join `data-bi-prd-935c.bi_mart.max_fav_loc_dly` b 
    on a.msisdn = b.msisdn and date(b.dt_id) = vdt_id and priority = '1. GGSN'
  left join (select distinct(site_id) as site_id, circle, region_circle from `data-bi-prd-935c.bi_mart.ref_site`) c 
    on c.site_id = b.site_id
where date(a.dt_id) = vdt_id
group by dt_id, 2, 3;

delete from `data-bi-prd-935c.bi_stg.circle_im3_sms_report_kpi`
where dt_id = vdt_id and kpi_code in (select distinct(kpi_code) from `data-bi-prd-935c.bi_stg.tmp_final_sms_report_circle_uu`);

insert into `data-bi-prd-935c.bi_stg.circle_im3_sms_report_kpi`
select * from `data-bi-prd-935c.bi_stg.tmp_final_sms_report_circle_uu`;

delete from `data-bi-prd-935c.bi_mart.sms_report_circle`
where dt_id = vdt_id and kpi_code like 'uu_%' and brand = 'IM3';
  
-- final
insert into `data-bi-prd-935c.bi_mart.sms_report_circle`
select entity,
  definition,
  kpi_id,
  kpi_code,
  circle,
  region_circle,
  'D-1' as flag,
  sum(value) as metric,
  'IM3' as brand,
  vdt_id as dt_id
from `data-bi-prd-935c.bi_stg.circle_im3_sms_report_kpi`
where dt_id = vdt_id and kpi_code like 'uu_%'
group by 1, 2, 3, 4, 5, 6, dt_id
union all
select entity,
  definition,
  kpi_id,
  kpi_code,
  circle,
  region_circle,
  'D-2' as flag,
  sum(value) as metric,
  'IM3' as brand,
  vdt_id as dt_id
from `data-bi-prd-935c.bi_stg.circle_im3_sms_report_kpi`
where dt_id = date_sub(vdt_id, interval 1 day) and kpi_code like 'uu_%'
group by 1, 2, 3, 4, 5, 6, dt_id
union all
select entity,
  definition,
  kpi_id,
  kpi_code,
  circle,
  region_circle,
  'D-7' as flag,
  sum(value) as metric,
  'IM3' as brand,
  vdt_id as dt_id
from `data-bi-prd-935c.bi_stg.circle_im3_sms_report_kpi`
where dt_id = date_sub(vdt_id, interval 7 day) and kpi_code like 'uu_%'
group by 1, 2, 3, 4, 5, 6, dt_id
union all
select entity,
  definition,
  kpi_id,
  kpi_code,
  circle,
  region_circle,
  'MTD' as flag,
  case when (kpi_code like '%vlr%' or kpi_code like '%uu%') then avg(value) else sum(value) end metric,
  'IM3' as brand,
  vdt_id as dt_id
from `data-bi-prd-935c.bi_stg.circle_im3_sms_report_kpi`
where dt_id between date_trunc(vdt_id, month) and vdt_id and kpi_code like 'uu_%'
group by 1, 2, 3, 4, 5, 6, dt_id
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
  vdt_id as dt_id
from `data-bi-prd-935c.bi_mart.sms_report_circle`
where dt_id = date_sub(vdt_id, interval 1 month) and brand = 'IM3' and flag = 'MTD' and kpi_code like 'uu_%';

