declare vdt_id date default @vdt_id;
declare vdt_mth date default date_trunc(vdt_id,month);
-- sp tagging
delete from `data-bi-prd-935c.bi_mart`.sp_tag_outlet_mth where month_id = vdt_mth;
insert into `data-bi-prd-935c.bi_mart`.sp_tag_outlet_mth 
select org_id, org_msisdn, sp_tag_msisdn, dealercode, dt_id, timestamp(current_datetime('+7')) ppn_dttm, org_type, vdt_mth month_id
from
(
	select org_id, org_msisdn, sp_tag_msisdn, dealercode, dt_id, org_type, row_number() over(partition by sp_tag_msisdn order by dt_id desc) as rk
	from
	(
		select org_id, org_msisdn, sp_tag_msisdn, dealercode, date(dt_id) dt_id, org_type
		from `data-dtp-prd-aa1a.stg`.mobo_sp_tag_outlet
		where date(dt_id) between vdt_mth and vdt_id
		union all
		select org_id, org_msisdn, sp_tag_msisdn, dealercode, dt_id, org_type
		from `data-bi-prd-935c.bi_mart`.sp_tag_outlet_mth
		where month_id=vdt_mth - interval 1 month
			and dt_id>=vdt_mth - interval 24 month
	) x
) y
where rk=1;

-- voucher tagging
delete from `data-bi-prd-935c.bi_mart`.vo_tag_outlet_mth where month_id = vdt_mth;
insert into `data-bi-prd-935c.bi_mart`.vo_tag_outlet_mth 
select org_id, org_msisdn, serial_number, dealer_code, dt_id, timestamp(current_datetime('+7')) ppn_dttm,  vdt_mth month_id
from
(
	select org_id, org_msisdn, serial_number, dealer_code, dt_id, row_number() over(partition by serial_number order by dt_id desc) as rk
	from
	(
		select org_id, org_msisdn, serial_number, dealer_code, date(dt_id) dt_id
        from (
        select id_outlet org_id, org_msisdn, serial_number, dealer_code, dt_id,
        row_number() over(partition by serial_number order by `datetime` desc) as rk --update 20230727 sort by latest datetime
		from `data-dtp-prd-aa1a.stg`.mobo_indosat_voucher_tagging
		where date(dt_id) between vdt_mth and vdt_id) a
		where rk=1
		union all
		select org_id, org_msisdn, serial_number, dealer_code, dt_id
		from `data-bi-prd-935c.bi_mart`.vo_tag_outlet_mth
		where month_id=vdt_mth - interval 1 month
			and dt_id>=vdt_mth - interval 24 month
	) x
) y
where rk=1;

--- sellout/stock out isimple (dsf)
delete from  `data-bi-prd-935c.bi_mart`.immi_sellout_mth  where mth_id = vdt_mth;
insert into `data-bi-prd-935c.bi_mart`.immi_sellout_mth 
select dt_id, promoter_org_id, promoter_name, promoter_org_msisdn, hotspot_id, hotspot_name, hotspot_type, sales_type, msisdn, vdt_mth mth_id
from (
	select dt_id, promoter_org_id, promoter_name, promoter_org_msisdn, hotspot_id, hotspot_name, hotspot_type, sales_type, msisdn
		, ROW_NUMBER() over(partition by msisdn order by dt_id desc) rn
	from (
		select * from `data-bi-prd-935c.bi_mart`.immi_sellout_mth
		where mth_id=vdt_mth - interval 1 month
		and dt_id>=vdt_mth - interval 3 month
		union all
		select date(dt_id) dt_id, promoter_org_id, promoter_name,promoter_org_msisdn,
		hotspot_id, hotspot_name, hotspot_type, sales_type, msisdn, vdt_mth mth_id
		from (
			select dt_id, a.promoter_org_id, a.promoter_name,a.promoter_org_msisdn,
				a.hotspot_id, a.hotspot_name, a.hotspot_type, a.stockout_msisdn msisdn,
				case when (upper(a.hotspot_name) like 'GADGETSTORE_%' or
					upper(a.hotspot_name) like 'GS_%' or
					upper(a.hotspot_name) like 'GC_%' or
					upper(a.hotspot_name) like 'GADGET_%')
					and a.hotspot_id not in ('3A35863740','EFCE3976FF','9FB2CD3A73','19E98D0B60','284B77C0B9','DEF14481DC','875F43DF33') then 'Promotor'
					else 'Direct' end sales_type,
				ROW_NUMBER() over(partition by stockout_msisdn order by stockout_date desc) rn
			from (
				select date(dt_id) dt_id,promoter_org_id,promoter_name,promoter_org_msisdn,hotspot_id,hotspot_name,hotspot_type,stockout_msisdn,stockout_date from `data-dtp-prd-aa1a.stg`.immi_sellout_dsf1
				where date(dt_id) between vdt_mth and vdt_id and stockout_msisdn is not null
				union all
				select parse_date('%Y%m%d',dt_id) dt_id,promoter_org_id,promoter_name,promoter_org_msisdn,hotspot_id,hotspot_name,hotspot_type,stockout_msisdn,stockout_date from `data-dtp-prd-aa1a.sc`.immi_sellout_dsf_manual
				where parse_date('%Y%m%d',dt_id) between vdt_mth and vdt_id and stockout_msisdn is not null
			) a
		) a
		where rn=1
	) a
) a
where rn=1;