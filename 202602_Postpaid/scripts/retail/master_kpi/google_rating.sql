select
	'{dt_id}' as dt_id,
	'google_rating' as kpi_name,
	'store' as level, 
	cast(null as string) as agent_id, 
	store_code, 
	case when left(lower(store_name),6)='3store' then '3ID' else 'IM3' end as brand, 
	google_rating as value
from (
		select * from (
		select 
			a.*,
			row_number() over(partition by a.store_code order by a.last_updated desc, a.google_rating desc) rnk
		from `data-nationalslsdist-prd-986g`.retail.raw_google_rating as a
		where 1=1
			-- and left(a.last_updated,6)=left('{dt_id}',6)
			and a.google_rating is not null
			-- and a.google_rating <>''
		) as x
		where x.rnk=1
) as z
;

-- select
-- 	'{dt_id}' as dt_id,
-- 	'google_rating' as kpi_name,
-- 	'store' as level, 
-- 	cast(null as string) as agent_id, 
-- 	store_code, 
-- 	case when left(lower(store_name),6)='3store' then '3ID' else 'IM3' end as brand, 
-- 	google_rating as value
-- from `data-nationalslsdist-prd-986g`.retail.raw_google_rating 
-- 	where last_updated='{dt_id}'
-- ;