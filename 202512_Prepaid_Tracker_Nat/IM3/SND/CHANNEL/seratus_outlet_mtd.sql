declare vdt_id date default @vdt_id;

-- SERATUS SECONDARY OUTLET
delete from `data-bi-prd-935c.bi_mart`.seratus_sellin_outlet_detail where dt_id between date_trunc(vdt_id,month) and vdt_id;
insert into `data-bi-prd-935c.bi_mart`.seratus_sellin_outlet_detail
select b.site_id,a.credit_party_id organization_id,sum(amount) amt,a.dt_id
from
(select * from `data-bi-prd-935c.bi_mart`.fact_snd_secondary
where dt_id between date_trunc(vdt_id,month) and vdt_id) a
left join (select * from
(select site_id,area,sales_area,sales_cluster,micro_cluster,organization_id,organization_name,
ROW_NUMBER() OVER (partition by organization_id ORDER BY dt_id desc NULLS Last) AS rn
from `data-bi-prd-935c.bi_mart`.outlet_loc_ns
where dt_id between date_trunc(vdt_id,month) and vdt_id) a
where rn=1) b on a.credit_party_id=b.organization_id
group by 1,2,4;

--TERTIARY SITEWISE
delete from `data-bi-prd-935c.bi_mart`.seratus_tertiary_outlet where dt_id between date_trunc(vdt_id,month) and vdt_id;
insert into `data-bi-prd-935c.bi_mart`.seratus_tertiary_outlet
select b.site_id,a.organization_id,sum(amount_debit) amt,a.dt_id
from
(select * from `data-bi-prd-935c.bi_mart`.fact_snd_tertiary
where dt_id between date_trunc(vdt_id,month) and vdt_id) a
left join (select * from
(select site_id,area,sales_area,sales_cluster,micro_cluster,organization_id,organization_name,
ROW_NUMBER() OVER (partition by organization_id ORDER BY dt_id desc NULLS Last) AS rn
from `data-bi-prd-935c.bi_mart`.outlet_loc_ns
where dt_id between date_trunc(vdt_id,month) and vdt_id) a
where rn=1) b on a.organization_id=b.organization_id
group by 1,2,4;

--- URO DETAIL 20230529
delete from `data-bi-prd-935c.bi_mart`.seratus_uro_inject_detail where dt_id between date_trunc(vdt_id,month) and vdt_id;
insert into `data-bi-prd-935c.bi_mart`.seratus_uro_inject_detail
select b.site_id,a.organization_id,sum(amount_debit) amt,sum(main_price) main_price,count(1) hits,product_name,trx_type,a.dt_id
from
(select dt_id,organization_id,product_name,
case when lower(transaction_type) like '%package%' then 'MOBO Package'
when lower(transaction_type) like '%reload%' then 'MOBO Reload' end trx_type,
cast(amount_debit as numeric) amount_debit,cast(main_price as numeric) main_price
from `data-bi-prd-935c.bi_mart`.sellout_salmo_dly --ifrs
where dt_id between date_trunc(vdt_id,month) and vdt_id
and (lower(transaction_type) like '%package%' or lower(transaction_type) like '%reload%') and lower(channel)='traditional'
union all
select date(transactiondate),mobo_inj_outlet_id,mobo_inj_pack_name,'FDV Redeem' trx_type,mobo_inj_sales_price,mobo_inj_main_price
from `data-dtp-prd-aa1a.sor`.fdv_mobo_pm_join_match
where date(transactiondate) between date_trunc(vdt_id,month) and vdt_id
and category='MOBO' and pm_voucher_status = 'U'
and substring(concat('62',pm_red_msisdn), 1,5) in ('62857','62858','62856','62815','62816','62855','62814')
--and substr(case when substr(pm_red_msisdn,1,2)!='62' then concat('62',pm_red_msisdn) else pm_red_msisdn end,1,5) in ('62857','62858','62856','62815','62816','62855','62814')
union all
select date(transactiondate),mobo_inj_outlet_id,mobo_inj_pack_name,'FDV Reload' trx_type,mobo_inj_sales_price,mobo_inj_main_price
from `data-dtp-prd-aa1a.sor`.fdv_mobo_pm_join_match_reload
where date(transactiondate) between date_trunc(vdt_id,month) and vdt_id
and category='MOBO' and pm_voucher_status = 'U'
union all
select parse_date('%Y%m%d',transactiondate),inj_outlet_id,inj_pack_name,'Voucher Ori' trx_type,inj_sales_price,inj_main_price
from `data-dtp-prd-aa1a.smy`.smy_dv_redemption
where parse_date('%Y%m%d',transactiondate) between date_trunc(vdt_id,month) and vdt_id and prc_dt between timestamp(date_trunc(vdt_id,month)+interval 1 day) and timestamp(vdt_id + interval 1 day)
and pm_voucher_status = 'U'
union all
select inj_dt,organization_id,product_name,'SP Ori' trx_type,amount_debit,main_price 
from `data-bi-prd-935c.bi_mart`.first_inj_sp_data_mth
where mth_id=date_trunc(vdt_id,month) and inj_dt between date_trunc(vdt_id,month) and vdt_id
and REGEXP_CONTAINS(organization_id, r'^[0-9]+$')) a
left join (select * from
(select site_id,area,sales_area,sales_cluster,micro_cluster,organization_id,organization_name,
ROW_NUMBER() OVER (partition by organization_id ORDER BY dt_id desc nulls last) AS rn
from `data-bi-prd-935c.bi_mart`.outlet_loc_ns
where dt_id between date_trunc(vdt_id,month) and vdt_id) a
where rn=1) b on a.organization_id=b.organization_id
join (select outlet_code from `data-dtp-prd-aa1a.stg`.mobi_master_hierarchy_feed
where dt_id between timestamp(vdt_id - interval 30 day) and timestamp(vdt_id + interval 1 day)
and channel='Traditional' group by 1) d on a.organization_id=d.outlet_code
group by 1,2,6,7,8;

--- DSO DETAIL
delete from `data-bi-prd-935c.bi_mart`.seratus_dso_inject_detail where dt_id between date_trunc(vdt_id,month) and vdt_id;
insert into `data-bi-prd-935c.bi_mart`.seratus_dso_inject_detail
select b.site_id,a.organization_id,sum(cast(amount_debit as numeric)) amt,a.dt_id
from
(select * from `data-bi-prd-935c.bi_mart`.sellout_salmo_dly
where dt_id between date_trunc(vdt_id,month) and vdt_id and lower(channel)='traditional'
and (lower(product_name) like '%internet%' or lower(product_name) like '%freedom%' or lower(product_name) like '%combo%' or
lower(product_name) like '%yellow%' or lower(product_name) like '%unlimited%' or lower(product_name) like '%gb%')) a
left join (select * from
(select site_id,area,sales_area,sales_cluster,micro_cluster,organization_id,organization_name,
ROW_NUMBER() OVER (partition by organization_id ORDER BY dt_id desc nulls last) AS rn
from `data-bi-prd-935c.bi_mart`.outlet_loc_ns
where dt_id between date_trunc(vdt_id,month) and vdt_id) a
where rn=1) b on a.organization_id=b.organization_id
join (select outlet_code from `data-dtp-prd-aa1a.stg`.mobi_master_hierarchy_feed
where dt_id between timestamp(vdt_id - interval 30 day) and timestamp(vdt_id) and channel='Traditional' group by 1) d on a.organization_id=d.outlet_code
group by 1,2,4;

--- VSO DETAIL
delete from `data-bi-prd-935c.bi_mart`.seratus_vso_inject_detail where dt_id between date_trunc(vdt_id,month) and vdt_id;
insert into `data-bi-prd-935c.bi_mart`.seratus_vso_inject_detail
select b.site_id,a.organization_id,sum(cast(amount_debit as numeric)) amt,a.dt_id
from
(select * from `data-bi-prd-935c.bi_mart`.sellout_salmo_dly
where dt_id between date_trunc(vdt_id,month) and vdt_id and lower(channel)='traditional' and lower(transaction_type) in ('vouchercardinjection','bulk voucher card injection')) a
left join (select * from
(select site_id,area,sales_area,sales_cluster,micro_cluster,organization_id,organization_name,
ROW_NUMBER() OVER (partition by organization_id ORDER BY dt_id desc nulls last) AS rn
from `data-bi-prd-935c.bi_mart`.outlet_loc_ns
where dt_id between date_trunc(vdt_id,month) and vdt_id) a
where rn=1) b on a.organization_id=b.organization_id
join (select outlet_code from `data-dtp-prd-aa1a.stg`.mobi_master_hierarchy_feed
where dt_id between timestamp(vdt_id - interval 30 day) and timestamp(vdt_id) and channel='Traditional' group by 1) d on a.organization_id=d.outlet_code
group by 1,2,4;

