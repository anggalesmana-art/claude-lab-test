declare vdt_id date default @vdt_id;
declare start_date date default date(vdt_id- interval 2 month);
declare end_date date default vdt_id;

for vdt in (SELECT vdt_id
FROM UNNEST(
    GENERATE_DATE_ARRAY(start_date, end_date)
) AS vdt_id_loop)
DO

create or replace table `data-bi-prd-935c.bi_stg`.lrs_ioh_2025_temp as
select 
site_id,category,area,circle,region_circle,kecamatan_nm,kabkot_nm,total_site,addressable,addressable_site_count,oa_ns,as_of_date,tenure_day,tenure_month,java_nonjava, -- profile
--ioh
site_rev_target_ioh,rev1_ioh,rev1_fc_ioh,rev2_ioh,rev3_ioh,lrs1_ioh,lrs2_ioh,lrs3_ioh,
case 
when vdt.vdt_id = '2024-12-31' and  lrs_base_track = 'LRS' then 'LRS' 
when vdt.vdt_id = '2024-12-31' and  lrs_flag_ioh = 'LRS' then 'LRS - Intermitten 2/3'
else lrs_flag_ioh end  lrs_flag_ioh,
-- im3
site_rev_target_im3,rev1_im3,rev1_fc_im3,rev2_im3,rev3_im3,lrs1_im3,lrs2_im3,lrs3_im3,lrs_flag_im3,
-- tri
site_rev_target_tri,rev1_tri,rev1_fc_tri,rev2_tri,rev3_tri,lrs1_tri,lrs2_tri,lrs3_tri,lrs_flag_tri,
lrk_site_base,
lrs_base_track,
case 
when vdt.vdt_id = '2024-12-31' then  if(lrs_base_track = 'LRS', 'LRS','NON LRS')  
else
case when lrs_base_track = 'LRS' then if(lrs_flag_ioh = 'LRS','LRS','NON LRS') end end LRS_base_status,

case when  vdt.vdt_id = '2024-12-31' then null
else
case when lrs_base_track = 'LRS' and  lrs_flag_ioh = 'LRS' then null else date_trunc(vdt.vdt_id,month)  end
end
LRS_base_graduation_month,

case 
when  vdt.vdt_id = '2024-12-31' then if( lrs_base_track = 'LRS' , (coalesce(site_rev_target_ioh,0) - coalesce(rev1_fc_ioh,0)),null)
else 
if (lrs_flag_ioh = 'LRS' , (coalesce(site_rev_target_ioh,0) - coalesce(rev1_fc_ioh,0)),null) 
end
rev_gap,

case when  vdt.vdt_id = '2024-12-31' then 
    if( lrs_base_track = 'LRS' , 
    case 
    when (site_rev_target_ioh - coalesce(rev1_fc_ioh,0)) <= 5 then 'a. <= 5 Mn'
    when (site_rev_target_ioh - coalesce(rev1_fc_ioh,0)) <= 10 then 'b. 5Mn - 10Mn'
    when (site_rev_target_ioh - coalesce(rev1_fc_ioh,0)) > 10 then 'c. > 10Mn'  end
    , null) 
else
case 
when lrs_flag_ioh = 'LRS' then 
    case 
    when (site_rev_target_ioh - coalesce(rev1_fc_ioh,0)) <= 5 then 'a. <= 5 Mn'
    when (site_rev_target_ioh - coalesce(rev1_fc_ioh,0)) <= 10 then 'b. 5Mn - 10Mn'
    when (site_rev_target_ioh - coalesce(rev1_fc_ioh,0)) > 10 then 'c. > 10Mn' end
    end
end rev_gap_slab,
'NUll' first_lrs_base_graduation,
vdt.vdt_id dt_id
from
(
select *,
case 
when (upper(trim(category)) = 'BASE SITE' or tenure_month > 8) and upper( addressable) = 'ADDRESSABLE SITE' and (lrs1_ioh + lrs2_ioh + lrs3_ioh) = 3 then 'LRS' 
when (upper(trim(category)) = 'BASE SITE' or tenure_month > 8) and upper( addressable) = 'ADDRESSABLE SITE' and (lrs1_ioh + lrs2_ioh + lrs3_ioh) = 2 then 'LRS - Intermitten 2/3'
when (upper(trim(category)) = 'BASE SITE' or tenure_month > 8) and upper( addressable) = 'ADDRESSABLE SITE' and (lrs1_ioh + lrs2_ioh + lrs3_ioh) = 1 then 'LRS - Intermitten LRS 1/3'
when (upper(trim(category)) = 'BASE SITE' or tenure_month > 8) and upper( addressable) = 'ADDRESSABLE SITE' and (lrs1_ioh + lrs2_ioh + lrs3_ioh) = 0 then 'Profit_Site'
else 'Non Eligible Revenue Target' end LRS_FLAG_ioh,
case 
when (upper(trim(category)) = 'BASE SITE' or tenure_month > 8) and upper( addressable) = 'ADDRESSABLE SITE' and (lrs1_im3 + lrs2_im3 + lrs3_im3) = 3 then 'LRS' 
when (upper(trim(category)) = 'BASE SITE' or tenure_month > 8) and upper( addressable) = 'ADDRESSABLE SITE' and (lrs1_im3 + lrs2_im3 + lrs3_im3) = 2 then 'LRS - Intermitten 2/3'
when (upper(trim(category)) = 'BASE SITE' or tenure_month > 8) and upper( addressable) = 'ADDRESSABLE SITE' and (lrs1_im3 + lrs2_im3 + lrs3_im3) = 1 then 'LRS - Intermitten LRS 1/3'
when (upper(trim(category)) = 'BASE SITE' or tenure_month > 8) and upper( addressable) = 'ADDRESSABLE SITE' and (lrs1_im3 + lrs2_im3 + lrs3_im3) = 0 then 'Profit_Site'
else 'Non Eligible Revenue Target' end LRS_FLAG_im3,
case 
when (upper(trim(category)) = 'BASE SITE' or tenure_month > 8) and upper( addressable) = 'ADDRESSABLE SITE' and (lrs1_tri + lrs2_tri + lrs3_tri) = 3 then 'LRS' 
when (upper(trim(category)) = 'BASE SITE' or tenure_month > 8) and upper( addressable) = 'ADDRESSABLE SITE' and (lrs1_tri + lrs2_tri + lrs3_tri) = 2 then 'LRS - Intermitten 2/3'
when (upper(trim(category)) = 'BASE SITE' or tenure_month > 8) and upper( addressable) = 'ADDRESSABLE SITE' and (lrs1_tri + lrs2_tri + lrs3_tri) = 1 then 'LRS - Intermitten LRS 1/3'
when (upper(trim(category)) = 'BASE SITE' or tenure_month > 8) and upper( addressable) = 'ADDRESSABLE SITE' and (lrs1_tri + lrs2_tri + lrs3_tri) = 0 then 'Profit_Site'
else 'Non Eligible Revenue Target' end LRS_FLAG_tri,
vdt.vdt_id dt_id
from 
(
with site as 
(
SELECT site_id, total_site_ioh total_site, addressable, category, parse_date('%Y%m%d',coalesce(nullif(case when replace(oa_ns,'#N/A',NULL) = '19000100' then '19000101' else replace(oa_ns,'#N/A',NULL) end, ''), '20211231')) oa_ns, 
ceil(date_diff(vdt.vdt_id,parse_date('%Y%m%d',coalesce(nullif(case when replace(oa_ns,'#N/A',NULL) = '19000100' then '19000101' else replace(oa_ns,'#N/A',NULL) end, ''), '20211231')),month)) - 1 as tenure_month,
date_diff(vdt.vdt_id, parse_date('%Y%m%d',coalesce(nullif(case when replace(oa_ns,'#N/A',NULL) = '19000100' then '19000101' else replace(oa_ns,'#N/A',NULL) end, ''), '20211231')),day) tenure_day,
month_id
from `data-bi-prd-935c.bi_mart`.total_site_ioh_mth 
WHERE month_id =  date_trunc(vdt.vdt_id,month) and total_site_ioh = 1 
),
site_profile as
(
select  *, 
case
when java_nonjava = 'JAVA' then 75000000
when java_nonjava = 'NON JAVA' then 50000000 
else 0 end site_rev_target_ioh,
case
when circle = 'JAKARTA RAYA' and  java_nonjava = 'JAVA' then 0.67 * 75000000
when circle = 'JAVA' and  java_nonjava = 'JAVA' then 0.67 * 75000000
when circle = 'JAVA' and  java_nonjava = 'NON JAVA' then 0.67 * 50000000
when circle = 'SUMATERA' and  java_nonjava = 'NON JAVA' then 0.54 * 50000000
when circle = 'KALISUMAPA' and  java_nonjava = 'NON JAVA' then 0.69 * 50000000
else 0 end site_rev_target_im3,
case
when circle = 'JAKARTA RAYA' and  java_nonjava = 'JAVA' then 0.33 * 75000000
when circle = 'JAVA' and  java_nonjava = 'JAVA' then 0.33 * 75000000
when circle = 'JAVA' and  java_nonjava = 'NON JAVA' then 0.33 * 50000000
when circle = 'SUMATERA' and  java_nonjava = 'NON JAVA' then 0.46 * 50000000
when circle = 'KALISUMAPA' and  java_nonjava = 'NON JAVA' then 0.31 * 50000000
else 0 end site_rev_target_tri
from 
(
SELECT 
brand,site_id, area,circle,region_circle,kecamatan_nm,kabkot_nm,
case
when region_circle = 'BALI NUSRA' then 'NON JAVA'
when region_circle = 'CENTRAL JAVA' then 'JAVA'
when region_circle = 'CENTRAL SUMATERA' then 'NON JAVA'
when region_circle = 'EAST JAVA' then 'JAVA'
when region_circle = 'INNER JAKARTA' then 'JAVA'
when region_circle = 'KALIMANTAN' then 'NON JAVA'
when region_circle = 'MAPA' then 'NON JAVA'
when region_circle = 'NORTH SUMATERA' then 'NON JAVA'
when region_circle = 'OUTER JAKARTA' then 'JAVA'
when region_circle = 'SOUTH SUMATERA' then 'NON JAVA'
when region_circle = 'SULAWESI' then 'NON JAVA'
when region_circle = 'WEST JAVA' then 'JAVA'
else '' end java_nonjava,
row_number() over (partition by site_id order by brand asc) rowth  from  
(
SELECT 'IM3' brand,site_id, area,circle,region_circle,kecamatan_nm,kabkot_nm from `data-bi-prd-935c.bi_mart`.ref_site
UNION all
SELECT  'TRI' brand,site_id,area,circle,region_circle,kecamatan_nm,kabkot_nm from `data-bi-prd-935c.bi_mart`.ref_site_h3i
) a
) temp where rowth = 1
),
rev1 as
(
select 
site_id, 
sum (rev1) * 1.11 rev1_ioh,
sum(rev1_fc) * 1.11 rev1_fc_ioh,
sum(rev2) * 1.11 rev2_ioh,
sum(rev3) * 1.11 rev3_ioh,

sum (if(brand = 'IM3',rev1,0)) * 1.11 rev1_im3,
sum (if(brand = 'IM3',rev1_fc,0)) * 1.11 rev1_fc_im3,
sum (if(brand = 'IM3',rev2,0)) * 1.11 rev2_im3,
sum (if(brand = 'IM3',rev3,0)) * 1.11 rev3_im3,

sum (if(brand = 'TRI',rev1,0)) * 1.11 rev1_tri,
sum (if(brand = 'TRI',rev1_fc,0)) * 1.11 rev1_fc_tri,
sum (if(brand = 'TRI',rev2,0)) * 1.11 rev2_tri,
sum (if(brand = 'TRI',rev3,0)) * 1.11 rev3_tri
from 
(
    select  'IM3' brand,site_id,
    sum(
    case when 
        kpi = 'TOT_REV' and 
        dt_id between   DATE_SUB(vdt.vdt_id,INTERVAL (EXTRACT(DAY FROM LAST_DAY(vdt.vdt_id)) - 1) DAY) and vdt.vdt_id  
        then kpi_metric / 1.11 
        else 0 end) 
        rev1_fc,
    sum(case when kpi = 'TOT_REV' and dt_id between date_trunc(vdt.vdt_id,month) and vdt.vdt_id  then kpi_metric / 1.11 else 0 end) rev1,
    sum(case when kpi = 'TOT_REV' 
    and date_trunc(vdt.vdt_id,month) = date_trunc(vdt.vdt_id - interval 1 month,month)  then kpi_metric / 1.11 else 0 end) rev2,
    sum(case when kpi = 'TOT_REV' 
    and date_trunc(vdt.vdt_id,month) =  date_trunc(vdt.vdt_id - interval 2 month,month)  then kpi_metric / 1.11 else 0 end) rev3
    from `data-bi-prd-935c.bi_mart`.seratus_kpi_v1_new
    where  kpi = 'TOT_REV' and dt_id between vdt.vdt_id - interval 100 day and vdt.vdt_id 
    group by site_id
    
    union all
    
    select  'TRI' brand,site_id,
    sum(
    case when 
        kpi_code in ('rev_mobo','rev_nondata','rev_organic') and 
        load_dt_sk_id between   DATE_SUB(vdt.vdt_id,INTERVAL (EXTRACT(DAY FROM LAST_DAY(vdt.vdt_id)) - 1) DAY) and vdt.vdt_id  
        then cast(value as numeric) 
        else 0 end) rev1_fc,
    sum(case when kpi_code in ('rev_mobo','rev_nondata','rev_organic') and load_dt_sk_id between date_trunc(vdt.vdt_id,month) and vdt.vdt_id  
    then cast(value as numeric) else 0 end) rev1,
    sum(case when kpi_code in ('rev_mobo','rev_nondata','rev_organic') 
    and date_trunc(load_dt_sk_id,month) = date_trunc(vdt.vdt_id - interval 1 month,month)
    then cast(value as numeric) else 0 end) rev2,    
    sum(case when kpi_code in ('rev_mobo','rev_nondata','rev_organic') 
    and date_trunc(load_dt_sk_id,month) = date_trunc(vdt.vdt_id - interval 2 month,month)
    then cast(value as numeric) else 0 end) rev3    
    from `data-bi-prd-935c.bi_mart`.h3i_project_ioh_kpi_daily_tracker_site
    where  kpi_code in ('rev_mobo','rev_nondata','rev_organic')  
    and load_dt_sk_id between vdt.vdt_id - interval 100 day and vdt.vdt_id 
    group by site_id
    ) x
    group by site_id
),
lrs_track as 
(
select site_id,'LRS' LRS_BASE_TRACK, site_polygon,case when site_polygon like '%Polygon%'  then 'LRK Site' end lrk_site_base from `data-bi-prd-935c.bi_mart`.lrs_base_dec2024
)
select site.site_id, site.category,
area,circle,region_circle,kecamatan_nm,kabkot_nm ,
concat(kecamatan_nm,"|",kabkot_nm ) kec_kab,
total_site, 
addressable, 
if(upper( addressable) = 'ADDRESSABLE SITE',1,0) addressable_site_count,
oa_ns,
vdt.vdt_id as_of_date,
tenure_day,
round(tenure_month,2) tenure_month,
java_nonjava,
-- IOH
round(
case 
when 
(upper(trim(category)) = 'BASE SITE' or (upper(trim(category)) = 'BASE SITE' or tenure_month > 8)) and upper(addressable) = 'ADDRESSABLE SITE'  then site_rev_target_ioh /1000000 else 0 end,
2) site_rev_target_ioh,
round(rev1_ioh/1000000,2) rev1_ioh,
round(rev1_fc_ioh /1000000,2) rev1_fc_ioh,
round(rev2_ioh /1000000,2) rev2_ioh,
round(rev3_ioh /1000000,2) rev3_ioh,
case 
when (upper(trim(category)) = 'BASE SITE' or tenure_month > 8) and upper( addressable) = 'ADDRESSABLE SITE' and java_nonjava = 'JAVA' and coalesce(rev1_fc_ioh,0) < site_rev_target_ioh then 1
when (upper(trim(category)) = 'BASE SITE' or tenure_month > 8) and upper( addressable) = 'ADDRESSABLE SITE' and java_nonjava = 'NON JAVA' and coalesce(rev1_fc_ioh,0) < site_rev_target_ioh then 1
else 0 end lrs1_ioh,
case 
when (upper(trim(category)) = 'BASE SITE' or tenure_month > 8) and upper( addressable) = 'ADDRESSABLE SITE' and java_nonjava = 'JAVA' and coalesce(rev2_ioh,0) < site_rev_target_ioh then 1
when (upper(trim(category)) = 'BASE SITE' or tenure_month > 8) and upper( addressable) = 'ADDRESSABLE SITE' and java_nonjava = 'NON JAVA' and coalesce(rev2_ioh,0) < site_rev_target_ioh then 1
else 0 end lrs2_ioh,
case 
when (upper(trim(category)) = 'BASE SITE' or tenure_month > 8) and upper( addressable) = 'ADDRESSABLE SITE' and java_nonjava = 'JAVA' and coalesce(rev3_ioh,0) < site_rev_target_ioh then 1
when (upper(trim(category)) = 'BASE SITE' or tenure_month > 8) and upper( addressable) = 'ADDRESSABLE SITE' and java_nonjava = 'NON JAVA' and coalesce(rev3_ioh,0) < site_rev_target_ioh then 1
else 0 end lrs3_ioh,
--IM3
round(
case 
when 
(upper(trim(category)) = 'BASE SITE' or tenure_month > 8) and upper(addressable) = 'ADDRESSABLE SITE'  then site_rev_target_im3 /1000000 else 0 end,
2) site_rev_target_im3,
round(rev1_im3/1000000,2) rev1_im3,
round(rev1_fc_im3 /1000000,2) rev1_fc_im3,
round(rev2_im3 /1000000,2) rev2_im3,
round(rev3_im3 /1000000,2) rev3_im3,
case 
when (upper(trim(category)) = 'BASE SITE' or tenure_month > 8) and upper( addressable) = 'ADDRESSABLE SITE' and java_nonjava = 'JAVA' and coalesce(rev1_fc_im3,0) < site_rev_target_im3 then 1
when (upper(trim(category)) = 'BASE SITE' or tenure_month > 8) and upper( addressable) = 'ADDRESSABLE SITE' and java_nonjava = 'NON JAVA' and coalesce(rev1_fc_im3,0) < site_rev_target_im3 then 1
else 0 end lrs1_im3,
case 
when (upper(trim(category)) = 'BASE SITE' or tenure_month > 8) and upper( addressable) = 'ADDRESSABLE SITE' and java_nonjava = 'JAVA' and coalesce(rev2_im3,0) < site_rev_target_im3 then 1
when (upper(trim(category)) = 'BASE SITE' or tenure_month > 8) and upper( addressable) = 'ADDRESSABLE SITE' and java_nonjava = 'NON JAVA' and coalesce(rev2_im3,0) < site_rev_target_im3 then 1
else 0 end lrs2_im3,
case 
when (upper(trim(category)) = 'BASE SITE' or tenure_month > 8) and upper( addressable) = 'ADDRESSABLE SITE' and java_nonjava = 'JAVA' and coalesce(rev3_im3,0) < site_rev_target_im3 then 1
when (upper(trim(category)) = 'BASE SITE' or tenure_month > 8) and upper( addressable) = 'ADDRESSABLE SITE' and java_nonjava = 'NON JAVA' and coalesce(rev3_im3,0) < site_rev_target_im3 then 1
else 0 end lrs3_im3,

--TRI
round(
case 
when 
(upper(trim(category)) = 'BASE SITE' or tenure_month > 8) and upper(addressable) = 'ADDRESSABLE SITE'  then site_rev_target_tri /1000000 else 0 end,
2) site_rev_target_tri,
round(rev1_tri/1000000,2) rev1_tri,
round(rev1_fc_tri /1000000,2) rev1_fc_tri,
round(rev2_tri /1000000,2) rev2_tri,
round(rev3_tri /1000000,2) rev3_tri,
case 
when (upper(trim(category)) = 'BASE SITE' or tenure_month > 8) and upper( addressable) = 'ADDRESSABLE SITE' and java_nonjava = 'JAVA' and coalesce(rev1_fc_tri,0) < site_rev_target_tri then 1
when (upper(trim(category)) = 'BASE SITE' or tenure_month > 8) and upper( addressable) = 'ADDRESSABLE SITE' and java_nonjava = 'NON JAVA' and coalesce(rev1_fc_tri,0) < site_rev_target_tri then 1
else 0 end lrs1_tri,
case 
when (upper(trim(category)) = 'BASE SITE' or tenure_month > 8) and upper( addressable) = 'ADDRESSABLE SITE' and java_nonjava = 'JAVA' and coalesce(rev2_tri,0) < site_rev_target_tri then 1
when (upper(trim(category)) = 'BASE SITE' or tenure_month > 8) and upper( addressable) = 'ADDRESSABLE SITE' and java_nonjava = 'NON JAVA' and coalesce(rev2_tri,0) < site_rev_target_tri then 1
else 0 end lrs2_tri,
case 
when (upper(trim(category)) = 'BASE SITE' or tenure_month > 8) and upper( addressable) = 'ADDRESSABLE SITE' and java_nonjava = 'JAVA' and coalesce(rev3_tri,0) < site_rev_target_tri then 1
when (upper(trim(category)) = 'BASE SITE' or tenure_month > 8) and upper( addressable) = 'ADDRESSABLE SITE' and java_nonjava = 'NON JAVA' and coalesce(rev3_tri,0) < site_rev_target_tri then 1
else 0 end lrs3_tri,
lrs_track.lrs_base_track,
lrk_site_base
from site
left join site_profile on site.site_id = site_profile.site_id
left join rev1 on site.site_id = rev1.site_id
left join lrs_track on site.site_id = lrs_track.site_id
) temp 
) layout
;
delete from `data-bi-prd-935c.bi_mart`.lrs_ioh_2025 where dt_id = vdt.vdt_id;
insert into  `data-bi-prd-935c.bi_mart`.lrs_ioh_2025
select 
a.site_id,	a.category,	a.area,	a.circle,	a.region_circle,	a.kecamatan_nm,	a.kabkot_nm,	a.total_site,	a.addressable,	a.addressable_site_count,
a.oa_ns,	a.as_of_date,	a.tenure_day,	a.tenure_month,	a.java_nonjava,	a.site_rev_target_ioh,	a.rev1_ioh,	a.rev1_fc_ioh,	a.rev2_ioh,	a.rev3_ioh,
a.lrs1_ioh,	a.lrs2_ioh,	a.lrs3_ioh,	a.lrs_flag_ioh,	a.site_rev_target_im3,	a.rev1_im3,	a.rev1_fc_im3,	a.rev2_im3,	a.rev3_im3,	a.lrs1_im3,
a.lrs2_im3,	a.lrs3_im3,	a.lrs_flag_im3,	a.site_rev_target_tri,	a.rev1_tri,	a.rev1_fc_tri,	a.rev2_tri,	a.rev3_tri,	a.lrs1_tri,	a.lrs2_tri,
a.lrs3_tri,	a.lrs_flag_tri,	a.lrk_site_base,	a.lrs_base_track,	a.lrs_base_status,	a.lrs_base_graduation_month,	a.rev_gap,	a.rev_gap_slab,	
b.first_lrs_base_graduation,
b.last_lrs_base_graduation,
a.dt_id
from `data-bi-prd-935c.bi_stg`.lrs_ioh_2025_temp a
left join
(
select site_id,
min(lrs_base_graduation_month) first_lrs_base_graduation,
max(lrs_base_graduation_month) last_lrs_base_graduation
from 
(
select site_id,lrs_base_graduation_month from `data-bi-prd-935c.bi_mart`.lrs_ioh_2025
where dt_id in 
('2025-01-31','2025-02-28','2025-03-31','2025-04-30','2025-05-31','2025-06-30',
'2025-07-31','2025-08-31','2025-09-30','2025-10-31','2025-11-30','2025-12-31')
and lrs_base_track = 'LRS'
union all
select site_id,lrs_base_graduation_month from `data-bi-prd-935c.bi_stg`.lrs_ioh_2025_temp
where lrs_base_track = 'LRS'
) x group by site_id
) b on a.site_id = b.site_id
;

drop  table if exists  `data-bi-prd-935c.bi_stg`.lrs_ioh_2025_temp;

END FOR;

