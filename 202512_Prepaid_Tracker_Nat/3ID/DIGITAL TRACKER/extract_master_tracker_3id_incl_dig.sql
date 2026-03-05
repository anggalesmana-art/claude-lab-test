-- Done changed Arie
---tambahan digital date: 06 Nov 2025
declare vdt_id default @vdt_id;
select 
a.dt_id dt_id,'3ID' brand,'Prepaid' as page
,b.circle
,b.region_circle region
,b.area area
,b.gladiator_branch branch,
kpi_code  kpi , 
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
'' addfield11,
sum(CASE 
            	WHEN lower(flag) = 'avg' THEN 
                       case 
                            when kpi_code in ('myim3_bima_dpu','myim3_bima_dpu_inflow','myim3_bima_dpu_base','myim3_bima_dau','myim3_bima_dau_inflow','myim3_bima_dau_base')
                                then round(metric / extract(day from dt_id))
                            else metric / extract(day from dt_id) 
                        end
                ELSE 
                    metric
                END) as values   
from 
`data-bi-prd-935c.bi_mart.digital_tracker_site`a left join `data-bi-prd-935c.bi_mart.ref_site_h3i` b on 
CASE WHEN LENGTH(a.site_id)<=5 THEN '0'||a.site_id  ELSE a.site_id  END = CASE WHEN LENGTH(b.site_id)<=5 THEN '0'||b.site_id ELSE b.site_id END
AND (
dt_id in (
  DATE_SUB(DATE_SUB(DATE_TRUNC(DATE(vdt_id), MONTH),INTERVAL 1 MONTH),INTERVAL 1 DAY),
  DATE_SUB(DATE_SUB(DATE_TRUNC(DATE(vdt_id), MONTH),INTERVAL 2 MONTH),INTERVAL 1 DAY),
  DATE_SUB(DATE_SUB(DATE_TRUNC(DATE(vdt_id), MONTH),INTERVAL 3 MONTH),INTERVAL 1 DAY),
  DATE_SUB(DATE_SUB(DATE_TRUNC(DATE(vdt_id), MONTH),INTERVAL 4 MONTH),INTERVAL 1 DAY),
  DATE_SUB(DATE_SUB(DATE_TRUNC(DATE(vdt_id), MONTH),INTERVAL 5 MONTH),INTERVAL 1 DAY),
  DATE_SUB(DATE_SUB(DATE_TRUNC(DATE(vdt_id), MONTH),INTERVAL 6 MONTH),INTERVAL 1 DAY),
  DATE_SUB(DATE_SUB(DATE_TRUNC(DATE(vdt_id), MONTH),INTERVAL 7 MONTH),INTERVAL 1 DAY),
  DATE_SUB(DATE_SUB(DATE_TRUNC(DATE(vdt_id), MONTH),INTERVAL 8 MONTH),INTERVAL 1 DAY),
  DATE_SUB(DATE_SUB(DATE_TRUNC(DATE(vdt_id), MONTH),INTERVAL 9 MONTH),INTERVAL 1 DAY))
	or  
  dt_id >= DATE_SUB(DATE_SUB(DATE_TRUNC(DATE(vdt_id), MONTH),INTERVAL 1 MONTH),INTERVAL 0 DAY)
)
group by 1,2,3,4,5,6,7,8 ,9,10,11,12,13,14,15,16,17,18,19