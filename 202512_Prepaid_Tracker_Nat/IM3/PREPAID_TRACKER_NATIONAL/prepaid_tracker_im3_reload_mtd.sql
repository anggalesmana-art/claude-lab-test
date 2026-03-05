declare vdt_id date default @vdt_id;
delete from `data-bi-prd-935c.bi_mart`.kpi_national_tracker_dly where dt_id = vdt_id and brand = 'IM3' and kpi_id in (
'RLD0014',
'RLD0008',
'RLD0012'
);

insert into `data-bi-prd-935c.bi_mart`.kpi_national_tracker_dly
with reload_mtd as (
  select vdt_id dt_id, kpi_name, sum(kpi_value) metric
  from `data-dtp-prd-aa1a.smy`.daily_kpi_tracker_national_wise_it_report
  where date(dt_id) between date_trunc(vdt_id,month) and vdt_id
  and kpi_name in ('9.1.2: Inject hit','9.1.4: Redemption','9.1.5: Redemption_hit','9.2.5: Redemption','9.2.6: hit')
	group by 1, 2
),
fnl as (
  select dt_id, 'RLD0008' kpi_id, 'voucher_hits_ftm' kpi_code, metric
  from reload_mtd
  where kpi_name = '9.1.2: Inject hit'
  union all
  select dt_id, 'RLD0012' kpi_id, 'redemption_amt_ftm' kpi_code, sum(metric) metric
  from reload_mtd
  where kpi_name in ('9.1.4: Redemption','9.2.5: Redemption')
  group by 1
  union all
  select dt_id, 'RLD0014' kpi_id, 'redemption_hits_ftm' kpi_code, sum(metric) metric
  from reload_mtd
  where kpi_name in ('9.1.5: Redemption_hit','9.2.6: hit')
  group by 1
)
select 'IM3' brand, kpi_code, 'MTD' flag, metric, timestamp(current_datetime('+7')) process_dt, kpi_id, dt_id from fnl
;
