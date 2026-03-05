DECLARE observation_date DATE DEFAULT @vdt_id;
DECLARE eop_previous_month DATE DEFAULT LAST_DAY(DATE_SUB(observation_date, INTERVAL 1 MONTH));
DECLARE start_this_month DATE DEFAULT DATE_TRUNC(observation_date, MONTH);
DECLARE yday_date DATE DEFAULT DATE_SUB(observation_date, INTERVAL 1 DAY);


-- Temp Table
CREATE OR REPLACE TABLE `data-bi-prd-935c.bi_mart.tmp_pstpaid_ar_data` as
WITH ARPOSTALL AS (
    select 
        msisdn,
        invoicenumber,
        creditclassname,
        PARSE_DATE('%Y%m%d', overdueperiod) overdueperiod
        , DATE_ADD(PARSE_DATE('%Y%m%d', invoicedate), INTERVAL 37 DAY) invoicedate
        , invoiceoutstanding
        , accountnum
    from (
        select 
            *
        from `data-dtp-prd-aa1a.stg.eb_detail_aging_daily`
        where date(dtid) = observation_date
        and invoicedate >= '20180101'
        and invoicedate != 'Deposit'
        and invoicedate is not null 
        and length(overdueperiod) = 8
        and length(invoicedate) = 8
        and lower(customertype) in ('individual', 'vvip', 'smb')
        and upper(invoicenumber) not like 'DEP%'
        and currency_code = 'IDR'
        and (creditclassname in ('NEW', 'NEWINDREG', 'INREG', 'VVIP', 'PER1', 'PER2', 'INPRIME', 'BIZZC', 'INVIP') or creditclassname is null)
    ) a
),
ARPRE As (
    select 
        *,
        case
            when flag_ar = 'M3+' and creditclassname = 'INREG' then 'N'
            when flag_ar = 'Current' and creditclassname = 'INVIP' then 'N'
            when flag_ar = 'M3' and creditclassname in ('INVIP','INREG') then 'N'
            when flag_ar = 'M2' and creditclassname in ('INVIP','INREG') then 'N'
            when flag_ar = 'M1' and creditclassname in ('INVIP','INREG') then 'N'
            else 'Y'
        end as flag
    from (
        select
            msisdn,
            accountnum ac_num,
            creditclassname,
            invoicenumber,
            overdueperiod,
            invoicedate,
            case
                when DATE_DIFF(overdueperiod, invoicedate, day) < 0 then 'Current'
                when DATE_DIFF(overdueperiod, invoicedate, day) between 0 and 30 then 'M1'
                when DATE_DIFF(overdueperiod, invoicedate, day) between 31 and 60 then 'M2'
                when DATE_DIFF(overdueperiod, invoicedate, day) between 61 and 90 then 'M3'
                when DATE_DIFF(overdueperiod, invoicedate, day) > 90 then 'M3+'
            end as flag_ar,
            cast(invoiceoutstanding as int) invoiceoutstanding
        from ARPOSTALL
    ) a
),
ARFINAL AS (
    select msisdn, ac_num, flag_ar, sum(invoiceoutstanding)/1.11 ar_vals
    from ARPRE
    where flag = 'Y'
    group by 1,2,3
    order by 1
)
select 
    *
from ARFINAL;

INSERT INTO `data-bi-prd-935c.bi_mart.pstpaid_tracker_arcollection_region`
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
fnl as (
    select	
    	observation_date dt_id
    	, msisdn
    	, ac_num
    	, case
    		when flag_ar='Current' then 'POSAR001'
    		when flag_ar='M1' then 'POSAR002'
    		when flag_ar='M2' then 'POSAR003'
    		when flag_ar='M3' then 'POSAR004'
    		when flag_ar is null then 'POSAR005'
    		else 'POSAR006'
    	end kpi_id
    	, case
    		when flag_ar='Current' then 'post_ar_m0'
    		when flag_ar='M1' then 'post_ar_m1'
    		when flag_ar='M2' then 'post_ar_m2'
    		when flag_ar='M3' then 'post_ar_m3'
    		when flag_ar is null then 'post_ar_unk'
    		else 'post_ar_m3+'
    	end kpi_code
    	, 'DLY' flag
    	, sum(ar_vals) metric
    from `data-bi-prd-935c.bi_mart.tmp_pstpaid_ar_data`
    group by 1,2,3,4,5
),
fnl_2 AS (
    select 
        "IM3" brand,
        "POSTPAID" page,
        b.circle,
        b.region_circle,
        b.area,
        b.branch,
        kpi_code,
        "MTD" flag,
        sum(metric) metric,
        observation_date dt_id
    from fnl a 
    left join (
        select * from (
            select msisdn, ac_num, 
            coalesce(b.circle, ioh_circle) circle, 
            coalesce(b.region_circle, ioh_region) region_circle,
            coalesce(b.area, ioh_area) area,
            coalesce(b.branch, ioh_sa) branch, dt_id, 
            row_number() over(partition by msisdn, ac_num order by dt_id desc) rk
            from (
              select dt_id, msisdn, ac_num, sa_aggregate, case when store_code in ('MYIM3OLA','ESEP') then coalesce(favloc_lock, site_favloc_90) else territory_iom end territory_fnl
              from `data-bi-prd-935c.bi_mart.cst_pstpaid_rtl_detail_v3`
              where dt_id between '2022-01-01' and observation_date
            ) a
            left join ref_territory b
            on TRIM(UPPER(a.territory_fnl))=TRIM(UPPER(b.territory_id))
    		left join `data-bi-prd-935c.bi_mart.sa_aggregate_ref` c
    		on TRIM(UPPER(a.sa_aggregate)) =TRIM(UPPER(c.sales_area_ga))
        ) a 
        where rk = 1
    ) b 
    on a.msisdn=b.msisdn and a.ac_num = b.ac_num 
    group by 1,2,3,4,5,6,7,8,dt_id
)
select * from fnl_2;

-- Delete the Temp Table
drop table `data-bi-prd-935c.bi_mart.tmp_pstpaid_ar_data`;
