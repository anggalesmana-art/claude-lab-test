--Updated by query Mas Herwin 20231116 by Indra Maulana Ikhsan
DECLARE vdt_id DATE DEFAULT @vdt_id;
delete from `data-bi-prd-935c.bi_mart.kpi_national_tracker_dly`
where brand = 'TRI'
	and dt_id between vdt_id and vdt_id
	and kpi_id in (
		'REV0001',
		'REV0002',
		'REV0003',
		'REV0004',
		'REV0005',
		'REV0006',
		'REV0007',
		'REV0008',
		'REV0009',
		'REV0010',
		'REV0012',
		'REV0013',
		'REV0014',
		'REV0015',
		'REV0016',
		'REV0017',
		'REV0018',
		'REV0019',
		'REV0020',
		'REV0021'
	);
insert into `data-bi-prd-935c.bi_mart.kpi_national_tracker_dly` with rev as (
		select cast(dt_sk_id as date) dt_id,
			case
				when service_type_name in ('ORGANIC', 'PGImin') then 'ORGANIC'
				else service_type_name
			end as service_type_name,
			sum(netrevenue) metric
		from `data-bi-prd-935c.bi_mart.v_cwn_revenue_tracker_v2`
		where cast(dt_sk_id as date) between vdt_id and vdt_id
			and service_type_name not in (
				'Postpaid - B2B (PABX & Postpaid Revenue)',
				'Take out Postpaid B2C'
			)
		group by 1,
			2
	),
	calendarize as (
		select report_date_sk_id dt_id,
			case
				when fct.PROCESS_NM in (
					'RITA',
					'SIM_DEMAND',
					'VOUCHER_DEMAND',
					'VOUCHER_FORFEIT',
					'TOPUP'
				) then 'MOBO'
				else 'ORGANIC + PGI'
			end as service_type_name,
			sum(
				case
					when fct.product_id = 8 THEN net_revenue / 1.11
					when fct.product_id <> 8 THEN net_revenue
				end
			) metric
		from `data-dtptechm-prd-c7ca.dwh.revenue_base_calendarized` fct
			JOIN `data-dtptechm-prd-c7ca.dwh.demand_revenue_base_filter` AS drbf ON fct.process_nm = drbf.process_nm
			AND fct.revenue_src_ctgry = drbf.revenue_src_ctgry
		WHERE drbf.net_revenue_incl = 'Y'
			and report_date_sk_id between vdt_id and vdt_id
			and tool_of_trade_ind = 'N'
			and COALESCE(fct.service_type, 'BROADBAND') = 'BROADBAND'
			and fct.gl_cd not in (
				select ref_cd
				from `data-dtptechm-prd-c7ca.dwh.rprt_fltr_ref_ctgry`
				where ref_type_cd = 'ACCRUAL_GL_CODE'
			) --and fct.product_id = 8
			and fct.process_nm in (
				'DATA_BB_BASE',
				'RITA',
				'SIM_DEMAND',
				'TOPUP',
				'VOUCHER_DEMAND',
				'VOUCHER_FORFEIT'
			)
		group by 1,
			2
	),
	fnl as (
		-- non calenderize by services
		select cast(dt_id as date) as dt_id,
			case
				when service_type_name = 'MOBO' then 'REV0003'
				when service_type_name = 'ORGANIC' then 'REV0004'
				when service_type_name = 'TOTAL VOICE' then 'REV0005'
				when service_type_name = 'SMS' then 'REV0006'
				when service_type_name = 'VAS' then 'REV0007'
				when service_type_name = 'LOAN BALANCE' then 'REV0008'
				when service_type_name = 'PGI' then 'REV0009'
				when service_type_name = 'Others' then 'REV0010'
			end kpi_id,
			'' kpi_code,
			'DLY' flag,
			metric
		from rev
		union all
		-- non calenderize total all
		select cast(dt_id as date) as dt_id,
			'REV0001' kpi_id,
			'' kpi_code,
			'DLY' flag,
			sum(metric) metric
		from rev
		group by 1
		union all
		-- non calendrize total data
		select cast(dt_id as date) as dt_id,
			'REV0002' kpi_id,
			'' kpi_code,
			'DLY' flag,
			sum(metric) metric
		from rev
		where service_type_name in ('MOBO', 'ORGANIC', 'PGI')
		group by 1
		union all
		-- calenderize by services
		select cast(dt_id as date) as dt_id,
			case
				when service_type_name = 'TOTAL VOICE' then 'REV0016'
				when service_type_name = 'SMS' then 'REV0017'
				when service_type_name = 'VAS' then 'REV0018'
				when service_type_name = 'LOAN BALANCE' then 'REV0019'
				when service_type_name = 'Others' then 'REV0021'
			end kpi_id,
			'' kpi_code,
			'DLY' flag,
			metric
		from rev
		where service_type_name in (
				'TOTAL VOICE',
				'SMS',
				'VAS',
				'LOAN BALANCE',
				'Others'
			)
		union all
		-- calenderize mobo and organic
		select cast(dt_id as date) as dt_id,
			case
				when service_type_name = 'MOBO' then 'REV0014'
				when service_type_name = 'ORGANIC + PGI' then 'REV0015'
			end kpi_id,
			'' kpi_code,
			'DLY' flag,
			metric
		from calendarize
		union all
		-- calenderize total data
		select cast(dt_id as date) as dt_id,
			'REV0013' kpi_id,
			'' kpi_code,
			'DLY' flag,
			sum(metric) metric
		from calendarize
		group by 1
	)
select 'TRI' brand,
	kpi_code,
	flag,
	metric,
	current_timestamp() process_dt,
	kpi_id,
	dt_id
from fnl
union all
--- calenderize total all
select 'TRI' brand,
	'' kpi_code,
	'DLY' flag,
	sum(metric) metric,
	current_timestamp() process_dt,
	'REV0012' kpi_id,
	dt_id
from fnl
where kpi_id in (
		'REV0014',
		'REV0015',
		'REV0016',
		'REV0017',
		'REV0018',
		'REV0019',
		'REV0020',
		'REV0021',
		'REV0022'
	)
group by dt_id;