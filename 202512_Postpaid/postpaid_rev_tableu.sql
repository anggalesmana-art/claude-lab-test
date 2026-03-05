DECLARE observation_date DATE DEFAULT @vdt_id;

-- -- stage 1: Count of Subscriber Account
-- drop table if exists biadm.hg_tmp_postpaid_billrev_acnum_${var:dt_id} purge;
-- create table biadm.hg_tmp_postpaid_billrev_acnum_${var:dt_id} stored as parquet as
CREATE OR REPLACE TABLE `data-bi-prd-935c.bi_stg.hg_tmp_postpaid_billrev_acnum` AS
select ac_num, count(distinct msisdn) nsubs
from `data-bi-prd-935c.bi_mart.cst_pstpaid_rtl_v1`
where dt_id = observation_date
group by 1
;
 
-- stage 2: Additional Informations
-- drop table if exists biadm.hg_tmp_postpaid_billrev_info_${var:dt_id} purge;
-- create table biadm.hg_tmp_postpaid_billrev_info_${var:dt_id} stored as parquet as
CREATE OR REPLACE TABLE `data-bi-prd-935c.bi_stg.hg_tmp_postpaid_billrev_info` AS
select a.ac_num, a.msisdn, date(format_date('%Y-%m-%d', a.activation_date)) actvn_dt
	, trim(upper(a.pkg_nm)) pkg_nm
	, trim(upper(coalesce(d.product_type, "UNK"))) pkg_cat
	, trim(upper(b.region)) region
	, trim(upper(c.dealer_id)) dealer_id
	, min(a.dt_id) min_dt
	, max(a.dt_id) max_dt
from `data-bi-prd-935c.bi_mart.cst_pstpaid_rtl_v1` a
left join `data-bi-prd-935c.bi_mart.pstpaid_ref_region` b
	on trim(upper(cast(a.pfx_hlr as string))) = trim(upper(cast(b.pfx_hlr as string)))
left join `data-bi-prd-935c.bi_mart.ref_pstpaid_rtl_dealer` c
	on  UPPER(TRIM(SPLIT(a.actvn_cnl, ' ')[SAFE_OFFSET(0)])) = trim(upper(c.dealer_id))
left join `data-bi-prd-935c.bi_mart.ref_pstpaid_rtl_pkg` d
	on trim(upper(a.pkg_nm)) = trim(upper(d.pkg_nm))
where date(dt_id) > DATE_SUB(observation_date, INTERVAL 90 DAY) and date(dt_id) <= observation_date
group by 1,2,3,4,5,6,7
;
 
-- stage 3a: Create temp table for billing revenue (prepare only for july)
-- biadm.hg_tmp_postpaid_billing_rev_202308 ini untuk comparasi
-- drop table if exists biadm.hg_tmp_postpaid_billrev_${var:dt_id} purge;
-- create table biadm.hg_tmp_postpaid_billrev_${var:dt_id} stored as parquet as
CREATE OR REPLACE TABLE `data-bi-prd-935c.bi_stg.hg_tmp_postpaid_billrev` AS
select dt_id
	, CASE
		when cast(format_date('%d', date(dt_id)) as int) between 1 and 7 then '1'
		when cast(format_date('%d', date(dt_id)) as int) between 8 and 11 then '2'
		when cast(format_date('%d', date(dt_id)) as int) between 12 and 15 then '3'
		when cast(format_date('%d', date(dt_id)) as int) between 16 and 19 then '4'
		when cast(format_date('%d', date(dt_id)) as int) between 20 and 23 then '5'
		when cast(format_date('%d', date(dt_id)) as int) between 24 and 27 then '6'
		when cast(format_date('%d', date(dt_id)) as int) between 28 and 31 then '7'
	end as bill_cycle
	, account_number, asset_id msisdn, invoice_number
	, package_name, service_id, service_usage_type, revenue_code_name
	, case when asset_id is not null then 'ASSET NOT NULL' else 'ASSET NULL' end asset_flag
	, sum(cast(amount as numeric)) amount
from `data-dtp-prd-aa1a.stg.rbm_pstpaid_rev_ast`
where lower(customer_type) in ('individual', 'vvip') --B2C
  and filename like '1000_EB%'
	and upper(revenue_code_name) not like '%HIFI%'
	and upper(revenue_code_name) not in (
		'REFILL VOUCHER',
		'STMDTY',
		'VAT010',
		'ADJ025',
		'ADJ018',
		'B2B ADJUSMENT - PPH',
		'DISCCREDITPREPAID',
		'3701000', -- vat
		'3702000', -- vat
		'IM2ADJ02',
		'MIGCREDITADJ',
		'IM2ADJ01',
		'MIGDEBITADJ',
		'BC_DISPADJ',
		'PPH23_DISPADJ',
		'STAMP_DISPADJ',
		'SUBTOTAL_DISPADJ',
		'VAT10_DISPADJ'
	)
	and date(dt_id) = observation_date
group by 1,2,3,4,5,6,7,8,9
;
 
-- stage 3b: Fill-in asset from subcriber base and distribute
-- drop table if exists  biadm.hg_tmp_postpaid_billrev_asset_null_${var:dt_id} purge;
-- create table biadm.hg_tmp_postpaid_billrev_asset_null_${var:dt_id} stored as parquet as
CREATE OR REPLACE TABLE `data-bi-prd-935c.bi_stg.hg_tmp_postpaid_billrev_asset_null` AS
select 
	dt_id,
	bill_cycle,
	a.account_number,
	b.msisdn, 
	invoice_number,
	package_name,
	service_id,
	service_usage_type, 
	revenue_code_name,
	asset_flag,
	sum(a.amount/coalesce(c.nsubs,1)) amount_rev_assets
from `data-bi-prd-935c.bi_stg.hg_tmp_postpaid_billrev` a
left join `data-bi-prd-935c.bi_stg.hg_tmp_postpaid_billrev_info` b
on cast(a.account_number as string) = b.ac_num and date(b.max_dt) = observation_date
left join `data-bi-prd-935c.bi_stg.hg_tmp_postpaid_billrev_acnum` c
on cast(a.account_number as string) = c.ac_num
where asset_flag = 'ASSET NULL'
group by 1,2,3,4,5,6,7,8,9,10;


--- stage 3c: merge between asset not null and asset null
-- drop table if exists biadm.hg_tmp_postpaid_billrev_merge_assets_${var:dt_id} purge;
-- create table biadm.hg_tmp_postpaid_billrev_merge_assets_${var:dt_id} stored as parquet as
CREATE OR REPLACE TABLE `data-bi-prd-935c.bi_stg.hg_tmp_postpaid_billrev_merge_assets` AS
select 
dt_id,bill_cycle,account_number, msisdn, invoice_number,package_name,service_id,
service_usage_type, revenue_code_name,asset_flag,
amount amount_rev_assets
from `data-bi-prd-935c.bi_stg.hg_tmp_postpaid_billrev`
where asset_flag = 'ASSET NOT NULL'
union all
select * from `data-bi-prd-935c.bi_stg.hg_tmp_postpaid_billrev_asset_null`;

 
--  data-bi-prd-935c.bi_mart.postpaid_rev_tbleu
--- stage 3d: add some informations
-- insert overwrite biadm.rk_postpaid_rev_tbleu partition(dt_id)
-- CREATE OR REPLACE TABLE `data-bi-prd-935c.bi_dm.hg_temp_rk_postpaid_rev_tbleu_test` AS


delete from `data-bi-dev-e36d.bi_mart.postpaid_rev_tbleu` where dt_id = observation_date;
insert into `data-bi-dev-e36d.bi_mart.postpaid_rev_tbleu`
select 
account_number ac_num,
a.msisdn,
invoice_number,
coalesce(package_name,"UNK") pkg_nm,
service_usage_type,
revenue_code_name rev_code,
amount_rev_assets amt_rev,
tenure,
coalesce(c.dealer_id, "UNK") channel, 
coalesce(d.region, "UNK") region,
coalesce(b.pkg_cat, "UNK") pkg_cat,
bill_cycle,
service_id,
cast(a.dt_id as date) dt_id
from 
(select * from `data-bi-prd-935c.bi_stg.hg_tmp_postpaid_billrev_merge_assets`) a
left join (
    	select distinct 
				msisdn
				, DATE_DIFF(date(max_dt), date(actvn_dt), DAY) tenure
				, timestamp(actvn_dt) activation_date
				, max_dt
    	, pkg_nm, coalesce(region, "UNK") region, coalesce(pkg_cat, "UNK") pkg_cat
    	from `data-bi-prd-935c.bi_stg.hg_tmp_postpaid_billrev_info`
    	where  date(max_dt) = observation_date
) b
on a.msisdn = b.msisdn 
left join (
    select msisdn, dealer_id, row_number() over(partition by msisdn order by max_dt desc) rownum
    from `data-bi-prd-935c.bi_stg.hg_tmp_postpaid_billrev_info` 
    where date(max_dt) >= date_sub(observation_date, interval 60 day) 
    and dealer_id is not null
) c
	on a.msisdn = c.msisdn and c.rownum = 1
left join (
    select msisdn, region,row_number() over(partition by msisdn order by max_dt desc) rownum
    from `data-bi-prd-935c.bi_stg.hg_tmp_postpaid_billrev_info`
    where date(max_dt) >= date_sub(observation_date, interval 60 day) 
    and coalesce(region, "UNK") not in ("UNK", "nan")
) d
	on a.msisdn = d.msisdn and d.rownum = 1;

 
-- drop temp table
drop table `data-bi-prd-935c.bi_stg.hg_tmp_postpaid_billrev_acnum`;
drop table `data-bi-prd-935c.bi_stg.hg_tmp_postpaid_billrev_info`;
drop table `data-bi-prd-935c.bi_stg.hg_tmp_postpaid_billrev`;
drop table `data-bi-prd-935c.bi_stg.hg_tmp_postpaid_billrev_asset_null`;
drop table `data-bi-prd-935c.bi_stg.hg_tmp_postpaid_billrev_merge_assets`;