delete from `data-bi-prd-935c.bi_dm.technocom_raw_kpi_master`
where dt_id=parse_date('%Y%m%d','{dt_id}')
; 

insert into `data-bi-prd-935c.bi_dm.technocom_raw_kpi_master`
with t_ref_kec as
  (
  select
  distinct
  parse_date('%Y%m%d','{dt_id}') as dt_id,kabkot_nm,'IM3' brand 
  from  `data-bi-prd-935c.bi_mart.ref_kecamatan` 
  union all 
  select
  distinct
  parse_date('%Y%m%d','{dt_id}') as dt_id,kabkot_nm,'3ID' brand
  from  `data-bi-prd-935c.bi_mart.ref_kecamatan`  
  union all 
  select
  distinct
  parse_date('%Y%m%d','{dt_id}') as dt_id,kabkot_nm,'TELKOMSEL' brand
  from  `data-bi-prd-935c.bi_mart.ref_kecamatan`  
  union all 
  select
  distinct
  parse_date('%Y%m%d','{dt_id}') as dt_id,kabkot_nm,'XL' brand
  from  `data-bi-prd-935c.bi_mart.ref_kecamatan`  
  union all 
  select
  distinct
  parse_date('%Y%m%d','{dt_id}') as dt_id,kabkot_nm,'SMARTFREN' brand
  from  `data-bi-prd-935c.bi_mart.ref_kecamatan` 
  )
  -- select * from t_ref_kec limit 10
,t_fb_dt as 
  (
  select 
  date_trunc( wk_end_dt,month) as wk_end_dt2,
  max(wk_end_dt) wk_end_dt
  from `data-network-prd-t7nb.cxe.facebook_network_insight_wly` 
  where object_level = 'kabkot' and date_trunc(wk_end_dt,month) = date_trunc(parse_date('%Y%m%d','{dt_id}'),month)  
  group by 1
  )
, t_fb_exp_4g as
  (
  select
	  parse_date('%Y%m%d','{dt_id}') dt_id,
	  cast(wk_end_dt as string) as meas_dt,
	  object_name kabkot_nm,
	  case 
	  when brand = '3' then '3ID' else brand end as brand,
	  -- circle,
	  -- region,
	  sum(cast(dl_speed_median as numeric)) dl_speed_median_fb,
	  sum(cast(dl_speed_low as numeric)) dl_speed_low_fb,
	  sum(cast(dl_speed_high as numeric)) dl_speed_high_fb,
	  sum(cast(latency as numeric)) latency_fb,
	  sum(cast(rtt as numeric)) rtt_fb,
	  sum(cast(rsrq as numeric)) rsrq_fb,
	  sum(cast(network_gen as numeric)) network_gen_fb ,
	  sum(cast(signal_strength as numeric)) signal_strength_fb,
	  sum(cast(sample as numeric)) sample_fb
  from `data-network-prd-t7nb.cxe.facebook_network_insight_wly` a
  -- left join t_ref_kec b on a.object_name = b.kabkot_nm 
  where  wk_end_dt in (select wk_end_dt from t_fb_dt)
  and object_level = 'kabkot' and tech = '4G'  
  group by all
  )
--   select * from t_fb_exp_4g limit 100
, t_opensignal_dt as
  (
  select 
  date_trunc(date(end_date),month) as month_id,
  max(end_date) end_date
  from `data-network-prd-t7nb.cxe.opensignal_onx_wly`
  where granul_level = '30' and obj_level = 'kabupaten' and date_trunc(date(end_date),month) = date_trunc(parse_date('%Y%m%d','{dt_id}'),month)  
  group by 1 
  )  
, t_opensignal_exp as 
  (
  select 
	  parse_date('%Y%m%d','{dt_id}') dt_id,
	  cast(end_date as string) as meas_dt,
	  location kabkot_nm,
	  case 
	  when device_simserviceproviderbrandname = 'Telkomsel' then 'TELKOMSEL'
	  when device_simserviceproviderbrandname = 'Indosat' then 'IM3'
	  when device_simserviceproviderbrandname = '3' then '3ID'
	  when device_simserviceproviderbrandname = 'Smartfren' then 'SMARTFREN'
	  else device_simserviceproviderbrandname end as brand,
	  sum(cast(mean_videoexperience_overall as numeric)) mean_videoexperience_overall_os,
	  sum(cast(mean_voiceappexperience_overall as numeric)) mean_voiceappexperience_overall_os,
	  sum(cast(mean_gamesexperience_overall as numeric)) mean_gamesexperience_overall_os,
	  sum(cast(mean_downloadspeed_overall as numeric)) mean_downloadspeed_overall_os,
	  sum(cast(percent_ccq_overall as numeric)) percent_ccq_overall_os
	  from `data-network-prd-t7nb.cxe.opensignal_onx_wly` a
	  where granul_level = '30' and obj_level = 'kabupaten' 
	  and end_date in (select end_date from t_opensignal_dt)
	  group by all
  )
-- select * from t_opensignal_exp   limit 100
  ,
t_ookla_dt as
  (
  select date_trunc(date(ts_aggregate_date), month) month_id,
  max (ts_aggregate_date) ts_aggregate_date
  -- from `data-network-prd-t7nb.cxe.ookla_sci_agg_mly` 
  -- where date_trunc(date(ts_aggregate_date ),month)  = month_dt
  from `data-network-prd-t7nb.cxe.ookla_sci_agg_wly` 
  where date_trunc(date(ts_aggregate_date ),month)  = date_trunc(parse_date('%Y%m%d','{dt_id}'), month)
  group by 1
  ),
t_ookla_exp  as
  (
  select 
	  PARSE_DATE('%Y%m%d','{dt_id}') AS dt_id,
	  CAST(ts_aggregate_date AS STRING) AS meas_dt,
	  b.kabkot_nm,
	  case 
	  when upper(attr_provider_name) = 'IM3 OOREDOO' then 'IM3'
	  when upper(attr_provider_name) = '3' then '3ID'
	  when upper(attr_provider_name) = 'TELKOMSEL' then 'TELKOMSEL'
	  when upper(attr_provider_name) in ('XL','AXIS') then 'XL'
	  when upper(attr_provider_name) = 'SMARTFREN' then 'SMARTFREN'
	  else 'Others' end brand,
	  sum(CAST(val_total_test_count as numeric)) val_total_test_count_ookla,
	  sum(CAST(val_total_device_count as numeric)) val_total_device_count_ookla,
	  sum(CAST(val_overall_connectivity_score as numeric)) val_overall_connectivity_score_ookla,
	  sum(CAST(val_video_streaming_score as numeric)) val_video_streaming_score_ookla,
	  sum(CAST(val_video_streaming_score_sample_count as numeric)) val_video_streaming_score_sample_count_ookla,
	  sum(CAST(val_video_streaming_score_test_count as numeric)) val_video_streaming_score_test_count_ookla,
	  sum(CAST(val_web_browsing_score as numeric)) val_web_browsing_score_ookla,
	  sum(CAST(val_web_browsing_score_sample_count as numeric)) val_web_browsing_score_sample_count_ookla,
	  sum(CAST(val_web_browsing_score_test_count as numeric)) val_web_browsing_score_test_count_ookla,
	  sum(CAST(val_speed_score as numeric)) val_speed_score_ookla,
	  sum(CAST(val_performance_sample_count as numeric)) val_performance_sample_count_ookla,
	  sum(CAST(val_performance_test_count as numeric)) val_performance_test_count_ookla,
	  sum(CAST(val_percentage_quick_video_start_p as numeric)) val_percentage_quick_video_start_p_ookla,
	  sum(CAST(val_percentage_uninterupted_playback_p as numeric)) val_percentage_uninterupted_playback_p_ookla,
	  sum(CAST(val_percentage_full_hd_resolution_p as numeric)) val_percentage_full_hd_resolution_p_ookla,
	  sum(CAST(val_web_page_load_time_ms as numeric)) val_web_page_load_time_ms_ookla,
	  sum(CAST(val_p90_cdn_latency_ms as numeric)) val_p90_cdn_latency_ms_ookla,
	  sum(CAST(val_cdn_latency_sample_count as numeric)) val_cdn_latency_sample_count_ookla,
	  sum(CAST(val_p90_video_conferencing_latency_ms as numeric)) val_p90_video_conferencing_latency_ms_ookla,
	  sum(CAST(val_video_conferencing_latency_sample_count as numeric)) val_video_conferencing_latency_sample_count_ookla,
	  sum(CAST(val_p90_cloud_infrastructure_latency_ms as numeric)) val_p90_cloud_infrastructure_latency_ms_ookla,
	  sum(CAST(val_cloud_infrastructure_latency_sample_count as numeric)) val_cloud_infrastructure_latency_sample_count_ookla,
	  sum(CAST(val_p90_cdn_jitter_ms as numeric)) val_p90_cdn_jitter_ms_ookla,
	  sum(CAST(val_cdn_jitter_sample_count as numeric)) val_cdn_jitter_sample_count_ookla,
	  sum(CAST(val_p90_video_conferencing_jitter_ms as numeric)) val_p90_video_conferencing_jitter_ms_ookla,
	  sum(CAST(val_video_conferencing_jitter_sample_count as numeric)) val_video_conferencing_jitter_sample_count_ookla,
	  sum(CAST(val_p90_cloud_infrastructure_jitter_ms as numeric)) val_p90_cloud_infrastructure_jitter_ms_ookla,
	  sum(CAST(val_cloud_infrastructure_jitter_sample_count as numeric)) val_cloud_infrastructure_jitter_sample_count_ookla,
	  sum(CAST(val_p10_download_speed_mbps as numeric)) val_p10_download_speed_mbps_ookla,
	  sum(CAST(val_median_download_speed_mbps as numeric)) val_median_download_speed_mbps_ookla,
	  sum(CAST(val_p90_download_speed_mbps as numeric)) val_p90_download_speed_mbps_ookla,
	  sum(CAST(val_download_speed_sample_count as numeric)) val_download_speed_sample_count_ookla,
	  sum(CAST(val_p10_upload_speed_mbps as numeric)) val_p10_upload_speed_mbps_ookla,
	  sum(CAST(val_median_upload_speed_mbps as numeric)) val_median_upload_speed_mbps_ookla,
	  sum(CAST(val_p90_upload_speed_mbps as numeric)) val_p90_upload_speed_mbps_ookla,
	  sum(CAST(val_upload_speed_sample_count as numeric)) val_upload_speed_sample_count_ookla,
	  sum(CAST(val_p10_primary_server_download_loaded_latency_ms as numeric)) val_p10_primary_server_download_loaded_latency_ms_ookla,
	  sum(CAST(val_median_primary_server_download_loaded_latency_ms as numeric)) val_median_primary_server_download_loaded_latency_ms_ookla,
	  sum(CAST(val_p90_primary_server_download_loaded_latency_ms as numeric)) val_p90_primary_server_download_loaded_latency_ms_ookla,
	  sum(CAST(val_primary_server_download_loaded_latency_sample_count as numeric)) val_primary_server_download_loaded_latency_sample_count_ookla,
	  sum(CAST(val_p10_primary_server_upload_loaded_latency_ms as numeric)) val_p10_primary_server_upload_loaded_latency_ms_ookla,
	  sum(CAST(val_median_primary_server_upload_loaded_latency_ms as numeric)) val_median_primary_server_upload_loaded_latency_ms_ookla,
	  sum(CAST(val_p90_primary_server_upload_loaded_latency_ms as numeric)) val_p90_primary_server_upload_loaded_latency_ms_ookla,
	  sum(CAST(val_primary_server_upload_loaded_latency_sample_count as numeric)) val_primary_server_upload_loaded_latency_sample_count_ookla
  -- from `data-network-prd-t7nb.cxe.ookla_sci_agg_mly` a
  from `data-network-prd-t7nb.cxe.ookla_sci_agg_wly` a
  left join `data-bi-prd-935c.bi_dm.ds_ookla_kabupaten` b on a.attr_place_name = b.attr_place_name
  where 
  attr_place_type = 'administrative_area_level_2' 
  and ts_aggregate_date in (select ts_aggregate_date from t_ookla_dt)
  and upper(attr_provider_name) in ('IM3 OOREDOO','TELKOMSEL','XL', 'AXIS', 'SMARTFREN','3' ) 
  and attr_mobile_technologies_filter = 'All Cell' 
  group by all
  )
-- select * from t_ookla_exp   limit 100
, t_fb_share_dt as
  (
  select 
  date_trunc(dt_id, month) month_id ,
  max(dt_id) dt_id
  from `data-bi-prd-935c.bi_mart.fb_market_share`
  where kpi_nm = 'Kabupaten Kota 2022' and date_trunc(dt_id,month) = date_trunc(parse_date('%Y%m%d', '{dt_id}'), month) 
  group by 1  
  ),
  t_fb_share as
  (
  select 
	  PARSE_DATE('%Y%m%d','{dt_id}') AS dt_id,
	  CAST(dt_id AS STRING) AS meas_dt,
	  locations kabkot_nm,
	  case 
	  when operator = 'HUTCHISON' then '3ID' 
	  when operator = 'INDOSAT' then 'IM3'
	  when operator = 'XL' then 'XL' 
	  when operator = 'TELKOMSEL' then 'TELKOMSEL'
	  when operator = 'SMARTFREN' then 'SMARTFREN'
	  else 'OTHER' end brand,
	  cast(base_ori_abs as numeric) base_ori_abs_fb,
	  cast(base_norm_abs as numeric) base_norm_abs_fb,
	  cast(ga_ori_abs as numeric) ga_ori_abs_fb,
	  cast(ga_norm_abs as numeric) ga_norm_abs_fb,
	  cast(churn_ori_abs as numeric) churn_ori_abs_fb,
	  cast(churn_norm_abs as numeric) churn_norm_abs_fb
  from `data-bi-prd-935c.bi_mart.fb_market_share`
  where kpi_nm = 'Kabupaten Kota 2022' and dt_id  in (select dt_id from t_fb_share_dt)
  )
--   select * from t_fb_share   limit 100
, t_technocomm_dt as
  (
  select  date_trunc(dt_id, month) as month_id,
  max(dt_id) dt_id,
  max(weekid) weekid 
  from `data-bi-prd-935c.bi_mart.ioh_technocomm`
  -- where date_trunc(date(dt_id),month) = '2025-11-01'
  where date_trunc(date(dt_id),month) = date_trunc(parse_date('%Y%m%d', '{dt_id}'), month)
  and not (weekid = '202540' and date(dt_id)  = '2025-09-30')
  group by 1
  ),
t_technocomm as
  (
  select
	  PARSE_DATE('%Y%m%d','{dt_id}') AS dt_id,
	  CAST(dt_id AS STRING) AS meas_dt,
	  kabkot_nm,
	  'IM3' brand,
	  sum(cast(total_cell as numeric)) total_cell,
	  sum(cast(cell_900 as numeric)) cell_900,
	  sum(cast(cell_1800 as numeric)) cell_1800,
	  sum(cast(cell_2100 as numeric)) cell_2100,
	  sum(cast(vol_capacity_gb as numeric)) vol_capacity_gb,
	  sum(cast(vol_wd_gb as numeric)) vol_wd_gb,
	  sum(cast(total_complaint as numeric)) total_complaint,
	  sum(cast(network_complaint as numeric)) network_complaint,
	  cast(count(distinct if(upper(grid_status) = 'GREEN' ,grid_id,null)) as numeric) green_grids, 
	  sum(cast (avail5g_num as numeric)) avail5g_num,
	  sum(cast(avail5g_denum as numeric))avail5g_denum,
	  sum(cast(avail5g_lowsite99_monthly as numeric)) avail5g_lowsite99_monthly,
	  sum(cast (avail4g_num as numeric)) avail4g_num,
	  sum(cast(avail4g_denum as numeric))avail4g_denum,
	  sum(cast(avail4g_lowsite99_monthly as numeric)) avail4g_lowsite99_monthly,
	  sum(cast (avail2g_num as numeric)) avail2g_num,
	  sum(cast(avail2g_denum as numeric))avail2g_denum,
	  sum(cast(avail2g_lowsite99_monthly as numeric)) avail2g_lowsite99_monthly,
	  sum(cast(rsrp_4week as numeric)) rsrp_4week_num,
	  cast(sum(case when cast(rsrp_4week as numeric)  > -200 then 1 else 0 end) as numeric) rsrp_4week_denum,
	  sum(cast(rsrp_lowsite_cons4wk as numeric)) rsrp_lowsite_cons4wk,
	  sum(cast(prbnum_4week as numeric))  prbnum_4week,
	  sum(cast(prbdenum_4week as numeric)) prbdenum_4week,
	  sum(cast(eutnum_4week as numeric)) eutnum_4week,
	  sum(cast(eutdenum_4week as numeric)) eutdenum_4week,
	  sum(cast(eutprb_lowsite_cons4wk as numeric)) eutprb_lowsite_cons4wk,
	  sum(cast(suppress_lowsite_cons4wk as numeric)) suppress_lowsite_cons4wk,
	  sum(cast(vid_tput_avg4week as numeric))  vid_tput_avg4week_num,
	  cast(sum(case when cast(vid_tput_avg4week as numeric) > 0 then 1 else 0 end) as numeric)  vid_tput_avg4week_denum,
	  sum(cast(vid_delay_avg4week as numeric)) vid_delay_avg4week_num,
	  cast(sum(case when cast(vid_delay_avg4week as numeric) > 0 then 1 else 0 end) as numeric) vid_delay_avg4week_denum,
	  sum(cast(vid_tputdelay_lowsite_cons4wk as numeric)) vid_tputdelay_lowsite_cons4wk,
	  sum(cast(voice_2g_acore_avg4week as numeric) ) voice_2g_acore_avg4week_num,
	  cast(sum(case when cast(voice_2g_acore_avg4week as numeric) > 0 then 1 else 0 end) as numeric) voice_2g_acore_avg4week_denum,
	  sum(cast(voice_2g_lowsite70_cons4wk as numeric)) voice_2g_lowsite70_cons4wk,
	  sum(cast(voice_4g_score_avg4week as numeric)) voice_4g_score_avg4week_num,
	  cast(sum(case when cast(voice_4g_score_avg4week as numeric) > 0 then 1 else 0 end) as numeric) voice_4g_score_avg4week_denum,
	  sum(cast(voice_4g_lowsite80_cons4wk as numeric)) voice_4g_lowsite80_cons4wk,
	  sum(cast(volte_lowsite_cons4wk as numeric)) volte_lowsite_cons4wk,
	  sum(cast(total_site_ioh as numeric)) total_site_ioh,
	  sum(cast(site_5g as numeric)) site_5g,
	  sum(cast(vol_gb_mtd as numeric) ) vol_gb_mtd,
	  sum(cast(vol_gb_ytd as numeric) ) vol_gb_ytd,
	  sum(cast(vol_gb_lytd as numeric) ) vol_gb_lytd,
	  sum(cast(vlr as numeric)) vlr,
	  sum(cast(rgu90d as numeric)) rgu90d,
	  sum(cast(churn90d as numeric)) churn90d,
	  sum(cast(churnback90d as numeric)) churnback90d,
	  sum(cast(rgu90d_180dplus as numeric)) rgu90d_180dplus,
	  sum(cast(churn90d_180dplus as numeric)) churn90d_180dplus,
	  sum(cast(churnback90d_180dplus as numeric)) churnback90d_180dplus,
	  sum(cast(rgu90d_mtd as numeric)) rgu90d_mtd,
	  sum(cast(churn90d_mtd as numeric)) churn90d_mtd,
	  sum(cast(churnback90d_mtd as numeric)) churnback90d_mtd,
	  sum(cast(rgu90d_180dplus_mtd as numeric)) rgu90d_180dplus_mtd,
	  sum(cast(churn90d_180dplus_mtd as numeric)) churn90d_180dplus_mtd,
	  sum(cast(churnback90d_180dplus_mtd as numeric)) churnback90d_180dplus_mtd,
	  sum(cast(grossadd as numeric )) grossadd,
	  sum(cast(total_revenue as numeric)) total_revenue,
	  sum(cast(data_revenue as numeric)) data_revenue
  from `data-bi-prd-935c.bi_mart.ioh_technocomm` a 
  --  left join `data-bi-prd-935c.bi_dm.ref_site` b on a.site_id = b.site_id
  where 
  date(dt_id) in  (select date(dt_id) dt_id from t_technocomm_dt)
  and weekid in (select  weekid from t_technocomm_dt)
  group by all
  )
-- select * from t_technocomm limit 10 
, t_exp_stream_session as 
  (
  SELECT 
	  PARSE_DATE('%Y%m%d','{dt_id}') AS dt_id,
	  CAST(max(dt_id) AS STRING) AS meas_dt,
	  b.kabkot_nm,
	  'IM3' brand,
	  cast(count(DISTINCT dt_id) as numeric) day_count_strm,
	  sum(cast(total_traffic_gb as numeric)) total_traffic_gb_strm,
	  sum(cast(total_video_traffic_gb as numeric)) total_video_traffic_gb_strm,
	  sum(cast(average_video_traffic_gb as numeric)) average_video_traffic_gb_strm,
	  sum(cast(video_streaming_dw_throughput_mbps as numeric)) video_streaming_dw_throughput_mbps_strm,
	  sum(cast(video_streaming_xkb_start_delay_ms as numeric)) video_streaming_xkb_start_delay_ms_strm,
	  sum(cast(video_streaming_stall_rate as numeric)) video_streaming_stall_rate_strm,
	  sum(cast(streaming_dw_packets as numeric)) streaming_dw_packets_strm,
	  sum(cast(streaming_download_delay as numeric)) streaming_download_delay_strm,
	  sum(cast(video_total_start_delay as numeric)) video_total_start_delay_strm,
	  sum(cast(video_start_times as numeric)) video_start_times_strm,
	  sum(cast(stall_duration as numeric)) stall_duration_strm,
	  sum(cast(play_duration as numeric)) play_duration_strm,
	  sum(cast(total_subs as numeric)) total_subs_strm,
	  sum(cast(count_subs_in_360p as numeric)) count_subs_in_360p_strm,
	  sum(cast(count_subs_in_480p as numeric)) count_subs_in_480p_strm,
	  sum(cast(count_subs_in_720p as numeric)) count_subs_in_720p_strm,
	  sum(cast(count_subs_in_1080p as numeric)) count_subs_in_1080p_strm,
	  sum(cast(count_subs_in_1440p as numeric)) count_subs_in_1440p_strm,
	  sum(cast(total_video_traffic_gb_in_in_360p as numeric)) total_video_traffic_gb_in_in_360p_strm,
	  sum(cast(total_video_traffic_gb_in_in_480p as numeric)) total_video_traffic_gb_in_in_480p_strm,
	  sum(cast(total_video_traffic_gb_in_in_720p as numeric)) total_video_traffic_gb_in_in_720p_strm,
	  sum(cast(total_video_traffic_gb_in_in_1080p as numeric)) total_video_traffic_gb_in_in_1080p_strm,
	  sum(cast(total_video_traffic_gb_in_in_1440p as numeric)) total_video_traffic_gb_in_in_1440p_strm,
	  sum(cast(count_session_in_360p as numeric)) count_session_in_360p_strm,
	  sum(cast(count_session_in_480p as numeric)) count_session_in_480p_strm,
	  sum(cast(count_session_in_720p as numeric)) count_session_in_720p_strm,
	  sum(cast(count_session_in_1080p as numeric)) count_session_in_1080p_strm,
	  sum(cast(count_session_in_1440p as numeric)) count_session_in_1440p_strm,
	  sum(cast(video_streaming_dw_throughput_mbps_in_360p as numeric)) video_streaming_dw_throughput_mbps_in_360p_strm,
	  sum(cast(video_streaming_dw_throughput_mbps_in_480p as numeric)) video_streaming_dw_throughput_mbps_in_480p_strm,
	  sum(cast(video_streaming_dw_throughput_mbps_in_720p as numeric)) video_streaming_dw_throughput_mbps_in_720p_strm,
	  sum(cast(video_streaming_dw_throughput_mbps_in_1080p as numeric)) video_streaming_dw_throughput_mbps_in_1080p_strm,
	  sum(cast(video_streaming_dw_throughput_mbps_in_1440p as numeric)) video_streaming_dw_throughput_mbps_in_1440p_strm,
	  sum(cast(count_subs_in_thp_00_16_mbps as numeric)) count_subs_in_thp_00_16_mbps_strm,
	  sum(cast(count_subs_in_thp_16_23_mbps as numeric)) count_subs_in_thp_16_23_mbps_strm,
	  sum(cast(count_subs_in_thp_23_30_mbps as numeric)) count_subs_in_thp_23_30_mbps_strm,
	  sum(cast(count_subs_in_thp_30_50_mbps as numeric)) count_subs_in_thp_30_50_mbps_strm,
	  sum(cast(count_subs_in_thp_50_plus_mbps as numeric)) count_subs_in_thp_50_plus_mbps_strm,
	  sum(cast(session_in_thp_00_16_mbps as numeric)) session_in_thp_00_16_mbps_strm,
	  sum(cast(session_in_thp_16_23_mbps as numeric)) session_in_thp_16_23_mbps_strm,
	  sum(cast(session_in_thp_23_30_mbps as numeric)) session_in_thp_23_30_mbps_strm,
	  sum(cast(session_in_thp_30_50_mbps as numeric)) session_in_thp_30_50_mbps_strm,
	  sum(cast(session_in_thp_50_plus_mbps as numeric)) session_in_thp_50_plus_mbps_strm,
	  sum(cast(traffic_gb_in_thp_00_16_mbps as numeric)) traffic_gb_in_thp_00_16_mbps_strm,
	  sum(cast(traffic_gb_in_thp_16_23_mbps as numeric)) traffic_gb_in_thp_16_23_mbps_strm,
	  sum(cast(traffic_gb_in_thp_23_30_mbps as numeric)) traffic_gb_in_thp_23_30_mbps_strm,
	  sum(cast(traffic_gb_in_thp_30_50_mbps as numeric)) traffic_gb_in_thp_30_50_mbps_strm,
	  sum(cast(traffic_gb_in_thp_50_plus_mbps as numeric)) traffic_gb_in_thp_50_plus_mbps_strm
  from `data-bi-prd-935c.bi_ext.streaming_exp_bh` a 
  left join `data-bi-prd-935c.bi_dm.ref_site` b on a.site_id = b.site_id
  where date(dt_id) between date_trunc(parse_date('%Y%m%d', '{dt_id}'), month) and PARSE_DATE('%Y%m%d','{dt_id}')
  group by all
  ),
t_apps_exp as 
  (
  select 
	  PARSE_DATE('%Y%m%d','{dt_id}') AS dt_id,
	  CAST(max(dt_id) AS STRING) AS meas_dt,
	  b.kabkot_nm,
	  'IM3' brand,
	  sum(cast(case when category_name = 'Streaming' and  application_name = 'YouTube' then latency_total else 0 end as numeric))  as latency_youtube_num,
	  sum(cast(case when category_name = 'Streaming' and  application_name = 'YouTube' then msisdn_count else 0 end as numeric))  as youtube_den,
	  sum(cast(case when category_name = 'Streaming' and  application_name = 'TikTok' then latency_total else 0 end as numeric))  as latency_tiktok_num,
	  sum(cast(case when category_name = 'Streaming' and  application_name = 'TikTok' then msisdn_count else 0 end as numeric))  as tiktok_den,
	  sum(cast(case when category_name = 'Streaming' and  application_name = 'Facebook' then latency_total else 0 end as numeric))  as latency_facebook_num,
	  sum(cast(case when category_name = 'Streaming' and  application_name = 'Facebook' then msisdn_count else 0 end as numeric))  as facebook_den,
	  sum(cast(case when category_name = 'Streaming' and  application_name = 'Instagram' then latency_total else 0 end as numeric))  as latency_instagram_num,
	  sum(cast(case when category_name = 'Streaming' and  application_name = 'Instagram' then msisdn_count else 0 end as numeric))  as instagram_den,
	  sum(cast(case when category_name = 'Streaming' and  application_name = 'Netflix' then latency_total else 0 end as numeric))  as latency_Netflix_num,
	  sum(cast(case when category_name = 'Streaming' and  application_name = 'Netflix' then msisdn_count else 0 end as numeric))  as Netflix_den,
	  sum(cast(case when category_name = 'Streaming' and  application_name = 'Vidio' then latency_total else 0 end as numeric))  as latency_Vidio_num,
	  sum(cast(case when category_name = 'Streaming' and  application_name = 'Vidio' then msisdn_count else 0 end as numeric))  as Vidio_den,
	  sum(cast(case when category_name = 'Streaming' and  application_name = 'Twitter' then latency_total else 0 end as numeric))  as latency_Twitter_num,
	  sum(cast(case when category_name = 'Streaming' and  application_name = 'Twitter' then msisdn_count else 0 end as numeric))  as Twitter_den,
	  sum(cast(case when category_name = 'IM' and  application_name = 'WhatsApp' then latency_total else 0 end as numeric))  as latency_WhatsApp_num,
	  sum(cast(case when category_name = 'IM' and  application_name = 'WhatsApp' then msisdn_count else 0 end as numeric))  as WhatsApp_den,
	  sum(cast(case when category_name = 'Streaming' and  application_name = 'YouTube' then average_download_throughput else 0 end as numeric))  as dl_tput_youtube_num,
	  sum(cast(case when category_name = 'Streaming' and  application_name = 'TikTok' then average_download_throughput else 0 end as numeric))  as dl_tput_tiktok_num,
	  sum(cast(case when category_name = 'Streaming' and  application_name = 'Facebook' then average_download_throughput else 0 end as numeric))  as dl_tput_facebook_num,
	  sum(cast(case when category_name = 'Streaming' and  application_name = 'Instagram' then average_download_throughput else 0 end as numeric))  as dl_tput_instagram_num,
	  sum(cast(case when category_name = 'Streaming' and  application_name = 'Netflix' then average_download_throughput else 0 end as numeric))  as dl_tput_Netflix_num,
	  sum(cast(case when category_name = 'Streaming' and  application_name = 'Vidio' then average_download_throughput else 0 end as numeric))  as dl_tput_Vidio_num,
	  sum(cast(case when category_name = 'Streaming' and  application_name = 'Twitter' then average_download_throughput else 0 end as numeric))  as dl_tput_Twitter_num,
	  sum(cast(case when category_name = 'IM' and  application_name = 'WhatsApp' then average_download_throughput else 0 end as numeric))  as dl_tput_WhatsApp_num,
	  sum(cast(case when category_name = 'Streaming' and  application_name = 'YouTube' then first_data_delay else 0 end as numeric))  as first_data_delay_youtube_num,
	  sum(cast(case when category_name = 'Streaming' and  application_name = 'TikTok' then first_data_delay else 0 end as numeric))  as first_data_delay_tiktok_num,
	  sum(cast(case when category_name = 'Streaming' and  application_name = 'Facebook' then first_data_delay else 0 end as numeric))  as first_data_delay_facebook_num,
	  sum(cast(case when category_name = 'Streaming' and  application_name = 'Instagram' then first_data_delay else 0 end as numeric))  as first_data_delay_instagram_num,
	  sum(cast(case when category_name = 'Streaming' and  application_name = 'Netflix' then first_data_delay else 0 end as numeric))  as first_data_delay_Netflix_num,
	  sum(cast(case when category_name = 'Streaming' and  application_name = 'Vidio' then first_data_delay else 0 end as numeric))  as first_data_delay_Vidio_num,
	  sum(cast(case when category_name = 'Streaming' and  application_name = 'Twitter' then first_data_delay else 0 end as numeric))  as first_data_delay_Twitter_num,
	  sum(cast(case when category_name = 'IM' and  application_name = 'WhatsApp' then first_data_delay else 0 end as numeric))  as first_data_delay_WhatsApp_num
  from `data-bi-prd-935c.bi_dm.ds_nio_topapps_exp_site` a
  left join `data-bi-prd-935c.bi_mart.ref_site` b on a.site_id = b.site_id
  where date(a.dt_id) between date_trunc(parse_date('%Y%m%d', '{dt_id}'), month) and PARSE_DATE('%Y%m%d','{dt_id}')
  group by all
  ),
t_voice_2g as 
  (
  select
	  PARSE_DATE('%Y%m%d','{dt_id}') AS dt_id,
	  CAST(max(dt_id) AS STRING) AS meas_dt,
	  kabkot_nm,
	  'IM3' brand,
	   sum(cast(gsm_cssr_cs_num as numeric)) gsm_cssr_cs_num_bh,
	   sum(cast(gsm_cssr_cs_den as numeric)) gsm_cssr_cs_den_bh,
	   sum(cast(gsm_tch_dcr_num as numeric)) gsm_tch_dcr_num_bh,
	   sum(cast(gsm_tch_dcr_den as numeric)) gsm_tch_dcr_den_bh,
	   sum(cast(gsm_hosr_num as numeric)) gsm_hosr_num_bh,
	   sum(cast(gsm_hosr_den as numeric)) gsm_hosr_den_bh
  from `data-network-prd-t7nb.cxe.ranperf_2g_daily_bh` a 
  left outer join `data-bi-prd-935c.bi_dm.ref_site` b on a.site_id = b.site_id
  where date(dt_id) between date_trunc(parse_date('%Y%m%d', '{dt_id}'), month) and PARSE_DATE('%Y%m%d','{dt_id}')
  group by all
  ),
t_voice_4g as 
  (
  select
	  PARSE_DATE('%Y%m%d','{dt_id}') AS dt_id,
	  CAST(max(dt_id) AS STRING) AS meas_dt,
	  kabkot_nm,
	  'IM3' brand,
	  sum(cast(volte_cssr_num as numeric)) volte_cssr_num_bh,
	  sum(cast(volte_cssr_den as numeric)) volte_cssr_den_bh, 
	  sum(cast(lte_volte_dcr_num as numeric)) lte_volte_dcr_num_bh,
	  sum(cast(lte_volte_dcr_den as numeric)) lte_volte_dcr_den_bh, 
	  sum(cast(volte_ho_sr_den as numeric)) volte_ho_sr_den_bh,
	  sum(cast(volte_ho_sr_num as numeric)) volte_ho_sr_num_bh,
	  sum(cast(lte_cssr_ps_num as numeric)) lte_cssr_ps_num_bh,
	  sum(cast(lte_cssr_ps_den as numeric)) lte_cssr_ps_den_bh ,
	  sum(cast(lte_cdr_ps_num as numeric)) lte_cdr_ps_num_bh,
	  sum(cast(lte_cdr_ps_den as numeric)) lte_cdr_ps_den_bh,
	  sum(cast(lte_interfreq_ho_sr_den as numeric)) lte_interfreq_ho_sr_den_bh, 
	  sum(cast(lte_interfreq_ho_sr_num as numeric)) lte_interfreq_ho_sr_num_bh,
	  sum(cast(lte_intrafreq_ho_sr_den as numeric)) lte_intrafreq_ho_sr_den_bh,
	  sum(cast(lte_intrafreq_ho_sr_num as numeric)) lte_intrafreq_ho_sr_num_bh,
	  sum(cast(lte_avg_cqi_num as numeric)) lte_avg_cqi_num_bh,
	  sum(cast(lte_avg_cqi_den as numeric)) lte_avg_cqi_den_bh
  from `data-network-prd-t7nb.cxe.ranperf_lte_daily_bh` a  
  left join `data-bi-prd-935c.bi_dm.ref_site` b on a.site_id = b.site_id
  where date(dt_id) between date_trunc(parse_date('%Y%m%d', '{dt_id}'), month) and PARSE_DATE('%Y%m%d','{dt_id}')
  group by all
  ),
t_ggsn_traffic as 
  (
  select 
	  PARSE_DATE('%Y%m%d','{dt_id}') AS dt_id,
	  CAST(max(dt_id) AS STRING) AS meas_dt,
	  b.kabkot_nm,
	  'IM3' brand, 
	  sum(case when kpi = 'Data Traffic Mb - 5G' then  cast(metric as numeric) else 0 end)  traffic_rat10,
	  sum(case when kpi = 'Data Traffic Mb - 4G' then  cast(metric as numeric) else 0 end) traffic_rat06,
	  sum(case when kpi = 'Data Traffic Mb - 2G' then  cast(metric as numeric) else 0 end) traffic_rat02,
	  sum(case when kpi = 'Data Traffic Mb - other' then  cast(metric as numeric) else 0 end) traffic_rat_others,
	  sum(case when kpi = 'Data Traffic Mb - All' then  cast(metric as numeric) else 0 end) traffic_rat_all,
	  sum(case when kpi = 'Daily Data User 5G' then  cast(metric as numeric) else 0 end)  daiy_user_rat10_num,
	  sum(case when kpi = 'Daily Data User 4G' then  cast(metric as numeric) else 0 end)  daiy_user_rat06_num,
	  sum(case when kpi = 'Daily Data User 2G' then  cast(metric as numeric) else 0 end)  daiy_user_rat02_num,
	  sum(case when kpi = 'Daily Data User Other' then  cast(metric as numeric) else 0 end)  daiy_user_ratother_num,
	  sum(case when kpi = 'Daily Data User All' then  cast(metric as numeric) else 0 end)  daiy_user_all_num,
	  sum(case when kpi = 'Site With 5G Data Traffic' and date(dt_id) = PARSE_DATE('%Y%m%d','{dt_id}') then  cast(metric as numeric) else 0 end)  site_rat10,
	  sum(case when kpi = 'Site With 4G Data Traffic' and date(dt_id) = PARSE_DATE('%Y%m%d','{dt_id}') then  cast(metric as numeric) else 0 end)  site_rat06,
	  sum(case when kpi = 'Site With 2G Data Traffic' and date(dt_id) = PARSE_DATE('%Y%m%d','{dt_id}') then  cast(metric as numeric) else 0 end)  site_rat02,
	  sum(case when kpi = 'Site With Data Traffic' and date(dt_id) = PARSE_DATE('%Y%m%d','{dt_id}') then  cast(metric as numeric) else 0 end)  site_with_datavol
  from `data-bi-prd-935c.bi_dm.ioh_data_uu_traffic` a 
  left join `data-bi-prd-935c.bi_dm.ref_site` b on a.site_id = b.site_id
  where date(dt_id) between date_trunc(parse_date('%Y%m%d', '{dt_id}'), month) and PARSE_DATE('%Y%m%d','{dt_id}')
  group by all
  ),
t_cache as 
  (
  select
	  case when upper(b.pop) like '%GOO%' then 'GOOGLE'
	  when upper(b.pop) like '%FAC%' then 'FACEBOOK'
	  when upper(b.pop) like '%FB%' then 'FACEBOOK'
	  when upper(b.pop) like '%AKA%' then 'AKAMAI'
	  when upper(c.vendor) like '%GOO%' then 'GOOGLE'
	  when upper(c.vendor) like '%FAC%' then 'FACEBOOK'
	  when upper(c.vendor) like '%FNA%' then 'FACEBOOK'
	  when upper(c.vendor) like '%AKA%' then 'AKAMAI'
	  end partner,
	  dt_id,
	  a.week_num,
	  a.mo_entity,
	  d.string_field_3 kabkot_nm,
	  'IM3' brand,
	  traffic_mbps /1024 as traffic_gb,
	  case 
	  when a.brand = 'IM3' then b.capacity
	  when a.brand = '3ID' then c.capacity/1024 
	  end capacity_gb
  from  `data-bi-prd-935c.bi_dm.raw_iplinks_weekly_usage` a
  left join `data-bi-prd-935c.bi_dm.ref_iplinks_mapping_im3` b 
  on a.brand = b.brand and a.mo_entity = b.int_ip_router and a.week_num = b.week_num
  left join `data-bi-prd-935c.bi_dm.ref_iplinks_mapping_3id`c 
  on a.brand = c.brand and a.mo_entity = c.router_and_swicth and a.week_num = c.week_num
  left join `data-bi-prd-935c.bi_dm.ds_cache_city_kabkot` d on   a.mo_entity= d.string_field_2
  where 
  a.traffic_mbps > 0
  and (b.group_ne = 'D. Cache' or c.group_ne = 'D. Cache' or cache = 'Cache')
  and a.week_num = (select 
  						max(week_num)
  					from  `data-bi-prd-935c.bi_dm.raw_iplinks_weekly_usage`
  					where date_trunc(dt_id,month) = date_trunc(parse_date('%Y%m%d', '{dt_id}'), month))
  -- and a.mo_entity = 'Z0401BR01/Eth-Trunk55'
  ),
t_cache_top4 as
  (
  select * from 
  (select *, row_number() over (partition by mo_entity order by traffic_gb desc) rowth from t_cache) a
  where rowth <= 4  
  ),
t_cache_stack as
  (
  select 
  	  PARSE_DATE('%Y%m%d','{dt_id}') AS dt_id,
	  week_num as meas_dt,
	  mo_entity,
	  kabkot_nm,
	  partner,
	  avg(traffic_gb) traffic_gb,
	  avg(capacity_gb) capacity_gb,
	  avg(traffic_gb)/avg(capacity_gb) cache_utilization
	  from t_cache_top4
	  group by all
  ),
t_cache_summary as
  (  
  select 
  PARSE_DATE('%Y%m%d','{dt_id}') AS dt_id,
  meas_dt,
  kabkot_nm,
  'IM3' brand,
  sum(cache_facebook_traffic_gb) cache_facebook_traffic_gb,
  sum(cache_facebook_capacity_gb) cache_facebook_capacity_gb,
  sum(cache_google_traffic_gb) cache_google_traffic_gb,
  sum(cache_google_capacity_gb) cache_google_capacity_gb,
  sum(cache_akamai_traffic_gb) cache_akamai_traffic_gb,
  sum(cache_akamai_capacity_gb) cache_akamai_capacity_gb,
  cast(sum(case when  cache_facebook_capacity_gb > 0 and cache_facebook_traffic_gb/cache_facebook_capacity_gb > 0.9 then 1 else 0 end) as numeric) facebook_cache_flag,
  cast(sum(case when  cache_google_capacity_gb > 0 and cache_google_traffic_gb/cache_google_capacity_gb > 0.9 then 1 else 0 end) as numeric) google_cache_flag,
  cast(sum(case when  cache_akamai_capacity_gb > 0 and cache_akamai_traffic_gb/cache_akamai_capacity_gb > 0.9 then 1 else 0 end) as numeric) akamai_cache_flag
  from 
  (
  select 
	  mo_entity,
	  meas_dt,
	  kabkot_nm,
	  sum(case when partner = 'FACEBOOK' then  cast(traffic_gb as numeric) else 0 end) cache_facebook_traffic_gb,
	  sum(case when partner = 'FACEBOOK' then  cast(capacity_gb as numeric) else 0 end) cache_facebook_capacity_gb,
	  sum(case when partner = 'GOOGLE' then  cast(traffic_gb as numeric) else 0 end) cache_google_traffic_gb,
	  sum(case when partner = 'GOOGLE' then  cast(capacity_gb as numeric) else 0 end) cache_google_capacity_gb,
	  sum(case when partner = 'AKAMAI' then  cast(traffic_gb as numeric) else 0 end) cache_akamai_traffic_gb,
	  sum(case when partner = 'AKAMAI' then  cast(capacity_gb as numeric) else 0 end) cache_akamai_capacity_gb
  from t_cache_stack
  group by all
  ) a
  group by all
)
-- select * from t_cache_summary
, t_data_uu30 as 
  (
  select 
	  PARSE_DATE('%Y%m%d','{dt_id}') AS dt_id,
	  CAST('{dt_id}' AS STRING) AS meas_dt,
	  b.kabkot_nm,'IM3' brand, sum(data_uu30) data_uu30 from 
  (
  select  site_id, sum(case when kpi = 'Data_UU_30D' then cast(kpi_metric as numeric) else 0 end) data_uu30
  from `data-bi-prd-935c.bi_dm.ds_seratus_kpi_v1_new`
  where   kpi = 'Data_UU_30D'  and DATE(dt_id) = PARSE_DATE('%Y%m%d','{dt_id}') 
  group by site_id
  union all
  select site_id, 
  sum(case when kpi_code = 'rgu30_data' then cast(value as numeric)  else 0 end) data_uu30
  from `data-bi-prd-935c.bi_mart.project_ioh_kpi_daily_tracker_site`
  where date(load_dt_sk_id) = PARSE_DATE('%Y%m%d','{dt_id}')
  group by all
  ) a 
  left join `data-bi-prd-935c.bi_mart.ref_site` b on a.site_id = b.site_id
  group by all 
  )
--select * from t_data_uu30
, t_snd as 
  (
  select 
	  PARSE_DATE('%Y%m%d','{dt_id}') AS dt_id,
	  CAST(max(dt_id) AS STRING) AS meas_dt,
	  kabkot_nm,
	  'IM3' brand,
	  sum(case when kpi_id = 'dse_trx' then cast(` value ` as numeric)  else 0 end)  dse_trx,
	  sum(case when kpi_id = 'sso_all' then cast(` value ` as numeric)  else 0 end)  sso_all,
	  sum(case when kpi_id = 'stock_3dy_less_outlet' then cast(` value ` as numeric)  else 0 end) stock_3dy_less_outlet
  from  `data-bi-prd-935c.bi_dm.ds_snd_kabkot`
  where date(dt_id) = PARSE_DATE('%Y%m%d','{dt_id}')
  group by all
  )
, t_result as 
  (
  select 
	  a.dt_id,
	  coalesce(a.kabkot_nm,b.kabkot_nm, c.kabkot_nm, d.kabkot_nm, e.kabkot_nm, f.kabkot_nm,i.kabkot_nm,j.kabkot_nm,k.kabkot_nm,l.kabkot_nm,
	  m.kabkot_nm,n.kabkot_nm,o.kabkot_nm) kabkot_nm,
	  coalesce(a.brand,b.brand, c.brand, d.brand, e.brand, f.brand,i.brand,j.brand, k.brand, l.brand,k.brand,m.brand,n.brand,o.brand) brand,
	  b.* except (meas_dt, dt_id, kabkot_nm, brand),
	  c.* except (meas_dt, dt_id, kabkot_nm, brand),
	  d.* except (meas_dt, dt_id, kabkot_nm, brand),
	  e.* except (meas_dt, dt_id, kabkot_nm, brand),
	  f.* except (meas_dt, dt_id, kabkot_nm, brand),
	  i.* except (meas_dt, dt_id, kabkot_nm, brand),
	  j.* except (meas_dt, dt_id, kabkot_nm, brand),
	  k.* except (meas_dt, dt_id, kabkot_nm, brand),
	  l.* except (meas_dt, dt_id, kabkot_nm, brand),
	  m.* except (meas_dt, dt_id, kabkot_nm, brand),
	  n.* except (meas_dt, dt_id, kabkot_nm, brand),
	  o.* except (meas_dt, dt_id, kabkot_nm, brand),
	  p.* except (meas_dt, dt_id, kabkot_nm, brand)
    from  t_ref_kec a  
    full join t_opensignal_exp b on date(a.dt_id) = date(b.dt_id) and a.kabkot_nm = b.kabkot_nm and a.brand = b.brand 
    full join t_ookla_exp c on date(a.dt_id) = date(c.dt_id) and a.kabkot_nm = c.kabkot_nm and a.brand = c.brand
    full join t_fb_share d on date(a.dt_id) = date(d.dt_id) and a.kabkot_nm = d.kabkot_nm and a.brand = d.brand
    full join t_technocomm e on date(a.dt_id) = date(e.dt_id) and a.kabkot_nm = e.kabkot_nm and a.brand = e.brand
    full join t_fb_exp_4g f on  date(a.dt_id) = date(f.dt_id) and a.kabkot_nm = f.kabkot_nm and a.brand = f.brand
    full join t_exp_stream_session i on date(a.dt_id) = date(i.dt_id) and a.kabkot_nm = i.kabkot_nm and a.brand = i.brand
    full join t_apps_exp j on date(a.dt_id) = date(j.dt_id) and a.kabkot_nm = j.kabkot_nm and a.brand = j.brand
    full join t_voice_2g k on date(a.dt_id) = date(k.dt_id) and a.kabkot_nm = k.kabkot_nm and a.brand = k.brand
    full join t_voice_4g l on date(a.dt_id) = date(l.dt_id) and a.kabkot_nm = l.kabkot_nm and a.brand = l.brand
    full join t_ggsn_traffic m on date(a.dt_id) = date(m.dt_id) and a.kabkot_nm = m.kabkot_nm and a.brand = m.brand
    full join t_cache_summary n on date(a.dt_id) = date(n.dt_id) and a.kabkot_nm = n.kabkot_nm and a.brand = n.brand
    full join t_data_uu30 o on date(a.dt_id) = date(o.dt_id) and a.kabkot_nm = o.kabkot_nm and a.brand = o.brand    
    full join t_snd p on date(a.dt_id) = date(p.dt_id) and a.kabkot_nm = p.kabkot_nm and a.brand = p.brand    
  )
 select 
 	PARSE_DATE('%Y%m%d','{dt_id}') as dt_id,
	kpi_code,
	'mtd' AS period_type,
	'city' AS grain_level,
	kabkot_nm as grain_id,
	brand,
	sum(cast(metric_value as numeric)) metric,
	CURRENT_TIMESTAMP() AS processing_time,
	'{dt_id}' as meas_dt
 from t_result
 unpivot(
	 metric_value for kpi_code in (
	 	mean_videoexperience_overall_os,
		mean_voiceappexperience_overall_os,
		mean_gamesexperience_overall_os,
		mean_downloadspeed_overall_os,
		percent_ccq_overall_os,
		val_total_test_count_ookla,
		val_total_device_count_ookla,
		val_overall_connectivity_score_ookla,
		val_video_streaming_score_ookla,
		val_video_streaming_score_sample_count_ookla,
		val_video_streaming_score_test_count_ookla,
		val_web_browsing_score_ookla,
		val_web_browsing_score_sample_count_ookla,
		val_web_browsing_score_test_count_ookla,
		val_speed_score_ookla,
		val_performance_sample_count_ookla,
		val_performance_test_count_ookla,
		val_percentage_quick_video_start_p_ookla,
		val_percentage_uninterupted_playback_p_ookla,
		val_percentage_full_hd_resolution_p_ookla,
		val_web_page_load_time_ms_ookla,
		val_p90_cdn_latency_ms_ookla,
		val_cdn_latency_sample_count_ookla,
		val_p90_video_conferencing_latency_ms_ookla,
		val_video_conferencing_latency_sample_count_ookla,
		val_p90_cloud_infrastructure_latency_ms_ookla,
		val_cloud_infrastructure_latency_sample_count_ookla,
		val_p90_cdn_jitter_ms_ookla,
		val_cdn_jitter_sample_count_ookla,
		val_p90_video_conferencing_jitter_ms_ookla,
		val_video_conferencing_jitter_sample_count_ookla,
		val_p90_cloud_infrastructure_jitter_ms_ookla,
		val_cloud_infrastructure_jitter_sample_count_ookla,
		val_p10_download_speed_mbps_ookla,
		val_median_download_speed_mbps_ookla,
		val_p90_download_speed_mbps_ookla,
		val_download_speed_sample_count_ookla,
		val_p10_upload_speed_mbps_ookla,
		val_median_upload_speed_mbps_ookla,
		val_p90_upload_speed_mbps_ookla,
		val_upload_speed_sample_count_ookla,
		val_p10_primary_server_download_loaded_latency_ms_ookla,
		val_median_primary_server_download_loaded_latency_ms_ookla,
		val_p90_primary_server_download_loaded_latency_ms_ookla,
		val_primary_server_download_loaded_latency_sample_count_ookla,
		val_p10_primary_server_upload_loaded_latency_ms_ookla,
		val_median_primary_server_upload_loaded_latency_ms_ookla,
		val_p90_primary_server_upload_loaded_latency_ms_ookla,
		val_primary_server_upload_loaded_latency_sample_count_ookla,
		base_ori_abs_fb,
		base_norm_abs_fb,
		ga_ori_abs_fb,
		ga_norm_abs_fb,
		churn_ori_abs_fb,
		churn_norm_abs_fb,
		total_cell,
		cell_900,
		cell_1800,
		cell_2100,
		vol_capacity_gb,
		vol_wd_gb,
		total_complaint,
		network_complaint,
		green_grids,
		avail5g_num,
		avail5g_denum,
		avail5g_lowsite99_monthly,
		avail4g_num,
		avail4g_denum,
		avail4g_lowsite99_monthly,
		avail2g_num,
		avail2g_denum,
		avail2g_lowsite99_monthly,
		rsrp_4week_num,
		rsrp_4week_denum,
		rsrp_lowsite_cons4wk,
		prbnum_4week,
		prbdenum_4week,
		eutnum_4week,
		eutdenum_4week,
		eutprb_lowsite_cons4wk,
		suppress_lowsite_cons4wk,
		vid_tput_avg4week_num,
		vid_tput_avg4week_denum,
		vid_delay_avg4week_num,
		vid_delay_avg4week_denum,
		vid_tputdelay_lowsite_cons4wk,
		voice_2g_acore_avg4week_num,
		voice_2g_acore_avg4week_denum,
		voice_2g_lowsite70_cons4wk,
		voice_4g_score_avg4week_num,
		voice_4g_score_avg4week_denum,
		voice_4g_lowsite80_cons4wk,
		volte_lowsite_cons4wk,
		total_site_ioh,
		site_5g,
		vol_gb_mtd,
		vol_gb_ytd,
		vol_gb_lytd,
		vlr,
		rgu90d,
		churn90d,
		churnback90d,
		rgu90d_180dplus,
		churn90d_180dplus,
		churnback90d_180dplus,
		rgu90d_mtd,
		churn90d_mtd,
		churnback90d_mtd,
		rgu90d_180dplus_mtd,
		churn90d_180dplus_mtd,
		churnback90d_180dplus_mtd,
		grossadd,
		total_revenue,
		data_revenue,
		dl_speed_median_fb,
		dl_speed_low_fb,
		dl_speed_high_fb,
		latency_fb,
		rtt_fb,
		rsrq_fb,
		network_gen_fb,
		signal_strength_fb,
		sample_fb,
		day_count_strm,
		total_traffic_gb_strm,
		total_video_traffic_gb_strm,
		average_video_traffic_gb_strm,
		video_streaming_dw_throughput_mbps_strm,
		video_streaming_xkb_start_delay_ms_strm,
		video_streaming_stall_rate_strm,
		streaming_dw_packets_strm,
		streaming_download_delay_strm,
		video_total_start_delay_strm,
		video_start_times_strm,
		stall_duration_strm,
		play_duration_strm,
		total_subs_strm,
		count_subs_in_360p_strm,
		count_subs_in_480p_strm,
		count_subs_in_720p_strm,
		count_subs_in_1080p_strm,
		count_subs_in_1440p_strm,
		total_video_traffic_gb_in_in_360p_strm,
		total_video_traffic_gb_in_in_480p_strm,
		total_video_traffic_gb_in_in_720p_strm,
		total_video_traffic_gb_in_in_1080p_strm,
		total_video_traffic_gb_in_in_1440p_strm,
		count_session_in_360p_strm,
		count_session_in_480p_strm,
		count_session_in_720p_strm,
		count_session_in_1080p_strm,
		count_session_in_1440p_strm,
		video_streaming_dw_throughput_mbps_in_360p_strm,
		video_streaming_dw_throughput_mbps_in_480p_strm,
		video_streaming_dw_throughput_mbps_in_720p_strm,
		video_streaming_dw_throughput_mbps_in_1080p_strm,
		video_streaming_dw_throughput_mbps_in_1440p_strm,
		count_subs_in_thp_00_16_mbps_strm,
		count_subs_in_thp_16_23_mbps_strm,
		count_subs_in_thp_23_30_mbps_strm,
		count_subs_in_thp_30_50_mbps_strm,
		count_subs_in_thp_50_plus_mbps_strm,
		session_in_thp_00_16_mbps_strm,
		session_in_thp_16_23_mbps_strm,
		session_in_thp_23_30_mbps_strm,
		session_in_thp_30_50_mbps_strm,
		session_in_thp_50_plus_mbps_strm,
		traffic_gb_in_thp_00_16_mbps_strm,
		traffic_gb_in_thp_16_23_mbps_strm,
		traffic_gb_in_thp_23_30_mbps_strm,
		traffic_gb_in_thp_30_50_mbps_strm,
		traffic_gb_in_thp_50_plus_mbps_strm,
		latency_youtube_num,
		youtube_den,
		latency_tiktok_num,
		tiktok_den,
		latency_facebook_num,
		facebook_den,
		latency_instagram_num,
		instagram_den,
		latency_Netflix_num,
		Netflix_den,
		latency_Vidio_num,
		Vidio_den,
		latency_Twitter_num,
		Twitter_den,
		latency_WhatsApp_num,
		WhatsApp_den,
		dl_tput_youtube_num,
		dl_tput_tiktok_num,
		dl_tput_facebook_num,
		dl_tput_instagram_num,
		dl_tput_Netflix_num,
		dl_tput_Vidio_num,
		dl_tput_Twitter_num,
		dl_tput_WhatsApp_num,
		first_data_delay_youtube_num,
		first_data_delay_tiktok_num,
		first_data_delay_facebook_num,
		first_data_delay_instagram_num,
		first_data_delay_Netflix_num,
		first_data_delay_Vidio_num,
		first_data_delay_Twitter_num,
		first_data_delay_WhatsApp_num,
		gsm_cssr_cs_num_bh,
		gsm_cssr_cs_den_bh,
		gsm_tch_dcr_num_bh,
		gsm_tch_dcr_den_bh,
		gsm_hosr_num_bh,
		gsm_hosr_den_bh,
		volte_cssr_num_bh,
		volte_cssr_den_bh,
		lte_volte_dcr_num_bh,
		lte_volte_dcr_den_bh,
		volte_ho_sr_den_bh,
		volte_ho_sr_num_bh,
		lte_cssr_ps_num_bh,
		lte_cssr_ps_den_bh,
		lte_cdr_ps_num_bh,
		lte_cdr_ps_den_bh,
		lte_interfreq_ho_sr_den_bh,
		lte_interfreq_ho_sr_num_bh,
		lte_intrafreq_ho_sr_den_bh,
		lte_intrafreq_ho_sr_num_bh,
		lte_avg_cqi_num_bh,
		lte_avg_cqi_den_bh,
		traffic_rat10,
		traffic_rat06,
		traffic_rat02,
		traffic_rat_others,
		traffic_rat_all,
		daiy_user_rat10_num,
		daiy_user_rat06_num,
		daiy_user_rat02_num,
		daiy_user_ratother_num,
		daiy_user_all_num,
		site_rat10,
		site_rat06,
		site_rat02,
		site_with_datavol,
		cache_facebook_traffic_gb,
		cache_facebook_capacity_gb,
		cache_google_traffic_gb,
		cache_google_capacity_gb,
		cache_akamai_traffic_gb,
		cache_akamai_capacity_gb,
		facebook_cache_flag,
		google_cache_flag,
		akamai_cache_flag,
		data_uu30,
		dse_trx,
		sso_all,
		stock_3dy_less_outlet
	 )
 )
group by all; 

-- insert agg kpi from base
insert into `data-bi-prd-935c.bi_dm.technocom_raw_kpi_master`
select
	a.dt_id,
	'soc_vid_tput' as kpi_code,
	period_type,
	grain_level,
	grain_id,
	brand,
	safe_divide(sum(case when a.kpi_code='vid_tput_avg4week_num' then a.metric else 0 end),sum(case when a.kpi_code='vid_tput_avg4week_denum' then a.metric else 0 end)) as metric,
	CURRENT_TIMESTAMP() AS processing_time,
	'{dt_id}' as meas_dt
from `data-bi-prd-935c.bi_dm.technocom_raw_kpi_master` as a
where a.kpi_code in ('vid_tput_avg4week_num', 'vid_tput_avg4week_denum')
	and a.dt_id = parse_date('%Y%m%d','{dt_id}')
	and grain_level = 'city'
	and period_type = 'mtd'
group by all
union all
select
	a.dt_id,
	'subs_with_tput_below3mbps' as kpi_code,
	period_type,
	grain_level,
	grain_id,
	brand,
	safe_divide(sum(case when a.kpi_code in ('count_subs_in_thp_00_16_mbps_strm', 'count_subs_in_thp_16_23_mbps_strm', 'count_subs_in_thp_23_30_mbps_strm') then a.metric else 0 end),
		sum(case when a.kpi_code='total_subs_strm' then a.metric else 0 end)) as metric,
	CURRENT_TIMESTAMP() AS processing_time,
	'{dt_id}' as meas_dt
from `data-bi-prd-935c.bi_dm.technocom_raw_kpi_master` as a
where a.kpi_code in ('count_subs_in_thp_00_16_mbps_strm', 'count_subs_in_thp_16_23_mbps_strm', 'count_subs_in_thp_23_30_mbps_strm', 'total_subs_strm')
	and a.dt_id = parse_date('%Y%m%d','{dt_id}')
	and grain_level = 'city'
	and period_type = 'mtd'
group by all
union all
select
	a.dt_id,
	'subs_with_tput_below3mbps_abs' as kpi_code,
	period_type,
	grain_level,
	grain_id,
	brand,
	sum(case when a.kpi_code in ('count_subs_in_thp_00_16_mbps_strm', 'count_subs_in_thp_16_23_mbps_strm', 'count_subs_in_thp_23_30_mbps_strm') then a.metric else 0 end) as metric,
	CURRENT_TIMESTAMP() AS processing_time,
	'{dt_id}' as meas_dt
from `data-bi-prd-935c.bi_dm.technocom_raw_kpi_master` as a
where a.kpi_code in ('count_subs_in_thp_00_16_mbps_strm', 'count_subs_in_thp_16_23_mbps_strm', 'count_subs_in_thp_23_30_mbps_strm')
	and a.dt_id = parse_date('%Y%m%d','{dt_id}')
	and grain_level = 'city'
	and period_type = 'mtd'
group by all
;