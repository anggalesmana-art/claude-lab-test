declare vdt_id date default @vdt_id;

drop table if exists `data-bi-prd-935c.bi_stg.temp_postpaid_sms_report_rev_billing`;
create table `data-bi-prd-935c.bi_stg.temp_postpaid_sms_report_rev_billing` as 
with main_rev_bil as (
    select date(a.dt_id) as dt_id,
        asset_id msisdn,
        a.account_number,
        case
            when asset_id is not null then 'ASSET NOT NULL'
            else 'ASSET NULL'
        end asset_flag,
        sum(cast(amount as float64)) amount
    from `data-dtp-prd-aa1a.stg.rbm_pstpaid_rev_ast` a
        left join (
            select distinct msisdn
            from `data-dtp-prd-aa1a.smy.ar_cst_pstpaid_rtl`
            where date(dt_id) between date_sub(parse_date('%Y%m%d', vdt_id), interval 90 day) and parse_date('%Y%m%d', vdt_id)
        ) b on a.asset_id = b.msisdn
    where lower(customer_type) in ('individual', 'vvip') --B2C
        and filename like '1000_EB%'
        and upper(revenue_code_name) not like '%HIFI%'
        and upper(revenue_code_name) not in (
            'REFILL VOUCHER',
            'STMDTY',
            'VAT010',
            'ADJ025',
            'ADJ018',
            'B2B ADJUSMENT - PPH',
            'DISCCREDITPREPAID',
            '3701000', -- vat
            '3702000', -- vat
            'IM2ADJ02',
            'MIGCREDITADJ',
            'IM2ADJ01',
            'MIGDEBITADJ',
            'BC_DISPADJ',
            'PPH23_DISPADJ',
            'STAMP_DISPADJ',
            'SUBTOTAL_DISPADJ',
            'VAT10_DISPADJ'
        )
        and date(a.dt_id) = parse_date('%Y%m%d', vdt_id)
    group by 1, 2, 3, 4
),
nsubs as (
    select ac_num, count(distinct msisdn) nsubs
    from `data-dtp-prd-aa1a.smy.ar_cst_pstpaid_rtl`
    where date(dt_id) = parse_date('%Y%m%d', vdt_id)
    group by 1
),
favloc_90 as (
    select msisdn, site_id
    from `data-bi-prd-935c.bi_mart.all_90d_fav_loc_dly`
    where date(dt_id) = parse_date('%Y%m%d', vdt_id)
)
select date(date_trunc(date(dt_id), month) + interval (
    case
        when extract(day from date(dt_id)) between  1 and  7 then 7
        when extract(day from date(dt_id)) between  8 and 11 then 11
        when extract(day from date(dt_id)) between 12 and 15 then 15
        when extract(day from date(dt_id)) between 16 and 19 then 19
        when extract(day from date(dt_id)) between 20 and 23 then 23
        when extract(day from date(dt_id)) between 24 and 27 then 27
        when extract(day from date(dt_id)) >= 28 then extract(day from last_day(date(dt_id)))
      end
    ) - 1 day) as `date`,
    c.circle,
    c.region_circle,
    sum(amount) value,
    date(date_trunc(date(dt_id), month) + interval (
    case
        when extract(day from date(dt_id)) between  1 and  7 then 7
        when extract(day from date(dt_id)) between  8 and 11 then 11
        when extract(day from date(dt_id)) between 12 and 15 then 15
        when extract(day from date(dt_id)) between 16 and 19 then 19
        when extract(day from date(dt_id)) between 20 and 23 then 23
        when extract(day from date(dt_id)) between 24 and 27 then 27
        when extract(day from date(dt_id)) >= 28 then extract(day from last_day(date(dt_id)))
      end
    ) - 1 day) as `dt_id`,
    'IO' as entity,
    'IO' definition,
    'REV0008' kpi_id,
    'billing_revenue' kpi_code,
    date(date_trunc(date(dt_id), month) + interval (
    case
        when extract(day from date(dt_id)) between  1 and  7 then 7
        when extract(day from date(dt_id)) between  8 and 11 then 11
        when extract(day from date(dt_id)) between 12 and 15 then 15
        when extract(day from date(dt_id)) between 16 and 19 then 19
        when extract(day from date(dt_id)) between 20 and 23 then 23
        when extract(day from date(dt_id)) between 24 and 27 then 27
        when extract(day from date(dt_id)) >= 28 then extract(day from last_day(date(dt_id)))
      end
    ) - 1 day) as `prt_dt`
from main_rev_bil a
    left join favloc_90 b on a.msisdn = b.msisdn
    left join `data-bi-prd-935c.bi_mart.ref_site` c on b.site_id = c.site_id
group by 1, 2, 3;

delete from `data-bi-prd-935c.bi_stg.stg_postpaid_sms_report`
where kpi_code = 'billing_revenue' and prt_dt = date(date_trunc(date(parse_date('%Y%m%d', vdt_id)), month) + interval (
    case
        when extract(day from date(parse_date('%Y%m%d', vdt_id))) between  1 and  7 then 7
        when extract(day from date(parse_date('%Y%m%d', vdt_id))) between  8 and 11 then 11
        when extract(day from date(parse_date('%Y%m%d', vdt_id))) between 12 and 15 then 15
        when extract(day from date(parse_date('%Y%m%d', vdt_id))) between 16 and 19 then 19
        when extract(day from date(parse_date('%Y%m%d', vdt_id))) between 20 and 23 then 23
        when extract(day from date(parse_date('%Y%m%d', vdt_id))) between 24 and 27 then 27
        when extract(day from date(parse_date('%Y%m%d', vdt_id))) >= 28 then extract(day from last_day(date(parse_date('%Y%m%d', vdt_id))))
      end
    ) - 1 day);

insert into `data-bi-prd-935c.bi_stg.stg_postpaid_sms_report`
select * from `data-bi-prd-935c.bi_stg.temp_postpaid_sms_report_rev_billing`;

drop table if exists `data-bi-prd-935c.bi_stg.temp_postpaid_sms_report_rev_usage`;
create table `data-bi-prd-935c.bi_stg.temp_postpaid_sms_report_rev_usage` as 
with main_rev_usage as (
    select date(transaction_date) as dt_id,
        a.msisdn,
        sum(total_amount) as val
    from `data-dtptechm-prd-c7ca.smy.usg_postpaid_dly_smy_uat` a
        join (
            select distinct msisdn
            from `data-dtp-prd-aa1a.smy.ar_cst_pstpaid_rtl`
            where date(dt_id) = parse_date('%Y%m%d', vdt_id)
        ) b on a.msisdn = b.msisdn
    where date(transaction_date) = parse_date('%Y%m%d', vdt_id)
        and revenue_flag = 'Yes'
        and concat(service_type, "-", service_usage_type) <> "VOICE-VAS"
        and service_usage_type not in ('DROP', 'Voice other')
    group by 1,
        2
),
favloc_90 as (
    select msisdn, site_id
    from `data-bi-prd-935c.bi_mart.all_90d_fav_loc_dly`
    where date(dt_id) = parse_date('%Y%m%d', vdt_id)
)
select date(a.dt_id) as `date`,
  c.circle,
  c.region_circle,
  sum(val) as value,
  date(a.dt_id) as dt_id,
  'IO' as entity,
  'IO' as definition,
  'REV0007' as kpi_id,
  'usage_revenue' as kpi_code,
  a.dt_id as prt_dt
from main_rev_usage a 
  left join favloc_90 b on a.msisdn = b.msisdn
  left join `data-bi-prd-935c.bi_mart.ref_site` c on b.site_id = c.site_id
group by 1, 2, 3, 5, 10;

delete from `data-bi-prd-935c.bi_stg.stg_postpaid_sms_report`
where kpi_code in (select distinct(kpi_code) from `data-bi-prd-935c.bi_stg.temp_postpaid_sms_report_rev_usage`)
and date(prt_dt) in (select distinct(date(prt_dt)) from `data-bi-prd-935c.bi_stg.temp_postpaid_sms_report_rev_usage`);

insert into `data-bi-prd-935c.bi_stg.stg_postpaid_sms_report`
select * from `data-bi-prd-935c.bi_stg.temp_postpaid_sms_report_rev_usage`;

delete from `data-bi-prd-935c.bi_mart.postpaid_sms_report`
where dt_id between date_trunc(parse_date('%Y%m%d', vdt_id), month) and parse_date('%Y%m%d', vdt_id)
  and date(dt_id) = date_sub(parse_date('%Y%m%d', vdt_id), interval 1 month);

insert `data-bi-prd-935c.bi_mart.postpaid_sms_report`
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
  parse_date('%Y%m%d', vdt_id) as dt_id
from `data-bi-prd-935c.bi_stg.stg_postpaid_sms_report`
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
  'POSTPAID' brand,
  parse_date('%Y%m%d', vdt_id) as dt_id
from `data-bi-prd-935c.bi_stg.stg_postpaid_sms_report`
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
  'POSTPAID' brand,
  parse_date('%Y%m%d', vdt_id) as dt_id
from `data-bi-prd-935c.bi_stg.stg_postpaid_sms_report`
where dt_id = date_sub(parse_date('%Y%m%d', vdt_id), interval 7 day)
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
  'MTD' flag,
  sum(value) metric,
  'POSTPAID' brand,
  parse_date('%Y%m%d', vdt_id) as dt_id
from `data-bi-prd-935c.bi_stg.stg_postpaid_sms_report`
where date(dt_id) between  date_trunc(parse_date('%Y%m%d', vdt_id), month) and parse_date('%Y%m%d', vdt_id)
group by 1, 2, 3, 4, 5, 6, dt_id
union all
select 
  entity,
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
  parse_date('%Y%m%d', vdt_id) as dt_id
from `data-bi-prd-935c.bi_mart.postpaid_sms_report`
where date(dt_id) = date_sub(parse_date('%Y%m%d', vdt_id), interval 1 month)
and brand = 'POSTPAID' and flag = 'MTD';