   declare vdt_id date default @vdt_id;
--IM3

--------------------------------------
--- TOT REV  ---------------
--------------------------------------
 delete from `data-bi-prd-935c.bi_dev`.ioh_snd_master_kpi_detail where dt_id = vdt_id and kpi = 'tot_rev_ds' and brand = 'IM3';
-- insert into `data-bi-prd-935c.bi_dev`.ioh_snd_master_kpi_detail
-- with t_temp1 as        
--         (
--         SELECT 
--         parse_date('%Y%m%d',concat(cast(mth_id as string),'01')) mth_id,
--         im3_share_total,
--         row_number() over (order by mth_id desc) rowth
--         from `data-bi-prd-935c.bi_dm`.ref_vas_share
--         where parse_date('%Y%m%d',concat(cast(mth_id as string),'01')) <= date_trunc(vdt_id,month)
--         order by mth_id desc
--         ) ,
-- t_temp2 as (
--         select date_trunc(vdt_id,month) mth_id,im3_share_total  from t_temp1 where rowth= 1),
-- rev_ds as (
--         select 
--         site_id,
--         sum(
--         ccn_voice_revenue +
--         ccn_org_combo_addon_voice_rev +
--         mobo_voice_rev +
--         fdv_voice_rev +
--         ccn_sms_revenue +
--         ccn_org_combo_addon_sms_rev +
--         mobo_sms_rev+
--         fdv_sms_rev+
--         voucher_revenue +
--         (ccn_vas_revenue* im3_share_total) + 
--         (loan_package_revenue * 1.1) +
--         loan_balance_revenue +
--         loan_balance_fee +
--         ccn_data_revenue - ccn_org_combo_addon_voice_rev - ccn_org_combo_addon_sms_rev +
--         mobo_data_rev + fdv_data_rev + sp_data_rev + sp_fdv_data_rev +
--         myim3_rev +
--         ewallet_ovo_revenue+
--         ewallet_gopay_revenue + 
--         ewallet_shopeepay_revenue +
--         ewallet_dana_revenue +
--         ewallet_imkas_revenue +
--         ewallet_linkaja_revenue +
--         ewallet_other_revenue +
--         other_rev 
--         ) KPI_METRIC,
--         'TOT_REV' kpi,
--         dt_id
--         from `data-dtp-prd-aa1a.smy`.revenue_per_site_extended  a left join t_temp2 b on date_trunc(vdt_id,month) = b.mth_id
--         where date(dt_id) between date_trunc( vdt_id,month)  and vdt_id
--         group by site_id,dt_id
--         ),
-- rev_final as (
--         select 
--                 a.site_id id, kpi, 
--                 sum(kpi_metric)/1.11 amount
--         from rev_ds a 
--         group by 1,2
--         )
-- -------- Rev All  --------
-- select 'IM3' as brand, 
--         'site' as level, 
--         id as level_value, 
--         cast(sum(amount) as numeric) value,  -- gross 
--         'mtd' as time_flag, 
--         timestamp(current_datetime('+7')) as insert_date,
--         'tot_rev_ds' as kpi_id,
--         vdt_id as dt_id
-- from rev_final
-- where kpi = 'TOT_REV'
-- group by 1,2,3,5,6,7,8
-- ;

--3ID
--
 --Data Rev
 --

delete from `data-bi-prd-935c.bi_dev`.ioh_snd_master_kpi_detail where dt_id = vdt_id and kpi in ('tot_rev_data') and brand ='3ID';




insert into `data-bi-prd-935c.bi_dev`.ioh_snd_master_kpi_detail
 select '3ID' as brand, 
 'site_id',
 site_id,
 cast(sum(a.value) as numeric),
 'dly',
 current_timestamp,
 'tot_rev_data',
 vdt_id
 from `data-bi-prd-935c.bi_mart`.project_ioh_kpi_daily_tracker_site a
 where kpi_code in ('rev_organic', 'rev_mobo')
 and load_dt_sk_id = vdt_id
 group by 1,2,3,5,6,7,8;





 --
 --Non Data Rev
 --

delete from `data-bi-prd-935c.bi_dev`.ioh_snd_master_kpi_detail where dt_id = vdt_id and kpi in ('tot_rev_non_data') and brand ='3ID';




insert into `data-bi-prd-935c.bi_dev`.ioh_snd_master_kpi_detail
 select '3ID' as brand, 
 'site_id',
 site_id,
 cast(sum(a.value) as numeric),
 'dly',
 current_timestamp,
 'tot_rev_non_data',
 vdt_id
 from `data-bi-prd-935c.bi_mart`.project_ioh_kpi_daily_tracker_site a
 where kpi_code in ('rev_nondata')
 and load_dt_sk_id = vdt_id
 group by 1,2,3,5,6,7,8;





 --Total Revenue

delete from `data-bi-prd-935c.bi_dev`.ioh_snd_master_kpi_detail where dt_id = vdt_id and kpi in ('tot_rev') and brand ='3ID';




insert into `data-bi-prd-935c.bi_dev`.ioh_snd_master_kpi_detail
 select brand, level, level_value, 
 sum(values),
 time_flag,
 current_timestamp,
 'tot_rev',
 dt_id
 from `data-bi-prd-935c.bi_dev`.ioh_snd_master_kpi_detail
 where kpi in ('tot_rev_data', 'tot_rev_non_data') and brand = '3ID'
 and dt_id = vdt_id
 group by 1,2,3,5,6,7,8;
