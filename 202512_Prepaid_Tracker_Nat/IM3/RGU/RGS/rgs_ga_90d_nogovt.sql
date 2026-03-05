declare vdt_id date default @vdt_id;

--- Stage 1 : Segregate GA and Churn Back;
CREATE OR REPLACE TABLE `data-bi-prd-935c.bi_mart`.rgs_ga_cb_{{ vdt_id }} AS
SELECT a.dt_id, a.msisdn, a.actvn_dt, a.svc_class_code, a.usg_flag, ifnull(a.rev_90,0) total_rev, a.site_id_90 site_id
  , case when a.actvn_dt=b.actvn_dt THEN 'NO' else 'YES' end recycled
  , case when a.msisdn=b.msisdn then 'YES' else 'NO' end churn_back
FROM `data-bi-prd-935c.bi_mart`.rgs_all_nogovt_dly a
left join `data-bi-prd-935c.bi_mart`.first_rgs_govt b
  on a.msisdn=b.msisdn and b.mth_id = date_trunc(vdt_id - interval 1 month,month)
WHERE a.dt_id = vdt_id
  AND a.flag LIKE '%B%' -- GA 90D
;


--- Stage 2 : Add site
CREATE OR REPLACE TABLE `data-bi-prd-935c.bi_mart`.rgs_ga_cb_site_{{ vdt_id }} AS
with
all_ga_null_before_today as (
  select dt_id, msisdn
  from `data-bi-prd-935c.bi_mart`.rgs_ga_cb_{{ vdt_id }}
  where site_id is null
  union all
  select dt_id, msisdn
  from `data-bi-prd-935c.bi_mart`.rgs_ga_90d_dly_govt
  where dt_id >= date_trunc(vdt_id,month)
    and dt_id < vdt_id -- until yesterday
    and site_id is null
),
favloc as (
  select msisdn, site_id, site_dt, ga_dt
  from (
    SELECT a.msisdn, a.site_id, a.dt_id AS site_dt, b.dt_id ga_dt
      , ROW_NUMBER() OVER (PARTITION BY a.msisdn ORDER BY a.dt_id) rk
    FROM `data-bi-prd-935c.bi_mart`.all_90d_fav_loc_dly a
    inner join all_ga_null_before_today b
      on a.msisdn=b.msisdn
    WHERE a.dt_id >= date_trunc(vdt_id,month)
      AND a.dt_id <= vdt_id
      AND a.site_id IS NOT NULL
  ) x
  where rk=1
)
select a.msisdn, a.actvn_dt, a.usg_flag, a.total_rev, a.svc_class_code
  , a.churn_back, a.recycled
  , coalesce(a.site_id,b.site_id) site_id
  , case when a.site_id is not null then a.dt_id else b.site_dt end site_dt
  , timestamp(current_datetime('+7')) ppn_dttm
  , a.dt_id
from `data-bi-prd-935c.bi_mart`.rgs_ga_cb_{{ vdt_id }} a
left join favloc b
  on a.msisdn=b.msisdn
union all
select a.msisdn, a.actvn_dt, a.usg_flag, a.total_rev, a.svc_class_code
  , a.churn_back, a.recycled
  , coalesce(a.site_id,b.site_id) site_id
  , coalesce(a.site_dt,b.site_dt) site_dt
  , ppn_dttm
  , a.dt_id
from `data-bi-prd-935c.bi_mart`.rgs_ga_90d_dly_govt a
left join favloc b
  on a.msisdn=b.msisdn
  where dt_id >= date_trunc(vdt_id,month)
    and dt_id < vdt_id
;


delete from `data-bi-prd-935c.bi_mart`.rgs_ga_90d_dly_govt where dt_id between date_trunc(vdt_id,month) and vdt_id;
INSERT INTO `data-bi-prd-935c.bi_mart`.rgs_ga_90d_dly_govt
select * from `data-bi-prd-935c.bi_mart`.rgs_ga_cb_site_{{ vdt_id }};

--- Drop Temp Table
DROP TABLE `data-bi-prd-935c.bi_mart`.rgs_ga_cb_{{ vdt_id }} ;
DROP TABLE `data-bi-prd-935c.bi_mart`.rgs_ga_cb_site_{{ vdt_id }} ;
