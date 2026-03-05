--------------------------------------------------------------------------------------------------------------------------------------------------
DECLARE observation_date DATE DEFAULT @vdt_id;
DECLARE start_current_month  DATE DEFAULT DATE_TRUNC(observation_date, MONTH);
DECLARE eop_previous_month DATE DEFAULT LAST_DAY(DATE_SUB(observation_date, INTERVAL 1 MONTH));
DECLARE start_previous_month DATE DEFAULT DATE_TRUNC(LAST_DAY(DATE_SUB(observation_date, INTERVAL 1 MONTH)), MONTH);


-- insert overwrite table biadm.rk_pstpaid_tracker_ga_region_v2 partition(dt_id)
delete from `data-bi-prd-935c.bi_dev.pstpaid_tracker_ga_region_v2`
where date(dt_id) = observation_date;

insert into `data-bi-prd-935c.bi_dev.pstpaid_tracker_ga_region_v2`
WITH ref_store as (
    select store_code territory_id, circle, region region_circle, area, branch
    from `data-bi-prd-935c.bi_mart.pstpaid_store_ref_new`
    where coalesce(TRIM(UPPER(circle)),'') not in ('OTHERS','')
    and TRIM(UPPER(store_code)) not in (
        'JKBB',
        'JKBA',
        'ESEP',
        'LOC0'
    )
),
ref_dealer as (
    select 
        territory_id,
        circle,
        region_circle,
        area,
        branch
    from `data-bi-prd-935c.bi_mart.ref_pstpaid_rtl_dealer_test`
    where coalesce(TRIM(UPPER(branch)),'') not in ('OTHERS','')
),
ref_store_dealer as (
  select distinct coalesce(a.territory_id,b.territory_id) as territory_id,
    coalesce(a.circle, b.circle) as circle,
    coalesce(a.region_circle, b.region_circle) as region,
    coalesce(a.area,b.area) as area,
    coalesce(a.branch,b.branch) as branch
  from ref_store a
  full join ref_dealer b
    on a.territory_id=b.territory_id
),
ref_territory as (
    select 
        upper(territory_id) territory_id, 
        case
            when upper(circle) = '' then null
            when upper(circle) = 'OTHERS' then null
            when upper(circle) = 'OTHERS' then null
            else upper(circle)
        end as circle,
        case
            when upper(region) = '' then null
            when upper(region) = 'UNKNOWN' then null
            when upper(region) = 'OTHERS' then null
            else upper(region)
        end as region_circle,
        case
            when upper(area) = '' then null
            when upper(area) = 'UNKNOWN' then null
            when upper(area) = 'OTHERS' then null
            else upper(area)
        end as area,
        case
            when upper(branch) = '' then null
            when upper(branch) = 'UNKNOWN' then null
            when upper(branch) = 'OTHERS' then null
            else upper(branch)
        end as branch
    from (
        select territory_id, circle, region, area, branch
        from ref_store_dealer
        union all
        select site_id as territory_id, circle, region_circle as region, area, sales_area branch
        from `data-bi-prd-935c.bi_mart.ref_site`
    ) a
),
GROSSADDCLEAN AS (
    select 
        a.*
    from `data-bi-prd-935c.bi_mart.cst_pstpaid_ga_detail_v3` a 
    where a.dt_id = observation_date
	and a.flag like '%2%'
),
GROSSADDORDER AS (
    select
        b.circle circle,
        b.region_circle region_circle,
        b.area area,
        b.branch branch,
		case
		  when order_type='Migration' then 'post_ga_reg_order_migration'
		  when order_type='New Registration' then 'post_ga_reg_order_new_migration'
		  when order_type='Port In Migration' then 'post_ga_reg_order_port_in_migration'
		  else 'post_ga_reg_order_unknown'
		end kpi,
		count(distinct msisdn) value,
		dt_id
	from GROSSADDCLEAN a
	left join ref_territory b
    on TRIM(UPPER(a.territory_ola_site_id))=TRIM(UPPER(b.territory_id))
	group by 1,2,3,4,5,7

	union all

	select
		b.circle circle,
        b.region_circle region_circle,
        b.area area,
        b.branch branch,
		'post_ga_reg_order_total' kpi_code,
		count(distinct msisdn) value,
		dt_id
	from GROSSADDCLEAN a
	left join ref_territory b
    on TRIM(UPPER(a.territory_ola_site_id))=TRIM(UPPER(b.territory_id))
	group by 1,2,3,4,5,7
),
GROSSADDPACKAGE AS (
    select
		b.circle circle,
        b.region_circle region_circle,
        b.area area,
        b.branch branch,
		CASE
		  WHEN UPPER(TRIM(subscription_type)) = 'MONTHLY' THEN 'post_ga_reg_pkg_monthly'
		  WHEN UPPER(TRIM(subscription_type)) = 'POSTPAID BASIC' then 'post_ga_reg_pkg_monthly'
		  WHEN UPPER(TRIM(subscription_type)) = 'CONTRACT' AND UPPER(TRIM(contract_status)) = '03 - MONTHS' THEN 'post_ga_reg_pkg_contract_3'
		  WHEN UPPER(TRIM(subscription_type)) = 'CONTRACT' AND UPPER(TRIM(contract_status)) = '06 - MONTHS' THEN 'post_ga_reg_pkg_contract_6'
		  WHEN UPPER(TRIM(subscription_type)) = 'CONTRACT' AND UPPER(TRIM(contract_status)) = '12 - MONTHS' THEN 'post_ga_reg_pkg_contract_12'
		  WHEN UPPER(TRIM(subscription_type)) = 'CONTRACT' AND UPPER(TRIM(contract_status)) = '24 - MONTHS' THEN 'post_ga_reg_pkg_contract_24'
		  ELSE 'post_ga_reg_pkg_others'
		END kpi_code,
		count(distinct msisdn) value,
		dt_id
	from GROSSADDCLEAN a
	left join ref_territory b
    on TRIM(UPPER(a.territory_ola_site_id))=TRIM(UPPER(b.territory_id))
	where flag like '%2%'
	group by 1,2,3,4,5,7

	union all

	select
		b.circle circle,
        b.region_circle region_circle,
        b.area area,
        b.branch branch,
		'post_ga_reg_pkg_total' kpi_code,
		count(distinct msisdn) value,
		dt_id
	from GROSSADDCLEAN a
	left join ref_territory b
    on TRIM(UPPER(a.territory_ola_site_id))=TRIM(UPPER(b.territory_id))
	where flag like '%2%'
	group by 1,2,3,4,5,7
),
GROSSADDCHANNEL AS (
    select
		b.circle circle,
        b.region_circle region_circle,
        b.area area,
        b.branch branch,
		case
		  when UPPER(trim(channel_group)) like '%GERAI%' then 'post_ga_reg_channel_gerai_outcall_agent'
		  when UPPER(trim(channel_group)) = 'DIRECT SALES' then 'post_ga_reg_channel_gerai_outcall_agent'
		  when UPPER(trim(channel_group)) = 'OUTCALL AGENT' then 'post_ga_reg_channel_gerai_outcall_agent'
		  when UPPER(trim(channel_group)) = 'IPP' then 'post_ga_reg_channel_gerai_outcall_agent'
		  when UPPER(trim(channel_group)) = 'SDP' then 'post_ga_reg_channel_gerai_outcall_agent'
		  when UPPER(trim(channel_group)) = 'DST' then 'post_ga_reg_channel_gerai_outcall_agent'
		  when UPPER(trim(channel_group))='FRANCHISE' then 'post_ga_reg_channel_franchise'
		  when UPPER(trim(channel_group))='ONLINE CHANNEL' then 'post_ga_reg_channel_online'
		  when UPPER(trim(channel_group))='OLA' then 'post_ga_reg_channel_online'
		  when UPPER(trim(channel_group))='OLA RETAIL' then 'post_ga_reg_channel_online'
		  when UPPER(trim(channel_group))='SMB' then 'post_ga_reg_channel_smb'
		  when UPPER(trim(channel_group))='ALTERNATE CHANNEL' then 'post_ga_reg_channel_altchannel'
		  when UPPER(trim(channel_group))='OTHERS' then 'post_ga_reg_channel_others'
		  when UPPER(trim(channel_group)) ='NULL' or UPPER(trim(channel_group)) is null then 'post_ga_reg_channel_unknown'
		  when UPPER(trim(channel_group)) = 'PARTNER STORE NON-ERA' then 'post_ga_reg_channel_partner'
		  when UPPER(trim(channel_group)) = 'PARTNER STORE ERA' then 'post_ga_reg_channel_partner_era'
		  else 'post_ga_reg_channel_others'
		end kpi,
		count(distinct msisdn) value,
		dt_id
	from GROSSADDCLEAN a
	left join ref_territory b
    on TRIM(UPPER(a.territory_ola_site_id))=TRIM(UPPER(b.territory_id))
	where flag like '%2%'
	group by 1,2,3,4,5,7

	union all

	select
		b.circle circle,
        b.region_circle region_circle,
        b.area area,
        b.branch branch,
		'post_ga_reg_channel_total' kpi_code,
		count(distinct msisdn) value,
		dt_id
	from GROSSADDCLEAN a
	left join ref_territory b
    on TRIM(UPPER(a.territory_ola_site_id))=TRIM(UPPER(b.territory_id))
	where flag like '%2%'
	group by 1,2,3,4,5,7
),
ALLGA AS (
    select * from GROSSADDORDER
    union all
    select * from GROSSADDPACKAGE
    union all
    select * from GROSSADDCHANNEL
)    
select
    'IM3' brand,
    'POSTPAID' page,
    circle,
    region_circle,
    area,
    branch,
    kpi,
    'MTD' flag,
    sum(value) value,
    dt_id
from ALLGA a
group by 1,2,3,4,5,6,7,8,10;