-- Done changed Arie
declare vdt_id default @vdt_id;

WITH month_dates AS (
  SELECT 
    FORMAT_DATE('%Y-%m-%d', DATE_SUB(DATE_TRUNC(date(vdt_id), MONTH), INTERVAL 0 MONTH) + INTERVAL -1 DAY) AS month_1,
    FORMAT_DATE('%Y-%m-%d', DATE_SUB(DATE_TRUNC(date(vdt_id), MONTH), INTERVAL 1 MONTH) + INTERVAL -1 DAY) AS month_2,
    FORMAT_DATE('%Y-%m-%d', DATE_SUB(DATE_TRUNC(date(vdt_id), MONTH), INTERVAL 2 MONTH) + INTERVAL -1 DAY) AS month_3,
    FORMAT_DATE('%Y-%m-%d', DATE_SUB(DATE_TRUNC(date(vdt_id), MONTH), INTERVAL 3 MONTH) + INTERVAL -1 DAY) AS month_4,
    FORMAT_DATE('%Y-%m-%d', DATE_SUB(DATE_TRUNC(date(vdt_id), MONTH), INTERVAL 4 MONTH) + INTERVAL -1 DAY) AS month_5,
    FORMAT_DATE('%Y-%m-%d', DATE_SUB(DATE_TRUNC(date(vdt_id), MONTH), INTERVAL 5 MONTH) + INTERVAL -1 DAY) AS month_6,
    FORMAT_DATE('%Y-%m-%d', DATE_SUB(DATE_TRUNC(date(vdt_id), MONTH), INTERVAL 6 MONTH) + INTERVAL -1 DAY) AS month_7
),
all_months AS (
    select DATE(month_2) as dt_id from month_dates
    union all
    select DATE(month_3) from month_dates
    union all
    select DATE(month_4) from month_dates
    union all
    select DATE(month_5) from month_dates
    union all
    select DATE(month_6) from month_dates
    union all
    select DATE(month_7) from month_dates
),
m1 AS (
    select DATE(month_1) as dt_id from month_dates
)

select dt_id, 
         'IM3' as brand, 
         'Prepaid' as page,
         circle, 
         region, 
         area, 
         branch, 
         kpi_code as kpi, 
         null addfield1,
         null addfield2,
         null addfield3,
         null addfield4,
         null addfield5,
         null addfield6,
         null addfield7,
         null addfield8,
         null addfield9,
         null addfield10,
         null addfield11,
         sum(val)  as `values`
            from `data-bi-prd-935c.bi_mart.ioh_snd_master_kpi_dig_smy`
    where dt_id in (select dt_id from all_months )
    group by 1,2,3,4,5,6,7,8,9,10,11,12,13,14,15,16,17,18,19
union all 
---- MTD NUMBER DLY MONTH-1
    select dt_id, 
         'IM3' as brand, 
         'Prepaid' as page,
         circle, 
         region, 
         area, 
         branch, 
         kpi_code as kpi,  
         null addfield1,
         null addfield2,
         null addfield3,
         null addfield4,
         null addfield5,
         null addfield6,
         null addfield7,
         null addfield8,
         null addfield9,
         null addfield10,
         null addfield11,
         sum(val) as `values`
            from `data-bi-prd-935c.bi_mart.ioh_snd_master_kpi_dig_smy`
    where dt_id between DATE_TRUNC(DATE((SELECT dt_id FROM m1)), MONTH)
                AND DATE((SELECT dt_id FROM m1))
    group by 1,2,3,4,5,6,7,8,9,10,11,12,13,14,15,16,17,18,19
union all 
---- MTD NUMBER DLY MONTH-0
    select dt_id, 
         'IM3' as brand, 
         'Prepaid' as page,
         circle, 
         region, 
         area, 
         branch, 
         kpi_code as kpi,  
         null addfield1,
         null addfield2,
         null addfield3,
         null addfield4,
         null addfield5,
         null addfield6,
         null addfield7,
         null addfield8,
         null addfield9,
         null addfield10,
         null addfield11,
         sum(val) as `values`
            from `data-bi-prd-935c.bi_mart.ioh_snd_master_kpi_dig_smy`
    where dt_id between DATE(FORMAT_DATE('%Y-%m-01', DATE((vdt_id)))) and date(vdt_id)
    group by 1,2,3,4,5,6,7,8,9,10,11,12,13,14,15,16,17,18,19
;