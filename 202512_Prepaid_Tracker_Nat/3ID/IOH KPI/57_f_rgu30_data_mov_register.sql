declare vdt_id date default @vdt_id;

-- declare vdt_id date default @vdt_id;

delete from `data-bi-prd-935c.bi_mart.project_ioh_kpi_daily_tracker_national_wise`
where kpi_code in (
'subs_churn_rotat',
'subs_churn_not_rgs',
'subs_churn_vlr',
'subs_new_new',
'subs_new_invalid',
'subs_new_rotat')
and load_dt_sk_id =vdt_id ;

--- Rotational Subs
insert into `data-bi-prd-935c.bi_mart.project_ioh_kpi_daily_tracker_national_wise`
select cast(dt as date)
,'H3I' as entity 
,case when flag_rotation =  'Churn Rotational Subs' then 'subs_churn_rotat'
      when flag_rotation =  'Not RGS' then 'subs_churn_not_rgs'
      when flag_rotation =  'Not RGS but VLR' then 'subs_churn_vlr'
      when flag_rotation =  'New New' then 'subs_new_new'
      when flag_rotation =  'New Invalid' then 'subs_new_invalid'
      when flag_rotation =  'New Rotational' then 'subs_new_rotat' end   
,'IOH' as definition
,cast(dt as date) date
,count(*)  
from 
(select x.* from 
(
with subs as (select * from `data-dtptechm-prd-c7ca.dwh.sbscrptn_attribs`)
select a.*,b.sbscrptn_msisdn from 
`data-bi-prd-935c.bi_mart.dm_rgs30_subs_movement_detail`  a 
left join subs b on cast(a.sbscrptn_ek_id as string) =cast(b.sbscrptn_ek_id as string) 
where dt = vdt_id 
) x left join `data-bi-prd-935c.bi_mart.project_ioh_dgpcr_flag` y 
on x.sbscrptn_msisdn = y.service_msisdn 
where y.service_msisdn is not null 
) 
 a
where  flag_rotation in 
(
'Churn Rotational Subs','Not RGS','Not RGS but VLR','New New','New Invalid','New Rotational')
group by 1,2,3,4,5;

-- drop table if exists  tmp_ales_cvmstg3;
-- create table tmp_ales_cvmstg3 as  
-- 		select sbscrptn_ek_id
-- 		from dm_rgs_ex_zr_subs_ex_cvm   
-- 		where load_dt_sk_id between to_char(vdt_id::integer::text::date-29,'yyyymmdd')::integer
-- 		and vdt_id
-- 		group by 1;
  
delete from 
`data-bi-prd-935c.bi_mart.project_ioh_kpi_daily_tracker_national_wise`
where kpi_code in (
'subs_free','subs_non_free')
and load_dt_sk_id =vdt_id ;
  

insert into `data-bi-prd-935c.bi_mart.project_ioh_kpi_daily_tracker_national_wise`
select cast(dt as date) as dt
,'H3I' as entity ,
'subs_free' AS tag
        -- CASE
        --     WHEN b.sbscrptn_ek_id IS NOT NULL THEN 'subs_non_free'
        --     ELSE 'subs_free'::text
        -- END AS tag
,'IOH' as definition
,cast(dt as date) date
,count(*) From (select x.* from 
(
with subs as (select * from `data-dtptechm-prd-c7ca.dwh.sbscrptn_attribs`)
select a.*,b.sbscrptn_msisdn from 
`data-bi-prd-935c.bi_mart.dm_rgs30_subs_movement_detail`  a 
left join subs b on cast(a.sbscrptn_ek_id as string) =cast(b.sbscrptn_ek_id as string) 
where dt = vdt_id 
) x left join `data-bi-prd-935c.bi_mart.project_ioh_dgpcr_flag` y 
on x.sbscrptn_msisdn = y.service_msisdn 
where y.service_msisdn is not null 
) 
 a 
--  left join
-- tmp_ales_cvmstg3 b 
-- on a.sbscrptn_ek_id =b.sbscrptn_ek_id 
where dt=vdt_id
and flag_rotation ='Intermitten'  group by 1,2,3,4,5;