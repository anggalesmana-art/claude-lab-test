declare vdt_id date default @vdt_id;

----------------------------------
----- secondary_trad_sp ---------
----------------------------------


delete from `data-bi-prd-935c.bi_dev`.ioh_snd_master_kpi_detail 
where brand = '3ID' and dt_id = vdt_id and kpi = 'secondary_trad_sp' and time_flag ='mtd'
;


INSERT INTO `data-bi-prd-935c.bi_dev`.ioh_snd_master_kpi_detail
    SELECT '3ID',
    'outlet',
    qr_code,
    SUM(value)value,
    'mtd',
    timestamp(current_datetime('+7')),
    'secondary_trad_sp',
    dt_id 
    FROM `data-bi-prd-935c.bi_dev.mis_snd_prisec_detail` a 
    WHERE a.kpi_name = 'secondary' 
      AND TRIM(LOWER(a.flag)) IN ('sp0')
      AND a.dt_id = vdt_id
    GROUP BY 1,2,3,5,6,7,8 ;


-- delete table `data-bi-prd-935c.bi_dev`.ioh_snd_master_kpi_detail
delete from `data-bi-prd-935c.bi_dev`.ioh_snd_master_kpi_detail 
where brand = '3ID' and dt_id = vdt_id and kpi = 'secondary_trad_sp' and time_flag ='dly'
;
-- insert table `data-bi-prd-935c.bi_dev`.ioh_snd_master_kpi_detail 

INSERT INTO `data-bi-prd-935c.bi_dev`.ioh_snd_master_kpi_detail
WITH ids AS (
    SELECT
        vdt_id AS loop_date,
        vdt_id AS current_date_id,
        date(CASE
            WHEN EXTRACT(DAY FROM vdt_id) = 1 THEN
                vdt_id
            ELSE
                date(vdt_id - interval 1 day)
        END) AS previous_date_id
)
	SELECT 
	    '3ID',
	    'outlet',
	    a.level_value,
	    CASE 
	        WHEN EXTRACT(DAY FROM i.loop_date) = 1 THEN 
	            SUM(COALESCE(a.values, 0))
	        ELSE 
	            SUM(COALESCE(a.values, 0) - COALESCE(b.values, 0))
	    END AS daily_val,
	    'dly',
	    timestamp(current_datetime('+7')),
	    'secondary_trad_sp',
	    i.current_date_id
	FROM ids i
	JOIN (
	    SELECT * 
	    FROM `data-bi-prd-935c.bi_dev`.ioh_snd_master_kpi_detail 
	    WHERE kpi = 'secondary_trad_sp'  and brand = '3ID'
	      AND time_flag = 'mtd'
	) a ON a.dt_id = i.current_date_id
	LEFT JOIN (
	    SELECT * 
	    FROM `data-bi-prd-935c.bi_dev`.ioh_snd_master_kpi_detail 
	    WHERE kpi = 'secondary_trad_sp' and brand = '3ID'
	      AND time_flag = 'mtd'
	) b ON b.dt_id = i.previous_date_id
	   AND a.level_value = b.level_value
	GROUP BY a.level_value, i.current_date_id, i.loop_date
;

----------------------------------
----- secondary_trad_saldo ---------
----------------------------------




delete from `data-bi-prd-935c.bi_dev`.ioh_snd_master_kpi_detail 
where brand = '3ID' and dt_id = vdt_id and kpi = 'secondary_trad_saldo' and time_flag ='mtd'
;


-- insert table `data-bi-prd-935c.bi_dev`.ioh_snd_master_kpi_detail 

INSERT INTO `data-bi-prd-935c.bi_dev`.ioh_snd_master_kpi_detail
    SELECT '3ID',
    'outlet',
    qr_code,
    SUM(value)value,
    'mtd',
    timestamp(current_datetime('+7')),
    'secondary_trad_saldo',
    dt_id 
    FROM `data-bi-prd-935c.bi_dev.mis_snd_prisec_detail` a 
    WHERE a.kpi_name = 'secondary' 
      AND TRIM(LOWER(a.flag)) IN ('retailer_cashback','saldo','return to mp3')--,'spv0','sp0')
      AND a.dt_id = vdt_id
    GROUP BY 1,2,3,5,6,7,8
   ;


-- delete table `data-bi-prd-935c.bi_dev`.ioh_snd_master_kpi_detail

delete from `data-bi-prd-935c.bi_dev`.ioh_snd_master_kpi_detail 
where brand = '3ID' and dt_id = vdt_id and kpi = 'secondary_trad_saldo' and time_flag ='dly'
;


INSERT INTO `data-bi-prd-935c.bi_dev`.ioh_snd_master_kpi_detail
WITH ids AS (
    SELECT
        vdt_id AS loop_date,
        vdt_id AS current_date_id,
        date(CASE
            WHEN EXTRACT(DAY FROM vdt_id) = 1 THEN
                vdt_id
            ELSE
                date(vdt_id - interval 1 day)
        END) AS previous_date_id
)
	SELECT 
	    '3ID',
	    'outlet',
	    a.level_value,
	    CASE 
	        WHEN EXTRACT(DAY FROM i.loop_date) = 1 THEN 
	            SUM(COALESCE(a.values, 0))
	        ELSE 
	            SUM(COALESCE(a.values, 0) - COALESCE(b.values, 0))
	    END AS daily_val,
	    'dly',
	    timestamp(current_datetime('+7')),
	    'secondary_trad_saldo',
	    i.current_date_id
	FROM ids i
	JOIN (
	    SELECT * 
	    FROM `data-bi-prd-935c.bi_dev`.ioh_snd_master_kpi_detail 
	    WHERE kpi = 'secondary_trad_saldo' and brand = '3ID'
	      AND time_flag = 'mtd'
	) a ON a.dt_id = i.current_date_id
	LEFT JOIN (
	    SELECT * 
	    FROM `data-bi-prd-935c.bi_dev`.ioh_snd_master_kpi_detail 
	    WHERE kpi = 'secondary_trad_saldo' and brand = '3ID'
	      AND time_flag = 'mtd'
	) b ON b.dt_id = i.previous_date_id
	   AND a.level_value = b.level_value
	GROUP BY a.level_value, i.current_date_id, i.loop_date
;


----------------------------------
----- secondary_trad_spv ---------
----------------------------------





-- delete table `data-bi-prd-935c.bi_dev`.ioh_snd_master_kpi_detail
delete from `data-bi-prd-935c.bi_dev`.ioh_snd_master_kpi_detail 
where brand = '3ID' and dt_id = vdt_id and kpi = 'secondary_trad_spv' and time_flag ='mtd'
;



INSERT INTO `data-bi-prd-935c.bi_dev`.ioh_snd_master_kpi_detail
    SELECT '3ID',
    'outlet',
    qr_code,
    SUM(value)value,
    'mtd',
    timestamp(current_datetime('+7')),
    'secondary_trad_spv',
    dt_id 
    FROM `data-bi-prd-935c.bi_dev.mis_snd_prisec_detail` a 
    WHERE a.kpi_name = 'secondary' 
      AND TRIM(LOWER(a.flag)) IN ('spv0')
      AND a.dt_id = vdt_id
    GROUP BY 1,2,3,5,6,7,8 ;


-- delete table `data-bi-prd-935c.bi_dev`.ioh_snd_master_kpi_detail
delete from `data-bi-prd-935c.bi_dev`.ioh_snd_master_kpi_detail 
where brand = '3ID' and dt_id = vdt_id and kpi = 'secondary_trad_spv' and time_flag ='dly'
;

-- insert table `data-bi-prd-935c.bi_dev`.ioh_snd_master_kpi_detail 

INSERT INTO `data-bi-prd-935c.bi_dev`.ioh_snd_master_kpi_detail
WITH ids AS (
    SELECT
        vdt_id AS loop_date,
        vdt_id AS current_date_id,
        date(CASE
            WHEN EXTRACT(DAY FROM vdt_id) = 1 THEN
                vdt_id
            ELSE
                date(vdt_id - interval 1 day)
        END) AS previous_date_id
)
	SELECT 
	    '3ID',
	    'outlet',
	    a.level_value,
	    CASE 
	        WHEN EXTRACT(DAY FROM i.loop_date) = 1 THEN 
	            SUM(COALESCE(a.values, 0))
	        ELSE 
	            SUM(COALESCE(a.values, 0) - COALESCE(b.values, 0))
	    END AS daily_val,
	    'dly',
	    timestamp(current_datetime('+7')),
	    'secondary_trad_spv',
	    i.current_date_id
	FROM ids i
	JOIN (
	    SELECT * 
	    FROM `data-bi-prd-935c.bi_dev`.ioh_snd_master_kpi_detail 
	    WHERE kpi = 'secondary_trad_spv' and brand = '3ID'
	      AND time_flag = 'mtd'
	) a ON a.dt_id = i.current_date_id
	LEFT JOIN (
	    SELECT * 
	    FROM `data-bi-prd-935c.bi_dev`.ioh_snd_master_kpi_detail 
	    WHERE kpi = 'secondary_trad_spv' and brand = '3ID'
	      AND time_flag = 'mtd'
	) b ON b.dt_id = i.previous_date_id
	   AND a.level_value = b.level_value
	GROUP BY a.level_value, i.current_date_id, i.loop_date
;



--------------------------------------------------------------------
----- tertiary_trad_sp,tertiary_trad_spv,tertiary_trad_saldo ------------------
--------------------------------------------------------------------

-- delete table `data-bi-prd-935c.bi_dev`.ioh_snd_master_kpi_detail

delete from `data-bi-prd-935c.bi_dev`.ioh_snd_master_kpi_detail 
where brand = '3ID' and dt_id = vdt_id and kpi in ('tertiary_trad_sp','tertiary_trad_spv','tertiary_trad_saldo')
     and time_flag ='dly' 
;

-- insert table `data-bi-prd-935c.bi_dev`.ioh_snd_master_kpi_detail 

INSERT INTO `data-bi-prd-935c.bi_dev`.ioh_snd_master_kpi_detail
        SELECT '3ID', 'outlet', dealer_id, SUM(COALESCE(a.amount, 0)), 'dly', timestamp(current_datetime('+7')),
            CASE
                WHEN tertiary_category = 'SALDO' THEN 'tertiary_trad_saldo'
                WHEN tertiary_category = 'FRC' THEN 'tertiary_trad_sp'
                WHEN tertiary_category = 'UNLOCK' THEN 'tertiary_trad_spv'
            END AS kpi,
            dt_sk_id
        FROM `data-bi-prd-935c.bi_mart`.project_ioh_tertiary_outlet a
        LEFT JOIN `data-bi-prd-935c.bi_mart`.angie_hrchy_dim_hst b ON b.partner_qr_cd = a.dealer_id AND date_trunc(a.dt_sk_id,month) = b.mth
        WHERE a.dt_sk_id = vdt_id
          AND a.tertiary_category IN ('SALDO', 'FRC', 'UNLOCK')
          AND LENGTH(a.dealer_id) < 10
          AND UPPER(b.mp3_location) NOT IN ('POOL','DVM BM','SIM ONLINE','BSM TRI OFFICIAL STORE','3 BUSINESS','3 STORE','SOUTH JAKARTA TEST BM')
        GROUP BY 1,2,3,5,6,7,8
;



--------------------------------------------------------------------
----- ono_dly ------------------
--------------------------------------------------------------------

-- delete table `data-bi-prd-935c.bi_dev`.ioh_snd_master_kpi_detail

 DELETE FROM `data-bi-prd-935c.bi_dev`.ioh_snd_master_kpi_detail
        WHERE brand = '3ID' and lower(kpi) = 'ono_dly' and time_flag ='dly' AND date_trunc(dt_id,month) =date_trunc(vdt_id,month) --- 20250701 and 20251027
    ;
    
 -- insert table ioh_snd_master_kpi_deta
INSERT INTO `data-bi-prd-935c.bi_dev`.ioh_snd_master_kpi_detail
SELECT
            '3ID' AS brand_id, 'outlet' AS level_id, outlet_id AS level_value,
            count(DISTINCT outlet_id) AS kpi_value, 'dly' AS time_flag, timestamp(current_datetime('+7')) AS insert_date,
            'ono_dly' AS kpi, parse_date('%d-%b-%y',substr(a.ret_reg_date,1,9))  AS dt_id
        FROM `data-bi-prd-935c.bi_snd.pre_ref_retailer_hirarki` a 
        WHERE date_trunc(parse_date('%d-%b-%y',substr(a.ret_reg_date,1,9)),month) =date_trunc(vdt_id,month) and parse_date('%Y%m',cast(mth_id as string))=date_trunc(vdt_id,month)  --- between  20250701 and 20251027 -- =vdt_id
             GROUP BY 1,2,3,5,6,7,8;
           