DECLARE vdt_id DATE DEFAULT @vdt_id;

delete from `data-bi-prd-935c.bi_mart`.project_ioh_kpi_daily_tracker_national_wise where kpi_code ='subs_activate' and load_dt_sk_id = vdt_id ;

insert into `data-bi-prd-935c.bi_mart`.project_ioh_kpi_daily_tracker_national_wise
select CAST(activation_dtm AS DATE)
,'H3I' as entity 
,'subs_activate'
,'IOH' as definition
,CAST(activation_dtm AS DATE) date
,count(distinct a.sbscrptn_ek_id) 
from `data-dtptechm-prd-c7ca.dwh.sbscrptn_attribs` a 
where cast(activation_dtm AS DATE) = vdt_id
and a.tool_of_trade_ind ='N'
group by 1,2,3,4,5;

delete from 
`data-bi-prd-935c.bi_mart`.project_ioh_kpi_daily_tracker_national_wise where kpi_code ='subs_churn' 
and load_dt_sk_id = vdt_id;

insert into `data-bi-prd-935c.bi_mart`.project_ioh_kpi_daily_tracker_national_wise
select CAST(termination_dtm AS DATE)
,'H3I' as entity 
,'subs_churn'
,'IOH' as definition
,CAST(termination_dtm AS DATE) date
,count(distinct a.sbscrptn_ek_id) 
from `data-dtptechm-prd-c7ca.dwh.sbscrptn_attribs` a 
where CAST(termination_dtm AS DATE) = vdt_id 
and a.tool_of_trade_ind ='N'
group by 1,2,3,4,5 ;