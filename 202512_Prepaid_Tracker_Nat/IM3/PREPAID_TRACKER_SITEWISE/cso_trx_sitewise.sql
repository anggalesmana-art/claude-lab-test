declare vdt_id date default @vdt_id;
-------------------KPI SITEWISE------------------
-------------------------------------------------

--CSO NUM
delete from `data-bi-prd-935c.bi_mart`.kpi_site_wise_dly  where kpi_id = 'SND067' and dt_id = vdt_id and brand = 'IM3';
insert into `data-bi-prd-935c.bi_mart`.kpi_site_wise_dly 
select 'cso_num' kpi_code,'IM3' brand,micro_cluster site_id,
count(distinct operator_id) metric,current_datetime('+7') process_dt,'SND067' kpi_id,dt_id
from (
select dt_id,micro_cluster,operator_id
from `data-bi-prd-935c.bi_mart`.track_cso_dly_mobo
where dt_id=vdt_id and amt>=50000
union all
select dt_id,micro_cluster,operator_id
from `data-bi-prd-935c.bi_mart`.track_cso_dly_mobii
where dt_id=vdt_id
) a
group by 1,2,3,5,6,7;

--CSO OUTLET
delete from `data-bi-prd-935c.bi_mart`.kpi_site_wise_dly  where kpi_id = 'SND068' and dt_id = vdt_id and brand = 'IM3';
insert into `data-bi-prd-935c.bi_mart`.kpi_site_wise_dly 
select 'cso_num_outlet' kpi_code,'IM3' brand,micro_cluster site_id,
count(distinct organization_id) metric,current_datetime('+7') process_dt,'SND068' kpi_id,dt_id
from (
select dt_id,micro_cluster,credit_party_id organization_id
from `data-bi-prd-935c.bi_mart`.track_cso_dly_mobo
where dt_id=vdt_id and amt>=50000
union all
select dt_id,micro_cluster,dest_saldomobo_id organization_id
from `data-bi-prd-935c.bi_mart`.track_cso_dly_mobii
where dt_id=vdt_id
) a
group by 1,2,3,5,6,7;

--CSO NUM MTD
delete from `data-bi-prd-935c.bi_mart`.kpi_site_wise_dly  where kpi_id = 'SND069' and dt_id = vdt_id and brand = 'IM3';
insert into `data-bi-prd-935c.bi_mart`.kpi_site_wise_dly 
select 'cso_num_mtd' kpi_code,'IM3' brand,micro_cluster site_id,
count(distinct operator_id) metric,current_datetime('+7') process_dt,'SND069' kpi_id,vdt_id dt_id
from (
select micro_cluster,operator_id
from `data-bi-prd-935c.bi_mart`.track_cso_dly_mobo
where dt_id between date_trunc(vdt_id,month) and vdt_id and amt>=50000
union all
select micro_cluster,operator_id
from `data-bi-prd-935c.bi_mart`.track_cso_dly_mobii
where dt_id between date_trunc(vdt_id,month) and vdt_id) a
group by 1,2,3,5,6,7;

