declare vdt_id date default @vdt_id;

--- reference
create or replace table `data-bi-prd-935c.bi_stg`.tmp_favloc_dly_ref_lacci_{{ vdt_id }} as
select coalesce(b.lac_dec,a.lac) lac, coalesce(b.ci_dec,a.ci) ci, coalesce(b.site_id,a.site_id) site_id
from
(
  select lac_dec lac, ci_dec ci, site_id
    , row_number() over(partition by lac_dec, ci_dec
      order by dt_id desc
        , safe.parse_timestamp('%m/%d/%Y %H:%M',tgl_update) desc nulls last
        , case when bts_status ='ACTIVE' then 1 when bts_status='PLANNED' then 2 when bts_status='NOT ACTIVE' then 3 else 4 end
        , case
          when lower(cell_coverage_type) like '%macro%' then '1.MACRO'
          when lower(cell_coverage_type) like '%ibs%' then '2.IBS'
          when lower(cell_coverage_type) like '%micro%' then '3.MICRO'
          when lower(cell_coverage_type) like '%pico%' then '4.PICO'
          when lower(cell_coverage_type) like '%rural%' then '5.RURAL'
          when lower(cell_coverage_type) like '%sub%urban%' then '6.SUB URBAN'
          when lower(cell_coverage_type) like '%urban%' then '7.URBAN'
          else 'h.OTHERS'
        end
    ) rk
  from `data-dtp-prd-aa1a.stg`.data_lacci_com
  where date(dt_id) >= vdt_id - interval 29 day and date(dt_id) <= vdt_id
) a
full join `data-dtp-prd-aa1a.sor`.ref_data_lacci_com_bi b
  on a.lac=b.lac_dec and a.ci=b.ci_dec
where rk=1
;


--- ggsn
create or replace table `data-bi-prd-935c.bi_stg`.tmp_favloc_dly_ggsn_{{ vdt_id }}  as
select msisdn, concat(lac,'-',ci) lacci, site_id, "1. GGSN" priority
from (
    select msisdn, lac, ci, site_id, row_number() over (partition by msisdn order by tot_volume desc) as idx
    from (
      select msisdn, a.lac, a.ci, b.site_id, sum(volume) tot_volume
      from `data-bi-prd-935c.bi_mart`.ggsn_lacci_dly a
      inner join `data-bi-prd-935c.bi_stg`.tmp_favloc_dly_ref_lacci_{{ vdt_id }} b
        on a.lac=b.lac and a.ci=b.ci
      where date(dt_id) = vdt_id
      group by msisdn, a.lac, a.ci, b.site_id
    ) a
) a
where idx = 1
;


--- voice
create or replace table `data-bi-prd-935c.bi_stg`.tmp_favloc_dly_voice_{{ vdt_id }}  as
select msisdn, concat(lac,'-',ci) lacci, site_id, "2. Voice" priority
from (
    select msisdn, lac, ci, site_id, row_number() over (partition by msisdn order by tot_hits desc, tot_duration desc) as idx
    from (
      select msisdn, a.lac, a.ci, b.site_id, sum(hits) tot_hits, sum(duration) tot_duration
      from `data-bi-prd-935c.bi_mart`.voice_lacci_dly a
      inner join `data-bi-prd-935c.bi_stg`.tmp_favloc_dly_ref_lacci_{{ vdt_id }} b
        on a.lac=b.lac and a.ci=b.ci
      where date(dt_id) = vdt_id
      group by msisdn, a.lac, a.ci, b.site_id
    ) a
) a
where idx = 1
;


--- sms
create or replace table `data-bi-prd-935c.bi_stg`.tmp_favloc_dly_sms_{{ vdt_id }}  as
select msisdn, concat(lac,'-',ci) lacci, site_id, "3. SMS" priority
from (
    select msisdn, lac, ci, site_id, row_number() over (partition by msisdn order by tot_hits desc) as idx
    from (
        select msisdn, a.lac, a.ci, b.site_id, sum(hits) tot_hits
        from `data-bi-prd-935c.bi_mart`.sms_lacci_dly a
        inner join `data-bi-prd-935c.bi_stg`.tmp_favloc_dly_ref_lacci_{{ vdt_id }} b
          on a.lac=b.lac and a.ci=b.ci
        where date(dt_id) = vdt_id
        group by msisdn, a.lac, a.ci, b.site_id
    ) a
) a
where idx = 1
;


--- recharge
create or replace table `data-bi-prd-935c.bi_stg`.tmp_favloc_dly_recharge_{{ vdt_id }}  as
select msisdn, concat(lac,'-',ci) lacci, site_id, "4. Recharge" priority
from (
    select msisdn, lac, ci, site_id, row_number() over (partition by msisdn order by rld_amt desc) as idx
    from (
        select msisdn, a.lac, a.ci, b.site_id, sum(rld_amt) rld_amt
        from `data-bi-prd-935c.bi_mart`.recharge_lacci_dly a
        inner join `data-bi-prd-935c.bi_stg`.tmp_favloc_dly_ref_lacci_{{ vdt_id }} b
          on a.lac=b.lac and a.ci=b.ci
        where date(dt_id) = vdt_id
        group by msisdn, a.lac, a.ci, b.site_id
    ) a
) a
where idx = 1
;


--- mobo
create or replace table `data-bi-prd-935c.bi_stg`.tmp_favloc_dly_mobo_{{ vdt_id }}  as
select msisdn, concat(lac,'-',ci) lacci, site_id, "5. MOBO" priority
from (
    select msisdn, lac, ci, site_id, row_number() over (partition by msisdn order by amount_debit desc) as idx
    from (
        select msisdn, a.lac, a.ci, b.site_id, sum(amount_debit) amount_debit
        from `data-bi-prd-935c.bi_mart`.mobo_lacci_dly a
        inner join `data-bi-prd-935c.bi_stg`.tmp_favloc_dly_ref_lacci_{{ vdt_id }} b
          on a.lac=b.lac and a.ci=b.ci
        where date(dt_id) = vdt_id
        group by msisdn, a.lac, a.ci, b.site_id
    ) a
) a
where idx = 1
;


--- vlr
create or replace table `data-bi-prd-935c.bi_stg`.tmp_favloc_dly_vlr_{{ vdt_id }}  as
select msisdn, concat(lac,'-',ci) lacci, site_id, "6. VLR" priority
from (
    select msisdn, lac, ci, site_id, row_number() over (partition by msisdn order by dt_id desc) as idx
    from `data-bi-prd-935c.bi_dm`.vlr_site_wise
    where date(dt_id) = vdt_id and coalesce(site_id,'')!=''
) a
where idx = 1
;


--- final
delete from `data-bi-prd-935c.bi_mart`.max_fav_loc_dly where dt_id = vdt_id;
insert into `data-bi-prd-935c.bi_mart`.max_fav_loc_dly
select msisdn, lacci, site_id, coalesce(priority, "7. Not Captured") as priority, cast(current_timestamp() as string) ppn_dttm, vdt_id dt_id
from (
  select a.*, row_number() over (partition by a.msisdn order by priority) as idx
  from (
    select * from `data-bi-prd-935c.bi_stg`.tmp_favloc_dly_ggsn_{{ vdt_id }}
    union all
    select * from `data-bi-prd-935c.bi_stg`.tmp_favloc_dly_voice_{{ vdt_id }}
    union all
    select * from `data-bi-prd-935c.bi_stg`.tmp_favloc_dly_sms_{{ vdt_id }}
    union all
    select * from `data-bi-prd-935c.bi_stg`.tmp_favloc_dly_recharge_{{ vdt_id }}
    union all
    select * from `data-bi-prd-935c.bi_stg`.tmp_favloc_dly_mobo_{{ vdt_id }}
    union all
    select * from `data-bi-prd-935c.bi_stg`.tmp_favloc_dly_vlr_{{ vdt_id }}
  ) a
) a
where idx=1
;

--- drop temp table
drop table `data-bi-prd-935c.bi_stg`.tmp_favloc_dly_ref_lacci_{{ vdt_id }};
drop table `data-bi-prd-935c.bi_stg`.tmp_favloc_dly_ggsn_{{ vdt_id }};
drop table `data-bi-prd-935c.bi_stg`.tmp_favloc_dly_voice_{{ vdt_id }};
drop table `data-bi-prd-935c.bi_stg`.tmp_favloc_dly_sms_{{ vdt_id }};
drop table `data-bi-prd-935c.bi_stg`.tmp_favloc_dly_recharge_{{ vdt_id }};
drop table `data-bi-prd-935c.bi_stg`.tmp_favloc_dly_mobo_{{ vdt_id }};
drop table `data-bi-prd-935c.bi_stg`.tmp_favloc_dly_vlr_{{ vdt_id }};
