declare vdt_id date default @vdt_id;

delete from `data-bi-prd-935c.bi_mart`.myim3_subs_mau_dly where dt_id = vdt_id;
  insert into `data-bi-prd-935c.bi_mart`.myim3_subs_mau_dly
  select w.msisdn
    , max(case when max_dt=dt_id then subscriber_type end) subscriber_type
    , max(actvn_dt)
    , max(case when max_dt=dt_id then imei_id end) imei_id
    , max(case when max_dt=dt_id then svc_class_code end) svc_class_code
    , max(first_login_all) first_login_all
    , max(first_login_imi) first_login_imi
    , max(tnr) tnr
    , min(dt_id) dt_min
    , max(dt_id) dt_max
    , count(distinct dt_id) active_days
    , sum(total_trx) total_trx
    , sum(package_rev) package_rev
    , sum(hits_trx) hits_trx
    , sum(traffic_data_da_byte) traffic_data_da_byte
    , sum(traffic_data_all_byte) traffic_data_all_byte
    , sum(rgu_rev) rgu_rev
    , y.site_id
    , timestamp(current_datetime('+7')) ppn_dttm
    , sum(total_rev) total_rev
    , vdt_id dt_id
  from
  (
    select distinct msisdn
    from `data-analytics-prd-1b95.digital_sbx`.hen_prd_digital_din_mdi_new
    where date_partition = vdt_id and mau_imi = 1
  ) w
  left join
  (
    select a.*, max(dt_id) over (partition by msisdn) as max_dt
    from `data-bi-prd-935c.bi_mart`.myim3_subs_dly a
    where dt_id between vdt_id - interval 30 day and vdt_id
      and myim3_flag like '%A%'
  ) x
    on w.msisdn=x.msisdn
  left join
  (
    select msisdn, site_id
    from `data-bi-prd-935c.bi_mart`.all_90d_fav_loc_dly
    where dt_id=vdt_id
  ) y
    on w.msisdn=y.msisdn
  group by w.msisdn, y.site_id
  ;