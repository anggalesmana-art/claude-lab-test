DECLARE vdt_id DATE DEFAULT @vdt_id;

delete from `data-bi-prd-935c.bi_mart.ioh_site_dim` where dt_sk_id = vdt_id;

insert into `data-bi-prd-935c.bi_mart.ioh_site_dim`
select 
cast(vdt_id as date) as dt_sk_id,
aa.site_id,
aa.longitude,
aa.latitude,
kecamatan,
kabupaten,
city_priority,
gladiator_branch,
region_hcpt, 
new_region,
current_datetime() as created_dtm
from
(
 select 
 row_number()over(partition by site_id order by created_dtm desc) as seqno,
 a.*
 from
 (
  select distinct sam_id as site_id,
  longitude, latitude, upper(kecamatan) kecamatan, upper(kabupaten) as kabupaten, upper(city_priority) as city_priority, gladiator_branch, region_hcpt, new_region, created_dtm
  from `data-dtptechm-prd-c7ca.dwh.master_3g_cell_id`

  union all
  
  select distinct sam_id as site_id, longitude, latitude, upper(kecamatan) kecamatan, upper(kabupaten) as kabupaten, upper(city_priority) as city_priority, gladiator_branch, region_hcpt, new_region, created_dtm
  from `data-dtptechm-prd-c7ca.dwh.master_2g_cell_id`
 ) a
) aa
where seqno = 1;
