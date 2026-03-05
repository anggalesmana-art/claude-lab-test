declare vdt_id date default @vdt_id;
	  
                                                                                                                  
 create or replace table `data-bi-prd-935c.bi_stg`.tmp_kikida 
 as
  select date_trunc(trx_dt_sk_id,month) as mth, sbscrptn_ek_id,
  case when source_mapping in ('CUST_DIRECT','CUST_DIRECT_AUTO_RENEWAL','CUST_DIRECT_BIMA',
  'CUST_DIRECT_BONSTRI_REDEEM','CUST_DIRECT_CHATBOT','CUST_DIRECT_CVM',
  'CUST_DIRECT_LOAN','CUST_DIRECT_SMS','CUST_DIRECT_UMB_MENU',
  'EVC_BROADBAND','RITA','SPV','SIM_BROADBAND','VOUCHER_FORFEIT'
  ) then source_mapping else service_type_name end as service_type_name,
  product_name,
  sum(hit) as hit,
  sum(netrevenue) as rev
  from `data-bi-prd-935c.bi_mart`.fct_cwn_rev_detail
  where date_trunc(trx_dt_sk_id,month) = date_trunc(vdt_id,month) and trx_dt_sk_id <= vdt_id
  and source_channel like '%TRANSFER%'
  and process_nm not in ('FRC_BALLOON_HOKI_DEMAND', 'RITA_BALLOON_HOKI_DEMAND', 'UNLOCK_BALLOON_HOKI_DEMAND', --exclude baloon hoki
  'CLIP_COMMISSION', 'STARS COMMISSION')
  group by 1,2,3,4;

  


 delete from `data-bi-prd-935c.bi_stg`.tmp_ga_acq_new where dt = vdt_id;




insert into  `data-bi-prd-935c.bi_stg`.tmp_ga_acq_new
  select vdt_id as dt, a.sbscrptn_ek_id, d.Trade_Tag,
  coalesce(b.Data_Rev,0) as Data_Rev,
  coalesce(b.Non_Data_Rev,0) as Non_Data_Rev,
  coalesce(b.VAS_Rev,0) as VAS_Rev,
  coalesce(c.amt_data_rev,0) as kikida_data_rev,
  coalesce(c.amt_nondata_rev,0) as kikida_nondata_rev
  from `data-bi-prd-935c.bi_mart`.fct_ga_site_id a
  left outer join
  (
   select date_trunc(trx_dt_sk_id,month) as mth, sbscrptn_ek_id,
   sum(case when service_type_name in ('MOBO', 'ORGANIC + PGI', 'Others - PAYU', 'Others - Roaming') then revenue else 0 end) as Data_Rev,
   sum(case when service_type_name in ('Loan', 'Others - OTHERS', 'Others - VAS_PARTNER', 'SMS + MMS', 'VOICE + VIDEO', 'Others - Markup Pulsa', 'Others - Others') then revenue else 0 end) as Non_Data_Rev,
   sum(case when service_type_name in ('VAS + Loan') then revenue else 0 end) as VAS_Rev
   from `data-bi-prd-935c.bi_mart`.fct_cwn_rev_detail_fnl
   where date_trunc(trx_dt_sk_id,month) = date_trunc(vdt_id,month) and trx_dt_sk_id <= vdt_id
   group by 1,2
  ) b on a.sbscrptn_ek_id = b.sbscrptn_ek_id and date_trunc(a.dt,month) = b.mth
  left outer join 
  (
   select mth, sbscrptn_ek_id,
   sum(case when service_type_name like 'CUST%' or service_type_name = 'ROAMING' then rev else 0 end) as amt_data_rev,
   sum(case when service_type_name in ('OTHERS', 'SMS', 'VOICE', 'VAS') then rev else 0 end) as amt_nondata_rev
   from `data-bi-prd-935c.bi_stg`.tmp_kikida 
   group by 1,2
  ) c on a.sbscrptn_ek_id = c.sbscrptn_ek_id and date_trunc(a.dt,month) = c.mth
  left outer join
  (
   select distinct cast(sbscrptn_ek_id as string) sbscrptn_ek_id,
   case when coalesce(ret_hierarchy_type,'NA') = 'ANGIE' then 'Trade' else 'Non Trade' end as Trade_Tag
   from `data-dtptechm-prd-c7ca.dwh`.sbscrptn_attribs a
   left outer join `data-dtptechm-prd-c7ca.dwh`.angie_hrchy_dim b ON a.angie_retailer_name = b.partner_qr_cd
  ) d on a.sbscrptn_ek_id = d.sbscrptn_ek_id
  where date_trunc(a.dt,month) = date_trunc(vdt_id,month) and a.dt <= vdt_id;



delete from `data-bi-prd-935c.bi_mart.fct_ga_acq_new` where mth = vdt_id;

insert into `data-bi-prd-935c.bi_mart.fct_ga_acq_new`
  select dt as mth, '3ID' as brand, sbscrptn_ek_id, trade_tag,
  cast(sum(data_rev - kikida_data_rev) as numeric) as data_rev,
  cast(sum(non_data_rev - kikida_nondata_rev) as numeric) as non_data_rev,
  cast(sum(vas_rev) as numeric) as vas_data,
  cast(sum(kikida_data_rev) as numeric) as kikida_data_rev,
  cast(sum(kikida_nondata_rev) as numeric) as kikida_nondata_rev
  from `data-bi-prd-935c.bi_stg`.tmp_ga_acq_new
  where dt = vdt_id
  group by 1,2,3,4;


