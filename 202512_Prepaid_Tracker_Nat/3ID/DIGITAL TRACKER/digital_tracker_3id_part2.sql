BEGIN
  declare vdt_id default @vdt_id;
  
  delete from `data-bi-prd-935c.bi_mart.digital_tracker_site` 
  where dt_id = date(vdt_id)
  and kpi_code in ('myim3_bima_mau_netadd','myim3_bima_mpu_netadd');


  insert into `data-bi-prd-935c.bi_mart.digital_tracker_site`(dt_id, brand, kpi_id, kpi_code, flag, site_id, metric, process_dt)
  with netadd as (
    SELECT 
    date(vdt_id) dt_id, 
    site_id, 
    kpi_id||'.01' as kpi_id,
    kpi_code||'_netadd' as kpi_code,
    sum(case 
        when dt_id = date(vdt_id) then a.metric  
          else 0 
    end) cm_val,
    sum(case 
        when dt_id = DATE_SUB(DATE_TRUNC(DATE(vdt_id), MONTH), INTERVAL 1 DAY)
          then a.metric else 0 
    end) lm_val,
    sum(case 
        when dt_id = date(vdt_id) then a.metric  
          else 0 
    end) - sum(case 
        when dt_id = DATE_SUB(DATE_TRUNC(DATE(vdt_id), MONTH), INTERVAL 1 DAY)
          then a.metric else 0 
    end) as net_add
    FROM `data-bi-prd-935c.bi_mart.digital_tracker_site` a 
    --change by Indra Maulana Ikhsan because mis.project_ioh_kpi_daily_tracker_national_wise is a part of part2 job and always updated when part2 done
    WHERE (dt_id = date(vdt_id)  or dt_id = DATE_SUB(DATE_TRUNC(DATE(vdt_id), MONTH), INTERVAL 1 DAY))
    AND kpi_code in ('myim3_bima_mau','myim3_bima_mpu')
    group by 1,2,3,4
  )
  select dt_id , 'TRI' brand, kpi_id, kpi_code, 'MTD' flag, site_id, sum(net_add) as metric, CURRENT_TIMESTAMP() AS process_dt 
  from netadd
  group by dt_id, kpi_id, kpi_code, site_id;
END