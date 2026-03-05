declare vdt_id date default @vdt_id;

--- mobo
create or replace table `data-bi-prd-935c.bi_stg`.tmp_favloc_90d_mobo_{{ vdt_id }} as
select msisdn, concat(lac,'-',ci) lacci, site_id, "5. MOBO" priority
from (
  select msisdn, lac, ci, site_id, row_number() over (partition by msisdn order by amount_debit desc) as idx
  from (
    select msisdn, a.lac, a.ci, b.site_id, sum(amount_debit) amount_debit
    from `data-bi-prd-935c.bi_mart`.mobo_lacci_dly a
    inner join (
      select lac, ci, site_id
      from `data-bi-prd-935c.bi_mart`.ref_lacci_dly
      where dt_id = vdt_id
    ) b
      on a.lac=b.lac and a.ci=b.ci
    where date(dt_id) >= vdt_id - interval 89 day and date(dt_id) <= vdt_id
    group by msisdn, a.lac, a.ci, b.site_id
  ) a
) a
where idx = 1
;
