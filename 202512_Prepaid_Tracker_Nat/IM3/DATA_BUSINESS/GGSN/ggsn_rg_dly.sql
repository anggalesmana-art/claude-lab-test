declare vdt_id date default @vdt_id;
--- Temp GGSN RG Daily
create or replace table `data-bi-prd-935c.bi_mart.tmp_ggsn_rg_{{ vdt_id }}` as
select msisdn, rating_group
  , sum(case when rat_type not in ('1','6') then (volume_downlink+volume_uplink) else 0 end) vol_2g
  , sum(case when rat_type = '1' then (volume_downlink+volume_uplink) else 0 end) vol_3g
  , sum(case when rat_type = '6' then (volume_downlink+volume_uplink) else 0 end) vol_4g
  , date(recordopeningtime) as dt_id
from  `data-dtp-prd-aa1a.smy`.ggsn_hourly_summary
where date(recordopeningtime) = vdt_id
and (volume_downlink+volume_uplink) > 0
group by msisdn, rating_group, dt_id
;

-- - priority
-- 1. Postpaid B2B
-- 2. Postpaid B2C
-- 3. Prepaid B2B
-- 4. Prepaid B2C


--- subs flag
create or replace table `data-bi-prd-935c.bi_mart.tmp_subs_flag_{{ vdt_id }}` as
select msisdn, subs_flag
from
(
  select msisdn, subs_flag, row_number() over(partition by msisdn order by subs_flag) as rk
  from
  (
    select distinct msisdn, '2. Postpaid B2C' subs_flag
    from `data-dtp-prd-aa1a.smy`.ar_cst_pstpaid_rtl
    where date(dt_id)=vdt_id
    union all
    select distinct msisdn, '3. Prepaid B2B' subs_flag
    from `data-dtp-prd-aa1a.smy`.ar_cst_dly_smy
    where date(dt_id)=vdt_id and svc_class_code in (select svc_class_code from `data-bi-prd-935c.bi_mart`.ref_sc_b2b)
    union all
    select regexp_replace(svc_id,'[^[:digit:]]','') msisdn, '1. Postpaid B2B' subs_flag
    from
    (
        select a.*, row_number() over(partition by regexp_replace(svc_id,'[^[:digit:]]','') order by case when ast_st='Active' then 1 when ast_st='Suspended' then 2 else 3 end) rk
        from `data-dtp-prd-aa1a.smy`.ar_cst_pstpaid_b2b a
        where date(dt_id)=vdt_id and pd_cgy='Mobile' and ifnull(a.svc_id,'')!=''
    ) x
    where rk=1
  ) x
) x
where rk=1
;


--- insert to master table
delete from  `data-bi-prd-935c.bi_mart`.ggsn_rg_dly where date(dt_id) = vdt_id;

insert into  `data-bi-prd-935c.bi_mart`.ggsn_rg_dly
select a.msisdn, a.rating_group, a.vol_2g, a.vol_3g, a.vol_4g
  , case when a.msisdn=b.msisdn then regexp_replace(b.subs_flag, substr(b.subs_flag,1,3), '')
    else 'Prepaid B2C' end subs_flag
  , timestamp(current_datetime('+7')) ppn_dttm
  , date(a.dt_id) dt_id
from `data-bi-prd-935c.bi_mart.tmp_ggsn_rg_{{ vdt_id }}` a
left join `data-bi-prd-935c.bi_mart.tmp_subs_flag_{{ vdt_id }}` b
  on a.msisdn=b.msisdn
;


--- summary
delete from  `data-bi-prd-935c.bi_mart`.ggsn_rg_dly_smy where date(dt_id) = vdt_id 
and kpi in ('SUBS DAILY', 'VOL GB DAILY');
insert into `data-bi-prd-935c.bi_mart`.ggsn_rg_dly_smy
with
temp as (
  select dt_id, msisdn, subs_flag, sum(vol_2g) vol_2g, sum(vol_3g) vol_3g, sum(vol_4g) vol_4g
  from `data-bi-prd-935c.bi_mart`.ggsn_rg_dly
  where dt_id = vdt_id
    and rating_group not in ('23111', '55003', '70091')
    and substring(msisdn,1,5) in ('62814','62815','62816','62855','62856','62857','62858')
  group by 1,2,3
)
(
  select 'SUBS DAILY' kpi
    , subs_flag
    , case
      when vol_4g>0 then '4G'
      when vol_3g>0 then '3G'
      else '2G'
    end tech
    , count(distinct msisdn) subs
    , timestamp(current_datetime('+7')) ppn_dttm
    , dt_id
  from temp
  GROUP BY subs_flag, tech, dt_id
  union all
  select 'VOL GB DAILY' kpi
    , subs_flag
    , case
      when vol_4g>0 then '4G'
      when vol_3g>0 then '3G'
      else '2G'
    end tech
    , sum(vol_2g+vol_3g+vol_4g)/1024/1024/1024 vol_gb
    , timestamp(current_datetime('+7')) ppn_dttm
    , dt_id
  from temp
  GROUP BY subs_flag, tech, dt_id
)
;


DROP TABLE IF EXISTS `data-bi-prd-935c.bi_mart.tmp_ggsn_rg_{{ vdt_id }}`;
DROP TABLE IF EXISTS `data-bi-prd-935c.bi_mart.tmp_subs_flag_{{ vdt_id }}`;