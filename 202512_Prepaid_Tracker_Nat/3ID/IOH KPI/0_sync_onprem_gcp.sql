DECLARE vdt_id DATE DEFAULT @vdt_id;

delete from `data-bi-prd-935c.bi_mart.project_ioh_dgpcr_flag_hist` WHERE dt_sk_id = vdt_id;

insert into `data-bi-prd-935c.bi_mart.project_ioh_dgpcr_flag_hist`
SELECT dt_sk_id, service_msisdn, x_dgpcr_flag, nik, cast(sbscrptn_ek_id as string) 
FROM `data-dtptechm-prd-c7ca.mis.project_ioh_dgpcr_flag_hist` WHERE dt_sk_id = vdt_id;

truncate table `data-bi-prd-935c.bi_mart.project_ioh_fu_master_v2`;
insert into `data-bi-prd-935c.bi_mart.project_ioh_fu_master_v2` 
select * from `data-bi-prd-935c.bi_stg.project_ioh_fu_master_v2`;


truncate table `data-bi-prd-935c.bi_mart.project_ioh_fu_master_90_v2`;
insert into `data-bi-prd-935c.bi_mart.project_ioh_fu_master_90_v2` 
select * from `data-bi-prd-935c.bi_stg.project_ioh_fu_master_90_v2`;