declare vdt_id date default @vdt_id;



delete from `data-bi-prd-935c.bi_dev`.ioh_snd_master_kpi_detail where brand = '3ID' and dt_id = vdt_id and kpi in ('vlr_subs_act','vlr_subs_wo_act') and time_flag = 'dly';

insert into `data-bi-prd-935c.bi_dev`.ioh_snd_master_kpi_detail
select '3ID' as brand, 
'site_id',
site_id,
sum(subs),
'dly',
current_timestamp,
case when flag = 'No Activity' then 'vlr_subs_wo_act' else 'vlr_subs_act' end kpi_name, 
dt_id
from `data-bi-prd-935c.bi_mart`.vlr_site_activity a
where dt_id = vdt_id 
and dt_id not in ('2024-01-01','2024-01-02','2024-01-20','2024-01-28') -- takeout incomplete data
group by 1,2,3,5,6,7,8;



delete from `data-bi-prd-935c.bi_dev`.ioh_snd_master_kpi_detail where brand = '3ID' and dt_id = vdt_id and kpi in ('vlr_subs_act','vlr_subs_wo_act') and time_flag = 'mtd';

insert into `data-bi-prd-935c.bi_dev`.ioh_snd_master_kpi_detail
	with
	outgoing as (
	  select distinct load_dt_sk_id as dt_id, sbscrptn_ek_id, 1 flag_outgoing
	  from `data-bi-prd-935c.bi_mart`.project_rguog_subs_detail
	  where load_dt_sk_id between  date_trunc(vdt_id,month)  and vdt_id
	),
	incoming as (
	  select dt_id, sbscrptn_ek_id, 1 flag_incoming
	  from `data-bi-prd-935c.bi_mart`.stg_incoming
	  where dt_id between  date_trunc(vdt_id,month)  and vdt_id
	)
	select brand, 'site_id',site_id, count(distinct sbscrptn_ek_id), 'mtd', current_timestamp, 
	case
		  when flag_outgoing>=1 or  flag_incoming>=1 then 'vlr_subs_act'
		  else 'vlr_subs_wo_act'
		end kpi_name , vdt_id
		 from 
			(
				select vdt_id dt_id, '3ID' brand, site_id,a.sbscrptn_ek_id, sum(flag_incoming) flag_incoming, sum(flag_outgoing) flag_outgoing
				from `data-bi-prd-935c.bi_mart`.stg_vlr_site_tenure a
				left join outgoing b
				  on a.sbscrptn_ek_id=b.sbscrptn_ek_id and a.dt_id=b.dt_id
				left join incoming c
				  on a.sbscrptn_ek_id=c.sbscrptn_ek_id and a.dt_id=c.dt_id
				where a.dt_id  between  date_trunc(vdt_id,month)  and vdt_id
				  and flag_subs='PREPAID'
				and a.dt_id not in ('2024-01-01','2024-01-02','2024-01-20','2024-01-28') -- takeout incomplete data

				group by 1,2,3,4 
			) x 
		group by  1,2,3,5,6,7,8 
;
