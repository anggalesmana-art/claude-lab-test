--Script Migrated by Indra Maulana Ikhsan 20241120
--- Incoming Voice and SMS
declare vdt_id date default @vdt_id;
create or replace table `data-bi-prd-935c.bi_mart`.tmp_rgu_msc_{{ vdt_id }}  as
select distinct b_p_num msisdn
from (
  -- Voice Incoming
	select b_p_num, case when a_p_num like '628%' and length(a_p_num)>=10 then 'LONG NUMBER' else a_p_num end a_p_num
	from `data-bi-prd-935c.bi_mart`.msc_dly
	where dt_id = vdt_id
		AND substr(b_p_num,1,5) IN ('62814', '62815', '62816', '62855', '62856', '62857', '62858')
		AND substr(a_p_num,1,5) NOT IN ('62814', '62815', '62816', '62855', '62856', '62857', '62858', '62895', '62896',  '62897', '62898', '62899')
		and length(a_p_num)>=10
    and regexp_contains(a_p_num,'^[0-9]*$')
		and service_type in ('MTC')
		and max_duration>=6
	union all
  -- SMS Incoming
	select b_p_num, case when a_p_num like '628%' and length(a_p_num)>=10 then 'LONG NUMBER' else a_p_num end a_p_num
	from `data-bi-prd-935c.bi_mart`.msc_dly
	where dt_id = vdt_id
		AND substr(b_p_num,1,5) IN ('62814', '62815', '62816', '62855', '62856', '62857', '62858')
		AND substr(a_p_num,1,5) NOT IN ('62814', '62815', '62816', '62855', '62856', '62857', '62858', '62895', '62896',  '62897', '62898', '62899')
		and length(a_p_num)>=10
    and regexp_contains(a_p_num,'^[0-9]*$')
		and service_type in ('SMSMT')
) x
;