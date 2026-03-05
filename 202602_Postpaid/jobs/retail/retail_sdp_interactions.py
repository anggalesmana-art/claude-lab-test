from dagster import op, graph, schedule, DefaultScheduleStatus, repository, RetryPolicy
import jaydebeapi
import pandas as pd   
from sqlalchemy import create_engine, text 
import datetime as dt 
from datetime import timedelta   
from dagster import op, graph, schedule, DefaultScheduleStatus, repository 
from sshtunnel import SSHTunnelForwarder
import psycopg2
import time 
import os 
from dateutil.relativedelta import relativedelta  
from paramiko import SSHClient, AutoAddPolicy 
import os 
from google.cloud import bigquery
from google.auth.transport.requests import Request
from google_auth_oauthlib.flow import InstalledAppFlow
from google.oauth2.credentials import Credentials
from google.cloud.bigquery import SchemaField
from google.cloud import storage 

year_month=(dt.date.today() - timedelta(days = 2)).strftime("%Y%m") 
dt_id = (dt.date.today() - timedelta(days = 2)).strftime("%Y%m%d") 

import paramiko
import pandas as pd
import io

def execute_query(query):
    SSH_HOST = "10.34.163.126"          # Your remote Kerberos-enabled server
    SSH_USER = "hdp-rdm"
    SSH_PORT = 22
    SSH_PASSWORD = "beqkZl@6"

    IMPALA_HOST = "udc2-impala-lb.office.corp.indosat.com:25003"

    ssh = paramiko.SSHClient()
    ssh.set_missing_host_key_policy(paramiko.AutoAddPolicy())
    ssh.connect(SSH_HOST, username=SSH_USER, password=SSH_PASSWORD)

    cmd = f'impala-shell --quiet -k --ssl -i {IMPALA_HOST} -q "{query}"'

    stdin, stdout, stderr = ssh.exec_command(cmd)

    error = stderr.read().decode()

    # Ignore harmless LDAP/ID warnings
    harmless = [
        "cannot find name for group ID",
        "/usr/bin/id"
    ]
    if any(msg in error for msg in harmless):
        error = ""

    if error.strip():
        raise Exception("Impala Error: " + error)

    print("Query executed successfully.")
    ssh.close()

def get_df(query):
    SSH_HOST = "10.34.163.126"          # Your remote Kerberos-enabled server
    SSH_USER = "hdp-rdm"
    SSH_PORT = 22
    SSH_PASSWORD = "beqkZl@6"

    IMPALA_HOST = "udc2-impala-lb.office.corp.indosat.com:25003"

    ssh = paramiko.SSHClient()
    ssh.set_missing_host_key_policy(paramiko.AutoAddPolicy())
    ssh.connect(SSH_HOST, username=SSH_USER, password=SSH_PASSWORD)

    cmd = (
        f'impala-shell -B --print_header --quiet --output_delimiter="," '
        f'-k --ssl -i {IMPALA_HOST} -q "{query}"'
    )

    stdin, stdout, stderr = ssh.exec_command(cmd)

    data = stdout.read().decode()
    error = stderr.read().decode()

    ssh.close()

    # Ignore harmless OS warnings
    harmless = [
        "cannot find name for group ID",
        "/usr/bin/id"
    ]
    if any(msg in error for msg in harmless):
        error = ""

    if error.strip():
        raise Exception("Impala Error: " + error)

    # Convert to DataFrame
    df = pd.read_csv(io.StringIO(data))
    return df

# def get_df(query):
#     # JDBC driver path
#     jdbc_driver_path = "/data/hdp/ImpalaJDBC4.jar"  # Replace with your JDBC driver path

#     # Database connection properties
#     jdbc_url = "jdbc:impala://udc2-impala-lb.office.corp.indosat.com:21051/hdp-rdm;AuthMech=3;UID=94230066;SSL=1;LogLevel=6;transportMode=sasl;LogPath=/data/hdp/;SSLTrustStore=/data/hdp/truststore.jks;SSLTrustStorePassword=T$@Pwd@dl"
#     driver_class = "com.cloudera.impala.jdbc4.Driver"  # Class name for the Impala JDBC driver

#     # Connection properties (if required)
#     user = "hdp-rdm"
#     password = "beqkZl@6"
#     properties = {
#         "user": user,
#         "password": password
#     }

#     # Establishing a connection
#     try:
#         connection = jaydebeapi.connect(driver_class, jdbc_url, [user, password], jdbc_driver_path)
#         print("Connection established successfully.")

#         # Create a cursor to execute queries
#         cursor = connection.cursor()

#         # Sample query
#         cursor.execute(query)
#         print("SQL script executed successfully!")
        
#         # Fetch and print results
#         results = cursor.fetchall() 
#         column_names = [desc[0] for desc in cursor.description]  # Extract column names 

#         # Convert results to a pandas DataFrame
#         df = pd.DataFrame(results, columns=column_names)
        
#         # Closing the cursor and connection
#         cursor.close()
#         connection.close()
#         print("Connection closed.")

#     except Exception as e:
#         print(f"An error occurred: {e}") 
#     return df  

# def execute_query(query):
#     # JDBC driver path
#     jdbc_driver_path = "/data/hdp/ImpalaJDBC4.jar"  # Replace with your JDBC driver path

#     # Database connection properties
#     jdbc_url = "jdbc:impala://udc2-impala-lb.office.corp.indosat.com:21051/hdp-rdm;AuthMech=3;UID=94230066;SSL=1;LogLevel=6;transportMode=sasl;LogPath=/data/hdp/;SSLTrustStore=/data/hdp/truststore.jks;SSLTrustStorePassword=T$@Pwd@dl"
#     driver_class = "com.cloudera.impala.jdbc4.Driver"  # Class name for the Impala JDBC driver

#     # Connection properties (if required)
#     user = "hdp-rdm"
#     password = "beqkZl@6"
#     properties = {
#         "user": user,
#         "password": password
#     }

#     # Establishing a connection
#     try:
#         connection = jaydebeapi.connect(driver_class, jdbc_url, [user, password], jdbc_driver_path)
#         print("Connection established successfully.")

#         # Create a cursor to execute queries
#         cursor = connection.cursor()

#         # Sample query
#         cursor.execute(query)
#         print("SQL script executed successfully!")
        
#         # Closing the cursor and connection
#         cursor.close()
#         connection.close()
#         print("Connection closed.")

#     except Exception as e:
#         print(f"An error occurred: {e}") 

@op 
def t0_upd_idcc(last_status):
    print(last_status)   
    print(dt_id)
    # with open(f'/data/automation/Gerai_SDP_{dt_id}.txt', 'r', encoding='windows-1252') as file:
    #         lines = file.readlines()
    # df = pd.DataFrame(lines, columns=['Column1']) 
    file_path=f'/data/automation/Gerai_SDP_{dt_id}.txt'
    with open(file_path, "r", encoding="windows-1252") as file:
            lines = file.readlines()

    rows = []
    current_row = ""

    for line in lines:
        stripped = line.strip()
        if not stripped:
            continue  # skip empty lines

        if stripped.startswith(("GERAI", "MITRA IM3")):
            # kalau ada row lama, simpan dulu
            if current_row:
                rows.append(current_row.strip())
            # mulai row baru
            current_row = stripped
        else:
            # gabung dengan row terakhir
            current_row += " " + stripped

    # simpan row terakhir
    if current_row:
        rows.append(current_row.strip())

    df = pd.DataFrame(rows, columns=["Column1"])
    
    filtered_df = df[df['Column1'].str.contains('MITRA IM3', na=False)] 
    column_names = [
        'store_type', 'msisdn', 'issue_code', 'empty_column1',
        'issue_desc', 'store_code', 'start_date','created_by',
        'empty_column2', 'empty_column3', 'empty_column4'
    ]
    df_final=filtered_df['Column1'].str.split(';', expand=True)  
    df_final.columns=column_names 
    df_final.drop(columns=['empty_column1', 'empty_column2','empty_column3','empty_column4','created_by'], inplace=True) 
    df_final.loc[df_final.issue_code=='', 'issue_code']='11-Info' 
    df_final.loc[df_final.issue_code=='', 'issue_desc']='1203040043-pulse (reload) / prepaid starter pack (sp) purchasing' 
    df_final.loc[df_final.issue_desc=='', 'issue_desc']='1203040043-pulse (reload) / prepaid starter pack (sp) purchasing' 
    df_final['issue_desc_code']=df_final['issue_desc'].str.split('-').str[0].replace(' ','',regex=True).astype(str) 
    df_final['issue_desc']=df_final['issue_desc'].replace(',',' ',regex=True)
    mapping=pd.read_csv('/home/acp/retail/mapping_service_type.csv', dtype=str) 
    df_final=df_final.merge(mapping, on='issue_desc_code', how='left')
    df_final['store_code']=df_final['store_code'].str.upper() 
    ref_store = pd.read_excel("/home/acp/retail/PBI Database Retail IM3 & 3ID.xlsx", sheet_name="PBI Retail Store Ref", engine="openpyxl") 
    col=['STORE CODE GERAI', 'STORE NAME', 'CIRCLE', 'REGION']
    ref_store=ref_store[col]
    ref_store.columns=['store_code', 'store_name', 'circle', 'region']
    df_final=df_final.merge(ref_store, on='store_code', how='left') 
    df_final.dropna(subset=['circle','region','store_name'], inplace=True)
    df_final['dt_id']=pd.to_datetime(df_final['start_date']).dt.strftime('%Y%m%d')  
    df_final['month']=pd.to_datetime(df_final['start_date']).dt.strftime('%b') 
    df_final['year']=pd.to_datetime(df_final['start_date']).dt.strftime('%Y') 
    df_final['year_month']=pd.to_datetime(df_final['start_date']).dt.strftime('%Y%m') 
    df_final['month_number']=pd.to_datetime(df_final['start_date']).dt.strftime('%m')
    df_final['status']='Open'
    df_final['store_code_2']=df_final['store_code']
    df_final['year_month_2']=df_final['year_month'] 
    df_final['status_store']=''
    df_final["act_type"]="Appointment"
    columns=['act_type', 'msisdn', 'issue_desc', 'category_desc', 'intent_grouping', 'status',
            'start_date', 'dt_id', 'month', 'year', 'month_number', 'year_month', 'store_code', 
            'store_name', 'store_code_2', 'region', 'circle', 'source', 'year_month_2', 'status_store']  
    df_final['source']='IDCC'
    df_final=df_final[columns]
    
    df=df_final.copy()
    df['start_date']=pd.to_datetime(df['start_date']).dt.date
    # ==== BIGQUERY CONFIG ====
    project_id = "data-nationalslsdist-prd-986g"
    dataset_id = "retail"
    table_id = "raw_idcc_interactions_mitra_im3"
    full_table_id = f"{project_id}.{dataset_id}.{table_id}"
    client = bigquery.Client(project=project_id)
    delete_query = f"""
    DELETE FROM `{full_table_id}`
    WHERE dt_id = '{dt_id}' 
    """
    client.query(delete_query).result()
    print(f"Deleted rows in {full_table_id} where dt_id='{dt_id}'")
    # ==== APPEND NEW DATA ====
    job_config = bigquery.LoadJobConfig(
        write_disposition=bigquery.WriteDisposition.WRITE_APPEND,
        autodetect=True,
    )
    job = client.load_table_from_dataframe(df, full_table_id, job_config=job_config)
    job.result()
    print(f"Success Appended {len(df)} rows into {full_table_id}")

    # df_final.to_csv(f'/data/retail/idcc_interactions_mitra_im3_{dt_id}.csv', index=False, sep=';')
    # ssh = SSHClient()
    # ssh.set_missing_host_key_policy(AutoAddPolicy())
    # ssh.connect('10.34.163.126', username='hdp-rdm', password='beqkZl@6' , port=22)
    # sftp=ssh.open_sftp()   
    # sftp.put(f"/data/retail/idcc_interactions_mitra_im3_{dt_id}.csv", f"/home/hdp-rdm@office.corp.indosat.com/file_retail/idcc_interactions_mitra_im3_{dt_id}.csv") 
    # command=f"hdfs dfs -rm -R /data/rdm/upload/retail/idcc_interactions_mitra_im3/idcc_interactions_mitra_im3_{dt_id}.csv"
    # stdin, stdout, stderr = ssh.exec_command(command)  # Non-blocking call
    # exit_status = stdout.channel.recv_exit_status()          # Blocking call
    # if exit_status == 0:
    #     print ("running_success")
    # else:
    #     print("Error", exit_status) 
    # command=f"hdfs dfs -put /home/hdp-rdm@office.corp.indosat.com/file_retail/idcc_interactions_mitra_im3_{dt_id}.csv /data/rdm/upload/retail/idcc_interactions_mitra_im3/"
    # stdin, stdout, stderr = ssh.exec_command(command)  # Non-blocking call
    # exit_status = stdout.channel.recv_exit_status()          # Blocking call
    # if exit_status == 0:
    #     print ("running_success")
    # else:
    #     print("Error", exit_status) 
    # command='impala-shell --quiet -i udc2-impala-lb.office.corp.indosat.com:25003 -d default -k --ssl -q "refresh rdm.idcc_interactions_mitra_im3;"'
    # stdin, stdout, stderr = ssh.exec_command(command)  # Non-blocking call
    # exit_status = stdout.channel.recv_exit_status()          # Blocking call
    # if exit_status == 0:
    #     print ("running_success")
    # else:
    #     print("Error", exit_status)
    # os.system(f"rm -rf /data/retail/idcc_interactions_mitra_im3_{dt_id}.csv") 
    return 't0_upd_idcc sucess'  

@op 
def t1_ins_interactions(input_task): 
    print(input_task)    
    print(dt_id)

    project_id = "data-nationalslsdist-prd-986g"
    dataset_id = "retail"
    table_id = "raw_interaction_mitra_im3"
    full_table_id = f"{project_id}.{dataset_id}.{table_id}"
    client = bigquery.Client(project=project_id)
    delete_query = f"""
    DELETE FROM `{full_table_id}`
    WHERE mth_id = left('{dt_id}',6) 
    """
    client.query(delete_query).result()

    query=f'''
    insert into `data-nationalslsdist-prd-986g`.retail.raw_interaction_mitra_im3
    select  
            circle, 
            region, 
            store_code, 
            store_name, 
            null as transaction_id, 
            start_date transaction_date, 
            null as customer_name, 
            msisdn as customer_msisdn, 
            category_desc as service_type, 
            null as product_category, 
            null as product_name,
            status, 
            dt_id, 
            intent_grouping, 
            category_desc as category, 
            'IDCC' as source, 
            left(dt_id,6) as mth_id
        from `data-nationalslsdist-prd-986g`.retail.raw_idcc_interactions_mitra_im3 
            where left(dt_id,6)=left('{dt_id}',6) 
        union all
        select 
            b.circle, 
            b.region,
            coalesce(b.store_code, upper(trim(a.organization_ref_code))) as store_code,
            coalesce(b.store_name, upper(a.organization_name)) as store_name, 
            -- b.store_code, 
            -- b.store_name, 
            a.transaction_id, 
            date(PARSE_TIMESTAMP('%d/%m/%Y %H:%M:%S',transaction_date)) as transaction_date, 
            upper(a.customer_name) as customer_name, 
            a.customer_msisdn, 
            upper(service_type) as service_type, 
            a.product_category, 
            a.product_name, 
            a.status, 
            format_date('%Y%m%d',PARSE_TIMESTAMP('%d/%m/%Y %H:%M:%S',transaction_date)) as dt_id, 
            'Service Request' as intent_grouping, 
            'SIM Replacement' as category, 
            'IPOS' as source, 
            format_date('%Y%m',PARSE_TIMESTAMP('%d/%m/%Y %H:%M:%S',transaction_date)) as mth_id
        from `data-nationalslsdist-prd-986g`.retail.raw_ipos_nonps_trx as a  
        left join `data-nationalslsdist-prd-986g`.retail.ref_storelist as b 
            on trim(a.organization_ref_code) = trim(b.store_code) and b.mth_id=left('{dt_id}',6)
        where 1=1
            and lower(service_type) like '%sim%replacement%'  
            and ( 
                lower(b.store_name) like '%mitra%'
                or lower(a.organization_name) like 'mini gerai%'
                or lower(a.organization_name) like '%mitra%'
                or lower(a.organization_name) like '%sdp%'
                or a.channel_type='SDP'
            )
            and format_date('%Y%m',PARSE_TIMESTAMP('%d/%m/%Y %H:%M:%S',transaction_date))=left('{dt_id}',6)
    '''
    client.query(query).result()
    print('Insert Proses Finish')
    # cmd = f''' 
    # insert overwrite rdm.interaction_mitra_im3 
    # partition (mth_id)
    # select  
    #     circle, 
    #     region, 
    #     store_code, 
    #     store_name, 
    #     null as transaction_id, 
    #     SUBSTR(CAST(start_date AS STRING), 1, 10) transaction_date, 
    #     null as customer_name, 
    #     msisdn as customer_msisdn, 
    #     category_desc as service_type, 
    #     null as product_category, 
    #     null as product_name,
    #     status, 
    #     dt_id, 
    #     intent_grouping, 
    #     category_desc as category, 
    #     'IDCC' as source, 
    #     strleft(dt_id,6) as mth_id
    # from rdm.idcc_interactions_mitra_im3 
    #     where strleft(dt_id,6)=strleft('{dt_id}',6) 
    # union all
    # select 
    #     b.circle, 
    #     b.region,
    #     coalesce(b.store_code, upper(trim(a.organization_ref_code))) as store_code,
    #     coalesce(b.store_name, upper(a.organization_name)) as store_name, 
    #     -- b.store_code, 
    #     -- b.store_name, 
    #     a.transaction_id, 
    #     cast(FROM_UNIXTIME(UNIX_TIMESTAMP(a.transaction_date, 'dd/MM/yyyy HH:mm'), 'yyyy-MM-dd') as string) as transaction_date, 
    #     upper(a.customer_name) as customer_name, 
    #     a.customer_msisdn, 
    #     upper(service_type) as service_type, 
    #     a.product_category, 
    #     a.product_name, 
    #     a.status, 
    #     cast(FROM_UNIXTIME(UNIX_TIMESTAMP(a.transaction_date, 'dd/MM/yyyy HH:mm'), 'yyyyMMdd') as string) as dt_id, 
    #     'Service Request' as intent_grouping, 
    #     'SIM Replacement' as category, 
    #     'IPOS' as source, 
    #     cast(FROM_UNIXTIME(UNIX_TIMESTAMP(a.transaction_date, 'dd/MM/yyyy HH:mm'), 'yyyyMM') as string) as mth_id
    # from rdm.ipos_trans_details as a  
    # left join rdm.ref_store_retail as b 
    #     on trim(a.organization_ref_code) = trim(b.store_code)
    # where 1=1
    #     and lower(service_type) like '%sim%replacement%'  
    #     and ( 
    #         lower(b.store_name) like '%mitra%'
    #         or lower(a.organization_name) like 'mini gerai%'
    #         or lower(a.organization_name) like '%mitra%'
    #         or lower(a.organization_name) like '%sdp%'
    #         or a.channel_type='SDP'
    #     )
    #     and FROM_UNIXTIME(UNIX_TIMESTAMP(transaction_date, 'dd/MM/yyyy HH:mm'), 'yyyyMM')=strleft('{dt_id}',6)
    # '''
    # print(cmd[:50])
    # execute_query(cmd)
    return "t1_ins_interactions success"  

@op 
def t2_dump_interactions(input_task): 
    print(input_task)
    print(dt_id)
    project_id = "data-nationalslsdist-prd-986g"
    dataset_id = "retail"
    table_id = "raw_interaction_mitra_im3"
    full_table_id = f"{project_id}.{dataset_id}.{table_id}"
    client = bigquery.Client(project=project_id) 

    cmd=f'''
    select 
        source, 
        dt_id, 
        mth_id, 
        upper(store_code) store_code, 
        intent_grouping as `Intent Grouping`, 
        category as `Category`, 
        count(distinct customer_msisdn) as num_trans
    from `data-nationalslsdist-prd-986g`.retail.raw_interaction_mitra_im3
    where cast(mth_id as int) between 202201 and cast(left('{dt_id}',6) as int)
    group by 1, 2, 3, 4, 5, 6
    ''' 
    # cmd = f''' 
    # select 
    #     source, 
    #     dt_id, 
    #     mth_id, 
    #     upper(store_code) store_code, 
    #     intent_grouping as "Intent Grouping", 
    #     category as "Category", 
    #     count(distinct customer_msisdn) as num_trans
    # from rdm.interaction_mitra_im3 
    # where cast(mth_id as int) between 202201 and  {year_month}
    # group by 1, 2, 3, 4, 5, 6
    # '''
    print('dump raw interaction_mitra_im3')
    # df=get_df(cmd) 
    df=client.query(cmd).to_dataframe()
    df.columns=['source','dt_id', 'mth_id', 'store_code', 
            'Intent Grouping', 'Category', 'num_trans']  
    df['updated_dt']=dt.datetime.today() 
    df.to_excel("/data/retail/Interaction Mitra IM3.xlsx",
             sheet_name='Summary Interaction Mitra IM3', 
           index=False)
    os.system(f'''rclone copy /data/retail/"Interaction Mitra IM3.xlsx" dsn:"retail/mitra_im3/Agg Interaction Mitra IM3/"''')
    return "t2_dump_interactions success" 

@op 
def t3_dump_ipp_interactions(input_task): 
    print(input_task)
    print(dt_id) 
    cmd = f''' 
    select 
        'IPP IM3' as source, 
        cast(FROM_UNIXTIME(UNIX_TIMESTAMP(a.transaction_date, 'dd/MM/yyyy HH:mm'), 'yyyyMMdd') as string) as dt_id, 
        cast(FROM_UNIXTIME(UNIX_TIMESTAMP(a.transaction_date, 'dd/MM/yyyy HH:mm'), 'yyyyMM') as string) as mth_id, 
        upper(a.organization_ref_code) store_code, 
        'Service Request' as "Intent Grouping", 
        'SIM Replacement' as "Category", 
        count(distinct a.customer_msisdn) as num_trans
    from rdm.ipos_trans_details as a
    where cast(FROM_UNIXTIME(UNIX_TIMESTAMP(a.transaction_date, 'dd/MM/yyyy HH:mm'), 'yyyyMM') as int) between 202201 and  202411
    and a.organization_name like 'IPP%' 
    group by 1, 2, 3, 4, 5, 6  
    union all 
    select 
        'IPP 3ID' as source, 
        cast(FROM_UNIXTIME(UNIX_TIMESTAMP(a.transaction_date, 'dd/MM/yyyy HH:mm'), 'yyyyMMdd') as string) as dt_id, 
        cast(FROM_UNIXTIME(UNIX_TIMESTAMP(a.transaction_date, 'dd/MM/yyyy HH:mm'), 'yyyyMM') as string) as mth_id, 
        upper(a.organization_ref_code) store_code, 
        'Service Request' as "Intent Grouping", 
        'SIM Replacement' as "Category", 
        count(distinct a.customer_msisdn) as num_trans
    from rdm.sdp_trans_details as a
    where cast(FROM_UNIXTIME(UNIX_TIMESTAMP(a.transaction_date, 'dd/MM/yyyy HH:mm'), 'yyyyMM') as int) between 202201 and {year_month}
    and a.organization_name like 'IPP%' 
    group by 1, 2, 3, 4, 5, 6
    '''
    print('dump ipp_trans_details')
    df=get_df(cmd) 
    df.columns=['source','dt_id', 'mth_id', 'store_code', 
            'Intent Grouping', 'Category', 'num_trans']  
    df['updated_dt']=dt.datetime.today() 
    df.to_excel("/data/retail/Interaction IPP.xlsx",
             sheet_name='Interaction IPP', 
           index=False)
    os.system(f'''rclone copy /data/retail/"Interaction IPP.xlsx" dsn:"retail/mitra_im3/Agg Interaction Mitra IM3/"''')
    return "t3_dump_ipp_interactions"

# @op 
# def t4_dump_ga_cr(input_task): 
#     print(input_task)
#     print(dt_id) 
#     cmd = f''' 
#     with siebel_data as(
#         select  
#             distinct
#             a.dt_id as dt_id,
#             REGEXP_EXTRACT(a.creator_location , '^(.*?)-', 1) AS store_code, 
#             msisdn
#             -- count(distinct a.msisdn) as interactions
#             -- REGEXP_EXTRACT(a.creator_location , '-(.*)$', 1) AS store_name
#         from stg.stg_siebel_dly_intrctn as a 
#             where a.status='Closed' 
#             -- and channel='Galeri'  
#             and cast(strleft(a.dt_id,6) as int) between 202409 and cast(strleft('{dt_id}',6) as int) 
#     )    
#     , ipos_data as (	
#     select   
#     distinct
#             (FROM_UNIXTIME(UNIX_TIMESTAMP(a.transaction_date, 'dd/MM/yyyy HH:mm'), 'yyyyMMdd')) as dt_id,
#             organization_ref_code as store_code, 
#             customer_msisdn as msisdn
#         from rdm.ipos_trans_details as a
#         where cast(FROM_UNIXTIME(UNIX_TIMESTAMP(a.transaction_date, 'dd/MM/yyyy HH:mm'), 'yyyyMM') as int) between 202409 and cast(strleft('{dt_id}',6) as int)
#         and status='Success'
#     -- 	group by 1, 2, 3
#     ) 
#     , data_interactions as ( 
#         select   
#             'siebel' as source,
#             a.dt_id, 
#             a.store_code, 
#         count(distinct a.msisdn) as interactions
#         from siebel_data as a 
#         group by 1, 2, 3 
#         union all 
#         select   
#             'ipos' as source,
#             b.dt_id, 
#             b.store_code, 
#         count(distinct b.msisdn) as interactions
#         from (select 
#                 x.* 
#                 from ipos_data as x
#                 where concat(strleft(x.dt_id,6),x.store_code,x.msisdn) not in (select distinct concat(strleft(a.dt_id,6),a.store_code, a.msisdn) from siebel_data as a) 
#             )as b 
#         group by 1, 2, 3
#     )  
#     , itrx as (
#         select  
#             a.dt_id, 
#             a.store_code, 
#             sum(interactions) as interactions
#         from data_interactions as a 
#         group by 1, 2
#     )
#     , rgu_ga as(
#         select
#             a.activation_date as dt_id, 
#             a.store_code_rev as store_code, 
#             count(distinct case when lower(a.order_type) in ('migration', 'new registration') then a.msisdn end) as rgu_ga_only, 
#             count(distinct case when lower(a.order_type) in ('migration', 'change postpaid plan', 'new registration') then a.msisdn end) as rgu_ga		
#         from rdm.dump_daily_ga as a 
#         inner join rdm.storelist as b  
#             on a.store_code_rev=b.store_code 
#         where (lower(b.channel_group) like '%gerai%' or  lower(b.channel_group) like '%franchise%') 
#             and cast(strleft(a.activation_date,6) as int)between 202409 and cast(strleft('{dt_id}',6) as int)  
#         group by 1, 2
#     )  
#     , db_itrx as (
#         select 
#         b.dt_id, 
#         a.store_code
#         from (
#             select 
#             distinct 
#             store_code 
#             from rgu_ga
#         ) as a 
#         cross join (
#             select 
#             distinct 
#             dt_id
#             from rgu_ga
#         ) as b
#     )
#     , ga_combine as(
#     select 
#         a.dt_id, 
#         a.store_code, 
#         coalesce(b.rgu_ga,0) rgu_ga, 
#         coalesce(b.rgu_ga_only,0) rgu_ga_only
#     from db_itrx as a  
#     left join rgu_ga as b 
#     on a.dt_id=b.dt_id and a.store_code=b.store_code
#     ) 
#     , sum_ga as (
#         select 
#             a.dt_id,   
#             b.circle,  
#             b.region_circle, 
#             b.area, 
#             b.sales_area, 
#             upper(b.store_name) store_name, 
#             b.channel_group,
#             a.store_code,  
#             rgu_ga, 
#             rgu_ga_only
#         from ga_combine as a 
#             left join rdm.storelist as b
#             on a.store_code=b.store_code 
#     )  
#     , final_result as(
#         select  
#             a.dt_id,   
#             FROM_UNIXTIME(UNIX_TIMESTAMP(a.dt_id, 'yyyyMMdd'), 'yyyy-MM-dd') as trx_date,
#             strleft(a.dt_id,6) as mth_id,
#             a.circle, 
#             a.region_circle, 
#             a.area, 
#             a.sales_area, 
#             a.store_name, 
#             a.channel_group, 
#             a.store_code, 
#             a.rgu_ga,
#             a.rgu_ga_only, 
#             coalesce(b.interactions,0) unique_visitors
#         from sum_ga as a
#         left join itrx as b 
#         on a.store_code=b.store_code and a.dt_id=b.dt_id 
#     )  
#     select 
#         a.dt_id,
#         a.trx_date,
#         a.mth_id, 
#         a.circle, 
#         a.region_circle, 
#         a.area, 
#         a.sales_area, 
#         a.store_name, 
#         a.channel_group, 
#         a.store_code,   
#         sum(a.rgu_ga) as rgu_ga, 
#         sum(a.rgu_ga_only) as rgu_ga_only, 
#         sum(unique_visitors) as unique_visitors, 
#         round((sum(a.rgu_ga)/sum(unique_visitors))*100,2) as conversion_rate_ga, 
#         round((sum(a.rgu_ga_only)/sum(unique_visitors))*100,2) as conversion_rate_ga_only, 
#         CAST(FLOOR(DATEDIFF(a.trx_date, DATE_TRUNC('YEAR', a.trx_date)) / 7) + 1 AS INT) AS week_of_year
#     from final_result as a 
#     group by 1, 2, 3, 4, 5, 6, 7, 8, 9, 10, 16;
#     '''
#     print('dump Gerai GA Convertion Rate')
#     df=get_df(cmd) 
#     # df.columns=['source','dt_id', 'mth_id', 'store_code', 
#     #         'Intent Grouping', 'Category', 'num_trans']  
#     # df['updated_dt']=dt.datetime.today() 
#     df.to_excel("/data/retail/Gerai GA Conversion Rate.xlsx",
#              sheet_name='Gerai GA Conversion Rate', 
#            index=False)
#     os.system(f'''rclone copy /data/retail/"Gerai GA Conversion Rate.xlsx" dsn:"retail/gerai/"''')
#     return "t4_dump_ga_cr"


@op 
def t4_dump_ga_cr(input_task): 
    print(input_task)
    print(dt_id) 
    cmd = f''' 
    insert overwrite rdm.gerai_ga_conversion_rate 
    partition (mth_id)
    with siebel_data as(
            select  
                distinct
                a.dt_id as dt_id,
                REGEXP_EXTRACT(a.creator_location , '^(.*?)-', 1) AS store_code, 
                msisdn
                -- count(distinct a.msisdn) as interactions
                -- REGEXP_EXTRACT(a.creator_location , '-(.*)$', 1) AS store_name
            from stg.stg_siebel_dly_intrctn as a 
                where a.status='Closed' 
                -- and channel='Galeri'  
                and cast(strleft(a.dt_id,6) as int) = cast(strleft('{dt_id}',6) as int) 
        )    
        , ipos_data as (	
        select   
        distinct
                (FROM_UNIXTIME(UNIX_TIMESTAMP(a.transaction_date, 'dd/MM/yyyy HH:mm'), 'yyyyMMdd')) as dt_id,
                organization_ref_code as store_code, 
                customer_msisdn as msisdn
            from rdm.ipos_trans_details as a
            where cast(FROM_UNIXTIME(UNIX_TIMESTAMP(a.transaction_date, 'dd/MM/yyyy HH:mm'), 'yyyyMM') as int) = cast(strleft('{dt_id}',6) as int)
            and status='Success'
        -- 	group by 1, 2, 3
        ) 
        , data_interactions as ( 
            select   
                'siebel' as source,
                a.dt_id, 
                a.store_code, 
            count(distinct a.msisdn) as interactions
            from siebel_data as a 
            group by 1, 2, 3 
            union all 
            select   
                'ipos' as source,
                b.dt_id, 
                b.store_code, 
            count(distinct b.msisdn) as interactions
            from (select 
                    x.* 
                    from ipos_data as x
                    where concat(strleft(x.dt_id,6),x.store_code,x.msisdn) not in (select distinct concat(strleft(a.dt_id,6),a.store_code, a.msisdn) from siebel_data as a) 
                )as b 
            group by 1, 2, 3
        )  
        , itrx as (
            select  
                a.dt_id, 
                a.store_code, 
                sum(interactions) as interactions
            from data_interactions as a 
            group by 1, 2
        )
        , rgu_ga as(
            select
                a.activation_date as dt_id, 
                a.store_code_rev as store_code, 
                count(distinct case when lower(a.order_type) in ('migration', 'new registration') then a.msisdn end) as rgu_ga_only, 
                count(distinct case when lower(a.order_type) in ('migration', 'change postpaid plan', 'new registration') then a.msisdn end) as rgu_ga		
            from rdm.dump_daily_ga as a 
            inner join rdm.storelist as b  
                on a.store_code_rev=b.store_code 
            where (lower(b.channel_group) like '%gerai%' or  lower(b.channel_group) like '%franchise%') 
                and cast(strleft(a.activation_date,6) as int)= cast(strleft('{dt_id}',6) as int)  
            group by 1, 2
        )  
        , db_itrx as (
            select 
            b.dt_id, 
            a.store_code
            from (
                select 
                distinct 
                store_code 
                from rgu_ga
            ) as a 
            cross join (
                select 
                distinct 
                dt_id
                from rgu_ga
            ) as b
        )
        , ga_combine as(
        select 
            a.dt_id, 
            a.store_code, 
            coalesce(b.rgu_ga,0) rgu_ga, 
            coalesce(b.rgu_ga_only,0) rgu_ga_only
        from db_itrx as a  
        left join rgu_ga as b 
        on a.dt_id=b.dt_id and a.store_code=b.store_code
        ) 
        , sum_ga as (
            select 
                a.dt_id,   
                b.circle,  
                b.region_circle, 
                b.area, 
                b.sales_area, 
                upper(b.store_name) store_name, 
                b.channel_group,
                a.store_code,  
                rgu_ga, 
                rgu_ga_only
            from ga_combine as a 
                left join rdm.storelist as b
                on a.store_code=b.store_code 
        )  
        , final_result as(
            select  
                a.dt_id,   
                FROM_UNIXTIME(UNIX_TIMESTAMP(a.dt_id, 'yyyyMMdd'), 'yyyy-MM-dd') as trx_date,
                strleft(a.dt_id,6) as mth_id,
                a.circle, 
                a.region_circle, 
                a.area, 
                a.sales_area, 
                a.store_name, 
                a.channel_group, 
                a.store_code, 
                a.rgu_ga,
                a.rgu_ga_only, 
                coalesce(b.interactions,0) unique_visitors
            from sum_ga as a
            left join itrx as b 
            on a.store_code=b.store_code and a.dt_id=b.dt_id 
        )  
        select 
            a.dt_id,
            a.trx_date,
            a.circle, 
            a.region_circle, 
            a.area, 
            a.sales_area, 
            a.store_name, 
            a.channel_group, 
            a.store_code,   
            sum(a.rgu_ga) as rgu_ga, 
            sum(a.rgu_ga_only) as rgu_ga_only, 
            sum(unique_visitors) as unique_visitors, 
            round((sum(a.rgu_ga)/sum(unique_visitors))*100,2) as conversion_rate_ga, 
            round((sum(a.rgu_ga_only)/sum(unique_visitors))*100,2) as conversion_rate_ga_only, 
            CAST(FLOOR(DATEDIFF(a.trx_date, DATE_TRUNC('YEAR', a.trx_date)) / 7) + 1 AS INT) AS week_of_year, 
            a.mth_id
        from final_result as a 
        group by 1, 2, 3, 4, 5, 6, 7, 8, 9, 15, 16;
    ''' 
    print('Ins GA Conversion Rate') 
    execute_query(cmd)  
    
    cmd=f''' 
    select 
        a.dt_id,
        a.trx_date,
        a.mth_id, 
        a.circle, 
        a.region_circle, 
        a.area, 
        a.sales_area, 
        a.store_name, 
        a.channel_group, 
        a.store_code,    
        a.rgu_ga, 
        a.rgu_ga_only, 
        a.unique_visitors, 
        a.conversion_rate_ga, 
        a.conversion_rate_ga_only,  
        week_of_year
    from rdm.gerai_ga_conversion_rate as a
    '''
    print('dump Gerai GA Convertion Rate')
    df=get_df(cmd) 
    # df.columns=['source','dt_id', 'mth_id', 'store_code', 
    #         'Intent Grouping', 'Category', 'num_trans']  
    # df['updated_dt']=dt.datetime.today() 
    df.to_excel("/data/retail/Gerai GA Conversion Rate.xlsx",
             sheet_name='Gerai GA Conversion Rate', 
           index=False)
    os.system(f'''rclone copy /data/retail/"Gerai GA Conversion Rate.xlsx" dsn:"retail/gerai/"''') 
    os.system(f'''rclone copy dsn:"retail/gerai/Gerai GA Conversion Rate.xlsx" dsn:"Retail Performance Management - R100/gerai_ga_cr"''')
    return "t4_dump_ga_cr"

@op 
def t5_dcco_ga_cr(input_task): 
    print(input_task)
    print(dt_id) 
    cmd = f'''
    insert into rdm.gerai_ga_conversion_rate_summary
    with MaxDate AS (
        SELECT
        max(dt_id) dt_id,
        max(trx_date) max_date
        FROM rdm.gerai_ga_conversion_rate
        where dt_id <= '{dt_id}')
    SELECT
        x.dt_id,
        strleft(x.dt_id,6) as mth_id,
        x.circle,
        x.region_circle,
        x.rgu_ga_mtd,
        x.rgu_ga_lmtd,
        x.rgu_ga_only_mtd,
        x.rgu_ga_only_lmtd,
        x.unique_visitors_mtd,
        x.unique_visitors_lmtd,
        coalesce(round((x.rgu_ga_mtd/x.unique_visitors_mtd)*100,2),0) as conversion_rate_ga_mtd,
        coalesce(round((x.rgu_ga_lmtd/x.unique_visitors_lmtd)*100,2),0) as conversion_rate_ga_lmtd,
        coalesce(round((x.rgu_ga_only_mtd/x.unique_visitors_mtd)*100,2),0) as conversion_rate_ga_only_mtd,
        coalesce(round((x.rgu_ga_only_lmtd/x.unique_visitors_lmtd)*100,2),0) as conversion_rate_ga_only_lmtd
    FROM
    (SELECT 
        m.dt_id,
        circle,
        region_circle,
        SUM(CASE 
                WHEN t.trx_date >= TRUNC(m.max_date, 'MM') 
                AND t.trx_date <= m.max_date 
                THEN t.rgu_ga 
                ELSE 0 
            END) AS rgu_ga_mtd,
        SUM(CASE 
                WHEN t.trx_date >= TRUNC(ADD_MONTHS(m.max_date, -1), 'MM') 
                AND t.trx_date <= ADD_MONTHS(m.max_date, -1) 
                THEN t.rgu_ga 
                ELSE 0 
            END) AS rgu_ga_lmtd,
        SUM(CASE 
                WHEN t.trx_date >= TRUNC(m.max_date, 'MM') 
                AND t.trx_date <= m.max_date 
                THEN t.rgu_ga_only 
                ELSE 0 
            END) AS rgu_ga_only_mtd,
        SUM(CASE 
                WHEN t.trx_date >= TRUNC(ADD_MONTHS(m.max_date, -1), 'MM') 
                AND t.trx_date <= ADD_MONTHS(m.max_date, -1) 
                THEN t.rgu_ga_only 
                ELSE 0 
            END) AS rgu_ga_only_lmtd,
        SUM(CASE 
                WHEN t.trx_date >= TRUNC(m.max_date, 'MM') 
                AND t.trx_date <= m.max_date 
                THEN t.unique_visitors 
                ELSE 0 
            END) AS unique_visitors_mtd,
        SUM(CASE 
                WHEN t.trx_date >= TRUNC(ADD_MONTHS(m.max_date, -1), 'MM') 
                AND t.trx_date <= ADD_MONTHS(m.max_date, -1) 
                THEN t.unique_visitors 
                ELSE 0  
            END) AS unique_visitors_lmtd
    FROM rdm.gerai_ga_conversion_rate t
    CROSS JOIN MaxDate m
    group by 1,2,3) x
    '''
    print('dcco retail conversion Rate') 
    execute_query(cmd)
    
    cmd=f'''
    select
        dt_id,
        mth_id,
        circle,
        region_circle,
        rgu_ga_mtd,
        rgu_ga_lmtd,
        rgu_ga_only_mtd,
        rgu_ga_only_lmtd,
        unique_visitors_mtd,
        unique_visitors_lmtd,
        coalesce(conversion_rate_ga_mtd,0) as conversion_rate_ga_mtd,
        coalesce(conversion_rate_ga_lmtd,0) as conversion_rate_ga_lmtd,
        coalesce(conversion_rate_ga_only_mtd,0) as conversion_rate_ga_only_mtd,
        coalesce(conversion_rate_ga_only_lmtd,0) as conversion_rate_ga_only_lmtd
    from rdm.gerai_ga_conversion_rate_summary
    '''
    print('dump retail dcco tracker')
    df=get_df(cmd)
    df.to_excel("/data/retail/retail_dcco_tracker.xlsx",
        sheet_name='retail_dcco_tracker', 
        index=False)
    os.system(f'''rclone copy /data/retail/"retail_dcco_tracker.xlsx" dsn:"retail/kpi_retail/dcco_tracker/"''')
    return "t5_dcco_ga_cr"


@graph
def retail_interactions(last_status): 
    t0 = t0_upd_idcc(last_status)
    t1 = t1_ins_interactions(t0) 
    t2 = t2_dump_interactions(t1)
    # t3 = t3_dump_ipp_interactions(t2)
    # t4 = t4_dump_ga_cr(t3)
    # t5 = t5_dcco_ga_cr(t4)

    # t4 = t4_dump_ga_cr(last_status)

    return t2