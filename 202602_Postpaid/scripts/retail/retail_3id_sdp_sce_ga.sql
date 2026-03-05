-----------------------------------------------------------------------
--------- RGU GA per SCE SDP MITRAIM3/3KIOSK
--------- Edit by : DSN
--------- Last updated : 20/02/2025
--------- Note : Data RGU GA per SCE 3KIOSK menggunakan outlet tagging 
--------- Ada data manual yang perlu dimaintain di table marketing.rtl_sce_sdp untuk list qr yang digunakan SCE
----------------------------------------------------------------------- 

-- 0. Delete from tabel marketing.rtl_sce_sdp
delete from marketing.rtl_sce_sdp_ga where mth_id={dt_id}::int/100;

-- 1. Insert into tabel marketing.rtl_sce_sdp
insert into marketing.rtl_sce_sdp_ga
select  
	{dt_id}::int as dt_id, 
	{dt_id}::int/100 as mth_id,
	a.sdp_code, 
	a.sdp_name,
	a.circle, 
	a.region, 
	a.area, 
	a.branch, 
	NULLIF(REGEXP_REPLACE(a.id_outlet, '[^0-9]', '', 'g'), '')::int id_outlet, 
	a.msisdn_outlet, 
	'3KIOSK' as partner_type,
	case when c.retailer_qrcode is null then 'Not Valid - SCE QR not found in the systems hierarchy' 
		when c.mp3_partnerid <> a.sdp_code  then 'Not Valid - SDP partner id differs from the system hierarchy'
		when upper(c.retailer_outlet_name) not like '%KIOSK%' then  'Valid - Outlet name does not contains SDP name'
		else 'Valid' end as status_qr,  
	upper(c.retailer_outlet_name) as sce_name,
	count(distinct b.sbscrptn_ek_id) as rgu_ga, 
	a.status as status_service
from marketing.rtl_sce_sdp as a 
left join marketing.and_snd_rgu_ga_new_detail as b 
	on COALESCE(NULLIF(REGEXP_REPLACE(a.id_outlet, '[^0-9]', '', 'g'), ''), '0')::int=b.partner_qr_cd::int and b.load_dt_sk_id::int/100={dt_id}::int/100 
	and b.partner_qr_cd not in ('SCM_REQ')
left join dwh.retailer_hierarchy as c 
	on COALESCE(NULLIF(REGEXP_REPLACE(a.id_outlet, '[^0-9]', '', 'g'), ''), '0')::int=c.retailer_qrcode::int and c.periode_data::int={dt_id}::int 
group by 1, 2, 3, 4, 5, 6, 7, 8, 9, 10, 11, 12, 13, 15; 

-- 2.Dump all CSV 
select * from marketing.rtl_sce_sdp_ga where mth_id={dt_id}::int/100;