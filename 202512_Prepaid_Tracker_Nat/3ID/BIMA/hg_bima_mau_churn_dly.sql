 DECLARE vdt_id DATE DEFAULT @vdt_id;
 
  --- Temp 1 - Populate Churn

drop table if exists `data-bi-prd-935c.bi_stg.hg_tmp_bima_mau_churn_1`;


create table `data-bi-prd-935c.bi_stg.hg_tmp_bima_mau_churn_1`
 as
(
  select a.msisdn
    , a.subscriber_type
    , a.actvn_dt
    , a.tnr
    , a.site_id
  from
  (
    select * from `data-bi-prd-935c.bi_mart.bima_mau_dly`
    where dt_id = date_sub(vdt_id, interval 1 day)
  ) a
  left join
  (
    select * from `data-bi-prd-935c.bi_mart.bima_mau_dly`
    where dt_id = vdt_id 
  ) b
    on a.msisdn=b.msisdn
  where b.msisdn is null
);



  --- Temp 2 - Populate Value churn
drop table if exists `data-bi-prd-935c.bi_stg.hg_tmp_bima_mau_churn_2`;

create table `data-bi-prd-935c.bi_stg.hg_tmp_bima_mau_churn_2`  as
(
  select a.dt_id, a.msisdn, total_trx, inapp_rev, online_rev, cvm_rev, hits_trx
  from `data-bi-prd-935c.bi_mart.bima_mau_dly` a
  inner join `data-bi-prd-935c.bi_stg.hg_tmp_bima_mau_churn_1` b
    on a.msisdn=b.msisdn
  where dt_id in (date_sub(vdt_id,interval 31 day), date_sub(vdt_id,interval 62 day), date_sub(vdt_id,interval 93 day))
);

delete from `data-bi-prd-935c.bi_mart.bima_mau_churn_dly` where dt_id = vdt_id ;
  --- insert to master table

insert into `data-bi-prd-935c.bi_mart.bima_mau_churn_dly`
select cast(vdt_id as date)  dt_id
  , a.msisdn
  , a.subscriber_type
  , a.actvn_dt
  , a.tnr
  , coalesce(b.total_trx,0) total_trx_m1
  , coalesce(c.total_trx,0) total_trx_m2
  , coalesce(d.total_trx,0) total_trx_m3
  , coalesce(b.inapp_rev,0) inapp_rev_m1
  , coalesce(c.inapp_rev,0) inapp_rev_m2
  , coalesce(d.inapp_rev,0) inapp_rev_m3
  , coalesce(b.online_rev,0) online_rev_m1
  , coalesce(c.online_rev,0) online_rev_m2
  , coalesce(d.online_rev,0) online_rev_m3
  , coalesce(b.cvm_rev,0) cvm_rev_m1
  , coalesce(c.cvm_rev,0) cvm_rev_m2
  , coalesce(d.cvm_rev,0) cvm_rev_m3
  , coalesce(b.hits_trx,0) hits_trx_m1
  , coalesce(c.hits_trx,0) hits_trx_m2
  , coalesce(d.hits_trx,0) hits_trx_m3
  , a.site_id
  , current_timestamp() process_dt
from  `data-bi-prd-935c.bi_stg.hg_tmp_bima_mau_churn_1` a
left join
(
  select * from `data-bi-prd-935c.bi_stg.hg_tmp_bima_mau_churn_2`
  where dt_id = date_sub(vdt_id, interval 31 day)
) b
  on a.msisdn=b.msisdn
left join
(
  select * from `data-bi-prd-935c.bi_stg.hg_tmp_bima_mau_churn_2`
  where dt_id = date_sub(vdt_id, interval 62 day)
) c
  on a.msisdn=c.msisdn
left join
(
  select * from `data-bi-prd-935c.bi_stg.hg_tmp_bima_mau_churn_2`
  where dt_id =  date_sub(vdt_id, interval 93 day)
) d
  on a.msisdn=d.msisdn
where a.msisdn like '6289%'
;



  --- drop temp table
drop table if exists `data-bi-prd-935c.bi_stg.hg_tmp_bima_mau_churn_1`;
drop table if exists `data-bi-prd-935c.bi_stg.hg_tmp_bima_mau_churn_2`;