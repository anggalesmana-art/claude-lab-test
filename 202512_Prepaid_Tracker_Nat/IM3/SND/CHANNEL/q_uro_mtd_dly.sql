declare vdt_id date default @vdt_id;

delete from `data-bi-prd-935c.bi_mart`.seratus_q_uro_mtd where dt_id = vdt_id;
insert into `data-bi-prd-935c.bi_mart`.seratus_q_uro_mtd
select a.organization_id,organization_name,b.region,b.area,b.sales_area,b.sales_cluster,b.micro_cluster,b.site_id,new_1st_inject,new_2nd_inject,
old_sp_inject,hits_5k,case when old_sp_inject+new_2nd_inject>=5 then 1 else 0 end q_uro,hits,amt,vdt_id dt_id
from (
select mth,organization_id,sum(case when flag_sp='NEW' and hits_5k=1 then 1 else 0 end) new_1st_inject,
sum(case when flag_sp='NEW' and trx_type='SP' and hits_5k>1 then 1 else 0 end) new_2nd_inject,
sum(case when flag_sp='OLD' and trx_type='SP' and hits_5k>=1 then hits_5k else 0 end) old_sp_inject,
sum(hits_5k) hits_5k,sum(hits) hits,sum(amt) amt
from (select date_trunc(vdt_id,month) mth,organization_id,b_msisdn,flag_sp,trx_type,
sum(case when main_price>=5000 then 1 else 0 end) hits_5k,count(transaction_id) hits,sum(amount_debit) amt
from `data-bi-prd-935c.bi_mart`.seratus_uro_inject_detail_trx 
where dt_id between date_trunc(vdt_id,month) and vdt_id
group by 1,2,3,4,5) a
group by 1,2) a
left join
(select * from
(select site_id,region,area,sales_area,sales_cluster,micro_cluster,organization_id,organization_name,
ROW_NUMBER() OVER (partition by organization_id ORDER BY dt_id desc) AS rn
from `data-bi-prd-935c.bi_mart`.outlet_loc_ns
where dt_id between date_trunc(vdt_id,month) and vdt_id) a
where rn=1) b on a.organization_id=b.organization_id
;

--update voucher from same site to same mc
delete from `data-bi-prd-935c.bi_mart`.seratus_q_uro_fdv_mtd where dt_id = vdt_id;
insert into `data-bi-prd-935c.bi_mart`.seratus_q_uro_fdv_mtd
select a.organization_id,organization_name,region,area,sales_area,sales_cluster,micro_cluster,site_id,
new_1st_inject,new_2nd_inject,old_sp_inject,
new_2nd_vou_inject,old_vou_inject,
hits_5k,case when old_sp_inject+new_2nd_inject>=5 then 1 else 0 end q_uro_sp,
case when old_sp_inject+new_2nd_inject+new_2nd_vou_inject+old_vou_inject>=5
and old_sp_inject+new_2nd_inject<5 then 1 else 0 end q_uro_fdv,
hits,amt,vdt_id dt_id
from (
select mth,organization_id,organization_name,region,area,sales_area,sales_cluster,micro_cluster,site_id,
sum(case when flag_sp='NEW' and hits_5k=1 then 1 else 0 end) new_1st_inject,
sum(case when flag_sp='NEW' and trx_type='SP' and hits_5k>1 then 1 else 0 end) new_2nd_inject,
sum(case when flag_sp='OLD' and trx_type='SP' and hits_5k>=1 then hits_5k else 0 end) old_sp_inject,
sum(case when flag_sp='NEW' and trx_type like 'VOUCHER%' and hits_5k>1 and micro_cluster=micro_cluster_fav then 1 else 0 end) new_2nd_vou_inject,
sum(case when flag_sp='OLD' and trx_type like 'VOUCHER%' and hits_5k>=1 and micro_cluster=micro_cluster_fav then hits_5k else 0 end) old_vou_inject,
sum(hits_5k) hits_5k,sum(hits) hits,sum(amt) amt
from (select date_trunc(vdt_id,month) mth,a.organization_id,b_msisdn,flag_sp,trx_type,
organization_name,b.region,b.area,b.sales_area,b.sales_cluster,b.micro_cluster,b.site_id,
c.site_id site_fav,c.micro_cluster micro_cluster_fav,
sum(case when main_price>=5000 then 1 else 0 end) hits_5k,count(transaction_id) hits,sum(amount_debit) amt
from `data-bi-prd-935c.bi_mart`.seratus_uro_inject_detail_trx_fdv a
left join
(select * from
(select site_id,region,area,sales_area,sales_cluster,micro_cluster,organization_id,organization_name,
ROW_NUMBER() OVER (partition by organization_id ORDER BY dt_id desc) AS rn
from `data-bi-prd-935c.bi_mart`.outlet_loc_ns
where dt_id between date_trunc(vdt_id,month) and vdt_id) a
where rn=1) b on a.organization_id=b.organization_id
left join (select a.site_id,msisdn,b.micro_cluster
from `data-bi-prd-935c.bi_mart`.all_90d_fav_loc_dly a
join `data-bi-prd-935c.bi_mart`.ref_site b on a.site_id=b.site_id
--join (select * from `data-bi-prd-935c.bi_mart`.ref_site_mth
--where month_id=substr(vdt_id,1,6)) b on a.site_id=b.site_id
where dt_id=vdt_id) c on a.b_msisdn=c.msisdn
where dt_id between date_trunc(vdt_id,month) and vdt_id
group by 1,2,3,4,5,6,7,8,9,10,11,12,13,14) a
group by 1,2,3,4,5,6,7,8,9) a
;
