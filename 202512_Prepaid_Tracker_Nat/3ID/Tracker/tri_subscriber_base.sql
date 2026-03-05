DECLARE vdt_id DATE DEFAULT @vdt_id;

delete from `data-bi-prd-935c.bi_mart.kpi_national_tracker_dly` where brand = 'TRI' and dt_id = vdt_id and kpi_id in (select distinct kpi_id_newtracker from `data-bi-prd-935c.bi_mart.das_kpi_cd_mapping`);

INSERT INTO `data-bi-prd-935c.bi_mart.kpi_national_tracker_dly` (brand, kpi_code, flag, metric, process_dt, kpi_id, dt_id)
select 
'TRI' as brand,
b.kpi_nm_newtracker,
b.flag_newtracker,
SUM(a.value) as metric,
current_timestamp(),
b.kpi_id_newtracker,
a.load_dt_sk_id
from `data-bi-prd-935c.bi_mart.project_ioh_kpi_daily_tracker_national_wise` a
join `data-bi-prd-935c.bi_mart.das_kpi_cd_mapping` b ON a.kpi_code = b.kpi_cd AND b.source_table = 'mis.project_ioh_kpi_daily_tracker_national_wise' 
where load_dt_sk_id = vdt_id and entity = 'H3I' and definition = 'IOH'
group by brand, kpi_nm_newtracker, flag_newtracker, kpi_id_newtracker, load_dt_sk_id
;

INSERT INTO `data-bi-prd-935c.bi_mart.kpi_national_tracker_dly` (brand, kpi_code, flag, metric, process_dt, kpi_id, dt_id)
SELECT 
'TRI' as brand,
case 
when kpi_id in ('SUB0025','SUB0026') then 'VLR Attached Subs 90D'
when kpi_id in ('SUB0049','SUB0050') then 'VLR Attached Subs 30D'
end as kpi_nm,
'MTD',
SUM(metric) as calc_metric,
current_timestamp(),
case 
when kpi_id in ('SUB0025','SUB0026') then 'SUB0024'
when kpi_id in ('SUB0049','SUB0050') then 'SUB0048'
end as kpi_cd,
dt_id
FROM `data-bi-prd-935c.bi_mart.kpi_national_tracker_dly` 
where dt_id = vdt_id and kpi_id in ('SUB0025','SUB0026','SUB0049','SUB0050')  and brand = 'TRI'
group by brand, kpi_nm, kpi_cd, dt_id;