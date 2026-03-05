-- insert to main table 
INSERT OVERWRITE rdm.bai_postpaid_sankey_cpp_all_v2 PARTITION (mth_id = '{year_month}')
with cpp AS (
		select msisdn, circle_new , region_new , area_rev , sales_area , tenure , package_rev , 
		case 
--			when lower(channel_rev) like 'alt%' then 'Alternate Channel'
			when lower(channel_rev) in ('outcall agent','direct sales') then 'Direct Sales'
			when channel_rev in ('FRANCHISE','ONLINE CHANNEL','OWN GERAI') then channel_rev
			when lower(channel_partner_store_group) like '%partner%' and lower(channel_partner_store_group) like '%non%' then 'Partner Store Non-ERA'
			when lower(channel_partner_store_group) like '%partner%' and lower(channel_partner_store_group) not like '%non%' then 'Partner Store ERA'
			else 'Others'
		end channel 		
		from rdm.dump_daily_ga 
		where substr(activation_date , 1,6)='{year_month}' and order_type ='Change Postpaid Plan'
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
		from smy.ar_change_pkg_pstpaid_rtl 
		where order_type = 'Change Postpaid Plan'  and order_status = 'Complete'
		and substr(dt_id,1,6)='{year_month}'
	) a 
	where idx=1
)
select a.*, b.origin_main_package, b.origin_group
from cpp a
left join origin_package b 
on a.msisdn=b.msisdn
;


-- export to csv
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
case when tenure is null or tenure ='' then '1' else tenure end current_prime_package, 
count(msisdn) cnt
from rdm.bai_postpaid_sankey_cpp_all_v2
group by 1,2,3,4,5,6
order by 1,2,3,4,5,6;