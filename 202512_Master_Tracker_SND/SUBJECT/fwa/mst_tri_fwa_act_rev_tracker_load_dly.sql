BEGIN
DECLARE vdt_id date default @vdt_id;

	delete from `data-bi-prd-935c.bi_mart.fwa_usage_rev` where date(trx_dt_sk_id) = date(vdt_id);
	insert into `data-bi-prd-935c.bi_mart.fwa_usage_rev` 
	select 
	fct.trx_dt_sk_id, 
	b.site_id_90  as site_id,
	process_nm, 
	case 
		when service_type_name in ('BROADBAND') then 
		case 
			when process_nm = 'SIM_DEMAND' and UPPER(product_name) in ( 'SP FWA S1','SP FWA S1 ORI','SP FWA S2 ORI') then 'FWA SIM'
			when UPPER(product_name) in (
			'BOOSTER 20GB OL', 'BOOSTER HIFI AIR 10GB', 'BOOSTER HIFI AIR 20GB', 'BOOSTER HIFI AIR 50GB', 'BOOSTER HIFI AIR 5GB', 'EVC HIFIAIR 125GB 30D',
			'EVC HIFIAIR 200GB 30D', 'EVC HIFIAIR 500GB 30D', 'FWA 15GB/BULAN', 'HAPPY 90GB (30GB PER BULAN)', 'HAPPY PRO 150GB OL', 'HAPPY PRO 25GB 30 HARI',
			'HAPPY PRO 25GB OL', 'HAPPY PRO 50GB 30 HARI', 'HAPPY PRO 75GB 30 HARI', 'HIFI AIR 125GB 30 HARI', 'HIFI AIR 150GB 30 HARI', 'HIFI AIR 200GB 30 HARI',
			'HIFI AIR 250GB 30 HARI', 'HIFI AIR 25GB 30 HARI', 'HIFI AIR 500GB 30 HARI', 'HIFI AIR 50GB 30 HARI', 'HIFI AIR 75GB 30 HARI', 'HIFI AIR 80GB 30 HARI',
			'MAU BOS15GB', 'MAU BOS20GB', 'MAU BOS5GB', 'MAU HIFIAIR 125GB 30D', 'MAU HIFIAIR 200GB 30D', 'MAU HIFIAIR 20GB EXTRA', 'MAU HIFIAIR 500GB 30D',
			'MAU HIFIAIR 50GB EXTRA', 'MAU HIFIAIR 75GB 30D', 'RITA HIFIAIR 125GB 30D', 'RITA HIFIAIR 200GB 30D', 'RITA HIFIAIR 20GB EXTRA', 'RITA HIFIAIR 500GB 30D',
			'RITA HIFIAIR 50GB EXTRA', 'RITA HIFIAIR 75GB 30D'
			) then 'FWA PACK'
			when UPPER(product_name) like '%HIFI%AIR%' then 'FWA PACK'
		else 'REGULAR PACK' end
	else 'NON BROADBAND' end as product_grp,
	UPPER(product_name) as product_name, 
	cast(sum(fct.netrevenue) as numeric) as netrevenue 
	from `data-bi-prd-935c.bi_mart.fct_cwn_rev_detail` fct 
	left outer join `data-bi-prd-935c.bi_mart.ioh_subscriber_site_attribs_rolling` b on fct.trx_dt_sk_id =b.dt and cast(fct.sbscrptn_ek_id as int64) = cast(b.sbscrptn_ek_id as int64)
	join `data-dtptechm-prd-c7ca.dwh.sbscrptn_attribs` sa on cast(fct.sbscrptn_ek_id as int64) = cast(sa.sbscrptn_ek_id as int64) AND (UPPER(sa.promo_desc) like '%FWA%' or UPPER(sa.call_plan_desc) like '%FWA%')
	where trx_dt_sk_id = date(vdt_id)
	group by 1,2,3,4,5;

	delete from `data-bi-prd-935c.bi_mart.fwa_mart` a where a.kpi_nm like 'REV-%' and time_flag = 'dly' and dt_id = date(vdt_id);
	insert into `data-bi-prd-935c.bi_mart.fwa_mart`
	select 
	trx_dt_sk_id dt_id,
	site_id attr_value,
	'dly' time_flag,
	'siteid' as attr_nm,
	'REV-'||product_grp as kpi_nm,
	'3ID' brand,
	CURRENT_TIMESTAMP() created_dtm,
	cast(sum(netrevenue) as numeric) as metric_value
	from `data-bi-prd-935c.bi_mart.fwa_usage_rev`  a
	where a.trx_dt_sk_id = date(vdt_id)
	group by 1,2,3,4,5;


END