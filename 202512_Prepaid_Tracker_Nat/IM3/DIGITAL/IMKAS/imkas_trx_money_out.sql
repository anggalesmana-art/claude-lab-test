declare vdt_id date default @vdt_id;

--- Money Out
create or replace table `data-bi-prd-935c.bi_mart`.tmp_imkas_trx_money_out_{{ vdt_id }} as
select a.dt_id, a.no_rekening, a.msisdn, a.kode_transaksi, a.grp, a.category, sum(a.amount) amount, sum(a.hits) hits
from
(
  select * from `data-bi-prd-935c.bi_mart`.tmp_imkas_trx_cashout_{{ vdt_id }} union all
  select * from `data-bi-prd-935c.bi_mart`.tmp_imkas_trx_ottoagg_{{ vdt_id }} union all
  select * from `data-bi-prd-935c.bi_mart`.tmp_imkas_trx_myim3_bill_{{ vdt_id }} union all
  select * from `data-bi-prd-935c.bi_mart`.tmp_imkas_trx_fee_{{ vdt_id }}
) a
left join `data-bi-prd-935c.bi_mart`.tmp_imkas_trx_reversal_{{ vdt_id }} b
  on a.no_rekening=b.no_rekening and concat('R',a.kode_transaksi)=b.kode_transaksi and a.no_referensi=b.no_referensi and a.dt_id=b.dt_id where b.kode_transaksi is null
group by 1,2,3,4,5,6
;