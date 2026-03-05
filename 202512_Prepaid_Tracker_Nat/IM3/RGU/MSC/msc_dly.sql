declare vdt_id date default @vdt_id;

delete from `data-bi-prd-935c.bi_mart`.msc_dly  where dt_id = vdt_id;
insert into `data-bi-prd-935c.bi_mart`.msc_dly 
select calling_party_number as a_p_num
, called_party_number as b_p_num
, service_type
, count(1) hits
, sum(ifnull(cast(duration as float64),0)) duration
, min(ifnull(cast(duration as float64),0)) min_duration
, max(ifnull(cast(duration as float64),0)) max_duration
, timestamp(current_datetime('+7')) ppn_dttm
, date(dt_id) dt_id
from `data-dtp-prd-aa1a.sor.msc_detail`
where date(dt_id) = vdt_id
  and service_type in ('MOC','MTC','SMSMO','SMSMT')
group by a_p_num, b_p_num, service_type, dt_id
;
