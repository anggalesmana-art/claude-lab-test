declare vdt_id date default @vdt_id;

drop table if exists `data-bi-prd-935c.bi_stg.tmp_site_rolling_uu`;
create table `data-bi-prd-935c.bi_stg.tmp_site_rolling_uu` as
select distinct(date(dt)) as dt,
  sbscrptn_ek_id,
  case
    when length(trim(site_id_90)) < 6 then LPAD(trim(site_id_90), 6, '0')
    else trim(site_id_90)
  end as site_id_90,
  case
    when length(trim(site_id_30)) < 6 then LPAD(trim(site_id_30), 6, '0')
    else trim(site_id_30)
  end as site_id_30,
  case
    when length(trim(site_id_dly)) < 6 then LPAD(trim(site_id_dly), 6, '0')
    else trim(site_id_dly)
  end as site_id_dly
from `data-bi-prd-935c.bi_mart.ioh_subscriber_site_attribs_rolling`
where dt between date_trunc(vdt_id, month) and vdt_id;

delete from `data-bi-prd-935c.bi_stg.circle_tri_sms_report_kpi`
where dt_id between date_trunc(vdt_id, month) and vdt_id and kpi_code like 'uu_%';

insert into `data-bi-prd-935c.bi_stg.circle_tri_sms_report_kpi`
select date(load_dt_sk_id) as dt_id,
  'H3I' as entity,
  'IOH' as definition,
  'SUB0001' as kpi_id,
  'uu_daily' as kpi_code,
  count(distinct a.sbscrptn_ek_id) as value,
  concat('H3I_IO_', cast(format_datetime('%Y%m%d%H%M%S', current_datetime('UTC+7')) as string), '_JID_1') as jobid,
  date(load_dt_sk_id) as load_dt,
  c.circle,
  c.region_circle
from `data-bi-prd-935c.bi_mart.project_ioh_data_user_daily` a
  left outer join `data-bi-prd-935c.bi_stg.tmp_site_rolling_uu` b on a.sbscrptn_ek_id = b.sbscrptn_ek_id
  and date(a.load_dt_sk_id) = date(b.dt)
  left outer join (
    select distinct site_id,
      circle,
      region_circle
    from `data-bi-prd-935c.bi_mart.ref_site_h3i`
  ) c on coalesce(b.site_id_dly, b.site_id_30, b.site_id_90) = case
    when length(c.site_id) < 6 then LPAD(trim(c.site_id), 6, '0')
    else c.site_id
  end
where load_dt_sk_id between date_trunc(vdt_id, month) and vdt_id
group by 1, 9, 10;

insert into `data-bi-prd-935c.bi_stg.circle_tri_sms_report_kpi`
select load_dt_sk_id as dt_id,
  'H3I' as entity,
  'IOH' as definition,
  case
    when tec = '5g' then 'SUB0002'
    when tec = '4g' then 'SUB0003'
    when tec = '3g' then 'SUB0004'
    when tec = '2g' then 'SUB0005'
    else 'SUB0003'
  end kpi_id,
  case
    when tec = '5g' then 'uu_daily_5g'
    when tec = '4g' then 'uu_daily_4g'
    when tec = '3g' then 'uu_daily_3g'
    when tec = '2g' then 'uu_daily_2g'
    else 'uu_daily_4g'
  end kpi_code,
  count(distinct a.sbscrptn_ek_id) as value,
  concat('H3I_IO_', cast(format_datetime('%Y%m%d%H%M%S', current_datetime('UTC+7')) as string), '_JID_1') as jobid,
  date(load_dt_sk_id) as load_dt,
  c.circle,
  c.region_circle
from `data-bi-prd-935c.bi_mart.project_ioh_data_user_daily` a
  left outer join `data-bi-prd-935c.bi_stg.tmp_site_rolling_uu` b on a.sbscrptn_ek_id = b.sbscrptn_ek_id
  and a.load_dt_sk_id = b.dt
  left outer join (
    select distinct site_id,
      circle,
      region_circle
    from `data-bi-prd-935c.bi_mart.ref_site_h3i`
  ) c on coalesce(b.site_id_dly, b.site_id_30, b.site_id_90) = case
    when length(c.site_id) < 6 then LPAD(trim(c.site_id), 6, '0')
    else c.site_id
  end
where load_dt_sk_id between date_trunc(vdt_id, month)
  and vdt_id
group by 1, 4, 5, 9, 10;

delete from `data-bi-prd-935c.bi_mart.sms_report_circle`
where dt_id = vdt_id and kpi_code like 'uu_%' and brand = 'TRI';
  
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
  'TRI' as brand,
  vdt_id as dt_id
from `data-bi-prd-935c.bi_stg.circle_tri_sms_report_kpi`
where dt_id = vdt_id and kpi_code like 'uu_%'
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
  kpi_code,
  circle,
  region_circle,
  'D-2' as flag,
  sum(value) as metric,
  'TRI' as brand,
  vdt_id as dt_id
from `data-bi-prd-935c.bi_stg.circle_tri_sms_report_kpi`
where dt_id = date_sub(vdt_id, interval 1 day) and kpi_code like 'uu_%'
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
  kpi_code,
  circle,
  region_circle,
  'D-7' as flag,
  sum(value) as metric,
  'TRI' as brand,
  vdt_id as dt_id
from `data-bi-prd-935c.bi_stg.circle_tri_sms_report_kpi`
where dt_id = date_sub(vdt_id, interval 7 day) and kpi_code like 'uu_%'
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
  kpi_code,
  circle,
  region_circle,
  'MTD' as flag,
  case
    when (
      kpi_code like '%vlr%'
      or kpi_code like '%uu%'
    ) then avg(value)
    else sum(value)
  end metric,
  'TRI' as brand,
  vdt_id as dt_id
from `data-bi-prd-935c.bi_stg.circle_tri_sms_report_kpi`
where dt_id between date_trunc(vdt_id, month) and vdt_id and kpi_code like 'uu_%'
group by 1,
  2,
  3,
  4,
  5,
  6,
  dt_id
union all --Add LMTD By Indra Maulana Ikhsan 20241210
select entity,
  definition,
  kpi_id,
  kpi_code,
  circle,
  region_circle,
  'LMTD' flag,
  metric,
  'TRI' brand,
  vdt_id as dt_id
from `data-bi-prd-935c.bi_mart.sms_report_circle`
where dt_id = date_sub(vdt_id, interval 1 month) and brand = 'TRI' and flag = 'MTD' and kpi_code like 'uu_%';