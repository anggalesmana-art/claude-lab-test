declare vdt_id date default @vdt_id;
delete from `data-bi-prd-935c.bi_mart`.kpi_national_tracker_dly where dt_id = vdt_id and brand = 'IM3' and kpi_id in (
'DAT0002',
'DAT0006',
'DAT0015',
'DAT0004',
'DAT0003',
'DAT0008',
'DAT0017',
'DAT0007',
'DAT0001',
'DAT0005',
'DAT0016',
'DAT0013',
'DAT0028',
'DAT0014',
'DAT0029',
'DAT0030'
);

insert into `data-bi-prd-935c.bi_mart`.kpi_national_tracker_dly
with
data_ggsn as (
	select dt_id, kpi, technology, sum(metrics) metric
  from (
    select a.*, row_number() over (partition by dt_id, kpi, subs_flag, technology order by ppn_dttm desc) rk
    from `data-bi-prd-935c.bi_mart`.ggsn_rg_dly_smy a
    where dt_id between vdt_id and vdt_id
      and subs_flag like 'Prepaid%'
      and kpi in ('VOL GB DAILY','SUBS DAILY')
	) a
	where rk = 1
	group by 1, 2, 3
),
data_cs5 as (
	select date(daydate) dt_id, data_vol_traffic, round(sum(datavol/1024/1024/1024/1024),2) vol_tb, count(distinct subscriber) subs
	from `data-bi-prd-935c.bi_mart.usage_data_revcode_cs5_new`
	where date(daydate) between vdt_id and vdt_id
    and datavol > 0
	group by 1, 2
),
nio_5g as (
	select date(dt_id) dt_id, count(distinct msisdn) subs, round(sum(volume_in+volume_out)/1024/1024/1024/1024,2) vol_tb
	from `data-dtp-prd-aa1a.stg`.stg_nio_appsrtgout_5g
	where dt_id between timestamp(vdt_id) and timestamp(vdt_id)
	  and (volume_in+volume_out)>0
	  and left(msisdn,5) IN ('62814','62815','62816','62855','62856','62857','62858')
	group by 1
),
data_ggsn_trf as (
  select dt_id, round(sum(metric)/1024,2) as vol_tb
  from data_ggsn
  where kpi='VOL GB DAILY'
  group by 1
),
data_cs5_all as (
  select dt_id, sum(vol_tb) as vol_tb
  from data_cs5
  group by 1
),
data_pack as (
	select dt_id, sum(hits) hits, sum(rev) rev
	from (
		select msisdn, hits, rev, dt_id
		from `data-bi-prd-935c.bi_mart`.fact_product
		where dt_id between vdt_id and vdt_id
			and rev > 0 and pkg_source <> 'UMB'
		union all
		select msisdn, usg_hits  hits, data_rev AS rev, dt_id
		from `data-bi-prd-935c.bi_mart`.data_addon_dly
		where dt_id between vdt_id and vdt_id
			and data_rev >= 10
	) a
	group by 1
),
fnl as (
  select dt_id, 'DAT0001' kpi_id, 'data_trf_all' kpi_code, 'DLY' flag, vol_tb metric
  from data_ggsn_trf
  union all
  select a.dt_id, 'DAT0002' kpi_id, 'data_trf_billable' kpi_code, 'DLY' flag, round(sum(a.vol_tb*b.vol_tb/c.vol_tb),2) as metric from data_cs5 a
  left join data_ggsn_trf b on a.dt_id = b.dt_id
  left join data_cs5_all c on a.dt_id = c.dt_id
  where a.data_vol_traffic = 'Billable' group by 1, 2, 3, 4
  union all
  select a.dt_id, 'DAT0003' kpi_id, 'data_trf_bil_promo' kpi_code, 'DLY' flag, round(sum(a.vol_tb*b.vol_tb/c.vol_tb),2) as metric from data_cs5 a
  left join data_ggsn_trf b on a.dt_id = b.dt_id
  left join data_cs5_all c on a.dt_id = c.dt_id
  where a.data_vol_traffic = 'Billable Promo' group by 1, 2, 3, 4
  union all
  select a.dt_id, 'DAT0004' kpi_id, 'data_trf_unbillable' kpi_code, 'DLY' flag, round(sum(a.vol_tb*b.vol_tb/c.vol_tb),2) as metric from data_cs5 a
  left join data_ggsn_trf b on a.dt_id = b.dt_id
  left join data_cs5_all c on a.dt_id = c.dt_id
  where a.data_vol_traffic = 'Unbillable' group by 1, 2, 3, 4
  union all
  select dt_id, 'DAT0005' kpi_id, 'data_trf_5g' kpi_code, 'DLY' flag, vol_tb metric from nio_5g
  union all
  select a.dt_id, 'DAT0006' kpi_id, 'data_trf_4g' kpi_code, 'DLY' flag, round(coalesce(a.metric,0)/1024,2)-coalesce(b.vol_tb,0) metric
  from data_ggsn a
  left join nio_5g b on a.dt_id = b.dt_id
  where technology = '4G' and kpi='VOL GB DAILY'
  union all
  select dt_id, 'DAT0007' kpi_id, 'data_trf_3g' kpi_code, 'DLY' flag, round(metric/1024,2) metric
  from data_ggsn
  where technology = '3G' and kpi='VOL GB DAILY'
  union all
  select dt_id, 'DAT0008' kpi_id, 'data_trf_2g' kpi_code, 'DLY' flag, round(metric/1024,2) metric
  from data_ggsn
  where technology = '2G' and kpi='VOL GB DAILY'
  union all
  select dt_id, 'DAT0014' kpi_id, 'data_uu_dly_5g' kpi_code, 'AVG' flag, subs metric
  from nio_5g
  union all
  select a.dt_id, 'DAT0015' kpi_id, 'data_uu_dly_4g' kpi_code, 'AVG' flag, coalesce(a.metric,0)-coalesce(b.subs,0) metric
  from data_ggsn a
  left join nio_5g b on a.dt_id = b.dt_id
  where kpi = 'SUBS DAILY' and technology = '4G'
  union all
  select dt_id, 'DAT0016' kpi_id, 'data_uu_dly_3g' kpi_code, 'AVG' flag, metric
  from data_ggsn
  where kpi = 'SUBS DAILY' and technology = '3G'
  union all
  select dt_id, 'DAT0017' kpi_id, 'data_uu_dly_2g' kpi_code, 'AVG' flag, metric
  from data_ggsn
  where kpi = 'SUBS DAILY' and technology = '2G'
  union all
  select dt_id, 'DAT0028' kpi_id, 'subs_on_data_pack' kpi_code, 'AVG' flag, subs metric from data_cs5 where data_vol_traffic = 'Billable Promo'
  union all
  select dt_id, 'DAT0029' kpi_id, 'data_pack_sold' kpi_code, 'DLY' flag, sum(hits) metric from data_pack group by 1
  union all
  select dt_id, 'DAT0030' kpi_id, 'data_pack_rev' kpi_code, 'DLY' flag, round(sum(rev/1.11)) metric from data_pack group by 1
)
select 'IM3' brand, kpi_code, flag, metric, timestamp(current_datetime('+7')) process_dt, kpi_id, dt_id
from fnl
union all
select 'IM3' brand, 'data_uu_dly' kpi_code, 'AVG' flag, sum(metric) metric, timestamp(current_datetime('+7')) process_dt, 'DAT0013' kpi_id, dt_id
from fnl
where kpi_id in ('DAT0014','DAT0015','DAT0016','DAT0017')
group by dt_id