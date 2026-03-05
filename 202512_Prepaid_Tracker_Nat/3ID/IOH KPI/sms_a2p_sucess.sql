DECLARE vdt_id DATE DEFAULT @vdt_id;

DELETE from `data-bi-prd-935c.bi_mart.sms_a2p_sucess` where transaction_date = vdt_id;

INSERT INTO `data-bi-prd-935c.bi_mart.sms_a2p_sucess`
select called_number,grp,transaction_date from 
(
SELECT distinct(called_number) as called_number, 'A2P Domestic' as grp, cast(transaction_date as date) as transaction_date 
from `data-dtp-prd-aa1a.sor.cdr_smsc_tango`
where cast(transaction_date as date) = vdt_id
and lower(originating_msc_address) in ('a2psmsa', 'a2psmsb') 
and record_type='1' 
and msg_status = '2'
and substring(called_number, 1, 5) in ('62895','62896', '62897','62898', '62899')

union all

SELECT distinct(called_number) as called_number, 'Google' as grp, cast(transaction_date as date) as transaction_date 
from `data-dtp-prd-aa1a.sor.cdr_smsc_tango`
where cast(transaction_date as date) = vdt_id
and lower(originating_msc_address)  like '%googlea2p%'
and record_type='1' 
and msg_status = '2'
and substring(called_number, 1, 5) in ('62895','62896', '62897','62898', '62899')

union all

select distinct(called_number) as called_number, 'Facebook' as grp, cast(transaction_date as date) as transaction_date 
from `data-dtp-prd-aa1a.sor.cdr_smsc_tango`
where cast(transaction_date as date) = vdt_id
and (lower(originating_msc_address) like '%facebook%'
or lower(originating_msc_address) like '%whatsapp%')
and record_type='1'
and msg_status = '2'
and substring(called_number, 1, 5) in ('62895','62896', '62897','62898', '62899')

union all --add below script start on 22 Feb 2025, because the A2P Domestic is move into international trunk on MSC

SELECT distinct(called_party_number) as called_number,
case
 when cast(dt_id as date) >= '2023-05-09' and upper(calling_party_number) = 'GOOGLE' then 'A2P International (MSC)'
when regexp_replace(servicecenteraddress,'^11','') = '46731210219' then 'A2P Domestic (MSC)'
when regexp_replace(servicecenteraddress,'^11','') = '46731210217' then 'A2P Domestic (MSC)'
when regexp_replace(servicecenteraddress,'^11','') = '46731213046' then 'A2P International (MSC)'
when regexp_replace(servicecenteraddress,'^11','') = '46731210215' then 'A2P International (MSC)'
when regexp_replace(servicecenteraddress,'^11','') = '46731210206' then 'A2P International (MSC)'
when regexp_replace(servicecenteraddress,'^11','') = '46731213251' then 'A2P International (MSC)'
when regexp_replace(servicecenteraddress,'^11','') = '46731210232' then 'A2P Domestic (MSC)'
when regexp_replace(servicecenteraddress,'^11','') = '46731213035' then 'A2P International (MSC)'
end grp,
cast(dt_id as date) as transaction_date
from `data-dtp-prd-aa1a.sor.msc_detail` --sor.msc_detail_3id
where cast(dt_id as date) = vdt_id
and service_type = 'SMSMT'
and regexp_replace(servicecenteraddress,'^11','') in (
'46731210219',
'46731210217',
'46731213046',
'46731210215',
'46731210206',	
'46731213251',
'46731210232', --new GT that applied on 14 Mar 2024 (info from Sumantri)
'46731213035' --New GT on 01 Jul 2025 onwards
)
and substring(called_party_number, 1, 5) in ('62895','62896', '62897','62898', '62899')
)

union distinct

select distinct msisdn as called_number, 'A2P Domestic' as tag, cast(dt_id as date) as dt
from `data-dtp-prd-aa1a.stg.smsc_cdr`
where cast(dt_id as date) = vdt_id
and record_type = '4'
and status = '3'
and substring(msisdn, 1, 5) in ('62895','62896', '62897','62898', '62899')
--and mo_serving_msc in ('1013', '1014')
and mo_serving_msc in ('1013', '1014', '1008', '1007', '2014','2013','2012','2011','2008') -- add tanggal 16 Dec rerun from 1 des 2025 req mas denny

union distinct

select distinct msisdn as called_number, 'Facebook' as tag, cast(dt_id as date) as dt
from `data-dtp-prd-aa1a.stg.smsc_cdr`
where cast(dt_id as date) = vdt_id
and record_type = '4'
and status = '3'
and substring(msisdn, 1, 5) in ('62895','62896', '62897','62898', '62899')
and mo_serving_msc in ('1051')

union distinct

-- Add 20250625 by Mas Denny Request
select distinct msisdn as called_number, 'Google' as tag, cast(dt_id as date) as dt
from `data-dtp-prd-aa1a.stg.smsc_cdr`
where cast(dt_id as date) = vdt_id
and record_type = '4'
and status = '3'
and substring(msisdn, 1, 5) in ('62895','62896', '62897','62898', '62899')
and mo_serving_msc in ('1073');