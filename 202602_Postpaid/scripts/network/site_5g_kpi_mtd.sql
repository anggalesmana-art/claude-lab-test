select 
	(dt_id), 
	brand,  
	page,  
	circle,
	region,
	area,  
	branch , 
	kpi_name kpi,
	addfield1, 
  	NULL addfield2,
  	NULL addfield3,
  	NULL addfield4,
  	NULL addfield5,
  	NULL addfield6,
  	NULL addfield7,
  	NULL addfield8,
  	NULL addfield9,
  	NULL addfield10,
  	NULL addfield11, 
  	value `values`
 from `data-bi-prd-935c.bi_dm.ds_cmm_5g_dboard` 
UNION ALL
 select 
 	format_date('%Y%m%d',mth_id), 
 	'IOH' brand,  
 	'Prepaid' page,  
 	circle,
 	region_circle region,
 	area,  
 	sales_area branch, 
 	kpi, 
 	kabkot_nm addfield1, 
  	NULL addfield2,
  	NULL addfield3,
  	NULL addfield4,
  	NULL addfield5,
  	NULL addfield6,
  	NULL addfield7,
  	NULL addfield8,
  	NULL addfield9,
  	NULL addfield10,
  	NULL addfield11, 
  	metric `values`
  from `data-bi-prd-935c.bi_dm.tmp_eren_device_usg_summ_dboard` 
 order by 1 desc	
 ;