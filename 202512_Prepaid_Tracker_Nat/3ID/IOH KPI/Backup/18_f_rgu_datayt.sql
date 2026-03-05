declare vdt_id date default @vdt_id;


delete from  `data-bi-prd-935c.bi_mart`.project_ioh_kpi_daily_tracker_national_wise
where kpi_code in ('rgu_data_fb','rgu_data_yt')
and load_dt_sk_id=vdt_id;

drop table if exists  `data-bi-prd-935c.bi_stg`.tmp_stg_yt;

create table  `data-bi-prd-935c.bi_stg`.tmp_stg_yt as  
		select sbscrptn_ek_id
		FROM  `data-dtptechm-prd-c7ca.dwh.gprs_usage_fct` a
where created_dt_sk_id = vdt_id
and gprs_rating_grp_nm in 
--FB
('3',
'31',
'54',
'76',
'81',
'82'
 ) and (uplink_vol+downlink_vol) > 0 group by 1;

insert into 
`data-bi-prd-935c.bi_mart`.project_ioh_kpi_daily_tracker_national_wise  
 select 
cast(vdt_id as timestamp)
,'H3I' as entity 
,'rgu_data_fb'
,'IOH' as definition
,cast(vdt_id as date)
,count(distinct a.sbscrptn_ek_id) 
FROM `data-bi-prd-935c.bi_stg`.tmp_stg_yt  a
 group by 1,2,3,4,5 --order by 2 desc 
;

drop table if exists `data-bi-prd-935c.bi_stg`.tmp_stg_yt;

create table `data-bi-prd-935c.bi_stg`.tmp_stg_yt as  
		select sbscrptn_ek_id
		FROM `data-dtptechm-prd-c7ca.dwh.gprs_usage_fct`  a
where created_dt_sk_id = vdt_id
and gprs_rating_grp_nm in 
--FB
(
'5',
'73',
'75',
'77',
'81',
'220',
'221'
 ) and (uplink_vol+downlink_vol) > 0 group by 1 ;

insert into 
`data-bi-prd-935c.bi_mart`.project_ioh_kpi_daily_tracker_national_wise  
 select 
cast(vdt_id as timestamp)
,'H3I' as entity 
,'rgu_data_yt'
,'IOH' as definition
,cast(vdt_id as date)
,count(distinct a.sbscrptn_ek_id) 
FROM `data-bi-prd-935c.bi_stg`.tmp_stg_yt  a
 group by 1,2,3,4,5 --order by 2 desc 
 ;