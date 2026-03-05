DECLARE vdt_id DATE DEFAULT @vdt_id;

CREATE OR REPLACE TABLE
  `data-bi-prd-935c.bi_stg`.tmp_ggsn_90d_agg_{{ vdt_id }}
CLUSTER BY msisdn AS
SELECT
  a.msisdn,
  a.lac,
  a.ci,
  b.site_id,
  SUM(a.volume) AS tot_volume
FROM `data-bi-prd-935c.bi_mart`.ggsn_lacci_dly a
JOIN `data-bi-prd-935c.bi_mart`.ref_lacci_dly b
  ON a.lac = b.lac
 AND a.ci  = b.ci
 AND b.dt_id = vdt_id
WHERE a.dt_id BETWEEN vdt_id - INTERVAL 89 DAY AND vdt_id
GROUP BY a.msisdn, a.lac, a.ci, b.site_id;


CREATE OR REPLACE TABLE
  `data-bi-prd-935c.bi_stg`.tmp_favloc_90d_ggsn_{{ vdt_id }} AS
SELECT
  msisdn,
  CONCAT(lac, '-', ci) AS lacci,
  site_id,
  '1. GGSN' AS priority
FROM (
  SELECT
    msisdn,
    lac,
    ci,
    site_id,
    ROW_NUMBER() OVER (
      PARTITION BY msisdn
      ORDER BY tot_volume DESC, lac, ci
    ) AS idx
  FROM `data-bi-prd-935c.bi_stg`.tmp_ggsn_90d_agg_{{ vdt_id }}
)
WHERE idx = 1;

DROP TABLE IF EXISTS `data-bi-prd-935c.bi_stg`.tmp_ggsn_90d_agg_{{ vdt_id }};
