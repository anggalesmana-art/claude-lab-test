with siebel_data as
    (
	    select
		    distinct
		    format_date('%Y%m%d',a.dt_id) as dt_id,
		    REGEXP_EXTRACT(a.creator_location, r'^(.*?)-') AS store_code,
		    creator_login as creator_id,
		    creator_name,
		    a.msisdn
	    from `data-dtp-prd-aa1a.stg.stg_siebel_dly_intrctn` as a
	    where date(a.dt_id) between date(SUBSTR('{dt_id}',1,4) || '-' || SUBSTR('{dt_id}',5,2) || '-01') 
	    and PARSE_DATE('%Y%m%d', '{dt_id}')
	    and a.status='Closed'
	    -- and format_date('%Y%m',a.dt_id)=left('{dt_id}',6)
    )
    ,ipos_data as
    (
	    select
	        distinct
	        format_date('%Y%m%d',PARSE_TIMESTAMP('%d/%m/%Y %H:%M:%S', a.transaction_date)) as dt_id,
	        organization_ref_code as store_code,
	        a.username as creator_id,
	        concat(a.username,'-',a.organization_name) creator_name,
	        customer_msisdn as msisdn
	    from `data-nationalslsdist-prd-986g`.retail.raw_ipos_nonps_trx as a
	    where format_date('%Y%m',PARSE_TIMESTAMP('%d/%m/%Y %H:%M:%S', a.transaction_date))=left('{dt_id}',6)
	    and status='Success'
    )
    , data_interactions as (
	    select
	        'siebel' as source,
	        a.dt_id,
	        a.store_code,
	        a.creator_id,
	        count(distinct a.msisdn) as interactions
	    from siebel_data as a
	    group by 1, 2, 3, 4
	    union all
	        select
	        'ipos' as source,
	        b.dt_id,
	        b.store_code,
	        b.creator_id,
	        count(distinct b.msisdn) as interactions
		from ipos_data as b
	        	left join siebel_data as c 
	        		on b.dt_id=c.dt_id and b.store_code=c.store_code and b.msisdn=c.msisdn  
	    	where c.msisdn is null
	    -- from (select
	    --     x.*
	    -- from ipos_data as x
	    -- where concat(left(x.dt_id,6),x.store_code,x.msisdn) not in (select distinct concat(left(a.dt_id,6),a.store_code, a.msisdn) from siebel_data as a)
	    -- )as b
	    group by 1, 2, 3, 4),
	    itrx as (
	    select
	        a.dt_id,
	        a.store_code,
	        a.creator_id,
	        sum(interactions) as interactions
	    from data_interactions as a
	    group by 1, 2, 3
    )
-- mtd
select
	'{dt_id}' as dt_id,
	'traffic_visitor' as kpi_name,
	'agent' as level, 
	creator_id as agent_id, 
	store_code, 
	'IM3' as brand, 
	sum(interactions) as value
from itrx
	where left(dt_id,6)=left('{dt_id}',6)
		and dt_id<='{dt_id}'
group by 1, 2, 3, 4, 5, 6
union all
select
	'{dt_id}' as dt_id,
	'traffic_visitor' as kpi_name,
	'store' as level, 
	cast(null as string) agent_id, 
	store_code, 
	'IM3' as brand, 
	sum(interactions) as value
from itrx
	where left(dt_id,6)=left('{dt_id}',6)
		and dt_id<='{dt_id}'
group by 1, 2, 3, 4, 5, 6;

with siebel_data as
    (
	    select
		    distinct
		    format_date('%Y%m%d',a.dt_id) as dt_id,
		    REGEXP_EXTRACT(a.creator_location, r'^(.*?)-') AS store_code,
		    creator_login as creator_id,
		    creator_name,
		    a.msisdn
	    from `data-dtp-prd-aa1a.stg.stg_siebel_dly_intrctn` as a
	    where date(a.dt_id) between date(SUBSTR('{dt_id}',1,4) || '-' || SUBSTR('{dt_id}',5,2) || '-01') 
	    and PARSE_DATE('%Y%m%d', '{dt_id}')
	    and a.status='Closed'
	    -- and format_date('%Y%m',a.dt_id)=left('{dt_id}',6)
    )
    ,ipos_data as
    (
	    select
	        distinct
	        format_date('%Y%m%d',PARSE_TIMESTAMP('%d/%m/%Y %H:%M:%S', a.transaction_date)) as dt_id,
	        organization_ref_code as store_code,
	        a.username as creator_id,
	        concat(a.username,'-',a.organization_name) creator_name,
	        customer_msisdn as msisdn
	    from `data-nationalslsdist-prd-986g`.retail.raw_ipos_nonps_trx as a
	    where format_date('%Y%m',PARSE_TIMESTAMP('%d/%m/%Y %H:%M:%S', a.transaction_date))=left('{dt_id}',6)
	    and status='Success'
    )
    , data_interactions as (
	    select
	        'siebel' as source,
	        a.dt_id,
	        a.store_code,
	        a.creator_id,
	        count(distinct a.msisdn) as interactions
	    from siebel_data as a
	    group by 1, 2, 3, 4
	    union all
	        select
	        'ipos' as source,
	        b.dt_id,
	        b.store_code,
	        b.creator_id,
	        count(distinct b.msisdn) as interactions
	    from (select
	        x.*
	    from ipos_data as x
	    where concat(left(x.dt_id,6),x.store_code,x.msisdn) not in (select distinct concat(left(a.dt_id,6),a.store_code, a.msisdn) from siebel_data as a)
	    )as b
	    group by 1, 2, 3, 4),
	    itrx as (
	    select
	        a.dt_id,
	        a.store_code,
	        a.creator_id,
	        sum(interactions) as interactions
	    from data_interactions as a
	    group by 1, 2, 3
    )
-- daily
select
	dt_id,
	'traffic_visitor' as kpi_name,
	'agent' as level, 
	creator_id as agent_id, 
	store_code, 
	'IM3' as brand, 
	sum(interactions) as value
from itrx
	where left(dt_id,6)=left('{dt_id}',6)
		and dt_id<='{dt_id}'
group by 1, 2, 3, 4, 5, 6
union all
select
	dt_id,
	'traffic_visitor' as kpi_name,
	'store' as level, 
	cast(null as string) agent_id, 
	store_code, 
	'IM3' as brand, 
	sum(interactions) as value
from itrx
	where left(dt_id,6)=left('{dt_id}',6)
		and dt_id<='{dt_id}'
group by 1, 2, 3, 4, 5, 6;