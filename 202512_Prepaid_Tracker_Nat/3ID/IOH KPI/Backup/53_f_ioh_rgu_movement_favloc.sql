declare vdt_id date default @vdt_id;

delete from `data-bi-prd-935c.bi_mart.fct_rgu_by_branch_mtd` where dt = vdt_id;


INSERT INTO `data-bi-prd-935c.bi_mart.fct_rgu_by_branch_mtd`
SELECT vdt_id AS dt,
       'Gross Add' AS grp,
       'MTD' AS period,
       CASE 
           WHEN UPPER(COALESCE(b.branch, 'N/A')) IN ('ACEH', 'LHOKSEUMAWE', 'MEDAN', 'DELI SERDANG', 'KISARAN',
                                                     'SIANTAR', 'BATAM', 'PADANG', 'PEKANBARU', 'BENGKULU LAMPUNG', 'JAMBI', 'PALEMBANG') THEN 'NCSS'
           WHEN UPPER(COALESCE(b.branch, 'N/A')) IN ('CENTRAL WEST NORTH JKT', 'EAST SOUTH JKT DEPOK', 'TANGERANG', 'BEKASI', 'BOGOR', 'SERANG') THEN 'JABO'
           WHEN UPPER(COALESCE(b.branch, 'N/A')) IN ('BANDUNG', 'TASIKMALAYA', 'CIANJUR SUKABUMI', 'CIREBON', 'KARAWANG') THEN 'WJ'
           WHEN UPPER(COALESCE(b.branch, 'N/A')) IN ('BALIKPAPAN', 'BANJARMASIN', 'PONTIANAK', 'MAKASSAR', 'MANADO') THEN 'KALSUL'
           WHEN UPPER(COALESCE(b.branch, 'N/A')) IN ('PURWOKERTO', 'SEMARANG', 'YOGYAKARTA', 'SOLO', 'MADIUN', 'PONOROGO') THEN 'CJ'
           WHEN UPPER(COALESCE(b.branch, 'N/A')) IN ('MALANG', 'BLITAR', 'KEDIRI', 'SURABAYA', 'SIDOARJO', 'GRESIK', 'MOJOKERTO', 'JEMBER', 'BALI', 'LOMBOK') THEN 'EJBL'
           ELSE UPPER(COALESCE(b.branch, 'N/A'))
       END AS district,
       CASE 
           WHEN COALESCE(b.branch, 'N/A') = 'PONOROGO' THEN 'MADIUN'
           ELSE COALESCE(b.branch, 'N/A')
       END AS branch,
       COUNT(DISTINCT a.sbscrptn_ek_id) AS subs
FROM `data-bi-prd-935c.bi_mart.project_ioh_fu_master_v2` a
LEFT JOIN (
    SELECT DISTINCT sbscrptn_ek_id, COALESCE(UPPER(b.branch), 'N/A') AS branch
    FROM (SELECT * 
            FROM `bi_mart.ioh_subscriber_site_attribs_rolling` 
      WHERE dt =vdt_id) a-- _1_prt_vdt_id a
    LEFT JOIN (
        SELECT site_id, gladiator_branch AS branch
        FROM (
            SELECT DISTINCT site_id, gladiator_branch, ROW_NUMBER() OVER (PARTITION BY site_id ORDER BY mth_sk_id DESC) AS rnk
            FROM `data-bi-prd-935c.bi_mart.site_ref_dim`
            WHERE cast(mth_sk_id as date) IN (
                DATE_TRUNC(vdt_id, MONTH),
                DATE_TRUNC(DATE_SUB(DATE(vdt_id), INTERVAL 1 MONTH), MONTH),
                DATE_TRUNC(DATE_SUB(DATE(vdt_id), INTERVAL 2 MONTH), MONTH)
            )
        ) a
        WHERE a.rnk = 1
    ) b ON a.site_id_90 = b.site_id and a.dt =vdt_id
    WHERE b.site_id IS NULL
) b ON cast(a.sbscrptn_ek_id as string) = b.sbscrptn_ek_id
WHERE ga_date IS NOT NULL
  AND ga_date >= DATE_TRUNC(vdt_id,MONTH)
  AND ga_date <= vdt_id 
  AND b.sbscrptn_ek_id IS NULL
GROUP BY 1, 2, 3, 4, 5;


insert into `data-bi-prd-935c.bi_mart.fct_rgu_by_branch_mtd`
select vdt_id as dt, 'Gross Add' as grp, 'LMTD' as period,
case when upper(coalesce(b.branch, 'N/A')) in ('ACEH', 'LHOKSEUMAWE', 'MEDAN', 'DELI SERDANG', 'KISARAN',
'SIANTAR', 'BATAM', 'PADANG', 'PEKANBARU', 'BENGKULU LAMPUNG', 'JAMBI', 'PALEMBANG') then 'NCSS'
when upper(coalesce(b.branch, 'N/A')) in ('CENTRAL WEST NORTH JKT', 'EAST SOUTH JKT DEPOK', 'TANGERANG', 'BEKASI', 'BOGOR', 'SERANG') then 'JABO'
when upper(coalesce(b.branch, 'N/A')) in ('BANDUNG', 'TASIKMALAYA', 'CIANJUR SUKABUMI', 'CIREBON', 'KARAWANG') then 'WJ'
when upper(coalesce(b.branch, 'N/A')) in ('BALIKPAPAN', 'BANJARMASIN', 'PONTIANAK', 'MAKASSAR', 'MANADO') then 'KALSUL'
when upper(coalesce(b.branch, 'N/A')) in ('PURWOKERTO', 'SEMARANG', 'YOGYAKARTA', 'SOLO', 'MADIUN', 'PONOROGO') then 'CJ'
when upper(coalesce(b.branch, 'N/A')) in ('MALANG', 'BLITAR', 'KEDIRI', 'SURABAYA', 'SIDOARJO', 'GRESIK', 'MOJOKERTO', 'JEMBER', 'BALI', 'LOMBOK') then 'EJBL'
else upper(coalesce(b.branch, 'N/A')) end as district,
case when coalesce(b.branch, 'N/A') = 'PONOROGO' then 'MADIUN' else coalesce(b.branch, 'N/A') END as branch,
count(distinct a.sbscrptn_ek_id) as subs
from `data-bi-prd-935c.bi_mart.project_ioh_fu_master_v2` a
left join
(
 select distinct sbscrptn_ek_id, coalesce(upper(b.branch), 'N/A') as branch
 from (SELECT * 
            FROM `bi_mart.ioh_subscriber_site_attribs_rolling` 
      WHERE dt =date_sub(cast(vdt_id as date),interval 1 day)) a --_1_prt_'2024-10-14 a
 left join 
 (
  select site_id, gladiator_branch as branch
  from
  (
   select distinct site_id, gladiator_branch, row_number()over(partition by site_id order by mth_sk_id desc) as rnk
   from `data-bi-prd-935c.bi_mart.site_ref_dim`
   where mth_sk_id in
   (
    DATE_TRUNC(DATE_SUB(DATE(vdt_id), INTERVAL 1 MONTH), MONTH),
    DATE_TRUNC(DATE_SUB(DATE(vdt_id), INTERVAL 2 MONTH), MONTH),
    DATE_TRUNC(DATE_SUB(DATE(vdt_id), INTERVAL 3 MONTH), MONTH)
   )
   --where mth_sk_id in (202111, 202112, 202201) --for data 01 Mar onwards
   --where mth_sk_id in (202110, 202111, 202112) --for data 28 Feb backwards
  ) a
  where a.rnk = 1
 ) b on a.site_id_90 = b.site_id and a.dt=date_sub(cast(vdt_id as date),Interval 1 day) 
 where b.site_id is null
) b on cast(a.sbscrptn_ek_id as string) = b.sbscrptn_ek_id
where ga_date is not null
and ga_date >= DATE_TRUNC(vdt_id, MONTH)
and ga_date <= vdt_id
and b.sbscrptn_ek_id is null
group by 1,2,3,4,5;

INSERT INTO `data-bi-prd-935c.bi_mart.fct_rgu_by_branch_mtd`
SELECT vdt_id AS dt,
       'Gross Churn' AS grp,
       'MTD' AS period,
       CASE 
           WHEN UPPER(COALESCE(b.branch, 'N/A')) IN ('ACEH', 'LHOKSEUMAWE', 'MEDAN', 'DELI SERDANG', 'KISARAN',
                                                     'SIANTAR', 'BATAM', 'PADANG', 'PEKANBARU', 'BENGKULU LAMPUNG', 'JAMBI', 'PALEMBANG') THEN 'NCSS'
           WHEN UPPER(COALESCE(b.branch, 'N/A')) IN ('CENTRAL WEST NORTH JKT', 'EAST SOUTH JKT DEPOK', 'TANGERANG', 'BEKASI', 'BOGOR', 'SERANG') THEN 'JABO'
           WHEN UPPER(COALESCE(b.branch, 'N/A')) IN ('BANDUNG', 'TASIKMALAYA', 'CIANJUR SUKABUMI', 'CIREBON', 'KARAWANG') THEN 'WJ'
           WHEN UPPER(COALESCE(b.branch, 'N/A')) IN ('BALIKPAPAN', 'BANJARMASIN', 'PONTIANAK', 'MAKASSAR', 'MANADO') THEN 'KALSUL'
           WHEN UPPER(COALESCE(b.branch, 'N/A')) IN ('PURWOKERTO', 'SEMARANG', 'YOGYAKARTA', 'SOLO', 'MADIUN', 'PONOROGO') THEN 'CJ'
           WHEN UPPER(COALESCE(b.branch, 'N/A')) IN ('MALANG', 'BLITAR', 'KEDIRI', 'SURABAYA', 'SIDOARJO', 'GRESIK', 'MOJOKERTO', 'JEMBER', 'BALI', 'LOMBOK') THEN 'EJBL'
           ELSE UPPER(COALESCE(b.branch, 'N/A'))
       END AS district,
       CASE 
           WHEN COALESCE(b.branch, 'N/A') = 'PONOROGO' THEN 'MADIUN'
           ELSE COALESCE(b.branch, 'N/A')
       END AS branch,
       COUNT(DISTINCT a.sbscrptn_ek_id) AS subs
FROM `data-bi-prd-935c.bi_mart.fct_ioh_rgu_nik_movement` a
LEFT JOIN (
    SELECT DISTINCT sbscrptn_ek_id, COALESCE(UPPER(b.branch), 'N/A') AS branch
    FROM (SELECT * 
            FROM `bi_mart.ioh_subscriber_site_attribs_rolling` 
      WHERE dt =vdt_id) a
    LEFT JOIN (
        SELECT site_id, gladiator_branch AS branch
        FROM (
            SELECT DISTINCT site_id, gladiator_branch, 
                   ROW_NUMBER() OVER (PARTITION BY site_id ORDER BY mth_sk_id DESC) AS rnk
            FROM `data-bi-prd-935c.bi_mart.site_ref_dim`
            WHERE mth_sk_id IN (
                DATE_TRUNC(DATE_SUB(DATE(vdt_id), INTERVAL 1 MONTH), MONTH),
                DATE_TRUNC(DATE_SUB(DATE(vdt_id), INTERVAL 2 MONTH), MONTH),
                DATE_TRUNC(DATE_SUB(DATE(vdt_id), INTERVAL 3 MONTH), MONTH)
            )
        ) a
        WHERE a.rnk = 1
    ) b ON a.site_id_30 = b.site_id and a.dt=vdt_id
    WHERE b.site_id IS NULL
) b ON cast(a.sbscrptn_ek_id as string) = b.sbscrptn_ek_id
WHERE a.tag = 'rgu30_gross_churn'
  AND a.dt >= DATE_TRUNC(vdt_id, MONTH)
  AND a.dt <=vdt_id
  AND b.sbscrptn_ek_id IS NULL
GROUP BY 1, 2, 3, 4, 5;


INSERT INTO `data-bi-prd-935c.bi_mart.fct_rgu_by_branch_mtd`
SELECT vdt_id AS dt,
       'Gross Churn' AS grp,
       'LMTD' AS period,
       CASE 
           WHEN UPPER(COALESCE(b.branch, 'N/A')) IN ('ACEH', 'LHOKSEUMAWE', 'MEDAN', 'DELI SERDANG', 'KISARAN',
                                                     'SIANTAR', 'BATAM', 'PADANG', 'PEKANBARU', 'BENGKULU LAMPUNG', 'JAMBI', 'PALEMBANG') THEN 'NCSS'
           WHEN UPPER(COALESCE(b.branch, 'N/A')) IN ('CENTRAL WEST NORTH JKT', 'EAST SOUTH JKT DEPOK', 'TANGERANG', 'BEKASI', 'BOGOR', 'SERANG') THEN 'JABO'
           WHEN UPPER(COALESCE(b.branch, 'N/A')) IN ('BANDUNG', 'TASIKMALAYA', 'CIANJUR SUKABUMI', 'CIREBON', 'KARAWANG') THEN 'WJ'
           WHEN UPPER(COALESCE(b.branch, 'N/A')) IN ('BALIKPAPAN', 'BANJARMASIN', 'PONTIANAK', 'MAKASSAR', 'MANADO') THEN 'KALSUL'
           WHEN UPPER(COALESCE(b.branch, 'N/A')) IN ('PURWOKERTO', 'SEMARANG', 'YOGYAKARTA', 'SOLO', 'MADIUN', 'PONOROGO') THEN 'CJ'
           WHEN UPPER(COALESCE(b.branch, 'N/A')) IN ('MALANG', 'BLITAR', 'KEDIRI', 'SURABAYA', 'SIDOARJO', 'GRESIK', 'MOJOKERTO', 'JEMBER', 'BALI', 'LOMBOK') THEN 'EJBL'
           ELSE UPPER(COALESCE(b.branch, 'N/A'))
       END AS district,
       CASE 
           WHEN COALESCE(b.branch, 'N/A') = 'PONOROGO' THEN 'MADIUN'
           ELSE COALESCE(b.branch, 'N/A')
       END AS branch,
       COUNT(DISTINCT a.sbscrptn_ek_id) AS subs
FROM `data-bi-prd-935c.bi_mart.fct_ioh_rgu_nik_movement` a
LEFT JOIN (
    SELECT DISTINCT sbscrptn_ek_id, COALESCE(UPPER(b.branch), 'N/A') AS branch
    FROM (SELECT * 
            FROM `bi_mart.ioh_subscriber_site_attribs_rolling` 
      WHERE dt = date_sub(cast(vdt_id as date),interval 1 day)) a
    LEFT JOIN (
        SELECT site_id, gladiator_branch AS branch
        FROM (
            SELECT DISTINCT site_id, gladiator_branch, 
                   ROW_NUMBER() OVER (PARTITION BY site_id ORDER BY mth_sk_id DESC) AS rnk
            FROM `data-bi-prd-935c.bi_mart.site_ref_dim`
            WHERE mth_sk_id IN (
                DATE_TRUNC(DATE_SUB(DATE(date_sub(cast(vdt_id as date),interval 1 day)), INTERVAL 1 MONTH), MONTH),
                DATE_TRUNC(DATE_SUB(DATE(date_sub(cast(vdt_id as date),interval 1 day)), INTERVAL 2 MONTH), MONTH),
                DATE_TRUNC(DATE_SUB(DATE(date_sub(cast(vdt_id as date),interval 1 day)), INTERVAL 3 MONTH), MONTH)
            )
        ) a
        WHERE a.rnk = 1
    ) b ON a.site_id_30 = b.site_id and a.dt=date_sub(cast(vdt_id as date),interval 1 day)
    WHERE b.site_id IS NULL
) b ON cast(a.sbscrptn_ek_id as string) = b.sbscrptn_ek_id
WHERE a.tag = 'rgu30_gross_churn'
  AND a.dt >= DATE_TRUNC(date_sub(cast(vdt_id as date),interval 1 day), MONTH)
  AND a.dt <= date_sub(cast(vdt_id as date),interval 1 day)
  AND b.sbscrptn_ek_id IS NULL
GROUP BY 1, 2, 3, 4, 5;


INSERT INTO `data-bi-prd-935c.bi_mart.fct_rgu_by_branch_mtd`
SELECT vdt_id AS dt,
       'Gross Churn' AS grp,
       'LMTD' AS period,
       CASE 
           WHEN UPPER(COALESCE(b.branch, 'N/A')) IN ('ACEH', 'LHOKSEUMAWE', 'MEDAN', 'DELI SERDANG', 'KISARAN',
                                                     'SIANTAR', 'BATAM', 'PADANG', 'PEKANBARU', 'BENGKULU LAMPUNG', 'JAMBI', 'PALEMBANG') THEN 'NCSS'
           WHEN UPPER(COALESCE(b.branch, 'N/A')) IN ('CENTRAL WEST NORTH JKT', 'EAST SOUTH JKT DEPOK', 'TANGERANG', 'BEKASI', 'BOGOR', 'SERANG') THEN 'JABO'
           WHEN UPPER(COALESCE(b.branch, 'N/A')) IN ('BANDUNG', 'TASIKMALAYA', 'CIANJUR SUKABUMI', 'CIREBON', 'KARAWANG') THEN 'WJ'
           WHEN UPPER(COALESCE(b.branch, 'N/A')) IN ('BALIKPAPAN', 'BANJARMASIN', 'PONTIANAK', 'MAKASSAR', 'MANADO') THEN 'KALSUL'
           WHEN UPPER(COALESCE(b.branch, 'N/A')) IN ('PURWOKERTO', 'SEMARANG', 'YOGYAKARTA', 'SOLO', 'MADIUN', 'PONOROGO') THEN 'CJ'
           WHEN UPPER(COALESCE(b.branch, 'N/A')) IN ('MALANG', 'BLITAR', 'KEDIRI', 'SURABAYA', 'SIDOARJO', 'GRESIK', 'MOJOKERTO', 'JEMBER', 'BALI', 'LOMBOK') THEN 'EJBL'
           ELSE UPPER(COALESCE(b.branch, 'N/A'))
       END AS district,
       CASE 
           WHEN COALESCE(b.branch, 'N/A') = 'PONOROGO' THEN 'MADIUN'
           ELSE COALESCE(b.branch, 'N/A')
       END AS branch,
       COUNT(DISTINCT a.sbscrptn_ek_id) AS subs
FROM `data-bi-prd-935c.bi_mart.fct_ioh_rgu_nik_movement` a
LEFT JOIN (
    SELECT DISTINCT sbscrptn_ek_id, COALESCE(UPPER(b.branch), 'N/A') AS branch
    FROM (SELECT * 
            FROM `bi_mart.ioh_subscriber_site_attribs_rolling` 
      WHERE dt =date_sub(cast(vdt_id as date),interval 1 day)) a
    LEFT JOIN (
        SELECT site_id, gladiator_branch AS branch
        FROM (
            SELECT DISTINCT site_id, gladiator_branch, 
                   ROW_NUMBER() OVER (PARTITION BY site_id ORDER BY mth_sk_id DESC) AS rnk
            FROM `data-bi-prd-935c.bi_mart.site_ref_dim`
            WHERE mth_sk_id IN (
                DATE_TRUNC(DATE_SUB(date_sub(cast(vdt_id as date),interval 1 day), INTERVAL 1 MONTH), MONTH),
                DATE_TRUNC(DATE_SUB(date_sub(cast(vdt_id as date),interval 1 day), INTERVAL 2 MONTH), MONTH),
                DATE_TRUNC(DATE_SUB(date_sub(cast(vdt_id as date),interval 1 day), INTERVAL 3 MONTH), MONTH)
            )
        ) a
        WHERE a.rnk = 1
    ) b ON a.site_id_30 = b.site_id and a.dt=date_sub(cast(vdt_id as date),interval 1 day)
    WHERE b.site_id IS NULL
) b ON cast(a.sbscrptn_ek_id as string) = b.sbscrptn_ek_id
WHERE a.tag = 'rgu30_gross_churn'
  AND a.dt >= DATE_TRUNC(date_sub(cast(vdt_id as date),interval 1 day), MONTH)
  AND a.dt <= date_sub(cast(vdt_id as date),interval 1 day)
  AND b.sbscrptn_ek_id IS NULL
GROUP BY 1, 2, 3, 4, 5;



INSERT INTO `data-bi-prd-935c.bi_mart.fct_rgu_by_branch_mtd`
SELECT 
    vdt_id AS dt,
    'Churn Back' AS grp,
    'LMTD' AS period,
    CASE 
        WHEN UPPER(COALESCE(b.branch, 'N/A')) IN ('ACEH', 'LHOKSEUMAWE', 'MEDAN', 'DELI SERDANG', 'KISARAN', 
                                                  'SIANTAR', 'BATAM', 'PADANG', 'PEKANBARU', 'BENGKULU LAMPUNG', 'JAMBI', 'PALEMBANG') THEN 'NCSS'
        WHEN UPPER(COALESCE(b.branch, 'N/A')) IN ('CENTRAL WEST NORTH JKT', 'EAST SOUTH JKT DEPOK', 'TANGERANG', 'BEKASI', 'BOGOR', 'SERANG') THEN 'JABO'
        WHEN UPPER(COALESCE(b.branch, 'N/A')) IN ('BANDUNG', 'TASIKMALAYA', 'CIANJUR SUKABUMI', 'CIREBON', 'KARAWANG') THEN 'WJ'
        WHEN UPPER(COALESCE(b.branch, 'N/A')) IN ('BALIKPAPAN', 'BANJARMASIN', 'PONTIANAK', 'MAKASSAR', 'MANADO') THEN 'KALSUL'
        WHEN UPPER(COALESCE(b.branch, 'N/A')) IN ('PURWOKERTO', 'SEMARANG', 'YOGYAKARTA', 'SOLO', 'MADIUN', 'PONOROGO') THEN 'CJ'
        WHEN UPPER(COALESCE(b.branch, 'N/A')) IN ('MALANG', 'BLITAR', 'KEDIRI', 'SURABAYA', 'SIDOARJO', 'GRESIK', 'MOJOKERTO', 'JEMBER', 'BALI', 'LOMBOK') THEN 'EJBL'
        ELSE UPPER(COALESCE(b.branch, 'N/A'))
    END AS district,
    CASE 
        WHEN COALESCE(b.branch, 'N/A') = 'PONOROGO' THEN 'MADIUN'
        ELSE COALESCE(b.branch, 'N/A')
    END AS branch,
    COUNT(a.sbscrptn_ek_id) AS subs
FROM `data-bi-prd-935c.bi_mart.fct_ioh_rgu_nik_movement` a
LEFT JOIN (
    SELECT DISTINCT 
        sbscrptn_ek_id, 
        COALESCE(UPPER(b.branch), 'N/A') AS branch
    FROM (SELECT * 
            FROM `bi_mart.ioh_subscriber_site_attribs_rolling` 
      WHERE dt =date_sub(cast(vdt_id as date),interval 1 day)) a
    LEFT JOIN (
        SELECT 
            site_id, 
            gladiator_branch AS branch
        FROM (
            SELECT 
                DISTINCT site_id, 
                gladiator_branch, 
                ROW_NUMBER() OVER (PARTITION BY site_id ORDER BY mth_sk_id DESC) AS rnk
            FROM `data-bi-prd-935c.bi_mart.site_ref_dim`
            WHERE mth_sk_id IN (
                DATE_TRUNC(DATE_SUB(DATE(vdt_id), INTERVAL 1 MONTH), MONTH),
                DATE_TRUNC(DATE_SUB(DATE(vdt_id), INTERVAL 2 MONTH), MONTH),
                DATE_TRUNC(DATE_SUB(DATE(vdt_id), INTERVAL 3 MONTH), MONTH)
            )
        ) a
        WHERE a.rnk = 1
    ) b ON a.site_id_30 = b.site_id and a.dt =date_sub(cast(vdt_id as date),interval 1 day)
    WHERE b.site_id IS NULL
) b ON cast(a.sbscrptn_ek_id as string) = b.sbscrptn_ek_id
WHERE a.tag = 'rgu30_churn_back'
  AND a.dt >= DATE_TRUNC(date_sub(cast(vdt_id as date),interval 1 day), MONTH)
  AND a.dt <= date_sub(cast(vdt_id as date),interval 1 day)
  AND b.sbscrptn_ek_id IS NULL
GROUP BY 1, 2, 3, 4, 5;


INSERT INTO `data-bi-prd-935c.bi_mart.fct_rgu_by_branch_mtd`
SELECT 
    vdt_id AS dt,
    'RGU30' AS grp,
    'MTD' AS period,
    CASE 
        WHEN UPPER(COALESCE(b.branch, 'N/A')) IN ('ACEH', 'LHOKSEUMAWE', 'MEDAN', 'DELI SERDANG', 'KISARAN',
                                                  'SIANTAR', 'BATAM', 'PADANG', 'PEKANBARU', 'BENGKULU LAMPUNG', 
                                                  'JAMBI', 'PALEMBANG') THEN 'NCSS'
        WHEN UPPER(COALESCE(b.branch, 'N/A')) IN ('CENTRAL WEST NORTH JKT', 'EAST SOUTH JKT DEPOK', 'TANGERANG', 
                                                  'BEKASI', 'BOGOR', 'SERANG') THEN 'JABO'
        WHEN UPPER(COALESCE(b.branch, 'N/A')) IN ('BANDUNG', 'TASIKMALAYA', 'CIANJUR SUKABUMI', 'CIREBON', 
                                                  'KARAWANG') THEN 'WJ'
        WHEN UPPER(COALESCE(b.branch, 'N/A')) IN ('BALIKPAPAN', 'BANJARMASIN', 'PONTIANAK', 'MAKASSAR', 
                                                  'MANADO') THEN 'KALSUL'
        WHEN UPPER(COALESCE(b.branch, 'N/A')) IN ('PURWOKERTO', 'SEMARANG', 'YOGYAKARTA', 'SOLO', 'MADIUN', 
                                                  'PONOROGO') THEN 'CJ'
        WHEN UPPER(COALESCE(b.branch, 'N/A')) IN ('MALANG', 'BLITAR', 'KEDIRI', 'SURABAYA', 'SIDOARJO', 
                                                  'GRESIK', 'MOJOKERTO', 'JEMBER', 'BALI', 'LOMBOK') THEN 'EJBL'
        ELSE UPPER(COALESCE(b.branch, 'N/A'))
    END AS district,
    CASE 
        WHEN COALESCE(b.branch, 'N/A') = 'PONOROGO' THEN 'MADIUN'
        ELSE COALESCE(b.branch, 'N/A')
    END AS branch,
    COUNT(DISTINCT a.sbscrptn_ek_id) AS subs
FROM `data-bi-prd-935c.bi_mart.fct_rgu_ioh_nik_mstr` a
LEFT JOIN (
    SELECT 
        DISTINCT sbscrptn_ek_id, 
        COALESCE(UPPER(b.branch), 'N/A') AS branch
    FROM (SELECT * 
            FROM `bi_mart.ioh_subscriber_site_attribs_rolling` 
      WHERE dt =vdt_id) a
    LEFT JOIN (
        SELECT 
            site_id, 
            gladiator_branch AS branch
        FROM (
            SELECT 
                DISTINCT site_id, 
                gladiator_branch, 
                ROW_NUMBER() OVER (PARTITION BY site_id ORDER BY mth_sk_id DESC) AS rnk
            FROM `data-bi-prd-935c.bi_mart.site_ref_dim`
            WHERE mth_sk_id IN (
                DATE_TRUNC(vdt_id, MONTH),
                DATE_TRUNC(DATE_SUB(DATE(vdt_id), INTERVAL 1 MONTH), MONTH),
                DATE_TRUNC(DATE_SUB(DATE(vdt_id), INTERVAL 2 MONTH), MONTH)
            )
        ) a
        WHERE a.rnk = 1
    ) b ON a.site_id_30 = b.site_id and a.dt=vdt_id
    WHERE b.site_id IS NULL
) b ON cast(a.sbscrptn_ek_id as string) = b.sbscrptn_ek_id
WHERE a.tag = 'rgu30'
  AND a.dt = vdt_id
  AND b.sbscrptn_ek_id IS NULL
GROUP BY 1, 2, 3, 4, 5;


INSERT INTO `data-bi-prd-935c.bi_mart.fct_rgu_by_branch_mtd`
SELECT 
    vdt_id AS dt,
    'RGU30' AS grp,
    'LMTD' AS period,
    CASE 
        WHEN UPPER(COALESCE(b.branch, 'N/A')) IN ('ACEH', 'LHOKSEUMAWE', 'MEDAN', 'DELI SERDANG', 'KISARAN',
                                                  'SIANTAR', 'BATAM', 'PADANG', 'PEKANBARU', 'BENGKULU LAMPUNG',
                                                  'JAMBI', 'PALEMBANG') THEN 'NCSS'
        WHEN UPPER(COALESCE(b.branch, 'N/A')) IN ('CENTRAL WEST NORTH JKT', 'EAST SOUTH JKT DEPOK', 'TANGERANG',
                                                  'BEKASI', 'BOGOR', 'SERANG') THEN 'JABO'
        WHEN UPPER(COALESCE(b.branch, 'N/A')) IN ('BANDUNG', 'TASIKMALAYA', 'CIANJUR SUKABUMI', 'CIREBON',
                                                  'KARAWANG') THEN 'WJ'
        WHEN UPPER(COALESCE(b.branch, 'N/A')) IN ('BALIKPAPAN', 'BANJARMASIN', 'PONTIANAK', 'MAKASSAR',
                                                  'MANADO') THEN 'KALSUL'
        WHEN UPPER(COALESCE(b.branch, 'N/A')) IN ('PURWOKERTO', 'SEMARANG', 'YOGYAKARTA', 'SOLO', 'MADIUN',
                                                  'PONOROGO') THEN 'CJ'
        WHEN UPPER(COALESCE(b.branch, 'N/A')) IN ('MALANG', 'BLITAR', 'KEDIRI', 'SURABAYA', 'SIDOARJO',
                                                  'GRESIK', 'MOJOKERTO', 'JEMBER', 'BALI', 'LOMBOK') THEN 'EJBL'
        ELSE UPPER(COALESCE(b.branch, 'N/A'))
    END AS district,
    CASE 
        WHEN COALESCE(b.branch, 'N/A') = 'PONOROGO' THEN 'MADIUN'
        ELSE COALESCE(b.branch, 'N/A')
    END AS branch,
    COUNT(DISTINCT a.sbscrptn_ek_id) AS subs
FROM `data-bi-prd-935c.bi_mart.fct_rgu_ioh_nik_mstr` a
LEFT JOIN (
    SELECT 
        DISTINCT sbscrptn_ek_id,
        COALESCE(UPPER(b.branch), 'N/A') AS branch
    FROM (SELECT * 
            FROM `bi_mart.ioh_subscriber_site_attribs_rolling` 
      WHERE dt =date_sub(cast(vdt_id as date),interval 1 day)) a
    LEFT JOIN (
        SELECT 
            site_id,
            gladiator_branch AS branch
        FROM (
            SELECT 
                DISTINCT site_id,
                gladiator_branch,
                ROW_NUMBER() OVER (PARTITION BY site_id ORDER BY mth_sk_id DESC) AS rnk
            FROM `data-bi-prd-935c.bi_mart.site_ref_dim`
            WHERE mth_sk_id IN (
                DATE_TRUNC(DATE_SUB(date_sub(cast(vdt_id as date),interval 1 day), INTERVAL 1 MONTH), MONTH),
                DATE_TRUNC(DATE_SUB(date_sub(cast(vdt_id as date),interval 1 day), INTERVAL 2 MONTH), MONTH),
                DATE_TRUNC(DATE_SUB(date_sub(cast(vdt_id as date),interval 1 day), INTERVAL 3 MONTH), MONTH)
            )
        ) a
        WHERE rnk = 1
    ) b ON a.site_id_30 = b.site_id and a.dt=date_sub(cast(vdt_id as date),interval 1 day)
) b ON cast(a.sbscrptn_ek_id as string) = b.sbscrptn_ek_id
WHERE a.tag = 'rgu30'
  AND a.dt = date_sub(cast(vdt_id as date),interval 1 day)
GROUP BY 1, 2, 3, 4, 5;


INSERT INTO `data-bi-prd-935c.bi_mart.fct_rgu_by_branch_mtd`
SELECT 
    dt, 
    grp, 
    period, 
    district, 
    branch, 
    SUM(subs) AS subs
FROM (
    SELECT 
        dt, 
        'Net Churn' AS grp, 
        period, 
        district, 
        branch, 
        subs
    FROM `data-bi-prd-935c.bi_mart.fct_rgu_by_branch_mtd`
    WHERE grp = 'Gross Churn' 
      AND dt = vdt_id

    UNION ALL

    SELECT 
        dt, 
        'Net Churn' AS grp, 
        period, 
        district, 
        branch, 
        (subs * -1) AS subs
    FROM `data-bi-prd-935c.bi_mart.fct_rgu_by_branch_mtd`
    WHERE grp = 'Churn Back' 
      AND dt = vdt_id
) a
GROUP BY 1, 2, 3, 4, 5;


INSERT INTO `data-bi-prd-935c.bi_mart.fct_rgu_by_branch_mtd`
SELECT 
    dt, 
    grp, 
    period, 
    district, 
    branch, 
    SUM(subs) AS subs
FROM (
    SELECT 
        dt, 
        'Net Add' AS grp, 
        period, 
        district, 
        branch, 
        subs
    FROM `data-bi-prd-935c.bi_mart.fct_rgu_by_branch_mtd`
    WHERE grp = 'Gross Add' 
      AND dt = vdt_id

    UNION ALL

    SELECT 
        dt, 
        'Net Add' AS grp, 
        period, 
        district, 
        branch, 
        (subs * -1) AS subs
    FROM `data-bi-prd-935c.bi_mart.fct_rgu_by_branch_mtd`
    WHERE grp = 'Gross Churn' 
      AND dt = vdt_id

    UNION ALL

    SELECT 
        dt, 
        'Net Add' AS grp, 
        period, 
        district, 
        branch, 
        subs
    FROM `data-bi-prd-935c.bi_mart.fct_rgu_by_branch_mtd`
    WHERE grp = 'Churn Back' 
      AND dt = vdt_id
) a
GROUP BY 1, 2, 3, 4, 5;
