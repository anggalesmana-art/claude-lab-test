-- 0. Delete FCR Store   
delete from cockpit.retail_store_fcr where mth_id = left('{dt_id}',6); 

-- 1. Insert FCR Store 
insert into cockpit.retail_store_fcr
select 
	'INT' as source, 
	left(replace(substring(a.opened_time, 1, 10),'-',''),8) as dt_id, 
	a.intent, 
	a.usecase,   
	a.opened_by as agent_id, 
	upper(b.name) as agent_name,  
	b.dealercode as store_code,
	c.store_name, 
	c.circle, 
	c.region, 
	'3ID' as brand, 
	left(replace(substring(a.opened_time, 1, 10),'-',''),6) as mth_id, 
	count(a.tt_id) as total_trx
FROM cockpit_archieve.cstools_raw_tickets as a 
left join cockpit.master_agent b
	on a.opened_by =b.siebel_id  
left join cockpit.master_pbi_store_ref c 
	on b.dealercode = c.store_code
where left(replace(substring(opened_time, 1, 10),'-',''),6) = left('{dt_id}',6)
	and a.source = '3Store'
	and not (a.intent = 'Complaint' and ( a.escalated_to = 'Tier 2' or a.notes_related like '%1-1%' or a.ref_id like '%1-1%')) 
group by 1, 2, 3, 4, 5, 6, 7, 8, 9, 10, 11, 12 
union all
select  
	'SR' as source, 
	left(replace(substring(a.Opened, 1, 10),'-',''),8) as dt_id, 
	a.Intent as intent, 
	a.UseCase as usecase, 
	a.CreatedBy as agent_id, 
	upper(b.name) as agent_name, 
	a.DealerCode as store_code, 
	c.store_name, 
	c.circle, 
	c.region,  
	'3ID' as brand, 
	left(replace(substring(a.Opened, 1, 10),'-',''),6) as mth_id, 
	count(a.TicketId) as total_trx
from cenos_dtmart.tt_siebel_tmp as a 
	left join cockpit.master_agent b 
		on a.CreatedBy = b.siebel_id 
	left join cockpit.master_pbi_store_ref c  
		on a.DealerCode = c.store_code
where left(replace(substring(a.Opened, 1, 10),'-',''),6) = left('{dt_id}',6)
AND Intent = 'Complaint'
AND source = 'WIC'
AND createdby NOT IN ('kanda', 'edwinw', 'ades')
AND LTRIM(RTRIM(msisdn)) NOT IN ('62895415499177', '628979169620')
AND usecase <> 'CEM Usage'
AND year(DueDate) > 1970 
group by 1, 2, 3, 4, 5, 6, 7, 8, 9, 10, 11, 12; 

-- 2. Dump FCR Store
select * from cockpit.retail_store_fcr where mth_id = left('{dt_id}',6); 

-- 3. Dump Agent CSAT 
select 
	cs.mth_id, 
	cs.dt_id as dt_id, 
	cs.agent_id, 
	cs.store_code, 
	cs.channel, 
	pbi_ref.store_name, 
	pbi_ref.store_code_distribution as dist_id, 
	pbi_ref.circle, 
	pbi_ref.region,  
	'3ID' as brand,
	count(1) as respond,
	sum(case when answer >= 4 then 1 else 0 end) as happy,
	cast(sum(case when answer >= 4 then 1 else 0 end)/count(1) as decimal(10,2)) as csat
from (
	select
			DATE_FORMAT(cs.survey_open_date, '%Y%m') as mth_id, 
			DATE_FORMAT(cs.survey_open_date, '%Y%m%d') as dt_id,
			cs.survey_ref_no,
			-- sq.id,
			cs.created_by as agent_id, 			
			coalesce(cs.survey_dealercode, SUBSTRING_INDEX(cs.created_by, '-', 1)) as store_code, 
			case when st.id = 2 then '3Store' 
				when st.id = 101 then '3Kiosk'
				else null end as channel,
			AVG(sa.answer) answer
		FROM cockpit.csat_survey cs
		inner join cockpit.survey_answer sa on sa.reff_no = cs.survey_ref_no
		inner join cockpit.survey_question sq on sq.id = sa.question_id and sq.survey_id = sa.survey_id
		inner join cockpit.survey_template st on st.id = sq.survey_id 
		where cs.survey_status = 200
		and sq.question_type in ('rating-thumb','rating-star')
		and DATE_FORMAT(cs.survey_open_date, '%Y%m') = left('{dt_id}', 6)
		and st.id in (101, 2) 
		and sq.id in (23, 24, 25, 36)
		group by 1,2,3,4,5,6
) as cs 
left join cockpit.master_pbi_store_ref as pbi_ref
	on cs.store_code = pbi_ref.store_code 
group by 1, 2, 3, 4, 5, 6, 7, 8, 9, 10; 

