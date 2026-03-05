declare vdt_id date default @vdt_id;
--===============================================================================================--
-- SECONDARY DETAIL
--===============================================================================================--

-- create tmp outlet location NBS
create or replace table `data-bi-prd-935c.bi_stg`.tmp_ind_outlet_nbs_secondary_{{ vdt_id }}  as
select * from 
    (
		select site_id, organization_id, organization_name, channel,
		ROW_NUMBER() OVER (partition by organization_id ORDER BY dt_id desc) AS rn
		from `data-bi-prd-935c.bi_mart`.outlet_loc_ns
		where dt_id between date_trunc(vdt_id,month) and vdt_id
	) a
	where rn=1
;


-- create tmp outlet salmo

create or replace table `data-bi-prd-935c.bi_stg`.tmp_ind_org_salmo_{{ vdt_id }}  as
select organization_id, organization_name, organization_type, channel, channel_grp, l1_parent_id, l1_parent_name
    from `data-bi-prd-935c.bi_mart`.org_salmo
    where mth_id = date_trunc(vdt_id,month)
;


-- SELLIN SALMO (SALDO)
delete from `data-bi-prd-935c.bi_mart`.fact_snd_secondary_dtl where secondary_type = 'SELLIN SALDO' and dt_id = vdt_id;
insert into `data-bi-prd-935c.bi_mart`.fact_snd_secondary_dtl 
select upper(credit_party_id) organization_id,
    credit_party_name organization_nm,
    c.organization_type,
    a.channel,
    case when a.channel in ('Traditional','Direct') then 'Traditional'
         else 'Non Traditional' 
    end channel_grp,
    b.site_id site_outlet,
    a.organization_id parent_org_id,
    a.organization_name parent_org_nm,
    a.organization_type parent_org_type,
    operator_id,
    operator_name,
    operator_type,
    additional_territory,
    round(cast(amount as numeric)) amount,
    1 hits,
    timestamp(current_datetime('+7')) ppn_dttm,
    round(cast(amount as numeric)) main_price,
    'SELLIN SALDO' secondary_type,
    date(dt_id) dt_id
from `data-dtp-prd-aa1a.stg`.mobo_allocation_org_to_org a
left join `data-bi-prd-935c.bi_stg`.tmp_ind_outlet_nbs_secondary_{{ vdt_id }} b
    on a.credit_party_id = b.organization_id
left join `data-bi-prd-935c.bi_stg`.tmp_ind_org_salmo_{{ vdt_id }} c
    on a.credit_party_id = c.organization_id
where date(dt_id) = vdt_id
    and a.organization_type not in ('Dealer Branch','OnlinePurchase Parent')
    and account_type = 'Saldo Mobo Account'
    and credit_party_id not like 'D%'
    and transaction_status = 'Completed'
    and status_description = 'Success'
    and upper(credit_party_id) not like '%TEMP%'
    and upper(credit_party_id) not like '%TEST%'
;


-- ADJUSTMENT
delete from `data-bi-prd-935c.bi_mart`.fact_snd_secondary_dtl where secondary_type = 'ADJUSTMENT' and dt_id = vdt_id;
insert into `data-bi-prd-935c.bi_mart`.fact_snd_secondary_dtl 
select credit_party_id organization_id,
    credit_party_name organization_nm,
    'Outlet' organization_type,
    'Traditional' channel,
    'Traditional' channel_grp,
    b.site_id site_outlet,
    debit_party_id parent_org_id,
    debit_party_name parent_org_nm,
    debit_party_name parent_org_type,
    '' operator_id,
    '' operator_name,
    '' operator_type,
    '' additional_territory,
    sum(cast(after_tax as numeric)) amount,
    count(transaction_id) hits,
    timestamp(current_datetime('+7')) ppn_dttm,
    sum(cast(after_tax as numeric)) main_price,
    'ADJUSTMENT' secondary_type,
    date(dt_id)
from `data-dtp-prd-aa1a.stg`.daily_dump_bulk_adj a
left join `data-bi-prd-935c.bi_stg`.tmp_ind_outlet_nbs_secondary_{{ vdt_id }} b
    on a.credit_party_id = b.organization_id
where date(dt_id) = vdt_id
    and upper(credit_party_id) not like 'D%'
    and debit_party_id='1'
    and transaction_status = 'Completed'
    and transaction_status_desc = 'Success'
group by 1,2,3,4,5,6,7,8,9,10,11,12,13,16,18,19
;

-- CASHBACK
delete from `data-bi-prd-935c.bi_mart`.fact_snd_secondary_dtl where secondary_type = 'CASHBACK' and dt_id = vdt_id;
insert into `data-bi-prd-935c.bi_mart`.fact_snd_secondary_dtl 
select cast(short_code as string) organization_id,
    biz_org_name organization_nm,
    organization_type,
    'Traditional' channel,
    'Traditional' channel_grp,
    b.site_id site_outlet,
    -- parent_id parent_org_id,
    -- parent_name parent_org_nm,
    '' parent_org_id,
    '' parent_org_nm,
    '' parent_org_type,
    '' operator_id,
    '' operator_name,
    '' operator_type,
    -- partner_territory additional_territory,
      '' additional_territory,
    sum(cashback_value) amount,
    count(transaction_id) hits,
    timestamp(current_datetime('+7')) ppn_dttm,
    sum(cashback_value) main_price, 
    'CASHBACK' secondary_type,
    date(dt_id)
from `data-dtp-prd-aa1a.stg`.cashback a
left join `data-bi-prd-935c.bi_stg`.tmp_ind_outlet_nbs_secondary_{{ vdt_id }} b
    on cast(a.short_code as string) = b.organization_id
where date(dt_id) = vdt_id
group by 1,2,3,4,5,6,7,8,9,10,11,12,13,16,18,19
;

-- KOIN REDEEM
delete from `data-bi-prd-935c.bi_mart`.fact_snd_secondary_dtl where secondary_type = 'KOIN REDEEM' and dt_id = vdt_id;
insert into `data-bi-prd-935c.bi_mart`.fact_snd_secondary_dtl 
select a.organization_id,
    a.organization_name organization_nm,
    a.organization_type,
    a.channel,
    'Traditional' channel_grp,
    b.site_id site_outlet,
    c.l1_parent_id parent_org_id,
    c.l1_parent_name parent_org_nm,
    '' parent_org_type,
    operator_id,
    operator_name,
    operator_type,
    additional_territory,
    sum(cast(koin_amount as numeric)) amount,
    count(transaction_id) hits,
    timestamp(current_datetime('+7')) ppn_dttm,
    sum(cast(koin_amount as numeric)) main_price,
    'KOIN REDEEM' secondary_type,
    date(dt_id)
from `data-dtp-prd-aa1a.stg`.daily_dump_redeem_koin_details a
left join `data-bi-prd-935c.bi_stg`.tmp_ind_outlet_nbs_secondary_{{ vdt_id }} b
    on a.organization_id = b.organization_id
left join `data-bi-prd-935c.bi_stg`.tmp_ind_org_salmo_{{ vdt_id }} c
    on a.organization_id = c.organization_id
where date(dt_id) = vdt_id
    and redeem_type = 'Redeem Balance'
    and transaction_status = 'Completed'
group by 1,2,3,4,5,6,7,8,9,10,11,12,13,16,18,19
;

--CASHBACK NEW
delete from `data-bi-prd-935c.bi_mart`.fact_snd_secondary_dtl where secondary_type = 'CASHBACK NEW' and dt_id = vdt_id;
insert into `data-bi-prd-935c.bi_mart`.fact_snd_secondary_dtl 
select shortcode organization_id,
    b.organization_name organization_nm,
    c.organization_type organization_type,
    'Traditional' channel,
    'Traditional' channel_grp,
    b.site_id site_outlet,
    c.l1_parent_id parent_org_id,
    c.l1_parent_name parent_org_nm,
    '' parent_org_type,
    '' operator_id,
    '' operator_name,
    '' operator_type,
    '' additional_territory,
    sum(round(cast(amount as numeric)/100)) amount,
    count(orderid) hits,
    timestamp(current_datetime('+7')) ppn_dttm,
    sum(round(cast(amount as numeric)/100)) main_price, 
    'CASHBACK NEW' secondary_type,
    date(dt_id)
from `data-dtp-prd-aa1a.stg`.salmo_offline_usage_incentive a
left join `data-bi-prd-935c.bi_stg`.tmp_ind_outlet_nbs_secondary_{{ vdt_id }} b
    on a.shortcode = b.organization_id
left join `data-bi-prd-935c.bi_stg`.tmp_ind_org_salmo_{{ vdt_id }} c
    on a.shortcode = c.organization_id
where date(dt_id) = vdt_id
    and state = 'Completed'
    and a.amount <> '' 
group by 1,2,3,4,5,6,7,8,9,10,11,12,13,16,18,19
;

--  ONLINE PURCHASE 202212
delete from `data-bi-prd-935c.bi_mart`.fact_snd_secondary_dtl where secondary_type = 'ONLINE PURCHASE' and dt_id = vdt_id;
insert into `data-bi-prd-935c.bi_mart`.fact_snd_secondary_dtl 
select a.organization_id,
    b.organization_name organization_nm,
    c.organization_type organization_type,
    a.channel,
    case when a.channel in ('Traditional','Direct') then 'Traditional'
         else 'Non Traditional' 
    end channel_grp,
    b.site_id site_outlet,
    c.l1_parent_id parent_org_id,
    c.l1_parent_name parent_org_nm,
    '' parent_org_type,
    '' operator_id,
    '' operator_name,
    '' operator_type,
    '' additional_territory,
    sum(amount_debit) amount,
    count(a.transaction_id) hits,
    timestamp(current_datetime('+7')) ppn_dttm,
    sum(amount_debit) main_price, 
    'ONLINE PURCHASE' secondary_type,
    dt_id
from `data-bi-prd-935c.bi_mart`.salmo_online_dly a
left join `data-bi-prd-935c.bi_stg`.tmp_ind_outlet_nbs_secondary_{{ vdt_id }} b
    on a.organization_id = b.organization_id
left join `data-bi-prd-935c.bi_stg`.tmp_ind_org_salmo_{{ vdt_id }} c
    on a.organization_id = c.organization_id
where dt_id = vdt_id
group by 1,2,3,4,5,6,7,8,9,10,11,12,13,16,18,19
;


--  SP DATA
delete from `data-bi-prd-935c.bi_mart`.fact_snd_secondary_dtl where secondary_type = 'SP DATA' and dt_id = vdt_id;
insert into `data-bi-prd-935c.bi_mart`.fact_snd_secondary_dtl 
select a.organization_id,
        b.organization_name organization_nm,
        c.organization_type organization_type,
        coalesce(c.channel,b.channel) channel,
        case when coalesce(c.channel,b.channel) in ('Traditional','Direct') then 'Traditional'
             when coalesce(c.channel,b.channel) in ('Modern') then 'Non Traditional'
             else 'Traditional' 
        end channel_grp,--set modern as non trad 20240729
        b.site_id site_outlet,
        c.l1_parent_id parent_org_id,
        c.l1_parent_name parent_org_nm,
        '' parent_org_type,
        a.operator_id,
        a. operator_name,
        '' operator_type,
        '' additional_territory,
        sum(amount) amount,
        count(a.msisdn) hits,
        timestamp(current_datetime('+7')) ppn_dttm,
        sum(main_price) main_price,
        'SP DATA' secondary_type,
        dt_sellin dt_id
from `data-bi-prd-935c.bi_mart`.foss_sp_data_sellin_mth a
left join `data-bi-prd-935c.bi_stg`.tmp_ind_outlet_nbs_secondary_{{ vdt_id }} b
    on a.organization_id = b.organization_id
left join `data-bi-prd-935c.bi_stg`.tmp_ind_org_salmo_{{ vdt_id }} c
    on a.organization_id = c.organization_id
where mth_id = date_trunc(vdt_id,month)
    and dt_sellin=vdt_id
    and a.organization_id<>''
group by 1,2,3,4,5,6,7,8,9,10,11,12,13,16,18,19
;

-- SP DATA ALLOC - NO SELLIN using DEALER added 202308
delete from `data-bi-prd-935c.bi_mart`.fact_snd_secondary_dtl where secondary_type = 'SP DATA ALLOC' and dt_id = vdt_id;
insert into `data-bi-prd-935c.bi_mart`.fact_snd_secondary_dtl 
select c.dealer organization_id,
d.organization_name organization_nm,
d.organization_type,
d.channel,
case when d.channel in ('Traditional','Direct') then 'Traditional'
     when d.channel in ('Modern') then 'Non Traditional'
     else 'Traditional' 
end channel_grp,
'' site_outlet,
c.dealer parent_org_id,
d.organization_name parent_org_nm,
d.organization_type parent_org_type,
'' operator_id,
'' operator_name,
'' operator_type,
territoryid additional_territory,
sum(cast(amount_debit as numeric)) amount,
count(a.msisdn) hits,
timestamp(current_datetime('+7')) ppn_dttm,
sum(cast(a.main_price as numeric)) main_price, 
'SP DATA ALLOC' secondary_type,
date(a.revenue_date) dt_id
from `data-dtp-prd-aa1a.sor`.sp_data_revenue a
left join (
    select * from `data-bi-prd-935c.bi_mart`.foss_sp_data_sellin_mth
    where mth_id=date_trunc(vdt_id,month) and dt_sellin<=vdt_id
    and organization_id<>''
    ) b
    on a.msisdn=b.msisdn
left join (
    select dist_dt,msisdn,dealer from `data-bi-prd-935c.bi_mart`.foss_sp_mth
    where mth_id=date_trunc(vdt_id,month)
    ) c
    on a.msisdn=c.msisdn
left join (
    select * from `data-bi-prd-935c.bi_mart`.foss_dealer_mth
    where mth_id=date_trunc(vdt_id,month)
    ) d
    on c.dealer=d.dealer_code
where date(revenue_date)=vdt_id and b.msisdn is null
group by 1,2,3,4,5,6,7,8,9,10,11,12,13,16,18,19
;

-- VOUCHER ORI
delete from `data-bi-prd-935c.bi_mart`.fact_snd_secondary_dtl where secondary_type = 'VOU ORI' and dt_id = vdt_id;
insert into `data-bi-prd-935c.bi_mart`.fact_snd_secondary_dtl 
select a.organization_id,
    b.organization_name organization_nm,
    c.organization_type organization_type,
    coalesce(c.channel,b.channel) channel,
    case when coalesce(c.channel,b.channel) in ('Traditional','Direct') then 'Traditional'
    when coalesce(c.channel,b.channel) = 'Modern' then 'Non Traditional'
    else 'Traditional' end channel_grp, 
    b.site_id site_outlet,
    c.l1_parent_id parent_org_id,
    c.l1_parent_name parent_org_nm,
    '' parent_org_type,
    a.operator_id,
    a. operator_name,
    '' operator_type,
    '' additional_territory,
    sum(amount) amount,
    count(a.sno) hits,
    timestamp(current_datetime('+7')) ppn_dttm,
    sum(main_price) main_price,  
    'VOU ORI' secondary_type,
    dt_sellin dt_id
from `data-bi-prd-935c.bi_mart`.foss_vo_ori_sellin_mth a
left join `data-bi-prd-935c.bi_stg`.tmp_ind_outlet_nbs_secondary_{{ vdt_id }} b
    on a.organization_id = b.organization_id
left join `data-bi-prd-935c.bi_stg`.tmp_ind_org_salmo_{{ vdt_id }} c
    on a.organization_id = c.organization_id
where mth_id=date_trunc(vdt_id,month)
    and dt_sellin=vdt_id
    and a.organization_id<>''
group by 1,2,3,4,5,6,7,8,9,10,11,12,13,16,18,19
;

-- VOUCHER ORI ALLOC - NO SELLIN using DEALER added 202308
delete from `data-bi-prd-935c.bi_mart`.fact_snd_secondary_dtl where secondary_type = 'VOU ORI ALLOC' and dt_id = vdt_id;
insert into `data-bi-prd-935c.bi_mart`.fact_snd_secondary_dtl 
select c.dealer organization_id,
        d.organization_name organization_nm,
        d.organization_type,
        channel,
        case when channel in ('Traditional','Direct') then 'Traditional'
        when channel = 'Modern' then 'Non Traditional'
        else 'Traditional' end channel_grp,
        '' site_outlet,
        c.dealer parent_org_id,
        d.organization_name parent_org_nm,
        d.organization_type parent_org_type,
        '' operator_id,
        '' operator_name,
        '' operator_type,
        territoryid additional_territory,
        sum(inj_sales_price) amount,
        count(a.pm_voucher_sn) hits,
        timestamp(current_datetime('+7')) ppn_dttm,
        sum(inj_main_price) main_price,
        'VOU ORI ALLOC' secondary_type,
        parse_date('%Y%m%d',a.transactiondate) dt_id
from `data-dtp-prd-aa1a.smy`.smy_dv_redemption a
left join (
    select * from `data-bi-prd-935c.bi_mart`.foss_vo_ori_sellin_mth
    where mth_id=date_trunc(vdt_id,month) and dt_sellin<=vdt_id
    and organization_id<>''
    ) b
    on a.pm_voucher_sn=b.sno
left join (
    select dt_id,sno,dealer
    from `data-bi-prd-935c.bi_mart`.foss_vo_mth
    where mth_id=date_trunc(vdt_id,month)
    ) c
    on a.pm_voucher_sn=c.sno
left join (
    select * from `data-bi-prd-935c.bi_mart`.foss_dealer_mth
    where mth_id=date_trunc(vdt_id,month)
    ) d
    on c.dealer=d.dealer_code
where parse_date('%Y%m%d',a.transactiondate)=vdt_id
    and a.pm_voucher_status='U' and b.sno is null and prc_dt = timestamp(vdt_id + interval 1 day)
group by 1,2,3,4,5,6,7,8,9,10,11,12,13,16,18,19
;

-- SP ZERO start 220308
delete from `data-bi-prd-935c.bi_mart`.fact_snd_secondary_dtl where secondary_type = 'SP ZERO' and dt_id = vdt_id;
insert into `data-bi-prd-935c.bi_mart`.fact_snd_secondary_dtl 
select a.destination organization_id,
    c.organization_name organization_nm,
    d.organization_type,
    ltrim(a.channel) channel,
    case when ltrim(a.channel) in ('Traditional','Direct') then 'Traditional'
         else 'Non Traditional' 
    end channel_grp,
    c.site_id site_outlet,
    d.l1_parent_id parent_org_id,
    d.l1_parent_name parent_org_nm,
    '' parent_org_type,
    '' operator_id,
    '' operator_name,
    '' operator_type,
    '' additional_territory,
    sum(coalesce(cast(b.amount as numeric),cast(a.price as numeric))) amount,
    count(a.msisdn) hits,
    timestamp(current_datetime('+7')) ppn_dttm,
    sum(coalesce(cast(b.amount as numeric),cast(a.price as numeric))) main_price,
    'SP ZERO' secondary_type,
    a.dt_id
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
                /*
                select a.msisdn
                from `data-bi-prd-935c.bi_mart`.foss_sp_mth a
                left anti join (
                    select ext_product_id
                    from `data-bi-prd-935c.bi_mart`.ref_sp_vou_ori
                    group by 1
                    ) b
                    on a.program_code=b.ext_product_id
                where mth_id=substr('${var:dt_id}',1,6)
                */
    ) b
    on a.msisdn=b.msisdn
left join `data-bi-prd-935c.bi_stg`.tmp_ind_outlet_nbs_secondary_{{ vdt_id }} c
    on a.destination = c.organization_id
left join `data-bi-prd-935c.bi_stg`.tmp_ind_org_salmo_{{ vdt_id }}  d
    on a.destination = d.organization_id
where month_id = date_trunc(vdt_id,month)
    and dt_id=vdt_id
    and ltrim(a.channel)='Traditional'
    and upper(a.product_name) like '%ZERO%'
group by 1,2,3,4,5,6,7,8,9,10,11,12,13,16,18,19
;


-- drop table outlet location NBS
drop table  `data-bi-prd-935c.bi_stg`.tmp_ind_outlet_nbs_secondary_{{ vdt_id }};

-- drop table outlet salmo
drop table  `data-bi-prd-935c.bi_stg`.tmp_ind_org_salmo_{{ vdt_id }};