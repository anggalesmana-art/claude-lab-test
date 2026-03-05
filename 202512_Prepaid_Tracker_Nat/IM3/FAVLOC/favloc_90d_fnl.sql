declare vdt_id date default @vdt_id;

--- final
delete from `data-bi-prd-935c.bi_mart`.all_90d_fav_loc_dly where dt_id = vdt_id;
insert into `data-bi-prd-935c.bi_mart`.all_90d_fav_loc_dly
select msisdn, lacci, site_id, coalesce(priority, "7. Not Captured") as priority, timestamp(current_datetime('+7')) ppn_dttm, vdt_id dt_id
from (
  select a.*, row_number() over (partition by a.msisdn order by priority) as idx
  from (
    select * from `data-bi-prd-935c.bi_stg`.tmp_favloc_90d_ggsn_{{ vdt_id }}
    union all
    select * from `data-bi-prd-935c.bi_stg`.tmp_favloc_90d_voice_{{ vdt_id }}
    union all
    select * from `data-bi-prd-935c.bi_stg`.tmp_favloc_90d_sms_{{ vdt_id }}
    union all
    select * from `data-bi-prd-935c.bi_stg`.tmp_favloc_90d_recharge_{{ vdt_id }}
    union all
    select * from `data-bi-prd-935c.bi_stg`.tmp_favloc_90d_mobo_{{ vdt_id }}
    union all
    select * from `data-bi-prd-935c.bi_stg`.tmp_favloc_90d_vlr_{{ vdt_id }}
  ) a
) a
where idx=1
;


--- drop temp table
drop table if exists `data-bi-prd-935c.bi_stg`.tmp_favloc_90d_ggsn_{{ vdt_id }} ;
drop table if exists `data-bi-prd-935c.bi_stg`.tmp_favloc_90d_voice_{{ vdt_id }} ;
drop table if exists `data-bi-prd-935c.bi_stg`.tmp_favloc_90d_sms_{{ vdt_id }} ;
drop table if exists `data-bi-prd-935c.bi_stg`.tmp_favloc_90d_recharge_{{ vdt_id }} ;
drop table if exists `data-bi-prd-935c.bi_stg`.tmp_favloc_90d_mobo_{{ vdt_id }} ;
drop table if exists `data-bi-prd-935c.bi_stg`.tmp_favloc_90d_vlr_{{ vdt_id }} ;

