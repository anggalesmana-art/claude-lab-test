declare vdt_id date default @vdt_id;
delete from `data-bi-prd-935c.bi_mart`.kpi_national_tracker_dly where dt_id = vdt_id and brand = 'IM3' and kpi_id in (
'DIG0043',
'DIG0046',
'DIG0036',
'DIG0045',
'DIG0035',
'DIG0037',
'DIG0001',
'DIG0017',
'DIG0038',
'DIG0044'
);

insert into `data-bi-prd-935c.bi_mart`.kpi_national_tracker_dly
with potensial_user as (
  select vdt_id dt_id, 'DIG0001' kpi_id, 'myim3_bima_potential_users' kpi_code, count(distinct msisdn) metric
  from
  (
    select msisdn from `data-bi-prd-935c.bi_mart`.ggsn_rg_dly
    where dt_id between vdt_id - interval 29 day and vdt_id
    and rating_group not in ('23111', '55003', '70091')
    union all
    select msisdn from `data-analytics-prd-1b95.digital_sbx.din_master_data_imi`
    where mau_imi = 1 and date_partition = vdt_id
  ) x
),
active_days as (
  select vdt_id dt_id, avg(ndt) actv_days
  from (
    SELECT msisdn, count(distinct dt_id) ndt
    from `data-bi-prd-935c.bi_mart`.myim3_subs_dly
    where dt_id between vdt_id - interval 29 day and vdt_id
        and myim3_flag like '%P%'
    group by 1
  ) x
),
imkas as (
  select vdt_id dt_id, msisdn
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
  where dt_id between date_trunc(vdt_id,month) and vdt_id
),
fnl as (
  select dt_id, kpi_id, kpi_code, 'MTD' flag, metric from potensial_user
  union all
  select dt_id, 'DIG0017' kpi_id, 'myim3_bima_paid_days' kpi_code, 'MTD' flag, actv_days metric from active_days
  union all
  -- UTU
  select dt_id, 'DIG0035' kpi_id, 'imkas_utu_monthly' kpi_code, 'MTD' flag, count(distinct msisdn) metric
  from imkas
  where utu_flag='UTU'
  group by 1
  union all
  select dt_id
    , case when brand='IM3' then 'DIG0036' when brand='TRI' then 'DIG0037' else 'DIG0038' end kpi_id
    , case when brand='IM3' then 'imkas_utu_monthly_im3' when brand='TRI' then 'imkas_utu_monthly_tri' else 'imkas_utu_monthly_others' end kpi_code
    , 'MTD' flag
    , count(distinct msisdn) metric
  from imkas
  where utu_flag='UTU'
  group by 1,2,3
  union all
  select dt_id, 'DIG0043' kpi_id, 'imkas_val_monthly' kpi_code, 'MTD' flag, round(sum(amount)) metric
  from imkas
  group by 1
  union all
  select dt_id
    , case when typ='1. Money/Cash In' then 'DIG0044' when typ='2. Money/Cash Out' then 'DIG0045' else 'DIG0046' end kpi_id
    , case
      when typ='1. Money/Cash In' then 'imkas_val_monthly_cash_in'
      when typ='2. Money/Cash Out' then 'imkas_val_monthly_cash_out'
      else 'imkas_val_monthly_bill_pay'
    end kpi_code
    , 'MTD' flag
    , round(sum(amount)) metric
  from imkas
  where typ in ('1. Money/Cash In','2. Money/Cash Out','3. Bill Pay')
  group by 1,2,3
)
select 'IM3' brand, kpi_code, flag, metric, timestamp(current_datetime('+7')) process_dt, kpi_id, dt_id from fnl
;
