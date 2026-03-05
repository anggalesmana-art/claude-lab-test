   declare vdt_id date default @vdt_id;

--IM3

---------------- sso &  sso_pjp ----------------
delete from `data-bi-prd-935c.bi_dev`.ioh_snd_master_kpi_detail where kpi in ('sso_pjp', 'sso_all') and brand = 'IM3' and dt_id = vdt_id;
insert into `data-bi-prd-935c.bi_dev`.ioh_snd_master_kpi_detail 
with 
ga as (
    select *  from 
            (
                select a.msisdn, a.dt_id ga_dt, a.site_id, organization_id, flag_quality, main_price_acm2, flag_sp,channel_grp
                 from `data-bi-prd-935c.bi_mart`.rgs_ga_90d_dly_govt a
                join (select *
                        from `data-bi-prd-935c.bi_mart`.rgs_ga_channel_mth_govt 
                        where ga_dt between date_trunc(vdt_id,month) and vdt_id 
                      )b
                on a.msisdn = b.msisdn and a.dt_id = b.ga_dt
                where dt_id between date_trunc(vdt_id,month) and vdt_id 
                and (churn_back = 'NO' or recycled = 'YES')
            )x 
        ),
pjp as ( select 
            distinct id_outlet
        from `data-bi-prd-935c.bi_snd.pre_ref_outlet_mapping_im3`
        where parse_date('%Y%m%d',concat(cast(mth_id as string),'01')) = date_trunc(vdt_id,month)
        ),
nbs as (
        select * from 
        (
        select *, 
        ROW_NUMBER() OVER (partition by organization_id, date_trunc(dt_id,month) ORDER BY dt_id desc) AS rn 
        from  `data-bi-prd-935c.bi_mart`.outlet_loc_ns 
        where date_trunc(dt_id,month) = date_trunc(vdt_id,month)
        )a
        where rn = 1
        )
-- SSO PJP
select 'IM3' brand, 'site' level, id as level_value, 
    sum(cast(sso as numeric)) value, 
    'mtd' as time_flag, 
     timestamp(current_datetime('+7')) as insert_date,
    'sso_pjp' as kpi_id, 
    vdt_id as dt_id
from
(
    select site_id id, count(distinct organization_id) sso 
    from
    (
        select a.organization_id, b.site_id
        from ga a 
            left join nbs b   
        on a.organization_id=b.organization_id
            join pjp c 
        on a.organization_id=c.id_outlet
    )a
    group by 1
)a
group by 1,2,3,5,6,7,8
------- 
union all 
-- SSO 
select 'IM3' brand, 'site' level, id as level_value, 
    sum(cast(sso as numeric)) value, 
    'mtd' as time_flag, 
     timestamp(current_datetime('+7')) as insert_date,
    'sso_all' as kpi_id, 
    vdt_id as dt_id
from
(
    select site_id id, count(distinct organization_id) sso 
    from
    (
        select a.organization_id, b.site_id
        from ga a 
            left join nbs b   
        on a.organization_id=b.organization_id
    )a
    group by 1
)a
group by 1,2,3,5,6,7,8
;


---------------- sso_pjp_outlet ----------------
delete from `data-bi-prd-935c.bi_dev`.ioh_snd_master_kpi_detail where kpi in ('sso_pjp_outlet') and brand = 'IM3' and dt_id = vdt_id;

insert into `data-bi-prd-935c.bi_dev`.ioh_snd_master_kpi_detail 
with 
ga as (
    select *  from 
            (
                select a.msisdn, a.dt_id ga_dt, a.site_id, organization_id, flag_quality, main_price_acm2, flag_sp,channel_grp
                 from `data-bi-prd-935c.bi_mart`.rgs_ga_90d_dly_govt a
                join (select *
                        from `data-bi-prd-935c.bi_mart`.rgs_ga_channel_mth_govt 
                        where ga_dt between date_trunc(vdt_id,month) and vdt_id 
                      )b
                on a.msisdn = b.msisdn and a.dt_id = b.ga_dt
                where dt_id between date_trunc(vdt_id,month) and vdt_id 
                and (churn_back = 'NO' or recycled = 'YES')
            )x 
        ),
pjp as ( select 
            distinct id_outlet
        from `data-bi-prd-935c.bi_snd.pre_ref_outlet_mapping_im3`
        where parse_date('%Y%m%d',concat(cast(mth_id as string),'01')) = date_trunc(vdt_id,month)
        )
-- SSO OUTLET
select 'IM3' brand, 'outlet' level, organization_id as level_value, 
    count(organization_id)  value, 
    'mtd' as time_flag, 
     timestamp(current_datetime('+7')) as insert_date,
    'sso_pjp_outlet' as kpi_id, 
    vdt_id as dt_id
from
(
        select distinct a.organization_id
        from ga a 
            join pjp c 
        on a.organization_id=c.id_outlet
)a
group by 1,2,3,5,6,7,8
;

--3ID

--- depends on GA jobs 


DELETE FROM `data-bi-prd-935c.bi_dev`.ioh_snd_master_kpi_detail
WHERE kpi IN ('sso_pjp_dly') AND dt_id = vdt_id and brand = '3ID';


INSERT INTO `data-bi-prd-935c.bi_dev`.ioh_snd_master_kpi_detail
SELECT '3ID' as brand,
'site_id' level,
x.site_id level_value,
COUNT(DISTINCT a.partner_qr_cd) value,
'dly' time_flag,
timestamp(current_datetime('+7')) insert_date,
'sso_pjp_dly' kpi,
vdt_id dt_id
FROM `data-bi-prd-935c.bi_mart`.fct_ga_site_id_v3 a
INNER JOIN (
    SELECT
        parse_date('%Y%m%d',concat(cast(mth_id as string),'01')) AS mth_id,
        retailer_qrcode AS qr_code,
        mp3_name AS partner_name,
        branch,
        se_partnerid AS dse_code
    FROM `data-bi-prd-935c.bi_snd.pre_ref_outlet_mapping_3id` b
    WHERE parse_date('%Y%m%d',concat(cast(mth_id as string),'01')) = date_trunc(vdt_id,month)
) b ON date_trunc(a.dt,month) = b.mth_id AND a.partner_qr_cd = b.qr_code
LEFT JOIN `data-bi-prd-935c.bi_mart`.stg_v_map_tgt_ret_details_hist x ON a.dt = x.dt AND a.partner_qr_cd = x.ret_qr_cd
WHERE a.dt= vdt_id 
GROUP BY 1,2,3,5,7,8;



INSERT INTO `data-bi-prd-935c.bi_dev`.ioh_snd_master_kpi_detail
SELECT '3ID' as brand,
'outlet' level,
a.partner_qr_cd level_value,
COUNT(DISTINCT a.partner_qr_cd) value,
'dly' time_flag,
timestamp(current_datetime('+7')) insert_date,
'sso_pjp_dly' kpi,
vdt_id  dt_id
FROM `data-bi-prd-935c.bi_mart`.fct_ga_site_id_v3 a
INNER JOIN (
    SELECT
        parse_date('%Y%m%d',concat(cast(mth_id as string),'01')) AS mth_id,
        retailer_qrcode AS qr_code,
        mp3_name AS partner_name,
        branch,
        se_partnerid AS dse_code
    FROM `data-bi-prd-935c.bi_snd.pre_ref_outlet_mapping_3id` b
    WHERE parse_date('%Y%m%d',concat(cast(mth_id as string),'01')) = date_trunc(vdt_id,month)
) b ON date_trunc(a.dt,month) = b.mth_id AND a.partner_qr_cd = b.qr_code
LEFT JOIN `data-bi-prd-935c.bi_mart`.stg_v_map_tgt_ret_details_hist x ON a.dt = x.dt AND a.partner_qr_cd = x.ret_qr_cd
WHERE a.dt= vdt_id
GROUP BY 1,2,3,5,7,8;
