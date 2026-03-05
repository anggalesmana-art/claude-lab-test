declare vdt_id date default @vdt_id;


delete from `data-bi-prd-935c.bi_mart.project_rguog_subs_detail` where load_dt_sk_id = vdt_id;

drop table if exists `data-bi-prd-935c.bi_stg`.subs_rgu_base_regist_daily;

create table `data-bi-prd-935c.bi_stg`.subs_rgu_base_regist_daily	--Temp1
		as
		SELECT
			sbscrptn_ek_id,
			case when sum(
							COALESCE(voice_onnet_free_cnt_short,0)+COALESCE(voice_onnet_paid_cnt_short,0)+
							COALESCE(voice_onnet_free_cnt_long,0)+COALESCE(voice_onnet_paid_cnt_long,0)+
							COALESCE(Voice_offnet_olo_free_cnt_short,0)+COALESCE(voice_offnet_pstn_free_cnt_short,0)+
							COALESCE(voice_offnet_olo_paid_cnt_short,0)+COALESCE(voice_offnet_pstn_paid_cnt_short,0)+
							COALESCE(Voice_offnet_olo_free_cnt_long,0)+COALESCE(Voice_offnet_pstn_free_cnt_long,0)+
							COALESCE(Voice_offnet_olo_paid_cnt_long,0)+COALESCE(Voice_offnet_pstn_paid_cnt_long,0)+
							COALESCE(voice_idd_paid_cnt,0)+COALESCE(voice_idd_free_cnt,0)+
							COALESCE(voice_voip_1088_paid_cnt,0)+COALESCE(voice_voip_1089_paid_cnt,0)+
							COALESCE(voice_voip_1088_free_cnt,0)+COALESCE(voice_voip_1089_free_cnt,0)+
							COALESCE(voice_voip_others_free_cnt,0)+COALESCE(voice_voip_others_paid_cnt,0)+
							COALESCE(voice_others_paid_cnt,0)+COALESCE(voice_others_free_cnt,0)+
							COALESCE(video_onnet_free_cnt_short,0)+COALESCE(video_onnet_free_cnt_long,0)+
							COALESCE(video_onnet_paid_cnt_short,0)+COALESCE(video_onnet_paid_cnt_long,0)+
							COALESCE(video_offnet_free_cnt_short,0)+COALESCE(video_offnet_free_cnt_long,0)+
							COALESCE(video_offnet_paid_cnt_short,0)+COALESCE(video_offnet_paid_cnt_long,0)+
							COALESCE(video_idd_paid_cnt,0)+COALESCE(video_idd_free_cnt,0)+
							COALESCE(video_others_paid_cnt,0)+COALESCE(video_others_free_cnt,0)+
							COALESCE(video_mtc_roaming_cnt,0)+COALESCE(video_mtc_others_cnt,0)+
							COALESCE(sms_onnet_free_cnt,0)+COALESCE(sms_onnet_paid_cnt,0)+
							COALESCE(sms_offnet_free_cnt,0)+COALESCE(sms_offnet_paid_cnt,0)+
							COALESCE(sms_idd_free_cnt,0)+ COALESCE(sms_idd_paid_cnt,0)+
							COALESCE(sms_others_free_cnt,0)+COALESCE(sms_others_paid_cnt,0)+
							COALESCE(mms_onnet_free_cnt,0)+COALESCE(mms_onnet_paid_cnt,0)+
							COALESCE(mms_offnet_free_cnt,0)+COALESCE(mms_offnet_paid_cnt,0)+
							COALESCE(mms_idd_paid_cnt,0)+COALESCE(mms_idd_free_cnt,0)+
							COALESCE(mms_others_paid_cnt,0)+COALESCE(mms_others_free_cnt,0)+
							--COALESCE(bb_pkg_cnt,0)+
							--COALESCE(data_package_cnt,0)+
							COALESCE(Gprs_paid_cnt,0)+ COALESCE(gprs_free_cnt,0)+
							COALESCE(realtime_roaming_free_cnt,0)+
							COALESCE(realtime_roaming_paid_cnt,0)+
							--COALESCE(realtime_roaming_gprs_free_cnt,0)+
							COALESCE(realtime_roaming_gprs_paid_cnt,0)+
							COALESCE(roaming_idd_video_mtc_free_cnt,0)+
							COALESCE(roaming_idd_video_mtc_paid_cnt,0)+
							COALESCE(roaming_gprs_package_cnt,0)+
							COALESCE(roaming_tapin_voice_cnt,0)+
							COALESCE(roaming_tapin_gprs_cnt,0)+
							--COALESCE(vas_free_cnt,0)+
							COALESCE(vas_paid_cnt,0)
							--COALESCE(topup_spcl_vas_pkg_cnt,0)+COALESCE(topup_spcl_other_pkg_cnt,0)+
							--COALESCE(others_package_cnt,0) +COALESCE(cdr_others_cnt,0)
							--SC:20170720:Adding Topup for both Regular and Special
							--+COALESCE(topup_regular_cnt,0)+COALESCE(topup_special_cnt,0)
							--SC:20170720:Subtracting Topup for both Regular and Special
							--COALESCE(data_sp_activatn_cnt,0)-COALESCE(bb_sp_activatn_cnt,0)
							--+COALESCE(voice_package_cnt,0)+COALESCE(topup_spcl_voice_pkg_cnt,0)
							--+COALESCE(topup_spcl_sms_pkg_cnt,0)+ COALESCE(sms_package_cnt,0)
							--DWI:20210211:add gprs_package_cnt and vas_package_cnt
							--+COALESCE(vas_package_cnt,0) + COALESCE(gprs_package_cnt,0)
						) > 0
					then 1
					else 0
				end
			 as total_uniq_subs_cnt
		FROM
			`data-dtptechm-prd-c7ca.dwh.sbscrptn_base`
		where cast(load_dt_sk_id as date)= vdt_id
		GROUP BY
			1;

drop table if exists `data-bi-prd-935c.bi_stg`.vas_outgoing;

create table `data-bi-prd-935c.bi_stg`.vas_outgoing as
		SELECT 
		sbscrptn_ek_id
		FROM `data-dtptechm-prd-c7ca.dwh.charged_event_fct` a
		left join `data-dtptechm-prd-c7ca.dwh.sbscrptn_dim` sd on a.sbscrptn_sk_id = sd.sbscrptn_sk_id and sd.curr_ind ='Y'
		join `data-dtptechm-prd-c7ca.dwh`.traffic_dim td on a.traffic_sk_id = td.traffic_sk_id
		where  
		-- cast(sd.record_end_dtm as date) <= '9999-12-31' and
		cast(charge_start_dt_sk_id as date) = vdt_id 
		and	acct_type_cd = 'MAIN'
		and (case when event_type_sk_id = 61 and post_discounted_amt_idr <= 0 then 1 else 0 end) = 0 
		and vas_level_1_ctgry = 'VAS'
		and traffic_desc = 'Content Download(Initial Call Type)' and substr(video_request_url,length(video_request_url) - 2,3) = '#MO' 
		;

drop table if exists `data-bi-prd-935c.bi_stg`.subs_base_usage_daily;

create table `data-bi-prd-935c.bi_stg`.subs_base_usage_daily	--
		as
		SELECT
		sbscrptn_ek_id,
			case when sum(
							COALESCE(bb_uplink_vol,0)+COALESCE(bb_downlink_vol,0)+
							COALESCE(data_uplink_vol_free_url,0)+COALESCE(data_downlink_vol_free_url,0)+
							COALESCE(data_uplink_vol_Dongle,0)+COALESCE(data_downlink_vol_Dongle,0)+
							COALESCE(Other_apn_uplink_vol_Data,0)+COALESCE(Other_apn_downlink_vol_Data,0)+
							COALESCE(Other_apn_uplink_vol_PUG,0)+COALESCE(Other_apn_downlink_vol_PUG,0)+
							COALESCE(gprs_uplink_vol_free_url,0)+COALESCE(gprs_downlink_vol_free_url,0)+
							COALESCE(gprs_uplink_vol_Dongle,0)+COALESCE(gprs_downlink_vol_Dongle,0)+
							COALESCE(gprs_uplink_vol_PUG,0)+COALESCE(gprs_downlink_vol_PUG,0)
						) > 0
					then 1
					else 0
				end
			 as data_uniq_subs_cnt
		FROM
			`data-dtptechm-prd-c7ca.dwh.broadband_usage_dly_summary`
		where cast(created_dt_sk_id as date) = vdt_id
		GROUP BY	1;

insert into `data-bi-prd-935c.bi_mart.project_rguog_subs_detail`
	select
	cast(vdt_id as date) as load_dt_sk_id,
	cast(sbscrptn_ek_id as string)
	from `data-bi-prd-935c.bi_stg`.subs_rgu_base_regist_daily
	where total_uniq_subs_cnt = 1
	union distinct
	select
	cast(vdt_id as date) as load_dt_sk_id,
	cast(sbscrptn_ek_id as string)
	from `data-bi-prd-935c.bi_stg`.subs_base_usage_daily
	where data_uniq_subs_cnt = 1
	union distinct
	select
	cast(vdt_id as date) as load_dt_sk_id,
	cast(sbscrptn_ek_id as string)
	from `data-bi-prd-935c.bi_stg`.vas_outgoing;	
	
drop table if exists `data-bi-prd-935c.bi_stg`.vas_outgoing;