DECLARE vdt_id DATE DEFAULT @vdt_id;

delete from `data-bi-prd-935c.bi_dev`.ioh_snd_master_kpi_detail where kpi = 'osa' and dt_id = vdt_id and brand = 'IM3';
insert into `data-bi-prd-935c.bi_dev`.ioh_snd_master_kpi_detail
with OSA as (
--SELLIN SP/VOUCHER
                SELECT 
                    mth,
                    saldomobo_id mpc_id,
                    dest_saldomobo_id outlet_id,
                    product_category,
                    operator_id,
                    sum(cast(price as numeric)) amount,
                    count(msisdn) qty 
                from 
                    (
                        select 
                            date_trunc(SAFE.PARSE_DATE('%d-%b-%Y', SUBSTR(transaction_datetime, 1, 11)),month) mth,
                            msisdn,
                            saldomobo_id,
                            dest_saldomobo_id,
                            serial_number,
                            product_name,
                            product_category,
                            upper(operator_id) operator_id,
                            CAST((case when product_name LIKE '%IM3 90D%' THEN '10000' else price end) AS numeric) price
                        from `data-dtp-prd-aa1a.stg.mobii_physical_distribution`
                        where
                            cast(dt_id as date) <='9999-12-12' and
                            (
                            FORMAT_DATE('%Y-%m', SAFE.PARSE_DATE('%d-%b-%Y', SUBSTR(transaction_datetime, 1, 11))) = SUBSTR(cast(vdt_id as string), 1, 7) AND
                            FORMAT_DATE('%Y-%m-%d', SAFE.PARSE_DATE('%d-%b-%Y', SUBSTR(transaction_datetime, 1, 11))) <= cast(vdt_id as string)
                            ) 
                            and product_category in ('Starter Pack','Voucher')
                            and product_name not like '%3in1%'
                            and product_name not like '%SF%'
                            and product_name not like '%SF IM3 0 LTE%'
                            and distribution_type = 'Sell In'
                            and dest_saldomobo_id not like '%D%'
                            and (saldomobo_id LIKE '%D%' or saldomobo_id LIKE 'SDP%')
                        group by 
                            1,
                            msisdn,
                            saldomobo_id,
                            dest_saldomobo_id,
                            serial_number,
                            product_name,
                            product_category,
                            operator_id,
                            price
                    ) bb 
                group by 
                    mth,saldomobo_id,dest_saldomobo_id,product_category,operator_id
                union all
                --SALMO
                select 
                    date_trunc(date(a.dt_id),month) mth,
                    organization_id mpc_id,
                    credit_party_id outlet_id,
                    'Saldo Mobo' product_category,
                    upper(operator_id) operator_id,
                    sum(cast(amount as numeric)) amount,
                    count(transaction_id) qty
                from 
                    `data-dtp-prd-aa1a.stg`.mobo_allocation_org_to_org a
                where 
                    lower(channel) like '%traditional%'
                    and organization_type in ('Dealer','SDP')
                    and (upper(credit_party_id) not like '%DS%'
                    and upper(credit_party_id) not like '%SF%')
                    and account_type = 'Saldo Mobo Account'
                    and credit_party_id not like 'D%'
                    and transaction_status = 'Completed'
                    and status_description = 'Success'
                    and (
                            date(a.dt_id) between date_trunc(vdt_id,month) and vdt_id
                        )
                group by 1,2,3,5
            ),
oulet_mapping as 
            (select distinct id_outlet from `data-bi-prd-935c.bi_snd.pre_ref_outlet_mapping_im3` where parse_date('%Y%m',cast(mth_id as string)) = date_trunc(vdt_id, month)-- and status = 'Active'
)
-- OSA 
select 'IM3' brand, 'outlet' level, outlet_id as level_value, 
    sum(cast(amount as numeric)) value, 
    'mtd' as time_flag, 
     timestamp(current_datetime('+7')) as insert_date,
    'osa' as kpi_id, 
    vdt_id dt_id
from osa a
    join oulet_mapping b 
on a.outlet_id=b.id_outlet
group by 1,2,3,5,6,7,8
;


-------------------------------------------------
-------  OSA MOBO - SP -VOUCHER DLY ------------- 
-- update 26 aug 2025
-------------------------------------------------

delete from `data-bi-prd-935c.bi_dev`.ioh_snd_master_kpi_detail where brand='IM3' and kpi in ('osa_vou_dly', 'osa_sp_dly', 'osa_saldo_dly') and dt_id between date_trunc(vdt_id,month) and vdt_id;
insert into `data-bi-prd-935c.bi_dev`.ioh_snd_master_kpi_detail 
with osa_sp as (
--SELLIN SP
                SELECT 
                    mth as dt_id,
                    saldomobo_id mpc_id,
                    dest_saldomobo_id outlet_id,
                    product_category,
                    operator_id,
                    sum(cast(price as numeric)) amount,
                    count(msisdn) qty 
                from 
                    (
                        select 
                            safe.parse_date('%d-%b-%Y',left(transaction_datetime,11)) mth,
                            msisdn,
                            saldomobo_id,
                            dest_saldomobo_id,
                            serial_number,
                            product_name,
                            product_category,
                            upper(operator_id) operator_id,
                            CAST((case when product_name LIKE '%IM3 90D%' THEN '10000' else price end) AS numeric) price
                        from `data-dtp-prd-aa1a.stg`.mobii_physical_distribution
                        where
                            (
                                date_trunc(safe.parse_date('%d-%b-%Y',left(transaction_datetime,11)),month) between date_trunc(vdt_id,month) and vdt_id
                                and safe.parse_date('%d-%b-%Y',left(transaction_datetime,11)) <= vdt_id)
                                and date(dt_id)<= vdt_id
                            and product_category in ('Starter Pack')
                            and product_name not like '%3in1%'
                            and product_name not like '%SF%'
                            and product_name not like '%SF IM3 0 LTE%'
                            and distribution_type = 'Sell In'
                            and dest_saldomobo_id not like '%D%'
                            and (saldomobo_id LIKE '%D%' or saldomobo_id LIKE 'SDP%')
                        group by 
                            safe.parse_date('%d-%b-%Y',left(transaction_datetime,11)),
                            msisdn,
                            saldomobo_id,
                            dest_saldomobo_id,
                            serial_number,
                            product_name,
                            product_category,
                            operator_id,
                            price
                    ) bb 
                group by 
                    mth,saldomobo_id,dest_saldomobo_id,product_category,operator_id
        ),
osa_vou as (
    --SELLIN VOU
                SELECT 
                    mth as dt_id,
                    saldomobo_id mpc_id,
                    dest_saldomobo_id outlet_id,
                    product_category,
                    operator_id,
                    sum(cast(price as numeric)) amount,
                    count(msisdn) qty 
                from 
                    (
                        select 
                            safe.parse_date('%d-%b-%Y',left(transaction_datetime,11)) mth,
                            msisdn,
                            saldomobo_id,
                            dest_saldomobo_id,
                            serial_number,
                            product_name,
                            product_category,
                            upper(operator_id) operator_id,
                            CAST((case when product_name LIKE '%IM3 90D%' THEN '10000' else price end) AS numeric) price
                        from `data-dtp-prd-aa1a.stg`.mobii_physical_distribution
                        where
                            (
                                date_trunc(safe.parse_date('%d-%b-%Y',left(transaction_datetime,11)),month) = date_trunc(vdt_id,month)
                                and safe.parse_date('%d-%b-%Y',left(transaction_datetime,11)) <= vdt_id)
                            and date(dt_id) <= vdt_id
                            and product_category in ('Voucher')
                            and product_name not like '%3in1%'
                            and product_name not like '%SF%'
                            and product_name not like '%SF IM3 0 LTE%'
                            and distribution_type = 'Sell In'
                            and dest_saldomobo_id not like '%D%'
                            and (saldomobo_id LIKE '%D%' or saldomobo_id LIKE 'SDP%')
                        group by 
                            safe.parse_date('%d-%b-%Y',left(transaction_datetime,11)),
                            msisdn,
                            saldomobo_id,
                            dest_saldomobo_id,
                            serial_number,
                            product_name,
                            product_category,
                            operator_id,
                            price
                    ) bb 
                group by 
                    mth,saldomobo_id,dest_saldomobo_id,product_category,operator_id
        ),
osa_saldo as (
     --SALMO
                select 
                    date(dt_id) dt_id,
                    organization_id mpc_id,
                    credit_party_id outlet_id,
                    'Saldo Mobo' product_category,
                    upper(operator_id) operator_id,
                    sum(cast(amount as numeric)) amount,
                    count(transaction_id) qty
                from 
                    `data-dtp-prd-aa1a.stg`.mobo_allocation_org_to_org a
                where 
                    lower(channel) like '%traditional%'
                    and organization_type in ('Dealer','SDP')
                    and (upper(credit_party_id) not like '%DS%'
                    and upper(credit_party_id) not like '%SF%')
                    and account_type = 'Saldo Mobo Account'
                    and credit_party_id not like 'D%'
                    and transaction_status = 'Completed'
                    and status_description = 'Success'
                    and date_trunc(date(dt_id),month) = date_trunc(vdt_id,month) and date(dt_id) <= vdt_id
                group by dt_id, organization_id,credit_party_id,operator_id
            ),
oulet_mapping as 
            (select distinct id_outlet from `data-bi-prd-935c.bi_snd.pre_ref_outlet_mapping_im3` where safe.parse_date('%Y%m', cast(mth_id as string)) = date_trunc(vdt_id,month) -- and status = 'Active'
            )
-------- OSA SP DLY
select 'IM3' brand, 'outlet' level, outlet_id as level_value, 
    sum(cast(amount as numeric)) value, 
    'dly' as time_flag, 
     timestamp(current_datetime('+7')) as insert_date,
    'osa_sp_dly' as kpi, 
    dt_id
from osa_sp a
    join oulet_mapping b 
on a.outlet_id=b.id_outlet
group by 1,2,3,5,6,7,8
union all 
-------- OSA VOU DLY
select 'IM3' brand, 'outlet' level, outlet_id as level_value, 
    sum(cast(amount as numeric)) value, 
    'dly' as time_flag, 
     timestamp(current_datetime('+7')) as insert_date,
    'osa_vou_dly' as kpi, 
    dt_id
from osa_vou a
    join oulet_mapping b 
on a.outlet_id=b.id_outlet
group by 1,2,3,5,6,7,8
union all 
-------- OSA SALDO DLY
select 'IM3' brand, 'outlet' level, outlet_id as level_value, 
    sum(cast(amount as numeric)) value, 
    'dly' as time_flag, 
     timestamp(current_datetime('+7')) as insert_date,
    'osa_saldo_dly' as kpi, 
    dt_id
from osa_saldo a
    join oulet_mapping b 
on a.outlet_id=b.id_outlet
group by 1,2,3,5,6,7,8
;


    -- ========== OSA KPI - OUTLET LEVEL MTD (PJP ONLY) ==========
    DELETE FROM `data-bi-prd-935c.bi_dev`.ioh_snd_master_kpi_detail
    WHERE kpi = 'osa' AND dt_id = vdt_id 
      AND level = 'outlet' AND time_flag = 'mtd' and brand = '3ID';
    
    INSERT INTO `data-bi-prd-935c.bi_dev`.ioh_snd_master_kpi_detail    
    SELECT '3ID' as brand,
    'outlet' level,
    pjp.qr_code level_value,
    SUM(sellin_osa.amount) AS amount,
    'mtd' time_flag,
    timestamp(current_datetime('+7')) insert_date,
    'osa',
    vdt_id
    FROM (
        -- Get outlet mapping data
        SELECT 
            parse_date('%Y%m',cast(mth_id as string)) AS mth_id,
            retailer_qrcode AS qr_code,
            mp3_name AS partner_name,
            branch,
            se_partnerid AS dse_code
        FROM `data-bi-prd-935c.bi_snd.pre_ref_outlet_mapping_3id` b
        WHERE parse_date('%Y%m',cast(mth_id as string)) = date_trunc(vdt_id,month)
    ) pjp
    INNER JOIN (
        -- Get OSA transaction data
        SELECT 
            cast(ret_qrcode as string) AS outlet_id,
            SUM(a.value) AS amount
        FROM (
            SELECT b.partner_qr_cd as ret_qrcode,
                   SUM(a.kpi_value) as value
            FROM `data-dtptechm-prd-c7ca.dwh`.prt_daily_channel_movement_fct as a 
            LEFT JOIN `data-bi-prd-935c.bi_mart`.angie_hrchy_dim_hst b
              ON cast(a.partner_sk_id as string) = b.angie_hrchy_sk_id 
              AND b.mth = date_trunc(date(a.snp_dt_sk_id),month)
            WHERE a.partner_type = 'RET' 
              AND a.kpi_name = 'Purchase from CAN'
              AND a.kpi_freq = 'Daily' 
              AND date(a.snp_dt_sk_id) BETWEEN date_trunc(vdt_id,month) AND vdt_id
              AND COALESCE(UPPER(b.mp3_location),'CENTRAL WEST NORTH JKT') NOT IN (
                  'DVM BM','3 STORE','3 BUSINESS','NA','POOL','SIM ONLINE',
                  'SOUTH JAKARTA TEST BM','ADVCREDIT','FUT ANGIE 2.0','MODCHAN',
                  'BSM TRI OFFICIAL STORE'
              ) 
              AND b.hrchy_type = 'Retailer' 
            GROUP BY 1
        ) a  
        WHERE 1=1
        GROUP BY 1
    ) sellin_osa ON pjp.qr_code = sellin_osa.outlet_id 
    GROUP BY 1,2,3,5,7,8;

----------------------------------
----- osa_saldo ------------------
----------------------------------


-- delete table `data-bi-prd-935c.bi_dev`.ioh_snd_master_kpi_detail

delete from `data-bi-prd-935c.bi_dev`.ioh_snd_master_kpi_detail 
where brand = '3ID' and dt_id = vdt_id and kpi = 'osa_saldo' and time_flag ='dly'
;

-- insert table `data-bi-prd-935c.bi_dev`.ioh_snd_master_kpi_detail 

INSERT INTO `data-bi-prd-935c.bi_dev`.ioh_snd_master_kpi_detail
        SELECT '3ID' as brand, 'outlet' level, pjp.qr_code level_value, SUM(sellin_osa.amount) AS amount,
            'dly' time_flag, timestamp(current_datetime('+7')) insert_date, 'osa_saldo', vdt_id
        FROM (
            SELECT parse_date('%Y%m',cast(mth_id as string)) mth_id, retailer_qrcode AS qr_code, mp3_name AS partner_name, branch, se_partnerid AS dse_code
            FROM `data-bi-prd-935c.bi_snd.pre_ref_outlet_mapping_3id`
            WHERE parse_date('%Y%m',cast(mth_id as string)) = date_trunc(vdt_id,month)
        ) pjp
        INNER JOIN (
            SELECT ret_qrcode AS outlet_id, SUM(a.value) AS amount
            FROM (
                SELECT cast(b.partner_qr_cd as string) as ret_qrcode, SUM(a.kpi_value) as value
                FROM `data-dtptechm-prd-c7ca.dwh`.prt_daily_channel_movement_fct as a
                LEFT JOIN `data-bi-prd-935c.bi_mart`.angie_hrchy_dim_hst b ON cast(a.partner_sk_id as string) = b.angie_hrchy_sk_id AND b.mth = date_trunc(date(a.snp_dt_sk_id),month)
                WHERE a.partner_type = 'RET' AND a.kpi_name = 'Purchase from CAN' AND a.kpi_freq = 'Daily'
                  AND date(a.snp_dt_sk_id) = vdt_id
                  AND COALESCE(UPPER(b.mp3_location),'CENTRAL WEST NORTH JKT') NOT IN ('DVM BM','3 STORE','3 BUSINESS','NA','POOL','SIM ONLINE','SOUTH JAKARTA TEST BM','ADVCREDIT','FUT ANGIE 2.0','MODCHAN','BSM TRI OFFICIAL STORE')
                  AND b.hrchy_type = 'Retailer'
                GROUP BY 1
            ) a
            GROUP BY 1
        ) sellin_osa ON pjp.qr_code = sellin_osa.outlet_id
        GROUP BY 1,2,3,5,6,7,8
       ;