DECLARE vdt_id DATE DEFAULT @vdt_id;

delete from `data-bi-prd-935c.bi_mart.kpi_national_tracker_dly`
where brand = 'TRI' and dt_id = vdt_id
  and kpi_id in ('DIG0001','DIG0002','DIG0003','DIG0004','DIG0005','DIG0006','DIG0007','DIG0008','DIG0009',
    'DIG0011','DIG0012','DIG0013','DIG0014','DIG0015','DIG0016',
    'DIG0101','DIG0115','DIG0116','DIG0117','DIG0118','DIG0119','DIG0120','DIG0121','DIG0122','DIG0123'
  )
;

insert into `data-bi-prd-935c.bi_mart.kpi_national_tracker_dly`
with data_user as (
  SELECT load_dt_sk_id  dt_id, sum(value) metric
  -- FROM mis.project_ioh_kpi_daily_tracker_site
   FROM `data-bi-prd-935c.bi_mart.project_ioh_kpi_daily_tracker_national_wise` --change by Indra Maulana Ikhsan because `data-bi-prd-935c.bi_mart.project_ioh_kpi_daily_tracker_national_wise` is a part of part2 job and always updated when part2 done
  WHERE load_dt_sk_id = vdt_id
      AND kpi_code='rgu30_data'
  group by 1
),
mau as (
  select dt_id, msisdn, case when coalesce(tnr,0) <= 90 then 'AON<=90' else 'AON>90' end AON_GROUP, active_days
  from `data-bi-prd-935c.bi_mart.bima_mau_dly`
  where dt_id = vdt_id
),
mpu as (
  select dt_id, case when coalesce(tnr,0) <= 90 then 'AON<=90' else 'AON>90' end AON_GROUP, count(1) metric
  from `data-bi-prd-935c.bi_mart.bima_mpu_dly`
  where dt_id = vdt_id
  group by 1,2
),
dau as (
  select dt_id, case when coalesce(tnr,0) <= 90 then 'AON<=90' else 'AON>90' end AON_GROUP, count(1) metric
  from `data-bi-prd-935c.bi_mart.bima_dly`
  where bima_flag like '%A%'
      and dt_id = vdt_id
  group by 1,2
),
dpu as (
  select dt_id, case when coalesce(tnr,0) <= 90 then 'AON<=90' else 'AON>90' end AON_GROUP
    , count(1) metric
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
  from `data-bi-prd-935c.bi_mart.bima_dly`
  where bima_flag like '%P%'
      and dt_id = vdt_id
  group by 1,2
),
fnl as (
  select dt_id, 'DIG0001' kpi_id, 'myim3_bima_potential_users' kpi_code, 'MTD' flag, metric from data_user
  union all
  select dt_id, 'DIG0003' kpi_id, 'myim3_bima_mau' kpi_code, 'MTD' flag, count(1) metric from mau group by 1
  union all
  select dt_id
    , case when aon_group='AON<=90' then 'DIG0004' else 'DIG0005' end kpi_id
    , case when aon_group='AON<=90' then 'myim3_bima_mau_inflow' else 'myim3_bima_mau_base' end kpi_code
    , 'MTD' flag
    , count(1) metric
  from mau
  group by 1,2,3
  union all
  select dt_id, 'DIG0006' kpi_id, 'myim3_bima_dau' kpi_code, 'AVG' flag, sum(metric) metric from dau group by 1
  union all
  select dt_id
    , case when aon_group='AON<=90' then 'DIG0007' else 'DIG0008' end kpi_id
    , case when aon_group='AON<=90' then 'myim3_bima_dau_inflow' else 'myim3_bima_dau_base' end kpi_code
    , 'MTD' flag
    , metric
  from dau
  union all
  select dt_id, 'DIG0009' kpi_id, 'myim3_bima_active_days' kpi_code, 'MTD' flag, round(avg(active_days),2) metric
  from ( select distinct dt_id, msisdn, active_days from mau) x
  group by 1
  union all
  select dt_id, 'DIG0011' kpi_id, 'myim3_bima_mpu' kpi_code, 'MTD' flag, sum(metric) from mpu group by 1
  union all
  select dt_id
    , case when aon_group='AON<=90' then 'DIG0012' else 'DIG0013' end kpi_id
    , case when aon_group='AON<=90' then 'myim3_bima_mpu_inflow' else 'myim3_bima_mpu_base' end kpi_code
    , 'MTD' flag
    , sum(metric)
  from mpu
  group by 1,2,3
  union all
  select dt_id, 'DIG0014' kpi_id, 'myim3_bima_dpu' kpi_code, 'AVG' flag, sum(metric) metric from dpu group by 1
  union all
  select dt_id
    , case when aon_group='AON<=90' then 'DIG0015' else 'DIG0016' end kpi_id
    , case when aon_group='AON<=90' then 'myim3_bima_dpu_inflow' else 'myim3_bima_dpu_base' end kpi_code
    , 'MTD' flag
    , metric
  from dpu
  union all
  select dt_id, 'DIG0101' kpi_id, '' kpi_code, 'AVG' flag, sum(total_trx) metric
  from dpu
  where total_trx>0
  group by 1
  union all
  select dt_id, 'DIG0115' kpi_id, '' kpi_code, 'AVG' flag, sum(inapp_rev) metric
  from dpu
  where inapp_rev>0
  group by 1
  union all
  select dt_id, 'DIG0116' kpi_id, '' kpi_code, 'AVG' flag, sum(inapp_atl_rev) metric
  from dpu
  where inapp_atl_rev>0
  group by 1
  union all
  select dt_id, 'DIG0117' kpi_id, '' kpi_code, 'AVG' flag, sum(inapp_cvm_rev) metric
  from dpu
  where inapp_cvm_rev>0
  group by 1
  union all
  select dt_id, 'DIG0118' kpi_id, '' kpi_code, 'AVG' flag, sum(online_rev) metric
  from dpu
  where online_rev>0
  group by 1
  union all
  select dt_id, 'DIG0119' kpi_id, '' kpi_code, 'AVG' flag, sum(online_atl_rev) metric
  from dpu
  where online_atl_rev>0
  group by 1
  union all
  select dt_id, 'DIG0120' kpi_id, '' kpi_code, 'AVG' flag, sum(online_cvm_rev) metric
  from dpu
  where online_cvm_rev>0
  group by 1
  union all
  select dt_id, 'DIG0121' kpi_id, '' kpi_code, 'AVG' flag, sum(vas_rev) metric
  from dpu
  where vas_rev > 0
  group by 1
  union all
  select dt_id, 'DIG0122' kpi_id, '' kpi_code, 'AVG' flag, sum(reload) metric
  from dpu
  where reload>0
  group by 1
  union all
  select dt_id, 'DIG0123' kpi_id, '' kpi_code, 'AVG' flag, sum(p2p_topup) metric
  from dpu
  where p2p_topup>0
  group by 1
)
select 'TRI' brand, kpi_code, flag, metric, current_timestamp() process_dt, kpi_id, dt_id from fnl
;