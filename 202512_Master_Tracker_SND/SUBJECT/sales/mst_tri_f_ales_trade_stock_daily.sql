declare vdt_id date default @vdt_id;

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


