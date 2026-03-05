declare vdt_id date default @vdt_id;
------------ Gross Churn - Abs ------------ 
delete from `data-bi-prd-935c.bi_dev`.ioh_snd_master_kpi_detail where kpi in ('churn_less_90d','churn_90d_180d','churn_more_180d','churn') and dt_id = vdt_id and brand = 'IM3';
insert into `data-bi-prd-935c.bi_dev`.ioh_snd_master_kpi_detail
with gross_churn as (
    select a.*, 
            case when 
            date_diff(last_usg,first_usg,day) <= 90 then 'churn_less_90d'
            when
            date_diff(last_usg,first_usg,day) <= 180 then 'churn_90d_180d'
            when
            date_diff(last_usg,first_usg,day) > 180 then 'churn_more_180d'
            else 'churn_more_180d' end as kpi_id
    from `data-bi-prd-935c.bi_mart`.rgs_churn_90d_dly_govt a
    where dt_id = vdt_id
                ) 
-- churn tenur
select 'IM3' as brand, 
        'site' as level, 
        site_id as level_value, 
        cast(count(distinct msisdn) as numeric) value,  -- gross 
        'mtd' as time_flag, 
        timestamp(current_datetime('+7')) as insert_date,
        kpi_id,
        vdt_id as dt_id
from gross_churn
group by 1,2,3,5,6,7,8
union all 
-- churn 
select 'IM3' as brand, 
        'site' as level, 
        site_id as level_value, 
        cast(count(distinct msisdn) as numeric) value,  -- gross 
        'mtd' as time_flag, 
        timestamp(current_datetime('+7')) as insert_date,
        'churn' as kpi_id,
        vdt_id as dt_id
from gross_churn
group by 1,2,3,5,6,7,8
;


-------------------- Churn Back - Abs -------------------- 

delete from `data-bi-prd-935c.bi_dev`.ioh_snd_master_kpi_detail where dt_id = vdt_id and kpi in ('churn_back_90d_180d','churn_back_more_180d','churn_back') and brand ='IM3';
insert into `data-bi-prd-935c.bi_dev`.ioh_snd_master_kpi_detail
with churn_back as (
        select a.*, 
        case when 
            date_diff(dt_id,first_usg,day) <= 180 then 'churn_back_90d_180d'
            when
            date_diff(dt_id,first_usg,day) > 181 then 'churn_back_more_180d'
            else 'churn_back_more_180d' end as kpi_id
            from `data-bi-prd-935c.bi_mart`.rgs_churn_back_90d_govt a
            where dt_id = vdt_id
        )
-- churn_back tenut
select 'IM3' as brand, 
        'site' as level, 
        site_id as level_value, 
        cast(count(distinct msisdn) as numeric) value,  -- gross 
        'mtd' as time_flag, 
        timestamp(current_datetime('+7')) as insert_date,
        kpi_id,
        vdt_id as dt_id
from churn_back
group by 1,2,3,5,6,7,8
union all 
-- churn_back 
select 'IM3' as brand, 
        'site' as level, 
        site_id as level_value, 
        cast(count(distinct msisdn) as numeric) value,  -- gross 
        'mtd' as time_flag, 
        timestamp(current_datetime('+7')) as insert_date,
        'churn_back' as kpi_id,
        vdt_id as dt_id
from churn_back
group by 1,2,3,5,6,7,8
;


--- NET CHURN

delete from `data-bi-prd-935c.bi_dev`.ioh_snd_master_kpi_detail where dt_id between date_trunc(vdt_id,month) and vdt_id and kpi = 'net_churn' and brand ='IM3';
insert into `data-bi-prd-935c.bi_dev`.ioh_snd_master_kpi_detail 
select 'IM3' brand, 'site' level, level_value, 
    cast(sum(case when kpi ='churn' then values else values*-1 end ) as numeric) value, 
    'dly' as time_flag, 
     timestamp(current_datetime('+7')) as insert_date,
     'net_churn' as kpi_id, 
     dt_id
from  `data-bi-prd-935c.bi_dev`.ioh_snd_master_kpi_detail
where kpi in ('churn','churn_back') and brand = 'IM3'
    and dt_id between date_trunc(vdt_id,month) and vdt_id
group by 1,2,3,5,6,7,8
;


--- NET CHURN _90d_180d

delete from `data-bi-prd-935c.bi_dev`.ioh_snd_master_kpi_detail where dt_id between date_trunc(vdt_id,month) and vdt_id and kpi = 'net_churn_90d_180d' and brand ='IM3';
insert into `data-bi-prd-935c.bi_dev`.ioh_snd_master_kpi_detail 
select 'IM3' brand, 'site' level, level_value, 
    cast(sum(case when kpi ='churn_90d_180d' then values else values*-1 end ) as numeric) value, 
    'dly' as time_flag, 
     timestamp(current_datetime('+7')) as insert_date,
     'net_churn_90d_180d' as kpi_id, 
     dt_id
from  `data-bi-prd-935c.bi_dev`.ioh_snd_master_kpi_detail
where kpi in ('churn_90d_180d','churn_back_90d_180d') and brand = 'IM3'
    and dt_id between date_trunc(vdt_id,month) and vdt_id
group by 1,2,3,5,6,7,8
;


--- NET CHURN _more_180d

delete from `data-bi-prd-935c.bi_dev`.ioh_snd_master_kpi_detail where dt_id between date_trunc(vdt_id,month) and vdt_id and kpi = 'net_churn_more_180d' and brand ='IM3';
insert into `data-bi-prd-935c.bi_dev`.ioh_snd_master_kpi_detail 
select 'IM3' brand, 'site' level, level_value, 
    cast(sum(case when kpi ='churn_more_180d' then values else values*-1 end ) as numeric) value, 
    'dly' as time_flag, 
     timestamp(current_datetime('+7')) as insert_date,
     'net_churn_more_180d' as kpi_id, 
     dt_id
from  `data-bi-prd-935c.bi_dev`.ioh_snd_master_kpi_detail
where kpi in ('churn_more_180d','churn_back_more_180d') and brand = 'IM3'
    and dt_id between date_trunc(vdt_id,month) and vdt_id
group by 1,2,3,5,6,7,8
;


--- NET CHURN __less_90d
delete from `data-bi-prd-935c.bi_dev`.ioh_snd_master_kpi_detail where dt_id between date_trunc(vdt_id,month) and vdt_id and kpi = 'net_churn_less_90d' and brand ='IM3';
insert into `data-bi-prd-935c.bi_dev`.ioh_snd_master_kpi_detail 
select 'IM3' brand, 'site' level, level_value, 
    cast(sum(case when kpi ='churn_less_90d' then values end ) as numeric) value, 
    'dly' as time_flag, 
     timestamp(current_datetime('+7')) as insert_date,
     'net_churn_less_90d' as kpi_id, 
     dt_id
from  `data-bi-prd-935c.bi_dev`.ioh_snd_master_kpi_detail
where kpi in ('churn_less_90d') and brand = 'IM3'
    and dt_id between date_trunc(vdt_id,month) and vdt_id
group by 1,2,3,5,6,7,8
;





--- Insert to table Summary

delete from `data-bi-prd-935c.bi_dev`.ioh_snd_master_kpi_detail_smy  where dt_id = vdt_id and kpi in (
         'churn', 'churn_less_90d', 'churn_90d_180d', 'churn_more_180d', 
         'churn_back', 'churn_back_90d_180d', 'churn_back_more_180d',
         'net_churn','net_churn_less_90d','net_churn_90d_180d','net_churn_more_180d'
        ) and brand = 'IM3';
insert into `data-bi-prd-935c.bi_dev`.ioh_snd_master_kpi_detail_smy 
with ref_dealer as (
            select a.id, b.circle, b.region region_circle, b.area, b.sales_area, b.micro_cluster
                from  `data-dtp-prd-aa1a.rdm`.spa_tbl_ref_lowlevel_mth a
                left join
                        (
                        select * from `data-bi-prd-935c.bi_mart`.ref_kecamatan
                            ) b
                        on a.kec_unik = b.kec_kabkot
                where date(a.mth) = date_trunc(vdt_id,month)
            ),
ref_dealer_rn as (            
            select a.id, b.circle, b.region region_circle, b.area, b.sales_area, b.micro_cluster
                from
                (
                    select * from 
                    (
                    select a.*, 
                        ROW_NUMBER() OVER (partition by id ORDER BY mth desc) AS rn 
                    from  `data-dtp-prd-aa1a.rdm`.spa_tbl_ref_lowlevel_mth a
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
    where   dt_id between date_trunc(vdt_id,month) and vdt_id
        and kpi in 
        (
         'churn', 'churn_less_90d', 'churn_90d_180d', 'churn_more_180d', 
         'churn_back', 'churn_back_90d_180d', 'churn_back_more_180d',
         'net_churn','net_churn_less_90d','net_churn_90d_180d','net_churn_more_180d'
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
        vdt_id dt_id
    from tracker a 
        left join ref_dealer b
    on a.level_value=b.id 
   --     left join ref_dealer_rn c
   -- on a.level_value=c.id 
   where brand = 'IM3'
group by 1,2,3,4,5,6,8,9
;