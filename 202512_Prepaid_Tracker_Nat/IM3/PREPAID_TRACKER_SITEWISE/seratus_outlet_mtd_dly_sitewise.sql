declare vdt_id date default @vdt_id;

delete from `data-bi-prd-935c.bi_mart`.kpi_site_wise_dly 
where dt_id = vdt_id and kpi_id in (
'SND021',
'SND025'
);



-------------------------------------------------
--------------- URO -----------------------------
-- Unique Recharging Outlet SITEWISE-------------
-------------------------------------------------
insert into `data-bi-prd-935c.bi_mart`.kpi_site_wise_dly
select 'ret_uro' kpi_code,'IM3' brand,site_id,sum(uro_dly) metric,current_datetime('+7') process_dt,'SND021' kpi_id,dt_id
from `data-bi-prd-935c.bi_mart`.seratus_uro_inject 
where dt_id = vdt_id and uro_dly>0
group by 1,2,3,5,6,7;

insert into `data-bi-prd-935c.bi_mart`.kpi_site_wise_dly  
select 'ret_uro_mtd' kpi_code,'IM3' brand,site_id,sum(uro_mtd) metric,current_datetime('+7') process_dt,'SND025' kpi_id,dt_id
from `data-bi-prd-935c.bi_mart`.seratus_uro_inject 
where dt_id = vdt_id and uro_mtd>0
group by 1,2,3,5,6,7;

--SITE WITH URO
-- insert into `data-bi-prd-935c.bi_mart`.kpi_site_wise_dly  
-- select 'site_uro' kpi_code,'IM3' brand,a.site_id,count(a.site_id) metric,current_datetime('+7') process_dt,'SITE019' kpi_id,dt_id
-- from `data-bi-prd-935c.bi_dm`.ds_total_site_mth a
-- join (select dt_id,site_id,uro_mtd from `data-bi-prd-935c.bi_mart`.seratus_uro_inject
-- where dt_id=vdt_id and uro_mtd>0) b on a.site_id=b.site_id
-- where month_id=substr(vdt_id,1,6) and addressable_flag = 'ADDRESSABLE SITE'
-- and upper(a.ads_nbs)='YES'
-- group by 1,2,3,5,6,7; ds_total_site_mth not available in gcp, this must be active