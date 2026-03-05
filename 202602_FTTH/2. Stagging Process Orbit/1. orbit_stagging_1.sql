DECLARE observation_date DATE DEFAULT DATE_SUB(current_date("Asia/Jakarta"), INTERVAL 1 day);
DECLARE ysday_date DEFAULT format_date('%Y-%m-%d', date(observation_date) - INTERVAL 1 day);

CREATE OR REPLACE TABLE `data-bi-prd-935c.bi_dm.tysg_ftth_stg_subs_1` as
WITH MNCSUBSCRIBER AS (
  select
	distinct
	ca_id,
	ba_id,
	ac_refr,
	ac_nm,
	ac_st,
	date(FORMAT_TIMESTAMP('%Y-%m-%d', PARSE_TIMESTAMP('%d-%m-%Y %H:%M:%S', ac_st_dt))) AS ac_st_dt,
	-- date(FORMAT_TIMESTAMP('%Y-%m-%d', PARSE_TIMESTAMP('%d-%m-%Y %H:%M:%S', last_udt_dt))) AS last_udt_dt,
	format_date('%Y-%m-%d', dt_id) dt_id
  from `data-dtp-prd-aa1a.stg.stg_catalist_dly_ba`
  where dt_id between timestamp(observation_date) and timestamp(observation_date)
  and length(ac_refr) = 10
	and cr_clss = "FTTH Customer"
),
MTXMNC AS (
  select
	distinct
	customer_id,
	billing_account,
	format_date('%Y-%m-%d', dt_id) dt_id
  from `data-dtp-prd-aa1a.dm.ftth_subscriber`
  where
   dt_id between timestamp(observation_date) and timestamp(observation_date)
  and billing_account in (select ac_refr from MNCSUBSCRIBER)
),
JOINING AS (
  select
	a.customer_id as customer_id,
	a.billing_account as billing_account,
	concat(a.customer_id, "-", a.billing_account) as cust_bill_id,
	b.ca_id,
	b.ba_id,
	b.ac_st,
	b.ac_st_dt,
	a.dt_id
  from MTXMNC a
  left join MNCSUBSCRIBER b 
  on a.billing_account = b.ac_refr and a.dt_id = b.dt_id
),
OrbitData AS (
  select
	customer_id,
	customer_status,
	--kota,
	flag_name,
	so_date,
	preactivation_date as sa_date,
	permanent_date pa_date,
	case
	  when current_package is null or current_package = '-' then first_package
	  else current_package
	end as package_nm,
	case
	  when current_package_price is null or current_package_price = '-' then first_package_price
	  else current_package_price
	end as current_package_price,
	case
	  when current_package_date is null then permanent_date
	  else current_package_date
	end as current_package_date,
	customer_status_date,
	aging_duration,
	tanggal_instal
  from `data-dtp-prd-aa1a.stg.orbit_com_cumulative_subs`
  where dt_id = '2024-10-19'
),
JOINEDORBIT AS (
  select
	a.customer_id,
	a.billing_account,
	a.cust_bill_id,
	a.ca_id,
	a.ba_id,
	ac_st,
	a.ac_st_dt,
	b.customer_status,
	b.flag_name,
	b.so_date,
	b.sa_date,
	b.pa_date,
	b.current_package_date,
	b.package_nm,
	b.current_package_price,
	c.vendor,
	c.site_id,
	a.dt_id
  from JOINING a
  left join OrbitData b on a.billing_account=b.customer_id
  left join `data-bi-prd-935c.bi_dm.tysg_ftth_ast_orbit` c on a.billing_account = c.customer_id
),
FINALORBIT AS (
  select
	customer_id,
	billing_account,
	cust_bill_id,
	ca_id,
	ba_id,
	ac_st,
	ac_st_dt,
	case 
	  when ac_st='Hard Block' and DATE_DIFF(date(dt_id), date(ac_st_dt), DAY) <= 30 then 'Suspension-Bucket 1'
	  when ac_st='Hard Block' and DATE_DIFF(date(dt_id), date(ac_st_dt), DAY) < 45 then 'Suspension-Bucket 2'
	  when ac_st='Hard Block' and DATE_DIFF(date(dt_id), date(ac_st_dt), DAY) >= 45 then 'Suspension-Backlog Churn'
	  when ac_st='Terminate' then 'Terminate'
		when ac_st='Inactive' then 'Inactive'
	  else 'Active'
	END AS flag_account,
	date(so_date) as so_date,
	date(sa_date) as sa_date,
	date(pa_date) as pa_date,
	date(current_package_date) as current_package_date,
	package_nm,
	cast(current_package_price as int64) as current_package_price,
	vendor,
	site_id,
	date(dt_id) as dt_id
  from JOINEDORBIT
),
CHURNTABLEORDER AS (
  select * except(rk) from (
		select
			billing_account,
      account_status_reason,
      'Terminate' ac_st,
			cast (order_open_date as date) order_open_date,
			row_number() over(partition by concat(customer_id,billing_account) order by date(order_open_date) asc) as rk
		FROM `data-dtp-prd-aa1a.dm.ftth_subscriber_order_history`
		WHERE TIMESTAMP_TRUNC(dt_id, DAY) between TIMESTAMP("2024-10-22") and TIMESTAMP('2025-02-20') ---ganti sesuai tanggal yg dicari (harus pakai between, karena jika sudah dicompletekan ordernya, maka di order history sudah tidak mencatat)
		and TIMESTAMP_TRUNC(order_open_date, DAY) between TIMESTAMP("2024-10-22") and TIMESTAMP('2025-02-20') --stop customer jurney terminasi order open
		and order_type='Terminate'
		and account_status_reason!='DELETION BY MASS TERMINATION' --> part of cancel pre_activation.
		and account_status_reason!='DELETION-OTHERS'
		and account_status_reason!='DELETION BY MUTATION' -->
		and account_status_reason!='DELETION-PROYEK/EVENT SELESAI'
    and upper(account_status_reason) not like '%UNBLOCK%'
		and account_status_reason!=""
		and regexp_contains(billing_account, r'^\d{10}$')
		order by order_open_date asc
  ) a where rk=1
),
CHURNTABLEBA AS (
  select
    ac_refr billing_account,
    case
      when hs_st = '-' or hs_st is null then ac_st_rsn
      else hs_st
    end as account_status_reason,
    ac_st,
    date(FORMAT_TIMESTAMP('%Y-%m-%d', PARSE_TIMESTAMP('%d-%m-%Y %H:%M:%S', ac_st_dt))) as order_open_date
  from `data-dtp-prd-aa1a.stg.stg_catalist_dly_ba`
  where dt_id = timestamp(observation_date)
  and ac_st = 'Terminate'
  and cr_clss = 'FTTH Customer'
  and length(ac_refr) = 10
),
CHURNTABLE AS (
  select * from CHURNTABLEORDER
  union all
  select * from CHURNTABLEBA
),
FINALDATA AS (
	select * except(rk) from (
		select
		a.customer_id,
		a.billing_account,
		a.cust_bill_id,
		a.ca_id,
		a.ba_id,
		case
			when b.account_status_reason like 'RECONNECT%' then a.ac_st
			when b.account_status_reason not in ('SUSPENDED', 'ACTIVE') then 'Terminate'
			else a.ac_st
		end as ac_st,
		case
			when b.account_status_reason like 'RECONNECT%' then a.ac_st_dt
			when b.account_status_reason not in ('SUSPENDED', 'ACTIVE') then b.order_open_date
			-- when b.account_status_reason like 'DELETION%' then b.order_open_date
			-- when b.account_status_reason like 'TR-ADMIN' then b.order_open_date
			-- when b.account_status_reason like 'DAMAGE - PRODUCTION' then b.order_open_date
			-- when b.account_status_reason like 'REVOL' then b.order_open_date
			else a.ac_st_dt
		end as ac_st_dt,
		case
			when b.account_status_reason like 'RECONNECT%' then b.account_status_reason
			when b.account_status_reason not in ('SUSPENDED', 'ACTIVE') then b.account_status_reason
			-- when b.account_status_reason like 'DELETION%' then b.account_status_reason
			-- when b.account_status_reason like 'TR-ADMIN' then b.account_status_reason
			-- when b.account_status_reason like 'DAMAGE - PRODUCTION' then b.account_status_reason
			-- when b.account_status_reason like 'REVOL' then b.account_status_reason
			when a.flag_account like 'Suspension%' then 'SUSPENDED'
			else 'ACTIVE'
		end as ac_st_reason,
		case
			when b.account_status_reason like 'RECONNECT%' then a.flag_account
			when b.account_status_reason not in ('SUSPENDED', 'ACTIVE') then 'Terminate'
			-- when b.account_status_reason like 'DELETION%' then 'Terminate'
			-- when b.account_status_reason = 'TR-ADMIN' then 'Terminate'
			-- when b.account_status_reason like 'DAMAGE - PRODUCTION' then 'Terminate'
			else a.flag_account
		END AS flag_account,
		date(so_date) as so_date,
		date(sa_date) as sa_date,
		date(pa_date) as pa_date,
		date(current_package_date) as current_package_date,
		package_nm,
		cast(current_package_price as int64) as current_package_price,
		vendor,
		site_id,
		date(a.dt_id) as dt_id,
		timestamp(DATETIME(CURRENT_TIMESTAMP(), "Asia/Jakarta")) as prc_dt,
		row_number() over(partition by a.billing_account order by dt_id desc) rk
		from FINALORBIT a
		left join CHURNTABLE b
		on a.billing_account=cast(b.billing_account as string) and DATE(a.dt_id) >= date(b.order_open_date)
	) a
	where rk = 1
)
select * from FINALDATA;

delete from `data-bi-prd-935c.bi_dm.tysg_ftth_stg_orbit_subs`
where dt_id = observation_date;

INSERT INTO `data-bi-prd-935c.bi_dm.tysg_ftth_stg_orbit_subs`
select
	a.customer_id,
	a.billing_account,
	a.cust_bill_id,
	a.ca_id,
	a.ba_id,
	a.ac_st,
	a.ac_st_dt,
	a.ac_st_reason,
	a.flag_account,
	a.so_date,
	a.sa_date,
	a.pa_date,
	a.current_package_date,
	a.package_nm legacy_package,
	coalesce(
		case
			when lower(b.pd_nm) = "hifi internet" then a.package_nm
			else b.pd_nm
		end,
		c.current_package
	) current_package,
	a.current_package_price,
	a.vendor,
	a.site_id,
	a.dt_id,
	timestamp(DATETIME(CURRENT_TIMESTAMP(), "Asia/Jakarta")) as prc_dt
from (
	select * from `data-bi-prd-935c.bi_dm.tysg_ftth_stg_subs_1`
	where dt_id = date(observation_date)
) a
left join (
	select distinct ba_id, pd_nm, pd_tp, dt_id
	from `data-dtp-prd-aa1a.stg.stg_catalist_dly_ast`
	where date(dt_id) = observation_date
	and pd_tp = "Plan"
	and ast_st = "Active"
	and lower(pd_nm) like '%hifi%'
) b
on a.ba_id = b.ba_id and a.dt_id = date(b.dt_id)
left join (
	select distinct ba_id, current_package from `data-bi-prd-935c.bi_dm.tysg_ftth_orbit_cumulative_subs`
	where dt_id = date_sub(observation_date, interval 1 day)
) c
on a.ba_id = c.ba_id;
