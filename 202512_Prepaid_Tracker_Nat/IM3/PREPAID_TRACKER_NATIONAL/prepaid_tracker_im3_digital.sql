declare vdt_id date default @vdt_id;
delete from `data-bi-prd-935c.bi_mart`.kpi_national_tracker_dly where dt_id = vdt_id and brand = 'IM3' and kpi_id in (
'DIG0054',
'DIG0016',
'DIG0143',
'DIG0013',
'DIG0139',
'DIG0140',
'DIG0148',
'DIG0011',
'DIG0144',
'DIG0042',
'DIG0102',
'DIG0007',
'DIG0135',
'DIG0031',
'DIG0146',
'DIG0012',
'DIG0142',
'DIG0133',
'DIG0040',
'DIG0145',
'DIG0109',
'DIG0033',
'DIG0005',
'DIG0141',
'DIG0029',
'DIG0110',
'DIG0049',
'DIG0112',
'DIG0028',
'DIG0041',
'DIG0053',
'DIG0008',
'DIG0105',
'DIG0048',
'DIG0030',
'DIG0006',
'DIG0104',
'DIG0111',
'DIG0034',
'DIG0137',
'DIG0108',
'DIG0015',
'DIG0138',
'DIG0009',
'DIG0147',
'DIG0027',
'DIG0051',
'DIG0107',
'DIG0134',
'DIG0136',
'DIG0032',
'DIG0052',
'DIG0014',
'DIG0039',
'DIG0050',
'DIG0114',
'DIG0003',
'DIG0101',
'DIG0004',
'DIG0103',
'DIG0047'
);

insert into `data-bi-prd-935c.bi_mart`.kpi_national_tracker_dly
with
mau as (
  select dt_id, msisdn, if(coalesce(tnr,0) <= 90,'AON<=90','AON>90') aon_group, active_days
  from `data-bi-prd-935c.bi_mart`.myim3_subs_mau_dly
  WHERE dt_id between vdt_id and vdt_id
),
dau as (
  SELECT dt_id, if(coalesce(tnr,0) <= 90,'AON<=90','AON>90') aon_group, count(1) metric
  from `data-bi-prd-935c.bi_mart`.myim3_subs_dly
  where dt_id between vdt_id and vdt_id
      and myim3_flag like '%A%'
  group by 1,2
),
mpu as (
  select dt_id, if(coalesce(tnr,0) <= 90,'AON<=90','AON>90') aon_group
    , count(1) metric
    , sum(total_trx) total_trx
    , sum(pgi_package_rev+pgi_cvm_rev+pgi_package_cvm_rev+contract_renew_rev) online_rev
    , sum(pgi_package_rev) online_atl
    , sum(pgi_cvm_rev+pgi_package_cvm_rev) online_cvm
    , sum(contract_renew_rev) online_postpaid
    , sum(data_cvm_rev+data_noncvm_rev+voice_noncvm_rev+sms_noncvm_rev+airtime_postpaid_rev+vas_rev+p2ppackage_rev) as airtime_rev
    , sum(data_cvm_rev) as airtime_cvm
    , sum(data_noncvm_rev+voice_noncvm_rev+sms_noncvm_rev+airtime_postpaid_rev) as airtime_atl
    , sum(vas_rev) as airtime_vas
    , sum(p2ppackage_rev) as airtime_kios_pkg
    , sum(advpayment_rev) advpayment_rev
    , sum(billpay_rev) billpay_rev
    , sum(p2ptopupmobo_rev) p2ptopupmobo_rev
    , sum(reload_amt) reload_amt
  from `data-bi-prd-935c.bi_mart`.myim3_subs_mpu_dly
  WHERE dt_id between vdt_id and vdt_id
  group by 1,2
),
dpu as (
  SELECT dt_id, if(coalesce(tnr,0) <= 90,'AON<=90','AON>90') aon_group
    , count(1) metric
    , sum(total_trx) total_trx
    , sum(pgi_package_rev+pgi_cvm_rev+pgi_package_cvm_rev+contract_renew_rev) online_rev
    , sum(pgi_package_rev) online_atl
    , sum(pgi_cvm_rev+pgi_package_cvm_rev) online_cvm
    , sum(contract_renew_rev) online_postpaid
    , sum(data_cvm_rev+data_noncvm_rev+voice_noncvm_rev+sms_noncvm_rev+airtime_postpaid_rev+vas_rev+p2ppackage_rev) as airtime_rev
    , sum(data_cvm_rev) as airtime_cvm
    , sum(data_noncvm_rev+voice_noncvm_rev+sms_noncvm_rev+airtime_postpaid_rev) as airtime_atl
    , sum(vas_rev) as airtime_vas
    , sum(p2ppackage_rev) as airtime_kios_pkg
    , sum(advpayment_rev) advpayment_rev
    , sum(billpay_rev) billpay_rev
    , sum(p2ptopupmobo_rev) p2ptopupmobo_rev
    , sum(reload_amt) reload_amt
  from `data-bi-prd-935c.bi_mart`.myim3_subs_dly
  where dt_id between vdt_id and vdt_id
      and myim3_flag like '%P%'
  group by 1,2
),
dpu_trx as (
  /* total trx */
  select dt_id, 'DIG0101' kpi_id, '' kpi_code, 'AVG' flag, sum(total_trx) metric
  from dpu
  where total_trx>0
  group by 1
  union all
  /* online revenue */
  select dt_id, 'DIG0133' kpi_id, '' kpi_code, 'AVG' flag, sum(online_rev) metric
  from dpu
  where online_rev>0
  group by 1
  union all
  /* online atl */
  select dt_id, 'DIG0134' kpi_id, '' kpi_code, 'AVG' flag, sum(online_atl) metric
  from dpu
  where online_atl>0
  group by 1
  union all
  /* online cvm */
  select dt_id, 'DIG0135' kpi_id, '' kpi_code, 'AVG' flag, sum(online_cvm) metric
  from dpu
  where online_cvm>0
  group by 1
  union all
  /* online Postpaid Renewal Contract */
  select dt_id, 'DIG0103' kpi_id, '' kpi_code, 'AVG' flag, sum(online_postpaid) metric
  from dpu
  where online_postpaid>0
  group by 1
  union all
  /* Airtime Revenue */
  select dt_id, 'DIG0136' kpi_id, '' kpi_code, 'AVG' flag, sum(airtime_rev) metric
  from dpu
  where airtime_rev>0
  group by 1
  union all
  /* Airtime atl */
  select dt_id, 'DIG0137' kpi_id, '' kpi_code, 'AVG' flag, sum(airtime_atl) metric
  from dpu
  where airtime_atl>0
  group by 1
  union all
  /* Airtime cvm */
  select dt_id, 'DIG0138' kpi_id, '' kpi_code, 'AVG' flag, sum(airtime_cvm) metric
  from dpu
  where airtime_cvm>0
  group by 1
  union all
  /* Airtime vas */
  select dt_id, 'DIG0139' kpi_id, '' kpi_code, 'AVG' flag, sum(airtime_vas) metric
  from dpu
  where airtime_vas>0
  group by 1
  union all
  /* airtime kios package */
  select dt_id, 'DIG0140' kpi_id, '' kpi_code, 'AVG' flag, sum(airtime_kios_pkg) metric
  from dpu
  where airtime_kios_pkg>0
  group by 1
  /* adv payment */
  union all
  select dt_id, 'DIG0102' kpi_id, '' kpi_code, 'AVG' flag, sum(advpayment_rev) metric
  from dpu
  where advpayment_rev>0
  group by 1
  union all
  /* bill pay */
  select dt_id, 'DIG0104' kpi_id, '' kpi_code, 'AVG' flag, sum(billpay_rev) metric
  from dpu
  where billpay_rev>0
  group by 1
  union all
  /* p2p topup mobo */
  select dt_id, 'DIG0105' kpi_id, '' kpi_code, 'AVG' flag, sum(p2ptopupmobo_rev) metric
  from dpu
  where p2ptopupmobo_rev>0
  group by 1
  union all
  /* reload */
  select dt_id, 'DIG0107' kpi_id, '' kpi_code, 'AVG' flag, sum(reload_amt) metric
  from dpu
  where reload_amt>0
  group by 1
),
mpu_trx as (
  /* total trx */
  select dt_id, 'DIG0108' kpi_id, '' kpi_code, 'mtd' flag, sum(total_trx) metric
  from mpu
  where total_trx>0
  group by 1
  union all
  /* online revenue */
  select dt_id, 'DIG0141' kpi_id, '' kpi_code, 'mtd' flag, sum(online_rev) metric
  from mpu
  where online_rev>0
  group by 1
  union all
  /* online atl */
  select dt_id, 'DIG0142' kpi_id, '' kpi_code, 'mtd' flag, sum(online_atl) metric
  from mpu
  where online_atl>0
  group by 1
  union all
  /* online cvm */
  select dt_id, 'DIG0143' kpi_id, '' kpi_code, 'mtd' flag, sum(online_cvm) metric
  from mpu
  where online_cvm>0
  group by 1
  union all
  /* online Postpaid Renewal Contract */
  select dt_id, 'DIG0110' kpi_id, '' kpi_code, 'mtd' flag, sum(online_postpaid) metric
  from mpu
  where online_postpaid>0
  group by 1
  union all
  /* Airtime Revenue */
  select dt_id, 'DIG0144' kpi_id, '' kpi_code, 'mtd' flag, sum(airtime_rev) metric
  from mpu
  where airtime_rev>0
  group by 1
  union all
  /* Airtime atl */
  select dt_id, 'DIG0145' kpi_id, '' kpi_code, 'mtd' flag, sum(airtime_atl) metric
  from mpu
  where airtime_atl>0
  group by 1
  union all
  /* Airtime cvm */
  select dt_id, 'DIG0146' kpi_id, '' kpi_code, 'mtd' flag, sum(airtime_cvm) metric
  from mpu
  where airtime_cvm>0
  group by 1
  union all
  /* Airtime vas */
  select dt_id, 'DIG0147' kpi_id, '' kpi_code, 'mtd' flag, sum(airtime_vas) metric
  from mpu
  where airtime_vas>0
  group by 1
  union all
  /* airtime kios package */
  select dt_id, 'DIG0148' kpi_id, '' kpi_code, 'mtd' flag, sum(airtime_kios_pkg) metric
  from mpu
  where airtime_kios_pkg>0
  group by 1
  /* adv payment */
  union all
  select dt_id, 'DIG0109' kpi_id, '' kpi_code, 'mtd' flag, sum(advpayment_rev) metric
  from mpu
  where advpayment_rev>0
  group by 1
  union all
  /* bill pay */
  select dt_id, 'DIG0111' kpi_id, '' kpi_code, 'mtd' flag, sum(billpay_rev) metric
  from mpu
  where billpay_rev>0
  group by 1
  union all
  /* p2p topup mobo */
  select dt_id, 'DIG0112' kpi_id, '' kpi_code, 'mtd' flag, sum(p2ptopupmobo_rev) metric
  from mpu
  where p2ptopupmobo_rev>0
  group by 1
  union all
  /* reload */
  select dt_id, 'DIG0114' kpi_id, '' kpi_code, 'mtd' flag, sum(reload_amt) metric
  from mpu
  where reload_amt>0
  group by 1
),
myim3 as (
  /* MAU : [DIG0003,DIG0004,DIG0005] */
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
  /* DAU : [DIG0006,DIG0007,DIG0008] */
  select dt_id, 'DIG0006' kpi_id, 'myim3_bima_dau' kpi_code, 'AVG' flag, sum(metric) metric from dau group by 1
  union all
  select dt_id
    , case when aon_group='AON<=90' then 'DIG0007' else 'DIG0008' end kpi_id
    , case when aon_group='AON<=90' then 'myim3_bima_dau_inflow' else 'myim3_bima_dau_base' end kpi_code
    , 'MTD' flag
    , metric
  from dau
  union all
  /* DAU Active Days: [DIG0009] */
  select dt_id, 'DIG0009' kpi_id, 'myim3_bima_active_days' kpi_code, 'MTD' flag, round(avg(active_days),2) metric
  from ( select distinct dt_id, msisdn, active_days from mau ) x
  group by 1
  union all
  /* MPU : [DIG0011,DIG0012,DIG0013] */
  select dt_id, 'DIG0011' kpi_id, 'myim3_bima_mpu' kpi_code, 'MTD' flag, sum(metric) metric from mpu group by 1
  union all
  select dt_id
    , case when aon_group='AON<=90' then 'DIG0012' else 'DIG0013' end kpi_id
    , case when aon_group='AON<=90' then 'myim3_bima_mpu_inflow' else 'myim3_bima_mpu_base' end kpi_code
    , 'MTD' flag
    , sum(metric) metric
  from mpu
  group by 1,2,3
  union all
  /* DPU : [DIG0014,DIG0015,DIG0016] */
  select dt_id, 'DIG0014' kpi_id, 'myim3_bima_dpu' kpi_code, 'AVG' flag, sum(metric) metric from dpu group by 1
  union all
  select dt_id
    , case when aon_group='AON<=90' then 'DIG0015' else 'DIG0016' end kpi_id
    , case when aon_group='AON<=90' then 'myim3_bima_dpu_inflow' else 'myim3_bima_dpu_base' end kpi_code
    , 'MTD' flag
    , metric
  from dpu
  union all
  select * from dpu_trx
  union all
  select * from mpu_trx
),
imkas_registered_users as (
  SELECT dt_id, parse_date('%Y%m%d',tgl_register) tgl_register,parse_date('%Y%m%d',tgl_upgrade) tgl_upgrade, registered_user_with_saldo, registered_user_without_saldo
    , case
      when regexp_contains(msisdn,'^62814|62815|62816|62855|62856|62857|62858') then 'IM3'
      when regexp_contains(msisdn,'^62895|62896|62897|62898|62899') then 'TRI'
      else 'Others'
    end brand
    , count(distinct norek_digibank) metric
  from (
    SELECT date(dt_id) dt_id, norek_digibank
      , case
        when coalesce(no_alt,no_hp) like '0%' then  regexp_replace( coalesce(no_alt,no_hp) , '^0','62')
        when coalesce(no_alt,no_hp) like '8%' then concat('62', coalesce(no_alt,no_hp))
      end msisdn
      , regexp_replace(substr(tgl_register,1,10),'-','') tgl_register
      , regexp_replace(substr(tgl_upgrade,1,10),'-','') tgl_upgrade
      , saldo
      , if(saldo>0, 1,0) registered_user_with_saldo
      , if(saldo>0, 0,1) registered_user_without_saldo
    from `data-dtp-prd-aa1a.stg`.imkas_dtl_subscription
    where date(dt_id) between vdt_id and vdt_id
      and status_blokir = 'Tidak'
  ) x
  WHERE tgl_register !=''
  group by 1,2,3,4,5,6
),
imkas_trx_dly as (
    select dt_id, msisdn
      , case
        when regexp_contains(msisdn,'^62814|62815|62816|62855|62856|62857|62858') then 'IM3'
        when regexp_contains(msisdn,'^62895|62896|62897|62898|62899') then 'TRI'
        else 'Others'
      end brand
      , case
        when grp in ('BULK TOPUP','TOPUP') then '1. Money/Cash In'
        when grp in ('CASHOUT') then '2. Money/Cash Out'
        when grp in ('BILL PAYMENT','MYIM3 BILL PAYMENT') then '3. Bill Pay'
        else '4. OTHERS'
      end typ
      , if(grp in ('CASHOUT','BILL PAYMENT','MYIM3 BILL PAYMENT'),'UTU','NON UTU') utu_flag
      , amount
    from `data-bi-prd-935c.bi_mart`.imkas_trx_dly
    where dt_id BETWEEN vdt_id and vdt_id
),
imkas as (
  -- registered users
  select dt_id, 'DIG0027' kpi_id, 'imkas_registered_users' kpi_code, 'MTD' flag, sum(metric) metric
  from imkas_registered_users
  group by 1
  union all
  select dt_id
    , case when brand='IM3' then 'DIG0028' when brand='TRI' then 'DIG0029' else 'DIG0030' end kpi_id
    , case when brand='IM3' then 'imkas_registered_users_im3' when brand='TRI' then 'imkas_registered_users_tri' else 'imkas_registered_users_others' end kpi_code
    , 'MTD' flag
    , sum(metric) metric
  from imkas_registered_users
  group by 1,2,3
  union all
  select dt_id, 'DIG0047' kpi_id, 'imkas_registered_with_saldo' kpi_code, 'MTD' flag, sum(metric) metric
  from imkas_registered_users
  where registered_user_with_saldo = 1
  group by 1
  union all
  select dt_id
    , case when brand='IM3' then 'DIG0048' when brand='TRI' then 'DIG0049' else 'DIG0050' end kpi_id
    , case
      when brand='IM3' then 'imkas_registered_with_saldo_im3'
      when brand='TRI' then 'imkas_registered_with_saldo_tri'
      else 'imkas_registered_with_saldo_others'
    end kpi_code
    , 'MTD' flag
    , sum(metric) metric
  from imkas_registered_users
  where registered_user_with_saldo = 1
  group by 1,2,3
  union all
  select dt_id, 'DIG0051' kpi_id, 'imkas_new_registered_users' kpi_code, 'MTD' flag, sum(metric) metric
  from imkas_registered_users
  where tgl_register = dt_id
  group by 1
  union all
  select dt_id
    , case when brand='IM3' then 'DIG0052' when brand='TRI' then 'DIG0053' else 'DIG0054' end kpi_id
    , case
      when brand='IM3' then 'imkas_new_registered_users_im3'
      when brand='TRI' then 'imkas_new_registered_users_tri'
      else 'imkas_new_registered_users_others'
    end kpi_code
    , 'MTD' flag
    , sum(metric) metric
  from imkas_registered_users
  where tgl_register = dt_id
  group by 1,2,3
  union all
  -- UTU
  select dt_id, 'DIG0031' kpi_id, 'imkas_utu_daily' kpi_code, 'AVG' flag, count(distinct msisdn) metric
  from imkas_trx_dly
  where utu_flag='UTU'
  group by 1
  union all
  select dt_id
    , case when brand='IM3' then 'DIG0032' when brand='TRI' then 'DIG0033' else 'DIG0034' end kpi_id
    , case when brand='IM3' then 'imkas_utu_daily_im3' when brand='TRI' then 'imkas_utu_daily_tri' else 'imkas_utu_daily_others' end kpi_code
    , 'AVG' flag
    , count(distinct msisdn) metric
  from imkas_trx_dly
  where utu_flag='UTU'
  group by 1,2,3
  union all
  select dt_id, 'DIG0039' kpi_id, 'imkas_val_daily' kpi_code, 'AVG' flag, round(sum(amount)) metric
  from imkas_trx_dly
  group by 1
  union all
  select dt_id
    , case when typ='1. Money/Cash In' then 'DIG0040' when typ='2. Money/Cash Out' then 'DIG0041' else 'DIG0042' end kpi_id
    , case
      when typ='1. Money/Cash In' then 'imkas_val_daily_cash_in'
      when typ='2. Money/Cash Out' then 'imkas_val_daily_cash_out'
      else 'imkas_val_daily_bill_pay'
    end kpi_code
    , 'AVG' flag
    , round(sum(amount)) metric
  from imkas_trx_dly
  where typ in ('1. Money/Cash In','2. Money/Cash Out','3. Bill Pay')
  group by 1,2,3
)
select 'IM3' brand, kpi_code, flag, metric, timestamp(current_datetime('+7')) process_dt, kpi_id, dt_id from myim3
union all
select 'IM3' brand, kpi_code, flag, metric, timestamp(current_datetime('+7')) process_dt, kpi_id, dt_id from imkas
;
