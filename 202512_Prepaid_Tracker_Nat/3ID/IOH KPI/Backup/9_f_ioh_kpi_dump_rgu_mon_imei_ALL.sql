declare vdt_id date default @vdt_id;

-- declare vdt_id date default @vdt_id;

delete from `data-bi-prd-935c.bi_mart`.project_ioh_kpi_daily_tracker_national_wise where load_dt_sk_id = vdt_id and kpi_code like 'rgu_mon_imei%';

INSERT INTO `data-bi-prd-935c.bi_mart`.project_ioh_kpi_daily_tracker_national_wise
WITH tmp_vlr_band_mon AS (
    SELECT *
    FROM (
        SELECT 
            SUBSTRING(imei, 1, 14) AS imei, 
            band, 
            ROW_NUMBER() OVER (PARTITION BY msisdn ORDER BY load_dt DESC, SUBSTRING(imei, 1, 14)) AS rank
        FROM `data-dtptechm-prd-c7ca.mis`.fct_vlr_daily a
        LEFT JOIN (
            SELECT 
                tac, 
                CASE 
                    WHEN final_device_band_type LIKE 'LTE%' THEN '4G'
                    ELSE SUBSTRING(final_device_band_type, 1, 2)
                END AS band
            FROM `data-bi-prd-935c.bi_mart`.ioh_tac_dim_extd
            WHERE final_device_band_type <> 'N'
            GROUP BY 1, 2
        ) b ON SUBSTRING(a.imei, 1, 8) = b.tac
        WHERE load_dt <= vdt_id
        AND CAST(load_dt AS DATE) >= DATE_TRUNC(vdt_id, MONTH)
    ) b
    WHERE rank = 1
),
tmp_ggsn_band_mon AS (
    SELECT *
    FROM (
        SELECT 
            SUBSTRING(served_imeisv, 1, 14) AS imei, 
            band, 
            ROW_NUMBER() OVER (PARTITION BY sbscrptn_ek_id ORDER BY 
                CASE WHEN band IS NULL THEN '0G' ELSE band END DESC, 
                dt_sk_id DESC, 
                SUBSTRING(served_imeisv, 1, 14)) AS rank
        FROM `data-bi-prd-935c.bi_mart`.project_ioh_data_imei_usage a
        LEFT JOIN (
            SELECT 
                tac, 
                CASE 
                    WHEN final_device_band_type LIKE 'LTE%' THEN '4G'
                    ELSE SUBSTRING(final_device_band_type, 1, 2)
                END AS band
            FROM `data-bi-prd-935c.bi_mart`.ioh_tac_dim_extd
            WHERE final_device_band_type <> 'N'
            GROUP BY 1, 2
        ) b ON SUBSTRING(a.served_imeisv, 1, 8) = b.tac
        WHERE a.dt_sk_id <= vdt_id
        AND a.dt_sk_id >= DATE_TRUNC(vdt_id, MONTH)
    ) a
    WHERE rank = 1
)
SELECT 
    CAST(vdt_id AS TIMESTAMP), 
    'H3I' AS entity,
    CASE 
        WHEN band = '2G' THEN 'rgu_mon_imei_2g'
        WHEN band = '3G' THEN 'rgu_mon_imei_3g'
        WHEN band = '4G' THEN 'rgu_mon_imei_4g'
        WHEN band = '5G' THEN 'rgu_mon_imei_5g'
        ELSE 'rgu_mon_imei_other'
    END AS definition,
    'IO' AS data_source,
    CAST(vdt_id AS DATE) AS date,
    COUNT(DISTINCT imei) AS imei_count
FROM (
    SELECT imei, band
    FROM tmp_ggsn_band_mon
    UNION ALL
    SELECT imei, band
    FROM tmp_vlr_band_mon
    WHERE imei NOT IN (SELECT imei FROM tmp_ggsn_band_mon)
) a
GROUP BY 1, 2, 3, 4, 5;

		insert into `data-bi-prd-935c.bi_mart`.project_ioh_kpi_daily_tracker_national_wise
		select load_dt_sk_id, entity, kpi_code, 'H3I', date, value
		from `data-bi-prd-935c.bi_mart`.project_ioh_kpi_daily_tracker_national_wise where load_dt_sk_id = vdt_id and definition = 'IO' and kpi_code like 'rgu_mon_imei%';

		insert into `data-bi-prd-935c.bi_mart`.project_ioh_kpi_daily_tracker_national_wise
		select load_dt_sk_id, entity, kpi_code, 'IOH', date, value
		from `data-bi-prd-935c.bi_mart`.project_ioh_kpi_daily_tracker_national_wise where load_dt_sk_id = vdt_id and definition = 'IO' and kpi_code like 'rgu_mon_imei%';

		---------------------

		insert into `data-bi-prd-935c.bi_mart`.project_ioh_kpi_daily_tracker_national_wise
		select load_dt_sk_id, entity, 'rgu_mon_imei' kpi_code, 'H3I', date, sum(value)
		from `data-bi-prd-935c.bi_mart`.project_ioh_kpi_daily_tracker_national_wise where load_dt_sk_id = vdt_id and definition = 'IO' and kpi_code like 'rgu_mon_imei%'
		group by 1,2,3,4,5;

		insert into `data-bi-prd-935c.bi_mart`.project_ioh_kpi_daily_tracker_national_wise
		select load_dt_sk_id, entity, 'rgu_mon_imei' kpi_code, 'IOH', date, sum(value)
		from `data-bi-prd-935c.bi_mart`.project_ioh_kpi_daily_tracker_national_wise where load_dt_sk_id = vdt_id and definition = 'IO' and kpi_code like 'rgu_mon_imei%'
		group by 1,2,3,4,5;

		insert into `data-bi-prd-935c.bi_mart`.project_ioh_kpi_daily_tracker_national_wise
		select load_dt_sk_id, entity, 'rgu_mon_imei' kpi_code, 'IO', date, sum(value)
		from `data-bi-prd-935c.bi_mart`.project_ioh_kpi_daily_tracker_national_wise where load_dt_sk_id = vdt_id and definition = 'IO' and kpi_code like 'rgu_mon_imei%'
		group by 1,2,3,4,5;