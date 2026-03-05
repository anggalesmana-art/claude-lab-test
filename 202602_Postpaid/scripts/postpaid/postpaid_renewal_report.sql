with cpp as(
	select * from (
	select a.*, 
	row_number() over(partition by a.msisdn, a.account_num order by a.renewal_date  asc, renewal_tnr asc) as renewal_order
	from(
		select distinct
				a.msisdn, 
				a.order_id,
				a.ordernum,
				a.order_type, 
				a.order_status, 
				a.account_num,
				a.main_package as renewal_package, 
				a.origin_main_package,
				case 
					when a.origin_main_package='Postpaid Basic' then 'Postpaid Basic'
					when (lower(a.origin_main_package) like '%prime%' or lower(a.origin_main_package) like '%platinum%') and (lower(origin_main_package) like '%contract%' or lower(origin_main_package) like '%bundling%') then 'Platinum Contract'	
					when (lower(a.origin_main_package) like '%prime%' or lower(a.origin_main_package) like '%platinum%') and (lower(origin_main_package) like '%contract%' and lower(origin_main_package) like '%bundling%') then 'Platinum Monthly'	
				else 'Legacy Monthly'	
				end origin_group,
				a.created_date as renewal_createddate, 
				a.submitdate as renewal_submitdate, 
				a.completiondate as renewal_date, 
				a.nik renewal_nik,
				a.dealer_id renewal_dealerid,
				a.salesperson renewal_salesperson,
				a.tnr renewal_tnr,
				from_unixtime(unix_timestamp(a.completiondate), 'yyyyMMdd') as renewal_dt
		from smy.ar_change_pkg_pstpaid_rtl as a
		where a.order_type='Change Postpaid Plan'  
			and a.order_status = 'Complete'
			and lower(a.main_package) like '%platinum%'
	) as a
	) as xx 
		where xx.renewal_order = 1
			and strleft(xx.renewal_dt,6)=strleft('{dt_id}',6)
			and xx.renewal_dt<='{dt_id}'
)		
select 
	a.activation_date, 
	a.msisdn,
	a.store_code_rev,
	a.store_name_rev,
	a.package_rev,
	a.channel_rev, 
	a.circle_new as circle,
	a.region_new as region, 
	b.*
from rdm.dump_daily_ga as a
	inner join cpp as b
	on a.msisdn=b.msisdn
where 1=1
	and a.order_type in ('New Registration','Migration') 
	and  (strleft(a.activation_date,6)>=from_timestamp(add_months(to_timestamp('{dt_id}','yyyyMMdd'),-3),'yyyyMM') 
	and  a.activation_date<=from_timestamp(add_months(to_timestamp('{dt_id}','yyyyMMdd'),-1),'yyyyMMdd'))
	and  a.tenure='3';