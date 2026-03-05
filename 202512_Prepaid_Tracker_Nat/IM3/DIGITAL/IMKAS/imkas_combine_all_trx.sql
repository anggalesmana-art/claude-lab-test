declare vdt_id date default @vdt_id;

--- Combine all trx
drop table if exists `data-bi-prd-935c.bi_mart`.tmp_imkas_trx_{{ vdt_id }};
create or replace table `data-bi-prd-935c.bi_mart`.tmp_imkas_trx_{{ vdt_id }} as
select * from `data-bi-prd-935c.bi_mart`.tmp_imkas_trx_bt_{{ vdt_id }} union all
select * from `data-bi-prd-935c.bi_mart`.tmp_imkas_trx_topup_{{ vdt_id }} union all
select * from `data-bi-prd-935c.bi_mart`.tmp_imkas_trx_p2pa_{{ vdt_id }} union all
select * from `data-bi-prd-935c.bi_mart`.tmp_imkas_trx_p2pb_{{ vdt_id }} union all
select * from `data-bi-prd-935c.bi_mart`.tmp_imkas_trx_money_out_{{ vdt_id }} union all
select dt_id, no_rekening, msisdn, kode_transaksi, grp, category, sum(amount) amount, sum(hits) hits
from `data-bi-prd-935c.bi_mart`.tmp_imkas_trx_reversal_{{ vdt_id }}
group by 1,2,3,4,5,6
;