declare vdt_id date default @vdt_id; 
-- Primary Part
-- Saldo

delete from `data-bi-prd-935c.bi_dev.mis_snd_prisec_detail` 
     where kpi_name = 'primary' 
     and dt_id = vdt_id;  


insert into `data-bi-prd-935c.bi_dev.mis_snd_prisec_detail`
     
       select vdt_id dt_id
       ,bm_id
       ,mp3_id
       ,a.qr_code 
       ,'primary' kpi_name
       ,flag
       ,cast(sum(amount) as numeric)  kpi_value
       from `data-bi-prd-935c.bi_mart.mart_sales_productivity_mtd` a 
       left join `data-bi-prd-935c.bi_mart.angie_hrchy_dim_hst` hd   
       on hd.partner_id= a.qr_code --and hd.ret_hierarchy_type = 'ANGIE' --mis.angie_hrchy_dim_202311
       and hd.hrchy_type = 'MP3'
       where flag = 'primary_opt'
       and trx_dt_sk_id = vdt_id
       and hd.mth = date_trunc(vdt_id,month)
       group by 1,2,3,4,5,6;
      

insert into `data-bi-prd-935c.bi_dev.mis_snd_prisec_detail`
       select vdt_id dt_id
       ,bm_id
       ,mp3_id
       ,a.qr_code
       ,'primary' kpi_name
       ,flag
       ,cast(sum(amount) as numeric)  kpi_value
       from `data-bi-prd-935c.bi_mart.mart_sales_productivity_mtd` a 
       left join `data-bi-prd-935c.bi_mart.angie_hrchy_dim_hst` hd 
       on hd.partner_qr_cd= a.qr_code 
       and hd.hrchy_type = 'Retailer'
       where flag='primary_cuanweb'
       and trx_dt_sk_id = vdt_id
       and hd.mth = date_trunc(vdt_id,month)
       group by 1,2,3,4,5,6;
   
     
   insert into `data-bi-prd-935c.bi_dev.mis_snd_prisec_detail`     
        
   select  vdt_id dt_id,
     bm_id,
     mp3_id,
     adj.qr_code,
     'primary' kpi_name,
       'retailer_cashback' flag,   
     sum(kpi_value) value
   from  `data-bi-prd-935c.bi_mart.trd_trisakti_adjustment_daily` adj
   left join  `data-bi-prd-935c.bi_mart.angie_hrchy_dim_hst` ng 
   on adj.partner_id=ng.partner_id
   where  snp_dt_sk_id between date_trunc(vdt_id,month) and vdt_id
   and  ng.mth = date_trunc(vdt_id,month)
   and  is_inject = 'YES'
   group by 1,2,3,4,5,6;
          

-- data tuti

     insert into `data-bi-prd-935c.bi_dev.mis_snd_prisec_detail`(dt_id, bm_id, mp3_id,kpi_name,flag,value)
       
     select 
       vdt_id dt_id
       ,bm_id bm_prm_id
       ,prmid mp3_id
       ,'primary' kpi_name
       ,'sp0' flag
       ,sum(value) kpi_value
       from (
         select  attribute3 prmid,
            sum(case when a.item_Code like 'BP%' then item*qty*10000 else item*qty*500 end ) value
         from `data-dtptechm-prd-c7ca.dwh.erp_so_temp_v` a 
         left join `data-bi-prd-935c.bi_snd.pre_ref_list_alloc_3id` b 
         on a.item_code=b.item_Code 
         where date(time_release) between  date_trunc(vdt_id,month) and vdt_id
         and a.item_code like 'BP%'
         group by 1 
       ) x 
      left join `data-bi-prd-935c.bi_mart.angie_hrchy_dim_hst` hd 
      on hd.partner_id= x.prmid 
      where hd.mth = date_trunc(vdt_id,month)
      group by 1,2,3,4,5;


insert into `data-bi-prd-935c.bi_dev.mis_snd_prisec_detail`(dt_id, bm_id, mp3_id,kpi_name,flag,value)
  
     select 
       vdt_id dt_id
       ,bm_id bm_prm_id
       ,prmid mp3_id
       ,'primary' kpi_name
       ,'spv0' flag
       ,sum(value) kpi_value
       from (
         select  attribute3 prmid,
            sum(case when a.item_Code like 'BP%' then item*qty*10000 else item*qty*500 end ) value
         from `data-dtptechm-prd-c7ca.dwh.erp_so_temp_v` a 
         left join `data-bi-prd-935c.bi_snd.pre_ref_list_alloc_3id` b 
         on a.item_code=b.item_Code 
         where date(time_release) between  date_trunc(vdt_id,month) and vdt_id
         and a.item_code like 'VO%'
         group by 1 
       ) x 
      left join `data-bi-prd-935c.bi_mart.angie_hrchy_dim_hst` hd 
      on hd.partner_id= x.prmid --and hd.ret_hierarchy_type = 'ANGIE' --mis.angie_hrchy_dim_202311
      where hd.mth = date_trunc(vdt_id,month)
      group by 1,2,3,4,5;


-- secondary part

delete from `data-bi-prd-935c.bi_dev.mis_snd_prisec_detail` 
     where kpi_name = 'secondary' 
     and dt_id = vdt_id;  


insert into `data-bi-prd-935c.bi_dev.mis_snd_prisec_detail`(dt_id, bm_id, mp3_id, qr_code, kpi_name,flag,value)

     select  vdt_id dt_id,
       bm_id,
       mp3_id,
       a.partner_qr_cd ret_qrcode,
       'secondary' kpi_name,
       'saldo' flag,
       cast(sum(coalesce(value,0)) as numeric) kpi_value
     from `data-bi-prd-935c.bi_mart.project_ioh_secondary_outlet` a
     left join `data-bi-prd-935c.bi_mart.angie_hrchy_dim_hst` b 
     on b.partner_qr_cd = a.partner_qr_cd
     left join (
         select ret_qr_cd,site_id 
         from (
            select dt,ret_qr_cd,site_id,row_number() over (partition by ret_qr_cd order by dt desc) rnk
            from `data-bi-prd-935c.bi_mart.stg_v_map_tgt_ret_details_hist`
            where  site_id <> ''
           ) x where rnk = 1
        ) c 
     on a.partner_qr_cd=c.ret_qr_cd 
     where dt_sk_id between date_trunc(vdt_id,month) and vdt_id
     and b.mth = date_trunc(vdt_id,month)
     and secondary_category = 'SALDO'
     and coalesce(upper(b.bm_location),'CENTRAL WEST NORTH JKT') NOT IN ('DVM BM','3 STORE','3 BUSINESS','NA','POOL','SIM ONLINE','SOUTH JAKARTA TEST BM','ADVCREDIT','FUT ANGIE 2.0','MODCHAN','BSM TRI OFFICIAL STORE')
     and secondary_type in ('PRT_CUANWEB','Purchase from CAN','Purchase from MP3')
     group by 1,2,3,4,5,6;
     
       
insert into `data-bi-prd-935c.bi_dev.mis_snd_prisec_detail`(dt_id, bm_id, mp3_id, qr_code, kpi_name,flag,value)   
   
     select
      vdt_id dt_id,
      b.bm_id,
      b.mp3_id, 
      a.partner_qr_cd,
      'secondary' kpi_name,
      'return to mp3' flag,
      cast(sum(coalesce(value,0)) as numeric) kpi_value
     from `data-bi-prd-935c.bi_mart.project_ioh_secondary_outlet` a
     left join `data-bi-prd-935c.bi_mart.angie_hrchy_dim_hst` b 
     on b.partner_qr_cd = a.partner_qr_cd
     where dt_sk_id between date_trunc(vdt_id,month) and vdt_id
     and  secondary_type in ('RETURN TO MP3')
     and  secondary_category = 'SALDO'
     and  b.mth = date_trunc(vdt_id,month)
     group by 1,2,3,4,5,6; 
    
    
-- additional secondary
    
     insert into `data-bi-prd-935c.bi_dev.mis_snd_prisec_detail`(dt_id, bm_id, mp3_id, qr_code, kpi_name,flag,value)
           
     select  vdt_id trx_dt_Sk_id,
       b.bm_id,
       b.mp3_id, 
       b.partner_qr_cd, 
       'secondary' kpi_name,
       'spv0' as flag,
       cast(sum(gross_revenue) as numeric) rev  
     from `data-dtptechm-prd-c7ca.dwh.revenue_base` a 
     left join `data-bi-prd-935c.bi_mart.angie_hrchy_dim_hst` b
     on cast(a.angie_channel_sk_id as string) = b.angie_hrchy_sk_id
     where process_nm='UNLOCK'
     and service_type_category_1<>'UNLOCK'
     and b.mth = date_trunc(vdt_id,month)
     and date(trx_dt_Sk_id) between date_trunc(vdt_id,month) and vdt_id
     group by 1,2,3,4,5,6;


insert into `data-bi-prd-935c.bi_dev.mis_snd_prisec_detail`(dt_id, bm_id, mp3_id, qr_code, kpi_name,flag,value)

-- stop this part since blue marble case on june
--     select  vdt_id trx_dt_Sk_id,
--       b.bm_id,
--       b.mp3_id, 
--       b.partner_qr_cd, 
--       'secondary' kpi_name,
--       'sp0' as flag,
--       cast(sum(gross_revenue) as numeric) rev  
--     from `data-dtptechm-prd-c7ca.dwh.revenue_base` a 
--     left join `data-bi-prd-935c.bi_mart.angie_hrchy_dim_hst` b
--     on a.angie_channel_sk_id = b.angie_hrchy_sk_id
--     where process_nm='FRC'
--     and service_type_category_1<>'FRC'
--     and b.mth = date_trunc(vdt_id,month)
--     and trx_dt_Sk_id between date_trunc(vdt_id,month) and vdt_id
--     group by 1,2,3,4,5,6;
     
     select vdt_id trx_dt_sk_id, 
       b.bm_id,
       b.mp3_id, 
       b.partner_qr_cd, 
       'secondary' kpi_name,
       'sp0' as flag, 
       sum(coalesce(p3_cashback,0)) rev
     from `data-dtptechm-prd-c7ca.dwh.frc_stock` a
     left join `data-bi-prd-935c.bi_mart.angie_hrchy_dim_hst` b
     on cast(a.angie_hrchy_sk_id as string) = b.angie_hrchy_sk_id
     where date(stock_in_dtm) between date_trunc(vdt_id,month) and vdt_id
     and b.mth = date_trunc(vdt_id,month)
     group by 1,2,3,4,5,6;
    


      -- data bop
      
    insert into `data-bi-prd-935c.bi_dev.mis_snd_prisec_detail`

    select dt_id, bm_id, mp3_id, qr_code, 'secondary' kpi_name, flag, sum(value) value
    from `data-bi-prd-935c.bi_dev.mis_snd_prisec_detail`
    where dt_id = vdt_id
    and kpi_name = 'primary'
    and flag = 'retailer_cashback'
    group by 1,2,3,4,5,6;            
