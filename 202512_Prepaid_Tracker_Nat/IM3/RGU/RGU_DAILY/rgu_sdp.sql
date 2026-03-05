--Script Migrated by Indra Maulana Ikhsan 20241120
--- SDP Prepaid (A1 or A2)
declare vdt_id date default @vdt_id;
create or replace table `data-bi-prd-935c.bi_mart`.tmp_rgu_sdp_{{ vdt_id }}  as
with ofr as (
  select msisdn, offer_id
	from
	(
		select concat('62',regexp_replace(account_id,'[^[:digit:]]','')) msisdn, offer_id
			, row_number() over(partition by regexp_replace(account_id,'[^[:digit:]]','') order by case when offer_id=4443 then 1 else 2 end) rk
		from `data-dtp-prd-aa1a.stg.stg_sdp_ofr`
		where date(dt_id) = vdt_id
      and offer_id in (4444,4443)
	) x
	where rk=1 and length(msisdn)>=10
)
select case
		when b.offer_id=4444 then 'Active 1'
		when b.offer_id=4443 then 'Unpair'
		else 'Active 2'
	end flag_status
	, cast(a.actvn_dt as string) actvn_dt
	, cast(a.svc_class_code as string) svc_class_code
	, a.msisdn msisdn
from `data-dtp-prd-aa1a.smy.ar_cst_dly_smy` a
left join ofr b
	on a.msisdn=b.msisdn
where date(dt_id) = vdt_id
	--and lower(brand_sc_name) in ('im3','mentari')
;