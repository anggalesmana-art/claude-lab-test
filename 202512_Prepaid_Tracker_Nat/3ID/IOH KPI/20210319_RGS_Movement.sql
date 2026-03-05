-- Prepare Tables
declare vdt_id date default @vdt_id;


INSERT INTO `data-bi-prd-935c.bi_mart.dm_rgs30_subs_movement_detail`
SELECT 
    dt,
    flag1,
    CASE 
        WHEN flag2 = 'Idle IMEI' THEN 'Not RGS but VLR'
        WHEN flag2 = 'IMEI still RGS' THEN 'Churn Rotational Subs' 
        ELSE 'Not RGS' 
    END AS flag_rotation,
    cast(sbscrptn_ek_id as string)
FROM `data-bi-prd-935c.bi_mart.dm_project_rgs30_movement` 
WHERE 
    flag1 = '03. Churn' and dt=vdt_id

UNION ALL

SELECT  
    dt,
    '01. New' AS flag1,
    CASE 
        WHEN flag_new_acq = 'Y' AND flag_rotation = 'NEW Subs' THEN 'New New'
        WHEN flag_new_acq = 'Y' AND flag_rotation <> 'NEW Subs' THEN 'New Rotational'
        ELSE 'Intermittent' 
    END AS flag,
    cast(sbscrptn_ek_id as string) 
FROM (
    with subs as (select * from `data-dtptechm-prd-c7ca.dwh.sbscrptn_attribs`)
    SELECT 
        dt,
        a.sbscrptn_ek_id,
        CASE 
            WHEN  (
    SELECT MIN(d)
    FROM UNNEST([
      cast(first_usage_dt as date),
      safe.parse_date('%Y%m%d',cast(first_billing_usage_dt_sk_id as string)),
      cast(any_event_first_usage_date as date)
    ]) AS d
    WHERE d IS NOT NULL
  ) BETWEEN DATE_SUB(DATE(vdt_id), INTERVAL 30 DAY)
            AND vdt_id
            THEN 'Y' 
            ELSE 'N' 
        END AS flag_new_acq,
        CASE 
            WHEN flag2 IS NULL THEN 'NEW Subs' 
            ELSE 'Rotational Subs' 
        END AS flag_rotation
    FROM `data-bi-prd-935c.bi_mart.dm_project_rgs30_movement` a
    LEFT JOIN subs sa 
    ON a.sbscrptn_ek_id = sa.sbscrptn_ek_id 
    WHERE flag1 = '02. New' and a.dt=vdt_id
) x 

UNION ALL

SELECT  
    dt,
    '01. Existing' AS flag1,
    'Stay' AS flag,
    cast(sbscrptn_ek_id as string)
FROM `data-bi-prd-935c.bi_mart.dm_project_rgs30_movement` 
WHERE flag1 = '01. Existing' and dt=vdt_id;

drop table if exists `data-bi-prd-935c.bi_dm.dm_rgs30_subs_movement_detail_tmp`;
drop table if exists `data-bi-prd-935c.bi_stg.dm_rgs30_subs_movement_detail_tmp`;
CREATE TABLE `data-bi-prd-935c.bi_stg.dm_rgs30_subs_movement_detail_tmp` 
OPTIONS(
    description="Temporary table for subscription movement detail with compression",
    expiration_timestamp=TIMESTAMP_ADD(CURRENT_TIMESTAMP(), INTERVAL 7 DAY)
) AS
SELECT 
    x.*,
    CASE WHEN rown = 1 THEN 'New New' ELSE 'New Rotational' END AS new_flag
FROM (
    with subs as (select * from `data-dtptechm-prd-c7ca.dwh.sbscrptn_attribs`)
    SELECT 
        a.*,
        flag_rotation,
        ROW_NUMBER() OVER (PARTITION BY latest_imei ORDER BY (
    SELECT MIN(d)
    FROM UNNEST([
      cast(first_usage_dt as date),
      safe.parse_date('%Y%m%d',cast(first_billing_usage_dt_sk_id as string)),
      cast(any_event_first_usage_date as date)
    ]) AS d
    WHERE d IS NOT NULL
  ), a.sbscrptn_msisdn) AS rown,
       (
    SELECT MIN(d)
    FROM UNNEST([
      cast(first_usage_dt as date),
      safe.parse_date('%Y%m%d',cast(first_billing_usage_dt_sk_id as string)),
      cast(any_event_first_usage_date as date)
    ]) AS d
    WHERE d IS NOT NULL
  ) AS min_usage_date
    FROM (select * from `data-bi-prd-935c.bi_mart.dm_project_rgs30_movement` where dt=vdt_id) a
    LEFT JOIN (select * from `data-bi-prd-935c.bi_mart.dm_rgs30_subs_movement_detail` where dt=vdt_id) b 
        ON cast(a.sbscrptn_ek_id as string) = cast(b.sbscrptn_ek_id as string) AND a.dt = b.dt
    LEFT JOIN subs c 
        ON a.sbscrptn_ek_id = c.sbscrptn_ek_id 
    WHERE flag_rotation = 'New New'
) x;



    INSERT INTO `data-bi-prd-935c.bi_mart.dm_rgs30_subs_movement_detail`
    SELECT dt, '01. New' AS flag1, new_flag, cast(sbscrptn_ek_id as string)
    FROM `data-bi-prd-935c.bi_stg.dm_rgs30_subs_movement_detail_tmp`
    WHERE dt = vdt_id;

drop table if exists `data-bi-prd-935c.bi_stg.dm_rgs30_subs_movement_detail_tmp2` ;

-- insert into 
-- dm_rgs30_subs_movement_detail_tmp2
-- select a.dt,a.flag1,case when 
-- b.imeiflag <>'03. valid'
-- and flag_rotation in ('New New','New Rotational') then 'New Invalid'
-- else flag_rotation end as flag_rotation ,a.sbscrptn_ek_id   
--  from
-- dm_rgs30_subs_movement_detail_1_prt_:vtgl a 
-- left join 
-- (select * from  dm_project_RGS30_movement_1_prt_:vtgl a 
-- ) b on a.sbscrptn_ek_id=b.sbscrptn_ek_id 
-- and a.dt=b.dt
-- --where a.dt in (:vtgl )
-- group by 1,2,3,4;

create table `data-bi-prd-935c.bi_stg.dm_rgs30_subs_movement_detail_tmp2` as
SELECT 
a.dt,
a.flag1,
CASE 
        WHEN b.imeiflag <> '03. valid' 
                AND flag_rotation IN ('New New', 'New Rotational') 
        THEN 'New Invalid'
        ELSE flag_rotation 
END AS flag_rotation,
a.sbscrptn_ek_id
FROM 
(select * from `data-bi-prd-935c.bi_mart.dm_rgs30_subs_movement_detail` where dt=vdt_id) a
LEFT JOIN 
(SELECT * FROM `data-bi-prd-935c.bi_mart.dm_project_rgs30_movement` where dt=vdt_id) b
ON 
cast(a.sbscrptn_ek_id as string) = cast(b.sbscrptn_ek_id as string) 
AND a.dt = b.dt
GROUP BY 1, 2, 3, 4;

delete from `data-bi-prd-935c.bi_mart.dm_rgs30_subs_movement_detail` where dt=vdt_id;    

insert into `data-bi-prd-935c.bi_mart.dm_rgs30_subs_movement_detail` 
select * from `data-bi-prd-935c.bi_stg.dm_rgs30_subs_movement_detail_tmp2`;
