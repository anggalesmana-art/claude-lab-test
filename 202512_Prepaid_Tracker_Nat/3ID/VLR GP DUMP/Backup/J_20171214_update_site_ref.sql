declare vdt_id date default @vdt_id;

truncate table `data-bi-prd-935c.bi_stg.stg_site_ref_dim_3g`;
truncate table `data-bi-prd-935c.bi_stg.stg_site_ref_dim_2g`; 

INSERT INTO `data-bi-prd-935c.bi_stg.stg_site_ref_dim_3g`
SELECT 
  vdt_id AS mth_sk_id,
  CASE 
    WHEN LENGTH(UPPER(COALESCE(physical_site_id, sam_id, site_id))) < 6 
    THEN LPAD(UPPER(COALESCE(physical_site_id, sam_id, site_id)), 6, '0')
    ELSE UPPER(COALESCE(physical_site_id, sam_id, site_id))
  END AS site_id,
  CONCAT('CW', FORMAT_DATE('%V', DATE(vdt_id))) AS week,
  UPPER(physical_site_id) AS site_nominal_mapped,
  UPPER(io_micro_cluster) AS microcluster,
  CONCAT(g_type, 'NE') AS system,
  UPPER(gladiator_branch) AS gladiator_branch,
  new_region,
  h3i_technical_branch,
  region_hcpt,
  kecamatan,
  province,
  kabupaten,
  city_priority,
  lac,
  ci,
  latitude,
  longitude,
  ggsn_cellid_hexa AS egci,
  cell_number,
  enodebid,
  lac AS tac,
  mega_sow,
  physical_site_id AS site_id_original,
  sam_id,
  'NDB Data Source' AS remarks,
  CURRENT_TIMESTAMP() AS load_timestamp
FROM 
  `data-dtptechm-prd-c7ca.dwh.master_3g_cell_id`
WHERE 
  curr_ind = 'Y';

INSERT INTO `data-bi-prd-935c.bi_stg.stg_site_ref_dim_2g`
SELECT 
  DATE_TRUNC(vdt_id, month) AS mth_sk_id,
  CASE 
    WHEN LENGTH(UPPER(COALESCE(physical_site_id, sam_id, site_id))) < 6 
    THEN LPAD(UPPER(COALESCE(physical_site_id, sam_id, site_id)), 6, '0')
    ELSE UPPER(COALESCE(physical_site_id, sam_id, site_id))
  END AS site_id,
  CONCAT('CW', FORMAT_DATE('%V', DATE(vdt_id))) AS week,
  UPPER(physical_site_id) AS site_nominal_mapped,
  UPPER(io_micro_cluster) AS microcluster,
  CONCAT(g_type, 'NE') AS system,
  UPPER(gladiator_branch) AS gladiator_branch,
  new_region,
  h3i_technical_branch,
  region_hcpt,
  kecamatan,
  province,
  kabupaten,
  city_priority,
  lac,
  ci,
  latitude,
  longitude,
  ggsn_cellid_hexa AS egci,
  cell_number,
  enodebid,
  lac AS tac,
  mega_sow,
  physical_site_id AS site_id_original,
  sam_id,
  'NDB Data Source' AS remarks,
  CURRENT_TIMESTAMP() AS load_timestamp
FROM 
  `data-dtptechm-prd-c7ca.dwh.master_2g_cell_id`
WHERE 
  curr_ind = 'Y';

truncate table `data-bi-prd-935c.bi_stg.site_ref_dim_prep`;

INSERT INTO `data-bi-prd-935c.bi_stg.site_ref_dim_prep`
(
  mth_sk_id,
  site_id,
  week,
  site_nominal_mapped,
  microcluster,
  remarks,
  system,
  gladiator_branch,
  new_region,
  h3i_technical_branch,
  region_hcpt,
  kecamatan,
  province,
  kabupaten,
  city_priority,
  lac,
  ci,
  latitude,
  longitude,
  egci,
  cell_number,
  enodebid,
  tac,
  mega_sow,
  site_id_original,
  sam_id,
  ts
)
SELECT 
  vdt_id AS mth_sk_id,
  site_id,
  week,
  site_nominal_mapped,
  microcluster,
  CONCAT('From `data-bi-prd-935c.bi_mart.ndb` ', FORMAT_DATE('%b %y', DATE(CAST(vdt_id AS STRING)))) AS remarks,
  system,
  gladiator_branch,
  new_region,
  h3i_technical_branch,
  region_hcpt,
  kecamatan,
  province,
  kabupaten,
  city_priority,
  lac,
  ci,
  latitude,
  longitude,
  egci,
  cell_number AS cell_number,
  enodebid,
  tac,
  mega_sow,
  site_id_original,
  sam_id,
  CURRENT_TIMESTAMP() AS ts
FROM `data-bi-prd-935c.bi_stg.stg_site_ref_dim_3g`;


--truncate site_ref_dim_prep;
INSERT INTO `data-bi-prd-935c.bi_stg.site_ref_dim_prep`
(
  mth_sk_id,
  site_id,
  week,
  site_nominal_mapped,
  microcluster,
  remarks,
  system,
  gladiator_branch,
  new_region,
  h3i_technical_branch,
  region_hcpt,
  kecamatan,
  province,
  kabupaten,
  city_priority,
  lac,
  ci,
  latitude,
  longitude,
  egci,
  cell_number,
  enodebid,
  tac,
  mega_sow,
  site_id_original,
  sam_id,
  ts
)
SELECT 
  vdt_id AS mth_sk_id,
  site_id,
  week,
  site_nominal_mapped,
  microcluster,
  CONCAT('From `data-bi-prd-935c.bi_mart.ndb ', FORMAT_DATE('%b %y', DATE(CAST(vdt_id AS STRING))), '`') AS remarks,
  system,
  gladiator_branch,
  new_region,
  h3i_technical_branch,
  region_hcpt,
  kecamatan,
  province,
  kabupaten,
  city_priority,
  lac,
  ci,
  latitude,
  longitude,
  egci,
  cell_number AS cell_number,
  enodebid,
  tac,
  mega_sow,
  site_id_original,
  sam_id,
  CURRENT_TIMESTAMP() AS ts
FROM `data-bi-prd-935c.bi_stg.stg_site_ref_dim_2g`;



drop table `data-bi-prd-935c.bi_stg.site_ref_dim_prep_1`;
create table `data-bi-prd-935c.bi_stg.site_ref_dim_prep_1` as
select * from `data-bi-prd-935c.bi_mart.site_ref_dim` where mth_sk_id = (select max(mth_sk_id) from `data-bi-prd-935c.bi_mart.site_ref_dim`);

drop table `data-bi-prd-935c.bi_stg.site_ref_dim_prep_2`;
create table `data-bi-prd-935c.bi_stg.site_ref_dim_prep_2` as
select 
vdt_id as mth_sk_id,
"week",
egci,
site_id,
longitude,
latitude,
ci,
lac,
city_priority,
kabupaten,
province,
kecamatan,
region_hcpt,
h3i_technical_branch,
new_region,
gladiator_branch,
"system",
sam_id,
microcluster,
site_nominal_mapped,
mega_sow,
tac,
enodebid,
cell_number,
site_id_original,
remarks,
ts
from `data-bi-prd-935c.bi_stg.site_ref_dim_prep_1` where egci not in (select egci from `data-bi-prd-935c.bi_stg.site_ref_dim_prep` group by 1);

insert into `data-bi-prd-935c.bi_stg.site_ref_dim_prep`
select * from `data-bi-prd-935c.bi_stg.site_ref_dim_prep_2`;

drop table `data-bi-prd-935c.bi_mart.stg_site_ref_1`;

CREATE TABLE `data-bi-prd-935c.bi_mart.stg_site_ref_1` AS 
SELECT
  mth_sk_id,
  week,
  egci,
  site_id,
  longitude,
  latitude,
  ci,
  lac,
  city_priority,
  kabupaten,
  province,
  kecamatan,
  region_hcpt,
  h3i_technical_branch,
  new_region,
  gladiator_branch,
  `system`,
  sam_id,
  microcluster,
  site_nominal_mapped,
  mega_sow,
  tac,
  enodebid,
  cell_number,
  site_id_original,
  remarks,
  CURRENT_TIMESTAMP() AS ts
FROM (
  SELECT
    a.mth_sk_id,
    a.week,
    a.egci,
    a.site_id,
    a.longitude,
    a.latitude,
    a.ci,
    a.lac,
    COALESCE(b.kabkot_nm, a.city_priority) AS city_priority,
    COALESCE(b.kabkot_nm, a.kabupaten) AS kabupaten,
    COALESCE(b.provinsi_nm, a.province) AS province,
    COALESCE(b.kecamatan_nm, a.kecamatan) AS kecamatan,
    COALESCE(b.region, a.region_hcpt) AS region_hcpt,
    COALESCE(b.gladiator_branch, a.h3i_technical_branch) AS h3i_technical_branch,
    COALESCE(b.region, a.new_region) AS new_region,
    COALESCE(b.gladiator_branch, a.gladiator_branch) AS gladiator_branch,
    a.`system`,
    a.sam_id,
    a.microcluster,
    a.site_nominal_mapped,
    a.mega_sow,
    a.tac,
    a.enodebid,
    a.cell_number,
    a.site_id_original,
    a.remarks,
    a.ts,
    ROW_NUMBER() OVER (PARTITION BY a.egci) AS rn
  FROM 
    `data-bi-prd-935c.bi_stg.site_ref_dim_prep` a 
  LEFT JOIN (
    SELECT 
      site_id,
      kabkot_nm,
      provinsi_nm,
      kecamatan_nm,
      region,
      gladiator_branch 
    FROM (
      SELECT
        *,
        ROW_NUMBER() OVER (PARTITION BY site_id) AS rn
      FROM 
        `data-bi-prd-935c.bi_mart.ref_site_h3i_mth`
      GROUP BY 1, 2, 3, 4, 5, 6
    ) AS a
    WHERE rn = 1
  ) AS b ON a.site_id = b.site_id
) AS a
WHERE rn = 1;

insert into `data-bi-prd-935c.bi_mart.site_ref_dim`
select * from `data-bi-prd-935c.bi_mart.stg_site_ref_1`;