declare vdt_id date default @vdt_id;
delete from `data-bi-prd-935c.bi_mart`.sge_dly where dt_id = vdt_id;
insert into `data-bi-prd-935c.bi_mart`.sge_dly
with
prepaid as (
  select date(dt_id) dt_id, msisdn
    , sum(case when svc_usg_tp_rev='VOICE' then ifnull(drtn_of_usg,0) else 0 end) voice_dur
    , sum(case when svc_usg_tp_rev='SMS' then ifnull(usg_hits,0) else 0 end) sms_hits
  	, sum(case when svc_usg_tp_rev='VAS' then ifnull(usg_hits,0) else 0 end) vas_hits
  	, sum(case when svc_usg_tp_rev='DATA' then ifnull(vol_of_usg,0) else 0 end) data_vol
  from `data-dtp-prd-aa1a.smy`.cst_usg_dly_smy
  where date(dt_id)=vdt_id
  group by 1,2
),
ggsn as (
  select distinct dt_id, msisdn
  from `data-bi-prd-935c.bi_mart`.ggsn_rg_dly
  where dt_id=vdt_id
  and rating_group not in ('23111', '55003', '70091')
),
postpaid as (
  select date(transaction_date) dt_id, msisdn
    , sum(case when upper(service_type)='VOICE' then ifnull(total_duration,0) else 0 end) voice_dur
    , sum(case when upper(service_type)='SMS' then ifnull(total_hit,0) else 0 end) sms_hits
    , sum(case when upper(service_type)='VAS' then ifnull(total_hit,0) else 0 end) vas_hits
    , sum(case when upper(service_type)='DATA' then ifnull(total_volume,0) else 0 end) data_vol
  from `data-dtp-prd-aa1a.smy`.usg_postpaid_dly_smy
  where date(transaction_date)=vdt_id
  group by 1,2
),
subs as (
  select msisdn, subs_flag, actvn_dt, svc_class_code
  from
  (
    select msisdn, subs_flag, actvn_dt, svc_class_code
      , row_number() over(partition by msisdn order by subs_flag) as rk
    from
    (
      select distinct msisdn, '2. Postpaid B2C' subs_flag, date(actvn_dt) actvn_dt, sc_id svc_class_code
      from `data-dtp-prd-aa1a.smy`.ar_cst_pstpaid_rtl
      where date(dt_id)=vdt_id
      union all
      select distinct msisdn, '3. Prepaid B2B' subs_flag, date(actvn_dt) actvn_dt, svc_class_code
      from `data-dtp-prd-aa1a.smy`.ar_cst_dly_smy
      where date(dt_id)=vdt_id and svc_class_code in (select svc_class_code from `data-bi-prd-935c.bi_mart`.ref_sc_b2b)
      union all
      select distinct msisdn, '4. Prepaid B2C' subs_flag, date(actvn_dt) actvn_dt, svc_class_code
      from `data-dtp-prd-aa1a.smy`.ar_cst_dly_smy
      where date(dt_id)=vdt_id and svc_class_code not in (select svc_class_code from `data-bi-prd-935c.bi_mart`.ref_sc_b2b)
      union all
      select distinct msisdn, '5. Propaid' subs_flag, date(actvn_dt) actvn_dt, svc_class_code
      from  `data-dtp-prd-aa1a.smy`.ar_cst_propaid_smy
      where date(dt_id)=vdt_id
      union all
      select regexp_replace(svc_id,'[^[:digit:]]','') msisdn, '1. Postpaid B2B' subs_flag, date(actvn_dt) actvn_dt, NULL svc_class_code
      from
      (
        select a.*, row_number() over(partition by regexp_replace(svc_id,'[^[:digit:]]','') order by case when ast_st='Active' then 1 when ast_st='Suspended' then 2 else 3 end) rk
        from `data-dtp-prd-aa1a.smy`.ar_cst_pstpaid_b2b a
        where date(dt_id)=vdt_id  and ifnull(a.svc_id,'')!=''
      )x
      where rk=1
    )x
  )x
  where rk=1
),
subs_source as (
  select msisdn, 'Postpaid' flag
  from postpaid
  union all
  select a.msisdn, 'Prepaid' flag
  from prepaid a
  left join postpaid b
    on a.msisdn=b.msisdn
    where b.msisdn is null
),
gbg as (
  select dt_id, a.msisdn, actvn_dt, svc_class_code
    , case
      when a.msisdn=b.msisdn then regexp_replace(b.subs_flag,substr(b.subs_flag,1,3),'')
      when a.msisdn=c.msisdn then c.flag
      else NULL
      end subs_flag
    , sum(tmp_v) tmp_v
    , sum(tmp_s) tmp_s
    , sum(tmp_d) tmp_d
    , sum(tmp_a) tmp_a
    , sum(tmp_n) tmp_n
  from
  (
    select dt_id, msisdn
      , case when ifnull(voice_dur,0) > 0 then 1 else 0 end tmp_v
      , case when ifnull(sms_hits,0) > 0 then 1 else 0 end tmp_s
      , case when ifnull(data_vol,0) > 0 then 1 else 0 end tmp_d
      , case when ifnull(vas_hits,0) > 0 then 1 else 0 end tmp_a
      , 0 tmp_n
    from prepaid
    where abs(voice_dur)>0 or abs(sms_hits)>0 or abs(data_vol)>0 or abs(vas_hits)>0
    union all
    select dt_id, msisdn
      , 0 tmp_v
      , 0 tmp_s
      , 0 tmp_d
      , 0 tmp_a
      , 1 tmp_n
    from ggsn
    union all
    select dt_id, msisdn
      , case when ifnull(voice_dur,0) > 0 then 1 else 0 end tmp_v
      , case when ifnull(sms_hits,0) > 0 then 1 else 0 end tmp_s
      , case when ifnull(data_vol,0) > 0 then 1 else 0 end tmp_d
      , case when ifnull(vas_hits,0) > 0 then 1 else 0 end tmp_a
      , 0 tmp_n
    from postpaid
    where abs(voice_dur)>0 or abs(sms_hits)>0 or abs(data_vol)>0 or abs(vas_hits)>0
  ) a
  left join subs b
    on a.msisdn=b.msisdn
  left join subs_source c
    on a.msisdn=c.msisdn
  group by 1,2,3,4,5
)
(
  select msisdn, concat( ifnull(v_flag,''), ifnull(s_flag,''), ifnull(d_flag,''), ifnull(n_flag,''), ifnull(a_flag,'')) usg_flag
    , date(actvn_dt) actvn_dt, svc_class_code, subs_flag
    , timestamp(current_datetime('+7')) ppn_dttm
    , dt_id
  from
  (
    select dt_id, msisdn, actvn_dt, svc_class_code, subs_flag
      , case when ifnull(tmp_v,0) > 0 then 'V' else NULL end v_flag
      , case when ifnull(tmp_s,0) > 0 then 'S' else NULL end s_flag
      , case when ifnull(tmp_d,0) > 0 then 'D' else NULL end d_flag
      , case when ifnull(tmp_a,0) > 0 then 'A' else NULL end a_flag
      , case when ifnull(tmp_n,0) > 0 then 'N' else NULL end n_flag
    from gbg
  ) x
)
