DECLARE vdt_id DATE DEFAULT @vdt_id;

-- DECLARE vdt_id DATE DEFAULT @vdt_id;

truncate table `data-bi-prd-935c.bi_stg.tmp_subs_vlr_daily30_stg2`;

insert into `data-bi-prd-935c.bi_stg.tmp_subs_vlr_daily30_stg2`
select 
msisdn  
from `data-bi-prd-935c.bi_mart.fct_vlr_daily`
WHERE
CAST(load_dt AS DATE) between DATE_SUB(vdt_id, INTERVAL 89 DAY) and CAST(vdt_id AS DATE)
group by 1;

delete from `data-bi-prd-935c.bi_mart.subs_vlr_daily90`
 where CAST(load_dt AS DATE) = vdt_id;

 insert into `data-bi-prd-935c.bi_mart.subs_vlr_daily90`
 with subs as (select * from `data-dtptechm-prd-c7ca.dwh.sbscrptn_attribs`)
select cast(vdt_id as date) as load_Dt
,case when product_id <> 8 then 'postpaid' else 'prepaid' end as flag
,case when c.sbscrptn_msisdn is null then 0 else 1 end as b2b_flag
, (
    SELECT MIN(d)
    FROM UNNEST([
      cast(first_usage_dt as date),
      safe.parse_date('%Y%m%d',cast(first_billing_usage_dt_sk_id as string)),
      cast(any_event_first_usage_date as date)
    ]) AS d
    WHERE d IS NOT NULL
  ) AS fu_date
,count(distinct msisdn )  as count
from 
`data-bi-prd-935c.bi_stg.tmp_subs_vlr_daily30_stg2` a
left join subs b on a.msisdn =b.sbscrptn_msisdn and rank_ind =1 
left join (
    with subs as (select * from `data-dtptechm-prd-c7ca.dwh.sbscrptn_attribs`)
    select sbscrptn_msisdn from 
    `data-bi-prd-935c.bi_mart.dim_ioh_B2B` a 
    left join subs b
    on cast(a.sbscrptn_ek_id as string)=cast(b.sbscrptn_ek_id as string)
) c on a.msisdn =c.sbscrptn_msisdn 
where b.tool_of_trade_ind='N'
group by 1 ,2,3 ,4;