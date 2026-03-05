   declare vdt_id date default @vdt_id;

--IM3
--------------------------------------
---------- SITE QSSO M0 ------------
--------------------------------------
delete from `data-bi-prd-935c.bi_dev`.ioh_snd_master_kpi_detail where kpi = 'site_qsso_m0' and dt_id = vdt_id and brand = 'IM3';
insert into `data-bi-prd-935c.bi_dev`.ioh_snd_master_kpi_detail
select 'IM3' brand, 'site' level, site_id as level_value, 
    cast(count(case when qsso3 >=1 then site_id end) as numeric) value, 
    'mtd' as time_flag, 
     timestamp(current_datetime('+7')) as insert_date,
     'site_qsso_m0' as kpi_id, 
    vdt_id dt_id
from
    (
        select 
            month_id mth,
          --  region, area, cluster, micro_cluster,
            addr_site.site_id,
            sum((ifnull(a.cnt_outlet,0)+ifnull(b.cnt_outlet,0))) qsso3
        from 
            (
                select month_id, site_id, new_site_id, old_site_id 
                from `data-bi-prd-935c.bi_mart`.total_site_ioh_mth
                where month_id = date_trunc(vdt_id,month)
                and addressable like '%ADDRESSABLE%SITE%'
                and total_site_im3=1
            ) addr_site
        left join
            (
                select 
                    mth,
                    site_id site_id_outlet,
                    count(organization_id) cnt_outlet
                from 
                    (
                        select 
                            date_trunc(a.dt_id,month) mth,
                            c.site_id,
                            b.organization_id,
                            count(a.msisdn) sub
                        from `data-bi-prd-935c.bi_mart`.rgs_ga_90d_dly_govt a
                        join `data-bi-prd-935c.bi_mart`.rgs_ga_channel_mth_govt b
                            on a.msisdn = b.msisdn
                            and a.dt_id = b.ga_dt
                        join
                            (
                                select 
                                    distinct
                                    parse_date('%Y%m%d',concat(cast(mth_id as string),'01')) mth_id,
                                    id_outlet
                                from `data-bi-prd-935c.bi_snd.pre_ref_outlet_mapping_im3`
                                where parse_date('%Y%m%d',concat(cast(mth_id as string),'01')) in 
                                    (
                                        date_trunc(vdt_id,month)
                                    )
                                    and mth_id is not null
                            ) pjp
                            on b.organization_id = pjp.id_outlet
                            and b.month_id = pjp.mth_id
                        left join 
                            (
                                select * 
                                from
                                    (
                                        select
                                            dt_id,
                                            a.site_id,
                                            organization_id,
                                            organization_name,
                                            ROW_NUMBER() OVER (partition by organization_id, date_trunc(a.dt_id,month) ORDER BY dt_id desc) AS rn 
                                        from
                                            `data-bi-prd-935c.bi_mart`.outlet_loc_ns a
                                        where                                               
                                     date_trunc(a.dt_id,month) = date_trunc(vdt_id,month) and a.dt_id <= vdt_id
                                    ) a 
                                where rn = 1
                            ) c
                            on b.organization_id = c.organization_id 
                            and b.month_id = date_trunc(c.dt_id,month)
                        where 
                            (
                                date_trunc(a.dt_id,month) = date_trunc(vdt_id,month) and a.dt_id <= vdt_id)  
                        and (churn_back = 'NO' OR recycled = 'YES')
                        -- and b.main_price_acm2 >= 10000
                        group by 1,2,3
                    ) xx
                where sub>=3
                group by 1,2
            ) a
            on addr_site.old_site_id = a.site_id_outlet
            and addr_site.month_id = a.mth 
        left join
            (
                select 
                    mth,
                    site_id site_id_outlet,
                    count(organization_id) cnt_outlet
                from 
                    (
                        select 
                            date_trunc(a.dt_id,month) mth,
                            c.site_id,
                            b.organization_id,
                            count(a.msisdn) sub
                        from `data-bi-prd-935c.bi_mart`.rgs_ga_90d_dly_govt a
                        join `data-bi-prd-935c.bi_mart`.rgs_ga_channel_mth_govt b
                            on a.msisdn = b.msisdn
                            and a.dt_id = b.ga_dt
                        join
                            (
                                select 
                                    distinct
                                    parse_date('%Y%m%d',concat(cast(mth_id as string),'01')) mth_id,
                                    id_outlet
                                from `data-bi-prd-935c.bi_snd.pre_ref_outlet_mapping_im3`
                                where parse_date('%Y%m%d',concat(cast(mth_id as string),'01')) in 
                                    (
                                         date_trunc(vdt_id,month)
                                    )
                                    and mth_id is not null
                            ) pjp
                            on b.organization_id = pjp.id_outlet
                            and b.month_id = pjp.mth_id
                        left join 
                            (
                                select * 
                                from
                                    (
                                        select
                                            dt_id,
                                            a.site_id,
                                            organization_id,
                                            organization_name,
                                            ROW_NUMBER() OVER (partition by organization_id, date_trunc(a.dt_id,month) ORDER BY dt_id desc) AS rn 
                                        from
                                            `data-bi-prd-935c.bi_mart`.outlet_loc_ns a
                                        where
                                            (
                                date_trunc(a.dt_id,month) = date_trunc(vdt_id,month) and a.dt_id <= vdt_id  
                                            )
                                    ) a 
                                where rn = 1
                            ) c
                            on b.organization_id = c.organization_id 
                            and b.month_id = date_trunc(c.dt_id,month)
                        where 
                            (
                                date_trunc(a.dt_id,month) = date_trunc(vdt_id,month) and a.dt_id <= vdt_id  
                            )
                        and (churn_back = 'NO' OR recycled = 'YES')
                        -- and b.main_price_acm2 >= 10000
                        group by 1,2,3
                    ) xx
                where sub>=3
                group by 1,2
            ) b
            on addr_site.site_id = b.site_id_outlet
            and addr_site.month_id = b.mth 
        group by 1,2
    ) xx
group by 1,2,3,5,6,7,8
;


--3ID
create or replace table `data-bi-prd-935c.bi_stg`.tmp_nbs as
select ret_qr_cd,site_id
from
(
select dt,ret_qr_cd,site_id,row_number() over (partition by ret_qr_cd order by dt desc) rnk
from `data-bi-prd-935c.bi_mart`.stg_v_map_tgt_ret_details_hist
where site_id <> ''
and dt between date_trunc(vdt_id,month) and vdt_id
) x
where rnk=1;


DELETE FROM `data-bi-prd-935c.bi_dev`.ioh_snd_master_kpi_detail
WHERE kpi IN
(
'qsso_m0'
) 
 AND dt_id = vdt_id and brand = '3ID';


INSERT INTO `data-bi-prd-935c.bi_dev`.ioh_snd_master_kpi_detail 
-- This CTE first calculates the number of gross adds (GAGA) for each outlet for the month.
WITH outlet_monthly_gaga AS (
    SELECT
      coalesce(a.book_qrcode_final, a.partner_qr_cd) partner_qr_cd ,
        c.site_id,
        count(DISTINCT a.sbscrptn_ek_id) AS gaga_count
    FROM `data-bi-prd-935c.bi_mart.snd_rgu_ga_new_detail` a
    INNER JOIN (
        SELECT DISTINCT
            retailer_qrcode,
            parse_date('%Y%m',cast(mth_id as string)) mth_id
        FROM `data-bi-prd-935c.bi_snd.pre_ref_outlet_mapping_3id`
        WHERE parse_date('%Y%m',cast(mth_id as string)) = DATE_TRUNC(vdt_id, MONTH)
    ) b ON CAST(b.retailer_qrcode AS STRING) = CAST(coalesce(a.book_qrcode_final, a.partner_qr_cd) AS STRING)
    LEFT JOIN `data-bi-prd-935c.bi_stg.tmp_nbs` c ON coalesce(a.book_qrcode_final, a.partner_qr_cd) = c.ret_qr_cd
    WHERE
        a.load_dt_sk_id BETWEEN DATE_TRUNC(vdt_id, MONTH) AND vdt_id
    GROUP BY
        coalesce(a.book_qrcode_final, a.partner_qr_cd),
        c.site_id
)
-- The final SELECT counts the number of qualified outlets (gaga_count >= 3) and
-- aggregates this count by site_id.
SELECT
    '3ID' AS brand_id,
    'site_id' AS level_id,
    coalesce(site_id, 'null') AS level_value,
    count(DISTINCT partner_qr_cd) AS kpi_value,
    'mtd' AS period_type,
    CURRENT_TIMESTAMP() AS uVDate_dttm,
    'qsso_m0' AS kpi_name,
    vdt_id AS dt_id
FROM outlet_monthly_gaga
WHERE gaga_count >= 3
GROUP BY
    coalesce(site_id, 'null');
