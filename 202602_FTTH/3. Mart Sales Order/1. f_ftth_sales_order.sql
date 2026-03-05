CREATE OR REPLACE PROCEDURE `data-bi-prd-935c.bi_dm.f_ftth_sales_order`(IN starts_date DATE, IN observation_date DATE)
BEGIN
  DECLARE end_of_month DATE;
  DECLARE eop_previous_month DATE;
  DECLARE start_prev_month DATE;
  DECLARE start_current_month DATE;
  DECLARE yday_date DATE;

  SET end_of_month = LAST_DAY(observation_date, MONTH);
  SET eop_previous_month = LAST_DAY(DATE_SUB(observation_date, INTERVAL 1 MONTH));
  SET start_prev_month = DATE_TRUNC(eop_previous_month, MONTH);
  SET start_current_month = DATE_TRUNC(observation_date, MONTH);

  WHILE starts_date <= observation_date DO
    delete from `data-bi-prd-935c.bi_dm.ftth_cst_new_sales_order`
    where dt_id = starts_date;

    INSERT INTO `data-bi-prd-935c.bi_dm.ftth_cst_new_sales_order`
    WITH RBMAC AS (
      select distinct account_num, customer_ref, account_name
      from `data-dtp-prd-aa1a.stg.stg_rbm_dly_ac`
      where date(dt_id) = starts_date
    ),
    DLYBA AS (
      select * from (
        select ba_id, mbl_no, adr_line_2, email, row_number() over(partition by ba_id order by dt_id desc) rk   
        from `data-dtp-prd-aa1a.stg.stg_catalist_dly_ba`
        where date(dt_id) = starts_date
      )
      where rk = 1
    ),
    AST AS (
      select * from (
        select ba_id, pd_nm, pd_id, row_number() over(partition by ba_id order by dt_id desc) rk   
        from `data-dtp-prd-aa1a.stg.stg_catalist_dly_ordr`
        where date(dt_id) = starts_date
        and pd_tp = 'Plan'
      ) a 
      where rk = 1
    ),
    SALEPSN AS (
      select * from (
        select ba_id, sale_psn, row_number() over(partition by ba_id order by dt_id desc) rk   
        from `data-dtp-prd-aa1a.stg.stg_catalist_dly_ordr`
        where date(dt_id) = starts_date
        and sale_psn <> ''
        and sale_psn is not null
      ) a 
      where rk = 1
    ),
    HPM AS (
      select *
      from `data-bi-prd-935c.bi_dm.ftth_hpm`
      where prc_dt = (select max(prc_dt) from `data-bi-prd-935c.bi_dm.ftth_hpm`)
    )
    select * except(rk)
    from (
      select
        'HIFI' flag_customer,
        a.ca_id customer_account_id,
        a.ba_id billing_account_id,
        customer_ref customer_id,
        regexp_replace(a.svc_id, 'FH_', '') billing_account,
        account_name asset_name,
        mbl_no customer_phone,
        email customer_email,
        adr_line_2 cust_addres,
        d.pd_nm product_name,
        d.pd_id product_id, 
        ordr_tp order_type,
        null mrc,
        date(parse_timestamp('%d-%m-%Y %H:%M:%S', a.ordr_crt_dt)) so_date,
        case
          when upper(a.ftth_partnername) like '%ASIANET%' and a.ftth_deviceid not like '%#%' then concat('ASIANET MEDIA TEKNOLOGI#', a.ftth_deviceid)
          when upper(a.ftth_partnername) like '%IFORTE%' and a.ftth_deviceid not like '%#%'  then concat('IFORTE SOLUSI INFOTEK#', a.ftth_deviceid)
          else a.ftth_deviceid
        end as hpid,
        case
          when REGEXP_EXTRACT(a.ftth_deviceid, r'#(.*)') is null then a.ftth_deviceid
          else REGEXP_EXTRACT(a.ftth_deviceid, r'#(.*)')
        end as homepass_id,
        e.siteid site_id,
        '1. Consom' site_priority,
        province sa_province,
        city sa_kabkot,
        district sa_kecamatan,
        subdistrict sa_kelurahan,
        UPPER(coalesce(a.sale_psn, f.sale_psn)) salesperson,
        cast(null as string) sales_code,
        dt_id ppn_dtm,
        date(parse_timestamp('%d-%m-%Y %H:%M:%S', a.ordr_crt_dt)) dt_id,
        row_number() over(partition by regexp_replace(a.svc_id, 'FH_', '') order by date(parse_timestamp('%d-%m-%Y %H:%M:%S', a.ordr_crt_dt)) desc) rk
      from `data-dtp-prd-aa1a.stg.stg_catalist_dly_ordr`  a
      left join RBMAC b
      on regexp_replace(svc_id, 'FH_', '') = b.account_num 
      left join DLYBA c 
      on a.ba_id = c.ba_id
      left join AST d 
      on a.ba_id = d.ba_id
      left join HPM e 
      on a.ftth_deviceid = e.hpid
      left join SALEPSN f 
      on a.ba_id = f.ba_id
      where date(a.dt_id) = starts_date
      and ordr_tp = 'New Registration'
      -- and ordr_st = 'In Progress'
      and (a.svc_id is not null and a.svc_id <> '')
      and date(parse_timestamp('%d-%m-%Y %H:%M:%S', a.ordr_crt_dt)) = starts_date
      -- and a.pd_cgy = 'FTTH'
      and svc_id like '%FH_%'
    ) a
    where rk = 1;
    SET starts_date = DATE_ADD(starts_date, INTERVAL 1 DAY);
  END WHILE;
END;