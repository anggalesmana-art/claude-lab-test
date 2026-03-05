declare vdt_id date default @vdt_id;

drop table if exists `data-bi-prd-935c.bi_stg.tmp_circle_tri_sms_report_kpi_reload`;
create table `data-bi-prd-935c.bi_stg.tmp_circle_tri_sms_report_kpi_reload` as
select date(dt_id) as dt_id,
  sbscrptn_ek_id,
  sum(cast(tot_rechrg_idr_val as float64)) as rev,
  count(1) as hits
from `data-dtptechm-prd-c7ca.dwh.h3i_cst_rechrg_dly_smy`
where date(dt_id) between date_trunc(vdt_id, month) and vdt_id
group by 1, 2;

drop table if exists `data-bi-prd-935c.bi_stg.tmp_siteref_3id`;
create table `data-bi-prd-935c.bi_stg.tmp_siteref_3id` as with sites as (
  select 
    case when length(site_id) <= 5 then LPAD(site_id, 6, '0')
    else site_id end as site_id,
    circle,
    region_circle,
    row_number() over (partition by case when length(site_id) <= 5 then LPAD(site_id, 6, '0') else site_id end order by site_nm) as seq
  from `data-dtptechm-prd-c7ca.ioh_biadm.ref_site_h3i`
)
select * from sites where seq = 1;

delete from `data-bi-prd-935c.bi_stg.circle_tri_sms_report_kpi`
where date(dt_id) between date_trunc(vdt_id, month) and vdt_id and kpi_id like 'RLD%';

insert into `data-bi-prd-935c.bi_stg.circle_tri_sms_report_kpi`
select date(dt_id) as dt_id,
  'H3I' as entity,
  'IOH' as definition,
  'RLD0001' as kpi_id,
  'rld_rev_daily' as kpi_code,
  sum(cast(rev as bignumeric)) as `value`,
  concat('H3I_IO_', cast( format_datetime('%Y%m%d%H%M%S', current_datetime('UTC+7')) as string ), '_JID_1' ) as jobid,
  date(dt_id) as load_dt,
  c.circle,
  c.region_circle
from `data-bi-prd-935c.bi_stg.tmp_circle_tri_sms_report_kpi_reload` a
  left join `data-bi-prd-935c.bi_mart.ioh_subscriber_site_attribs_rolling` b
  on cast(a.sbscrptn_ek_id as string) = cast(b.sbscrptn_ek_id as string) and date(a.dt_id) = date(b.dt)
  left join `data-bi-prd-935c.bi_stg.tmp_siteref_3id` c on b.site_id_dly = c.site_id
where b.dt between date_trunc(vdt_id, month) and vdt_id
group by 1, 9, 10;

insert into `data-bi-prd-935c.bi_stg.circle_tri_sms_report_kpi`
select date(dt_id) as dt_id,
  'H3I' as entity,
  'IOH' as definition,
  'RLD0001' as kpi_id,
  'rld_uu_daily' as kpi_code,
  count(distinct a.sbscrptn_ek_id) as `value`,
  concat('H3I_IO_', cast( format_datetime('%Y%m%d%H%M%S', current_datetime('UTC+7')) as string ), '_JID_1' ) as jobid,
  date(dt_id) as load_dt,
  c.circle,
  c.region_circle
from `data-bi-prd-935c.bi_stg.tmp_circle_tri_sms_report_kpi_reload` a
  left join `data-bi-prd-935c.bi_mart.ioh_subscriber_site_attribs_rolling` b 
  on cast(a.sbscrptn_ek_id as string) = cast(b.sbscrptn_ek_id as string) and date(a.dt_id) = date(b.dt)
  left join `data-bi-prd-935c.bi_stg.tmp_siteref_3id` c on b.site_id_dly = c.site_id
  and c.seq = 1
where b.dt between date_trunc(vdt_id, month) and vdt_id
group by 1, 9, 10;

insert into `data-bi-prd-935c.bi_stg.circle_tri_sms_report_kpi`
select date(dt_id) as dt_id,
  'H3I' as entity,
  'IOH' as definition,
  'RLD0001' as kpi_id,
  'rld_hits_daily' as kpi_code,
  sum(cast(hits as bignumeric)) as `value`,
  concat('H3I_IO_', cast( format_datetime('%Y%m%d%H%M%S', current_datetime('UTC+7')) as string ), '_JID_1' ) as jobid,
  date(dt_id) as load_dt,
  c.circle,
  c.region_circle
from `data-bi-prd-935c.bi_stg.tmp_circle_tri_sms_report_kpi_reload` a
  left join `data-bi-prd-935c.bi_mart.ioh_subscriber_site_attribs_rolling` b 
  on cast(a.sbscrptn_ek_id as string) = cast(b.sbscrptn_ek_id as string) and date(a.dt_id) = date(b.dt)
  left join `data-bi-prd-935c.bi_stg.tmp_siteref_3id` c on b.site_id_dly = c.site_id
  and c.seq = 1
where b.dt between date_trunc(vdt_id, month) and vdt_id
group by 1, 9, 10;

-- final mart
delete from `data-bi-prd-935c.bi_mart.sms_report_circle`
where brand = 'TRI' and date(dt_id) = vdt_id and kpi_code like 'rld_%';

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
where dt_id = vdt_id
and kpi_code like 'rld_%'
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
  'TRI' as brand,
  vdt_id as dt_id
from `data-bi-prd-935c.bi_stg.circle_tri_sms_report_kpi`
where dt_id = date_sub(vdt_id, interval 1 day)
and kpi_code like 'rld_%'
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
  'TRI' as brand,
  vdt_id as dt_id
from `data-bi-prd-935c.bi_stg.circle_tri_sms_report_kpi`
where dt_id = date_sub(vdt_id, interval 7 day)
and kpi_code like 'rld_%'
group by 1, 2, 3, 4, 5, 6, dt_id
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
where dt_id between date_trunc(vdt_id, month)
  and vdt_id
  and kpi_code like 'rld_%'
group by 1, 2, 3, 4, 5, 6, dt_id
union all --Add LMTD By Indra Maulana Ikhsan 20241210
select entity,
  definition,
  kpi_id,
  kpi_code,
  circle,
  region_circle,
  'LMTD' as flag,
  metric,
  'TRI' as brand,
  vdt_id as dt_id
from `data-bi-prd-935c.bi_mart.sms_report_circle`
where dt_id = date_sub(vdt_id, interval 1 month)
  and brand = 'TRI'
  and flag = 'MTD'
  and kpi_code like 'rld_%';