   declare vdt_id date default @vdt_id;

--IM3
---------------- Q-URO & SITE with 5 QURO ----------------
delete from `data-bi-prd-935c.bi_dev`.ioh_snd_master_kpi_detail where kpi in ('site_5quro', 'quro')
and dt_id = vdt_id and brand = 'IM3';
insert into `data-bi-prd-935c.bi_dev`.ioh_snd_master_kpi_detail
with
quro as (
            select dt_id, site_id,
               sum(q_uro_sp+q_uro_fdv) quro
            from `data-bi-prd-935c.bi_mart`.seratus_q_uro_fdv_mtd a
                join (select distinct id_outlet from `data-bi-prd-935c.bi_snd.pre_ref_outlet_mapping_im3` where date_trunc(parse_date('%Y%m%d',concat(cast(mth_id as string),'01')),month) = date_trunc(vdt_id,month)) b -- and status = 'Active'
            on a.organization_id=b.id_outlet
            where dt_id = vdt_id 
            group by 1,2 
        ),
    site_address as (
            select month_id, site_id, new_site_id, old_site_id 
            from `data-bi-prd-935c.bi_mart`.total_site_ioh_mth
            where month_id = date_trunc(vdt_id,month)
            and addressable like '%ADDRESSABLE%SITE%'
            and total_site_im3=1
            )

-- SITE 5 QURO 
select 'IM3' brand, 'site' level, site_id as level_value, 
    sum(cast(`5quro` as numeric)) value,
    'mtd' as time_flag, 
     timestamp(current_datetime('+7')) as insert_date,
    'site_5quro' as kpi_id, 
    vdt_id as dt_id
from 
        (
        select a.site_id, sum(case when quro>=5 then 1 else 0 end) `5quro`
                from site_address a
            join quro b 
                on a.site_id=b.site_id
                group by 1 
        )a
group by 1,2,3,5,6,7,8
union all 
-- QURO 
select 'IM3' brand, 'site' level, site_id as level_value, 
    cast(sum(quro.quro) as numeric) value, 
    'mtd' as time_flag, 
     timestamp(current_datetime('+7')) as insert_date,
    'quro' as kpi_id, 
    vdt_id dt_id
from quro
group by 1,2,3,5,6,7,8
;

DELETE FROM `data-bi-prd-935c.bi_dev`.ioh_snd_master_kpi_detail
    WHERE kpi IN ('quro_all','quro_pjp') AND dt_id = vdt_id and brand = '3ID';

 -- URO PJP
    INSERT INTO `data-bi-prd-935c.bi_dev`.ioh_snd_master_kpi_detail   
    SELECT '3ID' as brand,
    'outlet' level,
    partner_qr_cd level_value,
    1 value,
    'mtd' time_flag,
    CURRENT_TIMESTAMP() insert_date,
    'quro_pjp' kpi,
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
      AND ret_quro_ind = 'Y'
    GROUP BY 1,2,3,5,7,8;



 -- URO PJP
    INSERT INTO `data-bi-prd-935c.bi_dev`.ioh_snd_master_kpi_detail   
    SELECT '3ID' as brand,
    'outlet' level,
    partner_qr_cd level_value,
    1 value,
    'mtd' time_flag,
    CURRENT_TIMESTAMP() insert_date,
    'quro_all' kpi,
    trx_dt_sk_id dt_id 
    FROM `data-bi-prd-935c.bi_mart.ret_uro_quro_indicator_dly` a 
    WHERE trx_dt_sk_id = vdt_id 
      AND ret_quro_ind = 'Y'
    GROUP BY 1,2,3,5,7,8;
