
declare vdt_id date default @vdt_id;
--Rev Final
delete from `data-bi-prd-935c.bi_mart.fct_cwn_rev_detail_fnl` where trx_dt_sk_id = vdt_id;




insert into `data-bi-prd-935c.bi_mart.fct_cwn_rev_detail_fnl`
select trx_dt_sk_id,
sbscrptn_ek_id,
case when upper(process_nm) in ('EVC MARKUP', 'MARKUP_RITA', 'MARKUP_UNLOCK', 'BIMA MARKUP') then 'Others - Markup Pulsa'
     when upper(service_type_name) like 'CUST%' or upper(service_type_name) = 'GPRS' then 'ORGANIC + PGI' --change on 01 Jun 2025
     when upper(service_type_name) in ('EVC_BROADBAND','RITA','SPV','SIM_BROADBAND', 'VOUCHER_FORFEIT',
     'PORTION_MAIN_LOAN', 'PORTION_FOR_FEE_LOAN') --add on 26 Sep 2025 --> (new source mapping for portion main loan, new source mapping for service fee loan)
     or (upper(service_type_name) = 'PAYU' and process_nm = 'VOUCHER_FORFEIT') then 'MOBO' --change on 01 Jun 2025
     when upper(service_type_name) = 'VAS' then 'VAS + Loan'
     --when upper(service_type_name) = 'GPRS' then 'Others - PAYU'
     when upper(service_type_name) = 'ROAMING' then 'Others - Roaming'
     when upper(service_type_name) = 'SMS' then 'SMS + MMS'
     when upper(service_type_name) = 'MMS' then 'SMS + MMS'
     when upper(service_type_name) = 'VOICE' then 'VOICE + VIDEO'
     when upper(service_type_name) = 'VIDEO' then 'VOICE + VIDEO'
     when upper(process_nm) in ('BALANCE TRANSFER', 'EXPERIAN_PROCESSING_FEE') then 'Loan'
     when upper(process_nm) in ('ADDON_PULSA', 'CEPEK AMORTIZATION', 'MAIN_BALANCE_OTHERS_ADJUSTMENT', 'RITA_TOPUP', 'TOPUP', 'UNTAGGED_COMMISSION') then 'Others - Others'
     when upper(process_nm) in ('ONE-OFF CDR') and service_type_name = 'OTHERS' then 'Loan'
else 'Others - '||service_type_name end as service_type_name,
process_nm,
sum(revenue) as revenue
from
(
select trx_dt_sk_id, a.sbscrptn_ek_id,
case when source_mapping in ('CUST_DIRECT','CUST_DIRECT_AUTO_RENEWAL','CUST_DIRECT_BIMA',
'CUST_DIRECT_BONSTRI_REDEEM','CUST_DIRECT_CHATBOT','CUST_DIRECT_CVM',
'CUST_DIRECT_LOAN','CUST_DIRECT_SMS','CUST_DIRECT_UMB_MENU',
'EVC_BROADBAND','RITA','SPV','SIM_BROADBAND','VOUCHER_FORFEIT',
'PORTION_MAIN_LOAN', 'PORTION_FOR_FEE_LOAN'
) then source_mapping else service_type_name end as service_type_name,  
process_nm,
sum(netrevenue) as revenue
from `data-bi-prd-935c.bi_mart.fct_cwn_rev_detail` a
where trx_dt_sk_id = vdt_id
and process_nm not in ('FRC_BALLOON_HOKI_DEMAND', 'RITA_BALLOON_HOKI_DEMAND', 'UNLOCK_BALLOON_HOKI_DEMAND', --exclude baloon hoki
'CLIP_COMMISSION', 'STARS COMMISSION')
group by 1,2,3,4
) a
group by 1,2,3,4;




