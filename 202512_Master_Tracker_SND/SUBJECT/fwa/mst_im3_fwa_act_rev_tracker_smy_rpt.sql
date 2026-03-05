BEGIN
DECLARE vdt_id date default @vdt_id;
select 
vdt_id dt_id
,a.brand
,'FWA' page
,b.circle
,b.region_circle 
,b.area
,b.sales_area branch
,a.kpi_id as kpi
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
,sum(a.metric_val) as val
from `data-bi-prd-935c.bi_mart.ioh_fwa_kpi_detail` a 
        left outer join `data-bi-prd-935c.bi_mart.ref_site` b ON a.level_value = b.site_id AND level = 'siteid'
where a.dt_id between DATE_TRUNC(date(vdt_id), MONTH) and date(vdt_id)  and time_flag = 'dly' and kpi_id like 'REV-%'
group by 1,2,3,4,5,6,7,8;

END
