declare vdt_id date default @vdt_id;
---------------- secondary_trad_dly ----------------

delete from `data-bi-prd-935c.bi_dev`.ioh_snd_master_kpi_detail where brand='IM3' and kpi='secondary_trad_dly' and dt_id between date_trunc(vdt_id,month) and vdt_id ;
insert into `data-bi-prd-935c.bi_dev`.ioh_snd_master_kpi_detail 
select 'IM3' brand, 'outlet' level, id as level_value, 
    sum(cast(value as numeric)) value, 
    'dly' as time_flag, 
     timestamp(current_datetime('+7')) as insert_date,
    'secondary_trad_dly' as kpi, 
     dt_id
from
(
SELECT 
    dt_id,
    credit_party_id id,
    sum(amount) value
FROM `data-bi-prd-935c.bi_mart`.fact_snd_secondary a
    where dt_id between date_trunc(vdt_id,month) and vdt_id 
    GROUP BY 1,2
)a
group by 1,2,3,5,6,7,8
; 


--------------------------------------
-------- OUTLET SUPPLY DEMAND --------
--------------------------------------
-- Source Incomplete
delete from `data-bi-prd-935c.bi_dev`.ioh_snd_master_kpi_detail where brand='IM3' and kpi in ('outlet_supply','outlet_demand') and dt_id = vdt_id;
insert into `data-bi-prd-935c.bi_dev`.ioh_snd_master_kpi_detail 
select 'IM3' brand, 'outlet' level, a.organization_id as level_value, 
    cast(count(distinct a.organization_id) as numeric) value, 
    'mtd' as time_flag, 
     timestamp(current_datetime('+7')) as insert_date,
     (case
        when a.type = 'Supply' then 'outlet_supply'
        when a.type = 'Demand' then 'outlet_demand'
      end) as kpi, 
     vdt_id as dt_id
from `data-bi-prd-935c.bi_dm.pre_raw_im3_ssd_details_daily` a
where  (date_trunc(a.dt_id,month) between date_trunc(vdt_id,month) and vdt_id)  
    and type in ('Supply','Demand')
group by 1,2,3,5,6,7,8
;



--------------------------------------------------
-------- SECONDARY DETAIL SP-VOU-ORI ------------
--------------------------------------------------

delete from `data-bi-prd-935c.bi_dev`.ioh_snd_master_kpi_detail where brand='IM3' and kpi in ('secondary_sp_dly', 'secondary_vou_dly', 'secondary_saldo_dly', 'secondary_other_dly') and dt_id between date_trunc(vdt_id,month) and vdt_id;
insert into `data-bi-prd-935c.bi_dev`.ioh_snd_master_kpi_detail  
select 'IM3' brand, 'outlet' level, a.organization_id as level_value, 
    sum(cast(amount as numeric)) value, 
    'dly' as time_flag, 
     timestamp(current_datetime('+7')) as insert_date,
    (case
        when secondary_type in ('SP DATA','SP DATA ALLOC','SP ZERO') then 'secondary_sp_dly'
        when secondary_type='SELLIN MPC' then 'secondary_saldo_dly'
        when secondary_type in ('VOU ORI','VOU ORI ALLOC') then 'secondary_vou_dly'
        else 'secondary_other_dly'
    end) as kpi, 
    dt_id
FROM
    (
        SELECT 
            dt_id,
            credit_party_id organization_id,
            secondary_type,
            sum(amount) amount
        FROM `data-bi-prd-935c.bi_mart`.fact_snd_secondary a
        where
            (
                (date_trunc(a.dt_id,month) = date_trunc(vdt_id,month) and a.dt_id <= vdt_id)  
            )
        GROUP BY 1,2,3
    ) a
group by 1,2,3,5,6,7,8
;


--------------------------------------
-------- TRADE DEMAND OUTLET  -----
--------------------------------------

delete from `data-bi-prd-935c.bi_dev`.ioh_snd_master_kpi_detail where brand='IM3' and kpi='trade_demand_outlet' and dt_id = vdt_id;
insert into `data-bi-prd-935c.bi_dev`.ioh_snd_master_kpi_detail 
with trade_demand as (
            select organization_id, sum(amount_debit) amount
            from `data-bi-prd-935c.bi_mart`.fact_snd_tertiary_dtl
            where dt_id between date_trunc(vdt_id,month) and vdt_id 
                and channel_grp in ('Traditional')
                and tertiary_type not in ('RELOAD','SP ZERO','VOU RLD')
            group by 1 
            )
-- trade demand
select 'IM3' brand, 'outlet' level, organization_id as level_value, 
    sum(cast(amount as numeric)) value, 
    'mtd' as time_flag, 
     timestamp(current_datetime('+7')) as insert_date,
    'trade_demand_outlet' as kpi, 
    vdt_id dt_id
from trade_demand a
group by 1,2,3,5,6,7,8
;


--------------------------------------
--- TRADE SUPPLY BY OUTLET CATEGORY
--------------------------------------

delete from `data-bi-prd-935c.bi_dev`.ioh_snd_master_kpi_detail where brand='IM3' and kpi in ('outlet_amt_retailer','outlet_amt_wholeseller','outlet_amt_serverplayer','outlet_retailer','outlet_amt_wholeseller','outlet_amt_serverplayer') and dt_id = vdt_id;
insert into `data-bi-prd-935c.bi_dev`.ioh_snd_master_kpi_detail 
WITH month_1 AS (
                  select date(date_trunc(vdt_id,month) - interval 1 day) AS dt_id
                ),
category as (
            select dt_id, level_value, flag_category, sum(amt) amt from 
            (
                select a.*, 
                       case when amt is null then 'retailer'
                            when amt < 30000000 then 'retailer'
                            when amt >= 30000000 and amt <50000000 then 'whole seller'
                            when amt >= 50000000 then 'Server Player'
                        end flag_category
                from 
                (
                    select dt_id, level_value, sum(values) amt
                from `data-bi-prd-935c.bi_dev`.ioh_snd_master_kpi_detail a
                    where kpi = 'trade_supply' and brand = 'IM3'
                        and dt_id = (select dt_id from month_1 b)
                group by 1,2
                )a
            )a
            group by 1,2,3
            ),
trade_supply as (
                select dt_id, level_value, 
                        case when amt is null then 'retailer'
                            when amt < 30000000 then 'retailer'
                            when amt >= 30000000 and amt <50000000 then 'whole seller'
                            when amt >= 50000000 then 'Server Player'
                        end flag_category,
                     sum(amt) amt
                from
                    (
                    select dt_id, level_value, sum(values) amt
                    from `data-bi-prd-935c.bi_dev`.ioh_snd_master_kpi_detail a
                        where kpi = 'trade_supply' and brand = 'IM3'
                            and dt_id = vdt_id
                    group by 1,2
                    )a
                group by 1,2,3
            ),
final as (
        select a.dt_id, a.level_value, coalesce(b.flag_category,a.flag_category) as flag_category, sum(a.amt) amt
            from trade_supply a
        left join category b 
        on a.level_value=b.level_value
        group by 1,2,3
        )
-------- outlet flag amt  --------
select 'IM3' as brand, 
        'site' as level, 
        level_value, 
        cast(sum(amt) as numeric) value,  -- gross 
        'mtd' as time_flag, 
        timestamp(current_datetime('+7')) as insert_date,
        case when flag_category = 'retailer' then 'outlet_amt_retailer'
             when flag_category = 'whole seller' then 'outlet_amt_wholeseller'
             when flag_category = 'Server Player' then 'outlet_amt_serverplayer'
        end as kpi,
        dt_id
from final
group by 1,2,3,5,6,7,8
union all 
-------- outlet flag amt outlet  --------
select 'IM3' as brand, 
        'site' as level, 
        level_value, 
        cast(count(level_value) as numeric) value,  -- gross 
        'mtd' as time_flag, 
        timestamp(current_datetime('+7')) as insert_date,
        case when flag_category = 'retailer' then 'outlet_retailer'
             when flag_category = 'whole seller' then 'outlet_wholeseller'
             when flag_category = 'Server Player' then 'outlet_serverplayer'
        end as kpi,
        dt_id
from final
group by 1,2,3,5,6,7,8
;


--- Insert to table Summary

delete from `data-bi-prd-935c.bi_dev`.ioh_snd_master_kpi_detail_smy  where brand = 'IM3' and kpi in 
        ('primary_trad','primary_nontrad','secondary_trad','tertiary_trad','tertiary_nontrad',
         'outlet_amt_retailer','outlet_amt_wholeseller','outlet_amt_serverplayer','outlet_retailer','outlet_wholeseller','outlet_serverplayer'
        ) and dt_id = vdt_id;
insert into `data-bi-prd-935c.bi_dev`.ioh_snd_master_kpi_detail_smy 
with ref_dealer as (
            select a.id, b.circle, b.region region_circle, b.area, b.sales_area, b.micro_cluster
                from  `data-bi-prd-935c.bi_snd.pre_ref_lowlevel_mth_im3` a
                left join
                        (
                        select * from `data-bi-prd-935c.bi_mart`.ref_kecamatan
                            ) b
                        on a.kec_unik = b.kec_kabkot
                where safe.parse_date('%Y%m',cast(a.mth as string)) = date_trunc(vdt_id,month)
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
        ('primary_trad','primary_nontrad','secondary_trad','tertiary_trad','tertiary_nontrad',
         'outlet_amt_retailer','outlet_amt_wholeseller','outlet_amt_serverplayer','outlet_retailer','outlet_wholeseller','outlet_serverplayer'
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