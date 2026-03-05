declare vdt_id date default @vdt_id;
	  
delete from `data-bi-prd-935c.bi_mart`.project_ioh_secondary_outlet where dt_sk_id = vdt_id and secondary_category in ('FRC','UNLOCK');

insert into `data-bi-prd-935c.bi_mart`.project_ioh_secondary_outlet(dt_sk_id,partner_type,msisdn,
angie_hrchy_sk_id,partner_qr_cd,secondary_category,secondary_type,kpi_cnt)
select 
dt,
'Ret',
ret_msisdn,
angie_hrchy_sk_Id,
partner_qr_cd,
package_type as secondary_category,
case
when voucher_type = 'PHYSICAL PULSA' then 'UNLOCK PULSA'
when package_type = 'UNLOCK' and voucher_type <> 'PHYSICAL PULSA' then 'UNLOCK SPV'
when service_type = 'FRC BROADBAND' then 'SP DATA'
when service_type <> 'FRC BROADBAND' then 'SP NON DATA'
else 'NA'
end as secondary_type,
sum(instances) as kpi_cnt
FROM
(
select dt, angie_hrchy_sk_Id, qr_cd as partner_qr_cd, null ret_msisdn, siteid_bnum, sd_type, package_type, service_type, voucher_type, 
hits_sidnum as instances, gross_revenue as main_price, net_revenue as amount
from `data-bi-prd-935c.bi_mart`.dm_snd_voucher where sd_type = 'SUPPLY' AND package_type = 'UNLOCK' and dt = vdt_id
UNION ALL
select dt, cast(angie_hrchy_sk_Id as string), partner_qr_cd, ret_msisdn, siteid_bnum, sd_type, 'FRC', report_rowname, null, 
hits_sim_msisdn as instances, gross_revenue as main_price, net_revenue as amount 
from `data-bi-prd-935c.bi_mart`.dm_snd_demand_frc where sd_type = 'SUPPLY' and dt = vdt_id
) a
group by 1,2,3,4,5,6,7;






delete from `data-bi-prd-935c.bi_mart`.project_ioh_secondary_outlet where secondary_category = 'SALDO' and dt_sk_id = vdt_id;

INSERT INTO `data-bi-prd-935c.bi_mart`.project_ioh_secondary_outlet
select date(snp_dt_sk_id) dt_sk_id, fct.partner_type, kpi_name, msisdn, cast(angie_hrchy_sk_id as string) angie_hrchy_sk_id , partner_qr_cd, 'SALDO' secondary_category, kpi_name secondary_type, hierarchy_type, value, kpi_cnt
from `data-bi-prd-935c.bi_mart`.v_snd_secondary_transaction fct
left join `data-dtptechm-prd-c7ca.stg`.stg_cx_angie_msisdn ph on ph.name = msisdn
and upper(status) in ('ACTIVE', 'SUSPENDED')
--left join `data-dtptechm-prd-c7ca.stg`.stg_cx_angie_prtnr prt on prt.row_id = ph.par_row_id
--left join `data-dtptechm-prd-c7ca.dwh`.angie_hrchy_dimtab_3 on tab_3.partner_id = prt.partner_id
left join `data-dtptechm-prd-c7ca.dwh`.angie_hrchy_dim    tab_3 on tab_3.partner_qr_cd = ph.qr_code
where date(snp_dt_sk_id) = vdt_id;


create or replace table `data-bi-prd-935c.bi_stg`.stg_daily_fav_site_dim as 
select date(dt_id) dt_id,* except (bq_load_id, bq_load_time,dt_id) 
from `data-dtptechm-prd-c7ca.dwh`.daily_fav_site_dim
where date(dt_id) =vdt_id;

delete from `data-bi-prd-935c.bi_mart`.mart_evc where topup_dt_sk_id = vdt_id;
INSERT INTO `data-bi-prd-935c.bi_mart`.mart_evc
SELECT 
date(a.topup_dt_sk_id) topup_dt_sk_id,
a.topup_source,
a.topup_type,
a.voucher_id,
a.category_1,
a.revenue_category,
/*
--- ternyata untuk topup_type = 'NG' ada yg BANK untuk Non PULSA
case when a.topup_type = 'BANKING' then bank.evc_bank_sk_id else b.evc_dealer_sk_Id end as evc_dealer_sk_Id,
case when a.topup_type = 'BANKING' then institution_id else c.hp_no end as dealer_id,
case when a.topup_type = 'BANKING' then bank.institution_name else c.dealer_name end as dealer_nm,
*/
case when bank.serial_number is not null and bank.evc_bank_sk_id <> -2 AND topup_type in ('BANKING','NG','EAD') then bank.evc_bank_sk_id else b.evc_dealer_sk_Id end as evc_dealer_sk_Id,
case when bank.serial_number is not null and bank.evc_bank_sk_id <> -2 AND topup_type in ('BANKING','NG','EAD') then bank.institution_id else c.hp_no end as dealer_id,
case when bank.serial_number is not null and bank.evc_bank_sk_id <> -2 AND topup_type in ('BANKING','NG','EAD') then bank.institution_name else c.dealer_name end as dealer_nm,


a.sbscrptn_msisdn,
cast(a.sbscrptn_ek_id as string) sbscrptn_ek_id,
fav.site_id_dly,
sum(gross_revenue) as gross_revenue,
sum(coalesce(comm_3as,0)+coalesce(comm_3as_bonus,0)) as comm_3as,
sum(net_revenue) as net_revenue,
sum(pulsa) as pulsa,
sum(src_value) as src_value,

--- broadband
sum(case when coalesce(revenue_type,'NA') = 'BROADBAND' then gross_revenue else 0 end) as Broadband_gross_rev,
sum(case when coalesce(revenue_type,'NA') = 'BROADBAND' then coalesce(comm_3as,0)+coalesce(comm_3as_bonus,0) else 0 end) as Broadband_comm_3as,
sum(case when coalesce(revenue_type,'NA') = 'BROADBAND' then net_revenue else 0 end) as Broadband_net_rev,

count(1) record_cnt,
timestamp(current_datetime('+7')) as created_dtm,
case 
when bank.serial_number is not null AND topup_type in ('BANKING','NG') then 'BANK' 
when b.product_serial_no is not null then topup_type else 'OTHERS'
end as source_nm
--a.*, b.src_value, b.*, c.*
FROM `data-dtptechm-prd-c7ca.dwh`.sbscrptn_topup_base a
left outer join `data-bi-prd-935c.bi_stg`.stg_daily_fav_site_dim fav 
ON fav.sbscrptn_ek_id = a.sbscrptn_ek_id ---AND a.topup_dt_sk_id = fav.dt 
left outer join `data-dtptechm-prd-c7ca.dwh`.evc_dealer_recharge_fct b ON a.voucher_id = b.product_serial_no and b.recharge_dt_sk_id = a.topup_dt_sk_id
left outer join `data-dtptechm-prd-c7ca.dwh`.evc_dealer_dim c ON b.evc_dealer_sk_id = c.evc_dealer_sk_id 
left outer join (
select distinct serial_number, evc_bank_sk_id, institution_id, institution_name
from `data-dtptechm-prd-c7ca.dwh`.evc_recharge_bank_fct a
left outer join `data-dtptechm-prd-c7ca.dwh`.evc_h2h_institution_dim b ON a.evc_bank_sk_id = b.evc_h2h_institution_sk_Id
where date_trunc(date(a.transaction_dt_sk_id),month) = date_trunc(vdt_id,month)
--where a.transaction_dt_sk_id
) bank ON bank.serial_number = a.voucher_id
where date(a.topup_dt_sk_id) =vdt_id 
--and upper(a.category_1)<>'REGULAR'
and upper(a.topup_group)<>'PHYSICAL'
group by 1,2,3,4,5,6,7,8,9,10,11,12,23;

delete from `data-bi-prd-935c.bi_mart.project_ioh_secondary_outlet` where dt_sk_id =  vdt_id and secondary_category in ('BANK');

INSERT INTO `data-bi-prd-935c.bi_mart`.project_ioh_secondary_outlet(dt_sk_id,partner_type,msisdn,
angie_hrchy_sk_id,partner_qr_cd,secondary_category,secondary_type,value)
SELECT 
topup_dt_sk_id, 
'Ret',
cast(null as string),
cast(evc_dealer_sk_id as string),
dealer_id,
'BANK' as secondary_category,
'ETOPUP'||case when category_1 = 'Regular' then 'PULSA' else 'NON PULSA' end as secondary_type,
cast(sum(case when category_1 = 'Regular' then 
case when source_nm = 'BANK' then pulsa else src_value end
else net_revenue end) as bignumeric) as value
FROM `data-bi-prd-935c.bi_mart`.mart_evc a
WHERE topup_dt_sk_id = vdt_id
AND source_nm = 'BANK'
GROUP BY 1,2,3,4,5,6,7;

 delete from `data-bi-prd-935c.bi_mart`.stg_v_map_tgt_ret_details_hist
 where dt =vdt_id ;
 
 insert into `data-bi-prd-935c.bi_mart`.stg_v_map_tgt_ret_details_hist 
 select vdt_id,a.* except(bq_job_id,bq_prc_dt,bq_ppn_dttm) from 
 `data-dtptechm-prd-c7ca.stg`.stg_v_map_tgt_ret_details a;