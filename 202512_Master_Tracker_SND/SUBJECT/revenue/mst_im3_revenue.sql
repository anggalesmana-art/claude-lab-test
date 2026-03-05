 --------------------------------------
-------------- ATL CVM ---------------
--------------------------------------
declare vdt_id date default @vdt_id;

delete from `data-bi-prd-935c.bi_dev`.ioh_snd_master_kpi_detail where dt_id = vdt_id and kpi in 
(
  'cvm_outlet',
  'atl_outlet',
  'cvm_revenue',
  'atl_revenue',
  'cvm_sachet_outlet',
  'atl_sachet_outlet',
  'cvm_sachet_revenue',
  'atl_sachet_revenue'
) and brand ='IM3';
insert into  `data-bi-prd-935c.bi_dev`.ioh_snd_master_kpi_detail  
with main as
    (
        select
            parse_date('%Y-%m-%d',left(`datetime`,10)) dt_id,
            a.organization_id,
            a.product_name,
            a.product_group,
            (case
                when cast(b.validity_package as int64) <=4 then '1.Sachet'
                when cast(b.validity_package as int64) <=20 then '2.Weekly'
                when cast(b.validity_package as int64) >20 then '3.Monthly'
            end) validity_grp,
            sum(CAST(a.main_price AS numeric)) main_price,
            sum(CAST(a.amount_debit AS numeric)) amount_debit
        from `data-dtp-prd-aa1a.stg`.ifrs_prepaid_salmo a
        left join
            `data-cvm-prd-c324.sor.im3_ref_mobo` b
            on a.product_name = b.product_name
        WHERE 
            a.transaction_type IN (
                'Bulk Voucher Card Injection',
                'Purchase Data Package',
                'Bulk Purchase Package Transaction',
                'VoucherCardInjection'
                )
            AND a.status_description='Success'
            AND a.transaction_status='Completed'
            AND (lower(a.channel) LIKE '%traditional%' or lower(a.channel) LIKE '%direct%') --AND lower(a.organization_type) LIKE '%outlet%'
            and (upper(a.cluster) not like '%TEST%' and upper(a.cluster) not like '%SEV%') 
            and (
                    (date_trunc(parse_date('%Y-%m-%d',left(`datetime`,10)),month) = date_trunc(vdt_id,month) and parse_date('%Y-%m-%d',left(`datetime`,10)) <= vdt_id)  and
                    date(process_id) between date_trunc(vdt_id,month) and vdt_id+ interval 1 day
                )
            and coalesce(substring(a.b_msisdn, 1,5),'') not in ('62895', '62896', '62897', '62898', '62899')

        group by 1,2,3,4,5
    ),
    param as
    (
        select 'cvm_outlet' par union all
        select 'atl_outlet' par union all
        select 'cvm_revenue' par union all
        select 'atl_revenue' par union all
        select 'cvm_sachet_outlet' par union all
        select 'atl_sachet_outlet' par union all
        select 'cvm_sachet_revenue' par union all
        select 'atl_sachet_revenue' par
    )
--- final  -----
select 'IM3' brand, 'outlet' level, organization_id as level_value, 
    cast(
        sum(case
        when param.par = 'cvm_outlet' then cvm_outlet
        when param.par = 'atl_outlet' then atl_outlet
        when param.par = 'cvm_revenue' then cvm_revenue
        when param.par = 'atl_revenue' then atl_revenue
        when param.par = 'cvm_sachet_outlet' then cvm_sachet_outlet
        when param.par = 'atl_sachet_outlet' then atl_sachet_outlet
        when param.par = 'cvm_sachet_revenue' then cvm_sachet_revenue
        when param.par = 'atl_sachet_revenue' then atl_sachet_revenue
        end) as numeric
        ) value, 
    'mtd' as time_flag, 
     timestamp(current_datetime('+7')) as insert_date,
     param.par as kpi, 
    vdt_id dt_id
from     
    param
cross join
    (
        select 
            organization_id,
            (case
                when date_trunc(dt_id,month) = date_trunc(vdt_id,month) then 'mtd'
            end) mthf,
            count(distinct case when product_group = 'CVM' then organization_id end) cvm_outlet,
            count(distinct case when product_group != 'CVM' then organization_id end) atl_outlet,
            ifnull(sum(case when product_group = 'CVM' then main_price end),0) cvm_revenue,
            ifnull(sum(case when product_group != 'CVM' then main_price end),0) atl_revenue,
            count(distinct case when product_group = 'CVM' and validity_grp = '1.Sachet' then organization_id end) cvm_sachet_outlet,
            count(distinct case when product_group != 'CVM' and validity_grp = '1.Sachet' then organization_id end) atl_sachet_outlet,
            ifnull(sum(case when product_group = 'CVM' and validity_grp = '1.Sachet' then main_price end),0) cvm_sachet_revenue,
            ifnull(sum(case when product_group != 'CVM' and validity_grp = '1.Sachet' then main_price end),0) atl_sachet_revenue
        from main
        group by 1,2
    ) xx
group by 1,2,3,5,6,7,8
;



--------------------------------------
-------- ISIMPEL Revenue -------------
--------------------------------------

delete from `data-bi-prd-935c.bi_dev`.ioh_snd_master_kpi_detail where dt_id = vdt_id and kpi = 'isimple_rev' and brand ='IM3';
insert into  `data-bi-prd-935c.bi_dev`.ioh_snd_master_kpi_detail 
select 'IM3' brand, 'site' level, y.site_id as level_value, 
    cast(sum(total) as numeric) value, 
    'mtd' as time_flag, 
     timestamp(current_datetime('+7')) as insert_date,
    'isimple_rev' as kpi, 
    vdt_id as dt_id
from
    (
        select 
            parse_date('%Y-%m-%d',left(`datetime`,10)) dt_id,transaction_type type,l1_parent_name parent,organization_name child,channel, b_msisdn msisdn,
            sum(cast(amount_debit as numeric))/1.11 total
        from `data-dtp-prd-aa1a.stg`.ifrs_prepaid_salmo
        where ((date_trunc(parse_date('%Y-%m-%d',left(`datetime`,10)),month) = date_trunc(vdt_id,month) and parse_date('%Y-%m-%d',left(`datetime`,10)) <= vdt_id)  and
date(process_id) between date_trunc(vdt_id,month) and vdt_id+ interval 1 day
                )
            and status_description = 'Success' 
            and transaction_status = 'Completed'
            and (upper(cluster) not like '%TEST%' and upper(cluster) not like '%SEV%') 
            AND (lower(channel) LIKE '%traditional%' or lower(channel) LIKE '%direct%') 
            AND REGEXP_CONTAINS(organization_id, r'^[0-9]+$')
            and transaction_channel = 'API' --API ISIMPEL
            and coalesce(substring(b_msisdn, 1,5),'') not in ('62895', '62896', '62897', '62898', '62899')
        group by 1,2,3,4,5,6
    ) x
left join  
    ( 
        select site_id,msisdn, dt_id
        from `data-bi-prd-935c.bi_mart`.all_90d_fav_loc_dly 
        where dt_id in (vdt_id
                        )
    ) y 
    on x.msisdn=y.msisdn
    and date_trunc(x.dt_id,month) = date_trunc(y.dt_id,month)
group by 1,2,3,5,6,7,8
;



--------------------------------------
---------- ISIMPLE TRX USER ----------
--------------------------------------

delete from `data-bi-prd-935c.bi_dev`.ioh_snd_master_kpi_detail where dt_id = vdt_id and kpi = 'isimple_trx_user' and brand ='IM3';
insert into  `data-bi-prd-935c.bi_dev`.ioh_snd_master_kpi_detail 
select 'IM3' brand, 'outlet' level, organization_id as level_value, 
    cast(count(distinct organization_id) as numeric) value, 
    (case
        when date_trunc(parse_date('%Y-%m-%d',left(`datetime`,10)),month) = date_trunc(vdt_id,month) then 'mtd'
    end) as time_flag, 
    timestamp(current_datetime('+7')) as insert_date,
    'isimple_trx_user' as kpi, 
    vdt_id as dt_id
from `data-dtp-prd-aa1a.stg`.ifrs_prepaid_salmo
where 
        (date_trunc(parse_date('%Y-%m-%d',left(`datetime`,10)),month) = date_trunc(vdt_id,month) and parse_date('%Y-%m-%d',left(`datetime`,10)) <= vdt_id) and
date(process_id) between date_trunc(vdt_id,month) and vdt_id+ interval 1 day
    and msisdn <> ""
    and upper(channel) = 'TRADITIONAL'
    and upper(transaction_channel) = 'API'
    and coalesce(substring(b_msisdn, 1,5),'') not in ('62895', '62896', '62897', '62898', '62899')
group by 1,2,3,5,6,7,8
;


-- --------------------------------------
-- --------- ISIMPLE LOGIN USER ---------
-- --------------------------------------
-- Source Incomplete
-- delete from `data-bi-prd-935c.bi_dev`.ioh_snd_master_kpi_detail where dt_id = vdt_id and kpi = 'isimple_login_user' and brand ='IM3';
-- insert into  `data-bi-prd-935c.bi_dev`.ioh_snd_master_kpi_detail 
-- select 'IM3' brand, 'outlet' level, outlet_id as level_value, 
--     cast(count(distinct outlet_id) as numeric) value, 
--     (case
--          when strleft(part_id,6) = date_trunc(vdt_id,month) then 'mtd'
--     end) as time_flag, 
--     timestamp(current_datetime('+7')) as insert_date,
--     'isimple_login_user' as kpi, 
--     vdt_id as dt_id
-- from rdm.bai_tbl_simple_log
-- where 
--     (
--         (strleft(part_id,6) = date_trunc(vdt_id,month) and part_id <= vdt_id)  
--     )
--     and (outlet_id is not null or outlet_id <> "")
--     and upper(activity) = 'LOGIN'
-- group by 1,2,3,5,6,7,8
-- ;



-------------------------------------
-------- revenue per service  --------
--------------------------------------

-------- Revenue new --------

delete from `data-bi-prd-935c.bi_dev`.ioh_snd_master_kpi_detail where dt_id  between date_trunc(vdt_id,month)  and vdt_id and kpi in 
(
'tot_rev_all',
'tot_rev_data',
'tot_rev_mobo',
'tot_rev_organic',
'tot_rev_voice',
'tot_rev_sms',
'tot_rev_vas',
'tot_rev_loan'
)
and brand ='IM3';
insert into  `data-bi-prd-935c.bi_dev`.ioh_snd_master_kpi_detail 
with rev_ds as (
        select date(dt_id) dt_id, site_id
        , cast(sum(coalesce(mobo_data_rev,0) + coalesce(fdv_data_rev,0) + coalesce(sp_data_rev,0) + coalesce(sp_fdv_data_rev,0))/1.11 as numeric) as mobo
        , cast(sum(coalesce(ccn_data_revenue,0) - coalesce(ccn_org_combo_addon_voice_rev,0) - coalesce(ccn_org_combo_addon_sms_rev,0))/1.11 as numeric) as organic
        , cast(sum(coalesce(ccn_voice_revenue,0) + coalesce(ccn_org_combo_addon_voice_rev,0) + coalesce(mobo_voice_rev,0) + coalesce(fdv_voice_rev,0))/1.11 as numeric) as voice
        , cast(sum(coalesce(ccn_sms_revenue,0) + coalesce(ccn_org_combo_addon_sms_rev,0) + coalesce(mobo_sms_rev,0) + coalesce(fdv_sms_rev,0) + coalesce(voucher_revenue,0))/1.11 as numeric) as sms
        --, cast(sum((coalesce(ccn_vas_revenue,0) * im3_share_total))/1.11 as numeric) as vas
        , cast(sum( (coalesce(ccn_vas_revenue,0)-coalesce(vas_rev_google,0)) + (coalesce(vas_rev_google,0)*0.15) )/1.11 as numeric) as vas -- VAS
        , cast(sum((coalesce(loan_package_revenue,0) * 1.1) + coalesce(loan_balance_revenue,0) + loan_balance_fee)/1.11 as numeric) as loan_balance
        , cast(sum(
            coalesce(myim3_rev,0) + coalesce(other_rev,0) +
            coalesce(ewallet_ovo_revenue,0) + coalesce(ewallet_gopay_revenue,0) + coalesce(ewallet_shopeepay_revenue,0) +
            coalesce(ewallet_dana_revenue,0) + coalesce(ewallet_imkas_revenue,0) + coalesce(ewallet_linkaja_revenue,0) + coalesce(ewallet_other_revenue,0)
        )/1.11 as numeric) as pgi
    from `data-dtp-prd-aa1a.smy`.revenue_per_site_extended 
    where date(dt_id) between date_trunc(vdt_id,month)  and vdt_id
    group by 1,2
        )
    -------- Rev All  --------
    select 'IM3' as brand, 
            'site' as level, 
            site_id as level_value, 
            cast(sum(mobo+organic+voice+sms+vas+loan_balance+pgi) as numeric) value,  -- nett 
            'dly' as time_flag, 
            timestamp(current_datetime('+7')) as insert_date,
            'tot_rev_all' as kpi,
            dt_id
    from rev_ds
    group by 1,2,3,5,6,7,8
    union all 
    -------- Rev data  --------
    select 'IM3' as brand, 
            'site' as level, 
            site_id as level_value, 
            cast(sum(mobo+organic+pgi) as numeric) value,  -- nett 
            'dly' as time_flag, 
            timestamp(current_datetime('+7')) as insert_date,
            'tot_rev_data' as kpi,
            dt_id
    from rev_ds
    group by 1,2,3,5,6,7,8
    union all 
    -------- Rev Mobo  --------
    select 'IM3' as brand, 
            'site' as level, 
            site_id as level_value, 
            cast(sum(mobo) as numeric) value,  -- nett 
            'dly' as time_flag, 
            timestamp(current_datetime('+7')) as insert_date,
            'tot_rev_mobo' as kpi,
            dt_id
    from rev_ds
    group by 1,2,3,5,6,7,8
    union all 
    -------- Rev Organic  --------
    select 'IM3' as brand, 
            'site' as level, 
            site_id as level_value, 
            cast(sum(organic+pgi) as numeric) value,  -- nett 
            'dly' as time_flag, 
            timestamp(current_datetime('+7')) as insert_date,
            'tot_rev_organic' as kpi,
            dt_id
    from rev_ds
    group by 1,2,3,5,6,7,8
    union all 
    -------- Rev voice  --------
    select 'IM3' as brand, 
            'site' as level, 
            site_id as level_value, 
            cast(sum(voice) as numeric) value,  -- nett 
            'dly' as time_flag, 
            timestamp(current_datetime('+7')) as insert_date,
            'tot_rev_voice' as kpi,
            dt_id
    from rev_ds
    group by 1,2,3,5,6,7,8
    union all 
    -------- Rev sms  --------
    select 'IM3' as brand, 
            'site' as level, 
            site_id as level_value, 
            cast(sum(sms) as numeric) value,  -- nett 
            'dly' as time_flag, 
            timestamp(current_datetime('+7')) as insert_date,
            'tot_rev_sms' as kpi,
            dt_id
    from rev_ds
    group by 1,2,3,5,6,7,8
    union all 
    -------- Rev vas  --------
    select 'IM3' as brand, 
            'site' as level, 
            site_id as level_value, 
            cast(sum(vas) as numeric) value,  -- nett 
            'dly' as time_flag, 
            timestamp(current_datetime('+7')) as insert_date,
            'tot_rev_vas' as kpi,
            dt_id
    from rev_ds
    group by 1,2,3,5,6,7,8
    union all 
    -------- Rev loan balance  --------
    select 'IM3' as brand, 
            'site' as level, 
            site_id as level_value, 
            cast(sum(loan_balance) as numeric) value,  -- nett 
            'dly' as time_flag, 
            timestamp(current_datetime('+7')) as insert_date,
            'tot_rev_loan' as kpi,
            dt_id
    from rev_ds
    group by 1,2,3,5,6,7,8
;


--------------------------------------
---- Revenue Non Data  -------
--------------------------------------

delete from `data-bi-prd-935c.bi_dev`.ioh_snd_master_kpi_detail where dt_id between date_trunc(vdt_id,month)  and vdt_id  and kpi = 'tot_rev_non_data_ds' and brand ='IM3';
insert into  `data-bi-prd-935c.bi_dev`.ioh_snd_master_kpi_detail 
select 'IM3' brand, 'site' level, level_value, 
    cast(sum(case when kpi ='tot_rev_all' then values else values*-1 end ) as numeric) value, 
    'mtd' as time_flag, 
     timestamp(current_datetime('+7')) as insert_date,
     'tot_rev_non_data_ds' as kpi, 
     dt_id
from  `data-bi-prd-935c.bi_dev`.ioh_snd_master_kpi_detail
where kpi in ('tot_rev_all','tot_rev_data') and brand = 'IM3'
    and dt_id between date_trunc(vdt_id,month)  and vdt_id 
group by 1,2,3,5,6,7,8
;

--Waiting `data-cvm-prd-c324.dm.cvm_revenue_dashboard`

----------------------------------------
---- Revenue MOBO TRAD & NON TRAD  -----
----------------------------------------

delete from `data-bi-prd-935c.bi_dev`.ioh_snd_master_kpi_detail where dt_id between date_trunc(vdt_id,month) and vdt_id and kpi = 'mobo_rev_trad' and brand ='IM3';
insert into  `data-bi-prd-935c.bi_dev`.ioh_snd_master_kpi_detail 
    with rev as (
            select date(daydate) daydate,
                site_id, 
                sum(case when service_type_name ='BROADBAND' then  netrevenue end) rev_data,
                sum(case when service_type_name not in ('BROADBAND') then  netrevenue end) rev_non_data,
                sum(case when channel = 'MOBO-TRADE' then netrevenue end) mobo_rev_trad,
                sum(case when channel = 'MOBO-NON TRADE' then netrevenue end) mobo_rev_modern,
                sum(case when channel in ('MOBO-NON TRADE','MOBO-TRADE')  then netrevenue end) mobo_rev,
                sum(netrevenue) net_rev
            from  
             ( 
                    select 
                    channel2,
                    kpi as kpi,
                    case 
                    	when kpi in ('DATA ORGANIC', 'PGI', 'REVENUE FDV', 'REVENUE MOBO', 'REVENUE VOUCHER ORI', 'REVENUE SP DATA', 'EWALLET', 'REVENUE OLA', 'REVENUE PGI WA') and
                    		 svc_typ in ('DATA','SMS','VOICE') then 'BROADBAND' 
                    	when kpi in ('ALL PPU') and svc_typ in ('DATA') then 'BROADBAND' 
                    	when kpi in ('ALL PPU') and svc_typ in ('SMS') then 'SMS + MMS' 
                    	when kpi in ('ALL PPU') and svc_typ in ('VOICE') then 'VOICE + VIDEO' 
                    	when kpi = 'VOICE' then 'VOICE + VIDEO'
                    	when kpi = 'SMS' then 'SMS + MMS'
                    	when kpi = 'VAS' then 'VAS + LOAN'
                    	when kpi = 'LOAN BALANCE' then 'LOAN BALANCE'
                    	else 'OTHERS' 
                    end as service_type_name,
                    date(daydate) daydate,
                    source as kpi_1,
                    ------------
                    case 
                    	when SOURCE = 'RETAIL' then channel 
                    	when SOURCE = 'ORGANIC' then channel2 
                    end as kpi_2,
                    -----------
                    case
                    	when kpi in ('DATA ORGANIC', 'PGI', 'EWALLET','REVENUE PGI WA','REVENUE OLA','ALL PPU') then 'ORGANIC'
                    	-- when kpi in ('VAS','LOAN BALANCE') then 'ORGANIC'
                    	when upper(channel) in ('ONLINE','BANK','MODERN') then 'MOBO-NON TRADE'
                    	when source = 'RETAIL' and kpi in ('REVENUE MOBO','REVENUE FDV','REVENUE VOUCHER ORI','REVENUE SP DATA') then 'MOBO-TRADE'
                    	when source = 'ORGANIC' then 'ORGANIC'
                    end channel,
                    -------------
                    case
                            	when SOURCE = 'RETAIL' AND (upper(channel) in ('BANK')) then 'BANK'
                            	when SOURCE = 'RETAIL' AND (upper(channel) in ('ONLINE')) then 'MOCHAN ONLINE'
                            	when SOURCE = 'RETAIL' AND (upper(channel) in ('MODERN')) then 'MOCHAN OFFLINE'
                            	when kpi in ('REVENUE SP DATA') then 'TRADE-SP'
                            	when kpi in ('REVENUE MOBO') and upper(revenue_trigger) = 'Y2' then 'TRADE-SP'
                            	when kpi in ('REVENUE FDV', 'REVENUE VOUCHER ORI','REVENUE MOBO') then 'TRADE-REBUY'
                            	when kpi in ('PGI','EWALLET','REVENUE PGI WA') then 'PGI'
                            --	when kpi in ('VAS','LOAN BALANCE') then 'APPS'  
                            	when upper(channel2) like '%MYIM3%' then 'APPS'
                            	when upper(channel2) like '%UMB%' then 'UMB'
                            	when upper(channel2) in ('RENEWAL','GIFT') then 'UMB'
                            	when upper(channel2) = 'PGI' then 'PGI'
                            	else 'OTHERS' 
                    end channel_wise,
                    site_id,
                    ----------
                    sum(sales_price) as netrevenue
                   from `data-cvm-prd-c324.dm.cvm_revenue_dashboard` a
                    where date(daydate) between date_trunc(vdt_id,month) and vdt_id  
                    and kpi in ('DATA ORGANIC', 'PGI', 'REVENUE FDV', 'REVENUE MOBO', 'REVENUE VOUCHER ORI', 'REVENUE SP DATA', 'EWALLET', 'REVENUE OLA', 'REVENUE PGI WA') 
                    group by 1,2,3,4,5,6,7,8,9
                union all
                    select 
                    channel2,
                    kpi,
                    ------------
                    case 
                    	when kpi in ('DATA ORGANIC', 'PGI', 'REVENUE FDV', 'REVENUE MOBO', 'REVENUE VOUCHER ORI', 'REVENUE SP DATA', 'EWALLET', 'REVENUE OLA', 'REVENUE PGI WA') 
                    	    and svc_typ in ('DATA','SMS','VOICE') then 'BROADBAND' 
                    	when kpi in ('ALL PPU') and svc_typ in ('DATA') then 'BROADBAND' 
                    	when kpi in ('ALL PPU') and svc_typ in ('SMS') then 'SMS + MMS' 
                    	when kpi in ('ALL PPU') and svc_typ in ('VOICE') then 'VOICE + VIDEO' 
                    	when kpi = 'VOICE' then 'VOICE + VIDEO'
                    	when kpi = 'SMS' then 'SMS + MMS'
                    	when kpi = 'VAS' then 'VAS + LOAN'
                    	when kpi = 'LOAN BALANCE' then 'LOAN BALANCE'
                    	else 'OTHERS' 
                    end as service_type_name,
                    date(daydate) daydate,
                    source as kpi_1,
                    ------------
                    case 
                    when SOURCE = 'RETAIL' then channel 
                    when SOURCE = 'ORGANIC' then channel2 
                    end as kpi_2,
                    -----------
                    ----------
                   case
                    	when kpi in ('DATA ORGANIC', 'PGI', 'EWALLET','REVENUE PGI WA','REVENUE OLA','ALL PPU') then 'ORGANIC'
                    --	when kpi in ('VAS','LOAN BALANCE') then 'ORGANIC'
                    	when upper(channel) in ('ONLINE','BANK','MODERN') then 'MOBO-NON TRADE'
                    	when source = 'RETAIL' and kpi in ('REVENUE MOBO','REVENUE FDV','REVENUE VOUCHER ORI','REVENUE SP DATA') then 'MOBO-TRADE'
                    	when source = 'ORGANIC' then 'ORGANIC'
                    end channel,
                    -------------
                    case
                            	when SOURCE = 'RETAIL' AND (upper(channel) in ('BANK')) then 'BANK'
                            	when SOURCE = 'RETAIL' AND (upper(channel) in ('ONLINE')) then 'MOCHAN ONLINE'
                            	when SOURCE = 'RETAIL' AND (upper(channel) in ('MODERN')) then 'MOCHAN OFFLINE'
                            	when kpi in ('REVENUE SP DATA') then 'TRADE-SP'
                            	when kpi in ('REVENUE MOBO') and upper(revenue_trigger) = 'Y2' then 'TRADE-SP'
                            	when kpi in ('REVENUE FDV', 'REVENUE VOUCHER ORI','REVENUE MOBO') then 'TRADE-REBUY'
                            	when kpi in ('PGI','EWALLET','REVENUE PGI WA') then 'PGI'
                            --	when kpi in ('VAS','LOAN BALANCE') then 'APPS' 
                            	when upper(channel2) like '%MYIM3%' then 'APPS'
                            	when upper(channel2) like '%UMB%' then 'UMB'
                            	when upper(channel2) in ('RENEWAL','GIFT') then 'UMB'
                            	when upper(channel2) = 'PGI' then 'PGI'
                            	else 'OTHERS' 
                    end channel_wise,
                    ----------
                    site_id,
                    sum(sales_price) as netrevenue
                    from `data-cvm-prd-c324.dm.cvm_revenue_dashboard` a
                    where date(daydate) between date_trunc(vdt_id,month) and vdt_id
                    and kpi not in ('DATA ORGANIC', 'PGI', 'REVENUE FDV', 'REVENUE MOBO', 'REVENUE VOUCHER ORI', 'REVENUE SP DATA', 'EWALLET', 'REVENUE OLA', 'REVENUE PGI WA')
                    group by 1,2,3,4,5,6,7,8,9
                )a  
            group by 1,2
    )
--------------------------------------
---- MOBO Revenue Trad  -------
--------------------------------------
select 'IM3' brand, 'site' level, site_id as level_value, 
    cast(sum(mobo_rev_trad)  as numeric) value, 
    'dly' as time_flag, 
     timestamp(current_datetime('+7')) as insert_date,
     'mobo_rev_trad' as kpi, 
     date(daydate) as dt_id
from rev 
group by 1,2,3,5,6,7,8
;

--------------------------------------
---- MOBO Revenue Non Trad -------
--------------------------------------

delete from `data-bi-prd-935c.bi_dev`.ioh_snd_master_kpi_detail where dt_id between date_trunc(vdt_id,month) and vdt_id and kpi = 'mobo_rev_modern' and brand ='IM3';
insert into  `data-bi-prd-935c.bi_dev`.ioh_snd_master_kpi_detail 
select 'IM3' brand, 'site' level, level_value, 
    cast(sum(case when kpi ='tot_rev_data' then values else values*-1 end ) as numeric) value, 
    'dly' as time_flag, 
     timestamp(current_datetime('+7')) as insert_date,
     'mobo_rev_modern' as kpi, 
     dt_id
from  `data-bi-prd-935c.bi_dev`.ioh_snd_master_kpi_detail
where kpi in ('tot_rev_data','mobo_rev_trad') and brand = 'IM3'
    and dt_id between date_trunc(vdt_id,month) and vdt_id
group by 1,2,3,5,6,7,8
;

-------------------------------------
-------- revenue rolling 30d  --------
--------------------------------------
-------- Revenue 30 Days --------

delete from `data-bi-prd-935c.bi_dev`.ioh_snd_master_kpi_detail where dt_id = vdt_id and kpi in('tot_rev_30', 'tot_rev_data_30') and brand ='IM3';
insert into  `data-bi-prd-935c.bi_dev`.ioh_snd_master_kpi_detail 
with rev_ds as (
        select dt_id, site_id
        , cast(sum(coalesce(mobo_data_rev,0) + coalesce(fdv_data_rev,0) + coalesce(sp_data_rev,0) + coalesce(sp_fdv_data_rev,0))/1.11 as numeric) as mobo
        , cast(sum(coalesce(ccn_data_revenue,0) - coalesce(ccn_org_combo_addon_voice_rev,0) - coalesce(ccn_org_combo_addon_sms_rev,0))/1.11 as numeric) as organic
        , cast(sum(coalesce(ccn_voice_revenue,0) + coalesce(ccn_org_combo_addon_voice_rev,0) + coalesce(mobo_voice_rev,0) + coalesce(fdv_voice_rev,0))/1.11 as numeric) as voice
        , cast(sum(coalesce(ccn_sms_revenue,0) + coalesce(ccn_org_combo_addon_sms_rev,0) + coalesce(mobo_sms_rev,0) + coalesce(fdv_sms_rev,0) + coalesce(voucher_revenue,0))/1.11 as numeric) as sms
        --, cast(sum((coalesce(ccn_vas_revenue,0) * im3_share_total))/1.11 as numeric) as vas
        , cast(sum( (coalesce(ccn_vas_revenue,0)-coalesce(vas_rev_google,0)) + (coalesce(vas_rev_google,0)*0.15) )/1.11 as numeric) as vas -- VAS
        , cast(sum((coalesce(loan_package_revenue,0) * 1.1) + coalesce(loan_balance_revenue,0) + loan_balance_fee)/1.11 as numeric) as loan_balance
        , cast(sum(
            coalesce(myim3_rev,0) + coalesce(other_rev,0) +
            coalesce(ewallet_ovo_revenue,0) + coalesce(ewallet_gopay_revenue,0) + coalesce(ewallet_shopeepay_revenue,0) +
            coalesce(ewallet_dana_revenue,0) + coalesce(ewallet_imkas_revenue,0) + coalesce(ewallet_linkaja_revenue,0) + coalesce(ewallet_other_revenue,0)
        )/1.11 as numeric) as pgi
    from `data-dtp-prd-aa1a.smy`.revenue_per_site_extended 
    where date(dt_id) between vdt_id - interval 29 day and vdt_id
    group by 1,2
        )
    -------- Rev 30  --------
    select 'IM3' as brand, 
            'site' as level, 
            site_id as level_value, 
            cast(sum(mobo+organic+voice+sms+vas+loan_balance+pgi) as numeric) value,  -- nett 
            'mtd' as time_flag, 
            timestamp(current_datetime('+7')) as insert_date,
            'tot_rev_30' as kpi,
            vdt_id as dt_id
    from rev_ds
    group by 1,2,3,5,6,7,8
union all 
    -------- Rev data 30  --------
    select 'IM3' as brand, 
            'site' as level, 
            site_id as level_value, 
            cast(sum(mobo+organic+pgi) as numeric) value,  -- nett 
            'mtd' as time_flag, 
            timestamp(current_datetime('+7')) as insert_date,
            'tot_rev_data_30' as kpi,
            vdt_id as dt_id
    from rev_ds
    group by 1,2,3,5,6,7,8
;

-------------------------------------
-------- revenue rolling 90d  --------
--------------------------------------
-------- Revenue 90 Days --------

delete from `data-bi-prd-935c.bi_dev`.ioh_snd_master_kpi_detail
where kpi in ('tot_rev_90') and dt_id = vdt_id and brand ='IM3';

insert into  `data-bi-prd-935c.bi_dev`.ioh_snd_master_kpi_detail
with rev_ds as (
        select date(dt_id) dt_id, site_id
        , cast(sum(coalesce(mobo_data_rev,0) + coalesce(fdv_data_rev,0) + coalesce(sp_data_rev,0) + coalesce(sp_fdv_data_rev,0))/1.11 as numeric) as mobo
        , cast(sum(coalesce(ccn_data_revenue,0) - coalesce(ccn_org_combo_addon_voice_rev,0) - coalesce(ccn_org_combo_addon_sms_rev,0))/1.11 as numeric) as organic
        , cast(sum(coalesce(ccn_voice_revenue,0) + coalesce(ccn_org_combo_addon_voice_rev,0) + coalesce(mobo_voice_rev,0) + coalesce(fdv_voice_rev,0))/1.11 as numeric) as voice
        , cast(sum(coalesce(ccn_sms_revenue,0) + coalesce(ccn_org_combo_addon_sms_rev,0) + coalesce(mobo_sms_rev,0) + coalesce(fdv_sms_rev,0) + coalesce(voucher_revenue,0))/1.11 as numeric) as sms
        --, cast(sum((coalesce(ccn_vas_revenue,0) * im3_share_total))/1.11 as numeric) as vas
        , cast(sum( (coalesce(ccn_vas_revenue,0)-coalesce(vas_rev_google,0)) + (coalesce(vas_rev_google,0)*0.15) )/1.11 as numeric) as vas -- VAS
        , cast(sum((coalesce(loan_package_revenue,0) * 1.1) + coalesce(loan_balance_revenue,0) + loan_balance_fee)/1.11 as numeric) as loan_balance
        , cast(sum(
            coalesce(myim3_rev,0) + coalesce(other_rev,0) +
            coalesce(ewallet_ovo_revenue,0) + coalesce(ewallet_gopay_revenue,0) + coalesce(ewallet_shopeepay_revenue,0) +
            coalesce(ewallet_dana_revenue,0) + coalesce(ewallet_imkas_revenue,0) + coalesce(ewallet_linkaja_revenue,0) + coalesce(ewallet_other_revenue,0)
        )/1.11 as numeric) as pgi
    from  `data-dtp-prd-aa1a.smy`.revenue_per_site_extended 
    where date(dt_id) between vdt_id - interval 89 day and vdt_id
    group by 1,2
        )
    -------- Rev 90  --------
    select 'IM3' as brand, 
            'site' as level, 
            site_id as level_value, 
            cast(sum(mobo+organic+voice+sms+vas+loan_balance+pgi) as numeric) value,  -- nett 
            'mtd' as time_flag, 
            timestamp(current_datetime('+7')) as insert_date,
            'tot_rev_90' as kpi_id,
            vdt_id as dt_id
    from rev_ds
    group by 1,2,3,5,6,7,8
;

---------------- TOT REV untuk ARPU ----------------
delete from `data-bi-prd-935c.bi_dev`.ioh_snd_master_kpi_detail
where kpi in ('tot_rev_arpu') and dt_id between date_trunc(vdt_id,month) and vdt_id and brand ='IM3';

insert into  `data-bi-prd-935c.bi_dev`.ioh_snd_master_kpi_detail
    select 'IM3' as brand, 
                'site' as level, 
                level_value, 
                -- cast(sum((value/tgl)*30) as numeric) value,  -- nett 
                cast(avg(avg_value) as numeric)*30 value,  -- nett 
                'mtd' as time_flag, 
                timestamp(current_datetime('+7')) as insert_date,
                'tot_rev_arpu' as kpi_id,
                vdt_id as dt_id
    from 
    (
    select a.level_value,  avg(a.values) avg_value
    from `data-bi-prd-935c.bi_dev`.ioh_snd_master_kpi_detail a
        where kpi = 'tot_rev_all' and brand = 'IM3'
            and dt_id between date_trunc(vdt_id,month) and vdt_id 
    group by 1
    )a
    group by 1,2,3,5,6,7,8
;
--- Insert to table Summary yg DLY jadiin ke MTD 

delete from `data-bi-prd-935c.bi_dev`.ioh_snd_master_kpi_detail_smy
where kpi in 
(
    'tot_rev_all','tot_rev_data','tot_rev_mobo','tot_rev_organic', 
    'tot_rev_voice','tot_rev_sms', 'tot_rev_vas','tot_rev_loan'
        )
and dt_id between date_trunc(vdt_id,month) and vdt_id and brand ='IM3';
insert into  `data-bi-prd-935c.bi_dev`.ioh_snd_master_kpi_detail_smy 
with ref_dealer as (
            select a.id, b.circle, b.region region_circle, b.area, b.sales_area, b.micro_cluster
                from  `data-bi-prd-935c.bi_snd.pre_ref_lowlevel_mth_im3` a
                left join
                        (
                        select * from `data-bi-prd-935c.bi_mart`.ref_kecamatan
                            ) b
                        on a.kec_unik = b.kec_kabkot
                where parse_date('%Y%m',cast(a.mth as string)) = date_trunc(vdt_id,month)
            ),
ref_dealer_rn as (            
            select a.id, b.circle, b.region region_circle, b.area, b.sales_area, b.micro_cluster
                from
                (
                    select * from 
                    (
                    select a.*, 
                        ROW_NUMBER() OVER (partition by id ORDER BY mth desc) AS rn 
                    from  `data-bi-prd-935c.bi_snd.pre_ref_lowlevel_mth_im3` a
                    )a
                    where rn = 1
                )a
            left join
                (select * from `data-bi-prd-935c.bi_mart`.ref_kecamatan) b
            on a.kec_unik = b.kec_kabkot
            ), 
tracker as (
    select *
    from `data-bi-prd-935c.bi_dev`.ioh_snd_master_kpi_detail
    where  dt_id between date_trunc(vdt_id,month) and vdt_id 
        and kpi in 
        ('tot_rev_all','tot_rev_data','tot_rev_mobo','tot_rev_organic', 
         'tot_rev_voice','tot_rev_sms', 'tot_rev_vas','tot_rev_loan'
        ) and brand = 'IM3'
            )
select  a.brand, b.circle, b.region_circle as region, b.area, b.sales_area branch,b.micro_cluster cluster,
    --    coalesce(b.circle,c.circle) as circle,
    --    coalesce(b.region_circle,c.region_circle) as region,
    --    coalesce(b.area,c.area) as area,
    --    coalesce(b.sales_area,c.sales_area) as branch,
    --   coalesce(b.micro_cluster,c.micro_cluster) as cluster,
        sum(values) value,
        a.kpi,
        vdt_id  dt_id
    from tracker a 
        left join ref_dealer b
    on a.level_value=b.id 
   --     left join ref_dealer_rn c
   -- on a.level_value=c.id 
group by 1,2,3,4,5,6,8,9
;


--- Insert to table Summary MTD to MTD

-- create table `data-bi-prd-935c.bi_dev`.ioh_snd_master_kpi_detail_smy partitioned by (kpi,dt_id) stored as parquet as
insert into  `data-bi-prd-935c.bi_dev`.ioh_snd_master_kpi_detail_smy 
with ref_dealer as (
            select a.id, b.circle, b.region region_circle, b.area, b.sales_area, b.micro_cluster
                from  `data-bi-prd-935c.bi_snd.pre_ref_lowlevel_mth_im3` a
                left join
                        (
                        select * from `data-bi-prd-935c.bi_mart`.ref_kecamatan
                            ) b
                        on a.kec_unik = b.kec_kabkot
                where parse_date('%Y%m',cast(a.mth as string)) = date_trunc(vdt_id,month)
            ),
ref_dealer_rn as (            
            select a.id, b.circle, b.region region_circle, b.area, b.sales_area, b.micro_cluster
                from
                (
                    select * from 
                    (
                    select a.*, 
                        ROW_NUMBER() OVER (partition by id ORDER BY mth desc) AS rn 
                    from  `data-bi-prd-935c.bi_snd.pre_ref_lowlevel_mth_im3` a
                    )a
                    where rn = 1
                )a
            left join
                (select * from `data-bi-prd-935c.bi_mart`.ref_kecamatan) b
            on a.kec_unik = b.kec_kabkot
            ), 
tracker as (
    select *
    from `data-bi-prd-935c.bi_dev`.ioh_snd_master_kpi_detail
    where   dt_id =  vdt_id 
        and kpi in 
        (
         --'tot_rev_ds', 'tot_rev_data_ds', 'tot_rev_organic_ds', 'tot_rev_non_data_ds',
         --'tot_rev_ds_voice','tot_rev_ds_sms','tot_rev_ds_vas','tot_rev_ds_loan', 
         --'tot_rev_ds_pgi', 'tot_rev_ds_others', 'tot_rev_ds_data',
         'tot_rev_data_30','tot_rev_30','tot_rev_90','tot_rev_arpu'
        ) and brand = 'IM3'
            )
select  a.brand, b.circle, b.region_circle as region, b.area, b.sales_area branch,b.micro_cluster cluster,
    --    coalesce(b.circle,c.circle) as circle,
    --    coalesce(b.region_circle,c.region_circle) as region,
    --    coalesce(b.area,c.area) as area,
    --    coalesce(b.sales_area,c.sales_area) as branch,
    --   coalesce(b.micro_cluster,c.micro_cluster) as cluster,
        sum(values) value,
        a.kpi,
        a.dt_id
    from tracker a 
        left join ref_dealer b
    on a.level_value=b.id 
   --     left join ref_dealer_rn c
   -- on a.level_value=c.id 
group by 1,2,3,4,5,6,8,9
;