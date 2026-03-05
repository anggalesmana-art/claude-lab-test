declare vdt_id date default @vdt_id;


-- insert data subs 90 (semesta) --
delete from `data-bi-prd-935c.bi_mart`.fact_rgu_90d_mtd where dt_id = vdt_id;

insert into `data-bi-prd-935c.bi_mart`.fact_rgu_90d_mtd 
select a.msisdn, a.actvn_dt, 
a.min_dt_90 as dt_min,
a.max_dt as dt_max,
d.first_rgu,
a.rev_30 as tot_rev_m0,
coalesce(b.rev_30,0) as tot_rev_m1,
coalesce(c.rev_30,0) as tot_rev_m2,
a.site_id_90 as site_id,
a.dt_id
from `data-bi-prd-935c.bi_mart`.rgs_all_nogovt_dly a
left outer join `data-bi-prd-935c.bi_mart`.rgs_all_nogovt_dly b on a.msisdn = b.msisdn and b.dt_id IN (vdt_id - interval 30 day) and b.flag LIKE '%K%'
left outer join `data-bi-prd-935c.bi_mart`.rgs_all_nogovt_dly c on a.msisdn = c.msisdn and c.dt_id IN (vdt_id - interval 60 day) and c.flag LIKE '%K%'
left outer join `data-bi-prd-935c.bi_mart`.first_rgs_govt d on a.msisdn = d.msisdn and date_trunc(a.dt_id,month) = d.mth_id and d.mth_id = date_trunc(vdt_id,month)
where a.dt_id = vdt_id
and a.flag LIKE '%A%'
;

---- RGU90 -------------------


delete from `data-bi-prd-935c.bi_dev`.ioh_snd_master_kpi_detail where brand='IM3' and kpi in 
(
  'pre_rgu_90d_less_90d',
  'pre_rgu_90d_90d_180d',
  'pre_rgu_90d_more_180d',
  'pre_rgu_90d'
)
and dt_id = vdt_id;
insert into `data-bi-prd-935c.bi_dev`.ioh_snd_master_kpi_detail
with rgu_90_slab as (
            select a.*,
            case when 
            DATE_DIFF(
                        rgu90_dt,
                        first_dt,day
                    ) <= 90 then 'pre_rgu_90d_less_90d'
            when		
            DATE_DIFF(
                        rgu90_dt,
                        first_dt,day
                    ) <= 180 then 'pre_rgu_90d_90d_180d'
            when 
            DATE_DIFF(
                        rgu90_dt,
                        first_dt,day
                    ) > 181 then 'pre_rgu_90d_more_180d'
            else 'pre_rgu_90d_more_180d' end as AON_slab
            from 
            (
             select dt_id, msisdn, site_id,
             dt_id as rgu90_dt, 
             first_rgu as first_dt
             from `data-bi-prd-935c.bi_mart`.fact_rgu_90d_mtd a
             where dt_id = vdt_id
            ) a
        )
-- RGU90 slab 
select 'IM3' as brand, 
'site' as level, 
site_id as level_value, 
cast(count(distinct msisdn) as numeric) value,  -- gross 
'mtd' as time_flag, 
timestamp(current_datetime('+7')) as insert_date,
AON_slab as kpi,
vdt_id as dt_id
from rgu_90_slab
where dt_id = vdt_id
    and AON_slab in ('pre_rgu_90d_less_90d', 'pre_rgu_90d_90d_180d', 'pre_rgu_90d_more_180d')
group by 1,2,3,5,6,7,8
union all
-- RGU90
select 'IM3' as brand, 
'site' as level, 
site_id as level_value, 
cast(count(distinct msisdn) as numeric) value,  -- gross 
'mtd' as time_flag, 
timestamp(current_datetime('+7')) as insert_date,
'pre_rgu_90d' as kpi,
vdt_id as dt_id
from rgu_90_slab
where dt_id = vdt_id
    and AON_slab in ('pre_rgu_90d_less_90d', 'pre_rgu_90d_90d_180d', 'pre_rgu_90d_more_180d')
group by 1,2,3,5,6,7,8
;


-- RGU90 Last Month M1

delete from `data-bi-prd-935c.bi_dev`.ioh_snd_master_kpi_detail where brand='IM3' and kpi = 'pre_rgu_90d_m1' and dt_id = vdt_id;
insert into `data-bi-prd-935c.bi_dev`.ioh_snd_master_kpi_detail
select 'IM3' as brand, 
'site' as level, 
level_value, 
cast(sum(values) as numeric) value,  -- gross 
'mtd' as time_flag, 
timestamp(current_datetime('+7')) as insert_date,
'pre_rgu_90d_m1' as kpi,
vdt_id as dt_id
FROM `data-bi-prd-935c.bi_dev`.ioh_snd_master_kpi_detail a
WHERE kpi = 'pre_rgu_90d' and brand = 'IM3'
  AND dt_id =  date(date_trunc(vdt_id,month) - interval 1 day)
group by 1,2,3,5,6,7,8;


-- pre_rgu_90d_less_90d_m1 

delete from `data-bi-prd-935c.bi_dev`.ioh_snd_master_kpi_detail where brand='IM3' and kpi= 'pre_rgu_90d_less_90d_m1' and dt_id = vdt_id;
insert into `data-bi-prd-935c.bi_dev`.ioh_snd_master_kpi_detail
select 'IM3' as brand, 
'site' as level, 
level_value, 
cast(sum(values) as numeric) value,  -- gross 
'mtd' as time_flag, 
timestamp(current_datetime('+7')) as insert_date,
'pre_rgu_90d_less_90d_m1' as kpi,
vdt_id as dt_id
FROM `data-bi-prd-935c.bi_dev`.ioh_snd_master_kpi_detail a
WHERE kpi = 'pre_rgu_90d_less_90d' and brand = 'IM3'
  AND dt_id =  date(date_trunc(vdt_id,month) - interval 1 day)
group by 1,2,3,5,6,7,8
      ;

-- pre_rgu_90d_90d_180d_m1

delete from `data-bi-prd-935c.bi_dev`.ioh_snd_master_kpi_detail where brand='IM3' and kpi = 'pre_rgu_90d_90d_180d_m1' and dt_id = vdt_id;
insert into `data-bi-prd-935c.bi_dev`.ioh_snd_master_kpi_detail
select 'IM3' as brand, 
'site' as level, 
level_value, 
cast(sum(values) as numeric) value,  -- gross 
'mtd' as time_flag, 
timestamp(current_datetime('+7')) as insert_date,
'pre_rgu_90d_90d_180d_m1' as kpi,
vdt_id as dt_id
FROM `data-bi-prd-935c.bi_dev`.ioh_snd_master_kpi_detail a
WHERE kpi = 'pre_rgu_90d_90d_180d' and brand = 'IM3'
  AND dt_id =  date(date_trunc(vdt_id,month) - interval 1 day)
group by 1,2,3,5,6,7,8
      ;

--- pre_rgu_90d_more_180d_m1

delete from `data-bi-prd-935c.bi_dev`.ioh_snd_master_kpi_detail where brand='IM3' and kpi = 'pre_rgu_90d_more_180d_m1' and dt_id = vdt_id;
insert into `data-bi-prd-935c.bi_dev`.ioh_snd_master_kpi_detail
select 'IM3' as brand, 
'site' as level, 
level_value, 
cast(sum(values) as numeric) value,  -- gross 
'mtd' as time_flag, 
timestamp(current_datetime('+7')) as insert_date,
'pre_rgu_90d_more_180d_m1' as kpi,
vdt_id as dt_id
FROM `data-bi-prd-935c.bi_dev`.ioh_snd_master_kpi_detail a
WHERE kpi = 'pre_rgu_90d_more_180d' and brand = 'IM3'
  AND dt_id =  date(date_trunc(vdt_id,month) - interval 1 day)
group by 1,2,3,5,6,7,8
      ;


--- NET ADD

delete from `data-bi-prd-935c.bi_dev`.ioh_snd_master_kpi_detail where brand ='IM3' and kpi = 'net_add' and dt_id between date_trunc(vdt_id,month) and vdt_id;
insert into  `data-bi-prd-935c.bi_dev`.ioh_snd_master_kpi_detail
select 'IM3' brand, 'site' level, level_value, 
    cast(sum(case when kpi ='pre_rgu_90d' then values else values*-1 end ) as numeric) value, 
    'dly' as time_flag, 
     timestamp(current_datetime('+7')) as insert_date,
     'net_add' as kpi, 
     dt_id
from  `data-bi-prd-935c.bi_dev`.ioh_snd_master_kpi_detail
where kpi in ('pre_rgu_90d','pre_rgu_90d_m1') and brand = 'IM3'
    and dt_id between date_trunc(vdt_id,month) and vdt_id
group by 1,2,3,5,6,7,8
;


--- NET ADD _90d_180d


delete from `data-bi-prd-935c.bi_dev`.ioh_snd_master_kpi_detail where brand = 'IM3' and kpi= 'net_add_90d_180d' and dt_id between date_trunc(vdt_id,month) and vdt_id;
insert into  `data-bi-prd-935c.bi_dev`.ioh_snd_master_kpi_detail 
select 'IM3' brand, 'site' level, level_value, 
    cast(sum(case when kpi ='pre_rgu_90d_90d_180d' then values else values*-1 end ) as numeric) value, 
    'dly' as time_flag, 
     timestamp(current_datetime('+7')) as insert_date,
     'net_add_90d_180d' as kpi, 
     dt_id
from  `data-bi-prd-935c.bi_dev`.ioh_snd_master_kpi_detail
where kpi in ('pre_rgu_90d_90d_180d','pre_rgu_90d_90d_180d_m1') and brand = 'IM3'
    and dt_id between date_trunc(vdt_id,month) and vdt_id
group by 1,2,3,5,6,7,8
;


--- NET ADD _more_180d


delete from `data-bi-prd-935c.bi_dev`.ioh_snd_master_kpi_detail where brand = 'IM3' and kpi= 'net_add_more_180d' and dt_id between date_trunc(vdt_id,month) and vdt_id;
insert into  `data-bi-prd-935c.bi_dev`.ioh_snd_master_kpi_detail 
select 'IM3' brand, 'site' level, level_value, 
    cast(sum(case when kpi ='pre_rgu_90d_more_180d' then values else values*-1 end ) as numeric) value, 
    'dly' as time_flag, 
     timestamp(current_datetime('+7')) as insert_date,
     'net_add_more_180d' as kpi, 
     dt_id
from  `data-bi-prd-935c.bi_dev`.ioh_snd_master_kpi_detail
where kpi in ('pre_rgu_90d_more_180d','pre_rgu_90d_more_180d_m1') and brand = 'IM3'
    and dt_id between date_trunc(vdt_id,month) and vdt_id
group by 1,2,3,5,6,7,8
;


--- NET ADD __less_90d


delete from `data-bi-prd-935c.bi_dev`.ioh_snd_master_kpi_detail where brand = 'IM3' and kpi= 'net_add_less_90d' and dt_id between date_trunc(vdt_id,month) and vdt_id;
insert into  `data-bi-prd-935c.bi_dev`.ioh_snd_master_kpi_detail 
select 'IM3' brand, 'site' level, level_value, 
    cast(sum(case when kpi ='pre_rgu_90d_less_90d' then values end ) as numeric) value, 
    'dly' as time_flag, 
     timestamp(current_datetime('+7')) as insert_date,
     'net_add_less_90d' as kpi, 
     dt_id
from  `data-bi-prd-935c.bi_dev`.ioh_snd_master_kpi_detail
where kpi in ('pre_rgu_90d_less_90d','pre_rgu_90d_less_90d_m1') and brand = 'IM3'
    and dt_id between date_trunc(vdt_id,month) and vdt_id
group by 1,2,3,5,6,7,8
;


--- GAMING VOUCHER

delete from `data-bi-prd-935c.bi_dev`.ioh_snd_master_kpi_detail where brand='IM3' and kpi = 'rev_game_vou' and dt_id between date_trunc(vdt_id,month) and vdt_id;
insert into `data-bi-prd-935c.bi_dev`.ioh_snd_master_kpi_detail
with rev as (
       -- select a.dt_id, msisdn, cast(sum(sales_price) as numeric) as games_rev
        select dt_id, msisdn,  site_id_favloc, cast(sum(sales_price) as numeric) games_rev from 
            (
            select *, 
                case
                     when kpi = 'LOAN BALANCE' then 'OTHERS'
                     when svc_typ = 'FORFEIT' then 'OTHERS'
            when kpi = 'VAS' and rev_code_nm in ('Melon Indonesia, PT', 'Nuon Digital Indonesia', 'Payment Gateway-Melon Indonesia PT', 
                                            'Nuon Digital Indonesia, PT', 'Lionsgate - Melon Indonesia PT', 'Nadaku-Melon Indonesia, PT') 
                                    then 'VAS - VOUCHER GAMING'
            when kpi = 'VAS' and rev_code_nm not in ('Melon Indonesia, PT', 'Nuon Digital Indonesia', 'Payment Gateway-Melon Indonesia PT', 
                                            'Nuon Digital Indonesia, PT', 'Lionsgate - Melon Indonesia PT', 'Nadaku-Melon Indonesia, PT') 
                                    then 'VAS - REGULAR'
                     else svc_typ
                end svc_typ_new
            from `data-dtp-prd-aa1a.sor`.fact_revenue_dashboard_extended
            where date(dt_id) between date_trunc(vdt_id,month) and vdt_id 
                and kpi = 'VAS'
            )a
         where svc_typ_new = 'VAS - VOUCHER GAMING' 
         group by 1,2,3
        ),
site as (
        select dt_id, msisdn, a.site_id
        from `data-bi-prd-935c.bi_mart`.fact_rgu_90d_mtd a
        where dt_id between date_trunc(vdt_id,month) and vdt_id  
        ) 
-----
    select 'IM3' as brand, 
    'site' as level, 
    b.site_id as level_value, 
    cast(sum(games_rev) as numeric) value,  -- nett 
    'dly' as time_flag, 
    timestamp(current_datetime('+7')) as insert_date,
    'rev_game_vou' as kpi,
    date(a.dt_id) dt_id
        from rev a
    left join site b 
    on a.msisdn=b.msisdn and date(a.dt_id)=b.dt_id
    group by 1,2,3,5,6,7,8
;

--------------- PRE RGU 90 untuk ARPU ----------------

delete from `data-bi-prd-935c.bi_dev.ioh_snd_master_kpi_detail` where dt_id = vdt_id and brand = 'IM3' and kpi = 'pre_rgu_90d_arpu';
insert into `data-bi-prd-935c.bi_dev.ioh_snd_master_kpi_detail`
WITH month_1 AS (
                  SELECT date(date_trunc(vdt_id,month) - interval 1 day) AS dt_id
                ),
pre_rgu_m1 as (
    select dt_id, kpi, a.level_value, sum(a.values) value
    from `data-bi-prd-935c.bi_dev.ioh_snd_master_kpi_detail` a
        where kpi in ('pre_rgu_90d'/*'pre_rgu_30d'*/) and brand = 'IM3'
            and dt_id = (select dt_id from month_1 b)
    group by 1,2,3
    ),
pre_rgu as (
    select dt_id, kpi, a.level_value, sum(a.values) value
    from `data-bi-prd-935c.bi_dev.ioh_snd_master_kpi_detail` a
        where kpi in ('pre_rgu_90d'/*,'pre_rgu_30d'*/) and brand = 'IM3'
            and dt_id = vdt_id
    group by 1,2,3
    )
-- pre rgu 90d arpu
select 'IM3' brand, 
    'site' level, 
    level_value, 
    cast(sum((value_m0+value_m1)/flag_value) as numeric) value,
     'mtd' as time_flag, 
     timestamp(current_datetime('+7')) as insert_date,
    'pre_rgu_90d_arpu' as kpi, 
    vdt_id as dt_id
from 
(
select a.dt_id, a.kpi, a.level_value, coalesce(a.value,0) value_m0, coalesce(b.value,0) value_m1, 
case when a.value is null or b.value is null then 1 else 2 end flag_value
    from pre_rgu a
left join (select * from pre_rgu_m1 where kpi = 'pre_rgu_90d')  b 
    on a.level_value =b.level_value
where a.kpi = 'pre_rgu_90d'
)a 
group by 1,2,3,5,6,7,8
;

--- Insert to table Summary DLY TO MTD

delete from `data-bi-prd-935c.bi_dev`.ioh_snd_master_kpi_detail_smy where brand ='IM3' and kpi = 'rev_game_vou' and dt_id between date_trunc(vdt_id,month) and vdt_id ;
insert into  `data-bi-prd-935c.bi_dev`.ioh_snd_master_kpi_detail_smy 
with ref_dealer as (
            select a.id, b.circle, b.region region_circle, b.area, b.sales_area, b.micro_cluster
                from  `data-bi-prd-935c.bi_snd.pre_ref_lowlevel_mth_im3` a
                left join
                        (
                        select * from `data-bi-prd-935c.bi_mart`.ref_kecamatan
                            ) b
                        on a.kec_unik = b.kec_kabkot
                where parse_date('%Y%m',cast(a.mth as string))  = date_trunc(vdt_id,month)
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
        ( 'rev_game_vou' ) and brand = 'IM3'
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


--- Insert to table Summary

-- create table `data-bi-prd-935c.bi_dev`.ioh_snd_master_kpi_detail_smy partitioned by (kpi,dt_id) stored as parquet as
delete from `data-bi-prd-935c.bi_dev`.ioh_snd_master_kpi_detail_smy where brand ='IM3' and kpi in 
        ('pre_rgu_90d','pre_rgu_90d_less_90d', 'pre_rgu_90d_90d_180d', 'pre_rgu_90d_more_180d',
        'pre_rgu_90d_m1','pre_rgu_90d_less_90d_m1', 'pre_rgu_90d_90d_180d_m1', 'pre_rgu_90d_more_180d_m1',
        'net_add','net_add_90d_180d','net_add_more_180d','net_add_less_90d'
        ) and dt_id between date_trunc(vdt_id,month) and vdt_id;
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
    where   dt_id  between date_trunc(vdt_id,month) and vdt_id
        and kpi in 
        ('pre_rgu_90d','pre_rgu_90d_less_90d', 'pre_rgu_90d_90d_180d', 'pre_rgu_90d_more_180d',
        'pre_rgu_90d_m1','pre_rgu_90d_less_90d_m1', 'pre_rgu_90d_90d_180d_m1', 'pre_rgu_90d_more_180d_m1',
        'net_add','net_add_90d_180d','net_add_more_180d','net_add_less_90d'
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