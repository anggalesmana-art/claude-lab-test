DECLARE vdt_id DATE DEFAULT @vdt_id;

drop table if exists `data-bi-prd-935c.bi_stg.stg_vlr_ericsson_1`;
create table `data-bi-prd-935c.bi_stg.stg_vlr_ericsson_1` as
select 
a.load_dt_sk_id as load_dt,
a.imsi,
a.msisdn,
a.imei,
a.latest_accessing_time as latest_attached_dt,
case 
when a.user_current_status = 'Attached' then 'A'
when a.user_current_status = 'Detached' then 'D'
else 'A'
end as flag,
a.gci_sai as gci
from `data-dtptechm-prd-c7ca.dwh.vlr` a
where cast(a.load_dt_sk_id as date)= vdt_id and a.file_name like '%vlr_3id%'
;


drop table if exists `data-bi-prd-935c.bi_stg.stg_vlr_ericsson_2`;
create table `data-bi-prd-935c.bi_stg.stg_vlr_ericsson_2` as
select 
a.*,
case 
when b.egci is null then 0
else 1
end as flag2
from `data-bi-prd-935c.bi_stg.stg_vlr_ericsson_1` a
left join
`data-bi-prd-935c.bi_mart.site_ref_dim` b
ON b.mth_sk_id=date_trunc( vdt_id, Month) and b.egci = substring(a.gci,1,3)||'F'||substring(replace(UPPER(a.gci),'-',''),4,16)

;


drop table if exists `data-bi-prd-935c.bi_stg.stg_vlr_ericsson_3`;
create table `data-bi-prd-935c.bi_stg.stg_vlr_ericsson_3` as
select
load_dt,
imsi,
msisdn,
imei,
latest_attached_dt,
flag,
gci
from
`data-bi-prd-935c.bi_stg.stg_vlr_ericsson_2`
where flag2=1
;

insert into `data-bi-prd-935c.bi_stg.stg_vlr_ericsson_3`
select
a.load_dt,
a.imsi,
a.msisdn,
a.imei,
a.latest_attached_dt,
a.flag,
a.gci
from
(select * from `data-bi-prd-935c.bi_stg.stg_vlr_ericsson_2` where flag2=0) a
left join
(select * from `data-bi-prd-935c.bi_stg.stg_vlr_ericsson_2` where flag2=1) b
on 
a.msisdn=b.msisdn
where b.msisdn is null;


drop table if exists `data-bi-prd-935c.bi_stg.stg_vlr_ericsson`;
create table `data-bi-prd-935c.bi_stg.stg_vlr_ericsson` as
select
cast(load_dt as date) as load_dt,
imsi,
msisdn,
imei,
latest_attached_dt,
flag,
gci
from
(
	select
	load_dt,
	imsi,
	msisdn,
	imei,
	latest_attached_dt,
	flag,
	gci,
	row_number()over(partition by msisdn order by gci desc) as rownum
	from
	`data-bi-prd-935c.bi_stg.stg_vlr_ericsson_3`
)a where rownum=1
;


delete from `data-bi-prd-935c.bi_mart.fct_vlr_daily` where load_dt= vdt_id;
insert into `data-bi-prd-935c.bi_mart.fct_vlr_daily`
select * from `data-bi-prd-935c.bi_stg.stg_vlr_ericsson`