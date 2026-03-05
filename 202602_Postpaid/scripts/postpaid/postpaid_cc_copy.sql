------------------- CHAMPION CLUB QUERY------------------------------------------------------------------------
-- 01. GA Postpaid
INSERT OVERWRITE rdm.bai_kpi_postpaid PARTITION (dt_id, kpi_name)
    select  
        c.circle,
        c.region_circle as region,
        c.sales_area,
        c.nik as nik_rce,
        c.rce as name_rce,
        -- a.store_code_rev as store_code,
        case when lower(a.agent_type) like '%outcall%' then upper(a.nik_sales) else upper(a.store_code_rev) end as store_code,
        c.store_name,
        upper(c.channel_group) as channel_group,
        count(distinct case when (strleft(a.activation_date,6)=strleft('{dt_id}',6) and a.activation_date<='{dt_id}') then a.msisdn else null end) value_mtd,
        count(distinct case when (strleft(a.activation_date,6)=from_timestamp(add_months(to_timestamp('{dt_id}','yyyyMMdd'),-1),'yyyyMM') and a.activation_date<=from_timestamp(add_months(to_timestamp('{dt_id}','yyyyMMdd'),-1),'yyyyMMdd')) then a.msisdn else null end) value_lmtd,
        strleft('{dt_id}',6) as mth_id,
        '{dt_id}' as dt_id,
        'GA' as kpi_name
    from rdm.dump_daily_ga as a 
    left join
        (select
        distinct c.store_code,
                 c.store_name,
                 upper(d.rce_name) as rce,
                 d.nik_rce as nik,
                 c.circle,
                 c.region_circle,
                 c.sales_area,
                 c.channel_group
        from rdm.storelist as c 
        left join 
        	(select * from rdm.rce_mapping 
        		where REPLACE(strleft(periode, 7), '-', '')=strleft('{dt_id}',6) ) d 
        	on upper(c.store_code) = upper(d.store_code_rev)
        ) c 
        -- on upper(a.store_code_rev) = upper(c.store_code)   
        on case when lower(a.agent_type) like '%outcall%' then upper(a.nik_sales) else upper(a.store_code_rev) end=upper(c.store_code)
        where 1=1 
        and ((strleft(a.activation_date,6)=strleft('{dt_id}',6) and a.activation_date<='{dt_id}')  
        or (strleft(a.activation_date,6)=from_timestamp(add_months(to_timestamp('{dt_id}','yyyyMMdd'),-1),'yyyyMM') and a.activation_date<=from_timestamp(add_months(to_timestamp('{dt_id}','yyyyMMdd'),-1),'yyyyMMdd'))) 
        and a.order_type in ('New Registration','Migration') 
    group by 1, 2, 3, 4, 5, 6, 7, 8, 11, 12, 13;

-- 02. Sales Revenue 
INSERT OVERWRITE rdm.bai_kpi_postpaid PARTITION (dt_id, kpi_name) 
select  
    circle, 
    region, 
    sales_area, 
    nik_rce, 
    name_rce, 
    store_code, 
    store_name, 
    channel_group, 
    cast(value_mtd as decimal(18,2)) value_mtd, 
    cast(value_lmtd as decimal(18,2)) value_lmtd, 
    mth_id, 
    dt_id, 
    kpi_name
from 
(
    select  
        c.circle,
        c.region_circle as region,
        c.sales_area,
        c.nik as nik_rce,
        c.rce as name_rce, 
        -- a.store_code_rev as store_code,
        case when lower(a.agent_type) like '%outcall%' then upper(a.nik_sales) else upper(a.store_code_rev) end as store_code,
        c.store_name,
        upper(c.channel_group) as channel_group,
        sum(case 
            when (strleft(a.activation_date,6) = strleft('{dt_id}',6) 
                  and a.activation_date <= '{dt_id}') 
            -- then CAST(NULLIF(a.guaranteed_revenue_mio, '') AS DECIMAL(18,2))*1000000 
            -- else CAST(0 AS DECIMAL(18,2))  
        then cast(nullif(a.guaranteed_revenue_mio,'') as float)*1000000 else 0
        end) as value_mtd,  
        sum(case 
            when (strleft(a.activation_date,6) = from_timestamp(add_months(to_timestamp('{dt_id}','yyyyMMdd'),-1),'yyyyMM') 
                  and a.activation_date <= from_timestamp(add_months(to_timestamp('{dt_id}','yyyyMMdd'),-1),'yyyyMMdd')) 
            -- then CAST(NULLIF(a.guaranteed_revenue_mio, '') AS DECIMAL(18,2))*1000000 
            -- else CAST(0 AS DECIMAL(18,2))  
        then cast(nullif(a.guaranteed_revenue_mio,'') as float)*1000000 else 0
        end) as value_lmtd,
        strleft('{dt_id}',6) as mth_id,
        '{dt_id}' as dt_id,
        'Sales Revenue' as kpi_name
    from rdm.dump_daily_ga as a 
    left join
        (select
        distinct c.store_code,
                 c.store_name,
                 upper(d.rce_name) as rce,
                 d.nik_rce as nik,
                 c.circle,
                 c.region_circle,
                 c.sales_area,
                 c.channel_group
        from rdm.storelist as c 
        left join 
        	(select * from rdm.rce_mapping 
        		where REPLACE(strleft(periode, 7), '-', '')=strleft('{dt_id}',6) ) d 
        	on upper(c.store_code) = upper(d.store_code_rev)
        ) c 
        -- on upper(a.store_code_rev) = upper(c.store_code)  
        on case when lower(a.agent_type) like '%outcall%' then upper(a.nik_sales) else upper(a.store_code_rev) end=upper(c.store_code)
        where 1=1 
        and ((strleft(a.activation_date,6)=strleft('{dt_id}',6) and a.activation_date<='{dt_id}')  
        or (strleft(a.activation_date,6)=from_timestamp(add_months(to_timestamp('{dt_id}','yyyyMMdd'),-1),'yyyyMM') and a.activation_date<=from_timestamp(add_months(to_timestamp('{dt_id}','yyyyMMdd'),-1),'yyyyMMdd'))) 
    group by 1, 2, 3, 4, 5, 6, 7, 8, 11, 12, 13
) as xx;

-- 03. Store Productivity
INSERT OVERWRITE rdm.bai_kpi_postpaid PARTITION (dt_id, kpi_name)
    select  
        xx.circle,
        xx.region_circle as region,
        xx.sales_area,
        xx.nik as nik_rce,
        xx.rce as name_rce,
        '' as store_code,
        '' as store_name,
        upper(xx.channel_group) as channel_group,
        sum(case when (act_mth=strleft('{dt_id}',6)) then productive_flag else 0 end) value_mtd,  
        sum(case when (act_mth=from_timestamp(add_months(to_timestamp('{dt_id}','yyyyMMdd'),-1),'yyyyMM')) then productive_flag else 0 end) value_lmtd,
        strleft('{dt_id}',6) as mth_id,
        '{dt_id}' as dt_id,
        'Store Productivity' as kpi_name
    from ( 
        select  
            strleft(a.activation_date,6) as act_mth,  
            a.store_code_rev,  
            a.store_name_rev,  
            c.circle, 
            c.region_circle,  
            c.sales_area,
            c.rce,
            c.nik,
            upper(a.channel_rev) as channel_group,  
            c.month_dif,  
            count(distinct a.msisdn) as ga,  
            case when c.month_dif = 1 and count(distinct a.msisdn)>=1 then 1  
                 when c.month_dif = 2 and count(distinct a.msisdn)>=2 then 1  
                 when c.month_dif >=3 and count(distinct a.msisdn)>=3 then 1  
                else 0 end as productive_flag 
        from rdm.dump_daily_ga as a 
        inner join ( 
            select
                 distinct c.store_code,
                 c.store_name,
                 upper(d.rce_name) as rce,
                 d.nik_rce as nik,
                 c.circle,
                 c.region_circle,
                 c.sales_area,
                 c.channel_group,
                 round(months_between( 
                        to_timestamp('{dt_id}', 'yyyyMMdd'), 
                        to_timestamp(registered_date, 'yyyyMMdd')),0) month_dif
        from rdm.storelist as c 
        left join 
        (select * from rdm.rce_mapping 
        		where REPLACE(strleft(periode, 7), '-', '')=strleft('{dt_id}',6) ) d 
        	on upper(c.store_code) = upper(d.store_code_rev)
        ) c 
        -- on upper(a.store_code_rev) = upper(c.store_code)  
        on case when lower(a.agent_type) like '%outcall%' then upper(a.nik_sales) else upper(a.store_code_rev) end=upper(c.store_code)
        where 1=1 
        and ((strleft(a.activation_date,6)=strleft('{dt_id}',6) and a.activation_date<='{dt_id}')  
        or  (strleft(a.activation_date,6)=from_timestamp(add_months(to_timestamp('{dt_id}','yyyyMMdd'),-1),'yyyyMM') and a.activation_date<=from_timestamp(add_months(to_timestamp('{dt_id}','yyyyMMdd'),-1),'yyyyMMdd'))) 
        and a.order_type in ('New Registration','Migration')  
        and upper(a.channel_rev) not in ('SMB', 'ONLINE CHANNEL', 'OLA', 'OTHERS', 'DIRECT SALES', 'OUTCALL AGENT') 
        group by 1, 2, 3, 4, 5, 6, 7, 8, 9, 10) as xx 
    group by 1, 2, 3, 4, 5, 6, 7, 8, 11, 12, 13;

-- 04. Agent Productivity 
INSERT OVERWRITE rdm.bai_kpi_postpaid PARTITION (dt_id, kpi_name)
    select  
        c.circle,
        c.region_circle as region,
        c.sales_area,
        c.nik as nik_rce,
        c.rce as name_rce,
        nik_sales as store_code,
        sales_name as store_name,
        upper(c.channel_group) as channel_group,
        count(distinct case when (strleft(a.activation_date,6)=strleft('{dt_id}',6) and a.activation_date<='{dt_id}') then a.msisdn else null end) value_mtd,
        count(distinct case when (strleft(a.activation_date,6)=from_timestamp(add_months(to_timestamp('{dt_id}','yyyyMMdd'),-1),'yyyyMM') and a.activation_date<=from_timestamp(add_months(to_timestamp('{dt_id}','yyyyMMdd'),-1),'yyyyMMdd')) then a.msisdn else null end) value_lmtd,
        strleft('{dt_id}',6) as mth_id,
        '{dt_id}' as dt_id,
        'Agent Productivity' as kpi_name
    from rdm.dump_daily_ga as a
    left join
    (select
        distinct c.store_code,
                 c.store_name,
                 upper(d.rce_name) as rce,
                 d.nik_rce as nik, 
                 c.circle,
                 c.region_circle,
                 c.sales_area,
                 c.channel_group
        from rdm.storelist as c 
        left join 
        	(select * from rdm.rce_mapping 
        		where REPLACE(strleft(periode, 7), '-', '')=strleft('{dt_id}',6) ) d 
        	on upper(c.store_code) = upper(d.store_code_rev)
        ) c 
        -- on upper(a.store_code_rev) = upper(c.store_code)
        on case when lower(a.agent_type) like '%outcall%' then upper(a.nik_sales) else upper(a.store_code_rev) end=upper(c.store_code)
    where 1=1 
    and ((strleft(a.activation_date,6)=strleft('{dt_id}',6) and a.activation_date<='{dt_id}')  
    or (strleft(a.activation_date,6)=from_timestamp(add_months(to_timestamp('{dt_id}','yyyyMMdd'),-1),'yyyyMM') and a.activation_date<=from_timestamp(add_months(to_timestamp('{dt_id}','yyyyMMdd'),-1),'yyyyMMdd'))) 
    and a.order_type in ('New Registration','Migration')
    and upper(a.channel_rev) in ('OUTCALL AGENT', 'DIRECT SALES', 'SMB')
    group by 1, 2, 3, 4, 5, 6, 7, 8, 11, 12, 13;

-- 05. M3S Monthly  
INSERT OVERWRITE rdm.bai_kpi_postpaid PARTITION (dt_id, kpi_name) 
select
        b.circle,
        b.region,
        b.sales_area,
        b.nik_rce,
        b.name_rce,
        b.store_code,
        b.store_name,
        b.channel_group,
        count(distinct case when a.msisdn = b.msisdn then a.msisdn else null end) as value_mtd,
        0 as value_lmtd,
        strleft('{dt_id}',6) as mth_id,
        '{dt_id}' as dt_id,
        'M3S Monthly' as kpi_name
    from
        (
        	select  
        	distinct
            	msisdn
            from biadm.rk_cst_pstpaid_rtl_v1
            where 1=1
            and upper(ast_st) = 'ACTIVE'
            and strleft(dt_id,6) = strleft('{dt_id}',6)
        ) a
    INNER JOIN
    (
	    	select  
	        a.msisdn,
	        a.activation_date,
	        c.circle,
	        c.region_circle as region,
	        c.sales_area,
	        c.nik as nik_rce,
	        c.rce as name_rce,
	        -- a.store_code_rev as store_code,
	        case when lower(a.agent_type) like '%outcall%' then upper(a.nik_sales) else upper(a.store_code_rev) end as store_code,
	        c.store_name,
	        upper(a.channel_rev) as channel_group
	        from rdm.dump_daily_ga as a 
	        left join
	         (select
	        distinct c.store_code,
	                 c.store_name,
	                 upper(d.rce_name) as rce,
	                 d.nik_rce as nik, 
	                 c.circle,
	                 c.region_circle,
	                 c.sales_area,
	                 c.channel_group
	        from rdm.storelist as c 
	        left join 
	        	(select * from rdm.rce_mapping 
	        		where REPLACE(strleft(periode, 7), '-', '')=strleft('{dt_id}',6) ) d 
	        	on upper(c.store_code) = upper(d.store_code_rev)
	        ) c 
	        -- on upper(a.store_code_rev) = upper(c.store_code)
	        on case when lower(a.agent_type) like '%outcall%' then upper(a.nik_sales) else upper(a.store_code_rev) end=upper(c.store_code)
	    where 1=1
	    and a.order_type in ('New Registration','Migration')
	    and a.tenure = '1' 
	    and strleft(activation_date,6)=FROM_TIMESTAMP(ADD_MONTHS(TO_TIMESTAMP('{dt_id}', 'yyyyMMdd'), -3), 'yyyyMM')
    ) b on a.msisdn = b.msisdn   
    group by 1, 2, 3, 4, 5, 6, 7, 8, 11, 12, 13;

-- 06. GA M3S Monthly
INSERT OVERWRITE rdm.bai_kpi_postpaid PARTITION (dt_id, kpi_name)
    select  
        c.circle,
        c.region_circle as region,
        c.sales_area,
        c.nik as nik_rce,
        c.rce as name_rce,
        -- a.store_code_rev as store_code,
        case when lower(a.agent_type) like '%outcall%' then upper(a.nik_sales) else upper(a.store_code_rev) end as store_code,
        c.store_name,
        upper(c.channel_group) as channel_group,
        count(distinct a.msisdn) value_mtd,
        0 value_lmtd,
        strleft('{dt_id}',6) as mth_id,
        '{dt_id}' as dt_id,
        'GA M3S Monthly' as kpi_name
    from rdm.dump_daily_ga as a 
    left join
    (select
        distinct c.store_code,
                 c.store_name,
                 upper(d.rce_name) as rce,
                 d.nik_rce as nik, 
                 c.circle,
                 c.region_circle,
                 c.sales_area,
                 c.channel_group
        from rdm.storelist as c 
        left join 
        	(select * from rdm.rce_mapping 
        		where REPLACE(strleft(periode, 7), '-', '')=strleft('{dt_id}',6) ) d 
        	on upper(c.store_code) = upper(d.store_code_rev)
        ) c 
        -- on upper(a.store_code_rev) = upper(c.store_code)'{dt_id}'
        on case when lower(a.agent_type) like '%outcall%' then upper(a.nik_sales) else upper(a.store_code_rev) end=upper(c.store_code)
    where 1=1 
    and strleft(activation_date,6)=FROM_TIMESTAMP(ADD_MONTHS(TO_TIMESTAMP('{dt_id}', 'yyyyMMdd'), -3), 'yyyyMM') 
    and a.order_type in ('New Registration','Migration')
    and a.tenure = '1'
    group by 1, 2, 3, 4, 5, 6, 7, 8, 11, 12, 13;

-- 07. M3S Monthly %
INSERT OVERWRITE rdm.bai_kpi_postpaid PARTITION (dt_id, kpi_name)
select  
	a.circle, 
	a.region, 
	'' as sales_area, 
	a.nik_rce, 
	a.name_rce, 
	'' as store_code, 
	'' as store_name, 
	a.channel_group, 
	cast(sum(case when a.kpi_name = 'M3S Monthly' then a.value_mtd else 0 end)/nullif(sum(case when a.kpi_name = 'GA M3S Monthly' then a.value_mtd else 0 end),0) as float) as value_mtd,
    cast(sum(case when a.kpi_name = 'M3S Monthly' then a.value_lmtd else 0 end)/nullif(sum(case when a.kpi_name = 'GA M3S Monthly' then a.value_lmtd else 0 end),0) as float) as value_lmtd,
	a.mth_id,
	a.dt_id,
	'M3S %' as kpi_name
from rdm.bai_kpi_postpaid as a
where a.mth_id = strleft('{dt_id}',6) and a.dt_id ='{dt_id}'
group by 1, 2, 3, 4, 5, 6, 7, 8, 11, 12, 13; 

-- INSERT OVERWRITE rdm.bai_kpi_postpaid PARTITION (dt_id, kpi_name)
--     select
--         b.circle,
--         b.region,
--         b.sales_area,
--         b.nik_rce,
--         b.name_rce,
--         b.store_code,
--         b.store_name,
--         b.channel_group,
--         count(distinct case when a.msisdn = b.msisdn then a.msisdn else null end) as value_mtd,
--         0 as value_lmtd,
--         strleft('{dt_id}',6) as mth_id,
--         '{dt_id}' as dt_id,
--         'M3S Monthly' as kpi_name
--     from
--         (select 
--             msisdn,
--             activation_date,
--             dt_id,
--             DATEDIFF(FROM_UNIXTIME(UNIX_TIMESTAMP(dt_id, 'yyyyMMdd'), 'yyyy-MM-dd'), activation_date) AS tenure_days,
--             FLOOR(DATEDIFF(FROM_UNIXTIME(UNIX_TIMESTAMP(dt_id, 'yyyyMMdd'), 'yyyy-MM-dd'), activation_date) / 30) as tenure_months
--             from biadm.rk_cst_pstpaid_rtl_v1
--             where 1=1
--             and upper(ast_st) = 'ACTIVE'
--             and dt_id = '{dt_id}'
--             and strleft(FROM_UNIXTIME(UNIX_TIMESTAMP(activation_date), 'yyyyMMdd'),6)=FROM_TIMESTAMP(ADD_MONTHS(TO_TIMESTAMP('{dt_id}', 'yyyyMMdd'), -3), 'yyyyMM')
--         ) a
--     INNER JOIN
--     (select  
--         a.msisdn,
--         a.activation_date,
--         c.circle,
--         c.region_circle as region,
--         c.sales_area,
--         c.nik as nik_rce,
--         c.rce as name_rce,
--         -- a.store_code_rev as store_code,
--         case when lower(a.agent_type) like '%outcall%' then upper(a.nik_sales) else upper(a.store_code_rev) end as store_code,
--         c.store_name,
--         upper(a.channel_rev) as channel_group
--         from rdm.dump_daily_ga as a 
--         left join
--          (select
--         distinct c.store_code,
--                  c.store_name,
--                  upper(d.rce_name) as rce,
--                  d.nik_rce as nik, 
--                  c.circle,
--                  c.region_circle,
--                  c.sales_area,
--                  c.channel_group
--         from rdm.storelist as c 
--         left join 
--         	(select * from rdm.rce_mapping 
--         		where REPLACE(strleft(periode, 7), '-', '')=strleft('{dt_id}',6) ) d 
--         	on upper(c.store_code) = upper(d.store_code_rev)
--         ) c 
--         -- on upper(a.store_code_rev) = upper(c.store_code)
--         on case when lower(a.agent_type) like '%outcall%' then upper(a.nik_sales) else upper(a.store_code_rev) end=upper(c.store_code)
--     where 1=1
--     and a.order_type in ('New Registration','Migration')
--     and a.tenure = '1' 
--     and strleft(activation_date,6)=FROM_TIMESTAMP(ADD_MONTHS(TO_TIMESTAMP('{dt_id}', 'yyyyMMdd'), -3), 'yyyyMM')
--     ) b on a.msisdn = b.msisdn and cast(a.activation_date as date) = CAST(FROM_UNIXTIME(UNIX_TIMESTAMP(b.activation_date, 'yyyyMMdd')) AS DATE)  
--     group by 1, 2, 3, 4, 5, 6, 7, 8, 11, 12, 13;