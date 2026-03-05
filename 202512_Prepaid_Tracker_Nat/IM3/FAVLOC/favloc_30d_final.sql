declare vdt_id date default @vdt_id;

--- final
delete from `data-bi-prd-935c.bi_mart`.favloc_30d_dly  where dt_id = vdt_id;
insert into `data-bi-prd-935c.bi_mart`.favloc_30d_dly 
select msisdn, lacci, site_id, coalesce(priority, "7. Not Captured") as priority, current_timestamp() ppn_dttm, vdt_id dt_id
from (
  select a.*, row_number() over (partition by a.msisdn order by priority) as idx
  from (
    select * from `data-bi-prd-935c.bi_stg`.tmp_favloc_30d_ggsn_{{ vdt_id }}
    union all
    select * from `data-bi-prd-935c.bi_stg`.tmp_favloc_30d_voice_{{ vdt_id }}
    union all
    select * from `data-bi-prd-935c.bi_stg`.tmp_favloc_30d_sms_{{ vdt_id }}
    union all
    select * from `data-bi-prd-935c.bi_stg`.tmp_favloc_30d_recharge_{{ vdt_id }}
    union all
    select * from `data-bi-prd-935c.bi_stg`.tmp_favloc_30d_mobo_{{ vdt_id }}
    union all
    select * from `data-bi-prd-935c.bi_stg`.tmp_favloc_30d_vlr_{{ vdt_id }}
  ) a
) a
where idx=1
;


--- drop temp table
drop table if exists `data-bi-prd-935c.bi_stg`.tmp_favloc_30d_ggsn_{{ vdt_id }};
drop table if exists `data-bi-prd-935c.bi_stg`.tmp_favloc_30d_voice_{{ vdt_id }};
drop table if exists `data-bi-prd-935c.bi_stg`.tmp_favloc_30d_sms_{{ vdt_id }};
drop table if exists `data-bi-prd-935c.bi_stg`.tmp_favloc_30d_recharge_{{ vdt_id }};
drop table if exists `data-bi-prd-935c.bi_stg`.tmp_favloc_30d_mobo_{{ vdt_id }};
drop table if exists `data-bi-prd-935c.bi_stg`.tmp_favloc_30d_vlr_{{ vdt_id }};
