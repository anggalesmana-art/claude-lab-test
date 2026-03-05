declare vdt_id date default @vdt_id;
--- VLR SUBS  IM3

delete from `data-bi-prd-935c.bi_dev`.ioh_snd_master_kpi_detail where kpi = 'vlr_subs' and dt_id between date_trunc(vdt_id,month) and vdt_id  and brand='IM3';
insert into `data-bi-prd-935c.bi_dev`.ioh_snd_master_kpi_detail
select 'IM3' brand, 'site' level, site_id as level_value, 
    sum(cast(vlr as numeric)) value, 
    'avg' as time_flag, 
    timestamp(current_datetime('+7')) as insert_date,
    'vlr_subs' as kpi, 
     dt_id
from
    (
    select dt_id, site_id, count(distinct msisdn) vlr -- 46123710
    from `data-bi-prd-935c.bi_mart`.vlr_activity_dly
    where dt_id between date_trunc(vdt_id,month) and vdt_id 
    and subs_flag like 'Prepaid%'
    and dt_id not in ('2024-01-01','2024-01-02','2024-03-03','2025-03-23') -- remove incomplete data
    group by 1,2 
    )a
group by 1,2,3,5,6,7,8
;


--- VLR SUBS by TENUR IM3

delete from `data-bi-prd-935c.bi_dev`.ioh_snd_master_kpi_detail where kpi in(
    'vlr_subs_less_90d',
    'vlr_subs_90d_180d',
    'vlr_subs_more_180d',
    'vlr_subs_wo_act',
    'vlr_subs_act'
) and dt_id between date_trunc(vdt_id,month) and vdt_id and brand='IM3';
insert into `data-bi-prd-935c.bi_dev`.ioh_snd_master_kpi_detail
with tmp as (
        select * 
        , date_diff(dt_id,coalesce(first_rgu,actvn_dt),day) as tnr
        , case
            when usg_flag='SI' then 'MO+MT'
            when usg_flag='S' then 'MO Only'
            when usg_flag='I' then 'MT Only'
            else 'No Activity'
        end flag
        from `data-bi-prd-935c.bi_mart`.vlr_activity_dly
        where dt_id between date_trunc(vdt_id,month) and vdt_id
        and subs_flag like 'Prepaid%'
        and dt_id not in ('2024-01-01','2024-01-02','2024-03-03','2025-03-23') -- remove incomplete data
            )
-- vlr with tenure
select 'IM3' brand, 'site' level, site_id as level_value, 
    cast(count(distinct msisdn) as numeric) value, 
    'avg' as time_flag, 
    timestamp(current_datetime('+7')) as insert_date,
     case
        when tnr<=90 then 'vlr_subs_less_90d'
        when tnr<=180 then 'vlr_subs_90d_180d'
        else 'vlr_subs_more_180d'
     end as kpi, 
    -- 'vlr_subs' as kpi, 
     dt_id
from tmp a
group by 1,2,3,5,6,7,8
union all 
-- vlr with activity
select 'IM3' brand, 'site' level, site_id as level_value, 
    cast(count(distinct msisdn) as numeric) value, 
    'avg' as time_flag, 
    timestamp(current_datetime('+7')) as insert_date,
     case
        when flag='No Activity' then 'vlr_subs_wo_act'
        else 'vlr_subs_act'
     end as kpi, 
    -- 'vlr_subs' as kpi, 
     dt_id
from tmp a
group by 1,2,3,5,6,7,8
;



--------  Data UU Daily (with tenure) ---- 

delete from `data-bi-prd-935c.bi_dev`.ioh_snd_master_kpi_detail where kpi in(
    'data_uu',
    'data_uu_less_90d',
    'data_uu_90d_180d',
    'data_uu_more_180d'
) and dt_id between date_trunc(vdt_id,month) and vdt_id and brand='IM3';
insert into `data-bi-prd-935c.bi_dev`.ioh_snd_master_kpi_detail
with data_uu as (
            select a.*, 
            case when DATE_DIFF(
                       a.dt_id_new,a.first_dt,day
                    ) <= 90 then 'data_uu_less_90d'
            when		
            DATE_DIFF(
                       a.dt_id_new,a.first_dt,day
                    ) <= 180 then 'data_uu_90d_180d'
            when 
            DATE_DIFF(
                       a.dt_id_new,a.first_dt,day
                    ) > 181 then 'data_uu_more_180d'
            else 'data_uu_more_180d' end as kpi
            from
            (
             select distinct 'IM3' as brand,
             a.dt_id as mth, 
             a.dt_id as dt_id_new,
             c.first_rgu as first_dt,
             a.msisdn,
             a.site_id
             from
             (
              select a.dt_id, a.msisdn, b.site_id, sum(vol_2g + vol_3g + vol_4g)/(1024*1024) as usage_mb
                from `data-bi-prd-935c.bi_mart`.ggsn_rg_dly a
                    left outer join `data-dtp-prd-aa1a.sor`.subs_fav_loc_dly_carry_fwd b 
                on a.msisdn = b.msisdn and a.dt_id = date(b.dt_id) 
                    and date(b.dt_id) = vdt_id
              where a.dt_id = vdt_id
              and rating_group not in ('23111', '55003', '70091')
              and subs_flag like 'Prepaid%'
              and substring(a.msisdn,1,5) in ('62814','62815','62816','62855','62856','62857','62858')
              group by 1,2,3
             ) a
             left outer join `data-bi-prd-935c.bi_mart`.first_rgs_govt c ON a.msisdn = c.msisdn and date_trunc(a.dt_id,month) = c.mth_id 
             AND c.mth_id = date_trunc(vdt_id,month)
            ) a
        )
-- data uu daily with tenur
select 'IM3' as brand, 
    'site' as level, 
    site_id as level_value, 
    cast(count(distinct msisdn) as numeric) value,  -- gross 
    'avg' as time_flag, 
   timestamp(current_datetime('+7')) as insert_date,
    kpi,
    vdt_id as dt_id
from data_uu
group by 1,2,3,5,6,7,8
union all 
-- data uu daily
select 'IM3' as brand, 
    'site' as level, 
    site_id as level_value, 
    cast(count(distinct msisdn) as numeric) value,  -- gross 
    'avg' as time_flag, 
   timestamp(current_datetime('+7')) as insert_date,
    'data_uu' as kpi,
    vdt_id as dt_id
from data_uu
group by 1,2,3,5,6,7,8
;



---------------- Data UU 30 daily (with tenure) ---------------- 

--Step I

create or replace table `data-bi-prd-935c.bi_stg`.tmp_datauu_30_siteid  as
select a.msisdn, b.site_id, sum(vol_2g + vol_3g + vol_4g)/(1024*1024) as usage_mb, vdt_id as mth
from `data-bi-prd-935c.bi_mart`.ggsn_rg_dly a
left outer join `data-bi-prd-935c.bi_mart`.favloc_30d_dly b on a.msisdn = b.msisdn and b.dt_id in (vdt_id)
where (a.dt_id between vdt_id - interval 29 day and vdt_id)
and rating_group not in ('23111', '55003', '70091')
and subs_flag like 'Prepaid%'
and substring(a.msisdn,1,5) in ('62814','62815','62816','62855','62856','62857','62858')
group by 1,2,4
;


--Step II


create or replace table `data-bi-prd-935c.bi_stg`.tmp_datauu_30_siteid_b  as
select a.*,
coalesce(c.first_rgu, date(d.actvn_dt)) first_usg_dt,
vdt_id as dt_id
from `data-bi-prd-935c.bi_stg`.tmp_datauu_30_siteid a
left join `data-bi-prd-935c.bi_mart`.first_rgs_govt c on a.msisdn = c.msisdn and c.mth_id = date_trunc(vdt_id,month)
left join `data-dtp-prd-aa1a.smy`.ar_cst_dly_smy d on a.msisdn = d.msisdn and date(d.dt_id) = vdt_id
where a.mth = vdt_id
;


delete from `data-bi-prd-935c.bi_dev`.ioh_snd_master_kpi_detail where dt_id = vdt_id and kpi in (
    'data_uu30_less_90d',
    'data_uu30_90d_180d',
    'data_uu30_more_180d',
    'data_uu_30d' ) and brand='IM3';

insert into `data-bi-prd-935c.bi_dev`.ioh_snd_master_kpi_detail
with datauu_30 as (
                select a.*, 
                case when DATE_DIFF(dt_id, first_usg_dt,day) <= 90 then 'data_uu30_less_90d' 
                     when DATE_DIFF(dt_id, first_usg_dt,day) <= 180 then 'data_uu30_90d_180d'
                     when DATE_DIFF(dt_id, first_usg_dt,day) <= 90 then 'data_uu30_more_180d'
                else 'data_uu30_more_180d' end as kpi
                from `data-bi-prd-935c.bi_stg`.tmp_datauu_30_siteid_b a
                where mth = vdt_id
                )
-- data uu 30 with tenur
select 'IM3' as brand, 
    'site' as level, 
    site_id as level_value, 
    cast(count(distinct msisdn) as numeric) value,  -- gross 
    'mtd' as time_flag, 
   timestamp(current_datetime('+7')) as insert_date,
    kpi,
    vdt_id as dt_id
from datauu_30
group by 1,2,3,5,6,7,8
union all 
-- data uu 30 
select 'IM3' as brand, 
    'site' as level, 
    site_id as level_value, 
    cast(count(distinct msisdn) as numeric) value,  -- gross 
    'mtd' as time_flag, 
   timestamp(current_datetime('+7')) as insert_date,
    'data_uu_30d' as kpi,
    vdt_id as dt_id
from datauu_30
group by 1,2,3,5,6,7,8
;


------ RGU30 ------------
delete from `data-bi-prd-935c.bi_dev`.ioh_snd_master_kpi_detail where dt_id = vdt_id and kpi in 
    (
        'pre_rgu_30d_less_90d',
        'pre_rgu_30d_90d_180d',
        'pre_rgu_30d_more_180d',
        'pre_rgu_30d' 
    ) and brand='IM3';

insert into `data-bi-prd-935c.bi_dev`.ioh_snd_master_kpi_detail 
with rgu_30_slab as (
            select a.*, site_id,
                case when
                DATE_DIFF(
                            rgu90_dt,
                            first_dt,day)<= 90 then 'pre_rgu_30d_less_90d'
                when
                DATE_DIFF(
                            rgu90_dt,
                            first_dt,day)<= 180 then 'pre_rgu_30d_90d_180d'
                when
                DATE_DIFF(
                            rgu90_dt,
                            first_dt,day) > 180 then 'pre_rgu_30d_more_180d'
                else 'pre_rgu_30d_more_180d' end as kpi
        from
            ( 
             select distinct dt_id as mth, msisdn,
             dt_id as rgu90_dt, 
             first_rgu as first_dt
             from `data-bi-prd-935c.bi_mart`.fact_rgu_90d_MTD a
             --from `data-bi-prd-935c.bi_mart`.rgu_90d_imei_nik a
             where a.dt_id = vdt_id
            ) a
        join
            (
             select distinct dt_id as mth, msisdn, site_id_30 as site_id
             from `data-bi-prd-935c.bi_mart`.rgs_all_nogovt_dly a
             where a.dt_id = vdt_id
             and flag LIKE '%K%'
            ) b on a.msisdn = b.msisdn and a.mth = b.mth
        )
-- RGU 30 TENUR
select 'IM3' as brand, 
        'site' as level, 
        site_id as level_value, 
        cast(count(distinct msisdn) as numeric) value,  -- gross 
        'mtd' as time_flag, 
       timestamp(current_datetime('+7')) as insert_date,
        kpi,
        vdt_id as dt_id
from rgu_30_slab
where mth = vdt_id
group by 1,2,3,5,6,7,8
union all 
-- RGU 30
select 'IM3' as brand, 
        'site' as level, 
        site_id as level_value, 
        cast(count(distinct msisdn) as numeric) value,  -- gross 
        'mtd' as time_flag, 
       timestamp(current_datetime('+7')) as insert_date,
        'pre_rgu_30d' as kpi,
        vdt_id as dt_id
from rgu_30_slab
where mth = vdt_id
group by 1,2,3,5,6,7,8
;


------------ Data Traffic ------------------
delete from `data-bi-prd-935c.bi_dev`.ioh_snd_master_kpi_detail where dt_id between date_trunc(vdt_id,month) and vdt_id and kpi ='data_traffic' and brand='IM3';

insert into `data-bi-prd-935c.bi_dev`.ioh_snd_master_kpi_detail 
with data_usg as ( 
             select date(dt_id) dt_id, site_id, sum( ifnull(cast(ggsn_data_volume as numeric),0)) / (1024*1024*1024) usg_data_gb
             from `data-dtp-prd-aa1a.smy`.revenue_per_site_extended
             where date(dt_id) between date_trunc(vdt_id,month) and vdt_id
             group by 1,2
                )
--USAGE TRAFFIC DATA GB
select 'IM3' as brand, 
        'site' as level, 
        site_id as level_value, 
        cast(sum(usg_data_gb) as numeric) value,  -- gross 
        'dly' as time_flag, 
       timestamp(current_datetime('+7')) as insert_date,
        'data_traffic' as kpi,
        dt_id
from data_usg
where usg_data_gb!=0
group by 1,2,3,5,6,7,8
;


---------- Subscribers on a Data Pack ----------------

create or replace table `data-bi-prd-935c.bi_stg`.tmp_data_pack_subs  as
select  subscriber as msisdn, vdt_id as dt_id
from `data-bi-prd-935c.bi_mart`.usage_data_revcode_cs5_new
where daydate between date_trunc(vdt_id,month) and vdt_id
    -- substr(daydate,1,6) = substr('20250601',1,6) and daydate <= '20250601'
and data_vol_traffic = 'Billable Promo'
and level_7 = 'DATA'
and datavol > 0
;

delete from `data-bi-prd-935c.bi_dev`.ioh_snd_master_kpi_detail where dt_id = vdt_id and kpi = 'subs_data_pack' and brand = 'IM3';
insert into `data-bi-prd-935c.bi_dev`.ioh_snd_master_kpi_detail 
select 'IM3' as brand, 
        'site' as level, 
        fav.site_id as level_value, 
        cast(count(distinct a.msisdn) as numeric) value,  -- gross 
        'mtd' as time_flag, 
       timestamp(current_datetime('+7')) as insert_date,
        'subs_data_pack' as kpi,
        vdt_id as dt_id
from `data-bi-prd-935c.bi_stg`.tmp_data_pack_subs a
left outer join `data-bi-prd-935c.bi_mart`.favloc_30d_dly fav 
    on a.msisdn = fav.msisdn and date_trunc(a.dt_id,month) = date_trunc(fav.dt_id,month) 
        and fav.dt_id in (vdt_id)
where a.dt_id = vdt_id
group by 1,2,3,5,6,7,8
;

-- PRE RGU 30D ARPU
delete from `data-bi-prd-935c.bi_dev.ioh_snd_master_kpi_detail` where dt_id = vdt_id and brand = 'IM3' and kpi = 'pre_rgu_30d_arpu';
insert into `data-bi-prd-935c.bi_dev.ioh_snd_master_kpi_detail`
WITH month_1 AS (
    SELECT date(date_trunc(vdt_id,month) - interval 1 day) AS dt_id
                ),
pre_rgu_m1 as (
    select dt_id, kpi, a.level_value, sum(a.values) value
    from `data-bi-prd-935c.bi_dev.ioh_snd_master_kpi_detail` a
        where kpi in ('pre_rgu_90d','pre_rgu_30d') and brand = 'IM3'
            and dt_id = (select dt_id from month_1 b)
    group by 1,2,3
    ),
pre_rgu as (
    select dt_id, kpi, a.level_value, sum(a.values) value
    from `data-bi-prd-935c.bi_dev.ioh_snd_master_kpi_detail` a
        where kpi in ('pre_rgu_90d','pre_rgu_30d') and brand = 'IM3'
            and dt_id = vdt_id
    group by 1,2,3
    )
-- pre rgu 30d arpu
select 'IM3' brand, 
    'site' level, 
    level_value, 
    cast(sum((value_m0+value_m1)/flag_value) as numeric) value,
     'mtd' as time_flag, 
     timestamp(current_datetime('+7')) as insert_date,
    'pre_rgu_30d_arpu' as kpi, 
    vdt_id as dt_id
from 
(
select a.dt_id, a.kpi, a.level_value, coalesce(a.value,0) value_m0, coalesce(b.value,0) value_m1, 
case when a.value is null or b.value is null then 1 else 2 end flag_value
    from pre_rgu a
left join (select * from pre_rgu_m1 where kpi = 'pre_rgu_30d')  b 
    on a.level_value =b.level_value
where a.kpi = 'pre_rgu_30d'
)a 
group by 1,2,3,5,6,7,8
;



--- Insert to table Summary yg MTD 

delete from `data-bi-prd-935c.bi_dev`.ioh_snd_master_kpi_detail_smy where kpi in (
    'data_uu_30d', 'data_uu30_less_90d', 'data_uu30_90d_180d', 'data_uu30_more_180d',
        -- 'data_uu_less_90d','data_uu_90d_180d', 'data_uu_more_180d',
         'pre_rgu_30d','pre_rgu_30d_less_90d','pre_rgu_30d_90d_180d','pre_rgu_30d_more_180d',
         'data_pack_hits','data_pack_hits_sachet','data_pack_hits_monthly','data_pack_rev','data_pack_rev_sachet','data_pack_rev_monthly',
         'subs_data_pack'
) and dt_id = vdt_id and brand='IM3';
insert into `data-bi-prd-935c.bi_dev`.ioh_snd_master_kpi_detail_smy 
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
        ('data_uu_30d', 'data_uu30_less_90d', 'data_uu30_90d_180d', 'data_uu30_more_180d',
        -- 'data_uu_less_90d','data_uu_90d_180d', 'data_uu_more_180d',
         'pre_rgu_30d','pre_rgu_30d_less_90d','pre_rgu_30d_90d_180d','pre_rgu_30d_more_180d',
         'data_pack_hits','data_pack_hits_sachet','data_pack_hits_monthly','data_pack_rev','data_pack_rev_sachet','data_pack_rev_monthly',
         'subs_data_pack'
        )
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

--- Insert to table Summary yg DLY jadiin ke MTD 

-- create table `data-bi-prd-935c.bi_dev`.ioh_snd_master_kpi_detail_smy partitioned by (kpi,dt_id) stored as parquet as
delete from `data-bi-prd-935c.bi_dev`.ioh_snd_master_kpi_detail_smy where kpi in ( 'data_traffic','data_uu', 'data_uu_less_90d', 'data_uu_90d_180d', 'data_uu_more_180d') and dt_id between date_trunc(vdt_id,month) and vdt_id and brand='IM3';

insert into `data-bi-prd-935c.bi_dev`.ioh_snd_master_kpi_detail_smy
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
        ( 'data_traffic','data_uu', 'data_uu_less_90d', 'data_uu_90d_180d', 'data_uu_more_180d') and brand = 'IM3'
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

--- Insert to table Summary yg AVG di hitung AVG

-- create table `data-bi-prd-935c.bi_dev`.ioh_snd_master_kpi_detail_smy partitioned by (kpi,dt_id) stored as parquet as
delete from `data-bi-prd-935c.bi_dev`.ioh_snd_master_kpi_detail_smy where kpi in ( 
            'vlr_subs', 'vlr_subs_less_90d', 'vlr_subs_90d_180d', 'vlr_subs_more_180d', 'vlr_subs_wo_act', 'vlr_subs_act'
        ) and dt_id between date_trunc(vdt_id,month) and vdt_id and brand='IM3';
insert into `data-bi-prd-935c.bi_dev`.ioh_snd_master_kpi_detail_smy
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
        ( 
            'vlr_subs', 'vlr_subs_less_90d', 'vlr_subs_90d_180d', 'vlr_subs_more_180d', 'vlr_subs_wo_act', 'vlr_subs_act'
        ) and brand = 'IM3'
            )
select  a.brand, b.circle, b.region_circle as region, b.area, b.sales_area branch,b.micro_cluster cluster,
    --   coalesce(b.circle,c.circle) as circle,
    --   coalesce(b.region_circle,c.region_circle) as region,
    --   coalesce(b.area,c.area) as area,
    --   coalesce(b.sales_area,c.sales_area) as branch,
    --   coalesce(b.micro_cluster,c.micro_cluster) as cluster,
        cast(sum(values) as numeric) value,
        a.kpi,
        vdt_id  as dt_id
    from tracker a 
        left join ref_dealer b
    on a.level_value=b.id 
   --     left join ref_dealer_rn c
   -- on a.level_value=c.id 
group by 1,2,3,4,5,6,8,9
;


drop table `data-bi-prd-935c.bi_stg`.tmp_datauu_30_siteid_b;
drop table `data-bi-prd-935c.bi_stg`.tmp_data_pack_subs;
drop table `data-bi-prd-935c.bi_stg`.tmp_datauu_30_siteid;


