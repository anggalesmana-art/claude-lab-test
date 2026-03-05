create or replace table `data-nationalslsdist-prd-986g`.retail.tmp_kpi_trx as
with siebel_data as
(
    select
	    distinct
	    format_date('%Y%m%d',a.dt_id) as dt_id,
	    REGEXP_EXTRACT(a.creator_location, r'^(.*?)-') AS store_code,
	    creator_login as agent_id,
	    -- creator_name,
	    count(distinct a.msisdn) as interactions
    from `data-dtp-prd-aa1a.stg.stg_siebel_dly_intrctn` as a
    where activity_type IN ('Walk In', 'Appointment')
	    and date(a.dt_id) between date(SUBSTR('{dt_id}',1,4) || '-' || SUBSTR('{dt_id}',5,2) || '-01') 
	    and PARSE_DATE('%Y%m%d', '{dt_id}')
	    and a.status='Closed'
	    -- and format_date('%Y%m',a.dt_id)=left('{dt_id}',6)
    group by 1, 2, 3
)
,ipos_data as
(
    select
        distinct
        format_date('%Y%m%d',PARSE_TIMESTAMP('%d/%m/%Y %H:%M:%S', a.transaction_date)) as dt_id,
        organization_ref_code as store_code,
        a.username as agent_id,
        -- concat(a.username,'-',a.organization_name) creator_name,
        count(distinct customer_msisdn) as interactions
    from `data-nationalslsdist-prd-986g`.retail.raw_ipos_nonps_trx as a
    where format_date('%Y%m',PARSE_TIMESTAMP('%d/%m/%Y %H:%M:%S', a.transaction_date))=left('{dt_id}',6)
    	and (`status` in ('Success', '') or `status` is null)
    group by 1, 2, 3
)
, itrx as (
	select 
		a.dt_id,
		a.store_code,
		a.agent_id,
		a.interactions
	from siebel_data as a
	union all
	select 
		b.dt_id,
		b.store_code,
		b.agent_id,
		b.interactions
	from ipos_data as b
) 
select 
    a.dt_id,
    a.store_code,
    a.agent_id,
    sum(a.interactions) as interactions
from itrx as a 
group by 1, 2, 3;

-- mtd value
select
	'{dt_id}' as dt_id,
	'interaction' as kpi_name,
	'agent' as level, 
	agent_id, 
	store_code, 
	'IM3' as brand, 
	sum(interactions) as value
from `data-nationalslsdist-prd-986g`.retail.tmp_kpi_trx
	where left(dt_id,6)=left('{dt_id}',6)
		and dt_id<='{dt_id}'
group by 1, 2, 3, 4, 5, 6
union all
select
	'{dt_id}' as dt_id,
	'interaction' as kpi_name,
	'store' as level, 
	cast(null as string) as agent_id, 
	store_code, 
	'IM3' as brand, 
	sum(interactions) as value
from `data-nationalslsdist-prd-986g`.retail.tmp_kpi_trx
	where left(dt_id,6)=left('{dt_id}',6)
		and dt_id<='{dt_id}'
group by 1, 2, 3, 4, 5, 6;


-- dly value
select
	dt_id,
	'interaction' as kpi_name,
	'agent' as level, 
	agent_id, 
	store_code, 
	'IM3' as brand, 
	sum(interactions) as value
from `data-nationalslsdist-prd-986g`.retail.tmp_kpi_trx
	where left(dt_id,6)=left('{dt_id}',6)
		and dt_id<='{dt_id}'
group by 1, 2, 3, 4, 5, 6
union all
select
	dt_id,
	'interaction' as kpi_name,
	'store' as level, 
	cast(null as string) as agent_id, 
	store_code, 
	'IM3' as brand, 
	sum(interactions) as value
from `data-nationalslsdist-prd-986g`.retail.tmp_kpi_trx
	where left(dt_id,6)=left('{dt_id}',6)
		and dt_id<='{dt_id}'
group by 1, 2, 3, 4, 5, 6;