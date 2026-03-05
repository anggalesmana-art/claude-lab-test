declare vdt_id date default @vdt_id;
--===============================================================================================--
-- TERTIARY 
--===============================================================================================--


--TERTIARY RELOAD
delete from `data-bi-prd-935c.bi_mart`.fact_snd_tertiary where tertiary_type = 'RELOAD' and dt_id = vdt_id;
insert into `data-bi-prd-935c.bi_mart`.fact_snd_tertiary 
select organization_id,sum(cast(amount_debit as numeric)) amount_debit,sum(cast(main_price as numeric)) main_price,
count(transaction_id) hits,'RELOAD' tertiary_type,dt_id
from `data-bi-prd-935c.bi_mart`.sellout_salmo_dly
where dt_id=vdt_id and lower(transaction_type) like '%reload%'
and lower(channel) in ('traditional','direct')
group by 1,5,6;

--TERTIARY VOU REDEMPTION
delete from `data-bi-prd-935c.bi_mart`.fact_snd_tertiary where tertiary_type = 'VOU REDEEM' and dt_id = vdt_id;
insert into `data-bi-prd-935c.bi_mart`.fact_snd_tertiary 
select mobo_inj_outlet_id,amount_debit,main_price,hits,tertiary_type,date(transactiondate)
from (select transactiondate,mobo_inj_outlet_id,'VOU REDEEM' tertiary_type,
case when a.mobo_inj_outlet_id=b.outlet_code or a.mobo_inj_outlet_id like 'SF%' then 'Traditional' else 'Others' end channel,
sum(mobo_inj_sales_price) amount_debit,sum(mobo_inj_main_price) main_price,
count(mobo_trx_id) hits
from `data-dtp-prd-aa1a.sor`.fdv_mobo_pm_join_match a
join (select outlet_code from `data-dtp-prd-aa1a.stg`.mobi_master_hierarchy_feed
where dt_id between timestamp(vdt_id - interval 30 day) and timestamp(vdt_id) and channel in ('Direct','Traditional')
group by 1) b on a.mobo_inj_outlet_id=b.outlet_code
where date(transactiondate)=vdt_id and category='MOBO' and pm_voucher_status = 'U'
and substring(concat('62',pm_red_msisdn), 1,5) in ('62857','62858','62856','62815','62816','62855','62814')
--and substr(case when substr(pm_red_msisdn,1,2)!='62' then concat('62',pm_red_msisdn) else pm_red_msisdn end,1,5) in ('62857','62858','62856','62815','62816','62855','62814')
group by 1,2,3,4) a
where channel='Traditional';

--TERTIARY SP MOBO
delete from `data-bi-prd-935c.bi_mart`.fact_snd_tertiary where tertiary_type = 'SP MOBO' and dt_id = vdt_id;
insert into `data-bi-prd-935c.bi_mart`.fact_snd_tertiary 
select organizationid,amount_debit,main_price,hits,tertiary_type,parse_date('%Y%m%d',revenue_date)
from (select revenue_date,organizationid,'SP MOBO' tertiary_type,
case when a.organizationid=b.outlet_code or a.organizationid like 'SF%' then 'Traditional' else 'Others' end channel,
sum(cast(amount_debit as numeric)) amount_debit,sum(cast(mainprice as numeric)) main_price,count(transactionid) hits
from `data-dtp-prd-aa1a.sor`.mobo_revenue a
left join (select outlet_code from `data-dtp-prd-aa1a.stg`.mobi_master_hierarchy_feed
where dt_id between timestamp(vdt_id - interval 30 day) and timestamp(vdt_id) and channel in ('Direct','Traditional')
group by 1) b on a.organizationid=b.outlet_code
where parse_date('%Y%m%d',revenue_date)=vdt_id and prc_dt = timestamp(vdt_id + interval 1 day)
and substring(a.b_msisdn, 1,5) in ('62857','62858','62856','62815','62816','62855','62814')
group by 1,2,3,4) a
where lower(channel) in ('traditional','direct');


--TERTIARY VOUCHER PULSA
delete from `data-bi-prd-935c.bi_mart`.fact_snd_tertiary where tertiary_type = 'VOU RLD' and dt_id = vdt_id;
insert into `data-bi-prd-935c.bi_mart`.fact_snd_tertiary 
select mobo_inj_outlet_id organization_id,sum(mobo_inj_sales_price) amt,sum(mobo_inj_main_price) main_price,
count(pm_red_msisdn) hits,'VOU RLD' tertiary_type,date(transactiondate) dt_id
from `data-dtp-prd-aa1a.sor`.fdv_mobo_pm_join_match_reload
where date(transactiondate)=vdt_id and category='MOBO' and pm_voucher_status = 'U'
group by 1,5,6;


--TERTIARY SP DATA update 202308 with dealer allocation if no sellin
delete from `data-bi-prd-935c.bi_mart`.fact_snd_tertiary where tertiary_type in ('SP DATA','SP DATA ALLOC') and dt_id = vdt_id;
insert into `data-bi-prd-935c.bi_mart`.fact_snd_tertiary 
select coalesce(b.organization_id,c.dealer) organization_id,
sum(cast(a.amount_debit as numeric)) amount_debit,sum(cast(a.main_price as numeric)) main_price,count(a.msisdn) hits,
case when a.msisdn=b.msisdn then 'SP DATA' else 'SP DATA ALLOC' end tertiary_type,date(a.revenue_date) dt_id
from `data-dtp-prd-aa1a.sor`.sp_data_revenue a
left join (select * from `data-bi-prd-935c.bi_mart`.foss_sp_data_sellin_mth
where mth_id=date_trunc(vdt_id,month) and dt_sellin<=vdt_id
and organization_id<>'') b on a.msisdn=b.msisdn
left join (select msisdn,dealer from `data-bi-prd-935c.bi_mart`.foss_sp_mth
where mth_id=date_trunc(vdt_id,month) and dt_id<=vdt_id) c on a.msisdn=c.msisdn
where date(revenue_date)=vdt_id
group by 1,5,6;

--TERTIARY VOUCHER ORI update 202308 with dealer allocation if no sellin
delete from `data-bi-prd-935c.bi_mart`.fact_snd_tertiary where tertiary_type in ('VOU ORI','VOU ORI ALLOC') and dt_id = vdt_id;
insert into `data-bi-prd-935c.bi_mart`.fact_snd_tertiary 
select coalesce(b.organization_id,c.dealer) organization_id,
sum(cast(a.inj_sales_price as numeric)) amount_debit,sum(cast(a.inj_main_price as numeric)) main_price,
count(a.pm_voucher_sn) hits,
case when a.pm_voucher_sn=b.sno then 'VOU ORI' else 'VOU ORI ALLOC' end tertiary_type,parse_date('%Y%m%d',a.transactiondate) dt_id
from `data-dtp-prd-aa1a.smy`.smy_dv_redemption a
left join (select * from `data-bi-prd-935c.bi_mart`.foss_vo_ori_sellin_mth
where mth_id=date_trunc(vdt_id,month) and dt_sellin<=vdt_id) b on a.pm_voucher_sn=b.sno
left join (select sno,dealer from `data-bi-prd-935c.bi_mart`.foss_vo_mth
where mth_id=date_trunc(vdt_id,month) and dt_id<=vdt_id) c on a.pm_voucher_sn=c.sno
where parse_date('%Y%m%d',a.transactiondate)=vdt_id and pm_voucher_status='U' and a.prc_dt = timestamp(vdt_id + interval 1 day)
group by 1,5,6;

--TERTIARY SP ZERO start 220308
delete from `data-bi-prd-935c.bi_mart`.fact_snd_tertiary where tertiary_type = 'SP ZERO' and dt_id = vdt_id;
insert into `data-bi-prd-935c.bi_mart`.fact_snd_tertiary 
select a.destination organization_id,sum(b.amount) amt,sum(b.amount) main_price,
count(a.msisdn) hits,'SP ZERO' tertiary_type,dt_id
from `data-bi-prd-935c.bi_mart`.mobii_msisdn_mth a
join (
        select distinct msisdn, gross_amt as amount
        from `data-bi-prd-935c.bi_mart`.foss_sp_mth a
        join
        (
            select distinct
            sales_order, gross_price_perunit, round((safe_cast(net_sales_perunit as numeric)*1.11),0) gross_amt
            from `data-dtp-prd-aa1a.stg`.reference_zero
            where date(date_trunc(dt_id,month)) = date_trunc(vdt_id,month)
        ) b
            on split(a.po_number,'/')[offset(2)]  = b.sales_order
            where mth_id = date_trunc(vdt_id,month) and upper(program_name) like '%ZERO%'
     /*   
    select a.msisdn
    from biadm.omn_foss_sp_mth a
    left anti join (select ext_product_id from biadm.omn_ref_sp_vou_ori group by 1) b
    on a.program_code=b.ext_product_id
    where mth_id=substr('${var:dt_id}',1,6)
    */
    ) b 
on a.msisdn=b.msisdn
left join (select * from
(select site_id,region,area,sales_area,sales_cluster,micro_cluster,organization_id,organization_name,
ROW_NUMBER() OVER (partition by organization_id ORDER BY dt_id desc) AS rn
from `data-bi-prd-935c.bi_mart`.outlet_loc_ns
where date_trunc(dt_id,month) = date_trunc(vdt_id,month)) a
where rn=1) c on a.destination=c.organization_id
where month_id = date_trunc(vdt_id,month)
and dt_id=vdt_id
and channel='Traditional' 
group by 1,5,6;