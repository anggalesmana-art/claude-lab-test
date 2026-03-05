DECLARE observation_date DATE DEFAULT @vdt_id;
DECLARE start_current_month  DATE DEFAULT DATE_TRUNC(observation_date, MONTH);
DECLARE eop_previous_month DATE DEFAULT LAST_DAY(DATE_SUB(observation_date, INTERVAL 1 MONTH));
DECLARE start_previous_month DATE DEFAULT DATE_TRUNC(LAST_DAY(DATE_SUB(observation_date, INTERVAL 1 MONTH)), MONTH);


-- insert overwrite table biadm.rk_cst_pstpaid_smb_v1 partition(dt_id)
delete from `data-bi-prd-935c.bi_dev.cst_pstpaid_smb_v1` 
where dt_id = observation_date;

insert into `data-bi-prd-935c.bi_dev.cst_pstpaid_smb_v1`
WITH favloc_90 as (
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
favloc_cfwd as (
  select msisdn, ac_num, territory as site_favloc_cfwd, dt_id
  from `data-bi-prd-935c.bi_mart.cst_pstpaid_smb_v1`
  where dt_id = date_sub(observation_date, interval 1 day)
  and coalesce(territory,'')!=''
),
BASE AS (
    select
        distinct
        svc_id msisdn,
        cast(lpad(cast(billing_account as string),8,'0') as string) ac_num,
        'SMB Legacy' customer_type,
        a.cst_tp,
        pd_nm,
        ofr_nm, 
        ast_nm,
        ast_st, 
        ac_st,
        actvn_dt activation_date, 
        ac_actvn_dt ac_activation_date,
        ac_st_dt,
        sale_nm,
        sale_psn,
        bill_prd,
        bill_dt,
        iccid,
        imsi,
        imei,
        tac,
        manufacturer_name,
        model,
        case
            when coalesce(trim(site_favloc_90), '') not in ('') then '1. Favloc 90'
            when coalesce(trim(site_favloc_30), '') not in ('') then '2. Favloc 30'
            when coalesce(trim(site_favloc_dly), '') not in ('') then '3. Favloc dly'
            when coalesce(trim(site_favloc_cfwd), '') not in ('') then '4. Favloc CFWD'
            else '5. Not Traceable'
        end as priority,
        c.site_favloc_90,
        d.site_favloc_30,
        e.site_favloc_dly,
        coalesce(site_favloc_90, site_favloc_30, site_favloc_dly, site_favloc_cfwd) territory,
        observation_date dt_id
    from (
        select * from `data-dtp-prd-aa1a.smy.ar_cst_pstpaid_b2b`
        where date(dt_id) = observation_date
    ) a
    inner join `data-dtp-prd-aa1a.stg.b2c_smb_mobile_msisdn` b
    on cast(a.svc_id as string) = cast(msisdn as string) and cast(a.ac_num as string) = lpad(cast(billing_account as string),8,'0')
    left join favloc_90 c 
    on cast(a.svc_id as string) = c.msisdn
    left join favloc_30 d 
    on cast(a.svc_id as string) = d.msisdn
    left join favloc_dly e 
    on cast(a.svc_id as string) = e.msisdn
    left join favloc_cfwd f
    on (cast(a.svc_id as string) = f.msisdn and lpad(cast(billing_account as string),8,'0') = f.ac_num)
)
select
    *
from BASE;