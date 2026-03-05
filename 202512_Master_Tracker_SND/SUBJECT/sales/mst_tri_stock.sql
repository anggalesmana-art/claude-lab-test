declare vdt_id date default @vdt_id;


--- Stock demand_30_saldo
delete  from `data-bi-prd-935c.bi_dev`.ioh_snd_master_kpi_detail
where brand = '3ID' and kpi in ('demand_30_saldo')  and dt_id = vdt_id  ;


insert into `data-bi-prd-935c.bi_dev`.ioh_snd_master_kpi_detail 
select '3ID' as brand,
'outlet' level,
dealer_id level_value
,SUM(COALESCE(a.amount, 0))  value
,'mtd' time_flag,timestamp(current_datetime('+7')) insert_date
,'demand_30_saldo'    kpi,vdt_id dt_id 
    FROM `data-bi-prd-935c.bi_mart`.project_ioh_tertiary_outlet a
 LEFT JOIN `data-bi-prd-935c.bi_mart`.angie_hrchy_dim_hst b 
		 ON b.partner_qr_cd = a.dealer_id 
        AND b.mth = date_trunc(vdt_id,month)
  WHERE 
        a.dt_sk_id  between vdt_id - interval 29 day and vdt_id
        AND a.tertiary_category IN ('SALDO') 
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
group by 1,2,3,5,6,7,8 ;


--- ('stock_sp_outlet','stock_vou_outlet','demand_30_sp','demand_30_vou')
delete  from `data-bi-prd-935c.bi_dev`.ioh_snd_master_kpi_detail
where brand = '3ID' and kpi in ('stock_sp_outlet','stock_vou_outlet','demand_30_sp','demand_30_vou')  and dt_id = vdt_id  ;


insert into  `data-bi-prd-935c.bi_dev`.ioh_snd_master_kpi_detail  
select '3ID' as brand,
'outlet' level,
qr_code level_value
,cast(sum(netnetrevenue) as numeric) value
,'mtd' time_flag,timestamp(current_datetime('+7')) insert_date
,case 	when type = 'Stock' and category = 'Trade SIM' then 'stock_sp_outlet'    
	when type = 'Stock' and category = 'Trade Voucher' then 'stock_vou_outlet'   
	when type = 'Demand 30' and category = 'Trade SIM' then 'demand_30_sp'   
	when type = 'Demand 30' and category = 'Trade Voucher' then 'demand_30_vou'   
end as kpi 
,dt_id dt_id 
--- M2S
FROM `data-bi-prd-935c.bi_mart`.mis_agg_stock_daily 
WHERE dt_id =vdt_id
      AND category in( 'Trade SIM','Trade Voucher' )
-- and qr_code ='00001129'
group by 1,2,3,5,6,7,8 ; 


delete  from `data-bi-prd-935c.bi_dev`.ioh_snd_master_kpi_detail
where brand = '3ID' and kpi in ('stock_sp_outlet_cnt','stock_vou_outlet_cnt')  and dt_id = vdt_id  ;


insert into  `data-bi-prd-935c.bi_dev`.ioh_snd_master_kpi_detail  
select '3ID' as brand,
'outlet' level,
qr_code level_value
,sum(hit) value
,'mtd' time_flag,timestamp(current_datetime('+7')) insert_date
,case 	when type = 'Stock' and category = 'Trade SIM' then 'stock_sp_outlet_cnt'    
	when type = 'Stock' and category = 'Trade Voucher' then 'stock_vou_outlet_cnt'   
end as kpi 
,dt_id dt_id 
--- M2S
FROM `data-bi-prd-935c.bi_mart`.mis_agg_stock_daily 
WHERE dt_id =vdt_id
      AND category in( 'Trade SIM','Trade Voucher' )
-- and qr_code ='00001129'
      and type = 'Stock'  
group by 1,2,3,5,6,7,8 ; 



--- ('stock_sp_outlet','stock_vou_outlet','demand_30_sp','demand_30_vou')
delete  from `data-bi-prd-935c.bi_dev`.ioh_snd_master_kpi_detail
where brand = '3ID' and kpi in ('stock_with_dist')  and dt_id = vdt_id  ;


insert into  `data-bi-prd-935c.bi_dev`.ioh_snd_master_kpi_detail  
select '3ID' as brand,
'partner' level,
partner_id level_value
,sum(kpi_value) value
,'mtd' time_flag,timestamp(current_datetime('+7')) insert_date
, 'stock_with_dist'      kpi 
,date(snp_dt_sk_id) dt_id 
--- M2S
from `data-dtptechm-prd-c7ca.dwh`.prt_daily_channel_movement_fct			
where kpi_name like 'DB Closing Balance'			
and partner_type in ('MP3') 
and date(snp_dt_sk_id) =vdt_id -- (vdt_id,vdt_id,20250228,20250331,20250430) 
 and hierarchy_type ='ANGIE'
and kpi_value >0 
group by 1,2,3,5,6,7,8  ; 


delete  from `data-bi-prd-935c.bi_dev`.ioh_snd_master_kpi_detail
where brand = '3ID' and kpi in ('stockout_outlet','stockout_outlet_saldo','stockout_outlet_sp','stockout_outlet_vou')  and dt_id = vdt_id  ;


insert into `data-bi-prd-935c.bi_dev`.ioh_snd_master_kpi_detail 
select '3ID' as brand
,'outlet' level
,qr_code qr_code
,sum(total_outlet) value
,'mtd' time_flag,timestamp(current_datetime('+7')) insert_date
,'stockout_outlet' kpi 
,dt_id
from 
(
select dt_id
,'3ID' brand
,Y.circle
,Y.region_circle
,Y.area
,Y.gladiator_branch 
,level_value qr_code 
,sum(case when kpi='stock_with_outlet' then values else 0 end)  as stock_with_outlet
,sum(case when kpi in ('demand_30_vou' ,'demand_30_sp') then (values)*1 *30
	 when kpi in ('demand_30_saldo') then (values) else 0 end ) as demand_30
	 ,sum(case when kpi='total_outlet' then values else 0 end)  as total_outlet
 from 
  	`data-bi-prd-935c.bi_dev`.ioh_snd_master_kpi_detail a left join `data-bi-prd-935c.bi_mart`.stg_v_map_tgt_ret_details_hist b on a.dt_id=b.dt and a.level_value=b.ret_qr_cd 
	left join `data-bi-prd-935c.bi_mart`.ref_site_h3i y 
	ON CASE WHEN LENGTH(b.site_id)<=5 THEN '0'||b.site_id ELSE b.site_id END = 
           CASE WHEN LENGTH(y.site_id)<=5 THEN '0'||y.site_id ELSE y.site_id END
                      left join `data-bi-prd-935c.bi_snd.pre_ref_outlet_mapping_3id`  d on a.level_value=d.retailer_qrcode and date_trunc(a.dt_id,month)= parse_date('%Y%m',cast(d.mth_id as string))

	where 
	dt_id in (vdt_id )
	and level='outlet' and time_flag='mtd' and d.retailer_qrcode is not null 
and  lower(kpi) 
in (
'stock_with_outlet',
'demand_30_saldo',
'demand_30_sp'	,
'demand_30_vou','total_outlet'
)  and brand = '3ID'
group by 1,2,3,4,5,6,7
) x where total_outlet=1 and coalesce(stock_with_outlet,0) =0
group by 1,2,3,5,6,7,8 

union all 

select '3ID' as brand
,'outlet' level
,qr_code qr_code
,sum(total_outlet) value
,'mtd' time_flag,timestamp(current_datetime('+7')) insert_date
,'stockout_outlet_saldo'
,dt_id
from 
(
select dt_id
,'3ID' brand
,Y.circle
,Y.region_circle
,Y.area
,Y.gladiator_branch 
,level_value qr_code 
,sum(case when kpi='stock_saldo_outlet' then values else 0 end)  as stock_with_outlet
,sum(case when kpi in ('demand_30_vou' ,'demand_30_sp') then (values)*1 *30
	 when kpi in ('demand_30_saldo') then (values) else 0 end ) as demand_30
	 ,sum(case when kpi='total_outlet' then values else 0 end)  as total_outlet
 from 
  	`data-bi-prd-935c.bi_dev`.ioh_snd_master_kpi_detail a left join `data-bi-prd-935c.bi_mart`.stg_v_map_tgt_ret_details_hist b on a.dt_id=b.dt and a.level_value=b.ret_qr_cd 
	left join `data-bi-prd-935c.bi_mart`.ref_site_h3i y 
	ON CASE WHEN LENGTH(b.site_id)<=5 THEN '0'||b.site_id ELSE b.site_id END = 
           CASE WHEN LENGTH(y.site_id)<=5 THEN '0'||y.site_id ELSE y.site_id END
                      left join `data-bi-prd-935c.bi_snd.pre_ref_outlet_mapping_3id`  d on a.level_value=d.retailer_qrcode and date_trunc(a.dt_id,month)= parse_date('%Y%m',cast(d.mth_id as string))

	where 
	dt_id in (vdt_id )
	and level='outlet' and time_flag='mtd' and d.retailer_qrcode is not null 
and  lower(kpi) 
in (
'stock_saldo_outlet',
'demand_30_saldo',
'demand_30_sp'	,
'demand_30_vou','total_outlet'
) and brand = '3ID'
group by 1,2,3,4,5,6,7
) x where total_outlet=1 and coalesce(stock_with_outlet,0) =0
group by 1,2,3,5,6,7,8 


union all 
select '3ID' as brand
,'outlet' level
,qr_code qr_code
,sum(total_outlet) value
,'mtd' time_flag,timestamp(current_datetime('+7')) insert_date
,'stockout_outlet_sp'
,dt_id
from 
(
select dt_id
,'3ID' brand
,Y.circle
,Y.region_circle
,Y.area
,Y.gladiator_branch 
,level_value qr_code 
,sum(case when kpi='stock_sp_outlet' then values else 0 end)  as stock_with_outlet
,sum(case when kpi in ('demand_30_vou' ,'demand_30_sp') then (values)*1 *30
	 when kpi in ('demand_30_saldo') then (values) else 0 end ) as demand_30
	 ,sum(case when kpi='total_outlet' then values else 0 end)  as total_outlet
 from 
  	`data-bi-prd-935c.bi_dev`.ioh_snd_master_kpi_detail a left join `data-bi-prd-935c.bi_mart`.stg_v_map_tgt_ret_details_hist b on a.dt_id=b.dt and a.level_value=b.ret_qr_cd 
	left join `data-bi-prd-935c.bi_mart`.ref_site_h3i y 
	ON CASE WHEN LENGTH(b.site_id)<=5 THEN '0'||b.site_id ELSE b.site_id END = 
           CASE WHEN LENGTH(y.site_id)<=5 THEN '0'||y.site_id ELSE y.site_id END
                      left join `data-bi-prd-935c.bi_snd.pre_ref_outlet_mapping_3id`  d on a.level_value=d.retailer_qrcode and date_trunc(a.dt_id,month)= parse_date('%Y%m',cast(d.mth_id as string))

	where 
	dt_id in (vdt_id )
	and level='outlet' and time_flag='mtd' and d.retailer_qrcode is not null 
and  lower(kpi) 
in (
'stock_sp_outlet',
'demand_30_saldo',
'demand_30_sp'	,
'demand_30_vou','total_outlet'
) and brand = '3ID'
group by 1,2,3,4,5,6,7
) x where total_outlet=1 and coalesce(stock_with_outlet,0) =0
group by 1,2,3,5,6,7,8 
union all 
select '3ID' as brand
,'outlet' level
,qr_code qr_code
,sum(total_outlet) value
,'mtd' time_flag,timestamp(current_datetime('+7')) insert_date
,'stockout_outlet_vou'
,dt_id
from 
(
select dt_id
,'3ID' brand
,Y.circle
,Y.region_circle
,Y.area
,Y.gladiator_branch 
,level_value qr_code 
,sum(case when kpi='stock_vou_outlet' then values else 0 end)  as stock_with_outlet
,sum(case when kpi in ('demand_30_vou' ,'demand_30_sp') then (values)*1 *30
	 when kpi in ('demand_30_saldo') then (values) else 0 end ) as demand_30
	 ,sum(case when kpi='total_outlet' then values else 0 end)  as total_outlet
 from 
  	`data-bi-prd-935c.bi_dev`.ioh_snd_master_kpi_detail a left join `data-bi-prd-935c.bi_mart`.stg_v_map_tgt_ret_details_hist b on a.dt_id=b.dt and a.level_value=b.ret_qr_cd 
	left join `data-bi-prd-935c.bi_mart`.ref_site_h3i y 
	ON CASE WHEN LENGTH(b.site_id)<=5 THEN '0'||b.site_id ELSE b.site_id END = 
           CASE WHEN LENGTH(y.site_id)<=5 THEN '0'||y.site_id ELSE y.site_id END
                      left join `data-bi-prd-935c.bi_snd.pre_ref_outlet_mapping_3id`  d on a.level_value=d.retailer_qrcode and date_trunc(a.dt_id,month)= parse_date('%Y%m',cast(d.mth_id as string))

	where 
	dt_id in (vdt_id )
	and level='outlet' and time_flag='mtd' and d.retailer_qrcode is not null 
and  lower(kpi) 
in (
'stock_vou_outlet',
'demand_30_saldo',
'demand_30_sp'	,
'demand_30_vou','total_outlet'
) and brand = '3ID'
group by 1,2,3,4,5,6,7
) x where total_outlet=1 and coalesce(stock_with_outlet,0) =0
group by 1,2,3,5,6,7,8 

;





