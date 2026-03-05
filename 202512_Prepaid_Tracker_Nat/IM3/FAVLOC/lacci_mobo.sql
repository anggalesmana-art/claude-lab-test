-- mobo
declare vdt_id date default @vdt_id;

delete from  `data-bi-prd-935c.bi_mart`.mobo_lacci_dly where dt_id =vdt_id;

insert into `data-bi-prd-935c.bi_mart`.mobo_lacci_dly 
select msisdn, lac, ci, amount_debit, dt_id
from
(
    select b_msisdn as msisdn, a_lac_dec as lac, a_ci_dec as ci, sum(cast(amount_debit as decimal)) amount_debit, vdt_id dt_id
  from `data-dtp-prd-aa1a.stg.ifrs_prepaid_salmo`
  where SAFE.PARSE_DATE('%Y-%m-%d', substr(`datetime`,1,10)) = vdt_id
    and lower(transaction_type) in ('bulk purchase package transaction','purchase data package')
    and lower(transaction_status) = 'completed'
    and lower(status_description) = 'success'
    and date(process_id) between date_trunc(vdt_id,month) and date(vdt_id + interval 1 day)
    and coalesce(substring(b_msisdn, 1,5),'') not in ('62895', '62896', '62897', '62898', '62899')
  group by b_msisdn, a_lac_dec, a_ci_dec
  union all
  select b_msisdn as msisdn, b_lac_dec as lac, b_ci_dec as ci, sum(cast(amount_debit as decimal)) amount_debit, vdt_id dt_id
  from `data-dtp-prd-aa1a.stg.ifrs_prepaid_salmo`
  where SAFE.PARSE_DATE('%Y-%m-%d', substr(`datetime`,1,10)) = vdt_id
    and lower(transaction_type) in ('bulk purchase package transaction','purchase data package')
    and lower(transaction_status) = 'completed'
    and lower(status_description) = 'success'
    and date(process_id) between date_trunc(vdt_id,month) and date(vdt_id + interval 1 day)
    and coalesce(substring(b_msisdn, 1,5),'') not in ('62895', '62896', '62897', '62898', '62899')
  group by b_msisdn, b_lac_dec, b_ci_dec
) a;

-- max

delete from `data-bi-prd-935c.bi_mart`.mobo_max_loc_dly  where dt_id = vdt_id;
insert into `data-bi-prd-935c.bi_mart`.mobo_max_loc_dly 
select msisdn, lac, ci, vdt_id dt_id
from (
  select msisdn, lac, ci, row_number() over (partition by msisdn order by amount_debit desc) as idx
  from (
    select msisdn, lac, ci, sum(amount_debit) amount_debit
    from `data-bi-prd-935c.bi_mart`.mobo_lacci_dly
    where dt_id = vdt_id and ( (ifnull(lac,'')!='' or ifnull(ci,'')!='') and (safe_cast(lac as int)!=0 or safe_cast(ci as int)!=0) )
    group by msisdn, lac, ci
  ) a
) a
where idx = 1
;