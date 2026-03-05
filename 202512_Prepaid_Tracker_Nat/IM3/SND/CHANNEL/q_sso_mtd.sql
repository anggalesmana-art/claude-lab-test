declare vdt_id date default @vdt_id;
delete from `data-bi-prd-935c.bi_mart`.q_sso_srs_rgs_act2 where srs_dt between date_trunc(vdt_id,month) and vdt_id ;
insert into `data-bi-prd-935c.bi_mart`.q_sso_srs_rgs_act2 
with
outlet_location as (
            select * from
                (select site_id,region,area,sales_area,sales_cluster,micro_cluster,organization_id,organization_name,
                ROW_NUMBER() OVER (partition by organization_id ORDER BY dt_id desc) AS rn
                from `data-bi-prd-935c.bi_mart`.outlet_loc_ns
                where dt_id between date_trunc(vdt_id,month) and vdt_id
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
            (select distinct id_outlet from `data-bi-prd-935c.bi_snd.pre_ref_outlet_mapping_im3` where parse_date('%Y%m%d',concat(cast(mth_id as string),01)) = date_trunc(vdt_id,month) and UPPER(status) = 'ACTIVE'
            ),
ref_site as (select * from `data-bi-prd-935c.bi_mart`.ref_site)
select 
coalesce(b.organization_id,'OTHERS') organization_id,
channel_grp as channel,
b.organization_name, 
case when a.main_price_acm2 >= 10000 then 1 else 0 end flag_inject_10k,
b.site_id as site_id_outlet, -- nbs
b.sales_cluster as sales_cluster_outlet, -- nbs
a.site_id as site_id_srs,
c.sales_cluster as sales_cluster_srs, -- ref_site by srs_site
case when b.sales_cluster=c.sales_cluster then 1 else 0 end flag_cluster,
a.msisdn,
a.ga_dt,
flag_sp,
a.ga_dt as srs_dt
from num_ga a
    join outlet_location b on a.organization_id=b.organization_id
    left join ref_site c on a.site_id=c.site_id
    join oulet_mapping d on a.organization_id=d.id_outlet
;


--- SSO UAO DETAIL 202210
delete from `data-bi-prd-935c.bi_mart`.seratus_uao_inject_detail where dt_id between date_trunc(vdt_id,month) and vdt_id;
insert into `data-bi-prd-935c.bi_mart`.seratus_uao_inject_detail
select site_id_outlet site_id,organization_id,count(msisdn) ga_act,srs_dt dt_id
from `data-bi-prd-935c.bi_mart`.q_sso_srs_rgs_act2
where srs_dt>=date_trunc(vdt_id,month)
and srs_dt<=vdt_id
group by 1,2,4;