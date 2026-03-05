declare vdt_id date default @vdt_id;

--- SGE 30
delete from `data-bi-prd-935c.bi_mart`.kpi_dly_smy where dt_id = vdt_id
and kpi_nm = 'SGE 30D';
insert into `data-bi-prd-935c.bi_mart`.kpi_dly_smy 
select 'SGE 30D' kpi_nm
  , subs_flag
  , cast(NULL as string) tenure
  , count(distinct msisdn) subs
  , timestamp(current_datetime('+7')) ppn_dttm
  , vdt_id dt_id
from
(
  select msisdn, subs_flag, row_number() over(partition by msisdn order by dt_id desc
      , case
        when subs_flag='Postpaid B2B' then 1
        when subs_flag='Postpaid B2C' then 2
        when subs_flag='Prepaid B2B' then 3
        when subs_flag='Prepaid B2C' then 4
        when subs_flag='Propaid' then 5
        when subs_flag='Postpaid' then 6
        when subs_flag='Prepaid' then 7
        else 8
      end
    ) rk
  from `data-bi-prd-935c.bi_mart`.sge_dly
  where dt_id between vdt_id - interval 29 day and vdt_id
) a
where rk=1
group by 1,2,3;