select 
		trim(a.store_code) store_code,
        upper(a.store_name) store_name,	
        a.status_2 as `type`,
        a.region,
        a.circle,
        left('{dt_id}',6) periode,
        c.total_ga as ga_target,
        coalesce(b.ga_only,0) ga_only
        from  `data-nationalslsdist-prd-986g`.retail.ref_storelist as a
            left join ( 
                select 
                    store_code_rev as store_code, 
                    count(distinct msisdn) as ga_only
                from `data-nationalslsdist-prd-986g`.postpaid.raw_daily_ga
                where left(activation_date,6)=left('{dt_id}',6)
                    and order_type in ('New Registration', 'Migration', 'Port in Migration')
                group by 1
            ) as b
            on trim(a.store_code)=b.store_code
            left join `data-nationalslsdist-prd-986g`.postpaid.ref_target_store as c
            	on trim(a.store_code)=c.store_code_rev
            	and format_date('%Y%m', PARSE_TIMESTAMP('%Y-%m-%d %H:%M:%S', c.date))=left('{dt_id}',6)
				and lower(c.channel_group) in ('own gerai', 'franchise')
		where lower(a.status_2) like '%gerai%im3%'
			and a.mth_id=left('{dt_id}',6)
			and a.store_code not in ('FCBE','JGLM');