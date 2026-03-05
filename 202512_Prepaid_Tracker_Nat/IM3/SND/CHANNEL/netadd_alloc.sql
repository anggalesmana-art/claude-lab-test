declare vdt_id date default @vdt_id;

create or replace table `data-bi-prd-935c.bi_stg`.tmp_dealer_ga_{{ vdt_id }} as
select vdt_id dt_id,dealer_code,channel,sales_cluster,count(distinct a.msisdn) ga_90d
from `data-bi-prd-935c.bi_mart`.rgs_ga_90d_dly_govt a
left join (select a.dealer dealer_code,b.channel,b.sales_cluster,msisdn
from `data-bi-prd-935c.bi_mart`.foss_sp_mth a
left join (select dealer_code,channel,sales_cluster 
from (select dealer_code,channel,sales_cluster,
ROW_NUMBER() OVER (partition by dealer_code ORDER BY dt_id desc) AS rn
from `data-bi-prd-935c.bi_mart`.foss_dealer_mth
where mth_id = date_trunc(vdt_id,month)
and organization_status='Active') a
where rn=1) b on a.dealer=b.dealer_code
where mth_id=date_trunc(vdt_id,month)) b on a.msisdn=b.msisdn
where dt_id between date_trunc(vdt_id,month) and vdt_id
and (churn_back='NO' or recycled='YES')
group by 1,2,3,4;


create or replace table `data-bi-prd-935c.bi_stg`.tmp_dealer_churn_{{ vdt_id }} as
select vdt_id dt_id,dealer_code,channel,sales_cluster,count(distinct a.msisdn) churn_90d
from `data-bi-prd-935c.bi_mart`.rgs_churn_90d_dly_govt a
left join (select a.dealer dealer_code,b.channel,b.sales_cluster,msisdn
from `data-bi-prd-935c.bi_mart`.foss_sp_mth a
left join (select dealer_code,channel,sales_cluster 
from (select dealer_code,channel,sales_cluster,
ROW_NUMBER() OVER (partition by dealer_code ORDER BY dt_id desc) AS rn
from `data-bi-prd-935c.bi_mart`.foss_dealer_mth
where mth_id = date_trunc(vdt_id,month)
and organization_status='Active') a
where rn=1) b on a.dealer=b.dealer_code
where mth_id=date_trunc(vdt_id,month)) b on a.msisdn=b.msisdn
where dt_id between date_trunc(vdt_id,month) and vdt_id
group by 1,2,3,4;


create or replace table `data-bi-prd-935c.bi_stg`.tmp_dealer_churn_back_{{ vdt_id }} as
select vdt_id dt_id,dealer_code,channel,sales_cluster,count(distinct a.msisdn) churn_back_90d
from `data-bi-prd-935c.bi_mart`.rgs_churn_back_90d_govt a
left join (select a.dealer dealer_code,b.channel,b.sales_cluster,msisdn
from `data-bi-prd-935c.bi_mart`.foss_sp_mth a
left join (select dealer_code,channel,sales_cluster 
from (select dealer_code,channel,sales_cluster,
ROW_NUMBER() OVER (partition by dealer_code ORDER BY dt_id desc) AS rn
from `data-bi-prd-935c.bi_mart`.foss_dealer_mth
where mth_id = date_trunc(vdt_id,month)
and organization_status='Active') a
where rn=1) b on a.dealer=b.dealer_code
where mth_id=date_trunc(vdt_id,month)) b on a.msisdn=b.msisdn
where dt_id between date_trunc(vdt_id,month) and vdt_id
group by 1,2,3,4;


create or replace table `data-bi-prd-935c.bi_stg`.tmp_dealer_churn_30d_{{ vdt_id }} as
select vdt_id dt_id,dealer_code,channel,sales_cluster,count(distinct a.msisdn) churn_30d
from `data-bi-prd-935c.bi_mart`.rgs_churn_30d_dly_govt a
left join (select a.dealer dealer_code,b.channel,b.sales_cluster,msisdn
from `data-bi-prd-935c.bi_mart`.foss_sp_mth a
left join (select dealer_code,channel,sales_cluster 
from (select dealer_code,channel,sales_cluster,
ROW_NUMBER() OVER (partition by dealer_code ORDER BY dt_id desc) AS rn
from `data-bi-prd-935c.bi_mart`.foss_dealer_mth
where mth_id = date_trunc(vdt_id,month)
and organization_status='Active') a
where rn=1) b on a.dealer=b.dealer_code
where mth_id=date_trunc(vdt_id,month)) b on a.msisdn=b.msisdn
where dt_id between date_trunc(vdt_id,month) and vdt_id
group by 1,2,3,4;


create or replace table `data-bi-prd-935c.bi_stg`.tmp_dealer_churn_back_30d_{{ vdt_id }} as
select vdt_id dt_id,dealer_code,channel,sales_cluster,count(distinct a.msisdn) churn_back_30d
from `data-bi-prd-935c.bi_mart`.rgs_churn_back_30d_govt a
left join (select a.dealer dealer_code,b.channel,b.sales_cluster,msisdn
from `data-bi-prd-935c.bi_mart`.foss_sp_mth a
left join (select dealer_code,channel,sales_cluster 
from (select dealer_code,channel,sales_cluster,
ROW_NUMBER() OVER (partition by dealer_code ORDER BY dt_id desc) AS rn
from `data-bi-prd-935c.bi_mart`.foss_dealer_mth
where mth_id = date_trunc(vdt_id,month)
and organization_status='Active') a
where rn=1) b on a.dealer=b.dealer_code
where mth_id=date_trunc(vdt_id,month)) b on a.msisdn=b.msisdn
where dt_id between date_trunc(vdt_id,month) and vdt_id
group by 1,2,3,4;

delete from `data-bi-prd-935c.bi_mart`.netadd_alloc where dt_id = vdt_id;
insert into `data-bi-prd-935c.bi_mart`.netadd_alloc 
select coalesce(a.dealer_code,b.dealer_code) dealer_code,
coalesce(a.channel,b.channel) channel,
case when coalesce(a.sales_cluster,b.sales_cluster) like 'CW-%' then 'CWJ'
when coalesce(a.sales_cluster,b.sales_cluster) like 'EB-%' then 'EJBN'
when coalesce(a.sales_cluster,b.sales_cluster) like 'JB-%' then 'JABO'
when coalesce(a.sales_cluster,b.sales_cluster) like 'KS-%' then 'KALISULA'
when coalesce(a.sales_cluster,b.sales_cluster) like 'S-%' then 'SUMATERA'
else coalesce(a.sales_cluster,b.sales_cluster) end region,
coalesce(a.sales_cluster,b.sales_cluster) sales_cluster,
sum(coalesce(ga_90d,0)) ga_90d,
sum(coalesce(churn_90d,0)) churn_90d,
sum(coalesce(churn_back_90d,0)) churn_back_90d,
sum(coalesce(ga_90d,0)-coalesce(churn_90d,0)+coalesce(churn_back_90d,0)) net_add_90d,
sum(coalesce(churn_30d,0)) churn_30d,
sum(coalesce(churn_back_30d,0)) churn_back_30d,
sum(coalesce(ga_90d,0)-coalesce(churn_30d,0)+coalesce(churn_back_30d,0)+coalesce(churn_back_90d,0)) net_add_30d,
coalesce(a.dt_id,b.dt_id) dt_id
from 
(select coalesce(a.dt_id,b.dt_id,c.dt_id) dt_id,
coalesce(a.dealer_code,b.dealer_code,c.dealer_code) dealer_code,
coalesce(a.channel,b.channel,c.channel) channel,
coalesce(a.sales_cluster,b.sales_cluster,c.sales_cluster) sales_cluster,
sum(coalesce(a.ga_90d,0)) ga_90d,
sum(coalesce(b.churn_90d,0)) churn_90d,
sum(coalesce(c.churn_back_90d,0)) churn_back_90d
from 
(select * from `data-bi-prd-935c.bi_stg`.tmp_dealer_ga_{{ vdt_id }}
where dt_id=vdt_id) a
full outer join
(select * from `data-bi-prd-935c.bi_stg`.tmp_dealer_churn_{{ vdt_id }}
where dt_id=vdt_id) b on a.dealer_code=b.dealer_code
full outer join
(select * from `data-bi-prd-935c.bi_stg`.tmp_dealer_churn_back_{{ vdt_id }}
where dt_id=vdt_id) c on coalesce(a.dealer_code,b.dealer_code)=c.dealer_code
group by 1,2,3,4) a
full outer join
(select coalesce(a.dt_id,b.dt_id) dt_id,
coalesce(a.dealer_code,b.dealer_code) dealer_code,
coalesce(a.channel,b.channel) channel,
coalesce(a.sales_cluster,b.sales_cluster) sales_cluster,
sum(coalesce(a.churn_30d,0)) churn_30d,
sum(coalesce(b.churn_back_30d,0)) churn_back_30d
from 
(select * from `data-bi-prd-935c.bi_stg`.tmp_dealer_churn_30d_{{ vdt_id }}
where dt_id=vdt_id) a
full outer join
(select * from `data-bi-prd-935c.bi_stg`.tmp_dealer_churn_back_30d_{{ vdt_id }}
where dt_id=vdt_id) b on a.dealer_code=b.dealer_code
group by 1,2,3,4) b on a.dealer_code=b.dealer_code
group by 1,2,3,4,12;

drop table if exists `data-bi-prd-935c.bi_stg`.tmp_dealer_ga_{{ vdt_id }};
drop table if exists `data-bi-prd-935c.bi_stg`.tmp_dealer_churn_{{ vdt_id }};
drop table if exists `data-bi-prd-935c.bi_stg`.tmp_dealer_churn_back_{{ vdt_id }};
drop table if exists `data-bi-prd-935c.bi_stg`.tmp_dealer_churn_30d_{{ vdt_id }};
drop table if exists `data-bi-prd-935c.bi_stg`.tmp_dealer_churn_back_30d_{{ vdt_id }};