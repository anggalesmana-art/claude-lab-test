declare vdt_id date default @vdt_id;

--- FEE
create or replace table `data-bi-prd-935c.bi_mart`.tmp_imkas_trx_fee_{{ vdt_id }} as
select date(dt_id) dt_id, no_rekening
  , case
    when no_alt like '0%' then  regexp_replace(no_alt, '^0','62')
    when no_alt like '8%' then concat('62',no_alt)
  end msisdn
  , kode_transaksi
  , 'FEE' grp
  , case
    when kode_transaksi = 'TFL' then 'FEE - CASHOUT ATMB'
    when kode_transaksi = 'TFOG' then 'FEE - BILL PAYMENT TAG'
    when kode_transaksi = 'TFQ' then 'FEE - CASHOUT QRIS PAYMENT'
    when kode_transaksi = 'TFTFB' then 'FEE - CASHOUT BCA'
  end category
  , no_referensi
  , sum(coalesce(debet,0)) as amount
  , count(1) hits
from `data-dtp-prd-aa1a.stg`.imkas_dtl_transaction
where date(dt_id) = vdt_id
  and d_c = 'D'
  and kode_transaksi in ('TFL','TFOG','TFQ','TFTFB')
  and length(no_rekening) > 0
group by 1,2,3,4,5,6,7
;