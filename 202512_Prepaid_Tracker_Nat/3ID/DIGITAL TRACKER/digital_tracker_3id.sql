-- Done changed Arie
BEGIN
  declare vdt_id default @vdt_id;

  delete from `data-bi-prd-935c.bi_mart.digital_tracker_site` where dt_id = date(vdt_id);

  insert into `data-bi-prd-935c.bi_mart.digital_tracker_site`(dt_id, brand, kpi_id, kpi_code, flag, site_id, metric, process_dt)
  with active_days as (
    select date(vdt_id) dt_id, 
    site_id, 
    avg(ndt) avg_active_days
    from (
      SELECT msisdn, site_id, count(distinct dt_id) ndt
      from `data-bi-prd-935c.bi_mart.bima_dly`
      where dt_id>=DATE_SUB(date(vdt_id), INTERVAL 29 DAY) and dt_id<=date(vdt_id)
          and bima_flag like '%P%'
      group by 1,2
    ) x group by site_id
  ),
  data_user as (
    SELECT date(load_dt_sk_id) dt_id, site_id, sum(value) metric
    -- FROM `data-bi-prd-935c.bi_mart.project_ioh_kpi_daily_tracker_site`
    FROM `data-bi-prd-935c.bi_mart.project_ioh_kpi_daily_tracker_site` --change by Indra Maulana Ikhsan because mis.project_ioh_kpi_daily_tracker_national_wise is a part of part2 job and always updated when part2 done
    WHERE ---to_date(load_dt_sk_id::text,'YYYYMMDD') BETWEEN :dt_start and :dt_end
    load_dt_sk_id = date(vdt_id) 
        AND kpi_code='rgu30_data'
    group by 1,2
  ),
  mau as (
    select dt_id, msisdn, site_id, case when coalesce(tnr,0) <= 90 then 'AON<=90' else 'AON>90' end AON_GROUP, active_days
    from `data-bi-prd-935c.bi_mart.bima_mau_dly`
    where  dt_id = date(vdt_id) 
  ),
  mpu as (
    select dt_id, site_id, case when coalesce(tnr,0) <= 90 then 'AON<=90' else 'AON>90' end AON_GROUP, count(1) metric
    from `data-bi-prd-935c.bi_mart.bima_mpu_dly`
    where 
    dt_id = date(vdt_id) 
    group by 1,2,3
  ),
  dau as (
    select date(vdt_id) as dt_id, site_id, case when coalesce(tnr,0) <= 90 then 'AON<=90' else 'AON>90' end AON_GROUP, count(1) metric
    from  `data-bi-prd-935c.bi_mart.bima_dly`
    where bima_flag like '%A%'
    and dt_id between DATE_TRUNC(DATE(vdt_id), MONTH) and date(vdt_id) 
    group by 1,2,3
  ),
  dpu as (
    select date(vdt_id) as dt_id, site_id, case when coalesce(tnr,0) <= 90 then 'AON<=90' else 'AON>90' end AON_GROUP
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
    and dt_id between DATE_TRUNC(DATE(vdt_id), MONTH) and date(vdt_id) 
    group by 1,2,3
  ),
  fnl as (
    select dt_id, site_id, 'DIG0001' kpi_id, 'myim3_bima_potential_users' kpi_code, 'MTD' flag, metric 
    from data_user   --> ini active user per site. 
    union all
    select dt_id, site_id, 'DIG0003' kpi_id, 'myim3_bima_mau' kpi_code, 'MTD' flag, count(1) metric 
    from mau group by 1,2
    union all
    select dt_id
      , site_id
      , case when aon_group='AON<=90' then 'DIG0004' else 'DIG0005' end kpi_id
      , case when aon_group='AON<=90' then 'myim3_bima_mau_inflow' else 'myim3_bima_mau_base' end kpi_code
      , 'MTD' flag
      , count(1) metric
    from mau
    group by 1,2,3,4
    union all
    select dt_id, site_id, 'DIG0006' kpi_id, 'myim3_bima_dau' kpi_code, 'AVG' flag, sum(metric) metric 
    from dau group by 1,2
    union all
    select dt_id
      , site_id
      , case when aon_group='AON<=90' then 'DIG0007' else 'DIG0008' end kpi_id
      , case when aon_group='AON<=90' then 'myim3_bima_dau_inflow' else 'myim3_bima_dau_base' end kpi_code
      , 'AVG' flag
      , metric
    from dau
    union all
    select dt_id, site_id, 'DIG0009.1' kpi_id, 'myim3_bima_active_days_nod' kpi_code, 'MTD' flag, sum(active_days) metric
    from ( select distinct dt_id, site_id, msisdn, active_days from mau) x
    group by 1,2
    union all
    select dt_id, site_id, 'DIG0009.2' kpi_id, 'myim3_bima_active_days_subscnt' kpi_code, 'MTD' flag, count(distinct msisdn) metric
    from ( select distinct dt_id, site_id, msisdn, active_days from mau) x
    group by 1,2
    union all
    select dt_id, site_id, 'DIG0011' kpi_id, 'myim3_bima_mpu' kpi_code, 'MTD' flag, sum(metric) from mpu group by 1,2
    union all
    select dt_id
      , site_id
      , case when aon_group='AON<=90' then 'DIG0012' else 'DIG0013' end kpi_id
      , case when aon_group='AON<=90' then 'myim3_bima_mpu_inflow' else 'myim3_bima_mpu_base' end kpi_code
      , 'MTD' flag
      , sum(metric)
    from mpu
    group by 1,2,3,4
    union all
    select dt_id, site_id, 'DIG0014' kpi_id, 'myim3_bima_dpu' kpi_code, 'AVG' flag, sum(metric) metric 
    from dpu 
    group by 1,2
    union all
    select dt_id
      , site_id
      , case when aon_group='AON<=90' then 'DIG0015' else 'DIG0016' end kpi_id
      , case when aon_group='AON<=90' then 'myim3_bima_dpu_inflow' else 'myim3_bima_dpu_base' end kpi_code
      , 'AVG' flag  --> ori MTD
      , metric
    from dpu
    union all
    select dt_id, site_id, 'DIG0101' kpi_id, 'dig_core_val_dly' kpi_code, 'AVG' flag, sum(total_trx) metric
    from dpu
    where total_trx>0
    group by 1,2
    union all
    select dt_id, site_id, 'DIG0115' kpi_id, 'dig_core_val_apps_dly' kpi_code, 'AVG' flag, sum(inapp_rev) metric
    from dpu
    where inapp_rev>0
    group by 1,2
    union all
    select dt_id, site_id, 'DIG0116' kpi_id, 'dig_core_val_apps_atl_dly' kpi_code, 'AVG' flag, sum(inapp_atl_rev) metric
    from dpu
    where inapp_atl_rev>0
    group by 1,2
    union all
    select dt_id, site_id, 'DIG0117' kpi_id, 'dig_core_val_apps_cvm_dly' kpi_code, 'AVG' flag, sum(inapp_cvm_rev) metric
    from dpu
    where inapp_cvm_rev>0
    group by 1,2
    union all
    select dt_id, site_id, 'DIG0118' kpi_id, 'dig_core_val_online_dly' kpi_code, 'AVG' flag, sum(online_rev) metric
    from dpu
    where online_rev>0
    group by 1,2
    union all
    select dt_id, site_id, 'DIG0119' kpi_id, 'dig_core_val_online_atl_dly' kpi_code, 'AVG' flag, sum(online_atl_rev) metric
    from dpu
    where online_atl_rev>0
    group by 1,2
    union all
    select dt_id, site_id, 'DIG0120' kpi_id, 'dig_core_val_online_cvm_dly' kpi_code, 'AVG' flag, sum(online_cvm_rev) metric
    from dpu
    where online_cvm_rev>0
    group by 1,2
    union all
    select dt_id, site_id, 'DIG0121' kpi_id, 'dig_core_val_vas_dly' kpi_code, 'AVG' flag, sum(vas_rev) metric
    from dpu
    where vas_rev>0
    group by 1,2
    union all
    select dt_id, site_id, 'DIG0122' kpi_id, 'dig_core_val_rld_dly' kpi_code, 'AVG' flag, sum(reload) metric
    from dpu
    where reload>0
    group by 1,2
    union all
    select dt_id, site_id, 'DIG0123' kpi_id, 'dig_core_val_p2p_topup_dly' kpi_code, 'AVG' flag, sum(p2p_topup) metric 
    from dpu where p2p_topup>0 
    group by 1,2
  ),
  fnl_mtd as (
    select 'myim3_bima_paid_days' kpi_code, 'MTD' flag, round(avg_active_days,2) metric, 'DIG0017' kpi_id, site_id, dt_id 
    from active_days
    union all
    select 'dig_core_val_apps' kpi_code, 'MTD' flag, round(inapp_rev,2) metric, 'DIG0124' kpi_id, site_id, dt_id
    from dpu
    where inapp_rev>0
    union all
    select 'dig_core_val_apps_atl' kpi_code, 'MTD' flag, round(inapp_atl_rev,2) metric, 'DIG0125' kpi_id, site_id, dt_id
    from dpu
    where inapp_atl_rev>0
    union all
    select 'dig_core_val_apps_cvm' kpi_code, 'MTD' flag, round(inapp_cvm_rev,2) metric, 'DIG0126' kpi_id, site_id, dt_id
    from dpu
    where inapp_cvm_rev>0
    union all
    select 'dig_core_val_online' kpi_code, 'MTD' flag, round(online_rev,2) metric, 'DIG0127' kpi_id, site_id, dt_id
    from dpu
    where online_rev>0
    union all
    select 'dig_core_val_online_atl' kpi_code, 'MTD' flag, round(online_atl_rev,2) metric, 'DIG0128' kpi_id, site_id, dt_id
    from dpu
    where online_atl_rev>0
    union all
    select 'dig_core_val_online_cvm' kpi_code, 'MTD' flag, round(online_cvm_rev,2) metric, 'DIG0129' kpi_id, site_id, dt_id
    from dpu
    where online_cvm_rev>0
    union all
    select 'dig_core_val_vas' kpi_code, 'MTD' flag, round(vas_rev,2) metric, 'DIG0130' kpi_id, site_id, dt_id
    from dpu
    where vas_rev>0
    union all
    select 'dig_core_val_rld' kpi_code, 'MTD' flag, round(reload,2) metric, 'DIG0131' kpi_id, site_id, dt_id
    from dpu
    where reload>0
    union all
    select 'dig_core_val_p2p_topup' kpi_code, 'MTD' flag, round(p2p_topup,2) metric, 'DIG0132' kpi_id, site_id, dt_id
    from dpu
    where p2p_topup>0
    union all
    select 'dig_core_val' kpi_code, 'MTD' flag, round(total_trx,2) metric, 'DIG0108' kpi_id, site_id, dt_id
    from dpu
  ),
  merges as (
  select date(vdt_id) , 'TRI' brand, kpi_id, kpi_code, flag, site_id, cast(metric as numeric), CURRENT_TIMESTAMP() process_dt from fnl
  union all 
  select date(vdt_id) , 'TRI' brand, kpi_id, kpi_code, flag, site_id, cast(metric as numeric), CURRENT_TIMESTAMP() process_dt from fnl_mtd
  )
  select * from merges;
END