declare vdt_id date default @vdt_id;

delete from `data-bi-prd-935c.bi_mart`.myim3_subs_mpu_dly where dt_id = vdt_id; 
insert into `data-bi-prd-935c.bi_mart`.myim3_subs_mpu_dly
select x.msisdn
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
  , sum(advpayment_rev) advpayment_rev
  , sum(billpay_rev) billpay_rev
  , sum(contract_renew_rev) contract_renew_rev
  , sum(p2ptopupmobo_rev) p2ptopupmobo_rev
  , sum(package_rev) package_rev
  , sum(pgi_package_rev) pgi_package_rev
  , sum(data_cvm_rev) data_cvm_rev
  , sum(voice_cvm_rev) voice_cvm_rev
  , sum(data_noncvm_rev) data_noncvm_rev
  , sum(voice_noncvm_rev) voice_noncvm_rev
  , sum(sms_noncvm_rev) sms_noncvm_rev
  , sum(airtime_postpaid_rev) airtime_postpaid_rev
  , sum(vas_rev) vas_rev
  , sum(reload_amt) reload_amt
  , sum(hits_trx) hits_trx
  , sum(traffic_data_da_byte) traffic_data_da_byte
  , sum(traffic_data_all_byte) traffic_data_all_byte
  , sum(rgu_rev) rgu_rev
  , y.site_id
  , timestamp(current_datetime('+7')) ppn_dttm
  , sum(pgi_cvm_rev) pgi_cvm_rev
  , sum(pgi_package_cvm_rev) pgi_package_cvm_rev
  , sum(p2ppackage_rev) p2ppackage_rev
  , sum(total_rev) total_rev
  , vdt_id dt_id
from
(
  select x.*, max(dt_id) over (partition by msisdn) as max_dt
  from `data-bi-prd-935c.bi_mart`.myim3_subs_dly x
  where dt_id between date_trunc(vdt_id,month) and vdt_id
    and myim3_flag like '%P%'
) x
left join
(
  select msisdn, site_id
  from `data-bi-prd-935c.bi_mart`.all_90d_fav_loc_dly
  where dt_id=vdt_id
) y
  on x.msisdn=y.msisdn
group by msisdn, site_id
;