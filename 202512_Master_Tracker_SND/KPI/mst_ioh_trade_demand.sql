   declare vdt_id date default @vdt_id;

--IM3
----- TRADE DEMAND ---- 
delete from `data-bi-prd-935c.bi_dev`.ioh_snd_master_kpi_detail where kpi = 'trade_demand' and dt_id = vdt_id and brand = 'IM3';
insert into `data-bi-prd-935c.bi_dev`.ioh_snd_master_kpi_detail
with trade_demand as (
            select site_bnum, sum(amount_debit) amount
            from `data-bi-prd-935c.bi_mart`.fact_snd_tertiary_dtl
            where dt_id between date_trunc(vdt_id,month) and vdt_id 
                and channel_grp in ('Traditional')
                and tertiary_type not in ('RELOAD','SP ZERO','VOU RLD')
            group by 1 
            )
-- trade demand
select 'IM3' brand, 'site' level, site_bnum as level_value, 
    sum(cast(amount as numeric)) value, 
    'mtd' as time_flag, 
     timestamp(current_datetime('+7')) as insert_date,
    'trade_demand' as kpi_id, 
    vdt_id dt_id
from trade_demand a
group by 1,2,3,5,6,7,8
;

----- TRADE DEMAND INNER & OUTER ---- 
delete from `data-bi-prd-935c.bi_dev`.ioh_snd_master_kpi_detail where kpi in ('trade_demand_outer','trade_demand_inner') and dt_id = vdt_id and brand = 'IM3';
insert into `data-bi-prd-935c.bi_dev`.ioh_snd_master_kpi_detail
with trade_demand as (
            select site_outlet, site_bnum, sum(amount_debit) amount
            from `data-bi-prd-935c.bi_mart`.fact_snd_tertiary_dtl
            where dt_id between date_trunc(vdt_id,month) and vdt_id 
                and channel_grp in ('Traditional')
                and tertiary_type not in ('RELOAD','SP ZERO','VOU RLD')
            group by 1,2
            ),
ref_site_outlet as (
        select distinct site_id, circle, region, area, sales_area, sales_cluster, micro_cluster, concat(kecamatan_nm,'|',kabkot_nm) kec_unik, month_id
        from `data-bi-prd-935c.bi_mart`.ref_site_mth
        where month_id = date_trunc(vdt_id,month) 
            ),
ref_site_bnum as (
        select distinct site_id, circle, region, area, sales_area, sales_cluster, micro_cluster, concat(kecamatan_nm,'|',kabkot_nm) kec_unik, month_id
        from `data-bi-prd-935c.bi_mart`.ref_site_mth
        where month_id = date_trunc(vdt_id,month) 
            )
-- trade demand inner & outer
select 'IM3' brand, 'site' level, site_bnum as level_value, 
    sum(cast(amount as numeric)) value, 
    'mtd' as time_flag, 
     timestamp(current_datetime('+7')) as insert_date,
    case when parameter = 'trade demand inner' then 'trade_demand_inner' 
         else 'trade_demand_outer'  
    end kpi_id, 
    vdt_id dt_id
from 
(
select site_bnum, 
     case
        when b.sales_area =  c.sales_area then 'trade demand inner' else 'trade demand outer'
    end  parameter,
    sum(amount) amount
from trade_demand a  
left join ref_site_outlet b
        on a.site_outlet=b.site_id
left join ref_site_bnum c
        on a.site_bnum=c.site_id
group by 1,2 
)a
group by 1,2,3,5,6,7,8
;

--3ID
--- chain snd funnel related 

DELETE
FROM `data-bi-prd-935c.bi_dev`.ioh_snd_master_kpi_detail
WHERE kpi in
(
    'trade_demand'
)
AND dt_id = vdt_id AND level = 'site_id' AND time_flag = 'mtd' and brand = '3ID';


INSERT INTO `data-bi-prd-935c.bi_dev`.ioh_snd_master_kpi_detail
SELECT '3ID',
'site_id',
coalesce(siteid_bnum,c.site_id) ,
sum(coalesce(amount,0)) kpi_value,
'mtd',
timestamp(current_datetime('+7')),
'trade_demand',
vdt_id dt_id
FROM `data-bi-prd-935c.bi_mart`.project_ioh_tertiary_outlet a
LEFT JOIN `data-bi-prd-935c.bi_mart`.angie_hrchy_dim_hst b ON b.partner_qr_cd = a.dealer_id AND date_trunc(a.dt_sk_id,month) = b.mth
LEFT JOIN
(
    SELECT ret_qr_cd,site_id
    FROM
    (
        SELECT dt,ret_qr_cd,site_id,row_number() over (partition by ret_qr_cd order by dt desc) rnk
        FROM `data-bi-prd-935c.bi_mart`.stg_v_map_tgt_ret_details_hist
        WHERE date_trunc(dt,month) = date_trunc(vdt_id,month) AND site_id <>''
    ) x WHERE rnk=1
) c ON a.dealer_id=c.ret_qr_cd
WHERE dt_sk_id between date_trunc(vdt_id,month) AND  vdt_id
AND tertiary_category IN ('SALDO','FRC','UNLOCK') AND length(dealer_id) < 10
AND upper(mp3_location) NOT IN
(
    'POOL',
    'DVM BM',
    'SIM ONLINE',
    'BSM TRI OFFICIAL STORE',
    '3 STORE',
    'SOUTH JAKARTA TEST BM'
)
AND tertiary_type NOT LIKE '%PULSA%'
GROUP BY 1,2,3,5,6,7,8;


DELETE
FROM `data-bi-prd-935c.bi_dev`.ioh_snd_master_kpi_detail
WHERE kpi in
(
    'trade_demand'
)
AND dt_id = vdt_id AND level = 'outlet' AND time_flag = 'mtd' and brand = '3ID';


INSERT INTO `data-bi-prd-935c.bi_dev`.ioh_snd_master_kpi_detail
SELECT '3ID',
'outlet',
dealer_id ,
sum(coalesce(amount,0)) kpi_value,
'mtd',
timestamp(current_datetime('+7')),
'trade_demand',
vdt_id dt_id
FROM `data-bi-prd-935c.bi_mart`.project_ioh_tertiary_outlet a
LEFT JOIN `data-bi-prd-935c.bi_mart`.angie_hrchy_dim_hst b ON b.partner_qr_cd = a.dealer_id AND date_trunc(a.dt_sk_id,month) = b.mth
LEFT JOIN
(
    SELECT ret_qr_cd,site_id
    FROM
    (
        SELECT dt,ret_qr_cd,site_id,row_number() over (partition by ret_qr_cd order by dt desc) rnk
        FROM `data-bi-prd-935c.bi_mart`.stg_v_map_tgt_ret_details_hist
        WHERE date_trunc(dt,month) = date_trunc(vdt_id,month) AND site_id <>''
    ) x WHERE rnk=1
) c ON a.dealer_id=c.ret_qr_cd
WHERE dt_sk_id between date_trunc(vdt_id,month) AND  vdt_id
AND tertiary_category IN ('SALDO','FRC','UNLOCK') AND length(dealer_id) < 10
AND upper(mp3_location) NOT IN
(
    'POOL',
    'DVM BM',
    'SIM ONLINE',
    'BSM TRI OFFICIAL STORE',
    '3 STORE',
    'SOUTH JAKARTA TEST BM'
)
AND tertiary_type NOT LIKE '%PULSA%'
GROUP BY 1,2,3,5,6,7,8;