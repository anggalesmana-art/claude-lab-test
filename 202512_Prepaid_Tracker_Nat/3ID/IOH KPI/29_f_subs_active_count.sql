DECLARE vdt_id DATE DEFAULT @vdt_id;

delete from `data-bi-prd-935c.bi_mart.project_ioh_kpi_daily_tracker_national_wise`
where kpi_code in ('subs_active_count')
and load_dt_sk_id=vdt_id ;

insert into `data-bi-prd-935c.bi_mart.project_ioh_kpi_daily_tracker_national_wise`  
 select 
cast(vdt_id as date) as dt
,'H3I' as entity 
,'subs_active_count'
,'IOH' as definition
,cast(vdt_id as date)
,sum(cnt) from 
(
select 
cast(vdt_id as date) as dt_sk_id,
sd.msisdn,
coalesce(rprt.ctgry_ref_chld,'Central West North Jkt') as region,
cds.channel_id as store_name,
count(distinct sd.sbscrptn_ek_id) as cnt
from `data-dtptechm-prd-c7ca.dwh.sbscrptn_dim` sd
left join `data-dtptechm-prd-c7ca.dwh.channel_dim` cd on sd.mp3_channel_sk_id = cd.channel_sk_id
left join `data-dtptechm-prd-c7ca.dwh.rprt_fltr_ref_ctgry` rprt on rprt.ref_cd=cd.channel_id and ref_type_cd='MP3'
left join `data-dtptechm-prd-c7ca.dwh.channel_dim` cds on sd.channel_sk_id = cds.channel_sk_id
where sd.curr_ind = 'Y'
and sd.tool_of_trade_ind = 'N'
and sd.sbscrptn_status_cd IN ('Active','Suspended')
and CAST(sd.activation_dtm AS date) <= vdt_id
group by 1,2,3,4
union all
select 
cast(vdt_id as date) as dt_sk_id,
sd.msisdn,
coalesce(rprt.ctgry_ref_chld,'Central West North Jkt') as region,
cds.channel_id as store_name,
count(distinct sd.sbscrptn_ek_id) as cnt 
from `data-dtptechm-prd-c7ca.dwh.sbscrptn_dim` sd
left join `data-dtptechm-prd-c7ca.dwh.channel_dim` cd on sd.mp3_channel_sk_id = cd.channel_sk_id
left join `data-dtptechm-prd-c7ca.dwh.rprt_fltr_ref_ctgry` rprt on rprt.ref_cd=cd.channel_id and ref_type_cd='MP3'
left join `data-dtptechm-prd-c7ca.dwh.channel_dim` cds on sd.channel_sk_id = cds.channel_sk_id
where sd.curr_ind = 'Y'
and tool_of_trade_ind = 'N'
and sbscrptn_status_cd not in ('Active','Suspended')
and CAST(sd.activation_dtm AS date)  <= vdt_id
and CAST(sd.termination_dtm AS date)  > vdt_id
group by 1,2,3,4
) x
 group by 1,2,3,4,5;