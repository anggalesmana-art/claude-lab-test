declare vdt_id date default @vdt_id;
--STOCK TRAD SP SITEWISE
delete from `data-bi-prd-935c.bi_mart`.kpi_site_wise_dly  where kpi_id = 'SND087' and dt_id = vdt_id;
insert into `data-bi-prd-935c.bi_mart`.kpi_site_wise_dly
select 'stock_trad_sp' kpi_code,'IM3' brand,site_id,sum(stock) metric,current_datetime('+7') process_dt,'SND087' kpi_id,vdt_id dt_id
from
(select a.organization_id,sum(amount_debit) stock
from `data-bi-prd-935c.bi_mart`.stock_mobo_sp a
join (select msisdn from `data-dtp-prd-aa1a.smy.ar_cst_dly_smy`
where dt_id=timestamp(vdt_id)) b on a.b_msisdn=b.msisdn
where dt_id=vdt_id and channel='Traditional'
group by 1
union all
select a.dest_saldomobo_id organization_id,sum(amount) stock
from `data-bi-prd-935c.bi_mart`.stock_sp_data_mobii a
join (select msisdn from `data-dtp-prd-aa1a.smy.ar_cst_dly_smy`
where dt_id=timestamp(vdt_id)) b on a.msisdn=b.msisdn
where dt_id=vdt_id
group by 1) a
join (select site_id,organization_id from
(select site_id,organization_id,
ROW_NUMBER() OVER (partition by organization_id ORDER BY dt_id desc) AS rn
from `data-bi-prd-935c.bi_mart`.outlet_loc_ns
where date_trunc(dt_id,month)= date_trunc(vdt_id,month)) a
where rn=1) b on a.organization_id=b.organization_id
group by 1,2,3,5,6,7;

--STOCK TRAD VOU SITEWISE
delete from `data-bi-prd-935c.bi_mart`.kpi_site_wise_dly  where kpi_id = 'SND088' and dt_id = vdt_id;
insert into `data-bi-prd-935c.bi_mart`.kpi_site_wise_dly
select 'stock_trad_vou' kpi_code,'IM3' brand,site_id,sum(stock) metric,current_datetime('+7') process_dt,'SND088' kpi_id,vdt_id dt_id
from
(select organization_id,sum(amount_debit) stock
from `data-bi-prd-935c.bi_mart`.stock_mobo_vou
where dt_id=vdt_id
group by 1
union all
select organization_id,sum(amount_debit) stock
from `data-bi-prd-935c.bi_mart`.stock_mobo_vou_pulsa
where dt_id=vdt_id
group by 1
union all
select organization_id,sum(amount) stock
from `data-bi-prd-935c.bi_mart`.stock_vo_ori_sellin
where dt_id=vdt_id
group by 1) a
join (select site_id,organization_id from
(select site_id,organization_id,
ROW_NUMBER() OVER (partition by organization_id ORDER BY dt_id desc) AS rn
from `data-bi-prd-935c.bi_mart`.outlet_loc_ns
where date_trunc(dt_id,month)= date_trunc(vdt_id,month)) a
where rn=1) b on a.organization_id=b.organization_id
group by 1,2,3,5,6,7;

--STOCK TRAD SALDO SITEWISE
delete from `data-bi-prd-935c.bi_mart`.kpi_site_wise_dly  where kpi_id = 'SND089' and dt_id = vdt_id;
insert into `data-bi-prd-935c.bi_mart`.kpi_site_wise_dly
select 'stock_trad_saldo' kpi_code,'IM3' brand,site_id,sum(stock) metric,current_datetime('+7') process_dt,'SND089' kpi_id,vdt_id dt_id
from
(select organization_id,sum(stock_balance) stock
from `data-bi-prd-935c.bi_mart`.stock_outlet_90d
where dt_id=vdt_id
group by 1) a
join (select site_id,organization_id from
(select site_id,organization_id,
ROW_NUMBER() OVER (partition by organization_id ORDER BY dt_id desc) AS rn
from `data-bi-prd-935c.bi_mart`.outlet_loc_ns
where date_trunc(dt_id,month)= date_trunc(vdt_id,month)) a
where rn=1) b on a.organization_id=b.organization_id
group by 1,2,3,5,6,7;

