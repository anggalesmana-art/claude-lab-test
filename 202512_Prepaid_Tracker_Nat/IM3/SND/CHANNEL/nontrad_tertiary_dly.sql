declare vdt_id date default @vdt_id;
--RELOAD MOBO

delete from `data-bi-prd-935c.bi_mart`.tertiary_nontrad where dt_id = vdt_id and tertiary_type = 'MOBO RLD';
insert into `data-bi-prd-935c.bi_mart`.tertiary_nontrad
select upper(a.organization_id) organization_id,a.b_msisdn,
sum(cast(amount_debit as numeric)) amt,sum(cast(main_price as numeric)) main_price,count(transaction_id) hits,
a.product_name,channel,'MOBO RLD' tertiary_type,dt_id
from `data-bi-prd-935c.bi_mart`.sellout_salmo_dly a
where dt_id=vdt_id and lower(transaction_type) like '%reload%'
and a.channel in ('Online','Modern','H2H','Bank','GERAI','P2P','Gadget Center','Other')
group by 1,2,6,7,8,9;

--SP MOBO
delete from `data-bi-prd-935c.bi_mart`.tertiary_nontrad where dt_id = vdt_id and tertiary_type like 'SP MOBO%'; 
insert into `data-bi-prd-935c.bi_mart`.tertiary_nontrad
select upper(organizationid) organization_id,a.b_msisdn,
sum(cast(amount_debit as numeric)) amt,sum(cast(mainprice as numeric)) main_price,count(transactionid) hits,
a.productname,channel,case when a.revenue_trigger='Y2' then 'SP MOBO Y2'
when a.revenue_trigger='Y3' then 'SP MOBO Y3'
else 'SP MOBO Y4' end tertiary_type,parse_date('%Y%m%d',revenue_date) dt_id
from `data-dtp-prd-aa1a.sor`.mobo_revenue a
join (select organization_id,channel from `data-bi-prd-935c.bi_mart`.org_salmo
where mth_id=date_trunc(vdt_id,month)
and channel in ('Online','Modern','H2H','Bank','GERAI','P2P','Gadget Center','Other'))
c on a.organizationid=c.organization_id
where parse_date('%Y%m%d',revenue_date)=vdt_id and substring(a.b_msisdn, 1,5) in ('62857','62858','62856','62815','62816','62855','62814')
and prc_dt = timestamp(vdt_id + interval 1 day)
group by 1,2,6,7,8,9;

--RELOAD IGATE
delete from `data-bi-prd-935c.bi_mart`.tertiary_nontrad where dt_id = vdt_id and tertiary_type = 'IGATE RLD';
insert into `data-bi-prd-935c.bi_mart`.tertiary_nontrad
select a.bank_code organization_id,a.msisdn b_msisdn,
sum(tot_rechrg_idr_val) amt,sum(tot_rechrg_idr_val) main_price,sum(a.tot_rechrg) hits,
cast(a.dnmn_val as string) dnmn_val,'Bank' channel,'IGATE RLD' tertiary_type,date(dt_id) dt_id
from `data-dtp-prd-aa1a.smy`.cst_rechrg_dly_smy a
left join (select * from `data-bi-prd-935c.bi_mart`.ref_mochan
where channel='Bank IGate') b on upper(a.bank_code)=upper(b.outlet_code)
where date(dt_id) =vdt_id and bank_code > '0'
group by 1,2,6,7,8,9;

