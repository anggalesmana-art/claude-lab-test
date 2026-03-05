declare vdt_id date default @vdt_id;
-------------------KPI SITEWISE------------------
-------------------------------------------------
--RETAIL REGISTERED
delete from `data-bi-prd-935c.bi_mart`.kpi_site_wise_dly where kpi_id = 'SND094' and dt_id = vdt_id;
insert into `data-bi-prd-935c.bi_mart`.kpi_site_wise_dly
select 'ret_register' kpi_code,'IM3' brand,site_id,
count(organization_id) metric,current_datetime('+7') process_dt,'SND094' kpi_id,vdt_id dt_id
from (select site_id,organization_id,
ROW_NUMBER() OVER (partition by organization_id ORDER BY dt_id desc) AS rn
from `data-bi-prd-935c.bi_mart`.outlet_loc_ns
where date_trunc(dt_id,month)= date_trunc(vdt_id,month))a
where rn = 1
group by 1,2,3,5,6,7;

--TERTIARY SITEWISE
delete from `data-bi-prd-935c.bi_mart`.kpi_site_wise_dly where kpi_id in ('SND065','SND084','SND085','SND086') and dt_id = vdt_id;
insert into `data-bi-prd-935c.bi_mart`.kpi_site_wise_dly
with tertiary as (
    select dt_id,organization_id,b_msisdn,tertiary_type,sum(amount_debit) amount_debit
    from `data-bi-prd-935c.bi_mart`.fact_snd_tertiary_dtl
--    where dt_id=vdt_id
 where dt_id between date_trunc(vdt_id,month) and vdt_id  and channel_grp = 'Traditional' --add by Indra Maulana Ikhsan at 20240726
 group by 1,2,3,4
    ),
outlet as (
    select * from
    (select site_id,organization_id,
    ROW_NUMBER() OVER (partition by organization_id ORDER BY dt_id desc) AS rn
    from `data-bi-prd-935c.bi_mart`.outlet_loc_ns
    where date_trunc(dt_id,month)= date_trunc(vdt_id,month)) a
    where rn=1
    ),
fav_loc as (
    select a.site_id,msisdn
    from `data-bi-prd-935c.bi_mart`.all_90d_fav_loc_dly a
    join `data-bi-prd-935c.bi_mart`.ref_site b on a.site_id=b.site_id
    where dt_id=vdt_id
    )
--TERTIARY TRADITIONAL ALL
select 'ter_sell_trad' kpi_code,'IM3' brand,coalesce(b.site_id,c.site_id) site_id,
sum(amount_debit) metric,current_datetime('+7') process_dt,'SND065' kpi_id,vdt_id dt_id
from tertiary a
left join outlet b
on a.organization_id=b.organization_id
left join fav_loc c
on a.b_msisdn=c.msisdn
group by 1,2,3,5,6,7
--TERTIARY TRADITIONAL SP
union all
select 'ter_sell_trad_sp' kpi_code,'IM3' brand,site_id,sum(amount_debit) metric,current_datetime('+7') process_dt,'SND084' kpi_id,dt_id
from tertiary a
join outlet b
on a.organization_id=b.organization_id
where dt_id=vdt_id
and tertiary_type in ('SP DATA','SP MOBO Y2','SP MOBO Y4')
group by 1,2,3,5,6,7
--TERTIARY TRADITIONAL VOU
union all
select 'ter_sell_trad_vou' kpi_code,'IM3' brand,site_id,sum(amount_debit) metric,current_datetime('+7') process_dt,'SND085' kpi_id,dt_id
from tertiary a
join outlet b
on a.organization_id=b.organization_id
where dt_id=vdt_id
and tertiary_type in ('VOU RLD','VOU REDEEM','VOU ORI','VOU ORI ALLOC')
group by 1,2,3,5,6,7
--TERTIARY TRADITIONAL SALDO
union all
select 'ter_sell_trad_saldo' kpi_code,'IM3' brand,site_id,sum(amount_debit) metric,current_datetime('+7') process_dt,'SND086' kpi_id,dt_id
from tertiary a
join outlet b
on a.organization_id=b.organization_id
where dt_id=vdt_id
and tertiary_type in ('RELOAD','SP MOBO Y3')
group by 1,2,3,5,6,7;

delete from `data-bi-prd-935c.bi_mart`.kpi_site_wise_dly where kpi_id = 'SLS0001' and dt_id = vdt_id;
--PRIMARY TRADITIONAL
insert into `data-bi-prd-935c.bi_mart`.kpi_site_wise_dly
select 'primary_trad' kpi_code,'IM3' brand,
case when a.organization_type='Dealer' then coalesce(b.cluster_name,d.sales_cluster) else c.sales_cluster end site_id,
sum(amt) metric,current_datetime('+7') process_dt,'SLS0001' kpi_id,a.dt_id
from (select dt_id,organization_id,organization_type,primary_type,sum(amount) amt from `data-bi-prd-935c.bi_mart`.fact_snd_primary
where dt_id=vdt_id
group by 1,2,3,4) a
left join (select mpc_short_code,cluster_name,region_name,sales_area_name,sub_area_name
from (select mpc_short_code,cluster_name,region_name,sales_area_name,sub_area_name,
ROW_NUMBER() OVER (partition by mpc_short_code ORDER BY dt_id desc) AS rn 
from `data-dtp-prd-aa1a.stg.mobi_master_hierarchy_feed`
where date(dt_id) between date_trunc(vdt_id,month) and vdt_id) a
where rn=1) b on a.organization_id=b.mpc_short_code
left join (select * from
(select site_id,area,sales_area,sales_cluster,micro_cluster,organization_id,organization_name,
ROW_NUMBER() OVER (partition by organization_id ORDER BY dt_id desc) AS rn
from `data-bi-prd-935c.bi_mart`.outlet_loc_ns
where date_trunc(dt_id,month)= date_trunc(vdt_id,month)) a
where rn=1) c on a.organization_id=c.organization_id
left join (select * from
(select *,
ROW_NUMBER() OVER (partition by dealer_code ORDER BY dt_id desc) AS rn
from `data-bi-prd-935c.bi_mart`.foss_dealer_mth
where date_trunc(dt_id,month)= date_trunc(vdt_id,month))a
where rn=1) d on a.organization_id=d.dealer_code
group by 1,2,3,5,6,7;

--SECONDARY OUTLET TRADITIONAL
delete from `data-bi-prd-935c.bi_mart`.kpi_site_wise_dly where kpi_id = 'SND091' and dt_id = vdt_id;
insert into `data-bi-prd-935c.bi_mart`.kpi_site_wise_dly
select 'sec_sell_ret_trad' kpi_code,'IM3' brand,b.site_id,
sum(a.amount) metric,current_datetime('+7') process_dt,'SND091' kpi_id,vdt_id dt_id
from `data-bi-prd-935c.bi_mart`.fact_snd_secondary a
left join
(select * from
(select site_id,organization_id,
ROW_NUMBER() OVER (partition by organization_id ORDER BY dt_id desc) AS rn
from `data-bi-prd-935c.bi_mart`.outlet_loc_ns
where date_trunc(dt_id,month)= date_trunc(vdt_id,month)) a
where rn=1) b on a.credit_party_id=b.organization_id
where dt_id between date_trunc(vdt_id,month) and vdt_id
group by 1,2,3,5,6,7;
-- insert into `data-bi-prd-935c.bi_mart`.kpi_site_wise_dly
-- select 'sec_sell_ret_trad' kpi_code,'IM3' brand,a.site_outlet site_id,
-- sum(a.amount) metric,current_datetime('+7') process_dt,'SND091' kpi_id,vdt_id dt_id
-- from `data-bi-prd-935c.bi_mart`.fact_snd_secondary_dtl a --change by Indra Maulana Ikhsan 20240729
-- where dt_id between date_trunc(vdt_id,month) and vdt_id and channel_grp = 'Traditional'
-- group by 1,2,3,5,6,7;

--OUTLET INJECTION AMOUNT
delete from `data-bi-prd-935c.bi_mart`.kpi_site_wise_dly where kpi_id = 'SND092' and dt_id = vdt_id;
insert into `data-bi-prd-935c.bi_mart`.kpi_site_wise_dly
select 'ret_injection_amt_mtd' kpi_code,'IM3' brand,site_id,
sum(amt) metric,current_datetime('+7') process_dt,'SND092' kpi_id,vdt_id dt_id
from (
select dt_id,organization_id,sum(amount_debit) amt
from `data-bi-prd-935c.bi_mart`.sellout_salmo_dly
where dt_id between date_trunc(vdt_id,month) and vdt_id
and channel='Traditional'
group by 1,2
union all
select dt_id,organization_id,sum(amount) amt
from `data-bi-prd-935c.bi_mart`.fact_snd_secondary
where dt_id between date_trunc(vdt_id,month) and vdt_id
and secondary_type in ('SP DATA','VOU ORI')
GROUP BY 1,2) a
left join
(select * from
(select site_id,organization_id,
ROW_NUMBER() OVER (partition by organization_id ORDER BY dt_id desc) AS rn
from `data-bi-prd-935c.bi_mart`.outlet_loc_ns
where date_trunc(dt_id,month)= date_trunc(vdt_id,month)) a
where rn=1) b on a.organization_id=b.organization_id
group by 1,2,3,5,6,7;
-- insert into `data-bi-prd-935c.bi_mart`.kpi_site_wise_dly
-- select 'ret_injection_amt_mtd' kpi_code,'IM3' brand,site_id,
-- sum(amt) metric,current_datetime('+7') process_dt,'SND092' kpi_id,vdt_id dt_id
-- from (
-- select dt_id,organization_id,sum(amount_debit) amt
-- from `data-bi-prd-935c.bi_mart`.sellout_salmo_dly
-- where dt_id between date_trunc(vdt_id,month) and vdt_id
-- and channel='Traditional'
-- group by 1,2
-- union all
-- select dt_id,organization_id,sum(amount) amt
-- from `data-bi-prd-935c.bi_mart`.fact_snd_secondary_dtl --change by Indra Maulana Ikhsan 20240729
-- where dt_id between date_trunc(vdt_id,month) and vdt_id
-- and secondary_type in ('SP DATA','VOU ORI') and channel_grp = 'Traditional'
-- GROUP BY 1,2) a
-- left join
-- (select * from
-- (select site_id,organization_id,
-- ROW_NUMBER() OVER (partition by organization_id ORDER BY dt_id desc) AS rn
-- from `data-bi-prd-935c.bi_mart`.outlet_loc_ns
-- where date_trunc(dt_id,month)= date_trunc(vdt_id,month) a
-- where rn=1) b on a.organization_id=b.organization_id
-- group by 1,2,3,5,6,7;

----------------------KPI SITEWISE----------------------
-------------------REVENUE & TRAFFIC--------------------
delete from `data-bi-prd-935c.bi_mart`.kpi_site_wise_dly where
kpi_id in 
('REV001',
'REV002',
'REV003',
'REV004',
'REV005',
'REV006',
'REV007',
'REV008',
'REV009',
'REV010',
'TRF001',
'TRF002',
'TRF003'
)
and dt_id = vdt_id;
insert into `data-bi-prd-935c.bi_mart`.kpi_site_wise_dly
with rev_site_dly as (
    select date(dt_id) dt_id,site_id,
    sum(
    ccn_voice_revenue +
    ccn_org_combo_addon_voice_rev +
    mobo_voice_rev +
    fdv_voice_rev +
    ccn_sms_revenue +
    ccn_org_combo_addon_sms_rev +
    mobo_sms_rev+
    fdv_sms_rev+
    voucher_revenue +
    (coalesce(ccn_vas_revenue,0)-coalesce(vas_rev_google,0)) + (coalesce(vas_rev_google,0)*0.15) +   
    (loan_package_revenue * 1.1) +
    loan_balance_revenue +
    loan_balance_fee +
    ccn_data_revenue - ccn_org_combo_addon_voice_rev - ccn_org_combo_addon_sms_rev +
    mobo_data_rev + fdv_data_rev + sp_data_rev + sp_fdv_data_rev +
    myim3_rev +
    ewallet_ovo_revenue+
    ewallet_gopay_revenue + 
    ewallet_shopeepay_revenue +
    ewallet_dana_revenue +
    ewallet_imkas_revenue +
    ewallet_linkaja_revenue +
    ewallet_other_revenue +
    other_rev 
    ) rev_total,
    sum(
    ccn_data_revenue - ccn_org_combo_addon_voice_rev - ccn_org_combo_addon_sms_rev +
    mobo_data_rev + fdv_data_rev + sp_data_rev + sp_fdv_data_rev
    ) rev_data,
    sum(
    mobo_data_rev + fdv_data_rev + sp_data_rev + sp_fdv_data_rev
    ) rev_data_mobo,
    sum(
    ccn_data_revenue - ccn_org_combo_addon_voice_rev - ccn_org_combo_addon_sms_rev
    ) rev_data_organic,
    sum(
    ccn_voice_revenue + ccn_org_combo_addon_voice_rev + mobo_voice_rev + fdv_voice_rev
    ) rev_voice,
    sum(
    ccn_sms_revenue+ccn_org_combo_addon_sms_rev+mobo_sms_rev+fdv_sms_rev+voucher_revenue
    ) rev_sms,
    sum
    ((coalesce(ccn_vas_revenue,0)-coalesce(vas_rev_google,0)) + (coalesce(vas_rev_google,0)*0.15)) rev_vas,
    sum(
    loan_balance_fee + loan_balance_revenue + (loan_package_revenue * 1.1)
    ) rev_loan,
    sum(
    myim3_rev+
    ewallet_ovo_revenue+
    ewallet_gopay_revenue + 
    ewallet_shopeepay_revenue +
    ewallet_dana_revenue +
    ewallet_imkas_revenue +
    ewallet_linkaja_revenue +
    ewallet_other_revenue
    ) rev_pgi,
    sum(
    other_rev
    ) rev_others,
    sum(
    ifnull(cast(ggsn_data_volume as numeric),0)) / (1024*1024*1024
    ) usg_data_gb,
    sum(
    ifnull(cast( voice_dur as numeric),0)
    ) usg_voice,
    sum(
    ifnull(cast(sms_hits as numeric),0)
    ) usg_sms
    from `data-dtp-prd-aa1a.smy.revenue_per_site_extended` 
    where date(dt_id) = vdt_id
    group by 1,2
),
rev_total_mtd as (
    select site_id,
    sum(
    ccn_voice_revenue +
    ccn_org_combo_addon_voice_rev +
    mobo_voice_rev +
    fdv_voice_rev +
    ccn_sms_revenue +
    ccn_org_combo_addon_sms_rev +
    mobo_sms_rev+
    fdv_sms_rev+
    voucher_revenue +
    ((coalesce(ccn_vas_revenue,0)-coalesce(vas_rev_google,0)) + (coalesce(vas_rev_google,0)*0.15)) +
    (loan_package_revenue * 1.1) +
    loan_balance_revenue +
    loan_balance_fee +
    ccn_data_revenue - ccn_org_combo_addon_voice_rev - ccn_org_combo_addon_sms_rev +
    mobo_data_rev + fdv_data_rev + sp_data_rev + sp_fdv_data_rev +
    myim3_rev +
    ewallet_ovo_revenue+
    ewallet_gopay_revenue +
    ewallet_shopeepay_revenue +
    ewallet_dana_revenue +
    ewallet_imkas_revenue +
    ewallet_linkaja_revenue +
    ewallet_other_revenue +
    other_rev
    ) rev_total
    from `data-dtp-prd-aa1a.smy.revenue_per_site_extended`
    where date(dt_id) between date_trunc(vdt_id,month) and vdt_id
    group by 1
)
--REVENUE TOTAL
select 'rev_total' kpi_code,'IM3' brand,site_id,sum(rev_total) metric,
current_datetime('+7') process_dt,'REV001' kpi_id,dt_id
from rev_site_dly
where rev_total!=0
group by 1,2,3,5,6,7
union all
--REVENUE TOTAL MTD
select 'rev_total_mtd' kpi_code,'IM3' brand,site_id,sum(rev_total) metric,
current_datetime('+7') process_dt,'REV010' kpi_id,vdt_id dt_id
from rev_total_mtd
where rev_total!=0
group by 1,2,3,5,6,7
union all
--REVENUE DATA
select 'rev_data' kpi_code,'IM3' brand,site_id,sum(rev_data) metric,
current_datetime('+7') process_dt,'REV002' kpi_id,dt_id
from rev_site_dly
where rev_data!=0
group by 1,2,3,5,6,7
union all
--REVENUE DATA MOBO
select 'rev_data_mobo' kpi_code,'IM3' brand,site_id,sum(rev_data_mobo) metric,
current_datetime('+7') process_dt,'REV003' kpi_id,dt_id
from rev_site_dly
where rev_data_mobo!=0
group by 1,2,3,5,6,7
union all
--REVENUE DATA ORGANIC
select 'rev_data_organic' kpi_code,'IM3' brand,site_id,sum(rev_data_organic) metric,
current_datetime('+7') process_dt,'REV004' kpi_id,dt_id
from rev_site_dly
where rev_data_organic!=0
group by 1,2,3,5,6,7
union all
--REVENUE VOICE
select 'rev_voice' kpi_code,'IM3' brand,site_id,sum(rev_voice) metric,
current_datetime('+7') process_dt,'REV005' kpi_id,dt_id
from rev_site_dly
where rev_voice!=0
group by 1,2,3,5,6,7
union all
--REVENUE SMS
select 'rev_sms' kpi_code,'IM3' brand,site_id,sum(rev_sms) metric,
current_datetime('+7') process_dt,'REV006' kpi_id,dt_id
from rev_site_dly
where rev_sms!=0
group by 1,2,3,5,6,7
union all
--REVENUE VAS
select 'rev_vas' kpi_code,'IM3' brand,site_id,sum(rev_vas) metric,
current_datetime('+7') process_dt,'REV007' kpi_id,dt_id
from rev_site_dly
where rev_vas!=0
group by 1,2,3,5,6,7
union all
--REVENUE LOAN BALANCE
select 'rev_loan' kpi_code,'IM3' brand,site_id,sum(rev_loan) metric,
current_datetime('+7') process_dt,'REV008' kpi_id,dt_id
from rev_site_dly
where rev_loan!=0
group by 1,2,3,5,6,7
union all
--REVENUE PGI
select 'rev_pgi' kpi_code,'IM3' brand,site_id,sum(rev_pgi) metric,
current_datetime('+7') process_dt,'REV009' kpi_id,dt_id
from rev_site_dly
where rev_pgi!=0
group by 1,2,3,5,6,7
union all
--REVENUE OTHERS
select 'rev_others' kpi_code,'IM3' brand,site_id,sum(rev_others) metric,
current_datetime('+7') process_dt,'REV010' kpi_id,dt_id
from rev_site_dly
where rev_others!=0
group by 1,2,3,5,6,7
union all
--USAGE TRAFFIC DATA GB
select 'usg_data_gb' kpi_code,'IM3' brand,site_id,sum(usg_data_gb) metric,
current_datetime('+7') process_dt,'TRF001' kpi_id,dt_id
from rev_site_dly
where usg_data_gb!=0
group by 1,2,3,5,6,7
union all
--USAGE TRAFFIC VOICE
select 'usg_voice' kpi_code,'IM3' brand,site_id,sum(usg_voice) metric,
current_datetime('+7') process_dt,'TRF002' kpi_id,dt_id
from rev_site_dly
where usg_voice!=0
group by 1,2,3,5,6,7
union all
--USAGE TRAFFIC SMS
select 'usg_sms' kpi_code,'IM3' brand,site_id,sum(usg_sms) metric,
current_datetime('+7') process_dt,'TRF003' kpi_id,dt_id
from rev_site_dly
where usg_sms!=0
group by 1,2,3,5,6,7
;
