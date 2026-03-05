DECLARE vdt_id DATE DEFAULT @vdt_id;


delete from  `data-bi-prd-935c.bi_mart`.kpi_site_wise_dly
where dt_id = vdt_id and kpi_id in ('SITE011',
'SITE014',
'SND030',
'SND083',
'SND082',
'SITE017');



--------------- HG KPI SITEWISE -----------------

-------------------------------------------------
--------------- Q URO ---------------------------
--Quality Unique Recharging Outlet SITEWISE------
-------------------------------------------------
insert into `data-bi-prd-935c.bi_mart`.kpi_site_wise_dly
with sites as (
    select site_id,old_site_id,new_site_id
    from `data-bi-prd-935c.bi_mart`.total_site_ioh_mth
    where date(month_id) = date_trunc(vdt_id,month)
    and addressable like '%ADDRESSABLE%SITE%'
    and total_site_im3 = 1
),
quro as (
    select dt_id,site_id,organization_id,sum(q_uro_sp+q_uro_fdv) q_uro,sum(q_uro_sp) q_uro_sp,sum(q_uro_fdv) q_uro_fdv
    from `data-bi-prd-935c.bi_mart`.seratus_q_uro_fdv_mtd
    where dt_id = vdt_id
    and (q_uro_sp > 0 or q_uro_fdv > 0)
    group by 1,2,3
),
quro_trx as (
    select organization_id,trx_type,flag_sp,main_price,count(1) hits,sum(amount_debit) amt
    from `data-bi-prd-935c.bi_mart`.seratus_uro_inject_detail_trx_fdv 
    where dt_id between date_trunc(vdt_id,month) and vdt_id
    group by 1,2,3,4
)
--Q-URO
select 'ret_quro' kpi_code,'IM3' brand,site_id,count(organization_id) metric,current_datetime('+7') process_dt,'SND030' kpi_id,dt_id
from quro
where q_uro > 0
group by 1,2,3,5,6,7
union all
--SITE W/O Q-URO
select 'site_wo_quro' kpi_code,'IM3' brand,a.site_id,count(a.site_id) metric,current_datetime('+7') process_dt,'SITE011' kpi_id,vdt_id dt_id
from sites a
left join 
    (
        select distinct site_id
        from quro
        where q_uro > 0
    ) b
    on a.new_site_id=b.site_id or a.old_site_id=b.site_id
  where b.site_id is null
group by 1,2,3,5,6,7
union all
--SITE >=5 Q-URO
select 'site_5quro' kpi_code,'IM3' brand,a.site_id,count(a.site_id) metric,current_datetime('+7') process_dt,'SITE014' kpi_id,vdt_id dt_id
from sites a
join
    (
        select site_id,sum(q_uro) q_uro
        from quro
        group by 1
    ) b
    on a.new_site_id=b.site_id or a.old_site_id=b.site_id
where q_uro >= 5
group by 1,2,3,5,6,7
union all
--SITE WITH Q-URO
select 'site_quro' kpi_code,'IM3' brand,a.site_id,count(a.site_id) metric,current_datetime('+7') process_dt,'SITE017' kpi_id,vdt_id dt_id
from sites a
join
    (
        select site_id,sum(q_uro) q_uro
        from quro
        group by 1
    ) b
    on a.new_site_id=b.site_id or a.old_site_id=b.site_id
where q_uro >= 1
group by 1,2,3,5,6,7
union all
--Q-URO >= 10 SPV
select 'ret_quro_10vou' kpi_code,'IM3' brand,a.site_id,count(a.organization_id) metric,current_datetime('+7') process_dt,'SND082' kpi_id,dt_id
from
    (
        select dt_id,site_id,organization_id
        from quro
    ) a
join
    (
        select organization_id,sum(hits) hits
        from quro_trx
        where trx_type like 'VOUCHER%'
        group by 1
    ) b
    on a.organization_id=b.organization_id
where hits>=10
group by 1,2,3,5,6,7
union all
--Q-URO with min inject 50K
select 'ret_quro_inj50k' kpi_code,'IM3' brand,a.site_id,count(a.organization_id) metric,current_datetime('+7') process_dt,'SND083' kpi_id,dt_id
from
    (
        select dt_id,site_id,organization_id
        from quro
    ) a
join
    (
        select organization_id,sum(hits) hits
        from quro_trx
        where trx_type ='SP' and main_price>=50000 and flag_sp='OLD'
        group by 1
    ) b
    on a.organization_id=b.organization_id
group by 1,2,3,5,6,7
;


delete from  `data-bi-prd-935c.bi_mart`.kpi_site_wise_dly
where dt_id = vdt_id and kpi_id in (
'BSM022',
'BSM023',
'BSM025',
'BSM026',
'BSM024');

-------------------------------------------------
----------------- VLR ---------------------------
-------------------------------------------------
insert into `data-bi-prd-935c.bi_mart`.kpi_site_wise_dly
with vlr as (
    select dt_id,kpi_nm,subs_flag,usg_flag,site_id,sum(metric) metric
    from `data-bi-prd-935c.bi_mart`.vlr_activity_smy
    where dt_id=vdt_id
    group by 1,2,3,4,5
)
-- VLR Daily
select 'vlr_daily' kpi_code,'IM3' brand,site_id,sum(metric) metric,current_datetime('+7') process_dt,'BSM022' kpi_id,dt_id
from vlr
where subs_flag like 'Prepaid%'
and kpi_nm = 'VLR_DAILY'
group by 1,2,3,5,6,7
union all
-- VLR 30D
select 'vlr30' kpi_code,'IM3' brand,site_id,sum(metric) metric,current_datetime('+7') process_dt,'BSM023' kpi_id,dt_id
from vlr
where subs_flag like 'Prepaid%'
and kpi_nm = 'VLR_30D'
group by 1,2,3,5,6,7
union all
-- VLR MO
select 'vlr_mo' kpi_code,'IM3' brand,site_id,sum(metric) metric,current_datetime('+7') process_dt,'BSM024' kpi_id,dt_id
from vlr
where subs_flag like 'Prepaid%'
and kpi_nm = 'VLR_DAILY'
and usg_flag='MO Only'
group by 1,2,3,5,6,7
union all
-- VLR MT
select 'vlr_mt' kpi_code,'IM3' brand,site_id,sum(metric) metric,current_datetime('+7') process_dt,'BSM025' kpi_id,dt_id
from vlr
where subs_flag like 'Prepaid%'
and kpi_nm = 'VLR_DAILY'
and usg_flag='MT Only'
group by 1,2,3,5,6,7
union all
-- VLR MO+MT
select 'vlr_momt' kpi_code,'IM3' brand,site_id,sum(metric) metric,current_datetime('+7') process_dt,'BSM026' kpi_id,dt_id
from vlr
where dt_id=vdt_id
and subs_flag like 'Prepaid%'
and kpi_nm = 'VLR_DAILY'
and usg_flag='MO+MT'
group by 1,2,3,5,6,7;


delete from  `data-bi-prd-935c.bi_mart`.kpi_site_wise_dly
where dt_id = vdt_id and kpi_id in (
'BSM014',
'BSM007',
'BSM016',
'BSM005',
'BSM011',
'BSM012',
'BSM015',
'BSM020',
'BSM006',
'BSM021'
);
-------------------------------------------------
----------------- BSM ---------------------------
-------------------------------------------------

insert into `data-bi-prd-935c.bi_mart`.kpi_site_wise_dly
with rgu_ga as (
    select dt_id,site_id,count(msisdn) metric
    FROM `data-bi-prd-935c.bi_mart`.rgs_ga_90d_dly_govt
    WHERE dt_id = vdt_id
        AND (churn_back = 'NO' OR recycled = 'YES')
    group by 1,2
),
churn30 as (
    select dt_id,site_id,count(msisdn) metric
    FROM `data-bi-prd-935c.bi_mart`.rgs_churn_30d_dly_govt
    WHERE dt_id = vdt_id
    group by 1,2
),
churn90 as (
    select dt_id,site_id,count(msisdn) metric
    FROM `data-bi-prd-935c.bi_mart`.rgs_churn_90d_dly_govt
    WHERE dt_id = vdt_id
    group by 1,2
),
churn_back90 as (
    select dt_id,site_id,count(msisdn) metric
    FROM `data-bi-prd-935c.bi_mart`.rgs_churn_back_90d_govt
    WHERE dt_id = vdt_id
    group by 1,2
),
churn_back30 as (
    select dt_id,site_id,sum(metric) metric
    from (
        select dt_id,site_id,count(msisdn) metric
        FROM `data-bi-prd-935c.bi_mart`.rgs_churn_back_30d_govt
        WHERE dt_id = vdt_id
        group by 1,2
        union all
        select dt_id,site_id,metric
        from churn_back90
        ) a
    group by 1,2
),
rgu30 as (
    select dt_id,site_id,tenure,sum(subs) metric
    FROM `data-bi-prd-935c.bi_mart`.rgs_30d_govt
    WHERE dt_id = vdt_id
    group by 1,2,3
),
rgu90 as (
    select dt_id,site_id,tenure,sum(subs) metric
    FROM `data-bi-prd-935c.bi_mart`.rgs_90d_govt
    WHERE dt_id = vdt_id
    group by 1,2,3
)
-- RGU GA 30D & 90D
select 'rgu30_gross_add' kpi_code,'IM3' brand,site_id,
metric,current_datetime('+7') process_dt,'BSM005' kpi_id, dt_id
FROM rgu_ga
union all
select 'rgu90_gross_add' kpi_code,'IM3' brand,site_id,
metric,current_datetime('+7') process_dt,'BSM014' kpi_id, dt_id
FROM rgu_ga
union all
-- Gross Churn 30D, Inflow, Base
select 'rgu30_gross_churn' kpi_code,'IM3' brand,site_id,
metric,current_datetime('+7') process_dt,'BSM006' kpi_id, dt_id
FROM churn30
union all
-- Gross Churn 90D, Inflow, Base
select 'rgu90_gross_churn' kpi_code,'IM3' brand,site_id,
metric,current_datetime('+7') process_dt,'BSM015' kpi_id, dt_id
FROM churn90
union all
-- Churn Back 30D, Inflow, Base
select 'rgu30_churn_back' kpi_code,'IM3' brand,site_id,
metric,current_datetime('+7') process_dt,'BSM007' kpi_id, dt_id
FROM churn_back30
union all
-- Churn Back 90D, Inflow, Base
select 'rgu90_churn_back' kpi_code,'IM3' brand,site_id,
metric,current_datetime('+7') process_dt,'BSM016' kpi_id, dt_id
FROM churn_back90
union all
-- Closing RGU 30D, Inflow, Base
select 'rgu30_inflow' kpi_code,'IM3' brand,site_id,
sum(metric) metric,current_datetime('+7') process_dt,'BSM011' kpi_id, dt_id
FROM rgu30
WHERE tenure='Inflow'
GROUP BY 1,2,3,5,6,7
union all
select 'rgu30_base' kpi_code,'IM3' brand,site_id,
sum(metric) metric,current_datetime('+7') process_dt,'BSM012' kpi_id, dt_id
FROM rgu30
WHERE tenure='Base'
GROUP BY 1,2,3,5,6,7
union all
-- Closing RGU 90D, Inflow, Base
select 'rgu90_inflow' kpi_code,'IM3' brand,site_id,
sum(metric) metric,current_datetime('+7') process_dt,'BSM020' kpi_id, dt_id
FROM rgu90
WHERE tenure='Inflow'
GROUP BY 1,2,3,5,6,7
union all
select 'rgu90_base' kpi_code,'IM3' brand,site_id,
sum(metric) metric,current_datetime('+7') process_dt,'BSM021' kpi_id, dt_id
FROM rgu90
WHERE tenure='Base'
GROUP BY 1,2,3,5,6,7;


delete from  `data-bi-prd-935c.bi_mart`.kpi_site_wise_dly
where dt_id = vdt_id and kpi_id in (
'SND072',
'SITE022',
'SND002',
'SND001',
'SND075',
'SND079',
'SND076',
'SND077',
'SND003',
'SND011',
'SND010'
);
-------------------------------------------------
-----------------  RGU GA -----------------------
-------------------------------------------------
insert into `data-bi-prd-935c.bi_mart`.kpi_site_wise_dly
with sites as (
    select site_id,old_site_id,new_site_id
    from `data-bi-prd-935c.bi_mart`.total_site_ioh_mth
    where date(month_id) = date_trunc(vdt_id,month)
    and addressable like '%ADDRESSABLE%SITE%'
    and total_site_im3 = 1
),
ga_channel as (
    select vdt_id dt_id,site_id,channel_grp,flag_quality,flag_acm,organization_id,a.msisdn
    from `data-bi-prd-935c.bi_mart`.rgs_ga_channel_mth_govt a
    join (
        select msisdn,site_id from `data-bi-prd-935c.bi_mart`.rgs_ga_90d_dly_govt
        where dt_id between date_trunc(vdt_id,month) and vdt_id
        and (churn_back='NO' or recycled='YES')
    ) b
    on a.msisdn=b.msisdn
    where a.ga_dt between date_trunc(vdt_id,month) and vdt_id
),
ga_channel_m2s as (
    select site_id,channel_grp,flag_quality,flag_acm,a.msisdn
    from `data-bi-prd-935c.bi_mart`.rgs_ga_channel_mth_govt a
    join (
        select msisdn,site_id from `data-bi-prd-935c.bi_mart`.rgs_ga_90d_dly_govt
        where dt_id between date_trunc(vdt_id-interval 2 month,month)
        and date_trunc(vdt_id-interval 1 month,month) - interval 1 day
        and (churn_back='NO' or recycled='YES')
    ) b
    on a.msisdn=b.msisdn
    where a.ga_dt between date_trunc(vdt_id-interval 2 month,month)
    and date_trunc(vdt_id-interval 1 month,month) - interval 1 day
),
ga_channel_m1s as (
    select site_id,channel_grp,flag_quality,flag_acm,a.msisdn
    from `data-bi-prd-935c.bi_mart`.rgs_ga_channel_mth_govt a
    join (
        select msisdn,site_id from `data-bi-prd-935c.bi_mart`.rgs_ga_90d_dly_govt
        where dt_id between date_trunc(vdt_id-interval 1 month,month)
        and date_trunc(vdt_id,month) - interval 1 day
        and (churn_back='NO' or recycled='YES')
    ) b
    on a.msisdn=b.msisdn
    where a.ga_dt between date_trunc(vdt_id-interval 1 month,month)
    and date_trunc(vdt_id,month) - interval 1 day
),
rgu as (
    select msisdn
    from `data-bi-prd-935c.bi_mart`.rgs_nogovt_dly
    where dt_id between date_trunc(vdt_id,month) and vdt_id
    group by 1
),
dsf as (
SELECT distinct organization_id AS mobo_id, organization_id AS mobii_username, cluster_alloc cluster
from `data-bi-prd-935c.bi_mart`.rgs_ga_channel_mth_govt
WHERE month_id = date_trunc(vdt_id - interval 1 month,month)
  AND channel_grp='DSF'
)
select 'acq_ga' kpi_code,'IM3' brand,site_id,count(msisdn) metric,current_datetime('+7') process_dt,'SND001' kpi_id,dt_id
from ga_channel
group by 1,2,3,5,6,7
union all
--ACQ GA INJECT
select 'acq_ga_inject' kpi_code,'IM3' brand,site_id,count(msisdn) metric,current_datetime('+7') process_dt,'SND002' kpi_id,dt_id
from ga_channel
where flag_quality in ('a. >=10K','b. <10K')
group by 1,2,3,5,6,7
union all
--ACQ GA INJECT HV
select 'acq_ga_inject_hv' kpi_code,'IM3' brand,site_id,count(msisdn) metric,current_datetime('+7') process_dt,'SND003' kpi_id,dt_id
from ga_channel
where flag_quality in ('a. >=10K','b. <10K')
and flag_acm in ('c. >=35k - <50k','d. >=50k')
group by 1,2,3,5,6,7
union all
--GA M2S
select 'acq_qoa_m2s' kpi_code,'IM3' brand,site_id,count(a.msisdn) metric,current_datetime('+7') process_dt,'SND011' kpi_id,vdt_id dt_id
from ga_channel_m2s a
join rgu b
on a.msisdn=b.msisdn
group by 1,2,3,5,6,7
union all
--GA M1S
select 'acq_qoa_m1s' kpi_code,'IM3' brand,site_id,count(a.msisdn) metric,current_datetime('+7') process_dt,'SND010' kpi_id,vdt_id dt_id
from ga_channel_m1s a
join rgu b
on a.msisdn=b.msisdn
group by 1,2,3,5,6,7
union all
--DSF GA
select 'dsf_acq_ga' kpi_code,'IM3' brand,site_id,count(msisdn) metric,current_datetime('+7') process_dt,'SND072' kpi_id,dt_id
from ga_channel
where channel_grp='DSF'
group by 1,2,3,5,6,7
union all
--DSF GA HV
select 'dsf_acq_ga_hv' kpi_code,'IM3' brand,site_id,count(msisdn) metric,current_datetime('+7') process_dt,'SND079' kpi_id,dt_id
from ga_channel
where channel_grp='DSF'
and flag_acm in ('c. >=35k - <50k','d. >=50k')
group by 1,2,3,5,6,7
union all
--DSF GA M2S
select 'dsf_acq_qoa_m2s' kpi_code,'IM3' brand,site_id,count(a.msisdn) metric,current_datetime('+7') process_dt,'SND075' kpi_id,vdt_id dt_id
from ga_channel_m2s a
join rgu b
on a.msisdn=b.msisdn
where channel_grp='DSF'
group by 1,2,3,5,6,7
union all
--DSF GA M2S GA
select 'dsf_acq_qoa_m2s_ga' kpi_code,'IM3' brand,site_id,count(msisdn) metric,current_datetime('+7') process_dt,'SND076' kpi_id,vdt_id dt_id
from ga_channel_m2s
where channel_grp='DSF'
group by 1,2,3,5,6,7
union all
--DSF Count
select 'dsf_num_mtd' kpi_code,'IM3' brand,cluster site_id,count(distinct organization_id) metric,current_datetime('+7') process_dt,'SND077' kpi_id,dt_id
from (
    select distinct dt_id,coalesce(mobo_id,organization_id) organization_id
    from ga_channel a
    left join dsf b
    on a.organization_id = b.mobii_username
    where channel_grp='DSF'
) a
join dsf b
on a.organization_id = b.mobo_id
group by 1,2,3,5,6,7
union all
--SITE W/O GA
select 'site_wo_ga' kpi_code,'IM3' brand,a.site_id,count(distinct a.site_id) metric,current_datetime('+7') process_dt,'SITE022' kpi_id,vdt_id dt_id
from sites a
left join (
    select distinct site_id
    from ga_channel
) b
on a.new_site_id=b.site_id or a.old_site_id=b.site_id
where b.site_id is null
group by 1,2,3,5,6,7
;
