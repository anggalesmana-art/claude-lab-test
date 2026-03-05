delete from `data-nationalslsdist-prd-986g`.postpaid.raw_cpp_sankey
	where mth_id=left('{dt_id}',6);
	
insert into `data-nationalslsdist-prd-986g`.postpaid.raw_cpp_sankey
with cpp AS (
		select 
			a.msisdn, 
			a.circle as circle_new, 
			a.region_new_2024 as region_new, 
			a.area_rev, 
			a.sales_area, 
			a.tenure, 
			a.package_rev, 
		case 
--			when lower(channel_rev) like 'alt%' then 'Alternate Channel'
			when lower(channel_rev) in ('outcall agent','direct sales') then 'Direct Sales'
			when channel_rev in ('FRANCHISE','ONLINE CHANNEL','OWN GERAI') then channel_rev
			when lower(channel_partner_store_group) like '%partner%' and lower(channel_partner_store_group) like '%non%' then 'Partner Store Non-ERA'
			when lower(channel_partner_store_group) like '%partner%' and lower(channel_partner_store_group) not like '%non%' then 'Partner Store ERA'
			else 'Others'
		end channel 		
		from `data-nationalslsdist-prd-986g`.postpaid.raw_daily_ga as a 
		where left(a.activation_date, 6)=left('{dt_id}',6) 
			and a.order_type in ('Change Postpaid Plan', 'Change Ownership')
), 
origin_package AS (
	select a.* from 
	(
		select msisdn, order_type , order_status , main_package , origin_main_package , 
		case 
		when origin_main_package='Postpaid Basic' then 'Postpaid Basic'
		when (lower(origin_main_package) like '%prime%' or lower(origin_main_package) like '%platinum%') and lower(origin_main_package) like '%contract%' then 'Platinum Contract'	
		when (lower(origin_main_package) like '%prime%' or lower(origin_main_package) like '%platinum%') and lower(origin_main_package) not like '%contract%' then 'Platinum Monthly'	
	--	when origin_main_package like 'Freedom%' then 'Freedom'
	--	when origin_main_package like 'Indosat_Mobile%' then 'Indosat_Mobile'	
	--	when origin_main_package like 'Matrix MAX%' then 'Matrix MAX'
	--	when origin_main_package like 'Matrix Super Plan%' then 'Matrix Super Plan'
	--	when origin_main_package like 'Postpaid Plan%' then 'Postpaid Plan'
		else 'Legacy Monthly'	
	end origin_group,
	created_date , submitdate , completiondate , nik ,
		row_number() over(partition by msisdn order by completiondate desc, submitdate desc ) idx 
		from `data-dtp-prd-aa1a`.smy.ar_change_pkg_pstpaid_rtl as a
		where format_date('%Y%m', a.dt_id)=left('{dt_id}',6) 
			and date(a.dt_id)<=PARSE_DATE('%Y%m%d', '{dt_id}')
			and a.order_type = 'Change Postpaid Plan' 
			and a.order_status = 'Complete'		
	) a 
	where idx=1
)
select 
	a.msisdn,
	a.circle_new,
	a.region_new,
	a.area_rev,
	a.sales_area,
	cast(a.tenure as string) tenure,
	a.package_rev,
	a.channel,
	b.origin_main_package, 
	b.origin_group, 
	left('{dt_id}',6) as mth_id, 
	date_trunc(parse_date('%Y%m%d','{dt_id}'), month) as prt_dt
from cpp a
left join origin_package b 
on a.msisdn=b.msisdn
;

select mth_id, circle_new, region_new, channel, 
case 
	when origin_main_package='Postpaid Basic' then 'Postpaid Basic'
	when (lower(origin_main_package) like '%prime%' or lower(origin_main_package) like '%platinum%') and lower(origin_main_package) like '%contract%' then 'Platinum Contract'	
	when (lower(origin_main_package) like '%prime%' or lower(origin_main_package) like '%platinum%') and lower(origin_main_package) not like '%contract%' then 'Platinum Monthly'		
--	when origin_main_package like 'Freedom%' then 'Freedom'
--	when origin_main_package like 'Indosat_Mobile%' then 'Indosat_Mobile'	
--	when origin_main_package like 'Matrix MAX%' then 'Matrix MAX'
--	when origin_main_package like 'Matrix Super Plan%' then 'Matrix Super Plan'
--	when origin_main_package like 'Postpaid Plan%' then 'Postpaid Plan'
	else 'Legacy Monthly'	
end origin_group, 
case when tenure is null or tenure='' then '1' else tenure end current_prime_package, 
count(msisdn) cnt
from `data-nationalslsdist-prd-986g`.postpaid.raw_cpp_sankey as a
group by all
order by 1,2,3,4,5,6;