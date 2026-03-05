DECLARE vdt_id DATE DEFAULT @vdt_id;

delete from `data-bi-prd-935c.bi_mart.fct_h3i_kpi_nik` where dt = vdt_id and grp = 'RGS Daily - NIK';

insert into `data-bi-prd-935c.bi_mart.fct_h3i_kpi_nik`
select cast(vdt_id as date) as dt, 'RGS Daily - NIK' as grp,
case when upper(coalesce(b.branch, 'N/A')) in ('ACEH', 'LHOKSEUMAWE', 'MEDAN', 'DELI SERDANG', 'KISARAN',
'SIANTAR', 'BATAM', 'PADANG', 'PEKANBARU', 'BENGKULU LAMPUNG', 'JAMBI', 'PALEMBANG') then 'NCSS'
when upper(coalesce(b.branch, 'N/A')) in ('CENTRAL WEST NORTH JKT', 'EAST SOUTH JKT DEPOK', 'TANGERANG', 'BEKASI', 'BOGOR', 'SERANG') then 'JABO'
when upper(coalesce(b.branch, 'N/A')) in ('BANDUNG', 'TASIKMALAYA', 'CIANJUR SUKABUMI', 'CIREBON', 'KARAWANG') then 'WJ'
when upper(coalesce(b.branch, 'N/A')) in ('BALIKPAPAN', 'BANJARMASIN', 'PONTIANAK', 'MAKASSAR', 'MANADO') then 'KALSUL'
when upper(coalesce(b.branch, 'N/A')) in ('PURWOKERTO', 'SEMARANG', 'YOGYAKARTA', 'SOLO', 'MADIUN', 'PONOROGO') then 'CJ'
when upper(coalesce(b.branch, 'N/A')) in ('MALANG', 'BLITAR', 'KEDIRI', 'SURABAYA', 'SIDOARJO', 'GRESIK', 'MOJOKERTO', 'JEMBER', 'BALI', 'LOMBOK') then 'EJBL'
else upper(coalesce(b.branch, 'N/A')) end as district,
case when coalesce(b.branch, 'N/A') = 'PONOROGO' then 'MADIUN' else coalesce(b.branch, 'N/A') END as branch,
count(distinct a.sbscrptn_ek_id) as val
from --start 01 Jun 2022, RGU Daily has addition from Voice + SMS Free and A2P Domestic --start 01 Mar 2022, RGU Daily is coming from 2 tables source
( 
 select distinct sbscrptn_ek_id
 from `data-bi-prd-935c.bi_mart.fct_rgu_ioh_nik_mstr` a
 where tag = 'rgu_daily' and dt = vdt_id

 union distinct

 select distinct sbscrptn_ek_id
 from `data-bi-prd-935c.bi_mart.fct_ioh_rgu_daily_nik_add` a
 where tag = 'rgu_daily' and dt = vdt_id
) a
left outer join
(
 select distinct sbscrptn_ek_id, coalesce(upper(b.branch), 'N/A') as branch
 from 
 (select * from `data-bi-prd-935c.bi_mart.ioh_subscriber_site_attribs_rolling` where dt=vdt_id) a
 left outer join 
 (
select site_id, gladiator_branch as branch
from
(
 select distinct site_id, gladiator_branch, row_number()over(partition by site_id order by mth_sk_id desc) as rnk
 from `data-bi-prd-935c.bi_mart.site_ref_dim`
 where mth_sk_id in
 (
DATE_TRUNC(vdt_id,MONTH),
DATE_SUB(DATE_TRUNC(vdt_id, MONTH), INTERVAL 1 MONTH),
DATE_SUB(DATE_TRUNC(vdt_id, MONTH), INTERVAL 2 MONTH)
 )
 --where mth_sk_id in (202111, 202112, 202201) --for data 01 Mar onwards
 --where mth_sk_id in (202110, 202111, 202112) --for data 28 Feb backwards
) a
where a.rnk = 1
 ) b on a.site_id_dly = b.site_id 
) b on cast(a.sbscrptn_ek_id as string) = cast(b.sbscrptn_ek_id as string)
group by 1,2,3,4;


--2. RGS30

delete from `data-bi-prd-935c.bi_mart.fct_h3i_kpi_nik` where dt = vdt_id and grp = 'RGS30 - NIK';

insert into `data-bi-prd-935c.bi_mart.fct_h3i_kpi_nik`
select cast(vdt_id as date) as dt, 'RGS30 - NIK' as grp,
case when upper(coalesce(b.branch, 'N/A')) in ('ACEH', 'LHOKSEUMAWE', 'MEDAN', 'DELI SERDANG', 'KISARAN',
'SIANTAR', 'BATAM', 'PADANG', 'PEKANBARU', 'BENGKULU LAMPUNG', 'JAMBI', 'PALEMBANG') then 'NCSS'
when upper(coalesce(b.branch, 'N/A')) in ('CENTRAL WEST NORTH JKT', 'EAST SOUTH JKT DEPOK', 'TANGERANG', 'BEKASI', 'BOGOR', 'SERANG') then 'JABO'
when upper(coalesce(b.branch, 'N/A')) in ('BANDUNG', 'TASIKMALAYA', 'CIANJUR SUKABUMI', 'CIREBON', 'KARAWANG') then 'WJ'
when upper(coalesce(b.branch, 'N/A')) in ('BALIKPAPAN', 'BANJARMASIN', 'PONTIANAK', 'MAKASSAR', 'MANADO') then 'KALSUL'
when upper(coalesce(b.branch, 'N/A')) in ('PURWOKERTO', 'SEMARANG', 'YOGYAKARTA', 'SOLO', 'MADIUN', 'PONOROGO') then 'CJ'
when upper(coalesce(b.branch, 'N/A')) in ('MALANG', 'BLITAR', 'KEDIRI', 'SURABAYA', 'SIDOARJO', 'GRESIK', 'MOJOKERTO', 'JEMBER', 'BALI', 'LOMBOK') then 'EJBL'
else upper(coalesce(b.branch, 'N/A')) end as district,
case when coalesce(b.branch, 'N/A') = 'PONOROGO' then 'MADIUN' else coalesce(b.branch, 'N/A') END as branch,
count(distinct a.sbscrptn_ek_id) as val
from `data-bi-prd-935c.bi_mart.fct_rgu_ioh_nik_mstr` a
left outer join
(
 select distinct sbscrptn_ek_id, coalesce(upper(b.branch), 'N/A') as branch
 from  (select * from `data-bi-prd-935c.bi_mart.ioh_subscriber_site_attribs_rolling` where dt=vdt_id) a
 left outer join 
 (
select site_id, gladiator_branch as branch
from
(
 select distinct site_id, gladiator_branch, row_number()over(partition by site_id order by mth_sk_id desc) as rnk
 from `data-bi-prd-935c.bi_mart.site_ref_dim`
 where mth_sk_id in
 (
DATE_TRUNC(vdt_id,MONTH),
DATE_SUB(DATE_TRUNC(vdt_id, MONTH), INTERVAL 1 MONTH),
DATE_SUB(DATE_TRUNC(vdt_id, MONTH), INTERVAL 2 MONTH)
 )
 --where mth_sk_id in (202111, 202112, 202201) --for data 01 Mar onwards
 --where mth_sk_id in (202110, 202111, 202112) --for data 28 Feb backwards
) a
where a.rnk = 1
 ) b on a.site_id_30 = b.site_id
) b on cast(a.sbscrptn_ek_id as string) = cast(b.sbscrptn_ek_id as string)
where tag = 'rgu30' and dt = vdt_id
group by 1,2,3,4;

delete from `data-bi-prd-935c.bi_mart.fct_h3i_kpi_nik` where dt = vdt_id and grp = 'RGS90 - NIK';

insert into `data-bi-prd-935c.bi_mart.fct_h3i_kpi_nik`
select cast(vdt_id as date) as dt, 'RGS90 - NIK' as grp,
case when upper(coalesce(b.branch, 'N/A')) in ('ACEH', 'LHOKSEUMAWE', 'MEDAN', 'DELI SERDANG', 'KISARAN',
'SIANTAR', 'BATAM', 'PADANG', 'PEKANBARU', 'BENGKULU LAMPUNG', 'JAMBI', 'PALEMBANG') then 'NCSS'
when upper(coalesce(b.branch, 'N/A')) in ('CENTRAL WEST NORTH JKT', 'EAST SOUTH JKT DEPOK', 'TANGERANG', 'BEKASI', 'BOGOR', 'SERANG') then 'JABO'
when upper(coalesce(b.branch, 'N/A')) in ('BANDUNG', 'TASIKMALAYA', 'CIANJUR SUKABUMI', 'CIREBON', 'KARAWANG') then 'WJ'
when upper(coalesce(b.branch, 'N/A')) in ('BALIKPAPAN', 'BANJARMASIN', 'PONTIANAK', 'MAKASSAR', 'MANADO') then 'KALSUL'
when upper(coalesce(b.branch, 'N/A')) in ('PURWOKERTO', 'SEMARANG', 'YOGYAKARTA', 'SOLO', 'MADIUN', 'PONOROGO') then 'CJ'
when upper(coalesce(b.branch, 'N/A')) in ('MALANG', 'BLITAR', 'KEDIRI', 'SURABAYA', 'SIDOARJO', 'GRESIK', 'MOJOKERTO', 'JEMBER', 'BALI', 'LOMBOK') then 'EJBL'
else upper(coalesce(b.branch, 'N/A')) end as district,
case when coalesce(b.branch, 'N/A') = 'PONOROGO' then 'MADIUN' else coalesce(b.branch, 'N/A') END as branch,
count(distinct a.sbscrptn_ek_id) as val
from `data-bi-prd-935c.bi_mart.fct_rgu_ioh_nik_mstr` a
left outer join
(
 select distinct sbscrptn_ek_id, coalesce(upper(b.branch), 'N/A') as branch
 from (select * from `data-bi-prd-935c.bi_mart.ioh_subscriber_site_attribs_rolling` where dt=vdt_id) a
 left outer join 
 (
select site_id, gladiator_branch as branch
from
(
 select distinct site_id, gladiator_branch, row_number()over(partition by site_id order by mth_sk_id desc) as rnk
 from `data-bi-prd-935c.bi_mart.site_ref_dim`
 where mth_sk_id in
 (
DATE_TRUNC(vdt_id,MONTH),
DATE_SUB(DATE_TRUNC(vdt_id, MONTH), INTERVAL 1 MONTH),
DATE_SUB(DATE_TRUNC(vdt_id, MONTH), INTERVAL 2 MONTH)
 )
 --where mth_sk_id in (202111, 202112, 202201) --for data 01 Mar onwards
 --where mth_sk_id in (202110, 202111, 202112) --for data 28 Feb backwards
) a
where a.rnk = 1
 ) b on a.site_id_90 = b.site_id
) b on cast(a.sbscrptn_ek_id as string)= cast(b.sbscrptn_ek_id as string)
where tag = 'rgu90' and dt = vdt_id
group by 1,2,3,4;


--Churn Back 30

delete from `data-bi-prd-935c.bi_mart.fct_h3i_kpi_nik` where dt = vdt_id and grp = 'Churn Back 30 - NIK';

insert into `data-bi-prd-935c.bi_mart.fct_h3i_kpi_nik`
select cast(vdt_id as date) as dt, 'Churn Back 30 - NIK' as grp,
case when upper(coalesce(b.branch, 'N/A')) in ('ACEH', 'LHOKSEUMAWE', 'MEDAN', 'DELI SERDANG', 'KISARAN',
'SIANTAR', 'BATAM', 'PADANG', 'PEKANBARU', 'BENGKULU LAMPUNG', 'JAMBI', 'PALEMBANG') then 'NCSS'
when upper(coalesce(b.branch, 'N/A')) in ('CENTRAL WEST NORTH JKT', 'EAST SOUTH JKT DEPOK', 'TANGERANG', 'BEKASI', 'BOGOR', 'SERANG') then 'JABO'
when upper(coalesce(b.branch, 'N/A')) in ('BANDUNG', 'TASIKMALAYA', 'CIANJUR SUKABUMI', 'CIREBON', 'KARAWANG') then 'WJ'
when upper(coalesce(b.branch, 'N/A')) in ('BALIKPAPAN', 'BANJARMASIN', 'PONTIANAK', 'MAKASSAR', 'MANADO') then 'KALSUL'
when upper(coalesce(b.branch, 'N/A')) in ('PURWOKERTO', 'SEMARANG', 'YOGYAKARTA', 'SOLO', 'MADIUN', 'PONOROGO') then 'CJ'
when upper(coalesce(b.branch, 'N/A')) in ('MALANG', 'BLITAR', 'KEDIRI', 'SURABAYA', 'SIDOARJO', 'GRESIK', 'MOJOKERTO', 'JEMBER', 'BALI', 'LOMBOK') then 'EJBL'
else upper(coalesce(b.branch, 'N/A')) end as district,
case when coalesce(b.branch, 'N/A') = 'PONOROGO' then 'MADIUN' else coalesce(b.branch, 'N/A') END as branch,
count(distinct a.sbscrptn_ek_id) as val
from `data-bi-prd-935c.bi_mart.fct_ioh_rgu_nik_movement` a
left outer join
(
 select distinct sbscrptn_ek_id, coalesce(upper(b.branch), 'N/A') as branch
 from (select * from `data-bi-prd-935c.bi_mart.ioh_subscriber_site_attribs_rolling` where dt=vdt_id) a
 left outer join 
 (
select site_id, gladiator_branch as branch
from
(
 select distinct site_id, gladiator_branch, row_number()over(partition by site_id order by mth_sk_id desc) as rnk
 from `data-bi-prd-935c.bi_mart.site_ref_dim`
 where mth_sk_id in
 (
DATE_TRUNC(vdt_id,MONTH),
DATE_SUB(DATE_TRUNC(vdt_id, MONTH), INTERVAL 1 MONTH),
DATE_SUB(DATE_TRUNC(vdt_id, MONTH), INTERVAL 2 MONTH)
 )
 --where mth_sk_id in (202111, 202112, 202201) --for data 01 Mar onwards
 --where mth_sk_id in (202110, 202111, 202112) --for data 28 Feb backwards
) a
where a.rnk = 1
 ) b on a.site_id_30 = b.site_id
) b on cast(a.sbscrptn_ek_id as string)= cast(b.sbscrptn_ek_id as string)
where tag = 'rgu30_churn_back'
and dt = vdt_id
group by 1,2,3,4;


--Churn Back 90
delete from `data-bi-prd-935c.bi_mart.fct_h3i_kpi_nik` where dt = vdt_id and grp = 'Churn Back 90 - NIK';

insert into `data-bi-prd-935c.bi_mart.fct_h3i_kpi_nik`
select cast(vdt_id as date) as dt, 'Churn Back 90 - NIK' as grp,
case when upper(coalesce(b.branch, 'N/A')) in ('ACEH', 'LHOKSEUMAWE', 'MEDAN', 'DELI SERDANG', 'KISARAN',
'SIANTAR', 'BATAM', 'PADANG', 'PEKANBARU', 'BENGKULU LAMPUNG', 'JAMBI', 'PALEMBANG') then 'NCSS'
when upper(coalesce(b.branch, 'N/A')) in ('CENTRAL WEST NORTH JKT', 'EAST SOUTH JKT DEPOK', 'TANGERANG', 'BEKASI', 'BOGOR', 'SERANG') then 'JABO'
when upper(coalesce(b.branch, 'N/A')) in ('BANDUNG', 'TASIKMALAYA', 'CIANJUR SUKABUMI', 'CIREBON', 'KARAWANG') then 'WJ'
when upper(coalesce(b.branch, 'N/A')) in ('BALIKPAPAN', 'BANJARMASIN', 'PONTIANAK', 'MAKASSAR', 'MANADO') then 'KALSUL'
when upper(coalesce(b.branch, 'N/A')) in ('PURWOKERTO', 'SEMARANG', 'YOGYAKARTA', 'SOLO', 'MADIUN', 'PONOROGO') then 'CJ'
when upper(coalesce(b.branch, 'N/A')) in ('MALANG', 'BLITAR', 'KEDIRI', 'SURABAYA', 'SIDOARJO', 'GRESIK', 'MOJOKERTO', 'JEMBER', 'BALI', 'LOMBOK') then 'EJBL'
else upper(coalesce(b.branch, 'N/A')) end as district,
case when coalesce(b.branch, 'N/A') = 'PONOROGO' then 'MADIUN' else coalesce(b.branch, 'N/A') END as branch,
count(distinct a.sbscrptn_ek_id) as val
from `data-bi-prd-935c.bi_mart.fct_ioh_rgu_nik_movement` a
left outer join
(
 select distinct sbscrptn_ek_id, coalesce(upper(b.branch), 'N/A') as branch
 from (select * from `data-bi-prd-935c.bi_mart.ioh_subscriber_site_attribs_rolling` where dt=vdt_id) a
 left outer join 
 (
select site_id, gladiator_branch as branch
from
(
 select distinct site_id, gladiator_branch, row_number()over(partition by site_id order by mth_sk_id desc) as rnk
 from `data-bi-prd-935c.bi_mart.site_ref_dim`
 where mth_sk_id in
 (
DATE_TRUNC(vdt_id,MONTH),
DATE_SUB(DATE_TRUNC(vdt_id, MONTH), INTERVAL 1 MONTH),
DATE_SUB(DATE_TRUNC(vdt_id, MONTH), INTERVAL 2 MONTH)
 )
 --where mth_sk_id in (202111, 202112, 202201) --for data 01 Mar onwards
 --where mth_sk_id in (202110, 202111, 202112) --for data 28 Feb backwards
) a
where a.rnk = 1
 ) b on a.site_id_90 = b.site_id
) b on cast(a.sbscrptn_ek_id as string)= cast(b.sbscrptn_ek_id as string)
where tag = 'rgu90_churn_back'
and dt = vdt_id
group by 1,2,3,4;


delete from `data-bi-prd-935c.bi_mart.fct_h3i_kpi_nik` where dt = vdt_id and grp = 'Gross Add - NIK';

--Jan 2022 onwards

insert into `data-bi-prd-935c.bi_mart.fct_h3i_kpi_nik`
select cast(vdt_id as date) as dt, 'Gross Add - NIK' as grp,
case when upper(coalesce(b.branch, 'N/A')) in ('ACEH', 'LHOKSEUMAWE', 'MEDAN', 'DELI SERDANG', 'KISARAN',
'SIANTAR', 'BATAM', 'PADANG', 'PEKANBARU', 'BENGKULU LAMPUNG', 'JAMBI', 'PALEMBANG') then 'NCSS'
when upper(coalesce(b.branch, 'N/A')) in ('CENTRAL WEST NORTH JKT', 'EAST SOUTH JKT DEPOK', 'TANGERANG', 'BEKASI', 'BOGOR', 'SERANG') then 'JABO'
when upper(coalesce(b.branch, 'N/A')) in ('BANDUNG', 'TASIKMALAYA', 'CIANJUR SUKABUMI', 'CIREBON', 'KARAWANG') then 'WJ'
when upper(coalesce(b.branch, 'N/A')) in ('BALIKPAPAN', 'BANJARMASIN', 'PONTIANAK', 'MAKASSAR', 'MANADO') then 'KALSUL'
when upper(coalesce(b.branch, 'N/A')) in ('PURWOKERTO', 'SEMARANG', 'YOGYAKARTA', 'SOLO', 'MADIUN', 'PONOROGO') then 'CJ'
when upper(coalesce(b.branch, 'N/A')) in ('MALANG', 'BLITAR', 'KEDIRI', 'SURABAYA', 'SIDOARJO', 'GRESIK', 'MOJOKERTO', 'JEMBER', 'BALI', 'LOMBOK') then 'EJBL'
else upper(coalesce(b.branch, 'N/A')) end as district,
case when coalesce(b.branch, 'N/A') = 'PONOROGO' then 'MADIUN' else coalesce(b.branch, 'N/A') END as branch,
count(distinct a.sbscrptn_ek_id) as val
from `data-bi-prd-935c.bi_mart.project_ioh_fu_master_v2` a
left outer join
(
 select distinct sbscrptn_ek_id, coalesce(upper(b.branch), 'N/A') as branch
 from (select * from `data-bi-prd-935c.bi_mart.ioh_subscriber_site_attribs_rolling` where dt=vdt_id) a
 left outer join 
 (
select site_id, gladiator_branch as branch
from
(
 select distinct site_id, gladiator_branch, row_number()over(partition by site_id order by mth_sk_id desc) as rnk
 from `data-bi-prd-935c.bi_mart.site_ref_dim`
 where mth_sk_id in
 (
DATE_TRUNC(vdt_id,MONTH) ,
DATE_SUB(DATE_TRUNC(vdt_id, MONTH), INTERVAL 1 MONTH),
DATE_SUB(DATE_TRUNC(vdt_id, MONTH), INTERVAL 2 MONTH)
 )
 --where mth_sk_id in (202111, 202112, 202201) --for data 01 Mar onwards
 --where mth_sk_id in (202110, 202111, 202112) --for data 28 Feb backwards
) a
where a.rnk = 1
 ) b on a.site_id_90 = b.site_id
) b on cast(a.sbscrptn_ek_id as string) = cast(b.sbscrptn_ek_id as string)
where ga_date is not null
and ga_date = vdt_id
--and ga_date >= to_char(date_trunc('month', vdt_id::text::date), 'yyyymmdd')::int
--and ga_date <= vdt_id
group by 1,2,3,4;
