declare vdt_id date default @vdt_id;
delete from `data-bi-prd-935c.bi_mart`.fct_ga_site_id where dt = vdt_id;

insert into `data-bi-prd-935c.bi_mart`.fct_ga_site_id
select distinct a.ga_date as dt, a.sbscrptn_ek_id, coalesce(site_id_90, 'N/A') as site_id
from `data-bi-prd-935c.bi_mart`.project_ioh_fu_master_v2 a
left outer join
(
 select distinct dt, sbscrptn_ek_id, site_id_90
 from `data-bi-prd-935c.bi_mart`.ioh_subscriber_site_attribs_rolling
 where dt = vdt_id
) b on a.ga_date = b.dt and a.sbscrptn_ek_id = b.sbscrptn_ek_id
where a.ga_date = vdt_id;
