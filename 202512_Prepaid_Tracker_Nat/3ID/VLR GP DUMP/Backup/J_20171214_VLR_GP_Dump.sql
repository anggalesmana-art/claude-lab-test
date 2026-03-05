declare vdt_id date default @vdt_id;

truncate table `data-bi-prd-935c.bi_stg.stg_vlr_ericsson_1`;

INSERT INTO `data-bi-prd-935c.bi_stg.stg_vlr_ericsson_1`
SELECT 
  a.load_dt_sk_id AS load_dt,
  a.imsi,
  a.msisdn,
  a.imei,
  a.latest_accessing_time AS latest_attached_dt,
  CASE 
    WHEN a.user_current_status = 'Attached' THEN 'A'
    WHEN a.user_current_status = 'Detached' THEN 'D'
    ELSE 'A'
  END AS flag,
  a.gci_sai AS gci
FROM `data-dtptechm-prd-c7ca.dwh.vlr` a 
LEFT JOIN `data-bi-prd-935c.bi_stg.stg_vlr_huawei` b
  ON a.msisdn = b.msisdn
WHERE a.file_name LIKE '%vlr_3id%'
  AND b.msisdn IS NULL;

truncate table `data-bi-prd-935c.bi_stg.stg_vlr_ericsson_2`;

INSERT INTO `data-bi-prd-935c.bi_stg.stg_vlr_ericsson_2`
SELECT 
  a.*,
  CASE 
    WHEN b.egci IS NULL THEN 0
    ELSE 1
  END AS flag2
FROM `data-bi-prd-935c.bi_stg.stg_vlr_ericsson_1` a
LEFT JOIN `data-bi-prd-935c.bi_mart.site_ref_dim` b
  ON b.egci = CONCAT(SUBSTR(a.gci, 1, 3), 'F', SUBSTR(REGEXP_REPLACE(UPPER(a.gci), '-', ''), 4, 16));

truncate table `data-bi-prd-935c.bi_mart.stg_vlr_ericsson_3`;
insert into stg_vlr_ericsson_3
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

truncate table `data-bi-prd-935c.bi_stg.stg_vlr_ericsson`;
insert into `data-bi-prd-935c.bi_stg.stg_vlr_ericsson`
select
load_dt,
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

INSERT INTO `data-bi-prd-935c.bi_mart.fct_vlr_daily`
SELECT *
FROM `data-bi-prd-935c.bi_stg.stg_vlr_ericsson`
WHERE _PARTITIONDATE = DATE(vdt_id);


	  