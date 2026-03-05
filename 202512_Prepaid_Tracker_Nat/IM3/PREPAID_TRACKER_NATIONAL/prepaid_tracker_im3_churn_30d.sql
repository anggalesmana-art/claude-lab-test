declare vdt_id date default @vdt_id;
delete from `data-bi-prd-935c.bi_mart`.kpi_national_tracker_dly where dt_id = vdt_id and brand = 'IM3' and kpi_id in (
'CRN0075',
'CRN0061',
'CRN0080',
'CRN0055',
'CRN0064',
'CRN0070',
'CRN0071',
'CRN0065',
'CRN0050',
'CRN0054',
'CRN0063',
'CRN0047',
'CRN0072',
'CRN0049',
'CRN0079',
'CRN0074',
'CRN0076',
'CRN0062',
'CRN0068',
'CRN0053',
'CRN0046',
'CRN0078',
'CRN0066',
'CRN0060',
'CRN0051',
'CRN0045',
'CRN0067');

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
    , round(sum( case when subs_l3m = 0 then 0 else (tot_l3m_rev/subs_l3m/1.11) end )) amount
  from (
    select a.*
      , (total_rev_m4+total_rev_m3+total_rev_m2) tot_l3m_rev
      , (
        (case when total_rev_m4 > 0 then 1 ELSE 0 end) +
        (case when total_rev_m3 > 0 then 1 ELSE 0 end) +
        (case when total_rev_m2 > 0 then 1 ELSE 0 end)
      ) subs_l3m
      , date_diff(last_usg, first_usg,day) AS tnr
    from `data-bi-prd-935c.bi_mart`.rgs_churn_30d_dly_govt a
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
    union all
    select a.*
      , date_diff(dt_id, first_usg,day) AS tnr
    from `data-bi-prd-935c.bi_mart`.rgs_churn_back_30d_govt a
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
  -- Value Segment Count -- CRN0045 s/d CRN0059
  select dt_id
    , case
      when arpu='HVC' then 'CRN0045'
      when arpu='MVC' then 'CRN0046'
      when arpu='LVC' then 'CRN0047'
    end kpi_id
    , case
      when arpu='HVC' then 'rgu_30d_churn_hvc'
      when arpu='MVC' then 'rgu_30d_churn_mvc'
      when arpu='LVC' then 'rgu_30d_churn_lvc'
    end kpi_code
    , sum(subs) metric
  from churn
  group by 1,2,3
  union all
  select dt_id
    , case
      when arpu='HVC' then 'CRN0049'
      when arpu='MVC' then 'CRN0050'
      when arpu='LVC' then 'CRN0051'
    end kpi_id
    , case
      when arpu='HVC' then 'rgu_30d_cback_hvc'
      when arpu='MVC' then 'rgu_30d_cback_mvc'
      when arpu='LVC' then 'rgu_30d_cback_lvc'
    end kpi_code
    , sum(subs) metric
  from cback
  group by 1,2,3
  union all
  select dt_id
    , case
      when arpu='HVC' then 'CRN0053'
      when arpu='MVC' then 'CRN0054'
      when arpu='LVC' then 'CRN0055'
    end kpi_id
    , case
      when arpu='HVC' then 'rgu_30d_netchurn_hvc'
      when arpu='MVC' then 'rgu_30d_netchurn_mvc'
      when arpu='LVC' then 'rgu_30d_netchurn_lvc'
    end kpi_code
    , sum(subs) metric
  from netchurn
  group by 1,2,3
  union all
  -- Value Churn IDR -- CRN0060 s/d CRN0068
  select dt_id, 'CRN0060' kpi_id, 'rgu_30d_churn_val' kpi_code, sum(amount) metric from churn group by 1
  union all
  select dt_id
    , case when tenure='Inflow' then 'CRN0061' else 'CRN0062' end kpi_id
    , case when tenure='Inflow' then 'rgu_30d_churn_val_inflow' else 'rgu_30d_churn_val_base' end kpi_code
    , sum(amount) metric
  from churn
  group by 1,2,3
  union all
  select dt_id, 'CRN0063' kpi_id, 'rgu_30d_cback_val' kpi_code, sum(amount) metric from cback group by 1
  union all
  select dt_id
    , case when tenure='Inflow' then 'CRN0064' else 'CRN0065' end kpi_id
    , case when tenure='Inflow' then 'rgu_30d_cback_val_inflow' else 'rgu_30d_cback_val_base' end kpi_code
    , sum(amount) metric
  from cback
  group by 1,2,3
  union all
  select dt_id, 'CRN0066' kpi_id, 'rgu_30d_netchurn_val' kpi_code, sum(amount) metric from netchurn group by 1
  union all
  select dt_id
    , case when tenure='Inflow' then 'CRN0067' else 'CRN0068' end kpi_id
    , case when tenure='Inflow' then 'rgu_30d_netchurn_val_inflow' else 'rgu_30d_netchurn_val_base' end kpi_code
    , sum(amount) metric
  from netchurn
  group by 1,2,3
  union all
  -- Value Segment IDR -- CRN0070 s/d CRN0080
  select dt_id
    , case
      when arpu='HVC' then 'CRN0070'
      when arpu='MVC' then 'CRN0071'
      when arpu='LVC' then 'CRN0072'
    end kpi_id
    , case
      when arpu='HVC' then 'rgu_30d_churn_val_hvc'
      when arpu='MVC' then 'rgu_30d_churn_val_mvc'
      when arpu='LVC' then 'rgu_30d_churn_val_lvc'
    end kpi_code
    , sum(amount) metric
  from churn
  group by 1,2,3
  union all
  select dt_id
    , case
      when arpu='HVC' then 'CRN0074'
      when arpu='MVC' then 'CRN0075'
      when arpu='LVC' then 'CRN0076'
    end kpi_id
    , case
      when arpu='HVC' then 'rgu_30d_cback_val_hvc'
      when arpu='MVC' then 'rgu_30d_cback_val_mvc'
      when arpu='LVC' then 'rgu_30d_cback_val_lvc'
    end kpi_code
    , sum(amount) metric
  from cback
  group by 1,2,3
  union all
  select dt_id
    , case
      when arpu='HVC' then 'CRN0078'
      when arpu='MVC' then 'CRN0079'
      when arpu='LVC' then 'CRN0080'
    end kpi_id
    , case
      when arpu='HVC' then 'rgu_30d_netchurn_val_hvc'
      when arpu='MVC' then 'rgu_30d_netchurn_val_mvc'
      when arpu='LVC' then 'rgu_30d_netchurn_val_lvc'
    end kpi_code
    , sum(amount) metric
  from netchurn
  group by 1,2,3
)
select 'IM3' brand, kpi_code, 'DLY' flag, metric, timestamp(current_datetime('+7')) process_dt, kpi_id, dt_id from fnl
;
