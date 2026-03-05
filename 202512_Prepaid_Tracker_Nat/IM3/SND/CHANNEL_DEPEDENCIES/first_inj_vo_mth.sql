declare vdt_id date default @vdt_id;
declare vdt_mth date default date_trunc(vdt_id,month);

--- monthly temp
create or replace table `data-bi-prd-935c.bi_stg`.tmp_inj_fdv_{{ vdt_id }} as
select a.msisdn, date(b.actvn_dt) actvn_dt, organization_id, product_name, amount_debit, main_price, sno, date(dt_id) dt_id
from
(
  select case when substr(pm_red_msisdn,1,2)!='62' then concat('62',pm_red_msisdn) else pm_red_msisdn end msisdn
    , inj_outlet_id organization_id
    , inj_pack_name product_name
    , inj_sales_price amount_debit
    , inj_main_price main_price
    , pm_voucher_sn sno
    , parse_date('%Y%m%d',transactiondate) dt_id
    , row_number() over(partition by case when substr(pm_red_msisdn,1,2)!='62' then concat('62',pm_red_msisdn) else pm_red_msisdn end order by transactiondate, inj_sales_price desc nulls last) as rk
  from `data-dtp-prd-aa1a.smy`.smy_dv_redemption
  where parse_date('%Y%m%d',transactiondate) between vdt_mth and vdt_id and inj_sales_price>0
	and date(prc_dt) <= date(vdt_id + interval 1 day)
) a
inner join
(
  select date(actvn_dt) actvn_dt, msisdn
  from `data-dtp-prd-aa1a.smy`.ar_cst_dly_smy
  where date(dt_id) = vdt_id --and lower(brand_sc_name) in ('im3','mentari') --Stop by Indra Maulana Ikhsan 20240821(HG Direction)
    and ifnull(cast(actvn_dt as string),'')!=''
    and date(actvn_dt)>=vdt_mth - interval 24 month
) b
  on a.msisdn=b.msisdn
where rk=1;

--- check outlet null (added voucher tag at 20230111)
create or replace table `data-bi-prd-935c.bi_stg`.tmp_inj_fdv_{{ vdt_id }}_tmp1 as
select a.msisdn, b.organization_id
from `data-bi-prd-935c.bi_stg`.tmp_inj_fdv_{{ vdt_id }} a
inner join
(
  select sno, organization_id
  from (
    select x.*, row_number() over(partition by sno order by dt_id desc, flag) as rk
    from (
      select serial_number sno, org_id organization_id, dt_id, 1 flag
      from `data-bi-prd-935c.bi_mart`.vo_tag_outlet_mth
      where month_id=vdt_mth and ifnull(org_id,'')!=''
      union all
      select sno, organization_id, dt_sellin dt_id, 2 flag
      from `data-bi-prd-935c.bi_mart`.foss_vo_ori_sellin_mth
      where mth_id=vdt_mth and ifnull(organization_id,'')!=''
    ) x
  ) x
  where rk=1
) b
  on a.sno=b.sno
where ifnull(a.organization_id,'')='' or regexp_contains(a.organization_id,"^[0-9]+$")=False
;


--- join month temp with check outlet null
create or replace table `data-bi-prd-935c.bi_stg`.tmp_inj_fdv_{{ vdt_id }}_tmp2 as
select a.msisdn, a.actvn_dt
  , case when a.msisdn=b.msisdn then b.organization_id else a.organization_id end organization_id
  , a.product_name, a.amount_debit, a.main_price, a.sno, a.dt_id
from `data-bi-prd-935c.bi_stg`.tmp_inj_fdv_{{ vdt_id }} a
left join `data-bi-prd-935c.bi_stg`.tmp_inj_fdv_{{ vdt_id }}_tmp1 b
  on a.msisdn=b.msisdn
;

--- final table
delete from `data-bi-prd-935c.bi_mart`.first_inj_vo_mth where mth_id = vdt_mth;
insert into `data-bi-prd-935c.bi_mart`.first_inj_vo_mth 
select msisdn, actvn_dt, organization_id, product_name, amount_debit, main_price, sno, inj_dt, timestamp(current_datetime('+7')) ppn_dttm, vdt_mth mth_id
from
(
  select a.*, row_number() over(partition by msisdn order by actvn_dt desc, inj_dt, amount_debit desc) rk
  from
  (
    select msisdn, actvn_dt, organization_id, product_name, amount_debit, main_price, sno, inj_dt
    from `data-bi-prd-935c.bi_mart`.first_inj_vo_mth
    where mth_id=vdt_mth - interval 1 month
      and actvn_dt>=vdt_mth - interval 24 month
      and inj_dt>=vdt_mth - interval 12 month
    union all
    select g.msisdn, g.actvn_dt, g.organization_id, g.product_name, g.amount_debit, g.main_price, g.sno, dt_id
    from `data-bi-prd-935c.bi_stg`.tmp_inj_fdv_{{ vdt_id }}_tmp2 g
    left join `data-bi-prd-935c.bi_mart`.first_inj_vo_mth h
      on g.msisdn=h.msisdn and g.actvn_dt=h.actvn_dt and h.mth_id=vdt_mth - interval 1 month
			where h.msisdn is null
  ) a
) x
where rk=1
;

drop table if exists `data-bi-prd-935c.bi_stg`.tmp_inj_fdv_{{ vdt_id }};
drop table if exists `data-bi-prd-935c.bi_stg`.tmp_inj_fdv_{{ vdt_id }}_tmp1;
drop table if exists `data-bi-prd-935c.bi_stg`.tmp_inj_fdv_{{ vdt_id }}_tmp2;


