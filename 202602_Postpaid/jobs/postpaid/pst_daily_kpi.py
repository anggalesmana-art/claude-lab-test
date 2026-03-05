from dagster import op, graph, schedule, DefaultScheduleStatus, repository 
from sshtunnel import SSHTunnelForwarder
import psycopg2
import pandas as pd
import datetime as dt 
from datetime import timedelta  
import time  
import os 
from dateutil.relativedelta import relativedelta 
import smbclient
import shutil
import jaydebeapi 
from sqlalchemy import create_engine, text  
import paramiko 
from paramiko import SSHClient, AutoAddPolicy 
import glob
from urllib.request import URLopener
from google.cloud import bigquery
from dateutil.relativedelta import relativedelta 
from google.cloud import bigquery
from google.auth.transport.requests import Request
from google_auth_oauthlib.flow import InstalledAppFlow
from google.oauth2.credentials import Credentials
from google.cloud.bigquery import SchemaField 

# Get data D-2 
year_month=(dt.date.today() - timedelta(days = 2)).strftime("%Y%m") 
dt_id = (dt.date.today() - timedelta(days = 2)).strftime("%Y%m%d")  
# Manual Data
# year_month='202503' 
# dt_id = '20250304'
## Function for grab, read, and execute data in Hadoop
        
def hdp_get_df(query):
    # JDBC driver path
    jdbc_driver_path = "/data/hdp/ImpalaJDBC4.jar"  # Replace with your JDBC driver path

    # Database connection properties
    jdbc_url = "jdbc:impala://udc2-impala-lb.office.corp.indosat.com:21051/hdp-rdm;AuthMech=3;UID=94230066;SSL=1;LogLevel=6;transportMode=sasl;LogPath=/data/hdp/;SSLTrustStore=/data/hdp/truststore.jks;SSLTrustStorePassword=T$@Pwd@dl"
    driver_class = "com.cloudera.impala.jdbc4.Driver"  # Class name for the Impala JDBC driver

    # Connection properties (if required)
    user = "hdp-rdm"
    password = "beqkZl@6"
    properties = {
        "user": user,
        "password": password
    }

    # Establishing a connection
    try:
        connection = jaydebeapi.connect(driver_class, jdbc_url, [user, password], jdbc_driver_path)
        print("Connection established successfully.")

        # Create a cursor to execute queries
        cursor = connection.cursor()

        # Sample query
        cursor.execute(query)
        print("SQL script executed successfully!")
        
        # Fetch and print results
        results = cursor.fetchall() 
        column_names = [desc[0] for desc in cursor.description]  # Extract column names 

        # Convert results to a pandas DataFrame
        df = pd.DataFrame(results, columns=column_names)
        
        # Closing the cursor and connection
        cursor.close()
        connection.close()
        print("Connection closed.")

    except Exception as e:
        print(f"An error occurred: {e}") 
    return df  

def hdp_execute_query(query):
    # JDBC driver path
    jdbc_driver_path = "/data/hdp/ImpalaJDBC4.jar"  # Replace with your JDBC driver path

    # Database connection properties
    jdbc_url = "jdbc:impala://udc2-impala-lb.office.corp.indosat.com:21051/hdp-rdm;AuthMech=3;UID=94230066;SSL=1;LogLevel=6;transportMode=sasl;LogPath=/data/hdp/;SSLTrustStore=/data/hdp/truststore.jks;SSLTrustStorePassword=T$@Pwd@dl"
    driver_class = "com.cloudera.impala.jdbc4.Driver"  # Class name for the Impala JDBC driver

    # Connection properties (if required)
    user = "hdp-rdm"
    password = "beqkZl@6"
    properties = {
        "user": user,
        "password": password
    }

    # Establishing a connection
    try:
        connection = jaydebeapi.connect(driver_class, jdbc_url, [user, password], jdbc_driver_path)
        print("Connection established successfully.")

        # Create a cursor to execute queries
        cursor = connection.cursor()

        # Sample query
        cursor.execute(query)
        print("SQL script executed successfully!")
        
        # Closing the cursor and connection
        cursor.close()
        connection.close()
        print("Connection closed.")

    except Exception as e:
        print(f"An error occurred: {e}") 

# @op 
# def t0_payment_report(): 
#     filename = '/data/data_automation_bai/data_automation_scheduling/scripts/postpaid/postpaid_payment_report.sql'
#     fd = open(filename, 'r')
#     sql_file = fd.read() 
#     sql_file=sql_file.format(**{"year_month": year_month, 
#                                 "dt_id": dt_id
#                                 })
#     fd.close() 
#     query = sql_file.split(';') 

#     print(f'Inserting row in table im3 rdm.postpaid_payment_monthly where mth_id : {year_month}') 
#     hdp_execute_query(query[0]) 

#     status_job = 'inserting row in table : success'
#     print(status_job)
    
#     df=hdp_get_df(query[1]) 
#     df.to_excel(f"/data/postpaid/platinum_monthly_payment_{year_month}.xlsx", 
#          index=False)
#     os.system(f'''rclone copy /data/postpaid/platinum_monthly_payment_{year_month}.xlsx dsn:postpaid/''') 
    
#     os.system(f'''rclone copy dsn:postpaid/platinum_monthly_payment_{year_month}.xlsx dsn:"Retail Performance Management - R100/platinum_monthly_payment"''')  
    
#     # local_file = f"/data/retail/im3_sce_ga_{year_month}.xlsx"
#     # remote_path = f"\\\\{server}\\S100\\{share}\\im3_sce_ga_{year_month}.xlsx" 
    
#     # # Configure SMB authentication
#     # smbclient.ClientConfig(username=username, password=password)
#     # # Upload file
#     # with open(local_file, "rb") as src, smbclient.open_file(remote_path, mode="wb") as dst:
#     #     shutil.copyfileobj(src, dst)
#     print("File uploaded successfully!") 
    
#     os.system(f'''rm -rf /data/postpaid/platinum_monthly_payment_{year_month}.xlsx''') 
#     return status_job 

@op 
def t0_payment_report(): 
    filename = '/data/data_automation_bai/data_automation_scheduling/scripts/postpaid/postpaid_payment_report.sql'
    fd = open(filename, 'r')
    sql_file = fd.read() 
    sql_file=sql_file.format(**{"year_month": year_month, 
                                "dt_id": dt_id
                                })
    fd.close() 
    query = sql_file.split(';') 
    
    bq_project = "data-nationalslsdist-prd-986g"
    bq_dataset = "postpaid" 
    bq_table = "raw_monthly_payment"
    client = bigquery.Client(project=bq_project)

    print('Start Deleting Raw Monthly Payment')
    query_delete=f""" 
    delete from `data-nationalslsdist-prd-986g`.postpaid.raw_monthly_payment 
        where mth_id=left('{dt_id}', 6);
    """
    # print(query)
    job_config = bigquery.QueryJobConfig(
        query_parameters=[
            bigquery.ScalarQueryParameter("year_month", "STRING", year_month),
            bigquery.ScalarQueryParameter("dt_id", "STRING", dt_id)
        ]
    )
 
    try:
        job = client.query(query_delete, job_config=job_config)
        job.result()  # Wait for the job to complete
        print(f"Finish deleting `data-nationalslsdist-prd-986g`.postpaid.raw_monthly_payment")
    except Exception as e:
        print(f"Error deleting `data data-nationalslsdist-prd-986g`.postpaid.raw_monthly_payment")
        raise

    job_config = bigquery.QueryJobConfig(
        query_parameters=[
            bigquery.ScalarQueryParameter("year_month", "STRING", year_month),
            bigquery.ScalarQueryParameter("dt_id", "STRING", dt_id)
        ]
    )
 
    try:
        job = client.query(query[0], job_config=job_config)
        job.result()  # Wait for the job to complete
        print(f"Inserting new data to `data-nationalslsdist-prd-986g`.postpaid.raw_monthly_payment")
    except Exception as e:
        print(f"Error inserting new `data data-nationalslsdist-prd-986g`.postpaid.raw_monthly_payment")
        raise
    
    print('Starting dump report monthly payment')
    bq_project = "data-nationalslsdist-prd-986g"
    bq_dataset = "postpaid" 
    bq_table = "raw_monthly_payment"
    client = bigquery.Client(project=bq_project)
    # Your SQL query
    query = f"""
        SELECT *
        FROM `{bq_project}.{bq_dataset}.{bq_table}`
        WHERE mth_id=left('{dt_id}', 6)
    """
    # Run query and return DataFrame
    df = client.query(query).to_dataframe()
    df.to_excel(f"/data/postpaid/platinum_monthly_payment_{year_month}.xlsx", 
         index=False)
    os.system(f'''rclone copy /data/postpaid/platinum_monthly_payment_{year_month}.xlsx dsn:postpaid/''')
    os.system(f'''rclone copy dsn:postpaid/platinum_monthly_payment_{year_month}.xlsx dsn:"Retail Performance Management - R100/platinum_monthly_payment"''')
    print("File uploaded successfully!") 
    os.system(f'''rm -rf /data/postpaid/platinum_monthly_payment_{year_month}.xlsx''') 
    status_job='Success Job'
    return status_job


def safe_format_date(val):
    try:
        return pd.to_datetime(val).strftime('%Y%m%d')
    except:
        return val  # return original value if conversion fails

@op
def t1_storelist_update(last_task):
    print(last_task)
    year_month=(dt.date.today()).strftime("%Y%m")
    dt_id = (dt.date.today()).strftime("%Y%m%d")
    os.system(f'''rclone copy dsn:"Data/Power BI Dashboard/Store/" dsn:retail --include "Database Hirearki Store Historical.xlsx"''')
    os.system(f'''rclone copy dsn:retail /data/retail --include "Database Hirearki Store Historical.xlsx"''')
    df = pd.read_excel('/data/retail/Database Hirearki Store Historical.xlsx', engine="openpyxl", dtype=str)
    df.columns=['registered_date',
    'store_name',
    'store_code',
    'hos',
    'bsm',
    'manager_rcm',
    'promotor',
    'region',
    'area',
    'sales_area',
    'city',
    'channel_group',
    'channel_detail',
    'province',
    'longitude',
    'latitude',
    'pic_name',
    'pic_email',
    'pic_phone_no',
    'address',
    'closed_date',
    'postpaid_manger',
    'hor',
    'nik_hor_era',
    'hor_era_name',
    'nik_hot_era',
    'head_of_territory_era_name',
    'nik_tsh_era',
    'tsh_era_name',
    'nik_store_leader_era',
    'store_leader_era_name',
    'nik_ast_store_leader_era',
    'ast_store_leader_era_name',
    'spv',
    'flag_target',
    'rce_buddy',
    'rce',
    'rce_title',
    'avp',
    'avp_title',
    'vp_pro',
    'circle',
    'region_circle']
    df['registered_date']=pd.to_datetime(df['registered_date']).dt.strftime('%Y%m%d')
    df['closed_date'] = df['closed_date'].apply(safe_format_date)
    df['update_dt']=dt_id
    df['mth_id']=year_month
    # Define the characters to remove
    chars_to_remove = '''\t#|,;"\n'''

    # Apply replacement
    for col in df.select_dtypes(include=['object']):
        df[col] = df[col].str.replace(f"[{chars_to_remove}]", " ", regex=True)
    df.to_csv(f'/data/retail/pst_storelist_{dt_id}.csv', index=False, sep='|')
    
    # upload to gcp
    print('upload to gcp first')
    bq_project = "data-nationalslsdist-prd-986g"
    bq_dataset = "postpaid" 
    bq_table = "ref_storelist" 

    client = bigquery.Client(project=bq_project)
    query = f"""
        delete from `{bq_project}.{bq_dataset}.{bq_table}`
        WHERE update_dt='{dt_id}'"""
    try:
        job = client.query(query)
        job.result()  # Wait for the job to complete
        print(f"Deleted data from {bq_table}.")
    except Exception as e:
        print(f"Error deleting data from BigQuery: {e}")
        raise
    # Define schema based on DataFrame
    schema = [
        SchemaField(column, 'STRING') if pd.api.types.is_object_dtype(df[column]) else
        SchemaField(column, 'INT64') if pd.api.types.is_integer_dtype(df[column]) else
        SchemaField(column, 'FLOAT64') if pd.api.types.is_float_dtype(df[column]) else
        SchemaField(column, 'TIMESTAMP') for column in df.columns
    ]
    # Load data to BigQuery
    job_config = bigquery.LoadJobConfig(schema=schema, write_disposition="WRITE_APPEND")
    job = client.load_table_from_dataframe(df, client.dataset(bq_dataset).table(bq_table), job_config=job_config)
    job.result()  # Wait for the job to complete
    print(f"Data uploaded to BigQuery table {bq_table}.")

    # upload to hdp
    ssh = SSHClient()
    ssh.set_missing_host_key_policy(AutoAddPolicy())
    ssh.connect('10.34.163.126', username='hdp-rdm', password='beqkZl@6' , port=22)
    sftp=ssh.open_sftp()   
    sftp.put(f"/data/retail/pst_storelist_{dt_id}.csv", f"/home/hdp-rdm@office.corp.indosat.com/file_retail/pst_storelist_{dt_id}.csv") 
    command=f"hdfs dfs -rm -R /data/rdm/upload/postpaid/pst_storelist/pst_storelist_{dt_id}.csv"
    stdin, stdout, stderr = ssh.exec_command(command)  # Non-blocking call
    exit_status = stdout.channel.recv_exit_status()          # Blocking call
    if exit_status == 0:
        print ("running_success")
    else:
        print("Error", exit_status)
    command=f"hdfs dfs -moveFromLocal /home/hdp-rdm@office.corp.indosat.com/file_retail/pst_storelist_{dt_id}.csv /data/rdm/upload/postpaid/pst_storelist/"
    stdin, stdout, stderr = ssh.exec_command(command)  # Non-blocking call
    exit_status = stdout.channel.recv_exit_status()          # Blocking call
    if exit_status == 0:
        print ("running_success")
    else:
        print("Error", exit_status) 
    command='impala-shell --quiet -i udc2-impala-lb.office.corp.indosat.com:25003 -d default -k --ssl -q "refresh rdm.pst_storelist;"'
    stdin, stdout, stderr = ssh.exec_command(command)  # Non-blocking call
    exit_status = stdout.channel.recv_exit_status()          # Blocking call
    if exit_status == 0:
        print ("running_success")
    else:
        print("Error", exit_status)
    status_job = 'running_success'
    return status_job

@op 
def t2_renewal_report(input_task): 
    print(input_task)
    filename = '/data/data_automation_bai/data_automation_scheduling/scripts/postpaid/postpaid_renewal_report.sql'
    fd = open(filename, 'r')
    sql_file = fd.read() 
    sql_file=sql_file.format(**{"year_month": year_month, 
                                "dt_id": dt_id
                                })
    fd.close() 
    query = sql_file.split(';')  

    df=hdp_get_df(query[0]) 
    df.to_excel(f"/data/postpaid/platinum_contract_renewal_{year_month}.xlsx", 
         index=False)
    os.system(f'''rclone copy /data/postpaid/platinum_contract_renewal_{year_month}.xlsx dsn:postpaid/''') 
    
    os.system(f'''rclone copy dsn:postpaid/platinum_contract_renewal_{year_month}.xlsx dsn:"Retail Performance Management - R100/platinum_contract_renewal"''')  
    
    # local_file = f"/data/retail/im3_sce_ga_{year_month}.xlsx"
    # remote_path = f"\\\\{server}\\S100\\{share}\\im3_sce_ga_{year_month}.xlsx" 
    
    # # Configure SMB authentication
    # smbclient.ClientConfig(username=username, password=password)
    # # Upload file
    # with open(local_file, "rb") as src, smbclient.open_file(remote_path, mode="wb") as dst:
    #     shutil.copyfileobj(src, dst)
    status_job="File uploaded successfully!" 
    
    # os.system(f'''rm -rf /data/postpaid/platinum_monthly_payment_{year_month}.xlsx''') 
    return status_job 

@op 
def t3_cpp_sankey(input_task): 
    print(input_task)
    filename = '/data/data_automation_bai/data_automation_scheduling/scripts/postpaid/gcp_cpp_sankey.sql'
    fd = open(filename, 'r')
    sql_file = fd.read() 
    sql_file=sql_file.format(**{"year_month": year_month, 
                                "dt_id": dt_id
                                })
    fd.close() 
    query = sql_file.split(';')  
    # filename = '/data/data_automation_bai/data_automation_scheduling/scripts/postpaid/hdp_cpp_sankey.sql'
    # fd = open(filename, 'r')
    # sql_file = fd.read() 
    # sql_file=sql_file.format(**{"year_month": year_month, 
    #                             "dt_id": dt_id
    #                             })
    # fd.close() 
    # query = sql_file.split(';')  
    # print(f'Inserting CPP Sankey {year_month}')
    # hdp_execute_query(query[0])
    # print(f'Dump result CPP Sankey {year_month}')
    # df=hdp_get_df(query[1]) 
    print(dt_id)
    project_id = "data-nationalslsdist-prd-986g"
    dataset_id = "postpaid"
    client = bigquery.Client(project=project_id)  
    
    # table_id = "raw_interaction_mitra_im3"
    # full_table_id = f"{project_id}.{dataset_id}.{table_id}" 
    print('start delete existing data')
    client.query(query[0]).result()
    print('start insert new data')
    client.query(query[1]).result()
    print('start dump new data')
    
    df=client.query(query[2]).to_dataframe()
    df.to_csv(f"/data/postpaid/cpp_sankey_final_v2.csv", 
         index=False, sep='|')
    os.system(f'''rclone copy /data/postpaid/cpp_sankey_final_v2.csv dsn:postpaid/''') 
    
    os.system(f'''rclone copy dsn:postpaid/cpp_sankey_final_v2.csv dsn:"Eko Febriyanto's files - POSTPAID/CPP Sankey"''')  
    status_job="File uploaded successfully!" 
    return status_job 

@graph
def pst_daily_kpi(): 
    t0 = t0_payment_report()
    t1 = t1_storelist_update(t0)
    # t2 = t2_renewal_report(t1)
    t3 = t3_cpp_sankey(t1)