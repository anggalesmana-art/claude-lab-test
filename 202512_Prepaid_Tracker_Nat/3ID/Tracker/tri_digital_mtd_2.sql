DECLARE vdt_id DATE DEFAULT @vdt_id;

delete from `data-bi-prd-935c.bi_mart.kpi_national_tracker_dly`
where brand = 'TRI' and dt_id = vdt_id
  and kpi_id in ('DIG0017','DIG0124','DIG0125','DIG0126','DIG0127','DIG0128','DIG0129', 'DIG0130', 'DIG0131', 'DIG0132','DIG0108')
;

insert into `data-bi-prd-935c.bi_mart.kpi_national_tracker_dly`
with active_days as (
  select cast(vdt_id as date) dt_id, cast(avg(ndt) as bignumeric) act_days
  from (
    SELECT msisdn, count(distinct dt_id) ndt
    from `data-bi-prd-935c.bi_mart.bima_dly`
    where dt_id>=date_sub(vdt_id,interval 29 day) and dt_id<=vdt_id
        and bima_flag like '%P%'
    group by 1
  ) x
),
dpu as (
  select cast(vdt_id as date) dt_id
    , sum(inapp_cvm_rev+inapp_atl_rev) inapp_rev
    , sum(inapp_atl_rev) inapp_atl_rev
    , sum(inapp_cvm_rev) inapp_cvm_rev
    , sum(online_atl_rev+online_cvm_rev) online_rev
    , sum(online_atl_rev) online_atl_rev
    , sum(online_cvm_rev) online_cvm_rev
    , sum(vas_rev) vas_rev
    , sum(reload) reload
    , sum(p2p_topup) p2p_topup
    , sum(inapp_atl_rev+inapp_cvm_rev+online_atl_rev+online_cvm_rev+vas_rev+reload+p2p_topup) total_trx
  from  `data-bi-prd-935c.bi_mart.bima_dly`
  where bima_flag like '%P%'
      and dt_id between date_trunc(vdt_id,month) and vdt_id
),
fnl as (
  select 'myim3_bima_paid_days' kpi_code, 'MTD' flag, act_days metric, 'DIG0017' kpi_id, dt_id from active_days
  union all
  select '' kpi_code, 'MTD' flag, inapp_rev metric, 'DIG0124' kpi_id, dt_id
  from dpu
  where inapp_rev>0
  union all
  select '' kpi_code, 'MTD' flag, inapp_atl_rev metric, 'DIG0125' kpi_id, dt_id
  from dpu
  where inapp_atl_rev>0
  union all
  select '' kpi_code, 'MTD' flag, inapp_cvm_rev metric, 'DIG0126' kpi_id, dt_id
  from dpu
  where inapp_cvm_rev>0
  union all
  select '' kpi_code, 'MTD' flag, online_rev metric, 'DIG0127' kpi_id, dt_id
  from dpu
  where online_rev>0
  union all
  select '' kpi_code, 'MTD' flag, online_atl_rev metric, 'DIG0128' kpi_id, dt_id
  from dpu
  where online_atl_rev>0
  union all
  select '' kpi_code, 'MTD' flag, online_cvm_rev metric, 'DIG0129' kpi_id, dt_id
  from dpu
  where online_cvm_rev>0
  union all
  select '' kpi_code, 'MTD' flag, vas_rev metric, 'DIG0130' kpi_id, dt_id
  from dpu
  where vas_rev>0
  union all
  select '' kpi_code, 'MTD' flag, reload metric, 'DIG0131' kpi_id, dt_id
  from dpu
  where reload>0
  union all
  select '' kpi_code, 'MTD' flag, p2p_topup metric, 'DIG0132' kpi_id, dt_id
  from dpu
  where p2p_topup>0
  union all
  select '' kpi_code, 'MTD' flag, total_trx metric, 'DIG0108' kpi_id, dt_id
  from dpu
)
select 'TRI' brand, kpi_code, flag, metric, current_timestamp() process_dt, kpi_id, dt_id from fnl
;