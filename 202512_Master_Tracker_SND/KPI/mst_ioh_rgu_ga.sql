declare vdt_id date default @vdt_id;
--IM3
delete from `data-bi-prd-935c.bi_dev`.ioh_snd_master_kpi_detail where kpi = 'rgu_ga_trad' and dt_id = vdt_id and brand = 'IM3';
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
-- rgu ga trad
select 'IM3' brand, 'site' level, site_id as level_value, 
    cast(count(msisdn) as numeric) value, 
    'mtd' as time_flag, 
     timestamp(current_datetime('+7')) as insert_date,
    'rgu_ga_trad' as kpi, 
    vdt_id as dt_id
from ga
    where parameter in ('RGUGA-Trad-Outlet','RGUGA-Trad-DSF')
group by 1,2,3,5,6,7,8;

delete from `data-bi-prd-935c.bi_dev`.ioh_snd_master_kpi_detail where kpi = 'rgu_ga_outlet' and dt_id = vdt_id and brand = 'IM3';
insert into `data-bi-prd-935c.bi_dev`.ioh_snd_master_kpi_detail
with ga as (
    select *  from 
            (
                select a.msisdn, a.dt_id ga_dt, a.site_id, organization_id, flag_quality, main_price_acm2, flag_sp,channel_grp
                 from  `data-bi-prd-935c.bi_mart`.rgs_ga_90d_dly_govt a
                join (select *
                        from  `data-bi-prd-935c.bi_mart`.rgs_ga_channel_mth_govt 
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

--TRI

     DELETE FROM `data-bi-prd-935c.bi_dev`.ioh_snd_master_kpi_detail
    WHERE kpi in ('rgu_ga','RGUGA_Trade','RGUGA-FWA','RGUGA-Digital-Modern','RGUGA-Digital-Online','RGUGA-Digital-OLA') AND dt_id = vdt_id
    and time_flag='dly' and brand = '3ID';
    
    -- Daily rgu_ga by site_id (general)
    INSERT INTO `data-bi-prd-935c.bi_dev`.ioh_snd_master_kpi_detail  
    SELECT '3ID' as brand,
    'site_id' level,
    a.site_id level_value,
    COUNT(*) value,
    'dly' time_flag,
    timestamp(current_datetime('+7')) insert_date,
    'rgu_ga' kpi,
    load_dt_sk_id dt_id 
    FROM `data-bi-prd-935c.bi_mart.snd_rgu_ga_new_detail` a
    WHERE load_dt_sk_id = vdt_id 
    GROUP BY 1,2,3,5,7,8;
    
    -- Daily rgu_ga by outlet (general)
    INSERT INTO `data-bi-prd-935c.bi_dev`.ioh_snd_master_kpi_detail   
    SELECT '3ID' as brand,
    'outlet' level,
    partner_qr_cd level_value,
    COUNT(*) value,
    'dly' time_flag,
    timestamp(current_datetime('+7')) insert_date,
    'rgu_ga' kpi,
    load_dt_sk_id dt_id 
    FROM `data-bi-prd-935c.bi_mart.snd_rgu_ga_new_detail` a
    WHERE load_dt_sk_id = vdt_id  
    GROUP BY 1,2,3,5,7,8;
    
    -- Daily rgu_ga by site_id (with channel breakdown)
    INSERT INTO `data-bi-prd-935c.bi_dev`.ioh_snd_master_kpi_detail  
    SELECT '3ID' as brand,
    'site_id' level,
    a.site_id level_value,
    COUNT(*) value,
    'dly' time_flag,
    timestamp(current_datetime('+7')) insert_date,
    CASE
        WHEN a.call_plan LIKE '%FWA%' THEN 'RGUGA-FWA'
        WHEN channel LIKE 'CIRCLE%' THEN 'RGUGA_Trade'
        WHEN channel = 'DOH POOL' THEN 'RGUGA_Trade'
        WHEN channel IN ('DOH MODERN CHANNEL','DOH TRI OFFICIAL STORE','DOH DVM','DOH THREE STORE') 
            THEN 'RGUGA-Digital-Modern'
        WHEN channel IN ('DOH SAHABAT VIRTUAL') THEN 'RGUGA-Digital-Online'
        WHEN channel IN ('DOH SIM ONLINE') THEN 'RGUGA-Digital-OLA'
        ELSE 'RGUGA_Trade'
    END kpi,
    load_dt_sk_id dt_id 
    FROM `data-bi-prd-935c.bi_mart.snd_rgu_ga_new_detail` a
    WHERE load_dt_sk_id = vdt_id 
    GROUP BY 1,2,3,5,7,8;
    
    -- Daily rgu_ga by outlet (with channel breakdown)
    INSERT INTO `data-bi-prd-935c.bi_dev`.ioh_snd_master_kpi_detail   
    SELECT '3ID' as brand,
    'outlet' level,
    partner_qr_cd level_value,
    COUNT(*) value,
    'dly' time_flag,
    timestamp(current_datetime('+7')) insert_date,
    CASE
        WHEN a.call_plan LIKE '%FWA%' THEN 'RGUGA-FWA'
        WHEN channel LIKE 'CIRCLE%' THEN 'RGUGA_Trade'
        WHEN channel = 'DOH POOL' THEN 'RGUGA_Trade'
        WHEN channel IN ('DOH MODERN CHANNEL','DOH TRI OFFICIAL STORE','DOH DVM','DOH THREE STORE') 
            THEN 'RGUGA-Digital-Modern'
        WHEN channel IN ('DOH SAHABAT VIRTUAL') THEN 'RGUGA-Digital-Online'
        WHEN channel IN ('DOH SIM ONLINE') THEN 'RGUGA-Digital-OLA'
        ELSE 'RGUGA_Trade'
    END kpi,
    load_dt_sk_id dt_id 
    FROM `data-bi-prd-935c.bi_mart.snd_rgu_ga_new_detail` a
    WHERE load_dt_sk_id = vdt_id  
    GROUP BY 1,2,3,5,7,8;  

    -- Delete existing RGU GA data for the specified date
    DELETE FROM `data-bi-prd-935c.bi_dev`.ioh_snd_master_kpi_detail
    WHERE kpi in ('rgu_ga','RGUGA_Trade','RGUGA-FWA','RGUGA-Digital-Modern','RGUGA-Digital-Online','RGUGA-Digital-OLA') AND dt_id = vdt_id
    and time_flag='mtd' and brand='3ID';


   
    -- MTD rgu_ga by site_id (general)
    INSERT INTO `data-bi-prd-935c.bi_dev`.ioh_snd_master_kpi_detail  
    SELECT '3ID' as brand,
    'site_id' level,
    a.site_id level_value,
    COUNT(*) value,
    'mtd' time_flag,
    timestamp(current_datetime('+7')) insert_date,
    'rgu_ga' kpi,
    vdt_id dt_id 
    FROM `data-bi-prd-935c.bi_mart.snd_rgu_ga_new_detail` a
    WHERE load_dt_sk_id between date_trunc(vdt_id,month) and vdt_id
    GROUP BY 1,2,3,5,7,8;
    
    -- MTD rgu_ga by outlet (general)
    INSERT INTO `data-bi-prd-935c.bi_dev`.ioh_snd_master_kpi_detail   
    SELECT '3ID' as brand,
    'outlet' level,
    partner_qr_cd level_value,
    COUNT(*) value,
    'mtd' time_flag,
    timestamp(current_datetime('+7')) insert_date,
    'rgu_ga' kpi,
    vdt_id dt_id 
    FROM `data-bi-prd-935c.bi_mart.snd_rgu_ga_new_detail` a
    WHERE load_dt_sk_id between date_trunc(vdt_id,month) and vdt_id
    GROUP BY 1,2,3,5,7,8;
    
    -- MTD rgu_ga by site_id (with channel breakdown)
    INSERT INTO `data-bi-prd-935c.bi_dev`.ioh_snd_master_kpi_detail  
    SELECT '3ID' as brand,
    'site_id' level,
    a.site_id level_value,
    COUNT(*) value,
    'mtd' time_flag,
    timestamp(current_datetime('+7')) insert_date,
    CASE
        WHEN a.call_plan LIKE '%FWA%' THEN 'RGUGA-FWA'
        WHEN channel LIKE 'CIRCLE%' THEN 'RGUGA_Trade'
        WHEN channel = 'DOH POOL' THEN 'RGUGA_Trade'
        WHEN channel IN ('DOH MODERN CHANNEL','DOH TRI OFFICIAL STORE','DOH DVM','DOH THREE STORE') 
            THEN 'RGUGA-Digital-Modern'
        WHEN channel IN ('DOH SAHABAT VIRTUAL') THEN 'RGUGA-Digital-Online'
        WHEN channel IN ('DOH SIM ONLINE') THEN 'RGUGA-Digital-OLA'
        ELSE 'RGUGA_Trade'
    END kpi,
    vdt_id dt_id 
    FROM `data-bi-prd-935c.bi_mart.snd_rgu_ga_new_detail` a
    WHERE load_dt_sk_id between date_trunc(vdt_id,month) and vdt_id
    GROUP BY 1,2,3,5,7,8;
    
    -- MTD rgu_ga by outlet (with channel breakdown)
    INSERT INTO `data-bi-prd-935c.bi_dev`.ioh_snd_master_kpi_detail   
    SELECT '3ID' as brand,
    'outlet' level,
    partner_qr_cd level_value,
    COUNT(*) value,
    'mtd' time_flag,
    timestamp(current_datetime('+7')) insert_date,
    CASE
        WHEN a.call_plan LIKE '%FWA%' THEN 'RGUGA-FWA'
        WHEN channel LIKE 'CIRCLE%' THEN 'RGUGA_Trade'
        WHEN channel = 'DOH POOL' THEN 'RGUGA_Trade'
        WHEN channel IN ('DOH MODERN CHANNEL','DOH TRI OFFICIAL STORE','DOH DVM','DOH THREE STORE') 
            THEN 'RGUGA-Digital-Modern'
        WHEN channel IN ('DOH SAHABAT VIRTUAL') THEN 'RGUGA-Digital-Online'
        WHEN channel IN ('DOH SIM ONLINE') THEN 'RGUGA-Digital-OLA'
        ELSE 'RGUGA_Trade'
    END kpi,
    vdt_id dt_id 
    FROM `data-bi-prd-935c.bi_mart.snd_rgu_ga_new_detail` a
    WHERE load_dt_sk_id between date_trunc(vdt_id,month) and vdt_id
    GROUP BY 1,2,3,5,7,8;