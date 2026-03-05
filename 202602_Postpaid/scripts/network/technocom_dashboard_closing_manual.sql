-- 00. Deleting Ookla Data
delete from `data-bi-prd-935c.bi_dm.technocom_raw_kpi_master`
	where period_type='mtd'
		and grain_level='city'
		and dt_id = parse_date('%Y%m%d', '{dt_id}')
		and kpi_code in (
		'val_total_test_count_ookla',
		'val_total_device_count_ookla',
		'val_overall_connectivity_score_ookla',
		'val_video_streaming_score_ookla',
		'val_video_streaming_score_sample_count_ookla',
		'val_video_streaming_score_test_count_ookla',
		'val_web_browsing_score_ookla',
		'val_web_browsing_score_sample_count_ookla',
		'val_web_browsing_score_test_count_ookla',
		'val_speed_score_ookla',
		'val_performance_sample_count_ookla',
		'val_performance_test_count_ookla',
		'val_percentage_quick_video_start_p_ookla',
		'val_percentage_uninterupted_playback_p_ookla',
		'val_percentage_full_hd_resolution_p_ookla',
		'val_web_page_load_time_ms_ookla',
		'val_p90_cdn_latency_ms_ookla',
		'val_cdn_latency_sample_count_ookla',
		'val_p90_video_conferencing_latency_ms_ookla',
		'val_video_conferencing_latency_sample_count_ookla',
		'val_p90_cloud_infrastructure_latency_ms_ookla',
		'val_cloud_infrastructure_latency_sample_count_ookla',
		'val_p90_cdn_jitter_ms_ookla',
		'val_cdn_jitter_sample_count_ookla',
		'val_p90_video_conferencing_jitter_ms_ookla',
		'val_video_conferencing_jitter_sample_count_ookla',
		'val_p90_cloud_infrastructure_jitter_ms_ookla',
		'val_cloud_infrastructure_jitter_sample_count_ookla',
		'val_p10_download_speed_mbps_ookla',
		'val_median_download_speed_mbps_ookla',
		'val_p90_download_speed_mbps_ookla',
		'val_download_speed_sample_count_ookla',
		'val_p10_upload_speed_mbps_ookla',
		'val_median_upload_speed_mbps_ookla',
		'val_p90_upload_speed_mbps_ookla',
		'val_upload_speed_sample_count_ookla',
		'val_p10_primary_server_download_loaded_latency_ms_ookla',
		'val_median_primary_server_download_loaded_latency_ms_ookla',
		'val_p90_primary_server_download_loaded_latency_ms_ookla',
		'val_primary_server_download_loaded_latency_sample_count_ookla',
		'val_p10_primary_server_upload_loaded_latency_ms_ookla',
		'val_median_primary_server_upload_loaded_latency_ms_ookla',
		'val_p90_primary_server_upload_loaded_latency_ms_ookla',
		'val_primary_server_upload_loaded_latency_sample_count_ookla'
		); 

-- 01. Inserting Ookla Data
insert into `data-bi-prd-935c.bi_dm.technocom_raw_kpi_master`
with
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
  from `data-network-prd-t7nb.cxe.ookla_sci_agg_mly` a
  -- from `data-network-prd-t7nb.cxe.ookla_sci_agg_wly` a
  left join `data-bi-prd-935c.bi_dm.ds_ookla_kabupaten` b on a.attr_place_name = b.attr_place_name
  where 
	  attr_place_type = 'administrative_area_level_2' 
	  and format_date('%Y%m',ts_aggregate_date)=left('{dt_id}',6)
	  and upper(attr_provider_name) in ('IM3 OOREDOO','TELKOMSEL','XL', 'AXIS', 'SMARTFREN','3' ) 
	  and attr_mobile_technologies_filter = 'All Cell' 
	  group by all
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
	max(meas_dt) as meas_dt
 from t_ookla_exp
 unpivot(
	 metric_value for kpi_code in (
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
		val_primary_server_upload_loaded_latency_sample_count_ookla
	 )
 )
group by all;