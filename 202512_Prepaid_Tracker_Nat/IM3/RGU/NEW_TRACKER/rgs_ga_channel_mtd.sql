declare vdt_id date default @vdt_id;
--- MTD
delete from `data-bi-prd-935c.bi_mart`.rgs_ga_channel_mtd_smy where dt_id = vdt_id;
INSERT into `data-bi-prd-935c.bi_mart`.rgs_ga_channel_mtd_smy
SELECT site_id, channel_grp, 
CASE WHEN flag_acm IN ( 'c. >=35k - <50k', 'd. >=50k' ) then 'HVC'
	 WHEN flag_acm IN ( 'a. >=10k - <25k', 'b. >=25k - <35k', 'd. >=10k' ) then 'MVC'
	 WHEN flag_acm IN ( 'a. <5k', 'b. >=5k - <7k', 'c. >=7k - <10k' ) then 'LVC'
END flag_inject, count(1) subs, sum(c.total_rev) acq_rev,
timestamp(current_datetime('+7')) ppn_dttm, vdt_id dt_id
FROM `data-bi-prd-935c.bi_mart`.rgs_ga_90d_dly_govt a
LEFT JOIN `data-bi-prd-935c.bi_mart`.rgs_ga_channel_mth_govt b  
ON a.msisdn = b.msisdn AND b.month_id = date_trunc(vdt_id,month)
LEFT JOIN `data-bi-prd-935c.bi_mart`.rgs_mtd_govt c
ON a.msisdn = c.msisdn AND c.dt_id = vdt_id
WHERE a.dt_id BETWEEN date_trunc(vdt_id,month) AND vdt_id
  AND (churn_back = 'NO' OR recycled = 'YES')
GROUP BY 1, 2, 3 ;