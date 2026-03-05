declare vdt_id date default @vdt_id;
declare vdt_mth date default date_trunc(vdt_id,month);

--/data/05/ioh/BI/schedule/mart/20231031_channel_depedencies/script/first_inj_salmo_mth.sql

--- monthly temp
create or replace table `data-bi-prd-935c.bi_stg`.tmp_inj_salmo_{{ vdt_id }} as
select msisdn, actvn_dt, channel, organization_id, product_name, amount_debit, main_price, transaction_type, transaction_id, dt_id
from
(
  select a.b_msisdn msisdn, b.actvn_dt, channel, organization_id, product_name, amount_debit, main_price, transaction_type, transaction_id, dt_id
    , row_number() over(partition by b_msisdn order by completion_date, amount_debit desc) rk
  from `data-bi-prd-935c.bi_mart`.sellout_salmo_dly a
  inner join
  (
    select date(actvn_dt) actvn_dt, msisdn
    from `data-dtp-prd-aa1a.smy`.ar_cst_dly_smy
    where date(dt_id) = vdt_id --and lower(brand_sc_name) in ('im3','mentari') --Stop by Indra Maulana Ikhsan 20240821(HG Direction)
      and ifnull(cast(actvn_dt as string),'')!=''
      and date(actvn_dt)>=vdt_mth - interval 24 month
  ) b
    on a.b_msisdn=b.msisdn
  where dt_id between vdt_mth and vdt_id
    and lower(transaction_type) in ('purchase data package','bulk purchase package transaction','indosat reload','bulk reload')
    and date_diff(a.dt_id, date(b.actvn_dt),day)>=-1
) x
where rk=1
;

--- final temp
drop table if exists `data-bi-prd-935c.bi_stg`.tmp_inj_salmo_{{ vdt_id }}_fnl;
create or replace table `data-bi-prd-935c.bi_stg`.tmp_inj_salmo_{{ vdt_id }}_fnl as
select msisdn, actvn_dt, channel, organization_id, product_name, amount_debit, main_price, transaction_type, transaction_id, inj_dt
from
(
  select a.*, row_number() over(partition by msisdn order by actvn_dt desc, inj_dt, amount_debit desc) rk
  from
  (
    select msisdn, actvn_dt, channel, organization_id, product_name, amount_debit, main_price, transaction_type, transaction_id, inj_dt
    from `data-bi-prd-935c.bi_mart`.first_inj_salmo_mth
    where mth_id=vdt_mth - interval 1 month
      and actvn_dt>=vdt_mth - interval 24 month
      and inj_dt>=vdt_mth - interval 12 month
    union all
    select g.msisdn, date(g.actvn_dt), g.channel, g.organization_id, g.product_name, g.amount_debit, g.main_price, g.transaction_type, g.transaction_id, dt_id
    from `data-bi-prd-935c.bi_stg`.tmp_inj_salmo_{{ vdt_id }} g
    left join `data-bi-prd-935c.bi_mart`.first_inj_salmo_mth h
      on g.msisdn=h.msisdn and date(g.actvn_dt)=h.actvn_dt and h.mth_id=vdt_mth - interval 1 month
			where h.msisdn is null
  ) a
) x
where rk=1
;

--- insert to master table
delete from `data-bi-prd-935c.bi_mart`.first_inj_salmo_mth  where mth_id = vdt_mth;
insert into `data-bi-prd-935c.bi_mart`.first_inj_salmo_mth 
select a.*, timestamp(current_datetime('+7')) ppn_dttm, vdt_mth mth_id from `data-bi-prd-935c.bi_stg`.tmp_inj_salmo_{{ vdt_id }}_fnl a
;

--- drop temp table
drop table if exists `data-bi-prd-935c.bi_stg`.tmp_inj_salmo_{{ vdt_id }};
drop table if exists `data-bi-prd-935c.bi_stg`.tmp_inj_salmo_{{ vdt_id }}_fnl;