declare vdt_id date default @vdt_id;

drop table if exists `data-bi-prd-935c.bi_stg.tmp_stg_postpaid_sms_report_uu`;

create table `data-bi-prd-935c.bi_stg.tmp_stg_postpaid_sms_report_uu` as with main as (
  select DATE(a.dt_id) as dt_id,
    a.subscriber as msisdn,
    case
      when a.rat_tp = 1 then '3G'
      when a.rat_tp = 6 then '4G'
      when a.rat_tp not in (1, 6) then '2G'
      else '4G'
    end as technology
  from `data-bi-prd-935c.bi_dm.traffic_ggsn` a
    left join `data-dtp-prd-aa1a.smy.ar_cst_dly_smy` b on a.subscriber = b.msisdn
    and DATE(b.dt_id) = vdt_id
  where DATE(a.dt_id) = vdt_id
    and (a.downlink + a.uplink) > 0
    and a.rating_group not in ('23111', '55003', '70091')
    and b.msisdn is null
),
data_5g_uu as (
  select distinct(date(dt_id)) as dt_id,
    msisdn
  from `data-dtp-prd-aa1a.stg.stg_nio_appsrtgout_5g`
  where date(dt_id) = vdt_id
    and (volume_in + volume_out) > 0 -- and left(msisdn,5) IN ('62814','62815','62816','62855','62856','62857','62858')
),
final_source as (
  select date(a.dt_id) as dt_id,
    a.msisdn,
    a.technology
  from (
      select date(a.dt_id) as dt_id,
        a.msisdn,
        a.technology,
        row_number() over (
          partition by msisdn
          order by technology desc
        ) as rn
      from (
          select date(a.dt_id) as dt_id,
            a.msisdn,
            case
              when b.msisdn is not null then '5G'
              else technology
            end technology
          from main a
            left join data_5g_uu b on a.msisdn = b.msisdn
            and date(a.dt_id) = date(b.dt_id)
        ) a
    ) a
  where rn = 1
)
select date(a.dt_id) as `date`,
  c.circle,
  c.region_circle,
  count(distinct a.msisdn) as value,
  date(a.dt_id) as dt_id,
  'IO' as entity,
  'IO' as definition,
  case
    when technology = '5G' then 'SUB0002'
    when technology = '4G' then 'SUB0003'
    when technology = '3G' then 'SUB0004'
    when technology = '2G' then 'SUB0005'
  end as kpi_id,
  case
    when technology = '5G' then 'uu_daily_5g'
    when technology = '4G' then 'uu_daily_4g'
    when technology = '3G' then 'uu_daily_3g'
    when technology = '2G' then 'uu_daily_2g'
  end as kpi_code,
  date(a.dt_id) as prt_dt
from final_source a
  left join `data-bi-prd-935c.bi_mart.max_fav_loc_dly` b on a.msisdn = b.msisdn
  and date(b.dt_id) = vdt_id
  and priority = '1. GGSN'
  left join (
    select distinct site_id,
      circle,
      region_circle
    from `data-bi-prd-935c.bi_mart.ref_site`
  ) c on c.site_id = b.site_id
where date(a.dt_id) = vdt_id
group by dt_id,
  2,
  3,
  technology
union all
select date(a.dt_id) as `date`,
  c.circle,
  c.region_circle,
  count(distinct a.msisdn) as value,
  date(a.dt_id) as dt_id,
  'IO' as entity,
  'IO' as definition,
  'SUB0001' as kpi_id,
  'uu_daily' as kpi_code,
  date(a.dt_id) as prt_dt
from main a
  left join `data-bi-prd-935c.bi_mart.max_fav_loc_dly` b on a.msisdn = b.msisdn
  and date(b.dt_id) = vdt_id
  and priority = '1. GGSN'
  left join (
    select distinct site_id,
      circle,
      region_circle
    from `data-bi-prd-935c.bi_mart.ref_site`
  ) c on c.site_id = b.site_id
where date(a.dt_id) = vdt_id
group by dt_id,
  2,
  3;

delete from `data-bi-prd-935c.bi_stg.stg_postpaid_sms_report`
where kpi_code in (
    select distinct(kpi_code)
    from `data-bi-prd-935c.bi_stg.tmp_stg_postpaid_sms_report_uu`
  )
  and prt_dt in (
    select distinct(prt_dt)
    from `data-bi-prd-935c.bi_stg.tmp_stg_postpaid_sms_report_uu`
  );

insert into `data-bi-prd-935c.bi_stg.stg_postpaid_sms_report`
select *
from `data-bi-prd-935c.bi_stg.tmp_stg_postpaid_sms_report_uu`;

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
  end kpi_code,
  circle,
  region_circle,
  'D-1' flag,
  sum(value) metric,
  'POSTPAID' brand,
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
  'D-2' flag,
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
  end kpi_code,
  circle,
  region_circle,
  'D-7' flag,
  sum(value) metric,
  'POSTPAID' brand,
  vdt_id dt_id
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
  end kpi_code,
  circle,
  region_circle,
  'MTD' flag,
  sum(value) metric,
  'POSTPAID' brand,
  vdt_id dt_id
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
  end kpi_code,
  circle,
  region_circle,
  'LMTD' flag,
  metric,
  'POSTPAID' brand,
  vdt_id dt_id
from `data-bi-prd-935c.bi_mart.postpaid_sms_report`
where dt_id = date_sub(vdt_id, interval 1 month)
  and brand = 'POSTPAID'
  and flag = 'MTD';