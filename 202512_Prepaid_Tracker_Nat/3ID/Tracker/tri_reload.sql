DECLARE vdt_id DATE DEFAULT @vdt_id;

delete from `data-bi-prd-935c.bi_mart.kpi_national_tracker_dly` where brand = 'TRI' and dt_id = vdt_id and kpi_id in ('RLD0015','RLD0016','RLD0017','RLD0018','RLD0019');

INSERT INTO `data-bi-prd-935c.bi_mart.kpi_national_tracker_dly`
select 
'TRI' as brand,
case 
when coalesce(acct_balance_amt,0) <= 0 and coalesce(quota_balance,0) <= 0 then 'Balance MA = 0 & DA = 0'
when coalesce(acct_balance_amt,0) <= 0 and coalesce(quota_balance,0) > 0 then 'Balance MA = 0 & DA > 0'
when coalesce(acct_balance_amt,0) > 0 and coalesce(quota_balance,0) <= 0 then 'Balance MA > 0 & DA = 0'
when coalesce(acct_balance_amt,0) > 0 and coalesce(quota_balance,0) > 0 then 'Balance MA > 0 & DA > 0'
end as kpi_code,
'AVG' as flag,
count(distinct a.sbscrptn_ek_id) as metric,
current_timestamp() as process_dt,
case 
when coalesce(acct_balance_amt,0) <= 0 and coalesce(quota_balance,0) <= 0 then 'RLD0016'
when coalesce(acct_balance_amt,0) <= 0 and coalesce(quota_balance,0) > 0 then 'RLD0017'
when coalesce(acct_balance_amt,0) > 0 and coalesce(quota_balance,0) <= 0 then 'RLD0018'
when coalesce(acct_balance_amt,0) > 0 and coalesce(quota_balance,0) > 0 then 'RLD0019'
end as kpi,
load_dt as dt_id
from `data-bi-prd-935c.bi_mart.dm_closingsubs` a where load_dt = vdt_id
group by brand,kpi_code,flag,process_dt,kpi,dt_id;

INSERT INTO `data-bi-prd-935c.bi_mart.kpi_national_tracker_dly`
select 
'TRI' as brand,
'Closing Balance' as kpi_code,
'AVG' as flag,
sum(case when acct_balance_amt < 0 then 0 else acct_balance_amt end) as metric,
current_timestamp() as process_dt,
'RLD0015' as kpi,
load_dt as dt_id
from `data-bi-prd-935c.bi_mart.dm_closingsubs` a where load_dt = vdt_id
group by brand,kpi_code,flag,process_dt,kpi,dt_id;