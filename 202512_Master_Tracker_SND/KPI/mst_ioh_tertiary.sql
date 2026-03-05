declare vdt_id date default @vdt_id;

--IM3
---------------- tertiary_trad ----------------
delete `data-bi-prd-935c.bi_dev`.ioh_snd_master_kpi_detail where dt_id = vdt_id and brand = 'IM3' and kpi = 'tertiary_trad';
insert into `data-bi-prd-935c.bi_dev`.ioh_snd_master_kpi_detail 
select 'IM3' brand, 'site' level, id as level_value, 
    sum(cast(value as numeric)) value, 
    'mtd' as time_flag, 
     timestamp(current_datetime('+7')) as insert_date,
    'tertiary_trad' as kpi, 
    vdt_id as dt_id
from
(
select -- coalesce(site_bnum,site_outlet) id , 
    site_bnum as id,
    sum(amount_debit) value 
    from `data-bi-prd-935c.bi_mart`.fact_snd_tertiary_dtl
    where dt_id between date_trunc(vdt_id,month) and vdt_id 
    and channel_grp in ('Traditional')
group by 1
)a
group by 1,2,3,5,6,7,8
;


---------------- tertiary_trad_dly ----------------
delete `data-bi-prd-935c.bi_dev`.ioh_snd_master_kpi_detail where dt_id between date_trunc(vdt_id,month) and vdt_id  and brand = 'IM3' and kpi = 'tertiary_trad_dly';
insert into `data-bi-prd-935c.bi_dev`.ioh_snd_master_kpi_detail 
select 'IM3' brand, 'site' level, id as level_value, 
    sum(cast(value as numeric)) value, 
    'dly' as time_flag, 
     timestamp(current_datetime('+7')) as insert_date,
    'tertiary_trad_dly' as kpi, 
    dt_id
from
(
select dt_id, -- coalesce(site_bnum,site_outlet) id , 
    site_bnum as id,
    sum(amount_debit) value 
    from `data-bi-prd-935c.bi_mart`.fact_snd_tertiary_dtl
    where dt_id between date_trunc(vdt_id,month) and vdt_id 
    and channel_grp in ('Traditional')
group by 1,2
)a
group by 1,2,3,5,6,7,8
;



---------------- tertiary_trad_outlet_dly ----------------
delete `data-bi-prd-935c.bi_dev`.ioh_snd_master_kpi_detail where dt_id between date_trunc(vdt_id,month) and vdt_id  and brand = 'IM3' and kpi = 'tertiary_trad_outlet_dly';
insert into `data-bi-prd-935c.bi_dev`.ioh_snd_master_kpi_detail 
select 'IM3' brand, 'outlet' level, id as level_value, 
    sum(cast(value as numeric)) value, 
    'dly' as time_flag, 
     timestamp(current_datetime('+7')) as insert_date,
    'tertiary_trad_outlet_dly' as kpi, 
    dt_id
from
(
select dt_id, organization_id id , sum(amount_debit) value 
    from `data-bi-prd-935c.bi_mart`.fact_snd_tertiary_dtl
    where dt_id between date_trunc(vdt_id,month) and vdt_id 
    and channel_grp in ('Traditional')
group by 1,2
)a
group by 1,2,3,5,6,7,8
;


---------------- tertiary_non_trad ----------------
delete `data-bi-prd-935c.bi_dev`.ioh_snd_master_kpi_detail where dt_id = vdt_id and brand = 'IM3' and kpi = 'tertiary_nontrad';
insert into `data-bi-prd-935c.bi_dev`.ioh_snd_master_kpi_detail 
select 'IM3' brand, 'site' level, id as level_value, 
    sum(cast(value as numeric)) value, 
    'mtd' as time_flag, 
     timestamp(current_datetime('+7')) as insert_date,
    'tertiary_nontrad' as kpi, 
    vdt_id as dt_id
from
(
select -- coalesce(site_bnum,site_outlet) id , 
    site_bnum as id,
    sum(amount_debit) value 
    from `data-bi-prd-935c.bi_mart`.fact_snd_tertiary_dtl
    where dt_id between date_trunc(vdt_id,month) and vdt_id 
    and channel_grp in ('Non Traditional')
group by 1
)a
group by 1,2,3,5,6,7,8
;


----- TERTIARY B# INNER & OUTER ----  CATEGORY
delete `data-bi-prd-935c.bi_dev`.ioh_snd_master_kpi_detail where dt_id = vdt_id and brand = 'IM3' and kpi in (
'tertiary_b_outer_reload',
'tertiary_b_inner_vouredeem',
'tertiary_b_outer_datapack',
'tertiary_b_inner',
'tertiary_b_inner_datapack',
'tertiary_b_outer',
'tertiary_b_outer_vouredeem',
'tertiary_b_inner_sp_usg',
'tertiary_b_outer_sp_usg',
'tertiary_b_inner_reload'
);
insert into `data-bi-prd-935c.bi_dev`.ioh_snd_master_kpi_detail 
with tertiary as (
            select site_outlet, site_bnum, tertiary_type,
            sum(amount_debit) amount
            from `data-bi-prd-935c.bi_mart`.fact_snd_tertiary_dtl
            where dt_id between date_trunc(vdt_id,month) and vdt_id 
                and channel_grp in ('Traditional')
            group by 1,2,3
            ),
ref_site_outlet as (
        select distinct site_id, circle, region, area, sales_area
        from `data-bi-prd-935c.bi_mart`.ref_site_mth
        where month_id = date_trunc(vdt_id,month) 
            ),
ref_site_bnum as (
        select distinct site_id, circle, region, area, sales_area
        from `data-bi-prd-935c.bi_mart`.ref_site_mth
        where month_id = date_trunc(vdt_id,month) 
            ),
final as (
    select c.site_id, 
         case
            when b.sales_area = c.sales_area then -- 'Tertiary B# Inner'
                case
                    when tertiary_type in ('RELOAD') then 'tertiary_b_inner_reload'
                    when tertiary_type in ('SP MOBO Y3','SP MOBO Y4') then 'tertiary_b_inner_datapack'
                    when tertiary_type in ('SP DATA','SP DATA ALLOC','SP MOBO Y2','SP ZERO') then 'tertiary_b_inner_sp_usg'
                    when tertiary_type in ('VOU ORI','VOU ORI ALLOC','VOU REDEEM','VOU RLD') then 'tertiary_b_inner_vouredeem'
                end
            when b.sales_area is null then --'Tertiary B# Inner'
                case
                    when tertiary_type in ('RELOAD') then 'tertiary_b_inner_reload'
                    when tertiary_type in ('SP MOBO Y3','SP MOBO Y4') then 'tertiary_b_inner_datapack'
                    when tertiary_type in ('SP DATA','SP DATA ALLOC','SP MOBO Y2','SP ZERO') then 'tertiary_b_inner_sp_usg'
                    when tertiary_type in ('VOU ORI','VOU ORI ALLOC','VOU REDEEM','VOU RLD') then 'tertiary_b_inner_vouredeem'
                end
            else --'Tertiary B# Outer'
                case
                    when tertiary_type in ('RELOAD') then 'tertiary_b_outer_reload'
                    when tertiary_type in ('SP MOBO Y3','SP MOBO Y4') then 'tertiary_b_outer_datapack'
                    when tertiary_type in ('SP DATA','SP DATA ALLOC','SP MOBO Y2','SP ZERO') then 'tertiary_b_outer_sp_usg'
                    when tertiary_type in ('VOU ORI','VOU ORI ALLOC','VOU REDEEM','VOU RLD') then 'tertiary_b_outer_vouredeem'
                end
         end parameter_category,
         case
            when b.sales_area = c.sales_area then 'tertiary_b_inner'
            when b.sales_area is null then 'tertiary_b_inner'
            else 'tertiary_b_outer'
        end parameter,
        sum(amount) amount
    from tertiary a  
    left join ref_site_outlet b
            on a.site_outlet=b.site_id
    left join ref_site_bnum c
            on a.site_bnum=c.site_id
    group by 1,2,3
    )
-- trade demand inner & outer
select 'IM3' brand, 'site' level, site_id as level_value, 
    sum(cast(amount as numeric)) value, 
    'mtd' as time_flag, 
     timestamp(current_datetime('+7')) as insert_date,
     parameter as kpi, 
    vdt_id dt_id
from final
group by 1,2,3,5,6,7,8
union all 
-- trade demand inner & outer tertiary type
select 'IM3' brand, 'site' level, site_id as level_value, 
    sum(cast(amount as numeric)) value, 
    'mtd' as time_flag, 
     timestamp(current_datetime('+7')) as insert_date,
     parameter_category as kpi, 
    vdt_id dt_id
from final
group by 1,2,3,5,6,7,8
;


--------------------------------------
-------- TERTIARY B# DETAIL ----------
--------------------------------------
delete `data-bi-prd-935c.bi_dev`.ioh_snd_master_kpi_detail where dt_id = vdt_id and brand = 'IM3' and kpi in(
'tertiary_b_reload',
'tertiary_b_spmobo',
'tertiary_b_redeem',
'tertiary_b_vouori',
'tertiary_b_spdata',
'tertiary_b_spzero'
);
insert into `data-bi-prd-935c.bi_dev`.ioh_snd_master_kpi_detail 
with tertiary as (
    select 
        a.site_bnum,
        'SITE' flag,
        -- sum(amount_debit)/1.11 amount, 
        sum(amount_debit) amount, 
        (case
            when date_trunc(a.dt_id,month) = date_trunc(vdt_id,month) then 'mtd'
            when date_trunc(a.dt_id,month) = date_trunc(vdt_id - interval 1 month,month) then 'lmtd'
            when date_trunc(a.dt_id,month) = date_trunc(vdt_id - interval 2 month,month) then 'llmtd'
        end) mthf,
        vdt_id as_of_dt,
        date_trunc(vdt_id,month) mth,
        (case
            when a.tertiary_type in ('RELOAD') then 'Tertiary B# Reload'
            when a.tertiary_type like 'SP MOBO%' then 'Tertiary B# SP Mobo'
            when a.tertiary_type in ('VOU REDEEM','VOU RLD') then 'Tertiary B# Redeem'
            when a.tertiary_type in ('VOU ORI','VOU ORI ALLOC') then 'Tertiary B# Vou Ori'
            when a.tertiary_type in ('SP DATA','SP DATA ALLOC') then 'Tertiary B# SP Data'
            when a.tertiary_type in ('SP ZERO') then 'Tertiary B# SP ZERO'
        end) parameter
    from `data-bi-prd-935c.bi_mart`.fact_snd_tertiary_dtl a
    where
        ((date_trunc(a.dt_id,month) = date_trunc(vdt_id,month) and a.dt_id <= vdt_id)  
            or (date_trunc(a.dt_id,month) = date_trunc(vdt_id - interval 1 month,month) and a.dt_id <= date_trunc(vdt_id - interval 1 month,month))
            or (date_trunc(a.dt_id,month) = date_trunc(vdt_id - interval 2 month,month) and a.dt_id <= date_trunc(vdt_id - interval 2 month,month))
            )
        and a.channel_grp in ('Traditional')
    group by 1,2,4,5,6,7
    )
------ 
select 
     'IM3' brand, 'site' level, site_bnum as level_value, 
    cast(sum(amount) as numeric) value,
    'mtd' as time_flag,
    timestamp(current_datetime('+7')) as insert_date,
    (case
        when parameter = 'Tertiary B# Reload' then 'tertiary_b_reload'
        when parameter = 'Tertiary B# SP Mobo' then 'tertiary_b_spmobo'
        when parameter = 'Tertiary B# Redeem' then 'tertiary_b_redeem'
        when parameter = 'Tertiary B# Vou Ori' then 'tertiary_b_vouori'
        when parameter = 'Tertiary B# SP Data' then 'tertiary_b_spdata'
        when parameter = 'Tertiary B# SP ZERO' then 'tertiary_b_spzero'
    end) as kpi,
    vdt_id as dt_id
from tertiary
where mthf = 'mtd'
group by 1,2,3,5,6,7,8
;

--------------------------------------
----- TERTIARY A outlet ----  CATEGORY
--------------------------------------
delete `data-bi-prd-935c.bi_dev`.ioh_snd_master_kpi_detail where dt_id = vdt_id and brand = 'IM3' and kpi in(
'tertiary_outlet');
delete `data-bi-prd-935c.bi_dev`.ioh_snd_master_kpi_detail where dt_id between date_trunc(vdt_id,month) and vdt_id  and brand = 'IM3' and kpi in(
'tertiary_outlet_dly'
);
insert into `data-bi-prd-935c.bi_dev`.ioh_snd_master_kpi_detail 
with tertiary as (
            select dt_id, organization_id, tertiary_type,
            sum(amount_debit) amount
            from `data-bi-prd-935c.bi_mart`.fact_snd_tertiary_dtl
            where dt_id between date_trunc(vdt_id,month) and vdt_id 
                and channel_grp in ('Traditional')
            group by 1,2,3
            )
-- tertiary outlet mtd
select 'IM3' brand, 'outlet' level, organization_id as level_value, 
    sum(cast(amount as numeric)) value, 
    'mtd' as time_flag, 
     timestamp(current_datetime('+7')) as insert_date,
     'tertiary_outlet' as kpi, 
    vdt_id dt_id
from tertiary
group by 1,2,3,5,6,7,8
union all 
-- tertiary outlet mtd
select 'IM3' brand, 'outlet' level, organization_id as level_value, 
    sum(cast(amount as numeric)) value, 
    'dly' as time_flag, 
     timestamp(current_datetime('+7')) as insert_date,
     'tertiary_outlet_dly' as kpi, 
     dt_id
from tertiary
group by 1,2,3,5,6,7,8
;


--------------------------------------
-------- TERTIARY OUTLET DETAIL DLY -----
--------------------------------------
delete `data-bi-prd-935c.bi_dev`.ioh_snd_master_kpi_detail where dt_id between date_trunc(vdt_id,month) and vdt_id  and brand = 'IM3' and kpi in(
'tertiary_sp_dly','tertiary_saldo_dly','tertiary_vou_dly','tertiary_other_dly'
);
insert into `data-bi-prd-935c.bi_dev`.ioh_snd_master_kpi_detail  
select 'IM3' brand, 'outlet' level, a.organization_id as level_value, 
    sum(cast(amount_debit as numeric)) value, 
    'dly' as time_flag, 
     timestamp(current_datetime('+7')) as insert_date,
    (case
        when a.tertiary_type in ('RELOAD','VOU RLD','SP MOBO Y2','SP MOBO Y3') then 'tertiary_saldo_dly'
        when a.tertiary_type not in ('RELOAD','VOU RLD','SP MOBO Y2','SP MOBO Y3','VOU ORI') then 'tertiary_sp_dly'
        when a.tertiary_type in ('VOU ORI') then 'tertiary_vou_dly'
        else 'tertiary_other_dly'
    end) as kpi, 
    dt_id
from
    `data-bi-prd-935c.bi_mart`.fact_snd_tertiary_dtl a
where channel_grp = 'Traditional' and 
    ((date_trunc(a.dt_id,month) = date_trunc(vdt_id,month) and a.dt_id <= vdt_id))
group by 1,2,3,5,6,7,8
;

--3ID
--TERTIARY


    -- ========== TERTIARY TRAD KPI - SITE LEVEL MTD ==========
DELETE FROM `data-bi-prd-935c.bi_dev`.ioh_snd_master_kpi_detail    
WHERE kpi = 'tertiary_trad' AND dt_id =vdt_id AND level = 'site_id' AND time_flag = 'mtd' and brand = '3ID';   
 
INSERT INTO `data-bi-prd-935c.bi_dev`.ioh_snd_master_kpi_detail    
SELECT '3ID',    
'site_id',    
siteid_bnum,    
SUM(COALESCE(a.amount, 0)),    
'mtd',    
timestamp(current_datetime('+7')),    
'tertiary_trad',    
vdt_id     
FROM `data-bi-prd-935c.bi_mart`.project_ioh_tertiary_outlet a        
LEFT JOIN `data-bi-prd-935c.bi_mart`.angie_hrchy_dim_hst b ON b.partner_qr_cd = a.dealer_id AND date_trunc(a.dt_sk_id,month) = b.mth    
WHERE a.dt_sk_id between date_trunc(vdt_id,month)  and vdt_id    
  AND a.tertiary_category IN ('SALDO', 'FRC', 'UNLOCK')     
  AND LENGTH(a.dealer_id) < 10    
  AND UPPER(b.mp3_location) NOT IN (    
          'POOL',     
      'DVM BM',     
      'SIM ONLINE',     
      'BSM TRI OFFICIAL STORE',     
      '3 BUSINESS',     
      '3 STORE',     
      'SOUTH JAKARTA TEST BM'    
  )    
GROUP BY 1,2,3,5,6,7,8;    

-- ========== TERTIARY TRAD KPI - OUTLET LEVEL DAILY ==========    
DELETE FROM `data-bi-prd-935c.bi_dev`.ioh_snd_master_kpi_detail    
WHERE kpi = 'tertiary_trad' AND dt_id =vdt_id AND level = 'outlet' AND time_flag = 'mtd' and brand = '3ID';  

INSERT INTO `data-bi-prd-935c.bi_dev`.ioh_snd_master_kpi_detail    
SELECT '3ID',    
'outlet',    
dealer_id,    
SUM(COALESCE(a.amount, 0)),    
'mtd',    
timestamp(current_datetime('+7')),    
'tertiary_trad',    
vdt_id     
FROM `data-bi-prd-935c.bi_mart`.project_ioh_tertiary_outlet a        
LEFT JOIN `data-bi-prd-935c.bi_mart`.angie_hrchy_dim_hst b ON b.partner_qr_cd = a.dealer_id AND date_trunc(a.dt_sk_id,month) = b.mth    
WHERE a.dt_sk_id between date_trunc(vdt_id,month)  and vdt_id    
  AND a.tertiary_category IN ('SALDO', 'FRC', 'UNLOCK')     
  AND LENGTH(a.dealer_id) < 10    
  AND UPPER(b.mp3_location) NOT IN (    
          'POOL',     
      'DVM BM',     
      'SIM ONLINE',     
      'BSM TRI OFFICIAL STORE',     
      '3 BUSINESS',     
      '3 STORE',     
      'SOUTH JAKARTA TEST BM'    
  )    
GROUP BY 1,2,3,5,6,7,8; 

