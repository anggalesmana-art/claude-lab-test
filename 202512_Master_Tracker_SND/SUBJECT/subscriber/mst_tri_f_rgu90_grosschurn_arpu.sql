declare vdt_id date default @vdt_id;

 --1a. First Usage table

 create or replace table `data-bi-prd-935c.bi_stg`.tmp_fu_stg as
 select sbscrptn_ek_id , case when fu_dt = '9999-12-31' then null else fu_dt end fu_dt from(
 select distinct cast(sbscrptn_ek_id as string) sbscrptn_ek_id,
 least(coalesce(date(first_usage_dt),'9999-12-31'), least(coalesce(parse_date('%Y%m%d',cast(first_billing_usage_dt_sk_id as string)),'9999-12-31'), coalesce(date(any_event_first_usage_date),'9999-12-31'))) as fu_dt
 from `data-dtptechm-prd-c7ca.dwh`.sbscrptn_attribs)a;
  



 --1b. Gross Add table

 create or replace table `data-bi-prd-935c.bi_stg`.tmp_ga_stg as
 select distinct dt as ga_dt, cast(sbscrptn_ek_id as string) sbscrptn_ek_id
 from `data-bi-prd-935c.bi_mart`.fct_ioh_mvmnt_1_detail_dec21
 where tag = 'rgu30_gross_add' and dt between date('2021-10-01') and date('2021-12-31')
 union distinct
 select distinct ga_date as ga_dt, sbscrptn_ek_id
 from `data-bi-prd-935c.bi_mart`.project_ioh_fu_master_v2
 where ga_date >= '2022-01-01' and ga_date <= vdt_id;


 
 

 --Favloc rolling 90

 
 create or replace table `data-bi-prd-935c.bi_stg`.tmp_favloc90 as
 select * from 
 (
  select vdt_id as dt, sbscrptn_ek_id, site_id_90 as site_id, row_number () over (partition by sbscrptn_ek_id order by dt desc) rown
  from `data-bi-prd-935c.bi_mart`.ioh_subscriber_site_attribs_rolling 
  where dt between vdt_id - interval 90 day and vdt_id
 ) x where rown = 1;
 




 delete from `data-bi-prd-935c.bi_mart`.fct_RGU90_Aging_Circle where dt = vdt_id;

 
 
 insert into `data-bi-prd-935c.bi_mart`.fct_RGU90_Aging_Circle
 select a.dt, a.sbscrptn_ek_id, cast(date_diff(a.dt,coalesce(b.ga_dt, c.fu_dt),day) as numeric) as aging_days, d.site_id
 from `data-bi-prd-935c.bi_mart`.fct_rgu_ioh_NIK_mstr a
 left outer join `data-bi-prd-935c.bi_stg`.tmp_ga_stg b on a.sbscrptn_ek_id = b.sbscrptn_ek_id
 left outer join `data-bi-prd-935c.bi_stg`.tmp_fu_stg c on a.sbscrptn_ek_id = c.sbscrptn_ek_id
 left outer join `data-bi-prd-935c.bi_stg`.tmp_favloc90 d on a.sbscrptn_ek_id = d.sbscrptn_ek_id and a.dt = d.dt
 where a.dt = vdt_id and a.tag = 'rgu90';




 --********************
 --Revenue for RGU90
 --********************
 
 --tmp_new_tracker_subs_reg_rev_m1

 create or replace table `data-bi-prd-935c.bi_stg`.tmp_new_tracker_subs_reg_rev_m1_new as
 select sbscrptn_ek_id, sum(revenue) as revenue
 from `data-bi-prd-935c.bi_mart`.fct_cwn_rev_detail_fnl
 where trx_dt_sk_id between vdt_id - interval 29 day and vdt_id
 group by 1;


 --tmp_new_tracker_subs_reg_rev_m2


 create or replace table `data-bi-prd-935c.bi_stg`.tmp_new_tracker_subs_reg_rev_m2_new as
 select sbscrptn_ek_id, sum(revenue) as revenue
 from `data-bi-prd-935c.bi_mart`.fct_cwn_rev_detail_fnl
 where trx_dt_sk_id between vdt_id - interval 59 day and vdt_id - interval 30 day
 group by 1;



 --tmp_new_tracker_subs_reg_rev_m3

 create or replace table `data-bi-prd-935c.bi_stg`.tmp_new_tracker_subs_reg_rev_m3_new as
 select sbscrptn_ek_id, sum(revenue) as revenue
 from `data-bi-prd-935c.bi_mart`.fct_cwn_rev_detail_fnl
 where trx_dt_sk_id between vdt_id - interval 89 day and vdt_id - interval 60 day
 group by 1;

 



 --*********
 --**RGU90**
 --*********
 
delete from `data-bi-prd-935c.bi_mart`.fct_RGU90_Aging_Circle_ARPU where dt = vdt_id;



insert into `data-bi-prd-935c.bi_mart`.fct_RGU90_Aging_Circle_ARPU
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
 from `data-bi-prd-935c.bi_mart`.fct_RGU90_Aging_Circle a
 left outer join `data-bi-prd-935c.bi_stg`.tmp_new_tracker_subs_reg_rev_m1_new b on a.sbscrptn_ek_id = b.sbscrptn_ek_id
 left outer join `data-bi-prd-935c.bi_stg`.tmp_new_tracker_subs_reg_rev_m2_new c on a.sbscrptn_ek_id = c.sbscrptn_ek_id
 left outer join `data-bi-prd-935c.bi_stg`.tmp_new_tracker_subs_reg_rev_m3_new d on a.sbscrptn_ek_id = d.sbscrptn_ek_id
 where a.dt = vdt_id
) a;



create or replace table `data-bi-prd-935c.bi_stg`.tmp_gc_aon_rev as
 select distinct dt, 'RGU90_Gross_Churn' as tag,
 a.sbscrptn_ek_id,
 case when ga_dt is not null then
  case
      when date_diff((a.dt - interval 90 day),ga_dt,day) >= 0 and date_diff((a.dt - interval 90 day),ga_dt,day) <= 29 then 'a.<=30D'
	  when date_diff((a.dt - interval 90 day),ga_dt,day) >= 30 and date_diff((a.dt - interval 90 day),ga_dt,day) <= 59 then 'b.<=60D'
	  when date_diff((a.dt - interval 90 day),ga_dt,day) >= 60 and date_diff((a.dt - interval 90 day),ga_dt,day) <= 89 then 'c.<=90D'
	  when date_diff((a.dt - interval 90 day),ga_dt,day) >= 90 and date_diff((a.dt - interval 90 day),ga_dt,day) <= 119 then 'd.<=120D'
	  when date_diff((a.dt - interval 90 day),ga_dt,day) >= 120 and date_diff((a.dt - interval 90 day),ga_dt,day) <= 179 then 'e.<=180D'
	  when date_diff((a.dt - interval 90 day),ga_dt,day) >= 180  then 'f.>180D'
  else 'f.>180D' end 
 else
 case
      when date_diff((a.dt - interval 90 day),fu_dt,day) >= 0 and date_diff((a.dt - interval 90 day),fu_dt,day) <= 29 then 'a.<=30D'
	  when date_diff((a.dt - interval 90 day),fu_dt,day) >= 30 and date_diff((a.dt - interval 90 day),fu_dt,day) <= 59 then 'b.<=60D'
	  when date_diff((a.dt - interval 90 day),fu_dt,day) >= 60 and date_diff((a.dt - interval 90 day),fu_dt,day) <= 89 then 'c.<=90D'
	  when date_diff((a.dt - interval 90 day),fu_dt,day) >= 90 and date_diff((a.dt - interval 90 day),fu_dt,day) <= 119 then 'd.<=120D'
	  when date_diff((a.dt - interval 90 day),fu_dt,day) >= 120 and date_diff((a.dt - interval 90 day),fu_dt,day) <= 179 then 'e.<=180D'
	  when date_diff((a.dt - interval 90 day),fu_dt,day) >= 180  then 'f.>180D'
 else 'f.>180D' end
 end as AON_slab,
 coalesce(ga_dt, fu_dt) as ga_fu_dt
 from `data-bi-prd-935c.bi_mart`.fct_ioh_rgu_NIK_movement a
 left outer join `data-bi-prd-935c.bi_stg`.tmp_ga_stg d on a.sbscrptn_ek_id = d.sbscrptn_ek_id
 left outer join `data-bi-prd-935c.bi_stg`.tmp_fu_stg e on a.sbscrptn_ek_id = e.sbscrptn_ek_id
 where a.tag = 'rgu90_gross_churn' and a.dt = vdt_id;





create or replace table `data-bi-prd-935c.bi_stg`.tmp_gc_attribs_rolling90 as
 select distinct vdt_id as mth, sbscrptn_ek_id, site_id
 from 
 (
  select a.sbscrptn_ek_id, site_id_90 as site_id, row_number () over (partition by a.sbscrptn_ek_id order by a.dt desc) rown
  from `data-bi-prd-935c.bi_mart`.ioh_subscriber_site_attribs_rolling a
  join `data-bi-prd-935c.bi_stg`.tmp_gc_aon_rev b on a.sbscrptn_ek_id = b.sbscrptn_ek_id and b.dt = vdt_id
  where a.dt = b.dt - interval 90 day
 ) x where rown = 1;




 delete from `data-bi-prd-935c.bi_mart`.fct_gc_aon_rev_2 a where a.dt = vdt_id;


 insert into `data-bi-prd-935c.bi_mart`.fct_gc_aon_rev_2
 select a.*, b.site_id
 from `data-bi-prd-935c.bi_stg`.tmp_gc_aon_rev a
 left outer join `data-bi-prd-935c.bi_stg`.tmp_gc_attribs_rolling90 b on a.sbscrptn_ek_id = b.sbscrptn_ek_id and a.dt = b.mth
 where a.dt = vdt_id;




create or replace table `data-bi-prd-935c.bi_stg`.tmp_rev_gc as
 select mth, sbscrptn_ek_id, sum(rev_m1) as rev_m1, sum(rev_m2) as rev_m2, sum(rev_m3) as rev_m3
 from
 (
 select vdt_id as mth, a.sbscrptn_ek_id, sum(revenue) as rev_m1, 0 as rev_m2, 0 as rev_m3
 from `data-bi-prd-935c.bi_mart`.fct_cwn_rev_detail_fnl a
 join 
 (
  select distinct dt, sbscrptn_ek_id
  from `data-bi-prd-935c.bi_mart`.fct_ioh_rgu_NIK_movement
  where tag = 'rgu90_gross_churn' and dt = vdt_id
 ) b on a.sbscrptn_ek_id = b.sbscrptn_ek_id
 where trx_dt_sk_id between b.dt - interval 119 day and b.dt - interval 90 day
 group by 1,2

 union distinct

 select vdt_id as mth, a.sbscrptn_ek_id, 0 as rev_m1, sum(revenue) as rev_m2, 0 as rev_m3
 from `data-bi-prd-935c.bi_mart`.fct_cwn_rev_detail_fnl a
 join 
 (
  select distinct dt, sbscrptn_ek_id
  from `data-bi-prd-935c.bi_mart`.fct_ioh_rgu_NIK_movement
  where tag = 'rgu90_gross_churn' and dt = vdt_id
 ) b on a.sbscrptn_ek_id = b.sbscrptn_ek_id
 where trx_dt_sk_id between b.dt - interval 149 day
 and  b.dt - interval 120 day
 group by 1,2

 union distinct

 select vdt_id as mth, a.sbscrptn_ek_id, 0 as rev_m1, 0 as rev_m2, sum(revenue) as rev_m3
 from `data-bi-prd-935c.bi_mart`.fct_cwn_rev_detail_fnl a
 join 
 (
  select distinct dt, sbscrptn_ek_id
  from `data-bi-prd-935c.bi_mart`.fct_ioh_rgu_NIK_movement
  where tag = 'rgu90_gross_churn' and dt = vdt_id
 ) b on a.sbscrptn_ek_id = b.sbscrptn_ek_id
 where trx_dt_sk_id between (b.dt - interval 179 day)
 and b.dt - interval 150 day
 group by 1,2
 ) a
 group by 1,2;


 
 delete from `data-bi-prd-935c.bi_mart`.fct_gc_aon_rev_3 where dt = vdt_id;


 insert into `data-bi-prd-935c.bi_mart`.fct_gc_aon_rev_3
 select a.*,
 case when (rev_m1 + rev_m2 + rev_m3) = 0 then (rev_m1 + rev_m2 + rev_m3)
 else (rev_m1 + rev_m2 + rev_m3)/(cnt_m1 + cnt_m2 + cnt_m3) end as churn_arpu
 from
 (
  select a.*,
  cast(coalesce(b.rev_m1,0) as numeric) as rev_m1,
  cast(coalesce(b.rev_m2,0) as numeric) as rev_m2,
  cast(coalesce(b.rev_m3,0) as numeric) as rev_m3,
  case when coalesce(b.rev_m1,0) = 0 then 0 else 1 end as cnt_m1,
  case when coalesce(b.rev_m2,0) = 0 then 0 else 1 end as cnt_m2,
  case when coalesce(b.rev_m3,0) = 0 then 0 else 1 end as cnt_m3
  from `data-bi-prd-935c.bi_mart`.fct_gc_aon_rev_2 a
  left outer join `data-bi-prd-935c.bi_stg`.tmp_rev_gc b on a.sbscrptn_ek_id = b.sbscrptn_ek_id and a.dt = b.mth
  where a.dt = vdt_id
 ) a;





 create or replace table `data-bi-prd-935c.bi_stg`.tmp_cb_favloc as
 select distinct dt, sbscrptn_ek_id, site_id_90 as site_id
 from `data-bi-prd-935c.bi_mart`.ioh_subscriber_site_attribs_rolling
 where dt = vdt_id;




 delete from `data-bi-prd-935c.bi_mart`.fct_cb_aon_rev where dt = vdt_id;
 insert into `data-bi-prd-935c.bi_mart`.fct_cb_aon_rev
 select distinct a.dt, 'RGU90_Churn_Back' as tag,
 a.sbscrptn_ek_id,
 f.site_id,
 case when ga_dt is not null then
  case
      when date_diff(a.dt,ga_dt,day) >= 0 and date_diff(a.dt,ga_dt,day) <= 29 then 'a.<=30D'
	  when date_diff(a.dt,ga_dt,day) >= 30 and date_diff(a.dt,ga_dt,day) <= 59 then 'b.<=60D'
	  when date_diff(a.dt,ga_dt,day) >= 60 and date_diff(a.dt,ga_dt,day) <= 89 then 'c.<=90D'
	  when date_diff(a.dt,ga_dt,day) >= 90 and date_diff(a.dt,ga_dt,day) <= 119 then 'd.<=120D'
	  when date_diff(a.dt,ga_dt,day) >= 120 and date_diff(a.dt,ga_dt,day) <= 179 then 'e.<=180D'
	  when date_diff(a.dt,ga_dt,day) >= 180  then 'f.>180D'
  else 'f.>180D' end 
 else
 case
      when date_diff(a.dt,fu_dt,day) >= 0 and date_diff(a.dt,fu_dt,day) <= 29 then 'a.<=30D'
	  when date_diff(a.dt,fu_dt,day) >= 30 and date_diff(a.dt,fu_dt,day) <= 59 then 'b.<=60D'
	  when date_diff(a.dt,fu_dt,day) >= 60 and date_diff(a.dt,fu_dt,day) <= 89 then 'c.<=90D'
	  when date_diff(a.dt,fu_dt,day) >= 90 and date_diff(a.dt,fu_dt,day) <= 119 then 'd.<=120D'
	  when date_diff(a.dt,fu_dt,day) >= 120 and date_diff(a.dt,fu_dt,day) <= 179 then 'e.<=180D'
	  when date_diff(a.dt,fu_dt,day) >= 180  then 'f.>180D'
  else 'f.>180D' end
  end as AON_slab,
 coalesce(ga_dt, fu_dt) as ga_fu_dt
 from `data-bi-prd-935c.bi_mart`.fct_ioh_rgu_NIK_movement a
 left outer join `data-bi-prd-935c.bi_stg`.tmp_ga_stg d on a.sbscrptn_ek_id = d.sbscrptn_ek_id
 left outer join `data-bi-prd-935c.bi_stg`.tmp_fu_stg e on a.sbscrptn_ek_id = e.sbscrptn_ek_id
 left outer join `data-bi-prd-935c.bi_stg`.tmp_cb_favloc f on a.sbscrptn_ek_id = f.sbscrptn_ek_id and a.dt = f.dt
 where a.tag = 'rgu90_churn_back' and a.dt = vdt_id;
                                                                                                                                       

