declare vdt_id date default @vdt_id;
--FDV RELOAD INJECT
delete from `data-bi-prd-935c.bi_mart`.sellout_fdv_pulsa where dt_id = vdt_id;
insert into `data-bi-prd-935c.bi_mart`.sellout_fdv_pulsa
select timestamp(`datetime`) completion_date, channel, organization_type, transaction_type
	, region, area, sales_area, cluster, additional_territory
	, organization_id, msisdn, b_msisdn, product_name, voucher_type, bill_number voucher_sn
	, cast(main_price as numeric) main_price, cast(amount_debit as numeric) amount_debit
	, timestamp(current_datetime('+7')) ppn_dttm, transaction_id, date(`datetime`) dt_id
from `data-dtp-prd-aa1a.stg`.ifrs_prepaid_salmo y
where  date(`datetime`) = vdt_id and process_id = timestamp(vdt_id + interval 1 day) 
    and lower(transaction_type) in ('vouchercardinjection','bulk voucher card injection')
	and lower(status_description) = 'success' and lower(transaction_status) = 'completed'
	and ifnull(channel,'')!=''
	and (upper(cluster) not like '%TEST%' and upper(cluster) not like '%SEV%')
	and upper(product_name) like '%PULSA%'
  and coalesce(substring(b_msisdn, 1,5),'') not in ('62895', '62896', '62897', '62898', '62899')
;


--- PRIMARY
delete from `data-bi-prd-935c.bi_mart`.fact_snd_primary where primary_type in ('PRIMARY','SALES MARGIN','ADJUSTMENT OUTLET','ADJUSTMENT MPC','CASHBACK','KOIN REDEEM','CASHBACK NEW') and dt_id = vdt_id;
insert into  `data-bi-prd-935c.bi_mart`.fact_snd_primary
select date(completion_date) completion_date,organization_id,organization_type,
cast(round(cast(amount as numeric),0) as int64) amount,
'PRIMARY' primary_type,date(dt_id) dt_id
from `data-dtp-prd-aa1a.stg`.sellin_sellout_stock_entry_success
where (so_number like 'ESCM11%' or so_number like '11%')
and lower(channel) like '%traditional%' and transaction_status='Completed'
and date(dt_id)=vdt_id
union all
select date(`datetime`) completion_date,organization_id,organization_type,
cast(round(safe_cast(incentive_balance_amount as numeric),0) as int64) amount,
'SALES MARGIN' primary_type,date(dt_id) dt_id
from `data-dtp-prd-aa1a.stg`.salmo_commission_incentive
where organization_type in ('Dealer','SDP') and date(dt_id)=vdt_id
union all
select date(approved_dt_time) completion_date,cast(credit_party_id as string) organization_id,'Outlet' organization_type,
cast(after_tax as int64) amount,
'ADJUSTMENT OUTLET' primary_type,date(dt_id) dt_id
from `data-dtp-prd-aa1a.stg`.daily_dump_bulk_adj
where date(dt_id)=vdt_id
                and (upper(credit_party_id) not like 'D%' and upper(credit_party_id) not like '%SF%' and upper(credit_party_id) not like '%H2H%')
                and debit_party_id='1'
                and transaction_status = 'Completed'
                and transaction_status_desc = 'Success'
union all
select date(approved_dt_time) completion_date,cast(credit_party_id as string) organization_id,'Dealer' organization_type,
cast(after_tax as int64) amount,
'ADJUSTMENT MPC' primary_type,date(dt_id) dt_id
from `data-dtp-prd-aa1a.stg`.daily_dump_bulk_adj
where date(dt_id) = vdt_id
                and (upper(credit_party_id) like 'D%' and upper(credit_party_id) not like '%SF%' and upper(credit_party_id) not like '%H2H%')
                and debit_party_id='1'
                and transaction_status = 'Completed'
                and transaction_status_desc = 'Success'
union all
select date(transaction_date) completion_date,cast(short_code as string) organization_id,'Outlet' organization_type,
cast(cashback_value as int64) amount,'CASHBACK' primary_type,date(dt_id) dt_id
from `data-dtp-prd-aa1a.stg`.cashback
where date(dt_id)=vdt_id
union all
select date(datatime) completion_date,organization_id,organization_type,
cast(koin_amount as int64) amount,'KOIN REDEEM' primary_type,date(dt_id) dt_id
from `data-dtp-prd-aa1a.stg`.daily_dump_redeem_koin_details
where date(dt_id)=vdt_id and redeem_type='Redeem Balance'
union all
select parse_date('%Y%m%d',substr(transactiontime,0,8)) completion_date,
cast(shortcode as string) organization_id,'Outlet' organization_type,
cast(round(cast(regexp_replace(amount, '[^0-9]', '') as numeric) / 100,0) as int64)  amount,
'CASHBACK NEW' primary_type,date(dt_id) dt_id
from `data-dtp-prd-aa1a.stg`.salmo_offline_usage_incentive
where date(dt_id)=vdt_id and state='Completed'
and regexp_replace(amount, '[^0-9]', '') != '';

--PRIMARY ONLINE PURCHASE
delete from `data-bi-prd-935c.bi_mart`.fact_snd_primary where primary_type = 'ONLINE PURCHASE' and dt_id = vdt_id;
insert into `data-bi-prd-935c.bi_mart`.fact_snd_primary
select date(completion_date) completion_date,organization_id,'Outlet' organization_type,
sum(cast(amount_debit as int64)) amount,'ONLINE PURCHASE' primary_type,dt_id
from `data-bi-prd-935c.bi_mart`.salmo_online_dly
where dt_id=vdt_id
group by 1,2,3,5,6
;

--PRIMARY SP DATA FOSS SELLIN update 202308
-- update May25
delete from `data-bi-prd-935c.bi_mart`.fact_snd_primary where primary_type = 'SP DATA' and dt_id = vdt_id;
insert into `data-bi-prd-935c.bi_mart`.fact_snd_primary
select dt_sellin completion_date,organization_id,'Dealer' organization_type,
sum(cast(amount as bigint)) amount,'SP DATA' primary_type,dt_sellin dt_id
from (  
        select * from `data-bi-prd-935c.bi_mart`.foss_sp_data_sellin_mth
        where mth_id=date_trunc(vdt_id,month) and dt_foss between date_trunc(vdt_id,month) and vdt_id 
      and upper(product_name) not like '%ZERO%'
      ) a
where dt_sellin = vdt_id and organization_id<>''
group by 1,2,3,5,6;

--PRIMARY SP DATA FOSS NO SELLIN using DEALER added 202308
-- update May25
delete from `data-bi-prd-935c.bi_mart`.fact_snd_primary where primary_type = 'SP DATA ALLOC' and dt_id = vdt_id;
insert into `data-bi-prd-935c.bi_mart`.fact_snd_primary 
select dt_foss completion_date,saldomobo_id organization_id,'Dealer' organization_type,
sum(cast(amount as bigint)) amount,'SP DATA ALLOC' primary_type, dt_foss dt_id
from 
  (
    select * from `data-bi-prd-935c.bi_mart`.foss_sp_data_sellin_mth
    where mth_id=date_trunc(vdt_id,month)
    and upper(product_name) not like '%ZERO%'
  ) a
where dt_foss = vdt_id
and (dt_sellin is null or  date_trunc(dt_sellin,month) < date_trunc(vdt_id,month) )
group by 1,2,3,5,6;

--PRIMARY VOUCHER ORI FOSS
-- update May25
delete from `data-bi-prd-935c.bi_mart`.fact_snd_primary where primary_type = 'VOU ORI' and dt_id = vdt_id;
insert into `data-bi-prd-935c.bi_mart`.fact_snd_primary
select dt_sellin completion_date,organization_id,'Dealer' organization_type,
sum(cast(amount as bigint)) amount,'VOU ORI' primary_type,dt_sellin dt_id
from `data-bi-prd-935c.bi_mart`.foss_vo_ori_sellin_mth
where mth_id=date_trunc(vdt_id,month) and date_trunc(dt_foss,month) = date_trunc(vdt_id,month) and dt_sellin=vdt_id
and organization_id<>''
group by 1,2,3,5,6;

--PRIMARY VOUCHER ORI FOSS NO SELLIN using DEALER added 202308
-- update may25
delete from `data-bi-prd-935c.bi_mart`.fact_snd_primary where primary_type = 'VOU ORI ALLOC' and dt_id = vdt_id;
insert into `data-bi-prd-935c.bi_mart`.fact_snd_primary
select dt_foss completion_date, saldomobo_id organization_id,'Outlet' organization_type,
sum(cast(amount as bigint)) amount,'VOU ORI ALLOC' primary_type, dt_foss dt_id
from `data-bi-prd-935c.bi_mart`.foss_vo_ori_sellin_mth
    where mth_id=date_trunc(vdt_id,month) 
    and dt_foss = vdt_id
    and (dt_sellin is null or date_trunc(dt_sellin,month) < date_trunc(vdt_id,month))
group by 1,2,3,5,6
;

--PRIMARY SP Zero start 220308
-- update May25
delete from `data-bi-prd-935c.bi_mart`.fact_snd_primary where primary_type = 'SP ZERO' and dt_id = vdt_id;
insert into `data-bi-prd-935c.bi_mart`.fact_snd_primary
select coalesce(dt_foss,dt_sellin) completion_date, saldomobo_id organization_id,'Outlet' organization_type,
        sum(cast(amount as bigint)) amount,'SP ZERO' primary_type, coalesce(dt_foss,dt_sellin) dt_id
        from
        (
        select * from `data-bi-prd-935c.bi_mart`.foss_sp_data_sellin_mth
        where mth_id=date_trunc(vdt_id,month) 
             and dt_foss = vdt_id
             and upper(product_name) like '%ZERO%'
        )a 
        group by 1,2,3,5,6
;