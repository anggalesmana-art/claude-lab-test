
declare vdt_id date default @vdt_id;
--REF CHANNEL ORGANIZATION
delete from `data-bi-prd-935c.bi_mart`.ref_channel_org where dt_id = vdt_id;
insert into `data-bi-prd-935c.bi_mart`.ref_channel_org
select channel,organization_type,organization_id,last_trx_dt,vdt_id dt_id
from (
select channel,organization_type,organization_id,last_trx_dt,
ROW_NUMBER() OVER (PARTITION BY organization_id ORDER BY last_trx_dt desc) as rn
from (
select channel,organization_type,organization_id,dt_id last_trx_dt,vdt_id dt_id
from
(select channel,organization_type,organization_id,dt_id,
ROW_NUMBER() OVER (PARTITION BY organization_id ORDER BY dt_id desc) as rn
from `data-bi-prd-935c.bi_mart`.sellout_salmo_dly
where dt_id=vdt_id) a
where rn=1
union all
select * from `data-bi-prd-935c.bi_mart`.ref_channel_org
where dt_id=vdt_id - interval 1 day) a
) a
where rn=1;