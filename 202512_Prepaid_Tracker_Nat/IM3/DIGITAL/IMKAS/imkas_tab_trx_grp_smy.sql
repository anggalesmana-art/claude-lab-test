declare vdt_id date default @vdt_id;

delete from `data-bi-prd-935c.bi_mart`.imkas_trx_kpi_grp_smy where dt_id = vdt_id;
insert into `data-bi-prd-935c.bi_mart`.imkas_trx_kpi_grp_smy
select coalesce(dly.tnr,mtd.tnr,lmtd.tnr) tnr
  , coalesce(dly.grp,mtd.grp,lmtd.grp) grp
  , coalesce(dly.category,mtd.category,lmtd.category) category
  , sum(coalesce(hits_dly,0)) hits_dly
  , sum(coalesce(amount_dly,0)) amount_dly
  , sum(coalesce(hits_mtd,0)) hits_mtd
  , sum(coalesce(amount_mtd,0)) amount_mtd
  , sum(coalesce(hits_lmtd,0)) hits_lmtd
  , sum(coalesce(amount_lmtd,0)) amount_lmtd
  , timestamp(current_datetime('+7')) ppn_dttm
  , vdt_id dt_id
from
(
  select CASE
      WHEN tnr <= 30 THEN 'a. 1-30 Days'
      WHEN tnr <= 60 THEN 'b. 31-60 Days'
      WHEN tnr <= 90 THEN 'c. 61-90 Days'
      WHEN tnr >  90 THEN 'd. > 90 Days'
    end tnr
    , grp, category
    , sum(hits) hits_dly
    , sum(amount) amount_dly
  from `data-bi-prd-935c.bi_mart`.imkas_trx_dly
  where dt_id=vdt_id
  group by 1,2,3
) dly
full join
(
  select CASE
      WHEN tnr <= 30 THEN 'a. 1-30 Days'
      WHEN tnr <= 60 THEN 'b. 31-60 Days'
      WHEN tnr <= 90 THEN 'c. 61-90 Days'
      WHEN tnr >  90 THEN 'd. > 90 Days'
    end tnr
    , grp, category
    , sum(hits) hits_mtd
    , sum(amount) amount_mtd
  from `data-bi-prd-935c.bi_mart`.imkas_trx_dly
  where dt_id between date_trunc(vdt_id,month) and vdt_id
  group by 1,2,3
) mtd
  on dly.tnr=mtd.tnr and dly.grp=mtd.grp and dly.category=mtd.category
full join
(
  select CASE
      WHEN tnr <= 30 THEN 'a. 1-30 Days'
      WHEN tnr <= 60 THEN 'b. 31-60 Days'
      WHEN tnr <= 90 THEN 'c. 61-90 Days'
      WHEN tnr >  90 THEN 'd. > 90 Days'
    end tnr
    , grp, category
    , sum(hits) hits_lmtd
    , sum(amount) amount_lmtd
  from `data-bi-prd-935c.bi_mart`.imkas_trx_dly
  where dt_id between date_trunc(vdt_id,month) - interval 1 month and vdt_id - interval 1 month
  group by 1,2,3
) lmtd
  on dly.tnr=lmtd.tnr and dly.grp=lmtd.grp and dly.category=lmtd.category
group by 1,2,3
;