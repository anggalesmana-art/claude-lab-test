declare vdt_id date default @vdt_id;  

delete from `data-bi-prd-935c.bi_stg`.bai_3id_osa_tmp
where snp_dt_sk_id = vdt_id and src = 'prt_daily';
						
insert into `data-bi-prd-935c.bi_stg`.bai_3id_osa_tmp
select  
	date(a.snp_dt_sk_id) snp_dt_sk_id, 
	b.partner_qr_cd as ret_qrcode,
	'prt_daily' src,
	sum(a.kpi_value) as value
from `data-dtptechm-prd-c7ca.dwh`.prt_daily_channel_movement_fct as a 
left join `data-bi-prd-935c.bi_mart`.angie_hrchy_dim_hst b
on cast(a.partner_sk_id as string) = b.angie_hrchy_sk_id 
and b.mth = date_trunc(date(a.snp_dt_sk_id), month)
where a.partner_type='RET' 
and a.kpi_name ='Purchase from CAN'
and a.kpi_freq = 'Daily' 
and date(a.snp_dt_sk_id) = vdt_id
and b.mth = date_trunc(date(a.snp_dt_sk_id), month)
and date_trunc(date(a.snp_dt_sk_id), month) in (date_trunc(vdt_id,month), date_trunc(vdt_id - interval 1 month,month))
and extract(day from date(a.snp_dt_sk_id)) <= extract(day from vdt_id)
and b.mth in (date_trunc(vdt_id,month), date_trunc(vdt_id - interval 1 month,month))
and coalesce(upper(b.mp3_location),'CENTRAL WEST NORTH JKT') NOT IN ('DVM BM','3 STORE','3 BUSINESS','NA','POOL','SIM ONLINE','SOUTH JAKARTA TEST BM','ADVCREDIT','FUT ANGIE 2.0','MODCHAN','BSM TRI OFFICIAL STORE') 
and b.hrchy_type = 'Retailer' 
group by 1,2,3;

delete from `data-bi-prd-935c.bi_stg`.bai_3id_imei_tmp where dt_id = vdt_id;	

insert into `data-bi-prd-935c.bi_stg`.bai_3id_imei_tmp

select dt dt_id, sbscrptn_ek_id, 'Y' imei_flag
from `data-bi-prd-935c.bi_mart`.dm_rgs30_subs_movement_detail a
where dt = vdt_id
and flag_rotation = 'New New';
  
