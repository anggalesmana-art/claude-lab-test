declare vdt_id date default @vdt_id;

--- MAP GW Reload
create or replace table `data-bi-prd-935c.bi_stg`.tmp_rgs_ga_channel_rld_mapgw_{{ vdt_id }}_nogovt as
select dt_id, msisdn, dnmn_val
from
(
	select date(dt_id) dt_id, concat('62',msisdn) msisdn, rld_amt/100 dnmn_val, row_number() over(partition by msisdn order by origin_timestamp nulls last) as rk
    from `data-dtp-prd-aa1a.stg`.stg_map_gw_rechrg
    where date_trunc(date(dt_id),month) = date_trunc(vdt_id,month) and (rld_amt/100)>=5000
        and upper(reload_channel) not in ('SALDOMOBO','PPSR')
        and lower(reload_channel) not like '%ngssp%'
        and concat('62',msisdn) in (select msisdn from `data-bi-prd-935c.bi_mart`.rgs_all_nogovt_dly where date_trunc(dt_id,month) = date_trunc(vdt_id,month) and flag like '%B%')
) x
where rk=1
;

--- FDV Reload
create or replace table `data-bi-prd-935c.bi_stg`.tmp_rgs_ga_channel_rld_fdv_{{ vdt_id }}_nogovt as
select dt_id, msisdn, dnmn_val
from
(
	select date(transactiondate) dt_id, case when substr(pm_red_msisdn,1,2)!='62' then concat('62',pm_red_msisdn) else pm_red_msisdn end msisdn, mobo_inj_sales_price dnmn_val
		, row_number() over(partition by case when substr(pm_red_msisdn,1,2)!='62' then concat('62',pm_red_msisdn) else pm_red_msisdn end order by transactiondate nulls last, mobo_inj_sales_price desc nulls last) rk
	from `data-dtp-prd-aa1a.sor`.fdv_mobo_pm_join_match_reload
	where pm_voucher_status='U'
		and date_trunc(date(transactiondate),month) = date_trunc(vdt_id,month)
		and category = 'MOBO'
		and mobo_inj_sales_price>=5000
		and concat('62',pm_red_msisdn) in (select msisdn from `data-bi-prd-935c.bi_mart`.rgs_all_nogovt_dly where date_trunc(dt_id,month) = date_trunc(vdt_id,month) and flag like '%B%')
) x
where rk=1
;

--- Union Reload
create or replace table `data-bi-prd-935c.bi_stg`.tmp_rgs_ga_channel_rld_{{ vdt_id }}_nogovt as
select dt_id, msisdn, dnmn_val
from
(
	select dt_id, msisdn, dnmn_val, row_number() over(partition by msisdn order by dt_id nulls last, dnmn_val desc nulls last) rk
	from
	(
		select * from `data-bi-prd-935c.bi_stg`.tmp_rgs_ga_channel_rld_mapgw_{{ vdt_id }}_nogovt
		union all
		select * from `data-bi-prd-935c.bi_stg`.tmp_rgs_ga_channel_rld_fdv_{{ vdt_id }}_nogovt
	) x
) y
where rk=1
;

--- 1st. Stamping allocation
create or replace table `data-bi-prd-935c.bi_stg`.tmp_rgs_ga_channel_{{ vdt_id }}_tmp1_nogovt as
select ga.msisdn, ga.actvn_dt, ga.usg_flag
  , ga.svc_class_code, ga.dt_id ga_dt
	, alloc.iccid, alloc.program_name, alloc.dealer_code, alloc.channel_alloc, alloc.cluster_alloc
  , substr(substr(alloc.po_number,instr(alloc.po_number,'/')+1),instr(substr(alloc.po_number,instr(alloc.po_number,'/')+1),'/')+1) so_number
  , alloc.foss_dt
  , coalesce(alloc.dist_dt, '2000-01-01') dist_dt --- date 20000101 tidak akan berubah. untuk alokasi lama. referencenya yang akan mengikuti.
from `data-bi-prd-935c.bi_mart`.rgs_all_nogovt_dly ga
left join
(
  select msisdn, iccid, program_name, dealer dealer_code
    , case
        when upper(program_name) like 'SF%' then 'DSF'
        when upper(program_name) like '%MODERN%' then 'MODERN'--update
        when a.dealer=b.dealer_code then upper(b.channel)
        else NULL
    end channel_alloc
    , territoryid cluster_alloc
    , po_number, dt_id foss_dt, dist_dt
  from `data-bi-prd-935c.bi_mart`.foss_sp_mth a
  left join
  (
    select dealer_code, channel, territoryid
    from `data-bi-prd-935c.bi_mart`.foss_dealer_mth
    where date_trunc(mth_id,month)=date_trunc(vdt_id,month)
  ) b
    on a.dealer=b.dealer_code
  where date_trunc(mth_id,month)=date_trunc(vdt_id,month)
    and date(dt_id) between date_trunc(vdt_id,month) - interval 36 month and vdt_id
    and msisdn in
    (
      select msisdn from `data-bi-prd-935c.bi_mart`.rgs_all_nogovt_dly where date_trunc(dt_id,month) = date_trunc(vdt_id,month) and flag like '%B%'
    )
) alloc
  on ga.msisdn=alloc.msisdn
where date_trunc(dt_id,month) = date_trunc(vdt_id,month) and flag like '%B%'
;

--- reference modern sp co brand
create or replace table `data-bi-prd-935c.bi_stg`.tmp_rgs_ga_channel_{{ vdt_id }}_tmp_modern_nogovt as
select a.msisdn, 'MODERN' channel_alloc, channel
	, b.organization_id, 2 rk_alloc, 1 rk_channel, 1 rk_all
	, b.dt_id
	, 'MODERN SP CO BRAND' flag
from `data-bi-prd-935c.bi_mart`.rgs_all_nogovt_dly a
left join
(
  select msisdn, organization_id, channel, dt_id, row_number() over(partition by msisdn order by rk nulls last) rk
  from
  (
    select msisdn, dealer_code organization_id, 'SP CO BRAND ALLOC - MODERN' channel, 2 rk, dt_id
    from `data-bi-prd-935c.bi_mart`.foss_sp_mth a
    left join
    (
      select dealer_code, channel, territoryid
      from `data-bi-prd-935c.bi_mart`.foss_dealer_mth
      where date_trunc(mth_id,month) = date_trunc(vdt_id,month) and upper(channel)='MODERN'
    ) b
      on a.dealer=b.dealer_code
    where date_trunc(mth_id,month)=date_trunc(vdt_id,month)
      and date(dt_id) between date_trunc(vdt_id,month)-interval 24 month and vdt_id
      and (upper(b.channel)='MODERN' or upper(a.program_name) like '%MODERN%')--update
    union all
    select msisdn, organization_id, concat('SP CO BRAND INJECT - ', upper(channel)) channel, 1 rk, inj_dt dt_id
    from `data-bi-prd-935c.bi_mart`.first_inj_channel_mth
    where date_trunc(mth_id,month)=date_trunc(vdt_id,month) and ifnull(organization_id,'')!=''
      and lower(channel) not in ('direct','dsf','traditional','p2p')
  ) x
) b
  on a.msisdn=b.msisdn
where rk=1 and date_trunc(a.dt_id,month) = date_trunc(vdt_id,month)
  and svc_class_code in (select svc_class_code from `data-bi-prd-935c.bi_mart`.ref_sc where flag='SP Modern' and eff_dt <= vdt_id and end_dt >=  vdt_id)
  and flag like '%B%'
;

--- reference sp data
create or replace table `data-bi-prd-935c.bi_stg`.tmp_rgs_ga_channel_{{ vdt_id }}_tmp_spdata_nogovt as
select a.msisdn
  , case
    when lower(channel) in ('direct','dsf','promotor','gadget shop') then 'DSF'
    when lower(channel) in ('traditional') then 'TRADITIONAL'
    when lower(channel) in ('modern') then 'MODERN'
  end channel_alloc
	, concat('INJECT - ', upper(channel)) channel
  , b.organization_id
  , case
    when lower(channel) in ('direct','dsf','promotor','gadget shop') then 1
    when lower(channel) in ('traditional') then 3
    when lower(channel) in ('modern') then 2
  end rk_alloc
  , case
    when lower(channel) in ('direct','dsf','promotor','gadget shop') then 1
    when lower(channel) in ('traditional') then 1
    when lower(channel) in ('modern') then 2
  end rk_channel
	, 99 rk_all
	, inj_dt dt_id
	, case
    when lower(channel) in ('direct','dsf','promotor','gadget shop') then 'SP DATA - DSF'
    when lower(channel) in ('traditional') then 'SP DATA - TRADITIONAL'
    when lower(channel) in ('modern') then 'SP DATA - MODERN'
  end flag
from `data-bi-prd-935c.bi_mart`.rgs_all_nogovt_dly a
inner join
(
  select msisdn, organization_id, channel, inj_dt
  from `data-bi-prd-935c.bi_mart`.first_inj_channel_mth
  where date_trunc(mth_id,month)=date_trunc(vdt_id,month) and ifnull(organization_id,'')!=''
    and transaction_type='SPDATA'
) b
  on a.msisdn=b.msisdn
where date_trunc(dt_id,month) = date_trunc(vdt_id,month)
  and svc_class_code in (select svc_class_code from `data-bi-prd-935c.bi_mart`.ref_sc where flag='SP DATA' and eff_dt <= vdt_id and end_dt >=  vdt_id)
  and flag like '%B%'
;


--- 2nd. Channel and Outlet reference
create or replace table `data-bi-prd-935c.bi_stg`.tmp_rgs_ga_channel_{{ vdt_id }}_tmp2_nogovt as
select *
from
(
  --- SP Data
  select * from `data-bi-prd-935c.bi_stg`.tmp_rgs_ga_channel_{{ vdt_id }}_tmp_spdata_nogovt
  union all
  --- Stockout DSF
  select * from (
select msisdn,'DSF' channel_alloc,concat('STOCKOUT - ', upper(sales_type)) channel,
promoter_org_id organization_id,1 rk_alloc,2 rk_channel,3 rk_all,dt_id,'STOCKOUT DSF' flag
from `data-bi-prd-935c.bi_mart`.immi_sellout_mth
where date_trunc(mth_id,month)=date_trunc(vdt_id,month) and dt_id >= date_trunc(vdt_id - interval 3 month,month)
and sales_type='Promotor'
union all
select msisdn,'DSF' channel_alloc,concat('STOCKOUT - ', upper(sales_type)) channel,
promoter_org_id organization_id,1 rk_alloc,2 rk_channel,3 rk_all,dt_id,'STOCKOUT DSF' flag
from `data-bi-prd-935c.bi_mart`.immi_sellout_mth
where date_trunc(mth_id,month)=date_trunc(vdt_id,month) and date_trunc(dt_id,month) >= date_trunc(vdt_id -interval 1 month,month)
and sales_type='Direct') a
  union all
  --- DSF Sellout
  select msisdn, 'DSF' channel_alloc, 'SELLOUT - DSF' channel, destination organization_id, 1 rk_alloc, 4 rk_channel, 3 rk_all, dt_id, 'SELLOUT DSF' flag
  from `data-bi-prd-935c.bi_mart`.mobii_msisdn_sellout_mth
  where date_trunc(month_id,month)=date_trunc(vdt_id,month)
    and date(dt_id) between date_trunc(vdt_id - interval 4 month, month) and vdt_id --- 4month
    and ifnull(destination,'')!=''
  union all
  --- SP Tagging
  select sp_tag_msisdn msisdn
    , case when regexp_contains(org_id,"^[0-9]+$")=False or org_type='Gadget Shop' then 'DSF' else 'TRADITIONAL' end channel_alloc
    , case
      when org_type='Gadget Shop' then 'SP TAG - GADGET SHOP'
      when regexp_contains(org_id,"^[0-9]+$")=False then 'SP TAG - DIRECT'
      else 'SP TAG - TRADITIONAL'
    end channel
    , org_id organization_id
    , case when regexp_contains(org_id,"^[0-9]+$")=False or org_type='Gadget Shop' then 1 else 3 end rk_alloc
    , case when regexp_contains(org_id,"^[0-9]+$")=False or org_type='Gadget Shop' then 3 else 2 end rk_channel
    , case when regexp_contains(org_id,"^[0-9]+$")=False or org_type='Gadget Shop' then 3 else 3 end rk_all
		, dt_id
		, case when regexp_contains(org_id,"^[0-9]+$")=False or org_type='Gadget Shop' then 'SP TAG - DSF' else 'SP TAG - TRADITIONAL' end flag
  from `data-bi-prd-935c.bi_mart`.sp_tag_outlet_mth
  where date_trunc(month_id,month)=date_trunc(vdt_id,month)
    and dt_id between date_trunc(vdt_id,month) - interval 6 month and vdt_id --- 2 years
    and ifnull(org_id,'')!=''
  union all
  --- First Inject by Channel
  select msisdn
    , case
      when lower(channel) in ('direct','dsf') then 'DSF'
      when lower(channel) in ('traditional') then 'TRADITIONAL'
      else 'MODERN'
    end channel_alloc
    , CONCAT('INJECT - ', UPPER(channel)) channel
    , organization_id
    , case
      when lower(channel) in ('direct','dsf') then 1
      when lower(channel) in ('traditional') then 3
      else 2
    end rk_alloc
    , case
      when lower(channel) in ('direct','dsf') then 5
      when lower(channel) in ('traditional') then 3
      else 3
    end rk_channel
    , 99 rk_all
		, inj_dt dt_id
		, case
      when lower(channel) in ('direct','dsf') then 'INJECT CHANNEL - DSF'
      when lower(channel) in ('traditional') then 'INJECT CHANNEL - TRADITIONAL'
      else 'INJECT CHANNEL - MODERN'
    end flag
  from `data-bi-prd-935c.bi_mart`.first_inj_channel_mth
  where date_trunc(mth_id,month)=date_trunc(vdt_id,month) and ifnull(organization_id,'')!=''
    and transaction_type != 'SPDATA'
      union all
  --- Modern SP Co Brand
  select * from `data-bi-prd-935c.bi_stg`.tmp_rgs_ga_channel_{{ vdt_id }}_tmp_modern_nogovt
  union all
  --- Modern SO
  select msisdn, 'MODERN' channel_alloc, 'SO MODERN' channel, dealer_code organization_id, 2 rk_alloc, 4 rk_channel, 2 rk_all, dt_id, 'SO MODERN' flag
  from `data-bi-prd-935c.bi_mart`.foss_sp_mth a
  left join
  (
    select dealer_code, channel, territoryid
    from `data-bi-prd-935c.bi_mart`.foss_dealer_mth
    where mth_id = date_trunc(vdt_id,month) and upper(channel)='MODERN'
  ) b
    on a.dealer=b.dealer_code
  where date_trunc(mth_id,month)=date_trunc(vdt_id,month)
    and date(dt_id) between date_trunc(vdt_id,month)-interval 24 month and vdt_id
    and (upper(b.channel)='MODERN' or upper(a.program_name) like '%MODERN%')--update
  union all
  --- Sellin Traditional
  select msisdn, 'TRADITIONAL' channel_alloc, 'SELLIN - TRADITIONAL' channel, destination organization_id, 3 rk_alloc, 4 rk_channel, 3 rk_all, dt_id, 'SELLIN TRADITIONAL' flag
  from `data-bi-prd-935c.bi_mart`.mobii_msisdn_mth
  where month_id=date_trunc(vdt_id,month)
    and date(dt_id) between date_trunc(vdt_id,month) - interval 36 month and vdt_id --- 2 years
    and ifnull(destination,'')!=''
  union all
  --- FOSS Activation
  select msisdn, 'TRADITIONAL' channel_alloc, 'ACT - TRADITIONAL' channel, organizationid organization_id, 3 rk_alloc, 5 rk_channel, 5 rk_all, act_date dt_id, 'ACT - TRADITIONAL' flag
  from `data-bi-prd-935c.bi_mart`.ga_outlet_mth
  where month_id=date_trunc(vdt_id,month)
    and date(act_date) between date_trunc(vdt_id,month) - interval 36 month and vdt_id --- 2 years
    and ifnull(organizationid,'')!=''
	union all
	--- First Inject all
  select msisdn
		, case
      when lower(channel) in ('direct','dsf','promotor','gadget shop') then 'DSF'
      when lower(channel) in ('traditional') then 'TRADITIONAL'
      else 'MODERN'
    end channel_alloc
		, concat('INJECT - ', upper(channel)) channel
    , organization_id, 99 rk_alloc, 99 rk_channel, 4 rk_all
		, inj_dt dt_id
		, case
      when lower(channel) in ('direct','dsf','promotor','gadget shop') then 'INJECT ALL - DSF'
      when lower(channel) in ('traditional') then 'INJECT ALL - TRADITIONAL'
      else 'INJECT ALL - MODERN'
    end flag
  from `data-bi-prd-935c.bi_mart`.first_inj_mth
  where date_trunc(mth_id,month)=date_trunc(vdt_id,month) and ifnull(organization_id,'')!=''
) a
where msisdn in (select msisdn from `data-bi-prd-935c.bi_mart`.rgs_all_nogovt_dly where date_trunc(dt_id,month) = date_trunc(vdt_id,month) and flag like '%B%')
;

--- 3a. stamping channel and outlet from allocation ori
create or replace table `data-bi-prd-935c.bi_stg`.tmp_rgs_ga_channel_{{ vdt_id }}_tmp3_nogovt_ori as
select ga.msisdn, ga.actvn_dt, ga.usg_flag
  , ga.channel_grp, ga.channel, ga.organization_id
	, sc.alias_name flag_sp
  , coalesce(cast(sc.price as numeric),0) sp_price
	, ga.ga_dt
	, ga.iccid, ga.program_name, ga.dealer_code, ga.channel_alloc, ga.cluster_alloc, ga.so_number, ga.foss_dt
	, case when ga.msisdn=rld.msisdn then 'Yes' else 'No' end flag_rld
  , coalesce(rld.dnmn_val,0) rld_denom
from
(
	select ga.msisdn, ga.actvn_dt, ga.usg_flag
    , ga.svc_class_code, ga.ga_dt
    , cnl.channel_alloc channel_grp, cnl.channel, cnl.organization_id
		, ga.iccid, ga.program_name, ga.dealer_code, ga.channel_alloc, ga.cluster_alloc, ga.so_number, ga.foss_dt, ga.dist_dt
	from `data-bi-prd-935c.bi_stg`.tmp_rgs_ga_channel_{{ vdt_id }}_tmp1_nogovt ga
	left join `data-bi-prd-935c.bi_stg`.tmp_rgs_ga_channel_{{ vdt_id }}_tmp_spdata_nogovt cnl
    on ga.msisdn=cnl.msisdn
) ga
left join `data-bi-prd-935c.bi_mart`.ref_sc sc
	on ga.svc_class_code=sc.svc_class_code and sc.eff_dt <= ga.dist_dt and sc.end_dt >=  ga.dist_dt
left join `data-bi-prd-935c.bi_stg`.tmp_rgs_ga_channel_rld_{{ vdt_id }}_nogovt rld
	on ga.msisdn=rld.msisdn
left join (
  select svc_class_code, alias_name, price
  from (
      select *, row_number() over(partition by svc_class_code order by end_dt desc nulls last) rk
      from `data-bi-prd-935c.bi_mart`.ref_sc 
  ) x
  where rk=1
) sc_rank
  on ga.svc_class_code=sc_rank.svc_class_code
;

--- 3b. stamping channel and outlet from allocation non ori from ori
create or replace table `data-bi-prd-935c.bi_stg`.tmp_rgs_ga_channel_{{ vdt_id }}_tmp3_nogovt as
select ga.msisdn, ga.actvn_dt, usg_flag
  , coalesce(ga.channel_grp, ga.channel_grp_nonori) channel_grp
  , coalesce(ga.channel, ga.channel_nonori) channel
  , coalesce(ga.organization_id, ga.organization_id_nonori) organization_id
	, ga.flag_sp
	, ga.sp_price
	, ga.ga_dt
	, ga.iccid, ga.program_name, ga.dealer_code, ga.channel_alloc, ga.cluster_alloc, ga.so_number, ga.foss_dt
	, ga.flag_rld
  , ga.rld_denom
from
(
	select ga.*, cnl.channel_alloc channel_grp_nonori, cnl.channel channel_nonori, cnl.organization_id organization_id_nonori
		, row_number() over(partition by ga.msisdn order by cnl.rk_alloc nulls last, cnl.rk_channel nulls last) rk
	from `data-bi-prd-935c.bi_stg`.tmp_rgs_ga_channel_{{ vdt_id }}_tmp3_nogovt_ori ga
	left join `data-bi-prd-935c.bi_stg`.tmp_rgs_ga_channel_{{ vdt_id }}_tmp2_nogovt cnl
    on ga.msisdn=cnl.msisdn and ga.channel_alloc=cnl.channel_alloc and cnl.rk_alloc!=99
) ga
where rk=1
;

--- 3c. rest of null stamps with reference channel and all injection
create or replace table `data-bi-prd-935c.bi_stg`.tmp_rgs_ga_channel_{{ vdt_id }}_tmp4_nogovt as
select ga.msisdn, ga.actvn_dt, ga.usg_flag
  , coalesce(ga.channel_grp, cnl.channel_grp) channel_grp
  , coalesce(ga.channel, cnl.channel) channel
  , coalesce(ga.organization_id, cnl.organization_id) organization_id
	, ga.flag_sp, ga.sp_price, ga.ga_dt
	, ga.iccid, ga.program_name, ga.dealer_code, ga.channel_alloc, ga.cluster_alloc, ga.so_number, ga.foss_dt
	, ga.flag_rld, ga.rld_denom
	, case when ga.msisdn=inj.msisdn then 'With Injection' else 'Without Injection' end flag_inject
	, inj.inj_dt inject_dt
	, inj.transaction_type act_type
	, inj.product_name product_name
	, coalesce(inj.main_price,0) main_price
from `data-bi-prd-935c.bi_stg`.tmp_rgs_ga_channel_{{ vdt_id }}_tmp3_nogovt ga
--- inject all channel outlet
left join
(
	select msisdn, channel_alloc channel_grp, channel, organization_id
	from
	(
    select a.*, row_number() over(partition by msisdn order by rk_all nulls last, dt_id desc nulls last) as rk
    from `data-bi-prd-935c.bi_stg`.tmp_rgs_ga_channel_{{ vdt_id }}_tmp2_nogovt a
    where rk_all!=99
	) x
	where rk=1
) cnl
	on ga.msisdn=cnl.msisdn
--- firts inject product
left join
(
	select msisdn, transaction_type, product_name, main_price, inj_dt
	from `data-bi-prd-935c.bi_mart`.first_inj_mth
	where date_trunc(mth_id,month)=date_trunc(vdt_id,month)
) inj
	on ga.msisdn=inj.msisdn
;

--- GA below 10k
create or replace table `data-bi-prd-935c.bi_stg`.tmp_rgs_ga_channel_{{ vdt_id }}_below_10k_nogovt as
select msisdn, actvn_dt, inject_dt, act_type, product_name, main_price
from
(
  select a.*, case when sp_price>=10000 or main_price>=10000 or rld_denom>=10000 then '>= 10K' else '< 10K' end flag_quality
  from `data-bi-prd-935c.bi_stg`.tmp_rgs_ga_channel_{{ vdt_id }}_tmp4_nogovt a
) xx
where flag_quality='< 10K'
;

--- salmo inject 360 days
create or replace table `data-bi-prd-935c.bi_stg`.tmp_rgs_ga_channel_{{ vdt_id }}_below_10k_salmo_nogovt as
select a.b_msisdn msisdn, b.actvn_dt, a.channel, a.organization_id, a.product_name, a.main_price
  , case
    when lower(a.transaction_type) in ('purchase data package','bulk purchase package transaction') then 'INJ'
    when lower(a.transaction_type) in ('indosat reload','bulk reload') then 'RLD'
  end transaction_type
  , a.transaction_id
  , a.completion_date
  , a.dt_id
from `data-bi-prd-935c.bi_mart`.sellout_salmo_dly a
inner join `data-bi-prd-935c.bi_mart`.first_inj_mth b
	on a.b_msisdn=b.msisdn and a.dt_id>=b.inj_dt and date_trunc(b.mth_id,month)=date_trunc(vdt_id,month)
where a.dt_id between date_trunc(vdt_id,month) - interval 12 month and vdt_id
  and lower(a.transaction_type) in ('purchase data package','bulk purchase package transaction','indosat reload','bulk reload')
	and b_msisdn in (select msisdn from `data-bi-prd-935c.bi_stg`.tmp_rgs_ga_channel_{{ vdt_id }}_below_10k_nogovt)
;

--- fdv 360 days
create or replace table `data-bi-prd-935c.bi_stg`.tmp_rgs_ga_channel_{{ vdt_id }}_below_10k_fdv_nogovt as
select concat('62',a.pm_red_msisdn) msisdn, b.actvn_dt, 'Traditional' channel, a.mobo_inj_outlet_id organization_id
  , a.mobo_inj_pack_name product_name, a.mobo_inj_main_price main_price
  , 'FDV' transaction_type, a.mobo_trx_id transaction_id, date(a.transactiondate) dt_id
from `data-dtp-prd-aa1a.sor`.fdv_mobo_pm_join_match a
inner join `data-bi-prd-935c.bi_mart`.first_inj_mth b
	on concat('62',a.pm_red_msisdn)=b.msisdn and date(a.transactiondate)>=b.inj_dt and date_trunc(b.mth_id,month)=date_trunc(vdt_id,month)
where a.transactiondate between timestamp(date_trunc(vdt_id,month) - interval 12 month) and timestamp(vdt_id)
  and a.pm_voucher_status='U'
	and concat('62',a.pm_red_msisdn) in (select msisdn from `data-bi-prd-935c.bi_stg`.tmp_rgs_ga_channel_{{ vdt_id }}_below_10k_nogovt)
  and substring(concat('62',pm_red_msisdn), 1,5) in ('62857','62858','62856','62815','62816','62855','62814')
  --and substr(case when substr(a.pm_red_msisdn,1,2)!='62' then concat('62',a.pm_red_msisdn) else a.pm_red_msisdn end,1,5) in ('62857','62858','62856','62815','62816','62855','62814')
;

--- union all inject
create or replace table `data-bi-prd-935c.bi_stg`.tmp_rgs_ga_channel_{{ vdt_id }}_below_10k_inj_all_nogovt as
select a.*, row_number() over(partition by msisdn order by actvn_dt desc nulls last, dt_id nulls last
    , case
      when transaction_type='INJ' then 1
      when transaction_type='RLD' then 2
      when transaction_type='FDV' then 3
    end nulls last
		, main_price desc nulls last
  ) rk
from
(
  select dt_id, actvn_dt, msisdn, channel, organization_id, product_name, main_price, transaction_type, date(completion_date) completion_date
  from `data-bi-prd-935c.bi_stg`.tmp_rgs_ga_channel_{{ vdt_id }}_below_10k_salmo_nogovt
  union all
  select dt_id, actvn_dt, msisdn, channel, organization_id, product_name, main_price, transaction_type, date(dt_id) completion_date
  from `data-bi-prd-935c.bi_stg`.tmp_rgs_ga_channel_{{ vdt_id }}_below_10k_fdv_nogovt
) a
;

--- final
create or replace table `data-bi-prd-935c.bi_stg`.tmp_rgs_ga_channel_{{ vdt_id }}_fnl_nogovt as
  select a.msisdn, a.actvn_dt, a.usg_flag
    , a.channel_grp, a.channel
    --, case when b.main_price>0 then 'With Injection' else 'Without Injection' end flag_inject
    , case when b.main_price_acm>0 then 'With Injection' else 'Without Injection' end flag_inject
    , a.organization_id, b.product_name, b.main_price, a.flag_rld, b.inject_dt, a.ga_dt
    , a.flag_sp, b.act_type, a.rld_denom, a.sp_price, b.main_price_acm
		, a.iccid, a.program_name, a.dealer_code, a.channel_alloc, a.cluster_alloc, a.so_number, a.foss_dt
		, timestamp(current_datetime('+7'))  ppn_dttm
    , date_trunc(vdt_id,month) month_id
  from `data-bi-prd-935c.bi_stg`.tmp_rgs_ga_channel_{{ vdt_id }}_tmp4_nogovt a
  left join
  (
    --- >=10k
    select msisdn, product_name, main_price, inject_dt
      , case
          when sp_price>=10000 then sp_price
          when main_price>=10000 then main_price
          else rld_denom
        end main_price_acm
      , act_type
    from `data-bi-prd-935c.bi_stg`.tmp_rgs_ga_channel_{{ vdt_id }}_tmp4_nogovt a
    where (sp_price>=10000 or main_price>=10000 or rld_denom>=10000)
    union all
    --- first inject <10 K with accumulation
    select x.msisdn, y.product_name, y.main_price, y.inject_dt, x.main_price_acm, y.act_type
    from
    (
      select msisdn, sum(main_price) main_price_acm
      from `data-bi-prd-935c.bi_stg`.tmp_rgs_ga_channel_{{ vdt_id }}_below_10k_inj_all_nogovt
      where msisdn in (select msisdn from `data-bi-prd-935c.bi_stg`.tmp_rgs_ga_channel_{{ vdt_id }}_below_10k_nogovt)
      group by 1
    ) x
    left join
    (
      select msisdn, main_price, product_name, inject_dt, act_type
      from `data-bi-prd-935c.bi_stg`.tmp_rgs_ga_channel_{{ vdt_id }}_below_10k_nogovt
    ) y
      on x.msisdn=y.msisdn
  ) b
    on a.msisdn=b.msisdn
;

--- insert to master table
delete from `data-bi-prd-935c.bi_mart`.rgs_ga_channel_mth_nogovt where month_id = date_trunc(vdt_id,month);
insert into `data-bi-prd-935c.bi_mart`.rgs_ga_channel_mth_nogovt
--create or replace table `data-bi-prd-935c.bi_stg`.tmp_rgs_ga_channel_mth_nogovt_{{ vdt_id }} as
select * from `data-bi-prd-935c.bi_stg`.tmp_rgs_ga_channel_{{ vdt_id }}_fnl_nogovt
;

--- insert tracking below 10k
delete from `data-bi-prd-935c.bi_mart`.rgs_ga_below_10k_track_mth_nogovt where month_id = date_trunc(vdt_id,month);
insert into `data-bi-prd-935c.bi_mart`.rgs_ga_below_10k_track_mth_nogovt
select msisdn, product_name, cast(main_price as numeric) main_price, cast(NULL as string), rk, dt_id inject_dt, transaction_type, date_trunc(vdt_id,month) month_id
from `data-bi-prd-935c.bi_stg`.tmp_rgs_ga_channel_{{ vdt_id }}_below_10k_inj_all_nogovt
where msisdn in (select msisdn from `data-bi-prd-935c.bi_stg`.tmp_rgs_ga_channel_{{ vdt_id }}_below_10k_nogovt)
;

--- drop temp table
drop table if exists `data-bi-prd-935c.bi_stg`.tmp_rgs_ga_channel_rld_mapgw_{{ vdt_id }}_nogovt;
drop table if exists `data-bi-prd-935c.bi_stg`.tmp_rgs_ga_channel_rld_fdv_{{ vdt_id }}_nogovt;
drop table if exists `data-bi-prd-935c.bi_stg`.tmp_rgs_ga_channel_rld_{{ vdt_id }}_nogovt;
drop table if exists `data-bi-prd-935c.bi_stg`.tmp_rgs_ga_channel_{{ vdt_id }}_tmp1_nogovt;
drop table if exists `data-bi-prd-935c.bi_stg`.tmp_rgs_ga_channel_{{ vdt_id }}_tmp_modern_nogovt;
drop table if exists `data-bi-prd-935c.bi_stg`.tmp_rgs_ga_channel_{{ vdt_id }}_tmp_spdata_nogovt;
drop table if exists `data-bi-prd-935c.bi_stg`.tmp_rgs_ga_channel_{{ vdt_id }}_tmp2_nogovt;
drop table if exists `data-bi-prd-935c.bi_stg`.tmp_rgs_ga_channel_{{ vdt_id }}_tmp3_nogovt_ori;
drop table if exists `data-bi-prd-935c.bi_stg`.tmp_rgs_ga_channel_{{ vdt_id }}_tmp3_nogovt;
drop table if exists `data-bi-prd-935c.bi_stg`.tmp_rgs_ga_channel_{{ vdt_id }}_tmp4_nogovt;
drop table if exists `data-bi-prd-935c.bi_stg`.tmp_rgs_ga_channel_{{ vdt_id }}_below_10k_nogovt;
drop table if exists `data-bi-prd-935c.bi_stg`.tmp_rgs_ga_channel_{{ vdt_id }}_below_10k_salmo_nogovt;
drop table if exists `data-bi-prd-935c.bi_stg`.tmp_rgs_ga_channel_{{ vdt_id }}_below_10k_fdv_nogovt;
drop table if exists `data-bi-prd-935c.bi_stg`.tmp_rgs_ga_channel_{{ vdt_id }}_below_10k_inj_all_nogovt;
drop table if exists `data-bi-prd-935c.bi_stg`.tmp_rgs_ga_channel_{{ vdt_id }}_fnl_nogovt;