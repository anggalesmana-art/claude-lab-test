declare vdt_id date default @vdt_id;

delete from `data-bi-prd-935c.bi_mart`.ref_lacci_dly where dt_id = vdt_id;
insert into `data-bi-prd-935c.bi_mart`.ref_lacci_dly
select coalesce(b.lac_dec,a.lac) lac, coalesce(b.ci_dec,a.ci) ci, coalesce(b.site_id,a.site_id) site_id, vdt_id dt_id
from
(
  select lac_dec lac, ci_dec ci, site_id
    , row_number() over(partition by lac_dec, ci_dec
      order by dt_id desc
        , safe.parse_timestamp('%m/%d/%Y %H:%M',tgl_update) desc nulls last -- in BQ null < any value
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
  from `data-dtp-prd-aa1a.stg.data_lacci_com` -- lacci daily
  where date(dt_id) between date(vdt_id - interval 29 day) and vdt_id
) a
full join `data-dtp-prd-aa1a.sor.ref_data_lacci_com_bi` b
  on a.lac=b.lac_dec and a.ci=b.ci_dec 
where rk=1
;