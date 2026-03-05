select 
report_date_sk_id,
mth mth_rpt,
fwa_tag,
product_grp,
product_name,
process_nm,
service_type_name,
category,
revenue_src_ctgry,
gl_cd,
source_channel,
product_sk_id,
curr_ind,
revenue_book_incl_ind,
revenue_source_indicator,
sum(grossrevenue) as gross_rev,
sum(netrevenue) net_rev,
sum(amort) as amort 
from `data-bi-prd-935c.bi_mart.fwa_cal_rev` a 
where fwa_tag = 'FWA'
and report_date_sk_id >= DATE_TRUNC(vdt_id, MONTH)
group by 1,2,3,4,5,6,7,8,9,10,11,12,13,14,15;