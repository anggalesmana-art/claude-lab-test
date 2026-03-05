declare vdt_id date default @vdt_id;
--- VLR 30D Summary
delete from `data-bi-prd-935c.bi_mart`.vlr_activity_smy  where dt_id = vdt_id and kpi_nm = 'VLR_30D';
insert into `data-bi-prd-935c.bi_mart`.vlr_activity_smy 
with
tmp as (
    select dt_id, msisdn, subs_flag, ifnull(first_rgu, actvn_dt) first_rgu, site_id
    from `data-bi-prd-935c.bi_mart`.vlr_activity_dly
    where dt_id between vdt_id - interval 29 day and vdt_id
),
max_dt as (
    select msisdn
        , coalesce(max(case when subs_flag is null then NULL else dt_id end), max(dt_id)) max_dt_subs_flag
        , coalesce(max(case when site_id is null then NULL else dt_id end), max(dt_id)) max_dt_site
        , max(dt_id) max_dt_ori
    from tmp
    group by 1
),
subs_flag as (
    select a.msisdn, subs_flag, first_rgu
    from tmp a
    inner join max_dt b
        on b.max_dt_subs_flag=a.dt_id and a.msisdn=b.msisdn
),
site_id as (
    select a.msisdn, site_id
    from tmp a
    inner join max_dt b
        on b.max_dt_site=a.dt_id and a.msisdn=b.msisdn
),
ori as (
    select a.msisdn, dt_id
    from tmp a
    inner join max_dt b
        on b.max_dt_ori=a.dt_id and a.msisdn=b.msisdn
),
gbg as (
    select distinct coalesce(a.msisdn, b.msisdn) msisdn, subs_flag, first_rgu, site_id
    from subs_flag a
    full join site_id b
        on a.msisdn=b.msisdn
)
select subs_flag, cast(NULL as string) usg_flag
    , CASE
        WHEN date_diff(dt_id, first_rgu,day ) <= 30 THEN 'a.1-30 Days'
        WHEN date_diff(dt_id, first_rgu,day ) <= 60 THEN 'b.31-60 Days'
        WHEN date_diff(dt_id, first_rgu,day ) <= 90 THEN 'c.61-90 Days'
        WHEN date_diff(dt_id, first_rgu,day ) >  90 THEN 'd.> 90 Days'
        else NULL
    END tenure
    , site_id
    , count(distinct coalesce(a.msisdn,b.msisdn)) metric
    , timestamp(current_datetime('+7')) ppn_dttm
    , 'VLR_30D' kpi_nm
    , vdt_id dt_id
from ori a
full join gbg b
    on a.msisdn=b.msisdn
group by 1,3,4
;