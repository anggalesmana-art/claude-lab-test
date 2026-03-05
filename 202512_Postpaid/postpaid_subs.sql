########################################################################################################################################################################################
# CREATED BY    : Herwin Goernia
# CREATION DATE : 2024-07-31
# DESCRIPTION   : Postpaid Retail Subs - Postpaid MTD
#
# EXECUTE
# sh hg_postpaid_subs_mnl.sh <start_dt> <end_dt> # OLD in IMPALA 
#
# HISTORY
# 2024-07-31  ; Herwin Goernia  			; Initial Release
# 2025-08-15  ; Timotius Yakti Sih Gumelar  ; Adjust Date because Completion Date back to Normal
# 2025-08-26  ; Timotius Yakti Sih Gumelar  ; Seperate GA and BASE to Define Subs Base 

# MIGRATE GCP
# 2025-12-31  ; Timotius Yakti Sih G		; Initial Release
########################################################################################################################################################################################



DECLARE observation_date DATE DEFAULT @vdt_id;

CREATE OR REPLACE TABLE `data-bi-prd-935c.bi_stg.hg_tmp_postpaid_siebel_order` AS 
select
	account_num ac_num
	, regexp_replace(msisdn, "[^0-9.]", "") msisdn
	, assetname ast_nm
	, case
		when order_type in ('Terminate','Postpaid To Prepaid','Port Out Migration') then 'Terminated'
		when order_type = 'Suspend' then 'Suspended'
		when order_type = 'Modify Block Status' and block_status='Soft Block' then 'SoftBlocked'
		when order_type = 'Modify Block Status' and block_status='Hard Block' then 'HardBlocked'
		else 'Active'
	end ast_st
	, reason ast_st_reason
	, `action`
	, order_type
	, y.product_id
	, main_package
	, dealer_id, channel
	, salesperson
	, card_type
	, completion_date ast_latest_actvn_dt
	, case 
		when order_type in ('New Registration','Port In Migration','Migration', 'New Registration From Prepaid') then completion_date 
		else NULL
	end ast_actvn_dt
	, case
		when x.end_dt = '' then cast(null as timestamp) 
		when coalesce((parse_timestamp('%d-%m-%Y %H:%M:%S', x.end_dt)), cast(null as timestamp)) is not null then cast(parse_timestamp('%d-%m-%Y %H:%M:%S', x.end_dt) as timestamp) 
		else cast(null as timestamp) 
	end contract_expiry_dt
from (
	select *, row_number() over(partition by regexp_replace(msisdn, "[^0-9.]", "") order by completion_date desc, action asc) rk
	from `data-dtp-prd-aa1a.stg.stg_siebel_dly_ordr`
	where date(dt_id) >= date_sub(date(observation_date), interval 1 day)
		and date(dt_id) <= observation_date
		and date(DATETIME(completion_date, 'Asia/Jakarta')) = observation_date
		and msisdn like '628%'
		and integration_status='Success'
) x
left join `data-bi-prd-935c.bi_mart.ref_pstpaid_rtl_pkg` y
on x.main_package = y.pkg_nm
where x.rk=1;


CREATE OR REPLACE TABLE `data-bi-prd-935c.bi_stg.hg_tmp_postpaid_siebel_asset` AS 
select
	account_id ac_id
	, regexp_replace(service_number, "[^0-9.]", "") msisdn
	, asset_name ast_nm
	, case
		when REGEXP_CONTAINS(status, r'(?i)inactive|nactive|inative') then 'Inactive'
		when REGEXP_CONTAINS(status, r'(?i)suspend') then 'Suspended'
		when status='Active' and block_status='Soft Block' then 'SoftBlocked'
		when status='Active' and block_status='Hard Block' then 'HardBlocked'
		else status
	end ast_st
	, reason ast_st_reason
	, activation_date ast_actvn_dt
	, last_update_date ast_latest_actvn_dt
	, termination_date ast_termination_dt
	, contract_code ast_dealer_code
	, iccid ast_iccid, imsi ast_imsi
	, x.product ast_product_id
	, y.pkg_nm ast_pkg_nm
	, observation_date as dt_id
from (
	select *, row_number() over(
			partition by regexp_replace(service_number, "[^0-9.]", "")
			order by
				case when date(last_update_date) < date(activation_date) then date(activation_date) 
				else date(last_update_date) 
			end desc
			, ppn_dttm desc
		) rk
	from `data-dtp-prd-aa1a.stg.stg_siebel_dly_asset`
	where date(dt_id) >= date_sub(date(observation_date), interval 1 day)
		and date(dt_id) <= observation_date
		and date(last_update_date)<=observation_date
		and date(coalesce(activation_date,last_update_date)) <= date_add(observation_date, interval 1 day)
		and (date(termination_date)>observation_date or date(termination_date) is null)
		and coalesce(regexp_replace(service_number, "[^0-9.]", ""),"")!=""
) x
left join `data-bi-prd-935c.bi_mart.ref_pstpaid_rtl_pkg` y
	on x.product=y.product_id and date(x.dt_id) BETWEEN  date(FORMAT_DATE('%Y-%m-%d', PARSE_DATE('%Y%m%d', cast(y.eff_dt as string)))) AND date(FORMAT_DATE('%Y-%m-%d', PARSE_DATE('%Y%m%d', cast( y.end_dt as string))))
where rk=1
;

CREATE OR REPLACE TABLE `data-bi-prd-935c.bi_stg.hg_tmp_postpaid_siebel_asset_order` AS 
select a.ac_id, a.msisdn, coalesce(b.ast_nm, a.ast_nm) ast_nm
	, coalesce(b.ast_st, a.ast_st) ast_st
	, coalesce(b.ast_st_reason, a.ast_st_reason) ast_st_reason
	, coalesce(b.ast_actvn_dt, a.ast_actvn_dt) ast_actvn_dt
	, coalesce(b.ast_latest_actvn_dt, a.ast_latest_actvn_dt) ast_latest_actvn_dt
	, case
	    when b.ast_st='Terminated' then b.ast_latest_actvn_dt 
	    else ast_termination_dt 
	  end ast_termination_dt
	, contract_expiry_dt ast_contract_expiry_dt
	, coalesce(b.dealer_id, a.ast_dealer_code) ast_dealer_code
    , coalesce(b.product_id, a.ast_product_id) ast_product_id
	, coalesce(b.main_package, a.ast_pkg_nm) ast_pkg_nm
	, observation_date as dt_id
from `data-bi-prd-935c.bi_stg.hg_tmp_postpaid_siebel_asset` a
left join `data-bi-prd-935c.bi_stg.hg_tmp_postpaid_siebel_order` b
	on a.msisdn=b.msisdn
;


CREATE OR REPLACE TABLE `data-bi-prd-935c.bi_stg.hg_tmp_postpaid_siebel_account` AS 
select customerid cust_id, accountid ac_id, account_num ac_num, accountname ac_nm
	, regexp_replace(account_status,'-','') ac_st, account_status_reason ac_st_reason
	, case when go_live_date>account_status_date then account_status_date else go_live_date end ac_actvn_dt
	, case when go_live_date>account_status_date then go_live_date else account_status_date end ac_st_dt
	, last_update_date ac_last_upd_dt
	, bill_date ac_bill_dt, credit_class ac_credit_class, id_type ac_id_type, id_reference ac_id_ref, day_phone_number
from (
	select *, row_number() over(
			partition by account_num
			order by case
				when last_update_date < (case when go_live_date>account_status_date then go_live_date else account_status_date end) then account_status_date
				else last_update_date
				end desc
				, ppn_dttm desc
		) rk
	from `data-dtp-prd-aa1a.stg.stg_siebel_dly_acc`
	where date(dt_id) >= date_sub(date(observation_date), interval 1 day)
		and date(dt_id) <= observation_date
		and date(coalesce(account_status_date,last_update_date))<=date_add(observation_date, interval 1 day)
		and date(last_update_date)<=observation_date
) x
where rk=1
;

CREATE OR REPLACE TABLE `data-bi-prd-935c.bi_stg.hg_tmp_postpaid` AS 
WITH SUBSGA AS (
    select regexp_replace(a.msisdn, "[^0-9.]", "") msisdn, a.account_id ac_id, a.account_num ac_num, a.customer_type
    from (
        select *, ROW_NUMBER() over(partition by regexp_replace(msisdn, "[^0-9.]", "") order by coalesce(date(activation_date),date('1990-01-01')) desc) rk
        from `data-dtp-prd-aa1a.sor.postpaid_asset_rtl`
        where date(dt_id) >= date_sub(date(observation_date), interval 1 day)
        and date(dt_id) <=  observation_date
        and msisdn in (
            select distinct msisdn
            from `data-dtp-prd-aa1a.stg.stg_siebel_dly_ordr`
            where date(dt_id) = observation_date
            and date(DATETIME(completion_date, 'Asia/Jakarta')) = observation_date
            and msisdn like '628%'
            and integration_status='Success'
            and order_type in ('New Registration','Port In Migration','Migration', 'New Registration From Prepaid')
        )
        and (trim(lower(customer_type)) in ('individual','vvip', 'smb') or customer_type is null)
    ) a
    left join `data-bi-prd-935c.bi_stg.hg_tmp_postpaid_siebel_order` b
    	on regexp_replace(a.msisdn, "[^0-9.]", "")=b.msisdn
    		and TRIM(UPPER(order_type)) IN ('PORT OUT MIGRATION','POSTPAID TO PREPAID','TERMINATE')
    where rk=1 and b.msisdn is null
),
RECURRINGSUBS AS (
select regexp_replace(a.msisdn, "[^0-9.]", "") msisdn, a.account_id ac_id, a.account_num ac_num, a.customer_type
from (
	select *, ROW_NUMBER() over(partition by regexp_replace(msisdn, "[^0-9.]", "") order by coalesce(date(activation_date),date('1990-01-01')) desc) rk
	from `data-dtp-prd-aa1a.sor.postpaid_asset_rtl`
	where date(dt_id) >= date_sub(date(observation_date), interval 1 day)
		and date(dt_id) <= observation_date
		and coalesce(date(DATETIME(activation_date, 'Asia/Jakarta')),cast('1990-01-01' as DATE)) <= date_add(observation_date, interval 1 day)
		and (
      trim(lower(customer_type)) in ('individual','vvip', 'smb') or 
      (
        customer_type is null and 
        format_date('%Y-%m', DATETIME(activation_date, 'Asia/Jakarta')) >= '2025-11'
      )
    )
		and msisdn like '628%'
		and msisdn not in (
		    select distinct msisdn
		    from SUBSGA
		)
) a
left join `data-bi-prd-935c.bi_stg.hg_tmp_postpaid_siebel_order` b
	on regexp_replace(a.msisdn, "[^0-9.]", "")=b.msisdn
		and TRIM(UPPER(order_type)) IN ('PORT OUT MIGRATION','POSTPAID TO PREPAID','TERMINATE')
where rk=1 and b.msisdn is null
)
select * from SUBSGA
union all
select * from RECURRINGSUBS
;

delete from `data-bi-dev-e36d.bi_mart.cst_pstpaid_rtl_v1` where dt_id = observation_date;
-- data-bi-prd-935c.bi_mart.cst_pstpaid_rtl_v1
-- CREATE OR REPLACE TABLE `data-bi-prd-935c.bi_dm.hg_tmp_postpaid_dev_check` AS 
insert into `data-bi-dev-e36d.bi_mart.cst_pstpaid_rtl_v1`
select 
  a.msisdn
  , b.ast_st
  , c.ac_st
  , a.customer_type
  , b.ast_dealer_code actvn_cnl
  , b.ast_termination_dt termination_date
  , b.ast_actvn_dt activation_date
  , c.ac_actvn_dt ac_activation_date
  , c.ac_nm account_name
  , b.ast_product_id product_id
  , b.ast_pkg_nm pkg_nm
  , d.network_flag
  , safe_cast(d.pfx_hlr as int64)
  , NULL hlr_region, NULL hlr_branch, NULL hlr_city
  , c.ac_bill_dt bill_date
  , case
      when cast(c.ac_bill_dt as int) < 8 then "1"
      when cast(c.ac_bill_dt as int) < 12 then "2"
      when cast(c.ac_bill_dt as int) < 16 then "3"
      when cast(c.ac_bill_dt as int) < 20 then "4"
      when cast(c.ac_bill_dt as int) < 24 then "5"
      when cast(c.ac_bill_dt as int) < 28 then "6"
      else "7"
    end bill_cycle
  , a.ac_id
  , a.ac_num
  , d.card_tp card_type
  , current_timestamp() ppn_dttm
  , b.ast_contract_expiry_dt contract_expiry_dt
  , b.ast_latest_actvn_dt
  , c.ac_st_dt
  , d.imei
  , b.ast_st_reason
  , c.ac_st_reason
  , observation_date dt_id
from `data-bi-prd-935c.bi_stg.hg_tmp_postpaid` a
left join `data-bi-prd-935c.bi_stg.hg_tmp_postpaid_siebel_asset_order` b
  on a.msisdn=b.msisdn
left join `data-bi-prd-935c.bi_stg.hg_tmp_postpaid_siebel_account` c
  on a.ac_id=c.ac_id
left join (
  select distinct ac_num, msisdn, network_flag, imei, card_tp
    , case when a.pfx_hlr in ('6281573', '6285794', '6285795', '6285860', '6285861') then substr(msisdn, 1, 8) else a.pfx_hlr end as pfx_hlr
  from `data-dtp-prd-aa1a.smy.ar_cst_pstpaid_rtl` a
  left join (
    select tac, network_flag from `data-bi-prd-935c.bi_mart.ref_hset_adm`
    ) b
  on a.tac = b.tac
  where date(dt_id) = observation_date
) d
  on a.msisdn=d.msisdn
where lower(b.ast_st) not in ('inactive','pending','terminated') and b.ast_st is not null;

drop table `data-bi-prd-935c.bi_stg.hg_tmp_postpaid_siebel_order`;
drop table `data-bi-prd-935c.bi_stg.hg_tmp_postpaid_siebel_asset`;
drop table `data-bi-prd-935c.bi_stg.hg_tmp_postpaid_siebel_asset_order`;
drop table `data-bi-prd-935c.bi_stg.hg_tmp_postpaid_siebel_account`;
drop table `data-bi-prd-935c.bi_stg.hg_tmp_postpaid`;


