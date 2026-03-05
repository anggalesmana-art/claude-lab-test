declare vdt_id date default @vdt_id;


--VOUCHER CROSSELLING (FDV PULSA IT TABLE + VOU ORI)
delete from `data-bi-prd-935c.bi_mart`.fdv_cross_dtl where dt_id = vdt_id;
insert into `data-bi-prd-935c.bi_mart`.fdv_cross_dtl
select mobo_trx_id,a.organization_id,organization_name,
b.site_id site_outlet,a.msisdn,c.site_id site_bnum,a.product_name,
amount_debit,main_price,disc_price,voucher_sn,dt_id
from (select mobo_trx_id,mobo_inj_outlet_id organization_id,
concat('62',pm_red_msisdn) msisdn,mobo_inj_pack_name product_name,
mobo_inj_sales_price amount_debit,mobo_inj_main_price main_price,mobo_inj_disc_price disc_price,
date(transactiondate) dt_id,pm_voucher_sn voucher_sn
from `data-dtp-prd-aa1a.sor`.fdv_mobo_pm_join_match
where date(transactiondate)=vdt_id and category='MOBO' and pm_voucher_status = 'U'
and substring(concat('62',pm_red_msisdn), 1,5) in ('62857','62858','62856','62815','62816','62855','62814')
--and substr(case when substr(pm_red_msisdn,1,2)!='62' then concat('62',pm_red_msisdn) else pm_red_msisdn end,1,5) in ('62857','62858','62856','62815','62816','62855','62814')
union all
select mobo_trx_id,mobo_inj_outlet_id organization_id,
concat('62',pm_red_msisdn) msisdn,mobo_inj_pack_name product_name,
mobo_inj_sales_price amount_debit,mobo_inj_main_price main_price,mobo_inj_disc_price disc_price,
date(transactiondate) dt_id,pm_voucher_sn voucher_sn
from `data-dtp-prd-aa1a.sor`.fdv_mobo_pm_join_match_reload
where date(transactiondate)=vdt_id and category='MOBO' and pm_voucher_status = 'U'
union all
select cast(b.dt_foss as string),b.organization_id,
concat('62',pm_red_msisdn) msisdn,inj_pack_name product_name,
cast(inj_sales_price as bigint) amount_debit,cast(inj_main_price as bigint) main_price,
cast(inj_disc_price as bigint) disc_price,
parse_date('%Y%m%d',transactiondate) dt_id,pm_voucher_sn voucher_sn
from `data-dtp-prd-aa1a.smy`.smy_dv_redemption a
left join (select * from `data-bi-prd-935c.bi_mart`.foss_vo_ori_sellin_mth
where mth_id=date_trunc(vdt_id,month) and
dt_sellin<=date(date_trunc(vdt_id + interval 1 month, month)- interval 1 day)) b on a.pm_voucher_sn=b.sno
where parse_date('%Y%m%d',transactiondate)=vdt_id and pm_voucher_status='U' and prc_dt = timestamp(vdt_id + interval 1 day)) a
left join (select * from
(select site_id,organization_id,organization_name,
ROW_NUMBER() OVER (partition by organization_id ORDER BY dt_id desc) AS rn
from `data-bi-prd-935c.bi_mart`.outlet_loc_ns
where dt_id between date_trunc(vdt_id,month) and vdt_id ) a
where rn=1) b on a.organization_id=b.organization_id
left join (select site_id,msisdn
from `data-bi-prd-935c.bi_mart`.all_90d_fav_loc_dly
where dt_id=vdt_id) c on a.msisdn=c.msisdn
;

-- --MPC DEPO
-- delete from  `data-bi-prd-935c.bi_mart`.mpc_depo_mth where mth_id = date_trunc(vdt_id,month);
-- insert into `data-bi-prd-935c.bi_mart`.mpc_depo_mth
-- select id_dp,
-- a.micro_cluster,
-- cluster,
-- sales_area,
-- area,
-- region,
-- kecamatanunik,
-- kecamatan,
-- kabupaten,
-- provinsi,
-- cast(long as string) long,
-- cast(lat as string) lat,
-- dp_category,
-- mpc,
-- mth
-- from rdm.spa_tbl_ref_list_distpoint_v2 a
-- left join (select micro_cluster,mpc
-- from rdm.spa_tbl_ref_territory_to_mpc
-- where mth=date_trunc(vdt_id,month)
-- --mth='202308'
-- ) b on a.micro_cluster=b.micro_cluster
-- where mth=date_trunc(vdt_id,month)
-- ;