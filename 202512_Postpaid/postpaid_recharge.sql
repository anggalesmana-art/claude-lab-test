DECLARE observation_date DATE DEFAULT @vdt_id;

delete from `data-bi-dev-e36d.bi_mart.postpaid_rechage_stats` where dt_id = observation_date;
insert into `data-bi-dev-e36d.bi_mart.postpaid_rechage_stats` 
-- CREATE OR REPLACE TABLE `data-bi-prd-935c.bi_dm.tmp_postpaid_rech_stats_test` AS
select b.region, sum(a.tot_rechrg) tot_rechrg, count(distinct a.msisdn) nsubs, sum(tot_rechrg_idr_val) tot_amt, cast(a.dt_id as date)
from `data-dtp-prd-aa1a.smy.cst_rechrg_dly_smy` a
left join (
    select dt_id, msisdn, b.region
    FROM (
        select distinct dt_id, msisdn, pfx_hlr
        from `data-dtp-prd-aa1a.smy.ar_cst_pstpaid_rtl` 
        WHERE date(dt_id) = observation_date
            AND CAST(ar_lcs_tp_id AS string) = '2010'
            AND trim(lower(cst_tp)) IN ('individual', 'vvip')
            AND msisdn LIKE '628%'
    ) a
    left join (
        select distinct pfx_hlr, region
        from `data-bi-prd-935c.bi_mart.pstpaid_ref_region`
    ) b
    on a.pfx_hlr = b.pfx_hlr
) b
on date(a.dt_id) = date(b.dt_id) and a.msisdn = b.msisdn
where date(a.dt_id) = observation_date and tot_rechrg_idr_val > 0 and b.msisdn is not null
and coalesce(b.region, "nan") <> "nan"
group by a.dt_id, b.region;


delete from `data-bi-dev-e36d.bi_mart.postpaid_rechage_addon` where dt_id = observation_date;
insert into `data-bi-dev-e36d.bi_mart.postpaid_rechage_addon` -- Need copy to BI MART
-- CREATE OR REPLACE TABLE `data-bi-prd-935c.bi_dm.tmp_postpaid_rec_addon_test` AS
select a.service_type, a.sut service_usage_type, region, sum(t_amt) tot_amt, cast(transaction_date as date)
from (
  SELECT transaction_date, service_type,
  case
  when service_usage_type = 'Data - Roamer' then 'Data - PPU'
  when service_usage_type <> 'Voice - Addon' and service_type = 'VOICE' then 'Voice - PPU'
  when service_usage_type <> 'SMS - AddOn' and service_type = 'SMS' then 'SMS - PPU'
  when service_usage_type like 'VAS%' then 'VAS'
  else service_usage_type end as sut, msisdn, sum(total_amount) t_amt
  FROM `data-dtp-prd-aa1a.smy.usg_postpaid_dly_smy`
  WHERE date(transaction_date) = observation_date
  --  AND revenue_flag = 'Yes'
    AND account_id = 'DA39'
  GROUP BY transaction_date, service_type,
    case
        when service_usage_type = 'Data - Roamer' then 'Data - PPU'
        when service_usage_type <> 'Voice - Addon' and service_type = 'VOICE' then 'Voice - PPU'
        when service_usage_type <> 'SMS - AddOn' and service_type = 'SMS' then 'SMS - PPU'
        when service_usage_type like 'VAS%' then 'VAS'
        else service_usage_type 
    end, 
    msisdn
) a
left join (
    select dt_id, msisdn, b.region
    FROM `data-dtp-prd-aa1a.smy.ar_cst_pstpaid_rtl` a
    left join (
        select distinct pfx_hlr, region
        from `data-bi-prd-935c.bi_mart.pstpaid_ref_region`
    ) b
    on a.pfx_hlr = b.pfx_hlr
    WHERE date(dt_id) = observation_date
) b
on date(a.transaction_date) = date(b.dt_id) and a.msisdn = b.msisdn
and coalesce(region, "nan") <> "nan"
group by transaction_date, a.service_type, a.sut, region;


-- insert overwrite table biadm.rk_postpaid_rechage_overall partition (transaction_date) -- IMPALA
delete from `data-bi-dev-e36d.bi_mart.postpaid_rechage_overall` where date(transaction_date) = observation_date;
insert into `data-bi-dev-e36d.bi_mart.postpaid_rechage_overall`
-- CREATE OR REPLACE TABLE `data-bi-prd-935c.bi_dm.tmp_postpaid_rechage_overall_test` AS
select msisdn, service_type, service_usage_type, sum(total_amount) tot_amt, cast(transaction_date as date)
from `data-dtp-prd-aa1a.smy.usg_postpaid_dly_smy` 
where date(transaction_date) = observation_date and revenue_flag = 'Yes'  and concat(service_type, '-', service_usage_type) <> 'VOICE-VAS' 
group by msisdn, service_type, service_usage_type, transaction_date;