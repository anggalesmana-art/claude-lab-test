DECLARE observation_date DATE DEFAULT @vdt_id;
DECLARE start_current_month  DATE DEFAULT DATE_TRUNC(observation_date, MONTH);
DECLARE eop_previous_month DATE DEFAULT LAST_DAY(DATE_SUB(observation_date, INTERVAL 1 MONTH));
DECLARE start_previous_month DATE DEFAULT DATE_TRUNC(LAST_DAY(DATE_SUB(observation_date, INTERVAL 1 MONTH)), MONTH);

-- insert overwrite table biadm.rk_pstpaid_tracker_payment_region_v2 partition(dt_id)
delete from `data-bi-prd-935c.bi_dev.pstpaid_tracker_payment_region_v2`
where date(dt_id) = observation_date;

insert into `data-bi-prd-935c.bi_dev.pstpaid_tracker_payment_region_v2`
WITH POSTCOLLECTION AS (
	select account_num, flag_payment, payment_bln, pay_point channel, sum(payment_amt) payment_amt from 
		(
		select account_num, invoice_num, ac_inv, payment_bln, pay_point, pay_point2, flag_payment, sum(allocation_mny) payment_amt 
		 from 
			(
			select account_num, invoice_num, ac_inv, payment_bln, allocation_mny, account_payment_seq, pay_point2, 
				case
					when lower(pay_point) like 'gerai%' then "GERAI"
					when lower(pay_point) like '%bank%' then "BANK"
					when lower(pay_point) like '%debet%' then "BANK"
					when lower(pay_point) like '%debit%' then "BANK"
					when lower(pay_point) like '%credit%' then "BANK"
					when lower(pay_point) like 'jv%' then "PARTNER"
					when lower(pay_point) like '%/min%' then "GERAI"
					when lower(pay_point) like '%mpc%' then "GERAI"
					when lower(pay_point) like '%ios%' then "PARTNER"
					when lower(pay_point) like 'tp%' then "PARTNER"
					when lower(pay_point) like '%samsung%' then "PARTNER"
					when lower(pay_point) like '%oppo%' then "PARTNER"
					when lower(pay_point) like '%teller%' then "GERAI"
					when lower(trim(pay_point)) = 'griya' then "PARTNER"
					when lower(pay_point) like '%store%' then "PARTNER"
					when lower(pay_point) like 'dana' then "ONLINE"
					when lower(pay_point) like 'atm' then "BANK"
					when lower(pay_point) like 'mandiri' then "BANK"
					when lower(pay_point) like '%chat%' then "MyIM3"
					when lower(pay_point) like 'qris' then "ONLINE"
					when lower(pay_point) like 'gopay' then "ONLINE"
					when lower(pay_point) like 'virtual account' then "BANK"
					when lower(pay_point) like 'pos' then "PT POS"
					when lower(pay_point) like '%bank%' then "BANK"
					when lower(pay_point) like '%im3%' then "MyIM3"
					when lower(pay_point) like 'ds%' then "GERAI"
					when lower(pay_point) like '%bca%' then "BANK"
					when lower(pay_point) like 'ovo' then "ONLINE"
					when lower(pay_point) like 'digital%' then "ONLINE"
				--     when lower(pay_point) like '%jakarta direct channel%' then "Jakarta Direct Channel"
					-- when lower(pay_point) like '%-%' then "AM-CKRG"
				--     when lower(nvl(pay_point, '')) like '' then "UNK"
					else 'UNKNOWN' end 
				pay_point,
				case
					when diff_month < 1 then 'M0'
					when diff_month < 2 then 'M1'
					when diff_month < 3 then 'M2'
					when diff_month < 4 then 'M3'
					when diff_month >= 4 then 'M3+'
					when diff_month is null then 'UNK'
				end as flag_payment
			 from 
				(
				select
					account_num,
					invoice_num,  
					concat(account_num,'-',invoice_num) ac_inv,
					account_payment_seq,
					date(payment_dtm) payment_bln, 
					allocation_mny, 
					case
						when TRIM(SPLIT(account_payment_txt, '|')[OFFSET(2)]) = 'Cash' then account_payment_ref
						when TRIM(SPLIT(account_payment_txt, '|')[OFFSET(2)]) != '' then TRIM(SPLIT(account_payment_txt, '|')[OFFSET(2)])
						when TRIM(SPLIT(account_payment_txt, '|')[OFFSET(2)])  = '' and upper(account_payment_ref) like '%IM3%' then account_payment_ref
						else TRIM(SPLIT(account_payment_txt, '|')[OFFSET(1)])
					end as pay_point,
					TRIM(SPLIT(account_payment_txt, '|')[OFFSET(1)]) pay_point2,
					date_diff(
						date(payment_dtm),
						date(actual_bill_dtm), Month
					) as diff_month,
					rank() over(partition by account_payment_seq order by prc_dt desc) as rangking
				 from `data-dtp-prd-aa1a.sor.rbm_bill_pymt`
				 where date(dt_id) between start_current_month and observation_date
				   and job_id like'%EB%' 
				   and upper(invoice_num) not like '%DEP%'
				   and upper(invoice_num) not like 'DEP%'
			) y3
		 where rangking=1
		 group by 1,2,3,4,5,6,7,8,9  
		) y2
	 group by 1,2,3,4,5,6,7
	) y1
	where payment_amt > 0
	group by 1,2,3,4
),
ref_store as (
    select store_code territory_id, circle, region region_circle, area, branch
    from `data-bi-prd-935c.bi_mart.pstpaid_store_ref_new`
    where coalesce(TRIM(UPPER(circle)),'') not in ('OTHERS','')
    and TRIM(UPPER(store_code)) not in (
        'JKBB',
        'JKBA',
        'ESEP',
        'LOC0'
    )
),
ref_dealer as (
    select 
        territory_id,
        circle,
        region_circle,
        area,
        branch
    from `data-bi-prd-935c.bi_mart.ref_pstpaid_rtl_dealer_test`
    where coalesce(TRIM(UPPER(branch)),'') not in ('OTHERS','')
),
ref_store_dealer as (
  select distinct coalesce(a.territory_id,b.territory_id) as territory_id,
    coalesce(a.circle, b.circle) as circle,
    coalesce(a.region_circle, b.region_circle) as region,
    coalesce(a.area,b.area) as area,
    coalesce(a.branch,b.branch) as branch
  from ref_store a
  full join ref_dealer b
    on a.territory_id=b.territory_id
),
ref_territory as (
    select 
        upper(territory_id) territory_id, 
        case
            when upper(circle) = '' then null
            when upper(circle) = 'OTHERS' then null
            when upper(circle) = 'OTHERS' then null
            else upper(circle)
        end as circle,
        case
            when upper(region) = '' then null
            when upper(region) = 'UNKNOWN' then null
            when upper(region) = 'OTHERS' then null
            else upper(region)
        end as region_circle,
        case
            when upper(area) = '' then null
            when upper(area) = 'UNKNOWN' then null
            when upper(area) = 'OTHERS' then null
            else upper(area)
        end as area,
        case
            when upper(branch) = '' then null
            when upper(branch) = 'UNKNOWN' then null
            when upper(branch) = 'OTHERS' then null
            else upper(branch)
        end as branch
    from (
        select territory_id, circle, region, area, branch
        from ref_store_dealer
        union all
        select site_id as territory_id, circle, region_circle as region, area, sales_area branch
        from `data-bi-prd-935c.bi_mart.ref_site`
    ) a
),
fnl AS (
    select	
    	observation_date dt_id
    	, account_num
    	, case
    		when channel='BANK' then 'POS0085'
    		when channel='ONLINE' then 'POS0086'
    		when channel='MODERN' then 'POS0087'
    		when channel='MyIM3' then 'POS0088'
    		when channel='PT POS' then 'POS0089'
    		when channel='PARTNER' then 'POS0090'
    		when channel='GERAI' then 'POS0091'
    		when channel = 'UNKNOWN' then 'POS0092'
    	end kpi_id
    	, case
    		when channel='BANK' then 'post_payment_bank'
    		when channel='ONLINE' then 'post_payment_online'
    		when channel='MODERN' then 'post_payment_modern'
    		when channel='MyIM3' then 'post_payment_myim3'
    		when channel='PT POS' then 'post_payment_ptpos'
    		when channel='PARTNER' then 'post_payment_partner'
    		when channel='GERAI' then 'post_payment_gerai'
    		when channel = 'UNKNOWN' then 'post_payment_unknown'
    	end kpi_code
    	, 'DLY' flag
    	, sum(payment_amt) metric
    from POSTCOLLECTION
    where date(payment_bln) between start_current_month and observation_date
    group by 1,2,3,4
    union all 
    select	
    	observation_date dt_id
    	, account_num
    	, case
    		when flag_payment='M0' then 'POSN001'
    		when flag_payment='M1' then 'POSN002'
    		when flag_payment='M2' then 'POSN003'
    		when flag_payment='M3' then 'POSN004'
    		when flag_payment is null then 'POSN005'
    		else 'POSN006'
    	end kpi_id
    	, case
    		when flag_payment='M0' then 'post_payment_m0'
    		when flag_payment='M1' then 'post_payment_m1'
    		when flag_payment='M2' then 'post_payment_m2'
    		when flag_payment='M3' then 'post_payment_m3'
    		when flag_payment is null then 'post_payment_unk'
    		else 'post_payment_m3+'
    	end kpi_code
    	, 'DLY' flag
    	, sum(payment_amt) metric
    from POSTCOLLECTION
    where date(payment_bln) between start_current_month and observation_date
    group by 1,2,3,4
)
select 
    "IM3" brand,
    "POSTPAID" page,
    b.circle,
    b.region_circle,
    b.area,
    b.branch,
    kpi_code,
    "MTD" flag,
    sum(metric) metric,
    observation_date dt_id
from fnl a 
left join (
    select * from (
        select ac_num, coalesce(b.circle, ioh_circle) circle,
        coalesce(b.region_circle, ioh_region) region_circle,
        coalesce(b.area, ioh_area) area,
        coalesce(b.branch, ioh_sa) branch, dt_id, row_number() over(partition by ac_num order by dt_id desc) rk
        from  `data-bi-prd-935c.bi_mart.cst_pstpaid_rtl_detail_v3` a                           -- masih schema di impala, belum di angkat ke GCP, ini contoh yang udah di testing `data-bi-prd-935c.bi_dm.moti_testing` 
        left join ref_territory b
        on TRIM(UPPER(a.territory_iom))=TRIM(UPPER(b.territory_id))
        left join `data-bi-prd-935c.bi_mart.sa_aggregate_ref` c
        on TRIM(UPPER(a.sa_aggregate)) =TRIM(UPPER(c.sales_area_ga))
    ) a 
    where rk = 1
) b 
on a.account_num = b.ac_num
group by 1,2,3,4,5,6,7,8,10;