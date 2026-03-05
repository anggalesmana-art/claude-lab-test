delete from `data-bi-prd-935c.bi_dm.tysg_ftth_orbit_cumulative_subs`
where dt_id = DATE_SUB(CURRENT_DATE('Asia/Jakarta'), Interval 1 day);

INSERT INTO `data-bi-prd-935c.bi_dm.tysg_ftth_orbit_cumulative_subs`
select
  a.customer_id,
  a.billing_account,
  a.cust_bill_id,
  d.ac_nm asset_name,
  d.email,
  d.mbl_no phone_no,
  a.ca_id,
  a.ba_id,
  a.ac_st,
  a.ac_st_dt,
  a.ac_st_reason,
  a.flag_account,
  a.so_date,
  a.sa_date,
  a.pa_date,
  coalesce(c.current_package_date, b.current_package_date) current_package_date,
  a.package_nm legacy_package,
  coalesce(c.product_before, b.package_before) package_before,
  coalesce(c.product_after, b.current_package) current_package,
  cast(coalesce(e.Monthly_Price, b.current_package_price) as numeric) current_package_price,
  a.vendor,
  a.site_id,
  a.dt_id,
  timestamp(DATETIME(CURRENT_TIMESTAMP(), "Asia/Jakarta")) as prc_dt,
from (
  select * from `data-bi-prd-935c.bi_dm.tysg_ftth_stg_subs_1`
  where dt_id = DATE_SUB(CURRENT_DATE('Asia/Jakarta'), Interval 1 day)
) a
left join (
  select * from `data-bi-prd-935c.bi_dm.tysg_ftth_orbit_cumulative_subs`
  where dt_id = DATE_SUB(CURRENT_DATE('Asia/Jakarta'), Interval 2 day)
) b
on a.billing_account = b.billing_account
left join (
  select * except(rk)
  from (
    select *, row_number() over(partition by ba_id order by current_package_date DESC) rk
    from `data-bi-prd-935c.bi_dm.tysg_ftth_cpp_orbit`
    where current_package_date = DATE_SUB(CURRENT_DATE('Asia/Jakarta'), Interval 1 day)
  ) a
  where rk = 1
) c
on a.ba_id=c.ba_id and a.dt_id=c.current_package_date
left join `data-bi-prd-935c.bi_dm.dim_ftth_customer_asset` d
on a.billing_account = d.ac_refr
left join `data-bi-prd-935c.bi_dm.mlg_ftth_product_catalog` e
on coalesce(c.product_after, b.current_package) = e.Product_Name;


drop table `data-bi-prd-935c.bi_dm.tysg_ftth_stg_subs_1`;
drop table `data-bi-prd-935c.bi_dm.tysg_temp_cpp_order`;
drop table `data-bi-prd-935c.bi_dm.tysg_temp_cpp_products`;
drop table `data-bi-prd-935c.bi_dm.tysg_temp_subs_orbit`;
drop table `data-bi-prd-935c.bi_dm.tysg_temp_change_product_dev`;