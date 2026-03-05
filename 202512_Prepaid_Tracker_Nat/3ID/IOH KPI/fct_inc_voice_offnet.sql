DECLARE vdt_id DATE DEFAULT @vdt_id;

delete from `data-bi-prd-935c.bi_mart.sms_a2p_sucess` where cast(transaction_date as date) = vdt_id;

insert into `data-bi-prd-935c.bi_mart.sms_a2p_sucess`
select 
called_number,
grp,
cast(transaction_date as date)
from `data-dtptechm-prd-c7ca.mis.sms_a2p_sucess` where cast(transaction_date as date) = vdt_id;

DELETE FROM `data-bi-prd-935c.bi_mart.fct_ioh_dgpcr_consentdt_new`
WHERE dt = vdt_id;

insert into `data-bi-prd-935c.bi_mart.fct_ioh_dgpcr_consentdt_new`
SELECT 
service_msisdn, nik, x_dgpcr_flag, cast(x_dgpcr_reg_date as date), x_consent_dt, rank_ind, cast(dt as date) 
FROM `data-dtptechm-prd-c7ca.mis.fct_ioh_dgpcr_consentdt_new` 
WHERE cast(dt as date) = vdt_id;


-- delete from `data-bi-prd-935c.bi_mart.msc_detail_3id` where dt_id = vdt_id;

-- insert into `data-bi-prd-935c.bi_mart.msc_detail_3id`
-- select date(dt_id) dt_id,
--     'MT Offnet' as tag,
--     called_party_number as sbscrptn_msisdn,
--     sum(cast(duration as int)) as usage
-- from `data-dtp-prd-aa1a.sor.msc_detail_3id`
-- where dt_id = timestamp(vdt_id)
--     and substring(called_party_number, 1, 5) in ('62895', '62896', '62897', '62898', '62899')
--     and substring(calling_party_number, 1, 5) not in (
--         '62895',
--         '62896',
--         '62897',
--         '62898',
--         '62899',
--         '62814',
--         '62815',
--         '62816',
--         '62855',
--         '62856',
--         '62857',
--         '62858'
--     )
--     and service_type = 'MTC'
--     and cast(duration as int) >= 6
-- group by 1,2,3;

delete from `data-bi-prd-935c.bi_mart.fct_inc_voice_offnet` where dt =  vdt_id;


insert into `data-bi-prd-935c.bi_mart.fct_inc_voice_offnet`
select dt_id as dt, cast(b.sbscrptn_ek_id as string), a.sbscrptn_msisdn,
(
    SELECT MIN(d)
    FROM UNNEST([
      cast(first_usage_dt as date),
      safe.parse_date('%Y%m%d',cast(first_billing_usage_dt_sk_id as string)),
      cast(any_event_first_usage_date as date)
    ]) AS d
    WHERE d IS NOT NULL
  ) as first_usage_dt,
cast(sum(cast(usage as numeric)) as INT64) as usage
from `data-bi-prd-935c.bi_mart.msc_detail_3id` a
left outer join `data-dtptechm-prd-c7ca.dwh.sbscrptn_attribs` b on a.sbscrptn_msisdn = b.sbscrptn_msisdn and b.rank_ind = 1
join
(
 select distinct service_msisdn
 from `data-bi-prd-935c.bi_mart.project_ioh_dgpcr_flag_hist`
 where dt_sk_id= vdt_id and x_dgpcr_flag in ('Y', 'A')
 
 union all
 select distinct service_msisdn
 from `data-bi-prd-935c.bi_mart.fct_ioh_dgpcr_consentdt_new`
 where rank_ind = 1 and dt =  vdt_id
 and x_consent_dt <=  vdt_id
) c on a.sbscrptn_msisdn = c.service_msisdn
where dt_id =  vdt_id
group by 1,2,3,4;   

delete from `data-bi-prd-935c.bi_mart.fct_rgu_voice_sms_free` where dt = vdt_id;

insert into `data-bi-prd-935c.bi_mart.fct_rgu_voice_sms_free`
select distinct cast(a.transaction_date as date) as dt,
cast(d.sbscrptn_ek_id as string),
a.called_number as sbscrptn_msisdn,
'sms_a2p_domestic' as tag
from 
(
    select distinct a.transaction_date, a.called_number
    from `data-bi-prd-935c.bi_mart.sms_a2p_sucess` a
    where CAST(transaction_date AS STRING) <> 'transaction_date' and CAST(transaction_date AS DATE) = vdt_id
) a
join
(
 select distinct service_msisdn
 from `data-bi-prd-935c.bi_mart.project_ioh_dgpcr_flag_hist`
 where x_dgpcr_flag in ('Y', 'A')
 and dt_sk_id = vdt_id
 
 union all

 select distinct service_msisdn
 from `data-bi-prd-935c.bi_mart.fct_ioh_dgpcr_consentdt_new`
 where rank_ind = 1 and CAST(dt AS DATE) = vdt_id
 and CAST(x_consent_dt AS DATE) <= vdt_id
) c on a.called_number = c.service_msisdn
join `data-dtptechm-prd-c7ca.dwh.sbscrptn_attribs` d on a.called_number = d.sbscrptn_msisdn and d.rank_ind = 1 and d.tool_of_trade_ind = 'N' and d.product_id = 8;
