declare vdt_id date default @vdt_id;
delete from `data-bi-prd-935c.bi_mart`.kpi_national_tracker_dly where dt_id = vdt_id and brand = 'IM3' and kpi_id in (
'DAT0019',
'DAT0021',
'DAT0022',
'DAT0018',
'DAT0020'
);

insert into  `data-bi-prd-935c.bi_mart`.kpi_national_tracker_dly 
with ggsn_30d as (
	select vdt_id dt_id, technology, sum(metrics) subs
	from (
		select a.*, row_number() over (partition by kpi, subs_flag, technology order by ppn_dttm desc) rk
		from `data-bi-prd-935c.bi_mart`.ggsn_rg_dly_smy a
		where dt_id = vdt_id
			and subs_flag like 'Prepaid%'
			and kpi in ('SUBS 30D')
	) a
	where rk = 1
  group by 1,2
),
nio_5g_30d as (
	select vdt_id dt_id, count(distinct msisdn) subs, round(sum(volume_in+volume_out)/1024/1024/1024,2) vol_gb
	from `data-dtp-prd-aa1a.stg`.stg_nio_appsrtgout_5g
	where dt_id between timestamp(vdt_id - interval 29 day) and timestamp(vdt_id)
		and (volume_in+volume_out)>0
		and left(msisdn,5) IN ('62814','62815','62816','62855','62856','62857','62858')
),
fnl as (
	-- DATA UU 30D
	select dt_id, 'DAT0019' kpi_id, 'data_uu_30d_5g' kpi_code, subs metric from nio_5g_30d
	union all
	select coalesce(a.dt_id,b.dt_id) dt_id
		, 'DAT0020' kpi_id, 'data_uu_30d_4g' kpi_code
		, coalesce(a.subs,0)-coalesce(b.subs,0) metric
	from ggsn_30d a
	full join nio_5g_30d
		b on a.dt_id = b.dt_id
	where technology = '4G'
	union all
	select dt_id, case when technology='3G' then 'DAT0021' else 'DAT0022' end kpi_id
		, case when technology='3G' then 'data_uu_30d_3g' else 'data_uu_30d_2g' end kpi_code
		, subs metric
	from ggsn_30d
	where technology in ('3G','2G')
)
select 'IM3' brand, kpi_code, 'MTD' flag, metric,  timestamp(current_datetime('+7')) process_dt, kpi_id, dt_id from fnl
union all
select 'IM3' brand, 'data_uu_30d' kpi_code, 'MTD' flag, sum(metric) metric,  timestamp(current_datetime('+7')) process_dt, 'DAT0018' kpi_id, dt_id
from fnl
where kpi_id in ('DAT0019','DAT0020','DAT0021','DAT0022')
group by dt_id
;
