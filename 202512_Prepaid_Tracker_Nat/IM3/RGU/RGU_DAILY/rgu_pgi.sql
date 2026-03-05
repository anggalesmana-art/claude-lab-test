--Script Migrated by Indra Maulana Ikhsan 20241120
--- PGI
declare vdt_id date default @vdt_id;
create or replace table `data-bi-prd-935c.bi_mart`.tmp_rgu_pgi_{{ vdt_id }}  as
select msisdn, sum(rev_pgi) rev_pgi
from
(
  -- PGI
  SELECT msisdn, cast(amount as numeric) rev_pgi
  FROM `data-dtp-prd-aa1a.stg.myim3_payment_aj_report`
  WHERE date(dt_id) = vdt_id
	AND lower(trim(jenis_transaksi)) = 'package'
	AND lower(trim(status_fulfillment)) = 'success'
	AND cast(amount as numeric) > 0
  union all
  -- E-Wallet
  SELECT msisdn, CAST(amount AS numeric) rev_ewallet
  FROM `data-dtp-prd-aa1a.sor.transactiondaily_esb`
  WHERE date(dt_id) = vdt_id
    and upper(trim(payment_type)) = 'PUSH TO PAY (PTP)'
    AND lower(status) LIKE '%success%'
    AND upper(esb_channel) NOT LIKE '%3ID%'
    AND upper(trim(esb_channel)) not in ('DPP-ISIMPLE','WEBSITE')
    AND lower(product_name) NOT LIKE '%hifi%'
    AND lower(product_name) NOT LIKE '%top%up%'
    AND lower(product_name) NOT LIKE '%postpaid%bill%payment%'
    AND CAST(amount AS numeric) > 0
  union all
  -- PGI WA
  SELECT msisdn, cast(amount as numeric) rev_wa
  from `data-dtp-prd-aa1a.stg.chatbot_wa`
  where parse_date('%Y%m%d',dt_id) = vdt_id
    and date(load_dt) between vdt_id and  date(vdt_id+interval 3 day)
    and trim(kode_product) = '1101161'
    and cast(amount as numeric)>0
  union all
  -- OLA
  -- SELECT msisdn, cast(package_price as numeric) rev_ola
  -- from `data-dtp-prd-aa1a.stg.ola_transactions`
  -- where date(dt_id) = vdt_id
  --   and upper(trim(produk)) = 'PREPAID'
  --   and trim(paket_data) != '-'
  --   and cast(package_price as numeric) > 0
    select msisdn, rev_ola
  from (
  select msisdn, cast(package_price as numeric) rev_ola, dt_id, tanggal
    , row_number() over(partition by msisdn order by dt_id desc nulls last) as rk
  from `data-analytics-prd-1b95.digital_sbx`.gt_ola_all_sales
  where dt_id between current_timestamp() - interval 1 day and current_timestamp
    and safe.parse_date('%Y%m%d',tanggal) = vdt_id
    and cast(package_price as numeric)>0) a 
    where rk=1
) x
group by 1
;