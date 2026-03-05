declare vdt_id date default @vdt_id;

delete from `data-bi-prd-935c.bi_mart.msc_detail_3id` where dt_id = vdt_id;

insert into `data-bi-prd-935c.bi_mart.msc_detail_3id`
select date(dt_id) dt_id,
    'MT Offnet' as tag,
    called_party_number as sbscrptn_msisdn,
    sum(cast(duration as int)) as usage
from `data-dtp-prd-aa1a.sor.msc_detail_3id`
where dt_id = timestamp(vdt_id)
    and substring(called_party_number, 1, 5) in ('62895', '62896', '62897', '62898', '62899')
    and substring(calling_party_number, 1, 5) not in (
        '62895',
        '62896',
        '62897',
        '62898',
        '62899',
        '62814',
        '62815',
        '62816',
        '62855',
        '62856',
        '62857',
        '62858'
    )
    and service_type = 'MTC'
    and cast(duration as int) >= 6
group by 1,2,3;