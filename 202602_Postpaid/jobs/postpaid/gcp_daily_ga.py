from dagster import op, graph, schedule, DefaultScheduleStatus, repository, RetryPolicy  

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

jakarta = timezone('Asia/Jakarta')

def safe_convert(val, dt_id):
    try:
        return pd.to_datetime(val).tz_localize(jakarta).tz_convert('UTC')
    except:
        return pd.to_datetime(dt_id, format='%Y%m%d').tz_localize(jakarta).tz_convert('UTC')

# Get data D-1 
year_month=(dt.date.today() - timedelta(days = 1)).strftime("%Y%m") 
dt_id = (dt.date.today() - timedelta(days = 1)).strftime("%Y%m%d")  


# Rerun manual
# year_month="202506"
# dt_id ="20250630" 

@op
def get_raw_ga(): 
    # get data today
    # year_month=(dt.date.today()).strftime("%Y%m") 
    dt_id = (dt.date.today()).strftime("%Y%m%d") 
    year_month=dt_id[:6]

    print(dt_id)
    bq_project = "data-nationalslsdist-prd-986g"
    bq_dataset = "postpaid" 
    bq_table = "raw_new_verification"
    file_name=f"raw_data_new_verification2_{dt_id}.csv"
    # === 1. Connect to FTP server ===
    ftp = FTP('10.34.17.62')
    ftp.login(user='idsreport', passwd='idsreport123')

    remote_path = f'daily_verification/{file_name}'

    # === 2. Load file into memory ===
    buffer = io.BytesIO()
    ftp.retrbinary(f'RETR {remote_path}', buffer.write)
    ftp.quit()

    # === 3. Detect encoding using chardet ===
    buffer.seek(0)
    sample = buffer.read(10000)  # first 10KB
    result = chardet.detect(sample)
    #encoding = result['encoding']
    # If chardet wrongly detects ASCII, use a fallback
    encoding = result['encoding']
    # if encoding.lower() == 'ascii':
    #     encoding = 'latin1'  # or try 'ISO-8859-1'
    print("Detected encoding:", encoding)
    # === 4. Read CSV with pandas using detected encoding ===
    # buffer.seek(0)  # rewind to start again
    # df = pd.read_csv(buffer, sep='|', dtype=str, encoding=encoding, error_bad_lines=False)
    
    # === 4. Fix content before reading into pandas ===
    buffer.seek(0)
    raw_text = buffer.read().decode(encoding, errors='replace')  # decode the raw bytes
    cleaned_text = raw_text.replace("||Member", "/Member")        # fix the bad pattern

    # Convert back to BytesIO so pandas can read it like a file
    cleaned_buffer = io.StringIO(cleaned_text)

    # === 5. Read with pandas ===
    df = pd.read_csv(cleaned_buffer, sep='|', dtype=str, 
                     error_bad_lines=False) 
    
    df.columns=['created',
        'customer_ref',
        'customer_type_name',
        'main_contact_number',
        'account_num',
        'account_name',
        'doc_ref',
        'doc_dt',
        'salesperson_nm',
        'daytime_contact_tel',
        'daytime_extension',
        'cust_first_name',
        'cust_last_name',
        'activation_date',
        'completion_date',
        'msisdn',
        'sex',
        'siup',
        'npwp',
        'birth_date',
        'id_number',
        'package_code',
        'package_name',
        'mother_maiden_name',
        'bill_adr',
        'home_address',
        'office_address',
        'length_residence_time_month',
        'length_residence_time_year',
        'length_working_time_month',
        'length_working_time_year',
        'account_sub_status',
        'sub_status_reason',
        'id_address',
        'company_name',
        'ra_rate',
        'acc_act_thold_set_name',
        'name',
        'receipt_status_id',
        'welcome_call_status_id',
        'validation_status_id',
        'address_survey_status_id',
        'community_id',
        'comment',
        'outlet_code',
        'outlet_name',
        'order',
        'sr',
        'creditclass',
        'idd_call',
        'order_created_by',
        'order_last_updated_by',
        'galeri_name',
        'branch_name',
        'region_name'
    ]
    df['file_name']=file_name
    #df['dt_id']=pd.to_datetime(df['created']).dt.tz_localize('Asia/Jakarta').dt.tz_convert('UTC') 
    df['dt_id'] = df['created'].apply(lambda x: safe_convert(x, dt_id))
    df['account_num']=df['account_num'].str.replace("'", "", regex=False)
    df['msisdn']=df['msisdn'].str.replace("'", "", regex=False)
    df['id_number']=df['id_number'].str.replace("'", "", regex=False)
    client = bigquery.Client(project=bq_project)
    query = f"""
        delete from `{bq_project}.{bq_dataset}.{bq_table}`
        WHERE file_name='{file_name}'"""
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
    status = f"Data uploaded to BigQuery table {bq_table}." 
    return status

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
def get_n_process_ipos_file(last_status): 
    print(last_status) 
    dates=(dt.date.today() - timedelta(days = 1))
    # dates = (dt.date.today())
    dates_str = dates.strftime("%Y-%m-%d") 
    print('Check and copy from /data/ipos')
    base_path = "/data/ipos"
    destination_path = "/data/rpa"
    target_path = os.path.join(base_path, dates_str)
    # if os.path.exists(target_path):
    #     folder = target_path
    
    if os.path.exists(target_path):
        folder = target_path
        print(f" Folder UIPath rpa ipos exist and using folder: {folder}")
        copytree_force(target_path, os.path.join(destination_path, dates_str))
        # shutil.copytree(target_path, os.path.join(destination_path, dates_str))
        # has_customers = False
        # has_partners = False
        # for filename in os.listdir(folder):
        #     if 'Customers' in filename:
        #         has_customers = True
        #     if 'Partners' in filename:
        #         has_partners = True
        # if has_customers and has_partners:
        #     print("Folder berisi file Customers dan Partners.")
        #     shutil.copytree(target_path, os.path.join(destination_path, dates_str))
    else:
        print(f'00. Copying to RPA File {dates_str} Due to UIPath File not exist')
        os.system(f'''rclone copy "dsn:rpa/ipos/{dates_str}" /data/rpa/{dates_str}''')
    print('01. Start Copying IPOS File')
    # copy_ipos_file.main()
    copy_ipos_file.process_files(dates_str) 
    print('01. Finish Copying IPOS file') 
    raw_ipos_ps_trx=f'Partner_Store_Transaction_Report_{year_month}'
    raw_ipos_nonps_trx=f'Customer_Transaction_Details_{year_month}'
    print(f'02. Cleaning {raw_ipos_ps_trx}.xlsx')
    dataset_cleaning.main(raw_ipos_ps_trx+'.xlsx')
    print(f'03. Cleaning {raw_ipos_nonps_trx}.xlsx')
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
    status=f"Uploaded to gs://{bucket_name}/{destination_blob_name}"
    return status

@op(retry_policy=RetryPolicy(max_retries=3, delay=60))
def create_raw_ga(last_status): 
    print(last_status)  
    # ssot D-2
    # year_month=(dt.date.today() - timedelta(days = 2)).strftime("%Y%m") 
    # dt_id = (dt.date.today() - timedelta(days = 2)).strftime("%Y%m%d") 
    print(dt_id)

    # filename = '/data/data_automation_bai/data_automation_scheduling/scripts/postpaid/gcp_daily_ga.sql'
    # filename = '/data/data_automation_bai/data_automation_scheduling/scripts/postpaid/gcp_daily_ga_ssot.sql'
    filename = '/data/data_automation_bai/data_automation_scheduling/scripts/postpaid/gcp_daily_ga_ssot_rerun.sql' 

    fd = open(filename, 'r')
    sql_file = fd.read() 
    sql_file=sql_file.format(**{"year_month": year_month, 
                                "dt_id": dt_id
                                })
    fd.close() 
    query = sql_file.split(';')
    bq_project = "data-nationalslsdist-prd-986g"
    bq_dataset = "postpaid" 
    # bq_table = "raw_new_verification"
    client = bigquery.Client(project=bq_project)
    print('Start Deleting Raw Daily GA')
    query_delete=f""" 
    delete from `data-nationalslsdist-prd-986g`.postpaid.raw_daily_ga 
    where left(activation_date, 6)=left('{dt_id}', 6);
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
        print(f"Deleting data to `data-nationalslsdist-prd-986g`.postpaid.raw_daily_ga")
    except Exception as e:
        print(f"Error deleting `data data-nationalslsdist-prd-986g`.postpaid.raw_daily_ga")
        raise

    print('Finish Deleting Raw Daily GA')

    job_config = bigquery.QueryJobConfig(
        query_parameters=[
            bigquery.ScalarQueryParameter("year_month", "STRING", year_month),
            bigquery.ScalarQueryParameter("dt_id", "STRING", dt_id)
        ]
    )
 
    try:
        job = client.query(query[0], job_config=job_config)
        job.result()  # Wait for the job to complete
        print(f"Inserting new data to `data-nationalslsdist-prd-986g`.postpaid.raw_daily_ga")
    except Exception as e:
        print(f"Error inserting new `data data-nationalslsdist-prd-986g`.postpaid.raw_daily_ga")
        raise

    for i in range(1,15): 
        try:
            job = client.query(query[i], job_config=job_config)
            job.result()  # Wait for the job to complete
            print(f"Updating process {i} to `data-nationalslsdist-prd-986g`.postpaid.raw_daily_ga")
        except Exception as e:
            print(f"Error updating process {i} `data data-nationalslsdist-prd-986g`.postpaid.raw_daily_ga")
            raise

    # try:
    #     job = client.query(query[1], job_config=job_config)
    #     job.result()  # Wait for the job to complete
    #     print(f"Updating DC11 storecode to `data-nationalslsdist-prd-986g`.postpaid.raw_daily_ga")
    # except Exception as e:
    #     print(f"Error updating DC11 storecode `data data-nationalslsdist-prd-986g`.postpaid.raw_daily_ga")
    #     raise
    
    # try:
    #     job = client.query(query[2], job_config=job_config)
    #     job.result()  # Wait for the job to complete
    #     print(f"Updating direct sales nik to `data-nationalslsdist-prd-986g`.postpaid.raw_daily_ga")
    # except Exception as e:
    #     print(f"Error updating new `data data-nationalslsdist-prd-986g`.postpaid.raw_daily_ga")
    #     raise

    # try:
    #     job = client.query(query[3], job_config=job_config)
    #     job.result()  # Wait for the job to complete
    #     print(f"Updating instore agent nik to `data-nationalslsdist-prd-986g`.postpaid.raw_daily_ga")
    # except Exception as e:
    #     print(f"Error updating new `data data-nationalslsdist-prd-986g`.postpaid.raw_daily_ga")
    #     raise

    print('Starting dump report daily GA')
    bq_project = "data-nationalslsdist-prd-986g"
    bq_dataset = "postpaid" 
    bq_table = "raw_daily_ga"
    client = bigquery.Client(project=bq_project)
    # Your SQL query
    query = f"""
        SELECT *
        FROM `{bq_project}.{bq_dataset}.{bq_table}`
        WHERE substr(activation_date, 1, 6)=SUBSTR('{dt_id}', 1, 6)
        AND activation_date<='{dt_id}'
    """
    # Run query and return DataFrame
    df = client.query(query).to_dataframe()
    df.columns=[
        'activation_date',
        'account_num',
        'msisdn',
        'cust_name',
        'package_name',
        'order_type',
        'package_type',
        'tenure',
        'dealer_id',
        'store',
        'channel',
        'region',
        'area',
        'id_number',
        'salesperson_nm',
        'comment_text',
        'created',
        'outlet_code',
        'outlet_name',
        'galeri_name',
        'branch_name',
        'region_name',
        'store_code_rev',
        'Region_Rev',
        'Area_Rev',
        'SALES AREA',
        'Channel_Rev',
        'Store Name_Rev',
        'Channel_Partner Store_Group',
        'Channel_Partner_Store_Detail',
        'Circle',
        'Region New 2024',
        'RCM',
        'sales_name',
        'nik_sales',
        'no_imkas_sales',
        'npwp_sales',
        'alamat_sales',
        'nik_pelanggan',
        'SPV_Name',
        'NIK_SPV',
        'no imkas_SPV',
        'no NPWP SPV',
        'Alamat SPV',
        'Team Leader_Name',
        'nik_Team Leader',
        'no imkas_Team Leader',
        'no NPWP Team Leader',
        'Alamat Team Leader',
        'Remarks',
        'package_group',
        'Verification Status',
        'Check Duplicate',
        'Check Query',
        'Days',
        'Invoice No. Ipos',
        'Invoice No. Myretail',
        'Tactical/Regular',
        'Package_Rev',
        'Acq Revenue (mio)',
        'Guaranteed Ravenue excl VAT (mio)',
        'Guaranteed Revenue (Mio)',
        'Promotor',
        'BSM',
        'Detail reason Category',
        'Status SR',
        'Point',
        'Agent Type'
    ]
    df.to_excel(f'/data/gcp/Postpaid_Daily_Activation_{year_month}.xlsx',index=False, sheet_name='Sheet')
    df.to_csv(f'/data/gcp/Postpaid_Daily_Activation_{year_month}.csv',index=False, sep='|')

    df_jaya=df[df['Circle'].str.upper()=='JAKARTA RAYA'].copy()
    df_java=df[df['Circle'].str.upper()=='JAVA'].copy()
    df_kalisumapa=df[df['Circle'].str.upper()=='KALISUMAPA'].copy()
    df_sumatera=df[df['Circle'].str.upper()=='SUMATERA'].copy()
    exclude_circles = ['JAKARTA RAYA', 'JAVA', 'KALISUMAPA', 'SUMATERA']
    df_other = df[~df['Circle'].str.upper().isin(exclude_circles)].copy()
    
    df_jaya.to_excel(f'/data/gcp/Postpaid_Daily_Activation_{year_month}_JAYA.xlsx',index=False)
    df_java.to_excel(f'/data/gcp/Postpaid_Daily_Activation_{year_month}_JAVA.xlsx',index=False)
    df_kalisumapa.to_excel(f'/data/gcp/Postpaid_Daily_Activation_{year_month}_KALISUMAPA.xlsx',index=False)
    df_sumatera.to_excel(f'/data/gcp/Postpaid_Daily_Activation_{year_month}_SUMATERA.xlsx',index=False)
    df_other.to_excel(f'/data/gcp/Postpaid_Daily_Activation_{year_month}_OTHERS.xlsx',index=False)

    os.system(f'''rclone copy /data/gcp/Postpaid_Daily_Activation_{year_month}.xlsx dsn:postpaid/gcp --ignore-times''')
    os.system(f'''rclone copy /data/gcp/Postpaid_Daily_Activation_{year_month}_JAYA.xlsx dsn:postpaid/gcp --ignore-times''') 
    os.system(f'''rclone copy /data/gcp/Postpaid_Daily_Activation_{year_month}_JAVA.xlsx dsn:postpaid/gcp --ignore-times''')
    os.system(f'''rclone copy /data/gcp/Postpaid_Daily_Activation_{year_month}_KALISUMAPA.xlsx dsn:postpaid/gcp --ignore-times''')
    os.system(f'''rclone copy /data/gcp/Postpaid_Daily_Activation_{year_month}_SUMATERA.xlsx dsn:postpaid/gcp --ignore-times''')
    os.system(f'''rclone copy /data/gcp/Postpaid_Daily_Activation_{year_month}_OTHERS.xlsx dsn:postpaid/gcp --ignore-times''') 

    print('Deleting existing file dump report Daily GA in R100')
    os.system(f'''rclone delete dsn:"Retail Performance Management - R100/daily_ga/JAKARTA RAYA/Postpaid_Daily_Activation_{year_month}_JAYA.xlsx"''')
    os.system(f'''rclone delete dsn:"Retail Performance Management - R100/daily_ga/JAVA/Postpaid_Daily_Activation_{year_month}_JAVA.xlsx"''')
    os.system(f'''rclone delete dsn:"Retail Performance Management - R100/daily_ga/KALISUMAPA/Postpaid_Daily_Activation_{year_month}_KALISUMAPA.xlsx"''')
    os.system(f'''rclone delete dsn:"Retail Performance Management - R100/daily_ga/SUMATERA/Postpaid_Daily_Activation_{year_month}_SUMATERA.xlsx"''')
    os.system(f'''rclone delete dsn:"Retail Performance Management - R100/daily_ga/OTHERS/Postpaid_Daily_Activation_{year_month}_OTHERS.xlsx"''')

    print('Start Dump Report Dump Daily GA to R100')  
    os.system(f'''rclone copy dsn:postpaid/gcp/Postpaid_Daily_Activation_{year_month}.xlsx dsn:"Data/Power BI Dashboard/Daily GA"''')
    os.system(f'''rclone copy dsn:postpaid/gcp/Postpaid_Daily_Activation_{year_month}_JAYA.xlsx dsn:"Retail Performance Management - R100/daily_ga/JAKARTA RAYA"''')
    os.system(f'''rclone copy dsn:postpaid/gcp/Postpaid_Daily_Activation_{year_month}_JAVA.xlsx dsn:"Retail Performance Management - R100/daily_ga/JAVA"''')
    os.system(f'''rclone copy dsn:postpaid/gcp/Postpaid_Daily_Activation_{year_month}_KALISUMAPA.xlsx dsn:"Retail Performance Management - R100/daily_ga/KALISUMAPA"''')
    os.system(f'''rclone copy dsn:postpaid/gcp/Postpaid_Daily_Activation_{year_month}_SUMATERA.xlsx dsn:"Retail Performance Management - R100/daily_ga/SUMATERA"''')
    os.system(f'''rclone copy dsn:postpaid/gcp/Postpaid_Daily_Activation_{year_month}_OTHERS.xlsx dsn:"Retail Performance Management - R100/daily_ga/OTHERS"''')

    ssh = SSHClient()
    ssh.set_missing_host_key_policy(AutoAddPolicy())
    ssh.connect('10.34.163.126', username='hdp-rdm', password='beqkZl@6' , port=22)
    sftp=ssh.open_sftp()   
    sftp.put(f"/data/gcp/Postpaid_Daily_Activation_{year_month}.csv", f"/home/hdp-rdm@office.corp.indosat.com/file_retail/Postpaid_Daily_Activation_{year_month}.csv") 
    command=f"hdfs dfs -rm -R /data/rdm/upload/_rpm/dump_daily_ga/Postpaid_Daily_Activation_{year_month}.csv"
    stdin, stdout, stderr = ssh.exec_command(command)  # Non-blocking call
    exit_status = stdout.channel.recv_exit_status()          # Blocking call
    if exit_status == 0:
        print ("running_success")
    else:
        print("Error", exit_status) 
    command=f"hdfs dfs -moveFromLocal /home/hdp-rdm@office.corp.indosat.com/file_retail/Postpaid_Daily_Activation_{year_month}.csv /data/rdm/upload/_rpm/dump_daily_ga/"
    stdin, stdout, stderr = ssh.exec_command(command)  # Non-blocking call
    exit_status = stdout.channel.recv_exit_status()          # Blocking call
    if exit_status == 0:
        print ("running_success")
    else:
        print("Error", exit_status)
    
    command='impala-shell --quiet -i udc2-impala-lb.office.corp.indosat.com:25003 -d default -k --ssl -q "refresh rdm.dump_daily_ga;"'
    stdin, stdout, stderr = ssh.exec_command(command)  # Non-blocking call
    exit_status = stdout.channel.recv_exit_status()          # Blocking call
    if exit_status == 0:
        print ("running_success")
    else:
        print("Error", exit_status)

    status='Finish send report daily ga to PBI and R100'
    return status

@op(retry_policy=RetryPolicy(max_retries=3, delay=60))
def create_cpp_renewal_program(last_status): 
    print(last_status)
    # rerun manual
    # dt_id ='20250731'
    # year_month = dt_id[:6]

    print(dt_id)
    filename = '/data/data_automation_bai/data_automation_scheduling/scripts/postpaid/postpaid_cpp_renewal_program.sql'
    fd = open(filename, 'r')
    sql_file = fd.read() 
    sql_file=sql_file.format(**{"year_month": year_month, 
                                "dt_id": dt_id
                                })
    fd.close() 
    query = sql_file.split(';')
    bq_project = "data-nationalslsdist-prd-986g"
    bq_dataset = "postpaid" 
    # bq_table = "raw_new_verification"
    client = bigquery.Client(project=bq_project)
    print('Start Deleting CPP Renewal Program')
    query_delete=f""" 
    delete from `data-nationalslsdist-prd-986g`.postpaid.raw_cpp_renewal_program 
    where substr(cpp_renewal_date, 1, 6)=SUBSTR('{dt_id}', 1, 6);
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
        print(f"Deletign to `data-nationalslsdist-prd-986g`.postpaid.raw_cpp_renewal_program")
    except Exception as e:
        print(f"Error Deleting new `data data-nationalslsdist-prd-986g`.postpaid.raw_cpp_renewal_program")
        raise

    print('Finish Deleting raw_cpp_renewal_program')

    job_config = bigquery.QueryJobConfig(
        query_parameters=[
            bigquery.ScalarQueryParameter("year_month", "STRING", year_month),
            bigquery.ScalarQueryParameter("dt_id", "STRING", dt_id)
        ]
    )
 
    try:
        job = client.query(query[0], job_config=job_config)
        job.result()  # Wait for the job to complete
        print(f"Inserting new data to `data-nationalslsdist-prd-986g`.postpaid.raw_cpp_renewal_program")
    except Exception as e:
        print(f"Error inserting new `data data-nationalslsdist-prd-986g`.postpaid.raw_cpp_renewal_programa")
        raise
    
    print('Starting dump report daily GA')
    bq_project = "data-nationalslsdist-prd-986g"
    bq_dataset = "postpaid" 
    bq_table = "raw_cpp_renewal_program"
    client = bigquery.Client(project=bq_project)
    # Your SQL query
    query = f"""
        SELECT *
        FROM `{bq_project}.{bq_dataset}.{bq_table}`
        WHERE substr(cpp_renewal_date, 1, 6)=SUBSTR('{dt_id}', 1, 6)
    """
    # Run query and return DataFrame
    df = client.query(query).to_dataframe()
    df.to_excel(f'/data/gcp/CPP_Renewal_Program_{year_month}.xlsx',index=False, sheet_name='Sheet1')

    os.system(f'''rclone copy /data/gcp/CPP_Renewal_Program_{year_month}.xlsx dsn:postpaid/gcp''')

    print('Start Dump Report CPP Renewal Program to R100')  
    os.system(f'''rclone copy dsn:postpaid/gcp/CPP_Renewal_Program_{year_month}.xlsx dsn:"Retail Performance Management - R100/platinum_cpp_renewal_program"''')

    status='Finish send report CPP Renewal Program R100'
    return status


@op(retry_policy=RetryPolicy(max_retries=3, delay=60))
def create_renewal_rate(last_status): 
    print(last_status)
    # rerun manual
    # dt_id ='20250731'
    # year_month = dt_id[:6]

    print(dt_id)
    filename = '/data/data_automation_bai/data_automation_scheduling/scripts/postpaid/postpaid_renewal_rate.sql'
    fd = open(filename, 'r')
    sql_file = fd.read() 
    sql_file=sql_file.format(**{"year_month": year_month, 
                                "dt_id": dt_id
                                })
    fd.close() 
    query = sql_file.split(';')
    bq_project = "data-nationalslsdist-prd-986g"
    bq_dataset = "postpaid" 
    # bq_table = "raw_new_verification"
    client = bigquery.Client(project=bq_project)
    
    print('Starting dump report renewal rate')
    bq_project = "data-nationalslsdist-prd-986g"
    client = bigquery.Client(project=bq_project)
    # Run query and return DataFrame
    print("01. Deleting postpaid renewal rate") 
    client.query(query[0]).result() 
    print("02. Inserting postpaid renewal rate") 
    client.query(query[1]).result() 
    print("03. Dump postpaid renewal rate") 
    df = client.query(query[2]).to_dataframe()
    df.to_excel(f'/data/gcp/renewal_rate_{year_month}.xlsx', index=False, sheet_name='Sheet1')

    os.system(f'''rclone copy /data/gcp/renewal_rate_{year_month}.xlsx dsn:postpaid/gcp''')

    print('Start Dump Report Renewal Rate to R100')  
    os.system(f'''rclone copy dsn:postpaid/gcp/renewal_rate_{year_month}.xlsx dsn:"Retail Performance Management - R100/renewal_rate"''')

    status='Finish send report CPP Renewal Program R100'
    return status

@op(retry_policy=RetryPolicy(max_retries=3, delay=60))
def write_trigger_file(last_status):
    print(last_status)
    # === Connection Config ===
    ssh_host = "10.34.167.52"
    ssh_port = 22
    ssh_user = "hdp-rdm"
    ssh_password = "beqkZl@6"   # or use ssh_key if available
    # remote_dir = "/data/05/ioh/BI/schedule/trigger/postpaid/"
    remote_dir = "/home/hdp-rdm@office.corp.indosat.com/bi_trigger/"
    today = dt.datetime.now().strftime("%Y%m%d")
    filename = f"raw_daily_ga_{today}"
    remote_path = os.path.join(remote_dir, filename)

    # Connect SSH
    ssh = paramiko.SSHClient()
    ssh.set_missing_host_key_policy(paramiko.AutoAddPolicy())
    ssh.connect(hostname=ssh_host, port=ssh_port, username=ssh_user, password=ssh_password)

    # Open SFTP
    sftp = ssh.open_sftp()
    try:
        # Open (or create) the file on remote server
        with sftp.file(remote_path, "w") as f:
            f.write("TRIGGER\n")   # content can be anything, often empty or just a flag word
        print(f"Trigger file created: {remote_path}")
    finally:
        sftp.close()
        ssh.close()

@op 
def t_postpaid_cc(status):
    print(status)
    # dt_id = (dt.date.today() - timedelta(days = 2)).strftime("%Y%m%d")
    # year_month = (dt.date.today() - timedelta(days = 2)).strftime("%Y%m")
    # rerun manual
    # dt_id='20250630'
    # year_month=dt_id[:6]
    # print(input_task)
    # dt_id='20250831'
    # year_month=dt_id[:6]
    print(dt_id) 

    filename = '/data/data_automation_bai/data_automation_scheduling/scripts/postpaid/postpaid_cc.sql'
    fd = open(filename, 'r')
    sql_file = fd.read() 
    sql_file=sql_file.format(**{"year_month": year_month, 
                                "dt_id": dt_id
                                })
    fd.close() 
    query = sql_file.split(';')
    bq_project = "data-nationalslsdist-prd-986g"
    bq_dataset = "postpaid" 
    bq_table = "dm_cc_monthly"
    client = bigquery.Client(project=bq_project)
    print('Start Deleting CC Monthly Postpaid')
    query_delete=f""" 
    delete from `data-nationalslsdist-prd-986g`.postpaid.dm_cc_monthly
	    where dt_id='{dt_id}'
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
        print(f"Finish Deleting CC Monthly Postpaid")
    except Exception as e:
        print(f"Error Deleting CC Monthly Postpaid")
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
        print(f"Inserting new data to `data-nationalslsdist-prd-986g`.postpaid.dm_cc_monthly")
    except Exception as e:
        print(f"Error inserting new `data data-nationalslsdist-prd-986g`.postpaid.dm_cc_monthly")
        raise

    try:
        job = client.query(query[1], job_config=job_config)
        job.result()  # Wait for the job to complete
        print(f"Updating new data to `data-nationalslsdist-prd-986g`.postpaid.dm_cc_monthly")
    except Exception as e:
        print(f"Error updating new `data data-nationalslsdist-prd-986g`.postpaid.dm_cc_monthly")
        raise
    
    print('Starting dump report daily GA')
    bq_project = "data-nationalslsdist-prd-986g"
    bq_dataset = "postpaid" 
    bq_table = "dm_cc_monthly"
    client = bigquery.Client(project=bq_project)
    # Your SQL query
    query = f"""
        SELECT * except (updated_dt)
        FROM `{bq_project}.{bq_dataset}.{bq_table}`
        where dt_id='{dt_id}'
    """
    # Run query and return DataFrame
    df_new = client.query(query).to_dataframe() 

    # filename = '/data/data_automation_bai/data_automation_scheduling/scripts/postpaid/postpaid_cc.sql'
    # fd = open(filename, 'r')
    # sql_file = fd.read() 
    # sql_file=sql_file.format(**{
    #                             "dt_id": dt_id
    #                             })
    # fd.close() 
    # query = sql_file.split(';') 
    # print('Champions Club Postpaid - GA Only')
    # execute_query(query[0]) 

    # print('Champions Club Postpaid - Sales Revenue')
    # execute_query(query[1])

    # print('Champions Club Postpaid - Store Productivity')
    # execute_query(query[2])

    # print('Champions Club Postpaid - Agent Productivity')
    # execute_query(query[3])

    # print('Champions Club Postpaid - M3S Monthly')
    # execute_query(query[4])

    # print('Champions Club Postpaid - GA M3S Monthly')
    # execute_query(query[5])

    # print('Champions Club Postpaid - M3S % Monthly')
    # execute_query(query[6])

    # print('Dump Data Champion Club')
    # cmd=f'''
    # select * from rdm.bai_kpi_postpaid 
    # WHERE mth_id='{year_month}' 
    # and dt_id='{dt_id}'
    # '''    
    # df_new=get_df(cmd)
    
    # os.system(f'''rclone copy dsn:postpaid/postpaid_champions_club_daily.xlsx /data/mkt/''')
    # df_old=pd.read_excel('/data/mkt/postpaid_champions_club_daily.xlsx', engine='openpyxl', sheet_name='sheet1')
    # df_old=df_old[df_old['mth_id']!=int(year_month)] 
    # df_result=pd.concat([df_old,df_new])  

    # df_result.to_excel("/data/mkt/postpaid_champions_club_daily.xlsx",
    # sheet_name='sheet1', 
    # index=False)
    # os.system(f'''rclone copy /data/mkt/postpaid_champions_club_daily.xlsx dsn:postpaid''')
    
    df_new.to_excel(f"/data/postpaid/postpaid_champions_{year_month}.xlsx",
    sheet_name='sheet1', 
    index=False)
    os.system(f'''rclone copy /data/postpaid/postpaid_champions_{year_month}.xlsx dsn:postpaid --ignore-times''')
    os.system(f'''rclone copy dsn:postpaid/postpaid_champions_{year_month}.xlsx dsn:"Retail Performance Management - R100/postpaid_champion_club"''')

    df_new.to_excel(f"/data/postpaid/postpaid_kpi_{year_month}.xlsx",
    sheet_name='sheet1', 
    index=False)
    os.system(f'''rclone copy /data/postpaid/postpaid_kpi_{year_month}.xlsx dsn:postpaid --ignore-times''')
    os.system(f'''rclone copy dsn:postpaid/postpaid_kpi_{year_month}.xlsx dsn:"Retail Performance Management - R100/postpaid_kpi"''')
    
    print('Dump Data Champion Club Finished')

    query = f"""
        select 
            dt_id as report_dt,
            region as region_circle,
            circle,
            sum(value_mtd) as mtd,
            sum(value_lmtd) as lmtd,
            'GA Only' as kpi_name
        from `data-nationalslsdist-prd-986g`.postpaid.dm_cc_monthly
        where kpi_name='GA'
            and dt_id='{dt_id}'
        group by 1, 2, 3, 6;
    """
    # Run query and return DataFrame
    df_ga = client.query(query).to_dataframe() 
    df_ga.to_csv(f'/data/mkt/cc_ga_{year_month}.csv', index=False)
    os.system(f'''rclone copy /data/mkt/cc_ga_{year_month}.csv dsn:postpaid''')
    os.system(f'''rclone copy dsn:postpaid/cc_ga_{year_month}.csv dsn:"Retail Performance Management - R100/champion_club/cc_postpaid"''') 
    status="finish running sales ga" 
    print(status) 

    query = f"""
    select 
        dt_id as report_dt,
        region as region_circle,
        circle,
        sum(value_mtd) as mtd,
        sum(value_lmtd) as lmtd,
        kpi_name as kpi_name
    from `data-nationalslsdist-prd-986g`.postpaid.dm_cc_monthly
    where kpi_name='Sales Revenue'
        and dt_id='{dt_id}'
    group by 1, 2, 3, 6;
    """
    # Run query and return DataFrame
    df_sales = client.query(query).to_dataframe()
    df_sales.to_csv(f'/data/mkt/cc_sales_revenue_{year_month}.csv', index=False)
    os.system(f'''rclone copy /data/mkt/cc_sales_revenue_{year_month}.csv dsn:postpaid''')
    os.system(f'''rclone copy dsn:postpaid/cc_sales_revenue_{year_month}.csv dsn:"Retail Performance Management - R100/champion_club/cc_postpaid"''') 
    
    return "Dump Champion Club Success"

@graph
def postpaid_daily_ga(): 
    t1 = get_raw_ga() 
    # t2 = get_n_process_ipos_file(t1)
    t3 = create_raw_ga(t1)
    t4 = create_cpp_renewal_program(t3)
    t5 = create_renewal_rate(t4)
    t6 = t_postpaid_cc(t5)
    write_trigger_file(t6)

# report_daily_ga()