declare vdt_id date default @vdt_id;

--- BULK TOPUP
create or replace table `data-bi-prd-935c.bi_mart`.tmp_imkas_trx_topup_{{ vdt_id }} as
select date(dt_id) dt_id, no_rekening
  , case
    when no_alt like '0%' then  regexp_replace(no_alt, '^0','62')
    when no_alt like '8%' then concat('62',no_alt)
  end msisdn
  , kode_transaksi
  , 'TOPUP' grp
  , case
    when keterangan = 'Topup dari VA Bank|BCA' then 'TOPUP - BCA'
    when upper(keterangan) like '%ATMB%' then 'TOPUP - ATMB'
    when upper(keterangan) like '%MANDIRI%' then 'TOPUP - MANDIRI'
    when upper(keterangan) like '%ALFAMART%' then 'TOPUP - ALFA'
    else keterangan
  end category
  , sum(coalesce(kredit,0)) as amount
  , count(1) hits
from `data-dtp-prd-aa1a.stg`.imkas_dtl_transaction
where date(dt_id) = vdt_id
    and d_c = 'C'
    and kode_transaksi = 'SL'
    and length(no_rekening) > 0
group by 1,2,3,4,5,6
;