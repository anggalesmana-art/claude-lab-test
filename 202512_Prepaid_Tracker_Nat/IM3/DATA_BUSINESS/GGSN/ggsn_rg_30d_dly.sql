--GGSN 30D
declare vdt_id date default @vdt_id;
delete from `data-bi-prd-935c.bi_mart`.ggsn_rg_dly_smy where kpi = 'SUBS 30D' and dt_id = vdt_id;
insert into `data-bi-prd-935c.bi_mart`.ggsn_rg_dly_smy
select 'SUBS 30D' kpi
  , b.subs_flag
  , case
    when vol_4g>0 then '4G'
    when vol_3g>0 then '3G'
    else '2G'
  end technology
  , count(distinct a.msisdn) subs
  , timestamp(current_datetime('+7')) ppn_dttm
  ,vdt_id dt_id
from
(
  select msisdn, sum(vol_2g) vol_2g, sum(vol_3g) vol_3g, sum(vol_4g) vol_4g
  from `data-bi-prd-935c.bi_mart`.ggsn_rg_dly
  where dt_id between vdt_id - interval 29 day and vdt_id
    and rating_group not in ('23111', '55003', '70091')
    and substring(msisdn,1,5) in ('62814','62815','62816','62855','62856','62857','62858')
  group by 1
) a
left join
(
  select msisdn, subs_flag
  from
  (
    select msisdn, subs_flag, row_number() over(partition by msisdn order by dt_id desc
        , case
          when subs_flag='Postpaid B2B' then 1
          when subs_flag='Postpaid B2C' then 2
          when subs_flag='Prepaid B2B' then 3
          when subs_flag='Prepaid B2C' then 4
          else 5
        end
      ) rk
    from `data-bi-prd-935c.bi_mart`.ggsn_rg_dly
    where dt_id between vdt_id - interval 29 day and vdt_id
      and rating_group not in ('23111', '55003', '70091')
      and substring(msisdn,1,5) in ('62814','62815','62816','62855','62856','62857','62858')
  ) a
  where rk=1
) b
  on a.msisdn=b.msisdn
group by subs_flag, technology
;