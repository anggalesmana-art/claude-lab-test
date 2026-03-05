declare vdt_id date default @vdt_id;
delete from `data-bi-prd-935c.bi_mart`.kpi_national_tracker_dly where dt_id = vdt_id and brand = 'IM3' and kpi_id in (
'SUB0044',
'SUB0071',
'SUB0048',
'SUB0035',
'SUB0030',
'SUB0036',
'SUB0046',
'SUB0050',
'SUB0037',
'SUB0033',
'SUB0042',
'SUB0043',
'SUB0040',
'SUB0032',
'SUB0029',
'SUB0038',
'SUB0072',
'SUB0028',
'SUB0034',
'SUB0045',
'SUB0039',
'SUB0073',
'SUB0049',
'SUB0041'
);

insert into `data-bi-prd-935c.bi_mart`.kpi_national_tracker_dly
with base as (
  select dt_id+interval 1 day dt_id_1, dt_id
    , tenure
    , case
      WHEN arpu in ('a.>100K') THEN 'HVC'
      WHEN arpu in ('b.30K-100K') THEN 'MVC'
      WHEN arpu in ('c.<=30K','d.Non RGE') THEN 'LVC'
    end segment
    , 'MTD' flag
    , sum(subs) metric
  from `data-bi-prd-935c.bi_mart`.rgs_30d_govt
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
    from `data-bi-prd-935c.bi_mart`.rgs_churn_30d_dly_govt a
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
    union all
    select a.*,
      date_diff(dt_id, first_usg,day) AS tnr
    from `data-bi-prd-935c.bi_mart`.rgs_churn_back_30d_govt a
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
      and kpi_nm='VLR_30D'
      and subs_flag like 'Prepaid%'
  group by 1,2
),
fnl as (
  -- rgu_30d_opening
  select dt_id_1 dt_id, 'SUB0028' kpi_id, 'rgu_30d_opening' kpi_code, flag, sum(metric) metric
  from base
  where dt_id_1 between vdt_id and vdt_id
  group by 1,2,3,4
  union all
  -- rgu_30d_opening_inflow & rgu_30d_opening_base
  select dt_id_1 dt_id
    , case when tenure='Inflow' then 'SUB0029'
      else 'SUB0030'
    end kpi_code
    , case when tenure='Inflow' then 'rgu_30d_opening_inflow'
      else 'rgu_30d_opening_base'
    end kpi_code
    , flag
    , sum(metric) metric
  from base
  where dt_id_1 between vdt_id and vdt_id
  group by 1,2,3,4
  union all
  -- rgu_30d_churn
  select dt_id, 'SUB0032' kpi_id, 'rgu_30d_churn' kpi_code, flag, sum(metric) metric
  from churn
  group by 1,2,3,4
  union all
  -- rgu_30d_churn_inflow & rgu_30d_churn_base
  select dt_id
    , case when tenure='Inflow' then 'SUB0033'
      else 'SUB0034'
    end kpi_id
    , case when tenure='Inflow' then 'rgu_30d_churn_inflow'
      else 'rgu_30d_churn_base'
    end kpi_code
    , flag
    , sum(metric) metric
  from churn
  group by 1,2,3,4
  union all
  -- rgu_30d_cback
  select dt_id, 'SUB0035' kpi_id, 'rgu_30d_cback' kpi_code, flag, sum(metric) metric
  from cback
  group by 1,2,3,4
  union all
  -- rgu_30d_cback_inflow & rgu_30d_cback_base
  select dt_id
    , case when tenure='Inflow' then 'SUB0036'
      else 'SUB0037'
    end kpi_id
    , case when tenure='Inflow' then 'rgu_30d_cback_inflow'
      else 'rgu_30d_cback_base'
    end kpi_code
    , flag
    , sum(metric) metric
  from cback
  group by 1,2,3,4
  union all
  -- rgu_30d_closing
  select dt_id, 'SUB0041' kpi_id, 'rgu_30d_closing' kpi_code, flag, sum(metric) metric
  from base
  where dt_id between vdt_id and vdt_id
  group by 1,2,3,4
  union all
  -- rgu_30d_closing_inflow & rgu_30d_closing_base
  select dt_id
    , case when tenure='Inflow' then 'SUB0042'
      else 'SUB0043'
    end kpi_id
    , case when tenure='Inflow' then 'rgu_30d_closing_inflow'
      else 'rgu_30d_closing_base'
    end kpi_code
    , flag
    , sum(metric) metric
  from base
  where dt_id between vdt_id and vdt_id
  group by 1,2,3,4
  union all
  -- rgu_30d_netchurn
  select dt_id, 'SUB0038' kpi_id, 'rgu_30d_netchurn' kpi_code, flag, sum(metric) metric
  from netchurn
  group by 1,2,3,4
  union all
  -- rgu_30d_netchurn_inflow & rgu_30d_netchurn_base
  select dt_id
    , case when tenure='Inflow' then 'SUB0039'
      else 'SUB0040'
    end kpi_id
    , case when tenure='Inflow' then 'rgu_30d_netchurn_inflow'
      else 'rgu_30d_netchurn_base'
    end kpi_code
    , flag
    , sum(metric) metric
  from netchurn
  group by 1,2,3,4
  union all
  -- rgu_30d_netadd
  select dt_id, 'SUB0044' kpi_id, 'rgu_30d_netadd' kpi_code, flag, sum(metric) metric
  from netadd
  group by 1,2,3,4
  union all
  -- rgu_30d_netadd_inflow & rgu_30d_netadd_base
  select dt_id
    , case when tenure='Inflow' then 'SUB0045'
      else 'SUB0046'
    end kpi_id
    , case when tenure='Inflow' then 'rgu_30d_netadd_inflow'
      else 'rgu_30d_netadd_base'
    end kpi_code
    , flag
    , sum(metric) metric
  from netadd
  group by 1,2,3,4
  union all
  -- vlr_30d
  select dt_id, 'SUB0048' kpi_id, 'vlr_30d' kpi_code, flag, sum(metric) metric
  from vlr
  group by 1,2,3,4
  union all
  -- vlr_30d_inflow & vlr_30d_base
  select dt_id
    , case when tenure='Inflow' then 'SUB0049'
      else 'SUB0050'
    end kpi_id
    , case when tenure='Inflow' then 'vlr_30d_inflow'
      else 'vlr_30d_base'
    end kpi_code
    , flag
    , sum(metric) metric
  from vlr
  group by 1,2,3,4
  union all
  -- rgu_30d_closing_hvc & rgu_30d_closing_mvc & rgu_30d_closing_lvc
  select dt_id
    , case
      when segment='HVC' then 'SUB0071'
      when segment='MVC' then 'SUB0072'
      else 'SUB0073'
    end kpi_id
    , case
      when segment='HVC' then 'rgu_30d_closing_hvc'
      when segment='MVC' then 'rgu_30d_closing_mvc'
      else 'rgu_30d_closing_lvc'
    end kpi_code
    , flag
    , sum(metric) metric
  from base
  where dt_id between vdt_id and vdt_id
  group by 1,2,3,4
)
select 'IM3' brand, kpi_code, flag, metric, timestamp(current_datetime('+7')) process_dt, kpi_id, date(dt_id) dt_id from fnl
;
