declare vdt_id date default @vdt_id;

--- UTU
  create or replace table `data-bi-prd-935c.bi_mart`.tmp_imkas_kpi_smy_utu_{{ vdt_id }} as
  --- UTU Daily
  select count(distinct no_rekening) dly, 0 mtd, 0 lmtd, 0 m1, 0 m2
  from `data-bi-prd-935c.bi_mart`.imkas_trx_dly
  where dt_id = vdt_id
    and grp in ('CASHOUT','BILL PAYMENT','MYIM3 BILL PAYMENT')
  union all
  --- UTU MTD
  select  0 dly, count(distinct no_rekening) mtd, 0 lmtd, 0 m1, 0 m2
  from `data-bi-prd-935c.bi_mart`.imkas_trx_dly
  where dt_id between date_trunc(vdt_id,month) and vdt_id
    and grp in ('CASHOUT','BILL PAYMENT','MYIM3 BILL PAYMENT')
  union all
  --- UTU LMTD
  select 0 dly, 0 mtd, count(distinct no_rekening) lmtd, 0 m1, 0 m2
  from `data-bi-prd-935c.bi_mart`.imkas_trx_dly
  where dt_id between date_trunc(vdt_id,month) - interval 1 month and vdt_id - interval 1 month
    and grp in ('CASHOUT','BILL PAYMENT','MYIM3 BILL PAYMENT')
  union all
  --- UTU M1
  select 0 dly, 0 mtd, 0 lmtd, count(distinct no_rekening) m1, 0 m2
  from `data-bi-prd-935c.bi_mart`.imkas_trx_dly
  where dt_id between date_trunc(vdt_id,month) - interval 1 month and vdt_id - interval 1 month
    and grp in ('CASHOUT','BILL PAYMENT','MYIM3 BILL PAYMENT')
      union all
  --- UTU M2
  select 0 dly, 0 mtd, 0 lmtd,  0 m1, count(distinct no_rekening) m2
  from `data-bi-prd-935c.bi_mart`.imkas_trx_dly
  where dt_id between date_trunc(vdt_id,month) - interval 2 month and vdt_id - interval 2 month
    and grp in ('CASHOUT','BILL PAYMENT','MYIM3 BILL PAYMENT')
  ;

--- All Transaction
  create or replace table `data-bi-prd-935c.bi_mart`.tmp_imkas_kpi_smy_trx_{{ vdt_id }} as
  --- TRX Daily
  select sum(amount) dly, 0 mtd, 0 lmtd, 0 m1, 0 m2
  from `data-bi-prd-935c.bi_mart`.imkas_trx_dly
  where dt_id = vdt_id
    and grp in ('BULK TOPUP','TOPUP','CASHOUT','BILL PAYMENT','MYIM3 BILL PAYMENT')
  union all
  --- TRX MTD
  select  0 dly, sum(amount) mtd, 0 lmtd, 0 m1, 0 m2
  from `data-bi-prd-935c.bi_mart`.imkas_trx_dly
  where dt_id between date_trunc(vdt_id,month) and vdt_id
    and grp in ('BULK TOPUP','TOPUP','CASHOUT','BILL PAYMENT','MYIM3 BILL PAYMENT')
  union all
  --- TRX LMTD
  select 0 dly, 0 mtd, sum(amount) lmtd, 0 m1, 0 m2
  from `data-bi-prd-935c.bi_mart`.imkas_trx_dly
  where dt_id between date_trunc(vdt_id,month) - interval 1 month and vdt_id - interval 1 month
    and grp in ('BULK TOPUP','TOPUP','CASHOUT','BILL PAYMENT','MYIM3 BILL PAYMENT')
  union all
  --- TRX M1
  select 0 dly, 0 mtd, 0 lmtd, sum(amount) m1, 0 m2
  from `data-bi-prd-935c.bi_mart`.imkas_trx_dly
  where dt_id between date_trunc(vdt_id,month) - interval 1 month and vdt_id - interval 1 month
    and grp in ('BULK TOPUP','TOPUP','CASHOUT','BILL PAYMENT','MYIM3 BILL PAYMENT')
      union all
  --- TRX M2
  select 0 dly, 0 mtd, 0 lmtd, 0 m1, sum(amount) m2
  from `data-bi-prd-935c.bi_mart`.imkas_trx_dly
  where dt_id between date_trunc(vdt_id,month) - interval 2 month and vdt_id - interval 2 month
    and grp in ('BULK TOPUP','TOPUP','CASHOUT','BILL PAYMENT','MYIM3 BILL PAYMENT')
  ;

--- TOPUP BANK
  create or replace table `data-bi-prd-935c.bi_mart`.tmp_imkas_kpi_smy_topup_{{ vdt_id }} as
  --- TRX Daily
  select sum(amount) dly, 0 mtd, 0 lmtd, 0 m1, 0 m2
  from `data-bi-prd-935c.bi_mart`.imkas_trx_dly
  where dt_id = vdt_id and grp='TOPUP'
  union all
  --- TRX MTD
  select  0 dly, sum(amount) mtd, 0 lmtd, 0 m1, 0 m2
  from `data-bi-prd-935c.bi_mart`.imkas_trx_dly
  where dt_id between date_trunc(vdt_id,month) and vdt_id and grp='TOPUP'
  union all
  --- TRX LMTD
  select 0 dly, 0 mtd, sum(amount) lmtd, 0 m1, 0 m2
  from `data-bi-prd-935c.bi_mart`.imkas_trx_dly
  where dt_id between date_trunc(vdt_id,month) - interval 1 month and vdt_id - interval 1 month and grp='TOPUP'
  union all
  --- TRX M1
  select 0 dly, 0 mtd, 0 lmtd, sum(amount) m1, 0 m2
  from `data-bi-prd-935c.bi_mart`.imkas_trx_dly
  where dt_id between date_trunc(vdt_id,month) - interval 1 month and vdt_id - interval 1 month
    and grp='TOPUP'
  union all
  --- TRX M2
  select 0 dly, 0 mtd, 0 lmtd, 0 m1, sum(amount) m2
  from `data-bi-prd-935c.bi_mart`.imkas_trx_dly
  where dt_id between date_trunc(vdt_id,month) - interval 2 month and vdt_id - interval 2 month and grp='TOPUP'
  ;

--- BULK TOPUP
  drop table if exists `data-bi-prd-935c.bi_mart`.tmp_imkas_kpi_smy_bt_{{ vdt_id }};
  create or replace table `data-bi-prd-935c.bi_mart`.tmp_imkas_kpi_smy_bt_{{ vdt_id }} as
  --- TRX Daily
  select sum(amount) dly, 0 mtd, 0 lmtd, 0 m1, 0 m2
  from `data-bi-prd-935c.bi_mart`.imkas_trx_dly
  where dt_id = vdt_id and grp='BULK TOPUP'
  union all
  --- TRX MTD
  select  0 dly, sum(amount) mtd, 0 lmtd, 0 m1, 0 m2
  from `data-bi-prd-935c.bi_mart`.imkas_trx_dly
  where dt_id between date_trunc(vdt_id,month) and vdt_id and grp='BULK TOPUP'
  union all
  --- TRX LMTD
  select 0 dly, 0 mtd, sum(amount) lmtd, 0 m1, 0 m2
  from `data-bi-prd-935c.bi_mart`.imkas_trx_dly
  where dt_id between date_trunc(vdt_id,month) - interval 1 month and vdt_id - interval 1 month and grp='BULK TOPUP'
  union all
  --- TRX M1
  select 0 dly, 0 mtd, 0 lmtd, sum(amount) m1, 0 m2
  from `data-bi-prd-935c.bi_mart`.imkas_trx_dly
  where dt_id between date_trunc(vdt_id,month) - interval 1 month and vdt_id - interval 1 month
    and grp='BULK TOPUP'
  union all
  --- TRX M2
  select 0 dly, 0 mtd, 0 lmtd, 0 m1, sum(amount) m2
  from `data-bi-prd-935c.bi_mart`.imkas_trx_dly
  where dt_id between date_trunc(vdt_id,month) - interval 2 month and vdt_id - interval 2 month and grp='BULK TOPUP'
  ;

--- CASHOUT
  create or replace table `data-bi-prd-935c.bi_mart`.tmp_imkas_kpi_smy_cashout_{{ vdt_id }} as
  --- TRX Daily
  select sum(amount) dly, 0 mtd, 0 lmtd, 0 m1, 0 m2
  from `data-bi-prd-935c.bi_mart`.imkas_trx_dly
  where dt_id = vdt_id and grp='CASHOUT'
  union all
  --- TRX MTD
  select  0 dly, sum(amount) mtd, 0 lmtd, 0 m1, 0 m2
  from `data-bi-prd-935c.bi_mart`.imkas_trx_dly
  where dt_id between date_trunc(vdt_id,month) and vdt_id and grp='CASHOUT'
  union all
  --- TRX LMTD
  select 0 dly, 0 mtd, sum(amount) lmtd, 0 m1, 0 m2
  from `data-bi-prd-935c.bi_mart`.imkas_trx_dly
  where dt_id between date_trunc(vdt_id,month) - interval 1 month and vdt_id - interval 1 month and grp='CASHOUT'
  union all
  --- TRX M1
  select 0 dly, 0 mtd, 0 lmtd, sum(amount) m1, 0 m2
  from `data-bi-prd-935c.bi_mart`.imkas_trx_dly
  where dt_id between date_trunc(vdt_id,month) - interval 1 month and vdt_id - interval 1 month
    and grp='CASHOUT'
  union all
  --- TRX M2
  select 0 dly, 0 mtd, 0 lmtd, 0 m1, sum(amount) m2
  from `data-bi-prd-935c.bi_mart`.imkas_trx_dly
  where dt_id between date_trunc(vdt_id,month) - interval 2 month and vdt_id - interval 2 month and grp='CASHOUT'
  ;

--- BILL PAYMENT
  create or replace table `data-bi-prd-935c.bi_mart`.tmp_imkas_kpi_smy_bill_{{ vdt_id }} as
  --- TRX Daily
  select sum(amount) dly, 0 mtd, 0 lmtd, 0 m1, 0 m2
  from `data-bi-prd-935c.bi_mart`.imkas_trx_dly
  where dt_id = vdt_id and grp='BILL PAYMENT'
  union all
  --- TRX MTD
  select  0 dly, sum(amount) mtd, 0 lmtd, 0 m1, 0 m2
  from `data-bi-prd-935c.bi_mart`.imkas_trx_dly
  where dt_id between date_trunc(vdt_id,month) and vdt_id and grp='BILL PAYMENT'
  union all
  --- TRX LMTD
  select 0 dly, 0 mtd, sum(amount) lmtd, 0 m1, 0 m2
  from `data-bi-prd-935c.bi_mart`.imkas_trx_dly
  where dt_id between date_trunc(vdt_id,month) - interval 1 month and vdt_id - interval 1 month and grp='BILL PAYMENT'
  union all
  --- TRX M1
  select 0 dly, 0 mtd, 0 lmtd, sum(amount) m1, 0 m2
  from `data-bi-prd-935c.bi_mart`.imkas_trx_dly
  where dt_id between date_trunc(vdt_id,month) - interval 1 month and vdt_id - interval 1 month
    and grp='BILL PAYMENT'
  union all
  --- TRX M2
  select 0 dly, 0 mtd, 0 lmtd, 0 m1, sum(amount) m2
  from `data-bi-prd-935c.bi_mart`.imkas_trx_dly
  where dt_id between date_trunc(vdt_id,month) - interval 2 month and vdt_id - interval 2 month and grp='BILL PAYMENT'
  ;

--- MYIM3 BILL
  create or replace table `data-bi-prd-935c.bi_mart`.tmp_imkas_kpi_smy_myim3_{{ vdt_id }} as
  --- TRX Daily
  select sum(amount) dly, 0 mtd, 0 lmtd, 0 m1, 0 m2
  from `data-bi-prd-935c.bi_mart`.imkas_trx_dly
  where dt_id = vdt_id and grp='MYIM3 BILL PAYMENT'
  union all
  --- TRX MTD
  select  0 dly, sum(amount) mtd, 0 lmtd, 0 m1, 0 m2
  from `data-bi-prd-935c.bi_mart`.imkas_trx_dly
  where dt_id between date_trunc(vdt_id,month) and vdt_id and grp='MYIM3 BILL PAYMENT'
  union all
  --- TRX LMTD
  select 0 dly, 0 mtd, sum(amount) lmtd, 0 m1, 0 m2
  from `data-bi-prd-935c.bi_mart`.imkas_trx_dly
  where dt_id between date_trunc(vdt_id,month) - interval 1 month and vdt_id - interval 1 month and grp='MYIM3 BILL PAYMENT'
  union all
  --- TRX M1
  select 0 dly, 0 mtd, 0 lmtd, sum(amount) m1, 0 m2
  from `data-bi-prd-935c.bi_mart`.imkas_trx_dly
  where dt_id between date_trunc(vdt_id,month) - interval 1 month and vdt_id - interval 1 month
    and grp='MYIM3 BILL PAYMENT'
  union all
  --- TRX M2
  select 0 dly, 0 mtd, 0 lmtd, 0 m1, sum(amount) m2
  from `data-bi-prd-935c.bi_mart`.imkas_trx_dly
  where dt_id between date_trunc(vdt_id,month) - interval 2 month and vdt_id - interval 2 month and grp='MYIM3 BILL PAYMENT'
  ;

--- FEE
  create or replace table `data-bi-prd-935c.bi_mart`.tmp_imkas_kpi_smy_fee_{{ vdt_id }} as
  --- FEE Daily
  select sum(amount) dly, 0 mtd, 0 lmtd, 0 m1, 0 m2
  from `data-bi-prd-935c.bi_mart`.imkas_trx_dly
  where dt_id = vdt_id
    and grp = 'FEE'
  union all
  --- FEE MTD
  select  0 dly, sum(amount) mtd, 0 lmtd, 0 m1, 0 m2
  from `data-bi-prd-935c.bi_mart`.imkas_trx_dly
  where dt_id between date_trunc(vdt_id,month) and vdt_id
    and grp = 'FEE'
  union all
  --- FEE LMTD
  select 0 dly, 0 mtd, sum(amount) lmtd, 0 m1, 0 m2
  from `data-bi-prd-935c.bi_mart`.imkas_trx_dly
  where dt_id between date_trunc(vdt_id,month) - interval 1 month and vdt_id - interval 1 month
    and grp = 'FEE'
  union all
  --- FEE M1
  select 0 dly, 0 mtd, 0 lmtd, sum(amount) m1, 0 m2
  from `data-bi-prd-935c.bi_mart`.imkas_trx_dly
  where dt_id between date_trunc(vdt_id,month) - interval 1 month and vdt_id - interval 1 month
    and grp = 'FEE'
      union all
  --- FEE M2
  select 0 dly, 0 mtd, 0 lmtd, 0 m1, sum(amount) m2
  from `data-bi-prd-935c.bi_mart`.imkas_trx_dly
  where dt_id between date_trunc(vdt_id,month) - interval 2 month and vdt_id - interval 2 month
    and grp = 'FEE'
  ;

--- FEE CATEGORY
  create or replace table `data-bi-prd-935c.bi_mart`.tmp_imkas_kpi_smy_fee_cat_{{ vdt_id }} as
  --- FEE Daily
  select category, sum(amount) dly, 0 mtd, 0 lmtd, 0 m1, 0 m2
  from `data-bi-prd-935c.bi_mart`.imkas_trx_dly
  where dt_id = vdt_id
    and grp = 'FEE'
  group by 1
  union all
  --- FEE MTD
  select category, 0 dly, sum(amount) mtd, 0 lmtd, 0 m1, 0 m2
  from `data-bi-prd-935c.bi_mart`.imkas_trx_dly
  where dt_id between date_trunc(vdt_id,month) and vdt_id
    and grp = 'FEE'
  group by 1
  union all
  --- FEE LMTD
  select category, 0 dly, 0 mtd, sum(amount) lmtd, 0 m1, 0 m2
  from `data-bi-prd-935c.bi_mart`.imkas_trx_dly
  where dt_id between date_trunc(vdt_id,month) - interval 1 month and vdt_id - interval 1 month
    and grp = 'FEE'
  group by 1
  union all
  --- FEE M1
  select category, 0 dly, 0 mtd, 0 lmtd, sum(amount) m1, 0 m2
  from `data-bi-prd-935c.bi_mart`.imkas_trx_dly
  where dt_id between date_trunc(vdt_id,month) - interval 1 month and vdt_id - interval 1 month
    and grp = 'FEE'
  group by 1
      union all
  --- FEE M2
  select category, 0 dly, 0 mtd, 0 lmtd, 0 m1, sum(amount) m2
  from `data-bi-prd-935c.bi_mart`.imkas_trx_dly
  where dt_id between date_trunc(vdt_id,month) - interval 2 month and vdt_id - interval 2 month
    and grp = 'FEE'
  group by 1
  ;

--- REVERSAL
  create or replace table `data-bi-prd-935c.bi_mart`.tmp_imkas_kpi_smy_reversal_{{ vdt_id }} as
  --- REVERSAL Daily
  select sum(amount) dly, 0 mtd, 0 lmtd, 0 m1, 0 m2
  from `data-bi-prd-935c.bi_mart`.imkas_trx_dly
  where dt_id = vdt_id
    and grp = 'REVERSAL'
  union all
  --- REVERSAL MTD
  select  0 dly, sum(amount) mtd, 0 lmtd, 0 m1, 0 m2
  from `data-bi-prd-935c.bi_mart`.imkas_trx_dly
  where dt_id between date_trunc(vdt_id,month) and vdt_id
    and grp = 'REVERSAL'
  union all
  --- REVERSAL LMTD
  select 0 dly, 0 mtd, sum(amount) lmtd, 0 m1, 0 m2
  from `data-bi-prd-935c.bi_mart`.imkas_trx_dly
  where dt_id between date_trunc(vdt_id,month) - interval 1 month and vdt_id - interval 1 month
    and grp = 'REVERSAL'
  union all
  --- REVERSAL M1
  select 0 dly, 0 mtd, 0 lmtd, sum(amount) m1, 0 m2
  from `data-bi-prd-935c.bi_mart`.imkas_trx_dly
  where dt_id between date_trunc(vdt_id,month) - interval 1 month and vdt_id - interval 1 month
    and grp = 'REVERSAL'
      union all
  --- REVERSAL M2
  select 0 dly, 0 mtd, 0 lmtd, 0 m1, sum(amount) m2
  from `data-bi-prd-935c.bi_mart`.imkas_trx_dly
  where dt_id between date_trunc(vdt_id,month) - interval 2 month and vdt_id - interval 2 month
    and grp = 'REVERSAL'
  ;

--- REVERSAL CATEGORY
  create or replace table `data-bi-prd-935c.bi_mart`.tmp_imkas_kpi_smy_reversal_cat_{{ vdt_id }} as
  --- REVERSAL Daily
  select category, sum(amount) dly, 0 mtd, 0 lmtd, 0 m1, 0 m2
  from `data-bi-prd-935c.bi_mart`.imkas_trx_dly
  where dt_id = vdt_id
    and grp = 'REVERSAL'
  group by 1
  union all
  --- REVERSAL MTD
  select category, 0 dly, sum(amount) mtd, 0 lmtd, 0 m1, 0 m2
  from `data-bi-prd-935c.bi_mart`.imkas_trx_dly
  where dt_id between date_trunc(vdt_id,month) and vdt_id
    and grp = 'REVERSAL'
  group by 1
  union all
  --- REVERSAL LMTD
  select category, 0 dly, 0 mtd, sum(amount) lmtd, 0 m1, 0 m2
  from `data-bi-prd-935c.bi_mart`.imkas_trx_dly
  where dt_id between date_trunc(vdt_id,month) - interval 1 month and vdt_id - interval 1 month
    and grp = 'REVERSAL'
  group by 1
  union all
  --- REVERSAL M1
  select category, 0 dly, 0 mtd, 0 lmtd, sum(amount) m1, 0 m2
  from `data-bi-prd-935c.bi_mart`.imkas_trx_dly
  where dt_id between date_trunc(vdt_id,month) - interval 1 month and vdt_id - interval 1 month
    and grp = 'REVERSAL'
  group by 1
      union all
  --- REVERSAL M2
  select category, 0 dly, 0 mtd, 0 lmtd, 0 m1, sum(amount) m2
  from `data-bi-prd-935c.bi_mart`.imkas_trx_dly
  where dt_id between date_trunc(vdt_id,month) - interval 2 month and vdt_id - interval 2 month
    and grp = 'REVERSAL'
  group by 1
  ;


--- insert to master table
delete from `data-bi-prd-935c.bi_mart`.imkas_kpi_smy where dt_id = vdt_id;
insert into `data-bi-prd-935c.bi_mart`.imkas_kpi_smy
select 'UTU' kpi_nm, sum(dly) dly, sum(mtd) mtd, sum(lmtd) lmtd, sum(m1) m1, sum(m2) m2, timestamp(current_datetime('+7')) ppn_dttm, vdt_id dt_id
from `data-bi-prd-935c.bi_mart`.tmp_imkas_kpi_smy_utu_{{ vdt_id }}
union all
select 'TRX-ALL' kpi_nm, sum(dly) dly, sum(mtd) mtd, sum(lmtd) lmtd, sum(m1) m1, sum(m2) m2, timestamp(current_datetime('+7')) ppn_dttm, vdt_id dt_id
from `data-bi-prd-935c.bi_mart`.tmp_imkas_kpi_smy_trx_{{ vdt_id }}
union all
select 'TRX-TOPUP_BANK' kpi_nm, sum(dly) dly, sum(mtd) mtd, sum(lmtd) lmtd, sum(m1) m1, sum(m2) m2, timestamp(current_datetime('+7')) ppn_dttm, vdt_id dt_id
from `data-bi-prd-935c.bi_mart`.tmp_imkas_kpi_smy_topup_{{ vdt_id }}
union all
select 'TRX-BULK_TOPUP' kpi_nm, sum(dly) dly, sum(mtd) mtd, sum(lmtd) lmtd, sum(m1) m1, sum(m2) m2, timestamp(current_datetime('+7')) ppn_dttm, vdt_id dt_id
from `data-bi-prd-935c.bi_mart`.tmp_imkas_kpi_smy_bt_{{ vdt_id }}
union all
select 'TRX-CASHOUT' kpi_nm, sum(dly) dly, sum(mtd) mtd, sum(lmtd) lmtd, sum(m1) m1, sum(m2) m2, timestamp(current_datetime('+7')) ppn_dttm, vdt_id dt_id
from `data-bi-prd-935c.bi_mart`.tmp_imkas_kpi_smy_cashout_{{ vdt_id }}
union all
select 'TRX-BILL_PAYMENT' kpi_nm, sum(dly) dly, sum(mtd) mtd, sum(lmtd) lmtd, sum(m1) m1, sum(m2) m2, timestamp(current_datetime('+7')) ppn_dttm, vdt_id dt_id
from `data-bi-prd-935c.bi_mart`.tmp_imkas_kpi_smy_bill_{{ vdt_id }}
union all
select 'TRX-MYIM3_BILL' kpi_nm, sum(dly) dly, sum(mtd) mtd, sum(lmtd) lmtd, sum(m1) m1, sum(m2) m2, timestamp(current_datetime('+7')) ppn_dttm, vdt_id dt_id
from  `data-bi-prd-935c.bi_mart`.tmp_imkas_kpi_smy_myim3_{{ vdt_id }}
union all
select 'FEE' kpi_nm, sum(dly) dly, sum(mtd) mtd, sum(lmtd) lmtd, sum(m1) m1, sum(m2) m2, timestamp(current_datetime('+7')) ppn_dttm, vdt_id dt_id
from `data-bi-prd-935c.bi_mart`.tmp_imkas_kpi_smy_fee_{{ vdt_id }}
union all
select category kpi_nm, sum(dly) dly, sum(mtd) mtd, sum(lmtd) lmtd, sum(m1) m1, sum(m2) m2, timestamp(current_datetime('+7')) ppn_dttm, vdt_id dt_id
from `data-bi-prd-935c.bi_mart`.tmp_imkas_kpi_smy_fee_cat_{{ vdt_id }}
group by 1
union all
select 'REVERSAL' kpi_nm, sum(dly) dly, sum(mtd) mtd, sum(lmtd) lmtd, sum(m1) m1, sum(m2) m2, timestamp(current_datetime('+7')) ppn_dttm, vdt_id dt_id
from `data-bi-prd-935c.bi_mart`.tmp_imkas_kpi_smy_reversal_{{ vdt_id }}
union all
select category kpi_nm, sum(dly) dly, sum(mtd) mtd, sum(lmtd) lmtd, sum(m1) m1, sum(m2) m2, timestamp(current_datetime('+7')) ppn_dttm, vdt_id dt_id
from `data-bi-prd-935c.bi_mart`.tmp_imkas_kpi_smy_reversal_cat_{{ vdt_id }}
group by 1
;


--- drop temp table
drop table if exists `data-bi-prd-935c.bi_mart`.tmp_imkas_kpi_smy_utu_{{ vdt_id }};
drop table if exists `data-bi-prd-935c.bi_mart`.tmp_imkas_kpi_smy_trx_{{ vdt_id }};
drop table if exists `data-bi-prd-935c.bi_mart`.tmp_imkas_kpi_smy_topup_{{ vdt_id }};
drop table if exists `data-bi-prd-935c.bi_mart`.tmp_imkas_kpi_smy_bt_{{ vdt_id }};
drop table if exists `data-bi-prd-935c.bi_mart`.tmp_imkas_kpi_smy_cashout_{{ vdt_id }};
drop table if exists `data-bi-prd-935c.bi_mart`.tmp_imkas_kpi_smy_bill_{{ vdt_id }};
drop table if exists `data-bi-prd-935c.bi_mart`.tmp_imkas_kpi_smy_myim3_{{ vdt_id }};
drop table if exists `data-bi-prd-935c.bi_mart`.tmp_imkas_kpi_smy_fee_{{ vdt_id }};
drop table if exists `data-bi-prd-935c.bi_mart`.tmp_imkas_kpi_smy_fee_cat_{{ vdt_id }};
drop table if exists `data-bi-prd-935c.bi_mart`.tmp_imkas_kpi_smy_reversal_{{ vdt_id }};
drop table if exists `data-bi-prd-935c.bi_mart`.tmp_imkas_kpi_smy_reversal_cat_{{ vdt_id }};