declare vdt_id date default @vdt_id;
--IM3
---------------- acquisition_revenue  ----------------

delete from `data-bi-prd-935c.bi_dev`.ioh_snd_master_kpi_detail  where kpi = 'acquisition_revenue'
and dt_id = vdt_id and brand = 'IM3';
insert into `data-bi-prd-935c.bi_dev`.ioh_snd_master_kpi_detail 
select 'IM3' brand, 'site' level, id as level_value, 
    sum(cast(value as numeric)) value, 
    'mtd' as time_flag, 
     timestamp(current_datetime('+7')) as insert_date,
    'acquisition_revenue' as kpi_id, 
    dt_id
from
(
SELECT 
    dt_id,
    mtd_site id,
    sum(a.acq_rev) value
from `data-bi-prd-935c.bi_mart`.rgs_srs_acq_25mb_govt a
where dt_id =vdt_id
and date_trunc(a.ga_dt,month) = date_trunc(a.dt_id,month)
group by 1,2
)a
group by 1,2,3,5,6,7,8
;



------------------------------------
---- Acq. Revenue Data Non Data ----
------------------------------------
delete from `data-bi-prd-935c.bi_dev`.ioh_snd_master_kpi_detail  where kpi in ('acq_rev_rguga_nontrad','acq_rev_rguga_trad_data','acq_rev_rguga_trad_non_data', 'acq_rev_rguga_trad')
and dt_id = vdt_id and brand = 'IM3';
insert into `data-bi-prd-935c.bi_dev`.ioh_snd_master_kpi_detail   
with acq_rev as 
    (
        select 
            a.mth_id
            , a.msisdn
            , a.site_id
            , case when channel_grp in ('DSF','TRADITIONAL') then 'TRADITIONAL' else channel_grp end channel_grp
            , case when flag_acm is null then 'Without Injection' else 'With Injection' end flag_inject
            , CASE 
                WHEN flag_acm IN ( 'c. >=35k - <50k', 'd. >=50k' ) then 'HVC'
                WHEN flag_acm IN ( 'a. >=10k - <25k', 'b. >=25k - <35k', 'd. >=10k' ) then 'MVC'
                WHEN flag_acm IN ( 'a. <5k', 'b. >=5k - <7k', 'c. >=7k - <10k' ) then 'LVC'
            END flag_segment
            , flag_channel
        from 
            (
select 
                     date_trunc(date(dt_id),month) as mth_id, 
                     a.msisdn, 
                     flag_acm,
                     channel_grp,
                     site_id,
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
                    end flag_channel
                 FROM `data-bi-prd-935c.bi_mart`.rgs_ga_90d_dly_govt a
                 join `data-bi-prd-935c.bi_mart`.rgs_ga_channel_mth_govt b
                     on a.msisdn = b.msisdn
                     and DATE(a.dt_id) = b.ga_dt
                 where
                     (
                         (date_trunc(a.dt_id,month) = date_trunc(vdt_id,month) and a.dt_id <= vdt_id)  
                     )
                 AND (churn_back = 'NO' OR recycled = 'YES')
            ) a
    ),
rev as 
    (
        select 
            date_trunc(date(dt_id),month) as mth_id
            , msisdn
            , case when svc_typ='DATA' then 'DATA' else 'NON DATA' end svc_typ
            , case
                when package_flag='GIFT' and svc_typ='DATA' then 'GIFT DATA'
                when package_flag='GIFT' and svc_typ!='DATA' then 'GIFT NON DATA'
                when kpi='VAS' then 'VAS'
                when svc_typ='DATA' then 'DATA'
                else 'NON DATA'
            end flag
            , sum(case when kpi='VAS' then main_price else sales_price end) as rev
        from `data-dtp-prd-aa1a.sor`.fact_revenue_dashboard_extended a
        where 
            (
                (date_trunc(date(a.dt_id),month) = date_trunc(vdt_id,month) and date(a.dt_id) <= vdt_id)  
               -- or (date_trunc(a.dt_id,month) = date_trunc(vdt_id - interval 1 month,month) and a.dt_id <= vdt_id - interval 1 month)
               -- or (date_trunc(a.dt_id,month) = date_trunc(vdt_id - interval 2 month,month) and a.dt_id <= vdt_id - interval 2 month)
            )
        and kpi not in ('BALANCE FORFEIT','MARKUP PULSA','B2C MOBILE EXP', 'LOAN FLEXY FEE','LOAN FLEXY FEE STV',
                    'LOAN FLEXY PRINCIPAL','LOAN FLEXY PRINCIPAL STV', 'PPSR CLAIM','PREPAID NON USAGE', 
                    'REVENUE FTTH PLAN','REVENUE POSTPAID CVM FLEXY','REVENUE POSTPAID PULSA','REVENUE PROPAID USAGE',
                    'REVENUE VOUCHER FORFEIT','VMS CLAIM'
                        ) -- remove
        -- and regexp_like(coalesce(revenue_trigger,''),'Y4|Adjustment','i')=False -- remove expired
        and is_revenue = 'YES' and NOT REGEXP_CONTAINS(COALESCE(revenue_trigger, ''),r'(?i)(Y4|Adjustment)') -- remove expired
        group by 1,2,3,4
    ),
final as (
        select 
            a.mth_id
            , a.site_id
            ,a.flag_channel
            , coalesce(b.svc_typ,'NON DATA') as svc_typ
            , coalesce(b.flag,'NON DATA') as flag
            , count(distinct a.msisdn) as subs
            , sum(coalesce(b.rev,0)) as rev
        from acq_rev a
        left join 
            rev b
            on a.msisdn=b.msisdn 
            and a.mth_id=b.mth_id
        group by 1,2,3,4,5
        order by 1,2,3,4,5
        )
----------- acq_rev_rguga_trad_data
----------- acq_rev_rguga_trad_non_data
select 
     'IM3' brand, 'site' level, site_id as level_value, 
    cast(sum(rev) as numeric) value,
    (case
        when mth_id = date_trunc(vdt_id,month) then 'mtd'
       -- when mth_id = date_trunc(vdt_id - interval 1 month,month) then 'lmtd'
       -- when mth_id = date_trunc(vdt_id - interval 2 month,month) then 'llmtd'
    end) time_flag,
    timestamp(current_datetime('+7')) as insert_date,
    (case
        when svc_typ = 'DATA' then 'acq_rev_rguga_trad_data'
        when svc_typ = 'NON DATA' then 'acq_rev_rguga_trad_non_data'
    end) as kpi_id,
    vdt_id as dt_id
from final
where flag_channel in ('RGUGA-Trad-Outlet','RGUGA-Trad-DSF')
group by 1,2,3,5,6,7,8
union all 
--------- acq_rev_rguga_trad --------
select 
     'IM3' brand, 'site' level, site_id as level_value, 
    cast(sum(rev) as numeric) value,
    (case
        when mth_id = date_trunc(vdt_id,month) then 'mtd'
       -- when mth_id = date_trunc(vdt_id - interval 1 month,month) then 'lmtd'
       -- when mth_id = date_trunc(vdt_id - interval 2 month,month) then 'llmtd'
    end) time_flag,
    timestamp(current_datetime('+7')) as insert_date,
    'acq_rev_rguga_trad' as kpi_id,
    vdt_id as dt_id
from final
where flag_channel in ('RGUGA-Trad-Outlet','RGUGA-Trad-DSF')
group by 1,2,3,5,6,7,8
union all 
--------- acq_rev_rguga_non trad --------
select 
     'IM3' brand, 'site' level, site_id as level_value, 
    cast(sum(rev) as numeric) value,
    (case
        when mth_id = date_trunc(vdt_id,month) then 'mtd'
       -- when mth_id = date_trunc(vdt_id - interval 1 month,month) then 'lmtd'
       -- when mth_id = date_trunc(vdt_id - interval 2 month,month) then 'llmtd'
    end) time_flag,
    timestamp(current_datetime('+7')) as insert_date,
    'acq_rev_rguga_nontrad' as kpi_id,
    vdt_id as dt_id
from final
    where flag_channel not in ('RGUGA-Trad-Outlet','RGUGA-Trad-DSF')
group by 1,2,3,5,6,7,8
;

--------------------------------------
---- Acq. Revenue by Slab Segment ----
--------------------------------------
delete from `data-bi-prd-935c.bi_dev`.ioh_snd_master_kpi_detail 
where kpi in(
'acq_rev_rguga_trad_hvc',
'acq_rev_rguga_trad_mvc',
'acq_rev_rguga_trad_lvc',
'acq_rev_rguga_trad_noinj',
'acq_rev_rguga_trad_sptryme'
) and dt_id = vdt_id and brand ='IM3';

insert into `data-bi-prd-935c.bi_dev`.ioh_snd_master_kpi_detail 
select 'IM3' brand, 'site' level, a.id as level_value, 
    coalesce(cast(sum(a.acq_rev)/1.11 as numeric),0) value, 
    (case
        when date_trunc(a.dt_id,month) = date_trunc(vdt_id,month) then 'mtd'
        -- when date_trunc(a.dt_id,month) = date_trunc(vdt_id - interval 1 month,month) then 'lmtd'
        -- when date_trunc(a.dt_id,month) = date_trunc(vdt_id - interval 2 month,month) then 'llmtd'
    end) as time_flag, 
    timestamp(current_datetime('+7')) as insert_date,
    (case
        when parameter like '%HVC%' then 'acq_rev_rguga_trad_hvc'
        when parameter like '%MVC%' then 'acq_rev_rguga_trad_mvc'
        when parameter like '%LVC%' then 'acq_rev_rguga_trad_lvc'
        when parameter like '%NO INJ%' then 'acq_rev_rguga_trad_noinj'
        when parameter like '%Try Me%' then 'acq_rev_rguga_trad_sptryme'
    end) as kpi_id, 
    vdt_id as dt_id
from 
    (
        select 
            a.site_id id,
            a.dt_id,
            a.msisdn,
            acq_rev.acq_rev,
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
                select 
                    dt_id,
                    a.ga_dt,
                    a.msisdn,
                    sum(a.acq_rev) acq_rev
                from `data-bi-prd-935c.bi_mart`.rgs_srs_acq_25mb_govt a
                where a.dt_id in 
                        (
                            vdt_id
                            --,date(vdt_id - interval 1 month)
                            --,date(vdt_id - interval 2 month)
                        ) 
                and date_trunc(a.ga_dt,month) = date_trunc(a.dt_id,month)
                group by 1,2,3
            ) acq_rev
            on a.msisdn = acq_rev.msisdn
            and a.dt_id = acq_rev.ga_dt
        left join
            (
               select a.* 
               from 
               (
               SELECT distinct sales_order as so_number
                    , gross_price_perunit
                    , round((safe_cast(net_sales_perunit as numeric)*1.11),0) so_price
                    , dt_id
                    , ROW_NUMBER() OVER (partition by sales_order ORDER BY dt_id desc) AS rn
               FROM `data-dtp-prd-aa1a.stg.reference_zero` 
               where dt_id >= '2025-01-01'  -- fixed date
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
                      --  or (date_trunc(date(a.taker_date),month) = date_trunc(vdt_id - interval 1 month,month) and date(a.taker_date) <= vdt_id - interval 1 month)
                      --  or (date_trunc(date(a.taker_date),month) = date_trunc(vdt_id - interval 2 month,month) and date(a.taker_date) <= vdt_id - interval 2 month)
                    )
                and product_campaign = 'SP Zero'
            ) try_me
            on a.msisdn = try_me.msisdn
            and date_trunc(a.dt_id,month) = try_me.mth
        where 
            (
                    (date_trunc(a.dt_id,month) = date_trunc(vdt_id,month) and a.dt_id <= vdt_id)  
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
    ) a
group by 1,2,3,5,6,7,8
;

--------------------------------------
------- Acq. Revenue Trad SP 6GB -----
--------------------------------------
delete from `data-bi-prd-935c.bi_dev`.ioh_snd_master_kpi_detail 
where kpi in(
'acq_rev_rguga_trad_sp6gb',
'acq_rev_rguga_trad_sp3gb'
) and dt_id = vdt_id and brand ='IM3';

insert into `data-bi-prd-935c.bi_dev`.ioh_snd_master_kpi_detail 
select 'IM3' brand, 'site' level, a.site_id as level_value, 
    coalesce(cast(sum(acq_rev.acq_rev)/1.11 as numeric),0) value, 
    (case
        when date_trunc(a.dt_id,month) = date_trunc(vdt_id,month) then 'mtd'
        -- when date_trunc(a.dt_id,month) = date_trunc(vdt_id - interval 1 month,month) then 'lmtd'
        -- when date_trunc(a.dt_id,month) = date_trunc(vdt_id - interval 2 month,month) then 'llmtd'
    end) as time_flag, 
    timestamp(current_datetime('+7')) as insert_date,
    (case 
        when flag_sp = 'SP IM3 6GB' then 'acq_rev_rguga_trad_sp6gb'
        when flag_sp = 'SP IM3 3GB' then 'acq_rev_rguga_trad_sp3gb'
    end) as kpi_id, 
    vdt_id as dt_id
from `data-bi-prd-935c.bi_mart`.rgs_ga_90d_dly_govt a
join `data-bi-prd-935c.bi_mart`.rgs_ga_channel_mth_govt b
    on a.msisdn = b.msisdn
    and a.dt_id = b.ga_dt
left join
    (
        select 
            dt_id,
            a.ga_dt,
            a.msisdn,
            sum(a.acq_rev) acq_rev
        from `data-bi-prd-935c.bi_mart`.rgs_srs_acq_25mb_govt a
        where a.dt_id in 
                (
                    vdt_id
                    ,date(vdt_id - interval 1 month)
                    ,date(vdt_id - interval 2 month)
                ) 
        and date_trunc(a.ga_dt,month) = date_trunc(a.dt_id,month)
        group by 1,2,3
    ) acq_rev
    on a.msisdn = acq_rev.msisdn
    and a.dt_id = acq_rev.ga_dt
where 
    (date_trunc(a.dt_id,month) = date_trunc(vdt_id,month) and a.dt_id <= vdt_id)  
    --or (date_trunc(a.dt_id,month) = date_trunc(vdt_id - interval 1 month,month) and a.dt_id <= vdt_id - interval 1 month)
    --or (date_trunc(a.dt_id,month) = date_trunc(vdt_id - interval 2 month,month) and a.dt_id <= vdt_id - interval 2 month)
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
group by 1,2,3,5,6,7,8
;

-- --3ID
-- -- depend on GA trade table 

DELETE FROM `data-bi-prd-935c.bi_dev`.ioh_snd_master_kpi_detail
WHERE lower(kpi) IN (
'acq_rev_rguga_trad',
'acq_rev_rguga_trad_noinj',
'acq_rev_rguga_trad_lvc',
'acq_rev_rguga_trad_mvc',
'acq_rev_rguga_trad_hvc',
'acq_rev_rguga_trad_spdemo',
'acq_rev_rguga_trad_sp3gb',
'acq_rev_rguga_trad_fwa',
'acq_rev_rguga_trad_data',
'acq_rev_rguga_trad_non_data') 
 AND dt_id = vdt_id AND brand = '3ID';

INSERT INTO `data-bi-prd-935c.bi_dev`.ioh_snd_master_kpi_detail 
   WITH acq_rev_data AS (
    SELECT 
        vdt_id dt_id, 
        coalesce(a.site_id, 'null') AS site_id,
        a.acq_rev,
        a.acq_rev_data,
        a.acq_rev_nondata,
        a.flag_type,
        a.call_plan,
        a.channel,
        b.ret_type
    FROM `data-bi-prd-935c.bi_mart.snd_rgu_ga_new_detail` a
    LEFT JOIN (
        SELECT DISTINCT retailer_qrcode, ret_type
        FROM `data-dtptechm-prd-c7ca.dwh.retailer_hierarchy`
        WHERE periode_data = vdt_id
    ) b ON a.partner_qr_cd = b.retailer_qrcode
    WHERE 
        a.load_dt_sk_id BETWEEN DATE_TRUNC(vdt_id, MONTH) AND vdt_id
        AND (
            CASE
                WHEN a.channel LIKE 'CIRCLE%' THEN
                    CASE
                        WHEN b.ret_type = 'D' THEN 'RGUGA-Trad-DSF'
                        ELSE 'RGUGA-Trad-Outlet'
                    END
                WHEN a.channel = 'DOH POOL' THEN	
                    CASE
                        WHEN b.ret_type = 'D' THEN 'RGUGA-Trad-DSF'
                        ELSE 'RGUGA-Trad-Outlet'
                    END
                WHEN a.channel LIKE '%FWA%' THEN 'RGUGA-FWA'
                WHEN a.channel IN ('DOH MODERN CHANNEL', 'DOH TRI OFFICIAL STORE', 'DOH DVM', 'DOH THREE STORE') THEN 'RGUGA-Digital-Modern'
                WHEN a.channel IN ('DOH SAHABAT VIRTUAL') THEN 'RGUGA-Digital-Online'
                WHEN a.channel IN ('DOH SIM ONLINE') THEN 'RGUGA-Digital-OLA'
                ELSE 'RGUGA-Trad-Outlet'
            END
        ) IN ('RGUGA-Trad-Outlet', 'RGUGA-Trad-DSF', 'RGUGA-FWA')
)
SELECT * FROM (
    -- acq_rev_rguga_trad
    SELECT
        '3ID' AS brand_id,
        'site_id' AS level_id,
        site_id AS level_value,
        SUM(CASE WHEN channel NOT LIKE '%FWA%' THEN acq_rev END) AS kpi_value,
        'mtd' AS period_type,
        CURRENT_TIMESTAMP() AS uVDate_dttm,
        'acq_rev_rguga_trad' AS kpi_name,
        vdt_id AS dt_id
    FROM acq_rev_data
    GROUP BY dt_id, site_id

    UNION ALL

    -- acq_rev_rguga_trad_noinj
    SELECT
        '3ID' AS brand_id,
        'site_id' AS level_id,
        site_id AS level_value,
        SUM(CASE WHEN flag_type = 'NO INJ' AND channel NOT LIKE '%FWA%' THEN acq_rev END) AS kpi_value,
        'mtd' AS period_type,
        CURRENT_TIMESTAMP() AS uVDate_dttm,
        'acq_rev_rguga_trad_noinj' AS kpi_name,
        vdt_id AS dt_id
    FROM acq_rev_data
    GROUP BY dt_id, site_id
    
    UNION ALL

    -- acq_rev_rguga_trad_lvc
    SELECT
        '3ID' AS brand_id,
        'site_id' AS level_id,
        site_id AS level_value,
        SUM(CASE WHEN flag_type = 'LVC' AND channel NOT LIKE '%FWA%' THEN acq_rev END) AS kpi_value,
        'mtd' AS period_type,
        CURRENT_TIMESTAMP() AS uVDate_dttm,
        'acq_rev_rguga_trad_lvc' AS kpi_name,
        vdt_id AS dt_id
    FROM acq_rev_data
    GROUP BY dt_id, site_id
    
    UNION ALL

    -- acq_rev_rguga_trad_mvc
    SELECT
        '3ID' AS brand_id,
        'site_id' AS level_id,
        site_id AS level_value,
        SUM(CASE WHEN flag_type = 'MVC' AND channel NOT LIKE '%FWA%' THEN acq_rev END) AS kpi_value,
        'mtd' AS period_type,
        CURRENT_TIMESTAMP() AS uVDate_dttm,
        'acq_rev_rguga_trad_mvc' AS kpi_name,
        vdt_id AS dt_id
    FROM acq_rev_data
    GROUP BY dt_id, site_id
    
    UNION ALL

    -- acq_rev_rguga_trad_hvc
    SELECT
        '3ID' AS brand_id,
        'site_id' AS level_id,
        site_id AS level_value,
        SUM(CASE WHEN flag_type = 'HVC' AND channel NOT LIKE '%FWA%' THEN acq_rev END) AS kpi_value,
        'mtd' AS period_type,
        CURRENT_TIMESTAMP() AS uVDate_dttm,
        'acq_rev_rguga_trad_hvc' AS kpi_name,
        vdt_id AS dt_id
    FROM acq_rev_data
    GROUP BY dt_id, site_id
    
    UNION ALL

    -- acq_rev_rguga_trad_spdemo
    SELECT
        '3ID' AS brand_id,
        'site_id' AS level_id,
        site_id AS level_value,
        SUM(CASE WHEN trim(upper(call_plan)) = 'SP DEMO' AND channel NOT LIKE '%FWA%' THEN acq_rev END) AS kpi_value,
        'mtd' AS period_type,
        CURRENT_TIMESTAMP() AS uVDate_dttm,
        'acq_rev_rguga_trad_spdemo' AS kpi_name,
        vdt_id AS dt_id
    FROM acq_rev_data
    GROUP BY dt_id, site_id
    
    UNION ALL

    -- acq_rev_rguga_trad_sp3gb
    SELECT
        '3ID' AS brand_id,
        'site_id' AS level_id,
        site_id AS level_value,
        SUM(CASE WHEN trim(upper(call_plan)) LIKE 'SP HAPPY 3GB 30D%' AND channel NOT LIKE '%FWA%' THEN acq_rev END) AS kpi_value,
        'mtd' AS period_type,
        CURRENT_TIMESTAMP() AS uVDate_dttm,
        'acq_rev_rguga_trad_sp3gb' AS kpi_name,
        vdt_id AS dt_id
    FROM acq_rev_data
    GROUP BY dt_id, site_id
    
    UNION ALL

    -- acq_rev_rguga_trad_fwa
    SELECT
        '3ID' AS brand_id,
        'site_id' AS level_id,
        site_id AS level_value,
        SUM(CASE WHEN channel LIKE '%FWA%' THEN acq_rev END) AS kpi_value,
        'mtd' AS period_type,
        CURRENT_TIMESTAMP() AS uVDate_dttm,
        'acq_rev_rguga_trad_fwa' AS kpi_name,
        vdt_id AS dt_id
    FROM acq_rev_data
    GROUP BY dt_id, site_id

    UNION ALL
    
    -- acq_rev_rguga_trad_data
    SELECT
        '3ID' AS brand_id,
        'site_id' AS level_id,
        site_id AS level_value,
        SUM(CASE WHEN channel NOT LIKE '%FWA%' THEN acq_rev_data.acq_rev_data END) AS kpi_value,
        'mtd' AS period_type,
        CURRENT_TIMESTAMP() AS uVDate_dttm,
        'acq_rev_rguga_trad_data' AS kpi_name,
        vdt_id AS dt_id
    FROM acq_rev_data
    GROUP BY dt_id, site_id
    
    UNION ALL

    -- acq_rev_rguga_trad_non_data
    SELECT
        '3ID' AS brand_id,
        'site_id' AS level_id,
        site_id AS level_value,
        SUM(CASE WHEN channel NOT LIKE '%FWA%' THEN acq_rev_nondata END) AS kpi_value,
        'mtd' AS period_type,
        CURRENT_TIMESTAMP() AS uVDate_dttm,
        'acq_rev_rguga_trad_non_data' AS kpi_name,
        vdt_id AS dt_id
    FROM acq_rev_data
    GROUP BY dt_id, site_id

) AS combined_results;