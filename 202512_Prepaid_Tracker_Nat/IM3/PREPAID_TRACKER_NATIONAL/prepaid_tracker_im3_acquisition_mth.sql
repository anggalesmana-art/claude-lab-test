declare vdt_id date default @vdt_id;
-- always update from tgl 1
-- ACQ0001 s/d ACQ0010 (RGU GA Inject & Channel)
delete from `data-bi-prd-935c.bi_mart`.kpi_national_tracker_dly where brand = 'IM3' and dt_id between date_trunc(vdt_id,month) and vdt_id and kpi_id in ('ACQ0002','ACQ0003','ACQ0004','ACQ0005','ACQ0006','ACQ0007','ACQ0008','ACQ0009','ACQ0010');
insert into `data-bi-prd-935c.bi_mart`.kpi_national_tracker_dly
with
rgu_ga_channel as (
	select * from `data-bi-prd-935c.bi_mart`.rgs_ga_channel_dly_smy a
	where a.dt_id between date_trunc(vdt_id,month) and vdt_id
),
fnl as (
	select dt_id, 'ACQ0002' kpi_id, 'rgu_ga_wo_inject' kpi_code, sum(subs) metric from rgu_ga_channel
	where flag_inject is null
	group by 1
	union all
	select dt_id, 'ACQ0003' kpi_id, 'rgu_ga_inject' kpi_code, sum(subs) metric from rgu_ga_channel
	where flag_inject in ('HVC','MVC','LVC')
	group by 1
	union all
	select dt_id, 'ACQ0004' kpi_id, 'rgu_ga_inject_hvc' kpi_code, sum(subs) metric from rgu_ga_channel
	where flag_inject in ('HVC')
	group by 1
	union all
	select dt_id, 'ACQ0005' kpi_id, 'rgu_ga_inject_mvc' kpi_code, sum(subs) metric from rgu_ga_channel
	where flag_inject in ('MVC')
	group by 1
	union all
	select dt_id, 'ACQ0006' kpi_id, 'rgu_ga_inject_lvc' kpi_code, sum(subs) metric from rgu_ga_channel
	where flag_inject in ('LVC')
	group by 1
	union all
	select dt_id, 'ACQ0007' kpi_id, 'rgu_ga_trad' kpi_code, sum(subs) metric from rgu_ga_channel
	where channel_grp in ('DSF','TRADITIONAL')
	group by 1
	union all
	select dt_id, 'ACQ0008' kpi_id, 'rgu_ga_trad_dsf' kpi_code, sum(subs) metric from rgu_ga_channel
	where channel_grp in ('DSF')
	group by 1
	union all
	select dt_id, 'ACQ0009' kpi_id, 'rgu_ga_non_trad' kpi_code, sum(subs) metric from rgu_ga_channel
	where channel_grp in ('MODERN')
	group by 1
	union all
	select dt_id, 'ACQ0010' kpi_id, 'rgu_ga_others' kpi_code, sum(subs) metric from rgu_ga_channel
	where channel_grp is null
	group by 1
)
select 'IM3' brand, kpi_code, 'DLY' flag, metric, timestamp(current_datetime('+7')) ppn_dttm, kpi_id, dt_id from fnl
order by dt_id,kpi_id
;
