# import sys
# import os

# # Tambahkan path ke folder utama modul
# sys.path.append(os.path.abspath('/data/data_automation_bai'))

from dagster import op, graph, schedule, DefaultScheduleStatus, repository, RetryPolicy, Output, OpExecutionContext  
from typing import Optional, Dict

import data_automation_scheduling.scripts.retail.copy_ipos_file as copy_ipos_file
import data_automation_scheduling.scripts.retail.dataset_cleaning as dataset_cleaning

import pandas as pd
from urllib.request import URLopener
from google.cloud import bigquery
from dateutil.relativedelta import relativedelta 
from google.cloud import bigquery
from google.auth.transport.requests import Request
from google_auth_oauthlib.flow import InstalledAppFlow
from google.oauth2.credentials import Credentials
from google.cloud.bigquery import SchemaField
from google.cloud import storage
import chardet 
from ftplib import FTP
import io
from pytz import timezone
import datetime as dt  
from datetime import timedelta
import os
from sshtunnel import SSHTunnelForwarder
from paramiko import SSHClient, AutoAddPolicy
import shutil
import zipfile
from datetime import timedelta
import re 
import paramiko 
import glob  

import stat
from tempfile import TemporaryDirectory
from datetime import date, timedelta 
from paramiko import ProxyCommand

def report_error(
    context: OpExecutionContext,
    *,
    step: str,
    exc: Exception,
    extra: Optional[Dict] = None,
):
    context.log.error(
        f"[{step}] failed",
        exc_info=True
    )

    return {
        "step": step,
        "error": str(exc),
        **(extra or {})
    }

jakarta = timezone('Asia/Jakarta')

def safe_convert(val, dt_id):
    try:
        return pd.to_datetime(val).tz_localize(jakarta).tz_convert('UTC')
    except:
        return pd.to_datetime(dt_id, format='%Y%m%d').tz_localize(jakarta).tz_convert('UTC')

# Get data D-1 
dates = (dt.date.today() - timedelta(days=1))
# dates = (dt.date.today())
dt_id = dates.strftime("%Y%m%d")
year_month = dt_id[:6]
dates_str = dates.strftime("%Y-%m-%d") 

# Rerun manual
# year_month="202506"
# dt_id ="20250630" 

def is_valid_date(folder_name):
    try:
        dt.datetime.strptime(folder_name, "%Y-%m-%d")
        return True
    except ValueError:
        return False

def copytree_force(src, dst):
    if not os.path.exists(dst):
        os.makedirs(dst)
    for item in os.listdir(src):
        s = os.path.join(src, item)
        d = os.path.join(dst, item)
        if os.path.isdir(s):
            copytree_force(s, d)
        else:
            shutil.copy2(s, d)

@op(retry_policy=RetryPolicy(max_retries=3, delay=60))
def get_n_process_ipos_file(context): 
    try:
        # print(last_status) 
        # dates=(dt.date.today() - timedelta(days = 1))
        print(dates_str)
        print('Check and copy from /data/ipos')
        base_path = "/data/ipos"
        destination_path = "/data/rpa"
        target_path = os.path.join(base_path, dates_str)
        if os.path.exists(target_path):
            folder = target_path
            print(f" Folder UIPath rpa ipos exist and using folder: {folder}")
            copytree_force(target_path, os.path.join(destination_path, dates_str))
            os.system(f'''rclone copy "dsn:rpa/ipos/{dates_str}" /data/rpa/{dates_str}''')
        else:
            print(f'00. Copying to RPA File {dates_str} Due to UIPath File not exist')
            os.system(f'''rclone copy "dsn:rpa/ipos/{dates_str}" /data/rpa/{dates_str}''')
        print('01. Start Copying IPOS File')
        copy_ipos_file.process_files(dates_str) 
        print('02. Finish Copying IPOS file') 
        raw_ipos_ps_trx=f'Partner_Store_Transaction_Report_{year_month}'
        raw_ipos_nonps_trx=f'Customer_Transaction_Details_{year_month}'
        print(f'03. Cleaning {raw_ipos_ps_trx}.xlsx')
        dataset_cleaning.main(raw_ipos_ps_trx+'.xlsx')
        print(f'04. Cleaning {raw_ipos_nonps_trx}.xlsx')
        dataset_cleaning.main(raw_ipos_nonps_trx+'.xlsx')
        location_file='/data/gcp/ipos/'

        df = pd.read_excel(location_file+raw_ipos_ps_trx+'.xlsx', engine='openpyxl', dtype=str)
        # Convert DataFrame to CSV in memory (not saved on disk)
        csv_buffer = io.StringIO()
        df.to_csv(csv_buffer, index=False, sep='|')
        # GCS upload details
        bucket_name = 'data-nationalslsdist-prd-986g-data-nationalsalesdist-prd-0f39'
        destination_blob_name = f'bai/postpaid/raw_ipos_ps_trx/{raw_ipos_ps_trx}.csv'  # e.g., folder/data.csv 

        # Create GCS client
        client = storage.Client()  # uses default credentials
        bucket = client.bucket(bucket_name)
        blob = bucket.blob(destination_blob_name)

        # Upload from memory
        blob.upload_from_string(csv_buffer.getvalue(), content_type='text/csv')
        print(f"Uploaded to gs://{bucket_name}/{destination_blob_name}")

        df = pd.read_excel(location_file+raw_ipos_nonps_trx+'.xlsx', engine='openpyxl', dtype=str)
        # Convert DataFrame to CSV in memory (not saved on disk)
        csv_buffer = io.StringIO()
        df.to_csv(csv_buffer, index=False, sep='|')
        # GCS upload details
        bucket_name = 'data-nationalslsdist-prd-986g-data-nationalsalesdist-prd-0f39'
        destination_blob_name = f'bai/retail/raw_ipos_nonps_trx/{raw_ipos_nonps_trx}.csv'  # e.g., folder/data.csv 

        # Create GCS client
        client = storage.Client()  # uses default credentials
        bucket = client.bucket(bucket_name)
        blob = bucket.blob(destination_blob_name)

        # Upload from memory
        blob.upload_from_string(csv_buffer.getvalue(), content_type='text/csv')
        print(f"Uploaded to gs://{bucket_name}/{destination_blob_name}")
        print(f'05. Cleaning and Processing User Details {dt_id} and {year_month}') 
        user_details=f'User_Details_{year_month}'
        dataset_cleaning.main(f'{user_details}.xlsx')
        df = pd.read_excel(location_file+user_details+'.xlsx', engine='openpyxl', dtype=str)
        df['updated_dt']=dt_id
        df['mth_id']=year_month
        # Convert DataFrame to CSV in memory (not saved on disk)
        csv_buffer = io.StringIO()
        df.to_csv(csv_buffer, index=False)
        # GCS upload details
        bucket_name = 'data-nationalslsdist-prd-986g-data-nationalsalesdist-prd-0f39'
        destination_blob_name = f'bai/retail/raw_ipos_user_details/user_details_{year_month}.csv'  # e.g., folder/data.csv 

        # Create GCS client
        client = storage.Client()  # uses default credentials
        bucket = client.bucket(bucket_name)
        blob = bucket.blob(destination_blob_name)

        # Upload from memory
        blob.upload_from_string(csv_buffer.getvalue(), content_type='text/csv')
        print(f"Uploaded to gs://{bucket_name}/{destination_blob_name}")
        # dt_id='20250131'
        # year_month=dt_id[:6]
        print(f'06. Cleaning and Processing 3Kiosk Customer Transaction Detail {dt_id} and {year_month}') 
        sdp_trx=f'3Kiosk_Customer_Transaction_Details_{year_month}'
        dataset_cleaning.main(f'{sdp_trx}.xlsx')
        df = pd.read_excel(location_file+sdp_trx+'.xlsx', engine='openpyxl', dtype=str)
        # Convert DataFrame to CSV in memory (not saved on disk)
        csv_buffer = io.StringIO()
        df.to_csv(csv_buffer, index=False, sep='|')
        # GCS upload details
        bucket_name = 'data-nationalslsdist-prd-986g-data-nationalsalesdist-prd-0f39'
        destination_blob_name = f'bai/retail/raw_ipos_sdp_trx/3kiosk_customer_transaction_details_{year_month}.csv'  # e.g., folder/data.csv 

        # Create GCS client
        client = storage.Client()  # uses default credentials
        bucket = client.bucket(bucket_name)
        blob = bucket.blob(destination_blob_name)

        # Upload from memory
        blob.upload_from_string(csv_buffer.getvalue(), content_type='text/csv')
        print(f"Uploaded to gs://{bucket_name}/{destination_blob_name}")
        
        status = 'No Error and Passed'
    except Exception as e:
        context.log.error(f"Error happened: {e}")
        print(f"Error happened: {e}")
        status = f"Error happened: {e}"

    return status

@op
def gcp_qmatics(context, last_status):
    print(last_status)
    try:
        year_month=(dt.date.today() - timedelta(days = 1)).strftime("%Y%m") 
        dt_id = (dt.date.today() - timedelta(days = 1)).strftime("%Y%m%d")
        print(dt_id)
        print('Starting Dump Qmatic Customer Detail')
        # year_month=dt_id[:6]
        os.system(f'''rclone copy dsn:source_data_email/qmatics /data/gcp/customer_detail --include "customer_detail_{dt_id}*.csv"''')

        # Define file pattern
        file_pattern = f'/data/gcp/customer_detail/customer_detail_{dt_id}*.csv'
        # Get list of matching files
        csv_files = glob.glob(file_pattern)
        # Read and concatenate all files
        df = pd.concat((pd.read_csv(file,dtype=str, encoding='ISO-8859-1') for file in csv_files), ignore_index=True)
        df.columns=[
        'visit_time' ,
        'trans_id' ,
        'ticket_id' ,
        'store_name' ,
        'store_code' ,
        'circle' ,
        'region' ,
        'msisdn' ,
        'agent_id' ,
        'agent_name' ,
        'service_type' ,
        'brand' ,
        'customer_type' ,
        'handling_time' ,
        'sla_handling_time' ,
        'waiting_time' ,
        'sla_waiting_time'
        ]
        df.loc[df['store_name']=='Gerai BEC Bandung', 'store_code']='BDPL'
        df['dt_id']=pd.to_datetime(df['visit_time']).dt.tz_localize('Asia/Jakarta').dt.tz_convert('UTC')
        bq_project = "data-nationalslsdist-prd-986g"
        bq_dataset = "retail" 
        bq_table = "raw_qmatic_customer_detail"
        client = bigquery.Client(project=bq_project)
        query_delete=f""" 
            DELETE FROM
            `data-nationalslsdist-prd-986g`.retail.raw_qmatic_customer_detail
            WHERE format_date('%Y%m%d',DATETIME(dt_id,'Asia/Jakarta')) = '{dt_id}';
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
            print(f"Deleting data in `data-nationalslsdist-prd-986g`.retail.raw_qmatic_customer_detail")
        except Exception as e:
            print(f"Error deleting data in `data data-nationalslsdist-prd-986g`.retail.raw_qmatic_customer_detail")
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
        print('Finish Dump Qmatic Customer Detail')
        print('Starting Dump Qmatic Agent Detail')
        os.system(f'''rclone copy dsn:source_data_email/qmatics /data/gcp/agent_detail --include "agent_detail_{dt_id}*.csv"''')

        # Define file pattern
        file_pattern = f'/data/gcp/agent_detail/agent_detail_{dt_id}*.csv'
        # Get list of matching files
        csv_files = glob.glob(file_pattern)
        # Read and concatenate all files
        df = pd.concat((pd.read_csv(file,dtype=str, encoding='ISO-8859-1') for file in csv_files), ignore_index=True)
        df.columns=[
        'created_date',
        'agent_id',
        'agent_name',
        'circle',
        'region',
        'store_name',
        'store_id',
        'login_time',
        'logout_time',
        'tot_login',
        'avg_handling_time',
        'max_handling_time',
        'tot_handling_time',
        'avg_waiting_time_per_store',
        'arrived',
        'served',
        'no_shows'
        ]
        df.loc[df['store_name']=='Gerai BEC Bandung', 'store_id']='BDPL'
        df['dt_id']=pd.to_datetime(df['created_date'], format='%Y-%m-%d').dt.date
        # .dt.tz_localize('Asia/Jakarta').dt.tz_convert('UTC') 
        # df
        bq_project = "data-nationalslsdist-prd-986g"
        bq_dataset = "retail" 
        bq_table = "raw_qmatic_agent_detail"
        client = bigquery.Client(project=bq_project)

        query_delete=f""" 
            DELETE FROM
            `data-nationalslsdist-prd-986g`.retail.raw_qmatic_agent_detail
            WHERE format_date('%Y%m%d',dt_id) = '{dt_id}';
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
            print(f"Deleting data in `data-nationalslsdist-prd-986g`.retail.raw_qmatic_agent_detail")
        except Exception as e:
            print(f"Error deleting data in `data data-nationalslsdist-prd-986g`.retail.raw_qmatic_agent_detail")
            raise

        # Define schema based on DataFrame
        # schema = [
        #     SchemaField(column, 'STRING') if pd.api.types.is_object_dtype(df[column]) else
        #     SchemaField(column, 'INT64') if pd.api.types.is_integer_dtype(df[column]) else
        #     SchemaField(column, 'FLOAT64') if pd.api.types.is_float_dtype(df[column]) else
        #     SchemaField(column, 'DATE') for column in df.columns
        # ]
        # Load data to BigQuery
        # job_config = bigquery.LoadJobConfig(schema=schema, write_disposition="WRITE_APPEND")
        # job = client.load_table_from_dataframe(df, client.dataset(bq_dataset).table(bq_table), job_config=job_config)
        
        job = client.load_table_from_dataframe(
            df,
            client.dataset(bq_dataset).table(bq_table),
            job_config=bigquery.LoadJobConfig(write_disposition="WRITE_APPEND")
        )
        job.result()  # Wait for the job to complete
        print(f"Data uploaded to BigQuery table {bq_table}.")
        print('Finish Dump Qmatic Agent Detail')
        
        print('Starting dump report customer detail to R100')
        bq_project = "data-nationalslsdist-prd-986g"
        bq_dataset = "retail" 
        bq_table = "raw_qmatic_customer_detail"
        client = bigquery.Client(project=bq_project)
        # Your SQL query
        query = f"""
            SELECT
                visit_time,
                trans_id,
                ticket_id,
                store_name,
                store_code,
                circle,
                region,
                msisdn,
                agent_id,
                agent_name,
                service_type,
                brand,
                customer_type,
                handling_time,
                sla_handling_time,
                waiting_time,
                sla_waiting_time
            FROM `{bq_project}.{bq_dataset}.{bq_table}`
            WHERE format_date('%Y%m',DATETIME(dt_id,'Asia/Jakarta'))=left('{dt_id}', 6)
        """
        # Run query and return DataFrame
        df = client.query(query).to_dataframe()
        df.to_excel(f'/data/gcp/Qmatic_Customer_Detail_{year_month}.xlsx',index=False, sheet_name='Sheet1')
        os.system(f'''rclone copy /data/gcp/Qmatic_Customer_Detail_{year_month}.xlsx dsn:retail/gcp''')
        os.system(f'''rclone copy dsn:retail/gcp/Qmatic_Customer_Detail_{year_month}.xlsx dsn:"Retail Performance Management - R100/qmatic"''')
        status='Finish Create Report'
    
        status = 'No Error and Passed'
    except Exception as e:
        context.log.error(f"Error happened: {e}")
        print(f"Error happened: {e}")
        status = f"Error happened: {e}"

    return status
    # return status

def normalize(name: str) -> str:
    return name.lower().strip()

@op
def survey_sensum(context, last_status):
    print(last_status)
    try:
        project_id = "data-nationalslsdist-prd-986g"
        client = bigquery.Client(project=project_id)

        query='''
            select 
                distinct raw_file_name
            from `data-nationalslsdist-prd-986g`.retail.raw_response_surveysensum
        '''
        df=client.query(query).to_dataframe()
        raw_file_name=df['raw_file_name'].to_list()
        print(raw_file_name)
        
        processed_set = {normalize(f) for f in raw_file_name}
        host = '52.76.140.165'
        port = 22
        username = 'ioh_gerai'
        password = 'ioh_gerai@#survey'
        proxy_host = '10.45.127.5'
        proxy_port = 3128
        REMOTE_FOLDERS = [
            "/IOHGeraiSurvey/Reports/RawResponseData"
        ]

        # Create an SSH client
        ssh = paramiko.SSHClient()
        ssh.set_missing_host_key_policy(paramiko.AutoAddPolicy())

        # Connect to the SFTP server using a proxy
        ssh.connect(
            hostname=host,
            port=port,
            username=username,
            password=password,
            sock=paramiko.ProxyCommand(f"ncat --proxy-type http --proxy {proxy_host}:{proxy_port} {host} {port}")
        )

        # Open an SFTP session
        sftp = ssh.open_sftp()
        
        new_files_by_folder = {}
        
        for folder in REMOTE_FOLDERS:
            files = []

            for f in sftp.listdir_attr(folder):
                if (
                    stat.S_ISREG(f.st_mode)
                    and f.filename.lower().endswith(".xlsx")
                    and normalize(f.filename) not in processed_set
                ):
                    files.append(f.filename)

            if files:
                new_files_by_folder[folder] = files
        print(new_files_by_folder)

        cols=[
            'sequence_no',
            'q_agent_understanding',
            'q_agent_understanding_score',
            'q_agent_solution',
            'q_agent_solution_score',
            'q_agent_solution_store',
            'q_store_experience',
            'q_store_experience_score',
            'q_store_experience_group',
            'q_agent_understanding_alt',
            'q_agent_understanding_alt_score',
            'q_agent_solution_alt',
            'q_agent_solution_alt_score',
            'q_agent_solution_alt_2',
            'q_store_experience_alt',
            'q_store_experience_alt_score',
            'respondent_id',
            'survey_status',
            'survey_mode',
            'sync_on_datetime',
            'sync_by',
            'response_time',
            'interviewer_id',
            'subscription_id',
            'project_id',
            'questionnaire_version',
            'channel_type',
            'is_anonymous',
            'test_response',
            'distribution_channel',
            'name',
            'email',
            'phone_number',
            'tnr_cat',
            'circle',
            'region',
            'sales_area',
            'micro_cluster',
            'hvc_segment',
            'data_usage_segment',
            'area',
            'sp_name',
            'status',
            'have_da_bonus',
            'have_da_dq',
            'panel',
            'tnr',
            'pymt_tp',
            'partner',
            'template_survey_csat',
            'mitra',
            'msisdn',
            'msisdn_list',
            'value_segment',
            'rotation',
            'package_name',
            'flag',
            'group_package',
            'customer_segment',
            'month',
            'week',
            'year',
            'date_survey',
            'brand',
            'mocn_name',
            'siteid_before',
            'siteid_after',
            'nano_cluster',
            'target_group',
            'activity',
            'produk',
            'price',
            'total_hit',
            'mittra',
            'country',
            'bank_code',
            'remark',
            'groupx_bima',
            'eligible_device_bima',
            'data_usage',
            'paket',
            'point_bonstri',
            'category_point',
            'zone',
            'tenure',
            'segment',
            'destination_country',
            'brand_type',
            'tenure_day',
            'area_outlet',
            'prefix',
            'city_outlet',
            'operator',
            'revenue_grouping',
            'nama_toko',
            'stats_subs',
            'tenure_tag',
            'fav_loc_district',
            'current_pack',
            'prev_pack',
            'group_nano',
            'asset_name',
            'billing_account',
            'product_id',
            'product_name',
            'micro_cluster_260',
            'micro_cluster_281',
            'date',
            'service_id',
            'service_type',
            'channel',
            'aging',
            'apps_name',
            'transactionid',
            'mini_gerai',
            'geraitype',
            'brand_name',
            'agent_id',
            'store_id',
            'store_name',
            'interaction_id',
            'channel_source',
            'kabupaten',
            'arpu',
            'transaction_date',
            'ticket_id_qmatic',
            'service_type_qmatic',
            'handling_time_qmatic',
            'visit_time_qmatic',
            'waiting_time',
            'kecamatan',
            'agent_name',
            'trigger_time',
            'campaign_id',
            'camp_sent_on_date_time'
        ]
        dfs = []

        with TemporaryDirectory() as tmpdir:
            for folder, files in new_files_by_folder.items():
                for file_name in files:
                    remote_path = f"{folder}/{file_name}"
                    local_path = os.path.join(tmpdir, file_name)

                    # download
                    sftp.get(remote_path, local_path)

                    # read excel
                    df = pd.read_excel(local_path, engine='openpyxl', 
                                        header=None,
                                        names=cols,
                                        dtype=str)
                    df["raw_file_name"] = file_name
                    # df["source_folder"] = folder
                    df['prt_dt']= date.today() - timedelta(days=2)
                    dfs.append(df)

        df_all=pd.concat(dfs)
        project_id = "data-nationalslsdist-prd-986g"
        dataset_id = "retail"
        table_id = "raw_response_surveysensum"
        client = bigquery.Client(project=project_id)
        full_table_id = f"{project_id}.{dataset_id}.{table_id}"
        # ==== APPEND NEW DATA ====
        job_config = bigquery.LoadJobConfig(
            write_disposition=bigquery.WriteDisposition.WRITE_APPEND,
            autodetect=True,
        )
        job = client.load_table_from_dataframe(df_all, full_table_id, job_config=job_config)
        job.result()

        print(f"Success Appended {len(df_all)} rows into {full_table_id}")
        # status = f"Success Appended {len(df_all)} rows into {full_table_id}"
        status = 'No Error and Passed'
    except Exception as e:
        context.log.error(f"Error happened: {e}")
        print(f"Error happened: {e}")
        status = f"Error happened: {e}"

    return status
    #  return status

@graph
def retail_ipos_upload(): 
    t0 = get_n_process_ipos_file()
    t1 = gcp_qmatics(t0)
    survey_sensum(t1)