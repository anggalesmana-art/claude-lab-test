declare vdt_id date default @vdt_id;
declare vdt_id2 date default date(vdt_id + interval 1 day);
declare v_mth date default date_trunc(vdt_id,month);

--- Voice Outgoing 
CREATE or replace TABLE `data-bi-prd-935c.bi_stg`.usage_voice_mtd_{{ vdt_id }} as
SELECT subscriber AS msisdn, Sum(charge) AS rev, Sum(duration) AS duration
FROM `data-bi-prd-935c.bi_dm`.usage_voice_revcode_cs5
  WHERE daydate >= timestamp(v_mth)
    AND daydate < timestamp(vdt_id2)
    AND typ <> 'Reg'
       AND duration > 0
GROUP BY msisdn ;

--- Voice Incoming 
CREATE OR REPLACE TABLE `data-bi-prd-935c.bi_stg`.ms_voice_inc_{{ vdt_id }} as
SELECT b_p_num AS msisdn, sum(hits) tot_hits, sum(duration) tot_duration
FROM `data-bi-prd-935c.bi_mart`.msc_dly
WHERE dt_id BETWEEN v_mth AND vdt_id
  AND service_type = 'MTC' --record_type = 'MTC'
  AND substr(b_p_num, 1, 5) IN ('62814', '62815', '62816', '62855', '62856', '62857', '62858')
GROUP BY b_p_num ;

--- Data GGSN 
CREATE OR REPLACE TABLE `data-bi-prd-935c.bi_stg`.datausr_ggsn_{{ vdt_id }} as
SELECT msisdn, Count(dt_id) AS day, Sum(d_vol) AS d_vol, Sum(d_vol_4g) AS d_vol_4g 
FROM
( SELECT subscriber AS msisdn, dt_id, 
  Sum(uplink+downlink) AS d_vol,
  Sum(CASE WHEN rat_tp = 6 THEN (uplink+downlink) ELSE 0 END) AS d_vol_4g
  FROM `data-bi-prd-935c.bi_dm`.traffic_ggsn
  WHERE dt_id BETWEEN timestamp(v_mth) AND timestamp(vdt_id)
    AND acs_pnt_nm_ni_id in (384, 100, 105, 140, 146, 395, 474, 2113, 139, 461, 482, 118)
  GROUP BY subscriber, dt_id
) x
GROUP BY msisdn ;

--- Voice Data User 
CREATE OR REPLACE TABLE `data-bi-prd-935c.bi_stg`.voice_data_user_{{ vdt_id }} as
SELECT COALESCE (a.msisdn, b.msisdn, c.msisdn) AS msisdn,
ifnull(a.duration,0) AS v_out_dur,
ifnull(b.tot_duration,0) AS v_inc_dur,
ifnull(c.d_vol,0) AS d_vol, ifnull(c.d_vol_4g,0) AS d_vol_4g
FROM `data-bi-prd-935c.bi_stg`.usage_voice_mtd_{{ vdt_id }} a
FULL OUTER JOIN `data-bi-prd-935c.bi_stg`.ms_voice_inc_{{ vdt_id }} b
ON a.msisdn = b.msisdn
FULL OUTER JOIN `data-bi-prd-935c.bi_stg`.datausr_ggsn_{{ vdt_id }} c
ON COALESCE(a.msisdn, b.msisdn) = c.msisdn ;



delete from `data-bi-prd-935c.bi_mart`.voice_data_user_mtd where dt_id = vdt_id;
INSERT into `data-bi-prd-935c.bi_mart`.voice_data_user_mtd
SELECT msisdn, v_out_dur, v_inc_dur, d_vol,
timestamp(current_datetime('+7')) AS ppn_dttm, d_vol_4g, vdt_id dt_id 
FROM `data-bi-prd-935c.bi_stg`.voice_data_user_{{ vdt_id }} ;

--- Drop Tables
DROP TABLE IF EXISTS `data-bi-prd-935c.bi_stg`.usage_voice_mtd_{{ vdt_id }};
DROP TABLE IF EXISTS `data-bi-prd-935c.bi_stg`.ms_voice_inc_{{ vdt_id }};
DROP TABLE IF EXISTS `data-bi-prd-935c.bi_stg`.datausr_ggsn_{{ vdt_id }};
DROP TABLE IF EXISTS `data-bi-prd-935c.bi_stg`.voice_data_user_{{ vdt_id }};