BEGIN
DECLARE vdt_id date default @vdt_id;

--- 01. dump table fwa subs
truncate table `data-bi-prd-935c.bi_mart.fwa_subs`;
insert into `data-bi-prd-935c.bi_mart.fwa_subs`
select sbscrptn_ek_id from `data-dtptechm-prd-c7ca.dwh.sbscrptn_attribs` sa 
where (UPPER(sa.promo_desc) like '%FWA%' or UPPER(sa.call_plan_desc) like '%FWA%');

--01. RGUGA
delete from `data-bi-prd-935c.bi_mart.fwa_mart` a where a.kpi_nm = 'RGUGA' and time_flag = 'dly' and dt_id = date(vdt_id);
insert into `data-bi-prd-935c.bi_mart.fwa_mart` (dt_id, brand, kpi_nm, attr_nm, attr_value, time_flag, metric_value, created_dtm)
select
fct.dt,
'3ID' as brand,
'RGUGA' as kpi_nm,
'siteid' as attr_nm,
case when length(fct.site_id) <= 5 then LPAD(fct.site_id,6,'0') else fct.site_id end as attr_val,
'dly' as time_flag,
count(distinct fct.sbscrptn_ek_id) as metric_value,
current_timestamp() as created_dtm
from `data-bi-prd-935c.bi_mart.fct_ga_site_id` fct
	--join dwh.sbscrptn_attribs sa on fct.sbscrptn_ek_id = sa.sbscrptn_ek_id and sa.promo_desc like '%FWA%'
	join `data-bi-prd-935c.bi_mart.fwa_subs` sa on cast(fct.sbscrptn_ek_id as int64) = sa.sbscrptn_ek_id
where fct.dt = date(vdt_id)
group by 1,2,3,4,5,6;

--raise INFO '[FWA - Subs] Generate Gross Churn  at %',timeofday();
--02. GrossChurn 90
delete from `data-bi-prd-935c.bi_mart.fwa_mart` a where a.kpi_nm = 'GROSSCHURN90' and time_flag = 'dly' and a.dt_id = date(vdt_id);
insert into `data-bi-prd-935c.bi_mart.fwa_mart` (dt_id, brand, kpi_nm, attr_nm, attr_value, time_flag, metric_value, created_dtm)
select 
a.dt, 
'3ID' as brand,
'GROSSCHURN90' as kpi_nm,
'siteid_90' as attr_nm,
case when length(a.site_id) <= 5 then LPAD(a.site_id,6,'0') else a.site_id end as attr_val,
'dly' as time_flag, 
count(distinct a.sbscrptn_ek_id) as metric_value,
current_timestamp()
from `data-bi-prd-935c.bi_mart.fct_gc_aon_rev_3` a
left outer join `data-bi-prd-935c.bi_mart.ref_site_h3i` c on case 
												when length(a.site_id) <= 5 then LPAD(a.site_id,6,'0') 
											else a.site_id 
											end = case 
													when length(c.site_id) <= 5 then LPAD(c.site_id,6,'0') 
												  else c.site_id end
--join dwh.sbscrptn_attribs sa on fct.sbscrptn_ek_id = sa.sbscrptn_ek_id and sa.promo_desc like '%FWA%'
join `data-bi-prd-935c.bi_mart.fwa_subs` sa on cast(a.sbscrptn_ek_id as int64) = sa.sbscrptn_ek_id
where a.dt = date(vdt_id)
group by 1,2,3,4,5,6;

--raise INFO '[FWA - Subs] Generate Churn Back  at %',timeofday();
--03. Churnback 90
delete from `data-bi-prd-935c.bi_mart.fwa_mart` a where a.kpi_nm = 'CHURNBACK90' and time_flag = 'dly' and dt_id = date(vdt_id);
insert into `data-bi-prd-935c.bi_mart.fwa_mart`(dt_id, brand, kpi_nm, attr_nm, attr_value, time_flag, metric_value, created_dtm)
select 
a.dt, 
'3ID' as brand,
'CHURNBACK90' as kpi_nm,
'siteid_90' as lvl,
case when length(a.site_id) <= 5 then LPAD(a.site_id,6,'0') else a.site_id end as site_id,
'dly' as time_flag, 
count(distinct a.sbscrptn_ek_id) as subs,
current_timestamp()
from `data-bi-prd-935c.bi_mart.fct_cb_aon_rev` a
--join dwh.sbscrptn_attribs sa on fct.sbscrptn_ek_id = sa.sbscrptn_ek_id and sa.promo_desc like '%FWA%'
join `data-bi-prd-935c.bi_mart.fwa_subs` sa on cast(a.sbscrptn_ek_id as int64) = sa.sbscrptn_ek_id
left outer join `data-bi-prd-935c.bi_mart.ref_site_h3i` c on case when length(a.site_id) <= 5 then LPAD(a.site_id,6,'0') else a.site_id end 
												= case when length(c.site_id) <= 5 then LPAD(c.site_id,6,'0') else c.site_id end
where a.dt = date(vdt_id)
group by 1,2,3,4,5,6;


---- MTD
--raise INFO '[FWA - Subs] Generate RGU90  at %',timeofday();
--01. RGU90 - Closing
delete from `data-bi-prd-935c.bi_mart.fwa_mart` a where a.kpi_nm = 'RGU90' and time_flag = 'mtd' and dt_id = date(vdt_id);
insert into `data-bi-prd-935c.bi_mart.fwa_mart` (dt_id, brand, kpi_nm, attr_nm, attr_value, time_flag, metric_value, created_dtm)
select
a.dt,
'3ID' as brand,
'RGU90' as kpi_nm,
'siteid_90' as lvl,
case when length(a.site_id) <= 5 then LPAD(a.site_id,6,'0') else a.site_id end as site_id,
'mtd' as time_flag, 
count(distinct a.sbscrptn_ek_id) as metric_value,
current_timestamp()
from `data-bi-prd-935c.bi_mart.fct_rgu90_aging_circle_arpu` a 
--join dwh.sbscrptn_attribs sa on fct.sbscrptn_ek_id = sa.sbscrptn_ek_id and sa.promo_desc like '%FWA%'
join `data-bi-prd-935c.bi_mart.fwa_subs` sa on cast(a.sbscrptn_ek_id as int64) = sa.sbscrptn_ek_id
		left outer join `data-bi-prd-935c.bi_mart.ref_site_h3i` c on case 
														when length(a.site_id) <= 5 then LPAD(a.site_id,6,'0') 
													else a.site_id 
													end = case 
															when length(c.site_id) <= 5 then LPAD(c.site_id,6,'0') 
														  else c.site_id end
where 
a.dt = date(vdt_id)
group by 1,2,3,4,5,6;

--raise INFO '[FWA - Subs] done  at %',timeofday();
--END $$;

/*

--01. RGUGA
delete from fwa_mart a where a.kpi_nm = 'RGUGA' and time_flag = 'mtd' and dt_id = 20250714;
insert into fwa_mart(dt_id, brand, kpi_nm, attr_nm, attr_val, time_flag, metric_value, created_dtm)
select
to_char(date_trunc('month', fct.dt::text::date+interval'1 month')::date -1,'YYYYMMDD')::int as dt_id ,
'3ID' as brand,
'RGUGA' as kpi_nm,
'siteid' as attr_nm,
case when length(fct.site_id) <= 5 then LPAD(fct.site_id,6,'0') else fct.site_id end as attr_val,
'mtd' as time_flag,
count(distinct a.sbscrptn_ek_id) as metric_value,
now() as created_dtm
from mis.fct_ga_site_id fct
	join dwh.sbscrptn_attribs sa on a.sbscrptn_ek_id = sa.sbscrptn_ek_id AND sa.promo_desc like '%FWA%'
where 
a.dt between to_char(date_trunc('month',20250714::text::date),'YYYYMMDD')::int and 20250714
group by 1,2,3,4,5,6;


--02. GrossChurn 90
delete from fwa_mart a where a.kpi_nm = 'GROSSCHURN90' and time_flag = 'mtd' and dt_id = 20250714;
insert into fwa_mart(dt_id, brand, kpi_nm, attr_nm, attr_val, time_flag, metric_value, created_dtm)
select 
to_char(date_trunc('month', fct.dt::text::date+interval'1 month')::date -1,'YYYYMMDD')::int as dt_id, 
'3ID' as brand,
'GROSSCHURN90' as kpi_nm,
'siteid_90' as attr_nm,
case when length(a.site_id) <= 5 then LPAD(a.site_id,6,'0') else a.site_id end as attr_val,
'mtd' as time_flag, 
count(distinct a.sbscrptn_ek_id) as metric_value,
now()
from mis.fct_gc_aon_rev_3 a
left outer join ioh_biadm.ref_site_h3i c on case 
												when length(a.site_id) <= 5 then LPAD(a.site_id,6,'0') 
											else a.site_id 
											end = case 
													when length(c.site_id) <= 5 then LPAD(c.site_id,6,'0') 
												  else c.site_id end
join dwh.sbscrptn_attribs sa on a.sbscrptn_ek_id = sa.sbscrptn_ek_id and UPPER(promo_desc) like '%FWA%' 
where 
a.dt between to_char(date_trunc('month',20250714::text::date),'YYYYMMDD')::int and 20250714
group by 1,2,3,4,5,6;

--03. Churnback 90
delete from fwa_mart a where a.kpi_nm = 'CHURNBACK90' and time_flag = 'mtd' and dt_id = 20250714;
insert into fwa_mart(dt_id, brand, kpi_nm, attr_nm, attr_val, time_flag, metric_value, created_dtm)
select 
to_char(date_trunc('month', fct.dt::text::date+interval'1 month')::date -1,'YYYYMMDD')::int as dt_id, 
'3ID' as brand,
'CHURNBACK90' as kpi_nm,
'siteid_90' as lvl,
case when length(a.site_id) <= 5 then LPAD(a.site_id,6,'0') else a.site_id end as site_id,
'mtd' as time_flag, 
count(distinct a.sbscrptn_ek_id) as subs,
now()
from mis.fct_cb_aon_rev a
join dwh.sbscrptn_attribs sa on a.sbscrptn_ek_id = sa.sbscrptn_ek_id and UPPER(promo_desc) like '%FWA%' 
left outer join ioh_biadm.ref_site_h3i c on case when length(a.site_id) <= 5 then LPAD(a.site_id,6,'0') else a.site_id end 
												= case when length(c.site_id) <= 5 then LPAD(c.site_id,6,'0') else c.site_id end
WHERE a.dt between to_char(date_trunc('month',20250714::text::date),'YYYYMMDD')::int and 20250714
group by 1,2,3,4,5,6;


*/
END