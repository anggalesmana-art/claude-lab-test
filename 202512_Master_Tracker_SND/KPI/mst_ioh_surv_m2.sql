   declare vdt_id date default @vdt_id;

--IM3
---------------- survialance  ------------------

delete `data-bi-prd-935c.bi_dev`.ioh_snd_master_kpi_detail where kpi = 'surv_m2' and brand = 'IM3' and dt_id = vdt_id;
insert into `data-bi-prd-935c.bi_dev`.ioh_snd_master_kpi_detail
with surv as (
        select 
            ga.site_id,
            'SITE' flag,
            count(usg.msisdn) amount,
            'FM' mthf,
            vdt_id as_of_dt,
            date_trunc(usg.dt_id,month) mth,
            (case 
                when date_trunc(ga.dt_id,month)=date_trunc(usg.dt_id-interval 1 month,month) then 'SURV_M1'
                when date_trunc(ga.dt_id,month)=date_trunc(usg.dt_id-interval 2 month,month) then 'SURV_M2'
                when date_trunc(ga.dt_id,month)=date_trunc(usg.dt_id-interval 3 month,month) then 'SURV_M3'
            end) parameter
        from
            (
                select site_id, msisdn, dt_id
                from (
                        select dt_id, site_id, msisdn
                        from `data-bi-prd-935c.bi_mart`.rgs_ga_90d_dly
                        where dt_id >= '2022-01-01' and dt_id <='2022-05-31'
                        and (churn_back = 'NO' OR recycled = 'YES')
                        union all
                        select dt_id, site_id, msisdn
                        from `data-bi-prd-935c.bi_mart`.rgs_ga_90d_dly_govt
                        where dt_id >= '2022-06-01'
                        and (churn_back = 'NO' OR recycled = 'YES')
                    )xx
                where date_trunc(dt_id,month) in (date_trunc(vdt_id- interval 1 month,month) 
                                            ,date_trunc(vdt_id- interval 2 month,month)
                                            ,date_trunc(vdt_id- interval 3 month,month)
                                            ,date_trunc(vdt_id- interval 4 month,month)
                                            ,date_trunc(vdt_id- interval 5 month,month)
                                            )
            ) ga
        left join   
            (   
                select msisdn, dt_id, total_rev 
                from `data-bi-prd-935c.bi_mart`.rgs_mtd_govt
                where dt_id in (vdt_id)
            ) usg   
            on ga.msisdn = usg.msisdn
        where
            1=1
            and date_trunc(usg.dt_id,month) is not null
        group by 1,2,4,5,6,7
    )
-- surv_m2 
select 'IM3' brand, 'site' level, site_id as level_value, 
    sum(cast(amount as numeric)) value, 
    'mtd' as time_flag, 
     timestamp(current_datetime('+7')) as insert_date,
    'surv_m2' as kpi_id, 
    vdt_id as dt_id
from surv
where parameter = 'SURV_M2'
group by 1,2,3,5,6,7,8
;


--3ID
    -- ========== SURV_M2 and GA_M2 KPIs ==========
    DELETE FROM `data-bi-prd-935c.bi_dev`.ioh_snd_master_kpi_detail
    WHERE kpi IN ('surv_m2', 'ga_m2') AND dt_id = vdt_id and brand = '3ID';
    
  /*  INSERT INTO ioh_snd_master_kpi_detail   
    SELECT '3ID' as brand,
    'site_id' level,
    site_id level_value,
    sum(value),
    'mtd' time_flag,
    timestamp(current_datetime('+7')) insert_date,
    CASE WHEN kpi_code = 'M2S_MTD' THEN 'surv_m2' ELSE 'ga_m2' END kpi,
    load_dt_sk_id dt_id 
    FROM `data-bi-prd-935c.bi_mart`.project_ioh_kpi_daily_tracker_site -- select * From project_ioh_kpi_daily_tracker_site limit 10 
    WHERE load_dt_sk_id = vdt_id
      AND kpi_code IN ('M2S_MTD','GA_M2S_MTD') 
    GROUP BY 1,2,3,5,7,8;
    */
  INSERT INTO `data-bi-prd-935c.bi_dev`.ioh_snd_master_kpi_detail  
    SELECT '3ID' as brand,
    'site_id' level,
    site_id level_value,
    sum(value),
    'mtd' time_flag,
    timestamp(current_datetime('+7')) insert_date,
    CASE WHEN kpi_code = 'M2S_MTD' THEN 'surv_m2' ELSE 'ga_m2' END kpi,
    load_dt_sk_id dt_id 
    FROM
(

select vdt_id as load_dt_sk_id, 'H3I' as entity, 'M2S_MTD' as kpi_code, 'IOH' as definition,
vdt_id dt, b.site_id, count(distinct a.sbscrptn_ek_id) as value, 'SITE ROLLING 90' as remark, current_date as created_dtm
from 
(
 select distinct a.sbscrptn_ek_id
 from `data-bi-prd-935c.bi_mart`.fct_rgu_ioh_nik_mstr a
 where tag = 'rgu_daily'
 and dt between date_trunc(vdt_id,month) and vdt_id

 union distinct

 select distinct a.sbscrptn_ek_id
 from `data-bi-prd-935c.bi_mart`.fct_ioh_rgu_daily_nik_add a --changes start on 23 May 2022 (add the daily RGU from this table)
 where tag = 'rgu_daily'
 and dt between date_trunc(vdt_id,month) and vdt_id
 
--  union

--  select distinct a.sbscrptn_ek_id
--  from `data-bi-prd-935c.bi_mart`.fct_rgu_voice_sms_free a
--  where a.dt >= date_trunc(vdt_id,month)
--  and a.dt <= vdt_id
) a
join 
(
 --Change start 01 Mar 2022 onwards
 select distinct sbscrptn_ek_id, site_id
 from `data-bi-prd-935c.bi_mart`.fct_ga_site_id
 where date_trunc(dt,month) = date_trunc(vdt_id-interval 2 month,month)
) b on a.sbscrptn_ek_id = b.sbscrptn_ek_id
group by 1,2,3,4,5,6,8,9
union all 
select vdt_id as laod_dt_sk_id, 'H3I' as entity, 'GA_M2S_MTD' as kpi_code, 'IOH' as definition,
vdt_id as dt, a.site_id, count(distinct a.sbscrptn_ek_id) as value, 'SITE ROLLING 90' as remark, current_date as created_dtm
from 
(
 select distinct sbscrptn_ek_id, site_id
 from `data-bi-prd-935c.bi_mart`.fct_ga_site_id
 where date_trunc(dt,month) = date_trunc(vdt_id-interval 2 month,month)
) a
group by 1,2,3,4,5,6,8,9
) b
   GROUP BY 1,2,3,5,7,8; 
