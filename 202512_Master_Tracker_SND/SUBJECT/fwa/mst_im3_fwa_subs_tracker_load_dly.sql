BEGIN
DECLARE vdt_id date default @vdt_id;
/*
ALTER TABLE biadm.ioh_fwa_kpi_detail DROP PARTITION (kpi_id='FWA_RGU90');
ALTER TABLE biadm.ioh_fwa_kpi_detail DROP PARTITION (kpi_id='FWA_RGUGA');
ALTER TABLE biadm.ioh_fwa_kpi_detail DROP PARTITION (kpi_id='RGU90_Gross_Churn');
*/

/*
change log
10 Nov 25  >> add service_class_code 8157 sesuai dengan emial dari mas Legowo. Efektif 1 Nov 2025

*/


--- 01. RGUGA
--drop table biadm.ioh_fwa_kpi_detail purge;
--create table biadm.ioh_fwa_kpi_detail partitioned by (time_flag,kpi_id,dt_id) stored as parquet as
delete from `data-bi-prd-935c.bi_mart.ioh_fwa_kpi_detail` where time_flag = 'dly' and kpi_id = 'RGUGA'  and dt_id = date(vdt_id);
insert into `data-bi-prd-935c.bi_mart.ioh_fwa_kpi_detail`
select 
'IM3' as brand,
'siteid' as level,
a.site_id as level_value,
count(distinct a.msisdn) as metric_val,
current_timestamp() as insert_date,
'dly' as time_flag,
'RGUGA' kpi_id,
dt_id
from `data-bi-prd-935c.bi_mart.rgs_ga_90d_dly_govt` a 
    left outer join `data-bi-prd-935c.bi_mart.ref_site` st ON st.site_id = a.site_id
where 
date(a.dt_id) = date(vdt_id)
AND a.actvn_dt >= '2025-03-01'
AND a.svc_class_code IN ('8153','8157')
AND (churn_back = 'NO' OR recycled = 'YES')
group by 1,2,3,8;


--- 02. RGU90
delete from `data-bi-prd-935c.bi_mart.ioh_fwa_kpi_detail` where time_flag = 'mtd' and kpi_id = 'RGU90' and dt_id = date(vdt_id);
insert into `data-bi-prd-935c.bi_mart.ioh_fwa_kpi_detail`
select 
'IM3' as brand,
'siteid_90' as level,
a.site_id as level_value,
count(distinct a.msisdn) as subs,
current_timestamp() as insert_date,
'mtd' as time_flag,
'RGU90' kpi_id,
a.dt_id
from
(
    select distinct format_date('%Y-%m',a.dt_id) as mth, a.dt_id, a.msisdn, a.site_id,
    timestamp(a.dt_id) as rgu90_dt, 
    timestamp(first_rgu) as first_dt
     ---from biadm.umr_rgu_90d_imei_nik a --> ini untuk akhir bulan
    from `data-bi-prd-935c.bi_mart.fact_rgu_90d_mtd` a
    join `data-dtp-prd-aa1a.smy.ar_cst_dly_smy` b ON date(a.dt_id) = date(b.dt_id) and a.msisdn = b.msisdn and svc_class_code='8153'
    where 
	date(a.dt_id) = date(vdt_id) and date(b.dt_id) = date(vdt_id)
    and svc_class_code IN ('8153','8157')
    and a.actvn_dt >= '2025-03-01'  --> act_dt sebelum 1 Mar 2025, adalah nomor2 testing. Informed by Legowo @ 9 May 2025
) a
left outer join `data-bi-prd-935c.bi_mart.ref_site` st ON st.site_id = a.site_id
group by 1,2,3,8;


--- 03. GROSS CHURN
delete from `data-bi-prd-935c.bi_mart.ioh_fwa_kpi_detail` where time_flag = 'dly' and kpi_id = 'GROSSCHURN90'  and dt_id = date(vdt_id);
insert into `data-bi-prd-935c.bi_mart.ioh_fwa_kpi_detail`
select 
'IM3' as brand,
'siteid_90' as level,
a.site_id as level_value,
count(distinct a.msisdn) as subs,
current_timestamp() as insert_date,
'dly' as time_flag,
'GROSSCHURN90' as kpi_id,
a.dt_id
from `data-bi-prd-935c.bi_mart.rgs_churn_90d_dly_govt` a
where 
date(dt_id) = date(vdt_id)
and svc_class_code IN ('8153','8157')
group by 1,2,3,8;


--- 04. CHURN BACK
delete from `data-bi-prd-935c.bi_mart.ioh_fwa_kpi_detail` where time_flag = 'dly' and kpi_id = 'CHURNBACK90'  and dt_id = date(vdt_id);
insert into `data-bi-prd-935c.bi_mart.ioh_fwa_kpi_detail`
select 
'IM3' as brand,
'siteid_90' as level,
a.site_id,
count(distinct a.msisdn) as subs,
current_timestamp() as insert_date,
'dly' as time_flag,
'CHURNBACK90' as kpi_id,
a.dt_id
from `data-bi-prd-935c.bi_mart.rgs_churn_back_90d_govt` a
where 
date(a.dt_id) = date(vdt_id)
and a.actvn_dt >= '2025-03-01'  --> act_dt sebelum 1 Mar 2025, adalah nomor2 testing. Informed by Legowo @ 9 May 2025
and svc_class_code IN ('8153','8157')
group by 1,2,3,8;


/*
---- MTD level (RGUGA, CHURNBACK, GROSSCHURN)
--- 01. RGUGA
insert overwrite table biadm.ioh_fwa_kpi_detail partition (time_flag,kpi_id,dt_id)
select 
'IM3' as brand,
'siteid' as level,
a.level_value as site_id,
sum(a.metric_val) as metric_val,
current_timestamp() as insert_date,
'mtd' as time_flag,
'FWA_RGUGA' kpi_id,
cast(date_add(trunc(date_add(cast(a.dt_id as date format'YYYYMMDD'), interval 1 month),'Month'), interval -1 days) as string) as dt_id
from biadm.ioh_fwa_kpi_detail a 
where 
a.dt_id between '20250301' and '20250707'
and kpi_id = 'FWA_RGUGA'
and time_flag = 'dly'
and level = 'siteid'
group by 1,2,3,8;


--- 02. GROSS CHURN
insert overwrite table biadm.ioh_fwa_kpi_detail partition (time_flag,kpi_id,dt_id)
select 
'IM3' as brand,
'siteid_90' as level,
a.level_value as site_id,
sum(a.metric_val) as subs,
current_timestamp() as insert_date,
'mtd' as time_flag,
'RGU90_Gross_Churn' as kpi_id,
cast(date_add(trunc(date_add(cast(a.dt_id as date format'YYYYMMDD'), interval 1 month),'Month'), interval -1 days) as string) as dt_id
from biadm.ioh_fwa_kpi_detail a 
where a.dt_id between '20250301' and '20250707'
and kpi_id = 'RGU90_Gross_Churn'
and time_flag = 'dly'
and level = 'siteid_90'
group by 1,2,3,8;

--- 03. CHURN BACK
insert overwrite table biadm.ioh_fwa_kpi_detail partition (time_flag,kpi_id,dt_id)
select 
'IM3' as brand,
'siteid_90' as level,
a.level_value as site_id,
sum(a.metric_val) as subs,
current_timestamp() as insert_date,
'mtd' as time_flag,
'RGU90_Churn_Back' as tag,
cast(date_add(trunc(date_add(cast(a.dt_id as date format'YYYYMMDD'), interval 1 month),'Month'), interval -1 days) as string) as dt_id
from biadm.ioh_fwa_kpi_detail a 
where a.dt_id between '20250301' and '20250707'
and kpi_id = 'RGU90_Churn_Back'
and time_flag = 'dly'
and level = 'siteid_90'
group by 1,2,3,8;

*/
END