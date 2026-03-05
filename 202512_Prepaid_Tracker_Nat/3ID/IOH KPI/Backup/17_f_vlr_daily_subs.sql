DECLARE vdt_id DATE DEFAULT @vdt_id;

truncate table `data-bi-prd-935c.bi_stg.stg_vlr_daily_tag`;

-- create table stg_vlr_daily_tag
-- WITH (appendonly=true, compresstype=zlib, compresslevel=3) AS
insert into `data-bi-prd-935c.bi_stg`.stg_vlr_daily_tag
select x.*, case when y.sbscrptn_msisdn is not null and z.sbscrptn_msisdn is not null then 'Both MT and MO'
                                when y.sbscrptn_msisdn is  null and z.sbscrptn_msisdn is not null then 'MT Only'
                                when y.sbscrptn_msisdn is  not null and z.sbscrptn_msisdn is null then 'MO Only'
                                when y.sbscrptn_msisdn is  null and z.sbscrptn_msisdn is null then 'Not MT and MO ' end as flag 
from
(
select cast(vdt_id as date) as load_Dt,msisdn as sbscrptn_msisdn from 
`data-dtptechm-prd-c7ca.dwh.fct_vlr_daily` 
where load_Dt = vdt_id
group by 1,2 
) x 
left join 
(
select cast(vdt_id as date) as load_Dt_sk_id,sbscrptn_msisdn From 
`data-bi-prd-935c.bi_mart`.project_rguog_subs_detail a left  join `data-dtptechm-prd-c7ca.dwh.sbscrptn_attribs`  b
on cast(a.sbscrptn_ek_id as string)=cast(b.sbscrptn_ek_id as string) 
where load_Dt_sk_id=  vdt_id 
group by 1,2 
) y
on x.load_Dt=y.load_Dt_sk_id and x.sbscrptn_msisdn=y.sbscrptn_msisdn
left join 
(
select cast(vdt_id as date) as load_Dt_sk_id,sbscrptn_msisdn From 
`data-bi-prd-935c.bi_mart`.project_rgumt_subs_detail a left join `data-dtptechm-prd-c7ca.dwh.sbscrptn_attribs`  b
on cast(a.sbscrptn_ek_id as string)=cast(b.sbscrptn_ek_id as string) 
where load_Dt_sk_id = vdt_id
group by 1,2 
) z 
on x.load_Dt=z.load_Dt_sk_id and x.sbscrptn_msisdn=z.sbscrptn_msisdn;


delete from `data-bi-prd-935c.bi_mart`.project_ioh_kpi_daily_tracker_national_wise
where kpi_code in 
(
'vlr30'
,'vlr_mo'
,'vlr_mt'
,'vlr_momt'
,'post_vlr'
,'post_vlr30'
) and load_dt_sk_id = vdt_id;

truncate table `data-bi-prd-935c.bi_stg`.stg_tmp_vlr30;

-- create table stg_tmp_vlr30
-- WITH (appendonly=true, compresstype=zlib, compresslevel=3) AS
insert into `data-bi-prd-935c.bi_stg`.stg_tmp_vlr30
select msisdn 
from `data-dtptechm-prd-c7ca.dwh.fct_vlr_daily`
where load_dt = vdt_id group by 1;
-- distributed by (msisdn)' ;


insert into `data-bi-prd-935c.bi_mart`.project_ioh_kpi_daily_tracker_national_wise
select cast(vdt_id as date)
,'H3I' as entity 
,'vlr30'
,'IOH' as definition
,cast(vdt_id as date)
,count(distinct a.msisdn) 
from `data-bi-prd-935c.bi_stg`.stg_tmp_vlr30
 a left join 
`data-dtptechm-prd-c7ca.dwh.sbscrptn_attribs` b on a.msisdn =b.sbscrptn_msisdn and b.rank_ind =1
where
b.tool_of_trade_ind ='N'
group by 1,2,3,4,5;

insert into `data-bi-prd-935c.bi_mart`.project_ioh_kpi_daily_tracker_national_wise
select 
load_dt
,'H3I' as entity 
,'vlr_mo'
,'IOH' as definition
,CAST(load_dt AS DATE)
,count(distinct a.sbscrptn_msisdn) 
 from 
`data-bi-prd-935c.bi_stg`.stg_vlr_daily_tag a
left join 
`data-dtptechm-prd-c7ca.dwh.sbscrptn_attribs` b on a.sbscrptn_msisdn =b.sbscrptn_msisdn and b.rank_ind =1
where a.load_dt = vdt_id
and a.flag='MO Only'
and b.tool_of_trade_ind ='N'
group by 1,2,3,4,5;

insert into `data-bi-prd-935c.bi_mart`.project_ioh_kpi_daily_tracker_national_wise
select 
load_dt
,'H3I' as entity 
,'vlr_mt'
,'IOH' as definition
,CAST(load_dt AS DATE)
,count(distinct a.sbscrptn_msisdn) 
 from 
`data-bi-prd-935c.bi_stg`.stg_vlr_daily_tag a
left join 
`data-dtptechm-prd-c7ca.dwh.sbscrptn_attribs` b on a.sbscrptn_msisdn =b.sbscrptn_msisdn and b.rank_ind =1
where a.load_dt =vdt_id
and a.flag='MT Only'
and b.tool_of_trade_ind ='N'
group by 1,2,3,4,5;


insert into `data-bi-prd-935c.bi_mart`.project_ioh_kpi_daily_tracker_national_wise
select 
load_dt
,'H3I' as entity 
,'vlr_momt'
,'IOH' as definition
,CAST(load_dt AS DATE)
,count(distinct a.sbscrptn_msisdn) 
 from 
`data-bi-prd-935c.bi_stg.stg_vlr_daily_tag` a
left join 
`data-dtptechm-prd-c7ca.dwh.sbscrptn_attribs` b on a.sbscrptn_msisdn =b.sbscrptn_msisdn and b.rank_ind =1
where a.load_dt = vdt_id
and a.flag='Both MT and MO'
and b.tool_of_trade_ind ='N'
group by 1,2,3,4,5;

insert into `data-bi-prd-935c.bi_mart`.project_ioh_kpi_daily_tracker_national_wise
select load_dt
,'H3I' as entity 
,'post_vlr'
,'IOH' as definition
,CAST(load_dt AS DATE) date
,count(distinct a.msisdn) 
from `data-dtptechm-prd-c7ca.dwh.fct_vlr_daily` a left join 
`data-dtptechm-prd-c7ca.dwh.sbscrptn_attribs` b on a.msisdn =b.sbscrptn_msisdn and b.rank_ind =1
where a.load_dt = vdt_id and 
b.tool_of_trade_ind ='N'
and cast(product_id as string) <> '8'
group by 1,2,3,4,5;

insert into `data-bi-prd-935c.bi_mart`.project_ioh_kpi_daily_tracker_national_wise
select cast(vdt_id as date)
,'H3I' as entity 
,'post_vlr30'
,'IOH' as definition
,cast(vdt_id as date)
,count(distinct a.msisdn) 
from `data-bi-prd-935c.bi_stg`.stg_tmp_vlr30 a left join 
`data-dtptechm-prd-c7ca.dwh.sbscrptn_attribs` b on a.msisdn =b.sbscrptn_msisdn and b.rank_ind =1
where b.tool_of_trade_ind ='N'
and cast(product_id as string) <> '8'
group by 1,2,3,4,5;
