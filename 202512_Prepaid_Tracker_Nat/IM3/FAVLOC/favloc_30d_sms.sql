declare vdt_id date default @vdt_id;

--- sms
create or replace table `data-bi-prd-935c.bi_stg`.tmp_favloc_30d_sms_{{ vdt_id }} as
select msisdn, concat(lac,'-',ci) lacci, site_id, "3. SMS" priority
from (
  select msisdn, lac, ci, site_id, row_number() over (partition by msisdn order by tot_hits desc) as idx
  from (
    select msisdn, a.lac, a.ci, b.site_id, sum(hits) tot_hits
    from `data-bi-prd-935c.bi_mart`.sms_lacci_dly a
    inner join (
      select lac, ci, site_id
      from `data-bi-prd-935c.bi_mart`.ref_lacci_dly
      where date(dt_id) = vdt_id
    ) b
      on a.lac=b.lac and a.ci=b.ci
    where date(dt_id) >= vdt_id - interval 29 day and date(dt_id) <= vdt_id
    group by msisdn, a.lac, a.ci, b.site_id
  ) a
) a
where idx = 1
;
