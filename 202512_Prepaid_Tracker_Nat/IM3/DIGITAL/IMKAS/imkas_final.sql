declare vdt_id date default @vdt_id;

--- insert to master table
delete from `data-bi-prd-935c.bi_mart`.imkas_trx_dly where dt_id = vdt_id;
insert into `data-bi-prd-935c.bi_mart`.imkas_trx_dly 
select no_rekening, msisdn
  , reg_dt as dt_reg
  , date_diff(dt_id,reg_dt,day) tnr
  , kode_transaksi, grp, category
  , amount, hits
  , timestamp(current_datetime('+7')) ppn_dttm
  , dt_id
from `data-bi-prd-935c.bi_mart`.tmp_imkas_trx_{{ vdt_id }} a
left join
(
  select distinct date(timestamp(tgl_register)) reg_dt, norek_digibank
  from `data-dtp-prd-aa1a.stg`.imkas_dtl_subscription
  where date(dt_id)=vdt_id
    and length(norek_digibank) > 0
) b
  on a.no_rekening=b.norek_digibank
;

--- drop temp table
drop table if exists `data-bi-prd-935c.bi_mart`.tmp_imkas_trx_bt_{{ vdt_id }};
drop table if exists `data-bi-prd-935c.bi_mart`.tmp_imkas_trx_topup_{{ vdt_id }};
drop table if exists `data-bi-prd-935c.bi_mart`.tmp_imkas_trx_reversal_{{ vdt_id }};
drop table if exists `data-bi-prd-935c.bi_mart`.tmp_imkas_trx_cashout_{{ vdt_id }};
drop table if exists `data-bi-prd-935c.bi_mart`.tmp_imkas_trx_ottoagg_{{ vdt_id }};
drop table if exists `data-bi-prd-935c.bi_mart`.tmp_imkas_trx_myim3_bill_{{ vdt_id }};
drop table if exists `data-bi-prd-935c.bi_mart`.tmp_imkas_trx_fee_{{ vdt_id }};
drop table if exists `data-bi-prd-935c.bi_mart`.tmp_imkas_trx_p2pa_{{ vdt_id }};
drop table if exists `data-bi-prd-935c.bi_mart`.tmp_imkas_trx_p2pb_{{ vdt_id }};
drop table if exists `data-bi-prd-935c.bi_mart`.tmp_imkas_trx_money_out_{{ vdt_id }};
drop table if exists `data-bi-prd-935c.bi_mart`.tmp_imkas_trx_{{ vdt_id }};