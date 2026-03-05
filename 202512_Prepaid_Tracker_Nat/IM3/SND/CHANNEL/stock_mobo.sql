declare vdt_id date default @vdt_id;

--- STOCK BALANCE
delete from `data-bi-prd-935c.bi_mart`.outlet_stock_balance where dt_id = vdt_id;
insert into `data-bi-prd-935c.bi_mart`.outlet_stock_balance
select region_name region,area_name area,sales_area_name sales_area,cluster_name cluster,
short_code,sum(current_balance) stock_balance, date(dt_id) dt_id 
from `data-dtp-prd-aa1a.stg`.stock_balance_daily 
where date(dt_id) = vdt_id
and lower(cluster_name) not in ('','cw-cja-purbamen','cw-cja-purwotelang')
and lower(cluster_name) not like '%test%'
and lower(cluster_name) not like '%cluster sev%'
and lower(sales_channel_name) ='traditional'
and lower(sales_channel)='salmobo'
and lower(region_name) not in ('regional-hr','regional-project','regional-test','regional sev')
and lower(organization_type) in ('outlet','sub outlet')
and account_type_id in ('2','192')  -- ,'128'
group by 1,2,3,4,5,7;

--- STOCK BALANCE enhance include all 20240429
delete from `data-bi-prd-935c.bi_mart`.stock_balance where dt_id = vdt_id;
insert into `data-bi-prd-935c.bi_mart`.stock_balance
select sales_channel_name channel, sales_channel, short_code organization_id, organization_type,
account_type_id, cluster_name, additional_territory_name,
sum(total_debit_amt) total_debit_amt,
sum(current_balance) stock_balance, date(dt_id) dt_id
from `data-dtp-prd-aa1a.stg`.stock_balance_daily 
where date(dt_id)=vdt_id
and lower(cluster_name) not in ('','cw-cja-purbamen','cw-cja-purwotelang')
and lower(cluster_name) not like '%test%'
and lower(cluster_name) not like '%cluster sev%'
--and lower(sales_channel_name) ='traditional'
--and lower(sales_channel)='salmobo'
and lower(region_name) not in ('regional-hr','regional-project','regional-test','regional sev')
--and lower(organization_type) in ('outlet','sub outlet')
--and account_type_id in ('2','128','192')
group by 1,2,3,4,5,6,7,10
;

--STOCK_BALANCE_MPC and OUTLET
delete from `data-bi-prd-935c.bi_mart`.track_stock where dt_id = vdt_id;
insert into `data-bi-prd-935c.bi_mart`.track_stock 
select short_code organization_id,
sum( case when lower(organization_type)='dealer' then current_balance else 0 end ) as stock_mpc,
sum( case when lower(organization_type)='outlet' then current_balance else 0 end ) as stock_outlet,
date(dt_id) dt_id
from `data-dtp-prd-aa1a.stg`.stock_balance_daily 
where date(dt_id)=vdt_id
and lower(cluster_name) not in ('','cw-cja-purbamen','cw-cja-purwotelang')
and lower(cluster_name) not like '%test%'
and lower(cluster_name) not like '%cluster sev%'
and lower(sales_channel_name) ='traditional'
and lower(sales_channel)='salmobo'
and lower(region_name) not in ('regional-hr','regional-project','regional-test','regional sev')
and account_type_id in ('2','192')  -- ,'128'
group by 1,4;

--STOCK MPC
delete from `data-bi-prd-935c.bi_mart`.track_stock_mpc where dt_id = vdt_id;
insert into `data-bi-prd-935c.bi_mart`.track_stock_mpc 
select case when upper(area_name) in ('CENTRAL JAVA','WEST JAVA') then 'CWJ'
when upper(area_name) in ('BALI NUSRA','EAST JAVA') then 'EJBN'
when upper(area_name) in ('BOTABEK','JAKARTA') then 'JBRO'
when upper(area_name) in ('KALIMANTAN','SUMAPA') then 'KALISULA'
when upper(area_name) in ('NORTHERN SUMATERA','SOUTHERN SUMATERA') then 'SUMATERA'
end region,area_name area,sales_area_name sales_area,cluster_name sales_cluster,
count(distinct short_code) mpc_count,sum(current_balance) as stock_mpc,date(dt_id) dt_id
from `data-dtp-prd-aa1a.stg`.stock_balance_daily 
where date(dt_id)=vdt_id
and lower(cluster_name) not in ('','cw-cja-purbamen','cw-cja-purwotelang')
and lower(cluster_name) not like '%test%'
and lower(cluster_name) not like '%cluster sev%'
and lower(sales_channel_name) ='traditional'
and lower(sales_channel)='salmobo'
and lower(region_name) not in ('regional-hr','regional-project','regional-test','regional sev')
and lower(organization_type)='dealer'
and account_type_id in ('2','192')  -- ,'128'
group by 1,2,3,4,7;

--STOCK OUTLET MOBO SP
delete from `data-bi-prd-935c.bi_mart`.stock_mobo_sp where dt_id = vdt_id;
insert into `data-bi-prd-935c.bi_mart`.stock_mobo_sp 
select channel,organization_type,transaction_type,organization_id,a_msisdn,b_msisdn,
product_name,main_price,amount_debit,transaction_id,a.dt_id inj_dt_id,vdt_id dt_id 
from (select channel,organization_type,transaction_type,organization_id,a_msisdn,b_msisdn,
product_name,main_price,amount_debit,transaction_id,inj_dt_id dt_id
from `data-bi-prd-935c.bi_mart`.stock_mobo_sp
where dt_id=date(vdt_id - interval 1 day)
and inj_dt_id>=date(vdt_id - interval 365 day)
union all
select channel,organization_type,transaction_type,organization_id,a_msisdn,b_msisdn,
product_name,main_price,amount_debit,transaction_id,dt_id
from `data-bi-prd-935c.bi_mart`.sellout_salmo_dly
where dt_id=vdt_id and transaction_type in ('Purchase Data Package','Bulk Purchase Package Transaction')) a
left join
(select transactionid from `data-dtp-prd-aa1a.sor`.mobo_revenue
where parse_date('%Y%m%d',revenue_date)=vdt_id and prc_dt = timestamp(vdt_id + interval 1 day)
and substring(b_msisdn, 1,5) in ('62857','62858','62856','62815','62816','62855','62814')
group by 1) b on a.transaction_id=b.transactionid
where b.transactionid is null;

--STOCK OUTLET MOBO VOUCHER
delete from `data-bi-prd-935c.bi_mart`.stock_mobo_vou  where dt_id = vdt_id;
insert into `data-bi-prd-935c.bi_mart`.stock_mobo_vou 
select channel,organization_type,transaction_type,organization_id,a_msisdn,b_msisdn,
product_name,main_price,amount_debit,transaction_id,a.dt_id inj_dt_id,vdt_id dt_id
from (select channel,organization_type,transaction_type,organization_id,a_msisdn,b_msisdn,
product_name,main_price,amount_debit,transaction_id,inj_dt_id dt_id
from `data-bi-prd-935c.bi_mart`.stock_mobo_vou
where dt_id=date(vdt_id - interval 1 day)
and inj_dt_id>=date(vdt_id - interval 365 day)
union all
select channel,organization_type,transaction_type,organization_id,a_msisdn,b_msisdn,
product_name,main_price,amount_debit,transaction_id,dt_id
from `data-bi-prd-935c.bi_mart`.sellout_salmo_dly
where dt_id=vdt_id and transaction_type in ('Bulk Voucher Card Injection','VoucherCardInjection')
and upper(product_name) not like '%PULSA%') a
left join
(select mobo_trx_id from `data-dtp-prd-aa1a.sor`.fdv_mobo_pm_join_match
where pm_voucher_status='U' and transactiondate=timestamp(vdt_id) and category='MOBO'
and substring(concat('62',pm_red_msisdn), 1,5) in ('62857','62858','62856','62815','62816','62855','62814')
--and substr(case when substr(pm_red_msisdn,1,2)!='62' then concat('62',pm_red_msisdn) else pm_red_msisdn end,1,5) in ('62857','62858','62856','62815','62816','62855','62814')
group by 1) b on a.transaction_id=b.mobo_trx_id
where b.mobo_trx_id is null;

delete from `data-bi-prd-935c.bi_mart`.stock_mobo_vou_pulsa where dt_id = vdt_id;
insert into `data-bi-prd-935c.bi_mart`.stock_mobo_vou_pulsa 
select channel,organization_type,transaction_type,organization_id,msisdn,
product_name,main_price,amount_debit,a.voucher_sn,a.dt_id inj_dt_id,vdt_id dt_id
from (select channel,organization_type,transaction_type,organization_id,msisdn,
product_name,main_price,amount_debit,voucher_sn,inj_dt_id dt_id
from `data-bi-prd-935c.bi_mart`.stock_mobo_vou_pulsa
where dt_id=date(vdt_id - interval 1 day)
and inj_dt_id>=date(vdt_id - interval 365 day)
union all
select channel,organization_type,transaction_type,organization_id,msisdn,
product_name,main_price,amount_debit,voucher_sn,dt_id
from `data-bi-prd-935c.bi_mart`.sellout_fdv_pulsa
where dt_id=vdt_id) a
left join
(select pm_voucher_sn voucher_sn from `data-dtp-prd-aa1a.sor`.fdv_mobo_pm_join_match_reload
where transactiondate=timestamp(vdt_id)
group by 1) b on a.voucher_sn=b.voucher_sn
where b.voucher_sn is null;

--FOSS SP DATA
delete from `data-bi-prd-935c.bi_mart`.foss_sp_data where dt_id between date(vdt_id - interval 5 day) and vdt_id;
insert into `data-bi-prd-935c.bi_mart`.foss_sp_data 
select msisdn,a.program_code,a.program_name,a.dist_dt,a.alloc_pymt_dt,a.exp_dt,a.dealer, cast(amount as numeric) amount,dt_id
from `data-bi-prd-935c.bi_mart`.foss_sp_mth a
join -- `data-bi-prd-935c.bi_mart`.omn_ref_sp_vou_ori b on a.program_code=b.ext_product_id and a.dt_id between b.start_dt and b.end_dt
                    (
                            select distinct
                                sales_order, gross_price_perunit, round((cast(REPLACE(net_sales_perunit, '-', '') as numeric)*1.11),0) amount
                                from `data-dtp-prd-aa1a.stg`.reference_zero
                                where -- substr(dt_id,1,6) = date_trunc(vdt_id,month)
                                date(dt_id) between vdt_id - interval 5 day and vdt_id
                    ) b
                    on SPLIT(a.po_number, '/')[ORDINAL(3)]  = b.sales_order
where dt_id between vdt_id - interval 5 day and vdt_id and a.mth_id=date_trunc(vdt_id,month)
and upper(a.program_name) not like '%ZERO%';


--FOSS VOUCHER ORI
delete from `data-bi-prd-935c.bi_mart`.foss_vo_ori where dt_id between date(vdt_id - interval 5 day) and vdt_id;
insert into `data-bi-prd-935c.bi_mart`.foss_vo_ori 
select a.sno,a.program_code,a.program_name,a.exp_dt,a.dealer,amount,a.dt_id
from `data-bi-prd-935c.bi_mart`.foss_vo_mth a
join -- `data-bi-prd-935c.bi_mart`.omn_ref_sp_vou_ori b on a.program_code=b.ext_product_id and a.dt_id between b.start_dt and b.end_dt
                    (
                            select distinct
                                sales_order, gross_price_perunit, round((cast(REPLACE(net_sales_perunit, '-', '') as numeric)*1.11),0) amount
                                from `data-dtp-prd-aa1a.stg`.reference_zero
                                where -- substr(dt_id,1,6) = date_trunc(vdt_id,month)
                                date(dt_id) between vdt_id - interval 5 day and vdt_id
                    ) b
                    on SPLIT(a.po_number, '/')[ORDINAL(3)]  = b.sales_order
where dt_id between vdt_id - interval 5 day and vdt_id and a.mth_id=date_trunc(vdt_id,month)
and upper(a.program_name) not like '%V0%';



--SP DATA STOCK
delete from `data-bi-prd-935c.bi_mart`.stock_sp_data where dt_id = vdt_id;
insert into `data-bi-prd-935c.bi_mart`.stock_sp_data 
select a.msisdn,program_code,program_name,exp_dt,dealer_id,amount,foss_dt_id,vdt_id dt_id
from 
    (
        select msisdn,program_code,program_name,exp_dt,dealer_id,amount,foss_dt_id
        from 
        (
            select msisdn,program_code,program_name,exp_dt,dealer_id,amount,foss_dt_id,
            ROW_NUMBER() over(partition by msisdn order by foss_dt_id desc) as rn
            from
            (
                select msisdn,program_code,program_name,exp_dt,dealer_id,amount,foss_dt_id
                from `data-bi-prd-935c.bi_mart`.stock_sp_data
                where dt_id=date(vdt_id - interval 1 day)
                union all
                select msisdn,a.program_code,a.program_name,a.exp_dt,a.dealer,amount,dt_id
                from `data-bi-prd-935c.bi_mart`.foss_sp_mth a
                join -- `data-bi-prd-935c.bi_mart`.omn_ref_sp_vou_ori b on a.program_code=b.ext_product_id and a.dt_id between b.start_dt and b.end_dt
                    (
                            select distinct
                                sales_order, gross_price_perunit, round((cast(REPLACE(net_sales_perunit, '-', '') as numeric)*1.11),0) amount
                                from `data-dtp-prd-aa1a.stg`.reference_zero
                                where -- substr(dt_id,1,6) = date_trunc(vdt_id,month)
                                date_trunc(date(dt_id),month) = date_trunc(vdt_id,month)
                    ) b
                    on SPLIT(a.po_number, '/')[ORDINAL(3)]  = b.sales_order
where dt_id = vdt_id and a.mth_id=date_trunc(vdt_id,month)
            ) a
        ) a
        where rn=1
    ) a
left join 
(
    select b_msisdn from `data-dtp-prd-aa1a.sor`.mobo_revenue
    -- where revenue_date=vdt_id
    where parse_date('%Y%m%d',revenue_date) 
    -- between date_trunc(vdt_id,month) and vdt_id
         --between date(vdt_id - interval 730 day) and vdt_id  and date(prc_dt) <= vdt_id + interval 1 day
         between '2023-12-31' and vdt_id  and date(prc_dt) <= vdt_id + interval 1 day
         and substring(b_msisdn, 1,5) in ('62857','62858','62856','62815','62816','62855','62814')
    group by 1
) b 
on a.msisdn=b.b_msisdn
where coalesce(exp_dt,date(vdt_id + interval 30 day)) > vdt_id and b.b_msisdn is null
;


--VOUCHER ORI STOCK
delete from `data-bi-prd-935c.bi_mart`.stock_vo_ori where dt_id = vdt_id;
insert into `data-bi-prd-935c.bi_mart`.stock_vo_ori 
select sno,program_code,program_name,exp_dt,dealer_id,amount,foss_dt_id,vdt_id dt_id
from
(
    select sno,program_code,program_name,exp_dt,dealer_id,amount,foss_dt_id
    from
    (
        select sno,program_code,program_name,exp_dt,dealer_id,amount,foss_dt_id,
        ROW_NUMBER() over(partition by sno order by foss_dt_id desc) as rn
        from
        (
            select sno,program_code,program_name,exp_dt,dealer_id,amount,foss_dt_id
            from `data-bi-prd-935c.bi_mart`.stock_vo_ori
            where dt_id=date(vdt_id - interval 1 day)
            union all
            select sno,program_code,program_name,exp_dt,dealer,amount,dt_id
            from `data-bi-prd-935c.bi_mart`.foss_vo_mth a
            join -- `data-bi-prd-935c.bi_mart`.omn_ref_sp_vou_ori b on a.program_code=b.ext_product_id and a.dt_id between b.start_dt and b.end_dt
                    (
                            select distinct
                                sales_order, gross_price_perunit, round((cast(REPLACE(net_sales_perunit, '-', '') as numeric)*1.11),0) amount
                                from `data-dtp-prd-aa1a.stg`.reference_zero
                                where -- substr(dt_id,1,6) = date_trunc(vdt_id,month)
                                date_trunc(date(dt_id),month) = date_trunc(vdt_id,month)
                    ) b
                    on SPLIT(a.po_number, '/')[ORDINAL(3)]  = b.sales_order
where dt_id  = vdt_id  and a.mth_id=date_trunc(vdt_id,month)
        ) a
    ) a
    where rn=1
) a
left join 
(
    select pm_voucher_sn from `data-dtp-prd-aa1a.smy`.smy_dv_redemption
    where -- transactiondate=vdt_id
    parse_date('%Y%m%d',transactiondate) -- between concat(date_trunc(vdt_id,month),'01') and vdt_id --update omn 20240828 to process stock sellin after usage
        between date(vdt_id - interval 730 day)
                                and vdt_id  and prc_dt<= timestamp(vdt_id + interval 1 day)
    group by 1
) b on a.sno=b.pm_voucher_sn
where coalesce(exp_dt,date(vdt_id + interval 30 day)) > vdt_id and b.pm_voucher_sn is null
;



--TERTIARY FOSS SP_DATA
delete from `data-bi-prd-935c.bi_mart`.foss_sp_tertiary where dt_id = vdt_id;
insert into `data-bi-prd-935c.bi_mart`.foss_sp_tertiary 
select a.msisdn,dealer,amt,date(b.dt_id) dt_id
from `data-bi-prd-935c.bi_mart`.foss_sp_data a
join (select revenue_date dt_id,msisdn,sum(cast(amount_debit as numeric)) amt from `data-dtp-prd-aa1a.sor`.sp_data_revenue
where revenue_date =timestamp(vdt_id)
group by 1,2) b on a.msisdn=b.msisdn;

--TERTIARY FOSS VO_ORI
delete from `data-bi-prd-935c.bi_mart`.foss_vo_tertiary where dt_id = vdt_id;
insert into `data-bi-prd-935c.bi_mart`.foss_vo_tertiary 
select a.sno,dealer_id,amt,date(b.dt_id) dt_id
from `data-bi-prd-935c.bi_mart`.foss_vo_ori a
join (select parse_date('%Y%m%d',transactiondate) dt_id,pm_voucher_sn,sum(cast(inj_sales_price as numeric)) amt from `data-dtp-prd-aa1a.smy`.smy_dv_redemption
where parse_date('%Y%m%d',transactiondate) =vdt_id and prc_dt = timestamp(vdt_id + interval 1 day)
group by 1,2) b on a.sno=b.pm_voucher_sn;

--STOCK OUTLET 30D     
delete from `data-bi-prd-935c.bi_mart`.stock_outlet_30d  where dt_id = vdt_id; 
insert into `data-bi-prd-935c.bi_mart`.stock_outlet_30d 
select organization_id,stock_balance,dt_id from
(select dt_id,short_code,stock_balance from `data-bi-prd-935c.bi_mart`.outlet_stock_balance
where dt_id=vdt_id) a
join                    
(select organization_id from `data-bi-prd-935c.bi_mart`.seratus_uro_inject_detail
where dt_id>=date(vdt_id - interval 30 day)
and dt_id<=vdt_id
group by 1) b on a.short_code=b.organization_id;
                        
--STOCK OUTLET 90D  
delete from `data-bi-prd-935c.bi_mart`.stock_outlet_90d  where dt_id = vdt_id;    
insert into `data-bi-prd-935c.bi_mart`.stock_outlet_90d 
select organization_id,stock_balance,dt_id from
(select dt_id,short_code,stock_balance from `data-bi-prd-935c.bi_mart`.outlet_stock_balance
where dt_id=vdt_id) a
join                    
(select organization_id from `data-bi-prd-935c.bi_mart`.seratus_uro_inject_detail
where dt_id>=date(vdt_id - interval 90 day)
and dt_id<=vdt_id
group by 1) b on a.short_code=b.organization_id;
                        
--STOCK OUTLET 
delete from `data-bi-prd-935c.bi_mart`.track_stock_outlet where dt_id = vdt_id;         
insert into `data-bi-prd-935c.bi_mart`.track_stock_outlet 
select site_id,a.short_code organization_id,sum(a.stock_balance) stock_balance,dt_id
from `data-bi-prd-935c.bi_mart`.outlet_stock_balance a
left join (select * from
(select site_id,area,sales_area,sales_cluster,micro_cluster,organization_id,organization_name,
ROW_NUMBER() OVER (partition by organization_id ORDER BY dt_id desc) AS rn
from `data-bi-prd-935c.bi_mart`.outlet_loc_ns
where date_trunc(dt_id,month)= date_trunc(vdt_id,month)) a
where rn=1) b on a.short_code = b.organization_id
where dt_id=vdt_id and a.stock_balance>=0
group by 1,2,4;         

delete from `data-bi-prd-935c.bi_mart`.stock_uro_area where dt_id = vdt_id;
insert into `data-bi-prd-935c.bi_mart`.stock_uro_area 
select case when lower(d.area)='bali nusra' then 'EJBN'
when lower(d.area)='botabek' then 'JBRO'
when lower(d.area)='central java' then 'CWJ'
when lower(d.area)='east java' then 'EJBN'
when lower(d.area)='jakarta' then 'JBRO'
when lower(d.area)='kalimantan' then 'KALISULA'
when lower(d.area)='northern sumatera' then 'SUMATERA'
when lower(d.area)='southern sumatera' then 'SUMATERA'
when lower(d.area)='sumapa' then 'KALISULA'
when lower(d.area)='west java' then 'CWJ' end region,area,sales_area,sales_cluster,micro_cluster,count(a.organization_id) uro,
sum(case when a.organization_id=b.organization_id then 1 else 0 end) uro20k,
sum(case when a.organization_id=c.organization_id then 1 else 0 end) uro_less20ksaldo,vdt_id dt_id
from
(select organization_id,sum(main_price) main_price,sum(amt) amt
from `data-bi-prd-935c.bi_mart`.seratus_uro_inject_detail
where dt_id>=date_trunc(vdt_id,month)
and dt_id<=vdt_id
group by 1) a
left join
(select organization_id,sum(main_price) main_price,sum(amt) amt2
from
(select organization_id,sum(main_price) main_price,sum(amt) amt
from `data-bi-prd-935c.bi_mart`.seratus_uro_inject_detail
where dt_id>=date_trunc(vdt_id,month)
and dt_id<=vdt_id
group by 1) a
where main_price>=20000
group by 1) b on a.organization_id=b.organization_id
left join
(select organization_id
from (select organization_id,sum(stock) stock from `data-bi-prd-935c.bi_mart`.stock_outlet_area 
where dt_id=vdt_id
group by 1) a
where stock<20000) c on a.organization_id=c.organization_id
left join (select * from
(select site_id,area,sales_area,sales_cluster,micro_cluster,organization_id,organization_name,
ROW_NUMBER() OVER (partition by organization_id ORDER BY dt_id desc) AS rn
from `data-bi-prd-935c.bi_mart`.outlet_loc_ns
where date_trunc(dt_id,month)= date_trunc(vdt_id,month)) a
where rn=1) d on a.organization_id=d.organization_id
group by 1,2,3,4,5,9;

--SP DATA STOCK MOBII--
--MOBII SP DATA
-- delete from `data-bi-prd-935c.bi_mart`.mobii_spdata where mth_id = date_trunc(vdt_id,month);
-- insert into `data-bi-prd-935c.bi_mart`.mobii_spdata 
-- select product_code,product_name,a.msisdn,price,saldomobo_id,dest_saldomobo_id,
-- expired_date,transaction_date mobii_dt_id,date_trunc(vdt_id,month) mth_id
-- from (
-- select product_code,product_name,msisdn,price,saldomobo_id,dest_saldomobo_id,
-- transaction_date,expired_date,ROW_NUMBER() OVER (partition by msisdn ORDER BY transaction_date desc) AS rn
-- from (
-- select product_code,product_name,msisdn,price,saldomobo_id,dest_saldomobo_id,
-- date(transaction_datetime) transaction_date,
-- date(expired_date) expired_date
-- from `data-dtp-prd-aa1a.stg`.mobii_physical_distribution
-- where date(transaction_datetime)
-- between date_trunc(vdt_id,month)
-- and vdt_id
-- and dest_saldomobo_id not like 'D%' and product_category='Starter Pack'
-- and distribution_type='Sell In'
-- and (product_name like '%DAT 2GB%' or product_name like '%DAT 8GB%' or product_name like '%DAT 16GB%')
-- union all
-- select product_code,product_name,msisdn,price,saldomobo_id,dest_saldomobo_id,
-- mobii_dt_id,expired_date
-- from `data-bi-prd-935c.bi_mart`.mobii_spdata
-- where mth_id=date_trunc(vdt_id - interval 1 month, month)) a) a
-- join (select msisdn from `data-bi-prd-935c.bi_mart`.foss_sp_data
-- where dt_id<=vdt_id
-- group by 1) b on a.msisdn=b.msisdn
-- where rn=1;

--STOCK SP DATA MOBII
delete from `data-bi-prd-935c.bi_mart`.stock_sp_data_mobii where dt_id = vdt_id;
insert into `data-bi-prd-935c.bi_mart`.stock_sp_data_mobii 
select product_code,product_name,msisdn,amount,saldomobo_id,
case when dest_saldomobo_id is null or dest_saldomobo_id = '' then org_id
else dest_saldomobo_id end dest_saldomobo_id,
expired_date,mobii_dt_id,vdt_id dt_id
from (
select product_code,product_name,a.msisdn,cast(amount as bigint) amount,saldomobo_id,dest_saldomobo_id,
expired_date,mobii_dt_id,ROW_NUMBER() OVER (partition by a.msisdn ORDER BY mobii_dt_id desc) AS rn
from (select msisdn,product_code,product_name,expired_date,saldomobo_id,dest_saldomobo_id,mobii_dt_id,amount
from `data-bi-prd-935c.bi_mart`.stock_sp_data_mobii
where dt_id=date(vdt_id - interval 1 day)
union all
select msisdn,product_code,product_name,expired_date,saldomobo_id,organization_id,dt_sellin mobii_dt_id,amount
from `data-bi-prd-935c.bi_mart`.foss_sp_data_sellin_mth
where mth_id=date_trunc(vdt_id,month) and dt_sellin=vdt_id) a
left join (select b_msisdn from `data-dtp-prd-aa1a.sor`.mobo_revenue
where parse_date('%Y%m%d',revenue_date) 
    -- between date_trunc(vdt_id,month) and vdt_id
    --between vdt_id - interval 730 day and vdt_id  -- update ind 20240911 to process sellin after usage until 365 days before
    between '2023-12-31' and vdt_id
and prc_dt <= timestamp(vdt_id + interval 1 day)
and substring(b_msisdn, 1,5) in ('62857','62858','62856','62815','62816','62855','62814')
group by 1) b on a.msisdn=b.b_msisdn
where b.b_msisdn is null
) a
--add logic for tagging 20240429
left join (
select org_id, sp_tag_msisdn
from `data-bi-prd-935c.bi_mart`.sp_tag_outlet_mth
where month_id = date_trunc(vdt_id,month)
and lower(org_type) in ('outlet','sub outlet','outlet non mobo')
) b
on a.msisdn=b.sp_tag_msisdn
where rn=1
and expired_date > vdt_id
;


--MOBII SP DATA SP TAG
delete from `data-bi-prd-935c.bi_mart`.mobii_sptag_spdata where mth_id = date_trunc(vdt_id,month);
insert into `data-bi-prd-935c.bi_mart`.mobii_sptag_spdata 
select product_code,product_name,a.msisdn,price,saldomobo_id,coalesce(org_id,dest_saldomobo_id) dest_saldomobo_id,
expired_date,mobii_dt_id,mth_id
from `data-bi-prd-935c.bi_mart`.mobii_spdata a
left join (select org_id,msisdn 
from (
select org_id,sp_tag_msisdn msisdn,ROW_NUMBER() OVER (partition by sp_tag_msisdn ORDER BY dt_id desc) AS rn
from `data-dtp-prd-aa1a.stg`.mobo_sp_tag_outlet
where status='Success'
and dt_id between timestamp(date_trunc(vdt_id,month))
and timestamp(vdt_id)) a
where rn=1) b on a.msisdn=b.msisdn
where mth_id=date_trunc(vdt_id,month);


----STOCK SP DATA MOBII TAG
--insert into `data-bi-prd-935c.bi_mart`.stock_sp_data_mobii 
--select product_code,product_name,a.msisdn,price,saldomobo_id,dest_saldomobo_id,
--expired_date,mobii_dt_id,vdt_id dt_id
--from (
--select product_code,product_name,msisdn,price,saldomobo_id,dest_saldomobo_id,
--expired_date,mobii_dt_id,ROW_NUMBER() OVER (partition by msisdn ORDER BY mobii_dt_id desc) AS rn
--from (
--select product_code,product_name,msisdn,price,saldomobo_id,dest_saldomobo_id,
--expired_date,mobii_dt_id from `data-bi-prd-935c.bi_mart`.stock_sp_data_mobii
--where dt_id=date(vdt_id - interval 1 day)
--union all
--select product_code,product_name,msisdn,price,saldomobo_id,dest_saldomobo_id,
--expired_date,mobii_dt_id from `data-bi-prd-935c.bi_mart`.mobii_sptag_spdata
--where mth_id=date_trunc(vdt_id,month)
--and mobii_dt_id between date_trunc(vdt_id,month)
--and vdt_id) a) a
--left anti join (select msisdn from `data-dtp-prd-aa1a.sor`.sp_data_revenue
--where revenue_date between date_trunc(vdt_id,month)
--and vdt_id
--group by 1) b on a.msisdn=b.msisdn
--where rn=1
--;


--STOCK VO ORI FOSS MOBII
delete from `data-bi-prd-935c.bi_mart`.stock_vo_ori_sellin where dt_id = vdt_id;
insert into `data-bi-prd-935c.bi_mart`.stock_vo_ori_sellin 
select sno,product_code,product_name,expired_date,saldomobo_id,
case when organization_id is null or organization_id = '' then org_id
else organization_id end organization_id,foss_dt_id,
amount,vdt_id dt_id
from (
select sno,product_code,product_name,expired_date,saldomobo_id,organization_id,foss_dt_id,
cast(amount as bigint) amount,ROW_NUMBER() OVER (partition by sno ORDER BY foss_dt_id desc) AS rn
from 
(select sno,product_code,product_name,expired_date,saldomobo_id,organization_id,foss_dt_id,amount
from `data-bi-prd-935c.bi_mart`.stock_vo_ori_sellin
where dt_id=date(vdt_id - interval 1 day)
union all
select sno,product_code,product_name,expired_date,saldomobo_id,organization_id,dt_foss foss_dt_id,amount
from `data-bi-prd-935c.bi_mart`.foss_vo_ori_sellin_mth
where mth_id=date_trunc(vdt_id,month) and dt_sellin=vdt_id) a
left join 
(select pm_voucher_sn from `data-dtp-prd-aa1a.smy`.smy_dv_redemption
where --transactiondate = vdt_id
parse_date('%Y%m%d',transactiondate) -- between concat(date_trunc(vdt_id,month),'01') and vdt_id --update omn 20240828 to process stock sellin after usage
        between date(vdt_id - interval 730 day)
                                and vdt_id and prc_dt <= timestamp(vdt_id + interval 1 day) -- update ind 20240911 to process sellin after usage until 365 days before
group by 1) b on a.sno=b.pm_voucher_sn
where b.pm_voucher_sn is null
) a
--add logic for tagging 20240429
left join (
select org_id, serial_number
from `data-bi-prd-935c.bi_mart`.vo_tag_outlet_mth
where month_id = date_trunc(vdt_id,month)
) b
on a.sno=b.serial_number
where rn=1
and expired_date > vdt_id;


--STOCK OUTLET AREA     
delete from `data-bi-prd-935c.bi_mart`.stock_outlet_area where dt_id = vdt_id;
insert into `data-bi-prd-935c.bi_mart`.stock_outlet_area 
select a.organization_id,stock_source,b.region,
b.area,b.sales_area,b.sales_cluster,b.micro_cluster,sum(stock) stock,a.dt_id 
from (select dt_id,organization_id,case when a.b_msisdn=b.msisdn then 'MOBO SP VALID'
else 'MOBO SP CHURN' end stock_source,sum(amount_debit) stock
from `data-bi-prd-935c.bi_mart`.stock_mobo_sp a
left join (select msisdn from `data-dtp-prd-aa1a.smy`.ar_cst_dly_smy
where date(dt_id)=vdt_id) b on a.b_msisdn=b.msisdn
where dt_id=vdt_id and channel='Traditional'
and date_diff(date(dt_id),date(inj_dt_id),day) <= 365
group by 1,2,3          
union all               
select dt_id,organization_id,'MOBO VOUCHER' stock_source,sum(amount_debit) stock from `data-bi-prd-935c.bi_mart`.stock_mobo_vou
where dt_id=vdt_id and channel='Traditional'
and date_diff(date(dt_id),date(inj_dt_id),day) <= 365
group by 1,2,3          
union all               
select dt_id,organization_id,'SALDO' stock_source,sum(stock_balance) stock from `data-bi-prd-935c.bi_mart`.stock_outlet_90d
where dt_id=vdt_id
group by 1,2,3
union all               
select dt_id,organization_id,'MOBO VOUCHER RLD' stock_source,sum(amount_debit) stock from `data-bi-prd-935c.bi_mart`.stock_mobo_vou_pulsa
where dt_id=vdt_id and channel='Traditional'
and date_diff(date(dt_id),date(inj_dt_id),day) <= 365
group by 1,2,3
union all               
select dt_id,organization_id,'VOUCHER ORI' stock_source,sum(amount) stock from `data-bi-prd-935c.bi_mart`.stock_vo_ori_sellin
where dt_id=vdt_id
and expired_date > dt_id
group by 1,2,3
union all               
select dt_id,dest_saldomobo_id organization_id,'SP DATA' stock_source,sum(amount) stock from `data-bi-prd-935c.bi_mart`.stock_sp_data_mobii
where dt_id=vdt_id and product_name not like 'SF%'
and expired_date > dt_id
group by 1,2,3) a       
left join (select * from
(select site_id,region,area,sales_area,sales_cluster,micro_cluster,organization_id,organization_name,
ROW_NUMBER() OVER (partition by organization_id ORDER BY dt_id desc) AS rn
from `data-bi-prd-935c.bi_mart`.outlet_loc_ns
where date_trunc(dt_id,month)= date_trunc(vdt_id,month)) a
where rn=1) b on a.organization_id=b.organization_id
group by 1,2,3,4,5,6,7,9;
