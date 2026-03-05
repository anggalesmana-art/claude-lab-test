declare vdt_id date default @vdt_id;
delete from `data-bi-prd-935c.bi_mart`.kpi_national_tracker_dly where dt_id = vdt_id and brand = 'IM3' and kpi_id in (
'SUB0013',
'SUB0061',
'SUB0062',
'SUB0016',
'SUB0018',
'SUB0025',
'SUB0022',
'SUB0005',
'SUB0024',
'SUB0020',
'SUB0007',
'SUB0008',
'SUB0010',
'SUB0019',
'SUB0015',
'SUB0026',
'SUB0009',
'SUB0011',
'SUB0004',
'SUB0014',
'SUB0006',
'SUB0021',
'SUB0063',
'SUB0017'
);

insert into `data-bi-prd-935c.bi_mart`.kpi_national_tracker_dly
with base as (
  select dt_id + interval 1 day dt_id_1, dt_id
    , tenure
    , case
      WHEN arpu in ('a.>100K') THEN 'HVC'
      WHEN arpu in ('b.30K-100K') THEN 'MVC'
      WHEN arpu in ('c.<=30K','d.Non RGE') THEN 'LVC'
    end segment
    , 'MTD' flag
    , sum(subs) metric
  from `data-bi-prd-935c.bi_mart`.rgs_90d_govt
  where dt_id between vdt_id - interval 1 day and vdt_id
  group by 1,2,3,4
),
churn as (
  select dt_id
    , case when tnr<= 90 then 'Inflow' else 'Base' end tenure
    , 'DLY' flag
    , count(1) metric
  from (
    select a.*,
      date_diff(last_usg, first_usg,day) AS tnr
    from `data-bi-prd-935c.bi_mart`.rgs_churn_90d_dly_govt a
    where dt_id between vdt_id and vdt_id
  ) x
  group by 1,2
),
cback as (
  select dt_id
    , case when tnr<= 90 then 'Inflow' else 'Base' end tenure
    , 'DLY' flag
    , count(1) metric
  from (
    select a.*,
      date_diff(dt_id, first_usg,day) AS tnr
    from `data-bi-prd-935c.bi_mart`.rgs_churn_back_90d_govt a
    where dt_id between vdt_id and vdt_id
  ) x
  group by 1,2
),
netchurn as (
  select coalesce(a.dt_id,b.dt_id) dt_id
    , coalesce(a.tenure,b.tenure) tenure
    , 'DLY' flag
    , coalesce(a.metric,0) - coalesce(b.metric,0) metric
  from churn a
  full join cback b
    on a.dt_id=b.dt_id and a.tenure=b.tenure
),
netadd as (
  select coalesce(a.dt_id,b.dt_id) dt_id
    , coalesce(a.tenure,b.tenure) tenure
    , 'DLY' flag
    , coalesce(a.metric,0) - coalesce(b.metric,0) metric
  from (
    select dt_id, tenure, sum(metric) metric
    from base
    where dt_id between vdt_id and vdt_id
    group by 1,2
  ) a
  full join (
    select dt_id_1 dt_id, tenure, sum(metric) metric
    from base
    where dt_id_1 between vdt_id and vdt_id
    group by 1,2
  ) b
    on a.dt_id=b.dt_id and a.tenure=b.tenure
),
vlr as (
  select dt_id
    , case when tenure in ('a.1-30 Days','b.31-60 Days','c.61-90 Days') then 'Inflow' else 'Base' end tenure
    , 'MTD' flag
    , sum(metric) metric
  from `data-bi-prd-935c.bi_mart`.vlr_activity_smy
  where dt_id between vdt_id and vdt_id
      and kpi_nm='VLR_90D'
      and subs_flag like 'Prepaid%'
  group by 1,2
),
fnl as (
  -- rgu_90d_opening
  select dt_id_1 dt_id, 'SUB0004' kpi_id, 'rgu_90d_opening' kpi_code, flag, sum(metric) metric
  from base
  where dt_id_1 between vdt_id and vdt_id
  group by 1,2,3,4
  union all
  -- rgu_90d_opening_inflow & rgu_90d_opening_base
  select dt_id_1 dt_id
    , case when tenure='Inflow' then 'SUB0005'
      else 'SUB0006'
    end kpi_code
    , case when tenure='Inflow' then 'rgu_90d_opening_inflow'
      else 'rgu_90d_opening_base'
    end kpi_code
    , flag
    , sum(metric) metric
  from base
  where dt_id_1 between vdt_id and vdt_id
  group by 1,2,3,4
  union all
  -- rgu_90d_ga
  select dt_id, 'SUB0007' kpi_id, 'rgu_90d_ga' kpi_code, 'DLY' flag, count(1) metric
  from `data-bi-prd-935c.bi_mart`.rgs_ga_90d_dly_govt
  where dt_id between vdt_id and vdt_id
    and (churn_back = 'NO' or recycled = 'YES')
  group by 1
  union all
  -- rgu_90d_churn
  select dt_id, 'SUB0008' kpi_id, 'rgu_90d_churn' kpi_code, flag, sum(metric) metric
  from churn
  group by 1,2,3,4
  union all
  -- rgu_90d_churn_inflow & rgu_90d_churn_base
  select dt_id
    , case when tenure='Inflow' then 'SUB0009'
      else 'SUB0010'
    end kpi_id
    , case when tenure='Inflow' then 'rgu_90d_churn_inflow'
      else 'rgu_90d_churn_base'
    end kpi_code
    , flag
    , sum(metric) metric
  from churn
  group by 1,2,3,4
  union all
  -- rgu_90d_cback
  select dt_id, 'SUB0011' kpi_id, 'rgu_90d_cback' kpi_code, flag, sum(metric) metric
  from cback
  group by 1,2,3,4
  union all
  -- rgu_90d_cback_inflow & rgu_90d_cback_base
  select dt_id
    , case when tenure='Inflow' then 'SUB0012'
      else 'SUB0013'
    end kpi_id
    , case when tenure='Inflow' then 'rgu_90d_cback_inflow'
      else 'rgu_90d_cback_base'
    end kpi_code
    , flag
    , sum(metric) metric
  from cback
  group by 1,2,3,4
  union all
  -- rgu_90d_closing
  select dt_id, 'SUB0017' kpi_id, 'rgu_90d_closing' kpi_code, flag, sum(metric) metric
  from base
  where dt_id between vdt_id and vdt_id
  group by 1,2,3,4
  union all
  -- rgu_90d_closing_inflow & rgu_90d_closing_base
  select dt_id
    , case when tenure='Inflow' then 'SUB0018'
      else 'SUB0019'
    end kpi_id
    , case when tenure='Inflow' then 'rgu_90d_closing_inflow'
      else 'rgu_90d_closing_base'
    end kpi_code
    , flag
    , sum(metric) metric
  from base
  where dt_id between vdt_id and vdt_id
  group by 1,2,3,4
  union all
  -- rgu_90d_netchurn
  select dt_id, 'SUB0014' kpi_id, 'rgu_90d_netchurn' kpi_code, flag, sum(metric) metric
  from netchurn
  group by 1,2,3,4
  union all
  -- rgu_90d_netchurn_inflow & rgu_90d_netchurn_base
  select dt_id
    , case when tenure='Inflow' then 'SUB0015'
      else 'SUB0016'
    end kpi_id
    , case when tenure='Inflow' then 'rgu_90d_netchurn_inflow'
      else 'rgu_90d_netchurn_base'
    end kpi_code
    , flag
    , sum(metric) metric
  from netchurn
  group by 1,2,3,4
  union all
  -- rgu_90d_netadd
  select dt_id, 'SUB0020' kpi_id, 'rgu_90d_netadd' kpi_code, flag, sum(metric) metric
  from netadd
  group by 1,2,3,4
  union all
  -- rgu_90d_netadd_inflow & rgu_90d_netadd_base
  select dt_id
    , case when tenure='Inflow' then 'SUB0021'
      else 'SUB0022'
    end kpi_id
    , case when tenure='Inflow' then 'rgu_90d_netadd_inflow'
      else 'rgu_90d_netadd_base'
    end kpi_code
    , flag
    , sum(metric) metric
  from netadd
  group by 1,2,3,4
  union all
  -- vlr_90d
  select dt_id, 'SUB0024' kpi_id, 'vlr_90d' kpi_code, flag, sum(metric) metric
  from vlr
  group by 1,2,3,4
  union all
  -- vlr_90d_inflow & vlr_90d_base
  select dt_id
    , case when tenure='Inflow' then 'SUB0025'
      else 'SUB0026'
    end kpi_id
    , case when tenure='Inflow' then 'vlr_90d_inflow'
      else 'vlr_90d_base'
    end kpi_code
    , flag
    , sum(metric) metric
  from vlr
  group by 1,2,3,4
  union all
  -- rgu_90d_closing_hvc & rgu_90d_closing_mvc & rgu_90d_closing_lvc
  select dt_id
    , case
      when segment='HVC' then 'SUB0061'
      when segment='MVC' then 'SUB0062'
      else 'SUB0063'
    end kpi_id
    , case
      when segment='HVC' then 'rgu_90d_closing_hvc'
      when segment='MVC' then 'rgu_90d_closing_mvc'
      else 'rgu_90d_closing_lvc'
    end kpi_code
    , flag
    , sum(metric) metric
  from base
  where dt_id between vdt_id and vdt_id
  group by 1,2,3,4
)
select 'IM3' brand, kpi_code, flag, metric, timestamp(current_datetime('+7')) process_dt, kpi_id, date(dt_id) dt_id from fnl
;
