   declare vdt_id date default @vdt_id;
--IM3
---------------- STOK OUTLET ----------------

delete from `data-bi-prd-935c.bi_dev`.ioh_snd_master_kpi_detail where kpi = 'stock_with_outlet' and dt_id = vdt_id and brand = 'IM3';
insert into `data-bi-prd-935c.bi_dev`.ioh_snd_master_kpi_detail
select 'IM3' brand, 'outlet' level, organization_id as level_value, 
    sum(cast(stock as numeric)) value, 
    'mtd' as time_flag, 
     timestamp(current_datetime('+7')) as insert_date,
    'stock_with_outlet' as kpi, 
     dt_id
from 
--- STOCK OUTLET
(
    select dt_id, organization_id, sum(stock) stock 
    from 
    ( 
        -- stock outlet balance 
        select dt_id, short_code organization_id, sum(cast(stock_balance as decimal)) stock 
        from `data-bi-prd-935c.bi_mart`.outlet_stock_balance
        where dt_id =vdt_id
        group by 1,2
        union all
        -- stock outlet sp mobo 
        select a.dt_id, organization_id, sum(cast(amount_debit as decimal)) stock
        from `data-bi-prd-935c.bi_mart`.stock_mobo_sp a
        join (
            select date(dt_id) dt_id,msisdn from `data-dtp-prd-aa1a.smy`.ar_cst_dly_smy
            where dt_id  = timestamp(vdt_id)
            and ar_lcs_tp_nm in ('ACTIVE','ACTIVE IN GRACE')
            ) b 
        on a.b_msisdn=b.msisdn and a.dt_id=b.dt_id
        where a.dt_id  =vdt_id
        -- and a.inj_dt_id >=from_timestamp(date_add(to_date(from_unixtime(unix_timestamp(vdt_id,'yyyyMMdd'))),-360),'yyyyMMdd')
        group by 1,2 
        union all
        -- stock outlet vou mobo 
        select dt_id, organization_id,sum(cast(amount_debit as decimal)) stock
        from `data-bi-prd-935c.bi_mart`.stock_mobo_vou
        where dt_id =vdt_id
        group by 1,2
        union all
        -- stock outlet sp data mobii (sp ori)
        select dt_id, organization_id, sum(stock) stock from 
        (
        select dt_id, dest_saldomobo_id organization_id ,  
            expired_date  expired_date_normalisasi,
            case when expired_date >= date(timestamp(current_datetime('+7'))) then 'No' else 'Expired' end exp_flag,
            sum(cast(amount as decimal)) stock
        from `data-bi-prd-935c.bi_mart`.stock_sp_data_mobii 
        where dt_id =vdt_id
        group by 1,2,3,4
        )a
        where expired_date_normalisasi>dt_id
        group by 1,2 
        union all
        -- stock outlet vou mobii (vou ori)
        select dt_id, organization_id, sum(cast(amount as decimal)) stock
        from `data-bi-prd-935c.bi_mart`.stock_vo_ori_sellin
        where dt_id  =vdt_id
        and expired_date>dt_id
        group by 1,2 
    )a 
    group by 1,2
)a 
group by 1,2,3,5,6,7,8
;


--TRI
-------------TRADE STOCK

-- create or replace table `data-bi-prd-935c.bi_stg`.tmp_trd_tableau_stock_rev
-- as
-- select
-- report_tabname type
-- ,date(fct.trx_dt_sk_id) load_date
-- ,date(fct.trx_dt_sk_id) dt_id
-- ,case
-- when product_nm like 'ADDON%' then 'ADDON'
-- when report_rowname='SIM' then 'Trade SIM'
-- when report_rowname='RITA' then 'EVC-NG'
-- when report_rowname='VOUCHER' then 'Trade Voucher'
-- end as category
-- ,fct.partner_qr_cd qr_code
-- ,'NA' product_code
-- ,replace(product_nm,'ADDON ','') product_name
-- ,sum(netnetrevenue) netnetrevenue
-- ,sum(hits) hit
-- from `data-dtptechm-prd-c7ca.dwh_olap.revenue_base_special_summary` fct
-- where
-- date(fct.trx_dt_sk_id)=vdt_id
-- and report_tabname in ('Stock')
-- and report_rowname in('SIM','VOUCHER','RITA')
-- and coalesce(service_type_name,'BROADBAND')='BROADBAND'
-- and retailer_mp3_location is not null
-- and retailer_mp3_location not in ('DVM BM','FUT ANGIE 2.0','POOL','NA','SIM ONLINE','SOUTH JAKARTA TEST BM')
-- and product_nm is not null
-- group by 1,2,3,4,5,6,7
-- ;



-- delete from `data-bi-prd-935c.bi_mart`.mis_agg_stock_daily where dt_id=vdt_id;

-- insert into `data-bi-prd-935c.bi_mart`.mis_agg_stock_daily
-- select * from `data-bi-prd-935c.bi_stg`.tmp_trd_tableau_stock_rev ;


-------------TRADE STOCK
create or replace table `data-bi-prd-935c.bi_stg`.tmp_trd_tableau_stock_rev
as
select 
report_tabname type
,date(fct.trx_dt_sk_id) load_date
,date(fct.trx_dt_sk_id) dt_id
,case 
	when product_nm like 'ADDON%' then 'ADDON'
 	when report_rowname='SIM' then 'Trade SIM'
 	when report_rowname='RITA' then 'EVC-NG'
 	when report_rowname='VOUCHER' then 'Trade Voucher' 
end as category
,fct.partner_qr_cd qr_code
,'NA' product_code
,replace(product_nm,'ADDON ','') product_name
,sum(netnetrevenue) netnetrevenue
,sum(hits) hit
from `data-dtptechm-prd-c7ca.dwh_olap`.revenue_base_special_summary fct
where 
date(fct.trx_dt_sk_id)=vdt_id   
and report_tabname in ('Stock')
and report_rowname in('SIM','VOUCHER','RITA')
and coalesce(service_type_name,'BROADBAND')='BROADBAND' 
and retailer_mp3_location is not null 
and retailer_mp3_location not in ('DVM BM','FUT ANGIE 2.0','POOL','NA','SIM ONLINE','SOUTH JAKARTA TEST BM')
and product_nm is not null
group by 1,2,3,4,5,6,7
;


-------------- TRADE STOCK DEMAND 30
create or replace table  `data-bi-prd-935c.bi_stg`.tmp_trd_tableau_stock_demand302
as
select 
'Demand 30' type
,date(trx_dt_sk_id) load_date
,date(trx_dt_sk_id) dt_id
,case 
	when report_rowname='SIM' then 'Trade SIM'
	when report_rowname='VOUCHER' then 'Trade Voucher' 
end category
,fct.partner_qr_cd qr_code
,'NA' product_code
,product_nm product_name
,sum(netnetrevenue) net_revenue
,0 hits
from `data-dtptechm-prd-c7ca.dwh_olap`.revenue_base_special_summary fct
left join `data-dtptechm-prd-c7ca.dwh`.channel_dim cd ON cd.channel_sk_id=fct.mp3_channel_sk_id
left join `data-dtptechm-prd-c7ca.dwh`.angie_hrchy_dim ng on fct.angie_channel_sk_id = ng.angie_hrchy_sk_id
where 
report_tabname='Avg_Demand_30' 
and report_rowname in('SIM','VOUCHER')
and date(fct.trx_dt_sk_id)=vdt_id	
group by 1,2,3,4,5,6,7;

------------INSERT TO STOCK TABLE
-----------############
delete from `data-bi-prd-935c.bi_mart`.mis_agg_stock_daily where dt_id=vdt_id; 


insert into `data-bi-prd-935c.bi_mart`.mis_agg_stock_daily

select * from `data-bi-prd-935c.bi_stg`.tmp_trd_tableau_stock_rev
union distinct
select * from `data-bi-prd-935c.bi_stg`.tmp_trd_tableau_stock_demand302
;





  DELETE FROM `data-bi-prd-935c.bi_dev`.ioh_snd_master_kpi_detail
    WHERE lower(kpi) ='stock_with_outlet' AND dt_id = vdt_id and brand = '3ID';
    
 

insert into `data-bi-prd-935c.bi_dev`.ioh_snd_master_kpi_detail
select brand,level,level_value,cast(sum(value) as numeric),time_flag,insert_date,'stock_with_outlet' kpi,dt_id from
(
  select '3ID' as brand,
  'outlet' level,
  qr_code level_value
  ,sum(netnetrevenue) value
  ,'mtd' time_flag,timestamp(current_datetime('+7')) insert_date
  ,case when type = 'Stock' then 'stock_with_outlet'
  end as kpi
  ,dt_id dt_id
  --- M2S
  FROM `data-bi-prd-935c.bi_mart`.mis_agg_stock_daily
  WHERE dt_id =vdt_id
  AND category in( 'Trade SIM','Trade Voucher' )and type = 'Stock'
  -- and qr_code ='00001129'
  group by 1,2,3,5,7,8
  union all
  select '3ID' as brand,
  'outlet' level,
  partner_qr_cd level_value
  ,sum(kpi_value) value
  ,'mtd' time_flag,timestamp(current_datetime('+7')) insert_date
  ,'stock_saldo_outlet' kpi,date(snp_dt_sk_id) dt_id
  --- M2S
  from
  `data-dtptechm-prd-c7ca.dwh.prt_daily_channel_movement_fct` a
  LEFT JOIN `data-bi-prd-935c.bi_mart.angie_hrchy_dim_hst` b
  ON cast(b.angie_hrchy_sk_id as string) = cast(a.partner_sk_id as string)
  AND b.mth = date_trunc(date(snp_dt_sk_id),month)
  where kpi_name like 'DB Closing Balance'
  and a.partner_type='Retailer'
  and date(a.snp_dt_sk_id) = vdt_id and kpi_value >0
  group by 1,2,3,5,7,8
) x group by 1,2,3,5,6,7,8
;

delete  from `data-bi-prd-935c.bi_dev`.ioh_snd_master_kpi_detail
where kpi in ('stock_saldo_outlet')  and dt_id =  vdt_id and brand = '3ID';


insert into  `data-bi-prd-935c.bi_dev`.ioh_snd_master_kpi_detail
select '3ID' as brand,
'outlet' level,
partner_qr_cd level_value
,cast(sum(kpi_value) as numeric) value
,'mtd' time_flag,timestamp(current_datetime('+7')) insert_date
,'stock_saldo_outlet'    kpi,date(snp_dt_sk_id) dt_id 
--- M2S
  from 			
	`data-dtptechm-prd-c7ca.dwh.prt_daily_channel_movement_fct` a 
	 LEFT JOIN `data-bi-prd-935c.bi_mart.angie_hrchy_dim_hst` b 
		ON cast(b.angie_hrchy_sk_id as string) = cast(a.partner_sk_id as string)
		AND b.mth = date(date_trunc(snp_dt_sk_id,month))
		where kpi_name like 'DB Closing Balance' 
		and a.partner_type='Retailer'
		and date(a.snp_dt_sk_id)  = vdt_id and kpi_value >0
group by 1,2,3,5,6,7,8 ;
