
declare vdt_id date default @vdt_id;


--ORGANIZATION ID FROM SALMO

create or replace table `data-bi-prd-935c.bi_stg`.tmp_org_salmo_{{ vdt_id }} as
select organization_id,channel_grp,channel,organization_type,organization_name,
l1_parent_id,l1_parent_name,date_trunc(vdt_id,month) mth_id
from (
select organization_id,
case when channel in ('Traditional','Direct') then 'Traditional' else 'Non Traditional' end channel_grp,
channel,organization_type,organization_name,l1_parent_id,l1_parent_name,
date(parse_timestamp('%Y-%m-%d %H:%M:%S', `datetime`)) dt_id,
ROW_NUMBER() OVER (PARTITION BY organization_id ORDER BY `datetime` desc) as rn
from `data-dtp-prd-aa1a.stg`.ifrs_prepaid_salmo
where date(parse_timestamp('%Y-%m-%d %H:%M:%S', `datetime`)) between date_trunc(vdt_id,month)
and vdt_id
and ifnull(channel,'')!=''
and process_id between timestamp(date_trunc(vdt_id,month)) and timestamp(vdt_id + interval 1 day)
and coalesce(substring(b_msisdn, 1,5),'') not in ('62895', '62896', '62897', '62898', '62899')
) a
where rn=1;

delete from `data-bi-prd-935c.bi_mart`.org_salmo  where mth_id = date_trunc(vdt_id,month);
insert into  `data-bi-prd-935c.bi_mart`.org_salmo  
select organization_id,channel_grp,channel,organization_type,organization_name,
l1_parent_id,l1_parent_name,date_trunc(vdt_id,month) mth_id
from (
select organization_id,channel_grp,channel,organization_type,organization_name,
l1_parent_id,l1_parent_name,
ROW_NUMBER() OVER (PARTITION BY organization_id ORDER BY mth_id desc) as rn
from (
select * from `data-bi-prd-935c.bi_stg`.tmp_org_salmo_{{ vdt_id }}
union all
select * from `data-bi-prd-935c.bi_mart`.org_salmo
where mth_id=date_trunc(vdt_id - interval 1 month, month)) a) a
where rn=1;

drop table if exists `data-bi-prd-935c.bi_stg`.tmp_org_salmo_{{ vdt_id }};
