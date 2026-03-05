declare vdt_id date default @vdt_id;


--SERATUS SECONDARY OUTLET SUMMARY
delete from `data-bi-prd-935c.bi_mart`.seratus_sellin_outlet where dt_id = vdt_id;
insert into `data-bi-prd-935c.bi_mart`.seratus_sellin_outlet
select coalesce(a.site_id,b.site_id) site_id,sum(sellin_dly) sellin_dly,sum(sellin_mtd) sellin_mtd,
sum(amt) amt,coalesce(a.dt_id,b.dt_id) dt_id
from
(select site_id,count(distinct organization_id) sellin_dly,dt_id,sum(amt) amt
from `data-bi-prd-935c.bi_mart`.seratus_sellin_outlet_detail
where dt_id=vdt_id
group by 1,3) a
full outer join
(select site_id,count(distinct organization_id) sellin_mtd,vdt_id dt_id
from `data-bi-prd-935c.bi_mart`.seratus_sellin_outlet_detail
where dt_id between date_trunc(vdt_id,month)and vdt_id
group by 1,3) b on a.site_id=b.site_id
group by 1,5;

--- URO SUMMARY 20230528
delete from `data-bi-prd-935c.bi_mart`.seratus_uro_inject where dt_id = vdt_id;
insert into `data-bi-prd-935c.bi_mart`.seratus_uro_inject
select coalesce(a.site_id,b.site_id) site_id,
sum(coalesce(uro_dly,0)) uro_dly,sum(coalesce(uro_mtd,0)) uro_mtd,sum(coalesce(amt,0)) amt,
sum(coalesce(uro_mtd2,0)) uro_mtd2,sum(coalesce(amt2,0)) amt2,sum(coalesce(main_price,0)) main_price,
sum(coalesce(uro_3fi,0)) uro_3fi,sum(coalesce(amt_3fi,0)) amt_3fi,sum(coalesce(main_price_3fi,0)) main_price_3fi,
coalesce(a.dt_id,b.dt_id) dt_id
from
(select site_id,count(distinct organization_id) uro_dly,dt_id,sum(amt) amt
from `data-bi-prd-935c.bi_mart`.seratus_uro_inject_detail
where dt_id=vdt_id
group by 1,3) a
full outer join
(select site_id,count(distinct organization_id) uro_mtd,vdt_id dt_id
from `data-bi-prd-935c.bi_mart`.seratus_uro_inject_detail
where dt_id between date_trunc(vdt_id,month) and vdt_id
group by 1,3) b on a.site_id=b.site_id
left join
(select site_id,count(organization_id) uro_mtd2,sum(main_price) main_price,sum(amt) amt2
from
(select site_id,organization_id,sum(main_price) main_price,sum(amt) amt
from `data-bi-prd-935c.bi_mart`.seratus_uro_inject_detail
where dt_id between date_trunc(vdt_id,month) and vdt_id
group by 1,2) a
where main_price>=20000
group by 1) c on b.site_id=c.site_id
left join
(select site_id,count(organization_id) uro_3fi,sum(main_price) main_price_3fi,sum(amt) amt_3fi
from
(select site_id,organization_id,sum(main_price) main_price,sum(amt) amt
from `data-bi-prd-935c.bi_mart`.seratus_uro_inject_detail a
join (select product_name 
from `data-dtp-prd-aa1a.smy.rls_moboreff`
where package_type_ng in 
('FIS 2.5GB 5D',
'FI 3GB',
'FI 5.5GB')
group by 1) b on a.product_name=b.product_name
where dt_id between date_trunc(vdt_id,month) and vdt_id
group by 1,2) a
group by 1) d on b.site_id=d.site_id
group by 1,11;

--- DSO SUMMARY
delete from `data-bi-prd-935c.bi_mart`.seratus_dso_inject where dt_id = vdt_id;
insert into `data-bi-prd-935c.bi_mart`.seratus_dso_inject
select coalesce(a.site_id,b.site_id) site_id,sum(dso_dly) dso_dly,sum(dso_mtd) dso_mtd,
sum(amt) amt,coalesce(a.dt_id,b.dt_id) dt_id
from
(select site_id,count(distinct organization_id) dso_dly,dt_id,sum(amt) amt
from `data-bi-prd-935c.bi_mart`.seratus_dso_inject_detail
where dt_id=vdt_id
group by 1,3) a
full outer join
(select site_id,count(distinct organization_id) dso_mtd,vdt_id dt_id
from `data-bi-prd-935c.bi_mart`.seratus_dso_inject_detail
where dt_id between date_trunc(vdt_id,month)and vdt_id
group by 1,3) b on a.site_id=b.site_id
group by 1,5;

--- VSO SUMMARY
delete from `data-bi-prd-935c.bi_mart`.seratus_vso_inject where dt_id = vdt_id;
insert into `data-bi-prd-935c.bi_mart`.seratus_vso_inject 
select coalesce(a.site_id,b.site_id) site_id,sum(vso_dly) vso_dly,sum(vso_mtd) vso_mtd,
sum(amt) amt,coalesce(a.dt_id,b.dt_id) dt_id
from
(select site_id,count(distinct organization_id) vso_dly,dt_id,sum(amt) amt
from `data-bi-prd-935c.bi_mart`.seratus_vso_inject_detail
where dt_id=vdt_id
group by 1,3) a
full outer join
(select site_id,count(distinct organization_id) vso_mtd,vdt_id dt_id
from `data-bi-prd-935c.bi_mart`.seratus_vso_inject_detail
where dt_id between date_trunc(vdt_id,month)and vdt_id
group by 1,3) b on a.site_id=b.site_id
group by 1,5;

------- SALES AND DISTRIBUTION ----------------------
----------------------------------------------------
--------------- SELLIN_DLY --------------------------
----------------------------------------------------

delete from `data-bi-prd-935c.bi_mart`.seratus_kpi_v1_new where dt_id = vdt_id and kpi = 'SELLIN_DLY';
insert into `data-bi-prd-935c.bi_mart`.seratus_kpi_v1_new 
SELECT 
site_id,
sum (sellin_dly) kpi_metric , 
cast('SELLIN_DLY' as STRING) kpi,
dt_id from  `data-bi-prd-935c.bi_mart`.seratus_sellin_outlet  
where dt_id = vdt_id
GROUP BY site_id,dt_id ;


----------------------------------------------------
--------------- SELLIN_MTD --------------------------
----------------------------------------------------
----------------------------------------------------
delete from `data-bi-prd-935c.bi_mart`.seratus_kpi_v1_new where dt_id = vdt_id and kpi = 'SELLIN_MTD';
insert into `data-bi-prd-935c.bi_mart`.seratus_kpi_v1_new 
SELECT 
site_id,
sum (sellin_mtd) kpi_metric , 
cast('SELLIN_MTD' as STRING) kpi, 
dt_id from  `data-bi-prd-935c.bi_mart`.seratus_sellin_outlet  
where dt_id = vdt_id
GROUP BY site_id,dt_id ;


----------------------------------------------------
--------------- SELLIN_AMOUNT ----------------------
----------------------------------------------------
----------------------------------------------------
delete from `data-bi-prd-935c.bi_mart`.seratus_kpi_v1_new where dt_id = vdt_id and kpi = 'SELLIN_AMOUNT_TO_OUTLET';
insert into `data-bi-prd-935c.bi_mart`.seratus_kpi_v1_new 
SELECT 
site_id,
sum (amt) kpi_metric , 
cast('SELLIN_AMOUNT_TO_OUTLET' as STRING) kpi, 
dt_id from  `data-bi-prd-935c.bi_mart`.seratus_sellin_outlet 
where dt_id = vdt_id
GROUP BY site_id,dt_id 
;

----------------------------------------------------
--------------- URO Daily---------------------------
--Unique Reload Outlet Daily------------------------
----------------------------------------------------

delete from `data-bi-prd-935c.bi_mart`.seratus_kpi_v1_new where dt_id = vdt_id and kpi = 'URO_DLY';
insert into `data-bi-prd-935c.bi_mart`.seratus_kpi_v1_new 
SELECT 
site_id,
sum(uro_dly) kpi_metric,
cast('URO_DLY' as STRING) kpi,
dt_id
from `data-bi-prd-935c.bi_mart`.seratus_uro_inject 
where dt_id = vdt_id
GROUP BY site_id,dt_id 
;

----------------------------------------------------
--------------- URO MTD-----------------------------
--Unique Reload Outlet Month To Date----------------
----------------------------------------------------
delete from `data-bi-prd-935c.bi_mart`.seratus_kpi_v1_new where dt_id = vdt_id and kpi = 'URO_MTD';
insert into `data-bi-prd-935c.bi_mart`.seratus_kpi_v1_new 
SELECT 
site_id,
sum(uro_mtd) kpi_metric,
cast('URO_MTD' as STRING) kpi,
dt_id
from `data-bi-prd-935c.bi_mart`.seratus_uro_inject 
where dt_id = vdt_id
GROUP BY site_id,dt_id ;


----------------------------------------------------
--------------- URO_AMOUNT-----------------------------
--Unique Reload Outlet IDR Amount----------------
----------------------------------------------------

delete from `data-bi-prd-935c.bi_mart`.seratus_kpi_v1_new where dt_id = vdt_id and kpi = 'URO_AMOUNT';
insert into `data-bi-prd-935c.bi_mart`.seratus_kpi_v1_new 
SELECT 
site_id,
sum(amt) kpi_metric,
cast('URO_AMOUNT' as STRING) kpi,
dt_id
from `data-bi-prd-935c.bi_mart`.seratus_uro_inject  
where dt_id = vdt_id
GROUP BY site_id,dt_id ;


---URO_AMOUNT_MTD
delete from `data-bi-prd-935c.bi_mart`.seratus_kpi_v1_new where dt_id = vdt_id and kpi = 'URO_AMOUNT_MTD';
insert into `data-bi-prd-935c.bi_mart`.seratus_kpi_v1_new 
SELECT 
site_id,
sum(amt) kpi_metric,
cast('URO_AMOUNT_MTD' as STRING) kpi,
vdt_id dt_id
from `data-bi-prd-935c.bi_mart`.seratus_uro_inject  
where dt_id = vdt_id
GROUP BY site_id ;

-- 30. URO20 MTD
delete from `data-bi-prd-935c.bi_mart`.seratus_kpi_v1_new where dt_id = vdt_id and kpi = 'URO20 MTD';
insert into `data-bi-prd-935c.bi_mart`.seratus_kpi_v1_new 
select
site_id,
sum(uro_mtd2) kpi_metric,
cast('URO20 MTD' as STRING) kpi,
dt_id
from `data-bi-prd-935c.bi_mart`.seratus_uro_inject 
where dt_id = vdt_id
GROUP BY site_id,dt_id 
;

-- 31. URO20 AMOUNT MTD
delete from `data-bi-prd-935c.bi_mart`.seratus_kpi_v1_new where dt_id = vdt_id and kpi = 'URO20 AMOUNT MTD';
insert into `data-bi-prd-935c.bi_mart`.seratus_kpi_v1_new 
select
site_id,
sum(amt2) kpi_metric,
cast('URO20 AMOUNT MTD' as STRING) kpi,
dt_id
from `data-bi-prd-935c.bi_mart`.seratus_uro_inject 
where dt_id = vdt_id
GROUP BY site_id,dt_id 
;

-----------------------------------------
--------------- TERTIATY WITH USAGE------
--URO/Tertiaty With usage IDR Amount-----
-----------------------------------------
delete from `data-bi-prd-935c.bi_mart`.seratus_kpi_v1_new where dt_id = vdt_id and kpi = 'TERTIARY_USG_AMOUNT';
insert into `data-bi-prd-935c.bi_mart`.seratus_kpi_v1_new 
SELECT 
site_id, 
sum(amt) kpi_metric ,
'TERTIARY_USG_AMOUNT' kpi,dt_id 
from `data-bi-prd-935c.bi_mart`.seratus_tertiary_outlet
where dt_id = vdt_id
GROUP BY site_id,dt_id ;
