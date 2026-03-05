Declare vdt_id date default @vdt_id;
--CSO TRANSACTION
delete from `data-bi-prd-935c.bi_mart`.cso_trx where dt_id = vdt_id;
insert into `data-bi-prd-935c.bi_mart`.cso_trx
select region,area,sales_area,cluster,organization_id,organization_name,organization_type,
operator_id,operator_name,operator_type,credit_party_id,credit_party_name,round(cast(amount as bignumeric)) amount,date(dt_id) dt_id
from `data-dtp-prd-aa1a.stg`.mobo_allocation_org_to_org
where lower(channel) like '%traditional%' 
and organization_type in ('Dealer','SDP')
and (upper(credit_party_id) not like '%DS%' 
and upper(credit_party_id) not like '%SF%'
and upper(credit_party_id) not like '%H2H%') 
and account_type = 'Saldo Mobo Account'
and credit_party_id not like 'D%'
and transaction_status = 'Completed' 
and status_description = 'Success'
and transaction_channel = 'API'
and (operator_type in ('Canvasser','Outlet Owner') or lower(operator_type) like '%canvasser%')
and dt_id=timestamp(vdt_id);

--CSO TRANSACTION DLY
delete from `data-bi-prd-935c.bi_mart`.track_cso_dly where dt_id = vdt_id;
insert into `data-bi-prd-935c.bi_mart`.track_cso_dly
select operator_id,b.region,b.area,b.sales_area,b.sales_cluster,b.micro_cluster,sum(cast(amount as numeric)) amt,count(distinct credit_party_id) num_outlet,vdt_id dt_id
from `data-bi-prd-935c.bi_mart`.cso_trx a
join (
    select cso_code,
    case when upper(area) in ('CENTRAL JAVA','NORTH CENTRAL JAVA','WEST CENTRAL JAVA','WEST JAVA') then 'CWJ'
    when upper(area) in ('BALI NUSRA','EAST JAVA','EASTERN EAST JAVA','WESTERN EAST JAVA') then 'EJBN'
    when upper(area) in ('BOTABEK','JAKARTA') then 'JBRO'
    when upper(area) in ('KALIMANTAN','SUMAPA') then 'KALISULA'
    when upper(area) in ('NORTHERN SUMATERA','SOUTHERN SUMATERA') then 'SUMATERA'
    end region,area,sales_area,sales_cluster,micro_cluster from
    (
        select cso_code,sub_area_name area,sales_area_name sales_area,
        cluster_name sales_cluster,micro_cluster_name micro_cluster,
        ROW_NUMBER() OVER (partition by cso_code ORDER BY dt_id,micro_cluster_name desc) AS rn
        from `data-dtp-prd-aa1a.stg`.mobi_master_hierarchy_feed a
        join (select distinct micro_cluster from `data-bi-prd-935c.bi_mart`.ref_site) b on a.micro_cluster_name=b.micro_cluster
        where 
        dt_id between timestamp(vdt_id - interval 30 day) and timestamp(vdt_id + interval 1 day)
        and (channel='Traditional' or channel like 'Outlet%') and micro_cluster_name not like '%OLD') a
    where rn=1) b 
    on a.operator_id=b.cso_code
where dt_id=vdt_id and amount>=50000
group by 1,2,3,4,5,6,9;

--CSO TRANSACTION DLY MOBO DETAIL
delete from `data-bi-prd-935c.bi_mart`.track_cso_dly_mobo where dt_id = vdt_id;
insert into `data-bi-prd-935c.bi_mart`.track_cso_dly_mobo
select operator_id,b.region,b.area,b.sales_area,b.sales_cluster,b.micro_cluster,credit_party_id,
sum(cast(amount as int64)) amt,vdt_id dt_id
from `data-bi-prd-935c.bi_mart`.cso_trx a
join (
    select cso_code,
    case when upper(area) in ('CENTRAL JAVA','NORTH CENTRAL JAVA','WEST CENTRAL JAVA','WEST JAVA') then 'CWJ'
    when upper(area) in ('BALI NUSRA','EAST JAVA','EASTERN EAST JAVA','WESTERN EAST JAVA') then 'EJBN'
    when upper(area) in ('BOTABEK','JAKARTA') then 'JBRO'
    when upper(area) in ('KALIMANTAN','SUMAPA') then 'KALISULA'
    when upper(area) in ('NORTHERN SUMATERA','SOUTHERN SUMATERA') then 'SUMATERA'
    end region,area,sales_area,sales_cluster,micro_cluster from
    (
        select cso_code,sub_area_name area,sales_area_name sales_area,
        cluster_name sales_cluster,micro_cluster_name micro_cluster,
        ROW_NUMBER() OVER (partition by cso_code ORDER BY dt_id desc) AS rn
        from `data-dtp-prd-aa1a.stg`.mobi_master_hierarchy_feed a
        join (
            select distinct micro_cluster from `data-bi-prd-935c.bi_mart`.ref_site_mth
            where month_id=date_trunc(vdt_id,month)
            ) b on a.micro_cluster_name=b.micro_cluster
        where --dt_id='20221130'
        dt_id between timestamp(vdt_id - interval 30 day) and timestamp(vdt_id + interval 1 day)
        and (channel='Traditional' or channel like 'Outlet%') --and micro_cluster_name not like '%OLD'
    ) a
    where rn=1
    ) b on a.operator_id=b.cso_code
where dt_id=vdt_id and amount>=50000
group by 1,2,3,4,5,6,7,9;

--CSO TRANSACTION MOBII
delete from `data-bi-prd-935c.bi_mart`.cso_trx_mobii where dt_id between date_trunc(vdt_id,month) and vdt_id;
insert into `data-bi-prd-935c.bi_mart`.cso_trx_mobii
select operator_id,operator_name,product_category,product_code,product_name,
saldomobo_id,dest_saldomobo_id,cast(price as numeric) price,serial_number,msisdn,
cast(PARSE_DATETIME('%d-%b-%Y %H:%M:%S', case when transaction_datetime='' or transaction_datetime='---EOF---' then null else REPLACE(transaction_datetime,'---EOF---','') end) as date) trx_dt,
date(dt_id) dt_id
from `data-dtp-prd-aa1a.stg`.mobii_physical_distribution
where distribution_type = 'Sell In'
and dest_saldomobo_id not like 'D%'
and product_category in ('Starter Pack','Voucher')
and dt_id between timestamp(date_trunc(vdt_id,month)) and timestamp(vdt_id);

--CSO TRANSACTION DLY MOBII DETAIL
delete from `data-bi-prd-935c.bi_mart`.track_cso_dly_mobii where dt_id between date_trunc(vdt_id,month) and vdt_id;
insert into `data-bi-prd-935c.bi_mart`.track_cso_dly_mobii
select operator_id,b.region,b.area,b.sales_area,b.sales_cluster,b.micro_cluster,
dest_saldomobo_id,
sum(case when product_category='Starter Pack' then 1 else 0 end) num_sp,
sum(case when product_category='Voucher' then 1 else 0 end) num_vou,
date(dt_id) dt_id
from (select operator_id,product_category,serial_number,dest_saldomobo_id,dt_id
from 
(select operator_id,product_category,serial_number,dest_saldomobo_id,dt_id,
ROW_NUMBER() OVER (partition by serial_number ORDER BY trx_dt desc) AS rn
from `data-bi-prd-935c.bi_mart`.cso_trx_mobii
where dt_id between date_trunc(vdt_id,month) and vdt_id) a
where rn=1) a
join (select cso_code,
case when upper(area) in ('CENTRAL JAVA','NORTH CENTRAL JAVA','WEST CENTRAL JAVA','WEST JAVA') then 'CWJ'
when upper(area) in ('BALI NUSRA','EAST JAVA','EASTERN EAST JAVA','WESTERN EAST JAVA') then 'EJBN'
when upper(area) in ('BOTABEK','JAKARTA') then 'JBRO'
when upper(area) in ('KALIMANTAN','SUMAPA') then 'KALISULA'
when upper(area) in ('NORTHERN SUMATERA','SOUTHERN SUMATERA') then 'SUMATERA'
end region,area,sales_area,sales_cluster,micro_cluster from
(select cso_code,sub_area_name area,sales_area_name sales_area,
cluster_name sales_cluster,micro_cluster_name micro_cluster,
ROW_NUMBER() OVER (partition by cso_code ORDER BY dt_id desc) AS rn
from `data-dtp-prd-aa1a.stg`.mobi_master_hierarchy_feed a
--join (select distinct micro_cluster from `data-bi-prd-935c.bi_mart`.ref_site_mth
--where month_id=substr(vdt_id,1,6)) b on a.micro_cluster_name=b.micro_cluster
join (select distinct micro_cluster from `data-bi-prd-935c.bi_mart`.ref_site) b on a.micro_cluster_name=b.micro_cluster
where --dt_id='20221130'
dt_id between timestamp(vdt_id - interval 30 day) and timestamp(vdt_id + interval 1 day)
and (channel='Traditional' or channel like 'Outlet%')--and micro_cluster_name not like '%OLD'
) a
where rn=1) b on a.operator_id=b.cso_code
group by 1,2,3,4,5,6,7,10;





