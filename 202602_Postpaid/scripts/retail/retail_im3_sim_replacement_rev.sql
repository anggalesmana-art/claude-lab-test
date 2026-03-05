-- using table ipos from download
insert overwrite rdm.dm_im3_simcard_replacement partition(month_id)
select
    customer_msisdn, 
    organization_name, 
    organization_ref_code, 
    service_type event_type_main, 
    max(from_timestamp(to_timestamp(transaction_date,'dd/MM/yyyy HH:mm:ss'),'yyyyMMdd')) dt_id,
    from_timestamp(to_timestamp(transaction_date,'dd/MM/yyyy HH:mm:ss'),'yyyyMM') month_id
from rdm.ipos_trans_details 
where (status in ('Success', '') or status is null)
and service_type in ('Prepaid SIM Replacement','Postpaid SIM Replacement','Postpaid Sim Replacement New','Postpaid SIM Replacement New')
and from_timestamp(to_timestamp(transaction_date,'dd/MM/yyyy HH:mm:ss'),'yyyyMM')='{year_month}'
and from_timestamp(to_timestamp(transaction_date,'dd/MM/yyyy HH:mm:ss'),'yyyyMMdd') <= '{dt_id}'
group by 1, 2, 3, 4, 6
;   

--create table rdm.tmp_asal as
insert overwrite rdm.dm_im3_simcard_replacement_revenue partition(rev_month)
select x1.msisdn, x1.organization_name, x1.store_code, x1.event_type_main, x1.month_id,
t2.rev_30, t2.rev_month
from (
select t1.* from
(
select a.*, row_number() over(partition by msisdn order by month_id desc, store_code) idx 
       from rdm.dm_im3_simcard_replacement a
--        where month_id in ('202405','202406','202407')
        where month_id in (from_timestamp(last_day(add_months(to_timestamp(CONCAT('{year_month}','01'),'yyyyMMdd'),-2)),'yyyyMM'),from_timestamp(last_day(add_months(to_timestamp(CONCAT('{year_month}','01'),'yyyyMMdd'),-1)),'yyyyMM'),from_timestamp(last_day(to_timestamp(CONCAT('{year_month}', '01'), 'yyyyMMdd')), 'yyyyMM'))
) t1
where idx=1 
) x1 
left join 
(
select msisdn, sum(rev_30) rev_30, strleft(dt_id,6) rev_month
from biadm.hg_rgs_all_nogovt_dly
-- where dt_id=from_timestamp(last_day(to_timestamp(CONCAT('{year_month}', '01'), 'yyyyMMdd')), 'yyyyMMdd')
where dt_id='{dt_id}'
group by 1,3
) t2
on x1.msisdn=t2.msisdn
;

--dump result
select * from rdm.dm_im3_simcard_replacement_revenue where rev_month='{year_month}';   

--create table rdm.dm_im3_simcard_replacement_revenue_dly as
insert overwrite rdm.dm_im3_simcard_replacement_revenue_dly partition(rev_month, rev_dt)
select 
	x1.msisdn, 
	x1.organization_name, 
	x1.store_code, 
	x1.event_type_main, 
	x1.month_id simrepl_month_id,
	x1.dt_id simrepl_dt,
	t2.rev_30, 
	t2.rev_month,
	t2.rev_dt
from (
select t1.* from
(
select a.*, row_number() over(partition by msisdn order by month_id desc, store_code) idx 
       from rdm.dm_im3_simcard_replacement a
--        where month_id in ('202405','202406','202407')
        where month_id in (from_timestamp(last_day(add_months(to_timestamp(CONCAT('{year_month}','01'),'yyyyMMdd'),-2)),'yyyyMM'),from_timestamp(last_day(add_months(to_timestamp(CONCAT('{year_month}','01'),'yyyyMMdd'),-1)),'yyyyMM'),from_timestamp(last_day(to_timestamp(CONCAT('{year_month}', '01'), 'yyyyMMdd')), 'yyyyMM'))
) t1
where idx=1 
) x1 
left join 
(
select 
	msisdn, 
	sum(rev_30) rev_30, 
	strleft(dt_id,6) rev_month,
	dt_id rev_dt
from biadm.hg_rgs_all_nogovt_dly
-- where dt_id=from_timestamp(last_day(to_timestamp(CONCAT('{year_month}', '01'), 'yyyyMMdd')), 'yyyyMMdd')
where 1=1
and strleft(dt_id,6)=strleft('{dt_id}',6)
and dt_id<='{dt_id}'
group by 1,3,4
) t2
	on x1.msisdn=t2.msisdn
;