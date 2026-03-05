create or replace table `data-nationalslsdist-prd-986g`.retail.tmp_kpi_sr as
with raw_sr_update as (
	select * from (
	select 
	sr.* except (status), 
		rpa.status_rpa,
		sr.status as status_initial,
		case when rpa.status_rpa in ('Closed', 'Cancelled') then rpa.status_rpa
			else sr.status end as status
	from `data-dtp-prd-aa1a.stg.stg_siebel_dly_sr` as sr
		left join (
			select * from (
				select 
					sr, status as status_rpa,
					row_number() over(partition by sr order by ins_dt desc) as rnk
				from `data-nationalslsdist-prd-986g`.retail.raw_im3_siebel_sr_rpa
			) as x where x.rnk=1
		) as rpa on sr.sr_number=rpa.sr
	where date(sr.dt_id) between date(SUBSTR('{dt_id}',1,4) || '-' || SUBSTR('{dt_id}',5,2) || '-01') 
	    and PARSE_DATE('%Y%m%d', '{dt_id}')
		and sr.creator_login<>sr.owner
		and sr.status <>'Cancelled'
	    and sr.creator_pr_location not like 'JKBB%' and sr.creator_pr_location not like 'LOC%'
	    and sr.creator_pr_location not like 'DS%' and sr.creator_pr_location not like 'DC%'
	    and sr.creator_pr_location not like 'TLS%' and sr.creator_pr_location not like 'OLA%'
	    and sr.owner <> 'VER_HQ'
	    and owner_pr_location <> 'JKBB-VERIFICATION HQ'
	    and sr.sr_group not like '%3ID%'
	    and sr.creator_login <> sr.owner
	    and substr(sr.activity_code,1,2) in ('12', '14')
	    ) as a where status <> 'Cancelled'
)
--select * from raw_sr_update
--where status_rpa is not null
, kpi as (
	select 
        '{dt_id}' as dt_id, 
        sr.creator_login as agent_id, 
        REGEXP_EXTRACT(sr.creator_pr_location , '^(.*?)-', 1) AS store_code, 
        'sr_total' as kpi_name,
        count(distinct sr.sr_number) as mtd_value
    -- from `data-dtp-prd-aa1a.stg.stg_siebel_dly_sr` as sr 
    from raw_sr_update as sr
    where substr(sr.activity_code,1,2) in ('12','13','14')
	    -- and sr.status in ('Open','In Progress','Closed')
    	and sr.status <>'Canceled'
	    and sr.creator_pr_location not like 'JKBB%' and sr.creator_pr_location not like 'LOC%'
	    and sr.creator_pr_location not like 'DS%' and sr.creator_pr_location not like 'DC%'
	    and sr.creator_pr_location not like 'TLS%' and sr.creator_pr_location not like 'OLA%'
	    and sr.owner <> 'VER_HQ'
	    and date(sr.dt_id) between date(SUBSTR('{dt_id}',1,4) || '-' || SUBSTR('{dt_id}',5,2) || '-01') 
	    and PARSE_DATE('%Y%m%d', '{dt_id}')
    group by 1, 2, 3, 4
	union all
    select 
        '{dt_id}' as dt_id, 
        sr.creator_login as agent_id, 
        REGEXP_EXTRACT(sr.creator_pr_location , '^(.*?)-', 1) AS store_code, 
        'sr_closed' as kpi_name,
        count(distinct sr.sr_number) as mtd_value
    -- from `data-dtp-prd-aa1a.stg.stg_siebel_dly_sr` as sr 
    from raw_sr_update as sr 
    where substr(sr.activity_code,1,2) in ('12','13','14')
	    and sr.status='Closed' 
	    and sr.creator_pr_location not like 'JKBB%' and sr.creator_pr_location not like 'LOC%'
	    and sr.creator_pr_location not like 'DS%' and sr.creator_pr_location not like 'DC%'
	    and sr.creator_pr_location not like 'TLS%' and sr.creator_pr_location not like 'OLA%'
	    and sr.owner <> 'VER_HQ'
	    and date(sr.dt_id) between date(SUBSTR('{dt_id}',1,4) || '-' || SUBSTR('{dt_id}',5,2) || '-01') 
		    and PARSE_DATE('%Y%m%d', '{dt_id}')
    group by 1, 2, 3, 4 
    union all 
    select 
        '{dt_id}' as dt_id, 
        sr.creator_login as agent_id, 
        REGEXP_EXTRACT(sr.creator_pr_location , '^(.*?)-', 1) AS store_code, 
        'sr_ontime' as kpi_name,
        count(distinct case when sr.inprogress_closed <= sr.due_date then sr.sr_number end) as mtd_value,
    -- from `data-dtp-prd-aa1a.stg.stg_siebel_dly_sr` as sr 
    from raw_sr_update as sr 
    where substr(sr.activity_code,1,2) in ('12','13','14')
	    and sr.status='Closed' 
	    and sr.creator_pr_location not like 'JKBB%' and sr.creator_pr_location not like 'LOC%'
	    and sr.creator_pr_location not like 'DS%' and sr.creator_pr_location not like 'DC%'
	    and sr.creator_pr_location not like 'TLS%' and sr.creator_pr_location not like 'OLA%'
	    and sr.owner <> 'VER_HQ'
	    and date(sr.dt_id) between date(SUBSTR('{dt_id}',1,4) || '-' || SUBSTR('{dt_id}',5,2) || '-01') 
		    and PARSE_DATE('%Y%m%d', '{dt_id}')
	    group by 1, 2, 3, 4
)
select 
    kpi.dt_id, 
    'IM3' as brand, 
    upper(kpi.store_code) as store_code, 
    upper(kpi.agent_id) agent_id,
    kpi.kpi_name,
    kpi.mtd_value
from kpi
; 

-- mtd value
select 
	'{dt_id}' as dt_id,
	'fcr' as kpi_name,
	'agent' as level, 
	a.agent_id, 
	a.store_code, 
	'IM3' as brand, 
	-- a.value/(a.value+coalesce(b.value,0)) as value
	safe_divide(a.value,(a.value+coalesce(b.value,0))) as value
from (
	select
		agent_id, 
		store_code, 
		sum(interactions) as value
	from `data-nationalslsdist-prd-986g`.retail.tmp_kpi_trx
		where left(dt_id,6)=left('{dt_id}',6)
			and dt_id<='{dt_id}'
	group by 1, 2
	) as a 
left join (
	select
		agent_id, 
		store_code, 
		sum(mtd_value) as value
	from `data-nationalslsdist-prd-986g`.retail.tmp_kpi_sr
		where left(dt_id,6)=left('{dt_id}',6)
			and dt_id<='{dt_id}'
			and kpi_name='sr_total'
	group by 1, 2
	) as b
		on a.agent_id = b.agent_id
union all
select 
	'{dt_id}' as dt_id,
	'fcr' as kpi_name,
	'store' as level, 
	cast(null as string) as agent_id, 
	a.store_code, 
	'IM3' as brand, 
	-- a.value/(a.value+coalesce(b.value,0)) as value
	safe_divide(a.value,(a.value+coalesce(b.value,0))) as value
from (
	select
		store_code, 
		sum(interactions) as value
	from `data-nationalslsdist-prd-986g`.retail.tmp_kpi_trx
		where left(dt_id,6)=left('{dt_id}',6)
			and dt_id<='{dt_id}'
	group by 1
	) as a 
left join (
	select
		store_code, 
		sum(mtd_value) as value
	from `data-nationalslsdist-prd-986g`.retail.tmp_kpi_sr
		where left(dt_id,6)=left('{dt_id}',6)
			and dt_id<='{dt_id}'
			and kpi_name='sr_total'
	group by 1
	) as b
		on a.store_code = b.store_code
union all
select
		'{dt_id}' as dt_id,
		kpi_name,
		'agent' as level, 
		agent_id, 
		store_code, 
		'IM3' as brand, 
		sum(mtd_value) as value
from `data-nationalslsdist-prd-986g`.retail.tmp_kpi_sr
	where kpi_name in ('sr_total', 'sr_ontime', 'sr_closed')
		and left(dt_id,6)=left('{dt_id}',6)
		and dt_id<='{dt_id}'
group by 1, 2, 3, 4, 5, 6
union all
select
		'{dt_id}' as dt_id,
		'sr_tt' as kpi_name,
		'agent' as level, 
		a.agent_id, 
		a.store_code, 
		'IM3' as brand,
		-- sum(case when kpi_name='sr_closed' then mtd_value else 0 end)/sum(case when kpi_name='sr_total' then mtd_value else 0 end) as value
		ifnull(safe_divide(sum(case when kpi_name='sr_closed' then mtd_value else 0 end),sum(case when kpi_name='sr_total' then mtd_value else 0 end)),1) as value
from (
	select
		distinct 
		store_code,
		agent_id 
	from (	
		select
			distinct
			store_code, 
			agent_id
		from `data-nationalslsdist-prd-986g`.retail.tmp_kpi_trx
		union all 
		select 
			distinct
			store_code, 
			agent_id
		from `data-nationalslsdist-prd-986g`.retail.tmp_kpi_sr
	) as x
) as a
left join (
	select *
	from `data-nationalslsdist-prd-986g`.retail.tmp_kpi_sr
		where kpi_name in ('sr_total', 'sr_closed')
			and left(dt_id,6)=left('{dt_id}',6)
			and dt_id<='{dt_id}'
) as b
	on a.agent_id=b.agent_id and a.store_code=b.store_code
group by 1, 2, 3, 4, 5, 6
union all
select
		'{dt_id}' as dt_id,
		kpi_name,
		'store' as level, 
		cast(null as string) as agent_id, 
		store_code, 
		'IM3' as brand, 
		sum(mtd_value) as value
from `data-nationalslsdist-prd-986g`.retail.tmp_kpi_sr
	where kpi_name in ('sr_total', 'sr_ontime', 'sr_closed')
		and left(dt_id,6)=left('{dt_id}',6)
		and dt_id<='{dt_id}'
group by 1, 2, 3, 4, 5, 6
union all
select
		'{dt_id}' as dt_id,
		'sr_tt' as kpi_name,
		'store' as level, 
		cast(null as string) as agent_id, 
		a.store_code, 
		'IM3' as brand,
		-- sum(case when kpi_name='sr_closed' then mtd_value else 0 end)/sum(case when kpi_name='sr_total' then mtd_value else 0 end) as value
		ifnull(safe_divide(sum(case when kpi_name='sr_closed' then mtd_value else 0 end),sum(case when kpi_name='sr_total' then mtd_value else 0 end)),1) as value
from (
	select
		distinct 
		store_code
	from (	
		select
			distinct
			store_code
		from `data-nationalslsdist-prd-986g`.retail.tmp_kpi_trx
		union all 
		select 
			distinct
			store_code
		from `data-nationalslsdist-prd-986g`.retail.tmp_kpi_sr
	) as x
) as a
left join (
	select *
	from `data-nationalslsdist-prd-986g`.retail.tmp_kpi_sr
		where kpi_name in ('sr_total', 'sr_closed')
			and left(dt_id,6)=left('{dt_id}',6)
			and dt_id<='{dt_id}'
) as b
	on a.store_code = b.store_code
group by 1, 2, 3, 4, 5, 6;