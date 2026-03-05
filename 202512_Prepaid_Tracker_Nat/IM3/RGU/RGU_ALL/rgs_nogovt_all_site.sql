declare vdt_id date default @vdt_id;
create or replace table `data-bi-prd-935c.bi_mart`.tmp_carry_fwd_favloc_60_{{ vdt_id }} as
select msisdn, site_id
from (
  select msisdn, site_id, row_number() over(partition by msisdn order by dt_id desc) rk
  from (
    select dt_id, msisdn, site_id
    from `data-dtp-prd-aa1a.sor`.subs_fav_loc_dly_carry_fwd
    where date(dt_id) IN (date(vdt_id - interval 60 day), date(vdt_id))
  ) x
)x
where rk=1;


create or replace table `data-bi-prd-935c.bi_mart`.tmp_carry_fwd_favloc_90_{{ vdt_id }} as
select msisdn, site_id site_id_90
from `data-bi-prd-935c.bi_mart`.all_90d_fav_loc_dly
where dt_id = vdt_id;

create or replace table `data-bi-prd-935c.bi_mart`.tmp_carry_fwd_favloc_30_{{ vdt_id }} as
select msisdn, site_id site_id_30
from `data-bi-prd-935c.bi_mart`.favloc_30d_dly
where dt_id = vdt_id;

--- union all
create or replace table `data-bi-prd-935c.bi_mart`.tmp_carry_fwd_favloc_60_90_30_{{ vdt_id }} as
with
fav_90_30 as (
  select distinct coalesce(a.msisdn,b.msisdn) msisdn
    , a.site_id_90, b.site_id_30
  from `data-bi-prd-935c.bi_mart`.tmp_carry_fwd_favloc_90_{{ vdt_id }} a
  full join `data-bi-prd-935c.bi_mart`.tmp_carry_fwd_favloc_30_{{ vdt_id }} b
    on a.msisdn=b.msisdn
)
select distinct coalesce(a.msisdn,b.msisdn) msisdn
  , coalesce(a.site_id_90, b.site_id) site_id_90
  , coalesce(a.site_id_30, b.site_id) site_id_30
from fav_90_30 a
full join `data-bi-prd-935c.bi_mart`.tmp_carry_fwd_favloc_60_{{ vdt_id }} b
  on a.msisdn=b.msisdn
;

--- rgu site
create or replace table `data-bi-prd-935c.bi_mart`.tmp_rgs_all_nogovt_dly_site_{{ vdt_id }} as
with
rgu_site as (
  select a.msisdn, actvn_dt, flag, usg_flag, max_dt, min_dt_90, min_dt_30, rev_90, rev_30, svc_class_code
    , case when flag like '%A%' then b.site_id_90 else NULL end site_id_90
    , case when flag like '%K%' then b.site_id_30 else NULL end site_id_30
    , ppn_dttm
    , a.dt_id
  from `data-bi-prd-935c.bi_mart`.rgs_all_nogovt_dly a
  left join `data-bi-prd-935c.bi_mart`.tmp_carry_fwd_favloc_60_90_30_{{ vdt_id }} b
    on a.msisdn=b.msisdn
  where a.dt_id = vdt_id
)
select a.msisdn, actvn_dt, flag, usg_flag, max_dt, min_dt_90, min_dt_30, rev_90, rev_30, svc_class_code
  , case
    when flag like '%C%' then b.site_id_90
    when flag not like '%C%' then a.site_id_90
    else NULL
  end site_id_90
  , case
    when flag like '%M%' then b.site_id_30
    when flag not like '%M%' then a.site_id_30
    else NULL
  end site_id_30
  , ppn_dttm
  , a.dt_id
from rgu_site a
left join (
  select msisdn, site_id_90, site_id_30
  from `data-bi-prd-935c.bi_mart`.rgs_all_nogovt_dly
  where dt_id = date_sub(vdt_id,interval 1 day )
) b
  on a.msisdn=b.msisdn
where a.dt_id=vdt_id
;

--- insert to master table
delete from `data-bi-prd-935c.bi_mart`.rgs_all_nogovt_dly  where dt_id = vdt_id;
insert into  `data-bi-prd-935c.bi_mart`.rgs_all_nogovt_dly 
select * from `data-bi-prd-935c.bi_mart`.tmp_rgs_all_nogovt_dly_site_{{ vdt_id }}
;


--- drop temp table
drop table if exists `data-bi-prd-935c.bi_mart`.tmp_carry_fwd_favloc_60_{{ vdt_id }};
drop table if exists `data-bi-prd-935c.bi_mart`.tmp_carry_fwd_favloc_60_90_30_{{ vdt_id }};
drop table if exists `data-bi-prd-935c.bi_mart`.tmp_rgs_all_nogovt_dly_site_{{ vdt_id }};
drop table if exists `data-bi-prd-935c.bi_mart`.tmp_carry_fwd_favloc_30_{{ vdt_id }};
drop table if exists `data-bi-prd-935c.bi_mart`.tmp_carry_fwd_favloc_90_{{ vdt_id }};