DECLARE vdt_id DATE DEFAULT @vdt_id;

delete from `data-bi-prd-935c.bi_mart.kpi_national_tracker_dly` where brand = 'TRI' and dt_id = '2024-10-15' and kpi_id in ('DAT0001','DAT0002','DAT0003','DAT0004','DAT0005','DAT0006','DAT0007','DAT0008','DAT0010','DAT0011','DAT0012','DAT0013','DAT0014','DAT0015','DAT0016','DAT0017','DAT0018','DAT0019','DAT0020','DAT0021','DAT0022','DAT0023','DAT0024','DAT0025','DAT0026','DAT0027','DAT0028','DAT0029','DAT0030','DAT0031');

INSERT INTO `data-bi-prd-935c.bi_mart.kpi_national_tracker_dly`
select 
'TRI' as brand,
case 
	when kpi_code = 'usg_data_blb' then 'Data Traffic Billable'
	when kpi_code = 'usg_data_blb_pro' then 'Data Traffic Billable Promo'
	when kpi_code = 'usg_data_unblb' then 'Data Traffic Unbillable'
	when kpi_code = 'usg_data_4g' then '4G'
	when kpi_code = 'usg_data_3g' then '3G'
	when kpi_code = 'usg_data_2g' then '2G'
	when kpi_code in ('prepaid_daily_data_user_4g_b2c','prepaid_daily_data_user_4g_b2b') then 'Data User - Daily Unique 4G'
	when kpi_code in ('prepaid_daily_data_user_3g_b2c','prepaid_daily_data_user_3g_b2b') then 'Data User - Daily Unique 3G'
	when kpi_code in ('prepaid_daily_data_user_2g_b2c','prepaid_daily_data_user_2g_b2b') then 'Data User - Daily Unique 2G'
	when kpi_code in ('prepaid_30d_data_user_4g_b2c','prepaid_30d_data_user_4g_b2b') then 'Data User - 30D Rolling 4G'
	when kpi_code in ('prepaid_30d_data_user_3g_b2c','prepaid_30d_data_user_3g_b2b') then 'Data User - 30D Rolling 3G'
	when kpi_code in ('prepaid_30d_data_user_2g_b2c','prepaid_30d_data_user_2g_b2b') then 'Data User - 30D Rolling 2G'
end as kpi_nm,
case 
	when kpi_code = 'usg_data_blb' then 'DLY'
	when kpi_code = 'usg_data_blb_pro' then 'DLY'
	when kpi_code = 'usg_data_unblb' then 'DLY'
	when kpi_code = 'usg_data_4g' then 'DLY'
	when kpi_code = 'usg_data_3g' then 'DLY'
	when kpi_code = 'usg_data_2g' then 'DLY'
	when kpi_code in ('prepaid_daily_data_user_4g_b2c','prepaid_daily_data_user_4g_b2b') then 'AVG'
	when kpi_code in ('prepaid_daily_data_user_3g_b2c','prepaid_daily_data_user_3g_b2b') then 'AVG'
	when kpi_code in ('prepaid_daily_data_user_2g_b2c','prepaid_daily_data_user_2g_b2b') then 'AVG'
	when kpi_code in ('prepaid_30d_data_user_4g_b2c','prepaid_30d_data_user_4g_b2b') then 'MTD'
	when kpi_code in ('prepaid_30d_data_user_3g_b2c','prepaid_30d_data_user_3g_b2b') then 'MTD'
	when kpi_code in ('prepaid_30d_data_user_2g_b2c','prepaid_30d_data_user_2g_b2b') then 'MTD'
end as flag,
sum(coalesce(value,0)) as metric,
current_timestamp() as process_dt,
case 
	when kpi_code = 'usg_data_blb' then 'DAT0002'
	when kpi_code = 'usg_data_blb_pro' then 'DAT0003'
	when kpi_code = 'usg_data_unblb' then 'DAT0004'
	when kpi_code = 'usg_data_4g' then 'DAT0006'
	when kpi_code = 'usg_data_3g' then 'DAT0007'
	when kpi_code = 'usg_data_2g' then 'DAT0008'
	when kpi_code in ('prepaid_daily_data_user_4g_b2c','prepaid_daily_data_user_4g_b2b') then 'DAT0015'
	when kpi_code in ('prepaid_daily_data_user_3g_b2c','prepaid_daily_data_user_3g_b2b') then 'DAT0016'
	when kpi_code in ('prepaid_daily_data_user_2g_b2c','prepaid_daily_data_user_2g_b2b') then 'DAT0017'
	when kpi_code in ('prepaid_30d_data_user_4g_b2c','prepaid_30d_data_user_4g_b2b') then 'DAT0020'
	when kpi_code in ('prepaid_30d_data_user_3g_b2c','prepaid_30d_data_user_3g_b2b') then 'DAT0021'
	when kpi_code in ('prepaid_30d_data_user_2g_b2c','prepaid_30d_data_user_2g_b2b') then 'DAT0022'
end as kpi,
load_dt_sk_id as dt_id
from `data-dtptechm-prd-c7ca.dwh.ioh_kpi_daily_tracker_national_wise`
where load_dt_sk_id = '2024-10-15' and entity = 'H3I' and definition = 'IOH' and kpi_code in ( 
'usg_data_blb','usg_data_blb_pro','usg_data_unblb',
'usg_data_4g','usg_data_3g','usg_data_2g')
GROUP BY brand,kpi_nm,flag,kpi,dt_id;

INSERT INTO `data-bi-prd-935c.bi_mart.kpi_national_tracker_dly`
select 
'TRI' as brand,
case 
	when kpi_code = 'usg_data_blb' then 'Data Traffic Billable'
	when kpi_code = 'usg_data_blb_pro' then 'Data Traffic Billable Promo'
	when kpi_code = 'usg_data_unblb' then 'Data Traffic Unbillable'
	when kpi_code = 'usg_data_4g' then '4G'
	when kpi_code = 'usg_data_3g' then '3G'
	when kpi_code = 'usg_data_2g' then '2G'
	when kpi_code in ('prepaid_daily_data_user_4g_b2c','prepaid_daily_data_user_4g_b2b') then 'Data User - Daily Unique 4G'
	when kpi_code in ('prepaid_daily_data_user_3g_b2c','prepaid_daily_data_user_3g_b2b') then 'Data User - Daily Unique 3G'
	when kpi_code in ('prepaid_daily_data_user_2g_b2c','prepaid_daily_data_user_2g_b2b') then 'Data User - Daily Unique 2G'
	when kpi_code in ('prepaid_30d_data_user_4g_b2c','prepaid_30d_data_user_4g_b2b') then 'Data User - 30D Rolling 4G'
	when kpi_code in ('prepaid_30d_data_user_3g_b2c','prepaid_30d_data_user_3g_b2b') then 'Data User - 30D Rolling 3G'
	when kpi_code in ('prepaid_30d_data_user_2g_b2c','prepaid_30d_data_user_2g_b2b') then 'Data User - 30D Rolling 2G'
end as kpi_nm,
case 
	when kpi_code = 'usg_data_blb' then 'DLY'
	when kpi_code = 'usg_data_blb_pro' then 'DLY'
	when kpi_code = 'usg_data_unblb' then 'DLY'
	when kpi_code = 'usg_data_4g' then 'DLY'
	when kpi_code = 'usg_data_3g' then 'DLY'
	when kpi_code = 'usg_data_2g' then 'DLY'
	when kpi_code in ('prepaid_daily_data_user_4g_b2c','prepaid_daily_data_user_4g_b2b') then 'AVG'
	when kpi_code in ('prepaid_daily_data_user_3g_b2c','prepaid_daily_data_user_3g_b2b') then 'AVG'
	when kpi_code in ('prepaid_daily_data_user_2g_b2c','prepaid_daily_data_user_2g_b2b') then 'AVG'
	when kpi_code in ('prepaid_30d_data_user_4g_b2c','prepaid_30d_data_user_4g_b2b') then 'MTD'
	when kpi_code in ('prepaid_30d_data_user_3g_b2c','prepaid_30d_data_user_3g_b2b') then 'MTD'
	when kpi_code in ('prepaid_30d_data_user_2g_b2c','prepaid_30d_data_user_2g_b2b') then 'MTD'
end as flag,
sum(coalesce(value,0)) as metric,
current_timestamp() as process_dt,
case 
	when kpi_code = 'usg_data_blb' then 'DAT0002'
	when kpi_code = 'usg_data_blb_pro' then 'DAT0003'
	when kpi_code = 'usg_data_unblb' then 'DAT0004'
	when kpi_code = 'usg_data_4g' then 'DAT0006'
	when kpi_code = 'usg_data_3g' then 'DAT0007'
	when kpi_code = 'usg_data_2g' then 'DAT0008'
	when kpi_code in ('prepaid_daily_data_user_4g_b2c','prepaid_daily_data_user_4g_b2b') then 'DAT0015'
	when kpi_code in ('prepaid_daily_data_user_3g_b2c','prepaid_daily_data_user_3g_b2b') then 'DAT0016'
	when kpi_code in ('prepaid_daily_data_user_2g_b2c','prepaid_daily_data_user_2g_b2b') then 'DAT0017'
	when kpi_code in ('prepaid_30d_data_user_4g_b2c','prepaid_30d_data_user_4g_b2b') then 'DAT0020'
	when kpi_code in ('prepaid_30d_data_user_3g_b2c','prepaid_30d_data_user_3g_b2b') then 'DAT0021'
	when kpi_code in ('prepaid_30d_data_user_2g_b2c','prepaid_30d_data_user_2g_b2b') then 'DAT0022'
end as kpi,
load_dt_sk_id as dt_id
from `data-bi-prd-935c.bi_mart.project_ioh_kpi_daily_tracker_national_wise`
where load_dt_sk_id = '2024-10-15' and entity = 'H3I' and definition = 'IOH' and kpi_code in ( 
'prepaid_daily_data_user_4g_b2c','prepaid_daily_data_user_4g_b2b',
'prepaid_daily_data_user_3g_b2c','prepaid_daily_data_user_3g_b2b',
'prepaid_daily_data_user_2g_b2c','prepaid_daily_data_user_2g_b2b',
'prepaid_30d_data_user_4g_b2c','prepaid_30d_data_user_4g_b2b',
'prepaid_30d_data_user_3g_b2c','prepaid_30d_data_user_3g_b2b',
'prepaid_30d_data_user_2g_b2c','prepaid_30d_data_user_2g_b2b')
GROUP BY brand,kpi_nm,flag,kpi,dt_id;

INSERT INTO `data-bi-prd-935c.bi_mart.kpi_national_tracker_dly`
select 
brand,
case 
when kpi_id in ('DAT0002','DAT0003','DAT0004') then 'Data Traffic - TOTAL'
when kpi_id in ('DAT0014','DAT0015','DAT0016','DAT0017') then 'Data User - Daily Unique'
when kpi_id in ('DAT0019','DAT0020','DAT0021','DAT0022') then 'Data User - 30D Rolling'
end as kpi_nm,
flag,
sum(metric) as metric,
current_timestamp() process_dt,
case 
when kpi_id in ('DAT0002','DAT0003','DAT0004') then 'DAT0001'
when kpi_id in ('DAT0014','DAT0015','DAT0016','DAT0017') then 'DAT0013'
when kpi_id in ('DAT0019','DAT0020','DAT0021','DAT0022') then 'DAT0018'
end as kpi,
dt_id
from `data-bi-prd-935c.bi_mart.kpi_national_tracker_dly` 
where 
dt_id = '2024-10-15' and
kpi_id in ('DAT0002','DAT0003','DAT0004',
		'DAT0014','DAT0015','DAT0016','DAT0017',
		'DAT0019','DAT0020','DAT0021','DAT0022') 
GROUP BY brand,kpi_nm,flag,kpi,dt_id;