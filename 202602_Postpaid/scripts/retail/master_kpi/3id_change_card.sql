delete from cockpit.tmp_kpi_change_card
where left(dt_id,6)=left('{dt_id}',6)
		and dt_id<='{dt_id}';

insert into cockpit.tmp_kpi_change_card
SELECT 
	msisdn, 
	case when ma.nik is not null then upper(ma.nik)
	    	when left(upper(a.CreatedBy),4)='MBPS' then UPPER(CONCAT('MBPS-', SUBSTRING(TRIM(REPLACE(REPLACE(a.CreatedBy, '-', ''), '_', '')), 5)))
	    	when left(upper(a.CreatedBy),4)='MPBS' then UPPER(CONCAT('MBPS-', SUBSTRING(TRIM(REPLACE(REPLACE(a.CreatedBy, '-', ''), '_', '')), 5)))
	    	else upper(a.CreatedBy) end as agent_id,
	coalesce(ma.store_code, a.dealercode) as store_code, 
	CallTypeTier3 as category,
	'SIEBEL' source_channel,
	max(date_format(Opened, '%Y%m%d')) as dt_id
FROM cockpit.raw_sr_opened as a
	left join cockpit.mapping_agent_nik as ma
		on case when left(upper(a.CreatedBy),4)='MPBS' then UPPER(CONCAT('MBPS', SUBSTRING(TRIM(REPLACE(REPLACE(a.CreatedBy, '-', ''), '_', '')), 5)))
    		else upper(TRIM(REPLACE(REPLACE(a.CreatedBy, '-', ''), '_', ''))) end = upper(ma.idx) 	           	
where date_format(a.Opened, '%Y%m')=left('{dt_id}',6)
	and date_format(a.Opened, '%Y%m%d')<='{dt_id}'
	and CallTypeTier3 = 'Replacement SIM Card'
	and STATUS = 'Closed'
group by 1, 2, 3, 4, 5
union all
SELECT
	case 
	    when left(customerid,3)='089' then concat('62',substr(customerid,2,100)) 
	    when left(customerid,3)='628' then customerid
	    else customerid
	end msisdn,
	trim(T2.dvm_code) AS agent_id,
	coalesce(T2.store_code, trim(T1.terminal_code)) as store_code,
	product_name as category, 
	case 
		when T2.dvm_code is not null then 'dvm_store'
		else 'dvm_standalone'
	  end as source_channel,
	max(date_format(date_trx, '%Y%m%d')) as dt_id
FROM cockpit_archieve.raw_3db_trx T1
	left join cockpit.dvm_mapping T2
				on trim(T1.terminal_code)=trim(T2.dvm_code)
    Where DATE_FORMAT(T1.date_trx, "%Y%m") = left('{dt_id}',6) 
	    and  DATE_FORMAT(T1.date_trx, "%Y%m%d")<='{dt_id}'
	    and T1.product_code <> 'VALIDITY_KTP'
	    and T1.product_code IN ('THREE_CHANGE_CARD','THREE_SIMCARD4G', 'THREE_CHANGE_CARD_O2O', 'Upgrade 4G O2O')
	    and T1.`result` = 'success'
	    and T1.state='Done'
group by 1, 2, 3, 4, 5
union all 
        select 
            -- a.user_contact as msisdn,
            case 
                when left(trim(a.user_contact),3)='089' then concat('62',substr(trim(a.user_contact),2,100)) 
                when left(trim(a.user_contact),3)='628' then trim(a.user_contact)
                else trim(a.user_contact)
            end msisdn,
			case when ma.nik is not null then upper(ma.nik)
				when left(upper(a.opened_by),4)='MBPS' then UPPER(CONCAT('MBPS-', SUBSTRING(TRIM(REPLACE(REPLACE(a.opened_by, '-', ''), '_', '')), 5)))
				when left(upper(a.opened_by),4)='MPBS' then UPPER(CONCAT('MBPS-', SUBSTRING(TRIM(REPLACE(REPLACE(a.opened_by, '-', ''), '_', '')), 5)))
				else upper(a.opened_by) end as agent_id,
            coalesce(ma.store_code, mb.dealercode) as store_code, 
            a.subcat as category, 
            'CSTOOLS' as source_channel, 
            max(date_format(a.opened_time, '%Y%m%d')) as dt_id
        from cockpit_archieve.cstools_raw_tickets as a 
            left join (
                select 
                distinct msisdn, CreatedBy
                FROM cockpit.raw_sr_opened
                    where replace(substring(Opened,1,7),'-','')=left('{dt_id}',6)
                    and date_format(Opened, '%Y%m%d')<='{dt_id}'
                    and CallTypeTier3 = 'Replacement SIM Card'
                    and STATUS = 'Closed'
            ) as b
                on a.user_contact = b.msisdn and a.opened_by=b.CreatedBy 
            left join cockpit.mapping_agent_nik ma
                on  case when left(upper(a.opened_by),4)='MPBS' then UPPER(CONCAT('MBPS', SUBSTRING(TRIM(REPLACE(REPLACE(a.opened_by, '-', ''), '_', '')), 5)))
                else upper(TRIM(REPLACE(REPLACE(a.opened_by, '-', ''), '_', ''))) end = upper(ma.idx)
            left join cockpit.master_agent mb
                on a.opened_by = mb.siebel_id 
        where 1=1
            and DATE_FORMAT(a.opened_time, '%Y%m%d') >= '20251101'
            and DATE_FORMAT(a.opened_time, '%Y%m') = left('{dt_id}',6)
            and DATE_FORMAT(a.opened_time, '%Y%m%d') <= '{dt_id}' 
            and a.source='3Store' 
            and (lower(a.subcat) like '%sim%replacement%' or lower(a.subcat) like '%replacement%sim%')
            and a.status_text='Close'
            and b.msisdn is null
        group by 1, 2, 3, 4, 5
;



-- mtd
-- select
-- 	'{dt_id}' as dt_id,
-- 	'change_card' as kpi_name,
-- 	'agent' as level, 
-- 	agent_id, 
-- 	store_code, 
-- 	'3ID' as brand, 
-- 	count(distinct msisdn) as value
-- from cockpit.tmp_kpi_change_card
-- 	where 1=1
-- 		-- and category='Replacement SIM Card'
-- 		and source_channel in ('SIEBEL', 'CSTOOLS')
-- 		and left(dt_id,6)=left('{dt_id}',6)
-- 		and dt_id<='{dt_id}'
-- group by 1, 2, 3, 4, 5, 6
-- union all
-- select
-- 	'{dt_id}' as dt_id,
-- 	'change_card' as kpi_name,
-- 	'store' as level, 
-- 	null as agent_id, 
-- 	store_code, 
-- 	'3ID' as brand, 
-- 	count(distinct msisdn) as value
-- from cockpit.tmp_kpi_change_card
-- 	where 1=1
-- 		-- and category='Replacement SIM Card'
-- 		and source_channel in ('SIEBEL', 'CSTOOLS')
-- 		and left(dt_id,6)=left('{dt_id}',6)
-- 		and dt_id<='{dt_id}'
-- group by 1, 2, 3, 4, 5, 6
-- union all
-- select
-- 	'{dt_id}' as dt_id,
-- 	'change_card_dvm' as kpi_name,
-- 	source_channel as level, 
-- 	agent_id as agent_id, 
-- 	store_code, 
-- 	'3ID' as brand, 
-- 	count(distinct msisdn) as value
-- from cockpit.tmp_kpi_change_card
-- 	where source_channel not in ('SIEBEL', 'CSTOOLS')
-- 		and left(dt_id,6)=left('{dt_id}',6)
-- 		and dt_id<='{dt_id}'
-- group by 1, 2, 3, 4, 5, 6;

-- -- dly
-- select
-- 	dt_id,
-- 	'change_card' as kpi_name,
-- 	'agent' as level, 
-- 	agent_id, 
-- 	store_code, 
-- 	'3ID' as brand, 
-- 	count(distinct msisdn) as value
-- from cockpit.tmp_kpi_change_card
-- 	where 1=1
-- 		-- and category='Replacement SIM Card'
-- 		and source_channel in ('SIEBEL', 'CSTOOLS')
-- 		and left(dt_id,6)=left('{dt_id}',6)
-- 		and dt_id<='{dt_id}'
-- group by 1, 2, 3, 4, 5, 6
-- union all
-- select
-- 	dt_id,
-- 	'change_card' as kpi_name,
-- 	'store' as level, 
-- 	null as agent_id, 
-- 	store_code, 
-- 	'3ID' as brand, 
-- 	count(distinct msisdn) as value
-- from cockpit.tmp_kpi_change_card
-- 	where 1=1
-- 		-- and category='Replacement SIM Card'
-- 		and source_channel in ('SIEBEL', 'CSTOOLS')
-- 		and left(dt_id,6)=left('{dt_id}',6)
-- 		and dt_id<='{dt_id}'
-- group by 1, 2, 3, 4, 5, 6 
-- union all
-- select
-- 	dt_id,
-- 	'change_card_dvm' as kpi_name,
-- 	source_channel as level, 
-- 	agent_id as agent_id, 
-- 	store_code, 
-- 	'3ID' as brand, 
-- 	count(distinct msisdn) as value
-- from cockpit.tmp_kpi_change_card
-- 	where  source_channel not in ('SIEBEL', 'CSTOOLS')
-- 		and left(dt_id,6)=left('{dt_id}',6)
-- 		and dt_id<='{dt_id}'
-- group by 1, 2, 3, 4, 5, 6;

-- select * from cockpit.tmp_kpi_change_card
-- where left(dt_id,6)=left('{dt_id}',6)
-- 		and dt_id<='{dt_id}';