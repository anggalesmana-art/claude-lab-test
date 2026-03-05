declare vdt_id date default @vdt_id;

drop table if exists `data-bi-prd-935c.bi_stg.temp_postpaid_sms_report_vlr`;

create table `data-bi-prd-935c.bi_stg.temp_postpaid_sms_report_vlr` as with data_5g_uu as (
  select distinct(date(dt_id)) as dt_id,
    msisdn
  from `data-dtp-prd-aa1a.stg.stg_nio_appsrtgout_5g`
  where date(dt_id) = vdt_id
    and (volume_in + volume_out) > 0
),
final_source as (
  select a.dt_id,
    a.msisdn,
    a.site_id,
    technology
  from (
      select date(a.dt_id) as dt_id,
        a.msisdn,
        a.site_id,
        case
          when c.msisdn is not null then '5G'
          when a.technology is null then '4G'
          else a.technology
        end as technology,
        ROW_NUMBER() OVER (
          partition BY a.msisdn
          order by case
              when c.msisdn is not null then 5
              when a.technology = '4G' then 4
              when a.technology = '3G' then 3
              when a.technology = '2G' then 2
              else 1
            end desc
        ) as rn
      from `data-bi-prd-935c.bi_dm.vlr_site_wise` a
        left join `data-dtp-prd-aa1a.smy.ar_cst_dly_smy` b on a.msisdn = b.msisdn
        and date(b.dt_id) = vdt_id
        left join data_5g_uu c on a.msisdn = c.msisdn
      where date(a.dt_id) = vdt_id
        and b.msisdn is null
    ) a
  where rn = 1
)
select a.dt_id as `date`,
  b.circle,
  b.region_circle,
  count(distinct a.msisdn) value,
  a.dt_id,
  'IO' as entity,
  'IO' definition,
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
  a.dt_id prt_dt
from final_source a
  left join (
    select distinct(site_id) as site_id,
      circle,
      region_circle
    from `data-bi-prd-935c.bi_mart.ref_site`
  ) b on a.site_id = b.site_id
group by 1,
  2,
  3,
  8,
  9
union all
select date(a.dt_id) as date,
  b.circle,
  b.region_circle,
  count(distinct a.msisdn) as value,
  date(a.dt_id) as dt_id,
  'IO' as entity,
  'IO' as definition,
  'SUB0006' as kpi_id,
  'vlr_daily' as kpi_code,
  date(a.dt_id) as prt_dt
from `data-bi-prd-935c.bi_dm.vlr_site_wise` a
  left join `data-dtp-prd-aa1a.smy.ar_cst_dly_smy` c on a.msisdn = c.msisdn
  and date(c.dt_id) = vdt_id
  left join (
    select distinct site_id,
      circle,
      region_circle
    from `data-bi-prd-935c.bi_mart.ref_site`
  ) b on a.site_id = b.site_id
where date(a.dt_id) = vdt_id
  and c.msisdn is null -- LEFT ANTI JOIN replacement
group by 1,
  2,
  3;

delete from `data-bi-prd-935c.bi_stg.stg_postpaid_sms_report`
where kpi_code in (
    select distinct(kpi_code)
    from `data-bi-prd-935c.bi_stg.temp_postpaid_sms_report_vlr`
  )
  and prt_dt in (
    select distinct(prt_dt)
    from `data-bi-prd-935c.bi_stg.temp_postpaid_sms_report_vlr`
  );

insert into `data-bi-prd-935c.bi_stg.stg_postpaid_sms_report`
select *
from `data-bi-prd-935c.bi_stg.temp_postpaid_sms_report_vlr`;

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
  vdt_id dt_id
from `data-bi-prd-935c.bi_stg.stg_postpaid_sms_report`
where date(dt_id) = vdt_id
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
  'D-2' flag,
  sum(value) metric,
  'POSTPAID' brand,
  vdt_id dt_id
from `data-bi-prd-935c.bi_stg.stg_postpaid_sms_report`
where date(dt_id) = date_sub(vdt_id, interval 1 day)
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
where date(dt_id) = date_sub(vdt_id, interval 7 day)
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
  sum(value) as metric,
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
where date(dt_id) = date_sub(vdt_id, interval 1 month)
  and brand = 'POSTPAID'
  and flag = 'MTD';