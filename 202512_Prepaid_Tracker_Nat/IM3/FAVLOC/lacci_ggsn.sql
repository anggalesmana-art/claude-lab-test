-- ggsn
declare vdt_id date default @vdt_id;


delete from  `data-bi-prd-935c.bi_mart`.ggsn_lacci_dly where dt_id = vdt_id;
insert into `data-bi-prd-935c.bi_mart`.ggsn_lacci_dly
select msisdn, lac, ci, sum(volume_uplink+volume_downlink) volume, date(recordopeningtime) dt_id
from `data-dtp-prd-aa1a.smy.ggsn_hourly_summary`
where date(recordopeningtime) = vdt_id
group by recordopeningtime, msisdn, lac, ci
having volume > 0;