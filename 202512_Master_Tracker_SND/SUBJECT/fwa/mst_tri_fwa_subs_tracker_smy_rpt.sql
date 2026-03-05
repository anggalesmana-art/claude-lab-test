BEGIN
DECLARE vdt_id date default @vdt_id;

	SELECT 
	date(vdt_id) dt_id
	,a.brand
	,'FWA' page
	,b.circle
	,b.region_circle 
	,b.area
	,b.gladiator_branch branch
	,a.kpi_nm as kpi
	,'' addfield1
	,'' addfield2
	,'' addfield3
	,'' addfield4
	,'' addfield5
	,'' addfield6
	,'' addfield7
	,'' addfield8
	,'' addfield9
	,'' addfield10
	,'' addfield11
	,sum(a.metric_value) as val
	from `data-bi-prd-935c.bi_mart.fwa_mart` a 
	left outer join `data-bi-prd-935c.bi_mart.ref_site_h3i` b on a.attr_value = b.site_id
	where 
	dt_id between DATE_TRUNC(date(vdt_id), MONTH) and date(vdt_id)
				and time_flag = 'dly'
				and kpi_nm in ('CHURNBACK90','GROSSCHURN90','RGUGA')
	group by 1,2,3,4,5,6,7,8
	union all 
	SELECT 
	dt_id
	,a.brand
	,'FWA' page
	,b.circle
	,b.region_circle 
	,b.area
	,b.gladiator_branch branch
	,a.kpi_nm as kpi
	,'' addfield1
	,'' addfield2
	,'' addfield3
	,'' addfield4
	,'' addfield5
	,'' addfield6
	,'' addfield7
	,'' addfield8
	,'' addfield9
	,'' addfield10
	,'' addfield11
	,sum(a.metric_value) as val
	from `data-bi-prd-935c.bi_mart.fwa_mart` a 
	left outer join `data-bi-prd-935c.bi_mart.ref_site_h3i` b on a.attr_value = b.site_id
	where 
	dt_id = date(vdt_id) and time_flag = 'mtd' and kpi_nm = 'RGU90'
	group by 1,2,3,4,5,6,7,8;

END