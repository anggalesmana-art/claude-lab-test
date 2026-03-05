declare vdt_id date default @vdt_id;

delete from `data-bi-prd-935c.bi_mart`.kpi_site_wise_dly 
where dt_id = vdt_id and kpi_id in (
'SITE016',
'SND022',
'SITE013',
'SND081',
'SND026',
'SITE010',
'SND080',
'SND029',
'SITE018',
'SITE009'
);



-------------------------------------------------
--------------- SSO & Q-SSO ---------------------
-- SIM Selling Outlet SITEWISE-------------------
-------------------------------------------------
insert into `data-bi-prd-935c.bi_mart`.kpi_site_wise_dly
with sites as (
    select site_id,old_site_id,new_site_id
    from `data-bi-prd-935c.bi_mart`.total_site_ioh_mth
    where date(month_id)=date_trunc(vdt_id,month)
    and addressable like '%ADDRESSABLE%SITE%'
    and total_site_im3=1
),
sso as (
    select dt_id,site_id,sum(uao_dly) uao_dly,sum(uao_mtd) uao_mtd
    from `data-bi-prd-935c.bi_mart`.seratus_uao_inject
    where dt_id=vdt_id
    group by 1,2
),
qsso as (
    select dt_id,site_id,sum(q_sso) q_sso,sum(q_sso_dly) q_sso_dly,sum(q_sso_rgu_ga) q_sso_rgu_ga
    from `data-bi-prd-935c.bi_mart`.seratus_q_sso_rgs_act2
    where dt_id=vdt_id
    group by 1,2
)
--SSO DAILY
select 'ret_sso' kpi_code,'IM3' brand,site_id,sum(uao_dly) metric,current_datetime('+7') process_dt,'SND022' kpi_id,dt_id
from sso
where uao_dly>0
group by 1,2,3,5,6,7
--SSO
union all
select 'ret_sso_mtd' kpi_code,'IM3' brand,site_id,sum(uao_mtd) metric,current_datetime('+7') process_dt,'SND026' kpi_id,dt_id
from sso
where uao_mtd>0
group by 1,2,3,5,6,7
--SITE WITH SSO
union all
select 'site_sso' kpi_code,'IM3' brand,a.site_id,count(a.site_id) metric,current_datetime('+7') process_dt,'SITE018' kpi_id,dt_id
from sites a
join sso b
on a.new_site_id=b.site_id or a.old_site_id=b.site_id
where uao_mtd>0
group by 1,2,3,5,6,7
--Q-SSO
union all
select 'ret_qsso' kpi_code,'IM3' brand,site_id,sum(q_sso) metric,current_datetime('+7') process_dt,'SND029' kpi_id,dt_id
from qsso
where q_sso>=1
group by 1,2,3,5,6,7
--SITE W/O Q-SSO
union all
select 'site_wo_qsso' kpi_code,'IM3' brand,a.site_id,count(a.site_id) metric,current_datetime('+7') process_dt,'SITE009' kpi_id,vdt_id dt_id
from sites a
left join (select site_id
            from qsso
            where q_sso>0) b
on a.new_site_id=b.site_id or a.old_site_id=b.site_id
where b.site_id is null
group by 1,2,3,5,6,7
--SITE <3 Q-SSO
union all
select 'site_less_3qsso' kpi_code,'IM3' brand,a.site_id,count(a.site_id) metric,current_datetime('+7') process_dt,'SITE010' kpi_id,vdt_id dt_id
from sites a
left join (select site_id,q_sso
            from qsso
            where q_sso>0) b
on a.new_site_id=b.site_id or a.old_site_id=b.site_id
where q_sso<3
group by 1,2,3,5,6,7
--SITE >=3 Q-SSO
union all
select 'site_3qsso' kpi_code,'IM3' brand,a.site_id,count(a.site_id) metric,current_datetime('+7') process_dt,'SITE013' kpi_id,vdt_id dt_id
from sites a
left join (select site_id,q_sso
            from qsso
            where q_sso>0) b
on a.new_site_id=b.site_id or a.old_site_id=b.site_id
where q_sso>=3
group by 1,2,3,5,6,7
--SITE WITH Q-SSO
union all
select 'site_qsso' kpi_code,'IM3' brand,a.site_id,count(a.site_id) metric,current_datetime('+7') process_dt,'SITE016' kpi_id,vdt_id dt_id
from sites a
left join (select site_id,q_sso
            from qsso
            where q_sso>0) b
on a.new_site_id=b.site_id or a.old_site_id=b.site_id
where q_sso>=1
group by 1,2,3,5,6,7
--Q-SSO Daily
union all
select 'ret_qsso_dly' kpi_code,'IM3' brand,site_id,sum(q_sso_dly) metric,current_datetime('+7') process_dt,'SND080' kpi_id,dt_id
from qsso
where q_sso_dly>=1
group by 1,2,3,5,6,7
--Q-SSO >= 10 QSC
union all
select 'ret_qsso_10qsc' kpi_code,'IM3' brand,site_id,sum(q_sso) metric,current_datetime('+7') process_dt,'SND081' kpi_id,dt_id
from qsso
where q_sso>=1 and q_sso_rgu_ga>=10
group by 1,2,3,5,6,7;

delete from `data-bi-prd-935c.bi_mart`.kpi_site_wise_dly 
where dt_id = vdt_id and kpi_id in ('SITE021','SITE025');


--SITE 3 Q-SSO & 3 Q-URO
insert into `data-bi-prd-935c.bi_mart`.kpi_site_wise_dly
select 'site_3qsso_3quro' kpi_code,'IM3' brand,a.site_id,count(a.site_id) metric,current_datetime('+7') process_dt,'SITE021' kpi_id,vdt_id dt_id
from `data-bi-prd-935c.bi_mart`.total_site_ioh_mth a
join (select a.site_id
from
(select site_id,q_sso
from `data-bi-prd-935c.bi_mart`.seratus_q_sso_rgs_act2
where dt_id=vdt_id
and q_sso>=3) a
join
(select site_id,q_uro
from (
select site_id,sum(q_uro_sp+q_uro_fdv) q_uro
from `data-bi-prd-935c.bi_mart`.seratus_q_uro_fdv_mtd
where dt_id=vdt_id
group by 1) a
where q_uro>=3) b on a.site_id=b.site_id
group by 1) b on a.new_site_id=b.site_id or a.old_site_id=b.site_id
left join `data-bi-prd-935c.bi_mart`.ref_site c on a.site_id=c.site_id
where date(month_id)=date_trunc(vdt_id,month) and a.addressable like '%ADDRESSABLE%SITE%'
--and upper(a.addressable_nbs) like '%YES%'
and a.total_site_im3=1
group by 1,2,3,5,6,7;

--SITE WO 3 Q-SSO & 3 Q-URO
insert into `data-bi-prd-935c.bi_mart`.kpi_site_wise_dly
select 'site_wo_3qsso_3quro' kpi_code,'IM3' brand,a.site_id,count(a.site_id) metric,current_datetime('+7') process_dt,'SITE025' kpi_id,vdt_id dt_id
from `data-bi-prd-935c.bi_mart`.total_site_ioh_mth a
left join ( select a.site_id from
                      (select site_id,q_sso
                      from `data-bi-prd-935c.bi_mart`.seratus_q_sso_rgs_act2
                      where dt_id=vdt_id and q_sso>=3) a
                      join
                      (select site_id,q_uro
                      from (
                      select site_id,sum(q_uro_sp+q_uro_fdv) q_uro from `data-bi-prd-935c.bi_mart`.seratus_q_uro_fdv_mtd
                      where dt_id=vdt_id
                      group by 1) a
                      where q_uro>=3) b on a.site_id=b.site_id
                      group by 1) b 
on a.new_site_id=b.site_id or a.old_site_id=b.site_id
left join `data-bi-prd-935c.bi_mart`.ref_site c on a.site_id=c.site_id
where date(month_id)=date_trunc(vdt_id,month) and a.addressable like '%ADDRESSABLE%SITE%' and b.site_id is null
--and upper(a.addressable_nbs) like '%YES%'
and a.total_site_im3=1
group by 1,2,3,5,6,7;

delete from `data-bi-prd-935c.bi_mart`.kpi_site_wise_dly 
where dt_id = vdt_id and kpi_id in (
'SND074',
'SITE026',
'SITE015',
'SITE012',
'SND070',
'SITE023',
'SND071',
'SND073');

-------------------------------------------------
------------- QSC & ACQ REV ---------------------
---------------- SITEWISE -----------------------
-------------------------------------------------
insert into `data-bi-prd-935c.bi_mart`.kpi_site_wise_dly
with sites as (
    select site_id,old_site_id,new_site_id
    from `data-bi-prd-935c.bi_mart`.total_site_ioh_mth
    where date(month_id)=date_trunc(vdt_id,month)
    and addressable like '%ADDRESSABLE%SITE%'
    and total_site_im3=1
),
ga_channel as (
    select msisdn,channel_grp,ga_dt
    from `data-bi-prd-935c.bi_mart`.rgs_ga_channel_mth_nogovt
    where ga_dt between date_trunc(vdt_id,month) and vdt_id
),
acq_qsc as (
    select dt_id,srs_dt,a.ga_dt,srs_site,channel_grp,count(a.msisdn) qsc,cast(sum(coalesce(acq_rev,0)) as int64) acq_rev
    from `data-bi-prd-935c.bi_mart`.rgs_srs_acq_25mb_govt a
    left join ga_channel b
    on a.msisdn=b.msisdn and a.ga_dt=b.ga_dt
    where dt_id=vdt_id and flag_status='Active 2'
    group by 1,2,3,4,5
)
--SITE W/O SRS CUST
select 'site_wo_qsc' kpi_code,'IM3' brand,a.site_id,count(a.site_id) metric,current_datetime('+7') process_dt,'SITE012' kpi_id,vdt_id dt_id
from sites a
left join acq_qsc b 
on a.new_site_id=b.srs_site or a.old_site_id=b.srs_site --202306 mtd_site to srs_site
where b.srs_site is null
group by 1,2,3,5,6,7
union all
--SITE >=25 SRS CUST
select 'site_25qsc' kpi_code,'IM3' brand,site_id,count(site_id) metric,current_datetime('+7') process_dt,'SITE015' kpi_id,vdt_id dt_id
from (
    select a.site_id,sum(qsc) qsc
    from sites a
    join acq_qsc b
    on a.new_site_id=b.srs_site or a.old_site_id=b.srs_site --202306 mtd_site to srs_site
    group by 1
    ) a
where qsc>=25
group by 1,2,3,5,6,7
union all
--SITE >=40 SRS CUST Start 20230101
select 'site_40qsc' kpi_code,'IM3' brand,site_id,count(site_id) metric,current_datetime('+7') process_dt,'SITE015' kpi_id,vdt_id dt_id
from (
    select a.site_id,sum(qsc) qsc
    from sites a
    join acq_qsc b
    on a.new_site_id=b.srs_site or a.old_site_id=b.srs_site --202306 mtd_site to srs_site
    group by 1
    ) a
where qsc>=40
group by 1,2,3,5,6,7
union all
--SITE <40 SRS CUST Start 20230101
select 'site_less_40qsc' kpi_code,'IM3' brand,site_id,count(site_id) metric,current_datetime('+7') process_dt,'SITE023' kpi_id,vdt_id dt_id
from (
    select a.site_id,sum(qsc) qsc
    from sites a
    join acq_qsc b
    on a.new_site_id=b.srs_site or a.old_site_id=b.srs_site --202306 mtd_site to srs_site
    group by 1
    ) a
where qsc<40
group by 1,2,3,5,6,7
union all
--SITE SRS CUST
select 'site_qsc' kpi_code,'IM3' brand,site_id,count(site_id) metric,current_datetime('+7') process_dt,'SITE026' kpi_id,vdt_id dt_id
from (
    select a.site_id,sum(qsc) qsc
    from sites a
    join acq_qsc b
    on a.new_site_id=b.srs_site or a.old_site_id=b.srs_site --202306 mtd_site to srs_site
    group by 1
    ) a
where qsc>0
group by 1,2,3,5,6,7
union all
--QSC
select 'acq_qsc_m0' kpi_code,'IM3' brand,srs_site,sum(qsc) metric,current_datetime('+7') process_dt,'SND070' kpi_id,dt_id
from acq_qsc
where date_trunc(ga_dt,month)=date_trunc(srs_dt,month)
group by 1,2,3,5,6,7
union all
--QSC Revenue
select 'acq_qsc_m0_rev' kpi_code,'IM3' brand,srs_site,sum(acq_rev) metric,current_datetime('+7') process_dt,'SND071' kpi_id,dt_id
from acq_qsc
where date_trunc(ga_dt,month)=date_trunc(srs_dt,month)
group by 1,2,3,5,6,7
union all
--DSF QSC
select 'dsf_acq_qsc_m0' kpi_code,'IM3' brand,srs_site,sum(qsc) metric,current_datetime('+7') process_dt,'SND073' kpi_id,dt_id
from acq_qsc
where date_trunc(ga_dt,month)=date_trunc(srs_dt,month)
and channel_grp='DSF'
group by 1,2,3,5,6,7
union all
--DSF QSC REV
select 'dsf_acq_qsc_m0_rev' kpi_code,'IM3' brand,srs_site,sum(acq_rev) metric,current_datetime('+7') process_dt,'SND074' kpi_id,dt_id
from acq_qsc
where date_trunc(ga_dt,month)=date_trunc(srs_dt,month)
and channel_grp='DSF'
group by 1,2,3,5,6,7
;

delete from `data-bi-prd-935c.bi_mart`.kpi_site_wise_dly
where dt_id = vdt_id and kpi_id in ('SITE001','SITE024');
-------------------- SITES ----------------------
------------------ SITEWISE ---------------------
-------------------------------------------------
insert into `data-bi-prd-935c.bi_mart`.kpi_site_wise_dly
with sites as (
    select site_id,old_site_id,new_site_id,addressable,total_site_im3
    from `data-bi-prd-935c.bi_mart`.total_site_ioh_mth
    where date(month_id)=date_trunc(vdt_id,month)
    and total_site_im3=1
)
--TOTAL SITE
select 'site_total' kpi_code,'IM3' brand,site_id,sum(total_site_im3) metric,current_datetime('+7') process_dt,'SITE001' kpi_id,vdt_id dt_id
from sites
group by 1,2,3,5,6,7
union all
--SITE ADDRESSABLE
select 'site_addressable' kpi_code,'IM3' brand,site_id,sum(total_site_im3) metric,current_datetime('+7') process_dt,'SITE024' kpi_id,vdt_id dt_id
from sites
where addressable like '%ADDRESSABLE%SITE%'
group by 1,2,3,5,6,7
;

