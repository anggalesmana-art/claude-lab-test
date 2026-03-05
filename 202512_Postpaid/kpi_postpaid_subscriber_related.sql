DECLARE observation_date DATE DEFAULT @vdt_id;
DECLARE start_current_month  DATE DEFAULT DATE_TRUNC(observation_date, MONTH);
DECLARE eop_previous_month DATE DEFAULT LAST_DAY(DATE_SUB(observation_date, INTERVAL 1 MONTH));
DECLARE start_previous_month DATE DEFAULT DATE_TRUNC(LAST_DAY(DATE_SUB(observation_date, INTERVAL 1 MONTH)), MONTH);


-- insert overwrite table biadm.rk_pstpaid_tracker_subs_region_v2 partition(dt_id)
delete from `data-bi-prd-935c.bi_dev.pstpaid_tracker_subs_region_v2`
where date(dt_id) = observation_date;

insert into `data-bi-prd-935c.bi_dev.pstpaid_tracker_subs_region_v2`
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
POSTPAIDSUBS AS (
    select
        coalesce(b.circle, ioh_circle) circle,
        coalesce(b.region_circle, ioh_region) region_circle,
        coalesce(b.area, ioh_area) area,
        coalesce(b.branch, ioh_sa) branch,
        case
          when lower(ac_st) like 'act%' then 'post_subs_active'
          when lower(ac_st) like 'soft%' then 'post_subs_soft_blocked'
          when lower(ac_st) like 'hard%' then 'post_subs_hard_blocked'
          when lower(ac_st) like 'suspend%' then 'post_subs_suspended'
        end as kpi,
        count(distinct concat(msisdn,'-',ac_num)) value,
        dt_id    
    from (
        select * from `data-bi-prd-935c.bi_mart.cst_pstpaid_rtl_detail_v3` a                           -- masih schema di impala, belum di angkat ke GCP, ini contoh yang udah di testing `data-bi-prd-935c.bi_dm.moti_testing`
        where dt_id = observation_date
        and ac_st in ("Active", "HardBlocked", "SoftBlocked", "Suspended")
    ) a
    left join ref_territory b
    on TRIM(UPPER(a.territory_iom))=TRIM(UPPER(b.territory_id))
    left join `data-bi-prd-935c.bi_mart.sa_aggregate_ref` c
    on TRIM(UPPER(a.sa_aggregate)) =TRIM(UPPER(c.sales_area_ga))
    group by 1,2,3,4,5,7
),
POSTPAIDGA AS (
    select
        coalesce(b.circle) circle,
        coalesce(b.region_circle)  region_circle,
        coalesce(b.area) area,
        coalesce(b.branch) branch,
        case
          when flag like '%1%' then 'post_subs_ga_dly'
          when flag like '%2%' then 'post_subs_ga_mtd'
        end kpi,
        count(distinct msisdn) value,
        dt_id
    from (
        select * from `data-bi-prd-935c.bi_mart.cst_pstpaid_ga_detail_v3`
        where dt_id = observation_date        
    ) a
    left join ref_territory b
    on TRIM(UPPER(a.territory_ola_site_id))=TRIM(UPPER(b.territory_id))
    group by 1,2,3,4,5,7
),
POSTPAIDCHURN AS (
    select
        coalesce(b.circle, ioh_circle) circle,
        coalesce(b.region_circle, ioh_region) region_circle,
        coalesce(b.area, ioh_area) area,
        coalesce(b.branch, ioh_sa) branch,
        case
          when flag='1. CHURN (Daily)' then 'post_subs_churn_dly'
          when flag='2. CHURN (EOP)' then 'post_subs_churn_mtd'
        end kpi,
        count(distinct msisdn) value,
        dt_id
    from (
        select * from `data-bi-prd-935c.bi_mart.cst_pstpaid_churn_detail_v3`
        where dt_id = observation_date
    ) a
    left join ref_territory b
    on TRIM(UPPER(a.territory_iom))=TRIM(UPPER(b.territory_id))
    left join `data-bi-prd-935c.bi_mart.sa_aggregate_ref` c
    on TRIM(UPPER(a.sa_aggregate)) =TRIM(UPPER(c.sales_area_ga))
    group by 1,2,3,4,5,7
),
POSTPAIDCB AS (
    select
        coalesce(b.circle, ioh_circle) circle,
        coalesce(b.region_circle, ioh_region) region_circle,
        coalesce(b.area, ioh_area) area,
        coalesce(b.branch, ioh_sa) branch,
        case
          when flag='1. CB (Daily)' then 'post_subs_cb_dly'
          when flag='2. CB (EOP)' then 'post_subs_cb_mtd'
        end kpi,
        count(distinct msisdn) value,
        dt_id
    from (
        select * from `data-bi-prd-935c.bi_mart.cst_pstpaid_cb_detail_v3`
        where dt_id = observation_date
    ) a
    left join ref_territory b
    on TRIM(UPPER(a.territory_iom))=TRIM(UPPER(b.territory_id))
    left join `data-bi-prd-935c.bi_mart.sa_aggregate_ref` c
    on TRIM(UPPER(a.sa_aggregate)) =TRIM(UPPER(c.sales_area_ga))
    group by 1,2,3,4,5,7
),
ALLPOSTPAID AS (
    select * from POSTPAIDSUBS
    union all 
    select * from POSTPAIDGA
    union all
    select * from POSTPAIDCHURN
    union all
    select * from POSTPAIDCB
),
PROPAIDSUBS AS (
    select
        "IM3" brand,
        "POSTPAID" page,
        b.circle,
        b.region_circle,
        b.area,
        b.sales_area branch,
        'propaid_subs' kpi,
        "MTD" flag,
        sum(value) value,
        date(dt_id) dt_id
    from (    
        select
            a.dt_id,
    		b.site_id,
    		count(a.msisdn) as value
        from `data-dtp-prd-aa1a.smy.ar_cst_propaid_smy` a
    	left join (
        select msisdn, site_id, dt_id
        from `data-bi-prd-935c.bi_mart.all_90d_fav_loc_dly`
        where date(dt_id) = observation_date
      ) b
    	on a.msisdn=b.msisdn and date(a.dt_id) = date(b.dt_id)
        where date(a.dt_id) = observation_date
        group by 1,2
    ) a
    left join `data-bi-prd-935c.bi_mart.ref_site` b
    on a.site_id=b.site_id
    group by 1,2,3,4,5,6,7,8,10
),
POSTPAIDSUBS2 AS ( 
    select
        "IM3" brand,
        "POSTPAID" page,
        circle,
        region_circle,
        area,
        branch,
        kpi,
        "MTD" flag,
        sum(value) value,
        dt_id
    from ALLPOSTPAID a
    group by 1,2,3,4,5,6,7,8,10
)
select * from POSTPAIDSUBS2
union all
select * from PROPAIDSUBS;