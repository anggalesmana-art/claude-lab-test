DECLARE vdt_id DATE DEFAULT @vdt_id;

update `data-bi-prd-935c.bi_mart.project_ioh_rita_adjustment_detail`
set first_rgs_date = null where cast(first_rgs_date as date) = vdt_id;


update `data-bi-prd-935c.bi_mart.project_ioh_rita_adjustment_detail` a
set first_rgs_date = cast(load_dt_sk_id as date)
from `data-dtptechm-prd-c7ca.dwh.rgs_subs_detail` b
 where a.sbscrptn_ek_id = cast(b.sbscrptn_ek_id as string)
 and b.tool_of_trade_ind = 'N'
 and b.rgs_all_ex_sp
 and a.first_rgs_date is null
 and cast(b.load_dt_sk_id as date) = vdt_id;