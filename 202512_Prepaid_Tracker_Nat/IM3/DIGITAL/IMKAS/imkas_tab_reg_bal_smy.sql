declare vdt_id date default @vdt_id;

--- balance
delete from `data-bi-prd-935c.bi_mart`.imkas_reg_bal_smy where dt_id = vdt_id;
insert into `data-bi-prd-935c.bi_mart`.imkas_reg_bal_smy
select status_upgrade
  , CASE
      WHEN date_diff(dt_id ,timestamp(tgl_register),day) <= 30 THEN 'a.1-30 Days'
      WHEN date_diff(dt_id ,timestamp(tgl_register),day) <= 60 THEN 'b.31-60 Days'
      WHEN date_diff(dt_id ,timestamp(tgl_register),day) <= 90 THEN 'c.61-90 Days'
      WHEN date_diff(dt_id ,timestamp(tgl_register),day) >  90 THEN 'd.> 90 Days'
  end tnr
  , case when a.norek_digibank=b.no_rekening then 'YES' else 'NO' end have_trx
  , count(distinct norek_digibank) subs, sum(saldo) balance
  , timestamp(current_datetime('+7')) ppn_dttm
  , vdt_id dt_id
from `data-dtp-prd-aa1a.stg`.imkas_dtl_subscription a
left join
(
  select distinct no_rekening
  from `data-bi-prd-935c.bi_mart`.imkas_trx_dly
  where dt_id between vdt_id - interval 30 day and vdt_id
    and grp in ('CASHOUT','BILL PAYMENT','MYIM3 BILL PAYMENT')
) b
  on a.norek_digibank=b.no_rekening
where date(dt_id)=vdt_id and ifnull(norek_digibank,'')!='' and saldo>0
group by 1,2,3
union all
select status_upgrade
  , CASE
    WHEN date_diff(dt_id ,timestamp(tgl_register),day) <= 30 THEN 'a.1-30 Days'
    WHEN date_diff(dt_id ,timestamp(tgl_register),day) <= 60 THEN 'b.31-60 Days'
    WHEN date_diff(dt_id ,timestamp(tgl_register),day) <= 90 THEN 'c.61-90 Days'
    WHEN date_diff(dt_id ,timestamp(tgl_register),day) >  90 THEN 'd.> 90 Days'
  end tnr
  , case when a.norek_digibank=b.no_rekening then 'YES' else 'NO' end have_trx
  , count(distinct norek_digibank) subs, 0 balance
  , timestamp(current_datetime('+7')) ppn_dttm
  , vdt_id dt_id
from `data-dtp-prd-aa1a.stg`.imkas_dtl_subscription a
left join
(
  select distinct no_rekening
  from `data-bi-prd-935c.bi_mart`.imkas_trx_dly
  where dt_id between vdt_id - interval 30 day and vdt_id
    and grp in ('CASHOUT','BILL PAYMENT','MYIM3 BILL PAYMENT')
) b
  on a.norek_digibank=b.no_rekening
where date(dt_id)=vdt_id and ifnull(norek_digibank,'')!='' and saldo<=0
group by 1,2,3
;
