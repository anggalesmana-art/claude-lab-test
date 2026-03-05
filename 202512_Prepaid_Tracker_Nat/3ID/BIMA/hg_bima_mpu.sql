 DECLARE vdt_id DATE DEFAULT @vdt_id;

 -- MPU Calculation
    
    delete from `data-bi-prd-935c.bi_mart.bima_mpu_dly` where dt_id = vdt_id;
    insert into `data-bi-prd-935c.bi_mart.bima_mpu_dly`
    select cast(vdt_id as date)  dt_id
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
      , sum(reload) reload
      , sum(p2p_topup) p2p_topup
      , sum(vas_rev) vas_rev
      , sum(bill_pay) bill_pay
      , sum(cvm_rev) cvm_rev
      , sum(hits_trx) hits_trx
      , y.site_id
      , current_timestamp() process_dt
      , sum(inapp_atl_rev) inapp_atl_rev
      , sum(inapp_cvm_rev) inapp_cvm_rev
      , sum(online_atl_rev) online_atl_rev
      , sum(online_cvm_rev) online_cvm_rev
      , sum(voucher_reload) voucher_reload
      , sum(gift_cvm) gift_cvm
      , sum(gift_atl) gift_atl
      , sum(gift_reload) gift_reload
      , sum(gift_cvm_lego) gift_cvm_lego      
    from
    (
      select a.*, max(dt_id) over (partition by msisdn) as max_dt
      from `data-bi-prd-935c.bi_mart.bima_dly` a
      where dt_id >= date_trunc(vdt_id,month) and dt_id <= vdt_id
        and bima_flag like '%P%'
    ) x
    left join
    (
      select sbscrptn_msisdn msisdn, site_id_90 site_id
      from
      (
        select sbscrptn_msisdn , site_id_90, row_number() over(partition by dt, sbscrptn_msisdn order by sbscrptn_ek_id desc) as rk
        from `data-bi-prd-935c.bi_mart.ioh_subscriber_site_attribs_rolling`
        where dt = vdt_id and site_id_90 is not null
      ) x
      where rk=1
    ) y
      on x.msisdn=y.msisdn
    group by x.msisdn, y.site_id
    ;