declare vdt_id date default @vdt_id;

delete from `data-bi-prd-935c.bi_mart`.kpi_national_tracker_dly
where dt_id = vdt_id and kpi_id in (
'SLS0006',
'SLS0003',
'RLD0010',
'SLS0008',
'SLS0004',
'RLD0009',
'SLS0001',
'SLS0002',
'SLS0007'
) and brand = 'IM3';

insert into `data-bi-prd-935c.bi_mart`.kpi_national_tracker_dly
with prim as (
    --PRIMARY TRAD
    select 'IM3' brand,'primary_trad' kpi_code,'DLY' flag,sum(amount) metric,timestamp(current_datetime('+7')) process_dt,'SLS0001' kpi_id,dt_id
    from `data-bi-prd-935c.bi_mart`.fact_snd_primary
    where dt_id = vdt_id
    group by 1,2,3,5,6,7
),
sec as (
    --SECONDARY TRAD
    select 'IM3' brand,'secondary_trad' kpi_code,'DLY' flag,sum(amount) metric,timestamp(current_datetime('+7')) process_dt,'SLS0002' kpi_id,dt_id
    from `data-bi-prd-935c.bi_mart`.fact_snd_secondary
    where dt_id = vdt_id 
    group by 1,2,3,5,6,7
    -- select 'IM3' brand,'secondary_trad' kpi_code,'DLY' flag,sum(amount) metric,timestamp(current_datetime('+7')) process_dt,'SLS0002' kpi_id,dt_id
    -- from `data-bi-prd-935c.bi_mart`.omn_secondary_dtl --change by Indra Maulana Ikhsan 20240729
    -- where dt_id = vdt_id and channel_grp = 'Traditional'
    -- group by 1,2,3,5,6,7
),
ter_trad as (
    select dt_id,tertiary_type,sum(amount_debit) metric
    from `data-bi-prd-935c.bi_mart`.fact_snd_tertiary
    where dt_id = vdt_id 
    group by 1,2
),
ter_nontrad as (
    select dt_id,sum(amt) metric
    from `data-bi-prd-935c.bi_mart`.tertiary_nontrad
    where dt_id = vdt_id 
    group by 1
),
outlet_ftd as (
    select 'IM3' brand,'outlet_ftd' kpi_code,'DLY' flag,count(distinct organization_id) metric,timestamp(current_datetime('+7')) process_dt,'RLD0009' kpi_id,dt_id
    from `data-bi-prd-935c.bi_mart`.sellout_salmo_dly
    where dt_id = vdt_id
    and lower(transaction_type) like '%vou%'
    group by 1,2,3,5,6,7
),
outlet_ftm as (
    select 'IM3' brand,'outlet_ftm' kpi_code,'MTD' flag,count(distinct organization_id) metric,timestamp(current_datetime('+7')) process_dt,'RLD0010' kpi_id,vdt_id dt_id
    from `data-bi-prd-935c.bi_mart`.sellout_salmo_dly
    where dt_id >= date_trunc(vdt_id,month) and dt_id<=vdt_id
    and lower(transaction_type) like '%vou%'
    group by 1,2,3,5,6,7
),
mpc as (
    --MPC
    select 'IM3' brand,'num_mpc' kpi_code,'MTD' flag,count(distinct mpc) metric,timestamp(current_datetime('+7')) process_dt,'DST0012' kpi_id,vdt_id dt_id
    from (select mth_id,mpc,
    ROW_NUMBER() OVER (partition by mpc ORDER BY mth_id desc) AS rn
    from `data-bi-prd-935c.bi_mart`.mpc_depo_mth
    where mth_id between date_trunc(vdt_id - interval 1 month,month)
    and date_trunc(vdt_id,month)
    and mpc is not null and mpc !='') a
    where rn=1
    group by 1,2,3,5,6,7
),
sdp as (
    --DEPO MDP SDP
    select 'IM3' brand,'num_depo_mdp_sdp' kpi_code,'MTD' flag,count(distinct id_dp) metric,timestamp(current_datetime('+7')) process_dt,'DST0013' kpi_id,vdt_id dt_id
    from (select mth_id,id_dp,
    ROW_NUMBER() OVER (partition by id_dp ORDER BY mth_id desc) AS rn
    from `data-bi-prd-935c.bi_mart`.mpc_depo_mth
    where mth_id between date_trunc(vdt_id - interval 1 month,month)
    and date_trunc(vdt_id,month)) a
    where rn=1
    group by 1,2,3,5,6,7
)
select *
from prim
union all
select *
from sec
--TERTIARY ALL
union all
select 'IM3' brand,'tertiary' kpi_code,'DLY' flag,sum(metric) metric,timestamp(current_datetime('+7')) process_dt,'SLS0003' kpi_id,dt_id
from 
(select dt_id,sum(metric) metric
from ter_trad
group by 1
union all
select dt_id,sum(metric) metric
from ter_nontrad
group by 1) a
group by 1,2,3,5,6,7
--TERTIARY TRADITIONAL
union all
select 'IM3' brand,'tertiary_trad' kpi_code,'DLY' flag,sum(metric) metric,timestamp(current_datetime('+7')) process_dt,'SLS0004' kpi_id,dt_id
from ter_trad
group by 1,2,3,5,6,7
union all
--TERTIARY RETAILER TRADITIONAL
select 'IM3' brand,'tertiary_ret' kpi_code,'DLY' flag,sum(metric) metric,timestamp(current_datetime('+7')) process_dt,'SLS0006' kpi_id,dt_id
from ter_trad
group by 1,2,3,5,6,7
--TERTIARY TRADITIONAL RELOAD
union all
select 'IM3' brand,'tertiary_ret_rld' kpi_code,'DLY' flag,sum(metric) metric,timestamp(current_datetime('+7')) process_dt,'SLS0007' kpi_id,dt_id
from ter_trad
where tertiary_type in ('RELOAD','VOU RLD')
group by 1,2,3,5,6,7
union all
--TERTIARY TRADITIONAL PACK
select 'IM3' brand,'tertiary_ret_pack' kpi_code,'DLY' flag,sum(metric) metric,timestamp(current_datetime('+7')) process_dt,'SLS0008' kpi_id,dt_id
from ter_trad
where tertiary_type in ('VOU ORI','VOU REDEEM','SP MOBO','SP DATA','SP DATA ALLOC')
group by 1,2,3,5,6,7
union all
select * from outlet_ftd
union all
select * from outlet_ftm
union all
select * from mpc
union all
select * from sdp
;


delete from `data-bi-prd-935c.bi_mart`.kpi_national_tracker_dly
where dt_id = vdt_id and kpi_id in (
'SLS0027',
'SLS0015',
'SLS0023',
'SLS0010',
'SLS0012',
'SLS0026',
'SLS0005',
'SLS0014',
'SLS0018',
'SLS0016',
'SLS0020',
'SLS0011',
'SLS0019',
'SLS0022',
'SLS0024',
'SLS0028') and brand = 'IM3';

insert into `data-bi-prd-935c.bi_mart`.kpi_national_tracker_dly
with ter_nontrad as (
select dt_id,channel,tertiary_type,sum(amt) amt
from `data-bi-prd-935c.bi_mart`.tertiary_nontrad
where  dt_id = vdt_id 
group by 1,2,3
)
--TERTIARY NON TRADITIONAL
select 'IM3' brand,'tertiary_nontrad' kpi_code,'DLY' flag,sum(amt) metric,timestamp(current_datetime('+7')) process_dt,'SLS0005' kpi_id,dt_id
from ter_nontrad
group by 1,2,3,5,6,7
union all
--TERTIARY BANK
select 'IM3' brand,'tertiary_bank' kpi_code,'DLY' flag,sum(amt) metric,timestamp(current_datetime('+7')) process_dt,'SLS0010' kpi_id,dt_id
from ter_nontrad
where channel='Bank'
group by 1,2,3,5,6,7
union all
select 'IM3' brand,'tertiary_bank_rld' kpi_code,'DLY' flag,sum(amt) metric,timestamp(current_datetime('+7')) process_dt,'SLS0011' kpi_id,dt_id
from ter_nontrad
where channel='Bank' and tertiary_type in ('IGATE RLD','MOBO RLD')
group by 1,2,3,5,6,7
union all
select 'IM3' brand,'tertiary_bank_pack' kpi_code,'DLY' flag,sum(amt) metric,timestamp(current_datetime('+7')) process_dt,'SLS0012' kpi_id,dt_id
from ter_nontrad
where channel='Bank' and tertiary_type like 'SP MOBO%'
group by 1,2,3,5,6,7
union all
--TERTIARY MODERN RETAIL
select 'IM3' brand,'tertiary_modern' kpi_code,'DLY' flag,sum(amt) metric,timestamp(current_datetime('+7')) process_dt,'SLS0014' kpi_id,dt_id
from ter_nontrad
where channel='Modern'
group by 1,2,3,5,6,7
union all
select 'IM3' brand,'tertiary_modern_rld' kpi_code,'DLY' flag,sum(amt) metric,timestamp(current_datetime('+7')) process_dt,'SLS0015' kpi_id,dt_id
from ter_nontrad
where channel='Modern' and tertiary_type = 'MOBO RLD'
group by 1,2,3,5,6,7
union all
select 'IM3' brand,'tertiary_modern_pack' kpi_code,'DLY' flag,sum(amt) metric,timestamp(current_datetime('+7')) process_dt,'SLS0016' kpi_id,dt_id
from ter_nontrad
where channel='Modern' and tertiary_type like 'SP MOBO%'
group by 1,2,3,5,6,7
union all
--TERTIARY ONLINE
select 'IM3' brand,'tertiary_online' kpi_code,'DLY' flag,sum(amt) metric,timestamp(current_datetime('+7')) process_dt,'SLS0018' kpi_id,dt_id
from ter_nontrad
where channel='Online'
group by 1,2,3,5,6,7
union all
select 'IM3' brand,'tertiary_online_rld' kpi_code,'DLY' flag,sum(amt) metric,timestamp(current_datetime('+7')) process_dt,'SLS0019' kpi_id,dt_id
from ter_nontrad
where channel='Online' and tertiary_type = 'MOBO RLD'
group by 1,2,3,5,6,7
union all
select 'IM3' brand,'tertiary_online_pack' kpi_code,'DLY' flag,sum(amt) metric,timestamp(current_datetime('+7')) process_dt,'SLS0020' kpi_id,dt_id
from ter_nontrad
where channel='Online' and tertiary_type like 'SP MOBO%'
group by 1,2,3,5,6,7
union all
--TERTIARY H2H
select 'IM3' brand,'tertiary_h2h' kpi_code,'DLY' flag,sum(amt) metric,timestamp(current_datetime('+7')) process_dt,'SLS0022' kpi_id,dt_id
from ter_nontrad
where channel='H2H'
group by 1,2,3,5,6,7
union all
select 'IM3' brand,'tertiary_h2h_rld' kpi_code,'DLY' flag,sum(amt) metric,timestamp(current_datetime('+7')) process_dt,'SLS0023' kpi_id,dt_id
from ter_nontrad
where channel='H2H' and tertiary_type = 'MOBO RLD'
group by 1,2,3,5,6,7
union all
select 'IM3' brand,'tertiary_h2h_pack' kpi_code,'DLY' flag,sum(amt) metric,timestamp(current_datetime('+7')) process_dt,'SLS0024' kpi_id,dt_id
from ter_nontrad
where channel='H2H' and tertiary_type like 'SP MOBO%'
group by 1,2,3,5,6,7
union all
--TERTIARY P2P
select 'IM3' brand,'tertiary_p2p' kpi_code,'DLY' flag,sum(amt) metric,timestamp(current_datetime('+7')) process_dt,'SLS0026' kpi_id,dt_id
from ter_nontrad
where channel='P2P'
group by 1,2,3,5,6,7
union all
select 'IM3' brand,'tertiary_p2p_rld' kpi_code,'DLY' flag,sum(amt) metric,timestamp(current_datetime('+7')) process_dt,'SLS0027' kpi_id,dt_id
from ter_nontrad
where channel='P2P' and tertiary_type = 'MOBO RLD'
group by 1,2,3,5,6,7
union all
select 'IM3' brand,'tertiary_p2p_pack' kpi_code,'DLY' flag,sum(amt) metric,timestamp(current_datetime('+7')) process_dt,'SLS0028' kpi_id,dt_id
from ter_nontrad
where channel='P2P' and tertiary_type like 'SP MOBO%'
group by 1,2,3,5,6,7;

--STOCK MPC
delete from `data-bi-prd-935c.bi_mart`.kpi_national_tracker_dly where dt_id = vdt_id and kpi_id = 'SLS0030' and brand = 'IM3';
insert into `data-bi-prd-935c.bi_mart`.kpi_national_tracker_dly 
select 'IM3' brand,'stock_mpc_idr' kpi_code,'MTD' flag,sum(stock_mpc) metric,timestamp(current_datetime('+7')) process_dt,'SLS0030' kpi_id,dt_id
from 
(select dt_id,sum(stock_mpc) stock_mpc
from `data-bi-prd-935c.bi_mart`.track_stock_mpc
where dt_id=vdt_id
group by 1
union all
select dt_id,sum(cast(amount as numeric)) stock_mpc
from `data-bi-prd-935c.bi_mart`.stock_sp_data
where dt_id =vdt_id
and exp_dt>dt_id
group by 1
union all
select dt_id,sum(cast(amount as numeric)) stock_mpc
from `data-bi-prd-935c.bi_mart`.stock_vo_ori
where dt_id =vdt_id
and exp_dt>dt_id
group by 1
) a
group by 1,2,3,5,6,7;

--STOCK OUTLET
delete from `data-bi-prd-935c.bi_mart`.kpi_national_tracker_dly where dt_id = vdt_id and kpi_id = 'SLS0031' and brand = 'IM3';
insert into `data-bi-prd-935c.bi_mart`.kpi_national_tracker_dly 
select 'IM3' brand,'stock_ret_idr' kpi_code,'MTD' flag,sum(stock) metric,timestamp(current_datetime('+7')) process_dt,'SLS0031' kpi_id,dt_id
from (
select dt_id,sum(stock_balance) stock
from `data-bi-prd-935c.bi_mart`.outlet_stock_balance
where dt_id =vdt_id
group by 1
union all
select a.dt_id,sum(amount_debit) stock
from `data-bi-prd-935c.bi_mart`.stock_mobo_sp a
join (select date(dt_id) dt_id,msisdn from `data-dtp-prd-aa1a.smy.ar_cst_dly_smy`
where dt_id =timestamp(vdt_id)
and ar_lcs_tp_nm in ('ACTIVE','ACTIVE IN GRACE')) b on a.b_msisdn=b.msisdn and a.dt_id=b.dt_id
where a.dt_id =vdt_id
and a.inj_dt_id >=date(vdt_id - interval 360 day)
group by 1
union all
select dt_id,sum(amount_debit) stock
from `data-bi-prd-935c.bi_mart`.stock_mobo_vou
where dt_id =vdt_id
group by 1
union all
select dt_id,sum(amount) stock
from `data-bi-prd-935c.bi_mart`.stock_sp_data_mobii 
where dt_id =vdt_id
and expired_date>dt_id
group by 1
union all
select dt_id,sum(amount) stock
from `data-bi-prd-935c.bi_mart`.stock_vo_ori_sellin
where dt_id =vdt_id
and expired_date>dt_id
group by 1) a
group by 1,2,3,5,6,7;

--DOS SP
delete from `data-bi-prd-935c.bi_mart`.kpi_national_tracker_dly where dt_id = vdt_id and kpi_id = 'SLS0032' and brand = 'IM3';
insert into `data-bi-prd-935c.bi_mart`.kpi_national_tracker_dly 
select 'IM3' brand,'dos_sp' kpi_code,'MTD' flag,stock/avg_tertiary_30d metric,timestamp(current_datetime('+7')) process_dt,'SLS0032' kpi_id,a.dt_id
from
(select vdt_id dt_id,sum(stock) stock
from (
select sum(amount_debit) stock
from `data-bi-prd-935c.bi_mart`.stock_mobo_sp a
join (select msisdn from `data-dtp-prd-aa1a.smy.ar_cst_dly_smy`
where dt_id=timestamp(vdt_id)) b on a.b_msisdn=b.msisdn
where dt_id=vdt_id and channel='Traditional'
union all
select sum(amount) stock
from `data-bi-prd-935c.bi_mart`.stock_sp_data_mobii a
join (select msisdn from `data-dtp-prd-aa1a.smy.ar_cst_dly_smy`
where dt_id=timestamp(vdt_id)) b on a.msisdn=b.msisdn
where dt_id=vdt_id) a) a
join
(select vdt_id dt_id,sum(amt)/30 avg_tertiary_30d
from (
select sum(amount_debit) amt from `data-bi-prd-935c.bi_mart`.fact_snd_tertiary_dtl
where dt_id between date(vdt_id - interval 30 day) and vdt_id
and tertiary_type in ('SP DATA','SP MOBO Y2','SP MOBO Y4') and channel_grp = 'Traditional' ) a) b on a.dt_id=b.dt_id
;

--DOS Others
delete from `data-bi-prd-935c.bi_mart`.kpi_national_tracker_dly where dt_id = vdt_id and kpi_id = 'SLS0033' and brand = 'IM3';
insert into `data-bi-prd-935c.bi_mart`.kpi_national_tracker_dly 
select 'IM3' brand,'dos_others' kpi_code,'MTD' flag,stock/avg_tertiary_30d metric,timestamp(current_datetime('+7')) process_dt,'SLS0033' kpi_id,a.dt_id
from
(select vdt_id dt_id,sum(stock) stock
from (
select sum(amount_debit) stock
from `data-bi-prd-935c.bi_mart`.stock_mobo_vou
where dt_id=vdt_id
union all
select sum(amount_debit) stock
from `data-bi-prd-935c.bi_mart`.stock_mobo_vou_pulsa
where dt_id=vdt_id
union all
select sum(amount) stock
from `data-bi-prd-935c.bi_mart`.stock_vo_ori_sellin
where dt_id=vdt_id
union all
select sum(stock_balance) stock
from `data-bi-prd-935c.bi_mart`.stock_outlet_90d
where dt_id=vdt_id) a) a
join
(select vdt_id dt_id,sum(amt)/30 avg_tertiary_30d
from (
select sum(amount_debit) amt from `data-bi-prd-935c.bi_mart`.fact_snd_tertiary_dtl
where dt_id between date(vdt_id - interval 30 day) and vdt_id
and tertiary_type in ('VOU RLD','RELOAD','VOU REDEEM','VOU ORI','SP MOBO Y3') and channel_grp = 'Traditional') a) b on a.dt_id=b.dt_id
;