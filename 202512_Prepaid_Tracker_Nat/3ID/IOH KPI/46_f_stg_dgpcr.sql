DECLARE vdt_id DATE DEFAULT @vdt_id;


DELETE FROM `data-bi-prd-935c.bi_mart.project_ioh_dgpcr_flag_hist`
WHERE dt_sk_id = vdt_id;



truncate table `data-bi-prd-935c.bi_mart.project_ioh_dgpcr_flag`;
  
insert into `data-bi-prd-935c.bi_mart.project_ioh_dgpcr_flag`
			 select service_msisdn,x_dgpcr_flag,nik 
			from (
			select so.service_msisdn,
			so.tax_iden_num as nik,
			so.x_dgpcr_flag,
			row_number() over (partition by service_msisdn
			order by service_last_upd desc, x_dgpcr_flag desc, tax_iden_num) as Rank_ind
			from `data-dtptechm-prd-c7ca.stg.stg_s_org_ext` so
			) d 
			where d.rank_ind = 1
			and x_dgpcr_flag in ('Y','A') ;

  insert into `data-bi-prd-935c.bi_mart.project_ioh_dgpcr_flag_hist`
		 select cast(vdt_id as date) as dt_sk_id, service_msisdn, x_dgpcr_flag, nik, cast(sbscrptn_ek_id as string) as sbscrptn_ek_id
			from `data-bi-prd-935c.bi_mart.project_ioh_dgpcr_flag` d 
			left join `data-dtptechm-prd-c7ca.dwh.sbscrptn_attribs` att on d.service_msisdn = att.sbscrptn_msisdn and att.rank_ind = 1;


-- since issue in SYNC table from on-prem we will copy data from UDP project

-- insert into `data-bi-prd-935c.bi_mart.project_ioh_dgpcr_flag`
-- SELECT service_msisdn, x_dgpcr_flag, nik 
-- FROM `data-dtptechm-prd-c7ca.mis.project_ioh_dgpcr_flag_hist` 
-- WHERE dt_sk_id = vdt_id ;