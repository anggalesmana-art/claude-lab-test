DECLARE observation_date DATE DEFAULT @vdt_id;
DECLARE start_current_month  DATE DEFAULT DATE_TRUNC(observation_date, MONTH);
DECLARE eop_previous_month DATE DEFAULT LAST_DAY(DATE_SUB(observation_date, INTERVAL 1 MONTH));
DECLARE start_previous_month DATE DEFAULT DATE_TRUNC(LAST_DAY(DATE_SUB(observation_date, INTERVAL 1 MONTH)), MONTH);

-- INSERT OVERWRITE TABLE biadm.rk_cst_pstpaid_ga_detail_v3 PARTITION(dt_id)
delete from `data-bi-prd-935c.bi_dev.cst_pstpaid_ga_detail_v3` 
where dt_id = observation_date;

insert into `data-bi-prd-935c.bi_dev.cst_pstpaid_ga_detail_v3`
WITH
GROSSADD AS (
    select * from `data-bi-prd-935c.bi_mart.cst_pstpaid_ga_v1`
    where dt_id = observation_date
),
CFWD AS (
    select * from `data-bi-prd-935c.bi_dev.cst_pstpaid_ga_detail_v3`
    where dt_id = date_sub(observation_date, interval 1 day)
),
STOREGA AS (
    select *
    from (
        select * except(activation_date), date(FORMAT_DATE('%Y-%m-%d', PARSE_DATE('%Y%m%d', cast(activation_date as string)))) activation_date,  row_number() over(partition by msisdn, account_num order by activation_date desc) rk 
        from `data-dtp-prd-aa1a.rdm.dump_daily_ga`
        where date(FORMAT_DATE('%Y-%m-%d', PARSE_DATE('%Y%m%d', cast(activation_date as string)))) between start_current_month and observation_date
        and UPPER(order_type) in (
            'NEW REGISTRATION',
            'MIGRATION',
            'PORT IN MIGRATION'
        )
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
new_reg_dly as (
    select * from (
        select dt_id, msisdn, completion_date, order_type, account_num ac_num, row_number() over(partition by msisdn order by completion_date desc) rk 
        from `data-dtp-prd-aa1a.stg.stg_siebel_dly_ordr`
        where date(dt_id) between start_current_month and observation_date
        and order_type in (
            'New Registration',
            'Migration',
            'Port In Migration'
        )
    ) a
    where rk = 1
),
GAWSTORE AS (
    select
        a.*,
        coalesce(completion_date, d.activation_date) activation_date,
        coalesce(d.favloc_lock, site_favloc_90, site_favloc_30, site_favloc_dly) favloc_lock, 
        coalesce(c.ac_num, d.ac_num) ac_num,
        case
            when coalesce(b.store_code_rev, d.store_code) = 'GTN-178' then 'GTN178'
            else coalesce(b.store_code_rev, d.store_code)
        end as store_code,
        coalesce(b.store_name_rev, d.store_name) store_name,
        coalesce(b.dealer_id, d.dealer_id) dealer_id_act,
        coalesce(e.subscription_type, d.subscription_type) subscription_type, 
        coalesce(e.contract_status, d.contract_status) contract_status,
        coalesce(e.product_type, d.product_type) product_type,
        coalesce(e.product_family, d.product_family) product_family,
        coalesce(e.product_grp, d.product_grp) product_grp,
        coalesce(e.product_cat, d.product_cat) product_cat,
        b.channel_partner_store_group channel_group,
        b.channel_partner_store_detail channel_detail
    from GROSSADD a
    left join STOREGA b
    on a.msisdn = b.msisdn
    left join new_reg_dly c
    on a.msisdn = c.msisdn and a.order_type = c.order_type and date(c.dt_id) <= date(a.dt_id)
    left join CFWD d
    on a.msisdn = d.msisdn and d.flag like '%2%'
    left join `data-bi-prd-935c.bi_mart.ref_pstpaid_rtl_pkg` e
    on trim(upper(a.pkg_nm)) = trim(upper(e.pkg_nm))
    left join favloc_90 f 
    on a.msisdn = f.msisdn
    left join favloc_30  g 
    on a.msisdn = g.msisdn
    left join favloc_dly h
    on a.msisdn = h.msisdn
),
FINALGA AS (
    select
        distinct
        a.flag,
        a.msisdn,
        ac_num,
        order_type,
        a.activation_date,
        salesperson,
        submitted_by,
        product_id,
        pkg_nm,
        subscription_type,
        contract_status,
        case
            when contract_status in ('Postpaid Basic', '01 - monthly','00 - unknown') then null
            else cast(activation_date as date)
        end as start_contract,
        case
            when contract_status in ('Postpaid Basic', '01 - monthly','00 - unknown') then null
            when contract_status like '%03%' then date_add(date(activation_date), interval 90 day)
            when contract_status like '%06%' then date_add(date(activation_date), interval 180 day)
            when contract_status like '%12%' then date_add(date(activation_date), interval 365 day)
            when contract_status like '%24%' then date_add(date(activation_date), interval 730 day)
        end as end_contract,
        product_type,
        product_family,
        product_grp,
        product_cat,
        network_flag,
        cast(pfx_hlr as string) as pfx_hlr,
        hlr_region,
        hlr_branch,
        hlr_city,
        bill_date,
        bill_cycle,
        a.dealer_id dealer_id,
        UPPER(TRIM(a.store_code)) store_code,
        UPPER(TRIM(a.store_name)) store_name,
        upper(coalesce(b.channel_group, a.channel_group)) channel_group,
        upper(coalesce(b.channel_detail, a.channel_detail)) channel_detail,
        favloc_lock,
        coalesce(a.store_code, a.dealer_id_act, favloc_lock) territory,
        case
            when upper(coalesce(b.channel_detail, a.channel_detail)) in
            ( 
                'ONLINE CHANNEL',
                'OLA'
            ) then favloc_lock
            else coalesce(a.store_code, a.dealer_id_act, favloc_lock)
        end as territory_ola_site_id,
        current_timestamp() ppn_dtm,
        dt_id
    from GAWSTORE a 
    left join `data-bi-prd-935c.bi_mart.pstpaid_store_ref_new` b 
    on trim(upper(a.store_code)) = trim(upper(b.store_code))
)
select * from FINALGA;