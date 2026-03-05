-- Done changed Arie
BEGIN
    declare vdt_id date default @vdt_id;
    delete from `data-bi-prd-935c.bi_mart.ioh_snd_master_kpi_dig_smy` 
    where dt_id = date(vdt_id) 
    and kpi_code in ('myim3_bima_mau_netadd','myim3_bima_mpu_netadd');

    /*** calculate NET ADD  ***/
    insert into `data-bi-prd-935c.bi_mart.ioh_snd_master_kpi_dig_smy`
    with netadd as (
        select 
        date(vdt_id) as dt_id,
        concat(kpi_code,'_netadd') as kpi_code,
        a.brand, 
        a.circle, 
        a.region, 
        a.area, 
        a.branch,
        a.cluster,
        sum(case 
        when dt_id = DATE_SUB(DATE_TRUNC(date(vdt_id), MONTH), INTERVAL 1 DAY)
        then a.val else 0 end) as lm_val,
        sum(case when dt_id = date(vdt_id) then a.val else 0 end) as cm_val
        from `data-bi-prd-935c.bi_mart.ioh_snd_master_kpi_dig_smy` a 
        where dt_id in (
        /** last eom **/
        DATE_SUB(DATE_TRUNC(date(vdt_id), MONTH), INTERVAL 1 DAY),
        /** curr month **/
        date(vdt_id)
        ) AND kpi_code in ('myim3_bima_mau','myim3_bima_mpu')
        group by 2,3,4,5,6,7,8
    )
    select a.brand, a.circle, a.region, a.area, a.branch, a.cluster, SUM(cm_val - lm_val) val, CURRENT_TIMESTAMP(), a.kpi_code, a.dt_id 
    from netadd a
    group by 1,2,3,4,5,6,9,10;
END