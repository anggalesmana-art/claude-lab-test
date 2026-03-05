DECLARE vdt_id DATE DEFAULT @vdt_id;


	drop table if exists `data-bi-prd-935c.bi_mart.dm_ggsn_band_30`;

	create table `data-bi-prd-935c.bi_mart`.dm_ggsn_band_30
	as
	select *
	from (select sbscrptn_ek_id, band, row_number() over(partition by sbscrptn_ek_id order by dt_sk_id desc, served_imeisv) rank
	from `data-bi-prd-935c.bi_mart.project_ioh_data_imei_usage` a
	 join (select tac, case when final_device_band_type like 'LTE%' then '4G'
	else substring(final_device_band_type,1,2)
	 end band
	from `data-bi-prd-935c.bi_mart.ioh_tac_dim_extd`
	where final_device_band_type <> 'N'
	group by 1,2) b on substring(a.served_imeisv,1,8) = b.tac
	where a.dt_sk_id <= vdt_id
	and a.dt_sk_id >= DATE_SUB(vdt_id, INTERVAL 29 DAY)
	and band is not null
	) a
	where rank = 1;