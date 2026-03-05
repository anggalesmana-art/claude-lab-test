declare vdt_id date default @vdt_id;
		
delete from `data-bi-prd-935c.bi_dev`.ioh_snd_master_kpi_detail where dt_id = vdt_id and kpi in ('data_pack_hits','data_pack_hits_sachet','data_pack_hits_monthly','data_pack_rev','data_pack_rev_sachet','data_pack_rev_monthly') and brand = 'IM3';
insert into `data-bi-prd-935c.bi_dev`.ioh_snd_master_kpi_detail 
with packsell_daily as 
        (
    			select 
    			kpi AS kpi,
    			 daydate,
    			 site_id,
    			 case 
    			when kpi in ('DATA ORGANIC', 'PGI', 'REVENUE FDV', 'REVENUE MOBO', 'REVENUE VOUCHER ORI', 'REVENUE SP DATA', 'EWALLET', 'REVENUE OLA', 'REVENUE PGI WA') and
    				svc_typ in ('DATA','SMS','VOICE') then 'BROADBAND' 
    				when kpi in ('ALL PPU') and svc_typ in ('DATA') then 'BROADBAND' 
    				when kpi in ('ALL PPU') and svc_typ in ('SMS') then 'SMS + MMS' 
    				when kpi in ('ALL PPU') and svc_typ in ('VOICE') then 'VOICE + VIDEO' 
    				when kpi = 'VOICE' then 'VOICE + VIDEO'
    				when kpi = 'SMS' then 'SMS + MMS'
    				when kpi = 'VAS' then 'VAS + LOAN'
    				when kpi = 'LOAN BALANCE' then 'LOAN BALANCE'
    				else 'OTHERS' end as service_type_name,
    			case
    				when validity_package <= 4 then '1.Sachet'
    				when validity_package <= 20 then '2.Weekly'
    				when validity_package > 20 then '3.Monthly'
    				else '4.Unknown'
    			end validity_grp,
    			format_date('%Y-%m',daydate) AS trx_dt_sk_id,
    			msisdn,
    			SUM(hits) AS hits,
    			SUM(sales_price) AS netrevenue
    		FROM `data-cvm-prd-c324.dm.cvm_revenue_dashboard` a
    		WHERE daydate between  timestamp(DATE_TRUNC(date(vdt_id), MONTH))  and  timestamp(date(vdt_id)) --=======================================================================================================
    		  AND kpi IN ('DATA ORGANIC', 'PGI', 'REVENUE FDV', 'REVENUE MOBO', 'REVENUE VOUCHER ORI', 'REVENUE SP DATA', 'EWALLET', 'REVENUE OLA', 'REVENUE PGI WA')
    		GROUP BY 1,2,3,4,5,6,7
    		)
SELECT 'IM3' AS brand, 'site_id' level, site_id level_value,
			cast(round(sum(hits),0) as numeric)  value,
			'MTD' time_flag, current_timestamp() insert_date, 'data_pack_hits' kpi_id, date(vdt_id) dt_id
			from packsell_daily
		where service_type_name = 'BROADBAND'
		group by 1,2,3,5,6,7
UNION ALL 
SELECT 'IM3' AS brand, 'site_id' level, site_id level_value,
			cast(round(sum(hits),0) as numeric)  value,
			'MTD' time_flag, current_timestamp() insert_date , 'data_pack_hits_sachet' kpi_id, date(vdt_id) dt_id
			from packsell_daily
		where service_type_name = 'BROADBAND'
		    and validity_grp  <> '3.Monthly'
		group by 1,2,3,5,6,7
UNION ALL
SELECT 'IM3' AS brand, 'site_id' level, site_id level_value,
			cast(round(sum(hits),0) as numeric)  value,
			'MTD' time_flag, current_timestamp()  insert_date,'data_pack_hits_monthly' kpi_id, date(vdt_id) dt_id
			from packsell_daily
		where service_type_name = 'BROADBAND'
		and validity_grp  ='3.Monthly'
		group by 1,2,3,5,6,7
UNION ALL
SELECT 'IM3' AS brand, 'site_id' level, site_id level_value,
			cast(round(sum(netrevenue),0) as numeric)  value,
			'MTD' time_flag, current_timestamp() insert_date, 'data_pack_rev' kpi_id, date(vdt_id) dt_id
			from packsell_daily
		where service_type_name = 'BROADBAND'
		group by 1,2,3,5,6,7
UNION ALL 
SELECT 'IM3' AS brand, 'site_id' level, site_id level_value,
			cast(round(sum(netrevenue),0) as numeric)  value,
			'MTD' time_flag, current_timestamp() insert_date , 'data_pack_rev_sachet' kpi_id, date(vdt_id) dt_id
			from packsell_daily
		where service_type_name = 'BROADBAND'
		    and validity_grp  <> '3.Monthly'
		group by 1,2,3,5,6,7
UNION ALL
SELECT 'IM3' AS brand, 'site_id' level, site_id level_value,
			cast(round(sum(netrevenue),0) as numeric)  value,
			'MTD' time_flag, current_timestamp()  insert_date,'data_pack_rev_monthly' kpi_id, date(vdt_id) dt_id
			from packsell_daily
		where service_type_name = 'BROADBAND'
		and validity_grp  ='3.Monthly'
		group by 1,2,3,5,6,7;
