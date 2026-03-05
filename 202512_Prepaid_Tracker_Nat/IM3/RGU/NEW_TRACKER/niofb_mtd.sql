declare vdt_id date default @vdt_id;

--- Nio FB
delete from `data-bi-prd-935c.bi_mart`.niofb_mtd  where dt_id = vdt_id;
INSERT into `data-bi-prd-935c.bi_mart`.niofb_mtd 
SELECT msisdn, Sum(volume_total_bytes) AS vol_total_bytes, timestamp(current_datetime('+7')) ppn_dttm, vdt_id dt_id
FROM `data-dtp-prd-aa1a.stg.stg_nio_appsrtgout`
WHERE date(dt_id) BETWEEN date_trunc(vdt_id,month) AND vdt_id
  AND lower(application_name) = 'facebook'
GROUP BY msisdn ;
