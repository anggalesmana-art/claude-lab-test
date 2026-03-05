   declare vdt_id date default @vdt_id;
--IM3

---------------- total_uro & uro_pjp ----------------

delete from `data-bi-prd-935c.bi_dev`.ioh_snd_master_kpi_detail where dt_id = vdt_id and kpi in('total_uro','uro_pjp') and brand ='IM3';
insert into `data-bi-prd-935c.bi_dev`.ioh_snd_master_kpi_detail
with uro  as (
    select 
        site_id id,
        organization_id,
        count(organization_id) value
    from `data-bi-prd-935c.bi_mart`.seratus_q_uro_fdv_mtd a
    where dt_id in (vdt_id)
    group by 1,2
            ),
outlet_mapping as (select distinct id_outlet from `data-bi-prd-935c.bi_snd.pre_ref_outlet_mapping_im3` where parse_date('%Y%m%d',concat(cast(mth_id as string),'01')) = date_trunc(vdt_id,month))
-- uro pjp 
select 'IM3' brand, 'site' level, id as level_value, 
    sum(cast(value as numeric)) value, 
    'mtd' as time_flag, 
     timestamp(current_datetime('+7')) as insert_date,
    'uro_pjp' as kpi_id, 
    vdt_id as dt_id
from uro a
    join outlet_mapping b
  on a.organization_id=b.id_outlet
group by 1,2,3,5,6,7,8
union all
-- total uro 
select 'IM3' brand, 'site' level, id as level_value, 
    sum(cast(value as numeric)) value, 
    'mtd' as time_flag, 
     timestamp(current_datetime('+7')) as insert_date,
    'total_uro' as kpi_id, 
    vdt_id as dt_id
from uro a
    left join outlet_mapping b
  on a.organization_id=b.id_outlet
group by 1,2,3,5,6,7,8
; 

--3ID
-- URO PJP
    DELETE FROM `data-bi-prd-935c.bi_dev`.ioh_snd_master_kpi_detail
    WHERE kpi IN ('uro_pjp') AND dt_id = vdt_id and brand = '3ID';
    INSERT INTO `data-bi-prd-935c.bi_dev`.ioh_snd_master_kpi_detail   
    SELECT '3ID' as brand,
    'outlet' level,
    partner_qr_cd level_value,
    1 value,
    'mtd' time_flag,
    CURRENT_TIMESTAMP() insert_date,
    'uro_pjp' kpi,
    trx_dt_sk_id dt_id 
    FROM `data-bi-prd-935c.bi_mart.ret_uro_quro_indicator_dly` a 
    INNER JOIN (
        SELECT 
            parse_date('%Y%m',cast(mth_id as string)) AS mth_id,
            retailer_qrcode AS qr_code,
            mp3_name AS partner_name,
            branch,
            se_partnerid AS dse_code
        FROM `data-bi-prd-935c.bi_snd.pre_ref_outlet_mapping_3id` b
        WHERE parse_date('%Y%m',cast(mth_id as string)) = DATE_TRUNC(vdt_id, MONTH)
    ) b ON DATE_TRUNC(a.trx_dt_sk_id, MONTH) = b.mth_id AND a.partner_qr_cd = b.qr_code
    WHERE trx_dt_sk_id = vdt_id 
      AND ret_uro_ind = 'Y'
    GROUP BY 1,2,3,5,7,8;

-- URO ALL
  DELETE FROM `data-bi-prd-935c.bi_dev`.ioh_snd_master_kpi_detail
    WHERE kpi IN ('uro_all') AND dt_id = vdt_id and brand = '3ID';
    INSERT INTO `data-bi-prd-935c.bi_dev`.ioh_snd_master_kpi_detail   
    SELECT '3ID' as brand,
    'outlet' level,
    partner_qr_cd level_value,
    1 value,
    'mtd' time_flag,
    CURRENT_TIMESTAMP() insert_date,
    'uro_all' kpi,
    vdt_id dt_id 
    FROM `data-bi-prd-935c.bi_mart.ret_uro_quro_indicator_dly` a 
    WHERE trx_dt_sk_id = vdt_id 
      AND ret_uro_ind = 'Y'
    GROUP BY 1,2,3,5,7,8;
    