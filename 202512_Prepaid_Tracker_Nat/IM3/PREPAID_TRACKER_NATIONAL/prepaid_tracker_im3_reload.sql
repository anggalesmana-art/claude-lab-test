declare vdt_id date default @vdt_id;
delete from `data-bi-prd-935c.bi_mart`.kpi_national_tracker_dly where dt_id = vdt_id and brand = 'IM3' and kpi_id in (
'RLD0006',
'RLD0013',
'RLD0007',
'RLD0003',
'RLD0019',
'RLD0004',
'RLD0015',
'RLD0002',
'RLD0016',
'RLD0011',
'RLD0001',
'RLD0009',
'RLD0017',
'RLD0005',
'RLD0018'
);

insert into `data-bi-prd-935c.bi_mart`.kpi_national_tracker_dly
with
reload_dly as (
	select date(dt_id) dt_id, kpi_name, kpi_value
	from `data-dtp-prd-aa1a.smy`.daily_kpi_tracker_national_wise_it_report
	where date(dt_id) between vdt_id and vdt_id
    and kpi_name in ('9.0.1: Recharge Count - Total','9.0.2: Recharge Count - Unique','9.0.3: Recharge Count - MTD','9.0.4: Recharge Amount','9.0.7: Reload per Subs',
      '9.1.1: Inject','9.1.2: Inject hit','9.1.3: outlet_cnt','9.1.4: Redemption','9.1.5: Redemption_hit','9.2.5: Redemption','9.2.6: hit'
    )
),
sdp as (
  select date(dt_id) dt_id, msisdn, coalesce(balance,0) ma_bal
  from `data-dtp-prd-aa1a.smy`.ar_cst_dly_smy
  where date(dt_id) between vdt_id and vdt_id
    and upper(trim(ar_lcs_tp_nm))='ACTIVE'
),
da as (
  select date(dt_id) dt_id, case when regexp_contains(account_id,'^628')=False then concat('62',account_id) else account_id end msisdn
      , sum(coalesce(da_balance,da_unit_balance,0)) da_bal
  from `data-dtp-prd-aa1a.stg`.sdp_dedicated_account_shadow
  where date(dt_id) between vdt_id and vdt_id
  group by 1,2
),
balance as (
  select sdp.dt_id
    , case
      when ma_bal=0 and coalesce(da_bal,0)=0 then 'RLD0016'
      when ma_bal=0 and coalesce(da_bal,0)>0 then 'RLD0017'
      when ma_bal>0 and coalesce(da_bal,0)=0 then 'RLD0018'
      when ma_bal>0 and coalesce(da_bal,0)>0 then 'RLD0019'
    end kpi_id
    , case
      when ma_bal=0 and coalesce(da_bal,0)=0 then 'balance_ma_=_0__da_=_0'
      when ma_bal=0 and coalesce(da_bal,0)>0 then 'balance_ma_=_0__da_>_0'
      when ma_bal>0 and coalesce(da_bal,0)=0 then 'balance_ma_>_0__da_=_0'
      when ma_bal>0 and coalesce(da_bal,0)>0 then 'balance_ma_>_0__da_>_0'
    end kpi_code
    , 'AVG' flag
    , count(1) subs
    , round(sum(ma_bal)) ma_bal
    , sum(coalesce(da_bal,0)) da_bal
  from sdp
  left join da
    on sdp.dt_id=da.dt_id and sdp.msisdn=da.msisdn
  group by 1,2,3
),
reload as (
  select dt_id, 'RLD0001' kpi_id, 'reload_amt' kpi_code, 'DLY' flag, sum(kpi_value) metric from reload_dly
  where kpi_name = '9.0.4: Recharge Amount' group by 1, 2, 3, 4
  union all
  select dt_id, 'RLD0002' kpi_id, 'reload_cnt_total' kpi_code, 'AVG' flag, sum(kpi_value) metric from reload_dly
  where kpi_name = '9.0.1: Recharge Count - Total' group by 1, 2, 3, 4
  union all
  select dt_id, 'RLD0003' kpi_id, 'reload_unique_ftd' kpi_code, 'AVG' flag, sum(kpi_value) metric from reload_dly
  where kpi_name = '9.0.2: Recharge Count - Unique' group by 1, 2, 3, 4
  union all
  select dt_id, 'RLD0004' kpi_id, 'reload_unique_ftm' kpi_code, 'MTD' flag, sum(kpi_value) metric from reload_dly
  where kpi_name = '9.0.3: Recharge Count - MTD' group by 1, 2, 3, 4
  union all
  select dt_id, 'RLD0005' kpi_id, 'reload_per_subs' kpi_code, 'AVG' flag, sum(kpi_value) metric from reload_dly
  where kpi_name = '9.0.7: Reload per Subs' group by 1, 2, 3, 4
  union all
  -- RLD002 (Voucher Inject & Hits)
  select dt_id, 'RLD0006' kpi_id, 'voucher_inject' kpi_code, 'DLY' flag, sum(kpi_value) metric from reload_dly
  where kpi_name = '9.1.1: Inject' group by 1, 2, 3, 4
  union all
  select dt_id, 'RLD0007' kpi_id, 'voucher_hits_ftd' kpi_code, 'AVG' flag, sum(kpi_value) metric from reload_dly
  where kpi_name = '9.1.2: Inject hit' group by 1, 2, 3, 4
  union all
  select dt_id, 'RLD0009' kpi_id, 'outlet_ftd' kpi_code, 'AVG' flag, sum(kpi_value) metric from reload_dly
  where kpi_name = '9.1.3: outlet_cnt' group by 1, 2, 3, 4
  union all
  -- RLD003 (Redemption Amount & Hits)
  select dt_id, 'RLD0011' kpi_id, 'redemption_amt_ftd' kpi_code, 'AVG' flag, sum(kpi_value) metric from reload_dly
  where kpi_name in ('9.1.4: Redemption','9.2.5: Redemption') group by 1, 2, 3, 4
  union all
  select dt_id, 'RLD0013' kpi_id, 'redemption_hits_ftd' kpi_code, 'AVG' flag, sum(kpi_value) metric from reload_dly
  where kpi_name in ('9.1.5: Redemption_hit','9.2.6: hit') group by 1, 2, 3, 4
)
select 'IM3' brand, kpi_code, flag, metric, timestamp(current_datetime('+7')) ppn_dttm, kpi_id, dt_id from reload
union all
select 'IM3' brand, kpi_code, flag, subs metric, timestamp(current_datetime('+7')) ppn_dttm, kpi_id, dt_id from balance
union all
select 'IM3' brand, 'balance_closing' kpi_code, 'AVG' flag, sum(ma_bal) metric, timestamp(current_datetime('+7')) ppn_dttm, 'RLD0015' kpi_id, dt_id from balance
group by dt_id
