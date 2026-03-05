declare vdt_id date default @vdt_id;

--- REVERSAL
create or replace table `data-bi-prd-935c.bi_mart`.tmp_imkas_trx_reversal_{{ vdt_id }} as
select date(dt_id) dt_id, no_rekening
  , case
    when no_alt like '0%' then  regexp_replace(no_alt, '^0','62')
    when no_alt like '8%' then concat('62',no_alt)
  end msisdn
  , kode_transaksi
  , 'REVERSAL' grp
  , case
    when kode_transaksi = 'RTBI' then 'REVERSAL - MYIM3 BILL PAYMENT'
    when kode_transaksi = 'RTDGB' then 'REVERSAL - BILL PAYMENT DATAGIFT'
    when kode_transaksi = 'RTFL' then 'REVERSAL - FEE CASHOUT ATMB'
    when kode_transaksi = 'RTFOG' then 'REVERSAL - FEE BILL PAYMENT TAG'
    when kode_transaksi = 'RTFQ' then 'REVERSAL - FEE CASHOUT QRIS PAYMENT'
    when kode_transaksi = 'RTFTFB' then 'REVERSAL - FEE CASHOUT BCA'
    when kode_transaksi = 'RTL' then 'REVERSAL - CASHOUT ATMB'
    when kode_transaksi = 'RTOG' then 'REVERSAL - BILL PAYMENT TAG'
    when kode_transaksi = 'RTQ' then 'REVERSAL - CASHOUT QRIS PAYMENT'
    when kode_transaksi = 'RTRFB' then 'REVERSAL - CASHOUT BCA'
  end category
  , no_referensi
  , sum(coalesce(kredit,0)) amount
  , count(1) hits
from `data-dtp-prd-aa1a.stg`.imkas_dtl_transaction
where date(dt_id) = vdt_id
  and kode_transaksi like 'R%'
  and length(no_rekening) > 0
group by 1,2,3,4,5,6,7
;