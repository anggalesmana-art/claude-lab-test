-- 01-3ID AHT
SELECT date_format(DateTimeCustQue, "%Y-%m-%d") as period, StoreName, 
COUNT(1) transaction 
, SUM(WaitingTime) WaitingTime, SUM(HandlingTime) HandlingTime 
, SUM(WaitingTime)/count(1) AWT
, SUM(HandlingTime)/count(1) AHT
FROM cockpit.raw_qms_detil
where date_format(DateTimeCustQue, "%Y%m") = left({dt_id},6) and date_format(DateTimeCustQue, "%Y%m%d") <= {dt_id}
group by 1,2; 

-- 02-3ID CSAT 3Store In House
select  period, created_by,  
survey_dealercode,
store_name,
count(1) as respond,
sum(case when answer >= 4 then 1 else 0 end) as happy,
sum(case when answer >= 4 then 1 else 0 end)/count(1) as CSAT
from (
SELECT
substring(survey_open_date,1,10) as period,
created_by, 
csat_survey.survey_ref_no,
survey_dealercode,
ms.name as store_name,
MIN(sa.answer) as answer
FROM cockpit.csat_survey 
inner join cockpit.survey_answer sa on sa.reff_no = csat_survey.survey_ref_no
inner join cockpit.survey_question sq on sq.id = sa.question_id and sq.survey_id = sa.survey_id and sq.id in (23,24,25)
inner join cockpit.survey_template st on st.id = sq.survey_id and st.id = 2
left join cockpit.master_stores as ms on ms.code = survey_dealercode
where survey_status = 200
and sq.question_type in ('rating-thumb','rating-star')
and left(replace(substring(survey_open_date, 1, 10),'-',''),6) = left({dt_id},6) and left(replace(substring(survey_open_date, 1, 10),'-',''),8)<={dt_id}
group by 1,2,3,4,5) A
group by 1,2,3,4; 

-- 03-3ID DVM Interaction
select substring(date_trx,1,10) as period
, terminal_code
, case when product_code IN ('THREE_CHANGE_CARD','THREE_REGPRABAYAR','THREE_SIMCARD4G') then 'Service Request' else 'Transaction' end as intent
, product_code
, case when product_code IN ('THREE_CHANGE_CARD','THREE_REGPRABAYAR','THREE_SIMCARD4G') then 'Non Transaction' else 'Transaction' end as intent_type
, product_name
, count(trxid) as TotalTrx
from  cockpit_archieve.raw_3db_trx
WHERE result = 'Success'
and left(replace(substring(date_trx, 1, 10),'-',''),6) = left({dt_id},6) and left(replace(substring(date_trx, 1, 10),'-',''),8)<={dt_id}
group by 1,2,3,4,5,6; 

-- 04-3ID Interaction (3Store, 3Kiosk, 3Kiosk Online)
select substring(opened_time, 1, 10) period
, source source_data
, opened_by 
, intent
, usecase
, case when intent = 'Transaction' then 'Transaction' else 'Non Transaction' end as intent_type
, case 
	when intent = 'Complaint' and (ref_id is null or ref_id ='') then 'Complaint FCR' 
  	when intent = 'Complaint' and (ref_id is not null or ref_id <>'') then 'Complaint Escalated' 
  	else "" 
  end as FCR_Flag
, count(*) TotalTrx
from cockpit_archieve.cstools_raw_tickets
where left(replace(substring(opened_time, 1, 10),'-',''),6) = left({dt_id},6) and left(replace(substring(opened_time, 1, 10),'-',''),8)<={dt_id}
and source in ('3Store','3Kiosk','3Kiosk Online')
group by 1,2,3,4,5,6,7; 

-- 05-3ID Revenue (union 3 table)
SELECT DATE_FORMAT(buv.salesdate, "%Y-%m-%d") AS period
		, 'POSS' AS buv_source
		, AgentName AS agent_id
		, buv.DealerCode AS dealer_code
		, buv.ProductName AS product_name
		, SUM(buv.Quantity) AS quantity
		, SUM(COALESCE(buv.CustomerPrice, 0))/SUM(buv.Quantity) AS price
		, SUM(COALESCE(buv.TotalAmount, 0)) AS total_amount_inc_ppn
	FROM cockpit.raw_poss buv 
	WHERE buv.TotalAmount > 0
	AND buv.ProductName not like 'SP-PR%' 
    AND DATE_FORMAT(buv.SalesDate, '%Y%m') = left({dt_id},6) and DATE_FORMAT(buv.SalesDate, '%Y%m%d')<={dt_id}
	GROUP BY 1,2,3,4,5
UNION ALL
	SELECT DATE_FORMAT(buv.document_date, "%Y-%m-%d") AS period
		, 'POSTPAID PAYMENT' AS buv_source
		-- , agent_id AS agent_id 
        , created_by AS agent_id
		, dealercode AS dealer_code
		, 'Postpaid' AS product_name
		, count(document_no) AS quantity
		, SUM(COALESCE(buv.amount, 0))/count(document_no) AS price
		, SUM(COALESCE(buv.amount, 0)) AS total_amount_inc_ppn
	FROM cockpit.raw_post_payment buv
	WHERE buv.amount > 0
    AND DATE_FORMAT(buv.document_date, '%Y%m') = left({dt_id},6) and DATE_FORMAT(buv.document_date, '%Y%m%d')<={dt_id}
	GROUP BY 1,2,3,4,5
UNION ALL
	SELECT substring(T1.date_trx,1,10) as period
	, case 
		when T2.group = '3Store' and product_code not like '%THREE%' then 'DVM 3Store PPOB'
		when T2.group = '3Store' and product_code like '%THREE%' then 'DVM 3Store Product'
		when T2.group <>'3Store' and product_code not like '%THREE%' then 'DVM StandAlone PPOB'
		when T2.group <>'3Store' and product_code like '%THREE%' then 'DVM StandAlone Product'
	  end  buv_source 
	, null AS agent_id
	, trim(T1.terminal_code) as dealer_code
	, T1.product_name as product_name
	, count(*) as quantity
	, sum(price_user)/count(*) as price
	, sum(payment_value) as total_amount_inc_ppn
	FROM cockpit_archieve.raw_3db_trx T1
		left join cockpit_archieve.master_3db_terminal as T2 on T1.terminal_code=T2.code
	Where result = 'success'
	and product_code NOT IN ('THREE_CHANGE_CARD','THREE_REGPRABAYAR','THREE_SIMCARD4G', 'THREE_CHANGE_CARD_O2O', 'Upgrade 4G O2O', 'VALIDITY_KTP')
    and DATE_FORMAT(T1.date_trx, "%Y%m") = left({dt_id},6) and  DATE_FORMAT(T1.date_trx, "%Y%m%d")<={dt_id}
	GROUP BY 1,2,3,4,5; 

-- 06-3ID Traffic Scan QR Buy union Scan QR Info
SELECT DATE_FORMAT(trx_dtm, "%Y-%m-%d") as period
, 'QR Buy' as source
, utm_medium as 'StoreQRBuy'
, count(1) AS quantity
FROM cockpit_archieve.raw_o2o_qrbuy 
where trx_status = 1
 and date_format(trx_dtm, "%Y%m") = left({dt_id},6) and date_format(trx_dtm, "%Y%m%d")<={dt_id}
group by 1,2,3
union all 
SELECT substring(access_at,1,10) as period
, 'QR Info' as source
, location as StoreQR
, count(1)
FROM cockpit_archieve.`raw_o2o_qrlog`
where content not like 'http://bimaplus.tri.co.id/O2O%'
 and date_format(access_at, "%Y%m") = left({dt_id},6) and date_format(access_at, "%Y%m%d")<={dt_id}
group by 1,2,3; 

-- 07-3ID Traffic Visitor Union (Store & DVM)
SELECT 
	substring(DateTimeCustQue,1,10) as period, 
	'Store' Flag, 
	null terminal_code, 
	StoreName, 
	count(*) as quantity
FROM cockpit.raw_qms_detil 
WHERE DATE_FORMAT(DateTimeCustQue, '%Y%m')  = left({dt_id},6) and DATE_FORMAT(DateTimeCustQue, '%Y%m%d')<={dt_id}
Group by 1,2,3,4
union all 
SELECT substring(date_trx,1,10) as period
, 'DVM' Flag
, terminal_code
, terminal_name
, count(trxid) as quantity
FROM cockpit_archieve.raw_3db_trx
Where result = 'success' and state='Done'
 and DATE_FORMAT(date_trx, '%Y%m')  = left({dt_id},6) and DATE_FORMAT(date_trx, '%Y%m%d')<={dt_id}
GROUP BY 1,2,3,4; 

-- 8. SR TT Agent MTD Level 
select 
	mtd.dt_id,  
	mpsr.circle, 
	mpsr.region,  
	mpsr.store_name, 
	'3ID' as brand,
	mtd.store_code, 
	mtd.agent_id, 
	mtd.kpi_name,
	coalesce(mtd.value,0) as mtd_value, 
	coalesce(lmtd.value,0) as lmtd_value
from (
	select  
	'{dt_id}' as dt_id,
	tt.DealerCode as store_code, 
	tt.CreatedBy as agent_id, 
	'sr_total' as kpi_name,  
	count(distinct tt.TicketId) as value
	from cenos_dtmart.tt_siebel_tmp tt 
	where DATE_FORMAT(tt.Closed, "%Y%m") = left('{dt_id}',6) and  DATE_FORMAT(tt.Closed, "%Y%m%d")<='{dt_id}'
	and tt.Intent='Complaint' 
	and tt.source = 'WIC'  
	and tt.Status = 'Closed'
	and tt.createdby NOT IN ('kanda', 'edwinw', 'ades')
	and LTRIM(RTRIM(tt.msisdn)) NOT IN ('62895415499177', '628979169620')
	and tt.usecase <> 'CEM Usage'
	and year(tt.DueDate) > 1970
	group by 1, 2, 3 
	union all
	select  
	'{dt_id}' as dt_id,
	tt.DealerCode as store_code, 
	tt.CreatedBy as agent_id, 
	'sr_done' as kpi_name,  
	count(distinct case when tt.Closed <= tt.DueDate then tt.TicketId end) as value
	from cenos_dtmart.tt_siebel_tmp tt 
	where DATE_FORMAT(tt.Closed, "%Y%m") = left('{dt_id}',6) and  DATE_FORMAT(tt.Closed, "%Y%m%d")<='{dt_id}'
	and tt.Intent='Complaint' 
	and tt.source = 'WIC'  
	and tt.Status = 'Closed'
	and tt.createdby NOT IN ('kanda', 'edwinw', 'ades')
	and LTRIM(RTRIM(tt.msisdn)) NOT IN ('62895415499177', '628979169620')
	and tt.usecase <> 'CEM Usage'
	and year(tt.DueDate) > 1970
	group by 1, 2, 3
	union all 
	select  
	'{dt_id}' as dt_id,
	tt.DealerCode as store_code, 
	tt.CreatedBy as agent_id, 
	'sr_tt' as kpi_name,  
	cast(count(distinct case when tt.Closed <= tt.DueDate then tt.TicketId end)/count(distinct tt.TicketId) as decimal) as value
	from cenos_dtmart.tt_siebel_tmp tt 
	where DATE_FORMAT(tt.Closed, "%Y%m") = left('{dt_id}',6) and  DATE_FORMAT(tt.Closed, "%Y%m%d")<='{dt_id}'
	and tt.Intent='Complaint' 
	and tt.source = 'WIC'  
	and tt.Status = 'Closed'
	and tt.createdby NOT IN ('kanda', 'edwinw', 'ades')
	and LTRIM(RTRIM(tt.msisdn)) NOT IN ('62895415499177', '628979169620')
	and tt.usecase <> 'CEM Usage'
	and year(tt.DueDate) > 1970
	group by 1, 2, 3
) as mtd	 
left join (
	select  
	'{dt_id}' as dt_id,
	tt.DealerCode as store_code, 
	tt.CreatedBy as agent_id, 
	'sr_total' as kpi_name,  
	count(distinct tt.TicketId) as value
	from cenos_dtmart.tt_siebel_tmp tt 
	where DATE_FORMAT(tt.Closed, "%Y%m") = DATE_FORMAT(DATE_SUB(STR_TO_DATE('{dt_id}', '%Y%m%d'), INTERVAL 1 MONTH), '%Y%m') and  DATE_FORMAT(tt.Closed, "%Y%m%d")<=DATE_FORMAT(DATE_SUB(STR_TO_DATE('{dt_id}', '%Y%m%d'), INTERVAL 1 MONTH), '%Y%m%d')
	and tt.Intent='Complaint' 
	and tt.source = 'WIC'  
	and tt.Status = 'Closed'
	and tt.createdby NOT IN ('kanda', 'edwinw', 'ades')
	and LTRIM(RTRIM(tt.msisdn)) NOT IN ('62895415499177', '628979169620')
	and tt.usecase <> 'CEM Usage'
	and year(tt.DueDate) > 1970
	group by 1, 2, 3 
	union all
	select  
	'{dt_id}' as dt_id,
	tt.DealerCode as store_code, 
	tt.CreatedBy as agent_id, 
	'sr_done' as kpi_name,  
	count(distinct case when tt.Closed <= tt.DueDate then tt.TicketId end) as value
	from cenos_dtmart.tt_siebel_tmp tt 
	where DATE_FORMAT(tt.Closed, "%Y%m") = DATE_FORMAT(DATE_SUB(STR_TO_DATE('{dt_id}', '%Y%m%d'), INTERVAL 1 MONTH), '%Y%m') and  DATE_FORMAT(tt.Closed, "%Y%m%d")<=DATE_FORMAT(DATE_SUB(STR_TO_DATE('{dt_id}', '%Y%m%d'), INTERVAL 1 MONTH), '%Y%m%d')
	and tt.Intent='Complaint' 
	and tt.source = 'WIC'  
	and tt.Status = 'Closed'
	and tt.createdby NOT IN ('kanda', 'edwinw', 'ades')
	and LTRIM(RTRIM(tt.msisdn)) NOT IN ('62895415499177', '628979169620')
	and tt.usecase <> 'CEM Usage'
	and year(tt.DueDate) > 1970
	group by 1, 2, 3
	union all 
	select  
	'{dt_id}' as dt_id,
	tt.DealerCode as store_code, 
	tt.CreatedBy as agent_id, 
	'sr_tt' as kpi_name,  
	cast(count(distinct case when tt.Closed <= tt.DueDate then tt.TicketId end)/count(distinct tt.TicketId) as decimal) as value
	from cenos_dtmart.tt_siebel_tmp tt 
	where DATE_FORMAT(tt.Closed, "%Y%m") = DATE_FORMAT(DATE_SUB(STR_TO_DATE('{dt_id}', '%Y%m%d'), INTERVAL 1 MONTH), '%Y%m') and  DATE_FORMAT(tt.Closed, "%Y%m%d")<=DATE_FORMAT(DATE_SUB(STR_TO_DATE('{dt_id}', '%Y%m%d'), INTERVAL 1 MONTH), '%Y%m%d')
	and tt.Intent='Complaint' 
	and tt.source = 'WIC'  
	and tt.Status = 'Closed'
	and tt.createdby NOT IN ('kanda', 'edwinw', 'ades')
	and LTRIM(RTRIM(tt.msisdn)) NOT IN ('62895415499177', '628979169620')
	and tt.usecase <> 'CEM Usage'
	and year(tt.DueDate) > 1970
	group by 1, 2, 3
) as lmtd 
on mtd.dt_id=lmtd.dt_id and mtd.store_code=lmtd.store_code and mtd.agent_id=lmtd.agent_id and mtd.kpi_name=lmtd.kpi_name 
left join cockpit.master_pbi_store_ref mpsr 
on mtd.store_code = mpsr.store_code; 

-- 09.CSAT 3ID NEW
select 
cs.mth_id, 
cs.dt_id as dt_id, 
cs.agent_id, 
cs.store_code, 
case when lower(pbi_ref.store_name) like '%kiosk%' then '3Kiosk'
else '3Store' end channel, 
pbi_ref.store_name, 
pbi_ref.store_code_distribution as dist_id, 
pbi_ref.circle, 
pbi_ref.region,  
'3ID' as brand, 
count(1) as responden_delivered,
sum(case when answer is not null then 1 else 0 end) as responden_feedback,
sum(case when answer >= 4 then 1 else 0 end) as happy,
cast(sum(case when answer >= 4 then 1 else 0 end)/sum(case when answer is not null then 1 else 0 end) as decimal(10,2)) as csat, 
cast(sum(case when answer is not null then 1 else 0 end)/count(1) as decimal(10,2)) as responden_rate, 
case when cast(sum(case when answer is not null then 1 else 0 end)/count(1) as decimal(10,2))>=0.1 then 'Valid' 
else 'Not Valid' end as responden_rate_status
from (
select
DATE_FORMAT(cs.survey_open_date, '%Y%m') as mth_id, 
DATE_FORMAT(cs.survey_open_date, '%Y%m%d') as dt_id,
cs.survey_ref_no,
cs.created_by as agent_id, 			
coalesce(ma.dealercode ,cs.survey_dealercode, SUBSTRING_INDEX(cs.created_by, '-', 1)) as store_code, 
avg(sa.answer) answer
FROM cockpit.csat_survey cs
left join cockpit.survey_answer sa on sa.reff_no = cs.survey_ref_no and question_id in (23, 24, 25, 36) 
left join cockpit.master_agent ma on (cs.created_by=ma.siebel_id or cs.created_by=ma.qms_id)
where 1=1
and DATE_FORMAT(cs.survey_open_date, '%Y%m') = left('{dt_id}', 6)
and cs.msgStatusText='Delivered' 
group by 1, 2, 3, 4, 5
) as cs 
left join cockpit.master_pbi_store_ref as pbi_ref
on cs.store_code = pbi_ref.store_code 
group by 1, 2, 3, 4, 5, 6, 7, 8, 9, 10;