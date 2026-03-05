declare vdt_id date default @vdt_id;


delete from `data-bi-prd-935c.bi_mart`.recharge_lacci_dly where dt_id = vdt_id;
insert into `data-bi-prd-935c.bi_mart`.recharge_lacci_dly 
select case when substr(msisdn, 1, 2) <> '62' then concat ('62', msisdn) else msisdn end as msisdn, lac_id lac, cell_id ci, sum(cast(rld_amt as bigint)) rld_amt, vdt_id dt_id
from `data-dtp-prd-aa1a.stg.stg_map_gw_rechrg`
where date(dt_id) = vdt_id
group by case when substr(msisdn, 1, 2) <> '62' then concat ('62', msisdn) else msisdn end, lac_id, cell_id
;