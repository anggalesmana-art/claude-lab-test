Declare vdt_id date default @vdt_id;
-----------------------NEW BY SRS CUST RGS ACT2---------------------------------------------------------------------------------

delete from `data-bi-prd-935c.bi_mart`.seratus_q_sso_rgs_act2 where dt_id = vdt_id;
insert into `data-bi-prd-935c.bi_mart`.seratus_q_sso_rgs_act2
select 
        coalesce(a.site_id,b.site_id) site_id,
        sum(coalesce(q_sso_dly,0)) q_sso_dly,
        sum(coalesce(q_sso,0)) q_sso,
        sum(coalesce(q_sso_stabil,0)) q_sso_stabil,
        sum(coalesce(b.rgu_ga,0)) q_sso_dly_rgu_ga,
        sum(coalesce(a.rgu_ga,0)) q_sso_rgu_ga,
vdt_id dt_id
from 
-- q_sso
    (
        select vdt_id dt_id,b.site_id,sum(case when rgu_ga>=3 then 1 else 0 end) q_sso, sum(rgu_ga) rgu_ga
        from 
            (
                select date_trunc(srs_dt,month) mth,organization_id, organization_name,site_id_outlet,
                -- sum(case when flag_inject_10k=1 and flag_cluster=1 then 1 else 0 end) q_sso,
                count(msisdn) rgu_ga
                from `data-bi-prd-935c.bi_mart`.q_sso_srs_rgs_act2
                where srs_dt between date_trunc(vdt_id,month) and vdt_id 
                group by 1,2,3,4
            ) a
        join `data-bi-prd-935c.bi_mart`.ref_site b on a.site_id_outlet=b.site_id
            --join (select * from `data-bi-prd-935c.bi_mart`.ref_site_mth
            --where month_id=substr(vdt_id,1,6)) b on a.site_id_outlet=b.site_id
        group by 1,2
    ) a
full outer join
-- q_sso_dly
    (
        select srs_dt,site_id,q_sso_dly,rgu_ga
        from 
            (
                select srs_dt,b.site_id,sum(case when rgu_ga>=3 then 1 else 0 end) q_sso_dly, sum(rgu_ga) rgu_ga
                from 
                (
                    select srs_dt,organization_id,organization_name,site_id_outlet,
                    -- sum(case when flag_inject_10k=1 and flag_cluster=1 then 1 else 0 end) q_sso,
                    count(msisdn) rgu_ga
                    from `data-bi-prd-935c.bi_mart`.q_sso_srs_rgs_act2
                    where srs_dt=vdt_id
                    group by 1,2,3,4
                ) a
        join `data-bi-prd-935c.bi_mart`.ref_site b on a.site_id_outlet=b.site_id
--join (select * from `data-bi-prd-935c.bi_mart`.ref_site_mth
--where month_id=substr(vdt_id,1,6)) b on a.site_id_outlet=b.site_id
        group by 1,2
            ) a
        where q_sso_dly>0
    ) b on a.site_id=b.site_id
-- q_sso_stabil & avg_rgu_ga
full outer join
(
    select vdt_id dt_id,d.site_id,count(distinct a.organization_id) q_sso_stabil, sum((a.rgu_ga+b.rgu_ga+c.rgu_ga)/3) avg_rgu_ga
    from
    (
        select mth,organization_id,organization_name,site_id_outlet,sum(rgu_ga) rgu_ga
        from (select date_trunc(srs_dt,month) mth,organization_id,organization_name,site_id_outlet,count(msisdn) rgu_ga
        from `data-bi-prd-935c.bi_mart`.q_sso_srs_rgs_act2
        where srs_dt between date_trunc(vdt_id,month) and vdt_id and flag_inject_10k=1 and flag_cluster=1 and channel='TRADITIONAL'
        group by 1,2,3,4) a
        where rgu_ga>=3
        group by 1,2,3,4
    ) a
    join 
        (
            select organization_id,sum(rgu_ga) rgu_ga from 
                (
                    select organization_id,count(msisdn) rgu_ga 
                    from `data-bi-prd-935c.bi_mart`.q_sso_srs_rgs_act2
                    where date_trunc(srs_dt,month)=date_trunc(vdt_id-interval 1 month,month)
                    and flag_inject_10k=1 and flag_cluster=1 and channel='TRADITIONAL'
                    group by 1
                ) a
            where rgu_ga>=3
            group by 1
        ) b on a.organization_id=b.organization_id
    join 
        (  
            select organization_id,sum(rgu_ga) rgu_ga 
            from 
                (  
                    select organization_id,count(msisdn) rgu_ga
                    from `data-bi-prd-935c.bi_mart`.q_sso_srs_rgs_act2
                    where date_trunc(srs_dt,month)=date_trunc(vdt_id - interval 2 month,month)
                    -- and flag_inject_10k=1 
                    and flag_cluster=1 and channel='TRADITIONAL'
                    group by 1
                ) a
            where rgu_ga>=3
            group by 1
         ) c on a.organization_id=c.organization_id
    join `data-bi-prd-935c.bi_mart`.ref_site d on a.site_id_outlet=d.site_id
    --join (select * from `data-bi-prd-935c.bi_mart`.ref_site_mth
    --where month_id=substr(vdt_id,1,6)) d on a.site_id_outlet=d.site_id
    group by 1,2
) c on a.site_id=c.site_id
group by 1,7;

----------------- SSO ---------------------------
--- SSO/UAO SUMMARY
delete from `data-bi-prd-935c.bi_mart`.seratus_uao_inject where dt_id = vdt_id;
insert into `data-bi-prd-935c.bi_mart`.seratus_uao_inject
select coalesce(a.site_id,b.site_id) site_id,sum(uao_dly) uao_dly,sum(uao_mtd) uao_mtd,
sum(sp_count) sp_count,sum(uao_mtd2) uao_mtd2,sum(sp_count2) sp_count2,coalesce(a.dt_id,b.dt_id) dt_id
from
(select site_id,count(distinct organization_id) uao_dly,dt_id,sum(ga_act) sp_count
from `data-bi-prd-935c.bi_mart`.seratus_uao_inject_detail
where dt_id=vdt_id
group by 1,3) a
full outer join
(select site_id,count(distinct organization_id) uao_mtd,vdt_id dt_id
from `data-bi-prd-935c.bi_mart`.seratus_uao_inject_detail
where dt_id>=date_trunc(vdt_id,month)
and dt_id<=vdt_id
group by 1,3) b on a.site_id=b.site_id
left join
(select site_id,count(organization_id) uao_mtd2,sum(ga_act) sp_count2
from
(select site_id,organization_id,sum(ga_act) ga_act
from `data-bi-prd-935c.bi_mart`.seratus_uao_inject_detail
where dt_id>=date_trunc(vdt_id,month)
and dt_id<=vdt_id
group by 1,2) a 
where ga_act>=3
group by 1) c on b.site_id=c.site_id
group by 1,7;

delete from `data-bi-prd-935c.bi_mart`.tmp_site_less3qsso where dt_id = vdt_id;
insert into `data-bi-prd-935c.bi_mart`.tmp_site_less3qsso
select count(site_id) num_site,vdt_id dt_id
from (
select a.site_id,sum(coalesce(q_sso,0)) q_sso
from `data-bi-prd-935c.bi_mart`.total_site_ioh_mth a
left join
(select site_id,sum(q_sso) q_sso from `data-bi-prd-935c.bi_mart`.seratus_q_sso_rgs_act2
where dt_id =vdt_id and site_id is not NULL
group by 1) b on a.site_id=b.site_id
where a.month_id=date_trunc(vdt_id,month) and a.addressable like '%ADDRESSABLE%SITE%'
----and upper(a.addressable_nbs) like '%YES%'
group by 1) a
where q_sso<3
group by 2;



