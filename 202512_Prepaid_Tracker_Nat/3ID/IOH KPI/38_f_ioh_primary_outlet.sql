DECLARE vdt_id DATE DEFAULT @vdt_id;

delete from `data-bi-prd-935c.bi_mart.project_ioh_primary_outlet` where primary_category = 'SALDO' and dt_sk_id = vdt_id;

INSERT INTO `data-bi-prd-935c.bi_mart.project_ioh_primary_outlet`
				select cast(snp_dt_sk_id as date) dt_sk_id, fct.partner_type, kpi_name, msisdn, cast(angie_hrchy_sk_id as string) angie_hrchy_sk_id , partner_qr_cd, 'SALDO' secondary_category, kpi_name primary_type, hierarchy_type, value, kpi_cnt
				from `data-bi-prd-935c.bi_mart.v_snd_primary_transaction` fct
				left join `data-dtptechm-prd-c7ca.stg.stg_cx_angie_msisdn` ph on ph.name = msisdn
									and upper(status) in ('ACTIVE', 'SUSPENDED')
				--left join stg.stg_cx_angie_prtnr prt on prt.row_id = ph.par_row_id
				--left join dwh.angie_hrchy_dimtab_3 on tab_3.partner_id = prt.partner_id
				left join `data-dtptechm-prd-c7ca.dwh.angie_hrchy_dim` tab_3 on tab_3.partner_qr_cd = ph.qr_code
				where cast(snp_dt_sk_id as date) = vdt_id;
