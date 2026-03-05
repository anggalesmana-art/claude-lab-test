declare vdt_id date default @vdt_id;
---------------- sdp_live  ----------------
delete from  `data-bi-prd-935c.bi_dev`.ioh_snd_master_kpi_detail where dt_id = vdt_id and kpi = 'sdp_live' and brand = 'IM3';
insert into `data-bi-prd-935c.bi_dev`.ioh_snd_master_kpi_detail 
select brand, 'partner' level, partner_shortcode as level_value, 
    cast(count(distinct partner_shortcode) as numeric) value, 
    'mtd' as time_flag, 
     timestamp(current_datetime('+7')) as insert_date,
    'sdp_live' as kpi_id, 
    vdt_id as dt_id
from `data-bi-prd-935c.bi_snd.pre_ref_hirarki_territory_ioh`
where parse_date('%Y%m',cast(mth as string)) = date_trunc(vdt_id,month) and brand = 'IM3' and pt_type = 'SDP'
group by 1,2,3,5,6,7,8
;


-- ---------------- sdp_trx  ----------------

delete from  `data-bi-prd-935c.bi_dev`.ioh_snd_master_kpi_detail where dt_id = vdt_id and kpi = 'sdp_trx' and brand = 'IM3';
insert into `data-bi-prd-935c.bi_dev`.ioh_snd_master_kpi_detail 
select 'IM3' brand, 'partner' level, partner as level_value, 
    cast(count(distinct partner) as numeric) value, 
    'mtd' as time_flag, 
     timestamp(current_datetime('+7')) as insert_date,
    'sdp_trx' as kpi_id, 
    vdt_id as dt_id
    from 
(
        select a.*, mth_id, parent_org_id, parent_org_nm, secondary,organization_id, amt_primary,
        case when parent_org_id is null then 0 else 1 end secondary_flag,
        case when organization_id is null then 0 else 1 end primary_flag
        from 
        (
        select 
        -- distinct partner -- feb24 s/d Jan25 
        distinct partner_shortcode partner -- feb25 onward
        from `data-bi-prd-935c.bi_snd.pre_ref_hirarki_territory_ioh`
        where parse_date('%Y%m',cast(mth as string)) = date_trunc(vdt_id,month) and brand = 'IM3' and pt_type = 'SDP'
        )a
        left join
        (
            select a.*, b.organization_id, b.amt_primary 
            from 
                (
                select date_trunc(vdt_id,month) mth_id, parent_org_id, parent_org_nm, sum(amount) secondary
                from `data-bi-prd-935c.bi_mart`.fact_snd_secondary_dtl
                where dt_id between date_trunc(vdt_id,month) and vdt_id 
                and parent_org_id like 'SDP%'
                group by 1,2,3
                )a
            left join
            (
            select date_trunc(vdt_id,month) mth_id, organization_id, sum(amount) amt_primary
            from `data-bi-prd-935c.bi_mart`.fact_snd_primary 
            where dt_id between date_trunc(vdt_id,month) and vdt_id 
            and organization_id like 'SDP%'
            group by 1,2
            )b
            on a.parent_org_id=b.organization_id
        )b
         on a.partner=b.parent_org_id
)a
where secondary_flag = 1 or primary_flag = 1
group by 1,2,3,5,6,7,8
;


-- ----------------  sdp_350_GA  ----------------

delete from  `data-bi-prd-935c.bi_dev`.ioh_snd_master_kpi_detail where dt_id = vdt_id and kpi = 'sdp_350_GA' and brand = 'IM3';
insert into `data-bi-prd-935c.bi_dev`.ioh_snd_master_kpi_detail 
with 
ga as (
    select *  from 
            (
                select a.msisdn, a.dt_id ga_dt, a.site_id, organization_id, flag_quality, main_price_acm2, flag_sp,channel_grp
                 from `data-bi-prd-935c.bi_mart`.rgs_ga_90d_dly_govt a
                join (select *
                        from `data-bi-prd-935c.bi_mart`.rgs_ga_channel_mth_govt 
                        where ga_dt between date_trunc(vdt_id,month) and vdt_id 
                        and channel_grp ='TRADITIONAL'
                      )b
                on a.msisdn = b.msisdn and a.dt_id = b.ga_dt
                where dt_id between date_trunc(vdt_id,month) and vdt_id 
                and (churn_back = 'NO' or recycled = 'YES')
            )x 
        ),
hirarki as (
            select id, kec_unik, partner
                from 
                    (
                    select * from  `data-bi-prd-935c.bi_snd.pre_ref_lowlevel_mth_im3`
                    where parse_date('%Y%m',cast(mth as string)) = date_trunc(vdt_id,month) -- and flag = 'SITE'
                    )a
                left join 
                    (
                    select distinct kecamatan, 
                        -- partner  -- feb24 s/d jan25
                        partner_shortcode partner  -- feb25 on ward
                    from `data-bi-prd-935c.bi_snd.pre_ref_hirarki_territory_ioh`
                    where parse_date('%Y%m',cast(mth as string)) = date_trunc(vdt_id,month) and brand = 'IM3' -- and pt_type = 'SDP'
                    )b 
                on a.kec_unik=b.kecamatan
         )
--SDP with 350 GA
select 'IM3' brand, 'partner' level, partner as level_value, 
    cast(count(distinct partner) as numeric) value, 
    'mtd' as time_flag, 
     timestamp(current_datetime('+7')) as insert_date,
    'sdp_350_GA' as kpi_id, 
    vdt_id as dt_id
    from 
(
    select partner, count(msisdn) rgu_ga
    from 
        (
        select a.*,  partner
            from ga a
        left join hirarki b
            on a.site_id = b.id
        )a
    where partner like 'SDP%'
    group by 1
)a
where rgu_ga >= 350
group by 1,2,3,5,6,7,8
;

----------------  sdp_80_sec  ----------------

delete from  `data-bi-prd-935c.bi_dev`.ioh_snd_master_kpi_detail where dt_id = vdt_id and kpi = 'sdp_80_sec' and brand = 'IM3';
insert into `data-bi-prd-935c.bi_dev`.ioh_snd_master_kpi_detail 
with
secondary as (
        select  date_trunc(dt_id,month) mth_id, organization_id, parent_org_id, parent_org_nm, sum(amount) amt 
        from 
        (
         -- SELLIN SALDO
            select * from `data-bi-prd-935c.bi_mart`.fact_snd_secondary_dtl
            where dt_id between date_trunc(vdt_id,month) and vdt_id 
                and secondary_type = 'SELLIN SALDO'
                and  (upper(organization_id) not like '%DS%'
                            and upper(organization_id) not like '%SF%'
                            and upper(organization_id) not like '%H2H%'
                        )
                and lower(channel_grp) like '%traditional%'
                and parent_org_type in ('Dealer','SDP')
            union all 
            -- SELAIN SELLIN SALDO
            select * from `data-bi-prd-935c.bi_mart`.fact_snd_secondary_dtl
            where dt_id between date_trunc(vdt_id,month) and vdt_id 
                and secondary_type not in  ('SELLIN SALDO')
        )a
        group by 1,2,3,4
            ),
hirarki as (
            select id, kec_unik, partner
                from 
                    (
                    select * from  `data-bi-prd-935c.bi_snd.pre_ref_lowlevel_mth_im3`
                    where parse_date('%Y%m',cast(mth as string)) = date_trunc(vdt_id,month) -- and flag = 'SITE'
                    )a
                left join 
                    (
                    select distinct kecamatan, 
                     --   partner  -- feb24 s/d jan25
                         partner_shortcode partner  -- feb25 on ward
                    from `data-bi-prd-935c.bi_snd.pre_ref_hirarki_territory_ioh`
                    where parse_date('%Y%m',cast(mth as string)) = date_trunc(vdt_id,month) and brand = 'IM3' -- and pt_type = 'SDP'
                    )b 
                on a.kec_unik=b.kecamatan
         )
-- secondary SDP 80mn
select 'IM3' brand, 'partner' level, partner as level_value, 
    cast(count(distinct partner) as numeric) value, 
    'mtd' as time_flag, 
     timestamp(current_datetime('+7')) as insert_date,
    'sdp_80_sec' as kpi_id, 
    vdt_id as dt_id
    from 
    (
        select partner, sum(amt) amt  -- until 5 may 24
            from 
            (
            select a.*, partner
            from secondary a
                left join hirarki b 
            on a.organization_id=b.id
            )a 
        where partner like 'SDP%'
        group by 1 
    )a
where amt >= 80000000
group by 1,2,3,5,6,7,8
;


----------------  total_outlet  ----------------

delete from  `data-bi-prd-935c.bi_dev`.ioh_snd_master_kpi_detail where dt_id = vdt_id and kpi = 'total_outlet' and brand = 'IM3';
insert into `data-bi-prd-935c.bi_dev`.ioh_snd_master_kpi_detail 
select 'IM3' brand, 'site' level, id as level_value, 
    sum(cast(value as numeric)) value, 
    'mtd' as time_flag, 
     timestamp(current_datetime('+7')) as insert_date,
    'total_outlet' as kpi_id, 
    vdt_id as dt_id
from
(
select 
    b.site_id id,
    'SITE' flag,
    count(a.organization_id) value,
    'FM' mthf,
   vdt_id as_of_dt,
    a.mth_id,
    'Total Outlet' parameter
from `data-bi-prd-935c.bi_snd.pre_ref_daily_dump_org_mth` a
left join 
    (
        select * 
        from
            (
                select
                    dt_id,
                    site_id,
                    organization_id,
                    ROW_NUMBER() OVER (partition by organization_id, date_trunc(dt_id,month) ORDER BY dt_id desc) AS rn 
                from
                    `data-bi-prd-935c.bi_mart`.outlet_loc_ns a
                where
                    ((date_trunc(dt_id,month) = date_trunc(vdt_id,month) and a.dt_id <= vdt_id))
            ) a 
        where rn = 1
    ) b 
    on a.organization_id = b.organization_id 
    and parse_date('%Y%m',cast(a.mth_id as string)) = date_trunc(b.dt_id,month)
where 
    parse_date('%Y%m',cast(mth_id as string)) = date_trunc(vdt_id,month)
    and status = 'Active'
    and channel = 'Traditional'
    and region not like 'REGIONAL%'
    and region <> ''
    and length(a.organization_id) >= 1
    and length(a.organization_id) <= 8
    and category not in ('TEST DOWNLINER')
    and lower(organization_type) like 'outlet%'
group by 1,2,4,5,6,7
)a
group by 1,2,3,5,6,7,8
; 




----------------  list_outlet  ----------------

delete from  `data-bi-prd-935c.bi_dev`.ioh_snd_master_kpi_detail where dt_id = vdt_id and kpi = 'list_outlet' and brand = 'IM3';
insert into `data-bi-prd-935c.bi_dev`.ioh_snd_master_kpi_detail 
select 'IM3' brand, 'outlet' level, id as level_value, 
    sum(cast(value as numeric)) value, 
    'mtd' as time_flag, 
     timestamp(current_datetime('+7')) as insert_date,
    'list_outlet' as kpi_id, 
    vdt_id as dt_id
from
(
select 
    a.organization_id id,
    'SITE' flag,
    count(a.organization_id) value,
    'FM' mthf,
   vdt_id as_of_dt,
    a.mth_id,
    'Total Outlet' parameter
from `data-bi-prd-935c.bi_snd.pre_ref_daily_dump_org_mth` a
left join 
    (
        select * 
        from
            (
                select
                    dt_id,
                    site_id,
                    organization_id,
                    ROW_NUMBER() OVER (partition by organization_id, date_trunc(dt_id,month) ORDER BY dt_id desc) AS rn 
                from
                    `data-bi-prd-935c.bi_mart`.outlet_loc_ns a
                where
                    ((date_trunc(dt_id,month) = date_trunc(vdt_id,month) and a.dt_id <= vdt_id))
            ) a 
        where rn = 1
    ) b 
    on a.organization_id = b.organization_id 
    and parse_date('%Y%m',cast(a.mth_id as string)) = date_trunc(b.dt_id,month)
where 
    parse_date('%Y%m',cast(a.mth_id as string)) = date_trunc(vdt_id,month)
    and status = 'Active'
    and channel = 'Traditional'
    and region not like 'REGIONAL%'
    and region <> ''
    and length(a.organization_id) >= 1
    and length(a.organization_id) <= 8
    and category not in ('TEST DOWNLINER')
    and lower(organization_type) like 'outlet%'
group by 1,2,4,5,6,7
)a
group by 1,2,3,5,6,7,8
; 


---------------- total_pjp_outlet ----------------

delete from  `data-bi-prd-935c.bi_dev`.ioh_snd_master_kpi_detail where dt_id = vdt_id and kpi = 'total_pjp_outlet' and brand = 'IM3';
insert into `data-bi-prd-935c.bi_dev`.ioh_snd_master_kpi_detail 
with
outlet_mapping as (
            select distinct id_outlet 
            from `data-bi-prd-935c.bi_snd.pre_ref_outlet_mapping_im3`
            where parse_date('%Y%m', cast(mth_id as string)) = date_trunc(vdt_id,month)
                    )
--- outlet pjp
select 'IM3' brand, 'outlet' level, id_outlet as level_value, 
    cast(count(distinct id_outlet) as numeric) value, 
    'mtd' as time_flag, 
     timestamp(current_datetime('+7')) as insert_date,
    'total_pjp_outlet' as kpi_id, 
    vdt_id as dt_id
from 
    (
    select a.*
        from outlet_mapping a 
    )a
group by 1,2,3,5,6,7,8
;


---------------- ONO -----------------

delete from  `data-bi-prd-935c.bi_dev`.ioh_snd_master_kpi_detail where dt_id = vdt_id and kpi = 'ono' and brand = 'IM3';
insert into `data-bi-prd-935c.bi_dev`.ioh_snd_master_kpi_detail 
with ono as (
select organization_id, site_id  from 
    (
        select a.*, site_id 
        from `data-bi-prd-935c.bi_snd.pre_ref_daily_dump_org_mth` a
        left join 
            (
                select *  from
                    (
                        select
                            dt_id, site_id,organization_id,
                            ROW_NUMBER() OVER (partition by organization_id, date_trunc(dt_id,month) ORDER BY dt_id desc) AS rn 
                        from
                            `data-bi-prd-935c.bi_mart`.outlet_loc_ns a
                        where
                            ((date_trunc(dt_id,month) = date_trunc(vdt_id,month) and a.dt_id <= vdt_id))
                    ) a 
                where rn = 1
            ) b 
        on a.organization_id = b.organization_id  and parse_date('%Y%m',cast(mth_id as string)) = date_trunc(b.dt_id,month)
        where 
            parse_date('%Y%m',cast(mth_id as string)) = date_trunc(vdt_id,month)
            and status = 'Active'
            and channel = 'Traditional'
            and region not like 'REGIONAL%'
            and region <> ''
            and length(a.organization_id) >= 1
            and length(a.organization_id) <= 8
            and category not in ('TEST DOWNLINER')
            and lower(organization_type) like 'outlet%'
        )a    
where parse_date('%Y-%m-%d',concat(left(register_datetime,7),'-01')) = date_trunc(vdt_id,month) and parse_date('%Y-%m-%d',left(register_datetime,10)) <= vdt_id
)
---- ONO
select 'IM3' brand, 'site' level, site_id as level_value, 
    cast(count(organization_id) as numeric) value, 
    'mtd' as time_flag, 
     timestamp(current_datetime('+7')) as insert_date,
    'ono' as kpi_id, 
    vdt_id as dt_id
from ono 
group by 1,2,3,5,6,7,8
;  


--------------------------------------
---------------- ONO DLY -------------
--------------------------------------

delete from  `data-bi-prd-935c.bi_dev`.ioh_snd_master_kpi_detail where dt_id between date_trunc(vdt_id,month) and vdt_id and kpi = 'ono_dly' and brand = 'IM3';
insert into `data-bi-prd-935c.bi_dev`.ioh_snd_master_kpi_detail 
with ono as (
select parse_date('%Y-%m-%d',left(register_datetime,10)) as dt_id, organization_id, site_id  from 
    (
        select a.*, site_id 
        from `data-bi-prd-935c.bi_snd.pre_ref_daily_dump_org_mth` a
        left join 
            (
                select *  from
                    (
                        select
                            dt_id, site_id,organization_id,
                            ROW_NUMBER() OVER (partition by organization_id, date_trunc(dt_id,month) ORDER BY dt_id desc) AS rn 
                        from
                            `data-bi-prd-935c.bi_mart`.outlet_loc_ns a
                        where
                            ((date_trunc(dt_id,month) = date_trunc(vdt_id,month) and a.dt_id <= vdt_id))
                    ) a 
                where rn = 1
            ) b 
        on a.organization_id = b.organization_id  and parse_date('%Y%m',cast(a.mth_id as string)) = date_trunc(b.dt_id,month)
        where 
            parse_date('%Y%m',cast(mth_id as string)) = date_trunc(vdt_id,month)
            and status = 'Active'
            and channel = 'Traditional'
            and region not like 'REGIONAL%'
            and region <> ''
            and length(a.organization_id) >= 1
            and length(a.organization_id) <= 8
            and category not in ('TEST DOWNLINER')
            and lower(organization_type) like 'outlet%'
        )a    
where parse_date('%Y-%m-%d',concat(left(register_datetime,7),'-01')) = date_trunc(vdt_id,month) and parse_date('%Y-%m-%d',left(register_datetime,10)) <= vdt_id
)
---- ONO OUTLET DLY
select 'IM3' brand, 'outlet' level, organization_id as level_value, 
    cast(count(organization_id) as numeric) value, 
    'dly' as time_flag, 
     timestamp(current_datetime('+7')) as insert_date,
    'ono_dly' as kpi_id, 
    dt_id
from ono 
group by 1,2,3,5,6,7,8
;  


-- QSSO & SITE 3 QSSO

delete from  `data-bi-prd-935c.bi_dev`.ioh_snd_master_kpi_detail where dt_id = vdt_id and kpi in ('site_3qsso','qsso') and brand = 'IM3';
insert into `data-bi-prd-935c.bi_dev`.ioh_snd_master_kpi_detail 
with
outlet_location as (
            select * from
                (select site_id,region,area,sales_area,sales_cluster,micro_cluster,organization_id,organization_name,
                ROW_NUMBER() OVER (partition by organization_id ORDER BY dt_id desc) AS rn
                from `data-bi-prd-935c.bi_mart`.outlet_loc_ns
                where date_trunc(dt_id,month)= date_trunc(vdt_id,month)
                ) a
            where rn=1
          ),
num_ga as (
            select *  from 
            (
                select a.msisdn, a.dt_id ga_dt, a.site_id, organization_id, flag_quality, main_price_acm2, flag_sp,channel_grp
                from `data-bi-prd-935c.bi_mart`.rgs_ga_90d_dly_govt a
                join (select *
                        from `data-bi-prd-935c.bi_mart`.rgs_ga_channel_mth_govt 
                        where ga_dt between date_trunc(vdt_id,month) and vdt_id 
                        -- and main_price_acm2 >= 10000
                      )b
                on a.msisdn = b.msisdn and a.dt_id = b.ga_dt
                where dt_id between date_trunc(vdt_id,month) and vdt_id 
                and (churn_back = 'NO' or recycled = 'YES')
            )x 
        ), 
oulet_mapping as 
            (select distinct id_outlet from `data-bi-prd-935c.bi_snd.pre_ref_outlet_mapping_im3` where parse_date('%Y%m',cast(mth_id as string)) = date_trunc(vdt_id,month) -- and status = 'Active'
            ),
qsso as (
        select site_id id, sum(case when num_ga>=3 then 1 else 0 end) qsso 
            from
            (
                select a.organization_id, b.site_id, count(msisdn) num_ga
                from num_ga a 
                    left join outlet_location b   
                on a.organization_id=b.organization_id
                    join oulet_mapping c 
                on a.organization_id=c.id_outlet
                group by 1,2
            )a
        group by 1   
        ),
site_address as (
        select distinct month_id, site_id, new_site_id, old_site_id 
        from `data-bi-prd-935c.bi_mart`.total_site_ioh_mth
        where month_id = date_trunc(vdt_id,month)
        and addressable like '%ADDRESSABLE%SITE%'
        and total_site_im3=1
		)
-- SITE with 3 QSSO
select 'IM3' brand, 'site' level, site_id as level_value, 
    sum(cast(_3qsso as numeric)) value, 
    'mtd' as time_flag, 
     timestamp(current_datetime('+7')) as insert_date,
    'site_3qsso' as kpi_id, 
    vdt_id  as dt_id
from 
    (
    select a.site_id, sum(case when qsso>=3 then 1 else 0 end) _3qsso
        from site_address a
    join qsso b 
        on a.new_site_id=b.id or a.old_site_id=b.id
    group by 1 
    )a
group by 1,2,3,5,6,7,8
union all
-- QSSO 
select 'IM3' brand, 'site' level, id as level_value, 
    sum(cast(qsso.qsso as numeric)) value, 
    'mtd' as time_flag, 
     timestamp(current_datetime('+7')) as insert_date,
    'qsso' as kpi_id, 
    vdt_id  as dt_id
    from qsso
group by 1,2,3,5,6,7,8
;
            


----- SITE ADDR  -----------

delete from  `data-bi-prd-935c.bi_dev`.ioh_snd_master_kpi_detail where dt_id = vdt_id and kpi = 'site_addrs' and brand = 'IM3';
insert into `data-bi-prd-935c.bi_dev`.ioh_snd_master_kpi_detail 
with site_address as (
        select distinct month_id, site_id, new_site_id, old_site_id 
        from `data-bi-prd-935c.bi_mart`.total_site_ioh_mth
        where month_id = date_trunc(vdt_id,month)
        and addressable like '%ADDRESSABLE%SITE%'
        and total_site_im3=1
		)
-- trade demand inner & outer tertiary type
select 'IM3' brand, 'site' level, site_id as level_value, 
    cast(count(distinct site_id) as numeric) value, 
    'mtd' as time_flag, 
     timestamp(current_datetime('+7')) as insert_date,
     'site_addrs' as kpi_id, 
    vdt_id dt_id
from site_address
group by 1,2,3,5,6,7,8
;





--------------------------------------
------------- DSSO -------------------
--------------------------------------

delete from  `data-bi-prd-935c.bi_dev`.ioh_snd_master_kpi_detail where dt_id = vdt_id and kpi = 'sso_daily' and brand = 'IM3';
insert into `data-bi-prd-935c.bi_dev`.ioh_snd_master_kpi_detail  
select 
    'IM3' brand, 'site' level, site_id as level_value, 
    cast(sum(amount) as numeric) value, 
    'mtd' as time_flag, 
    timestamp(current_datetime('+7')) as insert_date,
    'sso_daily' as kpi_id, 
    vdt_id as dt_id
from
    (
        --ver 2
        select
            dt_id,  
            site_id,
            'SSO_Daily' parameter,
            count(organization_id) amount
        from
            (
                select 
                    a.dt_id,
                    b.organization_id,
                    loc_ns.site_id,
                    count(a.msisdn) cnt
                from `data-bi-prd-935c.bi_mart`.rgs_ga_90d_dly_govt a
                join `data-bi-prd-935c.bi_mart`.rgs_ga_channel_mth_govt b
                    on a.msisdn = b.msisdn
                    and a.dt_id = b.ga_dt
                left join 
                    (
                        select * from
                            (
                                select
                                    dt_id,
                                    a.site_id,
                                    concat(kecamatan_nm,'|',kabkot_nm) kec_unik,
                                    organization_id,
                                    organization_name,
                                    ROW_NUMBER() OVER (partition by organization_id, date_trunc(dt_id,month) ORDER BY dt_id desc) AS rn 
                                from
                                    `data-bi-prd-935c.bi_mart`.outlet_loc_ns a
                                left join
                                    `data-bi-prd-935c.bi_mart`.ref_site b
                                    on a.site_id = b.site_id
                                where
                                    (
                                        (date_trunc(dt_id,month) = date_trunc(vdt_id,month) and a.dt_id <= vdt_id)  
                                    )
                            ) a 
                        where rn = 1
                    ) loc_ns
                    on b.organization_id = loc_ns.organization_id 
                    and b.month_id = date_trunc(loc_ns.dt_id,month)
                where 
                    (
                        (date_trunc(a.dt_id,month) = date_trunc(vdt_id,month) and a.dt_id <= vdt_id)  
                    )
                and (churn_back = 'NO' OR recycled = 'YES')
                -- and flag_quality = 'a. >=10K' 
                -- and b.main_price_acm2 >= 10000
                group by 1,2,3
            ) a 
        join
            (
                select  distinct parse_date('%Y%m',cast(mth_id as string)) mth_id, id_outlet
                from `data-bi-prd-935c.bi_snd.pre_ref_outlet_mapping_im3`
                where parse_date('%Y%m',cast(mth_id as string)) = (date_trunc(vdt_id,month))
                and mth_id is not null
            ) pjp
            on a.organization_id = pjp.id_outlet
            and date_trunc(dt_id,month) = pjp.mth_id
        group by 1,2,3
    )a 
group by 1,2,3,5,6,7,8
;


---------------- CNT MPC ----------------

delete from  `data-bi-prd-935c.bi_dev`.ioh_snd_master_kpi_detail where dt_id = vdt_id and kpi = 'mpc_cnt' and brand = 'IM3';
insert into `data-bi-prd-935c.bi_dev`.ioh_snd_master_kpi_detail 
select 'IM3' brand, 'partner' level, partner as level_value, 
    count(distinct partner) value, 
    'mtd' as time_flag, 
     timestamp(current_datetime('+7')) as insert_date,
    'mpc_cnt' as kpi_id, 
    vdt_id dt_id
from `data-bi-prd-935c.bi_snd.pre_ref_hirarki_territory_ioh`
where parse_date('%Y%m',cast(mth as string))=date_trunc(vdt_id,month)
    and pt_type = 'MPC'
    and brand = 'IM3'
group by 1,2,3,5,6,7,8
;

---------------- CNT MP3 ----------------

delete from  `data-bi-prd-935c.bi_dev`.ioh_snd_master_kpi_detail where dt_id = vdt_id and kpi = 'mp3_cnt' and brand = '3ID';
insert into `data-bi-prd-935c.bi_dev`.ioh_snd_master_kpi_detail 
select '3ID' brand, 'partner' level, partner as level_value, 
    count(distinct partner) value, 
    'mtd' as time_flag, 
    timestamp(current_datetime('+7')) as insert_date,
    'mp3_cnt' as kpi_id, 
    vdt_id dt_id
from `data-bi-prd-935c.bi_snd.pre_ref_hirarki_territory_ioh`
where parse_date('%Y%m',cast(mth as string))=date_trunc(vdt_id,month)
    and pt_type = 'MP3'
    and brand = '3ID'
group by 1,2,3,5,6,7,8
;



--------------------------------
------- site non lrs im3
----------------------------------
delete from  `data-bi-prd-935c.bi_dev`.ioh_snd_master_kpi_detail where dt_id = vdt_id and kpi = 'site_im3_non_lrs' and brand = 'IM3';
insert into `data-bi-prd-935c.bi_dev`.ioh_snd_master_kpi_detail 
select 'IM3' brand, 'site' level,
    site_id as level_value, 
    cast(count(site_id) as numeric) value, 
    'mtd' as time_flag, 
     timestamp(current_datetime('+7')) as insert_date,
    'site_im3_non_lrs' as kpi_id, 
    vdt_id as dt_id 
from `data-bi-prd-935c`.bi_snd.pre_raw_lrs_ioh
where prt_dt=vdt_id
    and lrs_flag_im3 not in ('LRS')
    and addressable = 'ADDRESSABLE SITE'
group by 1,2,3,5,6,7,8
;



--------------------------------
------- site lrs im3
----------------------------------

delete from  `data-bi-prd-935c.bi_dev`.ioh_snd_master_kpi_detail where dt_id = vdt_id and kpi = 'site_im3_lrs' and brand = 'IM3';
insert into `data-bi-prd-935c.bi_dev`.ioh_snd_master_kpi_detail 
select 'IM3' brand, 'site' level,
    site_id as level_value, 
    cast(count(site_id) as numeric) value, 
    'mtd' as time_flag, 
     timestamp(current_datetime('+7')) as insert_date,
    'site_im3_lrs' as kpi_id, 
    vdt_id as dt_id 
from `data-bi-prd-935c`.bi_snd.pre_raw_lrs_ioh
where prt_dt=vdt_id
    and lrs_flag_im3 in ('LRS')
    and addressable = 'ADDRESSABLE SITE'
group by 1,2,3,5,6,7,8
;


--------------------------------
------- site non lrs 3id
----------------------------------

delete from  `data-bi-prd-935c.bi_dev`.ioh_snd_master_kpi_detail where dt_id = vdt_id and kpi = 'site_3id_non_lrs' and brand = '3ID';
insert into `data-bi-prd-935c.bi_dev`.ioh_snd_master_kpi_detail 
select '3ID' brand, 'site' level,
    site_id as level_value, 
    cast(count(site_id) as numeric) value, 
    'mtd' as time_flag, 
     timestamp(current_datetime('+7')) as insert_date,
    'site_3id_non_lrs' as kpi_id, 
    vdt_id as dt_id 
from `data-bi-prd-935c`.bi_snd.pre_raw_lrs_ioh
where prt_dt=vdt_id
    and lrs_flag_tri not in ('LRS')
    and addressable = 'ADDRESSABLE SITE'
group by 1,2,3,5,6,7,8
;



--------------------------------
------- site lrs 3id
----------------------------------

delete from  `data-bi-prd-935c.bi_dev`.ioh_snd_master_kpi_detail where dt_id = vdt_id and kpi = 'site_3id_lrs' and brand = '3ID';
insert into `data-bi-prd-935c.bi_dev`.ioh_snd_master_kpi_detail 
select '3ID' brand, 'site' level,
    site_id as level_value, 
    cast(count(site_id) as numeric) value, 
    'mtd' as time_flag, 
     timestamp(current_datetime('+7')) as insert_date,
    'site_3id_lrs' as kpi_id, 
    vdt_id as dt_id 
from `data-bi-prd-935c`.bi_snd.pre_raw_lrs_ioh
where prt_dt=vdt_id
    and lrs_flag_tri in ('LRS')
    and addressable = 'ADDRESSABLE SITE'
group by 1,2,3,5,6,7,8
;


--------------------------------
------- site lrs ioh
----------------------------------

delete from  `data-bi-prd-935c.bi_dev`.ioh_snd_master_kpi_detail where dt_id = vdt_id and kpi = 'site_ioh_lrs' and brand = 'IOH';
insert into `data-bi-prd-935c.bi_dev`.ioh_snd_master_kpi_detail 
select 'IOH' brand, 'site' level,
    site_id as level_value, 
    cast(count(site_id) as numeric) value, 
    'mtd' as time_flag, 
     timestamp(current_datetime('+7')) as insert_date,
    'site_ioh_lrs' as kpi_id, 
    vdt_id as dt_id 
from `data-bi-prd-935c`.bi_snd.pre_raw_lrs_ioh
where prt_dt=vdt_id
    and lrs_flag_ioh in ('LRS')
    and addressable = 'ADDRESSABLE SITE'
group by 1,2,3,5,6,7,8
;
