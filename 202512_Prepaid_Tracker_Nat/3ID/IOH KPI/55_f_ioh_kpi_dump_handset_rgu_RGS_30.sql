declare vdt_id date default @vdt_id;
-- declare vdt_id date default @vdt_id;
-- dependencies 10,11,12

delete from `data-bi-prd-935c.bi_mart.project_ioh_kpi_daily_tracker_national_wise` where load_dt_sk_id = vdt_id and definition = 'IOH' and kpi_code like 'rgu30_imei%' ;

INSERT INTO `data-bi-prd-935c.bi_mart.project_ioh_kpi_daily_tracker_national_wise`
SELECT 
    vdt_id dt,
    'H3I' AS definition,
    CONCAT('rgu30_imei_', 
        LOWER(CASE 
            WHEN COALESCE(c.band, d.band) = '5G' THEN '5G'
            WHEN e.band = '4G' THEN '4G'
            WHEN e.band = '3G' THEN 
                CASE 
                    WHEN COALESCE(c.band, d.band) = '4G' AND imsi LIKE '510897%' THEN '4G'
                    ELSE '3G'
                END
            WHEN e.band = '2G' THEN 
                CASE 
                    WHEN COALESCE(c.band, d.band) = '4G' AND imsi LIKE '510897%' THEN '4G'
                    WHEN COALESCE(c.band, d.band) = '4G' AND COALESCE(imsi, '') NOT LIKE '510897%' THEN '3G'
                    WHEN COALESCE(c.band, d.band) = '3G' AND imsi LIKE '510897%' THEN '3G'
                    WHEN COALESCE(c.band, d.band) = '3G' AND COALESCE(imsi, '') NOT LIKE '510897%' THEN '3G'
                    ELSE '2G'
                END
            WHEN COALESCE(e.band, 'Unknown') = 'Unknown' THEN 
                CASE 
                    WHEN COALESCE(c.band, d.band) = '4G' AND imsi LIKE '510897%' THEN '4G'
                    WHEN COALESCE(c.band, d.band) = '4G' AND COALESCE(imsi, '') NOT LIKE '510897%' THEN '3G'
                    WHEN COALESCE(c.band, d.band) = '3G' AND imsi LIKE '510897%' THEN '3G'
                    WHEN COALESCE(c.band, d.band) = '3G' AND COALESCE(imsi, '') NOT LIKE '510897%' THEN '3G'
                    WHEN COALESCE(c.band, d.band) = '2G' AND imsi LIKE '510897%' THEN '2G'
                    WHEN COALESCE(c.band, d.band) = '2G' AND COALESCE(imsi, '') NOT LIKE '510897%' THEN '2G'
                    WHEN COALESCE(COALESCE(c.band, d.band), '') = '' AND imsi LIKE '510897%' THEN '4G'
                    WHEN COALESCE(COALESCE(c.band, d.band), '') = '' AND COALESCE(imsi, '') NOT LIKE '510897%' THEN '3G'
                    ELSE 'Other a'
                END
            ELSE 'Other'
        END)
    ) AS kpi_code,
    'IOH' AS entity,
    cast(vdt_id as date) AS date,
    COUNT(1) AS count_value
FROM (
    SELECT sbscrptn_ek_id
    FROM `data-dtptechm-prd-c7ca.dwh.rgs_subs_detail` a
    WHERE 
        cast(a.load_dt_sk_id as date) <= vdt_id
        AND cast(a.load_dt_sk_id as date) >= DATE_SUB(vdt_id, INTERVAL 29 DAY)
        AND a.tool_of_trade_ind = 'N'
        AND a.rgs_all_ex_sp
    GROUP BY sbscrptn_ek_id
) a
LEFT JOIN `data-dtptechm-prd-c7ca.dwh.sbscrptn_dim` b ON a.sbscrptn_ek_id = b.sbscrptn_ek_id and b.curr_ind = 'Y' and record_end_dtm >='1900-01-01'
LEFT JOIN `data-bi-prd-935c.bi_mart.dm_ggsn_band_30` c ON a.sbscrptn_ek_id = c.sbscrptn_ek_id
LEFT JOIN `data-bi-prd-935c.bi_mart.dm_vlr_band_30` d ON b.msisdn = d.msisdn
LEFT JOIN `data-bi-prd-935c.bi_mart.dm_usage_band_30` e ON a.sbscrptn_ek_id = e.sbscrptn_ek_id
JOIN `data-bi-prd-935c.bi_mart.project_ioh_dgpcr_flag` x ON b.msisdn = x.service_msisdn
GROUP BY dt, kpi_code, date;

insert into `data-bi-prd-935c.bi_mart.project_ioh_kpi_daily_tracker_national_wise`
				select date(load_dt_sk_id) , entity, 'rgu30_imei' kpi_code, definition, date, sum(value)
				from `data-bi-prd-935c.bi_mart.project_ioh_kpi_daily_tracker_national_wise` 
				where cast(load_dt_sk_id as date) = vdt_id and definition = 'IOH' and kpi_code like 'rgu30_imei%'
				group by 1,2,3,4,5;
