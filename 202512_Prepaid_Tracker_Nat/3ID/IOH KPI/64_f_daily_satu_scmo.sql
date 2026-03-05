DECLARE vdt_id DATE DEFAULT @vdt_id;

---ret_qsso

delete from `data-bi-prd-935c.bi_mart.dm_mart_satu`
where squad='BTS Factory' 
and kpi_code='SCM0 >= 35'
and dt=vdt_id;

insert into `data-bi-prd-935c.bi_mart.dm_mart_satu` 
select dt_sk_id,squad,kpi_code,branch,district,count(distinct sites)cnt
from 
(
	select x.* ,case when y.newsiteid is null then site_id 
						when y.newsiteid = '00000-' then site_id 
						else y.newsiteid end  as sites 
	from 
		(
		select cast(dt_sk_id as date) as dt_sk_id,
				'BTS Factory' as squad,
				'SCM0 >= 35' as kpi_code
				, upper(coalesce(branch, 'N/A')) branch,
				case when upper(coalesce(branch, 'N/A')) in ('ACEH', 'LHOKSEUMAWE', 'MEDAN', 'DELI SERDANG', 'KISARAN', 'SIANTAR', 'BATAM', 'PADANG', 'PEKANBARU', 'BENGKULU LAMPUNG', 'JAMBI', 'PALEMBANG') then 'NCSS'
				when upper(coalesce(branch, 'N/A')) in ('CENTRAL WEST NORTH JKT', 'EAST SOUTH JKT DEPOK', 'TANGERANG', 'BEKASI', 'BOGOR', 'SERANG') then 'JABO'
				when upper(coalesce(branch, 'N/A')) in ('BANDUNG', 'TASIKMALAYA', 'CIANJUR SUKABUMI', 'CIREBON', 'KARAWANG') then 'WJ'
				when upper(coalesce(branch, 'N/A')) in ('BALIKPAPAN', 'BANJARMASIN', 'PONTIANAK', 'MAKASSAR', 'MANADO') then 'KALSUL'
				when upper(coalesce(branch, 'N/A')) in ('PURWOKERTO', 'SEMARANG', 'YOGYAKARTA', 'SOLO', 'MADIUN', 'PONOROGO') then 'CJ'
				when upper(coalesce(branch, 'N/A')) in ('MALANG', 'BLITAR', 'KEDIRI', 'SURABAYA', 'SIDOARJO', 'GRESIK', 'MOJOKERTO', 'JEMBER', 'BALI', 'LOMBOK') then 'EJBL'
				when upper(coalesce(branch, 'N/A')) in ('NATIONAL') then 'NATIONAL'
				else upper(coalesce(branch, 'N/A')) end as district
				,case when length(x.site_id)<6 then lpad(x.site_id,6,'0') else x.site_id end site_id from 
				(
				select * from 
							(
							select cast(vdt_id as date) dt_sk_id,
							b.site_id, count(distinct a.sbscrptn_ek_id) as cnt, 'SCM0 >35= Subs', current_date()
							from 
							(
							 select distinct a.sbscrptn_ek_id
							 from `data-dtptechm-prd-c7ca.dwh.ioh_sales_distribution_kpi_subs_detail` a
							 where cast(load_dt_sk_id as date) = vdt_id
							 and heading_tag = 'ACQUISITION'
							 and month_kpi_tag = 'M-0'
							) a
							left outer join `data-bi-prd-935c.bi_mart.fct_ga_site_id` b on cast(a.sbscrptn_ek_id as string) = cast(b.sbscrptn_ek_id as string) and date_trunc(b.dt,MONTH) = date_trunc(vdt_id,month)
							group by 1,2) x where cnt >=35
				) x 
				left join 
				(
				select site_id,branch from 
				(
				select mth_sk_id, site_id, upper(gladiator_branch) branch, row_number() over(partition by site_id order by mth_sk_id desc ) rank
					from `data-bi-prd-935c.bi_mart.site_ref_dim`
				where mth_sk_id>='2022-01-01' 
				) x where rank=1 
				)y on case when length(x.site_id)<6 then lpad(x.site_id,6,'0') else x.site_id end =case when length(y.site_id)<6 then lpad(y.site_id,6,'0') else y.site_id end 
				where cnt>=35
				and dt_sk_id =vdt_id --in (20220516,20220416) --20220326)
				and case when length(x.site_id)<6 then lpad(x.site_id,6,'0') else x.site_id end
				in (
											select case when length(site)<6 then lpad(site,6,'0') else site end as site_id from 
											(
												select oldsiteid site from 
												`data-bi-prd-935c.bi_mart.dm_phy_addressable_sites`
												where mth= (select max(mth) from `data-bi-prd-935c.bi_mart.dm_phy_addressable_sites`  
                    where mth <= DATE_TRUNC(DATE_SUB(vdt_id, INTERVAL 0 MONTH), MONTH))
												and addressablesites='ADDRESSABLE SITE'
												union all 
												select newsiteid site from 
												`data-bi-prd-935c.bi_mart.dm_phy_addressable_sites`
												where mth= (select max(mth) from `data-bi-prd-935c.bi_mart.dm_phy_addressable_sites`  
                    where mth <= DATE_TRUNC(DATE_SUB(vdt_id, INTERVAL 0 MONTH), MONTH))
												and addressablesites='ADDRESSABLE SITE'
											) x group by 1 
								)
						
				group by 1,2,3,4,5,6
	) x 
	left join 
	(
									select case when length(oldsiteid)<6 then lpad(oldsiteid,6,'0') else oldsiteid end as oldsiteid 
									,case when length(newsiteid)<6 then lpad(newsiteid,6,'0') else newsiteid end as newsiteid
									from 
									`data-bi-prd-935c.bi_mart.dm_phy_addressable_sites`
									where mth= (select max(mth) from `data-bi-prd-935c.bi_mart.dm_phy_addressable_sites`  
                    				where mth <= DATE_TRUNC(DATE_SUB(vdt_id, INTERVAL 0 MONTH), MONTH))
									and addressablesites='ADDRESSABLE SITE'
									group by 1,2 
	) y on x.site_id=y.oldsiteid
) smy group by 1,2,3,4,5;
 

 delete from `data-bi-prd-935c.bi_mart.stg_v_map_tgt_ret_details_hist`
 where dt =vdt_id ;

 insert into `data-bi-prd-935c.bi_mart.stg_v_map_tgt_ret_details_hist` 
 select cast(vdt_id as date),ret_msisdn, ret_qr_cd, site_id, distance, load_id from 
 `data-dtptechm-prd-c7ca.stg.stg_v_map_tgt_ret_details` a;
