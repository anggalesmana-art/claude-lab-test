 DECLARE vdt_id DATE DEFAULT @vdt_id;

delete from `data-bi-prd-935c.bi_mart.bima_mau_dly` where dt_id = vdt_id;
  insert into `data-bi-prd-935c.bi_mart.bima_mau_dly`
  select cast(vdt_id as date) dt_id
    , x.msisdn
    , max(case when max_dt=dt_id then subscriber_type end) subscriber_type
    , max(actvn_dt)
    , max(tnr) tnr
    , min(dt_id) dt_min
    , max(dt_id) dt_max
    , count(distinct dt_id) active_days
    , sum(total_trx) total_trx
    , sum(inapp_rev) inapp_rev
    , sum(online_rev) online_rev
    , sum(cvm_rev) cvm_rev
    , sum(hits_trx) hits_trx
    , y.site_id_90
    , current_timestamp() process_dt
  from
  (
    select a.*, max(dt_id) over (partition by msisdn) as max_dt
    from `data-bi-prd-935c.bi_mart.bima_dly` a
    where dt_id >= date_sub(vdt_id, interval 30 day) and dt_id <= vdt_id
      and bima_flag like '%A%'
  ) x
  left join
  (
    select sbscrptn_msisdn , site_id_90
    from
    (
      select sbscrptn_msisdn , site_id_90, row_number() over(partition by dt, sbscrptn_msisdn order by sbscrptn_ek_id desc) as rk
      from `data-bi-prd-935c.bi_mart.ioh_subscriber_site_attribs_rolling`
      where dt=vdt_id and site_id_90 is not null
    ) x
    where rk=1
  ) y
    on x.msisdn=y.sbscrptn_msisdn
    where x.msisdn like '6289%'
  group by msisdn, site_id_90
  ;