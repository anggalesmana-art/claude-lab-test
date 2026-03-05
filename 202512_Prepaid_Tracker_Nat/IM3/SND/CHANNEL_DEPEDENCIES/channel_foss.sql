declare vdt_id date default @vdt_id;
declare vdt_mth date default date_trunc(vdt_id,month);
--FOSS SP
delete from `data-bi-prd-935c.bi_mart`.foss_sp_mth where mth_id = vdt_mth;
insert into `data-bi-prd-935c.bi_mart`.foss_sp_mth 
select iccid,msisdn,imsi,po_number,dealer,brand_code,case when length(exp_dt)=8 then parse_date('%Y%m%d',exp_dt) else parse_date('%d-%m-%Y',exp_dt) end exp_dt,
parse_date('%Y%m%d',dist_dt) dist_dt,program_code,program_name,parse_date('%Y%m%d',alloc_pymt_dt) alloc_pymt_dt, date(dt_id) dt_id ,vdt_mth mth_id
from (
  select iccid,msisdn,imsi,po_number,dealer,brand_code,exp_dt,dist_dt,program_code,program_name,alloc_pymt_dt,dt_id,
    ROW_NUMBER() OVER (partition by msisdn ORDER BY dt_id desc) AS rn
  from `data-dtp-prd-aa1a.stg.stg_sis_foss_sp_dist`
  --where date(dt_id) between date_trunc(vdt_mth - interval 24 month,month) and vdt_id
  -- change period 6 month disamakan dengan source impala by panji
  where date(dt_id) between date_sub(vdt_id,interval 25 month) and vdt_id
) a
where rn=1;

--- FOSS SP Sellin (added channel at 20230112)
-- update 202308 full outer join mobii_msisdn_mth with reference
delete from `data-bi-prd-935c.bi_mart`.foss_sp_data_sellin_mth where mth_id = vdt_mth;
insert into `data-bi-prd-935c.bi_mart`.foss_sp_data_sellin_mth
select coalesce(a.msisdn,b.msisdn) as msisdn
  , coalesce(a.program_code,b.product_code) as product_code
  , coalesce(a.program_name,b.product_name) as product_name
  , coalesce(a.main_price,b.price) price
  , coalesce(b.price,a.amount) amount
  , coalesce(a.dealer,b.saldomobo_id) saldomobo_id
  , coalesce(b.destination,a.dealer) organization_id
  , b.expired_date
  , a.dt_foss
  , b.dt_sellin
  , b.channel
  , b.operator_id
  , b.operator_name
  , coalesce(a.main_price,b.price) main_price
  , vdt_mth mth_id
from
(
  select msisdn, dealer, program_code, program_name, gross_amt as amount, gross_price_perunit as main_price, dt_id dt_foss,po_number
  from `data-bi-prd-935c.bi_mart`.foss_sp_mth a
  join 
  (
      select distinct
      sales_order, round(safe_cast(gross_price_perunit as numeric),0) gross_price_perunit, 
      round((safe_cast(net_sales_perunit as numeric)*1.11),0) gross_amt
      from `data-dtp-prd-aa1a.stg.reference_zero`
      --where date(dt_id) between vdt_mth and vdt_id
      where date_trunc(date(dt_id),month) = vdt_mth
  ) b
   on SPLIT(a.po_number, '/')[ORDINAL(3)]  = b.sales_order
  where mth_id = vdt_mth
) a
--left join
full outer join --update 202504
(
  select msisdn, product_code, a.product_name, price, saldomobo_id, destination, expired_date, dt_id dt_sellin, channel,operator_id, operator_name
  from `data-bi-prd-935c.bi_mart`.mobii_msisdn_mth a
where month_id  = vdt_mth
) b
  on a.msisdn=b.msisdn-- and b.dt_sellin>=a.dt_foss
;

--- FOSS Voucher Original
delete from `data-bi-prd-935c.bi_mart`.foss_vo_mth where mth_id = vdt_mth ;
insert into `data-bi-prd-935c.bi_mart`.foss_vo_mth 
select sno,po_number,dealer,brand_code,safe.parse_date('%Y%m%d',exp_dt) exp_dt,program_code,program_name,safe.parse_date('%Y%m%d',alloc_pymt_dt) alloc_pymt_dt ,date(dt_id) dt_id,vdt_mth mth_id
from (
  select sno,po_number,dealer_id dealer,brand_code,exp_dt,program_code,program_name,alloc_pymt_dt,dt_id,
    ROW_NUMBER() OVER (partition by sno ORDER BY dt_id desc) AS rn
  from `data-dtp-prd-aa1a.stg`.stg_sis_foss_vo_dist
  --where date(dt_id)>=date(vdt_mth - interval 25 month)
  -- change period 6 month disamakan dengan source impala by panji
  where date(dt_id) between date_sub(vdt_id,interval 6 month) and vdt_id
) a
where rn=1;

--- FOSS Voucher Original Sellin
delete from `data-bi-prd-935c.bi_mart`.foss_vo_ori_sellin_mth where mth_id = vdt_mth;
insert into `data-bi-prd-935c.bi_mart`.foss_vo_ori_sellin_mth 
select coalesce(a.sno,b.serial_number) as sno
  , coalesce(a.program_code,b.product_code) as product_code
  , coalesce(a.program_name,b.product_name) as product_name
  , coalesce(a.main_price,b.price) price
  , coalesce(b.price,a.amount) amount
  , coalesce(a.dealer,b.saldomobo_id) saldomobo_id
  , coalesce(b.destination,a.dealer) organization_id
  , b.expired_date
  , a.dt_foss
  , b.dt_sellin
  , b.operator_id
  , b.operator_name
  , coalesce(a.main_price,b.price) main_price
  , vdt_mth mth_id
from
(
  select sno, dealer, program_code, program_name, gross_amt as amount, gross_price_perunit as main_price, dt_id dt_foss
  from `data-bi-prd-935c.bi_mart`.foss_vo_mth a
  join
  (
    select distinct
        sales_order, round(safe_cast(gross_price_perunit as numeric),0) gross_price_perunit, round((safe_cast(net_sales_perunit as numeric)*1.11),0) gross_amt
        from `data-dtp-prd-aa1a.stg.reference_zero`
        --where date(dt_id) between vdt_mth and vdt_id
        where date_trunc(date(dt_id),month) = vdt_mth
  ) b
    on SPLIT(a.po_number, '/')[ORDINAL(3)]  = b.sales_order
  where mth_id = vdt_mth
) a
--left join
full outer join --202504
(
  select serial_number, product_code, a.product_name, price, saldomobo_id, destination, expired_date, dt_id dt_sellin,operator_id, operator_name, 
  from `data-bi-prd-935c.bi_mart`.mobii_msisdn_vo_mth a
  where month_id = vdt_mth
) b
  on a.sno=b.serial_number-- and b.dt_sellin>=a.dt_foss
;

delete from `data-bi-prd-935c.bi_mart`.foss_dealer_mth  where mth_id = vdt_mth ;
insert into `data-bi-prd-935c.bi_mart`.foss_dealer_mth 
select dealer_code, organization_parent_id, organization_mobii_id, organization_id, organization_name, channel
  , organization_type, organization_category, latitude, longitude
  , region, area, sales_area
  , case when territoryid='EB-BNA-TIMOR' then 'EB-BNA-KUPANG'
		when territoryid='EB-EJA-BANYUWANGI SITUBONDO' then 'EB-EEJ-BANYUWANGI SITUBONDO'
		when territoryid='EB-EJA-BLITAR' then 'EB-EEJ-BLITAR'
		when territoryid='EB-EJA-BOJONEGORO' then 'EB-WEJ-BOJONEGORO'
		when territoryid='EB-EJA-GRESIK' then 'EB-WEJ-GRESIK'
		when territoryid='EB-EJA-JEMBER BONDOWOSO' then 'EB-EEJ-JEMBER BONDOWOSO'
		when territoryid='EB-EJA-JOMBANG NGANJUK' then 'EB-WEJ-JOMBANG NGANJUK'
		when territoryid='EB-EJA-KEDIRI' then 'EB-EEJ-KEDIRI'
		when territoryid='EB-EJA-LAMONGAN' then 'EB-WEJ-LAMONGAN'
		when territoryid='EB-EJA-MADIUN' then 'EB-WEJ-MADIUN'
		when territoryid='EB-EJA-MADURA' then 'EB-WEJ-MADURA'
		when territoryid='EB-EJA-MALANG RAYA' then 'EB-EEJ-MALANG RAYA'
		when territoryid='EB-EJA-MOJOKERTO' then 'EB-WEJ-MOJOKERTO'
		when territoryid='EB-EJA-PANDAAN PASURUAN' then 'EB-EEJ-PANDAAN PASURUAN'
		when territoryid='EB-EJA-PONOROGO' then 'EB-WEJ-PONOROGO'
		when territoryid='EB-EJA-PROBOLINGGO' then 'EB-EEJ-PROBOLINGGO'
		when territoryid='EB-EJA-SIDOARJO' then 'EB-EEJ-SIDOARJO'
		when territoryid='EB-EJA-SURABAYA BARSEL' then 'EB-WEJ-SURABAYA BARSEL'
		when territoryid='EB-EJA-SURABAYA TIMUT' then 'EB-WEJ-SURABAYA TIMUT'
		when territoryid='EB-EJA-TUBAN' then 'EB-WEJ-TUBAN'
		when territoryid='EB-EJA-TULUNGAGUNG' then 'EB-EEJ-TULUNGAGUNG'
		when territoryid='JB-EBO-BGR_A' then 'JB-EBO-BOGOR'
		when territoryid='JB-EBO-BKS BARAT' then 'JB-EBO-WEST BEKASI'
		when territoryid='JB-EBO-BKS SELATAN' then 'JB-EBO-SOUTH BEKASI'
		when territoryid='JB-EBO-BKS TIMUR' then 'JB-EBO-EAST BEKASI'
		when territoryid='JB-EBO-CIKARANG SELATAN' then 'JB-EBO-SOUTH CIKARANG'
		when territoryid='JB-EBO-CIKARANG UTARA' then 'JB-EBO-NORTH CIKARANG'
		when territoryid='JB-JAK-JAKARTA BARAT' then 'JB-JAK-WEST JAKARTA'
		when territoryid='JB-JAK-JAKARTA PUSAT' then 'JB-JAK-CENTRAL JAKARTA'
		when territoryid='JB-JAK-JAKARTA SELATAN' then 'JB-JAK-SOUTH JAKARTA'
		when territoryid='JB-JAK-JAKARTA TIMUR' then 'JB-JAK-EAST JAKARTA'
		when territoryid='JB-JAK-JAKARTA UTARA' then 'JB-JAK-NORTH JAKARTA'
		when territoryid='CW-CJA-BANYUMAS' then 'CW-SCJ-BANYUMAS'
		when territoryid='CW-CJA-SOLOSUKO' then 'CW-SCJ-SOLOSUKO'
		when territoryid='CW-CJA-TEBES' then 'CW-NCJ-TEBES'
		when territoryid='EB-EJA-BANYUWANGI SITUBONDO' then 'EB-EEJ-BANYUWANGI SITUBONDO'
		when territoryid='EB-EJA-PANDAAN PASURUAN' then 'EB-EEJ-PANDAAN PASURUAN'
		when territoryid='EB-EJA-TUBAN' then 'EB-WEJ-TUBAN'
		when territoryid='JB-BOT-CISARUA' then 'JB-EBO-CISARUA'
		when territoryid='JB-BOT-SUKABUMI' then 'JB-WBO-SUKABUMI'
		when territoryid='JB-BOT-WEST RENGASDENGKLOK' then 'JB-EBO-WEST RENGASDENGKLOK'
		when territoryid='JB-BOT-EAST RENGASDENGKLOK' then 'JB-EBO-EAST RENGASDENGKLOK'
		when territoryid='CW-CJA-BLOREMPATIGRO' then 'CW-NCJ-BLOREMPATIGRO'
		when territoryid='JB-BOT-KRONJO BALARAJA' then 'JB-WBO-BALARAJA'
		when territoryid='S-NSA-PEKANBARU INNER' then 'S-CSA-PEKANBARU INNER'
		when territoryid='S-NSA-PEKANBARU OUTER' then 'S-CSA-PEKANBARU OUTER'
		else sales_cluster end sales_cluster
  , register_dt, approval_dt, organization_status, territoryid
  , timestamp(current_datetime('+7')) ppn_dttm
  , dt_id
  , vdt_mth mth_id
from
(
  select x.*, row_number() over(partition by dealer_code, organization_id--, organization_parent_id, organization_mobii_id  
  order by dt_id desc) as rk
  from
  (
    select a.dealer_code,organization_parent_id,organization_mobii_id,
    organization_id,organization_name,channel,organization_type,organization_category,latitude,longitude,
    region,area,sales_area,sales_cluster,
    register_dt,approval_dt,organization_status,territoryid,timestamp(current_datetime('+7')) ppn_dttm,dt_id,vdt_mth mth_id
    from `data-bi-prd-935c.bi_mart`.ref_foss_dealer a
    left join (select region,area,sales_area,sales_cluster from `data-bi-prd-935c.bi_mart`.ref_site group by 1,2,3,4) b 
    on a.territoryid=b.sales_cluster
    union all
    select * from `data-bi-prd-935c.bi_mart`.foss_dealer_mth
    where mth_id=vdt_mth-interval 1 month
    and territoryid  not in ('CW-NCJ-SEMAROUT')
  ) x
)x
where rk=1
;

--SP Ori Modern Allocation 202306

delete from `data-bi-prd-935c.bi_mart`.foss_sp_data_modern_mth where mth_id = vdt_mth ;
insert into `data-bi-prd-935c.bi_mart`.foss_sp_data_modern_mth 
select msisdn, a.po_number, a.program_code, a.program_name, a.dealer, a.exp_dt, a.dist_dt, amount, dt_id, vdt_mth mth_id
  from `data-bi-prd-935c.bi_mart`.foss_sp_mth a
  join
  (
    select ext_product_id, product_name, amount, start_dt, end_dt
    from `data-bi-prd-935c.bi_mart`.ref_sp_vou_ori
    --where start_dt <= vdt_id and end_dt >= vdt_id
  ) b
    on a.program_code=b.ext_product_id
  where mth_id = vdt_mth and lower(a.program_name) like '%modern%' and a.dist_dt between start_dt and end_dt
;

  
--drop table if exists `data-bi-prd-935c.bi_mart`.hg_tmp_foss_dealear_{{ vdt_id }};

--SP DATA Tagging 20230725
--Temporary table for Traditional & Direct Tagging (GA Channel Logic Stamping) 20230725
create or replace table `data-bi-prd-935c.bi_stg`.tmp_sp_data_{{ vdt_id }}_orgid as
select sp_tag_msisdn msisdn
  , case
    when org_type='Gadget Shop' then org_type
    when regexp_contains(org_id,"^[0-9]+$")=False then 'Direct'
    else 'Traditional' end channel
  , org_id organization_id
  , 'SP TAG' flag_tagging
  , dt_id
  , 2 flag
from `data-bi-prd-935c.bi_mart`.sp_tag_outlet_mth
where month_id=vdt_mth and ifnull(org_id,'')!=''
and dt_id between vdt_mth - interval 3 month
and vdt_id
union all
--- DSF Sellout
select msisdn, 'Direct' Channel, destination,'SELLOUT' flag_tagging, dt_id, 3 flag
from `data-bi-prd-935c.bi_mart`.mobii_msisdn_sellout_mth
where month_id=vdt_mth and regexp_contains(destination,"^[0-9]+$")=False
and dt_id between vdt_mth - interval 3 month and vdt_id
union all
--- Traditional Sellin
select msisdn, channel, organization_id,'SELLIN' flag_tagging, dt_sellin dt_id, 4 flag
from `data-bi-prd-935c.bi_mart`.foss_sp_data_sellin_mth
where mth_id=vdt_mth and ifnull(organization_id,'')!=''
union all
--- immi sellout Promotor (added at 20230111)
select msisdn, sales_type channel, promoter_org_id, 'STOCK OUT' flag_tagging, dt_id, 1 flag
from `data-bi-prd-935c.bi_mart`.immi_sellout_mth
where mth_id=vdt_mth and ifnull(promoter_org_id,'')!=''
and dt_id between vdt_mth - interval 3 month
and vdt_id
and sales_type='Promotor'
union all
--- immi sellout Direct (added at 20230111)
select msisdn, sales_type channel, promoter_org_id, 'STOCK OUT' flag_tagging, dt_id, 1 flag
from `data-bi-prd-935c.bi_mart`.immi_sellout_mth
where mth_id=vdt_mth and ifnull(promoter_org_id,'')!=''
and dt_id between vdt_mth - interval 1 month
and vdt_id
and sales_type='Direct'
;

--SP Data Sellin & Tagging All Channel 20230725
delete from `data-bi-prd-935c.bi_mart`.foss_sp_data_sellin_tag_mth where mth_id = vdt_mth ;
insert into `data-bi-prd-935c.bi_mart`.foss_sp_data_sellin_tag_mth 
select a.msisdn,a.product_code,a.product_name,cast(a.price as numeric) price,cast(a.amount as numeric) amount,coalesce(b.dealer,a.saldomobo_id) saldomobo_id,
coalesce(b.dealer,a.organization_id) organization_id,a.expired_date,a.dt_foss,a.dt_sellin,coalesce(b.channel,a.channel) channel,
a.flag_tagging,a.dt_tagging,a.mth_id
from
(select a.msisdn,a.product_code,a.product_name,a.price,a.amount,a.saldomobo_id,coalesce(b.organization_id,a.organization_id) organization_id,
a.expired_date,a.dt_foss,a.dt_sellin,coalesce(b.channel,a.channel) channel,b.flag_tagging,b.dt_id dt_tagging,a.mth_id,
row_number() over(partition by a.msisdn order by b.flag, b.dt_id desc nulls last) as rk
from `data-bi-prd-935c.bi_mart`.foss_sp_data_sellin_mth a
left join `data-bi-prd-935c.bi_stg`.tmp_sp_data_{{ vdt_id }}_orgid b
    on a.msisdn=b.msisdn
where mth_id=vdt_mth) a
left join
(   select msisdn,dealer,'Modern' channel,dist_dt
    from `data-bi-prd-935c.bi_mart`.foss_sp_data_modern_mth
    where mth_id=vdt_mth
) b on a.msisdn=b.msisdn
where rk=1;

drop table if exists `data-bi-prd-935c.bi_stg`.tmp_sp_data_{{ vdt_id }}_orgid;