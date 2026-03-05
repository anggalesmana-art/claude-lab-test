declare vdt_id date default @vdt_id;


    DELETE FROM `data-bi-prd-935c.bi_dev`.ioh_snd_master_kpi_detail
    WHERE brand = '3ID'
    AND kpi IN ('primary_nontrad','secondary_nontrad')
    AND dt_id = vdt_id;

 INSERT INTO `data-bi-prd-935c.bi_dev`.ioh_snd_master_kpi_detail   
    SELECT 
        '3ID' AS brand,
        'partner' AS level,
        ''  AS level_value,
        sum(fct.actual_amt)  value,
        'mtd' AS time_flag,
        timestamp(current_datetime('+7')) AS insert_date,
        'primary_nontrad' AS kpi,
        vdt_id AS dt_id 
    FROM    
  `data-dtptechm-prd-c7ca.dwh`.evc_dealer_purchase_fct fct
  join  `data-dtptechm-prd-c7ca.dwh`.date_dim dt  on fct.load_dt_sk_id = timestamp(safe.parse_date('%Y%m%d',cast(dt.date_sk_id as string)))  
  join  `data-dtptechm-prd-c7ca.dwh`.rprt_fltr_ref_ctgry     rfrc on (fct.stock_sk_id = rfrc.rprt_fltr_ref_ctgry_sk_id 
                                         and ref_type_cd = 'EVC ACCT TRA ERP STOCK DIM' and category = 'VO-ELC')  ---- Product = V3
 left  join  `data-dtptechm-prd-c7ca.dwh`.evc_dealer_dim          edd  on (fct.evc_dealer_sk_id = edd.evc_dealer_sk_id 
                                         and edd.evc_model_sk_id = 2
                                         --and (dc_hp_no in (select distinct ctgry_ref_prnt
                                           --                     from `data-dtptechm-prd-c7ca.dwh`.rprt_fltr_ref_ctgry where ref_type_cd = 'EVC Modern Channel')
                                 --  or upper(dealer_name) like '%MODERN%')
                                             ) 	
  left join (select distinct ctgry_ref_prnt, category
               from `data-dtptechm-prd-c7ca.dwh`.rprt_fltr_ref_ctgry where ref_type_cd = 'EVC Modern Channel') refr on refr.ctgry_ref_prnt = edd.dc_hp_no
 where fct.load_dt_sk_id between  timestamp(date_trunc(vdt_id,month))   and timestamp(vdt_id) 
			and  edd.dealer_name is not null
    GROUP BY 1, 2, 3, 5,6, 7, 8 
union all 
    SELECT 
        '3ID' AS brand,
        'partner' AS level,
        ''  AS level_value,
       sum(amount)    value,
        'mtd' AS time_flag,
        timestamp(current_datetime('+7')) AS insert_date,
        'primary_nontrad' AS kpi,
       vdt_id  AS dt_id 
    FROM        
`data-bi-prd-935c.bi_mart`.project_ioh_tertiary_outlet a 
where a.source_nm <>'3AS'
and dt_sk_id between    date_trunc(vdt_id,month)   and vdt_id 
and source_nm ='BANK'
    GROUP BY 1, 2, 3, 5,6, 7, 8 
union all
   SELECT 
        '3ID' AS brand,
        'partner' AS level,
        ''  AS level_value,
        sum(fct.actual_amt)  value,
        'mtd' AS time_flag,
        timestamp(current_datetime('+7')) AS insert_date,
        'secondary_nontrad' AS kpi,
        vdt_id AS dt_id 
    FROM    
  `data-dtptechm-prd-c7ca.dwh`.evc_dealer_purchase_fct fct
  join  `data-dtptechm-prd-c7ca.dwh`.date_dim dt  on (fct.load_dt_sk_id = timestamp(safe.parse_date('%Y%m%d',cast(dt.date_sk_id as string))))  
  join  `data-dtptechm-prd-c7ca.dwh`.rprt_fltr_ref_ctgry     rfrc on (fct.stock_sk_id = rfrc.rprt_fltr_ref_ctgry_sk_id 
                                         and ref_type_cd = 'EVC ACCT TRA ERP STOCK DIM' and category = 'VO-ELC')  ---- Product = V3
 left  join  `data-dtptechm-prd-c7ca.dwh`.evc_dealer_dim          edd  on (fct.evc_dealer_sk_id = edd.evc_dealer_sk_id 
                                         and edd.evc_model_sk_id = 2
                                         --and (dc_hp_no in (select distinct ctgry_ref_prnt
                                           --                     from `data-dtptechm-prd-c7ca.dwh`.rprt_fltr_ref_ctgry where ref_type_cd = 'EVC Modern Channel')
                                 --  or upper(dealer_name) like '%MODERN%')
                                             ) 	
  left join (select distinct ctgry_ref_prnt, category
               from `data-dtptechm-prd-c7ca.dwh`.rprt_fltr_ref_ctgry where ref_type_cd = 'EVC Modern Channel') refr on refr.ctgry_ref_prnt = edd.dc_hp_no
 where fct.load_dt_sk_id between  timestamp(date_trunc(vdt_id,month))   and timestamp(vdt_id) 
			and  edd.dealer_name is not null
    GROUP BY 1, 2, 3, 5,6, 7, 8 
union all 
    SELECT 
        '3ID' AS brand,
        'partner' AS level,
        ''  AS level_value,
       sum(amount)    value,
        'mtd' AS time_flag,
        timestamp(current_datetime('+7')) AS insert_date,
        'secondary_nontrad' AS kpi,
        vdt_id AS dt_id 
    FROM        
`data-bi-prd-935c.bi_mart`.project_ioh_tertiary_outlet a 
where a.source_nm <>'3AS'
and dt_sk_id between    date_trunc(vdt_id,month)   and vdt_id 
and source_nm ='BANK'
    GROUP BY 1, 2, 3, 5,6, 7, 8 
;
