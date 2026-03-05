--new gcp
delete from `data-bi-prd-935c.bi_snd.rtl_raw_master_kpi_mtd`
	where kpi_name in ('monthly_quiz')
		and dt_id='{dt_id}';

insert into `data-bi-prd-935c.bi_snd.rtl_raw_master_kpi_mtd`
select 
	'{dt_id}' as dt_id,
	'monthly_quiz' as kpi_name,
	'agent' as level, 
	coalesce(b.agent_nik, c.agent_nik, d.agent_nik, e.agent_nik, f.agent_nik, g.agent_nik, a.agent_nik) agent_nik , 
	coalesce(b.store_code, c.store_code, d.store_code, e.store_code, f.store_code, g.store_code, a.store_code) store_code, 	
	a.brand, 
	max(a.score) as value, 
 	CURRENT_TIMESTAMP() as insert_dt,
	current_date() as prt_dt
from `data-nationalslsdist-prd-986g`.retail.raw_monthly_quiz as a 
	left join (
		select * from (
			select 
				agent_nik,
				store_code,
				row_number() over(partition by agent_nik order by mth_id desc) as idx
			from `data-nationalslsdist-prd-986g`.retail.ref_agent_spv
				where agent_nik is not null
		) as x where x.idx=1
	) as b on upper(regexp_replace(a.agent_nik, r'[-_#\s]+', ''))=upper(regexp_replace(b.agent_nik, r'[-_#\s]+', ''))
		and a.store_code=b.store_code
	left join (
		select * from (
			select 
				agent_monthly_quiz as id,
				agent_nik,
				store_code,
				row_number() over(partition by agent_monthly_quiz order by mth_id desc) as idx
			from `data-nationalslsdist-prd-986g`.retail.ref_agent_spv
				where agent_nik is not null
					and agent_monthly_quiz is not null
		) as x where x.idx=1
	) as c on upper(regexp_replace(a.agent_nik, r'[-_#\s]+', ''))=upper(regexp_replace(c.id, r'[-_#\s]+', ''))
		and a.store_code=c.store_code and b.agent_nik is null
	left join (
		select * from (
			select 
				agent_name as id,
				agent_nik,
				store_code,
				row_number() over(partition by agent_name order by mth_id desc) as idx
			from `data-nationalslsdist-prd-986g`.retail.ref_agent_spv
				where agent_nik is not null
					and agent_name is not null
		) as x where x.idx=1
	) as d on upper(regexp_replace(a.agent_name, r'[-_#\s]+', ''))=upper(regexp_replace(d.id, r'[-_#\s]+', ''))
		and a.store_code=d.store_code and c.agent_nik is null
	left join (
		select * from (
			select 
				agent_name as id,
				agent_nik,
				store_code,
				row_number() over(partition by agent_name order by mth_id desc) as idx
			from `data-nationalslsdist-prd-986g`.retail.ref_agent_spv
				where agent_nik is not null
					and agent_name is not null
		) as x where x.idx=1
	) as e on upper(regexp_replace(a.agent_name, r'[-_#\s]+', ''))=upper(regexp_replace(e.id, r'[-_#\s]+', ''))
			and d.agent_nik is null
	left join (
		select * from (
			select 
				agent_monthly_quiz as id,
				agent_nik,
				store_code,
				row_number() over(partition by agent_monthly_quiz order by mth_id desc) as idx
			from `data-nationalslsdist-prd-986g`.retail.ref_agent_spv
				where agent_nik is not null
					and agent_monthly_quiz is not null
		) as x where x.idx=1
	) as f on upper(regexp_replace(a.agent_nik, r'[-_#\s]+', ''))=upper(regexp_replace(f.id, r'[-_#\s]+', ''))
		and e.agent_nik is null
	left join (
		select * from (
			select 
				agent_nik,
				store_code,
				row_number() over(partition by agent_nik order by mth_id desc) as idx
			from `data-nationalslsdist-prd-986g`.retail.ref_agent_spv
				where agent_nik is not null
		) as x where x.idx=1
	) as g on upper(regexp_replace(a.agent_nik, r'[-_#\s]+', ''))=upper(regexp_replace(g.agent_nik, r'[-_#\s]+', ''))
		and f.agent_nik is null
where 1=1
	and mth_id=left('{dt_id}',6)	
group by all
;