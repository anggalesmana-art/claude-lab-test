delete from `data-bi-prd-935c.bi_snd.tmp_network_competition`
where month_id='{asof_dt}'; 

-- create  table `data-bi-prd-935c.bi_dm.ds_network_competition_v4` as
--insert into `data-bi-prd-935c.bi_dm.ds_network_competition_v4`
insert into `data-bi-prd-935c.bi_snd.tmp_network_competition`
with t_ref_kec as
  (
  select
  distinct
  '{end_dt}' as end_dt,kabkot_nm,'IM3' brand 
  from  `data-bi-prd-935c.bi_mart.ref_kecamatan` 
  union all 
  select
  distinct
  '{end_dt}' as end_dt,kabkot_nm,'3ID' brand
  from  `data-bi-prd-935c.bi_mart.ref_kecamatan`  
  union all 
  select
  distinct
  '{end_dt}' as end_dt,kabkot_nm,'TELKOMSEL' brand
  from  `data-bi-prd-935c.bi_mart.ref_kecamatan`  
  union all 
  select
  distinct
  '{end_dt}' as end_dt,kabkot_nm,'XL' brand
  from  `data-bi-prd-935c.bi_mart.ref_kecamatan`  
  union all 
  select
  distinct
  '{end_dt}' as end_dt,kabkot_nm,'SMARTFREN' brand
  from  `data-bi-prd-935c.bi_mart.ref_kecamatan` 
  )
  -- select * from t_ref_kec limit 10
,t_fb_dt as 
  (
  select 
  date_trunc( wk_end_dt,month) as wk_end_dt2,
  max(wk_end_dt) wk_end_dt
  from `data-network-prd-t7nb.cxe.facebook_network_insight_wly` 
  where object_level = 'kabkot' and date_trunc(wk_end_dt,month) = '{month_dt}'  
  group by 1
  ),
t_fb_exp_4g as
  (
  select
  '{end_dt}' end_dt,
  object_name kabkot_nm,
  case 
  when brand = '3' then '3ID' else brand end as brand,
  -- circle,
  -- region,
  sum(dl_speed_median) dl_speed_median_fb,
  sum(dl_speed_low) dl_speed_low_fb,
  sum(dl_speed_high) dl_speed_high_fb,
  sum(latency) latency_fb,
  sum(rtt) rtt_fb,
  sum(rsrq) rsrq_fb,
  sum(network_gen) network_gen_fb ,
  sum(signal_strength) signal_strength_fb,
  sum(sample) sample_fb
  from `data-network-prd-t7nb.cxe.facebook_network_insight_wly` a
  -- left join t_ref_kec b on a.object_name = b.kabkot_nm 
  where  wk_end_dt in (select wk_end_dt from t_fb_dt)
  and object_level = 'kabkot' and tech = '4G'  
  group by 1,2,3
  )
  -- select * from t_fb_exp_4g limit 100
  ,
t_opensignal_dt as
  (
  select 
  date_trunc(date(end_date),month) as month_id,
  max(end_date) end_date
  from `data-network-prd-t7nb.cxe.opensignal_onx_wly`
  where granul_level = '30' and obj_level = 'kabupaten' and date_trunc(date(end_date),month) = '{month_dt}'  
  group by 1 
  ),  
t_opensignal_exp as 
  (
  select 
  '{end_dt}' as end_dt,
  location kabkot_nm,
  case 
  when device_simserviceproviderbrandname = 'Telkomsel' then 'TELKOMSEL'
  when device_simserviceproviderbrandname = 'Indosat' then 'IM3'
  when device_simserviceproviderbrandname = '3' then '3ID'
  when device_simserviceproviderbrandname = 'Smartfren' then 'SMARTFREN'
  else device_simserviceproviderbrandname end as brand,
  sum(cast(mean_videoexperience_overall as float64)) mean_videoexperience_overall_os,
  sum(cast(mean_voiceappexperience_overall as float64)) mean_voiceappexperience_overall_os,
  sum(cast(mean_gamesexperience_overall as float64)) mean_gamesexperience_overall_os,
  sum(cast(mean_downloadspeed_overall as float64)) mean_downloadspeed_overall_os,
  sum(cast(percent_ccq_overall as float64)) percent_ccq_overall_os
  from `data-network-prd-t7nb.cxe.opensignal_onx_wly` a
  where granul_level = '30' and obj_level = 'kabupaten' 
  and end_date in (select end_date from t_opensignal_dt)
  group by 1,2,3
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
  where date_trunc(date(ts_aggregate_date ),month)  = '{month_dt}'
  group by 1
  ),
t_ookla_exp  as
  (
  select 
  '{end_dt}' end_dt,
  b.kabkot_nm,
  case 
  when upper(attr_provider_name) = 'IM3 OOREDOO' then 'IM3'
  when upper(attr_provider_name) = '3' then '3ID'
  when upper(attr_provider_name) = 'TELKOMSEL' then 'TELKOMSEL'
  when upper(attr_provider_name) in ('XL','AXIS') then 'XL'
  when upper(attr_provider_name) = 'SMARTFREN' then 'SMARTFREN'
  else 'Others' end brand,
  sum(CAST(val_total_test_count as float64)) val_total_test_count_ookla,
  sum(CAST(val_total_device_count as float64)) val_total_device_count_ookla,
  sum(CAST(val_overall_connectivity_score as float64)) val_overall_connectivity_score_ookla,
  sum(CAST(val_video_streaming_score as float64)) val_video_streaming_score_ookla,
  sum(CAST(val_video_streaming_score_sample_count as float64)) val_video_streaming_score_sample_count_ookla,
  sum(CAST(val_video_streaming_score_test_count as float64)) val_video_streaming_score_test_count_ookla,
  sum(CAST(val_web_browsing_score as float64)) val_web_browsing_score_ookla,
  sum(CAST(val_web_browsing_score_sample_count as float64)) val_web_browsing_score_sample_count_ookla,
  sum(CAST(val_web_browsing_score_test_count as float64)) val_web_browsing_score_test_count_ookla,
  sum(CAST(val_speed_score as float64)) val_speed_score_ookla,
  sum(CAST(val_performance_sample_count as float64)) val_performance_sample_count_ookla,
  sum(CAST(val_performance_test_count as float64)) val_performance_test_count_ookla,
  sum(CAST(val_percentage_quick_video_start_p as float64)) val_percentage_quick_video_start_p_ookla,
  sum(CAST(val_percentage_uninterupted_playback_p as float64)) val_percentage_uninterupted_playback_p_ookla,
  sum(CAST(val_percentage_full_hd_resolution_p as float64)) val_percentage_full_hd_resolution_p_ookla,
  sum(CAST(val_web_page_load_time_ms as float64)) val_web_page_load_time_ms_ookla,
  sum(CAST(val_p90_cdn_latency_ms as float64)) val_p90_cdn_latency_ms_ookla,
  sum(CAST(val_cdn_latency_sample_count as float64)) val_cdn_latency_sample_count_ookla,
  sum(CAST(val_p90_video_conferencing_latency_ms as float64)) val_p90_video_conferencing_latency_ms_ookla,
  sum(CAST(val_video_conferencing_latency_sample_count as float64)) val_video_conferencing_latency_sample_count_ookla,
  sum(CAST(val_p90_cloud_infrastructure_latency_ms as float64)) val_p90_cloud_infrastructure_latency_ms_ookla,
  sum(CAST(val_cloud_infrastructure_latency_sample_count as float64)) val_cloud_infrastructure_latency_sample_count_ookla,
  sum(CAST(val_p90_cdn_jitter_ms as float64)) val_p90_cdn_jitter_ms_ookla,
  sum(CAST(val_cdn_jitter_sample_count as float64)) val_cdn_jitter_sample_count_ookla,
  sum(CAST(val_p90_video_conferencing_jitter_ms as float64)) val_p90_video_conferencing_jitter_ms_ookla,
  sum(CAST(val_video_conferencing_jitter_sample_count as float64)) val_video_conferencing_jitter_sample_count_ookla,
  sum(CAST(val_p90_cloud_infrastructure_jitter_ms as float64)) val_p90_cloud_infrastructure_jitter_ms_ookla,
  sum(CAST(val_cloud_infrastructure_jitter_sample_count as float64)) val_cloud_infrastructure_jitter_sample_count_ookla,
  sum(CAST(val_p10_download_speed_mbps as float64)) val_p10_download_speed_mbps_ookla,
  sum(CAST(val_median_download_speed_mbps as float64)) val_median_download_speed_mbps_ookla,
  sum(CAST(val_p90_download_speed_mbps as float64)) val_p90_download_speed_mbps_ookla,
  sum(CAST(val_download_speed_sample_count as float64)) val_download_speed_sample_count_ookla,
  sum(CAST(val_p10_upload_speed_mbps as float64)) val_p10_upload_speed_mbps_ookla,
  sum(CAST(val_median_upload_speed_mbps as float64)) val_median_upload_speed_mbps_ookla,
  sum(CAST(val_p90_upload_speed_mbps as float64)) val_p90_upload_speed_mbps_ookla,
  sum(CAST(val_upload_speed_sample_count as float64)) val_upload_speed_sample_count_ookla,
  sum(CAST(val_p10_primary_server_download_loaded_latency_ms as float64)) val_p10_primary_server_download_loaded_latency_ms_ookla,
  sum(CAST(val_median_primary_server_download_loaded_latency_ms as float64)) val_median_primary_server_download_loaded_latency_ms_ookla,
  sum(CAST(val_p90_primary_server_download_loaded_latency_ms as float64)) val_p90_primary_server_download_loaded_latency_ms_ookla,
  sum(CAST(val_primary_server_download_loaded_latency_sample_count as float64)) val_primary_server_download_loaded_latency_sample_count_ookla,
  sum(CAST(val_p10_primary_server_upload_loaded_latency_ms as float64)) val_p10_primary_server_upload_loaded_latency_ms_ookla,
  sum(CAST(val_median_primary_server_upload_loaded_latency_ms as float64)) val_median_primary_server_upload_loaded_latency_ms_ookla,
  sum(CAST(val_p90_primary_server_upload_loaded_latency_ms as float64)) val_p90_primary_server_upload_loaded_latency_ms_ookla,
  sum(CAST(val_primary_server_upload_loaded_latency_sample_count as float64)) val_primary_server_upload_loaded_latency_sample_count_ookla,
  -- from `data-network-prd-t7nb.cxe.ookla_sci_agg_mly` a
  from `data-network-prd-t7nb.cxe.ookla_sci_agg_wly` a
  left join `data-bi-prd-935c.bi_dm.ds_ookla_kabupaten` b on a.attr_place_name = b.attr_place_name
  where 
  attr_place_type = 'administrative_area_level_2' 
  and ts_aggregate_date in (select ts_aggregate_date from t_ookla_dt)
  and upper(attr_provider_name) in ('IM3 OOREDOO','TELKOMSEL','XL', 'AXIS', 'SMARTFREN','3' ) 
  and attr_mobile_technologies_filter = 'All Cell' 
  group by 1,2,3
  )
-- select * from t_ookla_exp   limit 100
 ,
t_fb_share_dt as
  (
  select 
  date_trunc(dt_id, month) month_id ,
  max(dt_id) dt_id
  from `data-bi-prd-935c.bi_mart.fb_market_share`
  where kpi_nm = 'Kabupaten Kota 2022' and date_trunc(dt_id,month) = '{month_dt}' 
  group by 1  
  ),
  t_fb_share as
  (
  select 
  '{end_dt}' as end_dt,
  locations kabkot_nm,
  case 
  when operator = 'HUTCHISON' then '3ID' 
  when operator = 'INDOSAT' then 'IM3'
  when operator = 'XL' then 'XL' 
  when operator = 'TELKOMSEL' then 'TELKOMSEL'
  when operator = 'SMARTFREN' then 'SMARTFREN'
  else 'OTHER' end brand,
  base_ori_abs base_ori_abs_fb,
  base_norm_abs base_norm_abs_fb,
  ga_ori_abs ga_ori_abs_fb,
  ga_norm_abs ga_norm_abs_fb,
  churn_ori_abs churn_ori_abs_fb,
  churn_norm_abs churn_norm_abs_fb
  from `data-bi-prd-935c.bi_mart.fb_market_share`
  where kpi_nm = 'Kabupaten Kota 2022' and dt_id  in (select dt_id from t_fb_share_dt)
  )
  -- select * from t_fb_share   limit 100
   ,
t_technocomm_dt as
  (
  select  date_trunc(dt_id, month) as month_id,
  max(dt_id) dt_id,
  max(weekid) weekid 
  from `data-bi-prd-935c.bi_mart.ioh_technocomm`
  -- where date_trunc(date(dt_id),month) = '2025-11-01'
  where date_trunc(date(dt_id),month) = '{month_dt}'
  and not (weekid = '202540' and date(dt_id)  = '2025-09-30')
  group by 1
  ),
t_technocomm as
  (
  select
  '{end_dt}' as end_dt,
  kabkot_nm,
  'IM3' brand,
  sum(cast(total_cell as float64)) total_cell,
  sum(cast(cell_900 as float64)) cell_900,
  sum(cast(cell_1800 as float64)) cell_1800,
  sum(cast(cell_2100 as float64)) cell_2100,
  sum(cast(vol_capacity_gb as float64)) vol_capacity_gb,
  sum(cast(vol_wd_gb as float64)) vol_wd_gb,
  sum(cast(total_complaint as float64)) total_complaint,
  sum(cast(network_complaint as float64)) network_complaint,
  count(distinct if(upper(grid_status) = 'GREEN' ,grid_id,null)) green_grids, 
  sum(cast (avail5g_num as float64)) avail5g_num,
  sum(cast(avail5g_denum as float64))avail5g_denum,
  sum(cast(avail5g_lowsite99_monthly as int64)) avail5g_lowsite99_monthly,
  sum(cast (avail4g_num as float64)) avail4g_num,
  sum(cast(avail4g_denum as float64))avail4g_denum,
  sum(cast(avail4g_lowsite99_monthly as int64)) avail4g_lowsite99_monthly,
  sum(cast (avail2g_num as float64)) avail2g_num,
  sum(cast(avail2g_denum as float64))avail2g_denum,
  sum(cast(avail2g_lowsite99_monthly as int64)) avail2g_lowsite99_monthly,
  sum(cast(rsrp_4week as float64)) rsrp_4week_num,
  sum(case when cast(rsrp_4week as float64)  > -200 then 1 else 0 end) rsrp_4week_denum,
  sum(cast(rsrp_lowsite_cons4wk as int64)) rsrp_lowsite_cons4wk,
  sum(cast(prbnum_4week as float64))  prbnum_4week,
  sum(cast(prbdenum_4week as float64)) prbdenum_4week,
  sum(cast(eutnum_4week as float64)) eutnum_4week,
  sum(cast(eutdenum_4week as float64)) eutdenum_4week,
  sum(cast(eutprb_lowsite_cons4wk as int64)) eutprb_lowsite_cons4wk,
  sum(cast(suppress_lowsite_cons4wk as int64)) suppress_lowsite_cons4wk,
  sum(cast(vid_tput_avg4week as float64))  vid_tput_avg4week_num,
  sum(case when cast(vid_tput_avg4week as float64) > 0 then 1 else 0 end)  vid_tput_avg4week_denum,
  sum(cast(vid_delay_avg4week as float64)) vid_delay_avg4week_num,
  sum(case when cast(vid_delay_avg4week as float64) > 0 then 1 else 0 end) vid_delay_avg4week_denum,
  sum(cast(vid_tputdelay_lowsite_cons4wk as int64)) vid_tputdelay_lowsite_cons4wk,
  sum(cast(voice_2g_acore_avg4week as float64) ) voice_2g_acore_avg4week_num,
  sum(case when cast(voice_2g_acore_avg4week as float64) > 0 then 1 else 0 end) voice_2g_acore_avg4week_denum,
  sum(cast(voice_2g_lowsite70_cons4wk as int64)) voice_2g_lowsite70_cons4wk,
  sum(cast(voice_4g_score_avg4week as float64)) voice_4g_score_avg4week_num,
  sum(case when cast(voice_4g_score_avg4week as float64) > 0 then 1 else 0 end) voice_4g_score_avg4week_denum,
  sum(cast(voice_4g_lowsite80_cons4wk as int64)) voice_4g_lowsite80_cons4wk,
  sum(cast(volte_lowsite_cons4wk as int64)) volte_lowsite_cons4wk,
  sum(cast(total_site_ioh as int64)) total_site_ioh,
  sum(cast(site_5g as int64)) site_5g,
  sum(cast(vol_gb_mtd as float64) ) vol_gb_mtd,
  sum(cast(vol_gb_ytd as float64) ) vol_gb_ytd,
  sum(cast(vol_gb_lytd as float64) ) vol_gb_lytd,
  sum(cast(vlr as int64)) vlr,
  sum(cast(rgu90d as int64)) rgu90d,
  sum(cast(churn90d as int64)) churn90d,
  sum(cast(churnback90d as int64)) churnback90d,
  sum(cast(rgu90d_180dplus as int64)) rgu90d_180dplus,
  sum(cast(churn90d_180dplus as int64)) churn90d_180dplus,
  sum(cast(churnback90d_180dplus as int64)) churnback90d_180dplus,
  sum(cast(rgu90d_mtd as int64)) rgu90d_mtd,
  sum(cast(churn90d_mtd as int64)) churn90d_mtd,
  sum(cast(churnback90d_mtd as int64)) churnback90d_mtd,
  sum(cast(rgu90d_180dplus_mtd as int64)) rgu90d_180dplus_mtd,
  sum(cast(churn90d_180dplus_mtd as int64)) churn90d_180dplus_mtd,
  sum(cast(churnback90d_180dplus_mtd as int64)) churnback90d_180dplus_mtd,
  sum(cast(grossadd as int64 )) grossadd,
  sum(cast(total_revenue as float64)) total_revenue,
  sum(cast(data_revenue as float64)) data_revenue
  from `data-bi-prd-935c.bi_mart.ioh_technocomm` a 
  --  left join `data-bi-prd-935c.bi_dm.ref_site` b on a.site_id = b.site_id
  where 
  date(dt_id) in  (select date(dt_id) dt_id from t_technocomm_dt)
  and weekid in (select  weekid from t_technocomm_dt)
  group by 1, 2,3
  )
-- select * from t_technocomm limit 10
  ,
t_exp_stream_session as 
  (
  SELECT 
  '{end_dt}' as end_dt,
  b.kabkot_nm,
  'IM3' brand,
  count(DISTINCT dt_id) day_count_strm,
  sum(total_traffic_gb) total_traffic_gb_strm,
  sum(total_video_traffic_gb) total_video_traffic_gb_strm,
  sum(average_video_traffic_gb) average_video_traffic_gb_strm,
  sum(video_streaming_dw_throughput_mbps) video_streaming_dw_throughput_mbps_strm,
  sum(video_streaming_xkb_start_delay_ms) video_streaming_xkb_start_delay_ms_strm,
  sum(video_streaming_stall_rate) video_streaming_stall_rate_strm,
  sum(streaming_dw_packets) streaming_dw_packets_strm,
  sum(streaming_download_delay) streaming_download_delay_strm,
  sum(video_total_start_delay) video_total_start_delay_strm,
  sum(video_start_times) video_start_times_strm,
  sum(stall_duration) stall_duration_strm,
  sum(play_duration) play_duration_strm,
  sum(total_subs) total_subs_strm,
  sum(count_subs_in_360p) count_subs_in_360p_strm,
  sum(count_subs_in_480p) count_subs_in_480p_strm,
  sum(count_subs_in_720p) count_subs_in_720p_strm,
  sum(count_subs_in_1080p) count_subs_in_1080p_strm,
  sum(count_subs_in_1440p) count_subs_in_1440p_strm,
  sum(total_video_traffic_gb_in_in_360p) total_video_traffic_gb_in_in_360p_strm,
  sum(total_video_traffic_gb_in_in_480p) total_video_traffic_gb_in_in_480p_strm,
  sum(total_video_traffic_gb_in_in_720p) total_video_traffic_gb_in_in_720p_strm,
  sum(total_video_traffic_gb_in_in_1080p) total_video_traffic_gb_in_in_1080p_strm,
  sum(total_video_traffic_gb_in_in_1440p) total_video_traffic_gb_in_in_1440p_strm,
  sum(count_session_in_360p) count_session_in_360p_strm,
  sum(count_session_in_480p) count_session_in_480p_strm,
  sum(count_session_in_720p) count_session_in_720p_strm,
  sum(count_session_in_1080p) count_session_in_1080p_strm,
  sum(count_session_in_1440p) count_session_in_1440p_strm,
  sum(video_streaming_dw_throughput_mbps_in_360p) video_streaming_dw_throughput_mbps_in_360p_strm,
  sum(video_streaming_dw_throughput_mbps_in_480p) video_streaming_dw_throughput_mbps_in_480p_strm,
  sum(video_streaming_dw_throughput_mbps_in_720p) video_streaming_dw_throughput_mbps_in_720p_strm,
  sum(video_streaming_dw_throughput_mbps_in_1080p) video_streaming_dw_throughput_mbps_in_1080p_strm,
  sum(video_streaming_dw_throughput_mbps_in_1440p) video_streaming_dw_throughput_mbps_in_1440p_strm,
  sum(count_subs_in_thp_00_16_mbps) count_subs_in_thp_00_16_mbps_strm,
  sum(count_subs_in_thp_16_23_mbps) count_subs_in_thp_16_23_mbps_strm,
  sum(count_subs_in_thp_23_30_mbps) count_subs_in_thp_23_30_mbps_strm,
  sum(count_subs_in_thp_30_50_mbps) count_subs_in_thp_30_50_mbps_strm,
  sum(count_subs_in_thp_50_plus_mbps) count_subs_in_thp_50_plus_mbps_strm,
  sum(session_in_thp_00_16_mbps) session_in_thp_00_16_mbps_strm,
  sum(session_in_thp_16_23_mbps) session_in_thp_16_23_mbps_strm,
  sum(session_in_thp_23_30_mbps) session_in_thp_23_30_mbps_strm,
  sum(session_in_thp_30_50_mbps) session_in_thp_30_50_mbps_strm,
  sum(session_in_thp_50_plus_mbps) session_in_thp_50_plus_mbps_strm,
  sum(traffic_gb_in_thp_00_16_mbps) traffic_gb_in_thp_00_16_mbps_strm,
  sum(traffic_gb_in_thp_16_23_mbps) traffic_gb_in_thp_16_23_mbps_strm,
  sum(traffic_gb_in_thp_23_30_mbps) traffic_gb_in_thp_23_30_mbps_strm,
  sum(traffic_gb_in_thp_30_50_mbps) traffic_gb_in_thp_30_50_mbps_strm,
  sum(traffic_gb_in_thp_50_plus_mbps) traffic_gb_in_thp_50_plus_mbps_strm
  from `data-bi-prd-935c.bi_ext.streaming_exp_bh` a 
  left join `data-bi-prd-935c.bi_dm.ref_site` b on a.site_id = b.site_id
  where date(dt_id) between '{start_dt}' and '{end_dt}'
  group by 2
  ),
t_apps_exp as 
  (
  select 
  '{end_dt}' as end_dt,
  b.kabkot_nm,
  'IM3' brand,
  sum(case when category_name = 'Streaming' and  application_name = 'YouTube' then latency_total else 0 end)  as latency_youtube_num,
  sum(case when category_name = 'Streaming' and  application_name = 'YouTube' then msisdn_count else 0 end)  as youtube_den,
  sum(case when category_name = 'Streaming' and  application_name = 'TikTok' then latency_total else 0 end)  as latency_tiktok_num,
  sum(case when category_name = 'Streaming' and  application_name = 'TikTok' then msisdn_count else 0 end)  as tiktok_den,
  sum(case when category_name = 'Streaming' and  application_name = 'Facebook' then latency_total else 0 end)  as latency_facebook_num,
  sum(case when category_name = 'Streaming' and  application_name = 'Facebook' then msisdn_count else 0 end)  as facebook_den,
  sum(case when category_name = 'Streaming' and  application_name = 'Instagram' then latency_total else 0 end)  as latency_instagram_num,
  sum(case when category_name = 'Streaming' and  application_name = 'Instagram' then msisdn_count else 0 end)  as instagram_den,
  sum(case when category_name = 'Streaming' and  application_name = 'Netflix' then latency_total else 0 end)  as latency_Netflix_num,
  sum(case when category_name = 'Streaming' and  application_name = 'Netflix' then msisdn_count else 0 end)  as Netflix_den,
  sum(case when category_name = 'Streaming' and  application_name = 'Vidio' then latency_total else 0 end)  as latency_Vidio_num,
  sum(case when category_name = 'Streaming' and  application_name = 'Vidio' then msisdn_count else 0 end)  as Vidio_den,
  sum(case when category_name = 'Streaming' and  application_name = 'Twitter' then latency_total else 0 end)  as latency_Twitter_num,
  sum(case when category_name = 'Streaming' and  application_name = 'Twitter' then msisdn_count else 0 end)  as Twitter_den,
  sum(case when category_name = 'IM' and  application_name = 'WhatsApp' then latency_total else 0 end)  as latency_WhatsApp_num,
  sum(case when category_name = 'IM' and  application_name = 'WhatsApp' then msisdn_count else 0 end)  as WhatsApp_den,
  sum(case when category_name = 'Streaming' and  application_name = 'YouTube' then average_download_throughput else 0 end)  as dl_tput_youtube_num,
  sum(case when category_name = 'Streaming' and  application_name = 'TikTok' then average_download_throughput else 0 end)  as dl_tput_tiktok_num,
  sum(case when category_name = 'Streaming' and  application_name = 'Facebook' then average_download_throughput else 0 end)  as dl_tput_facebook_num,
  sum(case when category_name = 'Streaming' and  application_name = 'Instagram' then average_download_throughput else 0 end)  as dl_tput_instagram_num,
  sum(case when category_name = 'Streaming' and  application_name = 'Netflix' then average_download_throughput else 0 end)  as dl_tput_Netflix_num,
  sum(case when category_name = 'Streaming' and  application_name = 'Vidio' then average_download_throughput else 0 end)  as dl_tput_Vidio_num,
  sum(case when category_name = 'Streaming' and  application_name = 'Twitter' then average_download_throughput else 0 end)  as dl_tput_Twitter_num,
  sum(case when category_name = 'IM' and  application_name = 'WhatsApp' then average_download_throughput else 0 end)  as dl_tput_WhatsApp_num,
  sum(case when category_name = 'Streaming' and  application_name = 'YouTube' then first_data_delay else 0 end)  as first_data_delay_youtube_num,
  sum(case when category_name = 'Streaming' and  application_name = 'TikTok' then first_data_delay else 0 end)  as first_data_delay_tiktok_num,
  sum(case when category_name = 'Streaming' and  application_name = 'Facebook' then first_data_delay else 0 end)  as first_data_delay_facebook_num,
  sum(case when category_name = 'Streaming' and  application_name = 'Instagram' then first_data_delay else 0 end)  as first_data_delay_instagram_num,
  sum(case when category_name = 'Streaming' and  application_name = 'Netflix' then first_data_delay else 0 end)  as first_data_delay_Netflix_num,
  sum(case when category_name = 'Streaming' and  application_name = 'Vidio' then first_data_delay else 0 end)  as first_data_delay_Vidio_num,
  sum(case when category_name = 'Streaming' and  application_name = 'Twitter' then first_data_delay else 0 end)  as first_data_delay_Twitter_num,
  sum(case when category_name = 'IM' and  application_name = 'WhatsApp' then first_data_delay else 0 end)  as first_data_delay_WhatsApp_num
  from `data-bi-prd-935c.bi_dm.ds_nio_topapps_exp_site` a
  left join `data-bi-prd-935c.bi_mart.ref_site` b on a.site_id = b.site_id
  where date(a.dt_id) between '{start_dt}' and '{end_dt}'
  group by 1,2,3
  ),
t_voice_2g as 
  (
  select
  '{end_dt}' as end_dt,
  kabkot_nm,
  'IM3' brand,
  sum(gsm_cssr_cs_num) gsm_cssr_cs_num_bh,
  sum(gsm_cssr_cs_den) gsm_cssr_cs_den_bh,
  sum(gsm_tch_dcr_num) gsm_tch_dcr_num_bh,
  sum(gsm_tch_dcr_den) gsm_tch_dcr_den_bh,
  sum(gsm_hosr_num) gsm_hosr_num_bh,
  sum(gsm_hosr_den) gsm_hosr_den_bh
  from `data-network-prd-t7nb.cxe.ranperf_2g_daily_bh` a 
  left outer join `data-bi-prd-935c.bi_dm.ref_site` b on a.site_id = b.site_id
  where date(dt_id) between '{start_dt}' and '{end_dt}'
  group by 1,2,3
  ),
t_voice_4g as 
  (
  select
  '{end_dt}' as end_dt,
  kabkot_nm,
  'IM3' brand,
  sum(volte_cssr_num) volte_cssr_num_bh,
  sum(volte_cssr_den) volte_cssr_den_bh, 
  sum(lte_volte_dcr_num) lte_volte_dcr_num_bh,
  sum(lte_volte_dcr_den) lte_volte_dcr_den_bh, 
  sum(volte_ho_sr_den) volte_ho_sr_den_bh,
  sum(volte_ho_sr_num) volte_ho_sr_num_bh,
  sum(lte_cssr_ps_num) lte_cssr_ps_num_bh,
  sum(lte_cssr_ps_den) lte_cssr_ps_den_bh ,
  sum(lte_cdr_ps_num) lte_cdr_ps_num_bh,
  sum(lte_cdr_ps_den) lte_cdr_ps_den_bh,
  sum(lte_interfreq_ho_sr_den) lte_interfreq_ho_sr_den_bh, 
  sum(lte_interfreq_ho_sr_num) lte_interfreq_ho_sr_num_bh,
  sum(lte_intrafreq_ho_sr_den) lte_intrafreq_ho_sr_den_bh,
  sum(lte_intrafreq_ho_sr_num) lte_intrafreq_ho_sr_num_bh,
  sum(lte_avg_cqi_num) lte_avg_cqi_num_bh,
  sum(lte_avg_cqi_den) lte_avg_cqi_den_bh
  from `data-network-prd-t7nb.cxe.ranperf_lte_daily_bh` a  
  left join `data-bi-prd-935c.bi_dm.ref_site` b on a.site_id = b.site_id
  where date(dt_id) between '{start_dt}' and '{end_dt}'
  group by 1,2,3
  ),
t_ggsn_traffic as 
  (
  select 
  '{end_dt}' end_dt,
  b.kabkot_nm,
  'IM3' brand, 
  sum(case when kpi = 'Data Traffic Mb - 5G' then  metric else 0 end)  traffic_rat10,
  sum(case when kpi = 'Data Traffic Mb - 4G' then  metric else 0 end) traffic_rat06,
  sum(case when kpi = 'Data Traffic Mb - 2G' then  metric else 0 end) traffic_rat02,
  sum(case when kpi = 'Data Traffic Mb - other' then  metric else 0 end) traffic_rat_others,
  sum(case when kpi = 'Data Traffic Mb - All' then  metric else 0 end) traffic_rat_all,
  sum(case when kpi = 'Daily Data User 5G' then  metric else 0 end)  daiy_user_rat10_num,
  sum(case when kpi = 'Daily Data User 4G' then  metric else 0 end)  daiy_user_rat06_num,
  sum(case when kpi = 'Daily Data User 2G' then  metric else 0 end)  daiy_user_rat02_num,
  sum(case when kpi = 'Daily Data User Other' then  metric else 0 end)  daiy_user_ratother_num,
  sum(case when kpi = 'Daily Data User All' then  metric else 0 end)  daiy_user_all_num,
  sum(case when kpi = 'Site With 5G Data Traffic' and date(dt_id) = '{end_dt}' then  metric else 0 end)  site_rat10,
  sum(case when kpi = 'Site With 4G Data Traffic' and date(dt_id) = '{end_dt}' then  metric else 0 end)  site_rat06,
  sum(case when kpi = 'Site With 2G Data Traffic' and date(dt_id) = '{end_dt}' then  metric else 0 end)  site_rat02,
  sum(case when kpi = 'Site With Data Traffic' and date(dt_id) = '{end_dt}' then  metric else 0 end)  site_with_datavol
  from `data-bi-prd-935c.bi_dm.ioh_data_uu_traffic` a 
  left join `data-bi-prd-935c.bi_dm.ref_site` b on a.site_id = b.site_id
  where date(dt_id) between '{start_dt}' and '{end_dt}'
  group by 2
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
  and a.week_num = '{week_cache}'
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
  mo_entity,
  kabkot_nm,
  partner,
  avg(traffic_gb) traffic_gb,
  avg(capacity_gb) capacity_gb,
  avg(traffic_gb)/avg(capacity_gb) cache_utilization
  from t_cache_top4
  group by 1,2,3
  ),
t_cache_summary as
  (  
  select 
  '{end_dt}' end_dt,
  kabkot_nm,
  'IM3' brand,
  sum(cache_facebook_traffic_gb) cache_facebook_traffic_gb,
  sum(cache_facebook_capacity_gb) cache_facebook_capacity_gb,
  sum(cache_google_traffic_gb) cache_google_traffic_gb,
  sum(cache_google_capacity_gb) cache_google_capacity_gb,
  sum(cache_akamai_traffic_gb) cache_akamai_traffic_gb,
  sum(cache_akamai_capacity_gb) cache_akamai_capacity_gb,
  sum(case when  cache_facebook_capacity_gb > 0 and cache_facebook_traffic_gb/cache_facebook_capacity_gb > 0.9 then 1 else 0 end) facebook_cache_flag,
  sum(case when  cache_google_capacity_gb > 0 and cache_google_traffic_gb/cache_google_capacity_gb > 0.9 then 1 else 0 end) google_cache_flag,
  sum(case when  cache_akamai_capacity_gb > 0 and cache_akamai_traffic_gb/cache_akamai_capacity_gb > 0.9 then 1 else 0 end) akamai_cache_flag
  from 
  (
  select 
  mo_entity,
  kabkot_nm,
  sum(case when partner = 'FACEBOOK' then  traffic_gb else 0 end) cache_facebook_traffic_gb,
  sum(case when partner = 'FACEBOOK' then  capacity_gb else 0 end) cache_facebook_capacity_gb,
  sum(case when partner = 'GOOGLE' then  traffic_gb else 0 end) cache_google_traffic_gb,
  sum(case when partner = 'GOOGLE' then  capacity_gb else 0 end) cache_google_capacity_gb,
  sum(case when partner = 'AKAMAI' then  traffic_gb else 0 end) cache_akamai_traffic_gb,
  sum(case when partner = 'AKAMAI' then  capacity_gb else 0 end) cache_akamai_capacity_gb
  from t_cache_stack
  group by 1,2
  ) a
  group by a.kabkot_nm
),
-- select * from t_cache_summary 
t_data_uu30 as 
  (
  select '{end_dt}' end_dt,b.kabkot_nm,'IM3' brand, sum(data_uu30) data_uu30 from 
  (
  select  site_id, sum(case when kpi = 'Data_UU_30D' then kpi_metric else 0 end) data_uu30
  from `data-bi-prd-935c.bi_dm.ds_seratus_kpi_v1_new`
  where   kpi = 'Data_UU_30D'  and DATE(dt_id) = '{end_dt}' 
  group by site_id
  union all
  select site_id, 
  sum(case when kpi_code = 'rgu30_data' then value  else 0 end) data_uu30
  from `data-bi-prd-935c.bi_mart.project_ioh_kpi_daily_tracker_site`
  where date(load_dt_sk_id) = '{end_dt}'
  group by 1
  ) a 
  left join `data-bi-prd-935c.bi_mart.ref_site` b on a.site_id = b.site_id
  group by 2  
  ),
t_snd as 
  (
  select 
  '{end_dt}' as end_dt,
  kabkot_nm,
  'IM3' brand,
  sum(case when kpi_id = 'dse_trx' then ` value `  else 0 end)  dse_trx,
  sum(case when kpi_id = 'sso_all' then ` value `  else 0 end)  sso_all,
  sum(case when kpi_id = 'stock_3dy_less_outlet' then ` value `  else 0 end) stock_3dy_less_outlet
  from  `data-bi-prd-935c.bi_dm.ds_snd_kabkot`
  where dt_id = '{end_dt}'
  group by 2
  ),
t_result as 
  (
  select 
  parse_date('%Y-%m-%d','{asof_dt}') month_id,
  coalesce(a.kabkot_nm,b.kabkot_nm, c.kabkot_nm, d.kabkot_nm, e.kabkot_nm, f.kabkot_nm,i.kabkot_nm,j.kabkot_nm,k.kabkot_nm,l.kabkot_nm,
  m.kabkot_nm,n.kabkot_nm,o.kabkot_nm) kabkot_nm,
  coalesce(a.brand,b.brand, c.brand, d.brand, e.brand, f.brand,i.brand,j.brand, k.brand, l.brand,k.brand,m.brand,n.brand,o.brand) brand,
  g.circle,
  g.region,
  h.micro_market,
  b.* except (end_dt, kabkot_nm, brand),
  c.* except (end_dt, kabkot_nm, brand),
  d.* except (end_dt, kabkot_nm, brand),
  e.* except (end_dt, kabkot_nm, brand),
  f.* except (end_dt, kabkot_nm, brand),
  i.* except (end_dt, kabkot_nm, brand),
  j.* except (end_dt, kabkot_nm, brand),
  k.* except (end_dt, kabkot_nm, brand),
  l.* except (end_dt, kabkot_nm, brand),
  m.* except (end_dt, kabkot_nm, brand),
  n.* except (end_dt, kabkot_nm, brand),
  o.* except (end_dt, kabkot_nm, brand),
  p.* except (end_dt, kabkot_nm, brand)
    from  t_ref_kec a  
    full join t_opensignal_exp b on date(a.end_dt) = date(b.end_dt) and a.kabkot_nm = b.kabkot_nm and a.brand = b.brand 
    full join t_ookla_exp c on date(a.end_dt) = date(c.end_dt) and a.kabkot_nm = c.kabkot_nm and a.brand = c.brand
    full join t_fb_share d on date(a.end_dt) = date(d.end_dt) and a.kabkot_nm = d.kabkot_nm and a.brand = d.brand
    full join t_technocomm e on date(a.end_dt) = date(e.end_dt) and a.kabkot_nm = e.kabkot_nm and a.brand = e.brand
    full join t_fb_exp_4g f on  date(a.end_dt) = date(f.end_dt) and a.kabkot_nm = f.kabkot_nm and a.brand = f.brand
    left join 
    (
     select kabkot_nm,circle,region from 
     ( 
     select kabkot_nm,circle,region, row_number() over (partition by kabkot_nm order by kec_count desc) rowth from
     ( select kabkot_nm,circle,region, count(distinct kecamatan_nm) kec_count from  `data-bi-prd-935c.bi_mart.ref_kecamatan`  group by 1,2,3) a
     ) b where rowth = 1
    ) g on a.kabkot_nm = g.kabkot_nm
    full join `data-bi-prd-935c.bi_dm.ds_micro_market` h on a.kabkot_nm = h.kabkot_nm 
    full join t_exp_stream_session i on date(a.end_dt) = date(i.end_dt) and a.kabkot_nm = i.kabkot_nm and a.brand = i.brand
    full join t_apps_exp j on date(a.end_dt) = date(j.end_dt) and a.kabkot_nm = j.kabkot_nm and a.brand = j.brand
    full join t_voice_2g k on date(a.end_dt) = date(k.end_dt) and a.kabkot_nm = k.kabkot_nm and a.brand = k.brand
    full join t_voice_4g l on date(a.end_dt) = date(l.end_dt) and a.kabkot_nm = l.kabkot_nm and a.brand = l.brand
    full join t_ggsn_traffic m on date(a.end_dt) = date(m.end_dt) and a.kabkot_nm = m.kabkot_nm and a.brand = m.brand
    full join t_cache_summary n on date(a.end_dt) = date(n.end_dt) and a.kabkot_nm = n.kabkot_nm and a.brand = n.brand
    full join t_data_uu30 o on date(a.end_dt) = date(o.end_dt) and a.kabkot_nm = o.kabkot_nm and a.brand = o.brand    
    full join t_snd p on date(a.end_dt) = date(p.end_dt) and a.kabkot_nm = p.kabkot_nm and a.brand = p.brand    
  )
select a.*,coalesce(b.kabkot_5g, 'Non Kabkot 5G') kabkot_5g from t_result a
left join
(
select b.kabkot_nm,'Kabkot 5G' kabkot_5g, count(distinct a.site_id) count_site5g from 
(
SELECT site_id, rfs_af from `data-bi-prd-935c.bi_dm.ds_hermes1b`
union all
SELECT site_id,rfs_af from `data-bi-prd-935c.bi_dm.ds_hermes2`
where date(rfs_af) between '2025-09-01' and '{end_dt}'
) a
left join `data-bi-prd-935c.bi_dm.ref_site` b on a.site_id = b.site_id
group by 1
) b on a.kabkot_nm = b.kabkot_nm 
left join `data-bi-prd-935c.bi_dm.ds_focus_kabkot_v2` c on a.kabkot_nm = c.kabkot_nm 
;