declare vdt_id date default @vdt_id;
delete from  `data-bi-prd-935c.bi_mart`.data_uu_subs_smy where dt_id = vdt_id;

insert into `data-bi-prd-935c.bi_mart`.data_uu_subs_smy
	select  vdt_id 
,'3ID' brand,'Prepaid' as page
	,circle
	,region_circle region
	,area
	,gladiator_branch branch,kpi , 
'' addfield1 ,
'' addfield2,
'' addfield3,
'' addfield4,
'' addfield5,
'' addfield6,
'' addfield7,
'' addfield8,
'' addfield9,
'' addfield10,
'' addfield11,sum(values)/cast(right(cast(vdt_id as string),2) as integer) as value
  From 
	`data-bi-prd-935c.bi_dev`.ioh_snd_master_kpi_detail  a left join `data-bi-prd-935c.bi_mart`.ref_site_h3i b on 
	CASE WHEN LENGTH(a.level_value)<=5 THEN concat('0',a.level_value) ELSE a.level_value END = CASE WHEN LENGTH(b.site_id)<=5 THEN '0'||b.site_id ELSE b.site_id END
	where kpi in (
	'data_uu',
	'data_uu_less_90d',
	'data_uu_90d_180d',
	'data_uu_more_180d'
	) and level='site_id'
	and time_flag='dly' and brand = '3ID'
	AND  
	dt_id between 
date_trunc(vdt_id,month)
 and vdt_id 
group by 1,2,3,4,5,6,7,8 ,9,10,11,12,13,14,15,16,17,18,19;