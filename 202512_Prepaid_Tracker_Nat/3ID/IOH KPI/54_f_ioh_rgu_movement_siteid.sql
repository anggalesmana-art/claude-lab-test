declare vdt_id date default @vdt_id;

truncate table `data-bi-prd-935c.bi_stg.fct_site_attribs_rolling_90`;

INSERT INTO `data-bi-prd-935c.bi_stg.fct_site_attribs_rolling_90`
-- create table `data-bi-prd-935c.bi_stg.fct_site_attribs_rolling_90` as
SELECT *
FROM (
    SELECT 
        cast(vdt_id as date) AS dt,
        sbscrptn_ek_id,
        site_id_90 AS site_id,
        ROW_NUMBER() OVER (PARTITION BY sbscrptn_ek_id ORDER BY dt DESC) AS rown
    FROM `data-bi-prd-935c.bi_mart.ioh_subscriber_site_attribs_rolling`
    WHERE dt BETWEEN DATE_SUB(vdt_id,INTERVAL 90 day)
        AND vdt_id
) x
WHERE rown = 1;

truncate table `data-bi-prd-935c.bi_stg.fct_site_attribs_rolling_30`;

insert into `data-bi-prd-935c.bi_stg.fct_site_attribs_rolling_30`

-- create table `data-bi-prd-935c.bi_stg.fct_site_attribs_rolling_30` as
select * from 
(
 SELECT vdt_id as dt, sbscrptn_ek_id, site_id_30 as site_id, row_number () over (partition by sbscrptn_ek_id order by dt desc) rown
 FROM `data-bi-prd-935c.bi_mart.ioh_subscriber_site_attribs_rolling`
  WHERE  dt BETWEEN DATE_SUB(vdt_id,INTERVAL 30 day)
    AND vdt_id 
) x where rown = 1;
-- why truncate insert ??
truncate table `data-bi-prd-935c.bi_mart.fct_ioh_rgu_movement_siteid`;

--Opening

INSERT INTO `data-bi-prd-935c.bi_mart.fct_ioh_rgu_movement_siteid`
SELECT 
    DATE_SUB(a.load_dt_sk_id, INTERVAL 1 DAY) AS dt,
    'rgu30' AS tag,
    'Opening' AS tag2,
    site_id,
    cast(SUM(value) as INT64) AS subs
FROM `data-bi-prd-935c.bi_mart.project_ioh_kpi_daily_tracker_site` a
WHERE kpi_code IN ('rgu30_closing_base') 
    AND date(a.load_dt_sk_id) = DATE_SUB(vdt_id, INTERVAL 1 DAY)
GROUP BY 1, 2, 3, 4;

--Gross Add

INSERT INTO `data-bi-prd-935c.bi_mart.fct_ioh_rgu_movement_siteid`
SELECT 
    a.ga_date AS dt,
    'rgu30' AS tag,
    'Gross Add' AS tag2,
    COALESCE(b.site_id_90, 'N/A') AS site_id,
    COUNT(DISTINCT a.sbscrptn_ek_id) AS subs
FROM `data-bi-prd-935c.bi_mart.project_ioh_fu_master_v2` a
LEFT JOIN (
    SELECT DISTINCT dt, sbscrptn_ek_id, site_id_90
    FROM `data-bi-prd-935c.bi_mart.ioh_subscriber_site_attribs_rolling`
    WHERE dt = vdt_id
) b ON a.ga_date = b.dt AND cast(a.sbscrptn_ek_id as string) = b.sbscrptn_ek_id
WHERE a.ga_date = vdt_id
--AND b.sbscrptn_ek_id IS NULL
GROUP BY 1, 2, 3, 4;

--Gross Churn

INSERT INTO `data-bi-prd-935c.bi_mart.fct_ioh_rgu_movement_siteid`
SELECT 
    a.dt AS dt,
    'rgu30' AS tag,
    'Gross Churn' AS tag2,
    COALESCE(b.site_id, 'N/A') AS site_id,
    COUNT(DISTINCT a.sbscrptn_ek_id) AS subs
FROM `data-bi-prd-935c.bi_mart.fct_ioh_rgu_nik_movement` a
LEFT JOIN (
    SELECT 
        distinct cast(vdt_id as date) AS dt,
        sbscrptn_ek_id,
        site_id_30 AS site_id
    FROM `data-bi-prd-935c.bi_mart.ioh_subscriber_site_attribs_rolling`
    WHERE dt = DATE_SUB(vdt_id, INTERVAL 30 DAY)
) b ON a.dt = b.dt AND cast(a.sbscrptn_ek_id as string)= b.sbscrptn_ek_id
WHERE a.tag = 'rgu30_gross_churn' AND a.dt = vdt_id --AND b.sbscrptn_ek_id IS NULL
GROUP BY 1, 2, 3, 4;

--Churn Back

INSERT INTO `data-bi-prd-935c.bi_mart.fct_ioh_rgu_movement_siteid`
SELECT 
    a.dt,
    'rgu30' AS tag,
    'Churn Back' AS tag2,
    COALESCE(b.site_id_30, 'N/A') AS site_id,
    COUNT(DISTINCT a.sbscrptn_ek_id) AS subs
FROM `data-bi-prd-935c.bi_mart.fct_ioh_rgu_nik_movement` a
LEFT JOIN (
    SELECT DISTINCT 
        dt, 
        sbscrptn_ek_id, 
        site_id_30
    FROM `data-bi-prd-935c.bi_mart.ioh_subscriber_site_attribs_rolling`
    WHERE dt = vdt_id
) b ON a.dt = b.dt AND cast(a.sbscrptn_ek_id as string) = b.sbscrptn_ek_id
WHERE a.dt = vdt_id
  AND a.tag = 'rgu30_churn_back'
  --AND b.sbscrptn_ek_id is null
GROUP BY 1, 2, 3, 4;


--Closing

INSERT INTO `data-bi-prd-935c.bi_mart.fct_ioh_rgu_movement_siteid`
SELECT 
    cast(a.dt as date) as dt,
    a.tag, 
    'Closing' AS tag2,
    COALESCE(b.site_id, 'N/A') AS site_id,
    COUNT(DISTINCT a.sbscrptn_ek_id) AS subs
FROM `data-bi-prd-935c.bi_mart.fct_rgu_ioh_nik_mstr` a
LEFT JOIN (
    SELECT DISTINCT 
        cast(dt as date) as dt, 
        sbscrptn_ek_id, 
        site_id
    FROM `data-bi-prd-935c.bi_stg.fct_site_attribs_rolling_30`
    WHERE dt = vdt_id
) b ON a.dt = b.dt AND cast(a.sbscrptn_ek_id as string) = b.sbscrptn_ek_id
WHERE a.tag = 'rgu30' 
  AND a.dt = vdt_id
  --AND b.sbscrptn_ek_id IS NULL
GROUP BY 1, 2, 3, 4;


--#####
--RGU90
--#####

--Opening

INSERT INTO `data-bi-prd-935c.bi_mart.fct_ioh_rgu_movement_siteid`
SELECT 
    DATE_ADD(CAST(a.load_dt_sk_id AS DATE), INTERVAL 1 DAY) AS dt,
    'rgu90' AS tag, 
    'Opening' AS tag2,
    a.site_id,
    cast(SUM(a.value) as INT64) AS subs
FROM `data-bi-prd-935c.bi_mart.project_ioh_kpi_daily_tracker_site` a
WHERE a.kpi_code = 'rgu90_closing_base' 
  AND cast(a.load_dt_sk_id as date) = DATE_SUB(vdt_id, INTERVAL 1 DAY)
GROUP BY 1, 2, 3, 4;

--Gross Add

INSERT INTO `data-bi-prd-935c.bi_mart.fct_ioh_rgu_movement_siteid`
SELECT 
    cast(a.ga_date as date) AS dt, 
    'rgu90' AS tag, 
    'Gross Add' AS tag2,
    COALESCE(b.site_id_90, 'N/A') AS site_id,
    COUNT(DISTINCT a.sbscrptn_ek_id) AS subs
FROM `data-bi-prd-935c.bi_mart.project_ioh_fu_master_v2` a
LEFT JOIN (
    SELECT DISTINCT dt, sbscrptn_ek_id, site_id_90
    FROM `data-bi-prd-935c.bi_mart.ioh_subscriber_site_attribs_rolling`
    WHERE dt = CAST(vdt_id AS date)
) b ON a.ga_date = b.dt AND cast(a.sbscrptn_ek_id as string) = b.sbscrptn_ek_id
WHERE a.ga_date = CAST(vdt_id AS date)
--AND b.sbscrptn_ek_id IS NULL
GROUP BY 1, 2, 3, 4;

--Gross Churn

INSERT INTO `data-bi-prd-935c.bi_mart.fct_ioh_rgu_movement_siteid`
SELECT 
    cast(a.dt as date) AS dt, 
    'rgu90' AS tag, 
    'Gross Churn' AS tag2,
    COALESCE(b.site_id, 'N/A') AS site_id,
    COUNT(DISTINCT a.sbscrptn_ek_id) AS subs
FROM `data-bi-prd-935c.bi_mart.fct_ioh_rgu_nik_movement` a
LEFT JOIN (
    SELECT DISTINCT 
        --DATE_SUB(vdt_id, INTERVAL 90 DAY) AS dt, 
        cast(vdt_id as date) as dt,
        sbscrptn_ek_id, 
        site_id_90 AS site_id
    FROM `data-bi-prd-935c.bi_mart.ioh_subscriber_site_attribs_rolling`
    WHERE dt = DATE_SUB(vdt_id, INTERVAL 90 DAY)
) b ON a.dt = b.dt AND cast(a.sbscrptn_ek_id as string) = b.sbscrptn_ek_id
WHERE a.tag = 'rgu90_gross_churn' AND a.dt = vdt_id
--AND b.sbscrptn_ek_id IS NULL
GROUP BY 1, 2, 3, 4;

--Churn Back

INSERT INTO `data-bi-prd-935c.bi_mart.fct_ioh_rgu_movement_siteid`
SELECT 
    a.dt,
    'rgu90' AS tag, 
    'Churn Back' AS tag2,
    COALESCE(b.site_id_90, 'N/A') AS site_id,
    COUNT(DISTINCT a.sbscrptn_ek_id) AS subs
FROM `data-bi-prd-935c.bi_mart.fct_ioh_rgu_nik_movement` a
LEFT JOIN (
    SELECT DISTINCT 
         cast(vdt_id AS date) AS dt, 
        sbscrptn_ek_id, 
        site_id_90
    FROM `data-bi-prd-935c.bi_mart.ioh_subscriber_site_attribs_rolling`
    WHERE dt =  vdt_id
) b ON a.dt = b.dt AND cast(a.sbscrptn_ek_id as string)= b.sbscrptn_ek_id
WHERE a.dt = vdt_id
  AND a.tag = 'rgu90_churn_back'
  --AND b.sbscrptn_ek_id IS NULL
GROUP BY 1, 2, 3, 4;

--Closing


INSERT INTO `data-bi-prd-935c.bi_mart.fct_ioh_rgu_movement_siteid`
SELECT 
    cast(a.dt as date),
    a.tag,
    'Closing' AS tag2,
    COALESCE(b.site_id, 'N/A') AS site_id,
    COUNT(DISTINCT a.sbscrptn_ek_id) AS subs
FROM `data-bi-prd-935c.bi_mart.fct_rgu_ioh_nik_mstr` a
LEFT JOIN (
    SELECT DISTINCT 
        cast(dt as date) as dt, 
        sbscrptn_ek_id, 
        site_id
    FROM `data-bi-prd-935c.bi_stg.fct_site_attribs_rolling_90` 
    WHERE dt = vdt_id
) b ON a.dt = b.dt AND cast(a.sbscrptn_ek_id as string) = b.sbscrptn_ek_id
WHERE a.tag = 'rgu90' 
  AND a.dt = vdt_id
  --AND b.sbscrptn_ek_id IS NULL
GROUP BY 1, 2, 3, 4;


--##
--Insert into project_ioh_kpi_daily_tracker_site
--##

--Gross Add

delete from `data-bi-prd-935c.bi_mart.project_ioh_kpi_daily_tracker_site` where load_dt_sk_id = vdt_id and kpi_code in
('rgu30_gross_add', 'rgu90_gross_add', 'rgu30_gross_churn', 'rgu90_gross_churn', 'rgu30_churn_back', 'rgu90_churn_back',
'rgu30_closing_base', 'rgu90_closing_base', 'rgu30_net_churn', 'rgu90_net_churn');


INSERT INTO `data-bi-prd-935c.bi_mart.project_ioh_kpi_daily_tracker_site`
SELECT 
    cast(dt as date) AS load_dt_sk_id, 
    'H3I' AS entity, 
    'rgu30_gross_add' AS kpi_code, 
    'IOH' AS definition, 
    CAST(dt AS DATE) AS date,
    site_id, 
    subs AS value, 
    'SITE ROLLING 30' AS remark 
    ,CURRENT_TIMESTAMP() AS created_dtm
FROM `data-bi-prd-935c.bi_mart.fct_ioh_rgu_movement_siteid`
WHERE tag = 'rgu30' 
  AND tag2 = 'Gross Add';


insert into `data-bi-prd-935c.bi_mart.project_ioh_kpi_daily_tracker_site`
select dt as load_dt_sk_id, 'H3I' as entity, 'rgu90_gross_add' as kpi_code, 'IOH' as definition, CAST(dt AS DATE) AS date,
site_id, subs as value, 'SITE ROLLING 90' as remark 
,CURRENT_TIMESTAMP() AS created_dtm
from `data-bi-prd-935c.bi_mart.fct_ioh_rgu_movement_siteid`
where tag in ('rgu90') and tag2 in ('Gross Add');


--Gross Churn

insert into `data-bi-prd-935c.bi_mart.project_ioh_kpi_daily_tracker_site`
select dt as load_dt_sk_id, 'H3I' as entity, 'rgu30_gross_churn' as kpi_code, 'IOH' as definition, CAST(dt AS DATE) AS date,
site_id, subs as value, 'SITE ROLLING 30' as remark, 
CURRENT_TIMESTAMP() AS created_dtm
from `data-bi-prd-935c.bi_mart.fct_ioh_rgu_movement_siteid`
where tag in ('rgu30') and tag2 in ('Gross Churn');

insert into `data-bi-prd-935c.bi_mart.project_ioh_kpi_daily_tracker_site`
select dt as load_dt_sk_id, 'H3I' as entity, 'rgu90_gross_churn' as kpi_code, 'IOH' as definition, CAST(dt AS DATE) AS date,
site_id, subs as value, 'SITE ROLLING 90' as remark, CURRENT_TIMESTAMP() AS created_dtm
from `data-bi-prd-935c.bi_mart.fct_ioh_rgu_movement_siteid`
where tag in ('rgu90') and tag2 in ('Gross Churn');

--Churn Back

insert into `data-bi-prd-935c.bi_mart.project_ioh_kpi_daily_tracker_site`
select dt as load_dt_sk_id, 'H3I' as entity, 'rgu30_churn_back' as kpi_code, 'IOH' as definition, CAST(dt AS DATE) AS date,
site_id, subs as value, 'SITE ROLLING 30' as remark, CURRENT_TIMESTAMP() AS created_dtm
from `data-bi-prd-935c.bi_mart.fct_ioh_rgu_movement_siteid`
where tag in ('rgu30') and tag2 in ('Churn Back');

insert into `data-bi-prd-935c.bi_mart.project_ioh_kpi_daily_tracker_site`
select dt as load_dt_sk_id, 'H3I' as entity, 'rgu90_churn_back' as kpi_code, 'IOH' as definition, CAST(dt AS DATE) AS date,
site_id, subs as value, 'SITE ROLLING 90' as remark, CURRENT_TIMESTAMP() AS created_dtm
from `data-bi-prd-935c.bi_mart.fct_ioh_rgu_movement_siteid`
where tag in ('rgu90') and tag2 in ('Churn Back');

--Closing

insert into `data-bi-prd-935c.bi_mart.project_ioh_kpi_daily_tracker_site`
select dt as load_dt_sk_id, 'H3I' as entity, 'rgu30_closing_base' as kpi_code, 'IOH' as definition, CAST(dt AS DATE) AS date,
site_id, subs as value, 'SITE ROLLING 30' as remark, CURRENT_TIMESTAMP() AS created_dtm
from `data-bi-prd-935c.bi_mart.fct_ioh_rgu_movement_siteid`
where tag in ('rgu30') and tag2 in ('Closing');


insert into `data-bi-prd-935c.bi_mart.project_ioh_kpi_daily_tracker_site`
select dt as load_dt_sk_id, 'H3I' as entity, 'rgu90_closing_base' as kpi_code, 'IOH' as definition, CAST(dt AS DATE) AS date,
site_id, subs as value, 'SITE ROLLING 90' as remark, CURRENT_TIMESTAMP() AS created_dtm
from `data-bi-prd-935c.bi_mart.fct_ioh_rgu_movement_siteid`
where tag in ('rgu90') and tag2 in ('Closing');

--Net Churn

insert into `data-bi-prd-935c.bi_mart.project_ioh_kpi_daily_tracker_site`
select load_dt_sk_id, entity, kpi_code, definition, date, site_id, SUM(value) as value, remark, CURRENT_TIMESTAMP() AS created_dtm
from
(
 select dt as load_dt_sk_id, 'H3I' as entity, 'rgu30_net_churn' as kpi_code, 'IOH' as definition, CAST(dt AS DATE) AS date,
 site_id, subs as value, 'SITE ROLLING 30' as remark
 from `data-bi-prd-935c.bi_mart.fct_ioh_rgu_movement_siteid`
 where tag in ('rgu30') and tag2 in ('Gross Churn')

 union all

 select dt as load_dt_sk_id, 'H3I' as entity, 'rgu30_net_churn' as kpi_code, 'IOH' as definition, CAST(dt AS DATE) AS date,
 site_id, (subs * -1) as value, 'SITE ROLLING 30' as remark
 from `data-bi-prd-935c.bi_mart.fct_ioh_rgu_movement_siteid`
 where tag in ('rgu30') and tag2 in ('Churn Back')
) a
group by 1,2,3,4,5,6,8;


insert into `data-bi-prd-935c.bi_mart.project_ioh_kpi_daily_tracker_site`
select load_dt_sk_id, entity, kpi_code, definition, date, site_id, SUM(value) as value, remark, CURRENT_TIMESTAMP() AS created_dtm
from
(
 select dt as load_dt_sk_id, 'H3I' as entity, 'rgu90_net_churn' as kpi_code, 'IOH' as definition, CAST(dt AS DATE) AS date,
 site_id, subs as value, 'SITE ROLLING 90' as remark
 from `data-bi-prd-935c.bi_mart.fct_ioh_rgu_movement_siteid`
 where tag in ('rgu90') and tag2 in ('Gross Churn')

 union all

 select dt as load_dt_sk_id, 'H3I' as entity, 'rgu90_net_churn' as kpi_code, 'IOH' as definition, CAST(dt AS DATE) AS date,
 site_id, (subs * -1) as value, 'SITE ROLLING 90' as remark
 from `data-bi-prd-935c.bi_mart.fct_ioh_rgu_movement_siteid`
 where tag in ('rgu90') and tag2 in ('Churn Back')
) a
group by 1,2,3,4,5,6,8;



--Load the GA with Site_ID

delete from `data-bi-prd-935c.bi_mart.fct_ga_site_id` where dt = vdt_id;

INSERT INTO `data-bi-prd-935c.bi_mart.fct_ga_site_id`
SELECT DISTINCT 
    a.ga_date AS dt, 
    cast(a.sbscrptn_ek_id as string), 
    COALESCE(site_id_90, 'N/A') AS site_id
FROM `data-bi-prd-935c.bi_mart.project_ioh_fu_master_v2` a
LEFT JOIN
(
    SELECT DISTINCT dt, sbscrptn_ek_id, site_id_90
    FROM `data-bi-prd-935c.bi_mart.ioh_subscriber_site_attribs_rolling`
    WHERE dt = vdt_id
) b 
ON a.ga_date = b.dt AND cast(a.sbscrptn_ek_id as string) = b.sbscrptn_ek_id
WHERE a.ga_date = vdt_id
--AND b.sbscrptn_ek_id IS NULL
;

--383
drop table if exists `data-bi-prd-935c.bi_stg.tmp_rgs30_movement`;

CREATE TABLE `data-bi-prd-935c.bi_stg.tmp_rgs30_movement` AS
SELECT load_dt_sk_id, tag, COUNT(DISTINCT a.sbscrptn_ek_id) AS subs
FROM (
    -- First part: 'rgu30_opening'
    SELECT DISTINCT CAST(vdt_id AS date) AS load_dt_sk_id, 
           'rgu30_opening' AS tag, 
           a.sbscrptn_ek_id
    FROM `data-bi-prd-935c.bi_mart.fct_rgu_ioh_nik_mstr` a
    WHERE tag = 'rgu30' 
      AND dt = DATE_SUB(vdt_id, INTERVAL 1 DAY)

    UNION distinct

    -- Second part: Conditional tag logic for 'rgu30_gross_add', 'rgu30_churn_back'
    SELECT DISTINCT dt AS load_dt_sk_id,
           CASE
               WHEN e.sbscrptn_ek_id IS NOT NULL THEN 'rgu30_gross_add'
               ELSE 
                   CASE 
                       WHEN a.fu_dt = cast(vdt_id as date) THEN 
                           CASE 
                               WHEN c.sbscrptn_ek_id IS NULL THEN 
                                   CASE 
                                       WHEN f.sbscrptn_ek_id IS NULL THEN 'rgu30_gross_add'
                                       ELSE 'rgu30_churn_back'
                                   END
                               ELSE 'rgu30_churn_back' 
                           END
                       ELSE 'rgu30_churn_back'
                   END
           END AS tag,
           a.sbscrptn_ek_id
    FROM (
        SELECT DISTINCT a.dt, a.sbscrptn_ek_id,
               CASE 
                   WHEN b.sbscrptn_ek_id IS NOT NULL THEN b.first_rgs_date -- RITA adjustment
                   ELSE a.first_usage_dt 
               END AS fu_dt
        FROM `data-bi-prd-935c.bi_mart.fct_rgu_ioh_nik_mstr` a
        LEFT OUTER JOIN `data-bi-prd-935c.bi_mart.project_ioh_rita_adjustment_detail` b  
            ON cast(a.sbscrptn_ek_id as string) = cast(b.sbscrptn_ek_id as string)
        WHERE a.tag = 'rgu30' 
          AND dt = vdt_id 
    ) a
    LEFT OUTER JOIN (
        SELECT DISTINCT sbscrptn_ek_id
        FROM `data-bi-prd-935c.bi_mart.fct_rgu_ioh_nik_mstr` a
        WHERE tag = 'rgu30' 
          AND dt = DATE_SUB(vdt_id, INTERVAL 1 DAY)
    ) b ON cast(a.sbscrptn_ek_id as string) = cast(b.sbscrptn_ek_id as string)
    LEFT OUTER JOIN (
        SELECT DISTINCT sbscrptn_ek_id
        FROM `data-bi-prd-935c.bi_mart.fct_rgu_ioh_nik_mstr` a
        WHERE tag = 'rgu90' 
          AND dt = DATE_SUB(vdt_id, INTERVAL 1 DAY)
    ) c ON cast(a.sbscrptn_ek_id as string) = cast(c.sbscrptn_ek_id as string)
    LEFT OUTER JOIN `data-bi-prd-935c.bi_mart.project_ioh_fu_master_v2` d 
        ON cast(a.sbscrptn_ek_id as string) = cast(d.sbscrptn_ek_id as string)
        AND d.ga_date IS NULL
        AND d.tag <> 'New-RGU'
    LEFT OUTER JOIN `data-bi-prd-935c.bi_mart.project_ioh_fu_master_v2` e 
        ON cast(a.sbscrptn_ek_id as string) = cast(e.sbscrptn_ek_id as string)
        AND e.ga_date = vdt_id 
        AND e.tag = 'New-RGU'
    LEFT OUTER JOIN `data-bi-prd-935c.bi_mart.project_ioh_fu_master_v2` f 
        ON cast(a.sbscrptn_ek_id as string) = cast(f.sbscrptn_ek_id as string)
        AND f.ga_date IS NOT NULL
    WHERE b.sbscrptn_ek_id IS NULL

    UNION distinct

    -- Third part: 'rgu30_gross_churn'
    SELECT DISTINCT CAST(vdt_id AS date) AS load_dt_sk_id,
           'rgu30_gross_churn' AS tag,
           a.sbscrptn_ek_id
    FROM `data-bi-prd-935c.bi_mart.fct_rgu_ioh_nik_mstr` a
    LEFT OUTER JOIN (
        SELECT DISTINCT sbscrptn_ek_id
        FROM `data-bi-prd-935c.bi_mart.fct_rgu_ioh_nik_mstr` a
        WHERE tag = 'rgu30' 
          AND dt = CAST(vdt_id AS date)
    ) b ON cast(a.sbscrptn_ek_id as string) = cast(b.sbscrptn_ek_id as string)
    WHERE tag = 'rgu30' 
      AND dt = DATE_SUB(CAST(vdt_id AS DATE), INTERVAL 1 DAY) 
      AND b.sbscrptn_ek_id IS NULL
) a
GROUP BY 1, 2;

delete from `data-bi-prd-935c.bi_mart.project_ioh_kpi_daily_tracker_site` where load_dt_sk_id = vdt_id and kpi_code = 'M2S_MTD';

insert into`data-bi-prd-935c.bi_mart.project_ioh_kpi_daily_tracker_site`
select cast(vdt_id as date) as laod_dt_sk_id, 'H3I' as entity, 'M2S_MTD' as kpi_code, 'IOH' as definition,
cast(vdt_id as date) as dt, b.site_id, count(distinct a.sbscrptn_ek_id) as value, 'SITE ROLLING 90' as remark, CURRENT_TIMESTAMP() as created_dtm
from 
(
 select distinct a.sbscrptn_ek_id
 from `data-bi-prd-935c.bi_mart.fct_rgu_ioh_nik_mstr` a
 where tag = 'rgu_daily'
 and dt >= date_trunc(vdt_id, MONTH)and dt <= vdt_id

 union distinct

 select distinct a.sbscrptn_ek_id
 from `data-bi-prd-935c.bi_mart.fct_ioh_rgu_daily_nik_add` a --changes start on 23 May 2022 (add the daily RGU from this table)
 where tag = 'rgu_daily'
 and dt >= date_trunc(vdt_id, MONTH) and dt <= vdt_id

) a
join 
(
 --Change start 01 Mar 2022 onwards
 select distinct sbscrptn_ek_id, site_id
 from `data-bi-prd-935c.bi_mart.fct_ga_site_id`
 where date_trunc(cast(dt as date), MONTH) = date_trunc(date_sub(cast(vdt_id as DATE), INTERVAL 2 MONTH), MONTH)
) b on cast(a.sbscrptn_ek_id as string) = cast(b.sbscrptn_ek_id as string)
group by 1,2,3,4,5,6,8,9;

delete from `data-bi-prd-935c.bi_mart.project_ioh_kpi_daily_tracker_site` where load_dt_sk_id = vdt_id and kpi_code = 'GA_M2S_MTD';

INSERT INTO `data-bi-prd-935c.bi_mart.project_ioh_kpi_daily_tracker_site`
SELECT cast(vdt_id as date) AS load_dt_sk_id,
       'H3I' AS entity,
       'GA_M2S_MTD' AS kpi_code,
       'IOH' AS definition,
       CAST(vdt_id AS DATE) AS dt,
       a.site_id,
       COUNT(DISTINCT a.sbscrptn_ek_id) AS value,
       'SITE ROLLING 90' AS remark,
       CURRENT_TIMESTAMP() AS created_dtm
FROM (
    SELECT DISTINCT sbscrptn_ek_id, site_id
    FROM `data-bi-prd-935c.bi_mart.fct_ga_site_id`
    WHERE date_trunc(dt, MONTH) = DATE_TRUNC(DATE_SUB(CAST(vdt_id as DATE), INTERVAL 2 MONTH), MONTH)
) a
GROUP BY load_dt_sk_id, entity, kpi_code, definition, dt, site_id, remark, created_dtm;

delete from `data-bi-prd-935c.bi_mart.project_ioh_kpi_daily_tracker_site` where load_Dt_sk_id = vdt_id and kpi_code in ('s_addr_qsso_lt3', 's_addr_qsso_0');
		
delete from `data-bi-prd-935c.bi_mart.dm_phy_addressable_sites_quro_val` where dt = vdt_id;

INSERT INTO `data-bi-prd-935c.bi_mart.dm_phy_addressable_sites_quro_val`
SELECT cast(vdt_id as date) AS dt,
       oldsiteid,
       newsiteid,
       cast(SUM(COALESCE(value, 0)) as numeric) AS value
FROM (
    SELECT CASE 
               WHEN LENGTH(a.oldsiteid) < 6 THEN LPAD(a.oldsiteid, 6, '0') 
               ELSE a.oldsiteid 
           END AS oldsiteid,
           CASE 
               WHEN LENGTH(a.newsiteid) < 6 THEN LPAD(a.newsiteid, 6, '0') 
               ELSE a.newsiteid 
           END AS newsiteid
    FROM `data-bi-prd-935c.bi_mart.dm_phy_addressable_sites` a
    WHERE mth = (select max(mth) from `data-bi-prd-935c.bi_mart.dm_phy_addressable_sites`  
                    where mth <= DATE_TRUNC(DATE_SUB(vdt_id, INTERVAL 1 MONTH), MONTH))
      AND addressablesites = 'ADDRESSABLE SITE'
) a
LEFT JOIN (
    SELECT site_id, value
    FROM `data-bi-prd-935c.bi_mart.project_ioh_kpi_daily_tracker_site`
    WHERE kpi_code = 'qsso_any'
      AND load_dt_sk_id = vdt_id
) b ON b.site_id = a.oldsiteid OR b.site_id = a.newsiteid
GROUP BY dt, oldsiteid, newsiteid;

INSERT INTO `data-bi-prd-935c.bi_mart.project_ioh_kpi_daily_tracker_site`
SELECT cast(dt as date) AS dts,
       'H3I' AS entity,
       's_addr_qsso_lt3' AS kpi_code,
       'IOH' AS definition,
       CAST(dt AS DATE),
       CASE 
           WHEN LENGTH(siteid) < 6 THEN LPAD(siteid, 6, '0')
           ELSE siteid
       END AS site_id,
       SUM(value) AS cnt,
       'Site Addressable without QSSO' AS remark,
       CURRENT_TIMESTAMP() AS created_dtm
FROM (
    SELECT dt,
           CASE 
               WHEN value < 1 THEN '0'
               WHEN value < 3 THEN '1-2'
               ELSE '>3' 
           END AS flag,
           siteid,
           value
    FROM (
        SELECT dt,
               CASE 
                   WHEN newsiteid = '00000-' THEN oldsiteid
                   ELSE newsiteid 
               END AS siteid,
               SUM(COALESCE(value, 0)) AS value
        FROM `data-bi-prd-935c.bi_mart.dm_phy_addressable_sites_quro_val`
        WHERE dt = vdt_id
        GROUP BY dt, siteid
    ) AS x
) AS x
WHERE flag <> '>3'
GROUP BY dt, entity, kpi_code, definition, CAST(dt AS DATE), site_id, remark, created_dtm;

INSERT INTO `data-bi-prd-935c.bi_mart.project_ioh_kpi_daily_tracker_site`
SELECT cast(dt as date) AS dts,
       'H3I' AS entity,
       's_addr_qsso_0' AS kpi_code,
       'IOH' AS definition,
       CAST(dt AS DATE),
       CASE 
           WHEN LENGTH(siteid) < 6 THEN LPAD(siteid, 6, '0')
           ELSE siteid
       END AS site_id,
       SUM(value) AS cnt,
       'Site Addressable without QSSO' AS remark,
       CURRENT_TIMESTAMP() AS created_dtm
FROM (
    SELECT dt,
           CASE 
               WHEN value < 1 THEN '0'
               WHEN value < 3 THEN '1-2'
               ELSE '>3' 
           END AS flag,
           siteid,
           value
    FROM (
        SELECT dt,
               CASE 
                   WHEN newsiteid = '00000-' THEN oldsiteid
                   ELSE newsiteid 
               END AS siteid,
               SUM(COALESCE(value, 0)) AS value
        FROM `data-bi-prd-935c.bi_mart.dm_phy_addressable_sites_quro_val`
        WHERE dt = vdt_id
        GROUP BY dt, siteid
    ) AS x
) AS x
WHERE flag = '0'
GROUP BY dt, entity, kpi_code, definition, CAST(dt AS DATE), site_id, remark, created_dtm;

delete from `data-bi-prd-935c.bi_mart.project_ioh_kpi_daily_tracker_site` where load_dt_sk_id = vdt_id and kpi_code = 'FU_MTD';

INSERT INTO `data-bi-prd-935c.bi_mart.project_ioh_kpi_daily_tracker_site`
with subs as (select * from `data-dtptechm-prd-c7ca.dwh.sbscrptn_attribs`)
SELECT cast(vdt_id as date) AS load_dt_sk_id,
       'H3I' AS entity,
       'FU_MTD' AS kpi_code,
       'IOH' AS definition,
       CAST(vdt_id AS DATE),
       COALESCE(b.site_id_90, 'N/A') AS site_id,
       COUNT(DISTINCT a.sbscrptn_ek_id) AS value,
       'SITE ROLLING 90' AS remark,
       CURRENT_TIMESTAMP() AS created_dtm
FROM subs a
LEFT JOIN (
    SELECT DISTINCT dt, sbscrptn_ek_id, site_id_90
    FROM `data-bi-prd-935c.bi_mart.ioh_subscriber_site_attribs_rolling`
    WHERE dt BETWEEN DATE_TRUNC(vdt_id, MONTH) AND vdt_id
) b ON cast(a.sbscrptn_ek_id as string) = cast(b.sbscrptn_ek_id as string) 
   AND (
    SELECT MIN(d)
    FROM UNNEST([
      cast(first_usage_dt as date),
      safe.parse_date('%Y%m%d',cast(first_billing_usage_dt_sk_id as string)),
      cast(any_event_first_usage_date as date)
    ]) AS d
    WHERE d IS NOT NULL
  )  = b.dt
WHERE 
 (
    SELECT MIN(d)
    FROM UNNEST([
      cast(first_usage_dt as date),
      safe.parse_date('%Y%m%d',cast(first_billing_usage_dt_sk_id as string)),
      cast(any_event_first_usage_date as date)
    ]) AS d
    WHERE d IS NOT NULL
  )  >= DATE_TRUNC(vdt_id, MONTH)
AND 
 (
    SELECT MIN(d)
    FROM UNNEST([
      cast(first_usage_dt as date),
      safe.parse_date('%Y%m%d',cast(first_billing_usage_dt_sk_id as string)),
      cast(any_event_first_usage_date as date)
    ]) AS d
    WHERE d IS NOT NULL
  )  <= vdt_id
  AND a.tool_of_trade_ind = 'N'
  AND a.product_id = 8
  --AND b.sbscrptn_ek_id IS NULL
GROUP BY load_dt_sk_id, entity, kpi_code, definition, CAST(vdt_id AS DATE), site_id, remark, created_dtm;

delete from`data-bi-prd-935c.bi_mart.project_ioh_kpi_daily_tracker_site` where load_dt_sk_id = vdt_id and kpi_code = 'HV_FU_MTD';

INSERT INTO `data-bi-prd-935c.bi_mart.project_ioh_kpi_daily_tracker_site`
with subs as (select * from `data-dtptechm-prd-c7ca.dwh.sbscrptn_attribs`)
SELECT cast(vdt_id as date) AS load_dt_sk_id,
       'H3I' AS entity,
       'HV_FU_MTD' AS kpi_code,
       'IOH' AS definition,
       CAST(vdt_id AS DATE),
       COALESCE(b.site_id_90, 'N/A') AS site_id,
       COUNT(DISTINCT a.sbscrptn_ek_id) AS value,
       'SITE ROLLING 90' AS remark,
       CURRENT_TIMESTAMP() AS created_dtm
FROM subs a
LEFT JOIN (
    SELECT DISTINCT dt, sbscrptn_ek_id, site_id_90
    FROM `data-bi-prd-935c.bi_mart.ioh_subscriber_site_attribs_rolling`
    WHERE dt BETWEEN DATE_TRUNC(vdt_id, MONTH) AND vdt_id
) b ON cast(a.sbscrptn_ek_id as string) = cast(b.sbscrptn_ek_id as string) 
   AND  (
    SELECT MIN(d)
    FROM UNNEST([
      cast(first_usage_dt as date),
      safe.parse_date('%Y%m%d',cast(first_billing_usage_dt_sk_id as string)),
      cast(any_event_first_usage_date as date)
    ]) AS d
    WHERE d IS NOT NULL
  ) = b.dt
JOIN `data-bi-prd-935c.bi_mart.ref_callplan_hvc_mvc_lvc` c 
  ON UPPER(a.call_plan_desc) = UPPER(c.call_plan) 
 AND c.segment = 'HVC'
WHERE 
 (
    SELECT MIN(d)
    FROM UNNEST([
      cast(first_usage_dt as date),
      safe.parse_date('%Y%m%d',cast(first_billing_usage_dt_sk_id as string)),
      cast(any_event_first_usage_date as date)
    ]) AS d
    WHERE d IS NOT NULL
  )  >= DATE_TRUNC(vdt_id, MONTH)
AND
 (
    SELECT MIN(d)
    FROM UNNEST([
      cast(first_usage_dt as date),
      safe.parse_date('%Y%m%d',cast(first_billing_usage_dt_sk_id as string)),
      cast(any_event_first_usage_date as date)
    ]) AS d
    WHERE d IS NOT NULL
  ) <= vdt_id
  AND a.tool_of_trade_ind = 'N'
  AND a.product_id = 8
  --AND b.sbscrptn_ek_id IS NULL
GROUP BY load_dt_sk_id, entity, kpi_code, definition, CAST(vdt_id AS DATE), site_id, remark, created_dtm;


delete from `data-bi-prd-935c.bi_mart.project_ioh_kpi_daily_tracker_site` where load_dt_sk_id = vdt_id and kpi_code = 'HV_FU_MTD_LIST';

INSERT INTO `data-bi-prd-935c.bi_mart.project_ioh_kpi_daily_tracker_site`
with subs as (select * from `data-dtptechm-prd-c7ca.dwh.sbscrptn_attribs`)
SELECT cast(vdt_id as date) AS load_dt_sk_id,
       'H3I' AS entity,
       'HV_FU_MTD_LIST' AS kpi_code,
       'IOH' AS definition,
       CAST(vdt_id AS DATE),
       COALESCE(b.site_id_90, 'N/A') AS site_id,
       COUNT(DISTINCT a.sbscrptn_ek_id) AS value,
       'SITE ROLLING 90' AS remark,
       CURRENT_TIMESTAMP() AS created_dtm
FROM subs a
LEFT JOIN (
    SELECT DISTINCT dt, sbscrptn_ek_id, site_id_90
    FROM `data-bi-prd-935c.bi_mart.ioh_subscriber_site_attribs_rolling`
    WHERE dt BETWEEN DATE_TRUNC(vdt_id, MONTH) AND vdt_id
) b ON cast(a.sbscrptn_ek_id as string) = cast(b.sbscrptn_ek_id as string) 
   AND
    (
    SELECT MIN(d)
    FROM UNNEST([
      cast(first_usage_dt as date),
      safe.parse_date('%Y%m%d',cast(first_billing_usage_dt_sk_id as string)),
      cast(any_event_first_usage_date as date)
    ]) AS d
    WHERE d IS NOT NULL
  )  = b.dt
WHERE 
 (
    SELECT MIN(d)
    FROM UNNEST([
      cast(first_usage_dt as date),
      safe.parse_date('%Y%m%d',cast(first_billing_usage_dt_sk_id as string)),
      cast(any_event_first_usage_date as date)
    ]) AS d
    WHERE d IS NOT NULL
  )  >= DATE_TRUNC(vdt_id, MONTH)
AND
 (
    SELECT MIN(d)
    FROM UNNEST([
      cast(first_usage_dt as date),
      safe.parse_date('%Y%m%d',cast(first_billing_usage_dt_sk_id as string)),
      cast(any_event_first_usage_date as date)
    ]) AS d
    WHERE d IS NOT NULL
  )  <= vdt_id
  AND a.tool_of_trade_ind = 'N'
  AND a.product_id = 8
  --AND b.sbscrptn_ek_id IS NULL
  AND UPPER(a.promo_desc) IN (
       'SP HP52', 'SP HP9', 'SP-PMAX-4GB-2018', 'KEPO9', 'SP BM9X', 'SP HAPPY 52GB', 
       'AON22 SPECIAL', 'AON52 SPECIAL', 'HAPPY 7', 'MINI 1GB', 'SP MINI 1GB', 
       'SP_MINI 1GB C2028', 'SP BM3X', 'MINI 1GB C2028', 'SP-PMAX-4GB-2018', 
       'SP-PMAX-4GB', 'PACUAN MAX 4GB', 'SP HP52', 'SP HAPPY 52GB', 'PACUAN 4GB', 
       'PM22SP', 'SP BM9X', 'MINI 3GB', 'SP_MINI 3GB'
   )
GROUP BY load_dt_sk_id, entity, kpi_code, definition, CAST(vdt_id AS DATE), site_id, remark, created_dtm;

delete from `data-bi-prd-935c.bi_mart.project_ioh_kpi_daily_tracker_site` where load_dt_sk_id = vdt_id and kpi_code = 'DSF_M2S_MTD_RATE';

INSERT INTO `data-bi-prd-935c.bi_mart.project_ioh_kpi_daily_tracker_site`
SELECT cast(vdt_id as date) AS load_dt_sk_id,
       'H3I' AS entity,
       'DSF_M2S_MTD_RATE' AS kpi_code,
       'IOH' AS definition,
       CAST(vdt_id AS DATE) AS dt,
       b.site_id,
       SUM(CAST(a.value AS NUMERIC) / CAST(b.value AS NUMERIC)) AS value,
       'SITE ROLLING 90' AS remark,
       CURRENT_TIMESTAMP() AS created_dtm
FROM (
    SELECT b.site_id,
           COUNT(DISTINCT a.sbscrptn_ek_id) AS value
    FROM (
        SELECT DISTINCT sbscrptn_ek_id
        FROM `data-bi-prd-935c.bi_mart.fct_rgu_ioh_nik_mstr`
        WHERE tag = 'rgu_daily'
          AND dt BETWEEN DATE_TRUNC(vdt_id, MONTH) AND vdt_id

        UNION distinct

        SELECT DISTINCT sbscrptn_ek_id
        FROM `data-bi-prd-935c.bi_mart.fct_ioh_rgu_daily_nik_add` -- Added daily RGU from this table as of 23 May 2022
        WHERE tag = 'rgu_daily'
          AND dt BETWEEN DATE_TRUNC(vdt_id, MONTH) AND vdt_id

    ) a
    JOIN (
        SELECT DISTINCT sbscrptn_ek_id, site_id
        FROM `data-bi-prd-935c.bi_mart.fct_ga_site_id`
        WHERE SUBSTR(CAST(dt AS STRING), 1, 7) = SUBSTR(CAST(DATE_TRUNC(DATE_SUB(vdt_id,INTERVAL 2 MONTH), MONTH) as string),1 , 7)
    ) b ON cast(a.sbscrptn_ek_id as string) = cast(b.sbscrptn_ek_id as string)
    JOIN (
        with subs as (select * from `data-dtptechm-prd-c7ca.dwh.sbscrptn_attribs`)
        SELECT DISTINCT sbscrptn_ek_id
        FROM subs a
        JOIN `data-bi-prd-935c.bi_mart.dsf_reference_list` b ON a.angie_retailer_name = b.retailer_qrcode
    ) c ON cast(a.sbscrptn_ek_id as string) = cast(c.sbscrptn_ek_id as string)
    GROUP BY b.site_id
) a
LEFT JOIN (
    with subs as (select * from `data-dtptechm-prd-c7ca.dwh.sbscrptn_attribs`)
    SELECT a.site_id,
           COUNT(DISTINCT a.sbscrptn_ek_id) AS value
    FROM `data-bi-prd-935c.bi_mart.fct_ga_site_id` a
    JOIN (
        SELECT DISTINCT sbscrptn_ek_id
        FROM subs a
        JOIN `data-bi-prd-935c.bi_mart.dsf_reference_list` b ON a.angie_retailer_name = b.retailer_qrcode 
    ) b ON cast(a.sbscrptn_ek_id as string) = cast(b.sbscrptn_ek_id as string)
    WHERE SUBSTR(CAST(dt AS STRING), 1, 7) = SUBSTR(CAST(DATE_TRUNC(DATE_SUB(vdt_id,INTERVAL 2 MONTH), MONTH) as string),1 , 7)
    GROUP BY a.site_id
) b ON a.site_id = b.site_id
GROUP BY load_dt_sk_id, entity, kpi_code, definition, dt, b.site_id, remark, created_dtm;


delete from `data-bi-prd-935c.bi_mart.project_ioh_kpi_daily_tracker_site` where load_dt_sk_id = vdt_id and kpi_code = 'DSF_M2S_MTD';

INSERT INTO `data-bi-prd-935c.bi_mart.project_ioh_kpi_daily_tracker_site`
SELECT CAST(vdt_id AS DATE) AS load_dt_sk_id,
       'H3I' AS entity,
       'DSF_M2S_MTD' AS kpi_code,
       'IOH' AS definition,
       CAST(vdt_id AS DATE) AS dt,
       b.site_id,
       COUNT(DISTINCT a.sbscrptn_ek_id) AS value,
       'SITE ROLLING 90' AS remark,
       CURRENT_TIMESTAMP() AS created_dtm
FROM (
    SELECT DISTINCT sbscrptn_ek_id
    FROM `data-bi-prd-935c.bi_mart.fct_rgu_ioh_nik_mstr`
    WHERE tag = 'rgu_daily'
      AND dt BETWEEN DATE_TRUNC(vdt_id, MONTH) AND vdt_id

    UNION distinct

    SELECT DISTINCT sbscrptn_ek_id
    FROM `data-bi-prd-935c.bi_mart.fct_ioh_rgu_daily_nik_add` -- Added daily RGU from this table as of 23 May 2022
    WHERE tag = 'rgu_daily'
      AND dt BETWEEN DATE_TRUNC(vdt_id, MONTH) AND vdt_id
) a
JOIN (
    SELECT DISTINCT a.sbscrptn_ek_id, site_id
    FROM `data-bi-prd-935c.bi_mart.fct_ga_site_id` a
    JOIN (
        with subs as (select * from `data-dtptechm-prd-c7ca.dwh.sbscrptn_attribs`)
        SELECT DISTINCT sbscrptn_ek_id
        FROM subs a
        JOIN `data-bi-prd-935c.bi_mart.dsf_reference_list` b ON a.angie_retailer_name = b.retailer_qrcode 
    ) b ON cast(a.sbscrptn_ek_id as string) = cast(b.sbscrptn_ek_id as string)
    WHERE SUBSTR(CAST(dt AS STRING), 1, 7) = SUBSTR(CAST(DATE_TRUNC(DATE_SUB(vdt_id,INTERVAL 2 MONTH), MONTH) as string),1 , 7)
) b ON cast(a.sbscrptn_ek_id as string) = cast(b.sbscrptn_ek_id as string)
GROUP BY load_dt_sk_id, entity, kpi_code, definition, dt, b.site_id, remark, created_dtm;


delete from `data-bi-prd-935c.bi_mart.project_ioh_kpi_daily_tracker_site` where load_dt_sk_id = vdt_id and kpi_code = 'DSF_GA_M2S_MTD';

INSERT INTO `data-bi-prd-935c.bi_mart.project_ioh_kpi_daily_tracker_site`
SELECT CAST(vdt_id AS DATE) AS load_dt_sk_id,
       'H3I' AS entity,
       'DSF_GA_M2S_MTD' AS kpi_code,
       'IOH' AS definition,
       CAST(vdt_id AS DATE) AS dt,
       a.site_id,
       COUNT(DISTINCT a.sbscrptn_ek_id) AS value,
       'SITE ROLLING 90' AS remark,
       CURRENT_TIMESTAMP() AS created_dtm
FROM (
    SELECT DISTINCT a.sbscrptn_ek_id, site_id
    FROM `data-bi-prd-935c.bi_mart.fct_ga_site_id` a
    JOIN (
        with subs as (select * from `data-dtptechm-prd-c7ca.dwh.sbscrptn_attribs`)
        SELECT DISTINCT sbscrptn_ek_id
        FROM subs a
        JOIN `data-bi-prd-935c.bi_mart.dsf_reference_list` b ON a.angie_retailer_name = b.retailer_qrcode 
    ) b ON cast(a.sbscrptn_ek_id as string) = cast(b.sbscrptn_ek_id as string)
    WHERE SUBSTR(CAST(dt AS STRING), 1, 7) = SUBSTR(CAST(DATE_TRUNC(DATE_SUB(vdt_id,INTERVAL 2 MONTH), MONTH) as string),1 , 7)
) a
GROUP BY load_dt_sk_id, entity, kpi_code, definition, dt, a.site_id, remark, created_dtm;

delete from `data-bi-prd-935c.bi_mart.project_ioh_kpi_daily_tracker_site` where load_dt_sk_id = vdt_id and kpi_code = 'M1S_MTD';

INSERT INTO `data-bi-prd-935c.bi_mart.project_ioh_kpi_daily_tracker_site`
SELECT CAST(vdt_id AS DATE) AS load_dt_sk_id,
       'H3I' AS entity,
       'M1S_MTD' AS kpi_code,
       'IOH' AS definition,
       CAST(vdt_id AS DATE) AS dt,
       b.site_id,
       COUNT(DISTINCT a.sbscrptn_ek_id) AS value,
       'SITE ROLLING 90' AS remark,
       CURRENT_TIMESTAMP() AS created_dtm
FROM `data-bi-prd-935c.bi_mart.fct_ga_m1s_m2s_detail` a
JOIN (
    --Change start 01 Mar 2022 onwards
    SELECT DISTINCT sbscrptn_ek_id, site_id 
    FROM `data-bi-prd-935c.bi_mart.fct_ga_site_id`
    WHERE SUBSTR(CAST(dt AS STRING), 1, 7) = SUBSTR(CAST(DATE_TRUNC(DATE_SUB(vdt_id,INTERVAL 1 MONTH), MONTH) as string),1 , 7)
) b ON cast(a.sbscrptn_ek_id as string) = cast(b.sbscrptn_ek_id as string)
WHERE a.tag = 'M1S' AND a.m_date = vdt_id
GROUP BY load_dt_sk_id, entity, kpi_code, definition, dt, b.site_id, remark, created_dtm;

delete from `data-bi-prd-935c.bi_mart.project_ioh_kpi_daily_tracker_site` where load_dt_sk_id = vdt_id and kpi_code = 'GA_M1S_MTD';

INSERT INTO `data-bi-prd-935c.bi_mart.project_ioh_kpi_daily_tracker_site`
SELECT cast(vdt_id as date) AS load_dt_sk_id,
       'H3I' AS entity,
       'GA_M1S_MTD' AS kpi_code,
       'IOH' AS definition,
       CAST(vdt_id AS DATE) AS dt,
       a.site_id,
       COUNT(DISTINCT a.sbscrptn_ek_id) AS value,
       'SITE ROLLING 90' AS remark,
       CURRENT_TIMESTAMP() AS created_dtm
FROM (
    SELECT DISTINCT sbscrptn_ek_id, site_id
    FROM `data-bi-prd-935c.bi_mart.fct_ga_site_id`
    WHERE SUBSTR(CAST(dt AS STRING), 1, 7) = SUBSTR(CAST(DATE_TRUNC(DATE_SUB(vdt_id,INTERVAL 1 MONTH), MONTH) as string),1 , 7)
) a
GROUP BY load_dt_sk_id, entity, kpi_code, definition, dt, a.site_id, remark, created_dtm;

--Calendarized Revenue

delete from `data-bi-prd-935c.bi_mart.fct_calendarize_rev_siteid_0` where report_date_sk_id = vdt_id;

INSERT INTO `data-bi-prd-935c.bi_mart.fct_calendarize_rev_siteid_0`
SELECT fct.report_date_sk_id,
       CASE 
           WHEN PROCESS_NM IN ('RITA', 'SIM_DEMAND', 'VOUCHER_DEMAND', 'VOUCHER_FORFEIT', 'TOPUP') THEN 'MOBO' 
           ELSE 'ORGANIC' 
       END AS grp,
       c.gladiator_branch,
       SUM(CASE 
               WHEN fct.product_id = 8 THEN net_revenue / 1.11 
               WHEN fct.product_id <> 8 THEN net_revenue 
           END) AS NetRevenue
FROM `data-dtptechm-prd-c7ca.dwh.revenue_base_calendarized` fct
LEFT JOIN (
    SELECT DISTINCT dt, 
                    a.sbscrptn_ek_id, 
                    CASE 
                        WHEN LENGTH(TRIM(site_id_90)) < 6 THEN LPAD(TRIM(site_id_90), 6, '0') 
                        ELSE TRIM(site_id_90) 
                    END AS site_id
    FROM `data-bi-prd-935c.bi_mart.ioh_subscriber_site_attribs_rolling` a
    WHERE dt = vdt_id
) b ON cast(fct.sbscrptn_ek_id as string) = cast(b.sbscrptn_ek_id as string) AND fct.report_date_sk_id = b.dt 
LEFT JOIN (
    SELECT CASE 
               WHEN LENGTH(site_id) <= 5 THEN LPAD(site_id, 6, '0') 
               ELSE site_id 
           END AS site_id, 
           region, 
           area, 
           sales_area, 
           sales_cluster, 
           micro_cluster, 
           gladiator_branch,
           ROW_NUMBER() OVER (PARTITION BY CASE 
                                               WHEN LENGTH(site_id) <= 5 THEN LPAD(site_id, 6, '0') 
                                               ELSE site_id 
                                           END ORDER BY site_nm) AS seq
    FROM `data-bi-prd-935c.bi_mart.ref_site_h3i`
) c ON b.site_id = c.site_id AND c.seq = 1
WHERE fct.report_date_sk_id = vdt_id
  AND tool_of_trade_ind = 'N'
  AND PROCESS_NM IN ('RITA', 'SIM_DEMAND', 'VOUCHER_DEMAND', 'VOUCHER_FORFEIT', 'TOPUP', 'DATA_BB_BASE')
  AND COALESCE(fct.service_type, 'BROADBAND') = 'BROADBAND'
  AND fct.process_nm IN (SELECT process_nm FROM `data-dtptechm-prd-c7ca.dwh.demand_revenue_base_filter` WHERE net_revenue_incl = 'Y')
  AND fct.revenue_src_ctgry IN (SELECT revenue_src_ctgry FROM `data-dtptechm-prd-c7ca.dwh.demand_revenue_base_filter` WHERE net_revenue_incl = 'Y')
  AND fct.gl_cd NOT IN (SELECT ref_cd FROM `data-dtptechm-prd-c7ca.dwh.rprt_fltr_ref_ctgry` WHERE ref_type_cd = 'ACCRUAL_GL_CODE')
  --AND b.dt IS NULL 
  --AND c.site_id IS NULL
GROUP BY fct.report_date_sk_id, grp, c.gladiator_branch;

delete from `data-bi-prd-935c.bi_mart`.project_ioh_branch_traffic_distribution where load_dt_sk_id = vdt_id;

insert into `data-bi-prd-935c.bi_mart`.project_ioh_branch_traffic_distribution
			 select load_dt_sk_id,
				       a.site_id,
				       tag,
				       gladiator_branch,
				       cast(sum(amount) as numeric) amount
				from `data-bi-prd-935c.bi_mart`.project_mis_profile_subs_sites a
				left join (select mth_sk_id, 
						case when length(site_id) < 6 then LPAD(site_id,6,'0') else site_id end site_id, 
						upper(gladiator_branch) gladiator_branch
						from `data-bi-prd-935c.bi_mart`.site_ref_dim
						where mth_sk_id = date_trunc(vdt_id,month)
						and site_id <> '000000'
						group by 1,2,3) b on case when length(a.site_id) < 6 then LPAD(a.site_id,6,'0') else a.site_id end = b.site_id
				where tag in ('data traffic','voice traffic')
				and load_dt_sk_id <= vdt_id
				group by 1,2,3,4;

delete from `data-bi-prd-935c.bi_mart.fct_calendarize_rev_siteid_1` where dt = vdt_id;

INSERT INTO `data-bi-prd-935c.bi_mart.fct_calendarize_rev_siteid_1`
SELECT cast(a.report_date_sk_id as date) AS dt,
       a.grp,
       a.gladiator_branch,
       b.site_id,
       (a.NetRevenue * CASE 
                          WHEN COALESCE(a.gladiator_branch, 'N/A') = 'N/A' THEN 1 
                          ELSE b.ratio 
                      END) AS amount
FROM `data-bi-prd-935c.bi_mart.fct_calendarize_rev_siteid_0` a
LEFT JOIN (
    SELECT cast(x.load_dt_sk_id as string) load_dt_sk_id, 
           x.gladiator_branch, 
           COALESCE(y.site_id, '') AS site_id,
           CASE 
               WHEN x.amount = 0 THEN 0 
               ELSE y.amount / x.amount 
           END AS ratio
    FROM (
        SELECT cast(load_dt_sk_id as string) as load_dt_sk_id, 
               COALESCE(gladiator_branch, '') AS gladiator_branch, 
               SUM(amount) AS amount
        FROM `data-bi-prd-935c.bi_mart.project_ioh_branch_traffic_distribution`
        WHERE tag = 'data traffic'
          AND load_dt_sk_id = vdt_id 
        GROUP BY 1, 2
    ) x 
    LEFT JOIN (
        SELECT cast(load_dt_sk_id as string) as load_dt_sk_id, 
               COALESCE(gladiator_branch, '') AS gladiator_branch, 
               COALESCE(site_id, '') AS site_id, 
               SUM(amount) AS amount
        FROM `data-bi-prd-935c.bi_mart.project_ioh_branch_traffic_distribution`
        WHERE tag = 'data traffic'
          AND load_dt_sk_id = vdt_id
        GROUP BY 1, 2, 3
    ) y ON cast(x.load_dt_sk_id as date)= cast(y.load_dt_sk_id as date) AND x.gladiator_branch = y.gladiator_branch
) b ON cast(a.report_date_sk_id as date)= cast(b.load_dt_sk_id as date) AND a.gladiator_branch = b.gladiator_branch;