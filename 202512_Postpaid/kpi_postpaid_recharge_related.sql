-------------------------------------------------------------------------------------------------------------------------------------
DECLARE observation_date DATE DEFAULT @vdt_id;
DECLARE start_current_month  DATE DEFAULT DATE_TRUNC(observation_date, MONTH);
DECLARE eop_previous_month DATE DEFAULT LAST_DAY(DATE_SUB(observation_date, INTERVAL 1 MONTH));
DECLARE start_previous_month DATE DEFAULT DATE_TRUNC(LAST_DAY(DATE_SUB(observation_date, INTERVAL 1 MONTH)), MONTH);


-- insert overwrite table biadm.rk_pstpaid_tracker_recharge_region_v2 partition(dt_id)
delete from `data-bi-prd-935c.bi_dev.pstpaid_tracker_recharge_region_v2`
where date(dt_id) = observation_date;

insert into `data-bi-prd-935c.bi_dev.pstpaid_tracker_recharge_region_v2`
WITH ref_store as (
    select store_code territory_id, circle, region region_circle, area, branch
    from `data-bi-prd-935c.bi_mart.pstpaid_store_ref_new`
    where coalesce(TRIM(UPPER(circle)),'') not in ('OTHERS','')
    and TRIM(UPPER(store_code)) not in (
        'JKBB',
        'JKBA',
        'ESEP',
        'LOC0'
    )
),
ref_dealer as (
    select 
        territory_id,
        circle,
        region_circle,
        area,
        branch
    from `data-bi-prd-935c.bi_mart.ref_pstpaid_rtl_dealer_test`
    where coalesce(TRIM(UPPER(branch)),'') not in ('OTHERS','')
),
ref_store_dealer as (
  select distinct coalesce(a.territory_id,b.territory_id) as territory_id,
    coalesce(a.circle, b.circle) as circle,
    coalesce(a.region_circle, b.region_circle) as region,
    coalesce(a.area,b.area) as area,
    coalesce(a.branch,b.branch) as branch
  from ref_store a
  full join ref_dealer b
    on a.territory_id=b.territory_id
),
ref_territory as (
    select 
        upper(territory_id) territory_id, 
        case
            when upper(circle) = '' then null
            when upper(circle) = 'OTHERS' then null
            when upper(circle) = 'OTHERS' then null
            else upper(circle)
        end as circle,
        case
            when upper(region) = '' then null
            when upper(region) = 'UNKNOWN' then null
            when upper(region) = 'OTHERS' then null
            else upper(region)
        end as region_circle,
        case
            when upper(area) = '' then null
            when upper(area) = 'UNKNOWN' then null
            when upper(area) = 'OTHERS' then null
            else upper(area)
        end as area,
        case
            when upper(branch) = '' then null
            when upper(branch) = 'UNKNOWN' then null
            when upper(branch) = 'OTHERS' then null
            else upper(branch)
        end as branch
    from (
        select territory_id, circle, region, area, branch
        from ref_store_dealer
        union all
        select site_id as territory_id, circle, region_circle as region, area, sales_area branch
        from `data-bi-prd-935c.bi_mart.ref_site`
    ) a
),
RECHARGE AS (
    select b.circle, b.region_circle, b.area, b.branch, sum(a.tot_rechrg) tot_rechrg, count(distinct a.msisdn) nsubs, 0 tot_amt, date(a.dt_id) dt_id 
    from `data-dtp-prd-aa1a.smy.cst_rechrg_dly_smy` a
    left join (
        select date(a.dt_id) dt_id, a.msisdn, circle, region_circle, area, branch
        FROM (
            select distinct date(dt_id) dt_id, msisdn, pfx_hlr
            from `data-dtp-prd-aa1a.smy.ar_cst_pstpaid_rtl` 
            WHERE date(dt_id) = observation_date  
            AND CAST(ar_lcs_tp_id AS string) = '2010'
            AND trim(lower(cst_tp)) IN ('individual', 'vvip')
            AND msisdn LIKE '628%'
        ) a
        left join (
            select distinct msisdn, coalesce(b.circle, ioh_circle) circle,
            coalesce(b.region_circle, ioh_region) region_circle,
            coalesce(b.area, ioh_area) area,
            coalesce(b.branch, ioh_sa) branch, dt_id
            from `data-bi-prd-935c.bi_mart.cst_pstpaid_rtl_detail_v3` a                           -- masih schema di impala, belum di angkat ke GCP, ini contoh yang udah di testing `data-bi-prd-935c.bi_dm.moti_testing`
            left join ref_territory b
            on TRIM(UPPER(a.territory_iom))=TRIM(UPPER(b.territory_id))
            left join `data-bi-prd-935c.bi_mart.sa_aggregate_ref` c
            on TRIM(UPPER(a.sa_aggregate)) =TRIM(UPPER(c.sales_area_ga))
            where a.dt_id = observation_date 
        ) b
        on a.msisdn = b.msisdn and date(a.dt_id) = b.dt_id
    )  b 
    on date(a.dt_id) = date(b.dt_id) and a.msisdn = b.msisdn
    where date(a.dt_id) = observation_date 
    and a.tot_rechrg_idr_val > 0
    and b.msisdn is not null
    group by 1,2,3,4, dt_id
    union all
    select b.circle, b.region_circle, b.area, b.branch, 0 tot_rechrg, 0 nsubs, sum(tot_rechrg_idr_val) tot_amt, date(a.dt_id) dt_id
    from `data-dtp-prd-aa1a.smy.cst_rechrg_dly_smy` a
    left join (
        select date(a.dt_id) dt_id, a.msisdn, circle, region_circle, area, branch
        FROM (
            select distinct date(dt_id) dt_id, msisdn, pfx_hlr
            from `data-dtp-prd-aa1a.smy.ar_cst_pstpaid_rtl` 
            WHERE date(dt_id) between start_current_month and observation_date 
                AND CAST(ar_lcs_tp_id AS string) = '2010'
                AND trim(lower(cst_tp)) IN ('individual', 'vvip')
                AND msisdn LIKE '628%'
        ) a
        left join (
            select distinct msisdn, coalesce(b.circle, ioh_circle) circle,
            coalesce(b.region_circle, ioh_region) region_circle,
            coalesce(b.area, ioh_area) area,
            coalesce(b.branch, ioh_sa) branch, dt_id
            from `data-bi-prd-935c.bi_mart.cst_pstpaid_rtl_detail_v3` a                           -- masih schema di impala, belum di angkat ke GCP, ini contoh yang udah di testing `data-bi-prd-935c.bi_dm.moti_testing`
            left join ref_territory b
            on TRIM(UPPER(a.territory_iom))=TRIM(UPPER(b.territory_id))
            left join `data-bi-prd-935c.bi_mart.sa_aggregate_ref` c
            on TRIM(UPPER(a.sa_aggregate)) =TRIM(UPPER(c.sales_area_ga))
            where a.dt_id between start_current_month and observation_date 
        ) b
        on a.msisdn = b.msisdn and date(a.dt_id) = date(b.dt_id)
    )  b 
    on date(a.dt_id) = date(b.dt_id) and a.msisdn = b.msisdn
    where date(a.dt_id) between start_current_month and observation_date 
    and tot_rechrg_idr_val > 0 
    and b.msisdn is not null
    group by 1,2,3,4, dt_id
)
select
    "IM3" brand,
    "POSTPAID" page,
    circle,
    region_circle,
    area,
    branch,
    "post_rld_hits" kpi_code,
    "MTD" flag,
    sum(tot_rechrg) value,
    observation_date dt_id
from RECHARGE
group by 1,2,3,4,5,6,7,8,10
union all 
select
    "IM3" brand,
    "POSTPAID" page,
    circle,
    region_circle,
    area,
    branch,
    "post_rld_subs" kpi_code,
    "MTD" flag,
    sum(nsubs) value,
    observation_date dt_id
from RECHARGE
group by 1,2,3,4,5,6,7,8,10
union all 
select
    "IM3" brand,
    "POSTPAID" page,
    circle,
    region_circle,
    area,
    branch,
    "post_rld_amt" kpi_code,
    "MTD" flag,
    sum(tot_amt) value,
    observation_date dt_id
from RECHARGE  
group by 1,2,3,4,5,6,7,8,10;