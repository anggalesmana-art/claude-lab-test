  DECLARE vdt_id DATE DEFAULT @vdt_id;

  -- Temp 1 - Populate DAU


drop table if exists `data-bi-prd-935c.bi_stg.hg_tmp_bima_dly_dau`;

create table `data-bi-prd-935c.bi_stg.hg_tmp_bima_dly_dau` 
 as
(
  select msisdn, 'A' bima_flag
  from (
    select cast(load_dt_sk_id as date) dt_id
      , REGEXP_EXTRACT(
  REGEXP_REPLACE(
    REGEXP_REPLACE(subscriber_msisdn, r'^0|^o|[^0-9]+', ''), 
    r'^8', '628'
  ), 
  r'([0-9]{1,14})'
) as msisdn
    from `data-dtptechm-prd-c7ca.dwh.bima_log_fct`
    where cast(load_dt_sk_id as date) = vdt_id
      and coalesce(trim(subscriber_msisdn),'N/A') <> 'N/A'
      and trim(subscriber_msisdn) <> ''
      --and upper(controller_class) <> 'LOGIN'
      and upper(trim(controller_api)) not in ('/API/V1/LOGIN/OTP-REQUEST','/API/V2/LOGIN/OTP-REQUEST', '/API/V1/LOGIN/GENERATE-NONHE-SSO') --('/API/V1/LOGIN/OTP-REQUEST','/API/V2/LOGIN/OTP-REQUEST')
    union all
    select 
    dt_id,
    msisdn
    from `data-analytics-prd-1b95.digital_sbx.hen_prd_bima_revamp_dau_to_dwh`
    where dt_id = vdt_id
    
  ) x
  where length(msisdn)>10 group by 1
);


drop table if exists `data-bi-prd-935c.bi_stg.hg_tmp_bima_dly_dpu`;

create table `data-bi-prd-935c.bi_stg.hg_tmp_bima_dly_dpu` 
as
(
  select coalesce(a.msisdn,b.msisdn,c.msisdn,d.msisdn,e.msisdn) msisdn, 'P' bima_flag
    , sum( coalesce(inapp_atl_rev,0)+coalesce(inapp_cvm_rev,0) ) inapp_rev
    , sum( coalesce(online_atl_rev,0) +coalesce(online_cvm_rev,0) ) online_rev
    , sum( coalesce(e.amount,0) ) reload
    , sum( coalesce(p2p_topup,0) +coalesce(c.transfer_balance,0) ) p2p_topup
    , sum( coalesce(vas_rev,0) +coalesce(d.vas,0) ) vas_rev
    , sum( coalesce(bill_pay,0) +coalesce(d.billpay,0) ) bill_pay
    , sum( coalesce(inapp_cvm_rev,0) +coalesce(online_cvm_rev,0) ) cvm_rev
    , sum( coalesce(inapp_atl_rev,0) ) inapp_atl_rev
    , sum( coalesce(inapp_cvm_rev,0) ) inapp_cvm_rev
    , sum( coalesce(online_atl_rev,0) ) online_atl_rev
    , sum( coalesce(online_cvm_rev,0) ) online_cvm_rev
    , sum(coalesce(c.voucher_reload,0) ) voucher_reload
    , sum(coalesce(c.gift_cvm,0) ) gift_cvm
    , sum(coalesce(c.gift_atl,0) ) gift_atl
    , sum(coalesce(c.gift_reload,0) ) gift_reload
    , sum(coalesce(d.gift_cvm_lego,0)) gift_cvm_lego
    , sum( coalesce(a.hits,0) + coalesce(b.hits,0) + coalesce(c.hits,0) + coalesce(d.hits,0) + coalesce(e.hits,0) ) hits_trx
  from (
    -- InApp & Online
    select sbscrptn_msisdn msisdn
      , sum(case when (source_channel in ('ODP_GNV','ODP_GNV_SUPERAPP') and revenue_source_indicator = 'CDR') or source_channel = 'TRANSFER-ODP_GNV' then net_revenue else 0 end) inapp_atl_rev
      , sum(case when source_channel IN ('CVM_BIMA_NONPGI','CVM_BIMA_LEGO_NONPGI','CVM_BIMA_LEGO_TP_NONPGI','CVM_BIMA_LEGO_NONPGI_SUPERAPP','CVM_BIMA_NONPGI_SUPERAPP') then net_revenue else 0 end) inapp_cvm_rev
      , sum(case when (source_channel in ('ODP_GNV','ODP_GNV_SUPERAPP') and revenue_source_indicator = 'MANUAL') then net_revenue else 0 end) online_atl_rev
      , sum(case when source_channel IN ('CVM_BIMA_PGI','CVM_BIMA_LEGO_PGI','CVM_BIMA_LEGO_PGI_SUPERAPP','CVM_BIMA_PGI_SUPERAPP') then net_revenue else 0 end) online_cvm_rev
      , count(1) hits
    from `data-dtptechm-prd-c7ca.dwh.revenue_base` fct
    left join `data-dtptechm-prd-c7ca.dwh.product_dim` pd
      ON pd.product_sk_id=fct.product_sk_id
    JOIN `data-dtptechm-prd-c7ca.dwh.demand_revenue_base_filter` AS drbf
    
							ON fct.process_nm = drbf.process_nm
							AND fct.revenue_src_ctgry = drbf.revenue_src_ctgry
						WHERE drbf.net_revenue_incl = 'Y' and  cast(trx_dt_sk_id as date) = vdt_id
      and coalesce(fct.gl_cd,'') not in (select ref_cd from `data-dtptechm-prd-c7ca.dwh.rprt_fltr_ref_ctgry` where ref_type_cd = 'ACCRUAL_GL_CODE')
      and tool_of_trade_ind = 'N'
      and source_channel in ('CVM_BIMA_NONPGI', 'CVM_BIMA_PGI', 'ODP_GNV', 'TRANSFER-ODP_GNV', 'CVM_BIMA_LEGO_NONPGI', 'CVM_BIMA_LEGO_PGI','CVM_BIMA_LEGO_TP_NONPGI','ODP_GNV_SUPERAPP','CVM_BIMA_PGI_SUPERAPP','CVM_BIMA_LEGO_PGI_SUPERAPP','CVM_BIMA_LEGO_NONPGI_SUPERAPP','CVM_BIMA_NONPGI_SUPERAPP')
      and fct.process_nm not in ('EVC MARKUP','MARKUP_RITA','MARKUP_UNLOCK')
      and net_revenue>0
    group by 1
  ) a
  full join (
    -- Reload & VAS
    select msisdn
     -- , sum(reload) reload
      , sum(p2p_topup) p2p_topup
      , sum(vas_rev) vas_rev
      , sum(bill_pay) bill_pay
      , count(1) hits
    from (
      select subs_msisdn msisdn
        , case when product_type_1 = 'Pulsa' and charging_mechanism = 'api_3pul' and pm.payment_method_cd is not null and payment_method_nm != 'Main Balance' then amount else 0 end reload
        , case when product_type_1 = 'Pulsa' and charging_mechanism is null and pm.payment_method_cd is null then amount else 0 end p2p_topup
        , case when product_type_1 = 'Non Pulsa' and charging_mechanism in ('api_nsn', 'free_url', '0', 'smsmt', 'featurepage') then amount else 0 end vas_rev
        , case when product_type_1 not in ('Non Pulsa','Pulsa') then amount else 0 end bill_pay
      from `data-dtptechm-prd-c7ca.dwh.odp_trx_merge_dly_fct` fct
      left join `data-dtptechm-prd-c7ca.dwh.odp_payment_method_dim` pm on fct.payment_method_cd = pm.payment_method_cd
      where cast(trx_dt_sk_id as date) = vdt_id
        and trim(upper(trx_status)) = 'SUCCESS'
        and trim(upper(trx_type_1)) <> 'UNSUBSCRIBE'
        and amount > 0
    ) x
    -- where (reload+p2p_topup+vas_rev+bill_pay)>0
    where (p2p_topup+vas_rev+bill_pay)>0
    group by 1
  ) b
    on a.msisdn=b.msisdn
  full join
  (
  	select msisdn,
	sum(case when operationtype ='GIFT' and transactiontype='CVM' then cast(callback_amount as bignumeric) else 0 end) gift_cvm,
	sum(case when operationtype ='GIFT' and transactiontype='PACKAGE' then cast(callback_amount as bignumeric) else 0 end) gift_atl,
	sum(case when operationtype ='GIFT' and transactiontype='RELOAD' then cast(callback_amount as bignumeric) else 0 end) gift_reload,
	sum(case when operationtype ='TRANSFER' and transactiontype='BALANCE' then cast(callback_amount as bignumeric) else 0 end) transfer_balance, --kalau kolom lama namanya p2p topup
	sum(case when operationtype ='VOUCHER' and transactiontype='RELOAD' then cast(callback_amount as bignumeric) else 0 end) voucher_reload,
	count(1) hits
	from `data-bi-prd-935c.bi_mart.hen_prd_bima_revamp_payments_vas` where cast(dt_id as date)= vdt_id
	and status ='2' and cast(callback_amount as bignumeric)  >0 
	group by 1 

  )c
  	on a.msisdn=c.msisdn
  full join 
  (
  	select msisdn,
  	sum(case when transactiontype='CONTENT' then cast(amount as bignumeric) else 0 end) vas,
	sum(case when operationtype ='GIFT' and transactiontype='RECOM' then cast(amount as bignumeric) else 0 end) gift_cvm_lego,
	sum(case when operationtype ='BUY' and transactiontype='BILLPAY' then cast(amount as bignumeric) else 0 end) billpay,
	count(1) hits
	from `data-bi-prd-935c.bi_mart.hen_prd_bima_revamp_payments_vas` where cast(dt_id as date) = vdt_id
	and status ='2' and cast(amount as bignumeric) >0 
	group by 1 

  )d
  	on a.msisdn=d.msisdn
  full join 
  (
  select sbscrptn_msisdn msisdn , sum(unearned) amount,sum(case when unearned>0 then 1 else 0 end) hits
	from `data-dtptechm-prd-c7ca.dwh.revenue_base` where cast(trx_dt_sk_id as date)=vdt_id and unearned >0 and revenue_source_indicator ='ODP' and source_system_nm='ETOPUP-ODP'
	group by 1 
  )e 
  	on a.msisdn=e.msisdn
  group by 1
);



  --- Temp 3 - Combine DAU & DPU

drop table if exists `data-bi-prd-935c.bi_stg.hg_tmp_bima_dly`;


create table `data-bi-prd-935c.bi_stg.hg_tmp_bima_dly` 
as
(
  select distinct coalesce(a.msisdn,b.msisdn) msisdn
    , coalesce(a.bima_flag,'') || coalesce(b.bima_flag,'') bima_flag
    , ( coalesce(inapp_rev,0) + coalesce(online_rev,0) + coalesce(reload,0) + coalesce(p2p_topup,0) + coalesce(vas_rev,0) + coalesce(bill_pay,0) ) total_trx
    , coalesce(inapp_rev,0) inapp_rev
    , coalesce(online_rev,0) online_rev
    , coalesce(reload,0) reload
    , coalesce(p2p_topup,0) p2p_topup
    , coalesce(vas_rev,0) vas_rev
    , coalesce(bill_pay,0) bill_pay
    , coalesce(cvm_rev,0) cvm_rev
    , coalesce(hits_trx,0) hits_trx
    , coalesce(inapp_atl_rev,0) inapp_atl_rev
    , coalesce(inapp_cvm_rev,0) inapp_cvm_rev
    , coalesce(online_atl_rev,0) online_atl_rev
    , coalesce(online_cvm_rev,0) online_cvm_rev
    , coalesce(voucher_reload,0) voucher_reload
    , coalesce(gift_cvm,0) gift_cvm
    , coalesce(gift_atl,0) gift_atl
    , coalesce(gift_reload,0) gift_reload
    , coalesce(gift_cvm_lego,0) gift_cvm_lego
  from `data-bi-prd-935c.bi_stg.hg_tmp_bima_dly_dau` a
  full join `data-bi-prd-935c.bi_stg.hg_tmp_bima_dly_dpu` b
    on a.msisdn=b.msisdn
);


  --- insert to master table

delete from `data-bi-prd-935c.bi_mart.bima_dly` where dt_id = vdt_id;


insert into `data-bi-prd-935c.bi_mart.bima_dly`
select cast(vdt_id as date) dt_id
  , a.msisdn, b.subscriber_type, cast(b.actvn_dt as timestamp), cast(b.first_usg_dt as timestamp), a.bima_flag
  , total_trx
  , inapp_rev
  , online_rev
  , reload
  , p2p_topup
  , vas_rev
  , bill_pay
  , cvm_rev
  , hits_trx
  , date_diff(cast(vdt_id as date) , coalesce(b.first_usg_dt,b.actvn_dt), Day) tnr
  , current_timestamp() process_dt
  , c.site_id
  , inapp_atl_rev
  , inapp_cvm_rev
  , online_atl_rev
  , online_cvm_rev
  , voucher_reload
  , gift_cvm
  , gift_atl
  , gift_reload
  , gift_cvm_lego  
from `data-bi-prd-935c.bi_stg.hg_tmp_bima_dly` a
left join
(
  select sbscrptn_msisdn msisdn
    , case when product_id=8 then 'PREPAID' ELSE 'POSTPAID' end subscriber_type
    , cast(activation_dtm as date) actvn_dt
    --, (least(coalesce(cast(first_usage_dt as date),'9999-12-31'), least(coalesce(parse_date('%Y%m%d',cast(first_billing_usage_dt_sk_id as string)),'9999-12-31'), coalesce(cast(any_event_first_usage_date as date),'9999-12-31')))) as first_usg_dt
    ,
    (
      SELECT MIN(d)
      FROM UNNEST([
        cast(first_usage_dt as date),
        safe.parse_date('%Y%m%d',cast(first_billing_usage_dt_sk_id as string)),
        cast(any_event_first_usage_date as date)
      ]) AS d
      WHERE d IS NOT NULL
    )  as first_usg_dt  
  from `data-dtptechm-prd-c7ca.dwh.sbscrptn_attribs`
  where rank_ind =1 
    -- and tool_of_trade_ind = 'N' -- non employee
) b
  on a.msisdn=b.msisdn
left join
(
  select sbscrptn_msisdn msisdn , site_id_90 site_id
  from
  (
    select sbscrptn_msisdn , site_id_90, row_number() over(partition by dt, sbscrptn_msisdn order by sbscrptn_ek_id desc) as rk
    from `data-bi-prd-935c.bi_mart.ioh_subscriber_site_attribs_rolling`
    where dt=vdt_id and site_id_90 is not null
  ) x
  where rk=1
) c
  on a.msisdn=c.msisdn
where a.msisdn like '6289%'
;

  --- drop temp table

drop table if exists `data-bi-prd-935c.bi_stg.hg_tmp_bima_dly_dau`;
drop table if exists `data-bi-prd-935c.bi_stg.hg_tmp_bima_dly_dpu`;
drop table if exists `data-bi-prd-935c.bi_stg.hg_tmp_bima_dly`;