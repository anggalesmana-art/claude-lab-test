declare vdt_id date default @vdt_id;

DELETE FROM `data-bi-prd-935c.bi_mart.new_site_tracking` WHERE yearth = '2026';
INSERT INTO `data-bi-prd-935c.bi_mart.new_site_tracking`
WITH
  t_temp AS (
    SELECT
      system_key,
      project_name project,
      site_id,
      new_site_id,
      site_category category,
      vendor_code vendor,
      parse_date('%m/%d/%Y', rfs_actual) oa_ns,
      0 long,
      0 lat,
      '' remark,
      '' file_name,
      year yearth
    FROM `data-bi-prd-935c.bi_dm.ds_ran_tracker_2026`
    WHERE
      safe.parse_date('%m/%d/%Y', rfs_actual)
        <= '2026-12-31'
      AND lower(ran_score) LIKE 'new site 2026 aop'
      AND year = '2026'
  )
SELECT * FROM t_temp;

delete from `data-bi-prd-935c.bi_mart`.kpi_national_tracker_dly
where kpi_id in (
'DST0047',
'DST0053',
'DST0042',
'DST0031',
'DST0034',
'DST0048',
'DST0036',
'DST0033',
'DST0040',
'DST0054',
'DST0028',
'DST0051',
'DST0045',
'DST0039',
'DST0052',
'DST0046',
'DST0043',
'DST0030',
'DST0049',
'DST0035',
'DST0037',
'DST0032',
'DST0029',
'DST0041',
'DST0038',
'DST0044',
'DST0050'
) and dt_id = vdt_id;
insert into `data-bi-prd-935c.bi_mart`.kpi_national_tracker_dly
with site_summary as (
  select * except(oa_ns), safe.parse_date('%Y%m%d',LEFT(oa_ns,8)) oa_ns from `data-bi-prd-935c.bi_snd.pre_raw_lrs_ioh` WHERE prt_dt = vdt_id
),
new_site as (
  select * from `data-bi-prd-935c.bi_mart`.new_site_tracking
),
fnl as (

  -- IOH
  select vdt_id dt_id, 'IOH' brand, 'DST0028' kpi_id, 'total_site' kpi_code, 'MTD' flag , sum(kpi_metric) kpi_metric
  from (
    select coalesce(count(distinct site_id),0) kpi_metric
    from new_site
    where oa_ns between date_trunc(vdt_id,month)  and vdt_id
    union all
    SELECT sum(total_site) kpi_metric
    from site_summary
    where oa_ns is null or oa_ns <  date_trunc(vdt_id,month) 
    ) temp
  union all
  select vdt_id dt_id, 'IOH' brand, 'DST0029' kpi_id, 'new_site_rolled_out' kpi_code, 'MTD' flag , coalesce(count(distinct site_id),0) kpi_metric
  from new_site
  where oa_ns between date_trunc(vdt_id,month)  and vdt_id
  union all
  SELECT vdt_id dt_id, 'IOH' brand, 'DST0030' kpi_id, 'total_site_base' kpi_code, 'MTD' flag , sum(total_site) kpi_metric
  from site_summary
  where oa_ns is null or oa_ns <  date_trunc(vdt_id,month) 
  union all
  SELECT  vdt_id dt_id, 'IOH' brand, 'DST0031' kpi_id, 'total_addressable_site' kpi_code, 'MTD' flag , sum(addressable_site_count) kpi_metric
  from site_summary
  where  lower(trim(addressable)) like 'add%'
  union all
  SELECT  vdt_id dt_id, 'IOH' brand, 'DST0032' kpi_id, 'total_addressable_new_site' kpi_code, 'MTD' flag , coalesce(sum(addressable_site_count),0) kpi_metric
  from site_summary
  where oa_ns >=  date_trunc(vdt_id,month)  and  
  lower(trim(addressable)) like 'add%'
  union all
  SELECT  vdt_id dt_id, 'IOH' brand, 'DST0033' kpi_id, 'total_addressable_base_site' kpi_code, 'MTD' flag , sum(addressable_site_count) kpi_metric
  from site_summary
  where  (oa_ns is null or oa_ns <  date_trunc(vdt_id,month))  and 
  lower(trim(addressable)) like 'add%'
  union all
  SELECT  vdt_id dt_id, 'IOH' brand, 'DST0034' kpi_id, 'total_addressable_site_lrs' kpi_code, 'MTD' flag , sum(total_site) kpi_metric
  from site_summary
  where  lower(trim(addressable)) like 'add%' and lrs_flag_ioh = 'LRS'
  union all
  SELECT  vdt_id dt_id, 'IOH' brand, 'DST0035' kpi_id, 'total_addressable_new_site_lrs' kpi_code, 'MTD' flag , coalesce(sum(total_site),0) kpi_metric
  from site_summary
  where oa_ns >=  date_trunc(vdt_id,month)  and lower(trim(addressable)) like 'add%' and lrs_flag_ioh = 'LRS'
  union all
  SELECT  vdt_id dt_id, 'IOH' brand, 'DST0036' kpi_id, 'total_addressable_base_site_lrs' kpi_code, 'MTD' flag , sum(total_site) kpi_metric
  from site_summary
  where (oa_ns is null or oa_ns <  date_trunc(vdt_id,month))  and 
  lower(trim(addressable)) like 'add%' and lrs_flag_ioh = 'LRS'

  -- IM3
   union all
  select vdt_id dt_id, 'IM3' brand, 'DST0037' kpi_id, 'total_site' kpi_code, 'MTD' flag , sum(kpi_metric) kpi_metric
  from (
    select coalesce(count(distinct site_id),0) kpi_metric
    from new_site
    where oa_ns between date_trunc(vdt_id,month)  and vdt_id 
    union all
    SELECT sum(total_site) kpi_metric
    from site_summary
    where oa_ns is null or oa_ns <  date_trunc(vdt_id,month)
  ) temp
  union all
  select vdt_id dt_id, 'IM3' brand, 'DST0038' kpi_id, 'new_site_rolled_out' kpi_code, 'MTD' flag , coalesce(count(distinct site_id),0) kpi_metric
  from new_site
  where oa_ns between date_trunc(vdt_id,month)  and vdt_id 
  union all
  SELECT vdt_id dt_id, 'IM3' brand, 'DST0039' kpi_id, 'total_site_base' kpi_code, 'MTD' flag , sum(total_site) kpi_metric
  from site_summary
  where oa_ns is null or oa_ns <  date_trunc(vdt_id,month) 
  union all
  SELECT vdt_id dt_id, 'IM3' brand, 'DST0040' kpi_id, 'total_addressable_site' kpi_code, 'MTD' flag , sum(total_site) kpi_metric
  from site_summary
  where  lower(trim(addressable)) like 'add%'
  union all
  SELECT vdt_id dt_id, 'IM3' brand, 'DST0041' kpi_id, 'total_addressable_new_site' kpi_code, 'MTD' flag , coalesce(sum(total_site),0) kpi_metric
  from site_summary
  where oa_ns >=  date_trunc(vdt_id,month)  and 
  lower(trim(addressable)) like 'add%'
  union all
  SELECT vdt_id dt_id, 'IM3' brand, 'DST0042' kpi_id, 'total_addressable_base_site' kpi_code, 'MTD' flag , sum(total_site) kpi_metric
  from site_summary
  where (oa_ns is null or oa_ns <  date_trunc(vdt_id,month))  and 
  lower(trim(addressable)) like 'add%'
  union all
  SELECT vdt_id dt_id, 'IM3' brand, 'DST0043' kpi_id, 'total_addressable_site_lrs' kpi_code, 'MTD' flag , sum(total_site) kpi_metric
  from site_summary
  where  lower(trim(addressable)) like 'add%' and lrs_flag_im3 = 'LRS'
  union all
  SELECT  vdt_id dt_id, 'IM3' brand, 'DST0044' kpi_id, 'total_addressable_new_site_lrs' kpi_code, 'MTD' flag , coalesce(sum(total_site),0) kpi_metric
  from site_summary
  where oa_ns >=  date_trunc(vdt_id,month)  and 
  lower(trim(addressable)) like 'add%' and lrs_flag_im3 = 'LRS'
  union all
  SELECT  vdt_id dt_id, 'IM3' brand, 'DST0045' kpi_id, 'total_addressable_base_site_lrs' kpi_code, 'MTD' flag , sum(total_site) kpi_metric
  from site_summary
  where (oa_ns is null or oa_ns <  date_trunc(vdt_id,month))  and 
  lower(trim(addressable)) like 'add%' and lrs_flag_im3 = 'LRS'
  union all
  -- TRI
  select vdt_id dt_id, 'TRI' brand, 'DST0046' kpi_id, 'total_site' kpi_code, 'MTD' flag , sum(kpi_metric) kpi_metric
  from (
    select coalesce(count(distinct site_id),0) kpi_metric
    from new_site
    where oa_ns between date_trunc(vdt_id,month)  and vdt_id 
    union all
    SELECT sum(total_site) kpi_metric
    from site_summary
    where oa_ns is null or oa_ns <  date_trunc(vdt_id,month) 
  ) temp
  union all
  select vdt_id dt_id, 'TRI' brand, 'DST0047' kpi_id, 'new_site_rolled_out' kpi_code, 'MTD' flag , coalesce(count(distinct site_id),0) kpi_metric
  from new_site
  where oa_ns between date_trunc(vdt_id,month)  and vdt_id 
  union all
  SELECT  vdt_id dt_id, 'TRI' brand, 'DST0048' kpi_id, 'total_site_base' kpi_code, 'MTD' flag , sum(total_site) kpi_metric
  from site_summary
  where oa_ns is null or oa_ns <  date_trunc(vdt_id,month) 
  union all
  SELECT  vdt_id dt_id, 'TRI' brand, 'DST0049' kpi_id, 'total_addressable_site' kpi_code, 'MTD' flag , sum(total_site) kpi_metric
  from site_summary
  where  lower(trim(addressable)) like 'add%'
  union all
  SELECT  vdt_id dt_id, 'TRI' brand, 'DST0050' kpi_id, 'total_addressable_new_site' kpi_code, 'MTD' flag , coalesce(sum(total_site),0) kpi_metric
  from site_summary
  where oa_ns >=  date_trunc(vdt_id,month)  and 
  lower(trim(addressable)) like 'add%'
  union all
  SELECT  vdt_id dt_id, 'TRI' brand, 'DST0051' kpi_id, 'total_addressable_base_site' kpi_code, 'MTD' flag , sum(total_site) kpi_metric
  from site_summary
  where (oa_ns is null or oa_ns <  date_trunc(vdt_id,month))  and 
  lower(trim(addressable)) like 'add%'
  union all
  SELECT  vdt_id dt_id, 'TRI' brand, 'DST0052' kpi_id, 'total_addressable_site_lrs' kpi_code, 'MTD' flag , sum(total_site) kpi_metric
  from site_summary
  where  lower(trim(addressable)) like 'add%' and lrs_flag_tri = 'LRS'
  union all
  SELECT  vdt_id dt_id, 'TRI' brand, 'DST0053' kpi_id, 'total_addressable_new_site_lrs' kpi_code, 'MTD' flag , coalesce(sum(total_site),0) kpi_metric
  from site_summary
  where oa_ns >=  date_trunc(vdt_id,month)  and 
  lower(trim(addressable)) like 'add%' and lrs_flag_tri = 'LRS'
  union all
  SELECT  vdt_id dt_id, 'TRI' brand, 'DST0054' kpi_id, 'total_addressable_base_site_lrs' kpi_code, 'MTD' flag , sum(total_site) kpi_metric
  from site_summary
  where (oa_ns is null or oa_ns <  date_trunc(vdt_id,month))  and  
  lower(trim(addressable)) like 'add%' and lrs_flag_tri = 'LRS'
)
select brand, kpi_code, flag, kpi_metric, timestamp(current_datetime('+7')) process_dt, kpi_id, dt_id from fnl
;