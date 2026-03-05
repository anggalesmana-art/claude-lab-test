DECLARE observation_date DATE DEFAULT @vdt_id;
DECLARE start_current_month  DATE DEFAULT DATE_TRUNC(observation_date, MONTH);
DECLARE eop_previous_month DATE DEFAULT LAST_DAY(DATE_SUB(observation_date, INTERVAL 1 MONTH));
DECLARE start_previous_month DATE DEFAULT DATE_TRUNC(LAST_DAY(DATE_SUB(observation_date, INTERVAL 1 MONTH)), MONTH);

-- insert overwrite table biadm.rk_pstpaid_tracker_billrev_region_v2 partition(dt_id)
delete from `data-bi-prd-935c.bi_dev.pstpaid_tracker_billrev_region_v2`
where date(dt_id) = observation_date;

insert into `data-bi-prd-935c.bi_dev.pstpaid_tracker_billrev_region_v2`
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
SUBSCRIBER AS (
    select a.*, coalesce(b.circle, ioh_circle) circle,
        coalesce(b.region_circle, ioh_region) region_circle,
        coalesce(b.area, ioh_area) area,
        coalesce(b.branch, ioh_sa) branch
    from (
        select msisdn, territory_iom, sa_aggregate, dt_id, row_number() over(PARTITION BY msisdn order by dt_id desc) rk
        from `data-bi-prd-935c.bi_mart.cst_pstpaid_rtl_detail_v3` a                           -- masih schema di impala, belum di angkat ke GCP, ini contoh yang udah di testing `data-bi-prd-935c.bi_dm.moti_testing`
        where dt_id between start_current_month and observation_date
    ) a 
    left join ref_territory b
    on TRIM(UPPER(a.territory_iom))=TRIM(UPPER(b.territory_id))
    left join `data-bi-prd-935c.bi_mart.sa_aggregate_ref` c
    on TRIM(UPPER(a.sa_aggregate)) =TRIM(UPPER(c.sales_area_ga))
    where rk = 1
),
base as (
    select * from `data-bi-prd-935c.bi_mart.postpaid_rev_tbleu`
    where dt_id between start_current_month and observation_date
)
select 
  "IM3" brand
  , "POSTPAID" page
  , circle
  , region_circle
  , area
  , branch
  , case
        when upper(b.product_family) = "PLATINUM" then "post_rev_bill_platinum"
        when upper(b.product_family) = "FREE ABONEMEN" then "post_rev_bill_abo"
        when upper(b.product_family) = "FREEDOM POSTPAID" then "post_rev_bill_freedom"
        when upper(b.product_family) = "LEGACY PACKAGE" then "post_rev_bill_legacy"
        when upper(b.product_family) = "POSTPAID BASIC" then "post_rev_bill_basic"
        else "post_rev_bill_other"
    end as kpi    
  , "MTD" flag
  , sum(amt_rev) metric
  , observation_date dt_id
from base a
left join `data-bi-prd-935c.bi_mart.ref_pstpaid_rtl_pkg` b
    on trim(upper(a.pkg_nm))=trim(upper(b.pkg_nm))
left join SUBSCRIBER c
on a.msisdn = c.msisdn
group by 1, 2, 3, 4,5,6,7,8,10
order by 8,9 desc;