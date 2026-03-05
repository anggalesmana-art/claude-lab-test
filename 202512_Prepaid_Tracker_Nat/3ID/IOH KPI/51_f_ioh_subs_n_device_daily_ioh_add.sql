DECLARE vdt_id DATE DEFAULT @vdt_id;


delete from `data-bi-prd-935c.bi_mart.fct_ioh_addition_kpi` where dt = vdt_id and kpi_code = 'M1S';

--# Add the M1S and M2S

insert into `data-bi-prd-935c.bi_mart.fct_ioh_addition_kpi`
select cast(vdt_id as date) as dt, 'H3I' as entity, 'M1S' as kpi_code, 'IOH' as definition, cast(vdt_id as date), count(distinct a.sbscrptn_ek_id) as value
from
(
 select distinct a.sbscrptn_ek_id
 from `data-bi-prd-935c.bi_mart.fct_rgu_ioh_nik_mstr` a
 where tag = 'rgu_daily'
 and dt >= DATE_TRUNC(vdt_id, MONTH) and dt <= vdt_id

 union distinct

 select distinct a.sbscrptn_ek_id
 from `data-bi-prd-935c.bi_mart.fct_ioh_rgu_daily_nik_add` a --changes start on 23 May 2022 (add the daily RGU from this table)
 where tag = 'rgu_daily'
 and dt >= DATE_TRUNC(cast(vdt_id as date), MONTH) and dt <= vdt_id 
 
 union distinct

 select distinct a.sbscrptn_ek_id
 from `data-bi-prd-935c.bi_mart.fct_inc_voice_offnet` a --changes start on 10 Dec 2024 (add the daily RGU from this table)
 where dt >= DATE_TRUNC(cast(vdt_id as date), MONTH) and dt <= vdt_id  -- ADD By Indra Maulana Ikhsan 20241210 Request By Mas Denny

) a
join
(
 select distinct sbscrptn_ek_id
 from `data-bi-prd-935c.bi_mart.project_ioh_fu_master_v2`
 where DATE_TRUNC(ga_date,MONTH) = DATE_TRUNC(DATE_SUB(vdt_id, INTERVAL 1 MONTH), MONTH)
) b on cast(a.sbscrptn_ek_id as string) = cast(b.sbscrptn_ek_id as string)
group by 1,2,3,4,5;

delete from `data-bi-prd-935c.bi_mart.fct_ioh_addition_kpi` where dt = vdt_id and kpi_code = 'M2S';

insert into `data-bi-prd-935c.bi_mart.fct_ioh_addition_kpi`
select cast(vdt_id as date) as dt, 'H3I' as entity, 'M2S' as kpi_code, 'IOH' as definition, cast(vdt_id as date), count(distinct a.sbscrptn_ek_id) as value
from 
(
 select distinct a.sbscrptn_ek_id
 from `data-bi-prd-935c.bi_mart.fct_rgu_ioh_nik_mstr` a
 where tag = 'rgu_daily'
 and dt >= DATE_TRUNC(vdt_id, MONTH) and dt <= vdt_id

 union distinct

 select distinct a.sbscrptn_ek_id
 from `data-bi-prd-935c.bi_mart.fct_ioh_rgu_daily_nik_add` a --changes start on 23 May 2022 (add the daily RGU from this table)
 where tag = 'rgu_daily'
 and dt >= DATE_TRUNC(vdt_id, MONTH) and dt <= vdt_id

  union distinct

 select distinct a.sbscrptn_ek_id
 from `data-bi-prd-935c.bi_mart.fct_inc_voice_offnet` a --changes start on 10 Dec 2024 (add the daily RGU from this table)
 where dt >= DATE_TRUNC(cast(vdt_id as date), MONTH) and dt <= vdt_id  -- ADD By Indra Maulana Ikhsan 20241210 Request By Mas Denny

) a
join 
(
 --Change start 01 Mar 2022 onwards
 select distinct sbscrptn_ek_id
 from `data-bi-prd-935c.bi_mart.project_ioh_fu_master_v2`
 where date_trunc(ga_date,MONTH) = DATE_TRUNC(DATE_SUB(vdt_id, INTERVAL 2 MONTH), MONTH)
) b on cast(a.sbscrptn_ek_id as string) = cast(b.sbscrptn_ek_id as string)
group by 1,2,3,4,5;

--# Add the GA - VLR

-- drop table if exists `data-bi-prd-935c.bi_stg.tmp_ga_mtd`;

create or replace table `data-bi-prd-935c.bi_stg.tmp_ga_mtd`
as
select distinct sbscrptn_msisdn, sbscrptn_ek_id 
                  from `data-bi-prd-935c.bi_mart.project_ioh_fu_master_v2` 
                 where ga_date >= DATE_TRUNC(vdt_id, MONTH) 
                and ga_date <= vdt_id;

delete from `data-bi-prd-935c.bi_mart.fct_ioh_addition_kpi` where dt = vdt_id and kpi_code = 'GA - VLR';

insert into `data-bi-prd-935c.bi_mart.fct_ioh_addition_kpi`
select cast(vdt_id as date)  as dt, 'H3I' as entity, 'GA - VLR' as kpi_code, 'IOH' as definition, cast(vdt_id as date), count(distinct a.sbscrptn_ek_id) as value
from
(
 select b.sbscrptn_ek_id, count(distinct a.load_dt) as hit
 from `data-bi-prd-935c.bi_mart.fct_vlr_daily` a
 join 
 `data-bi-prd-935c.bi_stg.tmp_ga_mtd` b on cast(a.msisdn as string) = cast(b.sbscrptn_msisdn as string)
 where load_dt >= DATE_TRUNC(vdt_id, MONTH) 
 and load_dt <= vdt_id
 group by 1
) a
where a.hit >= 5
group by 1,2,3,4,5;
--# Add the GA - DATA

delete from `data-bi-prd-935c.bi_mart.fct_ioh_addition_kpi` where dt = vdt_id and kpi_code = 'GA - Data';

insert into `data-bi-prd-935c.bi_mart.fct_ioh_addition_kpi`
select cast(vdt_id as date) as dt, 'H3I' as entity, 'GA - Data' as kpi_code, 'IOH' as definition, cast(vdt_id as date), count(distinct a.sbscrptn_ek_id) as value
from `data-dtptechm-prd-c7ca.dwh.rgs_subs_detail` a
join
(
 select distinct sbscrptn_ek_id
 from `data-bi-prd-935c.bi_mart.project_ioh_fu_master_v2`
 where ga_date >= DATE_TRUNC(vdt_id, MONTH) 
 and ga_date <= vdt_id
) b on cast(a.sbscrptn_ek_id as string)= cast(b.sbscrptn_ek_id as string)
where (rgs_datapackage_ex_sp or rgs_gprs_ex_sp or rgs_blackberry_ex_sp )
and a.tool_of_trade_ind = 'N' and a.product_id = 8
and cast(a.load_dt_sk_id as date) >= DATE_TRUNC(vdt_id, MONTH)
and cast(a.load_dt_sk_id as date) <= vdt_id
group by 1,2,3,4,5;

--# Add the GC - REVENUE

delete from `data-bi-prd-935c.bi_mart.dim_rita_rev` where dt = vdt_id;

insert into `data-bi-prd-935c.bi_mart.dim_rita_rev`
select cast(trx_dt_sk_id as date) as dt, cast(a.sbscrptn_ek_id as string), sum(net_revenue/case when a.product_id = 8 then 1.1 else 1 end) revenue 
from `data-dtptechm-prd-c7ca.dwh.revenue_base` a
where (COALESCE(a.service_type, 'BROADBAND')) = ('BROADBAND') 
and process_nm in ('RITA')
and product_name in ('RITA 34GB (AON 1GB+33GB Reg)',
'R34P10 (AON 10GB+330GB Reg)',
'R34P100 (AON 100GB+3300GB Reg)',
'R34P20 (AON 20GB+660GB Reg)',
'R34P50 (AON 50GB+1650GB Reg)',
'R67P10 (AON 10GB+660GB Reg)',
'RITA 67GB (AON 1GB+66GB Reg)'
) and a.tool_of_trade_ind = 'N'
and cast(trx_dt_sk_id as date) = vdt_id
group by 1,2;

delete from `data-bi-prd-935c.bi_mart.fct_ioh_addition_kpi` where dt = vdt_id and kpi_code = 'GC - Rev';

insert into `data-bi-prd-935c.bi_mart.fct_ioh_addition_kpi`
select cast(a.dt as date), a.entity, a.kpi_code, a.definition, a.dt_b, cast(sum(a.value - coalesce(b.revenue,0))/3 as int64) as value
from
(
 select cast(vdt_id as date) as dt, 'H3I' as entity, 'GC - Rev' as kpi_code, 'IOH' as definition, cast(vdt_id as date) as dt_b, 
 a.sbscrptn_ek_id,
 sum(total_net_revenue) as value
 from `data-dtptechm-prd-c7ca.dwh.ioh_sbscriber_daily_usage_revenue_smry` a
 join 
 (
select distinct sbscrptn_ek_id
from `data-bi-prd-935c.bi_mart.fct_ioh_rgu_nik_movement`
where tag = 'rgu30_gross_churn'
and dt = vdt_id
 ) b on cast(a.sbscrptn_ek_id as string)= cast(b.sbscrptn_ek_id as string)
 where date_trunc(cast(a.load_dt_sk_id as date),MONTH) in (DATE_TRUNC(DATE_SUB(vdt_id, INTERVAL 1 MONTH), MONTH),
 DATE_TRUNC(DATE_SUB(vdt_id, INTERVAL 2 MONTH), MONTH),
 (DATE_TRUNC(DATE_SUB(vdt_id, INTERVAL 3 MONTH), MONTH)))
 group by 1,2,3,4,5,6
) a
left outer join
(
 select a.sbscrptn_ek_id, sum(revenue) as revenue 
 from `data-bi-prd-935c.bi_mart.dim_rita_rev` a
 join 
 (
select distinct sbscrptn_ek_id
from `data-bi-prd-935c.bi_mart.fct_ioh_rgu_nik_movement`
where tag = 'rgu30_gross_churn'
and dt = vdt_id
 ) b on cast(a.sbscrptn_ek_id as string) = cast(b.sbscrptn_ek_id as string)
 where date_trunc(dt,month) in (DATE_TRUNC(DATE_SUB(vdt_id, INTERVAL 1 MONTH), MONTH),
 DATE_TRUNC(DATE_SUB(vdt_id, INTERVAL 2 MONTH), MONTH),
 (DATE_TRUNC(DATE_SUB(vdt_id, INTERVAL 3 MONTH), MONTH)))
 group by 1
) b on cast(a.sbscrptn_ek_id as string) = cast(b.sbscrptn_ek_id as string)
group by 1,2,3,4,5;

--# Add the Inflaw & Base

delete from `data-bi-prd-935c.bi_mart.fct_ioh_addition_kpi` where dt = vdt_id and (kpi_code like '%inflow' or kpi_code like '%base');

--RGU30 Inflow & Base
insert into `data-bi-prd-935c.bi_mart.fct_ioh_addition_kpi`
select a.dt, 
'H3I' as entity,
kpi_code||'_'||
case when kpi_code = 'rgu30_gross_add' then 'inflow' else
 case when b.ga_dt is not null then
case when (date_diff(a.last_dt,b.ga_dt,DAY)) between 0 and 89 then 'inflow' else 'base' end 
 else
case when (date_diff(a.last_dt,c.fu_dt,DAY)) between 0 and 89 then 'inflow' else 'base' end 
 end 
end as kpi_code,
'IOH' as definition,
cast(vdt_id as date),
count(distinct a.sbscrptn_ek_id) as value
from
(
 --Opening RGU30
 select distinct cast(vdt_id as date) as dt, a.dt as last_dt, a.tag||'_opening' as kpi_code, cast(sbscrptn_ek_id as string) as sbscrptn_ek_id
 from `data-bi-prd-935c.bi_mart.fct_rgu_ioh_nik_mstr` a
 where dt = DATE_SUB(vdt_id, INTERVAL 1 DAY)
 and tag in ('rgu30')

 union all

 --Gross Add RGU30
 select distinct ga_date as dt, ga_date as last_dt, 'rgu30_gross_add' as kpi_code, cast(sbscrptn_ek_id as string) as sbscrptn_ek_id
 from `data-bi-prd-935c.bi_mart.project_ioh_fu_master_v2`
 where ga_date = vdt_id

 union all

 --Churn Back RGU30
 select distinct a.dt, a.dt as last_dt, tag as kpi_code, cast(sbscrptn_ek_id as string) as sbscrptn_ek_id
 from `data-bi-prd-935c.bi_mart.fct_ioh_rgu_nik_movement` a
 where dt = vdt_id
 and tag in ('rgu30_churn_back')

 union all

 --Gross Churn RGU30
 select distinct a.dt, (a.dt - 30) as last_dt, tag as kpi_code, cast(sbscrptn_ek_id as string) as sbscrptn_ek_id
 from `data-bi-prd-935c.bi_mart.fct_ioh_rgu_nik_movement` a
 where dt = vdt_id
 and tag in ('rgu30_gross_churn')

 union all

 --Closing RGU30
 select distinct a.dt, a.dt as last_dt, a.tag||'_closing' as kpi_code, cast(sbscrptn_ek_id as string) as sbscrptn_ek_id
 from `data-bi-prd-935c.bi_mart.fct_rgu_ioh_nik_mstr` a
 where dt = vdt_id
 and tag in ('rgu30')
) a
left outer join
(
 select distinct dt as ga_dt, cast(sbscrptn_ek_id as string) as sbscrptn_ek_id
 from `data-bi-prd-935c.bi_mart.fct_ioh_mvmnt_1_detail_dec21` --dimension
 where tag = 'rgu90_gross_add' and dt >= '2021-10-01' and dt <= '2021-12-31'
 
 union all
 
 select distinct ga_date as ga_dt, cast(sbscrptn_ek_id as string)  as sbscrptn_ek_id
 from `data-bi-prd-935c.bi_mart.project_ioh_fu_master_v2`
 where ga_date >= '2022-01-01' and ga_date <= vdt_id
) b on cast(a.sbscrptn_ek_id as string) = cast(b.sbscrptn_ek_id as string) 
left outer join
(
 select distinct cast(sbscrptn_ek_id as string)  as sbscrptn_ek_id,
 (
    SELECT MIN(d)
    FROM UNNEST([
      cast(first_usage_dt as date),
      safe.parse_date('%Y%m%d',cast(first_billing_usage_dt_sk_id as string)),
      cast(any_event_first_usage_date as date)
    ]) AS d
    WHERE d IS NOT NULL
  ) AS fu_dt
 from `data-dtptechm-prd-c7ca.dwh.sbscrptn_attribs`
) c on cast(a.sbscrptn_ek_id as string) = cast(c.sbscrptn_ek_id as string)
group by 1,2,3,4,5;

--RGU90 Inflow & Base
insert into `data-bi-prd-935c.bi_mart.fct_ioh_addition_kpi`
select a.dt, 
'H3I' as entity,
kpi_code||'_'||
case when kpi_code = 'rgu90_gross_add' then 'inflow' 
 when kpi_code = 'rgu90_churn_back' then 'base' else
 case when b.ga_dt is not null then
case when (DATE_DIFF(a.last_dt,b.ga_dt,DAY)) between 0 and 89 then 'inflow' else 'base' end 
 else
case when (DATE_DIFF(a.last_dt,c.fu_dt,DAY)) between 0 and 89 then 'inflow' else 'base' end 
 end 
end as kpi_code,
'IOH' as definition,
cast(vdt_id as date),
count(distinct a.sbscrptn_ek_id) as value
from
(
 --Opening RGU90
 select distinct cast(vdt_id as date) as dt, a.dt as last_dt, a.tag||'_opening' as kpi_code, cast(sbscrptn_ek_id as string) as sbscrptn_ek_id
 from `data-bi-prd-935c.bi_mart.fct_rgu_ioh_nik_mstr` a
 where dt = DATE_SUB(vdt_id, INTERVAL 1 DAY)
 and tag in ('rgu90')

 union all

 --Gross Add RGU90
 select distinct ga_date as dt, ga_date as last_dt, 'rgu90_gross_add' as kpi_code, cast(sbscrptn_ek_id as string) as sbscrptn_ek_id
 from `data-bi-prd-935c.bi_mart.project_ioh_fu_master_90_v2`
 where ga_date = vdt_id

 union all

 --Churn Back RGU90
 select distinct a.dt, a.dt as last_dt, tag as kpi_code, cast(sbscrptn_ek_id as string) as sbscrptn_ek_id
 from `data-bi-prd-935c.bi_mart.fct_ioh_rgu_nik_movement` a
 where dt = vdt_id
 and tag in ('rgu90_churn_back')

 union all

 --Gross Churn RGU90
 select distinct a.dt, (a.dt - 90) as last_dt, tag as kpi_code, cast(sbscrptn_ek_id as string) as sbscrptn_ek_id
 from `data-bi-prd-935c.bi_mart.fct_ioh_rgu_nik_movement` a
 where dt = vdt_id
 and tag in ('rgu90_gross_churn')

 union all

 --Closing RGU90
 select distinct a.dt, a.dt as last_dt, a.tag||'_closing' as kpi_code, cast(sbscrptn_ek_id as string) as sbscrptn_ek_id
 from `data-bi-prd-935c.bi_mart.fct_rgu_ioh_nik_mstr` a
 where dt = vdt_id
 and tag in ('rgu90')
) a
left outer join
(
 select distinct dt as ga_dt, cast(sbscrptn_ek_id as string) as sbscrptn_ek_id
 from `data-bi-prd-935c.bi_mart.fct_ioh_mvmnt_1_detail_dec21`
 where tag = 'rgu90_gross_add' and dt >= '2021-10-01' and dt <= '2021-12-31'
 
 union all
 
 select distinct ga_date as ga_dt, cast(sbscrptn_ek_id as string) as sbscrptn_ek_id
 from `data-bi-prd-935c.bi_mart.project_ioh_fu_master_v2`
 where ga_date >= '2022-01-01' and ga_date <= vdt_id
) b on cast(a.sbscrptn_ek_id as string) = cast(b.sbscrptn_ek_id as string)
left outer join
(
 select distinct sbscrptn_ek_id,
  (
    SELECT MIN(d)
    FROM UNNEST([
      cast(first_usage_dt as date),
      safe.parse_date('%Y%m%d',cast(first_billing_usage_dt_sk_id as string)),
      cast(any_event_first_usage_date as date)
    ]) AS d
    WHERE d IS NOT NULL
  ) as fu_dt
 from `data-dtptechm-prd-c7ca.dwh.sbscrptn_attribs` 
) c on cast(a.sbscrptn_ek_id as string) = cast(c.sbscrptn_ek_id as string)
group by 1,2,3,4,5;

delete from `data-bi-prd-935c.bi_mart.dim_ioh_b2b_postpaid` where date_trunc(dt,MONTH) = date_trunc(vdt_id,MONTH);

insert into `data-bi-prd-935c.bi_mart.dim_ioh_b2b_postpaid`
with subs as (select * from `data-dtptechm-prd-c7ca.dwh.sbscrptn_attribs`)
select distinct cast(vdt_id as date) as dt, cast(a.sbscrptn_ek_id as string)
from subs a
left join `data-dtptechm-prd-c7ca.dwh.channel_dim` cd on cd.channel_sk_id = a.mp3_Channel_sk_id 
join `data-dtptechm-prd-c7ca.dwh.rprt_fltr_ref_ctgry` rprt on cd.channel_id = rprt.ref_cd and rprt.ref_type_cd = 'MP3' and rprt.ctgry_ref_chld = '3 BUSINESS';

--this deletion script is for prepaid and postpaid

delete from `data-bi-prd-935c.bi_mart.fct_ioh_addition_kpi` where dt = vdt_id and (kpi_code like '%B2B' or kpi_code like '%B2C');
--this deletion script is for prepaid and postpaid

insert into `data-bi-prd-935c.bi_mart.fct_ioh_addition_kpi`
select cast(vdt_id as date) as dt,
'H3I' as entity,
case when b.sbscrptn_ek_id is not null then a.tag||'_opening_B2B' else a.tag||'_opening_B2C' end as kpi_code,
'IOH' as definition,
cast(vdt_id as date),
count(distinct a.sbscrptn_ek_id) as subs
from `data-bi-prd-935c.bi_mart.fct_rgu_ioh_nik_mstr` a
left outer join `data-bi-prd-935c.bi_mart.dim_ioh_B2B` b on cast(a.sbscrptn_ek_id as string) = cast(b.sbscrptn_ek_id as string) and 
date_trunc(a.dt,MONTH)=date_trunc(b.dt,MONTH)
where a.dt = DATE_SUB(vdt_id, INTERVAL 1 DAY) and tag in ('rgu30', 'rgu90')
group by 1,2,3,4,5

union all

select distinct a.dt, 
'H3I' as entity,
  CASE 
    WHEN b.sbscrptn_ek_id IS NOT NULL THEN CONCAT(SUBSTR(tag, 1, 5), '_', SUBSTR(tag, 7, LENGTH(tag)), '_B2B') 
    ELSE CONCAT(SUBSTR(tag, 1, 5), '_', SUBSTR(tag, 7, LENGTH(tag)), '_B2C') 
  END AS kpi_code,
'IOH' as definition,
a.dt,
count(distinct a.sbscrptn_ek_id) as subs
from `data-bi-prd-935c.bi_mart.fct_ioh_rgu_nik_movement` a
left outer join `data-bi-prd-935c.bi_mart.dim_ioh_B2B` b on cast(a.sbscrptn_ek_id as string) = cast(b.sbscrptn_ek_id as string) and date_trunc(a.dt,MONTH)=date_trunc(b.dt,MONTH)
where a.dt = vdt_id and tag like '%gross_add%'
group by 1,2,3,4,5

union all

select distinct a.dt, 
'H3I' as entity,
  CASE 
    WHEN b.sbscrptn_ek_id IS NOT NULL THEN CONCAT(SUBSTR(tag, 1, 5), '_', SUBSTR(tag, 7, LENGTH(tag)), '_B2B') 
    ELSE CONCAT(SUBSTR(tag, 1, 5), '_', SUBSTR(tag, 7, LENGTH(tag)), '_B2C') 
  END AS kpi_code, 
'IOH' as definition,
a.dt,
count(distinct a.sbscrptn_ek_id) as subs
from `data-bi-prd-935c.bi_mart.fct_ioh_rgu_nik_movement` a
left outer join `data-bi-prd-935c.bi_mart.dim_ioh_B2B` b on cast(a.sbscrptn_ek_id as string) = cast(b.sbscrptn_ek_id as string) and date_trunc(a.dt,MONTH)=date_trunc(b.dt,MONTH)
where a.dt = vdt_id and tag like '%churn_back%'
group by 1,2,3,4,5

union all

select distinct a.dt, 
'H3I' as entity,
  CASE 
    WHEN b.sbscrptn_ek_id IS NOT NULL THEN CONCAT(SUBSTR(tag, 1, 5), '_', SUBSTR(tag, 7, LENGTH(tag)), '_B2B') 
    ELSE CONCAT(SUBSTR(tag, 1, 5), '_', SUBSTR(tag, 7, LENGTH(tag)), '_B2C') 
  END AS kpi_code, 
'IOH' as definition,
a.dt,
count(distinct a.sbscrptn_ek_id) as subs
from `data-bi-prd-935c.bi_mart.fct_ioh_rgu_nik_movement` a
left outer join `data-bi-prd-935c.bi_mart.dim_ioh_B2B` b on cast(a.sbscrptn_ek_id as string) = cast(b.sbscrptn_ek_id as string) and 
DATE_TRUNC(DATE_SUB(a.dt , INTERVAL 1 DAY),MONTH) = DATE_TRUNC(b.dt, MONTH)
where a.dt = vdt_id and tag like '%gross_churn%'
group by 1,2,3,4,5

union all

select a.dt,
'H3I' as entity,
case when b.sbscrptn_ek_id is not null then CONCAT(a.tag,'_closing_B2B') else CONCAT(a.tag,'_closing_B2C') end as kpi_code,
'IOH' as definition,
a.dt,
count(distinct a.sbscrptn_ek_id) as subs
from `data-bi-prd-935c.bi_mart.fct_rgu_ioh_nik_mstr` a
left outer join `data-bi-prd-935c.bi_mart.dim_ioh_B2B` b on cast(a.sbscrptn_ek_id as string) = cast(b.sbscrptn_ek_id as string) and date_trunc(a.dt,MONTH)=date_trunc(b.dt,MONTH)
where a.dt = vdt_id and tag in ('rgu30', 'rgu90')
group by 1,2,3,4,5;


--Postpaid B2B & B2C

delete from `data-bi-prd-935c.bi_mart.fct_postpaid_b2b_b2c` where dt = vdt_id;

insert into `data-bi-prd-935c.bi_mart.fct_postpaid_b2b_b2c`
with master as
(
select distinct a.*, case when b.sbscrptn_ek_id is not null then 'B2B' else 'B2C' end as Subs_Segment,
ROW_NUMBER() OVER (PARTITION BY a.sbscrptn_ek_id order by created_dtm desc) AS row_num
from `data-bi-prd-935c.bi_mart.master_postpaid_closing_subs` a
--left outer join `data-bi-prd-935c.bi_mart.dim_ioh_B2B` b on a.sbscrptn_ek_id = b.sbscrptn_ek_id and substr(a.dt,1,6) = substr(b.dt,1,6)
left outer join `data-bi-prd-935c.bi_mart.dim_ioh_b2b_postpaid` b on cast(a.sbscrptn_ek_id as string) = cast(b.sbscrptn_ek_id as string) and date_trunc(a.dt,MONTH)=date_trunc(b.dt,MONTH) --change start on 01 Jan 2023
where a.dt = vdt_id 
)
select dt, sbscrptn_ek_id, sbscrptn_msisdn, product_id, activation_dtm, created_dtm, subs_segment from master where row_num=1;

--the deletion has been happened in the above prepaid phase

insert into `data-bi-prd-935c.bi_mart.fct_ioh_addition_kpi`
select cast(vdt_id as date) as dt,
'H3I' as entity,
case when subs_segment = 'B2C' then 'EOP_POSTPAID_B2C' else 'EOP_POSTPAID_B2B' end as kpi_code, 
'IOH' as definition, 
cast(vdt_id as date) as date, 
count(distinct a.sbscrptn_ek_id) as subs
from `data-bi-prd-935c.bi_mart.fct_postpaid_b2b_b2c` a
where dt = vdt_id
group by 1,2,3,4,5

union all

select cast(vdt_id as date)  as dt,
'H3I' as entity,
case when a.subs_segment = 'B2C' then 'GA_POSTPAID_B2C' else 'GA_POSTPAID_B2B' end as kpi_code, 
'IOH' as definition, 
cast(vdt_id as date),
count(distinct a.sbscrptn_ek_id) as value
from `data-bi-prd-935c.bi_mart.fct_postpaid_b2b_b2c` a
left outer join `data-bi-prd-935c.bi_mart.fct_postpaid_b2b_b2c` b on cast(a.sbscrptn_ek_id as string) = cast(b.sbscrptn_ek_id as string) and a.subs_segment = b.subs_segment
and b.dt = DATE_SUB(date_trunc(vdt_id, MONTH), INTERVAL 1 DAY)
where a.dt = vdt_id and b.sbscrptn_ek_id is null
group by 1,2,3,4,5;

--Insert into `data-bi-prd-935c.bi_mart`.project_ioh_kpi_daily_tracker_national_wise

delete from `data-bi-prd-935c.bi_mart.project_ioh_kpi_daily_tracker_national_wise` where load_dt_sk_id = vdt_id and kpi_code in
(
 'gross_add_-_data_user',
 'gross_add_-_vlr',
 'gross_value_churn_revenue',
 'm1s',
 'm2s',
 'rgu_30d_-_churn_back_b2b',
 'rgu_30d_-_churn_back_b2c',
 'rgu_30d_-_churn_back_base',
 'rgu_30d_-_churn_back_inflow',
 'rgu_30d_-_closing_b2b',
 'rgu_30d_-_closing_b2c',
 'rgu_30d_-_closing_base',
 'rgu_30d_-_closing_inflow',
 'rgu_30d_-_gross_add_b2b',
 'rgu_30d_-_gross_add_b2c',
 'rgu_30d_-_gross_add_inflow',
 'rgu_30d_-_gross_churn_b2b',
 'rgu_30d_-_gross_churn_b2c',
 'rgu_30d_-_gross_churn_base',
 'rgu_30d_-_gross_churn_inflow',
 'rgu_30d_-_opening_b2b',
 'rgu_30d_-_opening_b2c',
 'rgu_30d_-_opening_base',
 'rgu_30d_-_opening_inflow',
 'rgu_90d_-_churn_back_b2b',
 'rgu_90d_-_churn_back_b2c',
 'rgu_90d_-_churn_back_base',
 'rgu_90d_-_churn_back_inflow',
 'rgu_90d_-_closing_b2b',
 'rgu_90d_-_closing_b2c',
 'rgu_90d_-_closing_base',
 'rgu_90d_-_closing_inflow',
 'rgu_90d_-_gross_add_b2b',
 'rgu_90d_-_gross_add_b2c',
 'rgu_90d_-_gross_add_inflow',
 'rgu_90d_-_gross_churn_b2b',
 'rgu_90d_-_gross_churn_b2c',
 'rgu_90d_-_gross_churn_base',
 'rgu_90d_-_gross_churn_inflow',
 'rgu_90d_-_opening_b2b',
 'rgu_90d_-_opening_b2c',
 'rgu_90d_-_opening_base',
 'rgu_90d_-_opening_inflow',
 'EOP_POSTPAID_B2C',
 'EOP_POSTPAID_B2B',
 'GA_POSTPAID_B2C',
 'GA_POSTPAID_B2B' 
);

insert into `data-bi-prd-935c.bi_mart`.project_ioh_kpi_daily_tracker_national_wise
select a.dt as load_dt_sk_id, a.entity, b.new_kpi_code as kpi_code, a.definition, a.date, a.value
from `data-bi-prd-935c.bi_mart.fct_ioh_addition_kpi` a
left outer join `data-bi-prd-935c.bi_mart.dim_ioh_new_kpi_code` b on a.kpi_code = b.kpi_code
where dt = vdt_id;

insert into `data-bi-prd-935c.bi_mart`.project_ioh_kpi_daily_tracker_national_wise
select a.dt as load_dt_sk_id, a.entity, a.kpi_code, a.definition, a.date, a.value
from `data-bi-prd-935c.bi_mart.fct_ioh_addition_kpi` a
where a.kpi_code in ('EOP_POSTPAID_B2C', 'EOP_POSTPAID_B2B', 'GA_POSTPAID_B2C', 'GA_POSTPAID_B2B')
and dt = vdt_id;


--M1S
delete from `data-bi-prd-935c.bi_mart.fct_ga_m1s_m2s_detail` where tag = 'M1S' and m_date = vdt_id;

insert into `data-bi-prd-935c.bi_mart.fct_ga_m1s_m2s_detail`
select distinct 'M1S' as tag, cast(FORMAT_DATE('%Y%m%d',ga_date) as INT64), cast(a.sbscrptn_ek_id as string)  as sbscrptn_ek_id, cast(vdt_id as date) as m_date
from `data-bi-prd-935c.bi_mart.project_ioh_fu_master_v2` a
join
(
 select distinct date_trunc(dt,MONTH) as mth, cast(a.sbscrptn_ek_id as string) as sbscrptn_ek_id
 from `data-bi-prd-935c.bi_mart.fct_rgu_ioh_nik_mstr` a
 where tag = 'rgu_daily'
 and dt >= DATE_TRUNC(vdt_id, MONTH)
 and dt <= vdt_id
 
 union distinct
 
 select distinct date_trunc(dt,MONTH) as mth, cast(a.sbscrptn_ek_id as string) as sbscrptn_ek_id
 from `data-bi-prd-935c.bi_mart.fct_ioh_rgu_daily_nik_add` a
 where tag = 'rgu_daily'
 and dt >= DATE_TRUNC(vdt_id, MONTH) 
 and dt <= vdt_id

  union distinct

 select distinct date_trunc(dt,month) mth, a.sbscrptn_ek_id
 from `data-bi-prd-935c.bi_mart.fct_inc_voice_offnet` a --changes start on 10 Dec 2024 (add the daily RGU from this table)
 where dt >= DATE_TRUNC(cast(vdt_id as date), MONTH) and dt <= vdt_id  -- ADD By Indra Maulana Ikhsan 20241210 Request By Mas Denny

) c on DATE_ADD(DATE_TRUNC(ga_date, MONTH), INTERVAL 1 MONTH) = c.mth and cast(a.sbscrptn_ek_id as string) = cast(c.sbscrptn_ek_id as string)
where DATE_TRUNC(ga_date, MONTH) = DATE_SUB(DATE_TRUNC(vdt_id, MONTH), INTERVAL 1 MONTH);

--M2S
delete from `data-bi-prd-935c.bi_mart.fct_ga_m1s_m2s_detail` where tag = 'M2S' and m_date = vdt_id;

insert into `data-bi-prd-935c.bi_mart.fct_ga_m1s_m2s_detail`
select distinct 'M2S' as tag,  cast(FORMAT_DATE('%Y%m%d',ga_date) as INT64), cast(a.sbscrptn_ek_id as string), cast(vdt_id as date) as m_date
from `data-bi-prd-935c.bi_mart.project_ioh_fu_master_v2` a
join
(
 select distinct date_trunc(dt,MONTH) as mth, cast(a.sbscrptn_ek_id as string) as sbscrptn_ek_id
 from `data-bi-prd-935c.bi_mart.fct_rgu_ioh_nik_mstr` a
 where tag = 'rgu_daily'
 and dt >= DATE_TRUNC(vdt_id, MONTH) 
 and dt <= vdt_id
 
 union distinct
 
 select distinct date_trunc(dt,MONTH) as mth, cast(a.sbscrptn_ek_id as string) as sbscrptn_ek_id
 from `data-bi-prd-935c.bi_mart.fct_ioh_rgu_daily_nik_add` a
 where tag = 'rgu_daily'
 and dt >= DATE_TRUNC(vdt_id, MONTH) 
 and dt <= vdt_id

   union distinct

 select distinct date_trunc(dt,month) mth, a.sbscrptn_ek_id
 from `data-bi-prd-935c.bi_mart.fct_inc_voice_offnet` a --changes start on 10 Dec 2024 (add the daily RGU from this table)
 where dt >= DATE_TRUNC(cast(vdt_id as date), MONTH) and dt <= vdt_id  -- ADD By Indra Maulana Ikhsan 20241210 Request By Mas Denny

) c on DATE_ADD(DATE_TRUNC(ga_date, MONTH), INTERVAL 2 MONTH) = c.mth and cast(a.sbscrptn_ek_id as string) = cast(c.sbscrptn_ek_id as string)
where DATE_TRUNC(ga_date, MONTH) = DATE_SUB(DATE_TRUNC(vdt_id, MONTH), INTERVAL 2 MONTH);


--Rev Detail
delete from `data-bi-prd-935c.bi_mart.fct_cwn_rev_detail` where trx_dt_sk_id = vdt_id;

insert into `data-bi-prd-935c.bi_mart.fct_cwn_rev_detail`
select trx_dt_sk_id, 
cast(sbscrptn_ek_id as string) as sbscrptn_ek_id, PRODUCT_NAME, service_type_name, category, process_nm, source_channel,
grossrev,
netrevenue,
new_other_amortization,
hit,
product_service,
source_mapping,
source_system_nm, 
service_type_category_2
--a.*
from
(
	select a.*
	, PRODUCT_NAME||category product_service
	, case 
	when source_system_nm = 'ALJ-LOAN' and service_type_category_2 = 'Portion Main Loan' then 'PORTION_MAIN_LOAN' -- change 26 Sep 2025 - new source mapping for portion main loan
        when source_system_nm = 'ALJ-LOAN' and service_type_category_2 = 'Portion For Fee' then 'PORTION_FOR_FEE_LOAN' -- change 26 Sep 2025 - new source mapping for service fee loan
	when process_nm in ('ADDON_REDEEM','SIM_DEMAND','SIM_FORFEIT','ADDON_FORFEIT') and service_type_name = 'BROADBAND' then 'SIM_BROADBAND'
	when process_nm in ('RITA', 'RITA_P3PRICE_AMORT') and service_type_name = 'BROADBAND' then 'RITA'
	when process_nm in ('UNLOCK_P3PRICE_AMORT','VOUCHER_DEMAND') and category = 'Unlock Data' and service_type_name = 'BROADBAND' then 'SPV'
	---- ORGANIC
	when process_nm in ('CEPEK AMORTIZATION','DATA_BB_BASE','MAIN_BALANCE_OTHERS_ADJUSTMENT','RITA_TOPUP') and service_type_name = 'BROADBAND' and REGEXP_CONTAINS(UPPER(source_channel), r'ODP') then 'CUST_DIRECT_BIMA'
	when process_nm in ('CEPEK AMORTIZATION','DATA_BB_BASE','MAIN_BALANCE_OTHERS_ADJUSTMENT','RITA_TOPUP') and service_type_name = 'BROADBAND' and REGEXP_CONTAINS(UPPER(source_channel), r'USSD') then 'CUST_DIRECT_UMB_MENU'
	--when process_nm in ('CEPEK AMORTIZATION','DATA_BB_BASE','MAIN_BALANCE_OTHERS_ADJUSTMENT','RITA_TOPUP') and service_type_name = 'BROADBAND' and upper(source_channel) = 'CVM_BIMA_NONPGI' then 'CUST_DIRECT_CVM_BIMA_NON_PGI'
	--when process_nm in ('CEPEK AMORTIZATION','DATA_BB_BASE','MAIN_BALANCE_OTHERS_ADJUSTMENT','RITA_TOPUP') and service_type_name = 'BROADBAND' and upper(source_channel) = 'CVM_BIMA_PGI' then 'CUST_DIRECT_CVM_BIMA_PGI'
	when process_nm in ('CEPEK AMORTIZATION','DATA_BB_BASE','MAIN_BALANCE_OTHERS_ADJUSTMENT','RITA_TOPUP') and service_type_name = 'BROADBAND' and REGEXP_CONTAINS(UPPER(source_channel), r'CVM|CLM') then 'CUST_DIRECT_CVM'
	when process_nm in ('CEPEK AMORTIZATION','DATA_BB_BASE','MAIN_BALANCE_OTHERS_ADJUSTMENT','RITA_TOPUP') and service_type_name = 'BROADBAND' and REGEXP_CONTAINS(UPPER(source_channel), r'SMS') then 'CUST_DIRECT_SMS'
	when process_nm in ('CEPEK AMORTIZATION','DATA_BB_BASE','MAIN_BALANCE_OTHERS_ADJUSTMENT','RITA_TOPUP') and service_type_name = 'BROADBAND' and REGEXP_CONTAINS(UPPER(source_channel), r'CHATBOT') then 'CUST_DIRECT_CHATBOT'
	when process_nm in ('CEPEK AMORTIZATION','DATA_BB_BASE','MAIN_BALANCE_OTHERS_ADJUSTMENT','RITA_TOPUP') and service_type_name = 'BROADBAND' and REGEXP_CONTAINS(UPPER(source_channel), r'EXPERIAN|ALJABOR') then 'CUST_DIRECT_LOAN'
	when process_nm in ('CEPEK AMORTIZATION','DATA_BB_BASE','MAIN_BALANCE_OTHERS_ADJUSTMENT','RITA_TOPUP') and service_type_name = 'BROADBAND' and REGEXP_CONTAINS(UPPER(source_channel), r'SLMS') then 'CUST_DIRECT_BONSTRI_REDEEM'
	when process_nm in ('CEPEK AMORTIZATION','DATA_BB_BASE','MAIN_BALANCE_OTHERS_ADJUSTMENT','RITA_TOPUP') and service_type_name = 'BROADBAND' and REGEXP_CONTAINS(UPPER(source_channel), r'SV') then 'CUST_DIRECT_AUTO_RENEWAL'
	when process_nm in ('DATA_BB_BASE') and service_type_name = 'BROADBAND' then 'CUST_DIRECT'
	when process_nm in ('CEPEK AMORTIZATION','MAIN_BALANCE_OTHERS_ADJUSTMENT','RITA_TOPUP') then 'ADJ_CUST_DIRECT'
	----- PPU
	when process_nm in ('CDR','CEPEK AMORTIZATION','EVC MARKUP','MAIN_BALANCE_OTHERS_ADJUSTMENT') and service_type_name = 'GPRS' then 'PPU'
	----- EVC
	when service_type_name = 'BROADBAND' and process_nm = 'TOPUP' and source_channel = 'VOUCHER' then 'EVC_BROADBAND'
	when source_channel = 'VOUCHER' then 'EVC'
	----- BIMA & CLM
	when upper(source_channel) = 'ODP_GNV' then 'BIMA'
	when REGEXP_CONTAINS(UPPER(source_channel), r'CVM|CLM') then 'CVM'
	---- VOUCER FORFEIT
	when service_type_name = 'BROADBAND' and process_nm = 'VOUCHER_FORFEIT' then 'VOUCHER_FORFEIT'
	else 'OTHERS'
	end source_mapping
	from 
	(
		select 
		cast(trx_dt_sk_id as date) as trx_dt_sk_id,
		sbscrptn_ek_id,
		--sbscrptn_msisdn,
		PRODUCT_NAME,
		upper(service_type_name) service_type_name,
		case when upper(COALESCE(service_type,'BROADBAND')) IN ('BROADBAND') AND (process_nm IN ('SIM_DEMAND','SIM_FORFEIT','ADDON','ADDON_PULSA','ADDON_REDEEM') OR process_nm LIKE 'FRC%') THEN 'SIM Broadband' 
		when upper(COALESCE(service_type,'BROADBAND')) IN ('BROADBAND') AND process_nm IN ('VOUCHER_DEMAND','UNLOCK_P3PRICE_AMORT','UNLOCK_BALLOON_HOKI_DEMAND') THEN 'Unlock Data'
		when upper(COALESCE(service_type,'BROADBAND')) IN ('BROADBAND') AND process_nm IN ('RITA','RITA_PULSA','CLIP_COMMISSION','RITA_P3PRICE_AMORT','RITA_BALLOON_HOKI_DEMAND','STARS COMMISSION') THEN 'RITA'
		when upper(COALESCE(service_type,'BROADBAND'))IN ('BROADBAND') AND 
			(
			(process_nm IN ('EVC MARKUP','MARKUP_UNLOCK','MARKUP_RITA')) OR
			(revenue_src_ctgry = 'Ret' and process_nm in ('RITA_TOPUP','UNTAGGED_COMMISSION')) OR
			(revenue_src_ctgry = 'Subs')
			) THEN 'USSD'
		ELSE 'OTHERS' END as category,
		process_nm,
		source_channel,
		source_system_nm,
        service_type_category_2,
		sum(grossrev) grossrev,
		sum(netrevenue) as netrevenue,
		sum(new_other_amortization) new_other_amortization,
		sum(hit) hit
		from 
		(
		select 
		*,
		Coalesce(case 
				when service_type in ('GPRS','GPRS_PACKAGE') then 'GPRS'
				when service_type in ('NA','NON_VMS','OTHERS') then 'OTHERS'
				when service_type in ('SMS','SMS_PACKAGE') then 'SMS'
				when service_type in ('VOICE','VOICE_PACKAGE','VOIP') then 'VOICE'
				else service_type
		end,'OTHERS') as service_type_name,
		case 
				when revenue_src_ctgry='Subs' then 'USSD'
				when revenue_src_ctgry<>'Subs' then
						case 
								when (process_nm IN ('SIM_DEMAND','SIM_FORFEIT','ADDON','ADDON_PULSA','ADDON_REDEEM') OR process_nm LIKE 'FRC%') then 'SIM BROADBAND'
								when process_nm in ('UNLOCK','UNLOCK_PULSA') then 'Unlock Data (Inc.NG)'
														when process_nm in ('BALANCE TRANSFER','CLIP_COMMISSION','RITA','RITA_P3PRICE_AMORT','STARS COMMISSION') then 'RITA'
								when process_nm in ('RITA_TOPUP','UNTAGGED_COMMISSION','EVC MARKUP','MARKUP_RITA','MARKUP_UNLOCK') then 'USSD'
								else 'OTHERS'
						end
		end as rowname
		from 
		(
		SELECT 
				load_date as trx_dt_sk_id,
				sbscrptn_ek_id,
				--sbscrptn_msisdn,
				fct.service_type,
				Revenue_Type  as Revenue_Type,
				process_nm as process_nm,
				product_nm AS PRODUCT_NAME,
				revenue_src_ctgry,
				source_channel,
				source_system_nm,
				service_type_category_2,
				0 AS GrossRev,
				sum(coalesce(Amort,0)) new_other_amortization,
				sum(coalesce(Amort,0)) * -1 AS NetRevenue,
				0 as hit
		FROM
				(
				select 
						cast(fct.trx_dt_sk_id as date) load_date,
						sbscrptn_ek_id,
						--sbscrptn_msisdn,
						COALESCE(fct.service_type,'BROADBAND') as service_type,
						pd.product_type  as Revenue_Type,
						process_nm,
						case when coalesce(pd.product_rpt_nm,'NA') <> 'NA' then pd.product_rpt_nm
										     when coalesce(pd.product_src_nm,'NA') <> 'NA' then pd.product_src_nm
										     when coalesce(pd.product_rpt_nm_alt,'NA') <> 'NA' then pd.product_rpt_nm_alt
										     else pd.product_primary_ref
										end as product_nm,
						revenue_src_ctgry,
						source_channel,
						fct.source_system_nm,
						fct.service_type_category_2,
						sum(case when product_id = 8 THEN commission/1.11 when product_id <> 8 THEN commission end)  as Amort
				from `data-dtptechm-prd-c7ca.dwh.revenue_base` fct
						left join `data-dtptechm-prd-c7ca.dwh.product_dim` pd ON pd.product_sk_id=fct.product_sk_id
				where date(fct.trx_dt_sk_id) = vdt_id
						AND STRUCT(fct.process_nm, fct.revenue_src_ctgry) IN (SELECT AS STRUCT process_nm, revenue_src_ctgry FROM `data-dtptechm-prd-c7ca.dwh.demand_revenue_base_filter`
          WHERE net_amort_incl = 'Y'
        )
						AND revenue_book_incl_ind='INCLUDE' and tool_of_trade_ind='N'
				--and (upper(fct.product_name) not like '%SUBS%' or fct.product_name is null)
				group by 1, 2,3,4,5,6,7,8,9,10
				) FCT
		group by 1,2,3,4 ,5,6,7,8,9,10
		union distinct
		select 
				cast(fct.trx_dt_sk_id as date) load_date,
				sbscrptn_ek_id,
				--sbscrptn_msisdn,
				COALESCE(fct.service_type,'BROADBAND') as service_type,
				pd.product_type  as Revenue_Type,
				process_nm as process_nm,
				case when source_channel='TARIFF_ADJUSTED' then source_channel
				when coalesce(pd.product_rpt_nm,'NA') <> 'NA' then pd.product_rpt_nm
										    when coalesce(pd.product_src_nm,'NA') <> 'NA' then pd.product_src_nm
										     when coalesce(pd.product_rpt_nm_alt,'NA') <> 'NA' then pd.product_rpt_nm_alt
										     else pd.product_primary_ref
										end as product_nm,
				revenue_src_ctgry,
				source_channel,
				fct.source_system_nm,
				fct.service_type_category_2,
				sum(case when fct.product_id = 8 THEN gross_revenue/1.11 when fct.product_id <> 8 THEN gross_revenue end) as GrossRev,
				sum(case when fct.product_id = 8 THEN fct.commission/1.11 when fct.product_id <> 8 THEN fct.commission  ELSE 0 end) as Amort,
				sum(case when fct.product_id = 8 THEN net_revenue/1.11 when fct.product_id <> 8 THEN net_revenue end) as NetRevenue,
				count(*) as hit
		from `data-dtptechm-prd-c7ca.dwh.revenue_base` fct
				left join `data-dtptechm-prd-c7ca.dwh.product_dim` pd ON pd.product_sk_id=fct.product_sk_id
		where date(fct.trx_dt_sk_id) = vdt_id
		AND STRUCT(fct.process_nm, fct.revenue_src_ctgry) IN (SELECT AS STRUCT process_nm, revenue_src_ctgry FROM `data-dtptechm-prd-c7ca.dwh.demand_revenue_base_filter` WHERE net_revenue_incl = 'Y')
				and coalesce(fct.gl_cd,'NA') not in (select ref_cd from `data-dtptechm-prd-c7ca.dwh.rprt_fltr_ref_ctgry` where ref_type_cd = 'ACCRUAL_GL_CODE')
				and tool_of_trade_ind='N'
		--and (upper(fct.product_name) not like '%SUBS%' or fct.product_name is null)
		group by 1,2,3,4,5,6,7,8,9,10
		) tab
		)A
		--where upper(service_type_name)='BROADBAND'
		group by 1,2,3,4,5,6,7,8,9
	)a
) a;


--Rev Final
delete from `data-bi-prd-935c.bi_mart.fct_cwn_rev_detail_fnl` where trx_dt_sk_id = vdt_id;


insert into `data-bi-prd-935c.bi_mart.fct_cwn_rev_detail_fnl`
select trx_dt_sk_id,
sbscrptn_ek_id,
case when upper(process_nm) in ('EVC MARKUP', 'MARKUP_RITA', 'MARKUP_UNLOCK', 'BIMA MARKUP') then 'Others - Markup Pulsa'
     when upper(service_type_name) like 'CUST%' or upper(service_type_name) = 'GPRS' then 'ORGANIC + PGI' --change on 01 Jun 2025
     when upper(service_type_name) in ('EVC_BROADBAND','RITA','SPV','SIM_BROADBAND', 'VOUCHER_FORFEIT',
     'PORTION_MAIN_LOAN', 'PORTION_FOR_FEE_LOAN') --add on 26 Sep 2025 --> (new source mapping for portion main loan, new source mapping for service fee loan)
     or (upper(service_type_name) = 'PAYU' and process_nm = 'VOUCHER_FORFEIT') then 'MOBO' --change on 01 Jun 2025
     when upper(service_type_name) = 'VAS' then 'VAS + Loan'
     --when upper(service_type_name) = 'GPRS' then 'Others - PAYU'
     when upper(service_type_name) = 'ROAMING' then 'Others - Roaming'
     when upper(service_type_name) = 'SMS' then 'SMS + MMS'
     when upper(service_type_name) = 'MMS' then 'SMS + MMS'
     when upper(service_type_name) = 'VOICE' then 'VOICE + VIDEO'
     when upper(service_type_name) = 'VIDEO' then 'VOICE + VIDEO'
     when upper(process_nm) in ('BALANCE TRANSFER', 'EXPERIAN_PROCESSING_FEE') then 'Loan'
     when upper(process_nm) in ('ADDON_PULSA', 'CEPEK AMORTIZATION', 'MAIN_BALANCE_OTHERS_ADJUSTMENT', 'RITA_TOPUP', 'TOPUP', 'UNTAGGED_COMMISSION') then 'Others - Others'
	 when upper(process_nm) in ('ONE-OFF CDR') and service_type_name = 'OTHERS' then 'Loan'
else 'Others - '||service_type_name end as service_type_name,
process_nm,
sum(revenue) as revenue
from
(
select trx_dt_sk_id, a.sbscrptn_ek_id,
case when source_mapping in ('CUST_DIRECT','CUST_DIRECT_AUTO_RENEWAL','CUST_DIRECT_BIMA',
'CUST_DIRECT_BONSTRI_REDEEM','CUST_DIRECT_CHATBOT','CUST_DIRECT_CVM',
'CUST_DIRECT_LOAN','CUST_DIRECT_SMS','CUST_DIRECT_UMB_MENU',
'EVC_BROADBAND','RITA','SPV','SIM_BROADBAND','VOUCHER_FORFEIT',
'PORTION_MAIN_LOAN', 'PORTION_FOR_FEE_LOAN'
) then source_mapping else service_type_name end as service_type_name,  
process_nm,
sum(netrevenue) as revenue
from `data-bi-prd-935c.bi_mart.fct_cwn_rev_detail` a
where trx_dt_sk_id = vdt_id
and process_nm not in ('FRC_BALLOON_HOKI_DEMAND', 'RITA_BALLOON_HOKI_DEMAND', 'UNLOCK_BALLOON_HOKI_DEMAND', --exclude baloon hoki
'CLIP_COMMISSION', 'STARS COMMISSION')
group by 1,2,3,4
) a
group by 1,2,3,4;