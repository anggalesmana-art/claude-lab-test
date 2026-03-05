-- Migrate Query by Indra Maulana Ikhsan 2024
/*
create table `data-bi-prd-935c.bi_mart`.rgs_mtd_govt_bak as
select * from `data-bi-prd-935c.bi_mart`.rgs_mtd_govt
where dt_id>='20240331'
;
*/

--- Create Table
/*
CREATE TABLE IF NOT EXISTS `data-bi-prd-935c.bi_mart`.rgs_mtd_govt
(
msisdn   string,
actvn_dt string,
dt_min   string,
dt_max   string,
total_rev double,
rge_voice int,
rge_sms   int,
rge_data  int,
rge_vas   int,
rge_mobo  int,
rge_spdata int,
rge_loan   int,
rge_fdv    int,
rge_smsv   int,
rge_edu    int,
rge_pgi    int,
sge_inc    int,
sge_out    int,
ppn_dttm   timestamp
)
partitioned BY (dt_id string)
stored AS parquet ;
*/
Declare vdt_id date default @vdt_id;
--- RGU MTD by Service
CREATE OR REPLACE TABLE `data-bi-prd-935c.bi_mart`.rgs_mtd_govt_{{ vdt_id }}_tmp1 as
SELECT msisdn, max(actvn_dt) AS actvn_dt,
  min(dt_id) AS dt_min, max(dt_id) AS dt_max, sum(ifnull(total_rev,0)) total_rev,
  max(rge_voice) AS rge_voice, max(rge_sms) AS rge_sms, max(rge_data) AS rge_data,
  max(rge_vas) AS rge_vas, max(rge_rld) AS rge_rld, max(rge_mobo) AS rge_mobo,
  max(rge_spdata) AS rge_spdata, max(rge_loan) AS rge_loan, max(rge_fdv) AS rge_fdv,
  max(rge_smsv) AS rge_smsv, max(rge_edu) AS rge_edu, max(sge_inc) AS sge_inc,
  max(sge_out) AS sge_out, max(rge_pgi) AS rge_pgi
FROM (
  SELECT a.*,
    CASE WHEN usg_flag LIKE '%V%' THEN 1 ELSE 0 END rge_voice,
    CASE WHEN usg_flag LIKE '%S%' THEN 1 ELSE 0 END rge_sms,
    CASE WHEN usg_flag LIKE '%D%' THEN 1 ELSE 0 END rge_data,
    CASE WHEN usg_flag LIKE '%A%' THEN 1 ELSE 0 END rge_vas,
    CASE WHEN usg_flag LIKE '%R%' THEN 1 ELSE 0 END rge_rld,
    CASE WHEN usg_flag LIKE '%M%' THEN 1 ELSE 0 END rge_mobo,
    CASE WHEN usg_flag LIKE '%P%' THEN 1 ELSE 0 END rge_spdata,
    CASE WHEN usg_flag LIKE '%L%' THEN 1 ELSE 0 END rge_loan,
    CASE WHEN usg_flag LIKE '%F%' THEN 1 ELSE 0 END rge_fdv,
    CASE WHEN usg_flag LIKE '%O%' THEN 1 ELSE 0 END rge_smsv,
    CASE WHEN usg_flag LIKE '%E%' THEN 1 ELSE 0 END rge_edu,
    CASE WHEN usg_flag LIKE '%I%' THEN 1 ELSE 0 END sge_inc,
    CASE WHEN usg_flag LIKE '%G%' THEN 1 ELSE 0 END sge_out,
    CASE WHEN usg_flag LIKE '%Y%' THEN 1 ELSE 0 END rge_pgi
  --FROM `data-bi-prd-935c.bi_mart`.rgs_nogovt_dly a
  FROM `data-bi-prd-935c.bi_mart`.rgs_nogovt_dly a
  WHERE dt_id BETWEEN date_trunc(vdt_id,month) AND vdt_id
    --AND (flag_status = 'Active 2' OR usg_flag NOT IN ('I')) AND (flag_y4 = 'NO' OR usg_flag LIKE '%G%')
    AND (flag_status = 'Active 2' OR ifnull(total_rev,0)>0)
    and flag_y4='NO' -- new definition from 1st April 2024
) x
GROUP BY msisdn
;

--- Insert Into
--REFRESH `data-bi-prd-935c.bi_mart`.rgs_mtd_govt ;

delete from `data-bi-prd-935c.bi_mart`.rgs_mtd_govt where dt_id = vdt_id;
INSERT into `data-bi-prd-935c.bi_mart`.rgs_mtd_govt 
SELECT msisdn, actvn_dt, dt_min, dt_max, total_rev,
  rge_voice, rge_sms, rge_data, rge_vas, --rge_rld,
  rge_mobo, rge_spdata, rge_loan, rge_fdv, rge_smsv, rge_edu,
  rge_pgi, sge_inc, sge_out, timestamp(current_datetime('+7')) AS ppn_dttm, vdt_id dt_id
FROM `data-bi-prd-935c.bi_mart`.rgs_mtd_govt_{{ vdt_id }}_tmp1
;

--- Drop Tables
DROP TABLE IF EXISTS `data-bi-prd-935c.bi_mart`.rgs_mtd_govt_{{ vdt_id }}_tmp1;