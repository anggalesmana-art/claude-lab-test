declare vdt_id date default @vdt_id;

delete from `data-bi-prd-935c.bi_mart`.stg_vlr_site_tenure where dt_id = vdt_id;

insert into `data-bi-prd-935c.bi_mart`.stg_vlr_site_tenure
with fu as (
 select distinct sbscrptn_ek_id , case when fu_dt = '9999-12-31' then null else fu_dt end fu_dt from(
 select distinct cast(sbscrptn_ek_id as string) sbscrptn_ek_id,
 least(coalesce(date(first_usage_dt),'9999-12-31'), least(coalesce(parse_date('%Y%m%d',cast(first_billing_usage_dt_sk_id as string)),'9999-12-31'), coalesce(date(any_event_first_usage_date),'9999-12-31'))) as fu_dt
 from `data-dtptechm-prd-c7ca.dwh`.sbscrptn_attribs
)a),
ga as (
  /* yang ini jangan diganti, historical */
  select distinct dt as ga_dt, cast(sbscrptn_ek_id as string) sbscrptn_ek_id
  from `data-bi-prd-935c.bi_mart`.fct_ioh_mvmnt_1_detail_dec21
  where tag = 'rgu90_gross_add' and dt >= '2021-10-01' and dt <= '2021-12-31'
  union distinct
  /* ini yang ter-update */
  select distinct ga_date as ga_dt, sbscrptn_ek_id
  from `data-bi-prd-935c.bi_mart`.project_ioh_fu_master_v2
  where ga_date >= '2022-01-01' and ga_date <= vdt_id
),
vlr as (
  /* VLR with tenure */
  select load_dt_sk_id as dt_id, msisdn, cast(b.sbscrptn_ek_id as string) sbscrptn_ek_id, siteid_nm site_id
    , case when b.product_id=8 then 'PREPAID' ELSE 'POSTPAID' end flag_subs
    , date_diff(a.load_dt_sk_id,coalesce(ga_dt, fu_dt),day) as tnr
    , coalesce(ga_dt, fu_dt) as ga_fu_dt
  from `data-bi-prd-935c.bi_mart`.fct_vlr_sites a
  left outer join `data-dtptechm-prd-c7ca.dwh`.sbscrptn_attribs b on a.msisdn = cast(b.sbscrptn_msisdn as string) and b.rank_ind = 1
  left outer join ga d on cast(b.sbscrptn_ek_id as string) = d.sbscrptn_ek_id
  left outer join fu e on cast(b.sbscrptn_ek_id as string) = e.sbscrptn_ek_id
  where load_dt_sk_id = vdt_id
)
select * from vlr
;


delete from `data-bi-prd-935c.bi_mart`.stg_incoming where dt_id = vdt_id;
insert into `data-bi-prd-935c.bi_mart`.stg_incoming 
with
a2p as (
  select distinct dt dt_id, sbscrptn_ek_id
  from `data-bi-prd-935c.bi_mart`.fct_rgu_voice_sms_free
  where dt = vdt_id
),
offnet as (
  select distinct dt_id, sbscrptn_ek_id
  from (
    select load_dt_sk_id as dt_id, cast(sbscrptn_ek_id as string) sbscrptn_ek_id
    from `data-bi-prd-935c.bi_mart`.project_rgumt_subs_detail
    where load_dt_sk_id = vdt_id
    union all
    select dt as dt_id, sbscrptn_ek_id
    from `data-bi-prd-935c.bi_mart`.fct_inc_voice_offnet
    where dt = vdt_id
  ) x
)
select distinct dt_id, sbscrptn_ek_id
from (
  select * from a2p
  union all
  select * from offnet
) x;


delete from `data-bi-prd-935c.bi_mart`.vlr_site_activity where dt_id = vdt_id;
insert into `data-bi-prd-935c.bi_mart`.vlr_site_activity
with
outgoing as (
  select distinct load_dt_sk_id as dt_id, sbscrptn_ek_id, 1 flag_outgoing
  from `data-bi-prd-935c.bi_mart`.project_rguog_subs_detail
  where load_dt_sk_id = vdt_id
),
incoming as (
  select dt_id, sbscrptn_ek_id, 1 flag_incoming
  from `data-bi-prd-935c.bi_mart`.stg_incoming
  where dt_id = vdt_id
)
select a.dt_id, '3ID' brand
  , case
      when flag_outgoing=1 and flag_incoming=1 then 'MO+MT'
      when flag_outgoing=1 then 'MO Only'
      when flag_incoming=1 then 'MT Only'
      else 'No Activity'
    end flag
  , case
    when tnr<=90 then 'a.<=90D'
    when tnr<=180 then 'b.91D - 180D'
    else 'c.>=181D'
  end tenure
  , site_id
  , count(1) subs
from `data-bi-prd-935c.bi_mart`.stg_vlr_site_tenure a
left join outgoing b
  on a.sbscrptn_ek_id=b.sbscrptn_ek_id and a.dt_id=b.dt_id
left join incoming cb
  on a.sbscrptn_ek_id=cb.sbscrptn_ek_id and a.dt_id=cb.dt_id
where a.dt_id = vdt_id
  and flag_subs='PREPAID'
group by 1,2,3,4,5
;