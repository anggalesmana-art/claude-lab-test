  declare vdt_id date default @vdt_id;


--waiting permision `data-analytics-prd-1b95.analytics.mkt_product_next_level_report_final_v3`
create or replace table `data-bi-prd-935c.bi_stg.temp_mkt_product_next_level_report_final_v3` as 
			select
			a.sbscrptn_ek_id msisdn, vdt_id mth,trx_dt_sk_id,
			case when coalesce(a.validity,0) > 20 then 'Monthly' else 'Sachet' end as validity,
			case when channel_wise in ('BANK', 'EAD', 'MOCHAN OFFLINE', 'MOCHAN ONLINE') then 'Mobo Non-Trade'
				 when channel_wise in ('RITA', 'SP/SIM', 'VOUCHER/SPV') then 'Mobo Trade'
				 when channel_wise in ('AR', 'BIMA', 'CHATBOT', 'DATA LOAN', 'MILLOM', 'ORG-OTHERS', 'SMS', 'UMB') then 'Organic'
			else 'N/A' end as channel_grp,
			sum(hits_rev) hits, 
			sum(netrevenue) netrevenue
			from `data-analytics-prd-1b95.analytics.mkt_product_next_level_report_final_v3` a 
			where DATE(a.trx_dt_sk_id) between  DATE_TRUNC(vdt_id, MONTH) and DATE(vdt_id)
			and a.netrevenue > 30
			and kpi_1 in ('DATA_BB_BASE', 'RITA', 'SIM_DEMAND', 'TOPUP', 'VOUCHER_DEMAND')
			group by 1,2,3,4,5 ;
		

create or replace table `data-bi-prd-935c.bi_stg.temp_daily_fav_site_dim` as 
select * from `data-dtptechm-prd-c7ca.dwh.daily_fav_site_dim`  where DATE(dt_id) between  DATE_TRUNC(vdt_id, MONTH) and DATE(vdt_id) ;


create or replace table `data-bi-prd-935c.bi_stg.temp_tmp_ale_rev_product_hit_channel` as 
			select
			a.sbscrptn_ek_id msisdn, vdt_id mth, trx_dt_sk_id,
			case when coalesce(d.validity,0) > 20 then 'Monthly' else 'Sachet' end as validity,
			case
				when process_nm in ('TOPUP') then 'Mobo Non-Trade'
				when process_nm in ('SIM_DEMAND', 'RITA', 'VOUCHER_DEMAND') then 'Mobo Trade'
				when process_nm in ('DATA_BB_BASE') then 'Organic'
			else 'N/A' end as channel_grp,
			count(distinct case when process_nm in ('RITA' ,  'ADDON_FORFEIT',  'ADDON_REDEEM',  'SIM_DEMAND',  'SIM_FORFEIT' ) then transaction_id
				when process_nm in ('VOUCHER_DEMAND','DATA_BB_BASE','TOPUP') then source_system_id end) as hits,
			sum(netrevenue) as netrevenue
			from `data-bi-prd-935c.bi_mart.rev_product_hit_channel` a
			left outer join 
			(
				 select product_rpt_nm, validity_days as validity, 
					row_number()over(partition by product_rpt_nm order by validity_days desc) as seq
				 from `data-dtptechm-prd-c7ca.dwh.ioh_calendarization_validity_dim_v3`
				 where primary_group = 'GROUP A'
			) d on a.product_name = d.product_rpt_nm and d.seq = 1
				where DATE(a.trx_dt_sk_id) between  DATE_TRUNC(vdt_id, MONTH) and DATE(vdt_id)
			and a.netrevenue > 30
			and process_nm in ('DATA_BB_BASE', 'RITA', 'SIM_DEMAND', 'TOPUP', 'VOUCHER_DEMAND')
			and service_type_name <> 'BROADBAND'
			group by 1,2,3,4,5 ;



create or replace table  `data-bi-prd-935c.bi_stg.temp_packsell_daily` as 
        
			select
			cast(msisdn as string) msisdn,vdt_id mth, b.site_id_dly site_id, 
			validity,
			channel_grp,
			sum(hits) hits, 
			sum(netrevenue) netrevenue
			from `data-bi-prd-935c.bi_stg.temp_mkt_product_next_level_report_final_v3` a 
			left outer join  `data-bi-prd-935c.bi_stg.temp_daily_fav_site_dim` b
				ON cast(a.msisdn as string) = cast(b.sbscrptn_ek_id as string) AND date(a.trx_dt_sk_id) = date(b.dt_id) 
			where DATE(a.trx_dt_sk_id) between  DATE_TRUNC(vdt_id, MONTH) and DATE(vdt_id)
		--	and a.netrevenue > 30
		--	and kpi_1 in ('DATA_BB_BASE', 'RITA', 'SIM_DEMAND', 'TOPUP', 'VOUCHER_DEMAND')
			group by 1,2,3,4,5

			UNION ALL 
			--NON Broadband
			select
			a.msisdn msisdn ,vdt_id, b.site_id_dly site_id,
			validity,
			channel_grp,
			 sum(hits)hits,
			sum(netrevenue) as netrevenue
			from `data-bi-prd-935c.bi_stg.temp_tmp_ale_rev_product_hit_channel` a
			left outer join `data-bi-prd-935c.bi_stg.temp_daily_fav_site_dim`  b
				ON cast(a.msisdn as string) = cast(b.sbscrptn_ek_id as string) AND date(a.trx_dt_sk_id) = date(b.dt_id) 
			where DATE(a.trx_dt_sk_id) between  DATE_TRUNC(vdt_id, MONTH) and DATE(vdt_id)
			group by 1,2,3,4,5
    		 ;
			
			
			
			


delete from `data-bi-prd-935c.bi_dev`.ioh_snd_master_kpi_detail where kpi like 'data_pack%' and dt_id = vdt_id and brand = '3ID';

insert into `data-bi-prd-935c.bi_dev`.ioh_snd_master_kpi_detail (brand,level,level_value,values, time_flag, insert_date ,kpi,dt_id)

SELECT '3ID' AS brand, 'site_id' level, site_id level_value,
cast(round(sum(netrevenue),0) as numeric)  values,
'MTD' time_flag, CURRENT_TIMESTAMP()  insert_date,'data_pack_rev' kpi, vdt_id dt_id
from `data-bi-prd-935c.bi_stg.temp_packsell_daily` where true 
group by 1,2,3,5,6,7
UNION ALL
SELECT '3ID' AS brand, 'site_id' level, site_id level_value,
cast(round(sum(netrevenue),0) as numeric)  values,
'MTD' time_flag, CURRENT_TIMESTAMP()  insert_date,'data_pack_rev_monthly' kpi, vdt_id dt_id
from `data-bi-prd-935c.bi_stg.temp_packsell_daily` where true 
and validity  ='Monthly'
group by 1,2,3,5,6,7
UNION ALL 
SELECT '3ID' AS brand, 'site_id' level, site_id level_value,
cast(round(sum(netrevenue),0) as numeric)  values,
'MTD' time_flag, CURRENT_TIMESTAMP()  insert_date,'data_pack_rev_sachet' kpi, vdt_id dt_id
from `data-bi-prd-935c.bi_stg.temp_packsell_daily` where true 
and validity  <> 'Monthly'
group by 1,2,3,5,6,7
UNION ALL 
SELECT '3ID' AS brand, 'site_id' level, site_id level_value,
cast(round(sum(hits),0) as numeric)  values,
'MTD' time_flag, CURRENT_TIMESTAMP()  insert_date,'data_pack_hits' kpi, vdt_id dt_id
from `data-bi-prd-935c.bi_stg.temp_packsell_daily` where true 
group by 1,2,3,5,6,7
UNION ALL
SELECT '3ID' AS brand, 'site_id' level, site_id level_value,
cast(round(sum(hits),0) as numeric)  values,
'MTD' time_flag, CURRENT_TIMESTAMP()  insert_date,'data_pack_hits_monthly' kpi, vdt_id dt_id
from `data-bi-prd-935c.bi_stg.temp_packsell_daily` where true 
and validity  ='Monthly'
group by 1,2,3,5,6,7
UNION ALL 
SELECT '3ID' AS brand, 'site_id' level, site_id level_value,
cast(round(sum(hits),0) as numeric)  values,
'MTD' time_flag, CURRENT_TIMESTAMP()  insert_date,'data_pack_hits_sachet' kpi, vdt_id dt_id
from `data-bi-prd-935c.bi_stg.temp_packsell_daily` where true 
and validity  <> 'Monthly'
group by 1,2,3,5,6,7  ;

    	
delete from `data-bi-prd-935c.bi_stg.temp_voucher_games`
where trx_dt_sk_id = vdt_id; 


insert into  `data-bi-prd-935c.bi_stg.temp_voucher_games`
select date(trx_dt_sk_id) trx_dt_sk_id,sbscrptn_ek_id,-- ,c.site_id_dly,
sum(case when product_id = 8 then net_revenue/1.11 else net_revenue end) as net_revenue
from `data-dtptechm-prd-c7ca.dwh.revenue_base` fct
left join `data-bi-prd-935c.bi_mart.ref_vas_games_prd` b on fct.service_type_category_2 = b.vas_prod
-- left outer join  `data-dtptechm-prd-c7ca.dwh.daily_fav_site_dim` c
				-- ON fct.sbscrptn_ek_id = c.sbscrptn_ek_id AND fct.trx_dt_sk_id = c.dt_id 
where date(trx_dt_sk_id) = vdt_id
and REGEXP_CONTAINS(service_type, r'VAS')
AND       
(struct(fct.process_nm,fct.revenue_src_ctgry) in ( select struct(process_nm,revenue_src_ctgry) from `data-dtptechm-prd-c7ca.dwh.demand_revenue_base_filter` where net_revenue_incl = 'Y') 
)and coalesce(fct.gl_cd,'NA') not in (select ref_cd from `data-dtptechm-prd-c7ca.dwh.rprt_fltr_ref_ctgry` where ref_type_cd = 'ACCRUAL_GL_CODE')
and tool_of_trade_ind = 'N'
 and (b.vas_prod is not null  -- matched in ref table
       or fct.service_type_category_2 in (
           'OTHERS|0771|', 'OTHERS|0773|', 'OTHERS|0774|', 'OTHERS|0775|', 'OTHERS|0776|', 'OTHERS|0777|', 'OTHERS|0778|',
           'OTHERS|0779|', 'OTHERS|0780|', 'OTHERS|0762|', 'OTHERS|0763|', 'OTHERS|0764|', 'OTHERS|0765|',
           'OTHERS|0772|', 'OTHERS|0781|', 'Nuon|0763|Nuon Voucher Games', '313|1111111111-994331|994331', 'OTHERS|0770|',
           'OTHERS|0677|', 'OTHERS|0743|', 'OTHERS|0747|', 'OTHERS|0752|', 'OTHERS|0756|', 'OTHERS|0757|', 'OTHERS|0758|',
           'OTHERS|0769|', 'OTHERS|0782|', 'OTHERS|0783|', 'OTHERS|0784|', 'OTHERS|0788|', 'OTHERS|0791|', 'OTHERS|0792|',
           'OTHERS|0793|', 'OTHERS|0798|', 'OTHERS|9870|', 'OTHERS|0794|', 'OTHERS|0795|', 'OTHERS|0796|', 'OTHERS|0797|',
           'OTHERS|0623|', 'OTHERS|0800|', 'OTHERS|0801|', 'OTHERS|0802|'
       ))
group by 1,2;


create or replace table `data-bi-prd-935c.bi_stg.temp_daily_fav_site_dim_vas` as 
select sbscrptn_ek_id,site_id_dly,date(dt_id) dt_id from `data-dtptechm-prd-c7ca.dwh.daily_fav_site_dim`  where DATE(dt_id) between  DATE_TRUNC(vdt_id, MONTH) and DATE(vdt_id) ;


delete from `data-bi-prd-935c.bi_stg.temp_voucher_games_sites`
where trx_dt_sk_id >= DATE_TRUNC(vdt_id, MONTH) and trx_dt_sk_id <= vdt_id ;


insert into `data-bi-prd-935c.bi_stg.temp_voucher_games_sites`  
select trx_dt_sk_id,site_id_dly, sum(net_revenue) netrevenue from 
`data-bi-prd-935c.bi_stg.temp_voucher_games` fct left join  `data-bi-prd-935c.bi_stg.temp_daily_fav_site_dim_vas` c
ON fct.sbscrptn_ek_id = c.sbscrptn_ek_id AND fct.trx_dt_sk_id = c.dt_id  
where trx_dt_sk_id >= DATE_TRUNC(vdt_id, MONTH) and trx_dt_sk_id <= vdt_id
group by 1,2; 



-- January 2025
delete from `data-bi-prd-935c.bi_dev`.ioh_snd_master_kpi_detail where kpi ='rev_game_vou'
AND dt_id = vdt_id and level='site_id' AND time_flag = 'mtd' and brand = '3ID';

insert into `data-bi-prd-935c.bi_dev`.ioh_snd_master_kpi_detail (brand,level,level_value,values, time_flag, insert_date ,kpi,dt_id)
SELECT '3ID' AS brand, 'site_id' level, site_id_dly level_value,
cast(round(sum(netrevenue),0) as numeric)  values,
'mtd' time_flag, CURRENT_TIMESTAMP()  insert_date,'rev_game_vou' kpi, vdt_id dt_id
from `data-bi-prd-935c.bi_stg.temp_voucher_games_sites`
where trx_dt_sk_id >= DATE_TRUNC(vdt_id, MONTH) and trx_dt_sk_id <= vdt_id
group by 1,2,3,5,6,7 ;

