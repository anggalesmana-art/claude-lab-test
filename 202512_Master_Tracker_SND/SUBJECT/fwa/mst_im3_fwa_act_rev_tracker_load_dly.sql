declare vdt_id date default @vdt_id;

delete from `data-bi-prd-935c.bi_mart.ioh_fwa_kpi_detail` where dt_id = date(vdt_id) and time_flag ='dly' and kpi_id like 'REV-%';

insert into `data-bi-prd-935c.bi_mart.ioh_fwa_kpi_detail`
with fwa_usg_rev as (
    select 
    format_date('%Y-%m',date(a.dt_id)) mth_id
    , date(a.dt_id) as dt_id
    , site_id_favloc
    , flag
    , case when kpi='ALL PPU' then 'ALL PPU' else source_name end source
    , kpi
    , pkg_commercial_nm
    , case
        when upper(pkg_commercial_nm) like 'HIFI AIR%' then 30
        when validity_final=0 then 1
        when kpi in ('VAS','ALL PPU') then 1
        else validity_final
    end validity_final
    , sum(sales_price) sales_price
    from (
    select 
    a.*
    , case
            when REGEXP_CONTAINS(pkg_commercial_nm, r'(?i)hifi|air')
 and kpi!='VAS' then 'FWA DATA PACK'
            when kpi = 'REVENUE SP FWA' then 'FWA SIM'
            when a.msisdn=b.msisdn AND (kpi not in ('REVENUE SP ZERO', 'REVENUE OLA', 'REVENUE PGI WA')
                                            and svc_typ = 'DATA' 
                                        and REGEXP_CONTAINS(COALESCE(revenue_trigger, ''), r'(?i)Y4|Adjustment')
 = False
                                        and kpi!='ALL PPU') then 'REGULAR PACK'
            else 'NON BROADBAND'
    end as flag
    from `data-dtp-prd-aa1a.sor.fact_revenue_dashboard_extended` a
        join `data-dtp-prd-aa1a.smy.ar_cst_dly_smy` b ON a.dt_id = b.dt_id AND a.msisdn=b.msisdn AND b.svc_class_code in ('8153','8157')
                                                and cast(b.actvn_dt as date) >= '2025-03-01'
    where date(a.dt_id) = date(vdt_id)
    and kpi!='MARKUP PULSA'
    ) a
    where flag!='Others'
    group by 1,2,3,4,5,6,7,8
    UNION ALL 
    ---- table ini hanya sampai 1 Jun, tgl 2 jun onward revenue SIM menggunakan revenue_dashboard
    select 
    format_date('%Y-%m',coalesce(parse_date('%Y%m%d',ua_date),date(a.dt_id))) mth_id
    , coalesce(parse_date('%Y%m%d',ua_date),date(a.dt_id)) as dt_id
    , b.site_id
    ,'FWA SIM' as flag
    ,'FWA SIM' as source
    ,'REVENUE SP FWA' as kpi 
    ,a.revenue_code as level_1
    ,cast(quota_validity as int) as quota_validity
    , sum(cast(amount_debit as bigint))/1.11 amount_debit
    from `data-dtp-prd-aa1a.stg.sp_fwa_revenue` a
        left outer join `data-dtp-prd-aa1a.sor.subs_fav_loc_dly_carry_fwd` b ON a.msisdn = b.msisdn and coalesce(parse_date('%Y%m%d',ua_date),date(a.dt_id)) = date(b.dt_id)
    where date(a.dt_id) between date('2025-03-01') and date('2025-06-01')    ---> ini fix jangan diubah2
     and date(b.dt_id) between date('2025-03-01') and date('2025-06-01')   -- filter partition
    group by 1,2,3,4,5,6,7,8
)
select 
'IM3' as brand,
'siteid' as level,
site_id_favloc as level_value,
sum(cast(sales_price as bigint)) as metric_val,
current_timestamp() as insert_date,
'dly' time_flag,
CONCAT('REV-',
case when kpi = 'ALL PPU' then 'NON BROADBAND' else flag end) as kpi_id,
a.dt_id dt_id
from fwa_usg_rev a 
where dt_id = date(vdt_id)
group by 1,2,3,7,8;