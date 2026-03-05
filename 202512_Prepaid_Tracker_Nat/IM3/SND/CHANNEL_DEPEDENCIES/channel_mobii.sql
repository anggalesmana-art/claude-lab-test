declare vdt_id date default @vdt_id;
declare vdt_mth date default date_trunc(vdt_id,month);
--- sellin sp (added channel at 20230112)
delete from `data-bi-prd-935c.bi_mart`.mobii_msisdn_mth where month_id = vdt_mth;
insert into `data-bi-prd-935c.bi_mart`.mobii_msisdn_mth 
select destination, msisdn, price, timestamp(current_datetime('+7')) ppn_dttm, dt_id, product_code, product_name, saldomobo_id, expired_date, channel,
operator_id, operator_name, product_category,vdt_mth month_id
from
(
	select destination, msisdn, price, dt_id, product_code, product_name, saldomobo_id, expired_date, channel,operator_id, operator_name, product_category, ROW_NUMBER() over(partition by msisdn order by dt_id desc) as rk from
(
		select destination, msisdn, price, dt_id, product_code, product_name, saldomobo_id, expired_date, channel, operator_id
		, operator_name, product_category
		from (
		    select case when lower(node_name) like 'sales promotor%' then operator_id else dest_saldomobo_id end destination, msisdn, cast(price as numeric) price
		    , cast(PARSE_DATETIME('%d-%b-%Y %H:%M:%S', case when transaction_datetime='' or transaction_datetime='---EOF---' then null else REPLACE(transaction_datetime,'---EOF---','') end) as date)  dt_id
            , product_code, product_name, saldomobo_id
            , PARSE_DATE('%d-%b-%Y', case when expired_date='' then null else expired_date end) expired_date
            , case when lower(node_name) like 'sales promotor%' or organization_type ='Sub outlet' then 'Promotor' else 'Traditional' end channel
            , operator_id
            , operator_name
            , product_category
            , ROW_NUMBER() over(partition by msisdn order by cast(PARSE_DATETIME('%d-%b-%Y %H:%M:%S', case when transaction_datetime='' or transaction_datetime='---EOF---' then null else REPLACE(transaction_datetime,'---EOF---','') end) as date) desc) as rk
		    from `data-dtp-prd-aa1a.stg`.mobii_physical_distribution a
		    --left anti join (select saldo_mobo_shortcode from `data-dtp-prd-aa1a.stg`.stg_snapshot_organization_detail --update 202308 exclude sellin to SPV/Promotor/DSF
            left join (
                select distinct saldo_mobo_shortcode,organization_type
                from `data-dtp-prd-aa1a.stg`.stg_snapshot_organization_detail
                where date(dt_id) between date(vdt_id - interval 5 day)
                and date(vdt_id + interval 1 day)
                and organization_type ='Sub outlet'
                --and regexp_like(saldo_mobo_shortcode,"^[0-9]+$")=False --202308 exclude sellin non outlet
                --group by 1
                ) b
                on a.dest_saldomobo_id=b.saldo_mobo_shortcode
		    where upper(distribution_type) = 'SELL IN'
			and upper(dest_saldomobo_id) not like 'D%'
      and upper(dest_saldomobo_id) not like 'SDP%'
			and upper(product_category) = 'STARTER PACK'
			--and cast(PARSE_DATETIME('%d-%b-%Y %H:%M:%S', case when transaction_datetime='' or transaction_datetime='---EOF---' then null else REPLACE(transaction_datetime,'---EOF---','') end) as date)  between vdt_mth and vdt_id
      and cast(PARSE_DATETIME('%d-%b-%Y %H:%M:%S', case when transaction_datetime='' or transaction_datetime='---EOF---' then null else REPLACE(transaction_datetime,'---EOF---','') end) as date) between vdt_mth and vdt_id
			and date(a.dt_id) <= vdt_id + interval 5 day
			) a
		where rk=1
		union all
		select destination, msisdn, price, dt_id, product_code, product_name, saldomobo_id, expired_date, channel,operator_id, operator_name, product_category
		from `data-bi-prd-935c.bi_mart`.mobii_msisdn_mth
		where month_id=vdt_mth - interval 1 month
			and dt_id>=vdt_mth - interval 24 month
      and regexp_contains(destination,"^[0-9]+$")!=False --202308 exclude sellin non outlet
	) x
) y
where rk=1
;

--- sellin voucher ori
delete from `data-bi-prd-935c.bi_mart`.mobii_msisdn_vo_mth where month_id = vdt_mth;
insert into `data-bi-prd-935c.bi_mart`.mobii_msisdn_vo_mth 
select destination, serial_number, price, timestamp(current_datetime('+7')) ppn_dttm, dt_id, product_code, product_name, saldomobo_id
    , expired_date, operator_id, operator_name, product_category
    , vdt_mth month_id
from (
    select destination, serial_number, price, dt_id, product_code, product_name, saldomobo_id, expired_date
	    , operator_id
        , operator_name
        , product_category
        , ROW_NUMBER() over(partition by serial_number order by dt_id desc) as rk
    from
    (
    select destination, serial_number, price, dt_id, product_code, product_name, saldomobo_id, expired_date
	    , operator_id
        , operator_name
        , product_category
    from (
    select dest_saldomobo_id destination, serial_number, cast(price as numeric) price
		, cast(PARSE_DATETIME('%d-%b-%Y %H:%M:%S', case when transaction_datetime='' or transaction_datetime='---EOF---' then null else REPLACE(transaction_datetime,'---EOF---','') end) as date) dt_id
        , product_code, product_name, saldomobo_id
        , PARSE_DATE('%d-%b-%Y', case when expired_date='' then null else expired_date end) expired_date
        , operator_id
        , operator_name
        , product_category
        , ROW_NUMBER() over(partition by serial_number order by cast(PARSE_DATETIME('%d-%b-%Y %H:%M:%S', case when transaction_datetime='' or transaction_datetime='---EOF---' then null else REPLACE(transaction_datetime,'---EOF---','') end) as date) desc) as rk
    from `data-dtp-prd-aa1a.stg`.mobii_physical_distribution a
	where upper(distribution_type) = 'SELL IN'
        and upper(dest_saldomobo_id) not like 'D%'
        and upper(dest_saldomobo_id) not like 'SDP%'
        and upper(product_category) = 'VOUCHER'
        and regexp_contains(dest_saldomobo_id,"^[0-9]+$")!=False --202308 exclude sellin non outlet
        --and (product_name like 'VCR DATA%' or product_name like 'VOU%ORI%' or product_name like 'VORI%')
		--and parse_date('%d-%b-%Y',left(replace(transaction_datetime,'',null),11)) between vdt_mth and vdt_id
    and cast(PARSE_DATETIME('%d-%b-%Y %H:%M:%S', case when transaction_datetime='' or transaction_datetime='---EOF---' then null else REPLACE(transaction_datetime,'---EOF---','') end) as date) between vdt_mth and vdt_id
    and date(dt_id) <= vdt_id + interval 5 day
	) a
	where rk=1
	union all
	select destination, serial_number, price, dt_id, product_code, product_name, saldomobo_id, expired_date
	    , operator_id
        , operator_name
        , product_category
	from `data-bi-prd-935c.bi_mart`.mobii_msisdn_vo_mth
	where month_id=vdt_mth - interval 1 month
		and dt_id>=vdt_mth - interval 24 month
		and regexp_contains(destination,"^[0-9]+$")!=False --202308 exclude sellin non outlet
	) x
) y
where rk =1
;


--- sellout sp
delete from `data-bi-prd-935c.bi_mart`.mobii_msisdn_sellout_mth where month_id = vdt_mth;
insert into `data-bi-prd-935c.bi_mart`.mobii_msisdn_sellout_mth 
select destination, msisdn, price, timestamp(current_datetime('+7')) ppn_dttm, dt_id, vdt_mth month_id
from
(
  select destination, msisdn, price, dt_id, ROW_NUMBER() over(partition by msisdn order by dt_id desc nulls last) as rk
  from
  (
    select operator_id destination, msisdn, price,
    cast(PARSE_DATETIME('%d-%b-%Y %H:%M:%S', case when transaction_datetime='' or transaction_datetime='---EOF---' then null else REPLACE(transaction_datetime,'---EOF---','') end) as date)  dt_id
    from `data-dtp-prd-aa1a.stg`.mobii_physical_distribution a
    where distribution_type = 'Sell Out'
      and dest_saldomobo_id not like 'D%'
      and product_category = 'Starter Pack'
      --and cast(PARSE_DATETIME('%d-%b-%Y %H:%M:%S', case when transaction_datetime='' or transaction_datetime='---EOF---' then null else REPLACE(transaction_datetime,'---EOF---','') end) as date)  between vdt_mth and vdt_id
      and cast(PARSE_DATETIME('%d-%b-%Y %H:%M:%S', case when transaction_datetime='' or transaction_datetime='---EOF---' then null else REPLACE(transaction_datetime,'---EOF---','') end) as date) between vdt_mth and vdt_id
      and date(dt_id) <= vdt_id + interval 5 day
      union all
      select destination, msisdn, price, dt_id
      from `data-bi-prd-935c.bi_mart`.mobii_msisdn_sellout_mth
      where month_id=vdt_mth - interval 1 month
			and dt_id>=vdt_mth - interval 6 month
  ) x
) x
where rk=1
;