/*
initial log [1 Jul 2025]

business owner: Ardee

*/
begin
declare vdt_id date default @vdt_id;

with lms_booking_info_sim as (
select 
bookingdatetime ,
reqtype as product_type,
callplan,
retailermsisdn ,
retailerqrcode ,
reqtype,
subscribermsisdn,
status,
expirydatetime ,
RANK () OVER ( 
		partition by case when reqtype = 'VOUCHER' then vouchersrlnum else subscribermsisdn end
		ORDER BY bookingdatetime 
	) rank_number,
	frcdatetime ,
	registereddatetime 
from `data-dtptechm-prd-c7ca.stg.stg_lms_booking_info`
where date(bookingdatetime) >= '2023-12-09'  --> tanggal ini jangan diubah karena default
AND status not in ('REJECTED')
and reqtype in ('SIM')
AND (status = 'EXPIRED' OR (status IN ('BOOKED','BOOKED_BY_OTHER') AND bookingperiod LIKE '%9999%'))
),

highest_rank as (
SELECT 
subscribermsisdn,max(rank_number) AS rnk
FROM lms_booking_info_sim
GROUP BY 1),

sim_tagging as (
SELECT
DISTINCT
a.bookingdatetime AS time_stamp,
regexp_replace(ahd.roh_location, r'[\n\r]+',' ' ) AS DISTRICT,	
regexp_replace(ahd.rsh_location, r'[\n\r]+',' ' ) AS REGION,
regexp_replace(ahd.bm_location, r'[\n\r]+',' ' ) AS BRANCH,
replace(regexp_replace(ahd.ts_location, r'[\n\r]+',' ' ),',',' ') AS CSE,
regexp_replace(ahd.mp3_location, r'[\n\r]+',' ' ) AS MP3,
regexp_replace(ahd.tm_location, r'[\n\r]+',' ' ) AS TSS,
REPLACE(regexp_replace(ahd.canvasser_location, r'[\n\r]+',' ' ),',',' ') AS DSE,
CASE 
	WHEN a.rank_number <> 1 THEN a.retailerqrcode
	WHEN c.rank_number = 1 THEN c.retailerqrcode
END AS booking_by,
CASE 
	WHEN a.rank_number <> 1 THEN a.retailermsisdn
	WHEN c.rank_number = 1 THEN c.retailermsisdn
END AS trx_retailer,
aa.retailer_qrcode AS produce_by,
UPPER(retailer_name) as retailer_nm,
a.reqtype AS product_type,
a.subscribermsisdn AS msisdn,
a.callplan,
CASE WHEN a.status = 'BOOKED' and attr.any_event_first_usage_date IS NOT NULL THEN 'REGISTERED'
ELSE a.status
END AS status,
date(a.bookingdatetime) AS booking_date,
a.expirydatetime AS expiry_date,
CASE 
	WHEN attr.sbscrptn_status = 'Active' THEN cast(attr.any_event_first_usage_date as string)
	ELSE cast('MSISDN NOT DOING USAGE YET' as string)
END AS first_usage_date,
attr.usage_250mb_dt AS fulfill_threshold_usage,
cast(round(attr.accmltd_usage/1024/1024) as int64) AS value_usage_in_mb 
FROM lms_booking_info_sim a
LEFT JOIN highest_rank b ON a.subscribermsisdn = b.subscribermsisdn AND a.rank_number = b.rnk
LEFT JOIN lms_booking_info_sim c ON a.subscribermsisdn = c.subscribermsisdn AND c.rank_number = 1
LEFT JOIN `data-dtptechm-prd-c7ca.dwh.angie_activations` aa ON a.subscribermsisdn = aa.msisdn
LEFT JOIN `data-dtptechm-prd-c7ca.dwh.sbscrptn_attribs` attr ON a.subscribermsisdn = attr.sbscrptn_msisdn AND attr.rank_ind = 1
JOIN `data-dtptechm-prd-c7ca.dwh.angie_hrchy_dim` ahd ON (CASE 
	WHEN a.rank_number <> 1 THEN a.retailerqrcode
	WHEN c.rank_number = 1 THEN c.retailerqrcode
END) = ahd.partner_qr_cd AND ahd.partner_status = 'Active'
WHERE date(a.bookingdatetime) 
		--BETWEEN dwh.get_current_mtd_cycle_date_sk_id('ETL_DAILY_LOAD') AND dwh.get_cycle_date_sk_id('ETL_DAILY_LOAD')
		between date_trunc(date(vdt_id),MONTH) and date(vdt_id)
),
fwa_ga as (
select 
a.sbscrptn_ek_id, sa.sbscrptn_msisdn , sa.call_plan_desc , sa.promo_desc, date(sa.activation_dtm) as activation_dt, a.dt as ga_dt,
a.site_id ,
site.cluster_nm_3id as cluster,
site.sales_area,
site.region_circle,
site.circle  
from `data-bi-prd-935c.bi_mart.fct_ga_site_id` a
			left outer join `data-dtptechm-prd-c7ca.dwh.sbscrptn_attribs` sa on cast(a.sbscrptn_ek_id as int64) = sa.sbscrptn_ek_id
			left outer join `data-bi-prd-935c.bi_mart.ref_site_h3i` site on coalesce(a.site_id,'NA')=coalesce(site.site_id,'NA')
	where (UPPER(sa.promo_desc) like '%FWA%' or UPPER(call_plan_desc) like '%FWA%')
	and date(dt) between date_trunc(date(vdt_id),month) and date(vdt_id)
)
select 
'3ID' as brand,
GA_dt,
sbscrptn_msisdn as msisdn,
site_id ,
cluster,
sales_area,
region_circle,
circle,
tagging,
trx_retailer as trx_retailer,
booking_by as retailer_qrcode,
retailer_nm,
booking_date,
current_timestamp() as load_dt
from 
(
	select 
	row_number()over(partition by sbscrptn_msisdn order by booking_date desc nulls last) as seqno,
	case when b.msisdn is not null then 'Y' else 'N' end as tagging,
	* from fwa_ga a 
		left outer join sim_tagging b on a.sbscrptn_msisdn = b.msisdn and a.ga_dt >= coalesce(date(b.booking_date),date('1900-01-01'))
												and b.status = 'REGISTERED'
) a 
where seqno = 1
order by ga_dt, a.sbscrptn_msisdn;
end
