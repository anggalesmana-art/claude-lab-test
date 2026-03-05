DECLARE vdt_id DATE DEFAULT @vdt_id;

delete from `data-bi-prd-935c.bi_mart.project_ioh_primary_outlet` where primary_category = 'SALDO V3' and dt_sk_id = vdt_id;

INSERT INTO `data-bi-prd-935c.bi_mart.project_ioh_primary_outlet`
				select cast(fct.load_dt_sk_id as date),
				 receiver_category_code,
				 coalesce(refr.category,'EAD'),
				 edd.dc_hp_no as DC_MSISDN,
				 cast(fct.evc_dealer_sk_id as string),
				 cast(fct.evc_dealer_sk_id as string),
				 'SALDO V3',
				 refr.category,
				 'V3',
				 sum(fct.actual_amt) as Stock_Aggregation_IDR,
				 count(1)
				from`data-dtptechm-prd-c7ca.dwh.evc_dealer_purchase_fct` fct
				join`data-dtptechm-prd-c7ca.dwh.rprt_fltr_ref_ctgry` rfrc on (fct.stock_sk_id = rfrc.rprt_fltr_ref_ctgry_sk_id 
									 and ref_type_cd = 'EVC ACCT TRA ERP STOCK DIM' and category = 'VO-ELC')---- Product = V3
				join`data-dtptechm-prd-c7ca.dwh.evc_dealer_dim` edd on (fct.evc_dealer_sk_id = edd.evc_dealer_sk_id 
									 and edd.evc_model_sk_id = 2
									 /*and (dc_hp_no in (select distinct ctgry_ref_prnt
												from dwh.rprt_fltr_ref_ctgry where ref_type_cd = 'EVC Modern Channel')
								 or upper(dealer_name) like '%MODERN%')*/
									 ) 	
				left join (select distinct ctgry_ref_prnt, category
					 from `data-dtptechm-prd-c7ca.dwh.rprt_fltr_ref_ctgry` where ref_type_cd = 'EVC Modern Channel') refr on refr.ctgry_ref_prnt = edd.dc_hp_no
				 where cast(fct.load_dt_sk_id as date) = vdt_id
				 group by 1,2,3,4,5,6,7,8,9;
