delete from `data-nationalslsdist-prd-986g`.retail.raw_im3_rev_service as a
where format_date('%Y%m', dt_id)=left('{dt_id}',6) 
-- where dt_id between date(SUBSTR('{dt_id}',1,4) || '-' || SUBSTR('{dt_id}',5,2) || '-01') 
-- 		and PARSE_DATE('%Y%m%d', '{dt_id}')
;

insert into `data-nationalslsdist-prd-986g`.retail.raw_im3_rev_service
SELECT 
	date(a.dt_id) as dt_id,
	format_date('%Y%m%d', a.dt_id) as rev_dt, 
	b.msisdn,
	b.agent_id,
	b.store_code,
	b.change_dt,
	sum(a.rev_30) as rev_service
FROM `data-bi-prd-935c.bi_dm.hg_rgs_all_nogovt_dly` as a
inner join (
		select * from (
				select 
					agent_id,
					store_code,
					msisdn,
					format_date('%Y%m%d',dt_id) as change_dt, 
					row_number() over(partition by msisdn order by dt_id desc, store_code) as idx
				from `data-nationalslsdist-prd-986g`.retail.raw_im3_change_card
				WHERE dt_id BETWEEN
				      DATE_TRUNC(DATE_SUB(PARSE_DATE('%Y%m%d', '{dt_id}'), INTERVAL 2 MONTH), MONTH) 
				  AND PARSE_DATE('%Y%m%d', '{dt_id}')
			) as x where x.idx=1
	) as b
	on a.msisdn=b.msisdn
-- where date(dt_id)between date(SUBSTR('{dt_id}',1,4) || '-' || SUBSTR('{dt_id}',5,2) || '-01') 
-- 	and PARSE_DATE('%Y%m%d', '{dt_id}')
where date(dt_id)=PARSE_DATE('%Y%m%d', '{dt_id}')
group by 1, 2, 3, 4, 5, 6
order by 1;

select 
	'{dt_id}' as dt_id,
	'rev_service' as kpi_name,
	'agent' as level, 
	agent_id,
	store_code,
	'IM3' as brand,
	sum(rev_service) as value
from `data-nationalslsdist-prd-986g`.retail.raw_im3_rev_service as a 
where dt_id between date(SUBSTR('{dt_id}',1,4) || '-' || SUBSTR('{dt_id}',5,2) || '-01') 
		and PARSE_DATE('%Y%m%d', '{dt_id}')
group by 1, 2, 3, 4, 5, 6
union all
select 
	'{dt_id}' as dt_id,
	'rev_service' as kpi_name,
	'store' as level, 
	cast(null as string) as agent_id,
	store_code,
	'IM3' as brand,
	sum(rev_service) as value
from `data-nationalslsdist-prd-986g`.retail.raw_im3_rev_service as a 
where dt_id between date(SUBSTR('{dt_id}',1,4) || '-' || SUBSTR('{dt_id}',5,2) || '-01') 
		and PARSE_DATE('%Y%m%d', '{dt_id}')
group by 1, 2, 3, 4, 5, 6;

select 
	format_date('%Y%m%d', dt_id) as dt_id,
	'rev_service' as kpi_name,
	'agent' as level, 
	agent_id,
	store_code,
	'IM3' as brand,
	sum(rev_service) as value
from `data-nationalslsdist-prd-986g`.retail.raw_im3_rev_service as a 
where dt_id between date(SUBSTR('{dt_id}',1,4) || '-' || SUBSTR('{dt_id}',5,2) || '-01') 
		and PARSE_DATE('%Y%m%d', '{dt_id}')
group by 1, 2, 3, 4, 5, 6
union all
select 
	format_date('%Y%m%d', dt_id) as dt_id,
	'rev_service' as kpi_name,
	'store' as level, 
	cast(null as string) as agent_id,
	store_code,
	'IM3' as brand,
	sum(rev_service) as value
from `data-nationalslsdist-prd-986g`.retail.raw_im3_rev_service as a 
where dt_id between date(SUBSTR('{dt_id}',1,4) || '-' || SUBSTR('{dt_id}',5,2) || '-01') 
		and PARSE_DATE('%Y%m%d', '{dt_id}')
group by 1, 2, 3, 4, 5, 6;