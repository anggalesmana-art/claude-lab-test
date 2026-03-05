declare vdt_id date default @vdt_id;
	  

-- insert GA Subs to tmp (msisdn, call_plan, partner_code)

create or replace table `data-bi-prd-935c.bi_stg.snd_rgu_ga_detail_tmp_1` as
with base as	(
					select ga_date, sbscrptn_ek_id
					from `data-bi-prd-935c.bi_mart`.project_ioh_fu_master_v2
					where ga_date = vdt_id
				)
			
select 	ga_date load_dt_sk_id, 
		fct_ga_site.site_id_90 site_id, 
		a.sbscrptn_ek_id, 
		nik.sbscrptn_msisdn, 
		coalesce(ang_act.new_plan_name,attribs.call_plan_desc) call_plan, 
		coalesce(ang_act.retailer_qrcode,attribs.angie_retailer_name) partner_qr_cd
from base a
left join	(	
				select sbscrptn_ek_id, sbscrptn_msisdn
				from	(
							select 	dt dt_id,sbscrptn_ek_id,sbscrptn_msisdn, 
									row_number() over (partition by sbscrptn_ek_id  order by dt desc) rnk 
							from `data-bi-prd-935c.bi_mart`.fct_rgu_ioh_NIK_mstr
							where tag = 'rgu90' 
							--and subs_segment ='B2C'
							and dt between date_trunc(vdt_id,month) and vdt_id
						) x
				where rnk = 1
			) nik 
on a.sbscrptn_ek_id = nik.sbscrptn_ek_id
left join	(
				select dt, sbscrptn_ek_id, site_id site_id_90
				FROM `data-bi-prd-935c.bi_mart`.fct_ga_site_id a
				WHERE a.dt = vdt_id
			) fct_ga_site
on a.sbscrptn_ek_id = fct_ga_site.sbscrptn_ek_id 
and a.ga_date = fct_ga_site.dt
left join	(
					select cast(a.sbscrptn_ek_id as string) xsubs, a.new_plan_name, a.retailer_qrcode 
					from `data-dtptechm-prd-c7ca.dwh`.angie_activations a 
					inner join base b
					on b.sbscrptn_ek_id = cast(a.sbscrptn_ek_id as string)
					where date(expiry_date) >= vdt_id
			) ang_act
on ang_act.xsubs = a.sbscrptn_ek_id			
left join	(
				select cast(a.sbscrptn_ek_id as string) xsubs, a.call_plan_desc, a.angie_retailer_name 
				from `data-dtptechm-prd-c7ca.dwh`.sbscrptn_attribs a
				inner join base b
				on b.sbscrptn_ek_id = cast(a.sbscrptn_ek_id as string)
			) attribs
on attribs.xsubs = a.sbscrptn_ek_id;

-- tmp 2

create or replace table `data-bi-prd-935c.bi_stg.snd_rgu_ga_detail_tmp_2` as

with tmp1 as	(
					select load_dt_sk_id, site_id, cast(sbscrptn_ek_id as int64) sbscrptn_ek_id, sbscrptn_msisdn, call_plan, partner_qr_cd				
					from `data-bi-prd-935c.bi_stg.snd_rgu_ga_detail_tmp_1`
				)

select 	tmp1.load_dt_sk_id, 
		tmp1.site_id, 
		cast(tmp1.sbscrptn_ek_id as string) sbscrptn_ek_id , 
		tmp1.sbscrptn_msisdn, 
		tmp1.call_plan, 
		tmp1.partner_qr_cd,
		tmp_rev_base.xsp_price sp_price_revbase,
		tmp_rev_base.xfrc_price injection_price_revbase,
		tmp_frc_stock.xsp_price sp_price_frcstock,
	 	tmp_frc_stock.xinjection injection_price_frcstock,
	 	coalesce(tmp_rev_base.xsp_price,tmp_frc_stock.xsp_price) combine_sp_price,
		coalesce(tmp_rev_base.xfrc_price,tmp_frc_stock.xinjection) combine_injection_price,
		xkabupaten kabupaten,
		xkecamatan kecamatan				
from tmp1
left join	(
				select trx_dt_sk_id, xsubs, sum(xsp_price) xsp_price, sum(xfrc_price) xfrc_price
				from	(
							select 	a.trx_dt_sk_id, a.sbscrptn_ek_id xsubs,
									case when service_type_category_1 = 'P3 FRC Blank SIM Revenue' then sum(gross_revenue) end xsp_price,
									case when service_type_category_1 = 'FRC' then sum(gross_revenue) end xfrc_price
							from `data-dtptechm-prd-c7ca.dwh.revenue_base` a
							inner join  tmp1 ga
							on ga.sbscrptn_ek_id  = a.sbscrptn_ek_id            
							where process_nm = 'SIM_DEMAND'
							and revenue_book_incl_ind = 'INCLUDE' 
							and trx_dt_sk_id between timestamp(date_sub(vdt_id, interval 12 month)) and  timestamp(vdt_id)
							group by a.trx_dt_sk_id, a.sbscrptn_ek_id, service_type_category_1							
						) x
				group by 1,2
			) tmp_rev_base
on tmp_rev_base.xsubs = tmp1.sbscrptn_ek_id
left join	(
				select   
			        a.sbscrptn_ek_id xsubs, 
			        sum(gross_revenue) xinjection, 
			        sum(p3_cashback) xsp_price
				from	tmp1 a
				inner join	`data-dtptechm-prd-c7ca.dwh.frc_stock` b
				on b.sbscrptn_ek_id = a.sbscrptn_ek_id
				where 1=1
				and load_dt_sk_id = vdt_id	
				and trx_dt_sk_id >= date_sub(vdt_id, interval 12 month)
				and stock_out_dtm = timestamp(vdt_id)
				group by 1								
			) tmp_frc_stock
on tmp_frc_stock.xsubs = tmp1.sbscrptn_ek_id
left join	(	
				select * 
				from	(
							select site_id xsite_id, kabupaten xkabupaten, kecamatan xkecamatan, cnt, row_number() over (partition by site_id order by cnt desc) rnk 
							from	(
										select site_id, kabkot_nm kabupaten, kecamatan_nm kecamatan, count(*) cnt 
										from `data-bi-prd-935c.bi_mart`.ref_site_h3i_mth
										where mth_id = date_trunc(vdt_id,month)
										group by 1,2,3
									) x
						) y 
				where rnk=1 														
			) ref_site
on tmp1.site_id = ref_site.xsite_id 			
where tmp1.load_dt_sk_id = vdt_id;

-- tmp 3 table (sp price, channel, outlet_flag, imei, flag)

create or replace table `data-bi-prd-935c.bi_stg.snd_rgu_ga_detail_tmp_3` as

with tmp2 as	(
					select	load_dt_sk_id, site_id, partner_qr_cd, cast(sbscrptn_ek_id as int64) sbscrptn_ek_id, sbscrptn_msisdn, call_plan, 
							kabupaten, kecamatan, sp_price_revbase, injection_price_revbase, 
							sp_price_frcstock, injection_price_frcstock, 
							combine_sp_price, combine_injection_price							
					from `data-bi-prd-935c.bi_stg.snd_rgu_ga_detail_tmp_2`
					where load_Dt_sk_id = vdt_id
				)

select 	tmp2.*,
		hoo_name,
		case when retailer_qrcode is not null then 'PJP' else 'Non PJP' end outlet_flag,
		case when imei_flag = 'Y' then imei_flag else 'N' end f_new_imei,
		case 	
				when coalesce(combine_injection_price,0) = 0 
						then 'NO INJ'
				when coalesce(combine_sp_price,10000) + coalesce(combine_injection_price,0) >= 1 
					and coalesce(combine_sp_price,10000) + coalesce(combine_injection_price,0) < 10000 
					and coalesce(combine_injection_price,0) > 0 
						then 'LVC'
				when coalesce(combine_sp_price,10000) + coalesce(combine_injection_price,0) >= 10000 
					and coalesce(combine_sp_price,10000) + coalesce(combine_injection_price,0) < 35000 
					and coalesce(combine_injection_price,0) > 0 
						then 'MVC'
				when coalesce(combine_sp_price,10000) + coalesce(combine_injection_price,0) >= 35000 
					and combine_injection_price > 0 
						then 'HVC'
		end xflag
from tmp2
left join	(			
				select distinct partner_qr_cd , hoo_name			
	            from `data-bi-prd-935c.bi_mart`.angie_hrchy_dim_hst b
	            where mth = date_trunc(vdt_id,month)
			) ref_hrchy
on ref_hrchy.partner_qr_cd = tmp2.partner_qr_cd 
left join	(
				select distinct retailer_qrcode
				from `data-bi-prd-935c.bi_snd.pre_ref_outlet_mapping_3id`
				where parse_date('%Y%m',cast(mth_id as string)) = date_trunc(vdt_id,month)
			) ref_outlet
on ref_outlet.retailer_qrcode = tmp2.partner_qr_cd
left join	(
				select sbscrptn_ek_id xsubs, imei_flag
				from	(
							select 	tmp2.sbscrptn_ek_id, 'Y' imei_flag,
									row_number() over (partition by tmp2.sbscrptn_ek_id  order by dt desc) rnk
							from `data-bi-prd-935c.bi_mart.dm_rgs30_subs_movement_detail` imei
							inner join tmp2
							on tmp2.sbscrptn_ek_id = cast(imei.sbscrptn_ek_id as int64)
							where dt between date_trunc(vdt_id,month) and vdt_id
							and flag_rotation = 'New New'
						) x
				where rnk = 1
			) ref_imei
on ref_imei.xsubs = tmp2.sbscrptn_ek_id;

-- acq rev

create or replace table `data-bi-prd-935c.bi_stg.snd_rgu_ga_detail_acq_rev` as
select
	mth,
	brand,
	case
		when trade_tag = 'Trade' then 'TRADITIONAL'
		else 'MODERN'
	end as channel_grp,
	'' as flag_inject,
	'DATA' as svc_typ,
	'DATA' as flag,
	sbscrptn_ek_id,
	sum(data_rev) as rev
from
	`data-bi-prd-935c.bi_mart`.fct_ga_acq_new
where 1=1
--	data_rev > 0
and mth = vdt_id
group by
	1,2,3,4,5,6,7

union all

select
	mth,
	brand,
	case
		when trade_tag = 'Trade' then 'TRADITIONAL'
		else 'MODERN'
	end as channel_grp,
	'' as flag_inject,
	'DATA' as svc_typ,
	'GIFT DATA' as flag,
	sbscrptn_ek_id,
	sum(kikida_data_rev) as rev
from
	`data-bi-prd-935c.bi_mart`.fct_ga_acq_new
where 1=1
--	kikida_data_rev > 0
and mth = vdt_id	
group by
	1,2,3,4,5,6,7

union all

select
	mth,
	brand,
	case
		when trade_tag = 'Trade' then 'TRADITIONAL'
		else 'MODERN'
	end as channel_grp,
	'' as flag_inject,
	'NON DATA' as svc_typ,
	'NON DATA' as flag,
	sbscrptn_ek_id,
	sum(non_data_rev) as rev
from
	`data-bi-prd-935c.bi_mart`.fct_ga_acq_new
where 1=1
--	non_data_rev > 0
and mth = vdt_id	
group by
	1,2,3,4,5,6,7

union all

select
	mth,
	brand,
	case
		when trade_tag = 'Trade' then 'TRADITIONAL'
		else 'MODERN'
	end as channel_grp,
	'' as flag_inject,
	'NON DATA' as svc_typ,
	'VAS' as flag,
	sbscrptn_ek_id,
	sum(vas_data) as rev
from
	`data-bi-prd-935c.bi_mart`.fct_ga_acq_new
where 1=1
-- vas_data > 0
and mth = vdt_id	
group by
	1,2,3,4,5,6,7

union all

select
	mth,
	brand,
	case
		when trade_tag = 'Trade' then 'TRADITIONAL'
		else 'MODERN'
	end as channel_grp,
	'' as flag_inject,
	'NON DATA' as svc_typ,
	'GIFT NON DATA' as flag,
	sbscrptn_ek_id,
	sum(kikida_nondata_rev) as rev
from
	`data-bi-prd-935c.bi_mart`.fct_ga_acq_new
where 1=1
--	kikida_nondata_rev > 0
and mth = vdt_id	
group by
	1,2,3,4,5,6,7;
					

-- tmp 4 table (acqusition revenue)

create or replace table `data-bi-prd-935c.bi_stg.snd_rgu_ga_detail_tmp_4` as

with tmp3 as	(
					select 	load_dt_sk_id, site_id, partner_qr_cd, sbscrptn_ek_id, sbscrptn_msisdn, call_plan, flag_type, flag_rgu_ga, kabupaten, kecamatan, 
							sp_price_revbase, injection_price_revbase, sp_price_frcstock, injection_price_frcstock, combine_sp_price, combine_injection_price, 
							cnt_100mb, cnt_250mb, cnt_500mb, cnt_1000mb, tot_usg, update_dt, 
							channel, outlet_flag, kpk_correction_price, f_new_imei, bookingdatetime, book_qrcode, book_qrcode_final, tag
					from `data-bi-prd-935c.bi_mart.snd_rgu_ga_new_detail`
					where load_Dt_sk_id >= date_trunc(vdt_id,month)
					and load_dt_sk_id < vdt_id
					
					union all 
					
					select 	load_dt_sk_id, site_id, partner_qr_cd, cast(sbscrptn_ek_id as string) sbscrptn_ek_id, sbscrptn_msisdn, call_plan, xflag flag_type, null flag_rgu_ga, kabupaten, kecamatan, 
							sp_price_revbase, injection_price_revbase, sp_price_frcstock, injection_price_frcstock, combine_sp_price, combine_injection_price, 
							null cnt_100mb, null cnt_250mb, null cnt_500mb, null cnt_1000mb, null tot_usg, null update_dt, 
							hoo_name, outlet_flag, null kpk_correction_price, f_new_imei, null bookingdatetime, null book_qrcode, null book_qrcode_final, null tag
					from `data-bi-prd-935c.bi_stg.snd_rgu_ga_detail_tmp_3`
					where load_Dt_sk_id = vdt_id
				) 

select 	tmp3.load_dt_sk_id, site_id, partner_qr_cd, tmp3.sbscrptn_ek_id, tmp3.sbscrptn_msisdn, call_plan, 
		flag_type, flag_rgu_ga, kabupaten, kecamatan, cast(sp_price_revbase as numeric) sp_price_revbase, cast(injection_price_revbase as numeric) injection_price_revbase, cast(sp_price_frcstock as numeric) sp_price_frcstock, cast(injection_price_frcstock as numeric) injection_price_frcstock, 
		cast(combine_sp_price as numeric) combine_sp_price, cast(combine_injection_price as numeric) combine_injection_price, cnt_100mb, cnt_250mb, cnt_500mb, cnt_1000mb, tot_usg, update_dt, 
		channel, outlet_flag, kpk_correction_price, f_new_imei, 
    acq_rev.rev, acq_rev.rev_data, acq_rev.rev_nondata,
		/*datetime(ref_tag.xbookingdatetime)*/ cast(ref_tag.xbookingdatetime as string) xbookingdatetime, ref_tag.xbook_qrcode,
		coalesce	(
						book_qrcode_final, 
						case						
							when xbookingdatetime is not null and date(ref_tag.xbookingdatetime) <= load_dt_sk_id 
								then xbook_qrcode 
							else partner_qr_cd
						end
					) book_qrcode_final,
		coalesce	(
						tag, 
						case						
							when xbookingdatetime is not null and date(ref_tag.xbookingdatetime) <= load_dt_sk_id 
								then 'booking'
							else 'frc'
						end
					) tag		
from tmp3
left join	(
				select 	xsubs, 
						sum(rev) rev,
						sum(rev_data) rev_data, 
						sum(rev_nondata) rev_nondata						
				from	(				
							select 	acq_rev.sbscrptn_ek_id xsubs, 
									case when svc_typ = 'DATA' then sum(rev) end rev_data,
									case when svc_typ = 'NON DATA' then sum(rev) end rev_nondata,
									sum(rev) rev
							from `data-bi-prd-935c.bi_stg.snd_rgu_ga_detail_acq_rev` acq_rev
							inner join	tmp3 ga
							on ga.sbscrptn_ek_id = acq_rev.sbscrptn_ek_id 
							group by acq_rev.sbscrptn_ek_id,acq_rev.svc_typ
						) x
				group by 1
			) acq_rev
on acq_rev.xsubs = tmp3.sbscrptn_ek_id
left join	(
				SELECT 
				    mart.*
				    FROM (
						    SELECT 
						        rnk.*, 
						        ROW_NUMBER() OVER (PARTITION BY sbscrptn_ek_id ORDER BY xbookingdatetime DESC) AS rnk 
						    FROM (
							        SELECT 
							        	a.load_dt_sk_id xload_dt_sk_id,
							        	cast(a.sbscrptn_ek_id as string) sbscrptn_ek_id,
							            a.sbscrptn_msisdn,
							            b.bookingdatetime xbookingdatetime,
							            b.retailerqrcode AS xbook_qrcode
							        FROM `data-bi-prd-935c.bi_stg.snd_rgu_ga_detail_tmp_3` a
							        LEFT JOIN 	(
										            SELECT 
														subscribermsisdn,
														retailerqrcode,
														bookingdatetime
										            from `data-dtptechm-prd-c7ca.stg.stg_lms_booking_info`
													where date(bookingdatetime) between date_trunc(vdt_id,month) and vdt_id
													and status not in ('REJECTED')
													and reqtype in ('SIM')
													union all 
													select 
														subscribermsisdn,
														retailerqrcode,
														timestamp(bookingdate) bookingdatetime													
													 from `data-bi-prd-935c.bi_snd.pre_raw_lms_addon_tagging_202512`
							        			) b
							        ON b.subscribermsisdn = a.sbscrptn_msisdn 
							        and  date(b.bookingdatetime) <= load_dt_sk_id  
						   		 ) rnk
						) mart 
				WHERE rnk = 1 and xbook_qrcode is not null
			) ref_tag
on ref_tag.sbscrptn_ek_id = tmp3.sbscrptn_ek_id
and ref_tag.sbscrptn_msisdn = tmp3.sbscrptn_msisdn; 

-- delete before insert

delete from `data-bi-prd-935c.bi_mart.snd_rgu_ga_new_detail` 
where load_dt_sk_id between date_trunc(vdt_id,month) and vdt_id;

-- insert into main table

insert into `data-bi-prd-935c.bi_mart.snd_rgu_ga_new_detail`

select *	
from `data-bi-prd-935c.bi_stg.snd_rgu_ga_detail_tmp_4`
where load_dt_sk_id between date_trunc(vdt_id,month) and vdt_id;

----------------------------------------------------------------------------

-- result check

--select *	
--from `data-bi-prd-935c.bi_stg.snd_rgu_ga_detail_tmp_2`
--where load_dt_sk_id between date_trunc(vdt_id,month) and vdt_id;
--
--select load_dt_sk_id, terr.circle, 'gcp' src, count(sbscrptn_ek_id) cnt 
--from `data-bi-prd-935c.bi_mart.snd_rgu_ga_new_detail` a
--left join	(
--			    SELECT id, id_name, flag, kec_unik, '3ID' AS brand
--			    FROM `data-bi-prd-935c`.`bi_snd`.`pre_ref_lowlevel_mth_3id`
--			    WHERE FORMAT_DATE('%Y%m', mth_id) = '202511' AND flag IN ('SITE')
--			) ref
--on ref.id = a.site_id
--LEFT JOIN	(
--			    select *, 'KEC_WISE' flag
--			    from `data-bi-prd-935c.bi_snd.pre_ref_hirarki_territory_ioh` terr
--			    where cast(terr.mth as string) = '202511' 
--			    and brand = '3ID'
--   			) terr
--ON 	ref.kec_unik = terr.kecamatan			
--group by all
--
--union all
--
--select load_dt_sk_id, terr.circle, 'gp' src, count(*) cnt 
--from `data-bi-prd-935c.bi_snd.pre_raw_3id_rgu_ga_dtl` a
--left join	(
--			    SELECT id, id_name, flag, kec_unik, '3ID' AS brand
--			    FROM `data-bi-prd-935c`.`bi_snd`.`pre_ref_lowlevel_mth_3id`
--			    WHERE FORMAT_DATE('%Y%m', mth_id) = '202511' AND flag IN ('SITE')
--			) ref
--on ref.id = a.site_id
--LEFT JOIN	(
--			    select *, 'KEC_WISE' flag
--			    from `data-bi-prd-935c.bi_snd.pre_ref_hirarki_territory_ioh` terr
--			    where cast(terr.mth as string) = '202511' 
--			    and brand = '3ID'
--   			) terr
--ON 	ref.kec_unik = terr.kecamatan	
--where load_dt_sk_id between '2025-11-01' and vdt_id
--group by all