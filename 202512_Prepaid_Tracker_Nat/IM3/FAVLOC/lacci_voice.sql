declare vdt_id date default @vdt_id;

delete from `data-bi-prd-935c.bi_mart`.voice_lacci_dly  where dt_id = vdt_id;
insert into `data-bi-prd-935c.bi_mart`.voice_lacci_dly 
select msisdn, lac, ci, count(*) hits, sum(duration) duration, vdt_id dt_id
from (
  -- outgoing
  select dt_id, calling_party_number msisdn, calling_number_lac_new lac,
    calling_number_ci_new ci, cast(duration as decimal) duration
  from `data-dtp-prd-aa1a.sor.msc_detail`
  where service_type IN ('MOC') AND
  date(dt_id) = vdt_id and
  --length(calling_party_number) >= 10 and length(calling_party_number) < 17 and
  --length(called_party_number) >= 10 and length(called_party_number) < 17 and
  substr(calling_party_number, 1, 5) IN ('62814', '62815', '62816', '62855', '62856', '62857', '62858')
  union ALL
  -- incoming
  select dt_id, called_party_number msisdn,
    called_number_lac_new lac,
    called_number_ci_new ci,
    cast(duration as decimal) duration
  from `data-dtp-prd-aa1a.sor.msc_detail`
  where service_type IN ('MTC') AND
  date(dt_id) = vdt_id and
  --length(calling_party_number) >= 10 and length(calling_party_number) < 17 and
  --length(called_party_number) >= 10 and length(called_party_number) < 17 and
  substr(called_party_number,1,5) IN ('62814', '62815', '62816', '62855', '62856', '62857', '62858')
) a
group by msisdn, lac, ci
;