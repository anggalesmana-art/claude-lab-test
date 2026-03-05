declare vdt_id date default @vdt_id;

--- vlr
create or replace table `data-bi-prd-935c.bi_mart`.tmp_favloc_30d_vlr_vdt_id as
select msisdn, concat(lac,'-',ci) lacci, site_id, "6. VLR" priority
from (
  select msisdn, lac, ci, site_id, row_number() over (partition by msisdn order by dt_id desc) as idx
  from `data-bi-prd-935c.bi_dm`.vlr_site_wise
  where date(dt_id) >= vdt_id - interval 29 day and date(dt_id) <= vdt_id
) a
where idx = 1
;

