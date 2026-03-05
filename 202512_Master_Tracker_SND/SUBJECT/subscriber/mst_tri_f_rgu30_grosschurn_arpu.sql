declare vdt_id date default @vdt_id;
                                             
 --1a. First Usage table
 create or replace table `data-bi-prd-935c.bi_stg`.tmp_fu_stg_30 AS
 select sbscrptn_ek_id , case when fu_dt = '9999-12-31' then null else fu_dt end fu_dt from(
 select distinct cast(sbscrptn_ek_id as string) sbscrptn_ek_id,
 least(coalesce(date(first_usage_dt),'9999-12-31'), least(coalesce(parse_date('%Y%m%d',cast(first_billing_usage_dt_sk_id as string)),'9999-12-31'), coalesce(date(any_event_first_usage_date),'9999-12-31'))) as fu_dt
 from `data-dtptechm-prd-c7ca.dwh`.sbscrptn_attribs)a;

 --1b. Gross Add table
 
 create or replace table `data-bi-prd-935c.bi_stg`.tmp_ga_stg_30 AS
 select distinct dt as ga_dt, cast(sbscrptn_ek_id as string) sbscrptn_ek_id
 from `data-bi-prd-935c.bi_mart`.fct_ioh_mvmnt_1_detail_dec21
 where tag = 'rgu30_gross_add' and dt between date('2021-10-01') and date('2021-12-31')
 union distinct
 select distinct ga_date as ga_dt, sbscrptn_ek_id
 from `data-bi-prd-935c.bi_mart`.project_ioh_fu_master_v2
 where ga_date >= '2022-01-01' and ga_date <= vdt_id;

 --Favloc rolling 30
 
 create or replace table `data-bi-prd-935c.bi_stg`.tmp_favloc30 AS
 select * from 
 (
  select vdt_id as dt, sbscrptn_ek_id, site_id_30 as site_id, row_number () over (partition by sbscrptn_ek_id order by dt desc) rown
  from `data-bi-prd-935c.bi_mart`.ioh_subscriber_site_attribs_rolling 
  where dt between vdt_id - interval 30 day and vdt_id
 ) x where rown = 1;
 




 delete from `data-bi-prd-935c.bi_mart`.fct_rgu30_aging_circle where dt = vdt_id;
 
 insert into `data-bi-prd-935c.bi_mart`.fct_rgu30_aging_circle
 select a.dt, a.sbscrptn_ek_id, date_diff(a.dt,coalesce(b.ga_dt, c.fu_dt),day) as aging_days, d.site_id
 from `data-bi-prd-935c.bi_mart`.fct_rgu_ioh_NIK_mstr a
 left outer join `data-bi-prd-935c.bi_stg`.tmp_ga_stg_30 b on a.sbscrptn_ek_id = b.sbscrptn_ek_id
 left outer join `data-bi-prd-935c.bi_stg`.tmp_fu_stg_30 c on a.sbscrptn_ek_id = c.sbscrptn_ek_id
 left outer join `data-bi-prd-935c.bi_stg`.tmp_favloc30 d on a.sbscrptn_ek_id = d.sbscrptn_ek_id and a.dt = d.dt
 where a.dt = vdt_id and a.tag = 'rgu30';
 




 --********************
 --Revenue for RGU30
 --********************
 
 --tmp_new_tracker_subs_reg_rev_m1

 create or replace table `data-bi-prd-935c.bi_stg`.tmp_new_tracker_subs_reg_rev_m1_30 as
 select sbscrptn_ek_id, sum(revenue) as revenue
 from `data-bi-prd-935c.bi_mart`.fct_cwn_rev_detail_fnl
 where trx_dt_sk_id between vdt_id - interval 29 day and vdt_id
 group by 1;




 --tmp_new_tracker_subs_reg_rev_m2
 
 create or replace table `data-bi-prd-935c.bi_stg`.tmp_new_tracker_subs_reg_rev_m2_30 as
 select sbscrptn_ek_id, sum(revenue) as revenue
 from `data-bi-prd-935c.bi_mart`.fct_cwn_rev_detail_fnl
 where trx_dt_sk_id between vdt_id - interval 59 day
 and vdt_id - interval 30 day
 group by 1;




 --tmp_new_tracker_subs_reg_rev_m3

 create or replace table `data-bi-prd-935c.bi_stg`.tmp_new_tracker_subs_reg_rev_m3_30 as
 select sbscrptn_ek_id, sum(revenue) as revenue
 from `data-bi-prd-935c.bi_mart`.fct_cwn_rev_detail_fnl
 where trx_dt_sk_id between vdt_id - interval 89 day
 and vdt_id - interval 60 day
 group by 1;

 



 --*********
 --**RGU30**
 --*********
 
 delete from `data-bi-prd-935c.bi_mart`.fct_rgu30_aging_circle_arpu where dt = vdt_id;

 insert into `data-bi-prd-935c.bi_mart`.fct_rgu30_aging_circle_arpu
 --create table `data-bi-prd-935c.bi_mart`.fct_rgu30_aging_circle_arpu
 --with (appendonly=true, compresstype=zlib, compresslevel=3) AS
 select *,
 case when (rev_m1 + rev_m2 + rev_m3) = 0 then (rev_m1 + rev_m2 + rev_m3)
 else (rev_m1 + rev_m2 + rev_m3)/(cnt_m1 + cnt_m2 + cnt_m3) end as arpu
 from
 (
  select a.*,
  cast(coalesce(b.revenue,0) as numeric) as rev_m1,
  cast(coalesce(c.revenue,0) as numeric) as rev_m2,
  cast(coalesce(d.revenue,0) as numeric) as rev_m3,
  case when coalesce(b.revenue,0) <> 0 then 1 else 0 end as cnt_m1,
  case when coalesce(c.revenue,0)  <> 0 then 1 else 0 end as cnt_m2,
  case when coalesce(d.revenue,0) <> 0 then 1 else 0 end as cnt_m3
  from `data-bi-prd-935c.bi_mart`.fct_rgu30_aging_circle a
  left outer join `data-bi-prd-935c.bi_stg`.tmp_new_tracker_subs_reg_rev_m1_30 b on a.sbscrptn_ek_id = b.sbscrptn_ek_id
  left outer join `data-bi-prd-935c.bi_stg`.tmp_new_tracker_subs_reg_rev_m2_30 c on a.sbscrptn_ek_id = c.sbscrptn_ek_id
  left outer join `data-bi-prd-935c.bi_stg`.tmp_new_tracker_subs_reg_rev_m3_30 d on a.sbscrptn_ek_id = d.sbscrptn_ek_id
  where a.dt = vdt_id
 ) a;
                                                                                                                                            