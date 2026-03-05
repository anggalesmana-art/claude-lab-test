declare vdt_id date default @vdt_id;
delete from `data-bi-prd-935c.bi_mart`.kpi_national_tracker_dly where dt_id = vdt_id and brand = 'IM3' and kpi_id in (
'CRN0035',
'CRN0010',
'CRN0015',
'CRN0006',
'CRN0021',
'CRN0026',
'CRN0009',
'CRN0030',
'CRN0031',
'CRN0038',
'CRN0011',
'CRN0014',
'CRN0028',
'CRN0040',
'CRN0032',
'CRN0027',
'CRN0023',
'CRN0022',
'CRN0020',
'CRN0034',
'CRN0025',
'CRN0005',
'CRN0039',
'CRN0007',
'CRN0013',
'CRN0036'
);

insert into `data-bi-prd-935c.bi_mart`.kpi_national_tracker_dly
with
churn as (
  select dt_id
    , case when tnr <= 90 then 'Inflow' when tnr >  90 then 'Base' end tenure
    , case
      when subs_l3m = 0 then 'LVC'
      when tot_l3m_rev/subs_l3m <= 30000  then 'LVC'
      when tot_l3m_rev/subs_l3m <= 100000 then 'MVC'
      when tot_l3m_rev/subs_l3m >  100000 then 'HVC'
    end arpu
    , count(1) subs
    , round(sum( case when subs_l3m = 0 then 0 ELSE (tot_l3m_rev/subs_l3m/1.11) end )) amount
  from (
    select a.*
      , (total_rev_m4+total_rev_m5+total_rev_m6) tot_l3m_rev
      , (
        (case when total_rev_m4 > 0 then 1 ELSE 0 end) +
        (case when total_rev_m5 > 0 then 1 ELSE 0 end) +
        (case when total_rev_m6 > 0 then 1 ELSE 0 end)
      ) subs_l3m
      , date_diff(last_usg, first_usg,day) AS tnr
    from `data-bi-prd-935c.bi_mart`.rgs_churn_90d_dly_govt a
    where dt_id between vdt_id and vdt_id
  ) b
  group by 1, 2, 3
),
cback as (
  select dt_id
    , case when tnr <= 90 then 'Inflow' when tnr >  90 then 'Base' end tenure
    , case
      when ifnull(total_rev,0) <= 30000  then 'LVC'
      when total_rev <= 100000 then 'MVC'
      when total_rev >  100000 then 'HVC'
    end arpu
    , count(1) subs
    , round(sum(total_rev/1.11)) amount
  from (
    select a.*
      , date_diff(dt_id, first_usg,day) AS tnr
    from `data-bi-prd-935c.bi_mart`.rgs_churn_back_90d_govt a
    where dt_id between vdt_id and vdt_id
	) x
	group by 1, 2, 3
),
netchurn as (
  select coalesce(a.dt_id,b.dt_id) dt_id
    , coalesce(a.tenure,b.tenure) tenure
    , coalesce(a.arpu,b.arpu) arpu
    , coalesce(a.subs,0) - coalesce(b.subs,0) subs
    , coalesce(a.amount,0) - coalesce(b.amount,0) amount
  from churn a
  full join cback b
    on a.dt_id=b.dt_id and a.tenure=b.tenure and a.arpu=b.arpu
),
fnl as (
  -- Value Segment Count -- CRN0005 s/d CRN0019
  select dt_id
    , case
      when arpu='HVC' then 'CRN0005'
      when arpu='MVC' then 'CRN0006'
      when arpu='LVC' then 'CRN0007'
    end kpi_id
    , case
      when arpu='HVC' then 'rgu_90d_churn_hvc'
      when arpu='MVC' then 'rgu_90d_churn_mvc'
      when arpu='LVC' then 'rgu_90d_churn_lvc'
    end kpi_code
    , sum(subs) metric
  from churn
  group by 1,2,3
  union all
  select dt_id
    , case
      when arpu='HVC' then 'CRN0009'
      when arpu='MVC' then 'CRN0010'
      when arpu='LVC' then 'CRN0011'
    end kpi_id
    , case
      when arpu='HVC' then 'rgu_90d_cback_hvc'
      when arpu='MVC' then 'rgu_90d_cback_mvc'
      when arpu='LVC' then 'rgu_90d_cback_lvc'
    end kpi_code
    , sum(subs) metric
  from cback
  group by 1,2,3
  union all
  select dt_id
    , case
      when arpu='HVC' then 'CRN0013'
      when arpu='MVC' then 'CRN0014'
      when arpu='LVC' then 'CRN0015'
    end kpi_id
    , case
      when arpu='HVC' then 'rgu_90d_netchurn_hvc'
      when arpu='MVC' then 'rgu_90d_netchurn_mvc'
      when arpu='LVC' then 'rgu_90d_netchurn_lvc'
    end kpi_code
    , sum(subs) metric
  from netchurn
  group by 1,2,3
  union all
  -- Value Churn IDR -- CRN0020 s/d CRN0028
  select dt_id, 'CRN0020' kpi_id, 'rgu_90d_churn_val' kpi_code, sum(amount) metric from churn group by 1
  union all
  select dt_id
    , case when tenure='Inflow' then 'CRN0021' else 'CRN0022' end kpi_id
    , case when tenure='Inflow' then 'rgu_90d_churn_val_inflow' else 'rgu_90d_churn_val_base' end kpi_code
    , sum(amount) metric
  from churn
  group by 1,2,3
  union all
  select dt_id, 'CRN0023' kpi_id, 'rgu_90d_cback_val' kpi_code, sum(amount) metric from cback group by 1
  union all
  select dt_id
    , case when tenure='Inflow' then 'CRN0024' else 'CRN0025' end kpi_id
    , case when tenure='Inflow' then 'rgu_90d_cback_val_inflow' else 'rgu_90d_cback_val_base' end kpi_code
    , sum(amount) metric
  from cback
  group by 1,2,3
  union all
  select dt_id, 'CRN0026' kpi_id, 'rgu_90d_netchurn_val' kpi_code, sum(amount) metric from netchurn group by 1
  union all
  select dt_id
    , case when tenure='Inflow' then 'CRN0027' else 'CRN0028' end kpi_id
    , case when tenure='Inflow' then 'rgu_90d_netchurn_val_inflow' else 'rgu_90d_netchurn_val_base' end kpi_code
    , sum(amount) metric
  from netchurn
  group by 1,2,3
  union all
  -- Value Segment IDR -- CRN0030 s/d CRN0040
  select dt_id
    , case
      when arpu='HVC' then 'CRN0030'
      when arpu='MVC' then 'CRN0031'
      when arpu='LVC' then 'CRN0032'
    end kpi_id
    , case
      when arpu='HVC' then 'rgu_90d_churn_val_hvc'
      when arpu='MVC' then 'rgu_90d_churn_val_mvc'
      when arpu='LVC' then 'rgu_90d_churn_val_lvc'
    end kpi_code
    , sum(amount) metric
  from churn
  group by 1,2,3
  union all
  select dt_id
    , case
      when arpu='HVC' then 'CRN0034'
      when arpu='MVC' then 'CRN0035'
      when arpu='LVC' then 'CRN0036'
    end kpi_id
    , case
      when arpu='HVC' then 'rgu_90d_cback_val_hvc'
      when arpu='MVC' then 'rgu_90d_cback_val_mvc'
      when arpu='LVC' then 'rgu_90d_cback_val_lvc'
    end kpi_code
    , sum(amount) metric
  from cback
  group by 1,2,3
  union all
  select dt_id
    , case
      when arpu='HVC' then 'CRN0038'
      when arpu='MVC' then 'CRN0039'
      when arpu='LVC' then 'CRN0040'
    end kpi_id
    , case
      when arpu='HVC' then 'rgu_90d_netchurn_val_hvc'
      when arpu='MVC' then 'rgu_90d_netchurn_val_mvc'
      when arpu='LVC' then 'rgu_90d_netchurn_val_lvc'
    end kpi_code
    , sum(amount) metric
  from netchurn
  group by 1,2,3
)
select 'IM3' brand, kpi_code, 'DLY' flag, metric, timestamp(current_datetime('+7')) process_dt, kpi_id, dt_id from fnl
;
