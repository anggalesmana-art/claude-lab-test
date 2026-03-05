declare vdt_id date default @vdt_id;

--IM3
--PRIMARY

---------------- primary_trad ----------------
delete from `data-bi-prd-935c.bi_dev`.ioh_snd_master_kpi_detail where kpi = 'primary_trad' and dt_id = vdt_id and brand = 'IM3';
insert into `data-bi-prd-935c.bi_dev`.ioh_snd_master_kpi_detail
select 'IM3' brand, 'outlet' level, id as level_value, 
    sum(cast(value as numeric)) value, 
    'mtd' as time_flag, 
     timestamp(current_datetime('+7')) as insert_date,
    'primary_trad' as kpi_id, 
    vdt_id as dt_id
from
(
select organization_id as id,  sum(amount) value
from `data-bi-prd-935c.bi_mart`.fact_snd_primary 
where dt_id between date_trunc(vdt_id,month) and vdt_id
group by 1
)a
group by 1,2,3,5,6,7,8
;  



---------------- primary_non_trad ----------------
delete from `data-bi-prd-935c.bi_dev`.ioh_snd_master_kpi_detail where kpi = 'primary_nontrad' and dt_id = vdt_id and brand = 'IM3';
insert into `data-bi-prd-935c.bi_dev`.ioh_snd_master_kpi_detail
-- Part 1: Primary Sellin data
WITH primary_sellin AS (
    SELECT 
       date(date_trunc(dt_id,month)) AS mth,
        Channel,
        organization_id, 
        SUM(CAST(amount AS numeric)) AS amount
    FROM `data-dtp-prd-aa1a.stg`.sellin_sellout_stock_entry_success
    WHERE (so_number LIKE 'ESCM11%' OR so_number LIKE '11%')
      AND LOWER(channel) NOT LIKE '%traditional%' 
      AND transaction_status = 'Completed'
      AND date(dt_id) between date(date_trunc(vdt_id,month)) and vdt_id 
     GROUP BY 1, 2,3
),
-- Part 2: Excluded organization IDs for Bank channel
excluded_bank_orgs AS (
    SELECT a.organization_id
    FROM (
        SELECT  
            a.organization_id,
            a.organization_type,
            a.channel,
            SUM(CAST(a.amount AS numeric)) AS amount,
            'PRIMARY' AS primary_type
        FROM `data-dtp-prd-aa1a.stg`.sellin_sellout_stock_entry_success a
        WHERE (so_number LIKE 'ESCM11%' OR so_number LIKE '11%')
          AND LOWER(channel) NOT LIKE '%traditional%' 
          AND transaction_status = 'Completed'
          AND date(dt_id) between date_trunc(vdt_id,month) and vdt_id 
        GROUP BY 1, 2, 3,5
    ) a 
    LEFT JOIN (
        SELECT * 
        FROM (
            SELECT 
                *, 
                ROW_NUMBER() OVER (PARTITION BY dealer_code ORDER BY dt_id DESC) AS rn
            FROM `data-bi-prd-935c.bi_mart`.foss_dealer_mth
            WHERE mth_id = date_trunc(vdt_id,month)
        ) dealer
        WHERE rn = 1
    ) b ON a.organization_id = b.organization_id 
    WHERE a.channel = 'Bank'
),
-- Part 3: Tertiary data for Bank channel (excluding specific orgs)
tertiary_bank AS (
    SELECT 
        date(date_trunc(dt_id,month)) AS mth,
        a.channel,
        a.organization_id,
        SUM(amount_debit) AS amount
    FROM `data-bi-prd-935c.bi_mart`.fact_snd_tertiary_dtl a
    LEFT JOIN excluded_bank_orgs b ON a.parent_org_id = b.organization_id
    WHERE b.organization_id IS NULL
      AND a.dt_id between date_trunc(vdt_id,month) and vdt_id 
      AND UPPER(a.channel) = 'BANK'
    GROUP BY 1, 2,3
),
p2p as (
        select date(dt_id) dt_id, channel, organization_id, sum(cast(amount_debit as numeric)) value  from 
        (
        -- sum(cast(amount_debit as numeric)) value
        select a.*, parse_date('%Y-%m-%d',left(`datetime`,10)) dt_id
        from
        `data-dtp-prd-aa1a.stg`.ifrs_prepaid_salmo a
        where channel='P2P' 
        and transaction_status='Completed' 
        and transaction_type='Transfer'
        and 
            (
                parse_date('%Y-%m-%d',left(`datetime`,10)) between date_trunc(vdt_id,month) and vdt_id 
                and date(process_id) between date_trunc(vdt_id,month) and vdt_id+ interval 1 day 
            )
        and coalesce(substring(b_msisdn, 1,5),'') not in ('62895', '62896', '62897', '62898', '62899')
        )a
        group by 1,2,3
        )
-- primary_non_trad
select 'IM3' brand, 'partner' level, organization_id as level_value, 
        sum(cast(amount as numeric)) value, 
        'mtd' as time_flag, 
         timestamp(current_datetime('+7')) as insert_date,
         'primary_nontrad' as kpi_id, 
         vdt_id as dt_id
from
(
-- Combine both result sets
SELECT * FROM primary_sellin
UNION ALL 
-- additional from bank
SELECT * FROM tertiary_bank
-- p2p
union all 
select * from p2p
)a
group by 1,2,3,5,6,7,8
;


--3ID
--PRIMARY
DELETE FROM `data-bi-prd-935c.bi_dev`.ioh_snd_master_kpi_detail
WHERE kpi = 'primary_trad' AND dt_id = vdt_id and brand = '3ID';


INSERT INTO `data-bi-prd-935c.bi_dev`.ioh_snd_master_kpi_detail
SELECT '3ID',
'partner',
mp3_id,
SUM(value),
'mtd',
timestamp(current_datetime('+7')),
'primary_trad',
dt_id
FROM `data-bi-prd-935c.bi_dev.mis_snd_prisec_detail`
WHERE kpi_name = 'primary' AND dt_id = vdt_id
GROUP BY 1,2,3,5,6,7,8;


