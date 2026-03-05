DECLARE vdt_id DATE DEFAULT @vdt_id;

-- DECLARE vdt_id DATE DEFAULT @vdt_id;

drop table if exists `data-bi-prd-935c.bi_stg.stg_corporate_ret`;

CREATE TABLE `data-bi-prd-935c.bi_stg.stg_corporate_ret` as
	select * from 
	(
		select 
		row_number()over(partition by name order by created desc) as seqno,
		TRIM(name) as ret_trx_msisdn,
		a.qr_code as retailerID,
		a.status,
		b.tm_name,
		b.tm_location,
		b.mp3_location,
		b.ret_hierarchy_type,
		CURRENT_TIMESTAMP() as created_dtm	
		from `data-dtptechm-prd-c7ca.stg.stg_cx_angie_msisdn` a
		left outer join `data-dtptechm-prd-c7ca.dwh.angie_hrchy_dim` b ON a.qr_code = b.partner_qr_cd
		where ret_hierarchy_type = 'SAHABAT'
	) a
	where seqno = 1;

delete from `data-bi-prd-935c.bi_mart.ioh_project_corporate_rchg` where trx_dt_sk_id = vdt_id;
--- 01. load data from RITA Channel                   
INSERT INTO `data-bi-prd-935c.bi_mart.ioh_project_corporate_rchg`
SELECT 
cast(trx_dt_sk_id as date) trx_dt_sk_id, 
process_nm, 
cast(sbscrptn_ek_id as string),
sbscrptn_msisdn,
cast(product_id as string),
product_name,
transaction_id,
service_type,
gl_cd,
b.ret_trx_msisdn,
b.retailerID,
sum(unearned) as topup_pulsa,
sum(net_revenue) as net_revenue,
CURRENT_TIMESTAMP()
from `data-dtptechm-prd-c7ca.dwh.revenue_base` a
join `data-bi-prd-935c.bi_stg.stg_corporate_ret` b ON b.ret_trx_msisdn = a.ret_trx_msisdn
where cast(trx_dt_sk_id as date) =vdt_id AND 
process_nm in ('RITA','RITA_TOPUP')
AND coalesce(tool_of_trade_ind,'N') = 'N'
group by 1,2,3,4,5,6,7,8,9,10,11;

--- >> Unlock yg diburn / voucher demand
INSERT INTO `data-bi-prd-935c.bi_mart.ioh_project_corporate_rchg`
SELECT 
cast(trx_dt_sk_id as date) trx_dt_sk_id,  
process_nm, 
cast(sbscrptn_ek_id as string),
sbscrptn_msisdn,
cast(product_id as string),
product_name,
transaction_id,
service_type,
gl_cd,
b.ret_trx_msisdn,
b.retailerID,
sum(unearned) as topup_pulsa,
sum(net_revenue) as net_revenue,
CURRENT_TIMESTAMP()
from `data-dtptechm-prd-c7ca.dwh.revenue_base` a
join `data-bi-prd-935c.bi_stg.stg_corporate_ret` b ON b.ret_trx_msisdn = a.ret_trx_msisdn
where cast(trx_dt_sk_id as date)  =vdt_id AND 
coalesce(tool_of_trade_ind,'N') = 'N'
and process_nm in (
'VOUCHER_DEMAND' 	---> non pulsa
)
GROUP BY 1,2,3,4,5,6,7,8,9,10,11;


--- TOPUP PULSA BURN >> get retailer trx dimappingkan dengan source_system_id
INSERT INTO `data-bi-prd-935c.bi_mart.ioh_project_corporate_rchg`
SELECT 
cast(trx_dt_sk_id as date) trx_dt_sk_id, 
a.process_nm, 
cast(sbscrptn_ek_id as string),
a.sbscrptn_msisdn,
cast(a.product_id as string),
a.product_name,
a.transaction_id,
a.service_type,
a.gl_cd,
c.ret_trx_msisdn,
c.retailerID,
sum(a.unearned) as topup_pulsa,
sum(a.net_revenue) as net_revenue,
CURRENT_TIMESTAMP()
from `data-dtptechm-prd-c7ca.dwh.revenue_base` a
left outer join  `data-dtptechm-prd-c7ca.dwh.vms_voucher_status_dim` b  ON a.source_system_id = b.sid_number and b.create_dtm <='9999-12-31'
join `data-bi-prd-935c.bi_stg.stg_corporate_ret` c ON c.ret_trx_msisdn = SPLIT(b.ret_detail_info, ';')[OFFSET(0)]
where 
cast(trx_dt_sk_id as date)  =vdt_id AND 
coalesce(tool_of_trade_ind,'N') = 'N'
and a.process_nm in (
	'UNBOOKED_RECHARGE'	---> pulsa
)
and UPPER(a.service_type_category_1) = 'REGULAR'
and a.curr_ind = '3AS'
group by 1,2,3,4,5,6,7,8,9,10,11;

delete from `data-bi-prd-935c.bi_mart.ioh_corporate_rch` where trx_dt_sk_id = vdt_id;

--- dump to datamart
INSERT INTO `data-bi-prd-935c.bi_mart.ioh_corporate_rch`
SELECT 
cast(trx_dt_sk_id as date) trx_dt_sk_id, 
case when b.msisdn is not null then '3 BUSINESS' else 'NON 3 BUSINESS' end as subs_tag,
cast(sum(case when coalesce(a.product_id,'8') ='8' then coalesce(topup_pulsa,0)/1.1 else coalesce(topup_pulsa,0) end) as bignumeric) as topup_pulsa_amount, 
cast(sum(case when coalesce(a.product_id,'8') = '8' then coalesce(net_revenue,0)/1.1 else coalesce(net_revenue,0) end) as bignumeric) as recharge_amount,
CURRENT_TIMESTAMP() as created_dtm
FROM `data-bi-prd-935c.bi_mart.ioh_project_corporate_rchg` a
LEFT OUTER JOIN (
--- Bila data di running H+1 (begining of month), maka menggunakan sbscrptn_attribs
--- list ini berdasarkn confirmasi shuvro @ 1 Apr by wa >> untuk mendapatkan 3Business Subs. Number sudah diconfirm oleh awang besar angkanya mirip
    select sa.msisdn from
	(select distinct sbscrptn_msisdn msisdn,mp3_Channel_sk_id, 
	row_number() over(partition by sbscrptn_msisdn order by mp3_Channel_sk_id) rank
	from  `data-dtptechm-prd-c7ca.dwh.sbscrptn_attribs`)	sa 	--> BILA DATA DIJALANKAN DI TANGGAL 1
 --	sa 	--> BILA DATA DIJALANKAN DI TANGGAL 1
					LEFT OUTER JOIN `data-dtptechm-prd-c7ca.dwh.channel_dim` cd on cd.channel_sk_id=sa.mp3_Channel_sk_id 
					LEFT OUTER JOIN `data-dtptechm-prd-c7ca.dwh.rprt_fltr_ref_ctgry` rprt on cd.channel_id=rprt.ref_cd and rprt.ref_type_cd='MP3'
	where UPPER(ctgry_ref_chld) = '3 BUSINESS'
	and rank = 1
) b ON a.sbscrptn_msisdn = b.msisdn
WHERE cast(trx_dt_sk_id as date)  = vdt_id and 
b.msisdn is null
group by 1,2;