declare vdt_id date default @vdt_id;
declare vdt_mth date default date_trunc(vdt_id,month);


--- monthly temp
create or replace table `data-bi-prd-935c.bi_stg`.tmp_inj_spdata_{{ vdt_id }} as
select dt_id, msisdn, actvn_dt, product_name, amount_debit, main_price
from
(
  select date(revenue_date) dt_id, msisdn, date(activation_date) actvn_dt
    , service_class_name product_name, cast(amount_debit as numeric) amount_debit,  cast(main_price as numeric) main_price
    , row_number() over(partition by msisdn order by date(activation_date) desc nulls last, revenue_date, cast(amount_debit as numeric) desc nulls last) rk
  from `data-dtp-prd-aa1a.sor`.sp_data_revenue
  where date(revenue_date) between vdt_mth and vdt_id
  union all
  select date(revenue_date) dt_id, msisdn, date(activation_date) actvn_dt
    , service_class_name product_name, cast(amount_debit as numeric) amount_debit,  cast(main_price as numeric) main_price
    , row_number() over(partition by msisdn order by date(activation_date) desc nulls last, revenue_date, cast(amount_debit as numeric) desc nulls last) rk
  from `data-dtp-prd-aa1a.sor`.sp_data_revenue_b2b
  where date(revenue_date) between vdt_mth and vdt_id
) x
where rk=1
;

--- join with previous month
create or replace table `data-bi-prd-935c.bi_stg`.tmp_inj_spdata_{{ vdt_id }}_tmp1 as
select msisdn, actvn_dt, organization_id, product_name, amount_debit, main_price, inj_dt
from
(
  select x.*, row_number() over(partition by msisdn order by actvn_dt desc, inj_dt, amount_debit desc) rk
  from
  (
    select msisdn, actvn_dt, organization_id, product_name, amount_debit, main_price, inj_dt
    from `data-bi-prd-935c.bi_mart`.first_inj_sp_data_mth
    --from `data-bi-prd-935c.bi_mart`.first_inj_sp_data_mth_alloc_202110 --- oct 2020 only
    where mth_id=vdt_mth - interval 1 month
      and actvn_dt>=vdt_mth - interval 24 month
      and inj_dt>=vdt_mth - interval 12 month
    union all
    select g.msisdn,g.actvn_dt, NULL organization_id, g.product_name, g.amount_debit, g.main_price, date(dt_id)
    from `data-bi-prd-935c.bi_stg`.tmp_inj_spdata_{{ vdt_id }} g
    left join `data-bi-prd-935c.bi_mart`.first_inj_sp_data_mth h
    --left anti join `data-bi-prd-935c.bi_mart`.first_inj_sp_data_mth_alloc_202110 h --- oct 2020 only
      on g.msisdn=h.msisdn and g.actvn_dt=h.actvn_dt and h.mth_id=vdt_mth - interval 1 month
			where h.msisdn is null
  ) x
)y
where rk=1
;

--- outlet tagging reference (202306 Policy update period)
create or replace table `data-bi-prd-935c.bi_stg`.tmp_first_inj_spdata_{{ vdt_id }}_orgid as
select sp_tag_msisdn msisdn
  , case
    when org_type='Gadget Shop' then org_type
    when regexp_contains(org_id,"^[0-9]+$")=False then 'Direct'
    else 'Traditional' end channel
  , org_id organization_id
  , dt_id
  , 2 flag
from `data-bi-prd-935c.bi_mart`.sp_tag_outlet_mth
where month_id=vdt_mth and ifnull(org_id,'')!=''
and dt_id between vdt_mth - interval 3 month and vdt_id
union all
--- DSF Sellout
select msisdn, 'Direct' Channel, destination, dt_id, 3 flag
from `data-bi-prd-935c.bi_mart`.mobii_msisdn_sellout_mth
where month_id=vdt_mth and regexp_contains(destination,"^[0-9]+$")=False
and dt_id between vdt_mth - interval 3 month and vdt_id
union all
--- Traditional Sellin
select msisdn, channel, organization_id, dt_sellin dt_id, 4 flag
from `data-bi-prd-935c.bi_mart`.foss_sp_data_sellin_mth
where mth_id=vdt_mth and ifnull(organization_id,'')!=''
union all
--- immi sellout Promotor (added at 20230111)
select msisdn, sales_type channel, promoter_org_id, dt_id, 1 flag
from `data-bi-prd-935c.bi_mart`.immi_sellout_mth
where mth_id=vdt_mth and ifnull(promoter_org_id,'')!=''
and dt_id between vdt_mth - interval 3 month and vdt_id
and sales_type='Promotor'
union all
--- immi sellout Direct (added at 20230111)
select msisdn, sales_type channel, promoter_org_id, dt_id, 1 flag
from `data-bi-prd-935c.bi_mart`.immi_sellout_mth
where mth_id=vdt_mth and ifnull(promoter_org_id,'')!=''
and dt_id between vdt_mth - interval 1 month
and vdt_id
and sales_type='Direct'
;

--- tagging outlet (remove allocation as of 20230111)
drop table if exists `data-bi-prd-935c.bi_stg`.tmp_inj_spdata_{{ vdt_id }}_tmp2;
create or replace table `data-bi-prd-935c.bi_stg`.tmp_inj_spdata_{{ vdt_id }}_tmp2 as
select x.msisdn, actvn_dt
  , coalesce(y.dealer,organization_id_new, organization_id) organization_id
  , coalesce(y.channel,x.channel,case when regexp_contains(organization_id,"^[0-9]+$")=False then 'Direct' else 'Traditional' end) channel
  , product_name, amount_debit, main_price, inj_dt
from
(
  select a.*, b.organization_id organization_id_new, b.channel
  , row_number() over(partition by a.msisdn order by b.flag, b.dt_id desc) as rk
  from `data-bi-prd-935c.bi_stg`.tmp_inj_spdata_{{ vdt_id }}_tmp1 a
  left join `data-bi-prd-935c.bi_stg`.tmp_first_inj_spdata_{{ vdt_id }}_orgid b
    on a.msisdn=b.msisdn
) x
left join
(
    select msisdn,dealer,'Modern' channel
    from `data-bi-prd-935c.bi_mart`.foss_sp_data_modern_mth
    where mth_id=vdt_mth
) y on x.msisdn=y.msisdn
WHERE rk=1
;

--- insert to master table
delete from `data-bi-prd-935c.bi_mart`.first_inj_sp_data_mth  where mth_id = vdt_mth;
insert into `data-bi-prd-935c.bi_mart`.first_inj_sp_data_mth 
select a.msisdn, coalesce(a.actvn_dt,c.actvn_dt) actvn_dt
  , organization_id, product_name, amount_debit, main_price, inj_dt
  , timestamp(current_datetime('+7')) ppn_dttm, channel, vdt_mth mth_id
from `data-bi-prd-935c.bi_stg`.tmp_inj_spdata_{{ vdt_id }}_tmp2 a
left join
(
  select date(actvn_dt) actvn_dt, msisdn
  from `data-dtp-prd-aa1a.smy`.ar_cst_dly_smy
  where date(dt_id) = vdt_id --and lower(brand_sc_name) in ('im3','mentari')
    and ifnull(cast(actvn_dt as string),'')!=''
) c
  on a.msisdn=c.msisdn
;

--- drop temp table
drop table if exists `data-bi-prd-935c.bi_stg`.tmp_inj_spdata_{{ vdt_id }};
drop table if exists `data-bi-prd-935c.bi_stg`.tmp_inj_spdata_{{ vdt_id }}_tmp1;
drop table if exists `data-bi-prd-935c.bi_stg`.tmp_inj_spdata_{{ vdt_id }}_tmp2;
drop table if exists `data-bi-prd-935c.bi_stg`.tmp_first_inj_spdata_{{ vdt_id }}_orgid;
