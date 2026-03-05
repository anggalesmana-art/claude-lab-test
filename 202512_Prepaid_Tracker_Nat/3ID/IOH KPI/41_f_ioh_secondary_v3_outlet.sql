DECLARE vdt_id DATE DEFAULT @vdt_id;


delete from `data-bi-prd-935c.bi_mart.project_ioh_v3_rs_stock` where load_dt_sk_id = vdt_id;
INSERT INTO `data-bi-prd-935c.bi_mart.project_ioh_v3_rs_stock`
WITH modern_dc AS (
  SELECT DISTINCT ctgry_ref_prnt
  FROM `data-dtptechm-prd-c7ca.dwh.rprt_fltr_ref_ctgry`
  WHERE ref_type_cd = 'EVC Modern Channel'
)
SELECT
  DATE_SUB(dt.full_dt, INTERVAL 1 DAY) AS load_dt_sk_id,
  REGEXP_REPLACE(edd_dc.dealer_name, r'[^a-zA-Z0-9\-_ ]', '') AS Switcher,
  fct.evc_dealer_sk_id,
  edd_dc.dc_hp_no AS DC_MSISDN,
  REGEXP_REPLACE(edd.dealer_name, r'[^a-zA-Z0-9\-_ ]', '') AS dealer_name,
  edd.hp_no AS dealer_msisdn,
  md.description AS dealer_type,
  refr.category,
  SUM(fct.stock0) AS total_stock
FROM `data-dtptechm-prd-c7ca.dwh.evc_dealer_hierarchy_stock_fct` fct
JOIN `data-dtptechm-prd-c7ca.dwh.evc_dealer_dim` edd
  ON fct.evc_dealer_sk_id = edd.evc_dealer_sk_id
JOIN `data-dtptechm-prd-c7ca.dwh.evc_dealer_dim` edd_dc
  ON edd.dc_sk_id = edd_dc.evc_dealer_sk_id
JOIN `data-dtptechm-prd-c7ca.dwh.date_dim` dt
  ON CAST(fct.load_dt_sk_id AS DATE) = CAST(dt.full_dt AS DATE)
JOIN `data-dtptechm-prd-c7ca.dwh.evc_model_dim` md
  ON edd.evc_model_sk_id = md.evc_model_sk_id
LEFT JOIN (
  SELECT DISTINCT ctgry_ref_prnt, category
  FROM `data-dtptechm-prd-c7ca.dwh.rprt_fltr_ref_ctgry`
  WHERE ref_type_cd = 'EVC Modern Channel'
) refr
  ON refr.ctgry_ref_prnt = edd_dc.dc_hp_no
-- filter after join instead of IN subquery
WHERE CAST(fct.load_dt_sk_id AS DATE) = DATE_ADD(vdt_id, INTERVAL 1 DAY)
  AND (
    edd_dc.dc_hp_no IN (SELECT ctgry_ref_prnt FROM modern_dc)
    OR UPPER(edd_dc.dealer_name) LIKE '%MODERN%'
  ) 
GROUP BY 1,2,3,4,5,6,7,8

			--ead
			union all
			select
				DATE_SUB(dt.full_dt, INTERVAL 1 DAY) as load_dt_sk_id,
				REGEXP_REPLACE(edd_dc.dealer_name, r'[^a-zA-Z0-9\-_ ]', '') AS Switcher,
				fct.evc_dealer_sk_id,
				edd_dc.dc_hp_no as DC_MSISDN,
				REGEXP_REPLACE(edd.dealer_name, r'[^a-zA-Z0-9\-_ ]', '') AS dealer_name,
				edd.hp_no as dealer_msisdn,
				md.description as dealer_type,
				'EAD',
				sum(fct.stock0) as total_stock
				from`data-dtptechm-prd-c7ca.dwh.evc_dealer_hierarchy_stock_fct` fct
				join `data-dtptechm-prd-c7ca.dwh.evc_dealer_dim`edd on fct.evc_dealer_sk_id = edd.evc_dealer_sk_id
				join  `data-dtptechm-prd-c7ca.dwh.evc_dealer_dim` edd_dc on (edd.dc_sk_id = edd_dc.evc_dealer_sk_id
								  and (lower(edd_DC.dealer_name) like '%ead%'
						and lower(edd_DC.dealer_name) not in (
						'keadaan cell',
						'reade ponsel',
						'victory readlo',
						'cread cell',
						'lead cell',
						'freadce'))) 
				 join `data-dtptechm-prd-c7ca.dwh.date_dim` dt on cast(fct.load_dt_sk_id as date) = dt.full_dt
				 join `data-dtptechm-prd-c7ca.dwh.evc_model_dim` md on (edd.evc_model_sk_id = md.evc_model_sk_id)
				 
				 where cast(fct.load_dt_sk_id as date) = DATE_ADD(vdt_id, INTERVAL 1 DAY)
				and md.description= 'Retailer'
			group by 1,2,3,4,5,6,7,8;

			
delete from `data-bi-prd-935c.bi_mart.project_ioh_secondary_outlet` where secondary_category = 'SALDO V3' and dt_sk_id = vdt_id;

INSERT INTO `data-bi-prd-935c.bi_mart.project_ioh_secondary_outlet`
				select CAST(vdt_id AS date),
				 'RS',
				 mst.category,
				 mst.dealer_msisdn,
				 cast(mst.evc_dealer_sk_id as string),
				 cast(mst.evc_dealer_sk_id as string),
				 'SALDO V3',
				 mst.category,
				 'V3',
				 coalesce(curr.total_stock,0) - coalesce(prev.total_stock,0) + coalesce(trx.val,0),1
				 
				from (select distinct dealer_msisdn, evc_dealer_sk_id, category
					from `data-bi-prd-935c.bi_mart.project_ioh_v3_rs_stock`
					where cast(load_dt_sk_id as date) in (vdt_id,DATE_SUB(vdt_id, INTERVAL 1 DAY))
					and dealer_type = 'Retailer'
					AND category in ('Mochan Offline', 'Mochan Online'))  mst
				left join `data-bi-prd-935c.bi_mart`.project_ioh_v3_rs_stock prev on cast(prev.load_dt_sk_id as date) = DATE_SUB(vdt_id, INTERVAL 1 DAY) and mst.evc_dealer_sk_id = prev.evc_dealer_sk_id
				left join `data-bi-prd-935c.bi_mart`.project_ioh_v3_rs_stock curr on cast(curr.load_dt_sk_id as date)= cast(vdt_id as date) and mst.evc_dealer_sk_id = curr.evc_dealer_sk_id
				left join (select
						cast(fct.recharge_dt_sk_id as date) as recharge_dt_sk_id,
						edd.EVC_DEALER_SK_ID as EVC_DEALER_SK_ID,
						sum(fct.src_value) as val
						from`data-dtptechm-prd-c7ca.dwh.evc_dealer_recharge_fct` fct
						join`data-dtptechm-prd-c7ca.dwh.rprt_fltr_ref_ctgry` rfrc on (fct.evc_acct_rec_stock_sk_id = rfrc.rprt_fltr_ref_ctgry_sk_id 
											and ref_type_cd = 'EVC ACCT TRA ERP STOCK DIM'
											and category = 'VO-ELC')
						 join `data-dtptechm-prd-c7ca.dwh.evc_dealer_dim` edd on fct.evc_dealer_sk_id = edd.evc_dealer_sk_id
											and edd.evc_model_sk_id = 5----retailer
						join`data-dtptechm-prd-c7ca.dwh.evc_dealer_dim` edd_dc on edd_dc.evc_dealer_sk_id = edd.dc_sk_id
						left join (select distinct ctgry_ref_prnt
							 from `data-dtptechm-prd-c7ca.dwh.rprt_fltr_ref_ctgry` where ref_type_cd = 'EVC Modern Channel') refmod 
							on edd_dc.dc_hp_no = refmod.ctgry_ref_prnt 
						join`data-dtptechm-prd-c7ca.dwh.date_dim` dt on cast(fct.recharge_dt_sk_id as date) = dt.full_dt
						where fct.stat_code = 0
						and fct.response_code = '00000'
						and cast(fct.recharge_dt_sk_id as date)  = vdt_id
						and (refmod.ctgry_ref_prnt is not null or upper(edd_dc.dealer_name) like '%MODERN%')
						group by 1,2) TRX on mst.EVC_DEALER_SK_ID = trx.EVC_DEALER_SK_ID

				--EAD
				union all
				select CAST(vdt_id AS date),
				 'RS',
				 mst.category,
				 mst.dealer_msisdn,
				 cast(mst.evc_dealer_sk_id as string),
				 cast(mst.evc_dealer_sk_id as string),
				 'SALDO V3',
				 mst.category,
				 'V3',
				 coalesce(curr.total_stock,0) - coalesce(prev.total_stock,0) + coalesce(trx.val,0),1
				 
				from (select distinct dealer_msisdn, evc_dealer_sk_id, category
					from `data-bi-prd-935c.bi_mart`.project_ioh_v3_rs_stock
					where load_dt_sk_id in (vdt_id,DATE_SUB(vdt_id, INTERVAL 1 DAY))
					and dealer_type = 'Retailer'
					AND category in ('EAD') ) mst
				left join `data-bi-prd-935c.bi_mart.project_ioh_v3_rs_stock` prev on prev.load_dt_sk_id = DATE_SUB(vdt_id, INTERVAL 1 DAY) and mst.evc_dealer_sk_id = prev.evc_dealer_sk_id
				left join `data-bi-prd-935c.bi_mart.project_ioh_v3_rs_stock` curr on cast(curr.load_dt_sk_id as date) = vdt_id and mst.evc_dealer_sk_id = curr.evc_dealer_sk_id
				left join (select
						cast(fct.recharge_dt_sk_id as date) as recharge_dt_sk_id,
						edd.EVC_DEALER_SK_ID as EVC_DEALER_SK_ID,
						sum(fct.src_value) as val
						from`data-dtptechm-prd-c7ca.dwh.evc_dealer_recharge_fct` fct
						left join `data-dtptechm-prd-c7ca.dwh.rprt_fltr_ref_ctgry` rfrc on (fct.evc_acct_rec_stock_sk_id = rfrc.rprt_fltr_ref_ctgry_sk_id 
											and ref_type_cd = 'EVC ACCT TRA ERP STOCK DIM'
											and category = 'VO-ELC')
						left join `data-dtptechm-prd-c7ca.dwh.evc_dealer_dim` edd on (fct.evc_dealer_sk_id = edd.evc_dealer_sk_id
											and edd.evc_model_sk_id = 5)----retailer
						join`data-dtptechm-prd-c7ca.dwh.evc_dealer_dim` edd_dc on edd_dc.evc_dealer_sk_id = edd.dc_sk_id
						left join (select distinct ctgry_ref_prnt
							 from `data-dtptechm-prd-c7ca.dwh.rprt_fltr_ref_ctgry` where ref_type_cd = 'EVC Modern Channel') refmod 
							on edd_dc.dc_hp_no = refmod.ctgry_ref_prnt 
						join`data-dtptechm-prd-c7ca.dwh.date_dim` dt on cast(fct.recharge_dt_sk_id as date) = dt.full_dt
						where fct.stat_code = 0
						and fct.response_code = '00000'
						and cast(fct.recharge_dt_sk_id as date)= vdt_id
						--and (refmod.ctgry_ref_prnt is not null or upper(edd_dc.dealer_name) like '%MODERN%')
						group by 1,2) TRX on mst.EVC_DEALER_SK_ID = trx.EVC_DEALER_SK_ID;
					

