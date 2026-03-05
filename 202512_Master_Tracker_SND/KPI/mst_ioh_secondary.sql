declare vdt_id date default @vdt_id;
--IM3
delete from `data-bi-prd-935c.bi_dev`.ioh_snd_master_kpi_detail where kpi = 'secondary_trad' and brand = 'IM3' and dt_id = vdt_id;
insert into `data-bi-prd-935c.bi_dev`.ioh_snd_master_kpi_detail
select 'IM3' brand, 'outlet' level, id as level_value, 
    sum(cast(value as numeric)) value, 
    'mtd' as time_flag, 
     timestamp(current_datetime('+7')) as insert_date,
    'secondary_trad' as kpi, 
    vdt_id as dt_id
from
(
SELECT 
    credit_party_id id,
    sum(amount) value
FROM `data-bi-prd-935c.bi_mart`.fact_snd_secondary a
    where dt_id between date_trunc(vdt_id,month) and vdt_id 
    GROUP BY 1
)a
group by 1,2,3,5,6,7,8
; 



--- sql

DELETE FROM `data-bi-prd-935c.bi_dev`.ioh_snd_master_kpi_detail
WHERE kpi = 'secondary_trad' AND dt_id = vdt_id AND level = 'site_id' and time_flag='mtd' and brand = '3ID';

INSERT INTO `data-bi-prd-935c.bi_dev`.ioh_snd_master_kpi_detail
with siteref as
(
(select ret_qr_cd,site_id from 
(
select dt,ret_qr_cd,site_id,row_number() over (partition by ret_qr_cd order by dt desc nulls last) rnk
from `data-bi-prd-935c.bi_mart.stg_v_map_tgt_ret_details_hist`
where  site_id <>''
) x where rnk=1
)    
)
SELECT '3ID',
'site_id',
x.site_id,
SUM(a.value),
'mtd',
timestamp(current_datetime('+7')) insert_date,
'secondary_trad',
a.dt_id
FROM `data-bi-prd-935c.bi_dev.mis_snd_prisec_detail` a
LEFT JOIN siteref x ON  a.qr_code = x.ret_qr_cd
WHERE a.kpi_name = 'secondary'
AND TRIM(LOWER(a.flag)) IN ('retailer_cashback','saldo','return to mp3','spv0','sp0')
AND a.dt_id = vdt_id
GROUP BY 1,2,3,5,6,7,8;


DELETE FROM `data-bi-prd-935c.bi_dev`.ioh_snd_master_kpi_detail
WHERE kpi = 'secondary_trad' AND dt_id = vdt_id AND level = 'outlet' and time_flag='mtd' and brand = '3ID';

INSERT INTO `data-bi-prd-935c.bi_dev`.ioh_snd_master_kpi_detail
SELECT '3ID',
'outlet',
qr_code,
SUM(value),
'mtd',
timestamp(current_datetime('+7')) insert_date,
'secondary_trad',
dt_id
FROM `data-bi-prd-935c.bi_dev.mis_snd_prisec_detail` a
WHERE a.kpi_name = 'secondary'
AND TRIM(LOWER(a.flag)) IN ('retailer_cashback','saldo','return to mp3','spv0','sp0')
AND a.dt_id = vdt_id
GROUP BY 1,2,3,5,6,7,8;

