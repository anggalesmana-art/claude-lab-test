DECLARE vdt_id DATE DEFAULT @vdt_id;

	drop table if exists `data-bi-prd-935c.bi_mart.dm_vlr_band_90`;


	  create table `data-bi-prd-935c.bi_mart.dm_vlr_band_90`
			as
			select *
			from (select msisdn, band, row_number() over(partition by msisdn order by load_dt desc, imei) rank
			from `data-bi-prd-935c.bi_mart.fct_vlr_daily` a
			join (select tac, case when final_device_band_type like 'LTE%' then '4G'
						    else substring(final_device_band_type,1,2)
					       end band
					from `data-bi-prd-935c.bi_mart.ioh_tac_dim_extd`
					where final_device_band_type <> 'N'
					group by 1,2) b on substring(a.imei,1,8) = b.tac
			where load_dt <= vdt_id
			and load_dt >= DATE_SUB(vdt_id, INTERVAL 89 DAY)
			and band is not null
			) b
			where rank = 1;