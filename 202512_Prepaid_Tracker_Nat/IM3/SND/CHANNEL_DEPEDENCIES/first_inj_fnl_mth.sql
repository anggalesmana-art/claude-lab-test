declare vdt_id date default @vdt_id;
declare vdt_mth date default date_trunc(vdt_id,month);

--- union all
delete from `data-bi-prd-935c.bi_mart`.first_inj_mth where mth_id = vdt_mth;
insert into `data-bi-prd-935c.bi_mart`.first_inj_mth
select msisdn, actvn_dt, channel, organization_id, product_name, amount_debit, main_price
  , transaction_type, transaction_id, inj_dt, timestamp(current_datetime('+7')) ppn_dttm, mth_id
from
(
  select a.*, row_number() over(partition by msisdn order by actvn_dt desc, inj_dt
    , case
      when transaction_type='SPDATA' and ifnull(organization_id,'')!='' then 1
      when transaction_type='INJ' then 2
      when transaction_type='RLD' then 3
      when transaction_type='FDV' then 4
      when transaction_type='FDV-RLD' then 5
      when transaction_type='SPDATA' then 6
      when transaction_type='VO-ORI' then 7
    end
    , main_price desc
    ) rk
  from
  (
    select msisdn, actvn_dt, channel, organization_id, product_name, amount_debit, main_price
      , case
        when lower(transaction_type) in ('purchase data package','bulk purchase package transaction') then 'INJ'
        when lower(transaction_type) in ('indosat reload','bulk reload') then 'RLD'
      end transaction_type
      , transaction_id, inj_dt, mth_id
    from `data-bi-prd-935c.bi_mart`.first_inj_salmo_mth
    where mth_id=vdt_mth
    union all
    select msisdn, actvn_dt, 'Traditional' channel, organization_id, product_name, amount_debit, main_price
      , 'FDV' transaction_type
      , transaction_id, inj_dt, mth_id
    from `data-bi-prd-935c.bi_mart`.first_inj_fdv_mth
    where mth_id=vdt_mth
    union all
    select msisdn, actvn_dt
      --, case when regexp_like(organization_id,"^[0-9]+$")=False then 'DSF' else 'Traditional' end channel /* changed at 20230112 */
      , channel
      , organization_id, product_name, amount_debit, main_price
      , 'SPDATA' transaction_type
      , NULL transaction_id, inj_dt, mth_id
    from `data-bi-prd-935c.bi_mart`.first_inj_sp_data_mth
    where mth_id=vdt_mth
    union all
    select msisdn, actvn_dt, 'Traditional' channel, organization_id, product_name, amount_debit, main_price
      , 'FDV-RLD' transaction_type
      , transaction_id, inj_dt, mth_id
    from `data-bi-prd-935c.bi_mart`.first_inj_fdv_reload_mth
    where mth_id=vdt_mth
    union all
    select msisdn, actvn_dt, 'Traditional' channel, organization_id, product_name, amount_debit, main_price
      , 'VO-ORI' transaction_type
      , sno, inj_dt, mth_id
    from `data-bi-prd-935c.bi_mart`.first_inj_vo_mth
    where mth_id=vdt_mth
  ) a
)x
where rk=1
;
