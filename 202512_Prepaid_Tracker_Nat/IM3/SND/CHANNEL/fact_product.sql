declare vdt_id date default @vdt_id;
CREATE or replace TABLE `data-bi-prd-935c.bi_mart`.dim_product_map_mobo  as
select distinct ltrim(rtrim(product_name)) pkg_name,package_type_ng pkg_type,
package_category_ng pkg_category,family_ng pkg_family,
validity_package validity
from `data-dtp-prd-aa1a.smy`.rls_moboreff;
-- from coreprop.rls_moboreff;

CREATE or replace TABLE `data-bi-prd-935c.bi_mart`.dim_product_map_umb as
select distinct ltrim(rtrim(level_1)) pkg_name,sid rev_code,
package_type_ng pkg_type,
package_category_ng pkg_category,family_ng pkg_family,
validity_package validity
from `data-dtp-prd-aa1a.smy`.rls_organicreff;
-- from coreprop.rls_organicreff;


--DATA ADDON
delete from `data-bi-prd-935c.bi_mart`.fact_product where pkg_source = 'UMB' and dt_id = vdt_id;
insert into `data-bi-prd-935c.bi_mart`.fact_product
select msisdn,level_1 pkg_name,sum(data_rev) rev,sum(usg_hits) hits,rev_code,
dt_id,'UMB' pkg_source
from `data-bi-prd-935c.bi_mart`.data_addon_dly
where dt_id=vdt_id
and (data_rev>=10 or lower(level_1) like '%edu%promo%' or lower(level_1) like '%longlife%renewal%free%')
group by 1,2,5,6,7
union all
select msisdn,level_1 pkg_name,sum(voice_rev) rev,sum(usg_hits) hits,rev_code,
dt_id,'UMB' pkg_source
from `data-bi-prd-935c.bi_mart`.voice_addon_dly
where dt_id=vdt_id
and voice_rev>=10
group by 1,2,5,6,7
union all
select msisdn,level_1 pkg_name,sum(sms_rev) rev,sum(usg_hits) hits,rev_code,
dt_id,'UMB' pkg_source
from `data-bi-prd-935c.bi_mart`.sms_addon_dly
where dt_id=vdt_id
and sms_rev>=10
group by 1,2,5,6,7;

--SP MOBO REVENUE
delete from `data-bi-prd-935c.bi_mart`.fact_product where pkg_source = 'MOBO' and dt_id = vdt_id;
insert into `data-bi-prd-935c.bi_mart`.fact_product 
select b_msisdn,productname pkg_name,sum(amount_debit) rev,count(transactionid) hits,productname,
parse_date('%Y%m%d',revenue_date) dt_id,'MOBO' pkg_source
from `data-dtp-prd-aa1a.sor`.mobo_revenue
where parse_date('%Y%m%d',revenue_date)=vdt_id
and prc_dt = timestamp(vdt_id + interval 1 day) 
and substring(b_msisdn, 1,5) in ('62857','62858','62856','62815','62816','62855','62814')
group by 1,2,5,6,7;

--FDV MOBO REDEMPTION
delete from `data-bi-prd-935c.bi_mart`.fact_product where pkg_source = 'VOUCHER' and dt_id = vdt_id;
insert into `data-bi-prd-935c.bi_mart`.fact_product 
select concat('62',pm_red_msisdn) msisdn,mobo_inj_pack_name pkg_name,
sum(mobo_inj_sales_price) rev,count(pm_voucher_sn) hits,mobo_inj_pack_name,
date(transactiondate) dt_id,'VOUCHER' pkg_source
from `data-dtp-prd-aa1a.sor`.fdv_mobo_pm_join_match
where date(transactiondate)=vdt_id and pm_voucher_status='U'
and substring(concat('62',pm_red_msisdn), 1,5) in ('62857','62858','62856','62815','62816','62855','62814')
--and substr(case when substr(pm_red_msisdn,1,2)!='62' then concat('62',pm_red_msisdn) else pm_red_msisdn end,1,5) in ('62857','62858','62856','62815','62816','62855','62814')
group by 1,2,5,6,7;

--SP DATA REVENUE
delete from `data-bi-prd-935c.bi_mart`.fact_product where pkg_source = 'SPDATA' and dt_id = vdt_id;
insert into `data-bi-prd-935c.bi_mart`.fact_product 
select msisdn,case when service_class_id in ('653','654','655','656','657') or substr(service_class_id,1,4)='8000' then 'SP Data 2GB'
when service_class_id in ('681','682','683','684','685') or substr(service_class_id,1,4)='8001' then 'SP Data 8GB'
when service_class_id in ('686','687','688','689','690') or substr(service_class_id,1,4)='8002' then 'SP Data 16GB'
when service_class_id in ('694','695','696','697','698','714','715','716','717','718','735','736','737','738','739') or substr(service_class_id,1,4)='8123' then 'SP Data 3GB'
when service_class_id in ('699','700','701','702','703','719','720','721','722','723','740','741','742','743','744') or substr(service_class_id,1,4)='8124' then 'SP Data 9GB'
when service_class_id in ('704','705','706','707','708','724','725','726','727','728','745','746','747','748','749') or substr(service_class_id,1,4)='8125' then 'SP Data 20GB'
else 'OTHERS' end pkg_name,sum(cast(amount_debit as numeric)) rev,
count(msisdn) hits,case when service_class_id in ('653','654','655','656','657') or substr(service_class_id,1,4)='8000' then 'SP Data 2GB'
when service_class_id in ('681','682','683','684','685') or substr(service_class_id,1,4)='8001' then 'SP Data 8GB'
when service_class_id in ('686','687','688','689','690') or substr(service_class_id,1,4)='8002' then 'SP Data 16GB'
when service_class_id in ('694','695','696','697','698','714','715','716','717','718','735','736','737','738','739') or substr(service_class_id,1,4)='8123' then 'SP Data 3GB'
when service_class_id in ('699','700','701','702','703','719','720','721','722','723','740','741','742','743','744') or substr(service_class_id,1,4)='8124' then 'SP Data 9GB'
when service_class_id in ('704','705','706','707','708','724','725','726','727','728','745','746','747','748','749') or substr(service_class_id,1,4)='8125' then 'SP Data 20GB'
when service_class_id in ('729','730','731','732','733') then 'SP Data 6GB'
else 'OTHERS' end pkg_name,
date(revenue_date) dt_id,'SPDATA' pkg_source
from `data-dtp-prd-aa1a.sor`.sp_data_revenue
--from `data-bi-prd-935c.bi_mart`.sp_data_revenue
where date(revenue_date)=vdt_id
--and flag_source!='SP B2B'
group by 1,2,5,6,7;

--VOUCHER ORI REDEMPTION
delete from `data-bi-prd-935c.bi_mart`.fact_product where pkg_source = 'VOUORI' and dt_id = vdt_id;
insert into `data-bi-prd-935c.bi_mart`.fact_product 
select concat('62',pm_red_msisdn) msisdn,inj_pack_name pkg_name,
sum(inj_sales_price) rev,count(pm_voucher_sn) hits,inj_pack_name,
parse_date('%Y%m%d',transactiondate) dt_id,'VOUORI' pkg_source
from `data-dtp-prd-aa1a.smy`.smy_dv_redemption
--from `data-bi-prd-935c.bi_mart`.smy_dv_redemption
where parse_date('%Y%m%d',transactiondate)=vdt_id and pm_voucher_status='U'
and prc_dt = timestamp(vdt_id + interval 1 day)
group by 1,2,5,6,7;

-- --EDU PACK REVENUE
-- delete from `data-bi-prd-935c.bi_mart`.fact_product where pkg_source = 'API' and dt_id = vdt_id;
-- insert into `data-bi-prd-935c.bi_mart`.fact_product 
-- select msisdn,CASE WHEN package_code='KBB20GB' then 'Paket KBB PAUD'
-- WHEN package_code='KBB42GB' then 'Paket KBB GURU'
-- WHEN package_code='KBB35GB' then 'Paket KBB SISWA'
-- WHEN package_code='KBB50GB' then 'Paket KBB MAHASISWA-DOSEN' 
-- else package_code end pkg_name,
-- sum(amount) rev,count(msisdn) hits,package_code,
-- dt_id,'API' pkg_source
-- from `data-bi-prd-935c.bi_mart`.edu_usage_rev_dly
-- where dt_id=vdt_id
-- group by 1,2,5,6,7;

--SP DATA B2B REVENUE
delete from `data-bi-prd-935c.bi_mart`.fact_product where pkg_source = 'SPDATA B2B' and dt_id = vdt_id;
insert into `data-bi-prd-935c.bi_mart`.fact_product 
select msisdn,b.svc_class_name pkg_name,sum(cast(amount_debit as numeric)) rev,
count(msisdn) hits,service_class_id ,
date(revenue_date) dt_id,'SPDATA B2B' pkg_source
from `data-dtp-prd-aa1a.sor`.sp_data_revenue_b2b a
left join `data-bi-prd-935c.bi_mart`.ref_sc_b2b b on a.service_class_id=b.svc_class_code
where date(revenue_date)=vdt_id
group by 1,2,5,6,7;

--PGI & EWALLET
delete from `data-bi-prd-935c.bi_mart`.fact_product where pkg_source in ('MYIM3','EWALLET') and dt_id = vdt_id;
insert into `data-bi-prd-935c.bi_mart`.fact_product 
select msisdn,product_name,sum(rev) rev,count(1) hits,product_id,dt_id,
case when flag='PGI' then 'MYIM3' else flag end pkg_source
from `data-bi-prd-935c.bi_mart`.pgi_ewallet_site
where dt_id=vdt_id
group by 1,2,5,6,7;

delete from `data-bi-prd-935c.bi_mart`.fact_product_detail where dt_id = vdt_id;
insert into `data-bi-prd-935c.bi_mart`.fact_product_detail
select msisdn,level_1 pkg_name,'UMB DATA ADDON' pkg_source,data_rev/nullif(usg_hits,0) main_price,
sum(data_rev) rev,sum(usg_hits) hits,dt_id
from `data-bi-prd-935c.bi_mart`.data_addon_dly
where dt_id=vdt_id
and data_rev>=10
group by 1,2,3,4,7
union all
select msisdn,level_1 pkg_name,'UMB VOICE ADDON' pkg_source,voice_rev/nullif(usg_hits,0) main_price,
sum(voice_rev) rev,sum(usg_hits) hits,dt_id
from `data-bi-prd-935c.bi_mart`.voice_addon_dly
where dt_id=vdt_id
and voice_rev>=10
group by 1,2,3,4,7
union all
select msisdn,level_1 pkg_name,'UMB SMS ADDON' pkg_source,sms_rev/nullif(usg_hits,0) main_price,
sum(sms_rev) rev,sum(usg_hits) hits,dt_id
from `data-bi-prd-935c.bi_mart`.sms_addon_dly
where dt_id=vdt_id
and sms_rev>=10
group by 1,2,3,4,7
union all
select b_msisdn,productname pkg_name,'MOBO' pkg_source,cast(mainprice as numeric) main_price,
sum(cast(amount_debit as numeric)) rev,count(transactionid) hits,parse_date('%Y%m%d',revenue_date) dt_id
from `data-dtp-prd-aa1a.sor`.mobo_revenue
where parse_date('%Y%m%d',revenue_date)=vdt_id
and prc_dt = timestamp(vdt_id + interval 1 day) 
and substring(b_msisdn, 1,5) in ('62857','62858','62856','62815','62816','62855','62814')
group by 1,2,3,4,7
union all
select concat('62',pm_red_msisdn) msisdn,mobo_inj_pack_name pkg_name,'VOUCHER' pkg_source,
cast(mobo_inj_main_price as numeric) main_price,sum(mobo_inj_sales_price) rev,count(pm_voucher_sn) hits,date(transactiondate) dt_id
from `data-dtp-prd-aa1a.sor`.fdv_mobo_pm_join_match
where date(transactiondate)=vdt_id and pm_voucher_status='U'
and substring(concat('62',pm_red_msisdn), 1,5) in ('62857','62858','62856','62815','62816','62855','62814')
--and substr(case when substr(pm_red_msisdn,1,2)!='62' then concat('62',pm_red_msisdn) else pm_red_msisdn end,1,5) in ('62857','62858','62856','62815','62816','62855','62814')
group by 1,2,3,4,7
union all
select msisdn,case when service_class_id in ('653','654','655','656','657') or substr(service_class_id,1,4)='8000' then 'SP Data 2GB'
when service_class_id in ('681','682','683','684','685') or substr(service_class_id,1,4)='8001' then 'SP Data 8GB'
when service_class_id in ('686','687','688','689','690') or substr(service_class_id,1,4)='8002' then 'SP Data 16GB'
when service_class_id in ('694','695','696','697','698','714','715','716','717','718','735','736','737','738','739') or substr(service_class_id,1,4)='8123' then 'SP Data 3GB'
when service_class_id in ('699','700','701','702','703','719','720','721','722','723','740','741','742','743','744') or substr(service_class_id,1,4)='8124' then 'SP Data 9GB'
when service_class_id in ('704','705','706','707','708','724','725','726','727','728','745','746','747','748','749') or substr(service_class_id,1,4)='8125' then 'SP Data 20GB'
when service_class_id in ('729','730','731','732','733') then 'SP Data 6GB'
else 'OTHERS' end pkg_name,'SPDATA' pkg_source,cast(main_price as numeric) main_price,
sum(cast(amount_debit as numeric)) rev,count(msisdn) hits,date(revenue_date) dt_id
from `data-dtp-prd-aa1a.sor`.sp_data_revenue
where date(revenue_date)=vdt_id
group by 1,2,3,4,7
union all
select concat('62',pm_red_msisdn) msisdn,inj_pack_name pkg_name,'VOUORI' pkg_source,cast(inj_main_price as numeric) main_price,
sum(inj_sales_price) rev,count(pm_voucher_sn) hits,parse_date('%Y%m%d',transactiondate) dt_id
from `data-dtp-prd-aa1a.smy`.smy_dv_redemption
--from `data-bi-prd-935c.bi_mart`.smy_dv_redemption
where parse_date('%Y%m%d',transactiondate)=vdt_id and pm_voucher_status='U'
and prc_dt = timestamp(vdt_id + interval 1 day)
group by 1,2,3,4,7
union all
select msisdn,concat('RELOAD',cast(dnmn_val as string)),'RELOAD' pkg_name,dnmn_val,
sum(tot_rechrg_idr_val) rev,sum(tot_rechrg) hits,date(dt_id) dt_id from `data-dtp-prd-aa1a.smy`.cst_rechrg_dly_smy
where date(dt_id)=vdt_id and dnmn_val>0
group by 1,2,3,4,7;

delete from `data-bi-prd-935c.bi_mart`.fact_product_renew where dt_id = vdt_id;
insert into `data-bi-prd-935c.bi_mart`.fact_product_renew 
select count(a.msisdn) subs_renew,vdt_id dt_id
from (select msisdn
from `data-bi-prd-935c.bi_mart`.fact_product
where dt_id>=date_trunc(vdt_id,month)
and dt_id<=vdt_id group by 1) a
join (select msisdn from `data-bi-prd-935c.bi_mart`.fact_product
where dt_id between date_trunc(vdt_id - interval 1 month,month) and date_trunc(vdt_id,month) - interval 1 day
group by 1) b on a.msisdn=b.msisdn
group by 2;

delete from `data-bi-prd-935c.bi_mart`.fact_product_renew_30d where dt_id = vdt_id;
insert into `data-bi-prd-935c.bi_mart`.fact_product_renew_30d 
select count(a.msisdn) subs_renew_base,sum(case when a.msisdn=b.msisdn then 1 else 0 end) subs_renew,vdt_id dt_id
from (select msisdn from `data-bi-prd-935c.bi_mart`.fact_product
where dt_id>vdt_id - interval 60 day
and dt_id<=vdt_id - interval 30 day
group by 1) a
left join (select msisdn
from `data-bi-prd-935c.bi_mart`.fact_product
where dt_id>vdt_id - interval 30 day
and dt_id<=vdt_id group by 1) b on a.msisdn=b.msisdn
group by 3;

---------------------------------------------------------------------------------------------------------------------
---------------------------------------------------------------------------------------------------------------------

---OMN PRODUCT EXTENDED
--MOBO
delete from `data-bi-prd-935c.bi_mart`.fact_product_ext where dt_id = vdt_id and pkg_source = 'MOBO';
insert into `data-bi-prd-935c.bi_mart`.fact_product_ext 
select b_msisdn,productname pkg_name,sum(amount_debit) rev,count(transactionid) hits,productname,
case when lower(trim(a.productname))=lower(trim(e.product_name)) then upper(e.pkg_type)
when upper(a.productname) like 'FREEDOM INTERNET%4GB%' then 'Freedom Internet 3GB/4GB'
when upper(a.productname) like 'FREEDOM U%1GB%' then 'Freedom U 1GB'
when upper(a.productname) like 'FREEDOM U%2GB%' then 'Freedom U 2GB'
when upper(a.productname) like 'FREEDOM U%10GB%' then 'Freedom U 10GB'
else 'OTHERS' end pkg_type,
b.channel,
case when channel in ('Direct','Traditional') then 'Traditional'
else 'Non Traditional' end channel_grp,
c.site_id,flag_sp,
case when revenue_trigger='Y2' then 'NEW SP'
else 'OLD SP' end flag_grp,sum(mainprice) main_price,sum(discount) discount,
parse_date('%Y%m%d',revenue_date) dt_id,'MOBO' pkg_source
from `data-dtp-prd-aa1a.sor`.mobo_revenue a
left join (select channel,organization_id
from `data-bi-prd-935c.bi_mart`.org_salmo
where mth_id=date_trunc(vdt_id,month)) b on a.organizationid=b.organization_id
left join (select msisdn,a.site_id,region,
    area,sales_area,sales_cluster,micro_cluster
    from `data-bi-prd-935c.bi_mart`.all_90d_fav_loc_dly a
    --join (select * from `data-bi-prd-935c.bi_mart`.ref_site_mth
    --where month_id=date_trunc(vdt_id,month)) b on a.site_id=b.site_id
    join `data-bi-prd-935c.bi_mart`.ref_site b on a.site_id=b.site_id
    where dt_id=vdt_id) c on a.b_msisdn=c.msisdn 
left join (select case
			when a.svc_class_code='6521' then 'SP Pantura'
			when a.svc_class_code='652' then 'SP IM3 Cool 5K'
			when a.svc_class_code='637' then 'SP Zero'
			when a.svc_class_code in ('549','546') then 'SP 2K'
			when a.svc_class_code in ('653','654','655','656','657','8000') then 'SP Data 2GB'
			when a.svc_class_code in ('681','682','683','684','685','8001') then 'SP IM3 8GB'
			when a.svc_class_code in ('686','687','688','689','690','8002') then 'SP IM3 16GB'
      when a.svc_class_code in ('694','695','696','697','698','714','715','716','717','718','735','736','737','738','739') or substr(a.svc_class_code,1 ,4)='8123' then 'SP IM3 3GB'
      when a.svc_class_code in ('699','700','701','702','703','719','720','721','722','723','740','741','742','743','744') or substr(a.svc_class_code,1,4)='8124' then 'SP IM3 9GB'
      when a.svc_class_code in ('704','705','706','707','708','724','725','726','727','728','745','746','747','748','749') or substr(a.svc_class_code,1,4)='8125' then 'SP IM3 20GB'
      when a.svc_class_code in ('729','730','731','732','733') then 'SP IM3 6GB'
			when a.svc_class_code=b.svc_class_code then 'SP B2B'
			else 'Others'
end flag_sp,a.msisdn
from `data-dtp-prd-aa1a.smy`.ar_cst_dly_smy a
left join `data-bi-prd-935c.bi_mart`.ref_sc_b2b b
on a.svc_class_code=b.svc_class_code
where date(dt_id)=vdt_id) d on a.b_msisdn=d.msisdn
left join (select distinct product_name,package_type_ng pkg_type from `data-dtp-prd-aa1a.smy`.rls_moboreff/* coreprop.rls_moboreff*/) e
on lower(trim(a.productname))=lower(trim(e.product_name))
--where revenue_date between concat(date_trunc(vdt_id,month),'01') and vdt_id
where parse_date('%Y%m%d',revenue_date) = vdt_id
and a.prc_dt = timestamp(vdt_id + interval 1 day)
and substring(a.b_msisdn, 1,5) in ('62857','62858','62856','62815','62816','62855','62814')
group by 1,2,5,6,7,8,9,10,11,14,15;

--FDV
delete from `data-bi-prd-935c.bi_mart`.fact_product_ext where dt_id = vdt_id and pkg_source = 'VOUCHER';
insert into `data-bi-prd-935c.bi_mart`.fact_product_ext 
select concat('62',pm_red_msisdn) msisdn,mobo_inj_pack_name pkg_name,
sum(mobo_inj_sales_price) rev,count(pm_voucher_sn) hits,mobo_inj_pack_name,
case when lower(trim(a.mobo_inj_pack_name))=lower(trim(e.product_name)) then upper(e.pkg_type)
when upper(a.mobo_inj_pack_name) like 'FREEDOM INTERNET%4GB%' then 'Freedom Internet 3GB/4GB'
when upper(a.mobo_inj_pack_name) like 'FREEDOM U%1GB%' then 'Freedom U 1GB'
when upper(a.mobo_inj_pack_name) like 'FREEDOM U%2GB%' then 'Freedom U 2GB'
when upper(a.mobo_inj_pack_name) like 'FREEDOM U%10GB%' then 'Freedom U 10GB'
else 'OTHERS' end pkg_type,
b.channel,
case when channel in ('Direct','Traditional') then 'Traditional'
else 'Traditional' end channel_grp,
c.site_id,flag_sp,
'VOUCHER' flag_grp,sum(mobo_inj_main_price) main_price,sum(mobo_inj_disc_price) discount,
date(transactiondate) dt_id,'VOUCHER' pkg_source
from `data-dtp-prd-aa1a.sor`.fdv_mobo_pm_join_match a
left join (select channel,organization_id
from `data-bi-prd-935c.bi_mart`.org_salmo
where mth_id=date_trunc(vdt_id,month)) b on a.mobo_inj_outlet_id=b.organization_id
left join (select msisdn,a.site_id,region,
area,sales_area,sales_cluster,micro_cluster
from `data-bi-prd-935c.bi_mart`.all_90d_fav_loc_dly a
--join (select * from `data-bi-prd-935c.bi_mart`.ref_site_mth
--where month_id=date_trunc(vdt_id,month)) b on a.site_id=b.site_id
join `data-bi-prd-935c.bi_mart`.ref_site b on a.site_id=b.site_id
where dt_id=vdt_id) c on concat('62',a.pm_red_msisdn)=c.msisdn
left join (select case
			when a.svc_class_code='6521' then 'SP Pantura'
			when a.svc_class_code='652' then 'SP IM3 Cool 5K'
			when a.svc_class_code='637' then 'SP Zero'
			when a.svc_class_code in ('549','546') then 'SP 2K'
			when a.svc_class_code in ('653','654','655','656','657','8000') then 'SP Data 2GB'
			when a.svc_class_code in ('681','682','683','684','685','8001') then 'SP IM3 8GB'
			when a.svc_class_code in ('686','687','688','689','690','8002') then 'SP IM3 16GB'
      when a.svc_class_code in ('694','695','696','697','698','714','715','716','717','718','735','736','737','738','739') or substr(a.svc_class_code,1 ,4)='8123' then 'SP IM3 3GB'
      when a.svc_class_code in ('699','700','701','702','703','719','720','721','722','723','740','741','742','743','744') or substr(a.svc_class_code,1,4)='8124' then 'SP IM3 9GB'
      when a.svc_class_code in ('704','705','706','707','708','724','725','726','727','728','745','746','747','748','749') or substr(a.svc_class_code,1,4)='8125' then 'SP IM3 20GB'
      when a.svc_class_code in ('729','730','731','732','733') then 'SP IM3 6GB'
			when a.svc_class_code=b.svc_class_code then 'SP B2B'
			else 'Others'
end flag_sp,a.msisdn
from `data-dtp-prd-aa1a.smy`.ar_cst_dly_smy a
left join `data-bi-prd-935c.bi_mart`.ref_sc_b2b b
on a.svc_class_code=b.svc_class_code
where date(dt_id)=vdt_id) d on concat('62',a.pm_red_msisdn)=d.msisdn
left join (select distinct product_name,package_type_ng pkg_type from `data-dtp-prd-aa1a.smy`.rls_moboreff /*coreprop.rls_moboreff*/) e
on lower(trim(a.mobo_inj_pack_name))=lower(trim(e.product_name))
--where transactiondate between concat(date_trunc(vdt_id,month),'01') and vdt_id
where date(transactiondate) = vdt_id
and pm_voucher_status='U' and category='MOBO'
and substring(concat('62',pm_red_msisdn), 1,5) in ('62857','62858','62856','62815','62816','62855','62814')
--and substr(case when substr(a.pm_red_msisdn,1,2)!='62' then concat('62',a.pm_red_msisdn) else a.pm_red_msisdn end,1,5) in ('62857','62858','62856','62815','62816','62855','62814')
group by 1,2,5,6,7,8,9,10,11,14,15;

--SP Data
delete from `data-bi-prd-935c.bi_mart`.fact_product_ext where dt_id = vdt_id and pkg_source = 'SPDATA';
insert into `data-bi-prd-935c.bi_mart`.fact_product_ext 
select a.msisdn,case when service_class_id in ('653','654','655','656','657') or substr(service_class_id,1,4)='8000' then 'SP Data 2GB'
when service_class_id in ('681','682','683','684','685') or substr(service_class_id,1,4)='8001' then 'SP Data 8GB'
when service_class_id in ('686','687','688','689','690') or substr(service_class_id,1,4)='8002' then 'SP Data 16GB'
when service_class_id in ('694','695','696','697','698','714','715','716','717','718','735','736','737','738','739') or substr(service_class_id,1,4)='8123' then 'SP Data 3GB'
when service_class_id in ('699','700','701','702','703','719','720','721','722','723','740','741','742','743','744') or substr(service_class_id,1,4)='8124' then 'SP Data 9GB'
when service_class_id in ('704','705','706','707','708','724','725','726','727','728','745','746','747','748','749') or substr(service_class_id,1,4)='8125' then 'SP Data 20GB'
when service_class_id in ('729','730','731','732','733') then 'SP Data 6GB'
else 'OTHERS' end pkg_name,sum(cast(amount_debit as numeric)) rev,
count(a.msisdn) hits,case when service_class_id in ('653','654','655','656','657') or substr(service_class_id,1,4)='8000' then 'SP Data 2GB'
when service_class_id in ('681','682','683','684','685') or substr(service_class_id,1,4)='8001' then 'SP Data 8GB'
when service_class_id in ('686','687','688','689','690') or substr(service_class_id,1,4)='8002' then 'SP Data 16GB'
when service_class_id in ('694','695','696','697','698','714','715','716','717','718','735','736','737','738','739') or substr(service_class_id,1,4)='8123' then 'SP Data 3GB'
when service_class_id in ('699','700','701','702','703','719','720','721','722','723','740','741','742','743','744') or substr(service_class_id,1,4)='8124' then 'SP Data 9GB'
when service_class_id in ('704','705','706','707','708','724','725','726','727','728','745','746','747','748','749') or substr(service_class_id,1,4)='8125' then 'SP Data 20GB'
when service_class_id in ('729','730','731','732','733') then 'SP Data 6GB'
else 'OTHERS' end pkg_name,
'SP DATA' pkg_type,
b.channel,
case when channel in ('Direct','Traditional') then 'Traditional'
else 'Traditional' end channel_grp,
c.site_id,
case when service_class_id in ('653','654','655','656','657') or substr(service_class_id,1,4)='8000' then 'SP Data 2GB'
when service_class_id in ('681','682','683','684','685') or substr(service_class_id,1,4)='8001' then 'SP IM3 8GB'
when service_class_id in ('686','687','688','689','690') or substr(service_class_id,1,4)='8002' then 'SP IM3 16GB'
when service_class_id in ('694','695','696','697','698','714','715','716','717','718','735','736','737','738','739') or substr(service_class_id,1,4)='8123' then 'SP Data 3GB'
when service_class_id in ('699','700','701','702','703','719','720','721','722','723','740','741','742','743','744') or substr(service_class_id,1,4)='8124' then 'SP Data 9GB'
when service_class_id in ('704','705','706','707','708','724','725','726','727','728','745','746','747','748','749') or substr(service_class_id,1,4)='8125' then 'SP Data 20GB'
when service_class_id in ('729','730','731','732','733') then 'SP Data 6GB'
else 'OTHERS' end flag_sp,
'NEW SP' flag_grp,sum(cast(main_price as numeric)) main_price,sum(cast(discount as numeric)) discount,
date(revenue_date) dt_id,'SPDATA' pkg_source
from `data-dtp-prd-aa1a.sor`.sp_data_revenue a
left join 
(select case when program_name like 'SF%DAT%' then 'Direct' else 'Traditional' end channel,
msisdn
from `data-bi-prd-935c.bi_mart`.foss_sp_mth a
join `data-bi-prd-935c.bi_mart`.ref_sp_vou_ori b
on a.program_code=b.ext_product_id and a.dist_dt between b.start_dt and b.end_dt
where mth_id=date_trunc(vdt_id,month)) b on a.msisdn=b.msisdn
left join
(select msisdn,a.site_id,region,
area,sales_area,sales_cluster,micro_cluster
from `data-bi-prd-935c.bi_mart`.all_90d_fav_loc_dly a
--join (select * from `data-bi-prd-935c.bi_mart`.ref_site_mth
--where month_id=date_trunc(vdt_id,month)) b on a.site_id=b.site_id
join `data-bi-prd-935c.bi_mart`.ref_site b on a.site_id=b.site_id
where dt_id=vdt_id) c on a.msisdn=c.msisdn
--where revenue_date between concat(date_trunc(vdt_id,month),'01') and vdt_id
where date(revenue_date) = vdt_id
group by 1,2,5,6,7,8,9,10,11,14,15;

--Voucher Ori
delete from `data-bi-prd-935c.bi_mart`.fact_product_ext where dt_id = vdt_id and pkg_source = 'VOU ORI';
insert into `data-bi-prd-935c.bi_mart`.fact_product_ext 
select concat('62',pm_red_msisdn) msisdn,inj_pack_name pkg_name,
sum(a.inj_sales_price) rev,count(pm_voucher_sn) hits,a.inj_pack_name,
'VOU ORI' pkg_type,
'Traditional' channel,
'Traditional' channel_grp,
c.site_id,flag_sp,
'VOUCHER' flag_grp,sum(inj_main_price) main_price,sum(inj_disc_price) discount,
parse_date('%Y%m%d',transactiondate) dt_id,'VOU ORI' pkg_source
from `data-dtp-prd-aa1a.smy`.smy_dv_redemption a
--from `data-bi-prd-935c.bi_mart`.smy_dv_redemption a
left join (select channel,organization_id
from `data-bi-prd-935c.bi_mart`.org_salmo
where mth_id=date_trunc(vdt_id,month)) b on a.inj_outlet_id=b.organization_id
left join (select msisdn,a.site_id,region,
area,sales_area,sales_cluster,micro_cluster
from `data-bi-prd-935c.bi_mart`.all_90d_fav_loc_dly a
--join (select * from `data-bi-prd-935c.bi_mart`.ref_site_mth
--where month_id=date_trunc(vdt_id,month)) b on a.site_id=b.site_id
join `data-bi-prd-935c.bi_mart`.ref_site b on a.site_id=b.site_id
where dt_id=vdt_id) c on concat('62',a.pm_red_msisdn)=c.msisdn
left join (select case
			when a.svc_class_code='6521' then 'SP Pantura'
			when a.svc_class_code='652' then 'SP IM3 Cool 5K'
			when a.svc_class_code='637' then 'SP Zero'
			when a.svc_class_code in ('549','546') then 'SP 2K'
			when a.svc_class_code in ('653','654','655','656','657','8000') then 'SP Data 2GB'
			when a.svc_class_code in ('681','682','683','684','685','8001') then 'SP IM3 8GB'
			when a.svc_class_code in ('686','687','688','689','690','8002') then 'SP IM3 16GB'
      when a.svc_class_code in ('694','695','696','697','698','714','715','716','717','718','735','736','737','738','739') or substr(a.svc_class_code,1 ,4)='8123' then 'SP IM3 3GB'
      when a.svc_class_code in ('699','700','701','702','703','719','720','721','722','723','740','741','742','743','744') or substr(a.svc_class_code,1,4)='8124' then 'SP IM3 9GB'
      when a.svc_class_code in ('704','705','706','707','708','724','725','726','727','728','745','746','747','748','749') or substr(a.svc_class_code,1,4)='8125' then 'SP IM3 20GB'
      when a.svc_class_code in ('729','730','731','732','733') then 'SP IM3 6GB'
			when a.svc_class_code=b.svc_class_code then 'SP B2B'
			else 'Others'
end flag_sp,a.msisdn
from `data-dtp-prd-aa1a.smy`.ar_cst_dly_smy a
left join `data-bi-prd-935c.bi_mart`.ref_sc_b2b b
on a.svc_class_code=b.svc_class_code
where date(dt_id)=vdt_id) d on concat('62',a.pm_red_msisdn)=d.msisdn
--where transactiondate between concat(date_trunc(vdt_id,month),'01') and vdt_id
where parse_date('%Y%m%d',transactiondate) = vdt_id
and prc_dt = timestamp(vdt_id + interval 1 day)
and pm_voucher_status='U'
group by 1,2,5,6,7,8,9,10,11,14,15;



--INJECTION FDV DAILY
delete from `data-bi-prd-935c.bi_mart`.fact_product_inj where dt_id = vdt_id and pkg_source = 'VOUCHER';
insert into `data-bi-prd-935c.bi_mart`.fact_product_inj 
select a.b_msisdn msisdn,a.organization_id,a.product_name pkg_name,a.product_name,
case when lower(trim(a.product_name))=lower(trim(e.product_name)) then upper(e.pkg_type)
when upper(a.product_name) like 'FREEDOM INTERNET%4GB%' then 'Freedom Internet 3GB/4GB'
when upper(a.product_name) like 'FREEDOM U%1GB%' then 'Freedom U 1GB'
when upper(a.product_name) like 'FREEDOM U%2GB%' then 'Freedom U 2GB'
when upper(a.product_name) like 'FREEDOM U%10GB%' then 'Freedom U 10GB'
else 'OTHERS' end pkg_type,
a.channel,
case when a.channel in ('Direct','Traditional') then 'Traditional'
else 'Traditional' end channel_grp,
c.site_id,'FDV' flag_sp,
'VOUCHER' flag_grp,
sum(a.amount_debit) amount_debit,count(a.transaction_id) hits,
a.dt_id,'VOUCHER' pkg_source
from `data-bi-prd-935c.bi_mart`.sellout_salmo_dly a
left join
(select * from
(select site_id,area,sales_area,sales_cluster,micro_cluster,organization_id,organization_name,
ROW_NUMBER() OVER (partition by organization_id ORDER BY dt_id desc) AS rn
from `data-bi-prd-935c.bi_mart`.outlet_loc_ns
where dt_id between date_trunc(vdt_id,month) and vdt_id) a
where rn=1) c on a.organization_id=c.organization_id
left join (select distinct product_name,package_type_ng pkg_type from `data-dtp-prd-aa1a.smy`.rls_moboreff /*coreprop.rls_moboreff*/) e
on lower(trim(a.product_name))=lower(trim(e.product_name))
where dt_id=vdt_id and upper(a.transaction_type) like '%VOU%'
group by 1,2,3,4,5,6,7,8,9,10,13,14
;

--INJECTION SELLIN SP DATA
delete from `data-bi-prd-935c.bi_mart`.fact_product_inj where dt_id = vdt_id and pkg_source = 'SP DATA';
insert into `data-bi-prd-935c.bi_mart`.fact_product_inj 
select a.msisdn,a.organization_id,
case when upper(a.product_name) like '%2GB%' then 'SP Data 2GB'
when upper(a.product_name) like '%8GB%' then 'SP Data 8GB'
when upper(a.product_name) like '%16GB%' then 'SP Data 16GB'
when upper(a.product_name) like '%3GB%' then 'SP Data 3GB'
when upper(a.product_name) like '%9GB%' then 'SP Data 9GB'
when upper(a.product_name) like '%20GB%' then 'SP Data 20GB'
when upper(a.product_name) like '%6GB%' then 'SP Data 6GB'
else 'OTHERS' end pkg_name,
case when upper(a.product_name) like '%2GB%' then 'SP Data 2GB'
when upper(a.product_name) like '%8GB%' then 'SP Data 8GB'
when upper(a.product_name) like '%16GB%' then 'SP Data 16GB'
when upper(a.product_name) like '%3GB%' then 'SP Data 3GB'
when upper(a.product_name) like '%9GB%' then 'SP Data 9GB'
when upper(a.product_name) like '%20GB%' then 'SP Data 20GB'
when upper(a.product_name) like '%6GB%' then 'SP Data 6GB'
else 'OTHERS' end product_name,'SP DATA' pkg_type,
case when upper(a.product_name) like 'SF%' then 'Direct' else 'Traditional' end channel,
'Traditional' channel_grp,
c.site_id,
case when upper(a.product_name) like '%2GB%' then 'SP Data 2GB'
when upper(a.product_name) like '%8GB%' then 'SP IM3 8GB'
when upper(a.product_name) like '%16GB%' then 'SP IM3 16GB'
else 'OTHERS' end flag_sp,
'NEW SP' flag_grp,
sum(a.amount) amount_debit,count(a.msisdn) hits,
a.dt_sellin dt_id,'SP DATA' pkg_source
from `data-bi-prd-935c.bi_mart`.foss_sp_data_sellin_mth a
left join
(select * from
(select site_id,area,sales_area,sales_cluster,micro_cluster,organization_id,organization_name,
ROW_NUMBER() OVER (partition by organization_id ORDER BY dt_id desc) AS rn
from `data-bi-prd-935c.bi_mart`.outlet_loc_ns
where dt_id between date_trunc(vdt_id,month) and vdt_id) a
where rn=1) c
on a.organization_id=c.organization_id
where mth_id=date_trunc(vdt_id,month) and dt_sellin=vdt_id
group by 1,2,3,4,5,6,7,8,9,10,13,14;

--INJECTION SELLIN VO ORI
delete from `data-bi-prd-935c.bi_mart`.fact_product_inj where dt_id = vdt_id and pkg_source = 'VOU ORI';
insert into `data-bi-prd-935c.bi_mart`.fact_product_inj 
select a.sno,a.organization_id,
'VOUCORI FI2.5GB/5D' pkg_name,a.product_name,
'VOU ORI' pkg_type,
'Traditional' channel,
'Traditional' channel_grp,
c.site_id,'VOUCHER' flag_sp,
'VOUCHER' flag_grp,
sum(a.amount) amount_debit,count(a.sno) hits,
a.dt_sellin dt_id,'VOU ORI' pkg_source
from `data-bi-prd-935c.bi_mart`.foss_vo_ori_sellin_mth a
left join
(select * from
(select site_id,area,sales_area,sales_cluster,micro_cluster,organization_id,organization_name,
ROW_NUMBER() OVER (partition by organization_id ORDER BY dt_id desc) AS rn
from `data-bi-prd-935c.bi_mart`.outlet_loc_ns
where dt_id between date_trunc(vdt_id,month) and vdt_id) a
where rn=1) c
on a.organization_id=c.organization_id
where mth_id=date_trunc(vdt_id,month) and dt_sellin=vdt_id
group by 1,2,3,4,5,6,7,8,9,10,13,14;

--INJECTION SP MOBO DAILY 
delete from `data-bi-prd-935c.bi_mart`.fact_product_inj where dt_id = vdt_id and pkg_source = 'MOBO';
insert into `data-bi-prd-935c.bi_mart`.fact_product_inj 
select a.b_msisdn msisdn,a.organization_id,a.product_name pkg_name,a.product_name,
case when lower(trim(a.product_name))=lower(trim(e.product_name)) then upper(e.pkg_type)
when upper(a.product_name) like 'FREEDOM INTERNET%4GB%' then 'Freedom Internet 3GB/4GB'
when upper(a.product_name) like 'FREEDOM U%1GB%' then 'Freedom U 1GB'
when upper(a.product_name) like 'FREEDOM U%2GB%' then 'Freedom U 2GB'
when upper(a.product_name) like 'FREEDOM U%10GB%' then 'Freedom U 10GB'
else 'OTHERS' end pkg_type,
a.channel,
case when a.channel in ('Direct','Traditional') then 'Traditional'
else 'Non Traditional' end channel_grp,
c.site_id,flag_sp,
case when a.transaction_id=b.transactionid and upper(revenue_trigger)='Y2' then 'NEW SP' 
when a.transaction_id=b.transactionid then 'OLD SP'
else 'NEW SP' end flag_grp,
sum(a.amount_debit) amount_debit,count(a.transaction_id) hits,
a.dt_id,'MOBO' pkg_source
from `data-bi-prd-935c.bi_mart`.sellout_salmo_dly a
left join (select revenue_trigger,transactionid from `data-dtp-prd-aa1a.sor`.mobo_revenue
where parse_date('%Y%m%d',revenue_date) =vdt_id
and prc_dt = timestamp(vdt_id + interval 1 day) 
and substring(b_msisdn, 1,5) in ('62857','62858','62856','62815','62816','62855','62814')
group by 1,2) b on a.transaction_id=b.transactionid
left join
(select * from
(select site_id,area,sales_area,sales_cluster,micro_cluster,organization_id,organization_name,
ROW_NUMBER() OVER (partition by organization_id ORDER BY dt_id desc) AS rn
from `data-bi-prd-935c.bi_mart`.outlet_loc_ns
where dt_id between date_trunc(vdt_id,month) and vdt_id) a
where rn=1) c on a.organization_id=c.organization_id
left join (select case when a.svc_class_code='6521' then 'SP Pantura'
			when a.svc_class_code='652' then 'SP IM3 Cool 5K'
			when a.svc_class_code='637' then 'SP Zero'
			when a.svc_class_code in ('549','546') then 'SP 2K'
			when a.svc_class_code in ('653','654','655','656','657','8000') then 'SP Data 2GB'
			when a.svc_class_code in ('681','682','683','684','685','8001') then 'SP IM3 8GB'
			when a.svc_class_code in ('686','687','688','689','690','8002') then 'SP IM3 16GB'
      when a.svc_class_code in ('694','695','696','697','698','714','715','716','717','718','735','736','737','738','739') or substr(a.svc_class_code,1 ,4)='8123' then 'SP IM3 3GB'
      when a.svc_class_code in ('699','700','701','702','703','719','720','721','722','723','740','741','742','743','744') or substr(a.svc_class_code,1,4)='8124' then 'SP IM3 9GB'
      when a.svc_class_code in ('704','705','706','707','708','724','725','726','727','728','745','746','747','748','749') or substr(a.svc_class_code,1,4)='8125' then 'SP IM3 20GB'
      when a.svc_class_code in ('729','730','731','732','733') then 'SP IM3 6GB'
			when a.svc_class_code=b.svc_class_code then 'SP B2B'
			else 'Others'
end flag_sp,msisdn from `data-dtp-prd-aa1a.smy`.ar_cst_dly_smy a
left join `data-bi-prd-935c.bi_mart`.ref_sc_b2b b
on a.svc_class_code=b.svc_class_code
where date(dt_id)=vdt_id) d on a.b_msisdn=d.msisdn
left join (select distinct product_name,package_type_ng pkg_type from `data-dtp-prd-aa1a.smy`.rls_moboreff /*coreprop.rls_moboreff*/) e
on lower(trim(a.product_name))=lower(trim(e.product_name))
where dt_id=vdt_id and upper(a.transaction_type) like '%PACK%'
group by 1,2,3,4,5,6,7,8,9,10,13,14
;
