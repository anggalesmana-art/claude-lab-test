declare vdt_id date default @vdt_id;
-- regular update (daily)
delete from  `data-bi-prd-935c.bi_mart`.kpi_national_tracker_dly where brand = 'IM3' and dt_id = vdt_id and kpi_id like 'ACQ%' and kpi_id not in ('ACQ0002','ACQ0003','ACQ0004','ACQ0005','ACQ0006','ACQ0007','ACQ0008','ACQ0009','ACQ0010');
insert into `data-bi-prd-935c.bi_mart`.kpi_national_tracker_dly
with
rgu_ga_acq_rev as (
	select a.*, round((acq_rev/1.11)) as acq_rev2
	from `data-bi-prd-935c.bi_mart`.rgs_ga_channel_mtd_smy a
	where a.dt_id = vdt_id
),
rgu_ga_imei as (
	select * from `data-bi-prd-935c.bi_mart`.rgs_m1s_m2s_mtd_smy a
	where a.dt_id = vdt_id
    and kpi = 'Rot Churn'
),
-- ACQ0011 s/d ACQ0026 (Acq Revenue by Inject & Channel)
acq_rev as (
    select dt_id, 'ACQ0011' kpi_id, 'acq_rev_all' kpi_code, sum(acq_rev2) metric from rgu_ga_acq_rev
    group by 1
    union all
    select dt_id, 'ACQ0012' kpi_id, 'acq_rev_wo_inject' kpi_code, sum(acq_rev2) metric from rgu_ga_acq_rev
    where flag_inject is null group by 1
    union all
    select dt_id, 'ACQ0013' kpi_id, 'acq_rev_inject' kpi_code, sum(acq_rev2) metric from rgu_ga_acq_rev
    where flag_inject in ('HVC','MVC','LVC') group by 1
    union all
    select dt_id, 'ACQ0014' kpi_id, 'acq_rev_inject_hvc' kpi_code, sum(acq_rev2) metric from rgu_ga_acq_rev
    where flag_inject in ('HVC') group by 1
    union all
    select dt_id, 'ACQ0015' kpi_id, 'acq_rev_inject_mvc' kpi_code, sum(acq_rev2) metric from rgu_ga_acq_rev
    where flag_inject in ('MVC') group by 1
    union all
    select dt_id, 'ACQ0016' kpi_id, 'acq_rev_inject_lvc' kpi_code, sum(acq_rev2) metric from rgu_ga_acq_rev
    where flag_inject in ('LVC') group by 1
    union all
    select dt_id, 'ACQ0017' kpi_id, 'acq_rev_trad' kpi_code, sum(acq_rev2) metric from rgu_ga_acq_rev
    where channel_grp in ('DSF','TRADITIONAL') group by 1
    union all
    select dt_id, 'ACQ0018' kpi_id, 'acq_rev_trad_dsf' kpi_code, sum(acq_rev2) metric from rgu_ga_acq_rev
    where channel_grp in ('DSF') group by 1
    union all
    select dt_id, 'ACQ0019' kpi_id, 'acq_rev_non_trad' kpi_code, sum(acq_rev2) metric from rgu_ga_acq_rev
    where channel_grp in ('MODERN') group by 1
    union all
    select dt_id, 'ACQ0020' kpi_id, 'acq_rev_others' kpi_code, sum(acq_rev2) metric from rgu_ga_acq_rev
    where channel_grp is null group by 1
    union all
    select dt_id, 'ACQ0021' kpi_id, 'rotational_churn' kpi_code, sum(subs) metric from rgu_ga_imei
    where channel_grp = '2.Old IMEI' group by 1
    union all
    select dt_id, 'ACQ0022' kpi_id, 'acq_arpu_all' kpi_code, sum(acq_rev2)/sum(subs) metric from rgu_ga_acq_rev
    group by 1
    union all
    select dt_id, 'ACQ0023' kpi_id, 'acq_arpu_trad' kpi_code, sum(acq_rev2)/sum(subs) metric from rgu_ga_acq_rev
    where channel_grp in ('DSF','TRADITIONAL') group by 1
    union all
    select dt_id, 'ACQ0024' kpi_id, 'acq_arpu_trad_dsf' kpi_code, sum(acq_rev2)/sum(subs) metric from rgu_ga_acq_rev
    where channel_grp in ('DSF') group by 1
    union all
    select dt_id, 'ACQ0025' kpi_id, 'acq_arpu_non_trad' kpi_code, sum(acq_rev2)/sum(subs) metric from rgu_ga_acq_rev
    where channel_grp in ('MODERN') group by 1
    union all
    select dt_id, 'ACQ0026' kpi_id, 'acq_arpu_others' kpi_code, sum(acq_rev2)/sum(subs) metric from rgu_ga_acq_rev
    where channel_grp is null group by 1
),
-- ACQ0027 s/d ACQ0046 (M0 QSC, M1S, M2S, M0 FB)
m0_qsc as (
	select * from `data-bi-prd-935c.bi_mart`.rgs_m0_qsc_fb_user_mtd_smy a
	where a.dt_id = vdt_id
    and kpi = 'M0 QSC'
),
m1_survive as (
	select * from `data-bi-prd-935c.bi_mart`.rgs_m1s_m2s_mtd_smy a
	where a.dt_id = vdt_id
    and kpi = 'M1S'
),
m2_survive as (
	select * from `data-bi-prd-935c.bi_mart`.rgs_m1s_m2s_mtd_smy a
	where a.dt_id = vdt_id
    and kpi = 'M2S'
),
m0_fb_user as (
	select * from `data-bi-prd-935c.bi_mart`.rgs_m0_qsc_fb_user_mtd_smy a
	where a.dt_id = vdt_id
    and kpi = 'M0 FB User'
),
qoa as (
    select dt_id, 'ACQ0027' kpi_id, 'm0_qsc_all' kpi_code, sum(subs) metric from m0_qsc
    group by 1
    union all
    select dt_id, 'ACQ0028' kpi_id, 'm0_qsc_trad' kpi_code, sum(subs) metric from m0_qsc
    where channel_grp in ('DSF','TRADITIONAL') group by 1
    union all
    select dt_id, 'ACQ0029' kpi_id, 'm0_qsc_trad_dsf' kpi_code, sum(subs) metric from m0_qsc
    where channel_grp in ('DSF') group by 1
    union all
    select dt_id, 'ACQ0030' kpi_id, 'm0_qsc_non_trad' kpi_code, sum(subs) metric from m0_qsc
    where channel_grp in ('MODERN') group by 1
    union all
    select dt_id, 'ACQ0031' kpi_id, 'm0_qsc_others' kpi_code, sum(subs) metric from m0_qsc
    where channel_grp is null group by 1
    union all
    select dt_id, 'ACQ0032' kpi_id, 'm1s_all' kpi_code, sum(subs) metric from m1_survive
    group by 1
    union all
    select dt_id, 'ACQ0033' kpi_id, 'm1s_trad' kpi_code, sum(subs) metric from m1_survive
    where channel_grp in ('DSF','TRADITIONAL') group by 1
    union all
    select dt_id, 'ACQ0034' kpi_id, 'm1s_trad_dsf' kpi_code, sum(subs) metric from m1_survive
    where channel_grp in ('DSF') group by 1
    union all
    select dt_id, 'ACQ0035' kpi_id, 'm1s_non_trad' kpi_code, sum(subs) metric from m1_survive
    where channel_grp in ('MODERN') group by 1
    union all
    select dt_id, 'ACQ0036' kpi_id, 'm1s_others' kpi_code, sum(subs) metric from m1_survive
    where channel_grp is null group by 1
    union all
    select dt_id, 'ACQ0037' kpi_id, 'm2s_all' kpi_code, sum(subs) metric from m2_survive
    group by 1
    union all
    select dt_id, 'ACQ0038' kpi_id, 'm2s_trad' kpi_code, sum(subs) metric from m2_survive
    where channel_grp in ('DSF','TRADITIONAL') group by 1
    union all
    select dt_id, 'ACQ0039' kpi_id, 'm2s_trad_dsf' kpi_code, sum(subs) metric from m2_survive
    where channel_grp in ('DSF') group by 1
    union all
    select dt_id, 'ACQ0040' kpi_id, 'm2s_non_trad' kpi_code, sum(subs) metric from m2_survive
    where channel_grp in ('MODERN') group by 1
    union all
    select dt_id, 'ACQ0041' kpi_id, 'm2s_others' kpi_code, sum(subs) metric from m2_survive
    where channel_grp is null group by 1
    union all
    select dt_id, 'ACQ0042' kpi_id, 'm0_fb_user_all' kpi_code, sum(subs) metric from m0_fb_user
    group by 1
    union all
    select dt_id, 'ACQ0043' kpi_id, 'm0_fb_user_trad' kpi_code, sum(subs) metric from m0_fb_user
    where channel_grp in ('DSF','TRADITIONAL') group by 1
    union all
    select dt_id, 'ACQ0044' kpi_id, 'm0_fb_user_trad_dsf' kpi_code, sum(subs) metric from m0_fb_user
    where channel_grp in ('DSF') group by 1
    union all
    select dt_id, 'ACQ0045' kpi_id, 'm0_fb_user_non_trad' kpi_code, sum(subs) metric from m0_fb_user
    where channel_grp in ('MODERN') group by 1
    union all
    select dt_id, 'ACQ0046' kpi_id, 'm0_fb_user_others' kpi_code, sum(subs) metric from m0_fb_user
    where channel_grp is null group by 1
)
select 'IM3' brand, kpi_code, 'DLY' flag, round(metric) metric, timestamp(current_datetime('+7')) ppn_dttm, kpi_id, dt_id from acq_rev
union all
select 'IM3' brand, kpi_code, 'MTD' flag, metric, timestamp(current_datetime('+7')) ppn_dttm, kpi_id, dt_id from qoa
;