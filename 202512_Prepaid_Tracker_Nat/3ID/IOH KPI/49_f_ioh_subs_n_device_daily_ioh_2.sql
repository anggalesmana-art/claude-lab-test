DECLARE vdt_id DATE DEFAULT @vdt_id;

/*truncate table `data-bi-prd-935c.bi_mart.project_ioh_fu_master_90_v2`;
insert into `data-bi-prd-935c.bi_mart.project_ioh_fu_master_90_v2` 
select * from `data-bi-prd-935c.bi_stg.project_ioh_fu_master_90_v2`;
*/


 delete from `data-bi-prd-935c.bi_mart.project_ioh_fu_master_90_v2` where ga_date >= cast(vdt_id as date) and Tag = 'New-RGU';

 delete from `data-bi-prd-935c.bi_mart.project_ioh_fu_master_90_v2` where first_usg_dt >= vdt_id and Tag in ('Non-RITA', 'RITA');

 --Update the GA and set null for first usage that coming from previous date or previous month --> (if rerun process is happened)

 update `data-bi-prd-935c.bi_mart.project_ioh_fu_master_90_v2` set ga_date = null where ga_date >= vdt_id;

-- -- First Usage from RGU with First Usage Date is null or First Usage Date > RGU Date

-- -- We add this logic start on 01 Mar 2022 onwards. Set the ga_date with the vdt_id
 insert into `data-bi-prd-935c.bi_mart.project_ioh_fu_master_90_v2`
 select distinct a.first_usg_dt, 
 cast(a.sbscrptn_ek_id as string), a.sbscrptn_msisdn,
 cast(vdt_id as date) as GA_Date,
 'B2C' as Subs_Segment, 
 'New-RGU' as Tag
 from
 (
  select distinct a.sbscrptn_ek_id, a.sbscrptn_msisdn, first_usage_dt as first_usg_dt
  from `data-bi-prd-935c.bi_mart.fct_rgu_ioh_nik_mstr` a
  left outer join `data-bi-prd-935c.bi_mart.project_ioh_rita_adjustment_detail` b on cast(a.sbscrptn_ek_id as string)= cast(b.sbscrptn_ek_id as string) --check into RITA
  left outer join
  (
 select distinct sbscrptn_ek_id
 from `data-bi-prd-935c.bi_mart.project_ioh_fu_master_90_v2`
 where ga_date >= '2022-01-01' and ga_date <= '2022-02-28'
  ) c on cast(a.sbscrptn_ek_id as string) = cast(c.sbscrptn_ek_id as string)
  where a.tag = 'rgu90' and dt = vdt_id
  and b.sbscrptn_ek_id is null --exclude RITA
  and 
  (
 first_usage_dt is null or 
 (first_usage_dt > vdt_id and first_usage_dt >= '2022-01-01') or
 (first_usage_dt < vdt_id and first_usage_dt >= '2022-01-01' and c.sbscrptn_ek_id is null) --take subs whoose FU but not GA in 01 Jan - 28 Feb 2022
  )
 ) a
 left outer join
 (
  select distinct sbscrptn_ek_id
  from `data-bi-prd-935c.bi_mart.fct_rgu_ioh_nik_mstr` a
  where tag = 'rgu90' and dt = DATE_SUB(vdt_id, INTERVAL 1 DAY)
 ) b on cast(a.sbscrptn_ek_id as string) = cast(b.sbscrptn_ek_id as string)
left outer join `data-bi-prd-935c.bi_mart.project_ioh_fu_master_90_v2` d on cast(a.sbscrptn_ek_id as string) = cast(d.sbscrptn_ek_id as string) --exclude from master fu tbl
 where b.sbscrptn_ek_id is null and d.sbscrptn_ek_id is null;

-- --First Usage from `data-dtptechm-prd-c7ca.dwh.sbscrptn_attribs`


 insert into `data-bi-prd-935c.bi_mart.project_ioh_fu_master_90_v2`
 select distinct
-- least(cast(first_usage_dt as date), least(parse_date('%Y%m%d',cast(first_billing_usage_dt_sk_id as string)), cast(any_event_first_usage_date as date))) as first_usg_dt,
 (
    SELECT MIN(d)
    FROM UNNEST([
      cast(first_usage_dt as date),
      safe.parse_date('%Y%m%d',cast(first_billing_usage_dt_sk_id as string)),
      cast(any_event_first_usage_date as date)
    ]) AS d
    WHERE d IS NOT NULL
  )  as first_usage_dt,
 cast(sd.sbscrptn_ek_id as string),
 sd.sbscrptn_msisdn,
 cast(null as date) as GA_Date,
 'B2C' as Subs_Segment,
 'Non-RITA' as Tag
 from `data-dtptechm-prd-c7ca.dwh.sbscrptn_attribs` sd
 left outer join --exclude from RITA
 (
  select distinct sbscrptn_ek_id
  from `data-bi-prd-935c.bi_mart.project_ioh_rita_adjustment_detail`
--  --where first_rgs_date = vdt_id
 ) b on cast(sd.sbscrptn_ek_id as string) = cast(b.sbscrptn_ek_id as string) 
 left outer join `data-bi-prd-935c.bi_mart.project_ioh_fu_master_90_v2` c on cast(sd.sbscrptn_ek_id as string) = cast(c.sbscrptn_ek_id as string)--exclude from master futbl
 where 
(
    SELECT MIN(d)
    FROM UNNEST([
      cast(first_usage_dt as date),
      safe.parse_date('%Y%m%d',cast(first_billing_usage_dt_sk_id as string)),
      cast(any_event_first_usage_date as date)
    ]) AS d
    WHERE d IS NOT NULL
  ) = vdt_id
 and coalesce(product_id,8) = 8
 and coalesce(tool_of_trade_ind, 'N') = 'N'
-- --AND --rank_ind = 1 and
-- --partition_flag <> 'A'
 and b.sbscrptn_ek_id is null
 and c.sbscrptn_ek_id is null;

-- --First Usage from RITA

 insert into `data-bi-prd-935c.bi_mart.project_ioh_fu_master_90_v2`
 select distinct first_rgs_date as fist_usg_dt, cast(a.sbscrptn_ek_id as string), b.sbscrptn_msisdn,
 cast(null as date) as GA_Date, 'B2C' as Subs_Segment, 'RITA' as Tag
 from `data-bi-prd-935c.bi_mart.project_ioh_rita_adjustment_detail` a
 left outer join `data-dtptechm-prd-c7ca.dwh.sbscrptn_attribs` b on cast(a.sbscrptn_ek_id as string) = cast(b.sbscrptn_ek_id as string)
 left outer join `data-bi-prd-935c.bi_mart.project_ioh_fu_master_90_v2` c on cast(a.sbscrptn_ek_id as string) = cast(c.sbscrptn_ek_id as string) --exclude from master fu tbl
 where first_rgs_date = vdt_id
 and c.sbscrptn_ek_id is null;

--13 - 19. RGU90 Movement

drop table if exists `data-bi-prd-935c.bi_stg.tmp_rgs90_movement_rev`;

create table `data-bi-prd-935c.bi_stg.tmp_rgs90_movement_rev` as
select cast(load_dt_sk_id as date) as load_dt_sk_id, tag, count(distinct a.sbscrptn_ek_id) as subs
from
(
 select distinct cast(vdt_id as date) as load_dt_sk_id, 'rgu90_opening' as tag, a.sbscrptn_ek_id
 from `data-bi-prd-935c.bi_mart.fct_rgu_ioh_nik_mstr` a
 where tag = 'rgu90' and dt = DATE_SUB(vdt_id, INTERVAL 1 DAY)
 
 union distinct

 select distinct cast(dt as date) as load_dt_sk_id,
 case when e.sbscrptn_ek_id is not null then 'rgu90_gross_add'
 else
 case when a.fu_dt = vdt_id then
case when f.sbscrptn_ek_id is null then 'rgu90_gross_add'
else 'rgu90_churn_back'
end
 else
case when d.sbscrptn_ek_id is not null then 'rgu90_gross_add'
else 'rgu90_churn_back' end
 end 
 end as tag,
 a.sbscrptn_ek_id
 from
 (
select distinct a.*
from
(
 select distinct a.dt, a.sbscrptn_ek_id,
 case when b.sbscrptn_ek_id is not null then b.first_rgs_date --set the first usage date for RITA
 else a.first_usage_dt end as fu_dt
 from `data-bi-prd-935c.bi_mart.fct_rgu_ioh_nik_mstr` a
 left outer join `data-bi-prd-935c.bi_mart.project_ioh_rita_adjustment_detail` b on cast(a.sbscrptn_ek_id as string) = cast(b.sbscrptn_ek_id as string) --check into RITA
 where tag = 'rgu90' and a.dt = vdt_id
) a
 ) a
 left outer join
 (
select distinct a.sbscrptn_ek_id
from `data-bi-prd-935c.bi_mart.fct_rgu_ioh_nik_mstr` a
where tag = 'rgu90' and dt = DATE_SUB(vdt_id, INTERVAL 1 DAY)
 ) b on cast(a.sbscrptn_ek_id as string) = cast(b.sbscrptn_ek_id as string)
 left outer join `data-bi-prd-935c.bi_mart.project_ioh_fu_master_90_v2` d on cast(a.sbscrptn_ek_id as string) = cast(d.sbscrptn_ek_id as string) 
 --and d.first_usg_dt >= to_char(date_trunc('month', vdt_id::text::date), 'yyyymmdd')::int
 --and d.first_usg_dt <= vdt_id
 and d.ga_date is null
 and d.tag <> 'New-RGU'
 left outer join `data-bi-prd-935c.bi_mart.project_ioh_fu_master_90_v2` e on cast(a.sbscrptn_ek_id as string) = cast(e.sbscrptn_ek_id as string) 
 and e.ga_date = vdt_id and e.tag = 'New-RGU'
 left outer join `data-bi-prd-935c.bi_mart.project_ioh_fu_master_90_v2` f on cast(a.sbscrptn_ek_id as string) = cast(f.sbscrptn_ek_id as string) and f.ga_date is not null
 where b.sbscrptn_ek_id is null

 union distinct

 select distinct cast(vdt_id as date) as load_dt_sk_id,
 'rgu90_gross_churn' as tag,
 a.sbscrptn_ek_id
 from `data-bi-prd-935c.bi_mart.fct_rgu_ioh_nik_mstr` a
 left outer join
 (
select distinct a.sbscrptn_ek_id
from `data-bi-prd-935c.bi_mart.fct_rgu_ioh_nik_mstr` a
where tag = 'rgu90' and dt = vdt_id
 ) b on a.sbscrptn_ek_id = b.sbscrptn_ek_id
 where tag = 'rgu90' and dt = DATE_SUB(vdt_id, INTERVAL 1 DAY)
 and b.sbscrptn_ek_id is null
) a
group by 1,2;


--#Insert into mis.fct_rgs90_movement_rev

delete from `data-bi-prd-935c.bi_mart.project_ioh_kpi_daily_tracker_national_wise` where load_dt_sk_id = vdt_id 
and kpi_code in ('rgu90_opening', 'rgu90_gross_add', 'rgu90_gross_churn', 'rgu90_churn_back', 'rgu90_net_churn', 'rgu90_closing_base', 'rgu90_net_add')
and definition = 'IOH';


insert into `data-bi-prd-935c.bi_mart.project_ioh_kpi_daily_tracker_national_wise`
select load_dt_sk_id, 'H3I' as entity, tag as kpi_code, 'IOH' as definition, cast(load_dt_sk_id as date) as date, subs as value
from
(
select load_dt_sk_id, tag, subs
from `data-bi-prd-935c.bi_stg.tmp_rgs90_movement_rev`

union all

select a.load_dt_sk_id, 'rgu90_net_churn' as tag, sum(subs) as subs
from
(
 select load_dt_sk_id, subs
 from `data-bi-prd-935c.bi_stg.tmp_rgs90_movement_rev` a
 where tag = 'rgu90_gross_churn'

 union all

 select load_dt_sk_id, subs * -1 as subs
 from `data-bi-prd-935c.bi_stg.tmp_rgs90_movement_rev` a
 where tag = 'rgu90_churn_back'
) a
group by 1,2

union all

select a.load_dt_sk_id, 'rgu90_closing_base' as tag, sum(subs) as subs
from
(
 select load_dt_sk_id, subs
 from `data-bi-prd-935c.bi_stg.tmp_rgs90_movement_rev` a
 where tag = 'rgu90_opening'

 union all

 select load_dt_sk_id, subs
 from `data-bi-prd-935c.bi_stg.tmp_rgs90_movement_rev` a
 where tag = 'rgu90_gross_add'

 union all
 
 select load_dt_sk_id, subs * -1
 from `data-bi-prd-935c.bi_stg.tmp_rgs90_movement_rev` a
 where tag = 'rgu90_gross_churn'

 union all

 select load_dt_sk_id, subs
 from `data-bi-prd-935c.bi_stg.tmp_rgs90_movement_rev` a
 where tag = 'rgu90_churn_back'
) a
group by 1,2

union all

select a.load_dt_sk_id, 'rgu90_net_add' as tag, sum(subs) as subs
from
(
 select load_dt_sk_id, subs
 from `data-bi-prd-935c.bi_stg.tmp_rgs90_movement_rev` a
 where tag = 'rgu90_gross_add'

 union all
 
 select load_dt_sk_id, subs * -1
 from `data-bi-prd-935c.bi_stg.tmp_rgs90_movement_rev` a
 where tag = 'rgu90_gross_churn'

 union all

 select load_dt_sk_id, subs
 from `data-bi-prd-935c.bi_stg.tmp_rgs90_movement_rev` a
 where tag = 'rgu90_churn_back'
) a
group by 1,2
) a;

--#Insert the RGU90 Movement detail to `data-bi-prd-935c.bi_mart.fct_ioh_rgu_nik_movement`

delete from `data-bi-prd-935c.bi_mart.fct_ioh_rgu_nik_movement` where dt = vdt_id and tag like 'rgu90%';

insert into `data-bi-prd-935c.bi_mart.fct_ioh_rgu_nik_movement`
select distinct dt as load_dt_sk_id,
case when e.sbscrptn_ek_id is not null then 'rgu90_gross_add'
else
case when a.fu_dt = vdt_id then
 case when f.sbscrptn_ek_id is null then 'rgu90_gross_add'
 else 'rgu90_churn_back'
 end 
else
 case when d.sbscrptn_ek_id is not null then 'rgu90_gross_add'
 else 'rgu90_churn_back' end
end 
end as tag,
a.sbscrptn_ek_id,
a.sbscrptn_msisdn,
'B2C' as Subs_Segment
from
(
 select distinct a.*
 from
 (
select distinct a.dt, a.sbscrptn_ek_id, a.sbscrptn_msisdn, 
case when b.sbscrptn_ek_id is not null then b.first_rgs_date --set the first usage date for RITA
else a.first_usage_dt end as fu_dt
from `data-bi-prd-935c.bi_mart.fct_rgu_ioh_nik_mstr` a
left outer join `data-bi-prd-935c.bi_mart.project_ioh_rita_adjustment_detail` b on cast(a.sbscrptn_ek_id as string) = cast(b.sbscrptn_ek_id as string)--check into RITA
where tag = 'rgu90' and a.dt = vdt_id
 ) a
) a
left outer join
(
 select distinct a.sbscrptn_ek_id
 from `data-bi-prd-935c.bi_mart.fct_rgu_ioh_nik_mstr` a
 where tag = 'rgu90' and dt = DATE_SUB(vdt_id, INTERVAL 1 DAY)
) b on a.sbscrptn_ek_id = b.sbscrptn_ek_id
left outer join `data-bi-prd-935c.bi_mart.project_ioh_fu_master_90_v2` d on cast(a.sbscrptn_ek_id as string) = cast(d.sbscrptn_ek_id as string) 
--and d.first_usg_dt >= to_char(date_trunc('month', vdt_id::text::date), 'yyyymmdd')::int
--and d.first_usg_dt <= vdt_id
and d.ga_date is null
and d.tag <> 'New-RGU'
left outer join `data-bi-prd-935c.bi_mart.project_ioh_fu_master_90_v2` e on cast(a.sbscrptn_ek_id as string) = cast(e.sbscrptn_ek_id as string) 
and e.ga_date = vdt_id and e.tag = 'New-RGU'
left outer join `data-bi-prd-935c.bi_mart.project_ioh_fu_master_90_v2` f on cast(a.sbscrptn_ek_id as string) = cast(f.sbscrptn_ek_id as string) and f.ga_date is not null
where b.sbscrptn_ek_id is null

union distinct

select distinct cast(vdt_id as date) as load_dt_sk_id,
'rgu90_gross_churn' as tag,
a.sbscrptn_ek_id,
a.sbscrptn_msisdn,
'B2C' as Subs_Segment
from `data-bi-prd-935c.bi_mart.fct_rgu_ioh_nik_mstr` a
left outer join
(
 select distinct a.sbscrptn_ek_id
 from `data-bi-prd-935c.bi_mart.fct_rgu_ioh_nik_mstr` a
 where tag = 'rgu90' and dt = vdt_id
) b on cast(a.sbscrptn_ek_id as string)= cast(b.sbscrptn_ek_id as string)
where tag = 'rgu90' and dt = DATE_SUB(vdt_id, INTERVAL 1 DAY)
and b.sbscrptn_ek_id is null;

--Update the first usage table master (I)

 update `data-bi-prd-935c.bi_mart.project_ioh_fu_master_90_v2` a
 set ga_date = b.dt
 from `data-bi-prd-935c.bi_mart.fct_ioh_rgu_nik_movement` b
 where cast(a.sbscrptn_ek_id as string)= cast(b.sbscrptn_ek_id as string) 
 and a.ga_date is null
-- --and a.first_usg_dt >= to_char(date_trunc('month', vdt_id::text::date), 'yyyymmdd')::int
-- --and a.first_usg_dt <= vdt_id
and b.tag = 'rgu90_gross_add'
 and b.dt = vdt_id;

--20 - 21 Inflaw & Base

delete from `data-bi-prd-935c.bi_mart.project_ioh_kpi_daily_tracker_national_wise` where load_dt_sk_id = vdt_id and kpi_code in ('rgu90_inflow', 'rgu90_base') 
and definition = 'IOH';

insert into `data-bi-prd-935c.bi_mart.project_ioh_kpi_daily_tracker_national_wise`
select load_dt_sk_id, 'H3I' as entity,
case when (first_usage_dt is not null and (date_diff(load_dt_sk_id,first_usage_dt,day)) >= 90) then 'rgu90_base'
 else 'rgu90_inflow' end as kpi_code,
'IOH' as definition, load_dt_sk_id as date, count(distinct a.sbscrptn_ek_id) as value
from
(
 select distinct a.dt as load_dt_sk_id, a.sbscrptn_ek_id, a.first_usage_dt
 from `data-bi-prd-935c.bi_mart.fct_rgu_ioh_nik_mstr` a
 where tag = 'rgu90' and dt = vdt_id
) a
group by 1,2,3,4,5;