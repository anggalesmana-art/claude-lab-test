declare vdt_id date default @vdt_id;

--- BILL PAYMENT
create or replace table `data-bi-prd-935c.bi_mart`.tmp_imkas_trx_ottoagg_{{ vdt_id }} as
select date(dt_id) dt_id, no_rekening
  , case
    when no_alt like '0%' then  regexp_replace(no_alt, '^0','62')
    when no_alt like '8%' then concat('62',no_alt)
  end msisdn
  , kode_transaksi
  , 'BILL PAYMENT' grp
  , case
    when kode_transaksi = 'TDGB' then 'BILL PAYMENT - DATAGIFT'
    when kode_transaksi = 'TBS' then 'BILL PAYMENT - DONASI'
    when kode_transaksi = 'TIV' then 'BILL PAYMENT - INVESTMENT'
    when kode_transaksi = 'TIS' then 'BILL PAYMENT - INSURANCE'
    when product_code in ('BLVGAFF','BLVGAML','BYBPJS','ELECTRICITY_POST_PAID','ELECTRICITY_PRE_PAID','MULTIFINANCE','TELKOM_BILL','WATER_BILL','MOBILE_POST_PAID') then concat('BILL PAYMENT - TAG ', product_code)
    when product_code = 'MOBILE_PRE_PAID' and lower(keterangan) like '%pulsa%' and lower(keterangan) like '%indosat%' then 'BILL PAYMENT - TAG PULSA ISAT'
    when product_code = 'MOBILE_PRE_PAID' and lower(keterangan) like '%0814%' then 'BILL PAYMENT - TAG DATA ISAT'
    when product_code = 'MOBILE_PRE_PAID' and lower(keterangan) like '%0815%' then 'BILL PAYMENT - TAG DATA ISAT'
    when product_code = 'MOBILE_PRE_PAID' and lower(keterangan) like '%0816%' then 'BILL PAYMENT - TAG DATA ISAT'
    when product_code = 'MOBILE_PRE_PAID' and lower(keterangan) like '%0855%' then 'BILL PAYMENT - TAG DATA ISAT'
    when product_code = 'MOBILE_PRE_PAID' and lower(keterangan) like '%0856%' then 'BILL PAYMENT - TAG DATA ISAT'
    when product_code = 'MOBILE_PRE_PAID' and lower(keterangan) like '%0857%' then 'BILL PAYMENT - TAG DATA ISAT'
    when product_code = 'MOBILE_PRE_PAID' and lower(keterangan) like '%0858%' then 'BILL PAYMENT - TAG DATA ISAT'
    when product_code = 'MOBILE_PRE_PAID' and lower(keterangan) like '%0859%' then 'BILL PAYMENT - TAG DATA ISAT'
    when product_code = 'MOBILE_PRE_PAID' and lower(keterangan) like '%pulsa%' then 'BILL PAYMENT - TAG PULSA OTHER'
    when product_code = 'MOBILE_PRE_PAID' then 'BILL PAYMENT - TAG DATA OTHER'
    when keterangan = 'Pembayaran PLN Postpaid' then 'BILL PAYMENT - TAG ELECTRICITY POSTPAID'
    when lower(keterangan) like '%token%' then 'BILL PAYMENT - TAG ELECTRICITY PREPAID'
    else concat('BILL PAYMENT - ', product_code)
  end category
  , no_referensi
  , sum(coalesce(debet,0)) as amount
  , count(1) hits
from `data-dtp-prd-aa1a.stg`.imkas_dtl_transaction a
where date(dt_id) = vdt_id
  and d_c = 'D'
  and kode_transaksi IN ( 'TOG','TDGB','TBS','TIV','TIS')
  and length(no_rekening) > 0
group by 1,2,3,4,5,6,7
;
