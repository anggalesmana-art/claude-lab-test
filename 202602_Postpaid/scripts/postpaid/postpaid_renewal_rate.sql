delete from `data-nationalslsdist-prd-986g`.postpaid.raw_renewal_rate
	where report_dt='{dt_id}';

insert into `data-nationalslsdist-prd-986g`.postpaid.raw_renewal_rate
with cpp as (
	select * from (
		select
			*, 
			row_number() over(partition by a.msisdn order by activation_date asc) as rnk
		from `data-nationalslsdist-prd-986g`.postpaid.raw_daily_ga as a
			where a.order_type in ('Change Postpaid Plan', 'Change Ownership')
	) as x where x.rnk=1
)
, ga as(
	select * from (
		select
			*,
			case when upper(a.channel_rev) in ('IN STORE GERAI') then 'OWN GERAI'
				when upper(a.channel_rev) in ('IN STORE FRANCHISE') then 'FRANCHISE'
				when upper(a.channel_rev) in ('PARTNER STORE NON ERA', 'PARTNER STORE NON-ERA') then 'PARTNER STORE NON-ERA'
				when upper(a.channel_rev) in ('OLA', 'OLA RETAIL') then 'OLA'
				when upper(a.channel_rev) in ('ALTC') then 'ALTERNATE CHANNEL'
				when upper(a.channel_rev) in ('OUTCALL AGENT') then 'DIRECT SALES'
				else upper(a.channel_rev) end channel_group,
			row_number() over(partition by a.msisdn order by activation_date asc) as rnk
		from `data-nationalslsdist-prd-986g`.postpaid.raw_daily_ga as a
			where a.order_type in ('New Registration', 'Migration', 'Port In Migration', 'New Registration From Prepaid')
				and a.tenure in (3, 6)
	) as x where x.rnk=1
)
, maps as (
	select *
	from (
		select
			a.store_code,
			a.store_name,
			case when upper(a.channel_group) in ('IN STORE GERAI') then 'OWN GERAI'
				when upper(a.channel_group) in ('IN STORE FRANCHISE') then 'FRANCHISE'
				when upper(a.channel_group) in ('PARTNER STORE NON ERA', 'PARTNER STORE NON-ERA') then 'PARTNER STORE NON-ERA'
				when upper(a.channel_group) in ('OLA', 'OLA RETAIL') then 'OLA'
				else upper(channel_group) end channel_group,
			a.circle,
			a.region_circle as region,
			row_number() over(partition by a.store_code order by a.update_dt desc) idx
		from `data-nationalslsdist-prd-986g`.postpaid.ref_storelist as a
	) as x
		where x.idx=1
)
, data_raw as (
	select 
		case when ga.tenure = 3 then format_date('%Y%m',date_add(parse_date('%Y%m%d', ga.activation_date), interval 5 month))
			when ga.tenure = 6 then format_date('%Y%m',date_add(parse_date('%Y%m%d', ga.activation_date), interval 8 month))
			end as mth_id,
		coalesce(maps.circle, case when ga.circle='JAYA' then 'JAKARTA RAYA' else ga.circle end) as circle,
		coalesce(maps.region, ga.region_new_2024) as region, 
		coalesce(maps.channel_group, ga.channel_group) as channel_group,
		case when lower(ga.agent_type) like '%outcall%' then upper(ga.nik_sales)
				else upper(ga.store_code_rev) end as store_code,
		cpp.activation_date as cpp_date,
		ga.msisdn,
		ga.activation_date as ga_date,
		ga.tenure,
		date_diff(parse_date('%Y%m%d', cpp.activation_date), parse_date('%Y%m%d', ga.activation_date), month) as diff_month,
		case when ga.tenure = 3 and date_diff(parse_date('%Y%m%d', cpp.activation_date), parse_date('%Y%m%d', ga.activation_date), month) between 0 and 5 then 1
			when ga.tenure = 6 and date_diff(parse_date('%Y%m%d', cpp.activation_date), parse_date('%Y%m%d', ga.activation_date), month) between 0 and 8 then 1
			else 0 end as flag_renewal_rate
	from ga
		left join cpp
			on cpp.msisdn=ga.msisdn
		left join maps
			on case when lower(ga.agent_type) like '%outcall%' then upper(ga.nik_sales)
				else upper(ga.store_code_rev) end=maps.store_code
	group by all
) 
, data_final as (
select
	'{dt_id}' report_dt,
	a.mth_id,
	a.circle,
	a.region,
	a.channel_group, 
	a.store_code,
	a.tenure,
	left(a.ga_date,6) as ga_mth,
	count(distinct msisdn) as ga,
	sum(flag_renewal_rate) as renewal,
	safe_divide(sum(flag_renewal_rate), count(distinct msisdn)) as renewal_rate
from data_raw as a
where a.mth_id =left('{dt_id}',6)
group by all
)
select 
	*
from data_final
;

select * from `data-nationalslsdist-prd-986g`.postpaid.raw_renewal_rate
	where report_dt='{dt_id}';