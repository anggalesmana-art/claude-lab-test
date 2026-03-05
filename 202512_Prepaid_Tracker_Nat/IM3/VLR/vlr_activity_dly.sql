declare vdt_id date default @vdt_id;

--- Temp SGE Incoming
create or replace table `data-bi-prd-935c.bi_mart`.tmp_vlr_activity_inc_sge_{{ vdt_id }} as
select coalesce(a.msisdn,b.msisdn) msisdn
  , concat( ifnull(a.usg_flag,''), ifnull(b.usg_flag,'') ) usg_flag
  , concat( ifnull(a.usg_flag_detail,''), ifnull(b.usg_flag_detail,'') ) usg_flag_detail
from
(
  select msisdn, 'S' usg_flag, usg_flag usg_flag_detail
  from `data-bi-prd-935c.bi_mart`.sge_dly
  where dt_id = vdt_id
) a
full join
(
  select distinct b_p_num msisdn, 'I' usg_flag, 'I' usg_flag_detail
  FROM `data-bi-prd-935c.bi_mart`.msc_dly
  where service_type in ('SMSMT','MTC')
    --AND Length(a_p_num) > 10
    AND SubStr(b_p_num,1,5) IN ('62814', '62815', '62816', '62855', '62856', '62857', '62858')
    --AND SubStr(a_p_num,1,3) = '628'
    and dt_id = vdt_id
) b
  on a.msisdn=b.msisdn
;


--- Temp SDP Status
create or replace table `data-bi-prd-935c.bi_mart`.tmp_vlr_activity_sdp_status_{{ vdt_id }} as
select case
		when b.offer_id=4444 then 'Active 1'
		when b.offer_id=4443 then 'Unpair'
		else 'Active 2'
	end flag_status
	, a.msisdn msisdn
from `data-dtp-prd-aa1a.smy`.ar_cst_dly_smy a
left join
(
	select msisdn, offer_id
	from
	(
		select concat('62',regexp_replace(account_id,'[^[:digit:]]','')) msisdn, offer_id
			, row_number() over(partition by regexp_replace(account_id,'[^[:digit:]]','') order by case when offer_id=4443 then 1 else 2 end) rk
		from `data-dtp-prd-aa1a.stg`.stg_sdp_ofr
		where offer_id in (4444,4443)
		and date(dt_id) = vdt_id
	) x
	where rk=1 and length(msisdn)>=10
) b
	on a.msisdn=b.msisdn
where date(a.dt_id) = vdt_id
;


--- Temp Subs Flag
create or replace table `data-bi-prd-935c.bi_mart`.tmp_vlr_activity_subs_flag_{{ vdt_id }} as
select msisdn, regexp_replace(subs_flag, substr(subs_flag,1,3), '') subs_flag, date(actvn_dt) actvn_dt, svc_class_code
from
(
  select msisdn, subs_flag, actvn_dt, svc_class_code
    , row_number() over(partition by msisdn order by subs_flag) as rk
  from
  (
    select distinct msisdn, '2. Postpaid B2C' subs_flag, actvn_dt, sc_id svc_class_code
    from `data-dtp-prd-aa1a.smy`.ar_cst_pstpaid_rtl
    where date(dt_id) = vdt_id
    union all
    select distinct msisdn, '3. Prepaid B2B' subs_flag, actvn_dt, svc_class_code
    from `data-dtp-prd-aa1a.smy`.ar_cst_dly_smy
    where date(dt_id) = vdt_id and svc_class_code in (select svc_class_code from `data-bi-prd-935c.bi_mart`.ref_sc_b2b)
    union all
    select distinct msisdn, '4. Prepaid B2C' subs_flag, actvn_dt, svc_class_code
    from `data-dtp-prd-aa1a.smy`.ar_cst_dly_smy
    where date(dt_id) = vdt_id and svc_class_code not in (select svc_class_code from `data-bi-prd-935c.bi_mart`.ref_sc_b2b)
    union all
    select distinct msisdn, '5. Propaid' subs_flag, actvn_dt, svc_class_code
    from  `data-dtp-prd-aa1a.smy`.ar_cst_propaid_smy
    where date(dt_id) = vdt_id
    union all
    select regexp_replace(svc_id,'[^[:digit:]]','') msisdn, '1. Postpaid B2B' subs_flag, actvn_dt, NULL svc_class_code
    from
    (
      select a.*, row_number() over(partition by regexp_replace(svc_id,'[^[:digit:]]','') order by case when ast_st='Active' then 1 when ast_st='Suspended' then 2 else 3 end) rk
      from `data-dtp-prd-aa1a.smy`.ar_cst_pstpaid_b2b a
      where date(dt_id) = vdt_id  and ifnull(a.svc_id,'')!=''
    ) x
    where rk=1
  ) x
) x
where rk=1
;


--- Insert to master table
delete from `data-bi-prd-935c.bi_mart`.vlr_activity_dly where dt_id = vdt_id;
insert into  `data-bi-prd-935c.bi_mart`.vlr_activity_dly
select a.msisdn, a.site_id
  , b.subs_flag, b.actvn_dt, b.svc_class_code
  , c.usg_flag, c.usg_flag_detail
  , case when a.dt_id=d.dt_id and a.msisdn=d.msisdn then 'YES' else 'NO' end rgu_flag
  , case when a.dt_id=d.dt_id and a.msisdn=d.msisdn then d.rgu_usg_flag else NULL end rgu_usg_flag
  , case when a.msisdn=e.msisdn then e.first_rgu else NULL end first_rgu
  , case when a.msisdn=f.msisdn then f.flag_status else NULL end flag_status
  , timestamp(current_datetime('+7')) ppn_dttm
  , a.dt_id
from
(
  select distinct date(dt_id) dt_id, msisdn, site_id
  from `data-bi-prd-935c.bi_dm`.vlr_site_wise
  where date(dt_id) = vdt_id
) a
left join `data-bi-prd-935c.bi_mart`.tmp_vlr_activity_subs_flag_{{ vdt_id }} b
  on a.msisdn=b.msisdn
left join `data-bi-prd-935c.bi_mart`.tmp_vlr_activity_inc_sge_{{ vdt_id }} c
  on a.msisdn=c.msisdn
left join
(
  select dt_id, msisdn, usg_flag rgu_usg_flag
  from `data-bi-prd-935c.bi_mart`.rgs_nogovt_dly
  where dt_id = vdt_id
    and (flag_status='Active 2' or ifnull(total_rev,0)>0)
) d
  on a.msisdn=d.msisdn
left join
(
  select msisdn, first_rgu
  from `data-bi-prd-935c.bi_mart`.first_rgs_govt
  where mth_id = date_trunc(vdt_id,month)
) e
  on a.msisdn=e.msisdn
left join `data-bi-prd-935c.bi_mart`.tmp_vlr_activity_sdp_status_{{ vdt_id }} f
  on a.msisdn=f.msisdn
;

/*
--- insert into summary table
insert overwrite table `data-bi-prd-935c.bi_mart`.vlr_activity_dly_smy partition(dt_id)
select subs_flag
  , case
    when usg_flag='S' then 'MO Only'
    when usg_flag='I' then 'MT Only'
    when usg_flag='SI' then 'MO+MT'
    else 'No Activity'
  end usg_flag
  , count(1) subs
  , timestamp(current_datetime('+7')) ppn_dttm
  , dt_id
from `data-bi-prd-935c.bi_mart`.vlr_activity_dly
where dt_id = vdt_id
group by subs_flag, usg_flag, dt_id
;
*/


--- insert into summary table
delete from `data-bi-prd-935c.bi_mart`.vlr_activity_smy where dt_id = vdt_id and kpi_nm = 'VLR_DAILY';
insert into `data-bi-prd-935c.bi_mart`.vlr_activity_smy
select subs_flag
    , case
        when usg_flag='S' then 'MO Only'
        when usg_flag='I' then 'MT Only'
        when usg_flag='SI' then 'MO+MT'
        else 'No Activity'
    end usg_flag
    , CASE
        WHEN date_diff(dt_id,ifnull(first_rgu,actvn_dt),day) <= 30 THEN 'a.1-30 Days'
        WHEN date_diff(dt_id,ifnull(first_rgu,actvn_dt),day) <= 60 THEN 'b.31-60 Days'
        WHEN date_diff(dt_id,ifnull(first_rgu,actvn_dt),day) <= 90 THEN 'c.61-90 Days'
        WHEN date_diff(dt_id,ifnull(first_rgu,actvn_dt),day) >  90 THEN 'd.> 90 Days'
    END tenure
    , site_id
    , count(1) metric
    , timestamp(current_datetime('+7')) ppn_dttm, 'VLR_DAILY' kpi_nm, dt_id
from `data-bi-prd-935c.bi_mart`.vlr_activity_dly
where dt_id = vdt_id
group by subs_flag, usg_flag, tenure, site_id, dt_id
;


--- Drop Temp Table
drop table if exists `data-bi-prd-935c.bi_mart`.tmp_vlr_activity_inc_sge_{{ vdt_id }};
drop table if exists `data-bi-prd-935c.bi_mart`.tmp_vlr_activity_sdp_status_{{ vdt_id }};
drop table if exists `data-bi-prd-935c.bi_mart`.tmp_vlr_activity_subs_flag_{{ vdt_id }};
