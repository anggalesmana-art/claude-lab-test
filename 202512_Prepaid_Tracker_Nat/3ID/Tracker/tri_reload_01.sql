
DECLARE vdt_id DATE DEFAULT @vdt_id;

delete from `data-bi-prd-935c.bi_mart.kpi_national_tracker_dly` where dt_id = vdt_id and brand ='TRI' and kpi_id in (
					'RLD0001','RLD0002','RLD0003','RLD0004','RLD0005','RLD0006','RLD0007',
					'RLD0008','RLD0009','RLD0010','RLD0011','RLD0012','RLD0013','RLD0014');

INSERT INTO `data-bi-prd-935c.bi_mart.kpi_national_tracker_dly`
select 
'TRI' as brand,
case 
when kpi_code = 'rech_cnt_tot' then 'Reload Count - TOTAL'
when kpi_code = 'rech_cnt_unq' then 'Reload Count - Unique - FTD'
when kpi_code = 'rech_cnt_mtd' then 'Reload Count - Unique - FTM'
when kpi_code = 'rech_amt' then 'Reload Amount'
when kpi_code = 'rech_vou_inj' then 'Inject'
when kpi_code = 'rech_vou_inj_cnt' then 'Hit - FTD'
when kpi_code = 'rech_vou_inj_ret' then 'Outlet - FTD'
when kpi_code = 'rech_vou_rdm' then 'Redemption - FTD'
when kpi_code = 'rech_vou_rdm_cnt' then 'Hit - FTD'
end as kpi,
case 
	when kpi_code in ('rech_cnt_tot','rech_cnt_unq','rech_vou_inj_cnt','rech_vou_inj_ret','rech_vou_rdm_cnt') then 'AVG'
	when kpi_code in ('rech_amt','rech_vou_inj','rech_vou_rdm') then 'DLY'
	when kpi_code in ('rech_cnt_mtd') then 'MTD'
end as flag,
coalesce(value,0) as metric,
current_timestamp() as process_dt,
case 
when kpi_code = 'rech_cnt_tot' then 'RLD0002'
when kpi_code = 'rech_cnt_unq' then 'RLD0003'
when kpi_code = 'rech_cnt_mtd' then 'RLD0004'
when kpi_code = 'rech_amt' then 'RLD0001'
when kpi_code = 'rech_vou_inj' then 'RLD0006'
when kpi_code = 'rech_vou_inj_cnt' then 'RLD0007'
when kpi_code = 'rech_vou_inj_ret' then 'RLD0009'
when kpi_code = 'rech_vou_rdm' then 'RLD0011'
when kpi_code = 'rech_vou_rdm_cnt' then 'RLD0013'
end as kpi,
load_dt_sk_id as dt_id
from `data-dtptechm-prd-c7ca.dwh.ioh_kpi_daily_tracker_national_wise`
where load_dt_sk_id = vdt_id and
kpi_code in ('rech_cnt_tot','rech_cnt_unq','rech_cnt_mtd','rech_amt','rech_vou_inj',
		'rech_vou_inj_cnt','rech_vou_inj_ret','rech_vou_rdm','rech_vou_rdm_cnt');

INSERT INTO `data-bi-prd-935c.bi_mart.kpi_national_tracker_dly`
select 
'TRI' as brand,
case 
when kpi_code = 'rech_vou_inj_cnt' then 'Hit - FTM'
--when kpi_code = 'rech_vou_inj_ret' then 'Outlet - FTM'
when kpi_code = 'rech_vou_rdm' then 'Redemption - FTM'
when kpi_code = 'rech_vou_rdm_cnt' then 'Redemption Hit - FTM'
end as kpi_cd,
'MTD' as flag,
sum(coalesce(value,0)) as metric,
current_timestamp() as process_dt,
case 
when kpi_code = 'rech_vou_inj_cnt' then 'RLD0008'
--when kpi_code = 'rech_vou_inj_ret' then 'RLD0010'
when kpi_code = 'rech_vou_rdm' then 'RLD0012'
when kpi_code = 'rech_vou_rdm_cnt' then 'RLD0014'
end as kpi,cast(vdt_id as date) as dt_id
from `data-dtptechm-prd-c7ca.dwh.ioh_kpi_daily_tracker_national_wise`
where (load_dt_sk_id between date_trunc(vdt_id,month) and vdt_id)  and
kpi_code in ('rech_vou_inj_cnt','rech_vou_rdm','rech_vou_rdm_cnt')
group by brand,kpi_cd,kpi,dt_id
order by kpi;

INSERT INTO `data-bi-prd-935c.bi_mart.kpi_national_tracker_dly`
select 
'TRI' as brand,
'Outlet - FTM' kpi_cd,
'MTD' as flag,
count(distinct qr_Cd) as metric,
current_timestamp() as process_dt,
'RLD0010' as kpi,
cast(vdt_id as date) as dt_id
from `data-bi-prd-935c.bi_mart.dm_snd_voucher` 
where sd_type='SUPPLY'
and package_type='UNLOCK'
and (dt between date_trunc(vdt_id,month) and vdt_id) 
and service_type='BROADBAND'
group by brand,kpi_cd,kpi,dt_id;