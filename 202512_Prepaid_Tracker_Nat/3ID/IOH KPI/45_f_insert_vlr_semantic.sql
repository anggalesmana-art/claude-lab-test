declare vdt_id date default @vdt_id;
-- declare vdt_id date default @vdt_id;

delete From `data-bi-prd-935c.bi_mart.project_ioh_kpi_daily_tracker_national_wise`
where kpi_code in 
(
'prepaid_daily_vlr_b2b',
'prepaid_daily_vlr_b2c',
'prepaid_30d_vlr_b2b_inflow_b2c',
'prepaid_30d_vlr_b2c_base_b2c',
'prepaid_30d_vlr_b2b_inflow_b2b',
'prepaid_30d_vlr_b2c_base_b2b',
'prepaid_90d_vlr_b2b_inflow_b2c',
'prepaid_90d_vlr_b2c_base_b2c',
'prepaid_90d_vlr_b2b_inflow_b2b',
'prepaid_90d_vlr_b2c_base_b2b')
and cast(load_dt_sk_id as date)=vdt_id;      

insert into `data-bi-prd-935c.bi_mart.project_ioh_kpi_daily_tracker_national_wise`
select 
cast(load_dt as date)
,'H3I'
,case when b2b_flag=0 then 'prepaid_daily_vlr_b2c' else'prepaid_daily_vlr_b2b' end ,
'IOH'
,CAST(load_dt AS DATE) 
,sum(count) from 
`data-bi-prd-935c.bi_mart.subs_vlr_daily` a  where flag='prepaid' and cast(load_dt as date)=vdt_id group by 1,2,3,4,5;

insert into `data-bi-prd-935c.bi_mart.project_ioh_kpi_daily_tracker_national_wise`
select 
cast(load_dt as date)
,'H3I'
,case when b2b_flag='B2C' and flag='inflow' then 'prepaid_90d_vlr_b2b_inflow_b2c'
         when b2b_flag='B2C' and flag='base' then 'prepaid_90d_vlr_b2c_base_b2c'
	 when b2b_flag='B2B' and flag='inflow' then 'prepaid_90d_vlr_b2b_inflow_b2b'
	 when b2b_flag='B2B' and flag='base' then 'prepaid_90d_vlr_b2c_base_b2b'
	 end ,
'IOH'
,cast(load_dt as date)
,sum(subs) from 
 (
select --a.*,-- load_dt,flag,
load_dt
,case when b2b_flag=0 then 'B2C' else'B2B' end as b2b_flag,
case when fu_Date is null or (DATE_DIFF(CAST(load_dt AS DATE), CAST(fu_date AS DATE), DAY) <= 90) then 'inflow' else 'base' end as flag
,'vlr 90' as report
,sum(count) subs from 
`data-bi-prd-935c.bi_mart.subs_vlr_daily90` a 
where flag='prepaid' and cast(load_dt as date)=vdt_id group by 1,2,3,4
) x  
group by 1,2,3,4,5;

insert into `data-bi-prd-935c.bi_mart.project_ioh_kpi_daily_tracker_national_wise`
select 
cast(load_dt as date)
,'H3I'
,case when b2b_flag='B2C' and flag='inflow' then 'prepaid_30d_vlr_b2b_inflow_b2c'
         when b2b_flag='B2C' and flag='base' then 'prepaid_30d_vlr_b2c_base_b2c'
	 when b2b_flag='B2B' and flag='inflow' then 'prepaid_30d_vlr_b2b_inflow_b2b'
	 when b2b_flag='B2B' and flag='base' then 'prepaid_30d_vlr_b2c_base_b2b'
	 end ,
'IOH'
,CAST(load_dt AS DATE)
,sum(subs) from 
 (
select --a.*,-- load_dt,flag,
cast(load_dt as date) as load_dt
,case when b2b_flag=0 then 'B2C' else'B2B' end as b2b_flag,
case when fu_Date is null or (DATE_DIFF(CAST(load_dt AS DATE), CAST(fu_date AS DATE), DAY) <= 90) then 'inflow' else 'base' end as flag
,'vlr 30' as report
,sum(count) subs from 
`data-bi-prd-935c.bi_mart.subs_vlr_daily30` a 
where flag='prepaid' and cast(load_dt as date)=vdt_id group by 1,2,3,4
) x  
group by 1,2,3,4,5;
