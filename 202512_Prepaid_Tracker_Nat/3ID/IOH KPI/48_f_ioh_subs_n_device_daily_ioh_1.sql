DECLARE vdt_id DATE DEFAULT @vdt_id;


/*truncate table `data-bi-prd-935c.bi_mart.project_ioh_fu_master_v2`;
insert into `data-bi-prd-935c.bi_mart.project_ioh_fu_master_v2` 
select * from `data-bi-prd-935c.bi_stg.project_ioh_fu_master_v2`;
*/

DELETE FROM `data-bi-prd-935c.bi_mart.fct_ioh_dgpcr_consentdt_new`
WHERE dt = vdt_id;

insert into `data-bi-prd-935c.bi_mart.fct_ioh_dgpcr_consentdt_new` 
select *
from
(
 select so.service_msisdn,
 so.tax_iden_num as nik,
 so.x_dgpcr_flag,
 cast(so.x_dgpcr_reg_date as date) x_dgpcr_reg_date,
 CAST(so.x_consent_dt AS DATE) as x_consent_dt,
 row_number() over (partition by service_msisdn order by coalesce(CAST(x_consent_dt AS DATE), CAST('1900-01-01' AS DATE)) desc) as Rank_ind,
 cast(vdt_id as date) as dt
 from `data-dtptechm-prd-c7ca.stg.stg_s_org_ext`  so
) a
where a.rank_ind = 1;

delete from `data-bi-prd-935c.bi_mart.fct_inc_voice_offnet` where dt =  vdt_id;


insert into `data-bi-prd-935c.bi_mart.fct_inc_voice_offnet`
with subs as (select * from `data-dtptechm-prd-c7ca.dwh.sbscrptn_attribs`)
select a.dt_id as dt, cast(b.sbscrptn_ek_id as string), a.sbscrptn_msisdn,
 (
    SELECT MIN(d)
    FROM UNNEST([
      cast(first_usage_dt as date),
      safe.parse_date('%Y%m%d',cast(first_billing_usage_dt_sk_id as string)),
      cast(any_event_first_usage_date as date)
    ]) AS d
    WHERE d IS NOT NULL
  )  as first_usage_dt,
cast(sum(cast(usage as numeric)) as INT64) as usage
from `data-bi-prd-935c.bi_mart.msc_detail_3id` a
left outer join subs b on a.sbscrptn_msisdn = b.sbscrptn_msisdn and b.rank_ind = 1 
join
(
 select distinct service_msisdn
 from `data-bi-prd-935c.bi_mart.project_ioh_dgpcr_flag_hist`
 where dt_sk_id= vdt_id and x_dgpcr_flag in ('Y', 'A')
 
 union distinct
 select distinct service_msisdn
 from `data-bi-prd-935c.bi_mart.fct_ioh_dgpcr_consentdt_new`
 where rank_ind = 1 and dt =  vdt_id
 and x_consent_dt <=  vdt_id
) c on a.sbscrptn_msisdn = c.service_msisdn
where a.dt_id =  vdt_id
group by 1,2,3,4;


delete from `data-bi-prd-935c.bi_mart.fct_rgu_voice_sms_free` where dt = vdt_id;

insert into `data-bi-prd-935c.bi_mart.fct_rgu_voice_sms_free`
with subs as (select * from `data-dtptechm-prd-c7ca.dwh.sbscrptn_attribs`)
select distinct cast(a.transaction_date as date) as dt,
cast(d.sbscrptn_ek_id as string),
a.called_number as sbscrptn_msisdn,
'sms_a2p_domestic' as tag
from 
(
    select distinct a.transaction_date, a.called_number
    from `data-bi-prd-935c.bi_mart.sms_a2p_sucess` a
    where CAST(transaction_date AS STRING) <> 'transaction_date' and CAST(transaction_date AS DATE) = vdt_id
) a
join
(
 select distinct service_msisdn
 from `data-bi-prd-935c.bi_mart.project_ioh_dgpcr_flag_hist`
 where x_dgpcr_flag in ('Y', 'A')
 and dt_sk_id = vdt_id
 
 union distinct

 select distinct service_msisdn
 from `data-bi-prd-935c.bi_mart.fct_ioh_dgpcr_consentdt_new`
 where rank_ind = 1 and CAST(dt AS DATE) = vdt_id
 and CAST(x_consent_dt AS DATE) <= vdt_id
) c on a.called_number = c.service_msisdn
join subs d on a.called_number = d.sbscrptn_msisdn and d.rank_ind = 1 and d.tool_of_trade_ind = 'N' and d.product_id = 8;

delete from `data-bi-prd-935c.bi_mart.fct_rgu_ioh_nik_mstr` where dt = vdt_id;

--#Dump the RGU Daily, RGU30, and RGU90 by NIK

--RGU Daily
insert into `data-bi-prd-935c.bi_mart.fct_rgu_ioh_nik_mstr`
with subs as (select * from `data-dtptechm-prd-c7ca.dwh.sbscrptn_attribs`)
select distinct cast(vdt_id as date) as dt, 'rgu_daily' as tag, cast(a.sbscrptn_ek_id as string), b.sbscrptn_msisdn,
 (
    SELECT MIN(d)
    FROM UNNEST([
      cast(first_usage_dt as date),
      safe.parse_date('%Y%m%d',cast(first_billing_usage_dt_sk_id as string)),
      cast(any_event_first_usage_date as date)
    ]) AS d
    WHERE d IS NOT NULL
  ) AS first_usage_dt,
'B2C' as Subs_Segment
from `data-dtptechm-prd-c7ca.dwh.rgs_subs_detail` a
left outer join subs b on a.sbscrptn_ek_id = b.sbscrptn_ek_id 
join
(
 select distinct service_msisdn
 from `data-bi-prd-935c.bi_mart.project_ioh_dgpcr_flag_hist`
 where x_dgpcr_flag in ('Y', 'A')
 and dt_sk_id = vdt_id
) c on b.sbscrptn_msisdn = c.service_msisdn
	where CAST(load_dt_sk_id AS DATE) = vdt_id
and rgs_all_ex_sp = true and a.tool_of_trade_ind = 'N' and a.product_id = 8;

delete from `data-bi-prd-935c.bi_mart.fct_ioh_rgu_daily_nik_add` where dt = vdt_id;

--RGU Daily Add
insert into `data-bi-prd-935c.bi_mart.fct_ioh_rgu_daily_nik_add`
with subs as (select * from `data-dtptechm-prd-c7ca.dwh.sbscrptn_attribs`)
select cast(a.load_dt_sk_id as date) as dt, 'rgu_daily' as tag, cast(a.sbscrptn_ek_id as string)sbscrptn_ek_id, b.sbscrptn_msisdn,
 (
    SELECT MIN(d)
    FROM UNNEST([
      cast(first_usage_dt as date),
      safe.parse_date('%Y%m%d',cast(first_billing_usage_dt_sk_id as string)),
      cast(any_event_first_usage_date as date)
    ]) AS d
    WHERE d IS NOT NULL
  ) as first_usage_dt
from `data-dtptechm-prd-c7ca.dwh.rgs_subs_detail` a
left outer join subs b 
on cast(a.sbscrptn_ek_id as string) = cast(b.sbscrptn_ek_id as string) 
left outer join
(
    select distinct dt, sbscrptn_ek_id
    from `data-bi-prd-935c.bi_mart.fct_rgu_ioh_nik_mstr`
    where tag = 'rgu_daily' and CAST(dt AS DATE) = vdt_id
) c on cast(a.load_dt_sk_id as date) = c.dt and cast(a.sbscrptn_ek_id as string) = cast(c.sbscrptn_ek_id as string)
left outer join
(
    select distinct service_msisdn, x_consent_dt as x_consent_dt
    from `data-bi-prd-935c.bi_mart.fct_ioh_dgpcr_consentdt_new`
    where rank_ind = 1 and CAST(dt AS DATE) = vdt_id and x_consent_dt <=  vdt_id
) d on b.sbscrptn_msisdn = d.service_msisdn 
where CAST(load_dt_sk_id AS DATE) = vdt_id
and rgs_all_ex_sp = true
and a.tool_of_trade_ind = 'N' 
and a.product_id = 8
and c.sbscrptn_ek_id is null
and d.service_msisdn is not null;
--and coalesce(d.service_msisdn, e.service_msisdn) is not null';

--RGU30
insert into `data-bi-prd-935c.bi_mart.fct_rgu_ioh_nik_mstr`
select distinct cast(vdt_id as date) as dt, 'rgu30' as tag, a.sbscrptn_ek_id, a.sbscrptn_msisdn,
first_usage_dt,
'B2C' as Subs_Segment
from 
(
 select sbscrptn_ek_id, sbscrptn_msisdn, first_usage_dt
 from
 (
  select distinct a.sbscrptn_ek_id, sbscrptn_msisdn, first_usage_dt,
  row_number() over(partition by sbscrptn_ek_id order by first_usage_dt asc) as rnk
  from
  (
   select sbscrptn_ek_id, sbscrptn_msisdn, first_usage_dt, row_number() over(partition by sbscrptn_ek_id, sbscrptn_msisdn order by first_usage_dt asc) as rnk
   from `data-bi-prd-935c.bi_mart.fct_rgu_ioh_nik_mstr` a
   where a.tag = 'rgu_daily'
   and CAST(a.dt AS DATE) >= DATE_SUB(vdt_id, INTERVAL 29 DAY)
   and CAST(a.dt AS DATE) <= vdt_id

   union all

   select sbscrptn_ek_id, sbscrptn_msisdn, first_usage_dt, 
   row_number() over(partition by sbscrptn_ek_id, sbscrptn_msisdn order by first_usage_dt asc) as rnk
   from `data-bi-prd-935c.bi_mart.fct_ioh_rgu_daily_nik_add` a
   where a.tag = 'rgu_daily'
   and CAST(CAST(a.dt AS STRING) AS DATE) >= DATE_SUB(vdt_id, INTERVAL 29 DAY)
   and CAST(CAST(a.dt AS STRING) AS DATE) <= vdt_id

   union all

   select sbscrptn_ek_id, sbscrptn_msisdn, first_usage_dt, 
   row_number() over(partition by sbscrptn_ek_id, sbscrptn_msisdn order by first_usage_dt asc) as rnk
   from `data-bi-prd-935c.bi_mart.fct_inc_voice_offnet` a
   where  
   CAST(CAST(a.dt AS STRING) AS DATE) >= DATE_SUB(vdt_id, INTERVAL 29 DAY)
   and CAST(CAST(a.dt AS STRING) AS DATE) <= vdt_id
   and sbscrptn_ek_id is not null 
  ) a
  where a.rnk = 1
 ) b where b.rnk = 1
) a;





--RGU90
insert into `data-bi-prd-935c.bi_mart.fct_rgu_ioh_nik_mstr`
select distinct cast(vdt_id as date) as dt, 'rgu90' as tag, a.sbscrptn_ek_id, a.sbscrptn_msisdn,
first_usage_dt,
'B2C' as Subs_Segment
from 
(
 select sbscrptn_ek_id, sbscrptn_msisdn, first_usage_dt
 from
 (
  select distinct a.sbscrptn_ek_id, sbscrptn_msisdn, first_usage_dt,
  row_number() over(partition by sbscrptn_ek_id order by first_usage_dt asc) as rnk
  from
  (
   select sbscrptn_ek_id, sbscrptn_msisdn, first_usage_dt, row_number() over(partition by sbscrptn_ek_id, sbscrptn_msisdn order by first_usage_dt asc) as rnk
   from `data-bi-prd-935c.bi_mart.fct_rgu_ioh_nik_mstr` a
   where a.tag = 'rgu_daily'
   and CAST(CAST(a.dt AS STRING) AS DATE) >= DATE_SUB(vdt_id, INTERVAL 89 DAY)
   and CAST(a.dt AS DATE) <= vdt_id

   union all

   select sbscrptn_ek_id, sbscrptn_msisdn, first_usage_dt, 
   row_number() over(partition by sbscrptn_ek_id, sbscrptn_msisdn order by first_usage_dt asc) as rnk
   from `data-bi-prd-935c.bi_mart.fct_ioh_rgu_daily_nik_add` a
   where a.tag = 'rgu_daily'
   and CAST(CAST(a.dt AS STRING) AS DATE) >= DATE_SUB(vdt_id, INTERVAL 89 DAY)
   and CAST(CAST(a.dt AS STRING) AS DATE) <= vdt_id

   union all

   select sbscrptn_ek_id, sbscrptn_msisdn, first_usage_dt, 
   row_number() over(partition by sbscrptn_ek_id, sbscrptn_msisdn order by first_usage_dt asc) as rnk
   from `data-bi-prd-935c.bi_mart.fct_inc_voice_offnet` a
   where  
   CAST(CAST(a.dt AS STRING) AS DATE) >= DATE_SUB(vdt_id, INTERVAL 89 DAY)
   and CAST(CAST(a.dt AS STRING) AS DATE) <= vdt_id
   and sbscrptn_ek_id is not null 

  ) a
  where a.rnk = 1
 ) b where b.rnk = 1
) a;

--1. RGU_Daily

delete from `data-bi-prd-935c.bi_mart.project_ioh_kpi_daily_tracker_national_wise` 
where CAST(load_dt_sk_id AS DATE) = vdt_id and kpi_code = 'rgu_daily' and definition = 'IOH';

insert into `data-bi-prd-935c.bi_mart.project_ioh_kpi_daily_tracker_national_wise`
select CAST(vdt_id AS date) as load_dt_sk_id, 'H3I' as entity, 'rgu_daily' as kpi_code, 'IOH' as definition, cast(vdt_id as date) as date, count(distinct a.sbscrptn_ek_id) as value
from
(
    select distinct a.sbscrptn_ek_id
    from `data-bi-prd-935c.bi_mart.fct_rgu_ioh_nik_mstr` a
    where tag = 'rgu_daily'
    and CAST(dt AS DATE) = vdt_id 

 union distinct

 select distinct a.sbscrptn_ek_id
 from `data-bi-prd-935c.bi_mart.fct_ioh_rgu_daily_nik_add` a
 where tag = 'rgu_daily'
 and CAST(CAST(dt AS STRING) AS DATE) = vdt_id

 union distinct

 select distinct a.sbscrptn_ek_id
 from `data-bi-prd-935c.bi_mart.fct_inc_voice_offnet`  a
 where CAST(CAST(dt AS STRING) AS DATE) = vdt_id --ADD By Indra Maulana Ikhsan 20241209 Request by Mas Denny
 and sbscrptn_ek_id is not null --ADD By Indra Maulana Ikhsan 20250811 Request by Mas Denny
 

) a
group by 1,2,3,4,5;
                 
--3. rgu30_base aka rgs30_daily

--(IOH)

delete from `data-bi-prd-935c.bi_mart.project_ioh_kpi_daily_tracker_national_wise` 
where CAST(load_dt_sk_id AS DATE) = vdt_id and kpi_code = 'rgu30_daily' and definition = 'IOH';

insert into `data-bi-prd-935c.bi_mart.project_ioh_kpi_daily_tracker_national_wise`
select CAST(vdt_id AS date) as load_dt_sk_id, 'H3I' as entity, 'rgu30_daily' as kpi_code, 'IOH' as definition, cast(vdt_id as date) as date, count(distinct a.sbscrptn_ek_id) as value
from `data-bi-prd-935c.bi_mart.fct_rgu_ioh_nik_mstr` a
where tag = 'rgu30' and CAST(dt AS DATE) = vdt_id
group by 1,2,3,4,5;
                 
-- --delete the project_ioh_fu_master_v2 where ga_date = ||VDate|| and Tag = 'New-RGU' --> (if rerun process is happened)


delete from `data-bi-prd-935c.bi_mart.project_ioh_fu_master_v2` where ga_date >= vdt_id and Tag = 'New-RGU';


-- --delete the project_ioh_fu_master_v2 where first_usg_dt = ||VDate|| and Tag in ('Non-RITA', 'RITA') --> (if rerun process is happened)

delete from `data-bi-prd-935c.bi_mart.project_ioh_fu_master_v2` where first_usg_dt >= vdt_id and Tag in ('Non-RITA', 'RITA');


-- --Update the GA and set null for first usage that coming from previous date or previous month --> (if rerun process is happened)

update `data-bi-prd-935c.bi_mart.project_ioh_fu_master_v2` set ga_date = null where ga_date >= vdt_id;

-- --First Usage from RGU with First Usage Date is null or First Usage Date > RGU Date

-- --We add this logic start on 01 Mar 2022 onwards. Set the ga_date with the vdt_id
insert into `data-bi-prd-935c.bi_mart.project_ioh_fu_master_v2`
select distinct cast(a.first_usg_dt as date), 
cast(a.sbscrptn_ek_id as string), a.sbscrptn_msisdn,
cast(vdt_id as date) as GA_Date, 
'B2C' as Subs_Segment, 
'New-RGU' as Tag
from
(
 select distinct a.sbscrptn_ek_id, a.sbscrptn_msisdn, CAST(first_usage_dt AS STRING) as first_usg_dt
  from `data-bi-prd-935c.bi_mart.fct_rgu_ioh_nik_mstr` a
  left outer join `data-bi-prd-935c.bi_mart.project_ioh_rita_adjustment_detail` b 
  on CAST(a.sbscrptn_ek_id AS STRING) = cast(b.sbscrptn_ek_id as string) --check into RITA
  left outer join
  (
   select distinct sbscrptn_ek_id
   from `data-bi-prd-935c.bi_mart.project_ioh_fu_master_v2`
   where ga_date >= '2022-01-01' and ga_date <= '2022-02-28'
  ) c on cast(a.sbscrptn_ek_id as string) = cast(c.sbscrptn_ek_id as string)
  where a.tag = 'rgu30' 
  and cast(dt as date) = vdt_id
  and b.sbscrptn_ek_id is null --exclude RITA
  and 
  (
   first_usage_dt is null or 
   first_usage_dt  > vdt_id and first_usage_dt >= '2022-01-01' or
   first_usage_dt  < vdt_id and first_usage_dt >= '2022-01-01' and c.sbscrptn_ek_id is null --take subs whoose FU but not GA in 01 Jan - 28 Feb 2022
  )
 ) a
 left outer join
 (
  select distinct sbscrptn_ek_id
  from `data-bi-prd-935c.bi_mart.fct_rgu_ioh_nik_mstr` a
  where tag = 'rgu30' and CAST(dt AS DATE) = DATE_SUB(vdt_id, INTERVAL 1 DAY) 
 ) b on cast(a.sbscrptn_ek_id as string) = cast(b.sbscrptn_ek_id as string)
 left outer join
 (
  select distinct sbscrptn_ek_id
  from `data-bi-prd-935c.bi_mart.fct_rgu_ioh_nik_mstr` a
  where tag = 'rgu90' and CAST(dt AS DATE) = DATE_SUB(vdt_id, INTERVAL 1 DAY)
 ) c on cast(a.sbscrptn_ek_id as string) = cast(c.sbscrptn_ek_id as string)
 left outer join `data-bi-prd-935c.bi_mart.project_ioh_fu_master_v2` d 
 on cast(a.sbscrptn_ek_id as string) = cast(d.sbscrptn_ek_id as string) --and d.ga_date < vdt_id--exclude from master fu tbl
 where b.sbscrptn_ek_id is null and c.sbscrptn_ek_id is null and d.sbscrptn_ek_id is null;

-- --First Usage from `data-dtptechm-prd-c7ca.dwh.sbscrptn_attribs`

 insert into `data-bi-prd-935c.bi_mart.project_ioh_fu_master_v2`
 select distinct                                                                                                            
 (
    SELECT MIN(d)
    FROM UNNEST([
      cast(first_usage_dt as date),
      safe.parse_date('%Y%m%d',cast(first_billing_usage_dt_sk_id as string)),
      cast(any_event_first_usage_date as date)
    ]) AS d
    WHERE d IS NOT NULL
  )  as first_usg_dt,                                                                                                              
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
  --where first_rgs_date = vdt_id
 ) b on cast(sd.sbscrptn_ek_id as string)= cast(b.sbscrptn_ek_id as string)
 left outer join `data-bi-prd-935c.bi_mart.project_ioh_fu_master_v2` c 
 on cast(sd.sbscrptn_ek_id as string) = cast(c.sbscrptn_ek_id as string) --exclude from master fu tbl
 where (
    SELECT MIN(d)
    FROM UNNEST([
      cast(first_usage_dt as date),
      safe.parse_date('%Y%m%d',cast(first_billing_usage_dt_sk_id as string)),
      cast(any_event_first_usage_date as date)
    ]) AS d
    WHERE d IS NOT NULL
  )  = vdt_id
-- where least(cast(first_usage_dt as date), least(PARSE_DATE('%Y%m%d',cast(first_billing_usage_dt_sk_id as string)), cast(any_event_first_usage_date as date))) = vdt_id
 and coalesce(cast(product_id as string),'8') = '8' and coalesce(tool_of_trade_ind, 'N') = 'N'
 and b.sbscrptn_ek_id is null
 and c.sbscrptn_ek_id is null;

-- --First Usage from RITA

 insert into `data-bi-prd-935c.bi_mart.project_ioh_fu_master_v2`
 select distinct first_rgs_date as fist_usg_dt, a.sbscrptn_ek_id, b.sbscrptn_msisdn,
 cast(null as date) as GA_Date, 'B2C' as Subs_Segment, 'RITA' as Tag
 from `data-bi-prd-935c.bi_mart.project_ioh_rita_adjustment_detail` a
 left outer join `data-dtptechm-prd-c7ca.dwh.sbscrptn_attribs` b on a.sbscrptn_ek_id = cast(b.sbscrptn_ek_id as string)
 left outer join `data-bi-prd-935c.bi_mart.project_ioh_fu_master_v2` c on a.sbscrptn_ek_id = cast(c.sbscrptn_ek_id as string) --exclude from master fu tbl
 where cast(first_rgs_date as date) = vdt_id
 and c.sbscrptn_ek_id is null;

--#Create RGU Movement on temporary table

drop table if exists `data-bi-prd-935c.bi_stg.tmp_rgs30_movement`;

create table `data-bi-prd-935c.bi_stg.tmp_rgs30_movement` as
select load_dt_sk_id, tag, count(distinct a.sbscrptn_ek_id) as subs
from
(
 select distinct cast(vdt_id as date) as load_dt_sk_id, 'rgu30_opening' as tag, a.sbscrptn_ek_id
 from `data-bi-prd-935c.bi_mart.fct_rgu_ioh_nik_mstr` a
 where tag = 'rgu30' and dt = DATE_SUB(vdt_id, INTERVAL 1 DAY)
 
 union distinct

 select distinct cast(dt as date) as load_dt_sk_id,
 case when e.sbscrptn_ek_id is not null then 'rgu30_gross_add'
 else
  case when a.fu_dt = vdt_id then 
  case when c.sbscrptn_ek_id is null then 
   case when f.sbscrptn_ek_id is null then 'rgu30_gross_add'
   else 'rgu30_churn_back'
   end
  else 'rgu30_churn_back' end 
 else 
  case when d.sbscrptn_ek_id is not null then 
   case when c.sbscrptn_ek_id is null then 'rgu30_gross_add' else 'rgu30_churn_back' end
  else 'rgu30_churn_back' end
 end 
 end as tag,
 a.sbscrptn_ek_id
 from
 (
  select distinct a.*
  from
  (
   select distinct cast(a.dt as date) as dt, a.sbscrptn_ek_id,
   case when b.sbscrptn_ek_id is not null then b.first_rgs_date --set the first usage date for RITA
   else a.first_usage_dt end as fu_dt
   from `data-bi-prd-935c.bi_mart.fct_rgu_ioh_nik_mstr` a
   left outer join `data-bi-prd-935c.bi_mart.project_ioh_rita_adjustment_detail` b on cast(a.sbscrptn_ek_id as string) = cast(b.sbscrptn_ek_id as string)--check into RITA
   where a.tag = 'rgu30' and dt = vdt_id
  ) a
 ) a
 left outer join
 (
  select distinct sbscrptn_ek_id
  from `data-bi-prd-935c.bi_mart.fct_rgu_ioh_nik_mstr` a
  where tag = 'rgu30' and dt = DATE_SUB(vdt_id, INTERVAL 1 DAY)
 ) b on cast(a.sbscrptn_ek_id as string)= cast(b.sbscrptn_ek_id as string)
 left outer join
 (
  select distinct sbscrptn_ek_id
  from `data-bi-prd-935c.bi_mart.fct_rgu_ioh_nik_mstr` a
  where tag = 'rgu90' and dt = DATE_SUB(vdt_id, INTERVAL 1 DAY)
 ) c on cast(a.sbscrptn_ek_id as string) = cast(c.sbscrptn_ek_id as string)
 left outer join `data-bi-prd-935c.bi_mart.project_ioh_fu_master_v2` d on cast(a.sbscrptn_ek_id as string)= cast(d.sbscrptn_ek_id as string)
 --and d.first_usg_dt >= to_char(date_trunc('month', vdt_id), 'yyyymmdd')::int
 --and d.first_usg_dt <= vdt_id
 and d.ga_date is null
 and d.tag <> 'New-RGU'
 left outer join `data-bi-prd-935c.bi_mart.project_ioh_fu_master_v2` e on cast(a.sbscrptn_ek_id as string)= cast(e.sbscrptn_ek_id as string)
 and e.ga_date = vdt_id and e.tag = 'New-RGU'
 left outer join `data-bi-prd-935c.bi_mart.project_ioh_fu_master_v2` f on cast(a.sbscrptn_ek_id as string)= cast(f.sbscrptn_ek_id as string) and f.ga_date is not null
 where b.sbscrptn_ek_id is null

 union distinct

 select distinct cast(vdt_id as date) as load_dt_sk_id,
 'rgu30_gross_churn' as tag,
 a.sbscrptn_ek_id
 from `data-bi-prd-935c.bi_mart.fct_rgu_ioh_nik_mstr` a
 left outer join
 (
  select distinct a.sbscrptn_ek_id
  from `data-bi-prd-935c.bi_mart.fct_rgu_ioh_nik_mstr` a
  where tag = 'rgu30' and dt = vdt_id
 ) b on cast(a.sbscrptn_ek_id as string) = cast(b.sbscrptn_ek_id as string)
 where tag = 'rgu30' and dt = DATE_SUB(vdt_id, INTERVAL 1 DAY)
 and b.sbscrptn_ek_id is null
) a
group by 1,2;

--#Insert into `data-bi-prd-935c.bi_mart.project_ioh_kpi_daily_tracker_national_wise`

delete from `data-bi-prd-935c.bi_mart.project_ioh_kpi_daily_tracker_national_wise` where load_dt_sk_id = vdt_id 
and kpi_code in ('rgu30_opening', 'rgu30_gross_add', 'rgu30_gross_churn', 'rgu30_churn_back', 'rgu30_net_churn', 'rgu30_closing_base', 'rgu30_net_add')
and definition = 'IOH';

insert into `data-bi-prd-935c.bi_mart.project_ioh_kpi_daily_tracker_national_wise`
select load_dt_sk_id, 'H3I' as entity, tag as kpi_code, 'IOH' as definition, load_dt_sk_id as date, subs as value
from
(
select load_dt_sk_id, tag, subs
from `data-bi-prd-935c.bi_stg.tmp_rgs30_movement`

union all

select a.load_dt_sk_id, 'rgu30_net_churn' as tag, sum(subs) as subs
from
(
 select load_dt_sk_id, subs
 from `data-bi-prd-935c.bi_stg.tmp_rgs30_movement` a
 where tag = 'rgu30_gross_churn'

 union all

 select load_dt_sk_id, subs * -1 as subs 
 from `data-bi-prd-935c.bi_stg.tmp_rgs30_movement` a
 where tag = 'rgu30_churn_back'
) a
group by 1,2

union all

select a.load_dt_sk_id, 'rgu30_closing_base' as tag, sum(subs) as subs
from
(
 select load_dt_sk_id, subs
 from `data-bi-prd-935c.bi_stg.tmp_rgs30_movement` a
 where tag = 'rgu30_opening'

 union all

 select load_dt_sk_id, subs
 from `data-bi-prd-935c.bi_stg.tmp_rgs30_movement` a
 where tag = 'rgu30_gross_add'

 union all
 
 select load_dt_sk_id, subs * -1
 from `data-bi-prd-935c.bi_stg.tmp_rgs30_movement` a
 where tag = 'rgu30_gross_churn'

 union all

 select load_dt_sk_id, subs
 from `data-bi-prd-935c.bi_stg.tmp_rgs30_movement` a
 where tag = 'rgu30_churn_back'
) a
group by 1,2

union all

select a.load_dt_sk_id, 'rgu30_net_add' as tag, sum(subs) as subs
from
(
 select load_dt_sk_id, subs
 from `data-bi-prd-935c.bi_stg.tmp_rgs30_movement` a
 where tag = 'rgu30_gross_add'

 union all
 
 select load_dt_sk_id, subs * -1
 from `data-bi-prd-935c.bi_stg.tmp_rgs30_movement` a
 where tag = 'rgu30_gross_churn'

 union all

 select load_dt_sk_id, subs
 from `data-bi-prd-935c.bi_stg.tmp_rgs30_movement` a
 where tag = 'rgu30_churn_back'
) a
group by 1,2
) a;
  

--#Insert the rgu30 movement detail into tabel fct_ioh_rgu_NIK_movement

delete from `data-bi-prd-935c.bi_mart.fct_ioh_rgu_nik_movement`where dt = vdt_id and tag like 'rgu30%';
 
insert into `data-bi-prd-935c.bi_mart.fct_ioh_rgu_nik_movement`
select distinct dt as load_dt_sk_id,
case when e.sbscrptn_ek_id is not null then 'rgu30_gross_add'
 else
  case when a.fu_dt = vdt_id then 
  case when c.sbscrptn_ek_id is null then 
   case when f.sbscrptn_ek_id is null then 'rgu30_gross_add'
   else 'rgu30_churn_back'
   end
  else 'rgu30_churn_back' end 
 else 
  case when d.sbscrptn_ek_id is not null then 
   case when c.sbscrptn_ek_id is null then 'rgu30_gross_add' else 'rgu30_churn_back' end
  else 'rgu30_churn_back' end
 end 
end as tag,
cast(a.sbscrptn_ek_id as string) sbscrptn_ek_id,
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
  left outer join `data-bi-prd-935c.bi_mart.project_ioh_rita_adjustment_detail` b on cast(a.sbscrptn_ek_id as string) = cast(b.sbscrptn_ek_id as string) --check into RITA
  where a.tag = 'rgu30' and dt = vdt_id
 ) a
) a
left outer join
(
 select distinct sbscrptn_ek_id
 from `data-bi-prd-935c.bi_mart.fct_rgu_ioh_nik_mstr` a
 where tag = 'rgu30' and dt = DATE_SUB(vdt_id, INTERVAL 1 DAY)
) b on cast(a.sbscrptn_ek_id as string) = cast(b.sbscrptn_ek_id as string)
left outer join
(
 select distinct sbscrptn_ek_id
 from `data-bi-prd-935c.bi_mart.fct_rgu_ioh_nik_mstr` a
 where tag = 'rgu90' and dt = DATE_SUB(vdt_id, INTERVAL 1 DAY)
) c on cast(a.sbscrptn_ek_id as string) = cast(c.sbscrptn_ek_id as string)
left outer join `data-bi-prd-935c.bi_mart.project_ioh_fu_master_v2` d on cast(a.sbscrptn_ek_id as string) = cast(d.sbscrptn_ek_id as string) 
--and d.first_usg_dt >= to_char(date_trunc('month', vdt_id), 'yyyymmdd')::int
--and d.first_usg_dt <= vdt_id
and d.ga_date is null
and d.tag <> 'New-RGU'
left outer join `data-bi-prd-935c.bi_mart.project_ioh_fu_master_v2` e on cast(a.sbscrptn_ek_id as string) = cast(e.sbscrptn_ek_id as string) 
and e.ga_date = vdt_id and e.tag = 'New-RGU'
left outer join `data-bi-prd-935c.bi_mart.project_ioh_fu_master_v2` f on cast(a.sbscrptn_ek_id as string)= cast(f.sbscrptn_ek_id as string) and f.ga_date is not null
where b.sbscrptn_ek_id is null

union distinct

select distinct cast(vdt_id as date) as load_dt_sk_id,
'rgu30_gross_churn' as tag,
cast(a.sbscrptn_ek_id as string) sbscrptn_ek_id,
a.sbscrptn_msisdn,
'B2C' as Subs_Segment
from `data-bi-prd-935c.bi_mart.fct_rgu_ioh_nik_mstr` a
left outer join
(
 select distinct a.sbscrptn_ek_id
 from `data-bi-prd-935c.bi_mart.fct_rgu_ioh_nik_mstr` a
 where tag = 'rgu30' and dt = vdt_id
) b on cast(a.sbscrptn_ek_id as string) = cast(b.sbscrptn_ek_id as string)
where tag = 'rgu30' and dt = DATE_SUB(vdt_id, INTERVAL 1 DAY)
and b.sbscrptn_ek_id is null;
--Update the first usage table master (I)

 update `data-bi-prd-935c.bi_mart.project_ioh_fu_master_v2` a
 set ga_date = b.dt
from `data-bi-prd-935c.bi_mart.fct_ioh_rgu_nik_movement` b
 where cast(a.sbscrptn_ek_id as string) = cast(b.sbscrptn_ek_id as string) 
 and a.ga_date is null
-- --and a.first_usg_dt >= to_char(date_trunc('month', vdt_id), 'yyyymmdd')::int
-- --and a.first_usg_dt <= vdt_id
 and a.tag <> 'New-RGU'
 and b.tag = 'rgu30_gross_add'
 and b.dt = vdt_id;

--20 - 21 Inflaw & Base

delete from `data-bi-prd-935c.bi_mart.project_ioh_kpi_daily_tracker_national_wise` 
where load_dt_sk_id = vdt_id and kpi_code in ('rgu30_inflow', 'rgu30_base') 
and definition = 'IOH';


insert into `data-bi-prd-935c.bi_mart.project_ioh_kpi_daily_tracker_national_wise`
select load_dt_sk_id, 'H3I' as entity,
case when (first_usage_dt is not null and (date_diff(cast(load_dt_sk_id as date),cast(first_usage_dt as date),day) >= 90)) then 'rgu30_base'
     else 'rgu30_inflow' end as kpi_code,
'IOH' as definition, load_dt_sk_id as date, count(distinct a.sbscrptn_ek_id) as value
from
(
 select distinct a.dt as load_dt_sk_id, a.sbscrptn_ek_id, a.first_usage_dt
 from `data-bi-prd-935c.bi_mart.fct_rgu_ioh_nik_mstr` a
 where tag = 'rgu30' and dt = vdt_id
) a
group by 1,2,3,4,5;