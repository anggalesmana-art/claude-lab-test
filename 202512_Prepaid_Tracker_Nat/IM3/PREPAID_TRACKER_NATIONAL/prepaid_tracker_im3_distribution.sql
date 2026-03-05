declare vdt_id date default @vdt_id;
--KPI NATIONAL TRACKER CSO
delete from `data-bi-prd-935c.bi_mart`.kpi_national_tracker_dly where dt_id = vdt_id and kpi_id = 'DST0008';
insert into `data-bi-prd-935c.bi_mart`.kpi_national_tracker_dly
select 'IM3' brand,kpi_code,'MTD' flag,sum(metric) metric,timestamp(current_datetime('+7')) process_dt,
case when kpi_id='SND069' then 'DST0008'
end kpi_id,dt_id
from `data-bi-prd-935c.bi_mart`.kpi_site_wise_dly
where dt_id = vdt_id
and kpi_id in ('SND069')
group by 1,2,3,5,6,7
;


delete from `data-bi-prd-935c.bi_mart`.kpi_national_tracker_dly
where dt_id = vdt_id and kpi_id in (
'DST0001',
'DST0002',
'DST0003',
'DST0004',
'DST0005',
'DST0006',
'DST0007',
'DST0009'
);

insert into `data-bi-prd-935c.bi_mart`.kpi_national_tracker_dly
select 'IM3' brand,kpi_code,'MTD' flag,sum(metric) metric,timestamp(current_datetime('+7')) process_dt,
case when kpi_id='SND025' then 'DST0001'
when kpi_id='SND030' then 'DST0002'
when kpi_id='SND026' then 'DST0003'
when kpi_id='SND029' then 'DST0004'
when kpi_id='SITE024' then 'DST0005'
when kpi_id='SITE025' then 'DST0006'
when kpi_id='SITE023' then 'DST0007'
when kpi_id='SND077' then 'DST0009'
end kpi_id,dt_id
from `data-bi-prd-935c.bi_mart`.kpi_site_wise_dly
where dt_id = vdt_id
and kpi_id in (--'SND026','SND029','SITE023','SITE024',
'SND025','SND030','SITE025','SND077','SND026','SND029','SITE025','SITE023','SITE024')
group by 1,2,3,5,6,7
;


delete from `data-bi-prd-935c.bi_mart`.kpi_national_tracker_dly where kpi_id = 'DST0008' and brand = 'IM3' and dt_id = vdt_id;
insert into `data-bi-prd-935c.bi_mart`.kpi_national_tracker_dly
select 'IM3' brand,kpi_code,'MTD' flag,sum(metric) metric,timestamp(current_datetime('+7')) process_dt,
case when kpi_id='SND069' then 'DST0008'
end kpi_id,dt_id
from `data-bi-prd-935c.bi_mart`.kpi_site_wise_dly
where dt_id = vdt_id
and kpi_id in ('SND069')
group by 1,2,3,5,6,7
;
