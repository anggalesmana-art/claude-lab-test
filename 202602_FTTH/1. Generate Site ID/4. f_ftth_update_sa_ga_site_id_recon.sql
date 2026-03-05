CREATE OR REPLACE PROCEDURE `data-bi-prd-935c.bi_dm.f_ftth_update_sa_ga_site_id_recon`()
BEGIN
  DECLARE column_list STRING;
  DECLARE merge_query_sa STRING;
  DECLARE merge_query_ga STRING;
  DECLARE row_count_sa INT64;
  DECLARE row_count_ga INT64;

  -- Step 1: Dapatkan daftar kolom untuk UPDATE
  SET column_list = (
    SELECT STRING_AGG(CONCAT("T.", column_name, " = S.", column_name), ', ') 
    FROM `data-bi-prd-935c.bi_dm.INFORMATION_SCHEMA.COLUMNS`
    WHERE table_name = 'tysg_ast_reference_recon'
    AND column_name NOT IN ('billing_account', 'dt_id')
  );

  -- Step 2: Cek apakah tabel sementara berisi data
  SET row_count_sa = (
    SELECT COUNT(*) FROM `data-bi-prd-935c.bi_dm.ftth_sa_temp`
  );
  
  SET row_count_ga = (
    SELECT COUNT(*) FROM `data-bi-prd-935c.bi_dm.ftth_ga_temp`
  );

  -- Step 3: Buat query MERGE secara dinamis hanya jika ada data
  IF row_count_sa > 0 THEN
    SET merge_query_sa = CONCAT(
      "MERGE `data-bi-prd-935c.bi_dm.tysg_ast_reference_recon` T ",
      "USING (SELECT * FROM `data-bi-prd-935c.bi_dm.ftth_sa_temp` WHERE billing_account IS NOT NULL) S ",
      "ON T.billing_account = S.billing_account AND T.dt_id = DATE(S.dt_id) ",
      "WHEN MATCHED THEN UPDATE SET ", column_list, " ",
      "WHEN NOT MATCHED THEN INSERT ROW;"
    );
    EXECUTE IMMEDIATE merge_query_sa;
  END IF;

  IF row_count_ga > 0 THEN
    SET merge_query_ga = CONCAT(
      "MERGE `data-bi-prd-935c.bi_dm.tysg_ast_reference_recon` T ",
      "USING (SELECT * FROM `data-bi-prd-935c.bi_dm.ftth_ga_temp` WHERE billing_account IS NOT NULL) S ",
      "ON T.billing_account = S.billing_account AND T.dt_id = DATE(S.dt_id) ",
      "WHEN MATCHED THEN UPDATE SET ", column_list, " ",
      "WHEN NOT MATCHED THEN INSERT ROW;"
    );
    EXECUTE IMMEDIATE merge_query_ga;
  END IF;

  -- Step 4: Drop Temp Table jika sudah diproses
  IF row_count_sa > 0 THEN
    DROP TABLE `data-bi-prd-935c.bi_dm.ftth_sa_temp`;
  END IF;

  IF row_count_ga > 0 THEN
    DROP TABLE `data-bi-prd-935c.bi_dm.ftth_ga_temp`;
  END IF;

END;