DECLARE vdt_id DATE DEFAULT @vdt_id;


	delete from `data-bi-prd-935c.bi_mart.kpi_national_tracker_dly` 
	where brand = 'TRI' and kpi_id in 
	(
	'DST0014',
	'DST0015',
	'DST0016',
	'DST0017'
	) and dt_id	 = vdt_id;

	insert into `data-bi-prd-935c.bi_mart.kpi_national_tracker_dly` 
	select 
	'TRI' brand
	,''kpi_code
	,'MTD' flag
	,sum(value)   -- value
	,CURRENT_TIMESTAMP()
	,case when kpi_code =	'uro_any' then 'DST0014'
		when kpi_code =	'quro_any' then 'DST0015'
		when kpi_code =	'sso_any' then 'DST0016'
		when kpi_code =	'qsso_any' then 'DST0017'
	end as  kpi_id
	,CAST(CAST(load_Dt_sk_id AS STRING) AS DATE)
	from 
`data-bi-prd-935c.bi_mart.h3i_project_ioh_kpi_daily_tracker_site`
where kpi_code in 
(
'uro_any',
'quro_any',
'sso_any',
'qsso_any'
) and load_Dt_sk_id =  vdt_id
group by  1,2,3,5,6,7; 



-- site without quro > 5

	delete from `data-bi-prd-935c.bi_mart.kpi_national_tracker_dly` 
	where brand = 'TRI' and kpi_id in 
	(
	'DST0019'
	) and dt_id = vdt_id; 

	insert into `data-bi-prd-935c.bi_mart.kpi_national_tracker_dly` 
	with addrs_sites as
	(
				  select case when length(oldsiteid)=5 then CAST(CONCAT('0',oldsiteid) AS STRING) else oldsiteid end oldsiteid
		      , case when length(newsiteid)<9 then NULL else newsiteid end newsiteid
		  from `data-bi-prd-935c.bi_mart.dm_phy_addressable_sites` a
		  where mth = (select max(mth) from `data-bi-prd-935c.bi_mart.dm_phy_addressable_sites`  
                    where mth <= DATE_TRUNC(DATE_SUB(vdt_id, INTERVAL 1 MONTH), MONTH))
		    and upper(addressablesites) = 'ADDRESSABLE SITE'
	),
	base as
	(
		select * from `data-bi-prd-935c.bi_mart.h3i_project_ioh_kpi_daily_tracker_site` b
		where b.load_dt_sk_id =  vdt_id and b.kpi_code in ('quro_any')
		  and coalesce(value,0) >=5  and  b.site_id is null
	)
	select 
	'TRI' brand
	,''kpi_code
	,'MTD' flag
	,sum(kpi_value)
	,CURRENT_TIMESTAMP()
	,'DST0019'
	,CAST(CAST(dt_id AS STRING) AS DATE)
	from (
		select vdt_id dt_id,'site_<3qsso' kpi_name,count(1) kpi_value
		from addrs_sites a
		left join base b
		  on (b.site_id=a.oldsiteid or b.site_id =a.newsiteid)  
		group by 1,2
	) x
group by  1,2,3,5,6,7;

	---site without qsso >3 


	delete from `data-bi-prd-935c.bi_mart.kpi_national_tracker_dly` 
	where brand = 'TRI' and kpi_id in 
	(
	'DST0020'
	) and dt_id = vdt_id;

	insert into `data-bi-prd-935c.bi_mart.kpi_national_tracker_dly` 
	with addrs_sites as
	(
				  select case when length(oldsiteid)=5 then CAST(CONCAT('0',oldsiteid) AS STRING) else oldsiteid end oldsiteid
		      , case when length(newsiteid)<9 then NULL else newsiteid end newsiteid
		  from `data-bi-prd-935c.bi_mart.dm_phy_addressable_sites` a
		  where mth= (select max(mth) from `data-bi-prd-935c.bi_mart.dm_phy_addressable_sites`  
                    where mth <= DATE_TRUNC(DATE_SUB(vdt_id, INTERVAL 1 MONTH), MONTH))
		    and upper(addressablesites) = 'ADDRESSABLE SITE'
	),
	base as 
	(
		select * from `data-bi-prd-935c.bi_mart.h3i_project_ioh_kpi_daily_tracker_site` b
		where b.load_dt_sk_id =  vdt_id and b.kpi_code in ('qsso_any') and coalesce(value,0) >=3 
		and b.site_id is null
	)
	select 
	'TRI' brand
	,''kpi_code
	,'MTD' flag
	,sum(kpi_value)
	,CURRENT_TIMESTAMP()
	,'DST0020'
	,CAST(CAST(dt_id AS STRING) AS DATE)
	from (
		select vdt_id dt_id,'site_<3qsso' kpi_name,count(1) kpi_value
		from addrs_sites a
		left join base b
		  on (b.site_id=a.oldsiteid or b.site_id =a.newsiteid)
		group by 1,2
	) x
group by  1,2,3,5,6,7; 



	---site without qsc 25

	delete from `data-bi-prd-935c.bi_mart.kpi_national_tracker_dly` 
	where brand = 'TRI' and kpi_id in 
	(
	'DST0021'
	) and dt_id = vdt_id;

	insert into `data-bi-prd-935c.bi_mart.kpi_national_tracker_dly` 
	with addrs_sites as
	(
			  select case when length(oldsiteid)=5 then CAST(CONCAT('0',oldsiteid) AS STRING) else oldsiteid end oldsiteid
		      , case when length(newsiteid)<9 then NULL else newsiteid end newsiteid
		  from `data-bi-prd-935c.bi_mart.dm_phy_addressable_sites` a
		  where mth= (select max(mth) from `data-bi-prd-935c.bi_mart.dm_phy_addressable_sites`  
                    where mth <= DATE_TRUNC(DATE_SUB(vdt_id, INTERVAL 1 MONTH), MONTH))
		    and upper(addressablesites) = 'ADDRESSABLE SITE'
	),
	base as
	(
		select * from `data-bi-prd-935c.bi_mart.h3i_project_ioh_kpi_daily_tracker_site`b
		where  b.load_dt_sk_id =  vdt_id and b.kpi_code in ('scm0_any') and coalesce(value,0) >=25 and b.site_id is null
	)
	select 
	'TRI' brand
	,''kpi_code
	,'MTD' flag
	,sum(kpi_value)
	,CURRENT_TIMESTAMP()
	,'DST0021'
	,CAST(CAST(dt_id AS STRING) AS DATE)
	from (
		select vdt_id dt_id,'site_<3qsso' kpi_name,count(1) kpi_value
		from addrs_sites a
		left join base b
		  on (b.site_id=a.oldsiteid or b.site_id =a.newsiteid) 
		group by 1,2
	) x
group by  1,2,3,5,6,7; 


-- SE transactional SE


	delete from `data-bi-prd-935c.bi_mart.kpi_national_tracker_dly` 
	where brand = 'TRI' and kpi_id in 
	(
	'DST0022'
	) and dt_id =vdt_id ;

-- SE 

	insert into `data-bi-prd-935c.bi_mart.kpi_national_tracker_dly` 
	select 
	'TRI' brand
	,''kpi_code
	,'MTD' flag
	,count(distinct sales) 
	,CURRENT_TIMESTAMP()
	,'DST0022'
	,CAST(CAST(mth AS STRING) AS DATE)
 from 
`data-bi-prd-935c.bi_mart.cse_1` 
where mth = vdt_id  
group by 1,2,3,5,6,7 ; 

	delete from `data-bi-prd-935c.bi_mart.kpi_national_tracker_dly` 
	where brand = 'TRI' and kpi_id in 
	(
	'DST0023'
	) and dt_id =vdt_id ;

insert into `data-bi-prd-935c.bi_mart.kpi_national_tracker_dly`
select 'TRI','','MTD',count(distinct partner_qr_cd),CURRENT_TIMESTAMP(),'DST0023' , CAST(CAST(dt AS STRING) AS DATE) from 
`data-bi-prd-935c.bi_mart.booking_dly_clean`
where dt= vdt_id
group by 1,2,3,5,6,7; 

delete from   `data-bi-prd-935c.bi_mart.booking_dly`
where dt= vdt_id;



-- MP3

delete from `data-bi-prd-935c.bi_mart.kpi_national_tracker_dly` 
	where brand = 'TRI' and kpi_id in 
	(
	'DST0026'
	) and dt_id =vdt_id  ;

insert into `data-bi-prd-935c.bi_mart.kpi_national_tracker_dly` 
	select 
		'TRI' brand
		,''kpi_code
		,'MTD' flag
		, count(distinct partner_id)
		,CURRENT_TIMESTAMP()
		,'DST0026'
		,cast(vdt_id as date)
   --mp3_location,case when mp3_location like '%KIOSK%' then 1 else 0 end ,count(*) 
	from `data-dtptechm-prd-c7ca.dwh.angie_hrchy_dim`
				where hrchy_type='MP3'  
				and ret_hierarchy_type='ANGIE'
				and partner_status='Active' and mp3_location 
				not in 
				('FUT ANGIE 2.0','AdvCredit' ,'MODCHAN','EAD HOB' , 'POOL','DVM BM','SIM ONLINE','BSM TRI OFFICIAL STORE','3 BUSINESS','3 STORE','SOUTH JAKARTA TEST BM')
	and case when mp3_location like '%KIOSK%' then 1 else 0 end = 0 
	and mp3_channel_sk_id<>-2 	and CAST(ret_active_Date AS DATE)<= vdt_id
		group by 1,2,3,5,6,7;		

-- 3 KIOSK


delete from `data-bi-prd-935c.bi_mart.kpi_national_tracker_dly` 
	where brand = 'TRI' and kpi_id in 
	(
	'DST0027'
	) and dt_id = vdt_id;

insert into `data-bi-prd-935c.bi_mart.kpi_national_tracker_dly` 
	select 
		'TRI' brand
		,''kpi_code
		,'MTD' flag
		, count(distinct partner_id)
		,CURRENT_TIMESTAMP()
		,'DST0027'
		,cast(vdt_id as date)
   --mp3_location,case when mp3_location like '%KIOSK%' then 1 else 0 end ,count(*) 
	from `data-dtptechm-prd-c7ca.dwh.angie_hrchy_dim`
				where hrchy_type='MP3'  
				and ret_hierarchy_type='ANGIE'
				and partner_status='Active' and mp3_location 
				not in 
				('FUT ANGIE 2.0','AdvCredit' ,'MODCHAN','EAD HOB' , 'POOL','DVM BM','SIM ONLINE','BSM TRI OFFICIAL STORE','3 BUSINESS','3 STORE','SOUTH JAKARTA TEST BM')
	and case when mp3_location like '%KIOSK%' then 1 else 0 end = 1 
	and mp3_channel_sk_id<>-2 	and CAST(ret_active_Date AS DATE) <= vdt_id	
		group by 1,2,3,5,6,7;	



--oct 
--booking 

insert into `data-bi-prd-935c.bi_mart.booking_dly` 
select cast(vdt_id as date) as dt, cast(sbscrptn_ek_id as string),fl_number,partner_qr_cd,'non bts as flag' as flag
from 
(
			select 
			sbscrptn_ek_id,fl_number
			from 
			(
				with subs as (select * from `data-dtptechm-prd-c7ca.dwh.sbscrptn_attribs`)
				select 
				CAST(CAST(FORMAT_DATE('%Y%m%d',CAST(booking_date AS DATE)) AS STRING) AS INT64) as booking_date
			,	fl_number
				,b.sbscrptn_ek_id, 
			 (
    SELECT MIN(d)
    FROM UNNEST([
      cast(first_usage_dt as date),
      safe.parse_date('%Y%m%d',cast(first_billing_usage_dt_sk_id as string)),
      cast(any_event_first_usage_date as date)
    ]) AS d
    WHERE d IS NOT NULL
  ) as first_usage_dt_dwh
				,row_number() over ( partition by booking_msisdn order by booking_Date desc) rown 
				from 
				(
				select * from `data-bi-prd-935c.bi_mart.mis_hcpt_frontliner_subs_booked_msisdn`   where report_month='2023-06-01' )   a left join 
				subs b on a.booking_msisdn =cast(b.sbscrptn_msisdn as string)
				and rank_ind =1
				where booking_date  between DATE_TRUNC( vdt_id, MONTH)  and vdt_id 
			) x where rown=1 and first_usage_dt_dwh between DATE_TRUNC( vdt_id, MONTH) and vdt_id 
) x		left join 	 
			( --list dsfs
			select CONCAT('62',substr(partner_mobile,2,length(partner_mobile))) AS partner_mobile,partner_qr_cd from `data-dtptechm-prd-c7ca.dwh.angie_hrchy_dim`
			where partner_type='DSF'
				and ret_hierarchy_type='ANGIE'
				and partner_status='Active' and mp3_location 
				not in 
				('POOL','DVM BM','SIM ONLINE','BSM TRI OFFICIAL STORE','3 BUSINESS','3 STORE','SOUTH JAKARTA TEST BM')
				and partner_qr_cd in 
	(
			select retailer_qrcode from 
			(
			select retailer_qrcode,activation_time,row_number() over (partition by retailer_qrcode order by activation_time desc) rnk  from 
			`data-bi-prd-935c.bi_mart.dsf_list_reference_phy`
			--where remark<>'Owner'
			) x where rnk=1
			union all 
			select partner_qr_cd 
			from
			`data-dtptechm-prd-c7ca.dwh.angie_hrchy_dim` a 
			where partner_status='Active'
			and hrchy_type='Retailer'
			and partner_type='DSF'
			and  CAST(ret_active_Date AS DATE)>='2023-01-01' 
			group by 1
	)and CAST(ret_active_Date AS DATE) <= vdt_id
						group by 1,2
			) y
	 on x.fl_number=y.partner_mobile 
	 where partner_qr_cd is not null 
union all 
(
	with subs as (select * from `data-dtptechm-prd-c7ca.dwh.sbscrptn_attribs`)
	select cast(vdt_id as date),cast(sbscrptn_ek_id as string),partner_mobile,angie_retailer_name,'bts as flag'  from 
		subs x
		left join 
			(
				select  CONCAT('62',substr(partner_mobile,2,length(partner_mobile))) AS partner_mobile,partner_qr_cd from `data-dtptechm-prd-c7ca.dwh.angie_hrchy_dim` 
				where partner_type='DSF'
				and ret_hierarchy_type='ANGIE'
				and partner_status='Active' and mp3_location 
				not in 
				('POOL','DVM BM','SIM ONLINE','BSM TRI OFFICIAL STORE','3 BUSINESS','3 STORE','SOUTH JAKARTA TEST BM')
				and partner_qr_cd in 
				(
					select retailer_qrcode from 
					(
					select retailer_qrcode,activation_time,type,row_number() over (partition by retailer_qrcode order by activation_time desc) rnk  from 
					`data-bi-prd-935c.bi_mart.dsf_list_reference_phy`   -- select * From `data-bi-prd-935c.bi_mart.dsf_list_reference_phy` limit 10
					--where remark<>'Owner'
					) x where rnk=1 and type='BTS'
				)	and CAST(ret_active_Date AS DATE)<= vdt_id
						group by 1,2
			) y on x.angie_retailer_name=y.partner_qr_cd

		where 
		 (
    SELECT MIN(d)
    FROM UNNEST([
      cast(first_usage_dt as date),
      safe.parse_date('%Y%m%d',cast(first_billing_usage_dt_sk_id as string))
    ]) AS d
    WHERE d IS NOT NULL
  ) AS fu_d,
		CAST(any_event_first_usage_date as date) )
		between DATE_TRUNC( vdt_id, MONTH) and vdt_id 
		and y.partner_qr_cd is not null
);



delete From 
`data-bi-prd-935c.bi_mart.booking_dly_clean` where dt= vdt_id; 


 --limit 10 
insert into `data-bi-prd-935c.bi_mart.booking_dly_clean`  
select coalesce(a.dt,b.dt) dt,
cast(coalesce(a.sbscrptn_ek_id,b.sbscrptn_ek_id) as int64) ek_id
,coalesce(a.fl_number,b.fl_number) fl_number
,coalesce(a.partner_qr_cd,b.partner_qr_cd) partner_qr_cd
,coalesce(a.flag,b.flag) flag
from (
select *  from 
`data-bi-prd-935c.bi_mart.booking_dly`  where flag='bts as flag'  and dt=vdt_id -- limit 10 
) a 
full join 
(
select *  from 
`data-bi-prd-935c.bi_mart.booking_dly`  where flag<>'bts as flag'   and dt=vdt_id --
) b
on a.dt=b.dt and a.sbscrptn_ek_id=b.sbscrptn_ek_id 
where a.sbscrptn_ek_id is null or b.sbscrptn_ek_id is null ;



---DSF 


	delete from `data-bi-prd-935c.bi_mart.kpi_national_tracker_dly` 
	where brand = 'TRI' and kpi_id in 
	(
	'DST0023'
	) and dt_id =vdt_id ;


	insert into `data-bi-prd-935c.bi_mart.kpi_national_tracker_dly` 
	select 
		'TRI' brand
		,''kpi_code
		,'MTD' flag
		,count(distinct partner_qr_cd) 
		,CURRENT_TIMESTAMP()
		,'DST0023'
		,CAST(CAST(dt AS STRING) AS DATE)
	 from 
	`data-bi-prd-935c.bi_mart.booking_dly_clean` where dt = vdt_id 
	group by 1,2,3,5,6,7 ; 






	delete from `data-bi-prd-935c.bi_mart.kpi_national_tracker_dly` 
	where brand = 'TRI' and kpi_id in 
	(
	'DST0018'
	) and dt_id =vdt_id ;

insert into `data-bi-prd-935c.bi_mart.kpi_national_tracker_dly`
select 'TRI','','MTD',41569,CURRENT_TIMESTAMP(),'DST0018' , cast(vdt_id as date)  ;




	delete from `data-bi-prd-935c.bi_mart.kpi_national_tracker_dly` 
	where brand = 'TRI' and kpi_id in 
	(
	'DST0027'
	) and dt_id =vdt_id ;


insert into `data-bi-prd-935c.bi_mart.kpi_national_tracker_dly`
select 'TRI','','MTD',349,CURRENT_TIMESTAMP(),'DST0027' , cast(vdt_id as date) ;


