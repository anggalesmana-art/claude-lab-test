--Migrate Query by Indra Maulana Ikhsan 20241120
/*
  create or replace table `data-bi-prd-935c.bi_mart`.rgs_all_nogovt_dly
  (
    msisdn string,
    actvn_dt string,
    flag string,
    usg_flag string,
    max_dt string,
    min_dt_90 string,
    min_dt_30 string,
    rev_90 double,
    rev_30 double,
    svc_class_code string,
    site_id_90 string,
    site_id_30 string,
    ppn_dttm timestamp
  )
  partitioned by (dt_id string)

  ;
*/
declare vdt_id date default @vdt_id;
--- Populate 90 days (A)
create or replace table `data-bi-prd-935c.bi_mart`.tmp_rgs_90d_nogovt_{{ vdt_id }} as
(
  select a.msisdn msisdn
    , max(actvn_dt) actvn_dt, max(a.dt_id) max_dt, min(a.dt_id) min_dt
    , sum(coalesce(total_rev,0)) total_rev
    , max(case when max_dt=a.dt_id then a.svc_class_code end) svc_class_code
    --, max(svc_class_code) svc_class_code
    , 'A' flag
  from (
    select msisdn, actvn_dt, dt_id, total_rev, svc_class_code, max(dt_id) over (partition by msisdn) as max_dt
    from `data-bi-prd-935c.bi_mart`.rgs_nogovt_dly
    where dt_id between vdt_id - interval 89 day and  vdt_id
      and (flag_status='Active 2' or coalesce(total_rev,0)>0)
      and flag_y4='NO'
  ) a
  group by a.msisdn
);


--- Populate GA 90 days (B)
create or replace table `data-bi-prd-935c.bi_mart`.tmp_rgs_90d_ga_nogovt_{{ vdt_id }} as
(
  select a.msisdn, a.flag, b.usg_flag
  from (
    select a.msisdn, 'B' flag
    from `data-bi-prd-935c.bi_mart`.tmp_rgs_90d_nogovt_{{ vdt_id }} a
    left join (
      select msisdn from `data-bi-prd-935c.bi_mart`.rgs_all_nogovt_dly
      where dt_id = date(vdt_id - interval 1 day)
        and flag like '%A%'
    ) b
      on a.msisdn=b.msisdn
    where b.msisdn is null
  ) a
  left join (
    select msisdn, usg_flag
    from `data-bi-prd-935c.bi_mart`.rgs_nogovt_dly
    where dt_id = vdt_id
  ) b
    on a.msisdn=b.msisdn
);


--- Populate Churn 90 days (C)
create or replace table `data-bi-prd-935c.bi_mart`.tmp_rgs_90d_churn_nogovt_{{ vdt_id }} as
(
  select a.msisdn, 'C' flag, a.actvn_dt, a.max_dt, a.svc_class_code, a.site_id_90
  from (
    select * from `data-bi-prd-935c.bi_mart`.rgs_all_nogovt_dly
    where dt_id = date(vdt_id - interval 1 day)
      and flag like '%A%'
  ) a
  left join `data-bi-prd-935c.bi_mart`.tmp_rgs_90d_nogovt_{{ vdt_id }} b
    on a.msisdn=b.msisdn
  where b.msisdn is null
);


--- Populate All 90 days
create or replace table `data-bi-prd-935c.bi_mart`.tmp_rgs_90d_all_nogovt_{{ vdt_id }} as
(
  select a.msisdn msisdn, actvn_dt, max_dt, min_dt, total_rev, svc_class_code
    , concat(coalesce(a.flag,''),coalesce(b.flag,'')) flag
    , b.usg_flag usg_flag
    , NULL site_id_90
  from `data-bi-prd-935c.bi_mart`.tmp_rgs_90d_nogovt_{{ vdt_id }} a -- 90 Base
  left join `data-bi-prd-935c.bi_mart`.tmp_rgs_90d_ga_nogovt_{{ vdt_id }} b -- 90 GA
    on a.msisdn=b.msisdn
  union all
  select msisdn, actvn_dt, max_dt, NULL min_dt, NULL total_rev, svc_class_code, flag, NULL usg_flag, site_id_90
  from `data-bi-prd-935c.bi_mart`.tmp_rgs_90d_churn_nogovt_{{ vdt_id }} -- 90 Churn
);


--- Populate RGS 30 days (K)
create or replace table `data-bi-prd-935c.bi_mart`.tmp_rgs_30d_nogovt_{{ vdt_id }} as
(
  select a.msisdn msisdn, min(a.dt_id) min_dt
    , sum(coalesce(total_rev,0)) total_rev
    , 'K' flag
  from `data-bi-prd-935c.bi_mart`.rgs_nogovt_dly a
  where a.dt_id between vdt_id - interval 29 day and vdt_id
    and (flag_status='Active 2' or coalesce(total_rev,0)>0)
    and flag_y4='NO'
  group by a.msisdn
);


--- Populate GA 30 days (L)
create or replace table `data-bi-prd-935c.bi_mart`.tmp_rgs_30d_ga_nogovt_{{ vdt_id }} as
(
  select a.msisdn, a.flag, b.usg_flag
  from (
    select a.msisdn, 'L' flag
    from `data-bi-prd-935c.bi_mart`.tmp_rgs_30d_nogovt_{{ vdt_id }} a
    left join (
      select msisdn from `data-bi-prd-935c.bi_mart`.rgs_all_nogovt_dly
      where dt_id = date(vdt_id - interval 1 day)
        and flag like '%K%'
    ) b
      on a.msisdn=b.msisdn
    where b.msisdn is null
  ) a
  left join (
    select msisdn, usg_flag
    from `data-bi-prd-935c.bi_mart`.rgs_nogovt_dly
    where dt_id = vdt_id
  ) b
    on a.msisdn=b.msisdn
);


--- Populate Churn 30 days (M)
create or replace table `data-bi-prd-935c.bi_mart`.tmp_rgs_30d_churn_nogovt_{{ vdt_id }} as
(
  select a.msisdn, 'M' flag
    --, a.actvn_dt, a.max_dt, a.svc_class_code
    , a.site_id_30
  from (
    select * from `data-bi-prd-935c.bi_mart`.rgs_all_nogovt_dly
    where dt_id = date(vdt_id - interval 1 day)
      and flag like '%K%'
  ) a
  left join `data-bi-prd-935c.bi_mart`.tmp_rgs_30d_nogovt_{{ vdt_id }} b
    on a.msisdn=b.msisdn
  where b.msisdn is null
);


--- Populate All 30 days
create or replace table `data-bi-prd-935c.bi_mart`.tmp_rgs_30d_all_nogovt_{{ vdt_id }} as
(
  select a.msisdn msisdn, min_dt, total_rev
    , concat(coalesce(a.flag,''),coalesce(b.flag,'')) flag
    , b.usg_flag, NULL site_id_30
  from `data-bi-prd-935c.bi_mart`.tmp_rgs_30d_nogovt_{{ vdt_id }} a -- 30 Base
  left join `data-bi-prd-935c.bi_mart`.tmp_rgs_30d_ga_nogovt_{{ vdt_id }} b -- 30 GA
    on a.msisdn=b.msisdn
  union all
  select msisdn, NULL min_dt, NULL total_rev, flag, NULL usg_flag, site_id_30
  from `data-bi-prd-935c.bi_mart`.tmp_rgs_30d_churn_nogovt_{{ vdt_id }} -- 30 Churn
);

--- insert to master table
delete from `data-bi-prd-935c.bi_mart`.rgs_all_nogovt_dly where dt_id = vdt_id;
insert into  `data-bi-prd-935c.bi_mart`.rgs_all_nogovt_dly 
select a.msisdn msisdn
  , a.actvn_dt actvn_dt
  , concat(coalesce(a.flag,''),coalesce(b.flag,'')) flag
  , coalesce(a.usg_flag, b.usg_flag) usg_flag
  , a.max_dt max_dt
  , a.min_dt min_dt_90, b.min_dt min_dt_30
  , coalesce(a.total_rev,0) rev_90, coalesce(b.total_rev,0) rev_30
  , a.svc_class_code svc_class_code
  , a.site_id_90, b.site_id_30
  , timestamp(current_datetime('+7')) ppn_dttm
  , vdt_id dt_id
from `data-bi-prd-935c.bi_mart`.tmp_rgs_90d_all_nogovt_{{ vdt_id }} a -- 90 Base GA
left join `data-bi-prd-935c.bi_mart`.tmp_rgs_30d_all_nogovt_{{ vdt_id }} b -- 30 Base GA Churn
  on a.msisdn=b.msisdn
;


drop table if exists `data-bi-prd-935c.bi_mart`.tmp_rgs_90d_nogovt_{{ vdt_id }};
drop table if exists `data-bi-prd-935c.bi_mart`.tmp_rgs_90d_ga_nogovt_{{ vdt_id }};
drop table if exists `data-bi-prd-935c.bi_mart`.tmp_rgs_90d_churn_nogovt_{{ vdt_id }};
drop table if exists `data-bi-prd-935c.bi_mart`.tmp_rgs_90d_all_nogovt_{{ vdt_id }};
drop table if exists `data-bi-prd-935c.bi_mart`.tmp_rgs_30d_nogovt_{{ vdt_id }};
drop table if exists `data-bi-prd-935c.bi_mart`.tmp_rgs_30d_ga_nogovt_{{ vdt_id }};
drop table if exists `data-bi-prd-935c.bi_mart`.tmp_rgs_30d_churn_nogovt_{{ vdt_id }};
drop table if exists `data-bi-prd-935c.bi_mart`.tmp_rgs_30d_all_nogovt_{{ vdt_id }};