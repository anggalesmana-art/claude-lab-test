declare vdt_id date default @vdt_id;
---------------- rgu_ga ------------------

delete from `data-bi-prd-935c.bi_dev`.ioh_snd_master_kpi_detail where brand = 'IM3' and kpi = 'rgu_ga' and dt_id = vdt_id ;
insert into `data-bi-prd-935c.bi_dev`.ioh_snd_master_kpi_detail 
with ga as (
    select *  from 
            (
                select a.msisdn, a.dt_id ga_dt, a.site_id, organization_id, flag_quality, main_price_acm2, flag_sp,channel_grp
                 from `data-bi-prd-935c.bi_mart`.rgs_ga_90d_dly_govt a
                join (select *
                        from `data-bi-prd-935c.bi_mart`.rgs_ga_channel_mth_govt 
                        where ga_dt between date_trunc(vdt_id,month) and vdt_id 
                      )b
                on a.msisdn = b.msisdn and a.dt_id = b.ga_dt
                where dt_id between date_trunc(vdt_id,month) and vdt_id 
                and (churn_back = 'NO' or recycled = 'YES')
            )x 
        )
select 'IM3' brand, 'site' level, site_id as level_value, 
    cast(count(msisdn) as numeric) value, 
    'mtd' as time_flag, 
     timestamp(current_datetime('+7')) as insert_date,
    'rgu_ga' as kpi_id, 
    vdt_id as dt_id
from ga
group by 1,2,3,5,6,7,8
;



---------------- rgu_ga_outlet ------------------

delete from `data-bi-prd-935c.bi_dev`.ioh_snd_master_kpi_detail where brand = 'IM3' and kpi = 'rgu_ga_outlet' and dt_id = vdt_id;
insert into `data-bi-prd-935c.bi_dev`.ioh_snd_master_kpi_detail 
with ga as (
    select *  from 
            (
                select a.msisdn, a.dt_id ga_dt, a.site_id, organization_id, flag_quality, main_price_acm2, flag_sp,channel_grp
                 from `data-bi-prd-935c.bi_mart`.rgs_ga_90d_dly_govt a
                join (select *
                        from `data-bi-prd-935c.bi_mart`.rgs_ga_channel_mth_govt 
                        where ga_dt between date_trunc(vdt_id,month) and vdt_id 
                      )b
                on a.msisdn = b.msisdn and a.dt_id = b.ga_dt
                where dt_id between date_trunc(vdt_id,month) and vdt_id 
                and (churn_back = 'NO' or recycled = 'YES')
            )x 
        )
select 'IM3' brand, 'outlet' level, organization_id as level_value, 
    cast(count(msisdn) as numeric) value, 
    'mtd' as time_flag, 
     timestamp(current_datetime('+7')) as insert_date,
    'rgu_ga_outlet' as kpi_id, 
    vdt_id as dt_id
from ga
group by 1,2,3,5,6,7,8
;



---------------- rgu_ga_trad and rgu_ga_nontrad ------------------

delete from `data-bi-prd-935c.bi_dev`.ioh_snd_master_kpi_detail where brand = 'IM3' and kpi = 'rgu_ga_nontrad'and dt_id = vdt_id;
insert into `data-bi-prd-935c.bi_dev`.ioh_snd_master_kpi_detail 
with ga as (
    select *  from 
            (
                select a.msisdn, a.dt_id ga_dt, a.site_id, organization_id, flag_quality, main_price_acm2, flag_sp,channel_grp,
                case
                    when flag_sp = 'SP OLA' then 'RGUGA-Digital-OLA'
                    when upper(trim(program_name)) like '%FWA%' then 'RGUGA-FWA'
                    when channel_grp = 'TRADITIONAL' then 'RGUGA-Trad-Outlet'
                    when channel_grp = 'DSF' then 'RGUGA-Trad-DSF'
                    when channel_grp = 'MODERN' and channel like '%ONLINE%' then 'RGUGA-Digital-Online'
                    when channel_grp = 'MODERN' then 'RGUGA-Digital-Modern'
                    -- else 'RGUGA-Others'
                    else
                        case
                            when b.channel_alloc = 'TRADITIONAL' then 'RGUGA-Trad-Outlet'
                            when b.channel_alloc = 'DSF' then 'RGUGA-Trad-DSF'
                            else 'RGUGA-Others'
                        end
                end as parameter
                from `data-bi-prd-935c.bi_mart`.rgs_ga_90d_dly_govt a
                    join (select *
                            from `data-bi-prd-935c.bi_mart`.rgs_ga_channel_mth_govt 
                            where ga_dt between date_trunc(vdt_id,month) and vdt_id 
                          )b
                on a.msisdn = b.msisdn and a.dt_id = b.ga_dt
                where dt_id between date_trunc(vdt_id,month) and vdt_id 
                and (churn_back = 'NO' or recycled = 'YES')
            )x 
        )
-- rgu ga nontrad
select 'IM3' brand, 'site' level, site_id as level_value, 
    cast(count(msisdn) as numeric) value, 
    'mtd' as time_flag, 
     timestamp(current_datetime('+7')) as insert_date,
    'rgu_ga_nontrad' as kpi_id, 
    vdt_id as dt_id
from ga
    where parameter not in ('RGUGA-Trad-Outlet','RGUGA-Trad-DSF')
group by 1,2,3,5,6,7,8
;


---------------- survialance  ------------------

delete from `data-bi-prd-935c.bi_dev`.ioh_snd_master_kpi_detail where brand = 'IM3' and kpi in('surv_m1', 'surv_m3') and dt_id = vdt_id ;
insert into `data-bi-prd-935c.bi_dev`.ioh_snd_master_kpi_detail 
with surv as (
        select 
            ga.site_id,
            'SITE' flag,
            count(usg.msisdn) amount,
            'FM' mthf,
            vdt_id as_of_dt,
            date_trunc(usg.dt_id,month) mth,
            (case 
                when date_trunc(ga.dt_id,month)=date_trunc(usg.dt_id-interval 1 month,month) then 'SURV_M1'
                when date_trunc(ga.dt_id,month)=date_trunc(usg.dt_id-interval 2 month,month) then 'SURV_M2'
                when date_trunc(ga.dt_id,month)=date_trunc(usg.dt_id-interval 3 month,month) then 'SURV_M3'
            end) parameter
        from
            (
                select site_id, msisdn, dt_id
                from (
                        select dt_id, site_id, msisdn
                        from `data-bi-prd-935c.bi_mart`.rgs_ga_90d_dly
                        where dt_id >= '2022-01-01' and dt_id <='2022-05-31'
                        and (churn_back = 'NO' OR recycled = 'YES')
                        union all
                        select dt_id, site_id, msisdn
                        from `data-bi-prd-935c.bi_mart`.rgs_ga_90d_dly_govt
                        where dt_id >= '2022-06-01'
                        and (churn_back = 'NO' OR recycled = 'YES')
                    )xx
                where date_trunc(dt_id,month) in (date_trunc(vdt_id- interval 1 month,month) 
                                            ,date_trunc(vdt_id- interval 2 month,month)
                                            ,date_trunc(vdt_id- interval 3 month,month)
                                            ,date_trunc(vdt_id- interval 4 month,month)
                                            ,date_trunc(vdt_id- interval 5 month,month)
                                            )
            ) ga
        left join   
            (   
                select msisdn, dt_id, total_rev 
                from `data-bi-prd-935c.bi_mart`.rgs_mtd_govt
                where dt_id in (vdt_id)
            ) usg   
            on ga.msisdn = usg.msisdn
        where
            1=1
            and date_trunc(usg.dt_id,month) is not null
        group by 1,2,4,5,6,7
    )
-- surv_m1
select 'IM3' brand, 'site' level, site_id as level_value, 
    sum(cast(amount as numeric)) value, 
    'mtd' as time_flag, 
     timestamp(current_datetime('+7')) as insert_date,
    'surv_m1' as kpi_id, 
    vdt_id as dt_id
from surv
where parameter = 'SURV_M1'
group by 1,2,3,5,6,7,8
union all
-- surv_m3
select 'IM3' brand, 'site' level, site_id as level_value, 
    sum(cast(amount as numeric)) value, 
    'mtd' as time_flag, 
     timestamp(current_datetime('+7')) as insert_date,
    'surv_m3' as kpi_id, 
    vdt_id as dt_id
from surv
where parameter = 'SURV_M3'
group by 1,2,3,5,6,7,8
;

--Waiting cvm_revenue_dashboard 
--------------------------------------
-------- M1S, M2S, M3S RECHARGE ------
--------------------------------------

delete from `data-bi-prd-935c.bi_dev`.ioh_snd_master_kpi_detail where brand = 'IM3' and kpi in ('surv_m1_recharge','surv_m2_recharge') and dt_id = vdt_id;
insert into `data-bi-prd-935c.bi_dev`.ioh_snd_master_kpi_detail 
select 'IM3' brand, 'site' level, site_id as level_value, 
    cast(sum(amount) as numeric) value, 
    'mtd' as time_flag, 
     timestamp(current_datetime('+7')) as insert_date,
     parameter as kpi_id, 
     vdt_id as dt_id
from
    (
        select 
            ga.site_id,
            'SITE' flag,
            count(usg.msisdn) amount,
            (case
                when usg.mth = date_trunc(vdt_id,month) then 'mtd'
                when usg.mth = date_trunc(vdt_id - interval 1 month,month) then 'lmtd'
                when usg.mth = date_trunc(vdt_id - interval 2 month,month) then 'llmtd'
            end) mthf,
            vdt_id as_of_dt,
            date_trunc(vdt_id,month) mth,
            (case 
                when date_trunc(ga.dt_id,month)=date_trunc(usg.mth - interval 1 month,month) then 'surv_m1_recharge'
                when date_trunc(ga.dt_id,month)=date_trunc(usg.mth - interval 2 month,month) then 'surv_m2_recharge'
            end) parameter
        from
            (
                select site_id, msisdn, dt_id
                from (
                        select dt_id, site_id, msisdn
                        from `data-bi-prd-935c.bi_mart`.rgs_ga_90d_dly_govt
                        where dt_id >= '2024-11-01'
                        and (churn_back = 'NO' OR recycled = 'YES')
                    )xx
                where date_trunc(dt_id,month) in (date(date_trunc(vdt_id,month)- interval 1 month) 
                                            ,date(date_trunc(vdt_id,month) - interval 2 month)
                                            ,date(date_trunc(vdt_id,month) - interval 3 month)
                                            ,date(date_trunc(vdt_id,month)- interval 4 month)
                                            )
            ) ga
        left join   
            (   
                select 
                    date_trunc(date(dt_id),month) mth,
                    a.msisdn,
                    sum(main_price)/1.11 total_rev
                from `data-dtp-prd-aa1a.sor.fact_revenue_dashboard_extended` a
                where       
                    (
                        (date_trunc(date(a.dt_id),month) = date_trunc(vdt_id,month) and date(a.dt_id) <= vdt_id)  
                        or (date_trunc(date(a.dt_id),month) = date_trunc(vdt_id - interval 1 month,month))
                        or (date_trunc(date(a.dt_id),month) = date_trunc(vdt_id-interval 2 month,month))
                    )
                and (
                        kpi in ('DATA ORGANIC', 'PGI', 'REVENUE FDV', 'REVENUE MOBO', 'REVENUE VOUCHER ORI', 'REVENUE SP DATA', 'EWALLET', 'REVENUE OLA', 'REVENUE PGI WA')
                        or (kpi = 'ALL PPU' and svc_typ = 'DATA')
                    )
                and is_revenue = 'YES'
                group by 1,2
            ) usg   
            on ga.msisdn = usg.msisdn
        where
            1=1
            and mth is not null
        group by 1,2,4,5,6,7
    ) xx
where parameter is not null  and mthf = 'mtd'
group by 1,2,3,5,6,7,8
;



--------------------------------------
-------- M1S, M2S, M3S REVENUE--------
--------------------------------------
delete from `data-bi-prd-935c.bi_dev`.ioh_snd_master_kpi_detail where brand = 'IM3' and kpi in ('surv_m1_rev','surv_m2_rev','surv_m3_rev') and dt_id = vdt_id;
insert into `data-bi-prd-935c.bi_dev`.ioh_snd_master_kpi_detail 
select 'IM3' brand, 'site' level, site_id as level_value, 
    cast(sum(amount) as numeric) value, 
    'mtd' as time_flag, 
     timestamp(current_datetime('+7')) as insert_date,
     parameter as kpi_id, 
     vdt_id as dt_id
from
    (
        select 
            ga.site_id,
            'SITE' flag,
            sum(usg.total_rev) amount,
            (case
                when date_trunc(usg.dt_id,month) = date_trunc(vdt_id,month) then 'mtd'
                when date_trunc(usg.dt_id,month) = date_trunc(vdt_id - interval 1 month,month) then 'lmtd'
                when date_trunc(usg.dt_id,month) = date_trunc(vdt_id - interval 2 month,month) then 'llmtd'
            end) mthf,
            vdt_id as_of_dt,
            date_trunc(vdt_id,month) mth,
            (case 
                when date_trunc(ga.dt_id,month)=date_trunc(usg.dt_id,month)- interval 1 month then 'surv_m1_rev'
                when date_trunc(ga.dt_id,month)=date_trunc(usg.dt_id,month)- interval 2 month then 'surv_m2_rev'
                when date_trunc(ga.dt_id,month)=date_trunc(usg.dt_id,month)- interval 3 month then 'surv_m3_rev'
            end) parameter
        from
            (
                select site_id, msisdn, dt_id
                from (
                        select dt_id, site_id, msisdn
                        from `data-bi-prd-935c.bi_mart`.rgs_ga_90d_dly
                        where dt_id >= '2022-01-01' and dt_id <='2022-05-31'
                        and (churn_back = 'NO' OR recycled = 'YES')
                        union all
                        select dt_id, site_id, msisdn
                        from `data-bi-prd-935c.bi_mart`.rgs_ga_90d_dly_govt
                        where dt_id >= '2022-06-01'
                        and (churn_back = 'NO' OR recycled = 'YES')
                    )xx
                where date_trunc(dt_id,month) in (date(date_trunc(vdt_id,month)- interval 1 month) 
                                            ,date(date_trunc(vdt_id,month) - interval 2 month)
                                            ,date(date_trunc(vdt_id,month) - interval 3 month)
                                            ,date(date_trunc(vdt_id,month)- interval 4 month)
                                            ,date(date_trunc(vdt_id,month)- interval 5 month)
                                            )
            ) ga
        left join   
            (   
                select msisdn, dt_id, total_rev 
                from `data-bi-prd-935c.bi_mart`.rgs_mtd_govt
                where dt_id in (vdt_id,
                                vdt_id - interval 1 month,
                                vdt_id - interval 2 month,
                                vdt_id - interval 3 month
                                )
            ) usg   
            on ga.msisdn = usg.msisdn
        where
            1=1
            and date_trunc(usg.dt_id,month) is not null
        group by 1,2,4,5,6,7
    ) xx
where parameter is not null and mthf = 'mtd'
group by 1,2,3,5,6,7,8
;



---------------- GA M1 ----------------


delete from `data-bi-prd-935c.bi_dev`.ioh_snd_master_kpi_detail where brand = 'IM3' and kpi = 'ga_m1' and dt_id = vdt_id;
insert into `data-bi-prd-935c.bi_dev`.ioh_snd_master_kpi_detail 
with ga_m1 as (
    select *  from 
            (
                select a.msisdn, a.dt_id ga_dt, a.site_id, organization_id, flag_quality, main_price_acm2, flag_sp, channel_grp
                from `data-bi-prd-935c.bi_mart`.rgs_ga_90d_dly_govt a
                join (
                    select a.*
                    from `data-bi-prd-935c.bi_mart`.rgs_ga_channel_mth_govt a
                    where 
                        ga_dt between date_trunc(vdt_id - interval 1 month,month) 
                            and date_trunc(vdt_id,month) - interval 1 day
                ) b
                on a.msisdn = b.msisdn and a.dt_id = b.ga_dt
                where a.dt_id between date_trunc(vdt_id - interval 1 month,month) 
                            and date_trunc(vdt_id,month) - interval 1 day
                    and (churn_back = 'NO' or recycled = 'YES')
            )x 
        )
select 'IM3' brand, 'site' level, site_id as level_value, 
    cast(count(msisdn) as numeric) value, 
    'mtd' as time_flag, 
     timestamp(current_datetime('+7')) as insert_date,
    'ga_m1' as kpi_id, 
    vdt_id as dt_id
from ga_m1
group by 1,2,3,5,6,7,8
; 


---------------- GA M2 / GA M2 TRAD / GA M2 NON TRAD ----------------

delete from `data-bi-prd-935c.bi_dev`.ioh_snd_master_kpi_detail where brand = 'IM3' and kpi in ('ga_m2_trad', 'ga_m2_nontrad', 'ga_m2') and dt_id = vdt_id;
insert into `data-bi-prd-935c.bi_dev`.ioh_snd_master_kpi_detail 
with ga_m2 as (
    select *  from 
            (
                select a.msisdn, a.dt_id ga_dt, a.site_id, organization_id, flag_quality, main_price_acm2, flag_sp, channel_grp,
                case
                    when flag_sp = 'SP OLA' then 'RGUGA-Digital-OLA'
                    when upper(trim(program_name)) like '%FWA%' then 'RGUGA-FWA'
                    when channel_grp = 'TRADITIONAL' then 'RGUGA-Trad-Outlet'
                    when channel_grp = 'DSF' then 'RGUGA-Trad-DSF'
                    when channel_grp = 'MODERN' and channel like '%ONLINE%' then 'RGUGA-Digital-Online'
                    when channel_grp = 'MODERN' then 'RGUGA-Digital-Modern'
                    -- else 'RGUGA-Others'
                    else
                        case
                            when b.channel_alloc = 'TRADITIONAL' then 'RGUGA-Trad-Outlet'
                            when b.channel_alloc = 'DSF' then 'RGUGA-Trad-DSF'
                            else 'RGUGA-Others'
                        end
                end as parameter
                from `data-bi-prd-935c.bi_mart`.rgs_ga_90d_dly_govt a
                join (
                    select a.*
                    from `data-bi-prd-935c.bi_mart`.rgs_ga_channel_mth_govt a
                    where 
                        ga_dt between date_trunc(vdt_id - interval 2 month,month) 
                            and date_trunc(vdt_id - interval 1 month,month) - interval 1 day
                ) b
                on a.msisdn = b.msisdn and a.dt_id = b.ga_dt
                where a.dt_id between date_trunc(vdt_id - interval 2 month,month) 
                            and date_trunc(vdt_id - interval 1 month,month) - interval 1 day
                    and (churn_back = 'NO' or recycled = 'YES')
            )x 
        )
--- ga_m2_trad
select 'IM3' brand, 'site' level, site_id as level_value, 
    cast(count(msisdn) as numeric) value, 
    'mtd' as time_flag, 
     timestamp(current_datetime('+7')) as insert_date,
    'ga_m2_trad' as kpi_id, 
    vdt_id as dt_id
from ga_m2
where parameter in ('RGUGA-Trad-Outlet','RGUGA-Trad-DSF')
group by 1,2,3,5,6,7,8
union all 
--- ga_m2_nontrad
select 'IM3' brand, 'site' level, site_id as level_value, 
    cast(count(msisdn) as numeric) value, 
    'mtd' as time_flag, 
     timestamp(current_datetime('+7')) as insert_date,
    'ga_m2_nontrad' as kpi_id, 
    vdt_id as dt_id
from ga_m2
where parameter not in ('RGUGA-Trad-Outlet','RGUGA-Trad-DSF')
group by 1,2,3,5,6,7,8
union all
--- ga_m2_all
select 'IM3' brand, 'site' level, site_id as level_value, 
    cast(count(msisdn) as numeric) value, 
    'mtd' as time_flag, 
     timestamp(current_datetime('+7')) as insert_date,
    'ga_m2' as kpi_id, 
    vdt_id as dt_id
from ga_m2
group by 1,2,3,5,6,7,8
; 


---------------- GA M3 ----------------


delete from `data-bi-prd-935c.bi_dev`.ioh_snd_master_kpi_detail where brand = 'IM3' and kpi = 'ga_m3' and dt_id = vdt_id;
insert into `data-bi-prd-935c.bi_dev`.ioh_snd_master_kpi_detail 
with ga_m3 as (
    select *  from 
            (
                select a.msisdn, a.dt_id ga_dt, a.site_id, organization_id, flag_quality, main_price_acm2, flag_sp, channel_grp
                from `data-bi-prd-935c.bi_mart`.rgs_ga_90d_dly_govt a
                join (
                    select a.*
                    from `data-bi-prd-935c.bi_mart`.rgs_ga_channel_mth_govt a
                    where 
                        ga_dt between date_trunc(vdt_id - interval 3 month,month) 
                            and date_trunc(vdt_id - interval 2 month,month) - interval 1 day
                ) b
                on a.msisdn = b.msisdn and a.dt_id = b.ga_dt
                where a.dt_id between date_trunc(vdt_id - interval 3 month,month) 
                            and date_trunc(vdt_id - interval 2 month,month) - interval 1 day
                    and (churn_back = 'NO' or recycled = 'YES')
            )x 
        )
select 'IM3' brand, 'site' level, site_id as level_value, 
    cast(count(msisdn) as numeric) value, 
    'mtd' as time_flag, 
     timestamp(current_datetime('+7')) as insert_date,
    'ga_m3' as kpi_id, 
    vdt_id as dt_id
from ga_m3
group by 1,2,3,5,6,7,8
; 




---------------- rgu_ga_dly ------------------

delete from `data-bi-prd-935c.bi_dev`.ioh_snd_master_kpi_detail where brand = 'IM3' and kpi = 'rgu_ga_dly' and dt_id between date_trunc(vdt_id,month) and vdt_id  ;
insert into `data-bi-prd-935c.bi_dev`.ioh_snd_master_kpi_detail 
with ga as (
    select *  from 
            (
                select a.msisdn, a.dt_id ga_dt, a.site_id, organization_id, flag_quality, main_price_acm2, flag_sp,channel_grp
                 from `data-bi-prd-935c.bi_mart`.rgs_ga_90d_dly_govt a
                join (select *
                        from `data-bi-prd-935c.bi_mart`.rgs_ga_channel_mth_govt 
                        where ga_dt between date_trunc(vdt_id,month) and vdt_id 
                      )b
                on a.msisdn = b.msisdn and a.dt_id = b.ga_dt
                where dt_id between date_trunc(vdt_id,month) and vdt_id 
                and (churn_back = 'NO' or recycled = 'YES')
            )x 
        )
select 'IM3' brand, 'site' level, site_id as level_value, 
    cast(count(msisdn) as numeric) value, 
    'dly' as time_flag, 
     timestamp(current_datetime('+7')) as insert_date,
    'rgu_ga_dly' as kpi_id, 
     ga_dt as dt_id
from ga
group by 1,2,3,5,6,7,8
;




--------------------------------------
--------- outlet_0_rguga_trad ---------
--------------------------------------


delete from `data-bi-prd-935c.bi_dev`.ioh_snd_master_kpi_detail where brand = 'IM3' and kpi = 'outlet_0_rguga_trad' and dt_id = vdt_id;
insert into `data-bi-prd-935c.bi_dev`.ioh_snd_master_kpi_detail 
select 'IM3' brand, 'outlet' level, id_outlet as level_value, 
    cast(count(case when amount=0 then id_outlet end) as numeric) value, 
    'mtd' as time_flag, 
     timestamp(current_datetime('+7')) as insert_date,
     'outlet_0_rguga_trad' as kpi_id, 
     vdt_id as dt_id
from
    (
        select 
            se.mth,
            se.id_outlet,
            coalesce(sum(ga.amount), 0) as amount
        from 
            (
                select 
                    parse_date('%Y%m',cast(mth_id as string)) mth,
                    id_outlet
                from `data-bi-prd-935c.bi_snd.pre_ref_outlet_mapping_im3`
                where parse_date('%Y%m',cast(mth_id as string)) = date_trunc(vdt_id,month)
                and cast(mth_id as string) <> 'NULL'
                group by 1,2
            ) se
        left join
            (
                select 
                    date_trunc(dt_id,month) mth,
                    b.organization_id id,
                    count(a.msisdn) amount
                from `data-bi-prd-935c.bi_mart`.rgs_ga_90d_dly_govt a
                    join `data-bi-prd-935c.bi_mart`.rgs_ga_channel_mth_govt b
                on a.msisdn = b.msisdn and a.dt_id = b.ga_dt
                where 
                    ((date_trunc(a.dt_id,month) = date_trunc(vdt_id,month) and a.dt_id <= vdt_id))
                and (churn_back = 'NO' OR recycled = 'YES')
                and 
                    (case
                        when flag_sp = 'SP OLA' then 'RGUGA-Digital-OLA'
                        when channel_grp = 'TRADITIONAL' then 'RGUGA-Trad-Outlet'
                        when channel_grp = 'DSF' then 'RGUGA-Trad-DSF'
                        when channel_grp = 'MODERN' and channel like '%ONLINE%' then 'RGUGA-Digital-Online'
                        when channel_grp = 'MODERN' then 'RGUGA-Digital-Modern'
                        -- else 'RGUGA-Others'
                        else
                            case
                                when b.channel_alloc = 'TRADITIONAL' then 'RGUGA-Trad-Outlet'
                                when b.channel_alloc = 'DSF' then 'RGUGA-Trad-DSF'
                                else 'RGUGA-Others'
                            end
                    end) in ('RGUGA-Trad-Outlet','RGUGA-Trad-DSF')
                group by 1,2
            ) ga
            on se.id_outlet = ga.id
            and se.mth = ga.mth
        group by 1,2
    ) x
group by 1,2,3,5,6,7,8
;



--------------------------------------
------- SITE 30 RGUGA TRAD -----------
--------------------------------------
delete from `data-bi-prd-935c.bi_dev`.ioh_snd_master_kpi_detail where brand = 'IM3' and kpi = 'site_30_rguga_trad' and dt_id = vdt_id;
insert into `data-bi-prd-935c.bi_dev`.ioh_snd_master_kpi_detail 
select 
    'IM3' brand, 'site' level, site_id as level_value, 
    cast(count(case when amount>=30 then xx.site_id end) as numeric) value, 
    'mtd' as time_flag, 
     timestamp(current_datetime('+7')) as insert_date,
     'site_30_rguga_trad' as kpi_id, 
     vdt_id as dt_id
from 
    (
        select 
            month_id mth,
            region, area, cluster, micro_cluster,
            addr_site.site_id,
            sum(ifnull(a.amount,0))+sum(ifnull(b.amount,0)) amount
        from 
            (
                select 
                    distinct region, area, salesarea sales_area, cluster, microcluster micro_cluster, main.java_outside_java,
                    main.site_id site_id, site_id_old old_site_id, main.site_id_mocn site_id_ioh, concat(kecamatan,'|',kabupaten) kec_unik,
                    parse_date('%Y%m',cast(main.mth as string)) month_id
                from `data-bi-prd-935c.bi_snd.pre_ref_nshim3_addrsite_gtm_mth` main --rdm.spa_tbl_list_sitefocus main
                where parse_date('%Y%m',cast(main.mth as string)) in (date_trunc(vdt_id,month)
                            -- ,date_trunc(vdt_id - interval 1 month,month)
                            -- ,date_trunc(vdt_id - interval 2 month,month)
                            )
                and trim(addressable_type) = 'ADDRESSABLE SITE'
                and list_site_im3 = 'Y'
            ) addr_site
        left join
            (
                select 
                    date_trunc(dt_id,month) mth,
                    a.site_id,
                    count(a.msisdn) amount
                from `data-bi-prd-935c.bi_mart`.rgs_ga_90d_dly_govt a
                join `data-bi-prd-935c.bi_mart`.rgs_ga_channel_mth_govt b
                    on a.msisdn = b.msisdn
                    and a.dt_id = b.ga_dt
                where 
                    ((date_trunc(a.dt_id,month) = date_trunc(vdt_id,month) and a.dt_id <= vdt_id)  
                    -- or (date_trunc(a.dt_id,month) = date_trunc(vdt_id - interval 1 month,month) and a.dt_id <= vdt_id - interval 1 month)
                    -- or (date_trunc(a.dt_id,month) = date_trunc(vdt_id - interval 2 month,month) and a.dt_id <= vdt_id - interval 2 month)
                    )
                and (churn_back = 'NO' OR recycled = 'YES')
                and 
                    (case
                        when flag_sp = 'SP OLA' then 'RGUGA-Digital-OLA'
                        when upper(trim(program_name)) like '%FWA%' then 'RGUGA-FWA'
                        when channel_grp = 'TRADITIONAL' then 'RGUGA-Trad-Outlet'
                        when channel_grp = 'DSF' then 'RGUGA-Trad-DSF'
                        when channel_grp = 'MODERN' and channel like '%ONLINE%' then 'RGUGA-Digital-Online'
                        when channel_grp = 'MODERN' then 'RGUGA-Digital-Modern'
                        -- else 'RGUGA-Others'
                        else
                            case
                                when b.channel_alloc = 'TRADITIONAL' then 'RGUGA-Trad-Outlet'
                                when b.channel_alloc = 'DSF' then 'RGUGA-Trad-DSF'
                                else 'RGUGA-Others'
                            end
                    end) in ('RGUGA-Trad-Outlet','RGUGA-Trad-DSF')
                group by 1,2
            ) a
            on addr_site.old_site_id = a.site_id
            and addr_site.month_id = a.mth
        left join
            (
                select 
                    date_trunc(dt_id,month) mth,
                    a.site_id,
                    count(a.msisdn) amount
                from `data-bi-prd-935c.bi_mart`.rgs_ga_90d_dly_govt a
                join `data-bi-prd-935c.bi_mart`.rgs_ga_channel_mth_govt b
                    on a.msisdn = b.msisdn
                    and a.dt_id = b.ga_dt
                where 
                    ((date_trunc(a.dt_id,month) = date_trunc(vdt_id,month) and a.dt_id <= vdt_id)  
                    )
                and (churn_back = 'NO' OR recycled = 'YES')
                and 
                    (case
                        when flag_sp = 'SP OLA' then 'RGUGA-Digital-OLA'
                        when upper(trim(program_name)) like '%FWA%' then 'RGUGA-FWA'
                        when channel_grp = 'TRADITIONAL' then 'RGUGA-Trad-Outlet'
                        when channel_grp = 'DSF' then 'RGUGA-Trad-DSF'
                        when channel_grp = 'MODERN' and channel like '%ONLINE%' then 'RGUGA-Digital-Online'
                        when channel_grp = 'MODERN' then 'RGUGA-Digital-Modern'
                        -- else 'RGUGA-Others'
                        else
                            case
                                when b.channel_alloc = 'TRADITIONAL' then 'RGUGA-Trad-Outlet'
                                when b.channel_alloc = 'DSF' then 'RGUGA-Trad-DSF'
                                else 'RGUGA-Others'
                            end
                    end) in ('RGUGA-Trad-Outlet','RGUGA-Trad-DSF')
                group by 1,2
            ) b
            on addr_site.site_id_ioh = b.site_id
            and addr_site.month_id = b.mth
        group by 1,2,3,4,5,6
    ) xx
group by 1,2,3,5,6,7,8
;


--------------------------------------
------- RGU GA FLAG INJ NEW ----------
--------------------------------------
--Source Incomplete Prass So Reference
delete from `data-bi-prd-935c.bi_dev`.ioh_snd_master_kpi_detail where brand = 'IM3' and kpi in ('rguga_mvc_new','rguga_hvc_new','rguga_no_inj','rguga_lvc') and dt_id = vdt_id;
insert into `data-bi-prd-935c.bi_dev`.ioh_snd_master_kpi_detail  
select 'IM3' brand, 'site' level, id as level_value, 
    sum(cast(amount as numeric)) value, 
    'mtd' as time_flag, 
     timestamp(current_datetime('+7')) as insert_date,
     parameter as kpi_id, 
    vdt_id dt_id
from 
( 
    select 
        a.site_id id,
        'SITE' flag,
        count(a.msisdn) amount,
        (case
            when date_trunc(a.dt_id,month) = date_trunc(vdt_id,month) then 'mtd'
            when date_trunc(a.dt_id,month) = date_trunc(vdt_id - interval 1 month,month) then 'lmtd'
            when date_trunc(a.dt_id,month) = date_trunc(vdt_id - interval 2 month,month) then 'llmtd'
        end) mthf,
        vdt_id as_of_dt,
        date_trunc(vdt_id,month) mth,
        (case
            when b.flag_sp = 'SP Zero' and b.main_price_acm2 >= 10000 then 
                case 
                    when (b.main_price_acm2+coalesce(so.so_price,so_mth.so_price,2000)) >= 10000 and (b.main_price_acm2+coalesce(so.so_price,so_mth.so_price,2000)) < 35000 then 'rguga_mvc_new'
                    when (b.main_price_acm2+coalesce(so.so_price,so_mth.so_price,2000)) >= 35000 then 'rguga_hvc_new'
                end
            else 
                case
                    when b.main_price_acm2 = 0 then 'rguga_no_inj'
                    when b.main_price_acm2 > 0 and b.main_price_acm2 < 10000 then 'rguga_lvc'
                    when b.main_price_acm2 >= 10000 and b.main_price_acm2 < 35000 then 'rguga_mvc_new'
                    when b.main_price_acm2 >= 35000 then 'rguga_hvc_new'
                end
        end) parameter
    from `data-bi-prd-935c.bi_mart`.rgs_ga_90d_dly_govt a
    join `data-bi-prd-935c.bi_mart`.rgs_ga_channel_mth_govt b
         on a.msisdn = b.msisdn and a.dt_id = b.ga_dt
    left join
        (
            select a.* 
               from 
               (
               SELECT distinct sales_order as so_number
                    , gross_price_perunit
                    , round((safe_cast(net_sales_perunit as numeric)*1.11),0) so_price
                    , date(dt_id) dt_id
                    , ROW_NUMBER() OVER (partition by sales_order ORDER BY dt_id desc) AS rn
               FROM `data-dtp-prd-aa1a.stg.reference_zero` 
               where date(dt_id) >= '2025-01-01'  -- fixed date
               )a
               where rn = 1
        ) so
        on b.so_number = so.so_number
    left join
        (
            select * from 
                    (
                         select *, 
                              row_number() over (partition by date_trunc(so_date_fixing,month) order by cast(so_price as bigint) asc) rn
                         from 
                         (
                              select product_description as product 
                                   , round((safe_cast(net_sales_perunit as numeric)*1.11),0) so_price
                                   , date(dt_id) as so_date_fixing
                              FROM `data-dtp-prd-aa1a.stg.reference_zero` 
                                        where date(dt_id) >= '2025-01-01'  -- fixed date
                                        and lower(product_description) not like '%dat%'
                    )a
                    )a 
                    where rn = 1
        ) so_mth
        on date_trunc(b.foss_dt,month) = date_trunc(so_mth.so_date_fixing,month)
    where 
        ((date_trunc(a.dt_id,month) = date_trunc(vdt_id,month) and a.dt_id <= vdt_id)  
        or (date_trunc(a.dt_id,month) = date_trunc(vdt_id - interval 1 month,month) and a.dt_id <= vdt_id - interval 1 month)
        or (date_trunc(a.dt_id,month) = date_trunc(vdt_id - interval 2 month,month) and a.dt_id <= vdt_id - interval 2 month)
        )
    and (churn_back = 'NO' OR recycled = 'YES')
    group by 1,2,4,5,6,7
)a 
where mthf = 'mtd'
group by 1,2,3,5,6,7,8
;



--------------------------------------
--- RGU GA FLAG INJ NEW TRAD ONLY-----
--------------------------------------
-- Source Incomplete Prass So Reference
delete from `data-bi-prd-935c.bi_dev`.ioh_snd_master_kpi_detail where brand = 'IM3' and kpi in (
'rguga_trad_lvc',
'rguga_trad_mvc_new',
'rguga_trad_no_inj',
'rguga_trad_hvc_new') and dt_id = vdt_id;

insert into `data-bi-prd-935c.bi_dev`.ioh_snd_master_kpi_detail   
with rgu_flag as (
        select 
            a.site_id id,
            'SITE' flag,
            count(a.msisdn) amount,
            (case
                when date_trunc(a.dt_id,month) = date_trunc(vdt_id,month) then 'mtd'
                when date_trunc(a.dt_id,month) = date_trunc(vdt_id - interval 1 month,month) then 'lmtd'
                when date_trunc(a.dt_id,month) = date_trunc(vdt_id - interval 2 month,month) then 'llmtd'
            end) mthf,
            vdt_id as_of_dt,
            date_trunc(vdt_id,month) mth,
            (case
                when b.flag_sp = 'SP Zero' and b.main_price_acm2 = 0 and try_me.msisdn is not null then 'RGUGA-Trad-Try Me'
                when b.flag_sp = 'SP Zero' and b.main_price_acm2 >= 10000 then 
                    case 
                        when (b.main_price_acm2+coalesce(so.so_price,so_mth.so_price,2000)) >= 10000 and (b.main_price_acm2+coalesce(so.so_price,so_mth.so_price,2000)) < 35000 then 'RGUGA-Trad MVC NEW'
                        when (b.main_price_acm2+coalesce(so.so_price,so_mth.so_price,2000)) >= 35000 then 'RGUGA-Trad HVC NEW'
                    end
                else 
                    case
                        when b.main_price_acm2 = 0 then 'RGUGA-Trad NO INJ'
                        when b.main_price_acm2 > 0 and b.main_price_acm2 < 10000 then 'RGUGA-Trad LVC'
                        when b.main_price_acm2 >= 10000 and b.main_price_acm2 < 35000 then 'RGUGA-Trad MVC NEW'
                        when b.main_price_acm2 >= 35000 then 'RGUGA-Trad HVC NEW'
                    end
            end) parameter
        from `data-bi-prd-935c.bi_mart`.rgs_ga_90d_dly_govt a
        join `data-bi-prd-935c.bi_mart`.rgs_ga_channel_mth_govt b
            on a.msisdn = b.msisdn
            and a.dt_id = b.ga_dt
        left join
            (
                select a.* 
                    from 
                    (
                    SELECT distinct sales_order as so_number
                            , gross_price_perunit
                            , round((safe_cast(net_sales_perunit as numeric)*1.11),0) so_price
                            , date(dt_id) dt_id
                            , ROW_NUMBER() OVER (partition by sales_order ORDER BY dt_id desc) AS rn
                    FROM `data-dtp-prd-aa1a.stg.reference_zero` 
                    where date(dt_id) >= '2025-01-01'  -- fixed date
                    )a
                where rn = 1
            ) so
            on b.so_number = so.so_number
        left join
            (
                select * from 
                    (
                         select *, 
                              row_number() over (partition by date_trunc(so_date_fixing,month) order by cast(so_price as bigint) asc) rn
                         from 
                         (
                              select product_description as product 
                                   , round((safe_cast(net_sales_perunit as numeric)*1.11),0) so_price
                                   , date(dt_id) as so_date_fixing
                              FROM `data-dtp-prd-aa1a.stg.reference_zero` 
                                        where date(dt_id) >= '2025-01-01'  -- fixed date
                                        and lower(product_description) not like '%dat%'
                    )a
                    )a 
                where rn = 1
            ) so_mth
            on date_trunc(b.foss_dt,month) = date_trunc(so_mth.so_date_fixing,month)
        left join
            (
                select 
                    distinct
                    date_trunc(date(a.taker_date),month) mth,
                    a.msisdn
                    -- a.provisioned_offerid cvm_inj
                from `data-cvm-prd-c324.dm.im3_sp_inject_cvm` a
                where 1=1
                and (
                        (date_trunc(date(a.taker_date),month) = date_trunc(vdt_id,month) and date(a.taker_date) <= vdt_id)  
                        or (date_trunc(date(a.taker_date),month) = date_trunc(vdt_id - interval 1 month,month) and date(a.taker_date) <= vdt_id - interval 1 month)
                        or (date_trunc(date(a.taker_date),month) = date_trunc(vdt_id - interval 2 month,month) and date(a.taker_date) <= vdt_id - interval 2 month)
                    )
                and product_campaign = 'SP Zero'
            ) try_me
            on a.msisdn = try_me.msisdn
            and date_trunc(a.dt_id,month) = try_me.mth
        where 
            ((date_trunc(a.dt_id,month) = date_trunc(vdt_id,month) and a.dt_id <= vdt_id)  
            or (date_trunc(a.dt_id,month) = date_trunc(vdt_id - interval 1 month,month) and a.dt_id <= vdt_id - interval 1 month)
            or (date_trunc(a.dt_id,month) = date_trunc(vdt_id - interval 2 month,month) and a.dt_id <= vdt_id - interval 2 month)
            )
        and (churn_back = 'NO' OR recycled = 'YES')
        and 
            (case
                when flag_sp = 'SP OLA' then 'RGUGA-Digital-OLA'
                when upper(trim(program_name)) like '%FWA%' then 'RGUGA-FWA'
                when channel_grp = 'TRADITIONAL' then 'RGUGA-Trad-Outlet'
                when channel_grp = 'DSF' then 'RGUGA-Trad-DSF'
                when channel_grp = 'MODERN' and channel like '%ONLINE%' then 'RGUGA-Digital-Online'
                when channel_grp = 'MODERN' then 'RGUGA-Digital-Modern'
                -- else 'RGUGA-Others'
                else
                    case
                        when b.channel_alloc = 'TRADITIONAL' then 'RGUGA-Trad-Outlet'
                        when b.channel_alloc = 'DSF' then 'RGUGA-Trad-DSF'
                        else 'RGUGA-Others'
                    end
            end) in ('RGUGA-Trad-Outlet','RGUGA-Trad-DSF')
        group by 1,2,4,5,6,7
    ) 
------- 
select 
     'IM3' brand, 'site' level, id as level_value, 
    cast(sum(amount) as numeric) value,
    'mtd' as time_flag,
    timestamp(current_datetime('+7')) as insert_date,
    (case
        when parameter = 'RGUGA-Trad NO INJ' then 'rguga_trad_no_inj'
        when parameter = 'RGUGA-Trad LVC' then 'rguga_trad_lvc'
        when parameter = 'RGUGA-Trad MVC NEW' then 'rguga_trad_mvc_new'
        when parameter = 'RGUGA-Trad HVC NEW' then 'rguga_trad_hvc_new'
    end) as kpi_id,
    vdt_id as dt_id
from rgu_flag
where mthf = 'mtd'
group by 1,2,3,5,6,7,8
;



--------------------------------------
------- RGU GA SP6GB TRAD ONLY -------
--------------------------------------
delete from `data-bi-prd-935c.bi_dev`.ioh_snd_master_kpi_detail where kpi in ('rguga_trad_sp6gb', 'rguga_trad_sp3gb') and dt_id = vdt_id;
insert into `data-bi-prd-935c.bi_dev`.ioh_snd_master_kpi_detail   
with rgu_flag as (
        select 
            a.site_id id,
            'SITE' flag,
            count(a.msisdn) amount,
            (case
                when date_trunc(a.dt_id,month) = date_trunc(vdt_id,month) then 'mtd'
                when date_trunc(a.dt_id,month) = date_trunc(vdt_id - interval 1 month,month) then 'lmtd'
                when date_trunc(a.dt_id,month) = date_trunc(vdt_id - interval 2 month,month) then 'llmtd'
            end) mthf,
            vdt_id as_of_dt,
            date_trunc(vdt_id,month) mth,
            (case 
                when flag_sp = 'SP IM3 6GB' then 'RGUGA-Trad-SP6GB'
                when flag_sp = 'SP IM3 3GB' then 'RGUGA-Trad-SP3GB'
            end) parameter
            -- 'RGUGA-Trad-SP6GB' parameter
        from `data-bi-prd-935c.bi_mart`.rgs_ga_90d_dly_govt a
        join `data-bi-prd-935c.bi_mart`.rgs_ga_channel_mth_govt b
            on a.msisdn = b.msisdn
            and a.dt_id = b.ga_dt
        where 
            ((date_trunc(a.dt_id,month) = date_trunc(vdt_id,month) and a.dt_id <= vdt_id)  
            or (date_trunc(a.dt_id,month) = date_trunc(vdt_id - interval 1 month,month) and a.dt_id <= vdt_id - interval 1 month)
            or (date_trunc(a.dt_id,month) = date_trunc(vdt_id - interval 2 month,month) and a.dt_id <= vdt_id - interval 2 month)
            )
        and (churn_back = 'NO' OR recycled = 'YES')
        and flag_sp in ('SP IM3 6GB','SP IM3 3GB')
        and 
            (case
                when flag_sp = 'SP OLA' then 'RGUGA-Digital-OLA'
                when upper(trim(program_name)) like '%FWA%' then 'RGUGA-FWA'
                when channel_grp = 'TRADITIONAL' then 'RGUGA-Trad-Outlet'
                when channel_grp = 'DSF' then 'RGUGA-Trad-DSF'
                when channel_grp = 'MODERN' and channel like '%ONLINE%' then 'RGUGA-Digital-Online'
                when channel_grp = 'MODERN' then 'RGUGA-Digital-Modern'
                -- else 'RGUGA-Others'
                else
                    case
                        when b.channel_alloc = 'TRADITIONAL' then 'RGUGA-Trad-Outlet'
                        when b.channel_alloc = 'DSF' then 'RGUGA-Trad-DSF'
                        else 'RGUGA-Others'
                    end
            end) in ('RGUGA-Trad-Outlet','RGUGA-Trad-DSF')
        group by 1,2,4,5,6,7
    ) 
------- 
select 
     'IM3' brand, 'site' level, id as level_value, 
    cast(sum(amount) as numeric) value,
    'mtd' as time_flag,
    timestamp(current_datetime('+7')) as insert_date,
    (case
        when parameter = 'RGUGA-Trad-SP6GB' then 'rguga_trad_sp6gb'
        when parameter = 'RGUGA-Trad-SP3GB' then 'rguga_trad_sp3gb'
    end) as kpi_id,
    vdt_id as dt_id
from rgu_flag
where mthf = 'mtd'
group by 1,2,3,5,6,7,8
;



--------------------------------------
------ RGU GA CHANNEL SEGMENT --------
--------------------------------------
delete from `data-bi-prd-935c.bi_dev`.ioh_snd_master_kpi_detail  where kpi in (
    'rguga_digital_ola',
    'rguga_fwa',
    'rguga_trad_outlet',
    'rguga_digital_online',
    'rguga_digital_modern',
    'rguga_trad_outlet',
    'rguga_trad_dsf'
) and dt_id = vdt_id and brand = 'IM3';
insert into `data-bi-prd-935c.bi_dev`.ioh_snd_master_kpi_detail   
with rgu_flag as (
        select 
            a.site_id id,
            'SITE' flag,
            count(a.msisdn) amount,
            (case
                when date_trunc(a.dt_id,month) = date_trunc(vdt_id,month) then 'mtd'
                when date_trunc(a.dt_id,month) = date_trunc(vdt_id - interval 1 month,month) then 'lmtd'
                when date_trunc(a.dt_id,month) = date_trunc(vdt_id - interval 2 month,month) then 'llmtd'
            end) mthf,
            vdt_id as_of_dt,
            date_trunc(vdt_id,month) mth,
            (case
                when flag_sp = 'SP OLA' then 'RGUGA-Digital-OLA'
                when upper(trim(program_name)) like '%FWA%' then 'RGUGA-FWA'
                when channel_grp = 'TRADITIONAL' then 'RGUGA-Trad-Outlet'
                when channel_grp = 'DSF' then 'RGUGA-Trad-DSF'
                when channel_grp = 'MODERN' and channel like '%ONLINE%' then 'RGUGA-Digital-Online'
                when channel_grp = 'MODERN' then 'RGUGA-Digital-Modern'
                -- else 'RGUGA-Others'
                else
                    case
                        when b.channel_alloc = 'TRADITIONAL' then 'RGUGA-Trad-Outlet'
                        when b.channel_alloc = 'DSF' then 'RGUGA-Trad-DSF'
                        else 'RGUGA-Others'
                    end
            end) parameter
        from `data-bi-prd-935c.bi_mart`.rgs_ga_90d_dly_govt a
        join `data-bi-prd-935c.bi_mart`.rgs_ga_channel_mth_govt b
            on a.msisdn = b.msisdn
            and a.dt_id = b.ga_dt
        where 
            ((date_trunc(a.dt_id,month) = date_trunc(vdt_id,month) and a.dt_id <= vdt_id)  
            or (date_trunc(a.dt_id,month) = date_trunc(vdt_id - interval 1 month,month) and a.dt_id <= vdt_id - interval 1 month)
            or (date_trunc(a.dt_id,month) = date_trunc(vdt_id - interval 2 month,month) and a.dt_id <= vdt_id - interval 2 month)
            )
        and (churn_back = 'NO' OR recycled = 'YES')
        group by 1,2,4,5,6,7
    ) 
------- 
select 
     'IM3' brand, 'site' level, id as level_value, 
    cast(sum(amount) as numeric) value,
    'mtd' as time_flag,
    timestamp(current_datetime('+7')) as insert_date,
    (case
        when parameter = 'RGUGA-Digital-OLA' then 'rguga_digital_ola'
        when parameter = 'RGUGA-FWA' then 'rguga_fwa'
        when parameter = 'RGUGA-Trad-Outlet' then 'rguga_trad_outlet'
        when parameter = 'RGUGA-Digital-Online' then 'rguga_digital_online'
        when parameter = 'RGUGA-Digital-Modern' then 'rguga_digital_modern'
        when parameter = 'RGUGA-Trad-Outlet' then 'rguga_trad_outlet'
        when parameter = 'RGUGA-Trad-DSF' then 'rguga_trad_dsf'
    end) as kpi_id,
    vdt_id as dt_id
from rgu_flag
where mthf = 'mtd'
group by 1,2,3,5,6,7,8
;


---------------- survialance m2 trad and non trad  ------------------

delete from `data-bi-prd-935c.bi_dev`.ioh_snd_master_kpi_detail where brand = 'IM3' and kpi in ('surv_m2_trad','surv_m2_nontrad') and dt_id = vdt_id;
insert into `data-bi-prd-935c.bi_dev`.ioh_snd_master_kpi_detail 
with surv as (
        select 
            ga.site_id,
            'SITE' flag,
            count(usg.msisdn) amount,
            'FM' mthf,
            vdt_id as_of_dt,
            date_trunc(usg.dt_id,month) mth,
            flag_channel,
            (case 
                when date_trunc(ga.dt_id,month)=date_trunc(usg.dt_id,month)- interval 1 month then 'SURV_M1'
                when date_trunc(ga.dt_id,month)=date_trunc(usg.dt_id,month)- interval 2 month then 'SURV_M2'
                when date_trunc(ga.dt_id,month)=date_trunc(usg.dt_id,month)- interval 3 month then 'SURV_M3'
            end) parameter
        from
            (
                select site_id, msisdn, dt_id, flag_channel
                from (
                        select a.dt_id, a.site_id, a.msisdn, 
                        case
                            when flag_sp = 'SP OLA' then 'RGUGA-Digital-OLA'
                            when upper(trim(program_name)) like '%FWA%' then 'RGUGA-FWA'
                            when channel_grp = 'TRADITIONAL' then 'RGUGA-Trad-Outlet'
                            when channel_grp = 'DSF' then 'RGUGA-Trad-DSF'
                            when channel_grp = 'MODERN' and channel like '%ONLINE%' then 'RGUGA-Digital-Online'
                            when channel_grp = 'MODERN' then 'RGUGA-Digital-Modern'
                            -- else 'RGUGA-Others'
                            else
                                case
                                    when b.channel_alloc = 'TRADITIONAL' then 'RGUGA-Trad-Outlet'
                                    when b.channel_alloc = 'DSF' then 'RGUGA-Trad-DSF'
                                    else 'RGUGA-Others'
                                end
                        end as flag_channel
                        from `data-bi-prd-935c.bi_mart`.rgs_ga_90d_dly_govt a
                        join `data-bi-prd-935c.bi_mart`.rgs_ga_channel_mth_govt b
                            on a.msisdn = b.msisdn  and a.dt_id = b.ga_dt
                        where dt_id >= '2022-06-01'
                        and (churn_back = 'NO' OR recycled = 'YES')
                    )xx
                where date_trunc(dt_id,month) in (date(date_trunc(vdt_id,month)- interval 1 month) 
                                            ,date(date_trunc(vdt_id,month) - interval 2 month)
                                            ,date(date_trunc(vdt_id,month) - interval 3 month)
                                            ,date(date_trunc(vdt_id,month)- interval 4 month)
                                            ,date(date_trunc(vdt_id,month)- interval 5 month)
                                            )
            ) ga
        left join   
            (   
                select msisdn, dt_id, total_rev 
                from `data-bi-prd-935c.bi_mart`.rgs_mtd_govt
                where dt_id in (vdt_id)
            ) usg   
            on ga.msisdn = usg.msisdn
        where
            1=1
            and date_trunc(usg.dt_id,month) is not null
        group by 1,2,4,5,6,7,8
    )
-- surv_m2_traditional
select 'IM3' brand, 'site' level, site_id as level_value, 
    sum(cast(amount as numeric)) value, 
    'mtd' as time_flag, 
     timestamp(current_datetime('+7')) as insert_date,
    'surv_m2_trad' as kpi_id, 
    vdt_id as dt_id
from surv
where parameter = 'SURV_M2'
    and flag_channel in ('RGUGA-Trad-Outlet','RGUGA-Trad-DSF')
group by 1,2,3,5,6,7,8
union all 
-- surv_m2_non_traditional
select 'IM3' brand, 'site' level, site_id as level_value, 
    sum(cast(amount as numeric)) value, 
    'mtd' as time_flag, 
     timestamp(current_datetime('+7')) as insert_date,
    'surv_m2_nontrad' as kpi_id, 
    vdt_id as dt_id
from surv
where parameter = 'SURV_M2'
    and flag_channel not in ('RGUGA-Trad-Outlet','RGUGA-Trad-DSF')
group by 1,2,3,5,6,7,8
;

-----------------------------------------------------
---  GA Subs (above IDR 35k) & (below IDR 35k) -----
----------------------------------------------------v

delete from `data-bi-prd-935c.bi_dev`.ioh_snd_master_kpi_detail  where kpi in ('GA Subs (above IDR 35k)','GA Subs (below IDR 35k)')
and dt_id between date_trunc(vdt_id,month) and vdt_id and brand = 'IM3';
insert into  `data-bi-prd-935c.bi_dev`.ioh_snd_master_kpi_detail
select 'IM3' as brand, 
'site' as level,
site_id as level_value,
cast(count(distinct msisdn) as numeric) as value ,
'dly' as time_flag,
current_timestamp() as insert_date,
case when flag_acm = '1. HVC' then 'GA Subs (above IDR 35k)' else 'GA Subs (below IDR 35k)' end as kpi_id,
dt_id
from
(
 select distinct dt_id, site_id, 
 CASE
  when flag_sp_new='SP 35K' then '1. HVC'
  when flag_sp in ('SP OLA','SP FWA') then '1. HVC'
  WHEN flag_quality = 'a. >=10K' AND main_price_acm2 >= 35000 THEN '1. HVC'
  WHEN flag_quality = 'a. >=10K' AND main_price_acm2 >= 10000 AND main_price_acm2 < 35000 THEN '2. MVC'
  WHEN flag_quality = 'b. <10K' AND (main_price_acm2 + sp_price) >= 10000 THEN '2. MVC'
 else '3. LVC' END flag_acm,
 a.msisdn,
 acq_rev
 from 
 (
  select *, 
  CASE
			WHEN flag_quality = 'a. >=10K' AND flag_sp LIKE 'SP Data%GB' THEN sp_price
			WHEN flag_quality = 'a. >=10K' AND flag_sp LIKE 'SP IM3%GB' THEN sp_price
			WHEN flag_quality = 'a. >=10K' AND main_price >= 10000 THEN main_price
			WHEN flag_quality = 'a. >=10K' AND rld_denom >= 10000 THEN rld_denom
			ELSE ifnull(main_price_acm, 0)
		END main_price_acm2
		, case when (upper(product_name) in ('PERDANA 3 GB/30HARI', 'PERDANA INTERNET 3GB/30HR', 'ULNEW3GBSPMAR25MO') 
	            or upper(product_name) like 'PERDANA INTERNET ONLINE 3GB%' 
				or upper(product_name) = 'SP IM3 3GB NEW' --start on Aug 2025
	  ) then 'SP 35K'
	  when flag_sp_grp in ('SP FWA','SP Modern','SP OLA','SP ORI') then 'SP OTHERS'
	  else 'Non SP 35K' end flag_sp_new
	from
 (
	select a.msisdn, site_id, a.dt_id, b.channel_grp
		, case
			when flag_sp='SP OLA' then 'SP OLA'
			when flag_sp='SP FWA' then 'SP FWA'
			when flag_sp='SP Zero' then 'SP Zero'
			when flag_sp='SP Modern CO Brand' then 'SP Modern'
			else 'SP ORI'
		end flag_sp_grp
		, flag_sp
		, b.product_name
		, b.main_price, b.rld_denom, b.main_price_acm
		, case when flag_sp='SP Zero' and a.msisdn=d.msisdn then d.kpk_rev else sp_price end as sp_price
		, coalesce(c.total_rev,0)/1.11 acq_rev
		, CASE
			WHEN flag_sp LIKE 'SP Data%GB' THEN 'a. >=10K'
			WHEN flag_sp LIKE 'SP IM3%GB' THEN 'a. >=10K'
			WHEN (main_price >= 10000 OR rld_denom >= 10000) THEN 'a. >=10K'
			WHEN (main_price >= 0) THEN 'b. <10K'
			ELSE NULL
		END flag_quality
	FROM `data-bi-prd-935c.bi_mart`.rgs_ga_90d_dly_govt a
	LEFT JOIN `data-bi-prd-935c.bi_mart`.rgs_ga_channel_mth_govt b
		ON a.msisdn = b.msisdn AND b.month_id = date_trunc(vdt_id,month)
	LEFT JOIN `data-bi-prd-935c.bi_mart`.rgs_mtd_govt c
		ON a.msisdn = c.msisdn AND c.dt_id = vdt_id
	left join (
		select distinct msisdn, cast(gross_price_amount as numeric) as kpk_rev
		from `data-dtp-prd-aa1a.stg.sp_zero_revenue`
		where date_trunc(date(dt_id),month) = date_trunc(vdt_id,month)
		and cast(gross_price_amount as numeric) > 0
	) d
		on a.msisdn=d.msisdn
	WHERE date_trunc(a.dt_id,month) = date_trunc(vdt_id,month) and a.dt_id <= vdt_id AND (churn_back = 'NO' OR recycled = 'YES')
	) a
) a
left outer join
(
 select distinct msisdn
 from `data-bi-prd-935c.bi_mart`.rgs_nogovt_dly
 where (flag_status = 'Active 2' or coalesce(total_rev,0)>0)
 and date_trunc(dt_id,month) = date_trunc(vdt_id + interval 2 month,month)
) c on a.msisdn = c.msisdn
) a
group by 1,2,3,5,6,7,8
;


----------------------------------------------------
---  ACQ REV (above IDR 35k) & (below IDR 35k) -----
----------------------------------------------------
delete from `data-bi-prd-935c.bi_dev`.ioh_snd_master_kpi_detail  where kpi in ('Acq Rev (above IDR 35k)','Acq Rev (below IDR 35k)')
and dt_id between date_trunc(vdt_id,month) and vdt_id and brand = 'IM3';
insert into  `data-bi-prd-935c.bi_dev`.ioh_snd_master_kpi_detail
select 'IM3' as brand, 
'site' as level,
site_id as level_value,
sum(cast(acq_rev as numeric)) as value ,
'dly' as time_flag,
current_timestamp() as insert_date,
case when flag_acm = '1. HVC' then 'Acq Rev (above IDR 35k)' else 'Acq Rev (below IDR 35k)' end as kpi_id,
dt_id
from
(
 select distinct dt_id, site_id, 
 CASE
  when flag_sp_new='SP 35K' then '1. HVC'
  when flag_sp in ('SP OLA','SP FWA') then '1. HVC'
  WHEN flag_quality = 'a. >=10K' AND main_price_acm2 >= 35000 THEN '1. HVC'
  WHEN flag_quality = 'a. >=10K' AND main_price_acm2 >= 10000 AND main_price_acm2 < 35000 THEN '2. MVC'
  WHEN flag_quality = 'b. <10K' AND (main_price_acm2 + sp_price) >= 10000 THEN '2. MVC'
 else '3. LVC' END flag_acm,
 a.msisdn,
 acq_rev
 from 
 (
  select *, 
  CASE
			WHEN flag_quality = 'a. >=10K' AND flag_sp LIKE 'SP Data%GB' THEN sp_price
			WHEN flag_quality = 'a. >=10K' AND flag_sp LIKE 'SP IM3%GB' THEN sp_price
			WHEN flag_quality = 'a. >=10K' AND main_price >= 10000 THEN main_price
			WHEN flag_quality = 'a. >=10K' AND rld_denom >= 10000 THEN rld_denom
			ELSE ifnull(main_price_acm, 0)
		END main_price_acm2
		, case when (upper(product_name) in ('PERDANA 3 GB/30HARI', 'PERDANA INTERNET 3GB/30HR', 'ULNEW3GBSPMAR25MO') 
	            or upper(product_name) like 'PERDANA INTERNET ONLINE 3GB%' 
				or upper(product_name) = 'SP IM3 3GB NEW' --start on Aug 2025
	  ) then 'SP 35K'
	  when flag_sp_grp in ('SP FWA','SP Modern','SP OLA','SP ORI') then 'SP OTHERS'
	  else 'Non SP 35K' end flag_sp_new
	from
 (
	select a.msisdn, site_id, a.dt_id, b.channel_grp
		, case
			when flag_sp='SP OLA' then 'SP OLA'
			when flag_sp='SP FWA' then 'SP FWA'
			when flag_sp='SP Zero' then 'SP Zero'
			when flag_sp='SP Modern CO Brand' then 'SP Modern'
			else 'SP ORI'
		end flag_sp_grp
		, flag_sp
		, b.product_name
		, b.main_price, b.rld_denom, b.main_price_acm
		, case when flag_sp='SP Zero' and a.msisdn=d.msisdn then d.kpk_rev else sp_price end as sp_price
		, coalesce(c.total_rev,0)/1.11 acq_rev
		, CASE
			WHEN flag_sp LIKE 'SP Data%GB' THEN 'a. >=10K'
			WHEN flag_sp LIKE 'SP IM3%GB' THEN 'a. >=10K'
			WHEN (main_price >= 10000 OR rld_denom >= 10000) THEN 'a. >=10K'
			WHEN (main_price >= 0) THEN 'b. <10K'
			ELSE NULL
		END flag_quality
	FROM `data-bi-prd-935c.bi_mart`.rgs_ga_90d_dly_govt a
	LEFT JOIN `data-bi-prd-935c.bi_mart`.rgs_ga_channel_mth_govt b
		ON a.msisdn = b.msisdn AND b.month_id = date_trunc(vdt_id,month)
	LEFT JOIN `data-bi-prd-935c.bi_mart`.rgs_mtd_govt c
		ON a.msisdn = c.msisdn AND c.dt_id = vdt_id
	left join (
		select distinct msisdn, cast(gross_price_amount as numeric) as kpk_rev
		from `data-dtp-prd-aa1a.stg.sp_zero_revenue`
		where date_trunc(date(dt_id),month) = date_trunc(vdt_id,month)
		and cast(gross_price_amount as numeric) > 0
	) d
		on a.msisdn=d.msisdn
	WHERE date_trunc(a.dt_id,month) = date_trunc(vdt_id,month) and a.dt_id <= vdt_id AND (churn_back = 'NO' OR recycled = 'YES')
	) a
) a
left outer join
(
 select distinct msisdn
 from `data-bi-prd-935c.bi_mart`.rgs_nogovt_dly
 where (flag_status = 'Active 2' or coalesce(total_rev,0)>0)
 and date_trunc(dt_id,month) = date_trunc(vdt_id + interval 2 month,month)
) c on a.msisdn = c.msisdn
) a
group by 1,2,3,5,6,7,8
;

------------------------------------------------
---- Acq. Revenue voucher gaming
-----------------------------------------------
-- Nov 25 on ward
delete from `data-bi-prd-935c.bi_dev`.ioh_snd_master_kpi_detail  where kpi in ('Acq_Rev_VchrGames','Acq_Rev_Excl_VchrGames')
and dt_id between date_trunc(vdt_id,month) and vdt_id and brand = 'IM3';
insert into  `data-bi-prd-935c.bi_dev`.ioh_snd_master_kpi_detail
with final as (
             select a.msisdn, a.site_id, date(a.dt_id) dt_id, 
             cast((coalesce(c.total_rev,0)/1.11) as numeric) as acq_rev, 
             cast(coalesce(d.games_rev,0) as numeric) as games_rev
             from `data-bi-prd-935c.bi_mart`.rgs_ga_90d_dly_govt a
             left join `data-bi-prd-935c.bi_mart`.rgs_ga_channel_mth_govt b on a.msisdn = b.msisdn AND b.month_id = date_trunc(vdt_id,month)
             left join `data-bi-prd-935c.bi_mart`.rgs_mtd_govt c on a.msisdn = c.msisdn and c.dt_id = vdt_id
             left outer join
             (
            -- fact revenue dashboard
             select date_trunc(date(a.dt_id),month) as mth, a.msisdn, sum(sales_price) as games_rev
              from
                (
                select a.*, 
                        case
                             when kpi = 'LOAN BALANCE' then 'OTHERS'
                             when svc_typ = 'FORFEIT' then 'OTHERS'
                            when kpi = 'VAS' and rev_code_nm in ('Melon Indonesia, PT',
                                                    'Nuon Digital Indonesia',
                                                    'Payment Gateway-Melon Indonesia PT', 
                                                    'Nuon Digital Indonesia, PT',
                                                    'Lionsgate - Melon Indonesia PT',
                                                    'Nadaku-Melon Indonesia, PT')  then 'VAS - VOUCHER GAMING'
                            when kpi = 'VAS' and rev_code_nm not in ('Melon Indonesia, PT',
                                                    'Nuon Digital Indonesia',
                                                    'Payment Gateway-Melon Indonesia PT', 
                                                    'Nuon Digital Indonesia, PT',
                                                    'Lionsgate - Melon Indonesia PT',
                                                    'Nadaku-Melon Indonesia, PT') then 'VAS - REGULAR'
                            else svc_typ 
                        end svc_typ_new
                from `data-dtp-prd-aa1a.sor`.fact_revenue_dashboard_extended a
                where date(dt_id) between date_trunc(vdt_id,month)  and vdt_id
                ) a
               where svc_typ_new = 'VAS - VOUCHER GAMING'
               and is_revenue = 'YES'
                -- and date_trunc(dt_id,month) = date_trunc(vdt_id,month) and dt_id <= vdt_id
              group by 1,2
             ) d on a.msisdn = d.msisdn and date_trunc(date(a.dt_id),month) = d.mth
             where date_trunc(a.dt_id,month) = date_trunc(vdt_id,month) and a.dt_id <= vdt_id AND (churn_back = 'NO' OR recycled = 'YES')
            ) 
-- acquisition rev vou games
select * from 
(
select 'IM3' as brand, 
    'site' as level,
    site_id as level_value,
    cast(sum(games_rev)as numeric) as value,
    'dly' as time_flag,
    current_timestamp() as insert_date,
    'Acq_Rev_VchrGames' as kpi_id,
    dt_id
from final
group by 1,2,3,5,6,7,8
)a
where value >0
union all
-- acquisition exclude vou games
select 'IM3' as brand, 
    'site' as level,
    site_id as level_value,
    cast(sum(acq_rev - games_rev)as numeric) as value,
    'dly' as time_flag,
    current_timestamp() as insert_date,
    'Acq_Rev_Excl_VchrGames' as kpi_id,
    dt_id
from final
group by 1,2,3,5,6,7,8
;


------------------------------------------------
---- GA voucher gaming
-----------------------------------------------
-- Nov 25 on ward
delete from `data-bi-prd-935c.bi_dev`.ioh_snd_master_kpi_detail  where kpi in ('ga_VchrGames')
and dt_id between date_trunc(vdt_id,month) and vdt_id and brand = 'IM3';
insert into  `data-bi-prd-935c.bi_dev`.ioh_snd_master_kpi_detail
with final as (
             select a.msisdn, a.site_id, a.dt_id, 
             cast((coalesce(c.total_rev,0)/1.11) as numeric) as acq_rev, 
             cast(coalesce(d.games_rev,0) as numeric) as games_rev
             from `data-bi-prd-935c.bi_mart`.rgs_ga_90d_dly_govt a
             left join `data-bi-prd-935c.bi_mart`.rgs_ga_channel_mth_govt b on a.msisdn = b.msisdn AND b.month_id = date_trunc(vdt_id,month)
             left join `data-bi-prd-935c.bi_mart`.rgs_mtd_govt c on a.msisdn = c.msisdn and c.dt_id = vdt_id
           join
             (
            -- fact revenue dashboard
             select date_trunc(date(a.dt_id),month) as mth, a.msisdn, sum(sales_price) as games_rev
              from
                (
                select a.*, 
                        case
                             when kpi = 'LOAN BALANCE' then 'OTHERS'
                             when svc_typ = 'FORFEIT' then 'OTHERS'
                            when kpi = 'VAS' and rev_code_nm in ('Melon Indonesia, PT',
                                                    'Nuon Digital Indonesia',
                                                    'Payment Gateway-Melon Indonesia PT', 
                                                    'Nuon Digital Indonesia, PT',
                                                    'Lionsgate - Melon Indonesia PT',
                                                    'Nadaku-Melon Indonesia, PT')  then 'VAS - VOUCHER GAMING'
                            when kpi = 'VAS' and rev_code_nm not in ('Melon Indonesia, PT',
                                                    'Nuon Digital Indonesia',
                                                    'Payment Gateway-Melon Indonesia PT', 
                                                    'Nuon Digital Indonesia, PT',
                                                    'Lionsgate - Melon Indonesia PT',
                                                    'Nadaku-Melon Indonesia, PT') then 'VAS - REGULAR'
                                                    else svc_typ 
                        end svc_typ_new
                from `data-dtp-prd-aa1a.sor`.fact_revenue_dashboard_extended a
                where date(dt_id) between date_trunc(vdt_id,month)  and vdt_id
                ) a
               where svc_typ_new = 'VAS - VOUCHER GAMING'
               and is_revenue = 'YES'
                -- and date_trunc(dt_id,month) = date_trunc(vdt_id,month) and dt_id <= vdt_id
              group by 1,2
             ) d on a.msisdn = d.msisdn and date_trunc(a.dt_id,month) = d.mth
             where date_trunc(a.dt_id,month) = date_trunc(vdt_id,month) and a.dt_id <= vdt_id AND (churn_back = 'NO' OR recycled = 'YES')
            ) 
-- ga vou games
select 'IM3' as brand, 
    'site' as level,
    site_id as level_value,
    cast(count(distinct msisdn)as numeric) as value,
    'dly' as time_flag,
    current_timestamp() as insert_date,
    'ga_VchrGames' as kpi_id,
    dt_id
from final
group by 1,2,3,5,6,7,8
;

--------------------------------------------------------
------- NEW GA & AQ REV GAMES VOUCHER -----------------
--------------------------------------------------------
delete from `data-bi-prd-935c.bi_dev`.ioh_snd_master_kpi_detail where brand = 'IM3' and kpi in (
'Acq Rev Games (35K)',
'Acq Rev (below 35k)',
'Acq Rev 35K and Above (35K)',
'GA Subs Games (35K)',
'GA Subs (below 35k)',
'Acq Rev Games',
'GA Subs Games (Non 35K)',
'GA Subs 35K and Above (35K)',
'Acq Rev 35K and Above (Non 35K)',
'GA Subs 35K and Above',
'GA Subs 35K and Above (Non 35K)',
'Acq Rev 35K and Above',
'Acq Rev Games (Non 35K)',
'GA Subs Games'
) and dt_id = vdt_id;
insert into `data-bi-prd-935c.bi_dev`.ioh_snd_master_kpi_detail 
with ga_acq_games_rev as (
    select  site_id,
            case when svc_class_code = '8139' then 'GA Subs 35K and Above (35K)'
                 when flag_acm = '1. HVC' then 
                  case when flag_sp_new = 'SP 35K' then 'GA Subs 35K and Above (35K)' 
            	  else 'GA Subs 35K and Above (Non 35K)' 
            	 end
            else 'GA Subs (below 35k)' end as sp_group,
    msisdn, acq_rev, games_rev
    from
    (
    select distinct date_trunc(dt_id,month) as mth_id
    	, site_id
    	,flag_sp_new
    	, CASE
    	    when flag_sp_new='SP 35K' then '1. HVC'
    	    when flag_sp in ('SP OLA','SP FWA') then '1. HVC'
    		WHEN flag_quality = 'a. >=10K' AND main_price_acm2 >= 35000 THEN '1. HVC'
    		WHEN flag_quality = 'a. >=10K' AND main_price_acm2 >= 10000 AND main_price_acm2 < 35000 THEN '2. MVC'
    		WHEN flag_quality = 'b. <10K' AND (main_price_acm2 + sp_price) >= 10000 THEN '2. MVC'
    		else '3. LVC'
    	END flag_acm,
    	SP_Pulse,
    	product_name,
    	a.msisdn,
    	a.svc_class_code,
    	case when c.msisdn is not null then 1 else 0 end as m2s_subs,
    	acq_rev,
    	coalesce(d.games_rev,0) as games_rev
    from (
    	select *
    		, CASE
    			WHEN flag_quality = 'a. >=10K' AND flag_sp LIKE 'SP Data%GB' THEN sp_price
    			WHEN flag_quality = 'a. >=10K' AND flag_sp LIKE 'SP IM3%GB' THEN sp_price
    			WHEN flag_quality = 'a. >=10K' AND main_price >= 10000 THEN main_price
    			WHEN flag_quality = 'a. >=10K' AND rld_denom >= 10000 THEN rld_denom
    			ELSE ifnull(main_price_acm, 0)
    		END main_price_acm2, 
    		case when (
    		            upper(product_name) in ('PERDANA 3 GB/30HARI', 'PERDANA INTERNET 3GB/30HR', 'ULNEW3GBSPMAR25MO') 
    	                or upper(product_name) like 'PERDANA INTERNET ONLINE 3GB%' 
    				    or upper(product_name) = 'SP IM3 3GB NEW' --start on Aug 2025
    	               ) then 'SP 35K'
    	         when flag_sp_grp in ('SP FWA','SP Modern','SP OLA','SP ORI') then 'SP OTHERS'
    	         else 'Non SP 35K' 
    	    end flag_sp_new,
    	    case when flag_sp_grp in ('SP Zero', 'SP Modern') then
    	            case when 
    	          product_name in ('1000000', '500000', '400000', '340000', '300000', '250000', '225000', '200000', '175000',
                                 '150000', '125000', '115000', '100000', '94000', '90000', '80000', '70000', '60000',
                                 '50000', '40000', '37000', '30000', '25000', '20000', '15000', '12000', '10000',
                                 '5000') 
                    then 'SP Pulse' else 'SP Others' end else 'SP Others' end as SP_Pulse
    	from
        (
        	select a.msisdn, a.svc_class_code, site_id, a.dt_id, b.channel_grp
        		, case
        			when flag_sp='SP OLA' then 'SP OLA'
        			when flag_sp='SP FWA' then 'SP FWA'
        			when flag_sp='SP Zero' then 'SP Zero'
        			when flag_sp='SP Modern CO Brand' then 'SP Modern'
        			else 'SP ORI'
        		end flag_sp_grp
        		, flag_sp
        		, b.product_name
        		, b.main_price, b.rld_denom, b.main_price_acm
        		, case when flag_sp='SP Zero' and a.msisdn=d.msisdn then d.kpk_rev else sp_price end as sp_price
        		, coalesce(c.total_rev,0)/1.11 acq_rev
        		, CASE
        			WHEN flag_sp LIKE 'SP Data%GB' THEN 'a. >=10K'
        			WHEN flag_sp LIKE 'SP IM3%GB' THEN 'a. >=10K'
        			WHEN (main_price >= 10000 OR rld_denom >= 10000) THEN 'a. >=10K'
        			WHEN (main_price >= 0) THEN 'b. <10K'
        			ELSE NULL
        		END flag_quality
        	FROM `data-bi-prd-935c.bi_mart`.rgs_ga_90d_dly_govt a
        	LEFT JOIN `data-bi-prd-935c.bi_mart`.rgs_ga_channel_mth_govt b
        		ON a.msisdn = b.msisdn AND b.month_id = date_trunc(vdt_id,month)
        	LEFT JOIN `data-bi-prd-935c.bi_mart`.rgs_mtd_govt c
        		ON a.msisdn = c.msisdn AND c.dt_id = vdt_id
        	left join (
        		select distinct msisdn, cast(gross_price_amount as numeric) as kpk_rev
        		from `data-dtp-prd-aa1a.stg.sp_zero_revenue`
        		where date_trunc(date(dt_id),month) = date_trunc(vdt_id,month)
        		and cast(gross_price_amount as numeric) > 0
        	) d
        		on a.msisdn=d.msisdn
        	WHERE date_trunc(a.dt_id,month) = date_trunc(vdt_id,month) and a.dt_id <= vdt_id AND (churn_back = 'NO' OR recycled = 'YES')
    	) a
    ) a
    left outer join
        (
        select distinct msisdn
        from `data-bi-prd-935c.bi_mart`.rgs_nogovt_dly
        where (flag_status = 'Active 2' or coalesce(total_rev,0)>0)
        and date_trunc(dt_id,month) = date_trunc(vdt_id + interval 2 month,month)
        ) c 
    on a.msisdn = c.msisdn
    left outer join
    (
    select date_trunc(date(a.dt_id),month) as mth, a.msisdn, sum(sales_price) as games_rev
    from 
        (
          select *, 
          case
           when kpi = 'LOAN BALANCE' then 'OTHERS'
           when svc_typ = 'FORFEIT' then 'OTHERS'
            when kpi = 'VAS' and rev_code_nm in ('Melon Indonesia, PT',
                                    'Nuon Digital Indonesia',
                                    'Payment Gateway-Melon Indonesia PT', 
                                    'Nuon Digital Indonesia, PT',
                                    'Lionsgate - Melon Indonesia PT',
                                    'Nadaku-Melon Indonesia, PT')  then 'VAS - VOUCHER GAMING'
            when kpi = 'VAS' and rev_code_nm not in ('Melon Indonesia, PT',
                                    'Nuon Digital Indonesia',
                                    'Payment Gateway-Melon Indonesia PT', 
                                    'Nuon Digital Indonesia, PT',
                                    'Lionsgate - Melon Indonesia PT',
                                    'Nadaku-Melon Indonesia, PT') then 'VAS - REGULAR'
                                    else svc_typ  
            end svc_typ_new
          from `data-dtp-prd-aa1a.sor`.fact_revenue_dashboard_extended
          where date_trunc(date(dt_id),month) = date_trunc(vdt_id,month) and date(dt_id) <= vdt_id
        ) a
        where svc_typ_new = 'VAS - VOUCHER GAMING'
        and is_revenue = 'YES'
        group by 1,2
    ) d on a.msisdn = d.msisdn and date_trunc(date(a.dt_id),month) = d.mth
    ) a
),
final as (
    ------ GA (Non Games)
    select 'IM3' brand, 'site' level, site_id as level_value, 
        cast(count(distinct msisdn) as numeric) value, 
        'mtd' as time_flag, 
         timestamp(current_datetime('+7')) as insert_date,
         sp_group as kpi_id, 
         vdt_id as dt_id
    from
    (
    select *, case when games_rev > (acq_rev - games_rev) then 'GA Games' else 'GA Non Games' end as GA_tag
    from ga_acq_games_rev
    ) a
    where a.GA_tag = 'GA Non Games'
    and sp_group in ('GA Subs 35K and Above (35K)', 'GA Subs 35K and Above (Non 35K)', 'GA Subs (below 35k)')
    group by 1,2,3,5,6,7,8
    union all 
    ------ ACQ REV (Non Games)
    select 'IM3' brand, 'site' level, site_id as level_value, 
        cast(sum(acq_rev) as numeric) value, 
        'mtd' as time_flag, 
         timestamp(current_datetime('+7')) as insert_date,
         case when sp_group = 'GA Subs 35K and Above (35K)' then 'Acq Rev 35K and Above (35K)'
              when sp_group = 'GA Subs 35K and Above (Non 35K)' then 'Acq Rev 35K and Above (Non 35K)'
              else 'Acq Rev (below 35k)' 
         end as kpi_id, 
         vdt_id as dt_id
    from
        (
        select *, case when games_rev > (acq_rev - games_rev) then 'GA Games' else 'GA Non Games' end as GA_tag
        from ga_acq_games_rev
        ) a
    where a.GA_tag = 'GA Non Games'
    and sp_group in ('GA Subs 35K and Above (35K)', 'GA Subs 35K and Above (Non 35K)', 'GA Subs (below 35k)')
    group by 1,2,3,5,6,7,8
    union all 
    ---- GA Load data (Games)
    select 'IM3' brand, 'site' level, site_id as level_value, 
        cast(count(distinct msisdn) as numeric) value, 
        'mtd' as time_flag, 
         timestamp(current_datetime('+7')) as insert_date,
         case when a.sp_group = 'GA Subs 35K and Above (35K)' then 'GA Subs Games (35K)'
              else 'GA Subs Games (Non 35K)' 
          end as kpi_id, 
         vdt_id as dt_id
    from
    (
    select *, case when games_rev > (acq_rev - games_rev) then 'GA Games' else 'GA Non Games' end as GA_tag
    from ga_acq_games_rev
    ) a
    where a.GA_tag = 'GA Games'
    and sp_group in ('GA Subs 35K and Above (35K)', 'GA Subs 35K and Above (Non 35K)', 'GA Subs (below 35k)')
    group by 1,2,3,5,6,7,8
    union all 
    --- ACQ REV (games)
    select 'IM3' brand, 'site' level, site_id as level_value, 
         cast(sum(acq_rev) as numeric) value, 
        'mtd' as time_flag, 
         timestamp(current_datetime('+7')) as insert_date,
         case when sp_group = 'GA Subs 35K and Above (35K)' then 'Acq Rev Games (35K)'
              else 'Acq Rev Games (Non 35K)' 
          end as kpi_id, 
         vdt_id as dt_id
    from
    (
    select *, case when games_rev > (acq_rev - games_rev) then 'GA Games' else 'GA Non Games' end as GA_tag
    from ga_acq_games_rev
    ) a
    where a.GA_tag = 'GA Games'
    and sp_group in ('GA Subs 35K and Above (35K)', 'GA Subs 35K and Above (Non 35K)', 'GA Subs (below 35k)')
    group by 1,2,3,5,6,7,8
) 
---- SUMMARY ALL
select * from final
union all 
--Load data (Parents)
select 'IM3' as brand, 
        level,
        level_value,
        sum(value) as value,
        time_flag,
        timestamp(current_datetime('+7')) as insert_date,
case when kpi_id in ('GA Subs 35K and Above (35K)', 'GA Subs 35K and Above (Non 35K)') then 'GA Subs 35K and Above'
    when kpi_id in ('GA Subs Games (35K)', 'GA Subs Games (Non 35K)') then 'GA Subs Games'
    when kpi_id in ('Acq Rev 35K and Above (35K)', 'Acq Rev 35K and Above (Non 35K)') then 'Acq Rev 35K and Above'
    when kpi_id in ('Acq Rev Games (35K)', 'Acq Rev Games (Non 35K)') then 'Acq Rev Games'
else 'N/A' end as kpi_id,
vdt_id as dt_id
from final a
where dt_id = vdt_id
and time_flag = 'mtd'
and kpi_id in ('GA Subs 35K and Above (35K)', 'GA Subs 35K and Above (Non 35K)', 'GA Subs Games (35K)', 'GA Subs Games (Non 35K)',
            'Acq Rev 35K and Above (35K)', 'Acq Rev 35K and Above (Non 35K)', 'Acq Rev Games (35K)', 'Acq Rev Games (Non 35K)')
group by 1,2,3,5,6,7,8
;

-- --- Insert to table Summary

-- -- create table `data-bi-prd-935c.bi_dev`.ioh_snd_master_kpi_detail_smy partitioned by (kpi_id,dt_id) stored as parquet as
-- insert into `data-bi-prd-935c.bi_dev`.ioh_snd_master_kpi_detail_smy 
-- with ref_dealer as (
--             select a.id, b.circle, b.region region_circle, b.area, b.sales_area, b.micro_cluster
--                 from  rdm.spa_tbl_ref_lowlevel_mth a
--                 left join
--                         (
--                         select * from `data-bi-prd-935c.bi_mart`.ref_kecamatan
--                             ) b
--                         on a.kec_unik = b.kec_kabkot
--                 where a.mth = substr(vdt_id,1,6)
--             ),
-- ref_dealer_rn as (            
--             select a.id, b.circle, b.region region_circle, b.area, b.sales_area, b.micro_cluster
--                 from
--                 (
--                     select * from 
--                     (
--                     select a.*, 
--                         ROW_NUMBER() OVER (partition by id ORDER BY mth desc) AS rn 
--                     from  rdm.spa_tbl_ref_lowlevel_mth a
--                     )a
--                     where rn = 1
--                 )a
--             left join
--                 (select * from `data-bi-prd-935c.bi_mart`.ref_kecamatan) b
--             on a.kec_unik = b.kec_kabkot
--             ), 
-- tracker as (
--     select *
--     from `data-bi-prd-935c.bi_dev`.ioh_snd_master_kpi_detail
--     where   dt_id =  vdt_id 
--         and kpi_id in 
--         ('rgu_ga','surv_m2','ga_m2','ga_m2_trad','ga_m2_nontrad',
--         'acquisition_revenue','rgu_ga_trad','rgu_ga_nontrad',
--          'surv_m2_trad','surv_m2_nontrad','acq_rev_rguga_trad_data','acq_rev_rguga_trad_non_data',
--          'acq_rev_rguga_trad','acq_rev_rguga_nontrad',
--             'GA Subs 35K and Above',
--             'GA Subs 35K and Above (35K)',
--             'GA Subs 35K and Above (Non 35K)',
--             'GA Subs (below 35k)',
--             'GA Subs Games',
--             'GA Subs Games (35K)',
--             'GA Subs Games (Non 35K)',
--             'Acq Rev 35K and Above',
--             'Acq Rev 35K and Above (35K)',
--             'Acq Rev 35K and Above (Non 35K)',
--             'Acq Rev (below 35k)',
--             'Acq Rev Games',
--             'Acq Rev Games (35K)',
--             'Acq Rev Games (Non 35K)'
--         )
--             )
-- select  a.brand, b.circle, b.region_circle as region, b.area, b.sales_area branch,b.micro_cluster cluster,
--     --    coalesce(b.circle,c.circle) as circle,
--     --    coalesce(b.region_circle,c.region_circle) as region,
--     --    coalesce(b.area,c.area) as area,
--     --    coalesce(b.sales_area,c.sales_area) as branch,
--     --   coalesce(b.micro_cluster,c.micro_cluster) as cluster,
--         sum(value) value,
--         a.kpi_id,
--         a.dt_id
--     from tracker a 
--         left join ref_dealer b
--     on a.level_value=b.id 
--    --     left join ref_dealer_rn c
--    -- on a.level_value=c.id 
-- group by 1,2,3,4,5,6,8,9
-- ;


-- --- Insert to table Summary yg DLY jadiin ke MTD 

-- -- create table `data-bi-prd-935c.bi_dev`.ioh_snd_master_kpi_detail_smy partitioned by (kpi_id,dt_id) stored as parquet as
-- insert into `data-bi-prd-935c.bi_dev`.ioh_snd_master_kpi_detail_smy 
-- with ref_dealer as (
--             select a.id, b.circle, b.region region_circle, b.area, b.sales_area, b.micro_cluster
--                 from  rdm.spa_tbl_ref_lowlevel_mth a
--                 left join
--                         (
--                         select * from `data-bi-prd-935c.bi_mart`.ref_kecamatan
--                             ) b
--                         on a.kec_unik = b.kec_kabkot
--                 where a.mth = substr(vdt_id,1,6)
--             ),
-- ref_dealer_rn as (            
--             select a.id, b.circle, b.region region_circle, b.area, b.sales_area, b.micro_cluster
--                 from
--                 (
--                     select * from 
--                     (
--                     select a.*, 
--                         ROW_NUMBER() OVER (partition by id ORDER BY mth desc) AS rn 
--                     from  rdm.spa_tbl_ref_lowlevel_mth a
--                     )a
--                     where rn = 1
--                 )a
--             left join
--                 (select * from `data-bi-prd-935c.bi_mart`.ref_kecamatan) b
--             on a.kec_unik = b.kec_kabkot
--             ), 
-- tracker as (
--     select *
--     from `data-bi-prd-935c.bi_dev`.ioh_snd_master_kpi_detail
--     where  dt_id between date_trunc(vdt_id,month) and vdt_id 
--         and kpi_id in 
--         ('GA Subs (above IDR 35k)','GA Subs (below IDR 35k)','Acq Rev (above IDR 35k)','Acq Rev (below IDR 35k)',
--          'Acq_Rev_Excl_VchrGames','Acq_Rev_VchrGames','ga_VchrGames'
--         )
--             )
-- select  a.brand, b.circle, b.region_circle as region, b.area, b.sales_area branch,b.micro_cluster cluster,
--     --    coalesce(b.circle,c.circle) as circle,
--     --    coalesce(b.region_circle,c.region_circle) as region,
--     --    coalesce(b.area,c.area) as area,
--     --    coalesce(b.sales_area,c.sales_area) as branch,
--     --   coalesce(b.micro_cluster,c.micro_cluster) as cluster,
--         sum(value) value,
--         a.kpi_id,
--         vdt_id  dt_id
--     from tracker a 
--         left join ref_dealer b
--     on a.level_value=b.id 
--    --     left join ref_dealer_rn c
--    -- on a.level_value=c.id 
-- group by 1,2,3,4,5,6,8,9
-- ;