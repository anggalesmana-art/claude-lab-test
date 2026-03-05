DECLARE observation_date DATE DEFAULT @vdt_id;
DECLARE start_current_month  DATE DEFAULT DATE_TRUNC(observation_date, MONTH);
DECLARE eop_previous_month DATE DEFAULT LAST_DAY(DATE_SUB(observation_date, INTERVAL 1 MONTH));
DECLARE start_previous_month DATE DEFAULT DATE_TRUNC(LAST_DAY(DATE_SUB(observation_date, INTERVAL 1 MONTH)), MONTH);


-- INSERT OVERWRITE TABLE biadm.rk_cst_pstpaid_cb_detail_v3 PARTITION(dt_id)
delete from `data-bi-prd-935c.bi_dev.cst_pstpaid_cb_detail_v3` 
where dt_id = observation_date;

insert into `data-bi-prd-935c.bi_dev.cst_pstpaid_cb_detail_v3`
WITH COMERCIALREF AS (
    select * 
    from (
        select msisdn, 
        store_code_rev,
        actvn_dt,
        sa_aggregate,
        case
            when length(territory) > 9 then coalesce(favloc_site, territory)
            else favloc_site
        end favloc_site, date(FORMAT_DATE('%Y-%m-%d', PARSE_DATE('%Y%m%d', cast(tgl as string)))) tgl, row_number() over(partition by msisdn order by tgl desc) rk
        from `data-cvm-prd-c324.main.im3_postpaid_base_strcd`
        where date(FORMAT_DATE('%Y-%m-%d', PARSE_DATE('%Y%m%d', cast(tgl as string)))) <= observation_date
        and date(bln_sts) <= observation_date
    ) a 
    where rk = 1
),
favloc_90 as (
  select msisdn, site_id as site_favloc_90, dt_id
  from `data-bi-prd-935c.bi_mart.all_90d_fav_loc_dly`
  where date(dt_id) = observation_date
    and coalesce(site_id,'')!=''
),
favloc_30 as (
  select msisdn, site_id as site_favloc_30, dt_id
  from `data-bi-prd-935c.bi_mart.favloc_30d_dly`
  where date(dt_id) = observation_date
    and coalesce(site_id,'')!=''
),
favloc_dly as (
  select msisdn, site_id as site_favloc_dly, dt_id
  from `data-dtp-prd-aa1a.sor.subs_fav_loc_dly_carry_fwd`
  where date(dt_id) = observation_date
    and coalesce(site_id,'')!=''
),
STORELISTBAI AS (
    select * from (
        select 
            msisdn, 
            ac_num, 
            activation_date, 
            store_code, 
            store_name, 
            dealer_id, 
            territory, 
            favloc_lock, 
            start_contract, 
            end_contract, 
        row_number() over(PARTITION BY msisdn, ac_num order by dt_id desc) rk
        from `data-bi-prd-935c.bi_dev.cst_pstpaid_ga_detail_v3`
        where flag like '%2%'
        and dt_id <= observation_date
    ) a
    where rk = 1
),
CHURNBACKPRE AS (
    select 
        a.flag,
        a.msisdn,
        coalesce(c.activation_date, b.actvn_dt) activation_date,
        a.order_type,
        a.salesperson,
        a.submitted_by,
        a.product_id,
        a.pkg_nm,
        a.network_flag,
        a.pfx_hlr,
        a.hlr_region,
        a.hlr_branch,
        a.hlr_city,
        a.bill_date,
        a.bill_cycle,
        case
            when coalesce(TRIM(UPPER(d.site_favloc_90)), TRIM(UPPER(e.site_favloc_30)), TRIM(UPPER(f.site_favloc_dly)), TRIM(UPPER(b.favloc_site)), TRIM(UPPER(c.favloc_lock)),'') not in ('' ,'NULL') then '1. favloc_lock'
            when coalesce(TRIM(UPPER(c.store_code)),'') not in ('' ,'NULL') then '2. store'
            when coalesce(TRIM(UPPER(c.dealer_id)), TRIM(UPPER(a.dealer_id)), '') not in ('' ,'NULL') then '3. dealer'
            when coalesce(TRIM(UPPER(b.sa_aggregate)),'') not in ('' ,'NULL') then '4. sa_aggregate'
            else null
        end bi_priority,
        coalesce(d.site_favloc_90, e.site_favloc_30, f.site_favloc_dly, b.favloc_site, c.favloc_lock, c.store_code, c.dealer_id, a.dealer_id) territory_bi,
        case
            when coalesce(c.store_code, c.dealer_id, a.dealer_id,  b.favloc_site, c.favloc_lock ) like '%OLA%' and coalesce(TRIM(UPPER(b.favloc_site)), TRIM(UPPER(c.favloc_lock)),'') not in ('' ,'NULL') then '3. favloc_lock'
            when coalesce(c.store_code, c.dealer_id, a.dealer_id,  b.favloc_site, c.favloc_lock ) like '%MYIM3%' and coalesce(TRIM(UPPER(b.favloc_site)), TRIM(UPPER(c.favloc_lock)),'') not in ('' ,'NULL') then '3. favloc_lock'
            when coalesce(c.store_code, c.dealer_id, a.dealer_id,  b.favloc_site, c.favloc_lock ) like '%MYM%' and coalesce(TRIM(UPPER(b.favloc_site)), TRIM(UPPER(c.favloc_lock)),'') not in ('' ,'NULL') then '3. favloc_lock'
            when coalesce(TRIM(UPPER(c.store_code)),'') not in ('' ,'NULL') then '1. store'
            when coalesce(TRIM(UPPER(c.dealer_id)), TRIM(UPPER(a.dealer_id)), '') not in ('' ,'NULL') then '2. dealer'
            when coalesce(TRIM(UPPER(b.sa_aggregate)),'') not in ('' ,'NULL') then '4. sa_aggregate'
            else null
        end iom_priority,
        case
            when coalesce(c.store_code, c.dealer_id, a.dealer_id,  b.favloc_site, c.favloc_lock) like '%OLA%'  then coalesce(b.favloc_site, c.favloc_lock, c.store_code, c.dealer_id, a.dealer_id)
            when coalesce(c.store_code, c.dealer_id, a.dealer_id,  b.favloc_site, c.favloc_lock ) like '%MYIM3%' then coalesce(b.favloc_site, c.favloc_lock, c.store_code, c.dealer_id, a.dealer_id)
            when coalesce(c.store_code, c.dealer_id, a.dealer_id,  b.favloc_site, c.favloc_lock ) like '%MYM%' then coalesce(b.favloc_site, c.favloc_lock, c.store_code, c.dealer_id, a.dealer_id)
            else coalesce(c.store_code, c.dealer_id, a.dealer_id,  b.favloc_site, c.favloc_lock )
        end as territory_iom,
         d.site_favloc_90,
        e.site_favloc_30,
        f.site_favloc_dly,
        c.favloc_lock,
        c.store_code,
        c.store_name,
        c.dealer_id actvn_dealer,
        b.sa_aggregate,	
        a.dt_id,
        row_number() over(partition by a.msisdn, a.flag order by a.dt_id desc) rk
    from (
        select * from `data-bi-prd-935c.bi_mart.cst_pstpaid_cb_v1`
        where dt_id = observation_date
    ) a
    left join COMERCIALREF b
    on a.msisdn = b.msisdn 
    left join STORELISTBAI c
    on a.msisdn = c.msisdn
    left join favloc_90 d
    on a.msisdn = d.msisdn
    left join favloc_30 e
    on a.msisdn = e.msisdn
    left join favloc_dly f
    on a.msisdn = f.msisdn
),
FINALCB AS (
    select 
        flag,
        msisdn,
        activation_date,
        order_type,
        salesperson,
        submitted_by,
        product_id,
        pkg_nm,
        network_flag,
        pfx_hlr,
        hlr_region,
        hlr_branch,
        hlr_city,
        bill_date,
        bill_cycle,
        bi_priority,
        territory_bi,
        iom_priority,
        territory_iom,
        site_favloc_90,
        site_favloc_30,
        site_favloc_dly,
        favloc_lock,
        store_code,
        store_name,
        actvn_dealer,
        sa_aggregate,
        current_timestamp() ppn_dtm,
        dt_id,
        row_number() over(partition by msisdn, flag order by dt_id desc) rk
    from CHURNBACKPRE
)
select 
  flag,
  msisdn,
  activation_date,
  order_type,
  salesperson,
  submitted_by,
  product_id,
  pkg_nm,
  network_flag,
  cast(pfx_hlr as string) as pfx_hlr,
  hlr_region,
  hlr_branch,
  hlr_city,
  bill_date,
  bill_cycle,
  bi_priority,
  territory_bi,
  iom_priority,
  territory_iom,
  site_favloc_90,
  site_favloc_30,
  site_favloc_dly,
  favloc_lock,
  store_code,
  store_name,
  actvn_dealer,
  sa_aggregate,
  current_timestamp() ppn_dtm,
  dt_id
from FINALCB
where rk = 1;