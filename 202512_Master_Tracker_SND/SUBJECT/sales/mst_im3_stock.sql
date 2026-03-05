declare vdt_id date default @vdt_id;
---------------  STOCK MPC ----------------

delete from `data-bi-prd-935c.bi_dev`.ioh_snd_master_kpi_detail where brand = 'IM3' and kpi= 'stock_with_dist' and dt_id = vdt_id;
insert into `data-bi-prd-935c.bi_dev`.ioh_snd_master_kpi_detail
select 'IM3' brand, 'partner' level, dealer_id as level_value, 
    sum(cast(amount as numeric)) value, 
    'mtd' as time_flag, 
     timestamp(current_datetime('+7')) as insert_date,
    'stock_with_dist' as kpi, 
     dt_id
from 
--- STOCK MPC
(
    select dt_id, dealer_id, sum(amount) amount  from 
    (
    -- stock balance primari mpc
        select date(dt_id) dt_id, short_code dealer_id,
         sum(cast(current_balance as numeric)) as amount
        from `data-dtp-prd-aa1a.stg`.stock_balance_daily 
        where date(dt_id)=vdt_id
        and lower(cluster_name) not in ('','cw-cja-purbamen','cw-cja-purwotelang')
        and lower(cluster_name) not like '%test%'
        and lower(cluster_name) not like '%cluster sev%'
        and lower(sales_channel_name) ='traditional'
        and lower(sales_channel)='salmobo'
        and lower(region_name) not in ('regional-hr','regional-project','regional-test','regional sev')
        and lower(organization_type)='dealer'
        and account_type_id in ('2','192')
        group by 1,2
    union all 
    -- stock sp ori mpc
        select dt_id, dealer_id, sum(cast(amount as numeric)) amount 
        from `data-bi-prd-935c.bi_mart`.stock_sp_data
        where dt_id =vdt_id
            and exp_dt>dt_id
        group by 1,2
    union all 
    -- stock vou ori mpc
        select dt_id,dealer_id,sum(cast(amount as numeric)) stock_mpc
        from `data-bi-prd-935c.bi_mart`.stock_vo_ori
        where dt_id = vdt_id 
        and exp_dt>dt_id
        group by 1,2
    )a
    group by 1,2
)a 
group by 1,2,3,5,6,7,8
;



---------------- DEMAND 30 ----------------

delete from `data-bi-prd-935c.bi_dev`.ioh_snd_master_kpi_detail where brand = 'IM3' and kpi='demand_30' and dt_id = vdt_id ;
insert into `data-bi-prd-935c.bi_dev`.ioh_snd_master_kpi_detail
with demand_30 as (
                select organization_id, type, sum(rev)rev
                from 
                (
                 select
                    a.organization_id, --> OUTLET NBS
                    a.site_bnum, --> FACLOC
                    a.b_msisdn,
                    '' flag_sp,
                    a.product_name,
                    '' expired_date,
                    '' exp_flag,
                    sum(a.hits)hit,
                    sum(a.amount_debit) rev,
                    vdt_id dt_id,
                    date_trunc(vdt_id,month) mth,  
                    'Demand 30' type,  
                    tertiary_type as category 
                from `data-bi-prd-935c.bi_mart`.fact_snd_tertiary_dtl a 
                where
                    (
                        a.dt_id between vdt_id - interval 30 day and vdt_id      
                    )
                and a.channel_grp in ('Traditional')
                and a.tertiary_type in ('RELOAD','SP MOBO Y2','SP MOBO Y3','VOU ORI','VOU REDEEM','SP DATA')
                group by 1,2,3,4,5,6,7,10,11,12,13
                )a
                group by 1,2
            )
-- DEMAND 30 / 30
select 'IM3' brand, 'outlet' level, organization_id as level_value, 
        cast(sum(rev)/30 as numeric) value, 
        'mtd' as time_flag, 
        timestamp(current_datetime('+7')) as insert_date,
        'demand_30' as kpi, 
        vdt_id as dt_id
from demand_30 a
group by 1,2,3,5,6,7,8
;


---------------- SALDO OUTLET & DEMAND 30   ----------------

delete from `data-bi-prd-935c.bi_dev`.ioh_snd_master_kpi_detail where brand = 'IM3' and kpi in ('demand_30_saldo','stock_saldo_outlet') and dt_id = vdt_id;
insert into `data-bi-prd-935c.bi_dev`.ioh_snd_master_kpi_detail
with demand_30 as (
    select organization_id, type, sum(cast(rev as numeric))rev
from 
    (
     select
        a.organization_id, --> OUTLET NBS
        a.site_bnum, --> FACLOC
        a.b_msisdn,
        '' flag_sp,
        a.product_name,
        '' expired_date,
        '' exp_flag,
        sum(a.hits)hit,
        sum(a.amount_debit) rev,
        vdt_id dt_id,
        date_trunc(vdt_id,month) mth,  
        'Demand 30' type,  
        tertiary_type as category 
    from `data-bi-prd-935c.bi_mart`.fact_snd_tertiary_dtl a 
    where
        (
            a.dt_id >= vdt_id - interval 30 day 
            and a.dt_id <= vdt_id      
        )
    and a.channel_grp in ('Traditional')
    and a.tertiary_type in ('RELOAD','SP MOBO Y3')
    group by 1,2,3,4,5,6,7,10,11,12,13
    )a
    group by 1,2
),
stock_saldo as (
    select short_code, sum(cast(stock_balance as numeric)) saldo from 
    (
        select * from `data-bi-prd-935c.bi_mart`.outlet_stock_balance
        where dt_id =vdt_id
    )a 
    group by 1
    )
-- stock saldo
select 'IM3' brand, 'outlet' level, short_code as level_value, 
    sum(cast(saldo as numeric)) value, 
    'mtd' as time_flag, 
     timestamp(current_datetime('+7')) as insert_date,
    'stock_saldo_outlet' as kpi, 
    vdt_id as dt_id
from stock_saldo a
group by 1,2,3,5,6,7,8
union all 
-- demand_30_saldo
select 'IM3' brand, 'outlet' level, organization_id as level_value, 
    cast(sum(rev)/30 as numeric) value, 
    'mtd' as time_flag, 
     timestamp(current_datetime('+7')) as insert_date,
    'demand_30_saldo' as kpi, 
      vdt_id as dt_id
from demand_30 
group by 1,2,3,5,6,7,8
;

---------------- STOCK SP OUTLET & DEMAND 30   ----------------

delete from `data-bi-prd-935c.bi_dev`.ioh_snd_master_kpi_detail where brand = 'IM3' and kpi in ('stock_sp_outlet','demand_30_sp') and dt_id = vdt_id;
insert into `data-bi-prd-935c.bi_dev`.ioh_snd_master_kpi_detail
with sp_mobo as  (
                select a.*
                from `data-bi-prd-935c.bi_mart`.stock_mobo_sp a
                join (
                    select date(dt_id) dt_id,msisdn from `data-dtp-prd-aa1a.smy`.ar_cst_dly_smy
                    where date(dt_id)  = vdt_id
                    and ar_lcs_tp_nm in ('ACTIVE','ACTIVE IN GRACE')
                    ) b 
                on a.b_msisdn=b.msisdn and a.dt_id=b.dt_id
                where a.dt_id  = vdt_id
               ),
sp_ori as (
            select * from 
                (
                select a.*,
                     expired_date expired_date_normalisasi,
                    (case
                        when expired_date >= date(timestamp(current_datetime('+7'))) then 'No' else 'Expired'
                    end) exp_flag
                from `data-bi-prd-935c.bi_mart`.stock_sp_data_mobii a
                where dt_id = vdt_id 
            )a
            where  expired_date_normalisasi>dt_id
        ),
demand_30 as (
    select organization_id, type, sum(rev) rev
        from 
            (
             select
                a.organization_id, --> OUTLET NBS
                a.site_bnum, --> FACLOC
                a.b_msisdn,
                '' flag_sp,
                a.product_name,
                '' expired_date,
                '' exp_flag,
                sum(a.hits) hit,
                sum(a.amount_debit) rev,
                vdt_id dt_id,
                date_trunc(vdt_id,month) mth,  
                'Demand 30' type,  
                tertiary_type as category 
            from `data-bi-prd-935c.bi_mart`.fact_snd_tertiary_dtl a 
            where
                (
                    a.dt_id >= vdt_id - interval 30 day 
                    and a.dt_id <= vdt_id      
                )
            and a.channel_grp in ('Traditional')
            and a.tertiary_type in ('SP MOBO Y2','SP DATA')
            group by 1,2,3,4,5,6,7,10,11,12,13
            )a
        group by 1,2
    )
-- stock SP outlet
    select 'IM3' brand, 'outlet' level, organization_id as level_value, 
        sum(cast(value as numeric)) value, 
        'mtd' as time_flag, 
        timestamp(current_datetime('+7')) as insert_date,
        'stock_sp_outlet' as kpi, 
        vdt_id as dt_id
    from 
        (
            select organization_id, sum(amount_debit) value from sp_mobo group by 1 
            union all 
            select dest_saldomobo_id organization_id, sum(amount) value from sp_ori group by 1
        )a
    group by 1,2,3,5,6,7,8
union all 
select 'IM3' brand, 'outlet' level, organization_id as level_value, 
    cast(sum(rev)/30 as numeric) value, 
    'mtd' as time_flag, 
     timestamp(current_datetime('+7')) as insert_date,
    'demand_30_sp' as kpi, 
      vdt_id as dt_id
from  demand_30 b
group by 1,2,3,5,6,7,8
;


--- STOCK & DEMAND 30 VOU OUTLET IM3

delete from `data-bi-prd-935c.bi_dev`.ioh_snd_master_kpi_detail where brand = 'IM3' and kpi in ('stock_vou_outlet','demand_30_vou') and dt_id = vdt_id;
insert into `data-bi-prd-935c.bi_dev`.ioh_snd_master_kpi_detail
with vou_ori as  (
                 -- stock outlet vou mobii (vou ori)
                select dt_id, organization_id, sum(amount) stock
                from `data-bi-prd-935c.bi_mart`.stock_vo_ori_sellin
                where dt_id  = vdt_id
                and expired_date>dt_id
                group by 1,2 
                ),
vou_inj as (
            -- stock outlet vou mobo 
            select dt_id, organization_id,sum(amount_debit) stock
            from `data-bi-prd-935c.bi_mart`.stock_mobo_vou
            where dt_id = vdt_id
            group by 1,2
            ),
demand_30 as (
    select organization_id, type, sum(rev) rev
        from 
            (
             select
                a.organization_id, --> OUTLET NBS
                a.site_bnum, --> FACLOC
                a.b_msisdn,
                '' flag_sp,
                a.product_name,
                '' expired_date,
                '' exp_flag,
                sum(a.hits) hit,
                sum(a.amount_debit) rev,
                vdt_id dt_id,
                date_trunc(vdt_id,month) mth,  
                'Demand 30' type,  
                tertiary_type as category 
            from `data-bi-prd-935c.bi_mart`.fact_snd_tertiary_dtl a 
            where
                (
                    a.dt_id >= vdt_id - interval 30 day 
                    and a.dt_id <= vdt_id      
                )
            and a.channel_grp in ('Traditional')
            and a.tertiary_type  in ('VOU ORI','VOU REDEEM')
            group by 1,2,3,4,5,6,7,10,11,12,13
            )a
        group by 1,2
    )
-- STOCK VOU
select 'IM3' brand, 'outlet' level, organization_id as level_value, 
    sum(cast(stock as numeric)) value,
    'mtd' as time_flag, 
     timestamp(current_datetime('+7')) as insert_date,
    'stock_vou_outlet' as kpi, 
      vdt_id as dt_id
from 
    ( select * from vou_ori 
        union all 
      select * from vou_inj
    )a
group by 1,2,3,5,6,7,8
union all 
-- DEMAND 30 VOU
select 'IM3' brand, 'outlet' level, organization_id as level_value, 
    cast(sum(rev)/30 as numeric) value, 
    'mtd' as time_flag, 
     timestamp(current_datetime('+7')) as insert_date,
    'demand_30_vou' as kpi, 
      vdt_id as dt_id
from demand_30
group by 1,2,3,5,6,7,8
;


--- STOCKOUT OUTLET & STOCK LESS OUTLET IM3 (VOU - SP - SALDO)

delete from `data-bi-prd-935c.bi_dev`.ioh_snd_master_kpi_detail where brand = 'IM3' and kpi in ('stockout_outlet','stockout_outlet_vou','stockout_outlet_sp','stockout_outlet_saldo') and dt_id = vdt_id;
insert into `data-bi-prd-935c.bi_dev`.ioh_snd_master_kpi_detail
with stock_saldo as (
                select short_code, sum(cast(stock_balance as numeric)) saldo from 
                    (
                        select * from `data-bi-prd-935c.bi_mart`.outlet_stock_balance
                        where dt_id =vdt_id
                    )a 
                -- where category = 'SALDO MOBO-OUTLET'
                group by 1
                ),
sp_mobo as  (
                select a.*
                from `data-bi-prd-935c.bi_mart`.stock_mobo_sp a
                join (
                    select date(dt_id) dt_id,msisdn from `data-dtp-prd-aa1a.smy`.ar_cst_dly_smy
                    where date(dt_id)  = vdt_id
                    and ar_lcs_tp_nm in ('ACTIVE','ACTIVE IN GRACE')
                    ) b 
                on a.b_msisdn=b.msisdn and a.dt_id = b.dt_id
                where a.dt_id  = vdt_id
                ),
sp_ori as (
            select * from 
                (
                select a.*,
                     expired_date expired_date_normalisasi,
                    (case
                        when expired_date >= date(timestamp(current_datetime('+7'))) then 'No' else 'Expired'
                    end) exp_flag
                from `data-bi-prd-935c.bi_mart`.stock_sp_data_mobii a
                where dt_id = vdt_id 
            )a
            where  expired_date_normalisasi>dt_id
        ),
vou_ori as  (
                 -- stock outlet vou mobii (vou ori)
                select dt_id, organization_id, sum(amount) stock
                from `data-bi-prd-935c.bi_mart`.stock_vo_ori_sellin
                where dt_id  =vdt_id
                and expired_date>dt_id
                group by 1,2 
                ),
vou_inj as (
            -- stock outlet vou mobo 
            select dt_id, organization_id,sum(amount_debit) stock
            from `data-bi-prd-935c.bi_mart`.stock_mobo_vou
            where dt_id =vdt_id
            group by 1,2
            ),
demand_30 as (
                select organization_id, sum(rev)rev
            from 
                (
                 select
                    a.organization_id, --> OUTLET NBS
                    a.site_bnum, --> FACLOC
                    a.b_msisdn,
                    '' flag_sp,
                    a.product_name,
                    '' expired_date,
                    '' exp_flag,
                    sum(a.hits)hit,
                    sum(a.amount_debit) rev,
                    vdt_id dt_id,
                    date_trunc(vdt_id,month) mth,  
                    'Demand 30' type,  
                    tertiary_type as category 
                from `data-bi-prd-935c.bi_mart`.fact_snd_tertiary_dtl a 
                where
                    (
                        a.dt_id >= vdt_id - interval 30 day 
                        and a.dt_id <= vdt_id      
                    )
                and a.channel_grp in ('Traditional')
                group by 1,2,3,4,5,6,7,10,11,12,13
                )a
                group by 1
            ),
outlet_mapping as (select distinct id_outlet from `data-bi-prd-935c.bi_snd.pre_ref_outlet_mapping_im3` where parse_date('%Y%m',cast(mth_id as string))=date_trunc(vdt_id,month)),
dos as (
    select a.*,         case 
                            when stock is null then 0
                            when stock <= 0 and (demand_30 is null or demand_30 = 0) then 0
                            when stock > 0 and (demand_30 is null or demand_30 = 0) then 30 -- cast(stock/30 as numeric)
                            else stock/demand_30 
                        end as dos 
    from 
            (
        select a.id_outlet as organization_id,  
                cast(sum(value) as numeric) stock,  
                cast(sum(rev)/30 as numeric)  demand_30
        from  outlet_mapping a
            left join 
                    (
                        select organization_id, sum(value) value
                        from 
                            (
                                select organization_id, sum(cast(amount_debit as numeric)) value from sp_mobo group by 1 
                                union all 
                                select dest_saldomobo_id organization_id, sum(cast(amount as numeric)) value from sp_ori group by 1
                                union all 
                                select short_code organization_id, sum(cast(saldo as numeric)) value from stock_saldo group by 1
                                union all 
                                select organization_id, sum(cast(stock as numeric)) value from vou_ori group by 1
                                union all 
                                select organization_id, sum(cast(stock as numeric)) value from vou_inj group by 1
                            )a
                        group by 1 
                    )b 
                on a.id_outlet=b.organization_id
            left join demand_30 c 
                on a.id_outlet=c.organization_id
        group by 1
            )a
    )
select 'IM3' brand, 'outlet' level, organization_id as level_value, 
        cast(count(distinct organization_id) as numeric) value,
        'mtd' as time_flag, 
        timestamp(current_datetime('+7')) as insert_date,
        'stockout_outlet' as kpi, 
        vdt_id as dt_id
from dos
where stock <= 0 or null
group by 1,2,3,5,6,7,8
union all
--- Stockout VOU
select 'IM3' brand, 'outlet' level, organization_id as level_value, 
    cast(count(distinct organization_id) as numeric) value,
    'mtd' as time_flag, 
     timestamp(current_datetime('+7')) as insert_date,
    'stockout_outlet_vou' as kpi, 
      vdt_id as dt_id
from 
    (
        select a.id_outlet as organization_id,  coalesce(value,0) value 
        from  outlet_mapping a
            left join  (select organization_id, sum(cast(stock as numeric)) value from vou_ori group by 1)b 
        on a.id_outlet=b.organization_id
    )a
where value <= 0 or null
group by 1,2,3,5,6,7,8
union all
--- Stockout SP
    select 'IM3' brand, 'outlet' level, organization_id as level_value, 
        cast(count(distinct organization_id) as numeric) value,
        'mtd' as time_flag, 
        timestamp(current_datetime('+7')) as insert_date,
        'stockout_outlet_sp' as kpi, 
        vdt_id as dt_id
from 
    (
        select a.id_outlet as organization_id,  coalesce(value,0) value 
        from  outlet_mapping a
            left join  (
                    select organization_id, sum(cast(amount_debit as numeric)) value from sp_mobo group by 1 
                    union all 
                    select dest_saldomobo_id organization_id, sum(cast(amount as numeric)) value from sp_ori group by 1
                        )b
        on a.id_outlet=b.organization_id
    )a
where value <=0 or null
group by 1,2,3,5,6,7,8
union all             
--- Stockout Saldo
select 'IM3' brand, 'outlet' level, organization_id as level_value, 
    cast(count(distinct organization_id) as numeric) value,
    'mtd' as time_flag, 
     timestamp(current_datetime('+7')) as insert_date,
    'stockout_outlet_saldo' as kpi, 
    vdt_id as dt_id
from 
    (
        select a.id_outlet as organization_id,  coalesce(value,0) value 
        from  outlet_mapping a
            left join  (select short_code, sum(cast(saldo as numeric)) value from stock_saldo group by 1)b 
        on a.id_outlet=b.short_code
    )a
where value <=0
group by 1,2,3,5,6,7,8
;


-- SSO outlet stock 

delete from `data-bi-prd-935c.bi_dev`.ioh_snd_master_kpi_detail where brand = 'IM3' and kpi in ('sso_stockout_outlet', 'sso_outlet_3dy_stock') and dt_id = vdt_id;
insert into `data-bi-prd-935c.bi_dev`.ioh_snd_master_kpi_detail
with demand_30 as (
        select organization_id, type, category, sum(rev)rev
            from 
                (
                 select
                    a.organization_id, --> OUTLET NBS
                    a.site_bnum, --> FACLOC
                    a.b_msisdn,
                    '' flag_sp,
                    a.product_name,
                    '' expired_date,
                    '' exp_flag,
                    sum(a.hits)hit,
                    sum(a.amount_debit) rev,
                    vdt_id dt_id,
                    date_trunc(vdt_id,month) mth,  
                    'Demand 30' type,  
                    tertiary_type as category 
                from `data-bi-prd-935c.bi_mart`.fact_snd_tertiary_dtl a 
                where
                    (
                        a.dt_id >= vdt_id - interval 30 day 
                        and a.dt_id <= vdt_id      
                    )
                and a.channel_grp in ('Traditional')
                and a.tertiary_type in ('RELOAD','SP MOBO Y2','SP MOBO Y3','SP DATA')
                        -- 'VOU ORI','VOU REDEEM'
                group by 1,2,3,4,5,6,7,10,11,12,13
                )a
                group by 1,2,3
            ),
stock_saldo as (
        select short_code, sum(cast(stock_balance as numeric)) saldo from 
        (
            select * from `data-bi-prd-935c.bi_mart`.outlet_stock_balance
            where dt_id =vdt_id
        )a 
        group by 1
        ),
sp_mobo as  (
            select a.* from `data-bi-prd-935c.bi_mart`.stock_mobo_sp a
                join (
                    select date(dt_id) dt_id,msisdn from `data-dtp-prd-aa1a.smy`.ar_cst_dly_smy
                    where date(dt_id)  =vdt_id
                    and ar_lcs_tp_nm in ('ACTIVE','ACTIVE IN GRACE')
                    ) b 
                on a.b_msisdn=b.msisdn and a.dt_id=b.dt_id
                where a.dt_id  = vdt_id
                   ),
sp_ori as (
            select * from 
                    (
                    select a.*,
                         expired_date expired_date_normalisasi,
                        (case
                            when expired_date >= date(timestamp(current_datetime('+7'))) then 'No' else 'Expired'
                        end) exp_flag
                    from `data-bi-prd-935c.bi_mart`.stock_sp_data_mobii a
                    where dt_id = vdt_id 
                )a
            where  expired_date_normalisasi>dt_id
            ),
vou_ori as  (
                -- stock outlet vou mobii (vou ori)
                    select dt_id, organization_id, sum(amount) stock
                    from `data-bi-prd-935c.bi_mart`.stock_vo_ori_sellin
                    where dt_id  =vdt_id
                    and expired_date>dt_id
                    group by 1,2 
                    ),
vou_inj as (
                -- stock outlet vou mobo 
                    select dt_id, organization_id,sum(amount_debit) stock
                    from `data-bi-prd-935c.bi_mart`.stock_mobo_vou
                    where dt_id =vdt_id
                    group by 1,2
                ),
sso_outlet as (
            select distinct organization_id from 
            (
                select a.msisdn, a.dt_id ga_dt, a.site_id, organization_id, flag_quality, main_price_acm2, flag_sp,channel_grp
                from `data-bi-prd-935c.bi_mart`.rgs_ga_90d_dly_govt a
                join (select *
                        from `data-bi-prd-935c.bi_mart`.rgs_ga_channel_mth_govt 
                        where ga_dt between date_trunc(vdt_id,month) and vdt_id 
                       -- and main_price_acm2 >= 10000
                      )b
                on a.msisdn = b.msisdn and a.dt_id = b.ga_dt
                where dt_id between date_trunc(vdt_id,month) and vdt_id 
                and (churn_back = 'NO' or recycled = 'YES')
            )x 
        ),
dos_all as (
        select a.*, case -- when demand_30 is null then 0
                        when stock is null then 0
                        when stock <= 0 and (demand_30 is null or demand_30 = 0) then 0
                        when stock > 0 and (demand_30 is null or demand_30 = 0) then 30 -- cast(stock/30 as numeric)
                    else stock/demand_30
                    end as dos  
        from 
                (
            select  a.organization_id,  
                    sum(b.value) as  stock,  
                    sum(d.value) as  saldo, 
                    cast(sum(rev)/30 as numeric) as demand_30
            from  sso_outlet a
                left join 
                        (
                            select organization_id, sum(value) value
                            from 
                                (
                                -- sp
                                   select organization_id, sum(cast(amount_debit as numeric)) value from sp_mobo group by 1 
                                   union all 
                                   select dest_saldomobo_id organization_id, sum(cast(amount as numeric)) value from sp_ori group by 1
                                --   union all 
                                -- saldo
                                --   select short_code organization_id, sum(cast(saldo as numeric)) value from stock_saldo group by 1
                                --   union all 
                                -- voucher
                                --   select organization_id, sum(cast(stock as numeric)) value from vou_ori group by 1
                                --   union all 
                                --   select organization_id, sum(cast(stock as numeric)) value from vou_inj group by 1
                                )a
                            group by 1 
                        )b 
                    on a.organization_id=b.organization_id
                -- SALDO
                 left join 
                        (select short_code organization_id, sum(cast(saldo as numeric)) value 
                        from stock_saldo group by 1) d
                    on a.organization_id=d.organization_id
                -- DEMAND
                left join  (select organization_id, sum(rev) rev from demand_30 
                             where category in ('RELOAD','SP MOBO Y2','SP MOBO Y3','SP DATA') -- ,'VOU ORI','VOU REDEEM'
                             group by 1
                            ) c
                    on a.organization_id=c.organization_id
            group by 1
                )a
        )
-- stockout_outlet
select 'IM3' brand, 'outlet' level, organization_id as level_value, 
        cast(count(distinct organization_id) as numeric) value,
        'mtd' as time_flag, 
        timestamp(current_datetime('+7')) as insert_date,
        'sso_stockout_outlet' as kpi, 
        vdt_id as dt_id
from dos_all
where stock <=0 and saldo <=0
group by 1,2,3,5,6,7,8
union all 
-- outlet_3dy_stock
select 'IM3' brand, 'outlet' level, organization_id as level_value, 
        cast(count(distinct organization_id) as numeric) value,
        'mtd' as time_flag, 
        timestamp(current_datetime('+7')) as insert_date,
        'sso_outlet_3dy_stock' as kpi, 
        vdt_id as dt_id
from dos_all
where dos < 3 and saldo <100000
group by 1,2,3,5,6,7,8
;

--- STOCK 3 DAY LESS OUTLET IM3 (VOU - SP - SALDO)

delete from `data-bi-prd-935c.bi_dev`.ioh_snd_master_kpi_detail where brand = 'IM3' and kpi in ('stock_3dy_less_outlet','stock_3dy_less_outlet_sp','stock_3dy_less_outlet_vou','stock_3dy_less_outlet_saldo') and dt_id = vdt_id;
insert into `data-bi-prd-935c.bi_dev`.ioh_snd_master_kpi_detail
with stock_saldo as (
        select short_code, sum(cast(stock_balance as numeric)) saldo from 
        (
            select * from `data-bi-prd-935c.bi_mart`.outlet_stock_balance
            where dt_id =vdt_id
        )a 
        -- where category = 'SALDO MOBO-OUTLET'
        group by 1
        ),
    sp_mobo as  (
                select a.*
                from `data-bi-prd-935c.bi_mart`.stock_mobo_sp a
                join (
                    select date(dt_id) dt_id,msisdn from `data-dtp-prd-aa1a.smy`.ar_cst_dly_smy
                    where date(dt_id)  =vdt_id
                    and ar_lcs_tp_nm in ('ACTIVE','ACTIVE IN GRACE')
                    ) b 
                on a.b_msisdn=b.msisdn and a.dt_id=b.dt_id
                where a.dt_id = vdt_id
                   ),
    sp_ori as (
                select * from 
                    (
                    select a.*,
                         expired_date expired_date_normalisasi,
                        (case
                            when expired_date >= date(timestamp(current_datetime('+7'))) then 'No' else 'Expired'
                        end) exp_flag
                    from `data-bi-prd-935c.bi_mart`.stock_sp_data_mobii a
                    where dt_id = vdt_id 
                )a
                where  expired_date_normalisasi>dt_id
            ),
    vou_ori as  (
                     -- stock outlet vou mobii (vou ori)
                    select dt_id, organization_id, sum(amount) stock
                    from `data-bi-prd-935c.bi_mart`.stock_vo_ori_sellin
                    where dt_id  = vdt_id
                    and expired_date>dt_id
                    group by 1,2 
                    ),
     vou_inj as (
                    -- stock outlet vou mobo 
                    select dt_id, organization_id,sum(amount_debit) stock
                    from `data-bi-prd-935c.bi_mart`.stock_mobo_vou
                    where dt_id =vdt_id
                    group by 1,2
                ),
    demand_30 as (
                select organization_id, category, sum(rev)rev
                from 
                    (
                     select
                        a.organization_id, --> OUTLET NBS
                        a.site_bnum, --> FACLOC
                        a.b_msisdn,
                        '' flag_sp,
                        a.product_name,
                        '' expired_date,
                        '' exp_flag,
                        sum(a.hits)hit,
                        sum(a.amount_debit) rev,
                        vdt_id dt_id,
                        date_trunc(vdt_id,month) mth,  
                        'Demand 30' type,  
                        tertiary_type as category 
                    from `data-bi-prd-935c.bi_mart`.fact_snd_tertiary_dtl a 
                    where
                        (
                            a.dt_id >= vdt_id - interval 30 day 
                            and a.dt_id <= vdt_id      
                        )
                    and a.channel_grp in ('Traditional')
                    group by 1,2,3,4,5,6,7,10,11,12,13
                    )a
                    group by 1,2
                ),
    outlet_mapping as (select distinct id_outlet from `data-bi-prd-935c.bi_snd.pre_ref_outlet_mapping_im3` where parse_date('%Y%m',cast(mth_id as string))=date_trunc(vdt_id,month)),
    dos_all as (
        select a.*, case -- when demand_30 is null then 0
                        when stock is null then 0
                        when stock <= 0 and (demand_30 is null or demand_30 = 0) then 0
                        when stock > 0 and (demand_30 is null or demand_30 = 0) then 30 -- cast(stock/30 as numeric)
                    else stock/demand_30
                    end as dos  
        from 
                (
            select a.id_outlet as organization_id,  
                    sum(b.value) as  stock,  
                    sum(d.value) as  saldo, 
                    cast(sum(rev)/30 as numeric) as demand_30
            from  outlet_mapping a
                left join 
                        (
                            select organization_id, sum(value) value
                            from 
                                (
                                -- sp
                                   select organization_id, sum(cast(amount_debit as numeric)) value from sp_mobo group by 1 
                                   union all 
                                   select dest_saldomobo_id organization_id, sum(cast(amount as numeric)) value from sp_ori group by 1
                                --   union all 
                                -- saldo
                                --   select short_code organization_id, sum(cast(saldo as numeric)) value from stock_saldo group by 1
                                --   union all 
                                -- voucher
                                --   select organization_id, sum(cast(stock as numeric)) value from vou_ori group by 1
                                --   union all 
                                --   select organization_id, sum(cast(stock as numeric)) value from vou_inj group by 1
                                )a
                            group by 1 
                        )b 
                    on a.id_outlet=b.organization_id
                -- SALDO
                 left join 
                        (select short_code organization_id, sum(cast(saldo as numeric)) value 
                        from stock_saldo group by 1) d
                    on a.id_outlet=d.organization_id
                left join  (select organization_id, sum(rev) rev from demand_30 
                             where category in ('RELOAD','SP MOBO Y2','SP MOBO Y3','SP DATA') -- ,'VOU ORI','VOU REDEEM'
                             group by 1
                            ) c
                    on a.id_outlet=c.organization_id
            group by 1
                )a
        ),
    dos_sp as (
        select a.*, case -- when demand_30 is null then 0
                         when stock is null then 0
                        when stock <= 0 and (demand_30 is null or demand_30 = 0) then 0
                        when stock > 0 and (demand_30 is null or demand_30 = 0) then 30 -- cast(stock/30 as numeric)
                    else stock/demand_30 
                    end as dos 
        from 
                (
            select a.id_outlet as organization_id,  
                    sum(value) as  stock,  
                    cast(sum(rev)/30 as numeric) as  demand_30
            from  outlet_mapping a
                left join 
                        (
                            select organization_id, sum(value) value
                            from 
                                (
                                -- sp
                                   select organization_id, sum(cast(amount_debit as numeric)) value from sp_mobo group by 1 
                                   union all 
                                   select dest_saldomobo_id organization_id, sum(cast(amount as numeric)) value from sp_ori group by 1
                                )a
                            group by 1 
                        )b 
                    on a.id_outlet=b.organization_id
                left join 
                       (select organization_id, sum(rev) rev  from demand_30 
                       -- where category not in ('RELOAD','VOU RLD','SP MOBO Y2','SP MOBO Y3','VOU ORI')
                        where category in ('SP MOBO Y2','SP DATA')
                        group by 1
                       ) c  -- SP ORI
                    on a.id_outlet=c.organization_id
            group by 1
                )a
        ),
    dos_vou as (
        select a.*, case -- when demand_30 is null then 0
                        when stock is null then 0
                        when stock <= 0 and (demand_30 is null or demand_30 = 0) then 0
                        when stock > 0 and (demand_30 is null or demand_30 = 0) then 30 -- cast(stock/30 as numeric)
                    else stock/demand_30
                    end as dos 
        from 
                (
            select a.id_outlet as organization_id,  
                    sum(value) as  stock,  
                    cast(sum(rev)/30 as numeric) as demand_30
            from  outlet_mapping a
                left join 
                        (
                            select organization_id, sum(value) value
                            from 
                                (
                                -- voucher
                                   select organization_id, sum(cast(stock as numeric)) value from vou_ori group by 1
                                   union all 
                                   select organization_id, sum(cast(stock as numeric)) value from vou_inj group by 1
                                )a
                            group by 1 
                        )b 
                    on a.id_outlet=b.organization_id
                left join 
                        (select organization_id, sum(rev) rev  from demand_30 where category in ('VOU ORI','VOU REDEEM')
                         group by 1
                        ) c -- VOU
                    on a.id_outlet=c.organization_id
            group by 1
                )a
        ),
    dos_saldo as (
        select a.*, -- case -- when demand_30 is null then 0
                    --     when stock is null then 0
                    --    when stock <= 0 and (demand_30 is null or demand_30 = 0) then 0
                    --    when stock > 0 and (demand_30 is null or demand_30 = 0) then 30 -- cast(stock/30 as numeric)
                    -- else stock/demand_30
                    -- end as dos 
                    case when stock < 100000 then 1 else 0 end dos
        from 
                (
            select a.id_outlet as organization_id,  
                    sum(value) as stock,  
                    cast(sum(rev)/30 as numeric) as demand_30
            from  outlet_mapping a
                left join 
                        (
                            select organization_id, sum(value) value
                            from 
                                (
                                -- saldo
                                   select short_code organization_id, sum(cast(saldo as numeric)) value from stock_saldo group by 1
                                )a
                            group by 1 
                        )b 
                    on a.id_outlet=b.organization_id
                left join  
                        (select organization_id, sum(rev) rev  from demand_30 where category in ('RELOAD','SP MOBO Y3')
                         group by 1
                        ) c -- SALDO
                    on a.id_outlet=c.organization_id
            group by 1
                )a
        )
    -- outlet_3dy_less_stock
        select 'IM3' brand, 'outlet' level, organization_id as level_value, 
                cast(count(distinct organization_id) as numeric) value,
                'mtd' as time_flag, 
                timestamp(current_datetime('+7')) as insert_date,
                'stock_3dy_less_outlet' as kpi,
                vdt_id as dt_id
        from dos_all
        where dos < 3 and saldo <100000
        group by 1,2,3,5,6,7,8
    union all
    -- outlet_3dy_less_stock_sp
        select 'IM3' brand, 'outlet' level, organization_id as level_value, 
                cast(count(distinct organization_id) as numeric) value,
                'mtd' as time_flag, 
                timestamp(current_datetime('+7')) as insert_date,
                'stock_3dy_less_outlet_sp' as kpi,
                vdt_id as dt_id
        from dos_sp
        where dos < 3
        group by 1,2,3,5,6,7,8
    union all
    -- outlet_3dy_less_stock_vou
        select 'IM3' brand, 'outlet' level, organization_id as level_value, 
                cast(count(distinct organization_id) as numeric) value,
                'mtd' as time_flag, 
                timestamp(current_datetime('+7')) as insert_date,
                'stock_3dy_less_outlet_vou' as kpi,
                vdt_id as dt_id
        from dos_vou
        where dos < 3
        group by 1,2,3,5,6,7,8
    union all
    -- outlet_3dy_less_stock_saldo
        select 'IM3' brand, 'outlet' level, organization_id as level_value, 
                cast(count(distinct organization_id) as numeric) value,
                'mtd' as time_flag, 
                timestamp(current_datetime('+7')) as insert_date,
                'stock_3dy_less_outlet_saldo' as kpi,
                vdt_id as dt_id
        from dos_saldo
        where dos = 1
        group by 1,2,3,5,6,7,8
;


--- STOCK SP OUTLET CNT 

delete from `data-bi-prd-935c.bi_dev`.ioh_snd_master_kpi_detail where brand = 'IM3' and kpi in ('stock_sp_outlet_cnt','stock_sp_outlet_sp35k_below', 'stock_sp_outlet_sp35k_above','stock_sp_outlet_sp0', 'stock_sp_outlet_sp35k'  ) and dt_id = vdt_id;
insert into `data-bi-prd-935c.bi_dev`.ioh_snd_master_kpi_detail 
with 
stock as (
        -- stock outlet sp mobo  
        select organization_id, product_name, flag_sp_35K,  b_msisdn msisdn, cast(amount_debit as numeric) stock_amt from 
            (
                select a.*, 
                    case when svc_class_code = '8139' then 'stock_sp_outlet_sp35k'
                         when  upper(a.product_name) like 'SP 3GB ORI 0725%' then 'stock_sp_outlet_sp35k'
                         when (upper(a.product_name) in ('PERDANA 3 GB/30HARI', 'PERDANA INTERNET 3GB/30HR', 'ULNEW3GBSPMAR25MO','SP IM3 3GB NEW') 
                                            or upper(a.product_name) like 'PERDANA INTERNET ONLINE 3GB%') then 'stock_sp_outlet_sp35k'
                         when upper(product_name) like '%ZERO%' then 'stock_sp_outlet_sp0'
                         when a.main_price >= 35000 then 'stock_sp_outlet_sp35k_above'
                        else 'stock_sp_outlet_sp35k_below'
                    end flag_sp_35K
                --    ROW_NUMBER() OVER (partition by a.b_msisdn ORDER BY a.inj_dt_id desc) AS rn 
                from `data-bi-prd-935c.bi_mart`.stock_mobo_sp a
                join (
                            select date(dt_id) dt_id,msisdn, svc_class_code from `data-dtp-prd-aa1a.smy`.ar_cst_dly_smy
                            where date(dt_id)  =vdt_id
                            and ar_lcs_tp_nm in ('ACTIVE','ACTIVE IN GRACE')
                            ) b 
                on a.b_msisdn=b.msisdn and a.dt_id=b.dt_id
                where a.dt_id  =vdt_id
               -- and a.inj_dt_id >=from_timestamp(date_add(to_date(from_unixtime(unix_timestamp(vdt_id,'yyyyMMdd'))),-360),'yyyyMMdd')
            )a 
           -- where rn =1
        union all
        -- stock outlet sp data mobii (sp ori)
        select dest_saldomobo_id as organization_id, product_name,  flag_sp_35K, msisdn,  cast(amount as numeric) stock_amt 
        from 
        (
        select a.*,
            case when svc_class_code = '8139' then 'stock_sp_outlet_sp35k'
                 when  upper(a.product_name) like 'SP 3GB ORI 0725%' then 'stock_sp_outlet_sp35k'
                 when (upper(a.product_name) in ('PERDANA 3 GB/30HARI', 'PERDANA INTERNET 3GB/30HR', 'ULNEW3GBSPMAR25MO','SP IM3 3GB NEW') 
                        or upper(a.product_name) like 'PERDANA INTERNET ONLINE 3GB%') then 'stock_sp_outlet_sp35k'
                 when upper(a.product_name) like '%ZERO%' then 'stock_sp_outlet_sp0'
                 when a.amount >= 35000 then 'stock_sp_outlet_sp35k_above'
                 else 'stock_sp_outlet_sp35k_below'
            end flag_sp_35K
            -- dt_id, dest_saldomobo_id organization_id ,  sum(cast(amount as numeric)) stock
        from `data-bi-prd-935c.bi_mart`.stock_sp_data_mobii a
        left join (
                            select date(dt_id) dt_id,msisdn, svc_class_code from `data-dtp-prd-aa1a.smy`.ar_cst_dly_smy
                            where date(dt_id)  =vdt_id
                            and ar_lcs_tp_nm in ('ACTIVE','ACTIVE IN GRACE')
                    ) b 
            on a.msisdn=b.msisdn and a.dt_id=b.dt_id
        where a.dt_id  =vdt_id
        and expired_date>a.dt_id
        -- group by 1,2 
        )a
)
---- summary by sp35k flag
select 'IM3' brand, 'outlet' level, organization_id as level_value, 
    cast(count(distinct msisdn) as numeric) value, 
    'mtd' as time_flag, 
     timestamp(current_datetime('+7')) as insert_date,
    flag_sp_35k as kpi, 
    vdt_id as dt_id
from stock a 
group by 1,2,3,5,6,7,8
union all 
---- summary all
select 'IM3' brand, 'outlet' level, organization_id as level_value, 
    cast(count(distinct msisdn) as numeric) value, 
    'mtd' as time_flag, 
     timestamp(current_datetime('+7')) as insert_date,
    'stock_sp_outlet_cnt' as kpi, 
    vdt_id as dt_id
from stock a 
group by 1,2,3,5,6,7,8
;


--- STOCK VOU OUTLET CNT

-- delete from `data-bi-prd-935c.bi_dev`.ioh_snd_master_kpi_detail where brand = 'IM3' and kpi =  'stock_vou_outlet_cnt' and dt_id = vdt_id;-- 
-- insert into `data-bi-prd-935c.bi_dev`.ioh_snd_master_kpi_detail
-- with vou_ori as  (
--                  -- stock outlet vou mobii (vou ori)
--                 select dt_id, organization_id, count(distinct sno) stock
--                 from `data-bi-prd-935c.bi_mart`.stock_vo_ori_sellin
--                 where dt_id  =vdt_id
--                 and expired_date>dt_id
--                 group by 1,2 
--                 ),
-- vou_inj as (
--             -- stock outlet vou mobo 
--             select dt_id, organization_id,sum(amount_debit) stock
--             from `data-bi-prd-935c.bi_mart`.stock_mobo_vou
--             where dt_id =vdt_id
--             group by 1,2
--             )
-- -- STOCK VOU
-- select 'IM3' brand, 'outlet' level, organization_id as level_value, 
--     sum(cast(stock as numeric)) value,
--     'mtd' as time_flag, 
--      timestamp(current_datetime('+7')) as insert_date,
--     'stock_vou_outlet_cnt' as kpi, 
--     vdt_id as dt_id
-- from 
--     ( select * from vou_ori 
--      --   union all 
--      -- select * from vou_inj
--     )a
-- group by 1,2,3,5,6,7,8
-- ;

--- Insert to table Summary

-- create table `data-bi-prd-935c.bi_dev`.ioh_snd_master_kpi_detail_smy partitioned by (kpi,dt_id) stored as parquet as
delete from `data-bi-prd-935c.bi_dev`.ioh_snd_master_kpi_detail_smy where brand = 'IM3' and kpi in 
        ('stock_with_dist','stock_with_outlet','demand_30',
         'stock_saldo_outlet','demand_30_saldo','stock_sp_outlet','demand_30_sp',
         'stock_vou_outlet','demand_30_vou',
         'stockout_outlet','stockout_outlet_saldo','stockout_outlet_vou','stockout_outlet_sp',
         'stock_less_outlet','sso_stockout_outlet','sso_outlet_3dy_stock',
         'stock_3dy_less_outlet','stock_3dy_less_outlet_sp','stock_3dy_less_outlet_vou','stock_3dy_less_outlet_saldo'
         ,'stock_sp_outlet_cnt'
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
        ('stock_with_dist','stock_with_outlet','demand_30',
         'stock_saldo_outlet','demand_30_saldo','stock_sp_outlet','demand_30_sp',
         'stock_vou_outlet','demand_30_vou',
         'stockout_outlet','stockout_outlet_saldo','stockout_outlet_vou','stockout_outlet_sp',
         'stock_less_outlet','sso_stockout_outlet','sso_outlet_3dy_stock',
         'stock_3dy_less_outlet','stock_3dy_less_outlet_sp','stock_3dy_less_outlet_vou','stock_3dy_less_outlet_saldo'
         ,'stock_sp_outlet_cnt'
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