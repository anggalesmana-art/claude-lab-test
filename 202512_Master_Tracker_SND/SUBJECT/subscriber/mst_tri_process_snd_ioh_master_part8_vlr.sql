declare vdt_id date default @vdt_id;

delete from  `data-bi-prd-935c.bi_mart`.vlr_subs_smy where dt_id = vdt_id;

insert into  `data-bi-prd-935c.bi_mart`.vlr_subs_smy 
select vdt_id dt_id 
,'3ID' brand
,'Prepaid' as page
,circle
,region_circle region
,area
,gladiator_branch branch
,'vlr_subs' as kpi 
,  sum(subs) /cast(right(cast(vdt_id as string),2) as integer)
  From 
`data-bi-prd-935c.bi_mart`.vlr_site_activity  a left join `data-bi-prd-935c.bi_mart`.ref_site_h3i b on 
CASE WHEN LENGTH(a.site_id)<=5 THEN '0'||a.site_id ELSE a.site_id END = CASE WHEN LENGTH(b.site_id)<=5 THEN '0'||b.site_id ELSE b.site_id END
where dt_id between 
date_trunc(vdt_id,month)
and vdt_id 
and dt_id not in ('2024-01-01','2024-01-02','2024-01-20','2024-01-28')
group by 1,2,3,4,5,6,7,8
union all 

select vdt_id
,'3ID' brand
,'Prepaid' as page
,circle
,region_circle region
,area
,gladiator_branch branch
,case when tenure='a.<=90D' then 'vlr_subs_less_90d' 
when tenure='b.91D - 180D' then 'vlr_subs_90d_180d' 
when tenure='c.>=181D' then 'vlr_subs_more_180d' 
end as kpi 
,  sum(subs) /cast(right(cast(vdt_id as string),2) as integer)
  From 
`data-bi-prd-935c.bi_mart`.vlr_site_activity  a left join `data-bi-prd-935c.bi_mart`.ref_site_h3i b on 
CASE WHEN LENGTH(a.site_id)<=5 THEN '0'||a.site_id ELSE a.site_id END = CASE WHEN LENGTH(b.site_id)<=5 THEN '0'||b.site_id ELSE b.site_id END
where dt_id between 
date_trunc(vdt_id,month)
and vdt_id 
and dt_id not in ('2024-01-01','2024-01-02','2024-01-20','2024-01-28')
group by 1,2,3,4,5,6,7,8
union all 

select vdt_id
,'3ID' brand
,'Prepaid' as page
,circle
,region_circle region
,area
,gladiator_branch branch
,case when flag ='No Activity' then 'vlr_subs_wo_act' else 'vlr_subs_act' end  kpi 
,  sum(subs) /cast(right(cast(vdt_id as string),2) as integer)
  From 
`data-bi-prd-935c.bi_mart`.vlr_site_activity  a left join `data-bi-prd-935c.bi_mart`.ref_site_h3i b on 
CASE WHEN LENGTH(a.site_id)<=5 THEN '0'||a.site_id ELSE a.site_id END = CASE WHEN LENGTH(b.site_id)<=5 THEN '0'||b.site_id ELSE b.site_id END
where dt_id between 
date_trunc(vdt_id,month)
and vdt_id 
and dt_id not in ('2024-01-01','2024-01-02','2024-01-20','2024-01-28')
group by 1,2,3,4,5,6,7,8;                                                                                                                                       

