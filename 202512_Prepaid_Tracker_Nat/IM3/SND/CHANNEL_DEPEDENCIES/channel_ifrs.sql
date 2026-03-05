declare vdt_id date default @vdt_id;
-- SELLOUT OUTLET
delete from `data-bi-prd-935c.bi_mart`.sellout_salmo_dly where dt_id = vdt_id;
insert into `data-bi-prd-935c.bi_mart`.sellout_salmo_dly
select parse_timestamp('%Y-%m-%d %H:%M:%S', `datetime`) completion_date, channel, organization_type, transaction_type
	, region, area, sales_area, cluster, additional_territory
	, organization_id, msisdn, b_msisdn, product_name
	, cast(main_price as numeric) main_price, cast(amount_debit as numeric) amount_debit
	, timestamp(current_date('+7')), transaction_id
	, voucher_type, bill_number, l1_parent_id, l1_parent_name
  , transaction_channel --added 20230724
	,  date(parse_timestamp('%Y-%m-%d %H:%M:%S', `datetime`)) dt_id
from `data-dtp-prd-aa1a.stg.ifrs_prepaid_salmo` y
where date(parse_timestamp('%Y-%m-%d %H:%M:%S',`datetime`)) = vdt_id
    and lower(transaction_type) in ('purchase data package','bulk purchase package transaction','indosat reload','vouchercardinjection','bulk voucher card injection','bulk reload')
	and lower(status_description) = 'success' and lower(transaction_status) = 'completed'
	and ifnull(channel,'')!=''
	and (upper(coalesce(cluster,'')) not like '%TEST%' and upper(coalesce(cluster,'')) not like '%SEV%')
	and date(process_id) <= date(vdt_id + interval 1 day)
	and coalesce(substring(b_msisdn, 1,5),'') not in ('62895', '62896', '62897', '62898', '62899')
;

--FOSS => Mobo Prepaid Registration
delete from `data-bi-prd-935c.bi_mart`.ga_outlet_mth where month_id = date_trunc(vdt_id,month);
insert into `data-bi-prd-935c.bi_mart`.ga_outlet_mth
select act_date act_date, msisdn, organizationid, cluster_nm, sales_area, area, region, timestamp(current_date('+7')) ppn_dttm, date_trunc(vdt_id,month) month_id
from
(
	select act_date, msisdn, organizationid, cluster_nm, sales_area, area, region
		, ROW_NUMBER() over(partition by msisdn order by act_date desc) rk
	from
	(
		select date(parse_timestamp('%Y-%m-%d %H:%M:%S',`datetime`)) act_date, concat('62',b_msisdn) msisdn,
        organization_id organizationid, cluster cluster_nm, sales_area, area, region
        FROM `data-dtp-prd-aa1a.stg.ifrs_prepaid_salmo`
        where date(parse_timestamp('%Y-%m-%d %H:%M:%S', `datetime`)) between date_trunc(vdt_id,month) and vdt_id
        and transaction_type='Prepaid Registration'
        and lower(status_description) = 'success' and lower(transaction_status) = 'completed'
        and (upper(coalesce(cluster,'')) not like '%TEST%' and upper(coalesce(cluster,'')) not like '%SEV%')
				and date(process_id) <= date(vdt_id + interval 1 day)
				--and process_id like 'date_trunc(vdt_id,month)%'
		and coalesce(substring(b_msisdn, 1,5),'') not in ('62895', '62896', '62897', '62898', '62899') 
		union all
		select act_date, msisdn, organizationid, cluster_nm, sales_area, area, region
		from `data-bi-prd-935c.bi_mart`.ga_outlet_mth
		where month_id=date_sub(date_trunc(vdt_id,month),interval 1 month)
		and act_date>=date_sub(date_trunc(vdt_id,month),interval 24 month)
	) x
) y
where rk=1
;

--- ONLINE PURCHASE from existing IFRS PREPAID SALMO 202308
delete `data-bi-prd-935c.bi_mart`.salmo_online_dly where dt_id = vdt_id;
insert into `data-bi-prd-935c.bi_mart`.salmo_online_dly 
select parse_timestamp('%Y-%m-%d %H:%M:%S', `datetime`) completion_date, channel, organization_type, transaction_type
	, organization_id organization_trx, b_msisdn organization_id, cast(amount_debit as numeric) amount_debit
	, timestamp(current_date('+7')) ppn_dttm, transaction_id
	, date(parse_timestamp('%Y-%m-%d %H:%M:%S', `datetime`)) dt_id
from `data-dtp-prd-aa1a.stg.ifrs_prepaid_salmo`
where date(parse_timestamp('%Y-%m-%d %H:%M:%S', `datetime`)) = vdt_id
    and lower(transaction_type) = 'transfer'
    and upper(organization_id) like 'ONLPURC%'
	and lower(status_description) = 'success' and lower(transaction_status) = 'completed'
	and ifnull(channel,'')!=''
	and (upper(coalesce(cluster,'')) not like '%TEST%' and upper(coalesce(cluster,'')) not like '%SEV%')
	and date(process_id) <= date(vdt_id + interval 1 day)
	and coalesce(substring(b_msisdn, 1,5),'') not in ('62895', '62896', '62897', '62898', '62899')
;