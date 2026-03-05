declare vdt_id date default @vdt_id;
delete from `data-bi-prd-935c.bi_mart`.kpi_national_tracker_dly where dt_id = vdt_id and brand = 'IM3' and kpi_id in (
'SUB0023',
'SUB0002',
'SUB0003',
'SUB0047',
'SUB0001'
);

insert into `data-bi-prd-935c.bi_mart`.kpi_national_tracker_dly
-- rgu_daily
select 'IM3' brand, 'rgu_daily' kpi_code, 'AVG' flag, count(1) metric, timestamp(current_datetime('+7')) process_dt, 'SUB0001' kpi_id, dt_id
from `data-bi-prd-935c.bi_mart`.rgs_nogovt_dly
where dt_id between vdt_id and vdt_id
  and (flag_status = 'Active 2' or coalesce(total_rev,0)>0)
group by dt_id
union all
-- sge_daily
select 'IM3' brand, 'sge_daily' kpi_code, 'AVG' flag, count(distinct msisdn) metric, timestamp(current_datetime('+7')) process_dt, 'SUB0002' kpi_id, dt_id
from `data-bi-prd-935c.bi_mart`.sge_dly
where dt_id between vdt_id and vdt_id
  and subs_flag like 'Prepaid%'
group by dt_id
union all
-- vlr_daily
select 'IM3' brand, 'vlr_daily' kpi_code, 'AVG' flag, sum(metric) metric, timestamp(current_datetime('+7')) process_dt, 'SUB0003' kpi_id, dt_id
from `data-bi-prd-935c.bi_mart`.vlr_activity_smy
where dt_id between vdt_id and vdt_id
    and kpi_nm='VLR_DAILY'
    and subs_flag like 'Prepaid%'
group by dt_id
union all
-- sge 90 and 30
select 'IM3' brand
  , case when kpi_nm='SGE 30D' then 'sge_30d' else 'sge_90d' end kpi_code
  , 'MTD' flag
  , sum(metric)
  , timestamp(current_datetime('+7')) process_dt
  , case when kpi_nm='SGE 30D' then 'SUB0047' else 'SUB0023' end kpi_id
  , dt_id
from (
    select *, row_number() over(partition by dt_id, kpi_nm, subs_flag order by ppn_dttm desc) as rk 
    from `data-bi-prd-935c.bi_mart`.kpi_dly_smy
    where dt_id between vdt_id and vdt_id
      and subs_flag like 'Prepaid%'
) x
where rk=1
group by kpi_code, kpi_id, dt_id
;