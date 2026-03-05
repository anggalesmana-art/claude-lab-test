-----------------------------------------------------------------------
--------- RGU GA per SCE SDP MITRAIM3/3KIOSK
--------- Edit by : DSN
--------- Last updated : 20/02/2025
--------- Note : Data RGU GA per SCE MITRA IM3 menggunakan outlet tagging 
--------- Ada data manual yang perlu dimaintain di table rdm.rtl_sce_sdp untuk list qr yang digunakan SCE
----------------------------------------------------------------------- 

-- 0. insert table rdm.rtl_sce_sdp_ga
insert overwrite rdm.rtl_sce_sdp_ga
partition (mth_id)
select    
	distinct
	'{dt_id}' as dt_id, 
	a.sdp_code, 
	a.sdp_name, 
	a.circle, 
	a.region, 
	a.area, 
	a.branch, 
	a.id_outlet, 
	a.msisdn_outlet, 
	'MITRA IM3' as partner_type,  
	case when b.outlet_code is null then 'Not Valid - SCE QR not found in the systems hierarchy' 
		when b.mpc_short_code <> a.sdp_code  then 'Not Valid - SDP partner id differs from the system hierarchy'
		when upper(b.outlet_name) not like '%SDP%' then  'Valid - Outlet name does not contains SDP name'
		else 'Valid' end as status_qr,   
	upper(b.outlet_name) as sce_name,  
	a.status as status_service,
	coalesce(cast(c.amount as int),0) as rgu_ga, 
    strleft('{dt_id}', 6) as mth_id
from rdm.rtl_sce_sdp as a 
	left join stg.mobi_master_hierarchy_feed as b 
		on a.id_outlet=b.outlet_code and b.dt_id='{dt_id}' 
	left join ( 
				select 
				    b.organization_id id,
				    strleft(a.dt_id,6) mth,
				    count(distinct a.msisdn) amount
				from biadm.umr_rgs_ga_90d_dly_govt a
				join biadm.umr_rgs_ga_channel_mth_govt b
				    on a.msisdn = b.msisdn
				    and a.dt_id = b.ga_dt
				where 
				    ((strleft(a.dt_id,6) = strleft('{dt_id}',6) and a.dt_id <= '{dt_id}'))
				and (churn_back = 'NO' OR recycled = 'YES') 
				group by 1, 2
		) as c	
			on a.id_outlet = c.id
;  

-- 1 Dump table table rdm.rtl_sce_sdp_ga 
select * from rdm.rtl_sce_sdp_ga where mth_id=strleft('{dt_id}',6);