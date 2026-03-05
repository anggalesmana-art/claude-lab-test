declare vdt_id date default @vdt_id;
	  
--	  DELETE MTD DATA
delete from `data-bi-prd-935c.bi_mart`.trd_trisakti_adjustment_daily where snp_dt_sk_id=vdt_id;
					

	
--  INSERT DAILY ADJUSTMENT TABLE2

insert into `data-bi-prd-935c.bi_mart`.trd_trisakti_adjustment_daily
select 		date(snp_dt_sk_id) snp_dt_sk_id, adj.* except (bq_load_id,bq_load_time,snp_dt_sk_id)
			,ng.partner_qr_cd qr_code
			,case when regexp_contains(upper(adj.remarks), r'(TRADE|PROGRAM)') then 'YES' else 'NO' end is_inject
			,case 
				when upper(adj.remarks) like '%KALISUMAPA%' and regexp_contains(upper(adj.remarks), r'(TRADE|PROGRAM)') then 'KALISUMAPA' 
				when upper(adj.remarks) like '%JAYA%' and regexp_contains(upper(adj.remarks), r'(TRADE|PROGRAM)') then 'JAYA'
				when upper(adj.remarks) like '%JAVA%' and regexp_contains(upper(adj.remarks), r'(TRADE|PROGRAM)') then 'JAVA'
				when upper(adj.remarks) like '%SUMATERA%' and regexp_contains(upper(adj.remarks), r'(TRADE|PROGRAM)') then 'SUMATERA'
			end circle_remarks
from 		`data-dtptechm-prd-c7ca.dwh`.pretaps_3as_mvmt_adjustment adj
left join 	`data-bi-prd-935c.bi_mart`.angie_hrchy_dim_hst ng on adj.partner_id=ng.partner_id
where date(snp_dt_sk_id) = vdt_id
and adj.kpi_name='Adjustment' 
and			adj.kpi_freq='Daily' 
and			adj.kpi_value_type='Credit' 
and			adj.partner_type='RET' 
and 		ng.mth = date_trunc(vdt_id,month);


