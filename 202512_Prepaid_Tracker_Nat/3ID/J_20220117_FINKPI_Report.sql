declare vdt_id date default @vdt_id;

drop table if exists `data-bi-prd-935c.bi_stg.revenue_base_tmp`;
create table `data-bi-prd-935c.bi_stg.revenue_base_tmp` as 
select  cast(FORMAT_DATE('%Y%m%d', CAST(trx_dt_sk_id AS DATE)) as INT64) as dt_sk_id,* except(trx_dt_sk_id)
from `data-dtptechm-prd-c7ca.dwh.revenue_base` where cast(trx_dt_sk_id as date) = vdt_id;


drop table if exists `data-bi-prd-935c.bi_stg.tmp_20220117_finKPI`;
create table `data-bi-prd-935c.bi_stg.tmp_20220117_finKPI` as
select cast(load_date as date) as dt_sk_id,
	upper(mp3_name) mp3_name,
	upper(service_type_name) service_type_name,
	CASE
		WHEN upper(COALESCE(service_type, 'BROADBAND')) IN ('BROADBAND')
		AND process_nm IN ('SIM_DEMAND', 'SIM_FORFEIT', 'ADDON_REDEEM')  
		OR process_nm LIKE 'FRC%' THEN 'SIM Broadband'
		WHEN upper(COALESCE(service_type, 'BROADBAND')) IN ('BROADBAND')
		AND process_nm IN (
			'VOUCHER_DEMAND',
			'UNLOCK_P3PRICE_AMORT',
			'UNLOCK_BALLOON_HOKI_DEMAND',
			'VOUCHER_FORFEIT'
		) THEN 'Unlock Data'
		WHEN upper(COALESCE(service_type, 'BROADBAND')) IN ('BROADBAND')
		AND process_nm IN (
			'RITA',
			'ADDON',
			'ADDON_PULSA',
			'RITA_PULSA',
			'CLIP_COMMISSION',
			'RITA_P3PRICE_AMORT',
			'RITA_BALLOON_HOKI_DEMAND',
			'STARS COMMISSION'
		) THEN 'RITA'
		WHEN upper(COALESCE(service_type, 'BROADBAND')) IN ('BROADBAND')
		AND (
			(
				process_nm IN ('EVC MARKUP', 'MARKUP_UNLOCK', 'MARKUP_RITA','BIMA MARKUP')
			)
			OR (
				revenue_src_ctgry = 'Ret'
				and process_nm in ('RITA_TOPUP', 'UNTAGGED_COMMISSION')
			)
			OR (revenue_src_ctgry = 'Subs')
		) THEN 'USSD'
		ELSE 'OTHERS'
	END as category,
	process_nm,
	source_channel,
	case
		when coalesce(product_id, 8) = 8 then 'PREPAID'
		else 'POSTPAID'
	end Cust_Type,
	sum(netrevenue) as netrevenue
from (
		select *,
			Coalesce(
				case
					when service_type in ('GPRS', 'GPRS_PACKAGE') then 'GPRS'
					when service_type in ('NA', 'NON_VMS', 'OTHERS') then 'OTHERS'
					when service_type in ('SMS', 'SMS_PACKAGE') then 'SMS'
					when service_type in ('VOICE', 'VOICE_PACKAGE', 'VOIP') then 'VOICE'
					else service_type
				end,
				'OTHERS'
			) as service_type_name,
			case
				when revenue_src_ctgry = 'Subs' then 'USSD'
				when revenue_src_ctgry <> 'Subs' then case
					when process_nm LIKE 'FRC%' then 'SIM BROADBAND'
					when process_nm in ('UNLOCK', 'UNLOCK_PULSA', 'VOUCHER_FORFEIT') then 'Unlock Data (Inc.NG)'
					when process_nm in (
						'ADDON_PULSA',
						'ADDON',
						'BALANCE TRANSFER',
						'CLIP_COMMISSION',
						'RITA',
						'RITA_P3PRICE_AMORT',
						'STARS COMMISSION'
					) then 'RITA'
					when process_nm in (
						'RITA_TOPUP',
						'UNTAGGED_COMMISSION',
						'EVC MARKUP',
						'MARKUP_RITA',
						'MARKUP_UNLOCK',
						'BIMA MARKUP'
					) then 'USSD'
					else 'OTHERS'
				end
			end as rowname
		from (
				SELECT load_date,
					mp3_location as mp3_name,
					fct.service_type,
					source_channel,
					Revenue_Type as Revenue_Type,
					process_nm as process_nm,
					product_nm AS PRODUCT_NAME,
					revenue_src_ctgry,
					product_id,
					0 AS GrossRev,
					sum(coalesce(Amort, 0)) new_other_amortization,
					sum(coalesce(Amort, 0)) * -1 AS NetRevenue
				FROM (
						select parse_date('%Y%m%d', cast(fct.dt_sk_id as string)) as load_date,
							upper(coalesce(cat.ctgry_ref_chld, 'HO NON BRANCH')) mp3_location,
							COALESCE(fct.service_type, 'BROADBAND') as service_type,
							source_channel,
							pd.product_type as Revenue_Type,
							fct.process_nm,
							product_id,
							case
								when coalesce(pd.product_rpt_nm, 'NA') <> 'NA' then pd.product_rpt_nm
								when coalesce(pd.product_src_nm, 'NA') <> 'NA' then pd.product_src_nm
								when coalesce(pd.product_rpt_nm_alt, 'NA') <> 'NA' then pd.product_rpt_nm_alt
								else pd.product_primary_ref
							end as product_nm,
							fct.revenue_src_ctgry,
							sum(
								case
									when product_id = 8
									and fct.dt_sk_id < 20220401 THEN commission / 1.1
									when product_id = 8
									and fct.dt_sk_id >= 20220401
									and fct.dt_sk_id < 20250101 THEN commission / 1.11
									when product_id = 8
									and fct.dt_sk_id >= 20250101 THEN commission / 1.11
									when product_id <> 8 THEN commission
								end
							) as Amort
						from `data-bi-prd-935c.bi_stg.revenue_base_tmp` fct
							left join `data-dtptechm-prd-c7ca.dwh.product_dim` pd ON pd.product_sk_id = fct.product_sk_id
							LEFT JOIN `data-dtptechm-prd-c7ca.dwh.channel_dim` cd ON fct.demand_mp3_channel_sk_id = cd.channel_sk_id
							LEFT JOIN `data-dtptechm-prd-c7ca.dwh.rprt_fltr_ref_ctgry` cat ON cat.ref_type_cd = 'MP3'
							AND cd.channel_id = cat.ref_cd
						JOIN `data-dtptechm-prd-c7ca.dwh.demand_revenue_base_filter` AS drbf
							ON fct.process_nm = drbf.process_nm
							AND fct.revenue_src_ctgry = drbf.revenue_src_ctgry
						WHERE drbf.net_amort_incl = 'Y'
							and parse_date('%Y%m%d', cast(fct.dt_sk_id as string)) = vdt_id
							AND revenue_book_incl_ind = 'INCLUDE'
						group by 1,
							2,
							3,
							4,
							5,
							6,
							7,
							8,
							9
					) FCT
				group by 1,
					2,
					3,
					4,
					5,
					6,
					7,
					8,
					9
				union all
				select parse_date('%Y%m%d', cast(fct.dt_sk_id as string)) as load_date,
					upper(coalesce(cat.ctgry_ref_chld, 'HO NON BRANCH')) mp3_location,
					COALESCE(fct.service_type, 'BROADBAND') as service_type,
					source_channel,
					pd.product_type as Revenue_Type,
					fct.process_nm as process_nm,
					case
						-- when source_channel='TARIFF_ADJUSTED' then fct.product_name
						when coalesce(pd.product_rpt_nm, 'NA') <> 'NA' then pd.product_rpt_nm
						when coalesce(pd.product_src_nm, 'NA') <> 'NA' then pd.product_src_nm
						when coalesce(pd.product_rpt_nm_alt, 'NA') <> 'NA' then pd.product_rpt_nm_alt
						else pd.product_primary_ref
					end as product_nm,
					fct.revenue_src_ctgry,
					product_id,
					sum(
						case
							When fct.product_sk_id = 516800 Then 45454.5454545454 
							When fct.product_sk_id = 516600 Then 31818.1818181818 
							When fct.product_sk_id = 516900 Then 18181.8181818182 
							When fct.product_sk_id = 517000 Then 38181.8181818182 
							when fct.product_id = 8
							and fct.dt_sk_id < 20220401 THEN gross_revenue / 1.1
							when fct.product_id = 8
							and fct.dt_sk_id >= 20220401
							and fct.dt_sk_id < 20250101 THEN gross_revenue / 1.11
							when fct.product_id = 8
							and fct.dt_sk_id >= 20250101 THEN gross_revenue / 1.11
							when fct.product_id <> 8 THEN gross_revenue
						end
					) as GrossRev,
					sum(
						case
							when fct.product_id = 8
							and fct.dt_sk_id < 20220401 THEN fct.commission / 1.1
							when fct.product_id = 8
							and fct.dt_sk_id >= 20220401
							and fct.dt_sk_id < 20250101 THEN fct.commission / 1.11
							when fct.product_id = 8
							and fct.dt_sk_id >= 20250101 THEN fct.commission / 1.11
							when fct.product_id <> 8 THEN fct.commission
							ELSE 0
						end
					) as Amort,
					sum(
						case
							When fct.product_sk_id = 516800 Then 45454.5454545454 
							When fct.product_sk_id = 516600 Then 31818.1818181818 
							When fct.product_sk_id = 516900 Then 18181.8181818182 
							When fct.product_sk_id = 517000 Then 38181.8181818182 
							when fct.product_id = 8
							and fct.dt_sk_id < 20220401 THEN net_revenue / 1.1
							when fct.product_id = 8
							and fct.dt_sk_id >= 20220401
							and fct.dt_sk_id < 20250101 THEN net_revenue / 1.11
							when fct.product_id = 8
							and fct.dt_sk_id >= 20250101 THEN net_revenue / 1.11
							when fct.product_id <> 8 THEN net_revenue
						end
					) as NetRevenue
				from `data-bi-prd-935c.bi_stg.revenue_base_tmp` fct
					left join `data-dtptechm-prd-c7ca.dwh.product_dim` pd ON pd.product_sk_id = fct.product_sk_id
					LEFT JOIN `data-dtptechm-prd-c7ca.dwh.channel_dim` cd ON fct.demand_mp3_channel_sk_id = cd.channel_sk_id
					LEFT JOIN `data-dtptechm-prd-c7ca.dwh.rprt_fltr_ref_ctgry` cat ON cat.ref_type_cd = 'MP3'
					AND cd.channel_id = cat.ref_cd
				JOIN `data-dtptechm-prd-c7ca.dwh.demand_revenue_base_filter` AS drbf
							ON fct.process_nm = drbf.process_nm
							AND fct.revenue_src_ctgry = drbf.revenue_src_ctgry
						WHERE drbf.net_revenue_incl = 'Y'
					and parse_date('%Y%m%d', cast(fct.dt_sk_id as string)) = vdt_id
					and coalesce(fct.gl_cd, '') not in (
						select ref_cd
						from `data-dtptechm-prd-c7ca.dwh.rprt_fltr_ref_ctgry`
						where ref_type_cd = 'ACCRUAL_GL_CODE'
					)
				group by 1,
					2,
					3,
					4,
					5,
					6,
					7,
					8,
					9
			) tab
	) A
group by 1,
	2,
	3,
	4,
	5,
	6,
	7;
drop table if exists `data-bi-prd-935c.bi_stg.tmp_20220117_finKPI_caccrc`;
create table `data-bi-prd-935c.bi_stg.tmp_20220117_finKPI_caccrc` as
select fct.fu_kpi_smry_dt_sk_id as load_date,
	fct.fu_kpi_smry_dt_sk_id as dt_sk_id,
	upper(
		coalesce(
			case
				when mp3_desc = 'NA' then 'Central West North Jkt'
				else mp3_desc
			end,
			'Central West North Jkt'
		)
	) as mp3_name,
	fct.report_row_nm,
	coalesce(ref.ref_cd_desc, fct.revenue_type) as report_super_row_nm,
	fct.revenue_type,
	case
		when mp3_desc = '3 STORE' then 'Customer Operation'
		when mp3_desc = '3 BUSINESS' then 'Corporate'
		else 'Consumer'
	end as channel,
	case
		when coalesce(product_id, 8) = 8 then 'PREPAID'
		else 'POSTPAID'
	end Cust_Type,
	sum(value_revenue) as caccrc_amount
from `data-dtptechm-prd-c7ca.dwh_olap.fu_kpi_summary` fct
	left join `data-dtptechm-prd-c7ca.dwh.rprt_fltr_ref_ctgry` ref on fct.revenue_type = ref.ref_cd
	and fct.report_row_nm = ref.ctgry_ref_chld
	and ref.ref_type_cd = 'FKPI_CAC_CRC_MAPPING'
WHERE (
		fct.report_tab_nm = 'FKPI_SUMMARY_CAC_CRC'
		AND parse_date(
			'%Y%m%d',
			cast(fct.fu_kpi_smry_dt_sk_id as string)
		) = vdt_id
		and cast(fu_kpi_smry_month_sk_id as date) = date_trunc(vdt_id, month)
		and coalesce(product_id, 8) = 8
		and coalesce(tool_of_trade_ind, 'N') = 'N'
	)
group by 1,
	2,
	3,
	4,
	5,
	6,
	7,
	8;
drop table if exists `data-bi-prd-935c.bi_stg.tmp_20220117_finKPI_other_rev`;
create table `data-bi-prd-935c.bi_stg.tmp_20220117_finKPI_other_rev` as
select *
from (
		select parse_date('%Y%m%d', cast(fct.dt_sk_id as string)) load_date,
			fct.dt_sk_id as dt_sk_id,
			-- upper(
			-- 	coalesce(
			-- 		case
			-- 			when mp3_location = 'NA' then 'Central West North Jkt'
			-- 			else mp3_location
			-- 		end,
			-- 		'Central West North Jkt'
			-- 	)
			-- ) 
			null as mp3_name,
			fct.process_nm,
			case
				when coalesce(product_id, 8) = 8 then 'PREPAID'
				else 'POSTPAID'
			end Cust_Type,
			sum(
				case
					when upper(coalesce(service_type, 'BROADBAND')) IN ('OTHERS', 'NA')
					AND product_id = 8
					and fct.dt_sk_id < 20220401 THEN coalesce(net_revenue, 0) / 1.1
					when upper(coalesce(service_type, 'BROADBAND')) IN ('OTHERS', 'NA')
					AND product_id = 8
					and fct.dt_sk_id >= 20220401
					and fct.dt_sk_id < 20250101 THEN coalesce(net_revenue, 0) / 1.11
					when upper(coalesce(service_type, 'BROADBAND')) IN ('OTHERS', 'NA')
					AND product_id = 8
					and fct.dt_sk_id >= 20250101 THEN coalesce(net_revenue, 0) / 1.11
					when upper(coalesce(service_type, 'BROADBAND')) IN ('OTHERS', 'NA')
					AND product_id <> 8 THEN coalesce(net_revenue, 0)
				end
			) as Others_Revenue
		from `data-bi-prd-935c.bi_stg.revenue_base_tmp` fct
		JOIN (select * from `data-dtptechm-prd-c7ca.dwh.revenue_base_filter` 
					where (
							net_revenue_incl = 'Y'
							OR net_amort_incl = 'Y'
						)  ) drbf 
									ON fct.process_nm = drbf.process_nm
							AND fct.revenue_src_ctgry = drbf.revenue_src_ctgry
		where -- cast(month_sk_id as date) = date_trunc(vdt_id, month) and
			 parse_date('%Y%m%d', cast(fct.dt_sk_id as string)) = vdt_id
			and coalesce(gl_cd, '') not in (
				select ref_cd
				from `data-dtptechm-prd-c7ca.dwh.rprt_fltr_ref_ctgry`
				where ref_type_cd = 'ACCRUAL_GL_CODE'
			)
			and upper(coalesce(service_type, 'BROADBAND')) IN ('OTHERS', 'NA')
		group by 1,
			2,
			3,
			4,
			5
	) A
WHERE Others_Revenue <> 0;
-- ==============================
-- BRANCH
-- ==============================
--=========================
-- OPERATIONAL REVENUE
--=========================
delete from `data-bi-prd-935c.bi_mart.j_20220117_finkpi_branch`
where dt_sk_id = vdt_id;
-- truncate `data-bi-prd-935c.bi_mart.j_20220117_finkpi_branch`;
insert into `data-bi-prd-935c.bi_mart.j_20220117_finkpi_branch`
select dt_sk_id,
	Cust_Type,
	upper(mp3_name),
	case
		when service_type_name in ('VIDEO', 'VOICE') then 'KPI-003'
		when service_type_name in ('SMS', 'MMS') then 'KPI-004'
		when service_type_name in ('BLACKBERRY') then 'KPI-016'
		when service_type_name in ('ROAMING') then 'KPI-005'
		when service_type_name in ('VAS') then 'KPI-008'
		when service_type_name = 'BROADBAND'
		and category = 'SIM Broadband' then 'KPI-019'
		when service_type_name = 'BROADBAND'
		and category = 'OTHERS'
		and process_nm = 'ADDON_FORFEIT' then 'KPI-019'
		when service_type_name = 'BROADBAND'
		and category = 'Unlock Data' then 'KPI-020'
		when service_type_name = 'BROADBAND'
		and category = 'RITA' then 'KPI-021'
		when service_type_name = 'BROADBAND'
		and category = 'USSD'
		and process_nm = 'TOPUP' then 'KPI-022'
		when service_type_name = 'BROADBAND'
		and category = 'USSD'
		and process_nm <> 'TOPUP'
		and source_channel not in ('EXPERIAN', 'ALJABOR') then 'KPI-023'
		when service_type_name = 'BROADBAND'
		and category = 'USSD'
		and process_nm <> 'TOPUP'
		and source_channel in ('EXPERIAN', 'ALJABOR') then 'KPI-014'
		when service_type_name = 'GPRS' then 'KPI-024'
		else '9999'
	end as KPI_Code,
	case
		when service_type_name in ('VIDEO', 'VOICE') then ' Voice + Video'
		when service_type_name in ('SMS', 'MMS') then ' SMS + MMS'
		when service_type_name in ('BLACKBERRY') then ' Others'
		when service_type_name in ('ROAMING') then ' Roaming'
		when service_type_name in ('VAS') then 'Digital (Gross)'
		when service_type_name = 'BROADBAND'
		and category = 'SIM Broadband' then '  SIM Broadband'
		when service_type_name = 'BROADBAND'
		and category = 'OTHERS'
		and process_nm = 'ADDON_FORFEIT' then '  SIM Broadband'
		when service_type_name = 'BROADBAND'
		and category = 'Unlock Data' then '  Voucher'
		when service_type_name = 'BROADBAND'
		and category = 'RITA' then '  RITA'
		when service_type_name = 'BROADBAND'
		and category = 'USSD'
		and process_nm = 'TOPUP' then '  EVC'
		when service_type_name = 'BROADBAND'
		and category = 'USSD'
		and process_nm <> 'TOPUP'
		and source_channel not in ('EXPERIAN', 'ALJABOR') then '  Customer Direct excluding - MFS -Principal data loan'
		when service_type_name = 'BROADBAND'
		and category = 'USSD'
		and process_nm <> 'TOPUP'
		and source_channel in ('EXPERIAN', 'ALJABOR') then 'Principal data loan'
		when service_type_name = 'GPRS' then ' PAYU'
		else ' Others'
	end as service_type_name,
	cast(sum(netrevenue) as bignumeric) as netrevenue
from `data-bi-prd-935c.bi_stg.tmp_20220117_finKPI`
where process_nm not in (
		'EVC MARKUP',
		'FRC_BALLOON_HOKI_DEMAND',
		'FRC_BALLOON_HOKI_SUPPLY',
		'MARKUP_RITA',
		'MARKUP_UNLOCK',
		'BIMA MARKUP',
		'RITA_BALLOON_HOKI_DEMAND',
		'RITA_BALLOON_HOKI_SUPPLY',
		'STARS COMMISSION',
		'UNLOCK_BALLOON_HOKI_DEMAND',
		'UNLOCK_BALLOON_HOKI_SUPPLY'
	)
	and coalesce(source_channel, '') not in ('ODS_TIBCO')
	and dt_sk_id = vdt_id
group by 1,
	2,
	3,
	4,
	5
order by 1,
	2,
	3,
	4,
	5 -- distributed by (dt_sk_id);
;
insert into `data-bi-prd-935c.bi_mart.j_20220117_finkpi_branch`
select dt_sk_id,
	Cust_Type,
	'NATIONAL' mp3_name,
	case
		when service_type_name in ('VIDEO', 'VOICE') then 'KPI-003'
		when service_type_name in ('SMS', 'MMS') then 'KPI-004'
		when service_type_name in ('BLACKBERRY') then 'KPI-016'
		when service_type_name in ('ROAMING') then 'KPI-005'
		when service_type_name in ('VAS') then 'KPI-008'
		when service_type_name = 'BROADBAND'
		and category = 'SIM Broadband' then 'KPI-019'
		when service_type_name = 'BROADBAND'
		and category = 'OTHERS'
		and process_nm = 'ADDON_FORFEIT' then 'KPI-019'
		when service_type_name = 'BROADBAND'
		and category = 'Unlock Data' then 'KPI-020'
		when service_type_name = 'BROADBAND'
		and category = 'RITA' then 'KPI-021'
		when service_type_name = 'BROADBAND'
		and category = 'USSD'
		and process_nm = 'TOPUP' then 'KPI-022'
		when service_type_name = 'BROADBAND'
		and category = 'USSD'
		and process_nm <> 'TOPUP'
		and source_channel not in ('EXPERIAN', 'ALJABOR') then 'KPI-023'
		when service_type_name = 'BROADBAND'
		and category = 'USSD'
		and process_nm <> 'TOPUP'
		and source_channel in ('EXPERIAN', 'ALJABOR') then 'KPI-014'
		when service_type_name = 'GPRS' then 'KPI-024'
		else '9999'
	end as KPI_Code,
	case
		when service_type_name in ('VIDEO', 'VOICE') then ' Voice + Video'
		when service_type_name in ('SMS', 'MMS') then ' SMS + MMS'
		when service_type_name in ('BLACKBERRY') then ' Others'
		when service_type_name in ('ROAMING') then ' Roaming'
		when service_type_name in ('VAS') then 'Digital (Gross)'
		when service_type_name = 'BROADBAND'
		and category = 'SIM Broadband' then '  SIM Broadband'
		when service_type_name = 'BROADBAND'
		and category = 'OTHERS'
		and process_nm = 'ADDON_FORFEIT' then '  SIM Broadband'
		when service_type_name = 'BROADBAND'
		and category = 'Unlock Data' then '  Voucher'
		when service_type_name = 'BROADBAND'
		and category = 'RITA' then '  RITA'
		when service_type_name = 'BROADBAND'
		and category = 'USSD'
		and process_nm = 'TOPUP' then '  EVC'
		when service_type_name = 'BROADBAND'
		and category = 'USSD'
		and process_nm <> 'TOPUP'
		and source_channel not in ('EXPERIAN', 'ALJABOR') then '  Customer Direct excluding - MFS -Principal data loan'
		when service_type_name = 'BROADBAND'
		and category = 'USSD'
		and process_nm <> 'TOPUP'
		and source_channel in ('EXPERIAN', 'ALJABOR') then 'Principal data loan'
		when service_type_name = 'GPRS' then ' PAYU'
		else ' Others'
	end as service_type_name,
	cast(sum(netrevenue) as bignumeric) as netrevenue
from `data-bi-prd-935c.bi_stg.tmp_20220117_finKPI`
where process_nm not in (
		'EVC MARKUP',
		'FRC_BALLOON_HOKI_DEMAND',
		'FRC_BALLOON_HOKI_SUPPLY',
		'MARKUP_RITA',
		'MARKUP_UNLOCK',
		'BIMA MARKUP',
		'RITA_BALLOON_HOKI_DEMAND',
		'RITA_BALLOON_HOKI_SUPPLY',
		'STARS COMMISSION',
		'UNLOCK_BALLOON_HOKI_DEMAND',
		'UNLOCK_BALLOON_HOKI_SUPPLY'
	)
	and coalesce(source_channel, '') not in ('ODS_TIBCO')
	and dt_sk_id = vdt_id
group by 1,
	2,
	3,
	4,
	5
order by 1,
	2,
	3,
	4,
	5;
insert into `data-bi-prd-935c.bi_mart.j_20220117_finkpi_branch`
select dt_sk_id,
	Cust_Type,
	upper(mp3_name) mp3_name,
	'KPI-001' as KPI_Code,
	'DEMAND REVENUE GROSS' as service_type_name,
	null as netrevenue
from `data-bi-prd-935c.bi_stg.tmp_20220117_finKPI`
where dt_sk_id = vdt_id
group by 1,
	2,
	3;
insert into `data-bi-prd-935c.bi_mart.j_20220117_finkpi_branch`
select dt_sk_id,
	Cust_Type,
	'NATIONAL' mp3_name,
	'KPI-001' as KPI_Code,
	'DEMAND REVENUE GROSS' as service_type_name,
	null as netrevenue
from `data-bi-prd-935c.bi_stg.tmp_20220117_finKPI`
where dt_sk_id = vdt_id
group by 1,
	2,
	3;
insert into `data-bi-prd-935c.bi_mart.j_20220117_finkpi_branch`
select dt_sk_id,
	Cust_Type,
	upper(mp3_name) mp3_name,
	'KPI-026' as KPI_Code,
	' EDU Rev/SFH' as service_type_name,
	cast(
		sum(
			case
				when coalesce(source_channel, '') in ('ODS_TIBCO') then netrevenue
				else 0
			end
		) as bignumeric
	) as netrevenue
from `data-bi-prd-935c.bi_stg.tmp_20220117_finKPI`
where dt_sk_id = vdt_id
group by 1,
	2,
	3,
	4
order by 1,
	2,
	3,
	4;
insert into `data-bi-prd-935c.bi_mart.j_20220117_finkpi_branch`
select dt_sk_id,
	Cust_Type,
	'NATIONAL' mp3_name,
	'KPI-026' as KPI_Code,
	' EDU Rev/SFH' as service_type_name,
	cast(
		sum(
			case
				when coalesce(source_channel, '') in ('ODS_TIBCO') then netrevenue
				else 0
			end
		) as bignumeric
	) as netrevenue
from `data-bi-prd-935c.bi_stg.tmp_20220117_finKPI`
where dt_sk_id = vdt_id
group by 1,
	2,
	3,
	4
order by 1,
	2,
	3,
	4;
insert into `data-bi-prd-935c.bi_mart.j_20220117_finkpi_branch`
select dt_sk_id,
	Cust_Type,
	upper(mp3_name) mp3_name,
	'KPI-018' as KPI_Code,
	' Mobile Broadband' as service_type_name,
	sum(netrevenue) as netrevenue
from `data-bi-prd-935c.bi_mart.j_20220117_finkpi_branch`
where dt_sk_id = vdt_id
	and KPI_Code in (
		'KPI-019',
		'KPI-020',
		'KPI-021',
		'KPI-022',
		'KPI-023'
	)
group by 1,
	2,
	3;
insert into `data-bi-prd-935c.bi_mart.j_20220117_finkpi_branch`
select dt_sk_id,
	Cust_Type,
	upper(mp3_name) mp3_name,
	'KPI-017' as KPI_Code,
	'Data' as service_type_name,
	sum(netrevenue) as netrevenue
from `data-bi-prd-935c.bi_mart.j_20220117_finkpi_branch`
where dt_sk_id = vdt_id
	and KPI_Code in ('KPI-018', 'KPI-024')
group by 1,
	2,
	3;
insert into `data-bi-prd-935c.bi_mart.j_20220117_finkpi_branch`
select a.dt_sk_id,
	Cust_Type,
	upper(mp3_name) mp3_name,
	'KPI-009' as KPI_Code,
	'Digital Cost' as service_type_name,
	cast(
		case
			when rate = 0 then 0
			else (rate) *(a.netrevenue / c.netrevenue)
		end as bignumeric
	) as netrevenue
from (
		select dt_sk_id,
			Cust_Type,
			mp3_name,
			sum(netrevenue) as netrevenue
		from `data-bi-prd-935c.bi_stg.tmp_20220117_finKPI`
		where dt_sk_id = vdt_id
			and service_type_name in ('VAS')
		group by 1,
			2,
			3
	) a
	left join (
		select dt_sk_id,
			max(cast(amount as numeric)) as rate
		from `data-bi-prd-935c.bi_mart.j_20220117_finkpi_manual_rev`
		where dt_sk_id = vdt_id
			and kpi_name in ('Content Cost', 'Demand_Content Cost ')
		group by 1
	) b on a.dt_sk_id = b.dt_sk_id
	left join (
		select dt_sk_id,
			sum(netrevenue) as netrevenue
		from `data-bi-prd-935c.bi_stg.tmp_20220117_finKPI`
		where dt_sk_id = vdt_id
			and service_type_name in ('VAS')
		group by 1
	) c on a.dt_sk_id = c.dt_sk_id;
insert into `data-bi-prd-935c.bi_mart.j_20220117_finkpi_branch`
select a.dt_sk_id,
	Cust_Type,
	'NATIONAL' mp3_name,
	'KPI-009' as KPI_Code,
	'Digital Cost' as service_type_name,
	cast(
		case
			when max(rate) = 0 then 0
			else (max(a.netrevenue) / max(c.netrevenue)) * max(rate)
		end as bignumeric
	) as netrevenue
from (
		select dt_sk_id,
			Cust_Type,
			sum(netrevenue) as netrevenue
		from `data-bi-prd-935c.bi_stg.tmp_20220117_finKPI`
		where dt_sk_id = vdt_id
			and service_type_name in ('VAS')
		group by 1,
			2
	) a
	left join (
		select dt_sk_id,
			max(cast(amount as numeric)) as rate
		from `data-bi-prd-935c.bi_mart.j_20220117_finkpi_manual_rev`
		where dt_sk_id = vdt_id
			and kpi_name in ('Content Cost', 'Demand_Content Cost ')
		group by 1
	) b on a.dt_sk_id = b.dt_sk_id
	left join (
		select dt_sk_id,
			sum(netrevenue) as netrevenue
		from `data-bi-prd-935c.bi_stg.tmp_20220117_finKPI`
		where dt_sk_id = vdt_id
			and service_type_name in ('VAS')
		group by 1
	) c on a.dt_sk_id = c.dt_sk_id
group by 1,
	2,
	3;
insert into `data-bi-prd-935c.bi_mart.j_20220117_finkpi_branch`
select dt_sk_id,
	Cust_Type,
	'NATIONAL' mp3_name,
	KPI_Code as KPI_Code,
	service_type_name,
	sum(netrevenue) as netrevenue
from (
		select a.dt_sk_id,
			'PREPAID' Cust_Type,
			'KPI-031' as KPI_Code,
			' Adj. Operational Revenue' as service_type_name,
			cast(sum(amount) as bignumeric) as netrevenue
		from (
				select dt_sk_id
				from `data-bi-prd-935c.bi_stg.tmp_20220117_finKPI`
				where dt_sk_id = vdt_id
				group by 1
			) a
			left join (
				select dt_sk_id,
					sum(cast(amount as bignumeric)) as amount
				from `data-bi-prd-935c.bi_mart.j_20220117_finkpi_manual_rev`
				where dt_sk_id = vdt_id
					and kpi_name in (
						'Demand_Tri Stock',
						'Demand_RITA SWAP',
						'Demand_Corporate Bulk Revenue',
						'Demand_2020 SUM Balance',
						'Demand_Others'
					)
				group by 1
			) b on a.dt_sk_id = b.dt_sk_id
		group by 1
		union all
		select a.dt_sk_id,
			'PREPAID' Cust_Type,
			'KPI-031' as KPI_Code,
			' Adj. Operational Revenue' as service_type_name,
			cast(sum(amount) as bignumeric) as netrevenue
		from (
				select dt_sk_id
				from `data-bi-prd-935c.bi_stg.tmp_20220117_finKPI`
				where dt_sk_id = vdt_id
				group by 1
			) a
			left join (
				select dt_sk_id,
					sum(cast(amount as bignumeric)) as amount
				from `data-bi-prd-935c.bi_mart.j_20220117_finkpi_manual_rev`
				where dt_sk_id = vdt_id
					and dt_sk_id >= '2022-04-01'
					and kpi_name in ('Demand_Demand Adjusment ( Special RITA)')
				group by 1
			) b on a.dt_sk_id = b.dt_sk_id
		group by 1
		union all
		select a.dt_sk_id,
			'PREPAID' Cust_Type,
			'KPI-031' as KPI_Code,
			' Adj. Operational Revenue' as service_type_name,
			cast(
				sum(
					case
						when (
							(
								date_trunc(b.dt_sk_id, month) in ('2022-02-01', '2022-03-01', '2022-04-01')
							)
							or b.dt_sk_id >= '2022-05-01'
						) then 0
						else amount
					end
				) as bignumeric
			) as netrevenue
		from (
				select dt_sk_id
				from `data-bi-prd-935c.bi_stg.tmp_20220117_finKPI`
				where dt_sk_id = vdt_id
				group by 1
			) a
			left join (
				select dt_sk_id,
					sum(cast(amount as numeric)) as amount
				from `data-bi-prd-935c.bi_mart.j_20220117_finkpi_manual_rev`
				where dt_sk_id = vdt_id
					and kpi_name in (
						'Adj. Operational Revenue',
						'Demand_Adj. Operational Revenue'
					)
				group by 1
			) b on a.dt_sk_id = b.dt_sk_id
		group by 1
	) a
group by 1,
	2,
	3,
	4,
	5;
insert into `data-bi-prd-935c.bi_mart.j_20220117_finkpi_branch`
select dt_sk_id,
	Cust_Type,
	'HO NON BRANCH' mp3_name,
	KPI_Code as KPI_Code,
	service_type_name,
	sum(netrevenue) as netrevenue
from (
		select a.dt_sk_id,
			'PREPAID' Cust_Type,
			'KPI-031' as KPI_Code,
			' Adj. Operational Revenue' as service_type_name,
			sum(amount) as netrevenue
		from (
				select dt_sk_id
				from `data-bi-prd-935c.bi_stg.tmp_20220117_finKPI`
				where dt_sk_id = vdt_id
				group by 1
			) a
			left join (
				select dt_sk_id,
					sum(cast(amount as bignumeric)) as amount
				from `data-bi-prd-935c.bi_mart.j_20220117_finkpi_manual_rev`
				where dt_sk_id = vdt_id
					and kpi_name in (
						'Demand_Tri Stock',
						'Demand_RITA SWAP',
						'Demand_2020 SUM Balance',
						'Demand_Others'
					)
				group by 1
			) b on a.dt_sk_id = b.dt_sk_id
		group by 1
		union all
		select a.dt_sk_id,
			'PREPAID' Cust_Type,
			'KPI-031' as KPI_Code,
			' Adj. Operational Revenue' as service_type_name,
			sum(amount) as netrevenue
		from (
				select dt_sk_id
				from `data-bi-prd-935c.bi_stg.tmp_20220117_finKPI`
				where dt_sk_id = vdt_id
				group by 1
			) a
			left join (
				select dt_sk_id,
					sum(cast(amount as bignumeric)) as amount
				from `data-bi-prd-935c.bi_mart.j_20220117_finkpi_manual_rev`
				where dt_sk_id = vdt_id
					and dt_sk_id >= '2022-04-01'
					and kpi_name in ('Demand_Demand Adjusment ( Special RITA)')
				group by 1
			) b on a.dt_sk_id = b.dt_sk_id
		group by 1
	) a
group by 1,
	2,
	3,
	4,
	5;
insert into `data-bi-prd-935c.bi_mart.j_20220117_finkpi_branch`
select dt_sk_id,
	Cust_Type,
	'3 BUSINESS' mp3_name,
	KPI_Code as KPI_Code,
	service_type_name,
	sum(netrevenue) as netrevenue
from (
		select a.dt_sk_id,
			'PREPAID' Cust_Type,
			'KPI-031' as KPI_Code,
			' Adj. Operational Revenue' as service_type_name,
			sum(amount) as netrevenue
		from (
				select dt_sk_id
				from `data-bi-prd-935c.bi_stg.tmp_20220117_finKPI`
				where dt_sk_id = vdt_id
				group by 1
			) a
			left join (
				select dt_sk_id,
					sum(amount) as amount
				from `data-bi-prd-935c.bi_mart.j_20220117_finkpi_manual_rev`
				where dt_sk_id = vdt_id
					and kpi_name in (
						'Adj. Operational Revenue',
						'Demand_Adj. Operational Revenue'
					)
				group by 1
			) b on a.dt_sk_id = b.dt_sk_id
		group by 1
	) a
group by 1,
	2,
	3,
	4,
	5;
insert into `data-bi-prd-935c.bi_mart.j_20220117_finkpi_branch`
select dt_sk_id,
	Cust_Type,
	'HO NON BRANCH' mp3_name,
	KPI_Code as KPI_Code,
	service_type_name,
	sum(netrevenue) as netrevenue
from (
		select a.dt_sk_id,
			'PREPAID' Cust_Type,
			'KPI-031' as KPI_Code,
			' Adj. Operational Revenue' as service_type_name,
			sum(amount) as netrevenue
		from (
				select dt_sk_id
				from `data-bi-prd-935c.bi_stg.tmp_20220117_finKPI`
				where dt_sk_id = vdt_id
				group by 1
			) a
			left join (
				select dt_sk_id,
					sum(amount) as amount
				from `data-bi-prd-935c.bi_mart.j_20220117_finkpi_manual_rev`
				where dt_sk_id = vdt_id
					and kpi_name in ('Demand_Corporate Bulk Revenue')
				group by 1
			) b on a.dt_sk_id = b.dt_sk_id
		group by 1
		union all
		select a.dt_sk_id,
			'PREPAID' Cust_Type,
			'KPI-031' as KPI_Code,
			' Adj. Operational Revenue' as service_type_name,
			sum(
				case
					when (
						(
							date_trunc(b.dt_sk_id, month) in ('2022-02-01', '2022-03-01', '2022-04-01')
						)
						or b.dt_sk_id >= '2022-05-01'
					) then amount * -1
					else amount
				end
			) as netrevenue
		from (
				select dt_sk_id
				from `data-bi-prd-935c.bi_stg.tmp_20220117_finKPI`
				where dt_sk_id = vdt_id
				group by 1
			) a
			left join (
				select dt_sk_id,
					sum(amount) as amount
				from `data-bi-prd-935c.bi_mart.j_20220117_finkpi_manual_rev`
				where dt_sk_id = vdt_id
					and kpi_name in (
						'Adj. Operational Revenue',
						'Demand_Adj. Operational Revenue'
					)
				group by 1
			) b on a.dt_sk_id = b.dt_sk_id
		group by 1
	) a
group by 1,
	2,
	3,
	4,
	5;
insert into `data-bi-prd-935c.bi_mart.j_20220117_finkpi_branch`
select a.dt_sk_id,
	'PREPAID' Cust_Type,
	'NATIONAL' mp3_name,
	'KPI-027' as KPI_Code,
	' SFH Refund' as service_type_name,
	sum(amount) as netrevenue
from (
		select dt_sk_id
		from `data-bi-prd-935c.bi_stg.tmp_20220117_finKPI`
		where dt_sk_id = vdt_id
		group by 1
	) a
	left join (
		select dt_sk_id,
			sum(amount) as amount
		from `data-bi-prd-935c.bi_mart.j_20220117_finkpi_manual_rev`
		where dt_sk_id = vdt_id
			and kpi_name in ('Demand_Refund SFH')
		group by 1
	) b on a.dt_sk_id = b.dt_sk_id
group by 1;
insert into `data-bi-prd-935c.bi_mart.j_20220117_finkpi_branch`
select a.dt_sk_id,
	'PREPAID' Cust_Type,
	'HO NON BRANCH' mp3_name,
	'KPI-027' as KPI_Code,
	' SFH Refund' as service_type_name,
	sum(amount) as netrevenue
from (
		select dt_sk_id
		from `data-bi-prd-935c.bi_stg.tmp_20220117_finKPI`
		where dt_sk_id = vdt_id
		group by 1
	) a
	left join (
		select dt_sk_id,
			sum(amount) as amount
		from `data-bi-prd-935c.bi_mart.j_20220117_finkpi_manual_rev`
		where dt_sk_id = vdt_id
			and kpi_name in ('Demand_Refund SFH')
		group by 1
	) b on a.dt_sk_id = b.dt_sk_id
group by 1;
insert into `data-bi-prd-935c.bi_mart.j_20220117_finkpi_branch`
select a.dt_sk_id,
	'PREPAID' Cust_Type,
	'NATIONAL' mp3_name,
	'KPI-029' as KPI_Code,
	' PABX' as service_type_name,
	sum(amount) as netrevenue
from (
		select dt_sk_id
		from `data-bi-prd-935c.bi_stg.tmp_20220117_finKPI`
		where dt_sk_id = vdt_id
		group by 1
	) a
	left join (
		select dt_sk_id,
			sum(amount) as amount
		from `data-bi-prd-935c.bi_mart.j_20220117_finkpi_manual_rev`
		where dt_sk_id = vdt_id
			and kpi_name in ('Demand_PABX')
		group by 1
	) b on a.dt_sk_id = b.dt_sk_id
group by 1;
insert into `data-bi-prd-935c.bi_mart.j_20220117_finkpi_branch`
select a.dt_sk_id,
	'PREPAID' Cust_Type,
	'3 BUSINESS' mp3_name,
	'KPI-029' as KPI_Code,
	' PABX' as service_type_name,
	sum(amount) as netrevenue
from (
		select dt_sk_id
		from `data-bi-prd-935c.bi_stg.tmp_20220117_finKPI`
		where dt_sk_id = vdt_id
		group by 1
	) a
	left join (
		select dt_sk_id,
			sum(amount) as amount
		from `data-bi-prd-935c.bi_mart.j_20220117_finkpi_manual_rev`
		where dt_sk_id = vdt_id
			and kpi_name in ('Demand_PABX')
		group by 1
	) b on a.dt_sk_id = b.dt_sk_id
group by 1;
insert into `data-bi-prd-935c.bi_mart.j_20220117_finkpi_branch`
select a.dt_sk_id,
	'PREPAID' Cust_Type,
	'NATIONAL' mp3_name,
	'KPI-030' as KPI_Code,
	' IFRS 15' as service_type_name,
	sum(amount) as netrevenue
from (
		select dt_sk_id
		from `data-bi-prd-935c.bi_stg.tmp_20220117_finKPI`
		where dt_sk_id = vdt_id
		group by 1
	) a
	left join (
		select dt_sk_id,
			sum(amount) as amount
		from `data-bi-prd-935c.bi_mart.j_20220117_finkpi_manual_rev`
		where dt_sk_id = vdt_id
			and kpi_name in ('Demand_Demand Adjusment ( Special RITA)')
		group by 1
	) b on a.dt_sk_id = b.dt_sk_id
group by 1;
insert into `data-bi-prd-935c.bi_mart.j_20220117_finkpi_branch`
select a.dt_sk_id,
	'PREPAID' Cust_Type,
	'NATIONAL' mp3_name,
	'KPI-030' as KPI_Code,
	' IFRS 15' as service_type_name,
	sum(amount) * -1 as netrevenue
from (
		select dt_sk_id
		from `data-bi-prd-935c.bi_stg.tmp_20220117_finKPI`
		where dt_sk_id = vdt_id
		group by 1
	) a
	left join (
		select dt_sk_id,
			sum(amount) as amount
		from `data-bi-prd-935c.bi_mart.j_20220117_finkpi_manual_rev`
		where dt_sk_id = vdt_id
			and dt_sk_id >= '2022-04-01'
			and kpi_name in ('Demand_Demand Adjusment ( Special RITA)')
		group by 1
	) b on a.dt_sk_id = b.dt_sk_id
group by 1;
insert into `data-bi-prd-935c.bi_mart.j_20220117_finkpi_branch`
select a.dt_sk_id,
	'PREPAID' Cust_Type,
	'HO NON BRANCH' mp3_name,
	'KPI-030' as KPI_Code,
	' IFRS 15' as service_type_name,
	sum(amount) as netrevenue
from (
		select dt_sk_id
		from `data-bi-prd-935c.bi_stg.tmp_20220117_finKPI`
		where dt_sk_id = vdt_id
		group by 1
	) a
	left join (
		select dt_sk_id,
			sum(amount) as amount
		from `data-bi-prd-935c.bi_mart.j_20220117_finkpi_manual_rev`
		where dt_sk_id = vdt_id
			and kpi_name in ('Demand_Demand Adjusment ( Special RITA)')
		group by 1
	) b on a.dt_sk_id = b.dt_sk_id
group by 1;
insert into `data-bi-prd-935c.bi_mart.j_20220117_finkpi_branch`
select a.dt_sk_id,
	'PREPAID' Cust_Type,
	'HO NON BRANCH' mp3_name,
	'KPI-030' as KPI_Code,
	' IFRS 15' as service_type_name,
	sum(amount) * -1 as netrevenue
from (
		select dt_sk_id
		from `data-bi-prd-935c.bi_stg.tmp_20220117_finKPI`
		where dt_sk_id = vdt_id
		group by 1
	) a
	left join (
		select dt_sk_id,
			sum(amount) as amount
		from `data-bi-prd-935c.bi_mart.j_20220117_finkpi_manual_rev`
		where dt_sk_id = vdt_id
			and dt_sk_id >= '2022-04-01'
			and kpi_name in ('Demand_Demand Adjusment ( Special RITA)')
		group by 1
	) b on a.dt_sk_id = b.dt_sk_id
group by 1;
insert into `data-bi-prd-935c.bi_mart.j_20220117_finkpi_branch`
select a.dt_sk_id,
	Cust_Type,
	upper(mp3_name) mp3_name,
	'KPI-013' as KPI_Code,
	'MFS (Experian processing fee)' as service_type_name,
	sum(amount) as netrevenue
from (
		select dt_sk_id
		from `data-bi-prd-935c.bi_stg.tmp_20220117_finKPI`
		where dt_sk_id = vdt_id
		group by 1
	) a
	left join (
		select load_date,
			Cust_Type,
			cast(mp3_name as string) as mp3_name,
			sum(others_revenue) as amount
		from `data-bi-prd-935c.bi_stg.tmp_20220117_finKPI_other_rev`
		where load_date = vdt_id
			and process_nm = 'EXPERIAN_PROCESSING_FEE'
		group by 1,
			2,
			3
		order by 1,
			2,
			3
	) b on a.dt_sk_id = b.load_date
group by 1,
	2,
	3;
insert into `data-bi-prd-935c.bi_mart.j_20220117_finkpi_branch`
select a.dt_sk_id,
	Cust_Type,
	'NATIONAL' mp3_name,
	'KPI-013' as KPI_Code,
	'MFS (Experian processing fee)' as service_type_name,
	sum(amount) as netrevenue
from (
		select dt_sk_id
		from `data-bi-prd-935c.bi_stg.tmp_20220117_finKPI`
		where dt_sk_id = vdt_id
		group by 1
	) a
	left join (
		select load_date,
			Cust_Type,
			sum(others_revenue) as amount
		from `data-bi-prd-935c.bi_stg.tmp_20220117_finKPI_other_rev`
		where load_date = vdt_id
			and process_nm = 'EXPERIAN_PROCESSING_FEE'
		group by 1,
			2
		order by 1,
			2
	) b on a.dt_sk_id = b.load_date
group by 1,
	2;
insert into `data-bi-prd-935c.bi_mart.j_20220117_finkpi_branch`
select a.dt_sk_id,
	Cust_Type,
	upper(mp3_name) mp3_name,
	'KPI-015' as KPI_Code,
	'Transfer balance fee' as service_type_name,
	sum(amount) as netrevenue
from (
		select dt_sk_id
		from `data-bi-prd-935c.bi_stg.tmp_20220117_finKPI`
		where dt_sk_id = vdt_id
		group by 1
	) a
	left join (
		select load_date,
			Cust_Type,
			cast(mp3_name as string) as mp3_name,
			sum(others_revenue) as amount
		from `data-bi-prd-935c.bi_stg.tmp_20220117_finKPI_other_rev`
		where load_date = vdt_id
			and process_nm = 'BALANCE TRANSFER'
		group by 1,
			2,
			3
		order by 1,
			2,
			3
	) b on a.dt_sk_id = b.load_date
group by 1,
	2,
	3;
insert into `data-bi-prd-935c.bi_mart.j_20220117_finkpi_branch`
select a.dt_sk_id,
	Cust_Type,
	'NATIONAL' mp3_name,
	'KPI-015' as KPI_Code,
	'Transfer balance fee' as service_type_name,
	sum(amount) as netrevenue
from (
		select dt_sk_id
		from `data-bi-prd-935c.bi_stg.tmp_20220117_finKPI`
		where dt_sk_id = vdt_id
		group by 1
	) a
	left join (
		select load_date,
			Cust_Type,
			sum(others_revenue) as amount
		from `data-bi-prd-935c.bi_stg.tmp_20220117_finKPI_other_rev`
		where load_date = vdt_id
			and process_nm = 'BALANCE TRANSFER'
		group by 1,
			2
		order by 1,
			2
	) b on a.dt_sk_id = b.load_date
group by 1,
	2;
insert into `data-bi-prd-935c.bi_mart.j_20220117_finkpi_branch`
select dt_sk_id,
	Cust_Type,
	upper(mp3_name) mp3_name,
	KPI_Code as KPI_Code,
	service_type_name,
	sum(netrevenue) as netrevenue
from (
		select dt_sk_id,
			Cust_Type,
			cast(mp3_name as string) as mp3_name,
			'KPI-016' as KPI_Code,
			' Others' as service_type_name,
			sum(netrevenue) as netrevenue
		from `data-bi-prd-935c.bi_mart.j_20220117_finkpi_branch`
		where dt_sk_id = vdt_id
			and KPI_Code in ('9999')
		group by 1,
			2,
			3
		union all
		select dt_sk_id,
			Cust_Type,
			upper(mp3_name) mp3_name,
			'KPI-016' as KPI_Code,
			' Others' as service_type_name,
			sum(netrevenue) * -1 as netrevenue
		from `data-bi-prd-935c.bi_mart.j_20220117_finkpi_branch`
		where dt_sk_id = vdt_id
			and KPI_Code in ('KPI-013', 'KPI-015')
		group by 1,
			2,
			3
	) a
group by 1,
	2,
	3,
	4,
	5;
delete from `data-bi-prd-935c.bi_mart.j_20220117_finkpi_branch`
where KPI_Code in ('9999');
insert into `data-bi-prd-935c.bi_mart.j_20220117_finkpi_branch`
select a.dt_sk_id,
	'PREPAID' Cust_Type,
	'NATIONAL' mp3_name,
	'KPI-011' as KPI_Code,
	'  B2C portion of A2P domestic' as service_type_name,
	sum(amount) * max(c.rate) as netrevenue
from (
		select dt_sk_id
		from `data-bi-prd-935c.bi_stg.tmp_20220117_finKPI`
		where dt_sk_id = vdt_id
		group by 1
	) a
	left join (
		select dt_sk_id,
			sum(amount) as amount
		from `data-bi-prd-935c.bi_mart.j_20220117_finkpi_manual_rev`
		where dt_sk_id = vdt_id
			and kpi_name in ('Demand_A2P Domestic')
		group by 1
	) b on a.dt_sk_id = b.dt_sk_id
	left join (
		select dt_sk_id,
			sum(amount) as rate
		from `data-bi-prd-935c.bi_mart.j_20220117_finkpi_manual_rev`
		where dt_sk_id = vdt_id
			and kpi_name in ('Demand_A2P Domestic - Digital')
		group by 1
	) c on a.dt_sk_id = c.dt_sk_id
group by 1,
	2,
	3;
insert into `data-bi-prd-935c.bi_mart.j_20220117_finkpi_branch`
select a.dt_sk_id,
	'PREPAID' Cust_Type,
	'HO NON BRANCH' mp3_name,
	'KPI-011' as KPI_Code,
	'  B2C portion of A2P domestic' as service_type_name,
	sum(amount) * max(c.rate) as netrevenue
from (
		select dt_sk_id
		from `data-bi-prd-935c.bi_stg.tmp_20220117_finKPI`
		where dt_sk_id = vdt_id
		group by 1
	) a
	left join (
		select dt_sk_id,
			sum(amount) as amount
		from `data-bi-prd-935c.bi_mart.j_20220117_finkpi_manual_rev`
		where dt_sk_id = vdt_id
			and kpi_name in ('Demand_A2P Domestic')
		group by 1
	) b on a.dt_sk_id = b.dt_sk_id
	left join (
		select dt_sk_id,
			sum(amount) as rate
		from `data-bi-prd-935c.bi_mart.j_20220117_finkpi_manual_rev`
		where dt_sk_id = vdt_id
			and kpi_name in ('Demand_A2P Domestic - Digital')
		group by 1
	) c on a.dt_sk_id = c.dt_sk_id
group by 1,
	2,
	3;
insert into `data-bi-prd-935c.bi_mart.j_20220117_finkpi_branch`
select a.dt_sk_id,
	'PREPAID' Cust_Type,
	'NATIONAL' mp3_name,
	'KPI-010' as KPI_Code,
	'  B2B portion of A2P domestic' as service_type_name,
	sum(amount) * max(c.rate) as netrevenue
from (
		select dt_sk_id
		from `data-bi-prd-935c.bi_stg.tmp_20220117_finKPI`
		where dt_sk_id = vdt_id
		group by 1
	) a
	left join (
		select dt_sk_id,
			sum(amount) as amount
		from `data-bi-prd-935c.bi_mart.j_20220117_finkpi_manual_rev`
		where dt_sk_id = vdt_id
			and kpi_name in ('Demand_A2P Domestic')
		group by 1
	) b on a.dt_sk_id = b.dt_sk_id
	left join (
		select dt_sk_id,
			sum(amount) as rate
		from `data-bi-prd-935c.bi_mart.j_20220117_finkpi_manual_rev`
		where dt_sk_id = vdt_id
			and kpi_name in ('Demand_A2P Domestic - Non Digital')
		group by 1
	) c on a.dt_sk_id = c.dt_sk_id
group by 1,
	2,
	3;
insert into `data-bi-prd-935c.bi_mart.j_20220117_finkpi_branch`
select a.dt_sk_id,
	'PREPAID' Cust_Type,
	'3 BUSINESS' mp3_name,
	'KPI-010' as KPI_Code,
	'  B2B portion of A2P domestic' as service_type_name,
	sum(amount) * max(c.rate) as netrevenue
from (
		select dt_sk_id
		from `data-bi-prd-935c.bi_stg.tmp_20220117_finKPI`
		where dt_sk_id = vdt_id
		group by 1
	) a
	left join (
		select dt_sk_id,
			sum(amount) as amount
		from `data-bi-prd-935c.bi_mart.j_20220117_finkpi_manual_rev`
		where dt_sk_id = vdt_id
			and kpi_name in ('Demand_A2P Domestic')
		group by 1
	) b on a.dt_sk_id = b.dt_sk_id
	left join (
		select dt_sk_id,
			sum(amount) as rate
		from `data-bi-prd-935c.bi_mart.j_20220117_finkpi_manual_rev`
		where dt_sk_id = vdt_id
			and kpi_name in ('Demand_A2P Domestic - Non Digital')
		group by 1
	) c on a.dt_sk_id = c.dt_sk_id
group by 1,
	2,
	3;
insert into `data-bi-prd-935c.bi_mart.j_20220117_finkpi_branch`
select dt_sk_id,
	Cust_Type,
	upper(mp3_name) mp3_name,
	'KPI-007' as KPI_Code,
	'Digital (Nett)' as service_type_name,
	sum(netrevenue) as netrevenue
from `data-bi-prd-935c.bi_mart.j_20220117_finkpi_branch`
where dt_sk_id = vdt_id
	and KPI_Code in ('KPI-008', 'KPI-009')
group by 1,
	2,
	3;
insert into `data-bi-prd-935c.bi_mart.j_20220117_finkpi_branch`
select dt_sk_id,
	Cust_Type,
	upper(mp3_name) mp3_name,
	'KPI-028' as KPI_Code,
	'Revenue (Accrual Operational)' as service_type_name,
	sum(netrevenue) as netrevenue
from `data-bi-prd-935c.bi_mart.j_20220117_finkpi_branch`
where dt_sk_id = vdt_id
	and KPI_Code in ('KPI-029', 'KPI-030', 'KPI-031')
group by 1,
	2,
	3;
insert into `data-bi-prd-935c.bi_mart.j_20220117_finkpi_branch`
select dt_sk_id,
	Cust_Type,
	upper(mp3_name) mp3_name,
	'KPI-025' as KPI_Code,
	'EDU Revenue/SFH' as service_type_name,
	sum(netrevenue) as netrevenue
from `data-bi-prd-935c.bi_mart.j_20220117_finkpi_branch`
where dt_sk_id = vdt_id
	and KPI_Code in ('KPI-026', 'KPI-027')
group by 1,
	2,
	3;
insert into `data-bi-prd-935c.bi_mart.j_20220117_finkpi_branch`
select dt_sk_id,
	Cust_Type,
	upper(mp3_name) mp3_name,
	'KPI-012' as KPI_Code,
	'  MFS' as service_type_name,
	sum(netrevenue) as netrevenue
from `data-bi-prd-935c.bi_mart.j_20220117_finkpi_branch`
where dt_sk_id = vdt_id
	and KPI_Code in ('KPI-013', 'KPI-014', 'KPI-015')
group by 1,
	2,
	3;
insert into `data-bi-prd-935c.bi_mart.j_20220117_finkpi_branch`
select dt_sk_id,
	Cust_Type,
	upper(mp3_name) mp3_name,
	'KPI-006' as KPI_Code,
	' Digital + MFS' as service_type_name,
	sum(netrevenue) as netrevenue
from `data-bi-prd-935c.bi_mart.j_20220117_finkpi_branch`
where dt_sk_id = vdt_id
	and KPI_Code in ('KPI-007', 'KPI-010', 'KPI-011', 'KPI-012')
group by 1,
	2,
	3;
insert into `data-bi-prd-935c.bi_mart.j_20220117_finkpi_branch`
select dt_sk_id,
	Cust_Type,
	upper(mp3_name) mp3_name,
	'KPI-002' as KPI_Code,
	'Non-data' as service_type_name,
	sum(netrevenue) as netrevenue
from `data-bi-prd-935c.bi_mart.j_20220117_finkpi_branch`
where dt_sk_id = vdt_id
	and KPI_Code in (
		'KPI-003',
		'KPI-004',
		'KPI-005',
		'KPI-006',
		'KPI-016'
	)
group by 1,
	2,
	3;
insert into `data-bi-prd-935c.bi_mart.j_20220117_finkpi_branch`
select dt_sk_id,
	Cust_Type,
	upper(mp3_name) mp3_name,
	'KPI-032' as KPI_Code,
	'OPERATIONAL REVENUE' as service_type_name,
	sum(netrevenue) as netrevenue
from `data-bi-prd-935c.bi_mart.j_20220117_finkpi_branch`
where dt_sk_id = vdt_id
	and KPI_Code in ('KPI-002', 'KPI-017', 'KPI-025', 'KPI-028')
group by 1,
	2,
	3;
--=========================
-- NON OPERATIONAL REVENUE
--=========================
insert into `data-bi-prd-935c.bi_mart.j_20220117_finkpi_branch`
select a.dt_sk_id,
	Cust_Type,
	'NATIONAL' mp3_name,
	'KPI-033' as KPI_Code,
	'Incoming Revenue - Voice' as service_type_name,
	sum(amount) as netrevenue
from (
		select dt_sk_id
		from `data-bi-prd-935c.bi_stg.tmp_20220117_finKPI`
		where dt_sk_id = vdt_id
		group by 1
	) a
	left join (
		select parse_date('%Y%m%d', cast(load_date as string)) as dt_sk_id,
			Cust_Type,
			mp3_name,
			sum(caccrc_amount) amount
		from `data-bi-prd-935c.bi_stg.tmp_20220117_finKPI_caccrc`
		where parse_date('%Y%m%d', cast(load_date as string)) = vdt_id
			and report_row_nm like 'incoming_interconnect_voice%'
		group by 1,
			2,
			3
	) b on a.dt_sk_id = b.dt_sk_id
group by 1,
	2,
	3;
insert into `data-bi-prd-935c.bi_mart.j_20220117_finkpi_branch`
select a.dt_sk_id,
	Cust_Type,
	'HO NON BRANCH' mp3_name,
	'KPI-033' as KPI_Code,
	'Incoming Revenue - Voice' as service_type_name,
	sum(amount) as netrevenue
from (
		select dt_sk_id
		from `data-bi-prd-935c.bi_stg.tmp_20220117_finKPI`
		where dt_sk_id = vdt_id
		group by 1
	) a
	left join (
		select parse_date('%Y%m%d', cast(load_date as string)) as dt_sk_id,
			Cust_Type,
			mp3_name,
			sum(caccrc_amount) amount
		from `data-bi-prd-935c.bi_stg.tmp_20220117_finKPI_caccrc`
		where parse_date('%Y%m%d', cast(load_date as string)) = vdt_id
			and report_row_nm like 'incoming_interconnect_voice%'
		group by 1,
			2,
			3
	) b on a.dt_sk_id = b.dt_sk_id
group by 1,
	2,
	3;
insert into `data-bi-prd-935c.bi_mart.j_20220117_finkpi_branch`
select a.dt_sk_id,
	Cust_Type,
	'NATIONAL' mp3_name,
	'KPI-034' as KPI_Code,
	'Incoming Revenue - SMS' as service_type_name,
	sum(amount) as netrevenue
from (
		select dt_sk_id
		from `data-bi-prd-935c.bi_stg.tmp_20220117_finKPI`
		where dt_sk_id = vdt_id
		group by 1
	) a
	left join (
		select parse_date('%Y%m%d', cast(load_date as string)) as dt_sk_id,
			Cust_Type,
			mp3_name,
			sum(caccrc_amount) amount
		from `data-bi-prd-935c.bi_stg.tmp_20220117_finKPI_caccrc`
		where parse_date('%Y%m%d', cast(load_date as string)) = vdt_id
			and report_row_nm like 'incoming_revenue_non_voice%'
		group by 1,
			2,
			3
	) b on a.dt_sk_id = b.dt_sk_id
group by 1,
	2,
	3;
insert into `data-bi-prd-935c.bi_mart.j_20220117_finkpi_branch`
select a.dt_sk_id,
	Cust_Type,
	'HO NON BRANCH' mp3_name,
	'KPI-034' as KPI_Code,
	'Incoming Revenue - SMS' as service_type_name,
	sum(amount) as netrevenue
from (
		select dt_sk_id
		from `data-bi-prd-935c.bi_stg.tmp_20220117_finKPI`
		where dt_sk_id = vdt_id
		group by 1
	) a
	left join (
		select parse_date('%Y%m%d', cast(load_date as string)) as dt_sk_id,
			Cust_Type,
			mp3_name,
			sum(caccrc_amount) amount
		from `data-bi-prd-935c.bi_stg.tmp_20220117_finKPI_caccrc`
		where parse_date('%Y%m%d', cast(load_date as string)) = vdt_id
			and report_row_nm like 'incoming_revenue_non_voice%'
		group by 1,
			2,
			3
	) b on a.dt_sk_id = b.dt_sk_id
group by 1,
	2,
	3;
insert into `data-bi-prd-935c.bi_mart.j_20220117_finkpi_branch`
select a.dt_sk_id,
	Cust_Type,
	'NATIONAL' mp3_name,
	'KPI-035' as KPI_Code,
	'Inbound roaming' as service_type_name,
	sum(amount) as netrevenue
from (
		select dt_sk_id
		from `data-bi-prd-935c.bi_stg.tmp_20220117_finKPI`
		where dt_sk_id = vdt_id
		group by 1
	) a
	left join (
		select parse_date('%Y%m%d', cast(load_date as string)) as dt_sk_id,
			Cust_Type,
			mp3_name,
			sum(caccrc_amount) amount
		from `data-bi-prd-935c.bi_stg.tmp_20220117_finKPI_caccrc`
		where parse_date('%Y%m%d', cast(load_date as string)) = vdt_id
			and report_row_nm = 'inbound_roaming'
		group by 1,
			2,
			3
	) b on a.dt_sk_id = b.dt_sk_id
group by 1,
	2,
	3;
insert into `data-bi-prd-935c.bi_mart.j_20220117_finkpi_branch`
select a.dt_sk_id,
	Cust_Type,
	'HO NON BRANCH' mp3_name,
	'KPI-035' as roaming,
	'Inbound roaming' as service_type_name,
	sum(amount) as netrevenue
from (
		select dt_sk_id
		from `data-bi-prd-935c.bi_stg.tmp_20220117_finKPI`
		where dt_sk_id = vdt_id
		group by 1
	) a
	left join (
		select parse_date('%Y%m%d', cast(load_date as string)) as dt_sk_id,
			Cust_Type,
			mp3_name,
			sum(caccrc_amount) amount
		from `data-bi-prd-935c.bi_stg.tmp_20220117_finKPI_caccrc`
		where parse_date('%Y%m%d', cast(load_date as string)) = vdt_id
			and report_row_nm = 'inbound_roaming'
		group by 1,
			2,
			3
	) b on a.dt_sk_id = b.dt_sk_id
group by 1,
	2,
	3;
insert into `data-bi-prd-935c.bi_mart.j_20220117_finkpi_branch`
select a.dt_sk_id,
	Cust_Type,
	'NATIONAL' mp3_name,
	'KPI-036' as KPI_Code,
	'Forfeiture Pulsa' as service_type_name,
	sum(amount) as netrevenue
from (
		select dt_sk_id
		from `data-bi-prd-935c.bi_stg.tmp_20220117_finKPI`
		where dt_sk_id = vdt_id
		group by 1
	) a
	left join (
		select parse_date('%Y%m%d', cast(load_date as string)) as dt_sk_id,
			Cust_Type,
			mp3_name,
			sum(caccrc_amount) amount
		from `data-bi-prd-935c.bi_stg.tmp_20220117_finKPI_caccrc`
		where parse_date('%Y%m%d', cast(load_date as string)) = vdt_id
			and report_row_nm = 'other'
		group by 1,
			2,
			3
	) b on a.dt_sk_id = b.dt_sk_id
group by 1,
	2,
	3;
insert into `data-bi-prd-935c.bi_mart.j_20220117_finkpi_branch`
select a.dt_sk_id,
	Cust_Type,
	'HO NON BRANCH' mp3_name,
	'KPI-036' as KPI_Code,
	'Forfeiture Pulsa' as service_type_name,
	sum(amount) as netrevenue
from (
		select dt_sk_id
		from `data-bi-prd-935c.bi_stg.tmp_20220117_finKPI`
		where dt_sk_id = vdt_id
		group by 1
	) a
	left join (
		select parse_date('%Y%m%d', cast(load_date as string)) as dt_sk_id,
			Cust_Type,
			mp3_name,
			sum(caccrc_amount) amount
		from `data-bi-prd-935c.bi_stg.tmp_20220117_finKPI_caccrc`
		where parse_date('%Y%m%d', cast(load_date as string)) = vdt_id
			and report_row_nm = 'other'
		group by 1,
			2,
			3
	) b on a.dt_sk_id = b.dt_sk_id
group by 1,
	2,
	3;
insert into `data-bi-prd-935c.bi_mart.j_20220117_finkpi_branch`
select a.dt_sk_id,
	'PREPAID' Cust_Type,
	'NATIONAL' mp3_name,
	'KPI-039' as KPI_Code,
	'  A2P International' as service_type_name,
	sum(amount) as netrevenue
from (
		select dt_sk_id
		from `data-bi-prd-935c.bi_stg.tmp_20220117_finKPI`
		where dt_sk_id = vdt_id
		group by 1
	) a
	left join (
		select dt_sk_id,
			sum(amount) as amount
		from `data-bi-prd-935c.bi_mart.j_20220117_finkpi_manual_rev`
		where dt_sk_id = vdt_id
			and kpi_name in ('Demand_A2P International')
		group by 1
	) b on a.dt_sk_id = b.dt_sk_id
group by 1,
	2;
insert into `data-bi-prd-935c.bi_mart.j_20220117_finkpi_branch`
select a.dt_sk_id,
	'PREPAID' Cust_Type,
	'3 BUSINESS' mp3_name,
	'KPI-039' as KPI_Code,
	'  A2P International' as service_type_name,
	sum(amount) as netrevenue
from (
		select dt_sk_id
		from `data-bi-prd-935c.bi_stg.tmp_20220117_finKPI`
		where dt_sk_id = vdt_id
		group by 1
	) a
	left join (
		select dt_sk_id,
			sum(amount) as amount
		from `data-bi-prd-935c.bi_mart.j_20220117_finkpi_manual_rev`
		where dt_sk_id = vdt_id
			and kpi_name in ('Demand_A2P International')
		group by 1
	) b on a.dt_sk_id = b.dt_sk_id
group by 1,
	2;
insert into `data-bi-prd-935c.bi_mart.j_20220117_finkpi_branch`
select dt_sk_id,
	Cust_Type,
	upper(mp3_name) mp3_name,
	'KPI-038' as KPI_Code,
	' A2P' as service_type_name,
	sum(netrevenue) as netrevenue
from `data-bi-prd-935c.bi_mart.j_20220117_finkpi_branch`
where dt_sk_id = vdt_id
	and KPI_Code in ('KPI-039')
group by 1,
	2,
	3;
insert into `data-bi-prd-935c.bi_mart.j_20220117_finkpi_branch`
select dt_sk_id,
	'PREPAID' Cust_Type,
	'NATIONAL' mp3_name,
	KPI_Code as KPI_Code,
	service_type_name,
	sum(netrevenue) as netrevenue
from (
		select a.dt_sk_id,
			'KPI-040' as KPI_Code,
			' Adj. Non Operational Revenue' as service_type_name,
			sum(amount) as netrevenue
		from (
				select dt_sk_id
				from `data-bi-prd-935c.bi_stg.tmp_20220117_finKPI`
				where dt_sk_id = vdt_id
				group by 1
			) a
			left join (
				select dt_sk_id,
					sum(amount) as amount
				from `data-bi-prd-935c.bi_mart.j_20220117_finkpi_manual_rev`
				where dt_sk_id = vdt_id
					and kpi_name in ('Demand_A2P Other')
				group by 1
			) b on a.dt_sk_id = b.dt_sk_id
		group by 1,
			2,
			3
		union all
		select a.dt_sk_id,
			'KPI-040' as KPI_Code,
			' Adj. Non Operational Revenue' as service_type_name,
			sum(amount) as netrevenue
		from (
				select dt_sk_id
				from `data-bi-prd-935c.bi_stg.tmp_20220117_finKPI`
				where dt_sk_id = vdt_id
				group by 1
			) a
			left join (
				select dt_sk_id,
					sum(0) as amount
				from `data-bi-prd-935c.bi_mart.j_20220117_finkpi_manual_rev`
				where dt_sk_id = vdt_id
					and kpi_name in ('Others & Adjutsment')
				group by 1
			) b -- exclude since doble counting
			on a.dt_sk_id = b.dt_sk_id
		group by 1,
			2,
			3
		union all
		select a.dt_sk_id,
			'KPI-040' as KPI_Code,
			' Adj. Non Operational Revenue' as service_type_name,
			sum(amount) as netrevenue
		from (
				select dt_sk_id
				from `data-bi-prd-935c.bi_stg.tmp_20220117_finKPI`
				where dt_sk_id = vdt_id
				group by 1
			) a
			left join (
				select dt_sk_id,
					sum(amount) as amount
				from `data-bi-prd-935c.bi_mart.j_20220117_finkpi_manual_rev`
				where dt_sk_id = vdt_id
					and kpi_name in ('Adj. Non-Operational Revenue')
				group by 1
			) b on a.dt_sk_id = b.dt_sk_id
		group by 1,
			2,
			3
	) a
group by 1,
	2,
	3,
	4,
	5;
insert into `data-bi-prd-935c.bi_mart.j_20220117_finkpi_branch`
select dt_sk_id,
	'PREPAID' Cust_Type,
	'HO NON BRANCH' mp3_name,
	KPI_Code as KPI_Code,
	service_type_name,
	sum(netrevenue) as netrevenue
from (
		select a.dt_sk_id,
			'KPI-040' as KPI_Code,
			' Adj. Non Operational Revenue' as service_type_name,
			sum(amount) as netrevenue
		from (
				select dt_sk_id
				from `data-bi-prd-935c.bi_stg.tmp_20220117_finKPI`
				where dt_sk_id = vdt_id
				group by 1
			) a
			left join (
				select dt_sk_id,
					sum(amount) as amount
				from `data-bi-prd-935c.bi_mart.j_20220117_finkpi_manual_rev`
				where dt_sk_id = vdt_id
					and kpi_name in ('Demand_A2P Other')
				group by 1
			) b on a.dt_sk_id = b.dt_sk_id
		group by 1,
			2,
			3
		union all
		select a.dt_sk_id,
			'KPI-040' as KPI_Code,
			' Adj. Non Operational Revenue' as service_type_name,
			sum(amount) as netrevenue
		from (
				select dt_sk_id
				from `data-bi-prd-935c.bi_stg.tmp_20220117_finKPI`
				where dt_sk_id = vdt_id
				group by 1
			) a
			left join (
				select dt_sk_id,
					sum(0) as amount
				from `data-bi-prd-935c.bi_mart.j_20220117_finkpi_manual_rev`
				where dt_sk_id = vdt_id
					and kpi_name in ('Others & Adjutsment')
				group by 1
			) b -- exclude since doble counting
			on a.dt_sk_id = b.dt_sk_id
		group by 1,
			2,
			3
		union all
		select a.dt_sk_id,
			'KPI-040' as KPI_Code,
			' Adj. Non Operational Revenue' as service_type_name,
			sum(amount) as netrevenue
		from (
				select dt_sk_id
				from `data-bi-prd-935c.bi_stg.tmp_20220117_finKPI`
				where dt_sk_id = vdt_id
				group by 1
			) a
			left join (
				select dt_sk_id,
					sum(amount) as amount
				from `data-bi-prd-935c.bi_mart.j_20220117_finkpi_manual_rev`
				where dt_sk_id = vdt_id
					and kpi_name in ('Adj. Non-Operational Revenue')
				group by 1
			) b on a.dt_sk_id = b.dt_sk_id
		group by 1,
			2,
			3
	) a
group by 1,
	2,
	3,
	4,
	5;
insert into `data-bi-prd-935c.bi_mart.j_20220117_finkpi_branch`
select dt_sk_id,
	Cust_Type,
	upper(mp3_name) mp3_name,
	'KPI-037' as KPI_Code,
	'Revenue (Accrual Non Operational)' as service_type_name,
	sum(netrevenue) as netrevenue
from `data-bi-prd-935c.bi_mart.j_20220117_finkpi_branch`
where dt_sk_id = vdt_id
	and KPI_Code in('KPI-038', 'KPI-040')
group by 1,
	2,
	3;
insert into `data-bi-prd-935c.bi_mart.j_20220117_finkpi_branch`
select dt_sk_id,
	Cust_Type,
	upper(mp3_name) mp3_name,
	'KPI-041' as KPI_Code,
	'NON-OPERATIONAL REVENUE' as service_type_name,
	sum(netrevenue) as netrevenue
from `data-bi-prd-935c.bi_mart.j_20220117_finkpi_branch`
where dt_sk_id = vdt_id
	and KPI_Code in (
		'KPI-033',
		'KPI-034',
		'KPI-035',
		'KPI-036',
		'KPI-037'
	)
group by 1,
	2,
	3;
--=========================
-- NON RECURRING REVENUE
--=========================
insert into `data-bi-prd-935c.bi_mart.j_20220117_finkpi_branch`
select a.dt_sk_id,
	'PREPAID' Cust_Type,
	'NATIONAL' mp3_name,
	'KPI-042' as KPI_Code,
	' Lease Tower' as service_type_name,
	sum(amount) as netrevenue
from (
		select dt_sk_id
		from `data-bi-prd-935c.bi_stg.tmp_20220117_finKPI`
		where dt_sk_id = vdt_id
		group by 1
	) a
	left join (
		select dt_sk_id,
			sum(amount) as amount
		from `data-bi-prd-935c.bi_mart.j_20220117_finkpi_manual_rev`
		where dt_sk_id = vdt_id
			and kpi_name in ('Demand_Lease Tower')
		group by 1
	) b on a.dt_sk_id = b.dt_sk_id
group by 1,
	2,
	3;
insert into `data-bi-prd-935c.bi_mart.j_20220117_finkpi_branch`
select a.dt_sk_id,
	'PREPAID' Cust_Type,
	'HO NON BRANCH' mp3_name,
	'KPI-042' as KPI_Code,
	' Lease Tower' as service_type_name,
	sum(amount) as netrevenue
from (
		select dt_sk_id
		from `data-bi-prd-935c.bi_stg.tmp_20220117_finKPI`
		where dt_sk_id = vdt_id
		group by 1
	) a
	left join (
		select dt_sk_id,
			sum(amount) as amount
		from `data-bi-prd-935c.bi_mart.j_20220117_finkpi_manual_rev`
		where dt_sk_id = vdt_id
			and kpi_name in ('Demand_Lease Tower')
		group by 1
	) b on a.dt_sk_id = b.dt_sk_id
group by 1,
	2,
	3;
insert into `data-bi-prd-935c.bi_mart.j_20220117_finkpi_branch`
select a.dt_sk_id,
	'PREPAID' Cust_Type,
	'NATIONAL' mp3_name,
	'KPI-043' as KPI_Code,
	' Other Non Recurring' as service_type_name,
	sum(amount) as netrevenue
from (
		select dt_sk_id
		from `data-bi-prd-935c.bi_stg.tmp_20220117_finKPI`
		where dt_sk_id = vdt_id
		group by 1
	) a
	left join (
		select dt_sk_id,
			sum(amount) as amount
		from `data-bi-prd-935c.bi_mart.j_20220117_finkpi_manual_rev`
		where dt_sk_id = vdt_id
			and kpi_name in ('Demand_Other Non-Recurring')
		group by 1
	) b on a.dt_sk_id = b.dt_sk_id
group by 1,
	2,
	3;
insert into `data-bi-prd-935c.bi_mart.j_20220117_finkpi_branch`
select a.dt_sk_id,
	'PREPAID' Cust_Type,
	'3 BUSINESS' mp3_name,
	'KPI-043' as KPI_Code,
	' Other Non Recurring' as service_type_name,
	sum(amount) as netrevenue
from (
		select dt_sk_id
		from `data-bi-prd-935c.bi_stg.tmp_20220117_finKPI`
		where dt_sk_id = vdt_id
		group by 1
	) a
	left join (
		select dt_sk_id,
			sum(amount) as amount
		from `data-bi-prd-935c.bi_mart.j_20220117_finkpi_manual_rev`
		where dt_sk_id = vdt_id
			and kpi_name in ('Demand_Other Non-Recurring')
		group by 1
	) b on a.dt_sk_id = b.dt_sk_id
group by 1,
	2,
	3;
insert into `data-bi-prd-935c.bi_mart.j_20220117_finkpi_branch`
select dt_sk_id,
	Cust_Type,
	upper(mp3_name) mp3_name,
	'KPI-044' as KPI_Code,
	'NON RECURRING REVENUE' as service_type_name,
	sum(netrevenue) as netrevenue
from `data-bi-prd-935c.bi_mart.j_20220117_finkpi_branch`
where dt_sk_id = vdt_id
	and KPI_Code in ('KPI-042', 'KPI-043')
group by 1,
	2,
	3;
insert into `data-bi-prd-935c.bi_mart.j_20220117_finkpi_branch`
select dt_sk_id,
	Cust_Type,
	upper(mp3_name) mp3_name,
	'KPI-045' as KPI_Code,
	'TOTAL GROSS REVENUE' as service_type_name,
	sum(netrevenue) as netrevenue
from `data-bi-prd-935c.bi_mart.j_20220117_finkpi_branch`
where dt_sk_id = vdt_id
	and KPI_Code in ('KPI-032', 'KPI-041', 'KPI-044')
group by 1,
	2,
	3;
--=========================
-- COST & INCENTIVE
--=========================
insert into `data-bi-prd-935c.bi_mart.j_20220117_finkpi_branch`
select dt_sk_id,
	Cust_Type,
	upper(mp3_name) mp3_name,
	'KPI-046' as KPI_Code,
	'COST & INCENTIVE' as service_type_name,
	null as netrevenue
from `data-bi-prd-935c.bi_stg.tmp_20220117_finKPI`
where dt_sk_id = vdt_id
group by 1,
	2,
	3;
insert into `data-bi-prd-935c.bi_mart.j_20220117_finkpi_branch`
select dt_sk_id,
	Cust_Type,
	'NATIONAL' mp3_name,
	'KPI-046' as KPI_Code,
	'COST & INCENTIVE' as service_type_name,
	null as netrevenue
from `data-bi-prd-935c.bi_stg.tmp_20220117_finKPI`
where dt_sk_id = vdt_id
group by 1,
	2,
	3;
insert into `data-bi-prd-935c.bi_mart.j_20220117_finkpi_branch`
select a.dt_sk_id,
	Cust_Type,
	'NATIONAL' mp3_name,
	'KPI-047' as KPI_Code,
	'Banking Commission' as service_type_name,
	-- sum(amount)*-1 as netrevenue
	null as netrevenue
from (
		select dt_sk_id
		from `data-bi-prd-935c.bi_stg.tmp_20220117_finKPI`
		where dt_sk_id = vdt_id
		group by 1
	) a
	left join (
		select parse_date('%Y%m%d', cast(load_date as string)) as dt_sk_id,
			Cust_Type,
			mp3_name,
			sum(caccrc_amount) as amount
		from `data-bi-prd-935c.bi_stg.tmp_20220117_finKPI_caccrc`
		where parse_date('%Y%m%d', cast(load_date as string)) = vdt_id
			and report_row_nm = 'banking_commission'
		group by 1,
			2,
			3
	) b on a.dt_sk_id = b.dt_sk_id
group by 1,
	2;
insert into `data-bi-prd-935c.bi_mart.j_20220117_finkpi_branch`
select a.dt_sk_id,
	Cust_Type,
	'HO NON BRANCH' mp3_name,
	'KPI-047' as KPI_Code,
	'Banking Commission' as service_type_name,
	-- sum(amount)*-1 as netrevenue
	null as netrevenue
from (
		select dt_sk_id
		from `data-bi-prd-935c.bi_stg.tmp_20220117_finKPI`
		where dt_sk_id = vdt_id
		group by 1
	) a
	left join (
		select parse_date('%Y%m%d', cast(load_date as string)) as dt_sk_id,
			Cust_Type,
			mp3_name,
			sum(caccrc_amount) as amount
		from `data-bi-prd-935c.bi_stg.tmp_20220117_finKPI_caccrc`
		where parse_date('%Y%m%d', cast(load_date as string)) = vdt_id
			and report_row_nm = 'banking_commission'
		group by 1,
			2,
			3
	) b on a.dt_sk_id = b.dt_sk_id
group by 1,
	2;
insert into `data-bi-prd-935c.bi_mart.j_20220117_finkpi_branch`
select a.dt_sk_id,
	Cust_Type,
	'NATIONAL' mp3_name,
	'KPI-048' as KPI_Code,
	'CLM Amortization' as service_type_name,
	-- sum(amount)-1 as netrevenue
	null as netrevenue
from (
		select dt_sk_id
		from `data-bi-prd-935c.bi_stg.tmp_20220117_finKPI`
		where dt_sk_id = vdt_id
		group by 1
	) a
	left join (
		select parse_date('%Y%m%d', cast(load_date as string)) as dt_sk_id,
			Cust_Type,
			mp3_name,
			sum(caccrc_amount) as amount
		from `data-bi-prd-935c.bi_stg.tmp_20220117_finKPI_caccrc`
		where parse_date('%Y%m%d', cast(load_date as string)) = vdt_id
			and report_row_nm = 'clm_amortization'
		group by 1,
			2,
			3
	) b on a.dt_sk_id = b.dt_sk_id
group by 1,
	2;
insert into `data-bi-prd-935c.bi_mart.j_20220117_finkpi_branch`
select a.dt_sk_id,
	Cust_Type,
	'HO NON BRANCH' mp3_name,
	'KPI-048' as KPI_Code,
	'CLM Amortization' as service_type_name,
	-- sum(amount)-1 as netrevenue
	null as netrevenue
from (
		select dt_sk_id
		from `data-bi-prd-935c.bi_stg.tmp_20220117_finKPI`
		where dt_sk_id = vdt_id
		group by 1
	) a
	left join (
		select parse_date('%Y%m%d', cast(load_date as string)) as dt_sk_id,
			Cust_Type,
			mp3_name,
			sum(caccrc_amount) as amount
		from `data-bi-prd-935c.bi_stg.tmp_20220117_finKPI_caccrc`
		where parse_date('%Y%m%d', cast(load_date as string)) = vdt_id
			and report_row_nm = 'clm_amortization'
		group by 1,
			2,
			3
	) b on a.dt_sk_id = b.dt_sk_id
group by 1,
	2;
insert into `data-bi-prd-935c.bi_mart.j_20220117_finkpi_branch`
select a.dt_sk_id,
	Cust_Type,
	'NATIONAL' mp3_name,
	'KPI-049' as KPI_Code,
	'CLM Managed Services' as service_type_name,
	-- sum(amount)*-1 as netrevenue
	null as netrevenue
from (
		select dt_sk_id
		from `data-bi-prd-935c.bi_stg.tmp_20220117_finKPI`
		where dt_sk_id = vdt_id
		group by 1
	) a
	left join (
		select parse_date('%Y%m%d', cast(load_date as string)) as dt_sk_id,
			Cust_Type,
			mp3_name,
			sum(caccrc_amount) as amount
		from `data-bi-prd-935c.bi_stg.tmp_20220117_finKPI_caccrc`
		where parse_date('%Y%m%d', cast(load_date as string)) = vdt_id
			and report_row_nm = 'clm_ms'
		group by 1,
			2,
			3
	) b on a.dt_sk_id = b.dt_sk_id
group by 1,
	2;
insert into `data-bi-prd-935c.bi_mart.j_20220117_finkpi_branch`
select a.dt_sk_id,
	Cust_Type,
	'HO NON BRANCH' mp3_name,
	'KPI-049' as KPI_Code,
	'CLM Managed Services' as service_type_name,
	-- sum(amount)*-1 as netrevenue
	null as netrevenue
from (
		select dt_sk_id
		from `data-bi-prd-935c.bi_stg.tmp_20220117_finKPI`
		where dt_sk_id = vdt_id
		group by 1
	) a
	left join (
		select parse_date('%Y%m%d', cast(load_date as string)) as dt_sk_id,
			Cust_Type,
			mp3_name,
			sum(caccrc_amount) as amount
		from `data-bi-prd-935c.bi_stg.tmp_20220117_finKPI_caccrc`
		where parse_date('%Y%m%d', cast(load_date as string)) = vdt_id
			and report_row_nm = 'clm_ms'
		group by 1,
			2,
			3
	) b on a.dt_sk_id = b.dt_sk_id
group by 1,
	2;
insert into `data-bi-prd-935c.bi_mart.j_20220117_finkpi_branch`
select a.dt_sk_id,
	Cust_Type,
	'NATIONAL' mp3_name,
	'KPI-050' as KPI_Code,
	'EAD Commission' as service_type_name,
	sum(amount) * -1 as netrevenue
from (
		select dt_sk_id
		from `data-bi-prd-935c.bi_stg.tmp_20220117_finKPI`
		where dt_sk_id = vdt_id
		group by 1
	) a
	left join (
		select parse_date('%Y%m%d', cast(load_date as string)) as dt_sk_id,
			Cust_Type,
			mp3_name,
			sum(caccrc_amount) as amount
		from `data-bi-prd-935c.bi_stg.tmp_20220117_finKPI_caccrc`
		where parse_date('%Y%m%d', cast(load_date as string)) = vdt_id
			and report_row_nm = 'ead_commission'
		group by 1,
			2,
			3
	) b on a.dt_sk_id = b.dt_sk_id
group by 1,
	2;
insert into `data-bi-prd-935c.bi_mart.j_20220117_finkpi_branch`
select a.dt_sk_id,
	Cust_Type,
	'HO NON BRANCH' mp3_name,
	'KPI-050' as KPI_Code,
	'EAD Commission' as service_type_name,
	sum(amount) * -1 as netrevenue
from (
		select dt_sk_id
		from `data-bi-prd-935c.bi_stg.tmp_20220117_finKPI`
		where dt_sk_id = vdt_id
		group by 1
	) a
	left join (
		select parse_date('%Y%m%d', cast(load_date as string)) as dt_sk_id,
			Cust_Type,
			mp3_name,
			sum(caccrc_amount) as amount
		from `data-bi-prd-935c.bi_stg.tmp_20220117_finKPI_caccrc`
		where parse_date('%Y%m%d', cast(load_date as string)) = vdt_id
			and report_row_nm = 'ead_commission'
		group by 1,
			2,
			3
	) b on a.dt_sk_id = b.dt_sk_id
group by 1,
	2;
insert into `data-bi-prd-935c.bi_mart.j_20220117_finkpi_branch`
select a.dt_sk_id,
	Cust_Type,
	'NATIONAL' mp3_name,
	'KPI-051' as KPI_Code,
	'Modern Channel Vtri Commission' as service_type_name,
	sum(amount) * -1 as netrevenue
from (
		select dt_sk_id
		from `data-bi-prd-935c.bi_stg.tmp_20220117_finKPI`
		where dt_sk_id = vdt_id
		group by 1
	) a
	left join (
		select parse_date('%Y%m%d', cast(load_date as string)) as dt_sk_id,
			Cust_Type,
			mp3_name,
			sum(caccrc_amount) as amount
		from `data-bi-prd-935c.bi_stg.tmp_20220117_finKPI_caccrc`
		where parse_date('%Y%m%d', cast(load_date as string)) = vdt_id
			and report_row_nm = 'modern_channel_vtri_commission'
		group by 1,
			2,
			3
	) b on a.dt_sk_id = b.dt_sk_id
group by 1,
	2;
insert into `data-bi-prd-935c.bi_mart.j_20220117_finkpi_branch`
select a.dt_sk_id,
	Cust_Type,
	'HO NON BRANCH' mp3_name,
	'KPI-051' as KPI_Code,
	'Modern Channel Vtri Commission' as service_type_name,
	sum(amount) * -1 as netrevenue
from (
		select dt_sk_id
		from `data-bi-prd-935c.bi_stg.tmp_20220117_finKPI`
		where dt_sk_id = vdt_id
		group by 1
	) a
	left join (
		select parse_date('%Y%m%d', cast(load_date as string)) as dt_sk_id,
			Cust_Type,
			mp3_name,
			sum(caccrc_amount) as amount
		from `data-bi-prd-935c.bi_stg.tmp_20220117_finKPI_caccrc`
		where parse_date('%Y%m%d', cast(load_date as string)) = vdt_id
			and report_row_nm = 'modern_channel_vtri_commission'
		group by 1,
			2,
			3
	) b on a.dt_sk_id = b.dt_sk_id
group by 1,
	2;
insert into `data-bi-prd-935c.bi_mart.j_20220117_finkpi_branch`
select a.dt_sk_id,
	Cust_Type,
	'NATIONAL' mp3_name,
	'KPI-052' as KPI_Code,
	'NG Commission' as service_type_name,
	-- sum(amount)*-1 as netrevenue
	null as netrevenue
from (
		select dt_sk_id
		from `data-bi-prd-935c.bi_stg.tmp_20220117_finKPI`
		where dt_sk_id = vdt_id
		group by 1
	) a
	left join (
		select parse_date('%Y%m%d', cast(load_date as string)) as dt_sk_id,
			Cust_Type,
			mp3_name,
			sum(caccrc_amount) as amount
		from `data-bi-prd-935c.bi_stg.tmp_20220117_finKPI_caccrc`
		where parse_date('%Y%m%d', cast(load_date as string)) = vdt_id
			and report_row_nm = 'ng_commission'
		group by 1,
			2,
			3
	) b on a.dt_sk_id = b.dt_sk_id
group by 1,
	2;
insert into `data-bi-prd-935c.bi_mart.j_20220117_finkpi_branch`
select a.dt_sk_id,
	Cust_Type,
	'HO NON BRANCH' mp3_name,
	'KPI-052' as KPI_Code,
	'NG Commission' as service_type_name,
	-- sum(amount)*-1 as netrevenue
	null as netrevenue
from (
		select dt_sk_id
		from `data-bi-prd-935c.bi_stg.tmp_20220117_finKPI`
		where dt_sk_id = vdt_id
		group by 1
	) a
	left join (
		select parse_date('%Y%m%d', cast(load_date as string)) as dt_sk_id,
			Cust_Type,
			mp3_name,
			sum(caccrc_amount) as amount
		from `data-bi-prd-935c.bi_stg.tmp_20220117_finKPI_caccrc`
		where parse_date('%Y%m%d', cast(load_date as string)) = vdt_id
			and report_row_nm = 'ng_commission'
		group by 1,
			2,
			3
	) b on a.dt_sk_id = b.dt_sk_id
group by 1,
	2;
insert into `data-bi-prd-935c.bi_mart.j_20220117_finkpi_branch`
select dt_sk_id,
	Cust_Type,
	'NATIONAL' mp3_name,
	case
		when process_nm in (
			'FRC_BALLOON_HOKI_DEMAND',
			'FRC_BALLOON_HOKI_SUPPLY',
			'RITA_BALLOON_HOKI_DEMAND',
			'RITA_BALLOON_HOKI_SUPPLY',
			'UNLOCK_BALLOON_HOKI_DEMAND',
			'UNLOCK_BALLOON_HOKI_SUPPLY'
		) then 'KPI-053'
		else 'KPI-054'
	end as KPI_Code,
	case
		when process_nm in (
			'FRC_BALLOON_HOKI_DEMAND',
			'FRC_BALLOON_HOKI_SUPPLY',
			'RITA_BALLOON_HOKI_DEMAND',
			'RITA_BALLOON_HOKI_SUPPLY',
			'UNLOCK_BALLOON_HOKI_DEMAND',
			'UNLOCK_BALLOON_HOKI_SUPPLY'
		) then 'Balloon Hoki'
		else 'Star Commission'
	end as service_type_name,
	cast(sum(netrevenue) as bignumeric) as netrevenue
from `data-bi-prd-935c.bi_stg.tmp_20220117_finKPI`
where process_nm in (
		'FRC_BALLOON_HOKI_DEMAND',
		'FRC_BALLOON_HOKI_SUPPLY',
		'RITA_BALLOON_HOKI_DEMAND',
		'RITA_BALLOON_HOKI_SUPPLY',
		'STARS COMMISSION',
		'UNLOCK_BALLOON_HOKI_DEMAND',
		'UNLOCK_BALLOON_HOKI_SUPPLY'
	)
	and coalesce(source_channel, '') not in ('ODS_TIBCO')
	and dt_sk_id = vdt_id
group by 1,
	2,
	3,
	4,
	5
order by 1,
	2,
	3,
	4,
	5;
insert into `data-bi-prd-935c.bi_mart.j_20220117_finkpi_branch`
select dt_sk_id,
	Cust_Type,
	mp3_name,
	case
		when process_nm in (
			'FRC_BALLOON_HOKI_DEMAND',
			'FRC_BALLOON_HOKI_SUPPLY',
			'RITA_BALLOON_HOKI_DEMAND',
			'RITA_BALLOON_HOKI_SUPPLY',
			'UNLOCK_BALLOON_HOKI_DEMAND',
			'UNLOCK_BALLOON_HOKI_SUPPLY'
		) then 'KPI-053'
		else 'KPI-054'
	end as KPI_Code,
	case
		when process_nm in (
			'FRC_BALLOON_HOKI_DEMAND',
			'FRC_BALLOON_HOKI_SUPPLY',
			'RITA_BALLOON_HOKI_DEMAND',
			'RITA_BALLOON_HOKI_SUPPLY',
			'UNLOCK_BALLOON_HOKI_DEMAND',
			'UNLOCK_BALLOON_HOKI_SUPPLY'
		) then 'Balloon Hoki'
		else 'Star Commission'
	end as service_type_name,
	cast(sum(netrevenue) as bignumeric) as netrevenue
from `data-bi-prd-935c.bi_stg.tmp_20220117_finKPI`
where process_nm in (
		'FRC_BALLOON_HOKI_DEMAND',
		'FRC_BALLOON_HOKI_SUPPLY',
		'RITA_BALLOON_HOKI_DEMAND',
		'RITA_BALLOON_HOKI_SUPPLY',
		'STARS COMMISSION',
		'UNLOCK_BALLOON_HOKI_DEMAND',
		'UNLOCK_BALLOON_HOKI_SUPPLY'
	)
	and coalesce(source_channel, '') not in ('ODS_TIBCO')
	and dt_sk_id = vdt_id
group by 1,
	2,
	3,
	4,
	5
order by 1,
	2,
	3,
	4,
	5;
insert into `data-bi-prd-935c.bi_mart.j_20220117_finkpi_branch`
select dt_sk_id,
	Cust_Type,
	upper(mp3_name) mp3_name,
	case
		when process_nm in ('MARKUP_RITA', 'MARKUP_UNLOCK', 'EVC MARKUP','BIMA MARKUP') then 'KPI-055'
	end as KPI_Code,
	case
		when process_nm in ('MARKUP_RITA', 'MARKUP_UNLOCK', 'EVC MARKUP','BIMA MARKUP') then 'Markup Pulsa'
	end as service_type_name,
	cast(sum(netrevenue) as bignumeric) as netrevenue
from `data-bi-prd-935c.bi_stg.tmp_20220117_finKPI`
where process_nm in (
		'EVC MARKUP',
		'MARKUP_RITA',
		'MARKUP_UNLOCK',
		'BIMA MARKUP'
	)
	and coalesce(source_channel, '') not in ('ODS_TIBCO')
	and dt_sk_id = vdt_id
group by 1,
	2,
	3,
	4,
	5
order by 1,
	2,
	3,
	4,
	5;
insert into `data-bi-prd-935c.bi_mart.j_20220117_finkpi_branch`
select dt_sk_id,
	Cust_Type,
	'NATIONAL' mp3_name,
	case
		when process_nm in ('MARKUP_RITA', 'MARKUP_UNLOCK', 'EVC MARKUP','BIMA MARKUP') then 'KPI-055'
	end as KPI_Code,
	case
		when process_nm in ('MARKUP_RITA', 'MARKUP_UNLOCK', 'EVC MARKUP','BIMA MARKUP') then 'Markup Pulsa'
	end as service_type_name,
	cast(sum(netrevenue) as bignumeric) as netrevenue
from `data-bi-prd-935c.bi_stg.tmp_20220117_finKPI`
where process_nm in (
		'EVC MARKUP',
		'MARKUP_RITA',
		'MARKUP_UNLOCK',
		'BIMA MARKUP'
	)
	and coalesce(source_channel, '') not in ('ODS_TIBCO')
	and dt_sk_id = vdt_id
group by 1,
	2,
	3,
	4,
	5
order by 1,
	2,
	3,
	4,
	5;
insert into `data-bi-prd-935c.bi_mart.j_20220117_finkpi_branch`
select dt_sk_id,
	Cust_Type,
	upper(mp3_name) mp3_name,
	'KPI-056' as KPI_Code,
	'Manual' as service_type_name,
	cast(null as bignumeric) as netrevenue
from `data-bi-prd-935c.bi_stg.tmp_20220117_finKPI`
where dt_sk_id = vdt_id
group by 1,
	2,
	3;
insert into `data-bi-prd-935c.bi_mart.j_20220117_finkpi_branch`
select dt_sk_id,
	Cust_Type,
	'NATIONAL' mp3_name,
	'KPI-056' as KPI_Code,
	'Manual' as service_type_name,
	cast(null as bignumeric) as netrevenue
from `data-bi-prd-935c.bi_stg.tmp_20220117_finKPI`
where dt_sk_id = vdt_id
group by 1,
	2,
	3;
insert into `data-bi-prd-935c.bi_mart.j_20220117_finkpi_branch`
select a.dt_sk_id,
	'PREPAID' Cust_Type,
	'NATIONAL' mp3_name,
	'KPI-057' as KPI_Code,
	' Tax' as service_type_name,
	-- sum(amount) as netrevenue
	cast(null as bignumeric) as netrevenue
from (
		select dt_sk_id
		from `data-bi-prd-935c.bi_stg.tmp_20220117_finKPI`
		where dt_sk_id = vdt_id
		group by 1
	) a
	left join (
		select dt_sk_id,
			sum(amount) as amount
		from `data-bi-prd-935c.bi_mart.j_20220117_finkpi_manual_rev`
		where dt_sk_id = vdt_id
			and kpi_name in ('Tax')
		group by 1
	) b on a.dt_sk_id = b.dt_sk_id
group by 1,
	2;
insert into `data-bi-prd-935c.bi_mart.j_20220117_finkpi_branch`
select a.dt_sk_id,
	'PREPAID' Cust_Type,
	'HO NON BRANCH' mp3_name,
	'KPI-057' as KPI_Code,
	' Tax' as service_type_name,
	-- sum(amount) as netrevenue
	cast(null as bignumeric) as netrevenue
from (
		select dt_sk_id
		from `data-bi-prd-935c.bi_stg.tmp_20220117_finKPI`
		where dt_sk_id = vdt_id
		group by 1
	) a
	left join (
		select dt_sk_id,
			sum(amount) as amount
		from `data-bi-prd-935c.bi_mart.j_20220117_finkpi_manual_rev`
		where dt_sk_id = vdt_id
			and kpi_name in ('Tax')
		group by 1
	) b on a.dt_sk_id = b.dt_sk_id
group by 1,
	2;
insert into `data-bi-prd-935c.bi_mart.j_20220117_finkpi_branch`
select a.dt_sk_id,
	'PREPAID' Cust_Type,
	'NATIONAL' mp3_name,
	'KPI-058' as KPI_Code,
	' Mp3 Commission' as service_type_name,
	cast(null as bignumeric) as netrevenue -- sum(netrevenue)*max(rate) as netrevenue
from (
		select dt_sk_id,
			sum(netrevenue) as netrevenue
		from `data-bi-prd-935c.bi_stg.tmp_20220117_finKPI`
		where dt_sk_id = vdt_id
			and (
				service_type_name = 'BROADBAND'
				and category in ('SIM Broadband', 'Unlock', 'RITA')
			)
			or (
				service_type_name = 'BROADBAND'
				and category = 'OTHERS'
				and process_nm = 'ADDON_FORFEIT'
			)
		group by 1
	) a
	left join (
		select dt_sk_id,
			max(amount) as rate
		from `data-bi-prd-935c.bi_mart.j_20220117_finkpi_manual_rev`
		where dt_sk_id = vdt_id
			and kpi_name in ('Mp3 Commission Rate')
		group by 1
	) b on a.dt_sk_id = b.dt_sk_id
group by 1,
	2;
insert into `data-bi-prd-935c.bi_mart.j_20220117_finkpi_branch`
select a.dt_sk_id,
	'PREPAID' Cust_Type,
	'HO NON BRANCH' mp3_name,
	'KPI-058' as KPI_Code,
	' Mp3 Commission' as service_type_name,
	cast(null as bignumeric) as netrevenue -- sum(netrevenue)*max(rate) as netrevenue
from (
		select dt_sk_id,
			sum(netrevenue) as netrevenue
		from `data-bi-prd-935c.bi_stg.tmp_20220117_finKPI`
		where dt_sk_id = vdt_id
			and (
				service_type_name = 'BROADBAND'
				and category in ('SIM Broadband', 'Unlock', 'RITA')
			)
			or (
				service_type_name = 'BROADBAND'
				and category = 'OTHERS'
				and process_nm = 'ADDON_FORFEIT'
			)
		group by 1
	) a
	left join (
		select dt_sk_id,
			max(amount) as rate
		from `data-bi-prd-935c.bi_mart.j_20220117_finkpi_manual_rev`
		where dt_sk_id = vdt_id
			and kpi_name in ('Mp3 Commission Rate')
		group by 1
	) b on a.dt_sk_id = b.dt_sk_id
group by 1,
	2;
insert into `data-bi-prd-935c.bi_mart.j_20220117_finkpi_branch`
select a.dt_sk_id,
	'PREPAID' Cust_Type,
	'NATIONAL' mp3_name,
	'KPI-059' as KPI_Code,
	' MCO Cost' as service_type_name,
	-- sum(amount) as netrevenue
	cast(null as bignumeric) as netrevenue
from (
		select dt_sk_id
		from `data-bi-prd-935c.bi_stg.tmp_20220117_finKPI`
		where dt_sk_id = vdt_id
		group by 1
	) a
	left join (
		select dt_sk_id,
			sum(amount) as amount
		from `data-bi-prd-935c.bi_mart.j_20220117_finkpi_manual_rev`
		where dt_sk_id = vdt_id
			and kpi_name in ('MCO Cost')
		group by 1
	) b on a.dt_sk_id = b.dt_sk_id
group by 1,
	2;
insert into `data-bi-prd-935c.bi_mart.j_20220117_finkpi_branch`
select a.dt_sk_id,
	'PREPAID' Cust_Type,
	'HO NON BRANCH' mp3_name,
	'KPI-059' as KPI_Code,
	' MCO Cost' as service_type_name,
	-- sum(amount) as netrevenue
	cast(null as bignumeric) as netrevenue
from (
		select dt_sk_id
		from `data-bi-prd-935c.bi_stg.tmp_20220117_finKPI`
		where dt_sk_id = vdt_id
		group by 1
	) a
	left join (
		select dt_sk_id,
			sum(amount) as amount
		from `data-bi-prd-935c.bi_mart.j_20220117_finkpi_manual_rev`
		where dt_sk_id = vdt_id
			and kpi_name in ('MCO Cost')
		group by 1
	) b on a.dt_sk_id = b.dt_sk_id
group by 1,
	2;
insert into `data-bi-prd-935c.bi_mart.j_20220117_finkpi_branch`
select a.dt_sk_id,
	'PREPAID' Cust_Type,
	'NATIONAL' mp3_name,
	'KPI-060' as KPI_Code,
	' Adj. Cost & Incentive' as service_type_name,
	cast(sum(amount) as bignumeric) as netrevenue
from (
		select dt_sk_id
		from `data-bi-prd-935c.bi_stg.tmp_20220117_finKPI`
		where dt_sk_id = vdt_id
		group by 1
	) a
	left join (
		select dt_sk_id,
			sum(amount) as amount
		from `data-bi-prd-935c.bi_mart.j_20220117_finkpi_manual_rev`
		where dt_sk_id = vdt_id
			and kpi_name in (
				'Adj. Cost & Incentive',
				'Demand_Adj. Cost & Incentive'
			)
		group by 1
	) b on a.dt_sk_id = b.dt_sk_id
group by 1,
	2;
insert into `data-bi-prd-935c.bi_mart.j_20220117_finkpi_branch`
select a.dt_sk_id,
	'PREPAID' Cust_Type,
	'HO NON BRANCH' mp3_name,
	'KPI-060' as KPI_Code,
	' Adj. Cost & Incentive' as service_type_name,
	cast(sum(amount) as bignumeric) as netrevenue
from (
		select dt_sk_id
		from `data-bi-prd-935c.bi_stg.tmp_20220117_finKPI`
		where dt_sk_id = vdt_id
		group by 1
	) a
	left join (
		select dt_sk_id,
			sum(amount) as amount
		from `data-bi-prd-935c.bi_mart.j_20220117_finkpi_manual_rev`
		where dt_sk_id = vdt_id
			and kpi_name in (
				'Adj. Cost & Incentive',
				'Demand_Adj. Cost & Incentive'
			)
		group by 1
	) b on a.dt_sk_id = b.dt_sk_id
group by 1,
	2;
insert into `data-bi-prd-935c.bi_mart.j_20220117_finkpi_branch`
select dt_sk_id,
	Cust_Type,
	upper(mp3_name) mp3_name,
	'KPI-061' as KPI_Code,
	'TOTAL COST & INCENTIVE' as service_type_name,
	cast(sum(netrevenue) as bignumeric) as netrevenue
from `data-bi-prd-935c.bi_mart.j_20220117_finkpi_branch`
where dt_sk_id = vdt_id
	and KPI_Code in (
		'KPI-047',
		'KPI-048',
		'KPI-049',
		'KPI-050',
		'KPI-051',
		'KPI-052',
		'KPI-053',
		'KPI-054',
		'KPI-055',
		'KPI-057',
		'KPI-058',
		'KPI-059',
		'KPI-060'
	)
group by 1,
	2,
	3;
--=========================
-- TOTAL REVENUE
--=========================
insert into `data-bi-prd-935c.bi_mart.j_20220117_finkpi_branch`
select dt_sk_id,
	Cust_Type,
	upper(mp3_name) mp3_name,
	'KPI-062' as KPI_Code,
	'' as service_type_name,
	cast(null as bignumeric) as netrevenue
from `data-bi-prd-935c.bi_stg.tmp_20220117_finKPI`
where dt_sk_id = vdt_id
group by 1,
	2,
	3;
insert into `data-bi-prd-935c.bi_mart.j_20220117_finkpi_branch`
select dt_sk_id,
	Cust_Type,
	'NATIONAL' mp3_name,
	'KPI-062' as KPI_Code,
	'' as service_type_name,
	cast(null as bignumeric) as netrevenue
from `data-bi-prd-935c.bi_stg.tmp_20220117_finKPI`
where dt_sk_id = vdt_id
group by 1,
	2;
insert into `data-bi-prd-935c.bi_mart.j_20220117_finkpi_branch`
select dt_sk_id,
	Cust_Type,
	upper(mp3_name) mp3_name,
	'KPI-063' as KPI_Code,
	'TOTAL REVENUE' as service_type_name,
	cast(sum(netrevenue) as bignumeric) as netrevenue
from `data-bi-prd-935c.bi_mart.j_20220117_finkpi_branch`
where dt_sk_id = vdt_id
	and KPI_Code in ('KPI-045', 'KPI-061')
group by 1,
	2,
	3;
delete from `data-bi-prd-935c.bi_mart.J_20220117_FINKPI`
where dt_sk_id = vdt_id;
insert into `data-bi-prd-935c.bi_mart.J_20220117_FINKPI`
select dt_sk_id,
	kpi_code,
	service_type_name,
	cast(sum(netrevenue) as bignumeric) as netrevenue
from `data-bi-prd-935c.bi_mart.j_20220117_finkpi_branch`
where dt_sk_id = vdt_id
	and mp3_name = 'NATIONAL'
group by 1,
	2,
	3;

insert into `data-bi-prd-935c.bi_mart.J_20220117_FINKPI`
select cast(trx_dt_sk_id as date),
	'KPI-064' as kpi_code,
	'  PGI' as service_type_name,
	net_revenue
from (
		select cast(fct.trx_dt_sk_id as date) as trx_dt_sk_id,
			case
				when (
					source_channel in ('ODP_GNV', 'ODP_GNV_SUPERAPP')
					and revenue_source_indicator = 'CDR'
				)
				or source_channel in (
					'TRANSFER-ODP_GNV',
					'CVM_BIMA_NONPGI',
					'CVM_BIMA_LEGO_NON_PGI',
					'CVM_BIMA_LEGO_NONPGI_SUPERAPP',
					'TRANSFER-ODP_GNV_SUPERAPP',
					'CVM_BIMA_NONPGI_SUPERAPP',
					'CVM_BIMA_LEGO_TP_NONPGI',
					'CVM_BIMA_LEGO_TP_NONPGI_SUPERAPP'
				) then 'In App' --- PULSA Payment
				when (
					source_channel in ('ODP_GNV', 'ODP_GNV_SUPERAPP')
					and revenue_source_indicator = 'MANUAL'
				)
				or source_channel in (
					'CVM_BIMA_PGI',
					'CVM_BIMA_LEGO_PGI',
					'CVM_BIMA_PGI_SUPERAPP',
					'CVM_BIMA_LEGO_PGI_SUPERAPP',
					'CVM_BIMA_LEGO_PGI_SUPERAPP'
				) then 'Online' --- NON PULSA/ PGI {e-walllet, bank, PPOB, etc)
				else 'N/A'
			end as grp_digital,
			count(distinct sbscrptn_ek_id) as pau,
			count(
				distinct coalesce(source_system_id, transaction_id)
			) as hit,
			sum(gross_revenue) as gross_revenue,
			sum(case
				when cast(fct.trx_dt_sk_id as date) < '2025-01-01' then net_revenue / 1.11
				else net_revenue / 1.11
			end) as net_revenue
		from `data-dtptechm-prd-c7ca.dwh.revenue_base` fct
			left join `data-dtptechm-prd-c7ca.dwh.product_dim` pd on pd.product_sk_id = fct.product_sk_id --where ((fct.trx_dt_sk_id >= 20230601 and fct.trx_dt_sk_id <= 20230610) or (fct.trx_dt_sk_id >= 20230701 and fct.trx_dt_sk_id <= 20230710))
		JOIN `data-dtptechm-prd-c7ca.dwh.demand_revenue_base_filter` AS drbf
							ON fct.process_nm = drbf.process_nm
							AND fct.revenue_src_ctgry = drbf.revenue_src_ctgry
						WHERE drbf.net_revenue_incl = 'Y'and  -- ((fct.trx_dt_sk_id >= 20240209 and fct.trx_dt_sk_id <= 20240318) or (fct.trx_dt_sk_id >= 20240301 and fct.trx_dt_sk_id <= 20240314)) and  
			cast(fct.trx_dt_sk_id as date)= vdt_id
			and fct.gl_cd not in (
				select ref_cd
				from `data-dtptechm-prd-c7ca.dwh.rprt_fltr_ref_ctgry`
				where ref_type_cd = 'ACCRUAL_GL_CODE'
			)
			and tool_of_trade_ind = 'N'
			and source_channel in (
				'ODP_GNV',
				'TRANSFER-ODP_GNV',
				'CVM_BIMA_NONPGI',
				'CVM_BIMA_PGI',
				'CVM_BIMA_LEGO_NON_PGI',
				'CVM_BIMA_LEGO_PGI',
				'ODP_GNV_SUPERAPP',
				'TRANSFER-ODP_GNV_SUPERAPP',
				'CVM_BIMA_NONPGI_SUPERAPP',
				'CVM_BIMA_PGI_SUPERAPP',
				'CVM_BIMA_LEGO_NONPGI_SUPERAPP',
				'CVM_BIMA_LEGO_PGI_SUPERAPP',
				'CVM_BIMA_LEGO_TP_NONPGI',
				-- KIKIDA via Pulsa
				'CVM_BIMA_LEGO_TP_NONPGI_SUPERAPP' -- KIKIDA via Pulsa
			)
		group by 1,
			2
		order by 1,
			2
	) a
where a.grp_digital = 'Online';