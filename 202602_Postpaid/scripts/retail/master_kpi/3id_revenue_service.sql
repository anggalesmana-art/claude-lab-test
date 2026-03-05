delete from `data-nationalslsdist-prd-986g`.retail.raw_3id_rev_service
where left(rev_dt,6)=left('{dt_id}',6);

insert into `data-nationalslsdist-prd-986g`.retail.raw_3id_rev_service
SELECT 
	a.trx_dt_sk_id as dt_id,
	format_date('%Y%m%d', a.trx_dt_sk_id) as rev_dt, 
	c.msisdn,
	c.agent_id,
	c.store_code,
	c.source_channel,
	c.change_dt,
	sum(revenue) as rev_service
FROM `data-dtptechm-prd-c7ca.mis.fct_cwn_rev_detail_fnl` as a 
-- FROM `data-dtptechm-prd-c7ca.mis.fct_cwn_rev_detail_fnl_prepaid_site` as a 
	left join `data-dtptechm-prd-c7ca.dwh.sbscrptn_attribs` as b
		on a.sbscrptn_ek_id=b.sbscrptn_ek_id and b.rank_ind=1
	inner join (
		select * from (
			select 
				agent_id,
				store_code,
				msisdn,
				source_channel,
				dt_id as change_dt, 
				row_number() over(partition by msisdn order by dt_id desc, store_code) as idx
			from `data-nationalslsdist-prd-986g`.retail.raw_3id_change_card
			WHERE DATE(PARSE_DATE('%Y%m%d', dt_id)) BETWEEN
			      DATE_TRUNC(DATE_SUB(PARSE_DATE('%Y%m%d', '{dt_id}'), INTERVAL 2 MONTH), MONTH) 
			  AND PARSE_DATE('%Y%m%d', '{dt_id}')
		) as x where x.idx=1
	) as c
		on b.sbscrptn_msisdn=c.msisdn
	where date(trx_dt_sk_id) between date(SUBSTR('{dt_id}',1,4) || '-' || SUBSTR('{dt_id}',5,2) || '-01') 
		and PARSE_DATE('%Y%m%d', '{dt_id}')
group by 1, 2, 3, 4, 5, 6, 7;  

select 
	'{dt_id}' as dt_id,
	'rev_service' as kpi_name,
	'agent' as level, 
	agent_id,
	store_code,
	'3ID' as brand,
	sum(rev_service) as value
from `data-nationalslsdist-prd-986g`.retail.raw_3id_rev_service as a 
where dt_id between date(SUBSTR('{dt_id}',1,4) || '-' || SUBSTR('{dt_id}',5,2) || '-01') 
		and PARSE_DATE('%Y%m%d', '{dt_id}')
		and source_channel in ('SIEBEL', 'CSTOOLS', 'ICARE')
group by 1, 2, 3, 4, 5, 6
union all
select 
	'{dt_id}' as dt_id,
	'rev_service' as kpi_name,
	'store' as level, 
	cast(null as string) agent_id,
	store_code,
	'3ID' as brand,
	sum(rev_service) as value
from `data-nationalslsdist-prd-986g`.retail.raw_3id_rev_service as a 
where dt_id between date(SUBSTR('{dt_id}',1,4) || '-' || SUBSTR('{dt_id}',5,2) || '-01') 
		and PARSE_DATE('%Y%m%d', '{dt_id}')
		and source_channel in ('SIEBEL', 'CSTOOLS', 'ICARE')
group by 1, 2, 3, 4, 5, 6
union all
select 
	'{dt_id}' as dt_id,
	'rev_service_dvm' as kpi_name,
	source_channel as level, 
	agent_id agent_id,
	store_code,
	'3ID' as brand,
	sum(rev_service) as value
from `data-nationalslsdist-prd-986g`.retail.raw_3id_rev_service as a 
where dt_id between date(SUBSTR('{dt_id}',1,4) || '-' || SUBSTR('{dt_id}',5,2) || '-01') 
		and PARSE_DATE('%Y%m%d', '{dt_id}')
		and source_channel not in ('SIEBEL', 'CSTOOLS', 'ICARE')
group by 1, 2, 3, 4, 5, 6;


select 
	format_date('%Y%m%d', dt_id) as dt_id,
	'rev_service' as kpi_name,
	'agent' as level, 
	agent_id,
	store_code,
	'3ID' as brand,
	sum(rev_service) as value
from `data-nationalslsdist-prd-986g`.retail.raw_3id_rev_service as a 
where dt_id between date(SUBSTR('{dt_id}',1,4) || '-' || SUBSTR('{dt_id}',5,2) || '-01') 
		and PARSE_DATE('%Y%m%d', '{dt_id}')
		and source_channel in ('SIEBEL', 'CSTOOLS', 'ICARE')
group by 1, 2, 3, 4, 5, 6
union all
select 
	format_date('%Y%m%d', dt_id) as dt_id,
	'rev_service' as kpi_name,
	'store' as level, 
	cast(null as string) agent_id,
	store_code,
	'3ID' as brand,
	sum(rev_service) as value
from `data-nationalslsdist-prd-986g`.retail.raw_3id_rev_service as a 
where dt_id between date(SUBSTR('{dt_id}',1,4) || '-' || SUBSTR('{dt_id}',5,2) || '-01') 
		and PARSE_DATE('%Y%m%d', '{dt_id}')
		and source_channel in ('SIEBEL', 'CSTOOLS', 'ICARE')
group by 1, 2, 3, 4, 5, 6
union all
select 
	format_date('%Y%m%d', dt_id) as dt_id,
	'rev_service_dvm' as kpi_name,
	source_channel as level, 
	agent_id agent_id,
	store_code,
	'3ID' as brand,
	sum(rev_service) as value
from `data-nationalslsdist-prd-986g`.retail.raw_3id_rev_service as a 
where dt_id between date(SUBSTR('{dt_id}',1,4) || '-' || SUBSTR('{dt_id}',5,2) || '-01') 
		and PARSE_DATE('%Y%m%d', '{dt_id}')
		and source_channel not in ('SIEBEL', 'CSTOOLS', 'ICARE')
group by 1, 2, 3, 4, 5, 6;