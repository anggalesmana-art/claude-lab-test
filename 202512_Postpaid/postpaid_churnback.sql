########################################################################################################################################################################################
# CREATED BY    : Timotius Yakti Sih Gumelar 
# CREATION DATE : 2025-08-31
# DESCRIPTION   : Postpaid Gross Add Churn - Postpaid MTD
#
# EXECUTE
# sh hg_postpaid_subs_mnl.sh <start_dt> <end_dt> # OLD in IMPALA 
#
# HISTORY
# 2025-08-15  ; Timotius Yakti Sih Gumelar  ; Initial Release
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
select a.*, '1. GA (Daily)' flag, observation_date dt_id
from tday_closing a
left join yday_closing b
  on a.msisdn_ac=b.msisdn_ac
where b.msisdn_ac is null
union all
-- GA MTD
select a.*, '2. GA (EOP)' flag, observation_date dt_id
from tday_closing a
left join prev_closing b
  on a.msisdn_ac=b.msisdn_ac
where b.msisdn_ac is null
union all
-- Churn Daily
select a.*, '1. CHURN (Daily)' flag, observation_date dt_id
from yday_closing a
left join tday_closing b
  on a.msisdn_ac=b.msisdn_ac
where b.msisdn_ac is null
union all
-- Churn MTD
select a.*, '2. CHURN (EOP)' flag, observation_date dt_id
from prev_closing a
left join tday_closing b
  on a.msisdn_ac=b.msisdn_ac
where b.msisdn_ac is null
;


--- TEMP Order
CREATE OR REPLACE TABLE `data-bi-prd-935c.bi_stg.hg_tmp_pstpaid_order` AS 
select format_date('%Y-%m-%d', DATETIME(completion_date, 'Asia/Jakarta')) dt_id
  , concat(regexp_replace(msisdn, "[^0-9.]", ""),'|',account_num) msisdn_ac, regexp_replace(msisdn, "[^0-9.]", "") msisdn
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
 

-- CREATE OR REPLACE TABLE `data-bi-prd-935c.bi_dm.hg_tmp_pstpaid_cb_test` AS 
delete from `data-bi-dev-e36d.bi_mart.cst_pstpaid_cb_v1` where dt_id = observation_date;
INSERT INTO `data-bi-dev-e36d.bi_mart.cst_pstpaid_cb_v1`
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
GARECORDED AS (
	select
		*,
		'GA' flag_stats
	from `data-bi-prd-935c.bi_mart.cst_pstpaid_ga_v1`
	where date(dt_id) = observation_date
	and flag like '%1%'
	union all
	select
		*,
		'GA' flag_stats
	from `data-bi-prd-935c.bi_mart.cst_pstpaid_ga_v1`
	where date(dt_id) = observation_date
	and flag like '%2%'
),
CHURNBACKDLY AS (
	select 
		a.msisdn
		,'1. CB (Daily)' flag
		, b.order_type
		, b.dealer_id
		, b.salesperson
		, b.submitted_by
		, a.product_id
		, a.pkg_nm
		, a.network_flag
		, a.pfx_hlr
		, a.hlr_region
		, a.hlr_branch
		, a.hlr_city
		, a.bill_date
		, a.bill_cycle
		, observation_date dt_id
    from (
      select a.* from	`data-bi-prd-935c.bi_stg.hg_tmp_pstpaid_ga_churn` a
      left join GARECORDED b
      on a.msisdn=b.msisdn
      where a.flag='1. GA (Daily)'
      and b.msisdn is null
	) a
	left join `data-bi-prd-935c.bi_stg.hg_tmp_pstpaid_order` b
	on a.msisdn = b.msisdn and date(a.dt_id) = date(b.dt_id)
),
CHURNBACKMTD AS (
	select 
		a.msisdn
		, '2. CB (EOP)'  flag
		, b.order_type
		, b.dealer_id
		, b.salesperson
		, b.submitted_by
		, a.product_id
		, a.pkg_nm
		, a.network_flag
		, a.pfx_hlr
		, a.hlr_region
		, a.hlr_branch
		, a.hlr_city
		, a.bill_date
		, a.bill_cycle
		, observation_date dt_id
    from (
      select a.* 
      from `data-bi-prd-935c.bi_stg.hg_tmp_pstpaid_ga_churn` a
      left join GARECORDED b
      on a.msisdn=b.msisdn
      where a.flag='2. GA (EOP)'
      and b.msisdn is null
	) a
	left join `data-bi-prd-935c.bi_stg.hg_tmp_pstpaid_order` b
	on a.msisdn=b.msisdn and date(a.dt_id) <= date(b.dt_id)
)
select * from CHURNBACKDLY
union all 
select * from CHURNBACKMTD
;

drop table `data-bi-prd-935c.bi_stg.hg_tmp_pstpaid_ga_churn`;
drop table `data-bi-prd-935c.bi_stg.hg_tmp_pstpaid_order`;
