DECLARE vdt_id DATE DEFAULT @vdt_id;



delete from `data-bi-prd-935c.bi_mart.subs_vlr_daily`
where CAST(load_dt AS DATE) =vdt_id;

insert into `data-bi-prd-935c.bi_mart.subs_vlr_daily`
with subs as (select * from `data-dtptechm-prd-c7ca.dwh.sbscrptn_attribs`)
select CAST(load_dt AS DATE) as load_dt
,case when product_id <> 8 then 'postpaid' else 'prepaid' end as flag
,case when c.sbscrptn_msisdn is null then 0 else 1 end as b2b_flag
,count(distinct msisdn )  as count
from 
`data-bi-prd-935c.bi_mart.fct_vlr_daily` a
left join subs b on a.msisdn =b.sbscrptn_msisdn and rank_ind =1  
left join (
with subs as (select * from `data-dtptechm-prd-c7ca.dwh.sbscrptn_attribs`)    
select sbscrptn_msisdn from 
`data-bi-prd-935c.bi_mart.dim_ioh_B2B` a left join subs b
on cast(a.sbscrptn_ek_id as string)=cast(b.sbscrptn_ek_id as string) 
 where  dt >= DATE_TRUNC(vdt_id,month) and dt<=vdt_id 
 group by 1 
)c on a.msisdn =c.sbscrptn_msisdn 
where b.tool_of_trade_ind='N' 
and CAST(load_dt AS DATE) =vdt_id
group by 1,2,3; 