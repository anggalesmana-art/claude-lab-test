--Script Migrated by Indra Maulana Ikhsan 20241120
--- Voucher Original
declare vdt_id date default @vdt_id;
DROP TABLE IF EXISTS `data-bi-prd-935c.bi_mart`.tmp_rgu_vori_{{ vdt_id }} ;
create table `data-bi-prd-935c.bi_mart`.tmp_rgu_vori_{{ vdt_id }}  as
select case when substr(pm_red_msisdn,1,2)!='62' then concat('62',pm_red_msisdn) else pm_red_msisdn end msisdn, sum(inj_sales_price) rev_vori
from `data-dtp-prd-aa1a.smy.smy_dv_redemption`
where 
date(prc_dt) <= date_sub(vdt_id ,interval 1 day)
and transactiondate = '{{ vdt_id }}'
  and inj_sales_price>0
  and pm_voucher_status='U'
group by 1;
