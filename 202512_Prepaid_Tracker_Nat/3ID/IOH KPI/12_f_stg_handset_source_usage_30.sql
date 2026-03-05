DECLARE vdt_id DATE DEFAULT @vdt_id;


drop table if exists `data-bi-prd-935c.bi_mart.dm_usage_band_30`;
create table `data-bi-prd-935c.bi_mart.dm_usage_band_30`
	as
	with subs as (select * from `data-dtptechm-prd-c7ca.dwh.sbscrptn_attribs`)
	select sbscrptn_ek_id, 
	       case when LTE_Usage > 0 then '4G'
	    when Usage_3g > 0 then '3G'
	    when Usage_2g > 0 then '2G'
	    else 'Unknown'
	       end band
	from (
	select vdt_id dt_sk_id, 
	       a.sbscrptn_ek_id,
	       case when product_id = 8 then 'prepaid' else 'postpaid' end prepaid_flag,
	      SUM(case when rat_type = '6' THEN (coalesce(usage,0)) ELSE 0 END)/(1024*1024*1024) as LTE_Usage,                                       
	      SUM(case when rat_type IN ('1','5') THEN (coalesce(usage,0)) ELSE 0 END)/(1024*1024*1024) as USAGE_3G,                           
	      SUM(case when rat_type = '2' THEN (coalesce(usage,0)) ELSE 0 END)/(1024*1024*1024) as USAGE_2G,
	      sum(usage) usage,
	      SUM(case when gprs_rating_grp_nm in ('Normal GPRS Modifier','Pay as you go - GPPEK') THEN (coalesce(usage,0)) ELSE 0 END) as USAGE_PYU,
	      SUM(case when coalesce(gprs_rating_grp_nm,'') not in ('GPRS Default Modifier','Pay as you go - GPPEK') THEN (coalesce(usage,0)) ELSE 0 END) as USAGE_package
	from `data-bi-prd-935c.bi_mart.project_ioh_data_imei_usage` a
	left join subs b on a.sbscrptn_ek_id = b.sbscrptn_ek_id 
	where dt_sk_id <= vdt_id 
	and dt_sk_id >=DATE_SUB(vdt_id, INTERVAL 29 DAY)
	and tool_of_trade_ind = 'N'
	group by 1,2,3
	) a;
