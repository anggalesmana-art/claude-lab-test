delete from `data-bi-prd-935c.bi_snd.rtl_raw_master_kpi_mtd`
	where kpi_name in ('rev_others_ftth')
		and brand in ('IM3', '3ID')
		and dt_id='{dt_id}';

insert into `data-bi-prd-935c.bi_snd.rtl_raw_master_kpi_mtd`
with agent_list as(
	select * from (
		select 
			agent_nik,
			agent_name,
			store_code,
			brand,
			row_number() over(partition by agent_name order by store_code) idx
		from (
			select 
			distinct
				agent_nik, 
				agent_name,
				store_code,
				brand
			from `data-nationalslsdist-prd-986g`.retail.ref_agent_store ras 
			where mth_id=left('{dt_id}',6)
			union all 
			select 
				distinct
				spv_nik agent_nik, 
				spv_name agent_name,
				store_code,
				brand
			from `data-nationalslsdist-prd-986g`.retail.ref_agent_store ras 
			where mth_id=left('{dt_id}',6)
			) as x 
		) as z where z.idx=1
)
select 
	'{dt_id}' as dt_id,
	'rev_others_ftth' as kpi_name,
 	'store' as level,
 	cast(null as string) as agent_id,
 	coalesce(b.store_code) as store_code,
 	b.brand,
 	sum(a.price) as value, 
 	CURRENT_TIMESTAMP() as insert_dt,
	current_date() as prt_dt
from `data-nationalslsdist-prd-986g`.retail.raw_ftth_rev_pa as a
left join agent_list as b
	on upper(a.sales_name)=upper(b.agent_name)
	where format_date('%Y%m', date_pa)=left('{dt_id}',6)
		and format_date('%Y%m%d', date_pa)<='{dt_id}'
		and (lower(a.sales_tl) like '%gerai%'
			or lower(a.sales_tl) like '%store%')
group by 1, 2, 3, 4, 5, 6 , 8, 9
union all 
select 
	'{dt_id}' as dt_id,
	'rev_others_ftth' as kpi_name,
 	'agent' as level,
 	b.agent_nik as agent_id,
 	coalesce(b.store_code) as store_code,
 	b.brand,
 	sum(a.price) as value, 
 	CURRENT_TIMESTAMP() as insert_dt,
	current_date() as prt_dt
from `data-nationalslsdist-prd-986g`.retail.raw_ftth_rev_pa as a
left join agent_list as b
	on upper(a.sales_name)=upper(b.agent_name)
	where format_date('%Y%m', date_pa)=left('{dt_id}',6)
		and format_date('%Y%m%d', date_pa)<='{dt_id}'
		and (lower(a.sales_tl) like '%gerai%'
			or lower(a.sales_tl) like '%store%')
group by 1, 2, 3, 4, 5, 6 , 8, 9
;