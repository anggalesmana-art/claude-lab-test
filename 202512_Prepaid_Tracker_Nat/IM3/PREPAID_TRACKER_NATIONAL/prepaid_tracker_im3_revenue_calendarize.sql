declare vdt_id date default @vdt_id;
delete from `data-bi-prd-935c.bi_mart`.kpi_national_tracker_dly where dt_id = vdt_id and brand = 'IM3' and kpi_id in (
'REV0017',
'REV0016',
'REV0018',
'REV0015',
'REV0013',
'REV0012',
'REV0019',
'REV0014'
);

insert into `data-bi-prd-935c.bi_mart`.kpi_national_tracker_dly
with calenderize as (
  select parse_date('%Y%m%d',revenue_date) dt_id, revenue_type
      , round(sum(mainprice_data/1.11)) rev_data
      , round(sum(mainprice_voice/1.11)) rev_voice
      , round(sum(mainprice_sms/1.11)) rev_sms
      , round(sum(mainprice_vas/1.11)*0.442907977) rev_vas
      , round(sum(mainprice_other/1.11)) rev_other
  from `data-bi-prd-935c.revenue`.calendarization_revenue_per_msisdn_national a
  where revenue_date between format_date('%Y%m%d',vdt_id) and format_date('%Y%m%d',vdt_id) and 
date(subscription_date) <= vdt_id
  group by 1,2
),
calenderize_fnl as (
  -- mobo & organic
  SELECT dt_id
    , case when revenue_type in ('data_voucher_ori','fdv','salmo','spdata') then 'REV0014' else 'REV0015' end kpi_id
    , '' kpi_code
    , 'DLY' flag
    , sum(rev_data) metric
  from calenderize
  where rev_data>0
  group by 1,2
  union all
  -- voice
  SELECT dt_id, 'REV0016' kpi_id, '' kpi_code, 'DLY' flag, sum(rev_voice) metric
  from calenderize
  where rev_voice>0
  group by 1
  union all
  -- sms
  SELECT dt_id, 'REV0017' kpi_id, '' kpi_code, 'DLY' flag, sum(rev_sms) metric
  from calenderize
  where rev_sms>0
  group by 1
  union all
  -- vas
  SELECT dt_id, 'REV0018' kpi_id, '' kpi_code, 'DLY' flag, sum(rev_vas) metric
  from calenderize
  where rev_vas>0
  group by 1
  union all
  -- loan balance
  SELECT dt_id, 'REV0019' kpi_id, '' kpi_code, 'DLY' flag, sum(rev_other) metric
  from calenderize
  where rev_other>0
  group by 1
)
-- total all
SELECT 'IM3' brand, '' kpi_code, 'DLY' flag, sum(metric) metric, timestamp(current_datetime('+7')) process_dt, 'REV0012' kpi_id, dt_id
from calenderize_fnl
group by dt_id
union all
-- total data
SELECT 'IM3' brand, '' kpi_code, 'DLY' flag, sum(metric) metric, timestamp(current_datetime('+7')) process_dt, 'REV0013' kpi_id, dt_id
from calenderize_fnl
where kpi_id in ('REV0014','REV0015')
group by dt_id
union all
-- by services
select 'IM3' brand, kpi_code, flag, metric, timestamp(current_datetime('+7')) process_dt, kpi_id, dt_id from calenderize_fnl
;