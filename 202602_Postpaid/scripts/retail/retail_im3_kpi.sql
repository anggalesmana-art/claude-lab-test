-------------------------------------------------- 
-- 0. Insert FCR Gerai --------------------------- 
insert overwrite rdm.retail_gerai_fcr 
partition (mth_id)
with fcr_raw as (
    select 'INT' source,
    dt_id,
    case
        when substr(act_code,1,2)='11' then '11-INFO'
        when substr(act_code,1,2)='12' then '12-REQUEST'
        when substr(act_code,1,2) in ('13','14') then '14-COMPLAINT'
        end ticket_type,
        issue_desc,
        creator_location,
        creator_region,
        creator_login as creator_id, 
        creator_name,  
        REGEXP_EXTRACT(creator_location , '^(.*?)-', 1) AS store_code, 
        count(*) total
    from stg.stg_siebel_dly_intrctn
    where activity_type='Walk In' 
        and strleft(dt_id,6) = strleft('{dt_id}',6)
        and substr(act_code,1,2) in ('11','12','13','14')
    group by 
    dt_id,
    case
        when substr(act_code,1,2)='11' then '11-INFO'
        when substr(act_code,1,2)='12' then '12-REQUEST'
        when substr(act_code,1,2) in ('13','14') then '14-COMPLAINT'
        end,issue_desc,creator_location,creator_region, creator_login, creator_name, 
        REGEXP_EXTRACT(creator_location , '^(.*?)-', 1)
    union all
    select 'SR',
    dt_id,
    case
        when substr(activity_code,1,2)='11' then '11-INFO'
        when substr(activity_code,1,2)='12' then '12-REQUEST'
        when substr(activity_code,1,2) in ('13','14') then '14-COMPLAINT'
        end ticket_type,
        issue_description,
        creator_pr_location,
        creator_pr_region, 
        creator_login as creator_id, 
        creator_full_name as creator_name, 
        REGEXP_EXTRACT(creator_pr_location , '^(.*?)-', 1) AS store_code, 
        count(distinct sr_number) total
    from    
    (select 
        *,
        case 
        when owner_pr_location like 'JKBB%' then 'CX'
        when substr(owner_pr_location,1,3) in ('OLA','TLS') then 'Sales'
        when substr(owner_pr_location,1,2) in ('DC','DS') then 'Sales'
        when owner_pr_location like 'LOC%' then 'Siebel'
        when owner_pr_location is null then 'null'
        else 'Gerai' end owner_channel
    from stg.stg_siebel_dly_sr) a
    where  substr(activity_code,1,2) in ('12','13','14')
        and status in ('Open','In Progress','Closed')
        and creator_pr_location not like 'JKBB%' and creator_pr_location not like 'LOC%'
        and creator_pr_location not like 'DS%' and creator_pr_location not like 'DC%'
        and creator_pr_location not like 'TLS%' and creator_pr_location not like 'OLA%'
        and strleft(dt_id,6)=strleft('{dt_id}',6)
        and owner_channel <> 'Gerai'
        and owner <> 'VER_HQ'
    group by 
    dt_id,
    case
        when substr(activity_code,1,2)='11' then '11-INFO'
        when substr(activity_code,1,2)='12' then '12-REQUEST'
        when substr(activity_code,1,2) in ('13','14') then '14-COMPLAINT'
        end,issue_description,creator_pr_location,creator_pr_region, creator_login, creator_full_name, 
        REGEXP_EXTRACT(creator_pr_location , '^(.*?)-', 1)
    union all
    select 
        'INT' source, 
        cast(FROM_UNIXTIME(UNIX_TIMESTAMP(a.transaction_date, 'dd/MM/yyyy HH:mm'), 'yyyyMMdd') as string)  AS dt_id, 
        'IPOS' ticket_type, 
        a.service_type as issue_desc, 
        concat(a.organization_ref_code,'-',a.organization_name) creator_location, 
        a.regional as creator_region, 
        a.username as creator_id, 
        concat(a.username,'-',a.organization_name) creator_name, 
        a.organization_ref_code as store_code,
        count(*) as total
    from rdm.ipos_trans_details as a 
        left join rdm.storelist as b 
            on a.organization_ref_code=b.store_code 
    where (lower(b.channel_group) like '%gerai%' or lower(b.channel_group) like '%franchise%' or upper(a.organization_name) like 'GERAI%') 
        and cast(FROM_UNIXTIME(UNIX_TIMESTAMP(a.transaction_date, 'dd/MM/yyyy HH:mm'), 'yyyyMM') as string)=strleft('{dt_id}',6)
    group by 1, 2, 3, 4, 5, 6, 7, 8, 9) 
select  
    a.source, 
    a.dt_id, 
    a.ticket_type, 
    a.issue_desc, 
    a.creator_location, 
    a.creator_region, 
    a.creator_id as agent_id, 
    upper(c.fullname) as agent_name,
    a.store_code, 
    b.region_circle, 
    b.circle, 
    a.total as total_trx,  
    'IM3' as brand,
    strleft(a.dt_id, 6) as mth_id
from fcr_raw as a 
    -- left join (select * from rdm.storelist 
    --     where lower(channel_group) like '%gerai%' or lower(channel_group) like '%franchise%') as b 
    left join rdm.storelist as b
        on a.store_code=b.store_code
    left join rdm.user_detail_report as c on a.creator_id = c.username;

-------------------------------------------------- 
-- 1. Dump data FCR ------------------------------ 
select * from rdm.retail_gerai_fcr
where mth_id = strleft('{dt_id}',6); 

-- 02. SR TT Agent MTD Level IM3 
with kpi as (
    select 
        '{dt_id}' as dt_id, 
        sr.creator_login as agent_id, 
        REGEXP_EXTRACT(sr.creator_pr_location , '^(.*?)-', 1) AS store_code, 
        'sr_total' as kpi_name,
        count(distinct case when (strleft(sr.dt_id,6)=strleft('{dt_id}',6) and sr.dt_id <= '{dt_id}') then sr.sr_number end) as mtd_value,
        count(distinct case when (strleft(sr.dt_id,6)=from_timestamp(add_months(to_timestamp('{dt_id}','yyyyMMdd'),-1),'yyyyMM') and sr.dt_id<=from_timestamp(add_months(to_timestamp('{dt_id}','yyyyMMdd'),-1),'yyyyMMdd')) then sr.sr_number end) as lmtd_value 
    from stg.stg_siebel_dly_sr as sr 
    where substr(sr.activity_code,1,2) in ('12','13','14')
    and sr.status='Closed' 
    and sr.creator_pr_location not like 'JKBB%' and sr.creator_pr_location not like 'LOC%'
    and sr.creator_pr_location not like 'DS%' and sr.creator_pr_location not like 'DC%'
    and sr.creator_pr_location not like 'TLS%' and sr.creator_pr_location not like 'OLA%'
    and ((strleft(sr.dt_id,6)=strleft('{dt_id}',6) and sr.dt_id <= '{dt_id}')
    or (strleft(sr.dt_id,6)=from_timestamp(add_months(to_timestamp('{dt_id}','yyyyMMdd'),-1),'yyyyMM') and sr.dt_id<=from_timestamp(add_months(to_timestamp('{dt_id}','yyyyMMdd'),-1),'yyyyMMdd')))
    and sr.owner <> 'VER_HQ'
    group by 1, 2, 3, 4 
    union all 
    select 
        '{dt_id}' as dt_id, 
        sr.creator_login as agent_id, 
        REGEXP_EXTRACT(sr.creator_pr_location , '^(.*?)-', 1) AS store_code, 
        'sr_done' as kpi_name,
        count(distinct case when (strleft(sr.dt_id,6)=strleft('{dt_id}',6) and sr.dt_id <= '{dt_id}') and sr.inprogress_closed <= sr.due_date then sr.sr_number end) as mtd_value,
        count(distinct case when (strleft(sr.dt_id,6)=from_timestamp(add_months(to_timestamp('{dt_id}','yyyyMMdd'),-1),'yyyyMM') and sr.dt_id<=from_timestamp(add_months(to_timestamp('{dt_id}','yyyyMMdd'),-1),'yyyyMMdd')) and sr.inprogress_closed <= sr.due_date then sr.sr_number end) as lmtd_value 
    from stg.stg_siebel_dly_sr as sr 
    where substr(sr.activity_code,1,2) in ('12','13','14')
    and sr.status='Closed' 
    and sr.creator_pr_location not like 'JKBB%' and sr.creator_pr_location not like 'LOC%'
    and sr.creator_pr_location not like 'DS%' and sr.creator_pr_location not like 'DC%'
    and sr.creator_pr_location not like 'TLS%' and sr.creator_pr_location not like 'OLA%'
    and ((strleft(sr.dt_id,6)=strleft('{dt_id}',6) and sr.dt_id <= '{dt_id}')
    or (strleft(sr.dt_id,6)=from_timestamp(add_months(to_timestamp('{dt_id}','yyyyMMdd'),-1),'yyyyMM') and sr.dt_id<=from_timestamp(add_months(to_timestamp('{dt_id}','yyyyMMdd'),-1),'yyyyMMdd')))
    and sr.owner <> 'VER_HQ'
    group by 1, 2, 3, 4  
    union all 
    select 
        '{dt_id}' as dt_id, 
        sr.creator_login as agent_id, 
        REGEXP_EXTRACT(sr.creator_pr_location , '^(.*?)-', 1) AS store_code, 
        'sr_tt' as kpi_name,
        count(distinct case when (strleft(sr.dt_id,6)=strleft('{dt_id}',6) and sr.dt_id <= '{dt_id}') and sr.inprogress_closed <= sr.due_date then sr.sr_number end)/count(distinct case when (strleft(sr.dt_id,6)=strleft('{dt_id}',6) and sr.dt_id <= '{dt_id}') then sr.sr_number end) as mtd_value,
        count(distinct case when (strleft(sr.dt_id,6)=from_timestamp(add_months(to_timestamp('{dt_id}','yyyyMMdd'),-1),'yyyyMM') and sr.dt_id<=from_timestamp(add_months(to_timestamp('{dt_id}','yyyyMMdd'),-1),'yyyyMMdd')) and sr.inprogress_closed <= sr.due_date then sr.sr_number end)/count(distinct case when (strleft(sr.dt_id,6)=from_timestamp(add_months(to_timestamp('{dt_id}','yyyyMMdd'),-1),'yyyyMM') and sr.dt_id<=from_timestamp(add_months(to_timestamp('{dt_id}','yyyyMMdd'),-1),'yyyyMMdd')) then sr.sr_number end) as lmtd_value 
    from stg.stg_siebel_dly_sr as sr 
    where substr(sr.activity_code,1,2) in ('12','13','14')
    and sr.status='Closed' 
    and sr.creator_pr_location not like 'JKBB%' and sr.creator_pr_location not like 'LOC%'
    and sr.creator_pr_location not like 'DS%' and sr.creator_pr_location not like 'DC%'
    and sr.creator_pr_location not like 'TLS%' and sr.creator_pr_location not like 'OLA%'
    and ((strleft(sr.dt_id,6)=strleft('{dt_id}',6) and sr.dt_id <= '{dt_id}')
    or (strleft(sr.dt_id,6)=from_timestamp(add_months(to_timestamp('{dt_id}','yyyyMMdd'),-1),'yyyyMM') and sr.dt_id<=from_timestamp(add_months(to_timestamp('{dt_id}','yyyyMMdd'),-1),'yyyyMMdd')))
    and sr.owner <> 'VER_HQ'
    group by 1, 2, 3, 4 
) 
select 
    kpi.dt_id, 
    st.circle, 
    st.region_circle as region, 
    st.store_name, 
    'IM3' as brand, 
    upper(kpi.store_code) as store_code, 
    kpi.agent_id,
    kpi.kpi_name,
    kpi.mtd_value,
    kpi.lmtd_value
from kpi
left join rdm.storelist st 
    on kpi.store_code=st.store_code
; 
