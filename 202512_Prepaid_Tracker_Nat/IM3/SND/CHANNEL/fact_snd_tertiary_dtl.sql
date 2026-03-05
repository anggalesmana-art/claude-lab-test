declare vdt_id date default @vdt_id;

--===============================================================================================--
--- TERTIARY DETAIL
--===============================================================================================--

-- create tmp outlet location NBS
create or replace table `data-bi-prd-935c.bi_stg`.tmp_ind_outlet_loc_ns_{{ vdt_id }}  as
select * from 
    (
		select site_id, organization_id, organization_name,
		ROW_NUMBER() OVER (partition by organization_id ORDER BY dt_id desc) AS rn
		from `data-bi-prd-935c.bi_mart`.outlet_loc_ns
		where dt_id between date_trunc(vdt_id,month) and vdt_id
	) a
	where rn=1
;

-- create tmp site - outlet favloc carry forward
create or replace table `data-bi-prd-935c.bi_stg`.tmp_ind_subs_fav_loc_dly_carry_fwd_{{ vdt_id }}  as
select msisdn, site_id
	from `data-dtp-prd-aa1a.sor`.subs_fav_loc_dly_carry_fwd
	-- from `data-bi-prd-935c.bi_mart`.rk_all_90d_fav_loc_dly
	where date(dt_id) = vdt_id
;


-- create tmp outlet salmo
create or replace table `data-bi-prd-935c.bi_stg`.tmp_ind_org_salmo_{{ vdt_id }}  as
select organization_id, organization_name, organization_type, channel, l1_parent_id, l1_parent_name
    from `data-bi-prd-935c.bi_mart`.org_salmo
    where mth_id = date_trunc(vdt_id,month)
;

-- RELOAD MOBO
-- insert into `data-bi-prd-935c.bi_stg`.tmp_tertiary_dtl 

-- drop table if exists `data-bi-prd-935c.bi_stg`.tmp_ind_tertiary_reload_{{ vdt_id }};
-- create table `data-bi-prd-935c.bi_stg`.tmp_ind_tertiary_reload_{{ vdt_id }}  as

delete from `data-bi-prd-935c.bi_mart`.fact_snd_tertiary_dtl where tertiary_type = 'RELOAD' and dt_id = vdt_id;
insert into  `data-bi-prd-935c.bi_mart`.fact_snd_tertiary_dtl 
select upper(a.organization_id) organization_id,
coalesce(b.organization_name,d.organization_name) organization_nm,
a.organization_type,
a.channel,
case when a.channel in ('Traditional','Direct') then 'Traditional'
else 'Non Traditional' end channel_grp,
b.site_id site_outlet,
a.l1_parent_id parent_org_id,
a.l1_parent_name parent_org_nm,
a.b_msisdn,
c.site_id site_bnum,
a.product_name,
sum(cast(amount_debit as numeric)) amount_debit,
sum(cast(main_price as numeric)) main_price,
count(transaction_id) hits,
timestamp(current_datetime('+7')) ppn_dttm,
'RELOAD' tertiary_type,
dt_id
from `data-bi-prd-935c.bi_mart`.sellout_salmo_dly a
--- OUTLET NBS
left join 
    (
	select * from `data-bi-prd-935c.bi_stg`.tmp_ind_outlet_loc_ns_{{ vdt_id }}
	) b
	on a.organization_id = b.organization_id
-- CARRY FORWARD
left join (
	select * from `data-bi-prd-935c.bi_stg`.tmp_ind_subs_fav_loc_dly_carry_fwd_{{ vdt_id }}
	) c
	on a.b_msisdn = c.msisdn
-- OUTLET SALMO
left join (
    select * from `data-bi-prd-935c.bi_stg`.tmp_ind_org_salmo_{{ vdt_id }}
    ) d
    on upper(a.organization_id) = upper(d.organization_id)
where dt_id = vdt_id
    and lower(transaction_type) like '%reload%'
    --and lower(channel) in ('traditional','direct')
group by 1,2,3,4,5,6,7,8,9,10,11,15,16,17
;

--MOBO REVENUE INJECT PACK to SP
delete from `data-bi-prd-935c.bi_mart`.fact_snd_tertiary_dtl where tertiary_type like 'SP MOBO%' and dt_id = vdt_id;
insert into  `data-bi-prd-935c.bi_mart`.fact_snd_tertiary_dtl 
select upper(a.organizationid) organization_id,
coalesce(b.organization_name,d.organization_name) organization_nm,
d.organization_type,
case when a.organizationid = b.organization_id then 'Traditional'
     else d.channel 
end channel,
case when a.organizationid = b.organization_id then 'Traditional'
     when d.channel in ('Traditional','Direct') then 'Traditional'
     else 'Non Traditional' 
end channel_grp,
b.site_id site_outlet,
a.l1parentid parent_org_id,
cast(null as string) parent_org_nm,
a.b_msisdn,
c.site_id site_bnum,
a.productname product_name,
sum(cast(amount_debit as numeric)) amount_debit,
sum(cast(mainprice as numeric)) main_price,
count(transactionid) hits,
timestamp(current_datetime('+7')) ppn_dttm,
case when a.revenue_trigger='Y2' then 'SP MOBO Y2'
    when a.revenue_trigger='Y3' then 'SP MOBO Y3'
    else 'SP MOBO Y4' 
end tertiary_type,
parse_date('%Y%m%d',revenue_date) dt_id
from `data-dtp-prd-aa1a.sor`.mobo_revenue a
--- OUTLET NBS 
left join 
    (
	select * from `data-bi-prd-935c.bi_stg`.tmp_ind_outlet_loc_ns_{{ vdt_id }}
	) b
	on a.organizationid = b.organization_id
--- CARRY FORWARD
left join (
	select * from `data-bi-prd-935c.bi_stg`.tmp_ind_subs_fav_loc_dly_carry_fwd_{{ vdt_id }}
	) c
	on a.b_msisdn = c.msisdn
-- OUTLET SALMO
left join (
    select * from `data-bi-prd-935c.bi_stg`.tmp_ind_org_salmo_{{ vdt_id }}
    ) d
    on upper(a.organizationid) = upper(d.organization_id)
where parse_date('%Y%m%d',revenue_date)=vdt_id and prc_dt = timestamp(vdt_id + interval 1 day)
and substring(a.b_msisdn, 1,5) in ('62857','62858','62856','62815','62816','62855','62814')
group by  1,2,3,4,5,6,7,8,9,10,11,15,16,17
;

--MOBO FDV (Flexible Data Voucher) Pack Redemption
delete from `data-bi-prd-935c.bi_mart`.fact_snd_tertiary_dtl where tertiary_type = 'VOU REDEEM' and dt_id = vdt_id;
insert into  `data-bi-prd-935c.bi_mart`.fact_snd_tertiary_dtl 
select mobo_inj_outlet_id organization_id,
coalesce(b.organization_name,d.organization_name) organization_nm,
d.organization_type,
case when a.mobo_inj_outlet_id = b.organization_id then 'Traditional'
     else d.channel 
end channel,
case when a.mobo_inj_outlet_id = b.organization_id then 'Traditional'
     when d.channel in ('Traditional','Direct') then 'Traditional'
     else 'Non Traditional' 
end channel_grp,
b.site_id site_outlet,
a.mobo_inj_dealer_id parent_org_id,
a.mobo_inj_dealer_name parent_org_nm,
concat('62',pm_red_msisdn) b_msisdn,
c.site_id site_bnum,
a.mobo_inj_pack_name product_name,
sum(mobo_inj_sales_price) amount_debit,
sum(mobo_inj_main_price) main_price,
count(mobo_trx_id) hits,
timestamp(current_datetime('+7')) ppn_dttm,
'VOU REDEEM' tertiary_type,
date(transactiondate) dt_id
from `data-dtp-prd-aa1a.sor`.fdv_mobo_pm_join_match a
-- OUTLET NBS
left join (
	select * from `data-bi-prd-935c.bi_stg`.tmp_ind_outlet_loc_ns_{{ vdt_id }}
	) b
	on a.mobo_inj_outlet_id = b.organization_id
--- CARRY FORWARD
left join (
	select * from `data-bi-prd-935c.bi_stg`.tmp_ind_subs_fav_loc_dly_carry_fwd_{{ vdt_id }}
	) c
	on concat('62',pm_red_msisdn) = c.msisdn
-- OUTLET SALMO
left join (
    select * from `data-bi-prd-935c.bi_stg`.tmp_ind_org_salmo_{{ vdt_id }} 
    ) d
    on upper(a.mobo_inj_outlet_id) = upper(d.organization_id)
where date(transactiondate)=vdt_id
    and category='MOBO' 
    and pm_voucher_status = 'U'
    and substring(concat('62',pm_red_msisdn), 1,5) in ('62857','62858','62856','62815','62816','62855','62814')
    --and substr(case when substr(a.pm_red_msisdn,1,2)!='62' then concat('62',a.pm_red_msisdn) else a.pm_red_msisdn end,1,5) in ('62857','62858','62856','62815','62816','62855','62814')
group by 1,2,3,4,5,6,7,8,9,10,11,15,16,17
;

--MOBO FDV (Flexible Data Voucher) Reload Redemption
delete from `data-bi-prd-935c.bi_mart`.fact_snd_tertiary_dtl where tertiary_type = 'VOU RLD' and dt_id = vdt_id;
insert into  `data-bi-prd-935c.bi_mart`.fact_snd_tertiary_dtl 
select mobo_inj_outlet_id organization_id,
coalesce(b.organization_name,d.organization_name) organization_nm,
d.organization_type,
case when a.mobo_inj_outlet_id = b.organization_id then 'Traditional'
     else d.channel 
end channel,
case when a.mobo_inj_outlet_id = b.organization_id then 'Traditional'
     when d.channel in ('Traditional','Direct') then 'Traditional'
     else 'Non Traditional' 
end channel_grp,
b.site_id site_outlet,
a.mobo_inj_dealer_id parent_org_id,
a.mobo_inj_dealer_name parent_org_nm,
concat('62',pm_red_msisdn) b_msisdn,
c.site_id site_bnum,
a.mobo_inj_pack_name product_name,
sum(mobo_inj_sales_price) amt,
sum(mobo_inj_main_price) main_price,
count(pm_red_msisdn) hits,
timestamp(current_datetime('+7')) ppn_dttm,
'VOU RLD' tertiary_type,
date(transactiondate) dt_id
from `data-dtp-prd-aa1a.sor`.fdv_mobo_pm_join_match_reload a
-- outlet NBS
left join (
	select * from `data-bi-prd-935c.bi_stg`.tmp_ind_outlet_loc_ns_{{ vdt_id }}
	) b
	on a.mobo_inj_outlet_id = b.organization_id
-- CARRY FORWARD
left join (
	select * from `data-bi-prd-935c.bi_stg`.tmp_ind_subs_fav_loc_dly_carry_fwd_{{ vdt_id }}
	) c
	on concat('62',pm_red_msisdn) = c.msisdn
-- OUTLET SALMO
left join (
    select * from `data-bi-prd-935c.bi_stg`.tmp_ind_org_salmo_{{ vdt_id }} 
    ) d
    on upper(a.mobo_inj_outlet_id) = upper(d.organization_id)
where date(transactiondate)=vdt_id
    and category='MOBO'
    and pm_voucher_status = 'U'
group by 1,2,3,4,5,6,7,8,9,10,11,15,16,17
;


--TERTIARY SP DATA / SP ORI
create or replace table `data-bi-prd-935c.bi_stg`.tmp_spdata_sellin_{{ vdt_id }}  as
select a.organization_id, a.msisdn, saldomobo_id,
    case when product_name like '%SF DAT%' then 'Direct'
    else 'Traditional' end channel,
    c.organization_name,
    c.site_id,
    d.l1_parent_id,
    d.l1_parent_name
from `data-bi-prd-935c.bi_mart`.foss_sp_data_sellin_mth a
join (
        select distinct msisdn
        from `data-dtp-prd-aa1a.sor`.sp_data_revenue
        where date(revenue_date) = vdt_id
    ) b
    on a.msisdn = b.msisdn
-- OUTLET NBS
left join (
	select * from `data-bi-prd-935c.bi_stg`.tmp_ind_outlet_loc_ns_{{ vdt_id }}
	) c
	on a.organization_id = c.organization_id
-- OUTLER SALMO
left join (
       select * from  `data-bi-prd-935c.bi_stg`.tmp_ind_org_salmo_{{ vdt_id }} 
    ) d
    on a.organization_id = d.organization_id
where mth_id = date_trunc(vdt_id,month)
    and dt_sellin <= date(date_trunc(vdt_id+interval 1 month,month) - interval 1 day)
    and a.organization_id <> ''
;

create or replace table `data-bi-prd-935c.bi_stg`.tmp_spdata_alloc_{{ vdt_id }}  as
select a.msisdn, dealer,
    case when program_name like '%SF DAT%' then 'Direct'
    else 'Traditional' end channel,
    organization_name, organization_type
from `data-bi-prd-935c.bi_mart`.foss_sp_mth a
join (
        select distinct msisdn
        from `data-dtp-prd-aa1a.sor`.sp_data_revenue
        where date(revenue_date) = vdt_id
    ) b
    on a.msisdn = b.msisdn
left join (
        select dealer_code, organization_name, channel, organization_type
        from `data-bi-prd-935c.bi_mart`.foss_dealer_mth
        where mth_id = date_trunc(vdt_id,month)
    ) c
    on a.dealer = c.dealer_code
where mth_id = date_trunc(vdt_id,month)
    and dt_id <= date(date_trunc(vdt_id + interval 1 month,month) - interval 1 day)
;


-- CARRY FORWARD
create or replace table `data-bi-prd-935c.bi_stg`.tmp_spdata_favloc_{{ vdt_id }}  as
select a.msisdn, a.site_id site_bnum 
from `data-bi-prd-935c.bi_stg`.tmp_ind_subs_fav_loc_dly_carry_fwd_{{ vdt_id }} a
join (
        select distinct msisdn
        from `data-dtp-prd-aa1a.sor`.sp_data_revenue
        where date(revenue_date) = vdt_id
    ) b
    on a.msisdn = b.msisdn
;


delete from `data-bi-prd-935c.bi_mart`.fact_snd_tertiary_dtl where tertiary_type in ('SP DATA','SP DATA ALLOC') and dt_id = vdt_id;
insert into  `data-bi-prd-935c.bi_mart`.fact_snd_tertiary_dtl 
select coalesce(b.organization_id,c.dealer) organization_id,
coalesce(b.organization_name,c.organization_name) organization_nm,
case when a.msisdn=b.msisdn then 'Outlet'
     when a.msisdn=c.msisdn then 'Dealer'
end organization_type,
coalesce(b.channel,c.channel) channel,
'Traditional' channel_grp,
b.site_id site_outlet,
coalesce(b.saldomobo_id,c.dealer) parent_org_id,
coalesce(b.l1_parent_name,c.organization_name) parent_org_nm,
a.msisdn b_msisdn,
d.site_bnum,
a.service_class_name product_name,
sum(cast(a.amount_debit as numeric)) amount_debit,
sum(cast(a.main_price as numeric)) main_price,
count(a.msisdn) hits,
timestamp(current_datetime('+7')) ppn_dttm,
case when a.msisdn=b.msisdn then 'SP DATA'
else 'SP DATA ALLOC'
end tertiary_type,
date(a.revenue_date) dt_id
from `data-dtp-prd-aa1a.sor`.sp_data_revenue a
left join `data-bi-prd-935c.bi_stg`.tmp_spdata_sellin_{{ vdt_id }} b
    on a.msisdn=b.msisdn
left join `data-bi-prd-935c.bi_stg`.tmp_spdata_alloc_{{ vdt_id }} c
    on a.msisdn=c.msisdn
left join `data-bi-prd-935c.bi_stg`.tmp_spdata_favloc_{{ vdt_id }} d
	on a.msisdn = d.msisdn
where date(revenue_date) = vdt_id
group by 1,2,3,4,5,6,7,8,9,10,11,15,16,17
;


drop table if exists `data-bi-prd-935c.bi_stg`.tmp_spdata_sellin_{{ vdt_id }};
drop table if exists `data-bi-prd-935c.bi_stg`.tmp_spdata_alloc_{{ vdt_id }};
drop table if exists `data-bi-prd-935c.bi_stg`.tmp_spdata_favloc_{{ vdt_id }};



--TERTIARY VOUCHER ORI update 202308 with dealer allocation if no sellin
-- insert into `data-bi-prd-935c.bi_stg`.tmp_tertiary_dtl 

-- drop table if exists `data-bi-prd-935c.bi_stg`.tmp_ind_tertiary_vouori_{{ vdt_id }};
-- create table `data-bi-prd-935c.bi_stg`.tmp_ind_tertiary_vouori_{{ vdt_id }}  as

delete from `data-bi-prd-935c.bi_mart`.fact_snd_tertiary_dtl where tertiary_type in ('VOU ORI','VOU ORI ALLOC') and dt_id = vdt_id;
insert into  `data-bi-prd-935c.bi_mart`.fact_snd_tertiary_dtl 
select coalesce(b.organization_id,c.dealer) organization_id,
coalesce(d.organization_name,f.organization_name) organization_nm,
case when a.pm_voucher_sn = b.sno then 'Outlet'
     when a.pm_voucher_sn = c.sno then 'Dealer'
end organization_type,
'Traditional' channel,
'Traditional' channel_grp,
d.site_id site_outlet,
coalesce(b.saldomobo_id,c.dealer) parent_org_id,
coalesce(g.l1_parent_name,f.organization_name) parent_org_nm,
concat('62',a.pm_red_msisdn) b_msisdn,
e.site_id site_bnum,
a.inj_pack_name product_name,
sum(cast(a.inj_sales_price as numeric)) amount_debit,
sum(cast(a.inj_main_price as numeric)) main_price,
count(a.pm_voucher_sn) hits,
timestamp(current_datetime('+7')) ppn_dttm,
case when a.pm_voucher_sn=b.sno then 'VOU ORI'
     else 'VOU ORI ALLOC' 
end tertiary_type,
parse_date('%Y%m%d',a.transactiondate) dt_id
from `data-dtp-prd-aa1a.smy`.smy_dv_redemption a
left join (
    select *
    from `data-bi-prd-935c.bi_mart`.foss_vo_ori_sellin_mth
    where mth_id = date_trunc(vdt_id,month)
        and dt_sellin <= date(date_trunc(vdt_id + interval 1 month,month) - interval 1 day)
    ) b
    on a.pm_voucher_sn = b.sno
left join (
    select sno, dealer
    from `data-bi-prd-935c.bi_mart`.foss_vo_mth
    where mth_id = date_trunc(vdt_id,month)
        and dt_id <= date(date_trunc(vdt_id + interval 1 month,month) - interval 1 day)
    ) c
    on a.pm_voucher_sn = c.sno
-- OUTLET NBS
left join (
	select * from `data-bi-prd-935c.bi_stg`.tmp_ind_outlet_loc_ns_{{ vdt_id }}
	) d
	on b.organization_id = d.organization_id
-- CARRY FORWARD
left join (
        select * from `data-bi-prd-935c.bi_stg`.tmp_ind_subs_fav_loc_dly_carry_fwd_{{ vdt_id }}
    ) e
    on concat('62',a.pm_red_msisdn) = e.msisdn
left join (
        select dealer_code, organization_name, channel, organization_type
        from `data-bi-prd-935c.bi_mart`.foss_dealer_mth
        where mth_id = date_trunc(vdt_id,month)
    ) f
    on c.dealer = f.dealer_code
left join (
        select * from `data-bi-prd-935c.bi_stg`.tmp_ind_org_salmo_{{ vdt_id }}
    ) g
    on b.organization_id = g.organization_id
where parse_date('%Y%m%d',a.transactiondate) = vdt_id and prc_dt = timestamp(vdt_id + interval 1 day)
    and pm_voucher_status='U'
group by 1,2,3,4,5,6,7,8,9,10,11,15,16,17
;


--TERTIARY SP ZERO start 202308
-- insert into `data-bi-prd-935c.bi_stg`.tmp_tertiary_dtl 

-- drop table if exists `data-bi-prd-935c.bi_stg`.tmp_ind_tertiary_spzero_{{ vdt_id }};
-- create table `data-bi-prd-935c.bi_stg`.tmp_ind_tertiary_spzero_{{ vdt_id }}  as

delete from `data-bi-prd-935c.bi_mart`.fact_snd_tertiary_dtl where tertiary_type = 'SP ZERO' and dt_id = vdt_id;
insert into `data-bi-prd-935c.bi_mart`.fact_snd_tertiary_dtl 
select a.destination organization_id,
c.organization_name organization_nm,
d.organization_type organization_type,
ltrim(a.channel) channel,
ltrim(a.channel) channel_grp,
c.site_id site_outlet,
d.l1_parent_id parent_org_id,
d.l1_parent_name parent_org_nm,
a.msisdn b_msisdn,
e.site_id site_bnum,
a.product_name,
sum(cast(amount as numeric)) amount_debit,
sum(cast(amount as numeric)) main_price,
count(a.msisdn) hits,
timestamp(current_datetime('+7')) ppn_dttm,
'SP ZERO' tertiary_type,
dt_id
from `data-bi-prd-935c.bi_mart`.mobii_msisdn_mth a
join (    select distinct msisdn, gross_amt as amount
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
    left anti join (
        select ext_product_id from biadm.omn_ref_sp_vou_ori group by 1
        ) b
        on a.program_code = b.ext_product_id
    where mth_id = substr('${var:dt_id}',1,6)
    */
    ) b
    on a.msisdn=b.msisdn
-- OUTLET NBS
left join (
	select * from `data-bi-prd-935c.bi_stg`.tmp_ind_outlet_loc_ns_{{ vdt_id }}
	) c 
	on a.destination = c.organization_id
-- OUTLET SALMO
left join (
        select * from `data-bi-prd-935c.bi_stg`.tmp_ind_org_salmo_{{ vdt_id }}
    ) d
    on a.destination = d.organization_id
-- CARRY FORWARD
left join (
        select * from `data-bi-prd-935c.bi_stg`.tmp_ind_subs_fav_loc_dly_carry_fwd_{{ vdt_id }}
    ) e
    on a.msisdn = e.msisdn
where month_id = date_trunc(vdt_id,month)
    and dt_id = vdt_id
    and ltrim(a.channel) = 'Traditional' 
group by 1,2,3,4,5,6,7,8,9,10,11,15,16,17
;


--TERTIARY BANK IGATE
-- insert into `data-bi-prd-935c.bi_stg`.tmp_tertiary_dtl 

-- drop table if exists `data-bi-prd-935c.bi_stg`.tmp_ind_tertiary_igate_{{ vdt_id }};
-- create table `data-bi-prd-935c.bi_stg`.tmp_ind_tertiary_igate_{{ vdt_id }}  as

delete from `data-bi-prd-935c.bi_mart`.fact_snd_tertiary_dtl where tertiary_type = 'IGATE RLD' and dt_id = vdt_id;
insert into  `data-bi-prd-935c.bi_mart`.fact_snd_tertiary_dtl 
select bank_code organization_id,
outlet_name organization_nm,
'Bank' organization_type,
'Bank' channel,
'Non Traditional' channel_grp,
'' site_outlet,
'1' parent_org_id,
'INDOSAT' parent_org_nm,
a.msisdn b_msisdn,
c.site_id site_bnum,
cast(dnmn_val as string) product_name,
sum(tot_rechrg_idr_val) amount_debit,
sum(tot_rechrg_idr_val) main_price,
sum(tot_rechrg) hits,
timestamp(current_datetime('+7')) ppn_dttm,
'IGATE RLD' tertiary_type,
date(dt_id)
from `data-dtp-prd-aa1a.smy`.cst_rechrg_dly_smy a
left join (
    select outlet_code, outlet_name
    from `data-bi-prd-935c.bi_mart`.ref_mochan
    where channel='Bank IGate'
    ) b on a.bank_code = b.outlet_code
-- CARRY FORWARD
left join (
        select * from `data-bi-prd-935c.bi_stg`.tmp_ind_subs_fav_loc_dly_carry_fwd_{{ vdt_id }}
    ) c
    on a.msisdn = c.msisdn
where date(dt_id) =vdt_id and bank_code > '0'
group by 1,2,3,4,5,6,7,8,9,10,11,15,16,17
;


-- -- capture current month site is null

-- insert into  `data-bi-prd-935c.bi_mart`.fact_snd_tertiary_dtl 
-- select organization_id, organization_nm, organization_type, channel, channel_grp, site_outlet, parent_org_id, parent_org_nm,
--         b_msisdn, coalesce(a.site_bnum,b.site_id) site_bnum, product_name, amount_debit, main_price, hits, 
--        timestamp(current_datetime('+7')) ppn_dttm, tertiary_type, dt_id
-- from 
-- (
--     select * from `data-bi-prd-935c.bi_mart`.fact_snd_tertiary_dtl 
--     where substr(dt_id,1,6) = date_trunc(vdt_id,month) 
--     and dt_id <= from_timestamp(date_add(date(from_unixtime(unix_timestamp(vdt_id,'yyyyMMdd'))),-1),'yyyyMMdd')
-- )a
-- -- CARRY FORWARD
-- left join (
--         select * from `data-bi-prd-935c.bi_stg`.tmp_ind_subs_fav_loc_dly_carry_fwd_{{ vdt_id }}
--     ) b
--  on a.b_msisdn = b.msisdn
-- ;

update `data-bi-prd-935c.bi_mart`.fact_snd_tertiary_dtl a
set a.site_bnum = coalesce(a.site_bnum,b.site_id)
from `data-bi-prd-935c.bi_stg`.tmp_ind_subs_fav_loc_dly_carry_fwd_{{ vdt_id }} b  
where a.dt_id between date_trunc(vdt_id,month) and vdt_id and a.b_msisdn = b.msisdn;

drop table if exists `data-bi-prd-935c.bi_stg`.tmp_ind_outlet_loc_ns_{{ vdt_id }};
drop table if exists `data-bi-prd-935c.bi_stg`.tmp_ind_subs_fav_loc_dly_carry_fwd_{{ vdt_id }};
drop table if exists `data-bi-prd-935c.bi_stg`.tmp_ind_org_salmo_{{ vdt_id }};
