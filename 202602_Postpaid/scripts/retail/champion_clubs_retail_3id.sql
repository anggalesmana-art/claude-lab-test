-- 3ID
-- 01. Agent Productivity
-- 01.A Droping temproraty table if exist
drop table if exists cockpit.temp_agent_productivity;
-- 01.B Creating temporary table
create table cockpit.temp_agent_productivity as
select
	a.mth_id,
	a.dt_id,
	a.circle,
	a.region,
	a.agent_id,
	a.agent_name,
	a.dealercode,
	a.store_name,
	sum(visitor) as visitor,
	sum(coalesce(b.gross_add,0)) as gross_add, 
	sum(coalesce(b.gross_add,0))/sum(visitor) as conversion_rate, 
	case when sum(coalesce(b.gross_add,0))/sum(visitor)>= 0.1 then 1 else 0 end productive
from (
	select
		DATE_FORMAT(qms.DateTimeCustQue, '%Y%m') as mth_id,
		'{dt_id}' as dt_id,
		qms.AgentName as agent_id,
		upper(ma.name) as agent_name,
		ma.title as agent_title,
		ma.dealercode,
		mr.store_name,
		mr.circle,
		mr.region,
		count(1) as visitor
	FROM cockpit.raw_qms_detil as qms
		left join cockpit.master_agent ma
			on qms.AgentName = ma.siebel_id
		left join cockpit.master_pbi_store_ref mr
			on ma.dealercode = mr.store_code
		WHERE (DATE_FORMAT(qms.DateTimeCustQue, '%Y%m') = left('{dt_id}',6) and DATE_FORMAT(qms.DateTimeCustQue, '%Y%m%d')<='{dt_id}') 
		or (DATE_FORMAT(qms.DateTimeCustQue, '%Y%m') = DATE_FORMAT(DATE_SUB(STR_TO_DATE('{dt_id}', '%Y%m%d'), INTERVAL 1 MONTH), '%Y%m') 
	    	and DATE_FORMAT(qms.DateTimeCustQue, '%Y%m%d')<=DATE_FORMAT(DATE_SUB(STR_TO_DATE('{dt_id}', '%Y%m%d'), INTERVAL 1 MONTH), '%Y%m%d'))		
	group by 1, 2, 3, 4, 5, 6, 7, 8, 9
) as a
left join (
	select
		DATE_FORMAT(buv.salesdate, "%Y%m") AS mth_id
		, '{dt_id}' as dt_id
		, buv.AgentName AS agent_id
		, upper(ma.name) as agent_name
		, ma.title as agent_title
		, buv.DealerCode AS dealer_code
		, mr.store_name as store_name
		, mr.circle
		, mr.region
		, SUM(buv.Quantity) AS gross_add
	from cockpit.raw_poss buv
		left join cockpit.master_agent ma
			on buv.AgentName =ma.poss_id
		left join cockpit.master_pbi_store_ref mr
			on buv.DealerCode = mr.store_code
	where (lower(buv.ProductName) like 'sp %'
		or lower(buv.ProductName) like 'perdana %'
		or lower(buv.ProductName) like 'elite%')
		and buv.ItemCode not like 'SP-PR%'
		and buv.ItemCode not like 'SP-RPLC%'
		and ((DATE_FORMAT(buv.SalesDate, '%Y%m') = left('{dt_id}',6) and DATE_FORMAT(buv.SalesDate, '%Y%m%d') <= '{dt_id}') 
		or (DATE_FORMAT(buv.SalesDate, '%Y%m') = DATE_FORMAT(DATE_SUB(STR_TO_DATE('{dt_id}', '%Y%m%d'), INTERVAL 1 MONTH), '%Y%m') 
	    	and DATE_FORMAT(buv.SalesDate, '%Y%m%d')<=DATE_FORMAT(DATE_SUB(STR_TO_DATE('{dt_id}', '%Y%m%d'), INTERVAL 1 MONTH), '%Y%m%d')))
	group by 1, 2, 3, 4, 5, 6, 7, 8, 9
) as b
on a.agent_id=b.agent_id and a.mth_id=b.mth_id
group by 1, 2, 3, 4, 5, 6, 7, 8
;

-- 01.C Deleting existing data
delete from cockpit.retail_champion_club
where kpi_name in ('total_agent_achieve','agent_productivity','total_agent') 
and mth_id=left('{dt_id}',6); 

-- 01.D Inserting new data
insert into cockpit.retail_champion_club
select 
	a.dt_id, 
	a.circle, 
	a.region as region_circle, 
	'3ID' as brand, 
	sum(case when a.mth_id=left('{dt_id}',6) then a.productive else 0 end) as mtd_value, 
	sum(case when a.mth_id=DATE_FORMAT(DATE_SUB(STR_TO_DATE('{dt_id}', '%Y%m%d'), INTERVAL 1 MONTH), '%Y%m') then a.productive else 0 end) as lmtd_value, 
	'total_agent_achieve' as kpi_name, 
	left('{dt_id}',6) as mth_id
from cockpit.temp_agent_productivity as a 
group by 1, 2, 3, 4, 7, 8 
union all 
select 
	'{dt_id}' as dt_id, 
	mpsr.circle, 
	mpsr.region as region_circle, 
	'3ID' as brand, 
	count(distinct ma.siebel_id) as mtd_value, 
	count(distinct ma.siebel_id) as lmtd_value, 
	'total_agent' as kpi_name, 
	left('{dt_id}',6)
from cockpit.master_agent ma  
	left join cockpit.master_pbi_store_ref mpsr 
		on ma.dealercode = mpsr.store_code
where ma.title='AGENT' and ma.status=1 
group by 1, 2, 3, 4, 7, 8
union all 
select 
	a.dt_id, 
	a.circle, 
	a.region_circle, 
	a.brand,
	b.mtd_value/a.mtd_value as mtd_value, 
	b.lmtd_value/a.lmtd_value as lmtd_value, 
	'agent_productivity' as kpi_name, 
	a.mth_id
from (
	select 
		'{dt_id}' as dt_id, 
		mpsr.circle, 
		mpsr.region as region_circle, 
		'3ID' as brand, 
		count(distinct ma.siebel_id) as mtd_value, 
		count(distinct ma.siebel_id) as lmtd_value, 
		'total_agent' as kpi_name, 
		left('{dt_id}',6) mth_id
	from cockpit.master_agent ma  
		left join cockpit.master_pbi_store_ref mpsr 
			on ma.dealercode = mpsr.store_code
	where ma.title='AGENT' and ma.status=1 
	group by 1, 2, 3, 4, 7, 8
) as a 
left join (
	select 
		a.dt_id, 
		a.circle, 
		a.region as region_circle, 
		'3ID' as brand, 
		sum(case when a.mth_id=left('{dt_id}',6) then a.productive else 0 end) as mtd_value, 
		sum(case when a.mth_id=DATE_FORMAT(DATE_SUB(STR_TO_DATE('{dt_id}', '%Y%m%d'), INTERVAL 1 MONTH), '%Y%m') then a.productive else 0 end) as lmtd_value, 
		'total_agent_achieve' as kpi_name, 
		left('{dt_id}',6) as mth_id
	from cockpit.temp_agent_productivity as a 
	group by 1, 2, 3, 4, 7, 8
) as b
on a.region_circle = b.region_circle
;  

-- 02. CSAT 3KIOSK 
-- 02.A Delete existing data 
delete from cockpit.retail_champion_club 
where kpi_name in ('csat_3kiosk_cnt','csat_3kiosk_ach','3kiosk_cnt') 
and mth_id=left('{dt_id}',6); 
-- 02.B Inserting new data 
insert into cockpit.retail_champion_club 
select 
	'{dt_id}' as dt_id,
	x.circle, 
	x.region_circle, 
	x.brand, 
	count(distinct case when x.csat>=0.99 and x.responden_rate>=0.1 and x.mth_id=left('{dt_id}', 6) then x.store_code end) as mtd_value, 
	count(distinct case when x.csat>=0.99 and x.responden_rate>=0.1 and x.mth_id=DATE_FORMAT(DATE_SUB(STR_TO_DATE('{dt_id}', '%Y%m%d'), INTERVAL 1 MONTH), '%Y%m') then x.store_code end) as lmtd_value, 
	'csat_3kiosk_cnt' as kpi_name, 
	left('{dt_id}', 6) as mth_id
from (
	select 
		a.mth_id, 
		a.circle, 
		a.region as region_circle, 
		a.channel, 
		a.store_code, 
		a.store_name, 
		a.brand, 
		sum(a.responden_delivered) as responden_delivered, 
		sum(a.responden_feedback) as responden_feedback, 
		sum(a.happy) as happy, 
		sum(a.happy)/nullif(sum(a.responden_feedback),0) as csat, 
		sum(a.responden_feedback)/nullif(sum(a.responden_feedback),0) as responden_rate
	from cockpit.kpi_agent_csat as a
		where 1=1 
			and a.circle is not null 
			and ((a.mth_id=left('{dt_id}', 6) and a.dt_id<='{dt_id}') 
				or (a.mth_id=DATE_FORMAT(DATE_SUB(STR_TO_DATE('{dt_id}', '%Y%m%d'), INTERVAL 1 MONTH), '%Y%m') and a.dt_id<=DATE_FORMAT(DATE_SUB(STR_TO_DATE('{dt_id}', '%Y%m%d'), INTERVAL 1 MONTH), '%Y%m%d'))) 
	group by 1, 2, 3, 4, 5, 6, 7
) as x 
	where lower(x.channel) like '%kiosk%'
group by 1, 2, 3, 4, 7, 8
union all
select  
	'{dt_id}' as dt_id, 
	b.circle, 
	b.region as region_circle, 
	'3ID' as brand, 
	count(distinct b.sdp_code) as mtd_value, 
	count(distinct b.sdp_code) as lmtd_value, 
	'3kiosk_cnt' as kpi_name, 
	left('{dt_id}', 6) as mth_id
from cockpit.rtl_sce_sdp as b
where b.status='Live Service' 
group by 1, 2, 3, 4, 7, 8
union all  
select  
	b.dt_id, 
	b.circle, 
	b.region_circle, 
	'3ID' as brand, 
	case 
        when nullif(b.mtd_value, 0) is null then 0 
        when a.mtd_value/nullif(b.mtd_value, 0) > 1 then 1 
        else a.mtd_value/nullif(b.mtd_value, 0) 
        end as mtd_values,
    case 
        when nullif(b.lmtd_value, 0) is null then 0 
        when a.lmtd_value/nullif(b.lmtd_value, 0) > 1 then 1 
        else a.lmtd_value/nullif(b.lmtd_value, 0) 
        end as lmtd_values,
	'csat_3kiosk_ach' as kpi_name, 
	b.mth_id
from (
	select 
		'{dt_id}' as dt_id,
		x.circle, 
		x.region_circle, 
		x.brand, 
		count(distinct case when x.csat>=0.99 and x.responden_rate>=0.1 and x.mth_id=left('{dt_id}', 6) then x.store_code end) as mtd_value, 
		count(distinct case when x.csat>=0.99 and x.responden_rate>=0.1 and x.mth_id=DATE_FORMAT(DATE_SUB(STR_TO_DATE('{dt_id}', '%Y%m%d'), INTERVAL 1 MONTH), '%Y%m') then x.store_code end) as lmtd_value, 
		'csat_3kiosk_cnt' as kpi_name, 
		left('{dt_id}', 6) as mth_id
	from (
		select 
			a.mth_id, 
			a.circle, 
			a.region as region_circle, 
			a.channel, 
			a.store_code, 
			a.store_name, 
			a.brand, 
			sum(a.responden_delivered) as responden_delivered, 
			sum(a.responden_feedback) as responden_feedback, 
			sum(a.happy) as happy, 
			sum(a.happy)/nullif(sum(a.responden_feedback),0) as csat, 
			sum(a.responden_feedback)/nullif(sum(a.responden_feedback),0) as responden_rate
		from cockpit.kpi_agent_csat as a
			where 1=1 
				and a.circle is not null 
				and ((a.mth_id=left('{dt_id}', 6) and a.dt_id<='{dt_id}') 
					or (a.mth_id=DATE_FORMAT(DATE_SUB(STR_TO_DATE('{dt_id}', '%Y%m%d'), INTERVAL 1 MONTH), '%Y%m') and a.dt_id<=DATE_FORMAT(DATE_SUB(STR_TO_DATE('{dt_id}', '%Y%m%d'), INTERVAL 1 MONTH), '%Y%m%d'))) 
		group by 1, 2, 3, 4, 5, 6, 7
	) as x 
		where lower(x.channel) like '%kiosk%'
	group by 1, 2, 3, 4, 7, 8
) as a 
right join (
	select  
		'{dt_id}' as dt_id, 
		b.circle, 
		b.region as region_circle, 
		'3ID' as brand, 
		count(distinct b.sdp_code) as mtd_value, 
		count(distinct b.sdp_code) as lmtd_value, 
		'3kiosk_cnt' as kpi_name, 
		left('{dt_id}', 6) as mth_id
	from cockpit.rtl_sce_sdp as b
	where b.status='Live Service' 
	group by 1, 2, 3, 4, 7, 8
) as b on b.region_circle=a.region_circle
;   

-- 03.CSAT 3STORE
-- 03.A Deleteing existing data
delete from cockpit.retail_champion_club
where kpi_name in ('csat_3store_cnt','csat_3store_ach','store_cnt') 
and mth_id=left('{dt_id}',6); 
-- 03.B Inserting new data 
insert into cockpit.retail_champion_club 
select 
	'{dt_id}' as dt_id,
	x.circle, 
	x.region_circle, 
	x.brand, 
	count(distinct case when x.csat>=0.99 and x.responden_rate>=0.1 and x.mth_id=left('{dt_id}', 6) then x.store_code end) as mtd_value, 
	count(distinct case when x.csat>=0.99 and x.responden_rate>=0.1 and x.mth_id=DATE_FORMAT(DATE_SUB(STR_TO_DATE('{dt_id}', '%Y%m%d'), INTERVAL 1 MONTH), '%Y%m') then x.store_code end) as lmtd_value, 
	'csat_3store_cnt' as kpi_name, 
	left('{dt_id}', 6) as mth_id
from (
	select 
		a.mth_id, 
		a.circle, 
		a.region as region_circle, 
		a.channel, 
		a.store_code, 
		a.store_name, 
		a.brand, 
		sum(a.responden_delivered) as responden_delivered, 
		sum(a.responden_feedback) as responden_feedback, 
		sum(a.happy) as happy, 
		sum(a.happy)/nullif(sum(a.responden_feedback),0) as csat, 
		sum(a.responden_feedback)/nullif(sum(a.responden_feedback),0) as responden_rate
	from cockpit.kpi_agent_csat as a
		where 1=1 
			and a.circle is not null 
			and ((a.mth_id=left('{dt_id}', 6) and a.dt_id<='{dt_id}') 
				or (a.mth_id=DATE_FORMAT(DATE_SUB(STR_TO_DATE('{dt_id}', '%Y%m%d'), INTERVAL 1 MONTH), '%Y%m') and a.dt_id<=DATE_FORMAT(DATE_SUB(STR_TO_DATE('{dt_id}', '%Y%m%d'), INTERVAL 1 MONTH), '%Y%m%d'))) 
	group by 1, 2, 3, 4, 5, 6, 7
) as x 
	where lower(x.channel) not like '%kiosk%'
group by 1, 2, 3, 4, 7, 8
union all
select 
	'{dt_id}' as dt_id, 
	b.circle, 
	b.region as region_circle, 
	'3ID' as brand, 
	count(distinct b.store_code) as mtd_value, 
	count(distinct b.store_code) as lmtd_value, 
	'store_cnt' as kpi_name, 
	left('{dt_id}', 6) as mth_id
from cockpit.master_pbi_store_ref as b 
	where b.channel_type ='Own 3Store'
group by 1, 2, 3, 4, 7, 8
union all  
select  
	b.dt_id, 
	b.circle, 
	b.region_circle, 
	'3ID' as brand, 
	a.mtd_value/nullif(b.mtd_value,0) as mtd_values, 
	a.lmtd_value/nullif(b.lmtd_value,0) as lmtd_values,
	'csat_3store_ach' as kpi_name, 
	b.mth_id
from (
	select 
		'{dt_id}' as dt_id,
		x.circle, 
		x.region_circle, 
		x.brand, 
		count(distinct case when x.csat>=0.99 and x.responden_rate>=0.1 and x.mth_id=left('{dt_id}', 6) then x.store_code end) as mtd_value, 
		count(distinct case when x.csat>=0.99 and x.responden_rate>=0.1 and x.mth_id=DATE_FORMAT(DATE_SUB(STR_TO_DATE('{dt_id}', '%Y%m%d'), INTERVAL 1 MONTH), '%Y%m') then x.store_code end) as lmtd_value, 
		'csat_3store_cnt' as kpi_name, 
		left('{dt_id}', 6) as mth_id
	from (
		select 
			a.mth_id, 
			a.circle, 
			a.region as region_circle, 
			a.channel, 
			a.store_code, 
			a.store_name, 
			a.brand, 
			sum(a.responden_delivered) as responden_delivered, 
			sum(a.responden_feedback) as responden_feedback, 
			sum(a.happy) as happy, 
			sum(a.happy)/nullif(sum(a.responden_feedback),0) as csat, 
			sum(a.responden_feedback)/nullif(sum(a.responden_feedback),0) as responden_rate
		from cockpit.kpi_agent_csat as a
			where 1=1 
				and a.circle is not null 
				and ((a.mth_id=left('{dt_id}', 6) and a.dt_id<='{dt_id}') 
					or (a.mth_id=DATE_FORMAT(DATE_SUB(STR_TO_DATE('{dt_id}', '%Y%m%d'), INTERVAL 1 MONTH), '%Y%m') and a.dt_id<=DATE_FORMAT(DATE_SUB(STR_TO_DATE('{dt_id}', '%Y%m%d'), INTERVAL 1 MONTH), '%Y%m%d'))) 
		group by 1, 2, 3, 4, 5, 6, 7
	) as x 
		where lower(x.channel) not like '%kiosk%'
	group by 1, 2, 3, 4, 7, 8
) as a 
right join (
	select 
		'{dt_id}' as dt_id, 
		b.circle, 
		b.region as region_circle, 
		'3ID' as brand, 
		count(distinct b.store_code) as mtd_value, 
		count(distinct b.store_code) as lmtd_value, 
		'store_cnt' as kpi_name, 
		left('{dt_id}', 6) as mth_id
	from cockpit.master_pbi_store_ref as b 
		where b.channel_type ='Own 3Store'
	group by 1, 2, 3, 4, 7, 8
) as b on b.region_circle=a.region_circle
;  

-- 04. Myshop Score 3Store 
-- 04.A Deleteing existing data
delete from cockpit.retail_champion_club 
where kpi_name in ('myshopp_score_cnt','myshopp_score_ach') 
and mth_id=left('{dt_id}',6);
-- 04.B Inserting new data
insert into cockpit.retail_champion_club
select 
	'{dt_id}' as dt_id, 
	mpsr.circle,
	mpsr.region as region_circle, 
	'3ID' as brand, 
	count(distinct case when cast(ms.myshopp_score as decimal)>=90 and ms.periode=DATE_FORMAT(DATE_SUB(STR_TO_DATE('{dt_id}', '%Y%m%d'), INTERVAL 1 MONTH), '%Y%m') then ms.store_code end) mtd_value,
	count(distinct case when cast(ms.myshopp_score as decimal)>=90 and ms.periode=DATE_FORMAT(DATE_SUB(STR_TO_DATE('{dt_id}', '%Y%m%d'), INTERVAL 2 MONTH), '%Y%m') then ms.store_code end) lmtd_value, 
	'myshopp_score_cnt' as kpi_name, 
	left('{dt_id}', 6) as mth_id
from cockpit.myshopp_score ms
	left join cockpit.master_pbi_store_ref mpsr  
		on ms.store_code=mpsr.store_code 
where (ms.periode=DATE_FORMAT(DATE_SUB(STR_TO_DATE('{dt_id}', '%Y%m%d'), INTERVAL 1 MONTH), '%Y%m') or ms.periode=DATE_FORMAT(DATE_SUB(STR_TO_DATE('{dt_id}', '%Y%m%d'), INTERVAL 2 MONTH), '%Y%m')) 
	and mpsr.channel_type ='Own 3Store'
group by 1, 2, 3, 4, 7, 8 
union all   
select  
	b.dt_id, 
	b.circle, 
	b.region_circle, 
	'3ID' as brand, 
	a.mtd_value/b.mtd_value as mtd_values, 
	a.lmtd_value/b.lmtd_value as lmtd_values,
	'myshopp_score_ach' as kpi_name, 
	b.mth_id
from (
	select 
		'{dt_id}' as dt_id, 
		mpsr.circle,
		mpsr.region as region_circle, 
		'3ID' as brand, 
		count(distinct case when cast(ms.myshopp_score as decimal)>=90 and ms.periode=DATE_FORMAT(DATE_SUB(STR_TO_DATE('{dt_id}', '%Y%m%d'), INTERVAL 1 MONTH), '%Y%m') then ms.store_code end) mtd_value,
		count(distinct case when cast(ms.myshopp_score as decimal)>=90 and ms.periode=DATE_FORMAT(DATE_SUB(STR_TO_DATE('{dt_id}', '%Y%m%d'), INTERVAL 2 MONTH), '%Y%m') then ms.store_code end) lmtd_value, 
		'myshopp_score_cnt' as kpi_name, 
		left('{dt_id}', 6) as mth_id
	from cockpit.myshopp_score ms
		left join cockpit.master_pbi_store_ref mpsr  
			on ms.store_code=mpsr.store_code 
	where (ms.periode=DATE_FORMAT(DATE_SUB(STR_TO_DATE('{dt_id}', '%Y%m%d'), INTERVAL 1 MONTH), '%Y%m') or ms.periode=DATE_FORMAT(DATE_SUB(STR_TO_DATE('{dt_id}', '%Y%m%d'), INTERVAL 2 MONTH), '%Y%m')) 
		and mpsr.channel_type ='Own 3Store'
	group by 1, 2, 3, 4, 7, 8 
) as a 
right join (
	select 
		'{dt_id}' as dt_id, 
		b.circle, 
		b.region as region_circle, 
		'3ID' as brand, 
		count(distinct b.store_code) as mtd_value, 
		count(distinct b.store_code) as lmtd_value, 
		'store_cnt' as kpi_name, 
		left('{dt_id}', 6) as mth_id
	from cockpit.master_pbi_store_ref as b 
		where b.channel_type ='Own 3Store'
	group by 1, 2, 3, 4, 7, 8
) as b on b.region_circle=a.region_circle
; 

-- 05. Store Productivity and Store revenue 
-- 05.A Deleteing existing data
delete from cockpit.retail_champion_club 
where kpi_name in ('store_prod_rev_cnt',
    'store_prod_rev_ach',
    'store_prod_rev_tgt',
    'store_rev',
    'store_rev_ach',
    'store_rev_tgt')
and mth_id=left('{dt_id}',6);
