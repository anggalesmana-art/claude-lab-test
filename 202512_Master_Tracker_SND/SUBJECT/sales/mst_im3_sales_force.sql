declare vdt_id date default @vdt_id;
---------------- dse_cnt ----------------

delete from `data-bi-prd-935c.bi_dev`.ioh_snd_master_kpi_detail where brand = 'IM3' and kpi = 'dse_cnt' and dt_id = vdt_id;
insert into `data-bi-prd-935c.bi_dev`.ioh_snd_master_kpi_detail
select 'IM3' brand, 'dse' level, username as level_value, 
    cast(count(distinct username) as numeric) value,
    'mtd' as time_flag, 
     timestamp(current_datetime('+7')) as insert_date,
    'dse_cnt' as kpi, 
    vdt_id as dt_id
from
(
    select distinct username
    from `data-bi-prd-935c.bi_snd.pre_ref_outlet_mapping_im3`
    where parse_date('%Y%m',cast(mth_id as string)) = date_trunc(vdt_id,month)
)a 
group by 1,2,3,5,6,7,8
;


---------------- dse_meet_ga_tgt ----------------

delete from `data-bi-prd-935c.bi_dev`.ioh_snd_master_kpi_detail where brand = 'IM3' and kpi = 'dse_meet_ga_tgt' and dt_id = vdt_id;
insert into `data-bi-prd-935c.bi_dev`.ioh_snd_master_kpi_detail 
with 
rgu_ga as (
                select a.msisdn, a.dt_id ga_dt, a.site_id, organization_id, flag_quality, main_price_acm2, flag_sp,channel_grp
                    from `data-bi-prd-935c.bi_mart`.rgs_ga_90d_dly_govt a
                    join (
                    		select * from `data-bi-prd-935c.bi_mart`.rgs_ga_channel_mth_govt 
                            where ga_dt between date_trunc(vdt_id,month) and vdt_id 
                           -- and main_price_acm2 >= 10000
                          and channel_grp ='TRADITIONAL'
                          )b
                    on a.msisdn = b.msisdn and a.dt_id = b.ga_dt
                where dt_id between date_trunc(vdt_id,month) and vdt_id 
                and (churn_back = 'NO' or recycled = 'YES')
                ),
cso_mapping as (
					select distinct id_outlet, username from `data-bi-prd-935c.bi_snd.pre_ref_outlet_mapping_im3`  where parse_date('%Y%m',cast(mth_id as string)) = date_trunc(vdt_id,month)
				)
-- dse 350 ga
select 'IM3' brand, 'dse' level, username as level_value, 
cast(sum(value) as numeric) value,
'mtd' as time_flag, 
timestamp(current_datetime('+7')) as insert_date,
'dse_meet_ga_tgt' as kpi, 
vdt_id as dt_id
from
    (
    select username, case when ga>=350 then 1 else 0 end value, ga
    from
        (
        select  username, count(msisdn) ga
                    from cso_mapping a
                        left join rgu_ga b 
                    on a.id_outlet=b.organization_id
        group by 1
        )a 
    )a
group by 1,2,3,5,6,7,8
;


---------------- dse_meet_sec_tgt  & dse_trx ----------------

delete from `data-bi-prd-935c.bi_dev`.ioh_snd_master_kpi_detail where brand = 'IM3' and kpi in ('dse_meet_sec_tgt','dse_trx') and dt_id = vdt_id;
insert into `data-bi-prd-935c.bi_dev`.ioh_snd_master_kpi_detail 
with 
secondary as (
                select date_trunc(dt_id,month) mth_id,  organization_id, sum(amount) amount from 
                       (
                         -- SELLIN SALDO
                        select * from `data-bi-prd-935c.bi_mart`.fact_snd_secondary_dtl
                        where dt_id between date_trunc(vdt_id,month) and vdt_id 
                            and secondary_type = 'SELLIN SALDO'
                            and  (upper(organization_id) not like '%DS%'
                                        and upper(organization_id) not like '%SF%'
                                        and upper(organization_id) not like '%H2H%'
                                    )
                            and lower(channel) like '%traditional%'
                            and parent_org_type in ('Dealer','SDP')
                        union all 
                        -- SELAIN SELLIN SALDO
                        select * from `data-bi-prd-935c.bi_mart`.fact_snd_secondary_dtl
                        where dt_id between date_trunc(vdt_id,month) and vdt_id 
                            and secondary_type not in  ('SELLIN SALDO')
                        )a 
                group by 1,2
                ),
cso_mapping as (
					select distinct id_outlet, username from `data-bi-prd-935c.bi_snd.pre_ref_outlet_mapping_im3`  where parse_date('%Y%m',cast(mth_id as string)) = date_trunc(vdt_id,month)
				)
-- dse 80m sec
select 'IM3' brand, 'dse' level, username as level_value, 
cast(sum(value) as numeric) value,
'mtd' as time_flag, 
timestamp(current_datetime('+7')) as insert_date,
'dse_meet_sec_tgt' as kpi, 
vdt_id as dt_id
from
    (
    select username, case when sec>=80000000 then 1 else 0 end value, sec
    from
        (
        select  username, sum(amount) sec
                    from cso_mapping a
                        left join secondary b 
                    on a.id_outlet=b.organization_id
        group by 1
        )a 
    )a
group by 1,2,3,5,6,7,8
union all 
-- dse trx
select 'IM3' brand, 'dse' level, username as level_value, 
cast(sum(value) as numeric) value,
'mtd' as time_flag, 
timestamp(current_datetime('+7')) as insert_date,
'dse_trx' as kpi, 
vdt_id as dt_id
from
    (
    select username, case when sec>0 then 1 else 0 end value, sec
    from
        (
        select  username, sum(amount) sec
                    from cso_mapping a
                        left join secondary b 
                    on a.id_outlet=b.organization_id
        group by 1
        )a 
    )a
group by 1,2,3,5,6,7,8
;




---------------- dse_meet_ga_and_sec_tgt ----------------

delete from `data-bi-prd-935c.bi_dev`.ioh_snd_master_kpi_detail where brand = 'IM3' and kpi = 'dse_meet_ga_sec_tgt' and dt_id = vdt_id ;
insert into `data-bi-prd-935c.bi_dev`.ioh_snd_master_kpi_detail 
with 
rgu_ga as (
                select a.msisdn, a.dt_id ga_dt, a.site_id, organization_id, flag_quality, main_price_acm2, flag_sp,channel_grp
                    from `data-bi-prd-935c.bi_mart`.rgs_ga_90d_dly_govt a
                    join (
                    		select * from `data-bi-prd-935c.bi_mart`.rgs_ga_channel_mth_govt 
                            where ga_dt between date_trunc(vdt_id,month) and vdt_id 
                           -- and main_price_acm2 >= 10000
                          and channel_grp ='TRADITIONAL'
                          )b
                    on a.msisdn = b.msisdn and a.dt_id = b.ga_dt
                where dt_id between date_trunc(vdt_id,month) and vdt_id 
                and (churn_back = 'NO' or recycled = 'YES')
                ),
secondary as (
                select date_trunc(dt_id,month) mth_id,  organization_id, sum(amount) amount from 
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
                group by 1,2
                ),
cso_mapping as (
					select distinct id_outlet, username from `data-bi-prd-935c.bi_snd.pre_ref_outlet_mapping_im3`  where parse_date('%Y%m',cast(mth_id as string)) = date_trunc(vdt_id,month)
				)
-- dse 350 ga
select 'IM3' brand, 'dse' level, username as level_value, 
cast(sum(value) as numeric) value,
'mtd' as time_flag, 
timestamp(current_datetime('+7')) as insert_date,
'dse_meet_ga_sec_tgt' as kpi, 
vdt_id as dt_id
from
    (
    select username, case when ga>=350 and sec>=80000000 then 1 else 0 end value, ga, sec
    from
        (
        select  username, count(msisdn) ga, sum(amount) sec
                    from cso_mapping a
                        left join rgu_ga b 
                    on a.id_outlet=b.organization_id
                        left join secondary c
                    on a.id_outlet=c.organization_id
        group by 1
        )a 
    )a
group by 1,2,3,5,6,7,8
;



--- Insert to table Summary

delete from `data-bi-prd-935c.bi_dev`.ioh_snd_master_kpi_detail_smy where brand = 'IM3' and kpi in ('dse_cnt','dse_meet_ga_tgt','dse_meet_sec_tgt', 'dse_meet_ga_sec_tgt','dse_trx'
        ) and dt_id = vdt_id;

insert into `data-bi-prd-935c.bi_dev`.ioh_snd_master_kpi_detail_smy 
with ref_dealer as (
            select a.id, b.circle, b.region region_circle, b.area, b.sales_area, b.micro_cluster
                from  `data-bi-prd-935c.bi_snd.pre_ref_lowlevel_mth_im3` a
                left join
                        (
                        select * from `data-bi-prd-935c.bi_mart`.ref_kecamatan
                            ) b
                        on a.kec_unik = b.kec_kabkot
                where parse_date('%Y%m',cast(a.mth as string)) = date_trunc(vdt_id,month)
            ),
ref_dealer_rn as (            
            select a.id, b.circle, b.region region_circle, b.area, b.sales_area, b.micro_cluster
                from
                (
                    select * from 
                    (
                    select a.*, 
                        ROW_NUMBER() OVER (partition by id ORDER BY mth desc) AS rn 
                    from  `data-bi-prd-935c.bi_snd.pre_ref_lowlevel_mth_im3` a
                    )a
                    where rn = 1
                )a
            left join
                (select * from `data-bi-prd-935c.bi_mart`.ref_kecamatan) b
            on a.kec_unik = b.kec_kabkot
            ), 
tracker as (
    select *
    from `data-bi-prd-935c.bi_dev`.ioh_snd_master_kpi_detail
    where   dt_id =  vdt_id 
        and kpi in 
        ('dse_cnt','dse_meet_ga_tgt','dse_meet_sec_tgt', 'dse_meet_ga_sec_tgt','dse_trx'
        ) and brand = 'IM3'
            )
select  a.brand, b.circle, b.region_circle as region, b.area, b.sales_area branch,b.micro_cluster cluster,
    --    coalesce(b.circle,c.circle) as circle,
    --    coalesce(b.region_circle,c.region_circle) as region,
    --    coalesce(b.area,c.area) as area,
    --    coalesce(b.sales_area,c.sales_area) as branch,
    --   coalesce(b.micro_cluster,c.micro_cluster) as cluster,
        sum(values) value,
        a.kpi,
        a.dt_id
    from tracker a 
        left join ref_dealer b
    on a.level_value=b.id 
   --     left join ref_dealer_rn c
   -- on a.level_value=c.id 
group by 1,2,3,4,5,6,8,9
;