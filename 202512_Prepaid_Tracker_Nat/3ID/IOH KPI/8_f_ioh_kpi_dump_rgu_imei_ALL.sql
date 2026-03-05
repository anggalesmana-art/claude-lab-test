declare vdt_id date default @vdt_id;

create or replace table `data-bi-prd-935c.bi_mart.tmp_ggsn_band_daily`
AS
    SELECT *
    FROM (
        SELECT 
            SUBSTRING(served_imeisv, 1, 14) AS imei, 
            band, 
            ROW_NUMBER() OVER (PARTITION BY sbscrptn_ek_id ORDER BY 
                CASE WHEN band IS NULL THEN '0G' ELSE band END DESC, 
                dt_sk_id DESC, 
                SUBSTRING(served_imeisv, 1, 14)) AS rank,
						dt_sk_id
        FROM (select sbscrptn_ek_id,served_imeisv,dt_sk_id from `data-bi-prd-935c.bi_mart.project_ioh_data_imei_usage` where dt_sk_id = vdt_id)  a --1_prtvdt_id` a
        LEFT JOIN (
            SELECT 
                tac, 
                CASE 
                    WHEN final_device_band_type LIKE 'LTE%' THEN '4G' 
                    ELSE SUBSTRING(final_device_band_type, 1, 2)
                END AS band
            FROM `data-bi-prd-935c.bi_mart.ioh_tac_dim_extd`
            WHERE final_device_band_type <> 'N'
            GROUP BY 1, 2
        ) b ON SUBSTRING(a.served_imeisv, 1, 8) = b.tac
    ) a
    WHERE rank = 1
		AND dt_sk_id = vdt_id;

create or replace table `data-bi-prd-935c.bi_mart.tmp_vlr_band_daily` AS
    SELECT *
    FROM (
        SELECT 
            SUBSTRING(imei, 1, 14) AS imei, 
            band, 
            ROW_NUMBER() OVER (PARTITION BY msisdn ORDER BY load_dt DESC, SUBSTRING(imei, 1, 14)) AS rank
        FROM `data-bi-prd-935c.bi_mart.fct_vlr_daily` a--1_prtvdt_id` a
        LEFT JOIN (
            SELECT 
                tac, 
                CASE 
                    WHEN final_device_band_type LIKE 'LTE%' THEN '4G' 
                    ELSE SUBSTRING(final_device_band_type, 1, 2)
                END AS band
            FROM `data-bi-prd-935c.bi_mart.ioh_tac_dim_extd`
            WHERE final_device_band_type <> 'N' 
            GROUP BY 1, 2
        ) b ON SUBSTRING(a.imei, 1, 8) = b.tac
        where a.load_dt='2024-03-01'
    ) b
    WHERE rank = 1;


delete from `data-bi-prd-935c.bi_mart`.project_ioh_kpi_daily_tracker_national_wise where load_dt_sk_id = vdt_id and kpi_code like 'rgu_imei%';

INSERT INTO `data-bi-prd-935c.bi_mart`.project_ioh_kpi_daily_tracker_national_wise
with final as (
        SELECT imei, band
    FROM `data-bi-prd-935c.bi_mart.tmp_ggsn_band_daily`
    UNION ALL
    SELECT imei, band
    FROM `data-bi-prd-935c.bi_mart.tmp_vlr_band_daily`
    WHERE imei NOT IN (SELECT distinct imei FROM `data-bi-prd-935c.bi_mart.tmp_ggsn_band_daily`)
)
SELECT 
    CAST(vdt_id AS date), 
    'H3I' AS entity,
    CASE 
        WHEN band = '2G' THEN 'rgu_imei_2g'
        WHEN band = '3G' THEN 'rgu_imei_3g'
        WHEN band = '4G' THEN 'rgu_imei_4g'
        WHEN band = '5G' THEN 'rgu_imei_5g'
        ELSE 'rgu_imei_other'
    END AS definition,
    'IO' AS data_source,
    CAST(vdt_id AS DATE) AS date,
    COUNT(DISTINCT imei) AS imei_count
FROM final
GROUP BY 1, 2, 3, 4, 5;

	-------------

	insert into `data-bi-prd-935c.bi_mart`.project_ioh_kpi_daily_tracker_national_wise	
	select load_dt_sk_id, entity, kpi_code, 'H3I', date, value
	from `data-bi-prd-935c.bi_mart`.project_ioh_kpi_daily_tracker_national_wise 
	where load_dt_sk_id = vdt_id and definition = 'IO' and kpi_code like 'rgu_imei%';

	insert into `data-bi-prd-935c.bi_mart`.project_ioh_kpi_daily_tracker_national_wise	
	select load_dt_sk_id, entity, kpi_code, 'IOH', date, value
	from `data-bi-prd-935c.bi_mart`.project_ioh_kpi_daily_tracker_national_wise 
	where load_dt_sk_id = vdt_id and definition = 'IO' and kpi_code like 'rgu_imei%';

	-----------

	insert into `data-bi-prd-935c.bi_mart`.project_ioh_kpi_daily_tracker_national_wise	
	select load_dt_sk_id, entity, 'rgu_imei' kpi_code, 'H3I', date, sum(value)
	from `data-bi-prd-935c.bi_mart`.project_ioh_kpi_daily_tracker_national_wise 
	where load_dt_sk_id = vdt_id and definition = 'IO' and kpi_code like 'rgu_imei%'
	group by 1,2,3,4,5;

	insert into `data-bi-prd-935c.bi_mart`.project_ioh_kpi_daily_tracker_national_wise	
	select load_dt_sk_id, entity, 'rgu_imei' kpi_code, 'IOH', date, sum(value)
	from `data-bi-prd-935c.bi_mart`.project_ioh_kpi_daily_tracker_national_wise 
	where load_dt_sk_id = vdt_id and definition = 'IO' and kpi_code like 'rgu_imei%'
	group by 1,2,3,4,5;

	insert into `data-bi-prd-935c.bi_mart`.project_ioh_kpi_daily_tracker_national_wise	
	select load_dt_sk_id, entity, 'rgu_imei' kpi_code, 'IO', date, sum(value)
	from `data-bi-prd-935c.bi_mart`.project_ioh_kpi_daily_tracker_national_wise 
	where load_dt_sk_id = vdt_id and definition = 'IO' and kpi_code like 'rgu_imei%'
	group by 1,2,3,4,5;