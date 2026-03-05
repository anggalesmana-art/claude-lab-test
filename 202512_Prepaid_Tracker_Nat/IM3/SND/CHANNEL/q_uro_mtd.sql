declare vdt_id date default @vdt_id;

--temp tagging vo salmo
create or replace table `data-bi-prd-935c.bi_stg`.tmp_inj_vo_salmo_{{ vdt_id }} as
select voucher_sn, channel, organization_id, product_name, amount_debit, main_price, dt_id
from (
select bill_number voucher_sn, channel, organization_id, product_name, amount_debit, main_price, dt_id,
row_number() over(partition by bill_number
      , case
        when lower(channel) in ('direct') then 'DSF'
        when lower(channel) in ('traditional') then 'Traditional'
        else 'modern' end
     order by completion_date desc, amount_debit desc) rn
from `data-bi-prd-935c.bi_mart`.sellout_salmo_dly
  where dt_id between date_trunc(vdt_id,month) and vdt_id
    and lower(transaction_type) like '%voucher%'
) a
where rn=1
;

--temp tagging vo tag
create or replace table `data-bi-prd-935c.bi_stg`.tmp_inj_vo_tag_{{ vdt_id }} as
select serial_number,organization_id,date(dt_id) dt_id,dt_time
from (
select serial_number, id_outlet organization_id,dt_id,`datetime` dt_time,
row_number() over(partition by serial_number order by `datetime` desc) rn
from `data-dtp-prd-aa1a.stg`.mobo_indosat_voucher_tagging
where date(dt_id) between date_trunc(vdt_id,month) and vdt_id) a
where rn=1;

--temp tagging vo ori
create or replace table `data-bi-prd-935c.bi_stg`.tmp_inj_vo_ori_tag_{{ vdt_id }} as
select sno,organization_id,dt_sellin dt_id,'SELLIN' tag_type
from `data-bi-prd-935c.bi_mart`.foss_vo_ori_sellin_mth
where mth_id=date_trunc(vdt_id,month)
and organization_id is not null
;

--temp table tagging mtd
create or replace table `data-bi-prd-935c.bi_stg`.tmp_vo_tagging_{{ vdt_id }} as
select sno,organization_id,dt_id,tag_type,date_trunc(vdt_id,month) mth_id
from (
select sno,organization_id,dt_id,tag_type,row_number() over(partition by sno order by dt_id desc nulls last) rn
from (
select sno,organization_id,dt_id,tag_type
from `data-bi-prd-935c.bi_stg`.tmp_inj_vo_ori_tag_{{ vdt_id }}
union all
select serial_number,organization_id,dt_id,'TAGGING' tag_type
from `data-bi-prd-935c.bi_stg`.tmp_inj_vo_tag_{{ vdt_id }}
union all
select voucher_sn,organization_id,dt_id,'INJECT' tag_type
from `data-bi-prd-935c.bi_stg`.tmp_inj_vo_salmo_{{ vdt_id }}) a) a
where rn=1;

--insert vo tagging
delete from `data-bi-prd-935c.bi_mart`.vo_tagging where mth_id = date_trunc(vdt_id,month);
insert into `data-bi-prd-935c.bi_mart`.vo_tagging
select sno,organization_id,dt_id,tag_type, date_trunc(vdt_id,month) mth_id
from (
select sno,organization_id,dt_id,tag_type,row_number() over(partition by sno order by dt_id desc nulls last) rn
from (
select * from `data-bi-prd-935c.bi_mart`.vo_tagging
where mth_id=date_trunc(vdt_id - interval 1 month,month)
union all
select * from `data-bi-prd-935c.bi_stg`.tmp_vo_tagging_{{ vdt_id }}) a) a
where rn=1;

--with FDV
--updated 202209 with voucher tagging
delete from `data-bi-prd-935c.bi_mart`.seratus_uro_inject_detail_trx_fdv where dt_id between date_trunc(vdt_id,month) and vdt_id;
insert into `data-bi-prd-935c.bi_mart`.seratus_uro_inject_detail_trx_fdv
select a.organization_id,b_msisdn,trx_type,amount_debit,main_price,a.transaction_id,
case when a.b_msisdn=b.msisdn and a.transaction_id=b.transaction_id then 'NEW' else 'OLD' end flag_sp,a.dt_id
from
(select dt_id,organization_id,b_msisdn,'SP' trx_type,cast(amount_debit as numeric) amount_debit,cast(main_price as numeric) main_price,
transaction_id
from `data-bi-prd-935c.bi_mart`.sellout_salmo_dly
where dt_id between date_trunc(vdt_id,month)
and vdt_id and (lower(transaction_type) like '%package%' or lower(transaction_type) like '%reload%')
and lower(channel)='traditional'
union all
select date(transactiondate),b.organization_id,concat('62',pm_red_msisdn) b_msisdn,'VOUCHER' trx_type,mobo_inj_sales_price,mobo_inj_main_price,
mobo_trx_id
from `data-dtp-prd-aa1a.sor`.fdv_mobo_pm_join_match a
left join (select sno,organization_id from `data-bi-prd-935c.bi_mart`.vo_tagging
where mth_id=date_trunc(vdt_id,month)) b
on a.pm_voucher_sn=b.sno
where date(transactiondate) between date_trunc(vdt_id,month)
and vdt_id and category='MOBO' and pm_voucher_status = 'U'
and substring(concat('62',pm_red_msisdn), 1,5) in ('62857','62858','62856','62815','62816','62855','62814')
--and substr(case when substr(pm_red_msisdn,1,2)!='62' then concat('62',pm_red_msisdn) else pm_red_msisdn end,1,5) in ('62857','62858','62856','62815','62816','62855','62814')
union all
select date(transactiondate),b.organization_id,concat('62',pm_red_msisdn) b_msisdn,'VOUCHER RLD' trx_type,mobo_inj_sales_price,mobo_inj_main_price,
mobo_trx_id
from `data-dtp-prd-aa1a.sor`.fdv_mobo_pm_join_match_reload a
left join (select sno,organization_id from `data-bi-prd-935c.bi_mart`.vo_tagging
where mth_id=date_trunc(vdt_id,month)) b
on a.pm_voucher_sn=b.sno
where date(transactiondate) between date_trunc(vdt_id,month)
and vdt_id and category='MOBO' and pm_voucher_status = 'U'
union all
select parse_date('%Y%m%d',transactiondate),b.organization_id,concat('62',pm_red_msisdn) b_msisdn,'VOUCHER ORI' trx_type,
inj_sales_price,inj_main_price,inj_trx_id
from `data-dtp-prd-aa1a.smy`.smy_dv_redemption a
join (select sno,organization_id from `data-bi-prd-935c.bi_mart`.vo_tagging
where mth_id=date_trunc(vdt_id,month)) b
on a.pm_voucher_sn=b.sno
where parse_date('%Y%m%d',transactiondate) between date_trunc(vdt_id,month) and vdt_id and pm_voucher_status = 'U'
and prc_dt = timestamp(vdt_id + interval 1 day)) a
left join 
(select msisdn,organization_id,transaction_id from `data-bi-prd-935c.bi_mart`.first_inj_mth
where mth_id=date_trunc(vdt_id,month)) b on a.b_msisdn=b.msisdn and a.transaction_id=b.transaction_id
join (select outlet_code from `data-dtp-prd-aa1a.stg`.mobi_master_hierarchy_feed
where dt_id between timestamp(vdt_id - interval 30 day)
and timestamp(vdt_id + interval 1 day) and channel='Traditional' group by 1) c on a.organization_id=c.outlet_code;

DROP TABLE IF EXISTS `data-bi-prd-935c.bi_stg`.tmp_inj_vo_salmo_{{ vdt_id }};
DROP TABLE IF EXISTS `data-bi-prd-935c.bi_stg`.tmp_inj_vo_tag_{{ vdt_id }};
DROP TABLE IF EXISTS `data-bi-prd-935c.bi_stg`.tmp_inj_vo_ori_tag_{{ vdt_id }};
DROP TABLE IF EXISTS `data-bi-prd-935c.bi_stg`.tmp_vo_tagging_{{ vdt_id }};