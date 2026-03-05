declare vdt_id date default @vdt_id;


delete from `data-bi-prd-935c.bi_mart.project_rgumt_subs_detail` where load_dt_sk_id = vdt_id;

drop table if exists `data-bi-prd-935c.bi_stg.subs_incoming_ict`;

create table `data-bi-prd-935c.bi_stg.subs_incoming_ict`  --Temp2
		as
		select distinct message_dt_sk_id as dt, coalesce(sd.sbscrptn_ek_id, -2) as sbscrptn_ek_id
			from `data-dtptechm-prd-c7ca.dwh.intercnt_fct` ICT
			left join `data-dtptechm-prd-c7ca.dwh.sbscrptn_dim` SD on ICT.sbscrptn_sk_id = SD.sbscrptn_sk_id
			-- and sd.created_dtm<'9999-12-01'
			where CAST(message_dt_sk_id AS DATE) = vdt_id 
			and	event_direction_cd = 'I' 
			--and product_group <> 'SMS' and Actual_usage_dur >= 6
			and coalesce(sd.tool_of_trade_ind, 'N') = 'N'
                ;

  drop table if exists `data-bi-prd-935c.bi_stg.subs_incoming_onnet`;

    create table `data-bi-prd-935c.bi_stg.subs_incoming_onnet`  --Temp2
		as
		select distinct a.dt, b.sbscrptn_ek_id
		from
		(
		select distinct cef.charge_start_dt_sk_id as dt, cef.called_party_id
		from `data-dtptechm-prd-c7ca.dwh.charged_event_fct` cef
		join `data-dtptechm-prd-c7ca.dwh.traffic_dim` td on cef.traffic_sk_id= td.traffic_sk_id and td.vas_level_1_ctgry not in ('BROADBAND','BLACKBERRY','VAS') -- TO EXCLUDE THE DATA/BB/VAS component from the Non-Oneoff CDR
		left join `data-dtptechm-prd-c7ca.dwh.sbscrptn_dim` sbdm on sbdm.sbscrptn_sk_id = cef.sbscrptn_sk_id 
		left join `data-dtptechm-prd-c7ca.dwh.acct_dim_1_prt_latest_set` ad on ad.acct_sk_id = cef.acct_sk_id 
		where event_type_sk_id in (1,3) and vas_level_1_ctgry in ('Voice', 'SMS') and vas_level_2_ctgry= 'On Net'

		and ad.acct_identifier_cd = 'MAIN'
		and coalesce(ad.tool_of_trade_ind, 'N') = 'N'
		and CAST(cef.charge_start_dt_sk_id AS DATE)  = vdt_id
		) a
		left join `data-dtptechm-prd-c7ca.dwh.sbscrptn_dim` b on a.called_party_id = b.msisdn and b.rank_ind = 1;
  -- VAS MT

  drop table if exists `data-bi-prd-935c.bi_stg.vas_incoming_2`;

  create table `data-bi-prd-935c.bi_stg.vas_incoming_2` as
		SELECT 
		sbscrptn_ek_id
		FROM `data-dtptechm-prd-c7ca.dwh.charged_event_fct` a
		left join `data-dtptechm-prd-c7ca.dwh.sbscrptn_dim` sd on a.sbscrptn_sk_id = sd.sbscrptn_sk_id
		join `data-dtptechm-prd-c7ca.dwh.traffic_dim` td on a.traffic_sk_id = td.traffic_sk_id
		where 
		CAST(charge_start_dt_sk_id AS DATE) = vdt_id 
		and acct_type_cd = 'MAIN'

		and (case when event_type_sk_id = 61 /*and post_discounted_amt_idr <= 0*/ then 1 else 0 end) = 0 
		and vas_level_1_ctgry = 'VAS'
		and traffic_desc = 'Content Download(Initial Call Type)' and substr(video_request_url,length(video_request_url) - 2,3) = '#MT';


  drop table if exists `data-bi-prd-935c.bi_stg.vas_incoming_2`;

  create table `data-bi-prd-935c.bi_stg.vas_incoming_2` as
		SELECT 
		sbscrptn_ek_id
		FROM `data-dtptechm-prd-c7ca.dwh.charged_event_fct` a
		left join `data-dtptechm-prd-c7ca.dwh.sbscrptn_dim` sd on a.sbscrptn_sk_id = sd.sbscrptn_sk_id
		join `data-dtptechm-prd-c7ca.dwh.traffic_dim` td on a.traffic_sk_id = td.traffic_sk_id
		where 
		CAST(charge_start_dt_sk_id AS DATE) = vdt_id 
		and acct_type_cd = 'MAIN'
    and sd.rank_ind = 1 -- and CAST(sd.record_end_dtm AS DATE) >= '1900-01-01'
		and (case when event_type_sk_id = 61 /*and post_discounted_amt_idr <= 0*/ then 1 else 0 end) = 0 
		and vas_level_1_ctgry = 'VAS'
		and traffic_desc = 'Content Download(Initial Call Type)' and substr(video_request_url,length(video_request_url) - 2,3) = '#MT';

INSERT INTO `data-bi-prd-935c.bi_mart.project_rgumt_subs_detail`
SELECT
    cast(vdt_id as date) AS load_dt_sk_id,
    sbscrptn_ek_id
FROM `data-bi-prd-935c.bi_stg.subs_incoming_ict`
WHERE sbscrptn_ek_id <> -2

UNION DISTINCT

SELECT
    vdt_id AS load_dt_sk_id,
    sbscrptn_ek_id
FROM `data-bi-prd-935c.bi_stg.subs_incoming_onnet`
WHERE sbscrptn_ek_id <> -2

UNION DISTINCT

SELECT
    vdt_id AS load_dt_sk_id,
    sbscrptn_ek_id
FROM `data-bi-prd-935c.bi_stg.vas_incoming_2`
WHERE sbscrptn_ek_id <> -2

UNION DISTINCT

SELECT 
    vdt_id AS load_dt_sk_id,
    sbscrptn_ek_id
FROM `data-dtptechm-prd-c7ca.dwh.sbscrptn_attribs` a
WHERE 
    CAST(a.activation_dtm AS DATE) = CAST(vdt_id AS DATE)
    AND tool_of_trade_ind = 'N'
    AND sbscrptn_ek_id <> -2;
