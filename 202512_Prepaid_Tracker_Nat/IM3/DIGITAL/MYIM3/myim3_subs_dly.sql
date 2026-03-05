declare vdt_id date default @vdt_id;


--- dau dpu
create or replace table `data-bi-prd-935c.bi_stg`.temp_revamp_myim3_ap_202312 as
with dau as (
    select date_partition dt_id
        , case
            when msisdn like '6208%' then regexp_replace(msisdn, '^6208','628')
            when msisdn like '08%' then regexp_replace(msisdn, '^08','628')
            when msisdn like '8%' then concat('62',msisdn)
            else msisdn
        end msisdn, date(first_login) first_login_all, date(first_login) first_login_imi, 'A' myim3_flag
    from  `data-analytics-prd-1b95.digital_sbx.hen_prd_digital_din_mdi_new`
    where date_partition = vdt_id  and mau_imi = 1 and inactive_days between -14 and 0 

),
dpu as (
    select date(dt_id) dt_id
        , case
            when msisdn like '6208%' then regexp_replace(msisdn, '^6208','628')
            when msisdn like '08%' then regexp_replace(msisdn, '^08','628')
            when msisdn like '8%' then concat('62',msisdn)
            else msisdn
        end msisdn
        , 'P' flag
        ,sum(CASE WHEN transactiontype = 'PGI - ADVPAYMENT' THEN rev ELSE 0 END) PGI_ADVPAYMENT
        ,sum(CASE WHEN transactiontype = 'PGI - BILLPAY' THEN rev ELSE 0 END) PGI_BILLPAY
        ,sum(CASE WHEN transactiontype = 'PGI - CONTRACT_RENEW' THEN rev ELSE 0 END) PGI_CONTRACT_RENEW
        ,sum(CASE WHEN transactiontype = 'PGI - P2PTOPUPMOBO' THEN rev ELSE 0 END) PGI_P2PTOPUPMOBO
        ,sum(CASE WHEN transactiontype = 'PGI - PACKAGE' THEN rev ELSE 0 END) PGI_PACKAGE
        ,sum(CASE WHEN transactiontype = 'DATA' AND channel = 'MYIM3 of CVM' THEN rev  ELSE 0 END) DATA_CVM
        ,sum(CASE WHEN transactiontype = 'DATA' AND channel = 'MYIM3' THEN rev ELSE 0 END) DATA_OTHER
        ,sum(CASE WHEN transactiontype = 'VOICE' THEN rev ELSE 0 END) VOICE
        ,sum(CASE WHEN transactiontype = 'SMS' THEN rev ELSE 0 END) SMS
        ,sum(CASE WHEN transactiontype = 'Postpaid' THEN rev ELSE 0 END) *1.11 POSTPAID
        ,sum(CASE WHEN transactiontype = 'VAS' THEN rev ELSE 0 END) VAS
        ,sum(CASE WHEN transactiontype = 'PGI - RELOAD' THEN rev ELSE 0 END) PGI_RELOAD
        ,sum(CASE WHEN transactiontype = 'PGI - CVM' THEN rev  ELSE 0 END) PGI_CVM
        ,sum(CASE WHEN transactiontype = 'PGI - PACKAGE - CVM' THEN rev ELSE 0 END) PGI_PACKAGE_CVM
        ,sum(CASE WHEN transactiontype = 'P2PPACKAGE' THEN rev ELSE 0 END) P2PPACKAGE
    from `data-analytics-prd-1b95.digital_sbx`.dca_prd_revenue_indosat_v1
    where date(dt_id) = vdt_id
        AND myim3_flag = 1
    group by 1,2
),
fnl as (
    select distinct coalesce(a.dt_id,b.dt_id) dt_id, coalesce(a.msisdn,b.msisdn) msisdn, first_login_all, first_login_imi
        , concat(coalesce(a.myim3_flag,''),coalesce(b.flag,'')) myim3_flag
        , coalesce(PGI_ADVPAYMENT,0) PGI_ADVPAYMENT
        , coalesce(PGI_BILLPAY,0) PGI_BILLPAY
        , coalesce(PGI_CONTRACT_RENEW,0) PGI_CONTRACT_RENEW
        , coalesce(PGI_P2PTOPUPMOBO,0) PGI_P2PTOPUPMOBO
        , coalesce(PGI_PACKAGE,0) PGI_PACKAGE
        , coalesce(DATA_CVM,0) DATA_CVM
        , coalesce(DATA_OTHER,0) DATA_OTHER
        , coalesce(VOICE,0) VOICE
        , coalesce(SMS,0) SMS
        , coalesce(POSTPAID,0) POSTPAID
        , coalesce(VAS,0) VAS
        , coalesce(PGI_RELOAD,0) PGI_RELOAD
        , coalesce(PGI_CVM,0) PGI_CVM
        , coalesce(PGI_PACKAGE_CVM,0) PGI_PACKAGE_CVM
        , coalesce(P2PPACKAGE,0) P2PPACKAGE
    from dau a
    full join dpu b
        on a.dt_id=b.dt_id and a.msisdn=b.msisdn
)
select * from fnl
where length(msisdn) between 10 and 15
;

-- flag subs
create or replace table `data-bi-prd-935c.bi_stg`.temp_revamp_myim3_flag_subs_202312 as
with
postpaid_b2b as (
	select date(dt_id) dt_id, msisdn, actvn_dt, imei, cast(NULL as string) svc_class_code, '1. Postpaid B2B' subs_flag
	from (
		select dt_id, regexp_replace(svc_id,'[^[:digit:]]','') msisdn, actvn_dt, imei
			, row_number() over(partition by dt_id, regexp_replace(svc_id,'[^[:digit:]]','') order by actvn_dt) rk
		from `data-dtp-prd-aa1a.smy`.ar_cst_pstpaid_b2b
		where date(dt_id) = vdt_id
			and substr(svc_id,1,5) in ('62814', '62815', '62816', '62855', '62856', '62857', '62858')
			and ac_st not in ('Terminate','NULL','')
			and ac_st is not NULL
			and actvn_dt is not null
	) x
	where rk=1
),
postpaid_b2c as (
	select date(dt_id) dt_id, msisdn, actvn_dt, imei, svc_class_code, '2. Postpaid B2C' subs_flag
	from (
		select dt_id, msisdn, actvn_dt, imei, sc_id svc_class_code, row_number() over(partition by dt_id, msisdn order by actvn_dt) rk
		from `data-dtp-prd-aa1a.smy`.ar_cst_pstpaid_rtl
		where date(dt_id) = vdt_id
			and termination_dt is null
			and ac_st not in ('Inactive','Pending','NULL','')
			and ac_st is not null
			and actvn_dt is not null
	)x
	where rk=1
),
prepaid as (
	select date(dt_id) dt_id, msisdn, actvn_dt, imei, a.svc_class_code
		, case when a.svc_class_code=b.svc_class_code then '3. Prepaid B2B' else '4. Prepaid B2C' end subs_flag
	from `data-dtp-prd-aa1a.smy`.ar_cst_dly_smy a
	left join (
		select distinct svc_class_code from `data-bi-prd-935c.bi_mart`.ref_sc
		where flag='B2B'
	) b
		on a.svc_class_code=b.svc_class_code
	where date(dt_id) = vdt_id
),
propaid as (
	select date(dt_id) dt_id, msisdn, actvn_dt, imei, svc_class_code, '5. Propaid' subs_flag
	from  `data-dtp-prd-aa1a.smy`.ar_cst_propaid_smy
	where date(dt_id) = vdt_id
)
select dt_id, a.msisdn, date(actvn_dt) actvn_dt, imei, svc_class_code, regexp_replace(subs_flag, substr(subs_flag,1,3), '') subs_flag
from (
	select *, row_number() over(partition by dt_id, msisdn order by subs_flag) rk
	from (
		select * from postpaid_b2b
		union all
		select * from postpaid_b2c
		union all
		select * from prepaid
		union all
		select * from propaid
	) x
) a
inner join (
	select distinct msisdn
	from  `data-bi-prd-935c.bi_stg`.temp_revamp_myim3_ap_202312 -- `data-bi-prd-935c.bi_stg`.temp_revamp_myim3_ap
	where dt_id = vdt_id
) b
	on a.msisdn=b.msisdn
where rk=1
;

--- insert to master table
delete from `data-bi-prd-935c.bi_mart`.myim3_subs_dly where dt_id = vdt_id;
insert into `data-bi-prd-935c.bi_mart`.myim3_subs_dly
select a.msisdn, b.subs_flag subscriber_type, actvn_dt, b.imei, b.svc_class_code
    , a.myim3_flag, a.first_login_all, a.first_login_imi, NULL flag_trx
    , pgi_advpayment+pgi_billpay+pgi_contract_renew+pgi_p2ptopupmobo+pgi_package+data_cvm+data_other+voice+sms+postpaid+vas+pgi_reload+pgi_cvm+pgi_package_cvm+p2ppackage as total_trx
    , pgi_advpayment as advpayment_rev
    , pgi_billpay as billpay_rev
    , pgi_contract_renew as contract_renew_rev
    , pgi_p2ptopupmobo as p2ptopupmobo_rev
    , 0 package_rev
    , pgi_package as pgi_package_rev
    , data_cvm as data_cvm_rev
    , 0 voice_cvm_rev
    , data_other as data_noncvm_rev
    , voice as voice_noncvm_rev
    , sms as sms_noncvm_rev
    , postpaid as airtime_postpaid_rev
    , vas as vas_rev
    , pgi_reload as reload_amt
    , 0 hits_trx
    , vol_da_byte as traffic_data_da_byte
    , vol_all_byte as traffic_data_all_byte
    , rgu_rev as rgu_rev
    , f.first_rgu
    , date_diff(a.dt_id, coalesce(f.first_rgu, b.actvn_dt),day) tnr
    , 0 activity_purchase_package
    , 0 activity_visit_package_page
    , 0 activity_visit_loyalty
    , 0 activity_visit_other_features
    , 0 activity_visit_promo_games
    , 0 activity_visit_account_page
    , 0 activity_visit_home_page
    , timestamp(current_datetime('+7')) ppn_dttm
    , g.site_id
    , pgi_cvm as pgi_cvm_rev
    , pgi_package_cvm as pgi_package_cvm_rev
    , p2ppackage as p2ppackage_rev
    , pgi_contract_renew+pgi_package+data_cvm+data_other+voice+sms+postpaid+vas+pgi_cvm+pgi_package_cvm+p2ppackage as total_rev
    , a.dt_id
from `data-bi-prd-935c.bi_stg`.temp_revamp_myim3_ap_202312 a
left join `data-bi-prd-935c.bi_stg`.temp_revamp_myim3_flag_subs_202312 b
    on a.dt_id=b.dt_id and a.msisdn=b.msisdn
left join (
    select date(dt_id) dt_id, msisdn, sum(vol) vol_da_byte
    from `data-analytics-prd-1b95.digital_sbx`.din_myim3_free_traffic
    where date(dt_id) = vdt_id and vol>0
    group by 1,2
) c
    on a.dt_id=c.dt_id and a.msisdn=c.msisdn
left join (
    select date(dt_id) dt_id, subscriber msisdn, sum(uplink+downlink) vol_all_byte
    from `data-bi-prd-935c.bi_dm`.traffic_ggsn
    where date(dt_id) = vdt_id
        and uplink+downlink>0
    group by 1,2
) d
    on a.dt_id=d.dt_id and a.msisdn=d.msisdn
left join (
    select dt_id, msisdn, ifnull(total_rev,0) rgu_rev
    from `data-bi-prd-935c.bi_mart`.rgs_nogovt_dly
    where dt_id = vdt_id and ifnull(total_rev,0)>0
) e
    on a.dt_id=e.dt_id and a.msisdn=e.msisdn
left join (
    select msisdn, first_rgu
    from `data-bi-prd-935c.bi_mart`.first_rgs_govt
    where mth_id = date_trunc(vdt_id,month)
) f
    on a.msisdn=f.msisdn
left join (
    select date(dt_id) dt_id, msisdn, site_id
    from `data-dtp-prd-aa1a.sor.subs_fav_loc_dly_carry_fwd`
    where date(dt_id) = vdt_id
) g
    on a.msisdn=g.msisdn and a.dt_id=g.dt_id
;
