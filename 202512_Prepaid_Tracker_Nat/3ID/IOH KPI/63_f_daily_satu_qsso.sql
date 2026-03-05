DECLARE vdt_id DATE DEFAULT @vdt_id;
-- DECLARE vdt_id DATE DEFAULT @vdt_id; 63

 drop table if exists `data-bi-prd-935c.bi_stg.gross_add_subs_temp`;
 

---ret_qsso
		create table `data-bi-prd-935c.bi_stg.gross_add_subs_temp` as
		with subs as (select * from `data-dtptechm-prd-c7ca.dwh.sbscrptn_attribs`)
		select  (
    SELECT MIN(d)
    FROM UNNEST([
      cast(first_usage_dt as date),
      safe.parse_date('%Y%m%d',cast(first_billing_usage_dt_sk_id as string)),
      cast(any_event_first_usage_date as date)
    ]) AS d
    WHERE d IS NOT NULL
  )  AS ga_date, fct.sbscrptn_ek_id
		from subs fct
		left outer join `data-dtptechm-prd-c7ca.dwh.channel_dim` CD2 ON (CD2.channel_sk_id=fct.mp3_channel_sk_id) 
		left outer join `data-dtptechm-prd-c7ca.dwh.rprt_fltr_ref_ctgry` REF2 ON (ref2.ref_cd=CD2.channel_id and REF2.ref_type_cd = 'MP3')
		where  (
    SELECT MIN(d)
    FROM UNNEST([
      cast(first_usage_dt as date),
      safe.parse_date('%Y%m%d',cast(first_billing_usage_dt_sk_id as string)),
      cast(any_event_first_usage_date as date)
    ]) AS d
    WHERE d IS NOT NULL
  )
		between DATE_TRUNC(vdt_id, MONTH) and CAST(vdt_id AS date)
		and partition_flag <> 'A'
		and coalesce(product_id,8) = 8 and coalesce(tool_of_trade_ind,'N') = 'N' group by 1 ,2
		;

drop table if exists `data-bi-prd-935c.bi_stg.subs_with_nik_first_usage_temp`;
 

		create table `data-bi-prd-935c.bi_stg.subs_with_nik_first_usage_temp` as
		with subs as (select * from `data-dtptechm-prd-c7ca.dwh.sbscrptn_attribs`)
		select 
		attr.sbscrptn_msisdn,
		ga.sbscrptn_ek_id
		from `data-bi-prd-935c.bi_stg.gross_add_subs_temp` ga
		join subs attr on ga.sbscrptn_ek_id = attr.sbscrptn_ek_id 
		where 
		 attr.angie_retailer_name is not null
		;
	 

drop table if exists `data-bi-prd-935c.bi_stg.subs_ref_site_temp`;

		create table `data-bi-prd-935c.bi_stg.subs_ref_site_temp` as
		select distinct
		sbscrptn_ek_id,
		site_id
		from `data-dtptechm-prd-c7ca.dwh.ioh_subscriber_site_attribs`
		where cast(load_dt_sk_Id as date) >= DATE_TRUNC(vdt_id, MONTH)
		and cast(load_dt_sk_Id as date) <= vdt_id
		;
	 

drop table if exists `data-bi-prd-935c.bi_stg.list_site_ref_temp`;
		create table `data-bi-prd-935c.bi_stg.list_site_ref_temp` as
				select distinct
				sam_id,
				coalesce(branch_name,gladiator_branch) gladiator_branch
				from
					(
					select sam_id,gladiator_branch from 
					(
						select *,row_number() over (partition by sam_id order by dt desc) rnk
						 From (
											select 
											sam_id,
											upper(gladiator_branch) gladiator_branch,cast(updated_dtm as date) dt
											from `data-dtptechm-prd-c7ca.dwh.master_3g_cell_id`
											where curr_ind = 'Y' group by 1,2,3
											union all
											select 
											sam_id,
											upper(gladiator_branch) gladiator_branch,cast(updated_dtm as date) dt
											from `data-dtptechm-prd-c7ca.dwh.master_2g_cell_id`
											where curr_ind = 'Y' group by 1,2,3

					) x 
					) y where rnk=1
					) a left join 
				(select case when length(siteid)<6 then lpad(siteid,6,'0') else siteid end site,branch branch_name from 
				`data-bi-prd-935c.bi_mart.stg_src_wad_nbd_site_master`
				group by 1 ,2
				)b on case when length(a.sam_id)<6 then lpad(a.sam_id,6,'0') else a.sam_id end =b.site	 
				where gladiator_branch is not null
				;
	 

drop table if exists `data-bi-prd-935c.bi_stg.subs_site_branch_temp`;

		create table `data-bi-prd-935c.bi_stg.subs_site_branch_temp` as
		select
		a.sbscrptn_ek_id,
		a.site_id,
		b.gladiator_branch as subs_branch
		from `data-bi-prd-935c.bi_stg.subs_ref_site_temp` a
		left join `data-bi-prd-935c.bi_stg.list_site_ref_temp` b on a.site_id = b.sam_id
		;
	 

drop table if exists `data-bi-prd-935c.bi_stg.ale_subs_ret_qsso_detail_temp`;

		create table `data-bi-prd-935c.bi_stg.ale_subs_ret_qsso_detail_temp` as
		select a.*,
		sub_ref.subs_branch,
		b.retailer_qrcode,
		upper(hd.mp3_location) as ret_branch,
		ret_map.site_id as ret_site_id
		from `data-bi-prd-935c.bi_stg.subs_with_nik_first_usage_temp` a
		join `data-dtptechm-prd-c7ca.dwh.angie_activations` b on a.sbscrptn_ek_id = b.sbscrptn_ek_id
		--join (select call_plan_desc from dwh.angie_call_plan_dim 
		--where mobile_code IN ('HP2','HP7','BM3X','BM9X','PM4','HP52L','HP9L','3DBXHP52GCBV','3DBXHP2GCBV'))c on b.new_plan_name = c.call_plan_desc
		left join `data-dtptechm-prd-c7ca.dwh.angie_hrchy_dim` hd on hd.angie_hrchy_sk_id = b.angie_hrchy_sk_id
		left join `data-bi-prd-935c.bi_stg.subs_site_branch_temp` sub_ref on sub_ref.sbscrptn_ek_id = a.sbscrptn_ek_id
		left join `data-dtptechm-prd-c7ca.stg.stg_v_map_tgt_ret_details` ret_map on ret_map.ret_qr_cd = b.retailer_qrcode
		;
	 


		delete from `data-bi-prd-935c.bi_mart.subs_ret_qsso_detail_2`
		where dt=vdt_id;

		insert into `data-bi-prd-935c.bi_mart.subs_ret_qsso_detail_2`
		select cast(vdt_id as date) as dt,a.* from `data-bi-prd-935c.bi_stg.ale_subs_ret_qsso_detail_temp` a;
	 
		delete from`data-bi-prd-935c.bi_mart.subs_ret_qsso_detail_3` where dt=vdt_id;

	insert into `data-bi-prd-935c.bi_mart.subs_ret_qsso_detail_3`
select cast(dt as date) as dt,ret_site_id,ret_branch, qsso from 
(
	select dt,ret_site_id,ret_branch, qsso_cum as qsso,row_number() over (partition by ret_site_id) rnk from 
	(
				select dt,ret_site_id,ret_branch, qsso,sum(qsso) over ( partition by ret_site_id) as qsso_cum from 
				(
				select dt,ret_site_id,ret_branch,count(distinct retailer_qrcode) qsso from 
				(
				select dt,ret_site_id,retailer_qrcode,ret_branch,count(distinct sbscrptn_ek_id) as subs from 
				`data-bi-prd-935c.bi_mart.subs_ret_qsso_detail_2`
				where 
				dt=vdt_id
				 group by 1,2,3,4 
				having count(*) >=3 
				) x group by 1,2,3
				) z group by 1,2,3,4 
	) A where qsso_cum >=3
) z where rnk=1;
 



		delete from `data-bi-prd-935c.bi_mart.dm_mart_satu`
		where squad='BTS Factory' 
		and 
		kpi_code='Sites >= 3 QSSO'and dt= vdt_id;
	 
		insert into  `data-bi-prd-935c.bi_mart.dm_mart_satu` 
		select cast(dt as date) as dt,
		'BTS Factory' as squad,
		'Sites >= 3 QSSO' as kpi_code,
		upper(coalesce(branch, 'N/A'))branch,
		case when upper(coalesce(branch, 'N/A')) in ('ACEH', 'LHOKSEUMAWE', 'MEDAN', 'DELI SERDANG', 'KISARAN', 'SIANTAR', 'BATAM', 'PADANG', 'PEKANBARU', 'BENGKULU LAMPUNG', 'JAMBI', 'PALEMBANG') then 'NCSS'
		when upper(coalesce(branch, 'N/A')) in ('CENTRAL WEST NORTH JKT', 'EAST SOUTH JKT DEPOK', 'TANGERANG', 'BEKASI', 'BOGOR', 'SERANG') then 'JABO'
		when upper(coalesce(branch, 'N/A')) in ('BANDUNG', 'TASIKMALAYA', 'CIANJUR SUKABUMI', 'CIREBON', 'KARAWANG') then 'WJ'
		when upper(coalesce(branch, 'N/A')) in ('BALIKPAPAN', 'BANJARMASIN', 'PONTIANAK', 'MAKASSAR', 'MANADO') then 'KALSUL'
		when upper(coalesce(branch, 'N/A')) in ('PURWOKERTO', 'SEMARANG', 'YOGYAKARTA', 'SOLO', 'MADIUN', 'PONOROGO') then 'CJ'
		when upper(coalesce(branch, 'N/A')) in ('MALANG', 'BLITAR', 'KEDIRI', 'SURABAYA', 'SIDOARJO', 'GRESIK', 'MOJOKERTO', 'JEMBER', 'BALI', 'LOMBOK') then 'EJBL'
		when upper(coalesce(branch, 'N/A')) in ('NATIONAL') then 'NATIONAL'
		else upper(coalesce(branch, 'N/A')) end as region
		,count(distinct ret_site_id) value from 
		(							select dt,ret_branch as branch,case when newsiteid is null then ret_site_id
							when newsiteid ='-' then oldsiteid
							else newsiteid end as ret_site_id,ret_branch,qsso from 
				(
					select * from 
					`data-bi-prd-935c.bi_mart.subs_ret_qsso_detail_3`
					where dt =vdt_id
					and case when length(ret_site_id)<6 then lpad(ret_site_id,6,'0') else ret_site_id end in (
					select site from 
					(
						select case when length(oldsiteid)<6 then lpad(oldsiteid,6,'0') else oldsiteid end site from 
						`data-bi-prd-935c.bi_mart.dm_phy_addressable_sites`
						where mth = (select max(mth) from `data-bi-prd-935c.bi_mart.dm_phy_addressable_sites`  
                    where mth <= DATE_TRUNC(DATE_SUB(vdt_id, INTERVAL 1 MONTH), MONTH))
						and addressablesites='ADDRESSABLE SITE'
						union all 
						select case when length(newsiteid)<6 then lpad(newsiteid,6,'0') else newsiteid end site from 
						`data-bi-prd-935c.bi_mart.dm_phy_addressable_sites`
						where mth = (select max(mth) from `data-bi-prd-935c.bi_mart.dm_phy_addressable_sites`  
                    where mth <= DATE_TRUNC(DATE_SUB(vdt_id, INTERVAL 1 MONTH), MONTH))
						and addressablesites='ADDRESSABLE SITE'
					) x group by 1 
					)
				) a left join 
				(
					select oldsiteid,newsiteid from 
					`data-bi-prd-935c.bi_mart.dm_phy_addressable_sites`
					where mth = (select max(mth) from `data-bi-prd-935c.bi_mart.dm_phy_addressable_sites`  
                    where mth <= DATE_TRUNC(DATE_SUB(vdt_id, INTERVAL 1 MONTH), MONTH))
					and addressablesites='ADDRESSABLE SITE'
					group by 1,2 
				) b on case when length(ret_site_id)<6 then lpad(ret_site_id,6,'0') else ret_site_id end =case when length(oldsiteid)<6 then lpad(oldsiteid,6,'0') else oldsiteid end
		) b
		group by 1,2,3,4,5;
	
