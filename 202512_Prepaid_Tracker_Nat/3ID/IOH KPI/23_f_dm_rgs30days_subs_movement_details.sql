declare vdt_id date default @vdt_id;



delete from `data-bi-prd-935c.bi_mart.dm_rgs30_subs_movement_detail` where dt in (vdt_id);


insert into `data-bi-prd-935c.bi_mart.dm_rgs30_subs_movement_detail`
SELECT 
    dt,
    flag1,
    CASE 
        WHEN flag2 = 'Idle IMEI' THEN 'Not RGS but VLR'
        WHEN flag2 = 'IMEI still RGS' THEN 'Churn Rotational Subs' 
        ELSE 'Not RGS' 
    END AS flag_rotation,
    cast(sbscrptn_ek_id as string)
FROM 
    `data-bi-prd-935c.bi_mart.dm_project_rgs30_movement` a
WHERE 
    dt IN (vdt_id) 
    AND flag1 = '03. Churn'

UNION ALL 

SELECT 
    dt,
    '01. New' AS flag1,
    CASE 
        WHEN flag_new_acq = 'Y' AND flag_rotation = 'NEW Subs' THEN 'New New'
        WHEN flag_new_acq = 'Y' AND flag_rotation <> 'NEW Subs' THEN 'New Rotational'
        ELSE 'Intermitten' 
    END AS flag,
    cast(sbscrptn_ek_id as string)sbscrptn_ek_id
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
                    ) 
                 BETWEEN DATE_SUB(vdt_id, INTERVAL 30 DAY) AND vdt_id 
            THEN 'Y' 
            ELSE 'N' 
        END AS flag_new_acq,
        CASE 
            WHEN flag2 IS NULL THEN 'NEW Subs' 
            ELSE 'Rotational Subs' 
        END AS flag_rotation
    FROM 
        `data-bi-prd-935c.bi_mart.dm_project_rgs30_movement` a
    LEFT JOIN 
        subs sa
    ON 
        cast(a.sbscrptn_ek_id as string) = cast(sa.sbscrptn_ek_id as string)
    WHERE 
        dt IN (vdt_id)
        AND flag1 = '02. New'
) x

UNION ALL

SELECT 
    dt,
    '01. Existing' AS flag1,
    'Stay' AS flag,
    cast(sbscrptn_ek_id as string) sbscrptn_ek_id
FROM 
    `data-bi-prd-935c.bi_mart.dm_project_rgs30_movement` a
WHERE 
    dt IN (vdt_id)
    AND flag1 = '01. Existing';

 drop table if exists `data-bi-prd-935c.bi_stg.dm_rgs30_subs_movement_detail_tmp`; 

CREATE TABLE `data-bi-prd-935c.bi_stg.dm_rgs30_subs_movement_detail_tmp`
AS
WITH ranked_data AS (
    with subs as (select * from `data-dtptechm-prd-c7ca.dwh.sbscrptn_attribs`)
    SELECT 
        a.*,
        flag_rotation,
        ROW_NUMBER() OVER (
            PARTITION BY latest_imei 
            ORDER BY 
                 (
                    SELECT MIN(d)
                    FROM UNNEST([
                    cast(first_usage_dt as date),
                    safe.parse_date('%Y%m%d',cast(first_billing_usage_dt_sk_id as string)),
                    cast(any_event_first_usage_date as date)
                    ]) AS d
                    WHERE d IS NOT NULL
                ) ,
                a.sbscrptn_msisdn
        ) AS rown,
         (
    SELECT MIN(d)
    FROM UNNEST([
      cast(first_usage_dt as date),
      safe.parse_date('%Y%m%d',cast(first_billing_usage_dt_sk_id as string)),
      cast(any_event_first_usage_date as date)
    ]) AS d
    WHERE d IS NOT NULL
  ) AS first_event_date
    FROM 
        `data-bi-prd-935c.bi_mart.dm_project_rgs30_movement` a
    LEFT JOIN (
        SELECT * 
        FROM `data-bi-prd-935c.bi_mart.dm_rgs30_subs_movement_detail` 
        WHERE dt = vdt_id
    ) b 
        ON cast(a.sbscrptn_ek_id as string) = cast(b.sbscrptn_ek_id as string)
        AND a.dt = b.dt
    LEFT JOIN subs c
        ON cast(a.sbscrptn_ek_id as string) = cast(c.sbscrptn_ek_id as string) 
    WHERE 
        a.dt IN (vdt_id)
        AND flag_rotation = 'New New'
)
SELECT 
    x.*,
    CASE 
        WHEN rown = 1 THEN 'New New'
        ELSE 'New Rotational'
    END AS new_flag
FROM ranked_data x;


delete from `data-bi-prd-935c.bi_mart.dm_rgs30_subs_movement_detail` where dt =vdt_id 
and flag_rotation='New New';


		insert into `data-bi-prd-935c.bi_mart.dm_rgs30_subs_movement_detail`
		select dt,'01. New' flag1,new_flag,cast(sbscrptn_ek_id as string) as sbscrptn_ek_id  from 
		`data-bi-prd-935c.bi_stg.dm_rgs30_subs_movement_detail_tmp`
		where dt =vdt_id; 
		 
 drop table if exists `data-bi-prd-935c.bi_stg.dm_rgs30_subs_movement_detail_tmp2`;


CREATE TABLE `data-bi-prd-935c.bi_stg.dm_rgs30_subs_movement_detail_tmp2` AS
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
    `data-bi-prd-935c.bi_mart.dm_rgs30_subs_movement_detail` a
LEFT JOIN (
    SELECT * 
    FROM `data-bi-prd-935c.bi_mart.dm_project_rgs30_movement` a
) b 
    ON cast(a.sbscrptn_ek_id as string)= cast(b.sbscrptn_ek_id as string)
    AND a.dt = b.dt
WHERE 
    a.dt IN (vdt_id)
GROUP BY 
    1, 2, 3, 4;

delete from `data-bi-prd-935c.bi_mart.dm_rgs30_subs_movement_detail` where dt=(vdt_id);

insert into `data-bi-prd-935c.bi_mart.dm_rgs30_subs_movement_detail`
select * from `data-bi-prd-935c.bi_stg.dm_rgs30_subs_movement_detail_tmp2`; 
