########################################################################################################################################################################################
# CREATED BY    : Herwin Goernia
# CREATION DATE : 2024-07-31
# DESCRIPTION   : Postpaid Gross Add Churn - Postpaid MTD
#
# EXECUTE
# sh hg_postpaid_subs_mnl.sh <start_dt> <end_dt> # OLD in IMPALA 
#
# HISTORY
# 2024-07-31  ; Herwin Goernia  			; Initial Release
# 2025-08-15  ; Timotius Yakti Sih Gumelar  ; Adjust Date because Completion Date back to Normal
#
# MIGRATION GCP
# 2025-12-31  ; Timotius Yakti Sih G		; Initial Release
########################################################################################################################################################################################

DECLARE observation_date DATE DEFAULT @vdt_id;
DECLARE eop_previous_month DATE DEFAULT LAST_DAY(DATE_SUB(observation_date, INTERVAL 1 MONTH));
DECLARE start_this_month DATE DEFAULT DATE_TRUNC(observation_date, MONTH);
DECLARE yday_date DATE DEFAULT DATE_SUB(observation_date, INTERVAL 1 DAY);

CREATE OR REPLACE TABLE `data-bi-prd-935c.bi_stg.hg_tmp_pstpaid_ga_churn` AS 
with
prev_closing as (
  select msisdn, ac_num, product_id, pkg_nm, network_flag, TRIM(SPLIT(actvn_cnl, '-')[OFFSET(0)]) dealer_id, pfx_hlr, hlr_region, hlr_branch, hlr_city, bill_date, bill_cycle
    , concat(msisdn,'|',ac_num) msisdn_ac
  from `data-bi-prd-935c.bi_mart.cst_pstpaid_rtl_v1` -- July periods use this table
  where date(dt_id) = eop_previous_month
    and ac_st in ('Active','SoftBlocked','HardBlocked')
),
yday_closing as (
  select msisdn, ac_num, product_id, pkg_nm, network_flag, TRIM(SPLIT(actvn_cnl, '-')[OFFSET(0)]) dealer_id, pfx_hlr, hlr_region, hlr_branch, hlr_city, bill_date, bill_cycle
    , concat(msisdn,'|',ac_num) msisdn_ac
  from `data-bi-prd-935c.bi_mart.cst_pstpaid_rtl_v1` -- Execution = 1st July, use this table
  --from biadm.hg_cst_pstpaid_rtl_v1 -- Execution 2nd July onwards, use this table
  where date(dt_id) = yday_date
    and ac_st in ('Active','SoftBlocked','HardBlocked')
),
tday_closing as (
  select msisdn, ac_num, product_id, pkg_nm, network_flag, TRIM(SPLIT(actvn_cnl, '-')[OFFSET(0)]) dealer_id, pfx_hlr, hlr_region, hlr_branch, hlr_city, bill_date, bill_cycle
    , concat(msisdn,'|',ac_num) msisdn_ac
  from `data-bi-prd-935c.bi_mart.cst_pstpaid_rtl_v1`
  where date(dt_id) = observation_date
    and ac_st in ('Active','SoftBlocked','HardBlocked')
)
-- GA Daily
select a.*, '1. GA (Daily)' flag
from tday_closing a
left join yday_closing b
  on a.msisdn_ac=b.msisdn_ac
where b.msisdn_ac is null
union all
-- GA MTD
select a.*, '2. GA (EOP)' flag
from tday_closing a
left join prev_closing b
  on a.msisdn_ac=b.msisdn_ac
where b.msisdn_ac is null
union all
-- Churn Daily
select a.*, '1. CHURN (Daily)' flag
from yday_closing a
left join tday_closing b
  on a.msisdn_ac=b.msisdn_ac
where b.msisdn_ac is null
union all
-- Churn MTD
select a.*, '2. CHURN (EOP)' flag
from prev_closing a
left join tday_closing b
  on a.msisdn_ac=b.msisdn_ac
where b.msisdn_ac is null
;


--- TEMP Order
CREATE OR REPLACE TABLE `data-bi-prd-935c.bi_stg.hg_tmp_pstpaid_order` AS 
select format_date('%Y-%m-%d', DATETIME(completion_date, 'Asia/Jakarta')) dt_id
  , concat(regexp_replace(msisdn, "[^0-9.]", ""),'|',account_num) msisdn_ac
  , order_type, TRIM(SPLIT(dealer_id, '-')[OFFSET(0)]) dealer_id, salesperson, submitted_by
from (
  select *, row_number() over(partition by regexp_replace(msisdn, "[^0-9.]", ""), format_date('%Y-%m-%d', DATETIME(completion_date, 'Asia/Jakarta')) order by DATETIME(completion_date, 'Asia/Jakarta') desc, action asc) rk
  from `data-dtp-prd-aa1a.stg.stg_siebel_dly_ordr`
  where date(dt_id) >= eop_previous_month
    and date(dt_id) <= observation_date
    and date(format_date('%Y-%m-%d', DATETIME(completion_date, 'Asia/Jakarta'))) >= start_this_month
    and date(format_date('%Y-%m-%d', DATETIME(completion_date, 'Asia/Jakarta'))) <= observation_date
    and msisdn like '628%'
    and integration_status='Success'
) x
where rk=1
;

-- data-bi-prd-935c.bi_mart.cst_pstpaid_ga_v1
-- CREATE OR REPLACE TABLE `data-bi-prd-935c.bi_dm.hg_tmp_pstpaid_ga_test` AS 
delete from `data-bi-dev-e36d.bi_mart.cst_pstpaid_ga_v1` where dt_id = observation_date;
INSERT INTO `data-bi-dev-e36d.bi_mart.cst_pstpaid_ga_v1`
with
new_reg_dly as (
  select distinct format_date('%Y-%m-%d', DATETIME(completion_date, 'Asia/Jakarta')) dt_id, concat(msisdn,'|',account_num) msisdn_ac
    , order_type, TRIM(SPLIT(dealer_id, '-')[OFFSET(0)]) dealer_id, salesperson, submitted_by
  from `data-dtp-prd-aa1a.stg.stg_siebel_dly_ordr`
  where date(dt_id) >= eop_previous_month
    and date(dt_id) <= observation_date
    and date(format_date('%Y-%m-%d', DATETIME(completion_date, 'Asia/Jakarta'))) >= start_this_month
    and date(format_date('%Y-%m-%d', DATETIME(completion_date, 'Asia/Jakarta'))) <= observation_date
    and order_type in ('Port In Migration', 'Migration', 'New Registration', 'New Registration From Prepaid')
    and action='Add'
),
ga_dly as (
  select a.msisdn, a.flag
    , b.order_type, b.dealer_id, b.salesperson, b.submitted_by
    , a.product_id, a.pkg_nm, a.network_flag, a.pfx_hlr, a.hlr_region, a.hlr_branch, a.hlr_city
    , a.bill_date, a.bill_cycle
    , observation_date dt_id
  from `data-bi-prd-935c.bi_stg.hg_tmp_pstpaid_ga_churn` a
  inner join (
    select distinct a.*
    from new_reg_dly a
    left join `data-bi-prd-935c.bi_stg.hg_tmp_pstpaid_order` b
      on a.msisdn_ac=b.msisdn_ac and a.dt_id=b.dt_id
        and b.order_type in ('Terminate','Postpaid To Prepaid','Port Out Migration','Suspend')
    where b.msisdn_ac is null
  ) b
    on a.msisdn_ac=b.msisdn_ac
  where a.flag='1. GA (Daily)'
),
ga_mtd as (
  select a.msisdn, a.flag
    , b.order_type, b.dealer_id, b.salesperson, b.submitted_by
    , a.product_id, a.pkg_nm, a.network_flag, a.pfx_hlr, a.hlr_region, a.hlr_branch, a.hlr_city
    , a.bill_date, a.bill_cycle
    , observation_date dt_id
  from `data-bi-prd-935c.bi_stg.hg_tmp_pstpaid_ga_churn` a
  inner join (
    select distinct a.*
    from new_reg_dly a
    left join `data-bi-prd-935c.bi_stg.hg_tmp_pstpaid_order` b
      on a.msisdn_ac=b.msisdn_ac
        and b.order_type in ('Terminate','Postpaid To Prepaid','Port Out Migration','Suspend')
      where b.msisdn_ac is null or (b.msisdn_ac is not null and b.dt_id < a.dt_id)
  ) b
    on a.msisdn_ac=b.msisdn_ac
  where a.flag='2. GA (EOP)'
)
select * from ga_dly
union all
select * from ga_mtd
;


-- data-bi-prd-935c.bi_mart.cst_pstpaid_churn_v1
-- CREATE OR REPLACE TABLE `data-bi-prd-935c.bi_dm.hg_tmp_pstpaid_churn_test` AS 
delete from `data-bi-dev-e36d.bi_mart.cst_pstpaid_churn_v1` where dt_id = observation_date;
INSERT INTO `data-bi-dev-e36d.bi_mart.cst_pstpaid_churn_v1`
with
tday_subs_st as (
  select concat(msisdn,'|',ac_num) msisdn_ac, ac_st
  from `data-bi-prd-935c.bi_mart.cst_pstpaid_rtl_v1`
  where date(dt_id) = observation_date
),
churn_dly as (
  select a.msisdn, a.flag, case when c.ac_st='Suspended' then 'Suspended' else 'Termination' end flag_dtl
    , b.order_type, a.dealer_id, b.salesperson, b.submitted_by
    , a.product_id, a.pkg_nm, a.network_flag, a.pfx_hlr, a.hlr_region, a.hlr_branch, a.hlr_city
    , a.bill_date, a.bill_cycle
    , observation_date dt_id
  from `data-bi-prd-935c.bi_stg.hg_tmp_pstpaid_ga_churn` a
  left join `data-bi-prd-935c.bi_stg.hg_tmp_pstpaid_order` b
    on a.msisdn_ac = b.msisdn_ac and date(b.dt_id) = observation_date
  left join tday_subs_st c
    on a.msisdn_ac=c.msisdn_ac
  where flag='1. CHURN (Daily)'
),
churn_mtd as (
  select a.msisdn, a.flag, case when c.ac_st='Suspended' then 'Suspended' else 'Termination' end flag_dtl
    , b.order_type, a.dealer_id, b.salesperson, b.submitted_by
    , a.product_id, a.pkg_nm, a.network_flag, a.pfx_hlr, a.hlr_region, a.hlr_branch, a.hlr_city
    , a.bill_date, a.bill_cycle
    , observation_date dt_id
  from `data-bi-prd-935c.bi_stg.hg_tmp_pstpaid_ga_churn` a
  left join (
    select * from (
      select *, row_number() over(partition by msisdn_ac order by dt_id desc) as rk
      from `data-bi-prd-935c.bi_stg.hg_tmp_pstpaid_order`
    ) x
    where rk=1
  ) b
    on a.msisdn_ac=b.msisdn_ac
  left join tday_subs_st c
    on a.msisdn_ac=c.msisdn_ac
  where flag='2. CHURN (EOP)'
)
select * from churn_dly
union all
select * from churn_mtd
;

drop table `data-bi-prd-935c.bi_stg.hg_tmp_pstpaid_ga_churn`;
drop table `data-bi-prd-935c.bi_stg.hg_tmp_pstpaid_order`;
