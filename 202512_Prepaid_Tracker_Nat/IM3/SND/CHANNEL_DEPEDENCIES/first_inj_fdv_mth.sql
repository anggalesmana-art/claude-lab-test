declare vdt_id date default @vdt_id;
declare vdt_mth date default date_trunc(vdt_id,month);

--- monthly temp
create or replace table `data-bi-prd-935c.bi_stg`.tmp_inj_fdv_{{ vdt_id }} as
select msisdn, actvn_dt, organization_id, product_name, amount_debit, main_price, transaction_id, dt_id
from
(
  select concat('62',pm_red_msisdn) msisdn, b.actvn_dt, mobo_inj_outlet_id organization_id
    , mobo_inj_pack_name product_name, mobo_inj_sales_price amount_debit, mobo_inj_main_price main_price
    , mobo_trx_id transaction_id, date(transactiondate) dt_id
    , row_number() over(partition by concat('62',pm_red_msisdn) order by transactiondate, mobo_trx_id, mobo_inj_sales_price desc) rk
  from `data-dtp-prd-aa1a.sor`.fdv_mobo_pm_join_match a
  inner join
  (
    select date(actvn_dt) actvn_dt, msisdn
    from `data-dtp-prd-aa1a.smy`.ar_cst_dly_smy
    where date(dt_id) = vdt_id --and lower(brand_sc_name) in ('im3','mentari') --Stop by Indra Maulana Ikhsan 20240821(HG Direction)
      and ifnull(cast(actvn_dt as string),'')!=''
      and date(actvn_dt)>=vdt_mth - interval 24 month
  ) b
    on concat('62',pm_red_msisdn)=b.msisdn
  where date(transactiondate) between vdt_mth and vdt_id
    and pm_voucher_status='U'
    and date_diff(date(a.transactiondate), date(b.actvn_dt),day)>=-1
    and substring(concat('62',pm_red_msisdn), 1,5) in ('62857','62858','62856','62815','62816','62855','62814')
    --and substr(case when substr(pm_red_msisdn,1,2)!='62' then concat('62',pm_red_msisdn) else pm_red_msisdn end,1,5) in ('62857','62858','62856','62815','62816','62855','62814')
) x
where rk=1
;

--- final temp
create or replace table `data-bi-prd-935c.bi_stg`.tmp_inj_fdv_{{ vdt_id }}_fnl as
select msisdn, actvn_dt, organization_id, product_name, amount_debit, main_price, transaction_id, inj_dt
from
(
  select a.*, row_number() over(partition by msisdn order by actvn_dt desc nulls last, inj_dt, amount_debit desc nulls last) rk
  from
  (
    select msisdn, actvn_dt, organization_id, product_name, amount_debit, main_price, transaction_id, inj_dt
    from `data-bi-prd-935c.bi_mart`.first_inj_fdv_mth
    where mth_id=vdt_mth - interval 1 month
      and actvn_dt>=vdt_mth - interval 24 month
      and inj_dt>=vdt_mth - interval 12 month
    union all
    select g.msisdn, g.actvn_dt, g.organization_id, g.product_name, g.amount_debit, g.main_price, g.transaction_id, dt_id
    from `data-bi-prd-935c.bi_stg`.tmp_inj_fdv_{{ vdt_id }} g
    left join `data-bi-prd-935c.bi_mart`.first_inj_fdv_mth h
      on g.msisdn=h.msisdn and date(g.actvn_dt)=h.actvn_dt and h.mth_id=vdt_mth - interval 1 month
		where h.msisdn is null
  ) a
) x
where rk=1
;

--- insert to master table
delete from `data-bi-prd-935c.bi_mart`.first_inj_fdv_mth where mth_id = vdt_mth;
insert into `data-bi-prd-935c.bi_mart`.first_inj_fdv_mth
select a.*, timestamp(current_datetime('+7')) ppn_dttm, vdt_mth mth_id from `data-bi-prd-935c.bi_stg`.tmp_inj_fdv_{{ vdt_id }}_fnl a
;

--- drop temp table
drop table if exists `data-bi-prd-935c.bi_stg`.tmp_inj_fdv_{{ vdt_id }};
drop table if exists `data-bi-prd-935c.bi_stg`.tmp_inj_fdv_{{ vdt_id }}_fnl;
