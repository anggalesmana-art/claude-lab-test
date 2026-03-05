declare vdt_id date default @vdt_id;

    
    -- ========== PRIMARY TRAD KPI ==========

    DELETE FROM `data-bi-prd-935c.bi_dev`.ioh_snd_master_kpi_detail
    WHERE brand = '3ID' and kpi in ('primary_opt','primary_cuanweb','primary_retailer_cashback')   AND dt_id = vdt_id;
    
    INSERT INTO `data-bi-prd-935c.bi_dev`.ioh_snd_master_kpi_detail
    SELECT '3ID',
    'partner',
    mp3_id,
    SUM(value),
    'mtd',
    timestamp(current_datetime('+7')),
    case when flag ='retailer_cashback'  then 'primary_retailer_cashback' else flag end ,
    dt_id 
    FROM `data-bi-prd-935c.bi_dev.mis_snd_prisec_detail` 
    WHERE kpi_name = 'primary' 
      AND flag IN ('primary_opt','primary_cuanweb','retailer_cashback') 
      AND dt_id = vdt_id
    GROUP BY 1,2,3,5,6,7,8;

    -- ========== PRIMARY TRAD SALDO KPI ==========
    DELETE FROM `data-bi-prd-935c.bi_dev`.ioh_snd_master_kpi_detail
    WHERE brand = '3ID' and kpi = 'primary_trad_saldo' AND dt_id = vdt_id;
    
    INSERT INTO `data-bi-prd-935c.bi_dev`.ioh_snd_master_kpi_detail
    SELECT '3ID',
    'partner',
    mp3_id,
    SUM(value),
    'mtd',
    timestamp(current_datetime('+7')),
    'primary_trad_saldo',
    dt_id 
    FROM `data-bi-prd-935c.bi_dev.mis_snd_prisec_detail` 
    WHERE kpi_name = 'primary' 
      AND flag IN ('primary_opt','primary_cuanweb','retailer_cashback') 
      AND dt_id = vdt_id
    GROUP BY 1,2,3,5,6,7,8;

    -- ========== PRIMARY TRAD SP ZERO KPI ==========
    DELETE FROM `data-bi-prd-935c.bi_dev`.ioh_snd_master_kpi_detail
    WHERE brand = '3ID' and kpi = 'primary_trad_sp_zero' AND dt_id = vdt_id;
    
    INSERT INTO `data-bi-prd-935c.bi_dev`.ioh_snd_master_kpi_detail
    SELECT '3ID',
    'partner',
    mp3_id,
    SUM(value),
    'mtd',
    timestamp(current_datetime('+7')),
    'primary_trad_sp_zero',
    dt_id 
    FROM `data-bi-prd-935c.bi_dev.mis_snd_prisec_detail` 
    WHERE kpi_name = 'primary' 
      AND flag IN ('sp0') 
      AND dt_id = vdt_id
    GROUP BY 1,2,3,5,6,7,8;

    -- ========== PRIMARY TRAD VOUORI KPI ==========
    DELETE FROM `data-bi-prd-935c.bi_dev`.ioh_snd_master_kpi_detail
    WHERE brand = '3ID' and kpi = 'primary_trad_vouori' AND dt_id = vdt_id;
    
    INSERT INTO `data-bi-prd-935c.bi_dev`.ioh_snd_master_kpi_detail
    SELECT '3ID',
    'partner',
    mp3_id,
    SUM(value),
    'mtd',
    timestamp(current_datetime('+7')),
    'primary_trad_vouori',
    dt_id 
    FROM `data-bi-prd-935c.bi_dev.mis_snd_prisec_detail` 
    WHERE kpi_name = 'primary' 
      AND flag IN ('spv0') 
      AND dt_id = vdt_id
    GROUP BY 1,2,3,5,6,7,8;

    -- ========== SECONDARY TRAD KPI - OUTLET LEVEL ==========
    DELETE FROM `data-bi-prd-935c.bi_dev`.ioh_snd_master_kpi_detail
    WHERE brand = '3ID' and kpi = 'secondary_trad' AND dt_id = vdt_id AND level = 'outlet';
    
    INSERT INTO `data-bi-prd-935c.bi_dev`.ioh_snd_master_kpi_detail
    SELECT '3ID',
    'outlet',
    qr_code,
    SUM(value),
    'mtd',
    timestamp(current_datetime('+7')),
    'secondary_trad',
    dt_id 
    FROM `data-bi-prd-935c.bi_dev.mis_snd_prisec_detail` a 
    WHERE a.kpi_name = 'secondary' 
      AND TRIM(LOWER(a.flag)) IN ('retailer_cashback','saldo','return to mp3','spv0','sp0') 
      AND a.dt_id = vdt_id 
    GROUP BY 1,2,3,5,6,7,8;

    -- ========== SECONDARY TRAD KPI - SITE LEVEL ==========
    DELETE FROM `data-bi-prd-935c.bi_dev`.ioh_snd_master_kpi_detail
    WHERE brand = '3ID' and kpi = 'secondary_trad' AND dt_id = vdt_id AND level = 'site_id';
    
    INSERT INTO `data-bi-prd-935c.bi_dev`.ioh_snd_master_kpi_detail
    SELECT '3ID',
    'site_id',
    x.site_id,
    SUM(a.value),
    'mtd',
    timestamp(current_datetime('+7')),
    'secondary_trad',
    a.dt_id 
    FROM `data-bi-prd-935c.bi_dev.mis_snd_prisec_detail` a 
    LEFT JOIN `data-bi-prd-935c.bi_mart`.stg_v_map_tgt_ret_details_hist x ON a.dt_id = x.dt AND a.qr_code = x.ret_qr_cd  
    WHERE a.kpi_name = 'secondary' 
      AND TRIM(LOWER(a.flag)) IN ('retailer_cashback','saldo','return to mp3','spv0','sp0') 
      AND a.dt_id = vdt_id 
    GROUP BY 1,2,3,5,6,7,8;

    -- ========== TERTIARY TRAD KPI - SITE LEVEL DAILY ==========
    DELETE FROM `data-bi-prd-935c.bi_dev`.ioh_snd_master_kpi_detail
    WHERE brand = '3ID' and kpi = 'tertiary_trad' AND dt_id = vdt_id AND level = 'site_id' AND time_flag = 'dly';
    
    INSERT INTO `data-bi-prd-935c.bi_dev`.ioh_snd_master_kpi_detail
    SELECT '3ID',
    'site_id',
    siteid_bnum,
    SUM(COALESCE(a.amount, 0)),
    'dly',
    timestamp(current_datetime('+7')),
    'tertiary_trad',
    dt_sk_id 
    FROM `data-bi-prd-935c.bi_mart`.project_ioh_tertiary_outlet a    
    LEFT JOIN `data-bi-prd-935c.bi_mart`.angie_hrchy_dim_hst b ON b.partner_qr_cd = a.dealer_id AND date_trunc(a.dt_sk_id,month) = b.mth
    WHERE a.dt_sk_id = vdt_id
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
    WHERE brand = '3ID' and kpi = 'tertiary_trad' AND dt_id = vdt_id AND level = 'outlet' AND time_flag = 'dly';
    
    INSERT INTO `data-bi-prd-935c.bi_dev`.ioh_snd_master_kpi_detail
    SELECT '3ID',
    'outlet',
    dealer_id,
    SUM(COALESCE(a.amount, 0)),
    'dly',
    timestamp(current_datetime('+7')),
    'tertiary_trad',
    dt_sk_id 
    FROM `data-bi-prd-935c.bi_mart`.project_ioh_tertiary_outlet a    
    LEFT JOIN `data-bi-prd-935c.bi_mart`.angie_hrchy_dim_hst b ON b.partner_qr_cd = a.dealer_id AND date_trunc(a.dt_sk_id,month) = b.mth
    WHERE a.dt_sk_id = vdt_id
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

    -- ========== TERTIARY TRAD KPI - SITE LEVEL MTD ==========
DELETE FROM `data-bi-prd-935c.bi_dev`.ioh_snd_master_kpi_detail    
WHERE kpi = 'tertiary_trad' AND dt_id =vdt_id AND level = 'site_id' AND time_flag = 'mtd';   
 
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
WHERE kpi = 'tertiary_trad' AND dt_id =vdt_id AND level = 'outlet' AND time_flag = 'mtd';  

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

delete
FROM `data-bi-prd-935c.bi_dev`.ioh_snd_master_kpi_detail
    WHERE kpi in 
    (
'tertiary_saldo',
'trade_demand_rita',
'trade_demand_sim',
'trade_demand_spv'
) and brand = '3ID'
AND dt_id = vdt_id AND level = 'site_id' AND time_flag = 'mtd';



    --  trade demand sim
    INSERT INTO `data-bi-prd-935c.bi_dev`.ioh_snd_master_kpi_detail
    SELECT '3ID',
    'site_id',
    coalesce(siteid_bnum,c.site_id) ,
    sum(coalesce(amount,0)) kpi_value,
    'mtd',
    timestamp(current_datetime('+7')),
    'trade_demand_sim',
    vdt_id dt_id 
    from `data-bi-prd-935c.bi_mart`.project_ioh_tertiary_outlet a
LEFT JOIN `data-bi-prd-935c.bi_mart`.angie_hrchy_dim_hst b ON b.partner_qr_cd = a.dealer_id AND date_trunc(a.dt_sk_id,month) = b.mth    
  --  on b.partner_qr_cd = a.dealer_id   
	left join 
	(select ret_qr_cd,site_id
	from 
	(select dt,ret_qr_cd,site_id,row_number() over (partition by ret_qr_cd order by dt desc) rnk
	from `data-bi-prd-935c.bi_mart`.stg_v_map_tgt_ret_details_hist
	where date_trunc(dt,month) = date_trunc(vdt_id,month) and  site_id <>''
	) x where rnk=1
	) c on a.dealer_id=c.ret_qr_cd 
	where dt_sk_id between date_trunc(vdt_id,month) and vdt_id
	and tertiary_category in ('FRC') and length(dealer_id) <10
	and upper(mp3_location) not in 
	('POOL','DVM BM','SIM ONLINE','BSM TRI OFFICIAL STORE','3 STORE','SOUTH JAKARTA TEST BM')
	and tertiary_type not like '%PULSA%'
    GROUP BY 1,2,3,5,6,7,8;


  INSERT INTO `data-bi-prd-935c.bi_dev`.ioh_snd_master_kpi_detail
    SELECT '3ID',
    'site_id',
    coalesce(siteid_bnum,c.site_id) ,
    sum(coalesce(amount,0)) kpi_value,
    'mtd',
    timestamp(current_datetime('+7')),
    'trade_demand_spv',
    vdt_id dt_id 
    from `data-bi-prd-935c.bi_mart`.project_ioh_tertiary_outlet a
LEFT JOIN `data-bi-prd-935c.bi_mart`.angie_hrchy_dim_hst b ON b.partner_qr_cd = a.dealer_id AND date_trunc(a.dt_sk_id,month) = b.mth    
  --  on b.partner_qr_cd = a.dealer_id  
	left join 
	(select ret_qr_cd,site_id
	from 
	(select dt,ret_qr_cd,site_id,row_number() over (partition by ret_qr_cd order by dt desc) rnk
	from `data-bi-prd-935c.bi_mart`.stg_v_map_tgt_ret_details_hist
	where date_trunc(dt,month) = date_trunc(vdt_id,month) and  site_id <>''
	) x where rnk=1
	) c on a.dealer_id=c.ret_qr_cd 
	where dt_sk_id between date_trunc(vdt_id,month) and vdt_id
	and tertiary_category in ('UNLOCK') and length(dealer_id) <10
	and upper(mp3_location) not in 
	('POOL','DVM BM','SIM ONLINE','BSM TRI OFFICIAL STORE','3 STORE','SOUTH JAKARTA TEST BM')
	and tertiary_type not like '%PULSA%'
    GROUP BY 1,2,3,5,6,7,8;


  INSERT INTO `data-bi-prd-935c.bi_dev`.ioh_snd_master_kpi_detail
    SELECT '3ID',
    'site_id',
    coalesce(siteid_bnum,c.site_id) ,
    sum(coalesce(amount,0)) kpi_value,
    'mtd',
    timestamp(current_datetime('+7')),
    'trade_demand_rita',
    vdt_id dt_id 
    from `data-bi-prd-935c.bi_mart`.project_ioh_tertiary_outlet a
LEFT JOIN `data-bi-prd-935c.bi_mart`.angie_hrchy_dim_hst b ON b.partner_qr_cd = a.dealer_id AND date_trunc(a.dt_sk_id,month) = b.mth    
  --  on b.partner_qr_cd = a.dealer_id  
	left join 
	(select ret_qr_cd,site_id
	from 
	(select dt,ret_qr_cd,site_id,row_number() over (partition by ret_qr_cd order by dt desc) rnk
	from `data-bi-prd-935c.bi_mart`.stg_v_map_tgt_ret_details_hist
	where date_trunc(dt,month) = date_trunc(vdt_id,month) and  site_id <>''
	) x where rnk=1
	) c on a.dealer_id=c.ret_qr_cd 
	where dt_sk_id between date_trunc(vdt_id,month) and vdt_id
	and tertiary_category in ('SALDO') and length(dealer_id) <10
	and upper(mp3_location) not in 
	('POOL','DVM BM','SIM ONLINE','BSM TRI OFFICIAL STORE','3 STORE','SOUTH JAKARTA TEST BM')
	and tertiary_type not like '%PULSA%'
    GROUP BY 1,2,3,5,6,7,8;


  INSERT INTO `data-bi-prd-935c.bi_dev`.ioh_snd_master_kpi_detail
    SELECT '3ID',
    'site_id',
    coalesce(siteid_bnum,c.site_id) ,
    sum(coalesce(amount,0)) kpi_value,
    'mtd',
    timestamp(current_datetime('+7')),
    'tertiary_saldo',
    vdt_id dt_id 
from `data-bi-prd-935c.bi_mart`.project_ioh_tertiary_outlet a
LEFT JOIN `data-bi-prd-935c.bi_mart`.angie_hrchy_dim_hst b ON b.partner_qr_cd = a.dealer_id AND date_trunc(a.dt_sk_id,month) = b.mth    
  --  on b.partner_qr_cd = a.dealer_id    -- and b.ret_hierarchy_type = 'ANGIE' and b.hrchy_type = 'Retailer'
left join 
(select ret_qr_cd,site_id
from 
(select dt,ret_qr_cd,site_id,row_number() over (partition by ret_qr_cd order by dt desc) rnk
from `data-bi-prd-935c.bi_mart`.stg_v_map_tgt_ret_details_hist
where date_trunc(dt,month) = date_trunc(vdt_id,month) and  site_id <>''
) x where rnk=1
) c on a.dealer_id=c.ret_qr_cd 
where dt_sk_id between date_trunc(vdt_id,month) and vdt_id
and tertiary_category ='SALDO' and length(dealer_id) <10
and upper(mp3_location) not in 
('POOL','DVM BM','SIM ONLINE','BSM TRI OFFICIAL STORE','3 STORE','SOUTH JAKARTA TEST BM')
    GROUP BY 1,2,3,5,6,7,8;



--- Trade Supply 
DELETE FROM `data-bi-prd-935c.bi_dev`.ioh_snd_master_kpi_detail
WHERE lower(kpi) IN ('trade_supply') and level = 'outlet' AND dt_id = vdt_id and brand = '3ID';


--- Trade Supply Outlet
insert  into `data-bi-prd-935c.bi_dev`.ioh_snd_master_kpi_detail
    SELECT '3ID' as brand,
    'outlet' level,
    ret_qrcode level_value,
    cast(sum(kpi_value) as numeric) val,
    'mtd' time_flag,
    timestamp(current_datetime('+7')) insert_date,
    lower('trade_supply')kpi,
     dt_id dt_id 
 from 
(
select vdt_id dt_id,partner_qr_cd ret_qrcode,'trade_supply' kpi_name,sum(coalesce(value,0)) kpi_value
 from
(
--- Trade Supply Site NBS
-- trade supply voucher
select vdt_id dt ,partner_qr_cd,site_id,sum(net_Revenue) value
 from--sum(gross_revenue),sum(net_revenue)  from 
`data-bi-prd-935c.bi_mart`.dm_snd_voucher a left join (SELECT * from `data-bi-prd-935c.bi_mart`.angie_hrchy_dim_hst where hrchy_type='Retailer' and partner_Status='Active' and mth=date_trunc(vdt_id,month) ) b on a.qr_Cd=b.partner_qr_cd 
left outer join
(
select ret_qr_cd,site_id from 
	(
	select dt,ret_qr_cd,site_id,row_number() over (partition by ret_qr_cd order by dt desc) rnk
	from `data-bi-prd-935c.bi_mart`.stg_v_map_tgt_ret_details_hist
	where  site_id <>'' and dt<=vdt_id
	) x where rnk=1
) c on a.qr_Cd=c.ret_qr_cd  
where sd_type='SUPPLY'
and package_type='UNLOCK' 
and voucher_type in ('REGULAR_VOUCHER' ,'ORI_VOUCHER')
and a.dt  between date_trunc(vdt_id,month) and vdt_id
and upper(bm_location ) not in 
(
'DVM BM',
'3 BUSINESS',
'SIM ONLINE',
'NA',
'POOL',
'3 STORE',
'SOUTH JAKARTA TEST BM',
'BSM TRI OFFICIAL STORE'
) group by 1,2,3
union all 
-- trade supply rita
select vdt_id dt ,a.qr_cd,site_id,sum(net_Revenue)
 from--sum(gross_revenue),sum(net_revenue)  from  from--sum(gross_revenue),sum(net_revenue)  from 
`data-bi-prd-935c.bi_mart`.dm_snd_voucher a left join (SELECT * from `data-bi-prd-935c.bi_mart`.angie_hrchy_dim_hst where hrchy_type='Retailer' and partner_Status='Active' and mth=date_trunc(vdt_id,month) ) b on a.qr_Cd=b.partner_qr_cd 
left outer join
(
select ret_qr_cd,site_id from 
	(
	select dt,ret_qr_cd,site_id,row_number() over (partition by ret_qr_cd order by dt desc) rnk
	from `data-bi-prd-935c.bi_mart`.stg_v_map_tgt_ret_details_hist
	where  site_id <>'' and dt<=vdt_id
	) x where rnk=1
) c on a.qr_Cd=c.ret_qr_cd  
where sd_type='DEMAND'
and package_type='RITA'
and voucher_type='E TOP UP'
and a.dt  between date_trunc(vdt_id,month) and vdt_id
and upper(bm_location ) not in 
(
'DVM BM',
'3 BUSINESS',
'SIM ONLINE',
'NA',
'POOL',
'3 STORE',
'SOUTH JAKARTA TEST BM',
'BSM TRI OFFICIAL STORE'
) group by 1,2,3
union all 
-- supply frc 
select vdt_id dt ,a.partner_qr_cd,site_id,sum(net_Revenue)
 from--sum(gross_revenue),sum(net_revenue)  from 
`data-bi-prd-935c.bi_mart`.dm_snd_demand_frc a left join (SELECT * from `data-bi-prd-935c.bi_mart`.angie_hrchy_dim_hst where hrchy_type='Retailer' and partner_Status='Active' and mth=date_trunc(vdt_id,month) ) b on a.partner_qr_cd=b.partner_qr_cd --  limit 10 
left outer join
(
select ret_qr_cd,site_id from 
	(
	select dt,ret_qr_cd,site_id,row_number() over (partition by ret_qr_cd order by dt desc) rnk
	from `data-bi-prd-935c.bi_mart`.stg_v_map_tgt_ret_details_hist
	where  site_id <>'' and dt<=vdt_id
	) x where rnk=1
) c on a.partner_qr_cd=c.ret_qr_cd  
where sd_type='SUPPLY'
and a.dt between date_trunc(vdt_id,month) and vdt_id 
and upper(bm_location ) not in 
(
'DVM BM',
'3 BUSINESS',
'SIM ONLINE',
'NA',
'POOL',
'3 STORE',
'SOUTH JAKARTA TEST BM',
'BSM TRI OFFICIAL STORE'
) group by 1,2,3
) supply 	group by 1,2,3 
) x 
   GROUP BY 1,2,3,5,7,8   ;




DELETE FROM `data-bi-prd-935c.bi_dev`.ioh_snd_master_kpi_detail
WHERE lower(kpi) IN (
'trade_demand_inner','trade_demand_outer'
) 
 AND dt_id = vdt_id and brand = '3ID';



INSERT INTO `data-bi-prd-935c.bi_dev`.ioh_snd_master_kpi_detail 
-- This CTE consolidates the data from all the joins and performs the necessary checks
-- to determine inner vs. outer demand, making the final UNION ALL clearer.
WITH tertiary_demand_data AS (
    SELECT
        a.dt_sk_id,
        coalesce(coalesce(a.siteid_bnum, c.site_id), 'null') AS tertiary_site_id,
        CASE
            WHEN refa.gladiator_branch = refb.gladiator_branch THEN 'trade_demand_inner'
            ELSE 'trade_demand_outer'
        END AS demand_type,
        SUM(coalesce(a.amount, 0)) AS raw_amount
    FROM `data-bi-prd-935c.bi_mart`.project_ioh_tertiary_outlet a
    LEFT JOIN `data-bi-prd-935c.bi_stg`.tmp_angie b ON b.partner_qr_cd = a.dealer_id
    LEFT JOIN `data-bi-prd-935c.bi_stg`.tmp_nbs c ON a.dealer_id = c.ret_qr_cd
    LEFT JOIN `data-bi-prd-935c.bi_stg`.tmp_ref_branch_circle refa ON coalesce(a.siteid_bnum, c.site_id) = refa.site_id
    LEFT JOIN `data-bi-prd-935c.bi_stg`.tmp_nbs nbs ON a.dealer_id = nbs.ret_qr_cd
    LEFT JOIN `data-bi-prd-935c.bi_stg`.tmp_ref_branch_circle refb ON refb.site_id = nbs.site_id
    WHERE
        (dt_sk_id between date_trunc(vdt_id,month) AND vdt_id)
        AND (tertiary_category IN ('SALDO', 'FRC', 'UNLOCK') AND UPPER(tertiary_type) NOT LIKE '%PULSA%')
        AND length(a.dealer_id) < 10
        AND upper(b.mp3_location) NOT IN ('POOL', 'DVM BM', 'SIM ONLINE', 'BSM TRI OFFICIAL STORE', '3 BUSINESS', '3 STORE', 'SOUTH JAKARTA TEST BM')
    GROUP BY
        a.dt_sk_id,
        tertiary_site_id,
        refa.gladiator_branch,
        refb.gladiator_branch
)
-- UNION ALL to generate separate rows for 'Trade Demand Inner' and 'Trade Demand Outer'
SELECT * FROM (
    -- Data for 'Trade Demand Inner'
    SELECT
        '3ID' AS brand_id,
        'site_id' AS level_id,
        tertiary_site_id AS level_value,
        SUM(raw_amount)  AS kpi_value,
        'mtd' AS period_type,
        timestamp(current_datetime('+7')) AS uVDate_dttm,
        'trade_demand_inner' AS kpi_name,
        vdt_id AS dt_id
    FROM tertiary_demand_data
    WHERE demand_type = 'trade_demand_inner'
    GROUP BY
        tertiary_site_id

    UNION ALL

    -- Data for 'Trade Demand Outer'
    SELECT
        '3ID' AS brand_id,
        'site_id' AS level_id,
        tertiary_site_id AS level_value,
        SUM(raw_amount)  AS kpi_value,
        'mtd' AS period_type,
        timestamp(current_datetime('+7')) AS uVDate_dttm,
        'trade_demand_outer' AS kpi_name,
        vdt_id AS dt_id
    FROM tertiary_demand_data
    WHERE demand_type = 'trade_demand_outer'
    GROUP BY
        tertiary_site_id
) AS combined_results;


--Wait for Mas Arenzy
DELETE FROM `data-bi-prd-935c.bi_dev`.ioh_snd_master_kpi_detail
WHERE lower(kpi) IN (
'ono'
) 
 AND dt_id = vdt_id and brand = '3ID';




INSERT INTO `data-bi-prd-935c.bi_dev`.ioh_snd_master_kpi_detail 
-- This CTE gets the latest site ID for each outlet for the current month
WITH outlet_site_mapping AS (
    SELECT
        ret_qr_cd,
        (CASE WHEN length(site_id) <= 5 THEN LPAD(site_id, 6, '0') ELSE site_id END) AS site_id
    FROM (
        SELECT
            dt,
            ret_qr_cd,
            site_id,
            row_number() OVER (PARTITION BY ret_qr_cd ORDER BY dt DESC) AS rnk
        FROM `data-bi-prd-935c.bi_mart`.stg_v_map_tgt_ret_details_hist
        WHERE
            date_trunc(dt,month) = date_trunc(vdt_id,month)
            AND site_id <> ''
    ) x
    WHERE rnk = 1
),
-- This CTE joins the outlet data with the latest site IDs
outlet_data AS (
    SELECT
        a.outlet_id,
        parse_date('%d-%b-%y',left(a.ret_reg_date,9)) AS reg_date,
        g.site_id
    FROM `data-bi-prd-935c.bi_snd.pre_ref_retailer_hirarki` a
    LEFT JOIN outlet_site_mapping g ON a.outlet_id = g.ret_qr_cd
    WHERE
        parse_date('%Y%m',cast(mth_id as string)) = date_trunc(vdt_id,month)
)
-- UNION ALL to generate separate rows for '#ONO' and 'Total Outlet'
SELECT * FROM (
    -- Data for '#ONO' (Outlets registered in the current month up to the current day)
    SELECT
        '3ID' AS brand_id,
        'site_id' AS level_id,
        coalesce(site_id, 'null') AS level_value,
        count(DISTINCT outlet_id) AS kpi_value,
        'mtd' AS period_type,
        timestamp(current_datetime('+7')) AS uVDate_dttm,
        'ono' AS kpi_name,
        vdt_id AS dt_id
    FROM outlet_data
    WHERE
        date_trunc(reg_date,month) = date_trunc(vdt_id,month)
        AND reg_date <= vdt_id
    GROUP BY
        coalesce(site_id, 'null')
) AS combined_results;