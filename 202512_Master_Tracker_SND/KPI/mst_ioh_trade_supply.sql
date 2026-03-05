   declare vdt_id date default @vdt_id;

--IM3

-------  TRADE SUPPLY  --------------
delete from `data-bi-prd-935c.bi_dev`.ioh_snd_master_kpi_detail where kpi in ('trade_supply', 'site_trade_supply')
and dt_id = vdt_id and brand = 'IM3';
insert into `data-bi-prd-935c.bi_dev`.ioh_snd_master_kpi_detail
with trade_supply as (
        --SELLIN--
        select
            safe.parse_date('%d-%b-%Y',left(transaction_datetime,11)) dt_id,
            saldomobo_id mpc,
            dest_saldomobo_id outlet,
            distribution_type,
            product_category,
            product_name,
            count(*) qty,
            sum(cast(price as numeric)) amt
        from
            `data-dtp-prd-aa1a.stg`.mobii_physical_distribution 
        where
            (
                date_trunc(safe.parse_date('%d-%b-%Y',left(transaction_datetime,11)),month) between date_trunc(vdt_id,month)
                and vdt_id
                and dt_id between timestamp(date_trunc(vdt_id,month))
                and timestamp(vdt_id + interval 1 month)
            )
            and distribution_type in ('Sell In')
            and product_category in ('Starter Pack', 'Voucher')
            and (
                    product_name not in ('SF IM3 0 LTE','SP IM3 90D LTE (QN)','SP ZERO IM3 90D')
                    or product_name not like '%TEST%'
                )
            and (saldomobo_id LIKE '%D%' or saldomobo_id LIKE 'SDP%')
            and dest_saldomobo_id not like '%D%' 
        group by
            1,2,3,4,5,6
        union all
        --INJECT--
        select 
            safe.parse_date('%Y-%m-%d',left(`datetime`,10)) dt_id,
            a.l1_parent_id,
            a.organization_id,
            'Inj' type,
            (case
                when lower(transaction_type) like '%package%' then 'PAKET'
                when lower(transaction_type) like '%voucher%' then 'VOU'
            end) product_category,
            a.product_name,
            count(a.transaction_id) hit,
            sum(cast(case when lower(a.transaction_type) in ('evoucher') then a.amount_debit
                        else a.main_price 
                     end as numeric)) amt
            -- sum(cast(a.main_price as numeric)) amt
        from `data-dtp-prd-aa1a.stg`.ifrs_prepaid_salmo a 
        where 
        date_trunc(safe.parse_date('%Y-%m-%d',left(`datetime`,10)),month) between date_trunc(vdt_id,month) and  vdt_id 
        and date(process_id) between  date_trunc(vdt_id,month) and  vdt_id + interval 1 month
            and a.status_description = 'Success' 
            and a.transaction_status = 'Completed' 
            and lower(a.channel) like '%traditional%' 
            and lower(a.organization_type) like '%outlet%' 
            and (upper(a.organization_id) not like '%DS%' and upper(a.organization_id) not like '%SF%') 
            and lower(a.transaction_type) in ('purchase data package','bulk purchase package transaction','vouchercardinjection','bulk voucher card injection','evoucher')
            and (upper(a.cluster) not like '%TEST%' and upper(a.cluster) not like '%SEV%') 
            and upper(a.product_name) not like 'PULSA%'
            and coalesce(substring(b_msisdn, 1,5),'') not in ('62895', '62896', '62897', '62898', '62899')
        group by
            1,2,3,4,5,6
),
nbs as (
          select * from 
                    (select dt_id, site_id,region, circle, area,sales_area,sales_cluster,
                        micro_cluster,organization_id,organization_name, 
                        ROW_NUMBER() OVER (partition by organization_id ORDER BY dt_id desc) AS rn 
                        from `data-bi-prd-935c.bi_mart`.outlet_loc_ns where date_trunc(dt_id,month)<= date_trunc(vdt_id,month)
            ) a where rn=1 
        )
-- TRADE SUPPLY 
select 'IM3' brand, 'outlet' level, outlet as level_value, 
    sum(cast(amt as numeric)) value, 
    'mtd' as time_flag, 
     timestamp(current_datetime('+7')) as insert_date,
    'trade_supply' as kpi_id, 
    vdt_id dt_id
from trade_supply
group by 1,2,3,5,6,7,8
union all 
--- SITE TRADE SUPPLY 
select 'IM3' brand, 'site' level, site_id as level_value, 
    cast(sum(amt) as numeric) value, 
    'mtd' as time_flag, 
     timestamp(current_datetime('+7')) as insert_date,
     'site_trade_supply' as kpi_id, 
     vdt_id as dt_id
from 
    (
    select a.outlet, b.site_id, sum(amt)amt
        from trade_supply a
        left join nbs b 
    on a.outlet=b.organization_id 
    group by 1,2
    )a
group by 1,2,3,5,6,7,8
;

--3ID
--- chain snd funnel related 

DELETE FROM `data-bi-prd-935c.bi_dev`.ioh_snd_master_kpi_detail
WHERE lower(kpi) IN ('trade_supply') AND dt_id = vdt_id and level='site_id' and brand = '3ID';

INSERT INTO `data-bi-prd-935c.bi_dev`.ioh_snd_master_kpi_detail
SELECT '3ID' as brand,
'site_id' level,
coalesce(site_id, 'N/A') level_value,
sum(cast(net as numeric))val,
'mtd' time_flag,
timestamp(current_datetime('+7')) insert_date,
lower('trade_supply')kpi,
vdt_id dt_id
FROM
(
    --- 1. Trade Supply Voucher (UNLOCK REGULAR_VOUCHER SUPPLY)
    SELECT vdt_id dt ,partner_qr_cd,site_id,sum(net_Revenue) net
    FROM `data-bi-prd-935c.bi_mart`.dm_snd_voucher a
    LEFT JOIN (SELECT * from `data-bi-prd-935c.bi_mart`.angie_hrchy_dim_hst where hrchy_type='Retailer' and partner_Status='Active' and mth=date_trunc(vdt_id,month) ) b on a.qr_Cd=b.partner_qr_cd
    LEFT OUTER JOIN
    (
        SELECT ret_qr_cd,site_id
        FROM (SELECT dt,ret_qr_cd,site_id,row_number() over (partition by ret_qr_cd order by dt desc) rnk
        FROM `data-bi-prd-935c.bi_mart`.stg_v_map_tgt_ret_details_hist
        WHERE site_id <>'' and dt<=vdt_id) x WHERE rnk=1
    ) c on a.qr_Cd=c.ret_qr_cd
    WHERE sd_type='SUPPLY'
    AND package_type='UNLOCK'
    AND voucher_type in ('REGULAR_VOUCHER','ORI_VOUCHER')
    AND a.dt BETWEEN date_trunc(vdt_id,month) AND vdt_id
    AND upper(bm_location ) NOT IN
    (
        'DVM BM','3 BUSINESS','SIM ONLINE','NA','POOL','3 STORE',
        'SOUTH JAKARTA TEST BM','BSM TRI OFFICIAL STORE'
    )
    GROUP BY 1,2,3

    UNION ALL

    --- 2. Trade Supply RITA (E TOP UP DEMAND/Top Up)
    SELECT vdt_id dt ,a.qr_cd,site_id,sum(net_Revenue)
    FROM `data-bi-prd-935c.bi_mart`.dm_snd_voucher a
    LEFT JOIN (SELECT * from `data-bi-prd-935c.bi_mart`.angie_hrchy_dim_hst where hrchy_type='Retailer' and partner_Status='Active' and mth=date_trunc(vdt_id,month) ) b on a.qr_Cd=b.partner_qr_cd
    LEFT OUTER JOIN
    (
        SELECT ret_qr_cd,site_id
        FROM (SELECT dt,ret_qr_cd,site_id,row_number() over (partition by ret_qr_cd order by dt desc) rnk
        FROM `data-bi-prd-935c.bi_mart`.stg_v_map_tgt_ret_details_hist
        WHERE site_id <>'' and dt<=vdt_id) x WHERE rnk=1
    ) c on a.qr_Cd=c.ret_qr_cd
    WHERE sd_type='DEMAND'
    AND package_type='RITA'
    AND voucher_type='E TOP UP'
    AND a.dt BETWEEN date_trunc(vdt_id,month) AND vdt_id
    AND upper(bm_location ) NOT IN
    (
        'DVM BM','3 BUSINESS','SIM ONLINE','NA','POOL','3 STORE',
        'SOUTH JAKARTA TEST BM','BSM TRI OFFICIAL STORE'
    )
    GROUP BY 1,2,3

    UNION ALL

    --- 3. Trade Supply FRC
    SELECT vdt_id dt ,a.partner_qr_cd,site_id,sum(net_Revenue)
    FROM `data-bi-prd-935c.bi_mart`.dm_snd_demand_frc a
    LEFT JOIN (SELECT * from `data-bi-prd-935c.bi_mart`.angie_hrchy_dim_hst where hrchy_type='Retailer' and partner_Status='Active' and mth=date_trunc(vdt_id,month) ) b on a.partner_qr_cd=b.partner_qr_cd
    LEFT OUTER JOIN
    (
        SELECT ret_qr_cd,site_id
        FROM (SELECT dt,ret_qr_cd,site_id,row_number() over (partition by ret_qr_cd order by dt desc) rnk
        FROM `data-bi-prd-935c.bi_mart`.stg_v_map_tgt_ret_details_hist
        WHERE site_id <>'' and dt<=vdt_id) x WHERE rnk=1
    ) c on a.partner_qr_cd=c.ret_qr_cd
    WHERE sd_type='SUPPLY'
    AND a.dt BETWEEN date_trunc(vdt_id,month) AND vdt_id
    AND upper(bm_location ) NOT IN
    (
        'DVM BM','3 BUSINESS','SIM ONLINE','NA','POOL','3 STORE',
        'SOUTH JAKARTA TEST BM','BSM TRI OFFICIAL STORE'
    )
    GROUP BY 1,2,3
) supply
GROUP BY 1,2,3,5,7,8 ;
