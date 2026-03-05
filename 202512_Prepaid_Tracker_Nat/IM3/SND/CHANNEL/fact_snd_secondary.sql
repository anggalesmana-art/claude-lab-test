declare vdt_id date default @vdt_id;

--===============================================================================================--
-- SECONDARY 
--===============================================================================================--

delete from `data-bi-prd-935c.bi_mart`.fact_snd_secondary where secondary_type in ('SELLIN MPC','ADJUSTMENT','CASHBACK','KOIN REDEEM','CASHBACK NEW') and dt_id = vdt_id;
insert into `data-bi-prd-935c.bi_mart`.fact_snd_secondary 
select `datetime` completion_date,region,area,sales_area,cluster,organization_id,
    credit_party_id, round(cast(amount as numeric)) amount,'SELLIN MPC' secondary_type,date(dt_id) dt_id
from `data-dtp-prd-aa1a.stg`.mobo_allocation_org_to_org
where lower(channel) like '%traditional%'
    and organization_type in ('Dealer','SDP') --include SDP 202310 update from 202308
    and (upper(credit_party_id) not like '%DS%'
    and upper(credit_party_id) not like '%SF%'
    and upper(credit_party_id) not like '%H2H%')
    and account_type = 'Saldo Mobo Account'
    and credit_party_id not like 'D%'
    and transaction_status = 'Completed'
    and status_description = 'Success'
    and date(dt_id)=vdt_id
union all
select timestamp(approved_dt_time),null region,null area,null sales_area,null cluster,debit_party_id,credit_party_id,
cast(after_tax as int),'ADJUSTMENT' secondary_type,date(dt_id)
from `data-dtp-prd-aa1a.stg`.daily_dump_bulk_adj
where date(dt_id)=vdt_id
    and (upper(credit_party_id) not like 'D%' and upper(credit_party_id) not like '%SF%' and upper(credit_party_id) not like '%H2H%')
    and debit_party_id='1'
    and transaction_status = 'Completed'
    and transaction_status_desc = 'Success'
union all
select timestamp(parse_date('%Y%m%d',data_date)),null region,area_name area,sales_area_name sales_area,cluster_name cluster,null,
cast(short_code as string),cashback_value,'CASHBACK' secondary_type,date(dt_id) dt_id
from `data-dtp-prd-aa1a.stg`.cashback
where date(dt_id)=vdt_id
union all
select timestamp(datatime) ,region,area,sales_area,cluster,null,organization_id,cast(koin_amount as int),'KOIN REDEEM' secondary_type,date(dt_id) dt_id
from `data-dtp-prd-aa1a.stg`.daily_dump_redeem_koin_details
where date(dt_id)=vdt_id and redeem_type='Redeem Balance'
union all
select parse_timestamp('%Y%m%d%H%M%S',transactiontime) completion_date,null region,null area,null sales_area,null cluster,'1' organization_id,
shortcode credit_party_id,round(cast(amount as numeric)/100) amount,'CASHBACK NEW' secondary_type,date(dt_id) dt_id
from `data-dtp-prd-aa1a.stg`.salmo_offline_usage_incentive
where date(dt_id)=vdt_id and state='Completed'
and amount<>'' --ADD by Indra Maulana Ikhsan 20240910
;

--SECONDARY SP DATA
delete from `data-bi-prd-935c.bi_mart`.fact_snd_secondary where secondary_type = 'SP DATA' and dt_id = vdt_id;
insert into `data-bi-prd-935c.bi_mart`.fact_snd_secondary 
select timestamp(dt_foss) completion_date,region,area,sales_area,sales_cluster cluster,
saldomobo_id,a.organization_id,
sum(cast(amount as numeric)) amount,'SP DATA' secondary_type,dt_sellin dt_id -- changed by indra Maulana Ikhsan using amount based on discussion with Mas Oman 20240727
from `data-bi-prd-935c.bi_mart`.foss_sp_data_sellin_mth a
left join (select * from
(select site_id,region,area,sales_area,sales_cluster,micro_cluster,organization_id,organization_name,
ROW_NUMBER() OVER (partition by organization_id ORDER BY dt_id desc) AS rn
from `data-bi-prd-935c.bi_mart`.outlet_loc_ns
where dt_id between date_trunc(vdt_id,month) and vdt_id) a
where rn=1) b on a.organization_id=b.organization_id
where mth_id=date_trunc(vdt_id,month) and dt_sellin=vdt_id
and a.organization_id<>''
group by 1,2,3,4,5,6,7,9,10;

--SECONDARY SP DATA NO SELLIN using DEALER added 202308
delete from `data-bi-prd-935c.bi_mart`.fact_snd_secondary where secondary_type = 'SP DATA ALLOC' and dt_id = vdt_id;
insert into `data-bi-prd-935c.bi_mart`.fact_snd_secondary 
select revenue_date completion_date,region,area,sales_area,sales_cluster,
c.dealer organization_id,c.dealer credit_party_id,
sum(cast(amount_debit as numeric)) amount, -- changed by indra Maulana Ikhsan using amount_debit based on discussion with Mas Oman 20240727
'SP DATA ALLOC' secondary_type,date(a.revenue_date) dt_id
from `data-dtp-prd-aa1a.sor`.sp_data_revenue a
left join (select * from `data-bi-prd-935c.bi_mart`.foss_sp_data_sellin_mth
where mth_id=date_trunc(vdt_id,month) and dt_sellin<=vdt_id
and organization_id<>'') b on a.msisdn=b.msisdn
left join (select dist_dt,msisdn,dealer from `data-bi-prd-935c.bi_mart`.foss_sp_mth
where mth_id=date_trunc(vdt_id,month)) c on a.msisdn=c.msisdn
left join (select * from `data-bi-prd-935c.bi_mart`.foss_dealer_mth
where mth_id=date_trunc(vdt_id,month)) d on c.dealer=d.dealer_code
where date(revenue_date)=vdt_id and b.msisdn is null
group by 1,2,3,4,5,6,7,9,10;

--SECONDARY VOUCHER ORI
delete from `data-bi-prd-935c.bi_mart`.fact_snd_secondary where secondary_type = 'VOU ORI' and dt_id = vdt_id;
insert into `data-bi-prd-935c.bi_mart`.fact_snd_secondary 
select timestamp(dt_foss) completion_date,cast(null as string) region,cast(null as string) area,cast(null as string) sales_area,cast(null as string) cluster,
saldomobo_id,organization_id,
sum(cast(amount as numeric)) amount,'VOU ORI' secondary_type,dt_sellin dt_id -- changed by indra Maulana Ikhsan using amount based on discussion with Mas Oman 20240727
from `data-bi-prd-935c.bi_mart`.foss_vo_ori_sellin_mth
where mth_id=date_trunc(vdt_id,month) and dt_sellin=vdt_id
and organization_id<>''
group by 1,2,3,4,5,6,7,9,10;

--SECONDARY VOUCHER ORI NO SELLIN using DEALER added 202308
delete from `data-bi-prd-935c.bi_mart`.fact_snd_secondary where secondary_type = 'VOU ORI ALLOC' and dt_id = vdt_id;
insert into `data-bi-prd-935c.bi_mart`.fact_snd_secondary 
select timestamp(parse_date('%Y%m%d',a.transactiondate)) completion_date,region,area,sales_area,sales_cluster,
c.dealer organization_id,c.dealer credit_party_id,
sum(cast(a.inj_sales_price as numeric)) amount, -- changed by indra Maulana Ikhsan using inj_sales_price based on discussion with Mas Oman 20240727
'VOU ORI ALLOC' secondary_type,parse_date('%Y%m%d',a.transactiondate) dt_id
from `data-dtp-prd-aa1a.smy`.smy_dv_redemption a
left join (select * from `data-bi-prd-935c.bi_mart`.foss_vo_ori_sellin_mth
where mth_id=date_trunc(vdt_id,month) and dt_sellin<=vdt_id
and organization_id<>'') b on a.pm_voucher_sn=b.sno
left join (select dt_id,sno,dealer from `data-bi-prd-935c.bi_mart`.foss_vo_mth
where mth_id=date_trunc(vdt_id,month)) c on a.pm_voucher_sn=c.sno
left join (select * from `data-bi-prd-935c.bi_mart`.foss_dealer_mth
where mth_id=date_trunc(vdt_id,month)) d on c.dealer=d.dealer_code
where parse_date('%Y%m%d',a.transactiondate)=vdt_id and a.pm_voucher_status='U' and b.sno is null and prc_dt = timestamp(vdt_id + interval 1 day)
group by 1,2,3,4,5,6,7,9,10;

--SECONDARY ONLINE PURCHASE
delete from `data-bi-prd-935c.bi_mart`.fact_snd_secondary where secondary_type = 'ONLINE PURCHASE' and dt_id = vdt_id;
insert into `data-bi-prd-935c.bi_mart`.fact_snd_secondary 
select timestamp(completion_date),region,area,sales_area,sales_cluster,
organization_trx saldomobo_id, a.organization_id,
sum(cast(amount_debit as numeric)) amount,'ONLINE PURCHASE' secondary_type,dt_id
from `data-bi-prd-935c.bi_mart`.salmo_online_dly a
left join (select * from
(select site_id,region,area,sales_area,sales_cluster,micro_cluster,organization_id,organization_name,
ROW_NUMBER() OVER (partition by organization_id ORDER BY dt_id desc) AS rn
from `data-bi-prd-935c.bi_mart`.outlet_loc_ns
where dt_id between date_trunc(vdt_id,month) and vdt_id) a
where rn=1) b on a.organization_id=b.organization_id
where dt_id=vdt_id
group by 1,2,3,4,5,6,7,9,10;

--SP ZERO
delete from `data-bi-prd-935c.bi_mart`.fact_snd_secondary where secondary_type = 'SP ZERO' and dt_id = vdt_id;
insert into `data-bi-prd-935c.bi_mart`.fact_snd_secondary 
select timestamp(a.dt_id) completion_date,region,area,sales_area,sales_cluster,
a.saldomobo_id organization_id,a.destination credit_party_id,
sum(coalesce(cast(b.amount as numeric),cast(a.price as numeric))) amount,
'SP ZERO' secondary_type,a.dt_id
from `data-bi-prd-935c.bi_mart`.mobii_msisdn_mth a
left join 
(
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
        where date(mth_id) = date_trunc(vdt_id,month) and upper(program_name) like '%ZERO%'
) b 
on a.msisdn=b.msisdn
left join 
    (
        select * from
        (
            select site_id,region,area,sales_area,sales_cluster,micro_cluster,organization_id,organization_name,
            ROW_NUMBER() OVER (partition by organization_id ORDER BY dt_id desc) AS rn
            from `data-bi-prd-935c.bi_mart`.outlet_loc_ns
            where date_trunc(date(dt_id),month)= date_trunc(vdt_id,month)
        ) a
        where rn=1
    ) c 
on a.destination=c.organization_id
where date(month_id) = date_trunc(vdt_id,month)
and date(dt_id)=vdt_id
and channel='Traditional'
and upper(a.product_name) like '%ZERO%'
group by 1,2,3,4,5,6,7,9,10
;