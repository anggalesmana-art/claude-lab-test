from dagster import op, graph, schedule, DefaultScheduleStatus, repository, RetryPolicy, Failure  
from sshtunnel import SSHTunnelForwarder
import psycopg2
import pandas as pd
import datetime as dt 
from datetime import timedelta, datetime  
import time  
import os 
from dateutil.relativedelta import relativedelta 
import smbclient
import shutil
import jaydebeapi 
from sqlalchemy import create_engine, text  
import paramiko
from sqlalchemy.engine.url import URL
import tempfile
import psycopg2
from psycopg2 import sql
from paramiko import SSHClient, AutoAddPolicy 
from datetime import datetime, timedelta
from google.cloud import bigquery
from google.auth.transport.requests import Request
from google_auth_oauthlib.flow import InstalledAppFlow
from google.oauth2.credentials import Credentials
from google.cloud.bigquery import SchemaField
from google.cloud import storage
import glob
import random
import numpy as np
from numpy import nan
from dotenv import load_dotenv
import rarfile

def weeknum_excel(date, return_type=14):
    """
    Reproduce Excel WEEKNUM(serial_number, return_type)
    Supports return_type values:
      - 1..7   : week begins on Sun..Sat
      - 11..17 : alternate mapping where 11->Mon, 12->Tue, ..., 17->Sun
      - 21     : ISO week (equivalent to ISOWEEKNUM)
    For other values, it falls back to return_type=1 behavior.
    """
    if isinstance(date, str):
        date = datetime.strptime(date, "%Y-%m-%d")
    r = int(return_type)

    # ISO case
    if r == 21:
        return date.isocalendar()[1]

    # Map return_type to Excel weekday (1=Sun, 2=Mon, ..., 7=Sat)
    if 11 <= r <= 17:
        excel_week_start = r - 9   # 11->2 (Mon), 14->5 (Thu)
    elif 1 <= r <= 7:
        excel_week_start = r
    else:
        excel_week_start = 1  # default to Sunday

    # Convert Excel weekday (1=Sun..7=Sat) -> Python weekday (Mon=0..Sun=6)
    python_week_start = (excel_week_start + 5) % 7

    # Find start-of-week for the week that contains Jan 1 of the same year
    jan1 = datetime(date.year, 1, 1)
    offset = (jan1.weekday() - python_week_start) % 7
    start_of_week1 = jan1 - timedelta(days=offset)

    # Week number = number of full weeks since start_of_week1 + 1
    week_num = ((date - start_of_week1).days // 7) + 1
    return week_num 

# set
load_dotenv("/data/data_automation_bai/data_automation_scheduling/cred/pst_rtl.env")

# ==== CONFIG ====
JUMP_HOST = os.getenv("gp_ssh_host")
JUMP_USER = os.getenv("gp_ssh_user")
JUMP_PASS = os.getenv("gp_ssh_password")

SFTP_HOST = os.getenv("ipneperf_ssh_host")
SFTP_USER = os.getenv("ipneperf_ssh_user")
SFTP_PASS = os.getenv("ipneperf_ssh_password")

dts = (dt.date.today() - timedelta(days = 14)).strftime("%Y-%m-%d")
week_num = str(weeknum_excel(dts)).zfill(2)
year = dts[:4]

def download_network_file(week_num, year):
    print(f'start downloading {week_num} year {year}')
    REMOTE_RAR_PATH = f"/home/sftp_read/External/78. Internet Connection Traffic, Utilization & Performance Report/78_Internet Connection Traffic, Utilization & Performance Report_W{week_num}_{year}.rar"
    LOCAL_DIR = "/data/network_perf"
    LOCAL_RAR_PATH = os.path.join(LOCAL_DIR, os.path.basename(REMOTE_RAR_PATH))  # ✅ builds file path automatically

    os.makedirs(LOCAL_DIR, exist_ok=True)

    # ==== STEP 1: Create SSH Tunnel via Jump Host ====
    print("Opening SSH tunnel through jump host...")
    with SSHTunnelForwarder(
        (JUMP_HOST, 22),
        ssh_username=JUMP_USER,
        ssh_password=JUMP_PASS,
        remote_bind_address=(SFTP_HOST, 22),
        local_bind_address=('127.0.0.1', 0)
    ) as tunnel:
        local_port = tunnel.local_bind_port
        print(f"Tunnel established (local port {local_port})")

        transport = paramiko.Transport(('127.0.0.1', local_port))
        transport.connect(username=SFTP_USER, password=SFTP_PASS)
        sftp = paramiko.SFTPClient.from_transport(transport)

        print(f"Downloading {REMOTE_RAR_PATH}...")
        sftp.get(REMOTE_RAR_PATH, LOCAL_RAR_PATH)
        sftp.close()
        transport.close()
        print(f"Downloaded to {LOCAL_RAR_PATH}")

def get_next_year_week(current_year_week: str) -> str:
    year, week = map(int, current_year_week.split("-")) 
    # Parse using ISO week format
    current_date = datetime.strptime(f"{year} {week} 1", "%G %V %u")
    # Add 7 days to get next week
    next_date = current_date + timedelta(days=7)
    # Format back to ISO year-week
    next_year = next_date.strftime("%G")
    next_week = next_date.strftime("%V")
    # return f"{next_year}-{next_week}"
    return next_year, next_week

def download_network_file_2(file_name):
    SFTP_HOST = os.getenv("nekpi_ssh_host")
    SFTP_USER = os.getenv("nekpi_ssh_user")
    SFTP_PASS = os.getenv("nekpi_ssh_password") 

    print(f'start downloading {file_name}')
    REMOTE_RAR_PATH = f"/MPR_DATA/Weekly_New/{file_name}"
    LOCAL_DIR = "/data/network_perf"
    LOCAL_RAR_PATH = os.path.join(LOCAL_DIR, os.path.basename(REMOTE_RAR_PATH))  # ✅ builds file path automatically

    os.makedirs(LOCAL_DIR, exist_ok=True)

    # ==== STEP 1: Create SSH Tunnel via Jump Host ====
    print("Opening SSH tunnel through jump host...")
    with SSHTunnelForwarder(
        (JUMP_HOST, 22),
        ssh_username=JUMP_USER,
        ssh_password=JUMP_PASS,
        remote_bind_address=(SFTP_HOST, 22),
        local_bind_address=('127.0.0.1', 0)
    ) as tunnel:
        local_port = tunnel.local_bind_port
        print(f"Tunnel established (local port {local_port})")

        transport = paramiko.Transport(('127.0.0.1', local_port))
        transport.connect(username=SFTP_USER, password=SFTP_PASS)
        sftp = paramiko.SFTPClient.from_transport(transport)

        print(f"Downloading {REMOTE_RAR_PATH}...")
        sftp.get(REMOTE_RAR_PATH, LOCAL_RAR_PATH)
        sftp.close()
        transport.close()
        print(f"Downloaded to {LOCAL_RAR_PATH}")

@op
def iplinks_perf_weekly():
    # print(week_num, year)
    query = '''
    select
        max(concat(format_date('%Y',dt_id),'-',week_num))
    from `data-bi-prd-935c`.bi_dm.raw_iplinks_weekly_usage
    '''
    project_id = "data-bi-prd-935c"
    dataset_id = "bi_dm"
    client = bigquery.Client(project=project_id)
    week_current=client.query(query).to_dataframe()
    week_current=week_current.iloc[0,0]
    print(week_current)
    # next_year, next_week = get_next_year_week(week_num)
    year, week_num = get_next_year_week(week_current) 
    download_network_file(week_num, year)
    REMOTE_RAR_PATH = f"/home/sftp_read/External/78. Internet Connection Traffic, Utilization & Performance Report/78_Internet Connection Traffic, Utilization & Performance Report_W{week_num}_{year}.rar"
    LOCAL_DIR = "/data/network_perf"
    LOCAL_RAR_PATH = os.path.join(LOCAL_DIR, os.path.basename(REMOTE_RAR_PATH))  # ✅ builds file path automatically
    EXTRACT_FOLDER=os.path.join(LOCAL_DIR, f"extracted_W{week_num}_{year}")
    # ==== STEP 2: Extract .RAR File ==== 
    rarfile.UNRAR_TOOL = "/data/tools/rar/unrar"
    print("Extracting .rar file...")
    if not os.path.exists(EXTRACT_FOLDER):
        os.makedirs(EXTRACT_FOLDER)

    rf = rarfile.RarFile(LOCAL_RAR_PATH)
    rf.extractall(EXTRACT_FOLDER)
    rf.close()

    print(f"Files extracted to {EXTRACT_FOLDER}")
    print(week_num, year)
    # file_dir = f"/data/network_perf/extracted_W{week_num}_{year}/Intl IP Links Weekly Usage_W{week_num}_v2_{year}.xlsx"
    folder_path = f"/data/network_perf/extracted_W{week_num}_{year}"  # change this
    pattern = f"Intl IP Links Weekly Usage_W{week_num}"  # part of the filename you want to match
    
    # Find matching Excel files (e.g., something.xlsx, something_data.xlsx, etc.)
    file_dir = glob.glob(os.path.join(folder_path, f"*{pattern}*.xlsx"))

    if not file_dir:
        print("No Excel files found matching pattern.")
    file_dir=file_dir[0]
    print(file_dir)
    df_im3 = pd.read_excel(file_dir, 
                        sheet_name='Wk',
                        usecols='A:C',
                        dtype=str,
                        engine='openpyxl')

    df_im3.columns=['dt_id', 'mo_entity', 'traffic_mbps']
    df_im3['brand']='IM3'
    df_3id = pd.read_excel(file_dir, 
                        sheet_name='3id_Wk',
                        usecols='A:C',
                        dtype=str,
                        engine='openpyxl')
    df_3id.columns=['dt_id', 'mo_entity', 'traffic_mbps']
    df_3id['brand']='3ID'
    df=pd.concat([df_im3,df_3id])
    df=df.dropna(axis=0,subset=['dt_id', 'mo_entity', 'traffic_mbps'],how='all')
    df['week_num']=week_num
    df['traffic_mbps']=df['traffic_mbps'].astype('float64')
    df['dt_id']=pd.to_datetime(df['dt_id'], format='%Y-%m-%d').dt.date
    project_id = "data-bi-prd-935c"
    dataset_id = "bi_dm"
    table_id = "raw_iplinks_weekly_usage"
    client = bigquery.Client(project=project_id)
    full_table_id = f"{project_id}.{dataset_id}.{table_id}"
    delete_query = f"""
            DELETE FROM `{full_table_id}`
            WHERE week_num = '{week_num}' 
            """
    print(delete_query)
    client.query(delete_query).result()
     # ==== APPEND NEW DATA ====
    job_config = bigquery.LoadJobConfig(
        write_disposition=bigquery.WriteDisposition.WRITE_APPEND,
        autodetect=True,
    )
    job = client.load_table_from_dataframe(df, full_table_id, job_config=job_config)
    job.result()

    print(f"Success Appended {len(df)} rows into {full_table_id}")

    # file_dir = f"/data/network_perf/extracted_W{week_num}_{year}/Intl IP Links Weekly Usage_W{week_num}_v2_{year}.xlsx"
    folder_path = f"/data/network_perf/extracted_W{week_num}_{year}"  # change this
    pattern = f"Intl IP Links Weekly Usage_W{week_num}"  # part of the filename you want to match

    # Find matching Excel files (e.g., something.xlsx, something_data.xlsx, etc.)
    file_dir = glob.glob(os.path.join(folder_path, f"*{pattern}*.xlsx"))

    if not file_dir:
        print("No Excel files found matching pattern.")
    file_dir=file_dir[0]
    print(file_dir)
    df = pd.read_excel(file_dir, 
                        sheet_name='Mapping_3ID',
                        usecols='A:Q',
                        dtype=str,
                        engine='openpyxl')
    cols=[
        'rg',
        'ne',
        'router_and_swicth',
        'cap_check',
        'group_ne',
        'island',
        'isp',
        'capacity',
        'add_inp_foc',
        'cache',
        'vendor',
        'rg_2',
        'rg_3',
        'lcek',
        'check_2',
        'check_3',
        'router_and_switch_check'
    ]
    df.columns=cols
    df=df.dropna(axis=0,subset=cols,how='all')
    df=df.drop(['cap_check', 'lcek', 'check_2', 'check_3', 'router_and_switch_check'],axis=1)
    df['brand']='3ID'
    df['week_num']=week_num
    df['capacity']=df['capacity'].astype('float64')
    project_id = "data-bi-prd-935c"
    dataset_id = "bi_dm"
    table_id = "ref_iplinks_mapping_3id"
    client = bigquery.Client(project=project_id)
    full_table_id = f"{project_id}.{dataset_id}.{table_id}"
    delete_query = f"""
            DELETE FROM `{full_table_id}`
            WHERE week_num = '{week_num}' 
            """
    print(delete_query)
    client.query(delete_query).result()
     # ==== APPEND NEW DATA ====
    job_config = bigquery.LoadJobConfig(
        write_disposition=bigquery.WriteDisposition.WRITE_APPEND,
        autodetect=True,
    )
    job = client.load_table_from_dataframe(df, full_table_id, job_config=job_config)
    job.result()

    # file_dir = f"/data/network_perf/extracted_W{week_num}_{year}/Intl IP Links Weekly Usage_W{week_num}_v2_{year}.xlsx"
    folder_path = f"/data/network_perf/extracted_W{week_num}_{year}"  # change this
    pattern = f"Intl IP Links Weekly Usage_W{week_num}"  # part of the filename you want to match

    # Find matching Excel files (e.g., something.xlsx, something_data.xlsx, etc.)
    file_dir = glob.glob(os.path.join(folder_path, f"*{pattern}*.xlsx"))

    if not file_dir:
        print("No Excel files found matching pattern.")
    file_dir=file_dir[0]
    print(file_dir)
    df = pd.read_excel(file_dir, 
                        sheet_name='Mapping',
                        usecols='A:G',
                        dtype=str,
                        engine='openpyxl')
    cols=[
        'int_ip_router',
        'site',
        'pop',
        'interface',
        'partner',
        'capacity',
        'group_ne'
    ]
    df.columns=cols
    df=df.dropna(axis=0,subset=cols,how='all')
    # df=df.drop(['cap_check', 'lcek', 'check_2', 'check_3', 'router_and_switch_check'],axis=1)
    df['brand']='IM3'
    df['week_num']=week_num
    df['capacity']=df['capacity'].astype('float64')
    project_id = "data-bi-prd-935c"
    dataset_id = "bi_dm"
    table_id = "ref_iplinks_mapping_im3"
    client = bigquery.Client(project=project_id)
    full_table_id = f"{project_id}.{dataset_id}.{table_id}"
    delete_query = f"""
            DELETE FROM `{full_table_id}`
            WHERE week_num = '{week_num}' 
            """
    print(delete_query)
    client.query(delete_query).result()
     # ==== APPEND NEW DATA ====
    job_config = bigquery.LoadJobConfig(
        write_disposition=bigquery.WriteDisposition.WRITE_APPEND,
        autodetect=True,
    )
    job = client.load_table_from_dataframe(df, full_table_id, job_config=job_config)
    job.result()
    status = 'All task finished'
    return status

@op
def ran_rsrp_perf(): 
    try:
        print('RSRP')
        query = '''
        select 
            max(`week`) week
        from `data-bi-prd-935c`.bi_dm.raw_net_rsrp;
        '''
        project_id = "data-bi-prd-935c"
        dataset_id = "bi_dm"
        client = bigquery.Client(project=project_id)
        week_num=client.query(query).to_dataframe()
        week_num=week_num.iloc[0,0]
        next_year, next_week = get_next_year_week(week_num)
        #next_year,next_week = get_next_year_week('2025-47')
        print(next_week)
        file_name=f"locked_rsrp_{next_year}-{next_week}.csv"
        download_network_file_2(file_name)
        df=pd.read_csv(f'/data/network_perf/{file_name}')
        df.columns=df.columns.str.lower().str.replace(' ', '_')
        df=df[['siteid', 'week', 'rsrp', 'bad_rsrp', 'status_rsrp']]
        df['date_partition'] = pd.to_datetime(df['week'] + '-1', format='%G-%V-%u')
        project_id = "data-bi-prd-935c"
        dataset_id = "bi_dm"
        table_id = "raw_net_rsrp"
        client = bigquery.Client(project=project_id)
        full_table_id = f"{project_id}.{dataset_id}.{table_id}" 

        delete_query = f"""
                    DELETE FROM `{full_table_id}`
                    WHERE week = '{next_year}-{next_week}' 
                    """
        print(delete_query)
        client.query(delete_query).result()


        # ==== APPEND NEW DATA ====
        job_config = bigquery.LoadJobConfig(
            write_disposition=bigquery.WriteDisposition.WRITE_APPEND,
            autodetect=True,
        )
        job = client.load_table_from_dataframe(df, full_table_id, job_config=job_config)
        job.result()
        status=f"Success Appended {len(df)} rows into {full_table_id}"
        print(status)
        return status
    except Exception as e:
        status=f"Step failed in file{file_name} but pipeline continues with error {e}"
        print(status)
        return status

@op
def ran_streaming_perf(status):
    try:
        print(status)
        query = '''
        select 
            max(`week`) week
        from `data-bi-prd-935c`.bi_dm.raw_net_streaming;
        '''
        project_id = "data-bi-prd-935c"
        dataset_id = "bi_dm"
        client = bigquery.Client(project=project_id)
        week_num=client.query(query).to_dataframe()
        week_num=week_num.iloc[0,0]
        next_year, next_week = get_next_year_week(week_num)

        file_name=f"Streaming Thp_all site_W{next_week}-{next_year}.xlsx"

        download_network_file_2(file_name)
        df=pd.read_excel(f'/data/network_perf/{file_name}', engine='openpyxl', dtype=str)
        df.columns = (
            df.columns
            .str.strip()                 # remove leading/trailing spaces
            .str.lower()                 # to lowercase
            .str.replace(r"[\.\s]+", "_", regex=True)  # replace . or space with _
        )
        df = df.dropna(subset=['year', 'week', 'site_id'])
        df['week']=df['year'].astype(str)+'-'+df['week'].astype(str)
        df=df[['week',
            'site_id',
            'avg_streaming_dw_throughput_mbps',
            'avg_video_streaming_start_delay_s',
            'flag_thp',
            'flag_start_delay',
            'threshold_flag'
            ]]
        df['avg_streaming_dw_throughput_mbps']=df['avg_streaming_dw_throughput_mbps'].astype(float)
        df['avg_video_streaming_start_delay_s']=df['avg_video_streaming_start_delay_s'].astype(float)
        df['flag_thp']=df['flag_thp'].astype(float)
        df['flag_start_delay']=df['flag_start_delay'].astype(float)
        df['threshold_flag']=df['threshold_flag'].astype(float)
        df['date_partition'] = pd.to_datetime(df['week'] + '-1', format='%G-%V-%u')
        project_id = "data-bi-prd-935c"
        dataset_id = "bi_dm"
        table_id = "raw_net_streaming"
        client = bigquery.Client(project=project_id)
        full_table_id = f"{project_id}.{dataset_id}.{table_id}" 

        delete_query = f"""
                    DELETE FROM `{full_table_id}`
                    WHERE week = '{next_year}-{next_week}' 
                    """
        print(delete_query)
        client.query(delete_query).result()


        # ==== APPEND NEW DATA ====
        job_config = bigquery.LoadJobConfig(
            write_disposition=bigquery.WriteDisposition.WRITE_APPEND,
            autodetect=True,
        )
        job = client.load_table_from_dataframe(df, full_table_id, job_config=job_config)
        job.result()

        status=f"Success Appended {len(df)} rows into {full_table_id}"
        print(status)
        return status
    except Exception as e:
        status=f"Step failed in file{file_name} but pipeline continues with error {e}"
        print(status)
        return status

@op
def ran_eut_perf(status):
    try:
        print(status)
        query = '''
        select 
            max(`week`) week
        from `data-bi-prd-935c`.bi_dm.raw_net_eut;
        '''
        project_id = "data-bi-prd-935c"
        dataset_id = "bi_dm"
        client = bigquery.Client(project=project_id)
        week_num=client.query(query).to_dataframe()
        week_num=week_num.iloc[0,0]
        next_year, next_week = get_next_year_week(week_num)

        file_name=f"EUT_BelowDesign_{next_year}{next_week}.csv"

        download_network_file_2(file_name)
        df=pd.read_csv(f'/data/network_perf/{file_name}')
        df
        df.columns = (
            df.columns
            .str.strip()                 # remove leading/trailing spaces
            .str.lower()                 # to lowercase
            .str.replace(r"[\.\s]+", "_", regex=True)  # replace . or space with _
        )
        df
        df=df[[
            'week',
            'site_id_oss',
            'site_id_2',
            'site_name',
            'site_type',
            'prb_sec_1',
            'prb_sec_2',
            'prb_sec_3',
            'eut_sec_1',
            'eut_sec_2',
            'eut_sec_3',
            'eut_sec_1_denom',
            'eut_sec_2_denom',
            'eut_sec_3_denom',
            'eut_sec_1_nom',
            'eut_sec_2_nom',
            'eut_sec_3_nom',
            'remark_belowdesign_sec_1',
            'remark_belowdesign_sec_2',
            'remark_belowdesign_sec_3',
            'remark_belowdesign_site'
            ]]
        df
        df['date_partition'] = pd.to_datetime(df['week'] + '-1', format='%G-%V-%u')
        project_id = "data-bi-prd-935c"
        dataset_id = "bi_dm"
        table_id = "raw_net_eut"
        client = bigquery.Client(project=project_id)
        full_table_id = f"{project_id}.{dataset_id}.{table_id}" 

        delete_query = f"""
                    DELETE FROM `{full_table_id}`
                    WHERE week = '{next_year}-{next_week}' 
                    """
        print(delete_query)
        client.query(delete_query).result()


        # ==== APPEND NEW DATA ====
        job_config = bigquery.LoadJobConfig(
            write_disposition=bigquery.WriteDisposition.WRITE_APPEND,
            autodetect=True,
        )
        job = client.load_table_from_dataframe(df, full_table_id, job_config=job_config)
        job.result()
        status=f"Success Appended {len(df)} rows into {full_table_id}"
        print(status)
        return status
    except Exception as e:
        status=f"Step failed in file{file_name} but pipeline continues with error {e}"
        print(status)
        return status

@op
def ran_suppress_perf(status):
    try:
        print(status)
        query = '''
        select 
            max(`week`) week
        from `data-bi-prd-935c`.bi_dm.raw_net_suppress;
        '''
        project_id = "data-bi-prd-935c"
        dataset_id = "bi_dm"
        client = bigquery.Client(project=project_id)
        week_num=client.query(query).to_dataframe()
        week_num=week_num.iloc[0,0]
        next_year, next_week = get_next_year_week(week_num)

        file_name=f"{next_year}{next_week}_suppression.csv"

        download_network_file_2(file_name)
        df=pd.read_csv(f'/data/network_perf/{file_name}')
        df

        df.columns = (
            df.columns
            .str.strip()                 # remove leading/trailing spaces
            .str.lower()                 # to lowercase
            .str.replace(r"[\.\s]+", "_", regex=True)  # replace . or space with _
        )
        df
        df=df[[
            'site_id',
            'siteid_ii',
            'prb_sect_1',
            'prb_sect_2',
            'prb_sect_3',
            '#prb_sect_1',
            '#prb_sect_2',
            '#prb_sect_3',
            'bh_traffic_loss_sect_1',
            'bh_traffic_loss_sect_2',
            'bh_traffic_loss_sect_3',
            'bh_traffic_loss',
            'status_sect_1',
            'status_sect_2',
            'status_sect_3',
            'status_suppress_commerce',
            'week'
            ]]
        df
        df['siteid_ii']=df.apply(lambda x: x['siteid_ii'][len(x['site_id']):], axis=1)
        df.columns=[
            'site_id',
            'coverage',
            'prb_util_sect_1',
            'prb_util_sect_2',
            'prb_util_sect_3',
            'prb_sect_1',
            'prb_sect_2',
            'prb_sect_3',
            'traffic_loss_sect_1',
            'traffic_loss_sect_2',
            'traffic_loss_sect_3',
            'total_bh_traffic_loss',
            'commerce_sect_1',
            'commerce_sect_2',
            'commerce_sect_3',
            'status_suppress_commerce',
            'week'
        ]
        df
        df['week']=df['week'].str.replace('W','')
        df['date_partition'] = pd.to_datetime(df['week'] + '-1', format='%G-%V-%u')
        project_id = "data-bi-prd-935c"
        dataset_id = "bi_dm"
        table_id = "raw_net_suppress"
        client = bigquery.Client(project=project_id)
        full_table_id = f"{project_id}.{dataset_id}.{table_id}" 

        delete_query = f"""
                    DELETE FROM `{full_table_id}`
                    WHERE week = '{next_year}-{next_week}' 
                    """
        print(delete_query)
        client.query(delete_query).result()


        # ==== APPEND NEW DATA ====
        job_config = bigquery.LoadJobConfig(
            write_disposition=bigquery.WriteDisposition.WRITE_APPEND,
            autodetect=True,
        )
        job = client.load_table_from_dataframe(df, full_table_id, job_config=job_config)
        job.result()

        status=f"Success Appended {len(df)} rows into {full_table_id}"
        print(status)
        return status
    except Exception as e:
        status=f"Step failed in file{file_name} but pipeline continues with error {e}"
        print(status)
        return status

@op
def ran_qoe_perf(status):
    try:
        print(status)
        query = '''
        select 
            max(`week`) week
        from `data-bi-prd-935c`.bi_dm.raw_net_qoe;
        '''
        project_id = "data-bi-prd-935c"
        dataset_id = "bi_dm"
        client = bigquery.Client(project=project_id)
        week_num=client.query(query).to_dataframe()
        week_num=week_num.iloc[0,0]
        next_year, next_week = get_next_year_week(week_num)

        file_name=f"qoe_{next_year}{next_week}.csv"

        download_network_file_2(file_name)
        df=pd.read_csv(f'/data/network_perf/{file_name}')
        df

        df.columns = (
            df.columns
            .str.strip()                 # remove leading/trailing spaces
            .str.lower()                 # to lowercase
            .str.replace(r"[\.\s]+", "_", regex=True)  # replace . or space with _
        )
        df
        df=df[[
            'yearweek',
            'siteid',
            'excellent_data_nom',
            'excellent_data_denom',
            'excellent_data',
            'bad_excellent_qoe_data'
            ]]
        df
        df.columns=[
            'week',
            'siteid',
            'excellent_data_nom',
            'excellent_data_denom',
            'excellent_data',
            'bad_excellent_qoe_data'
        ]
        df
        df['week']=df['week'].str.replace('W','')
        df['date_partition'] = pd.to_datetime(df['week'] + '-1', format='%G-%V-%u')
        project_id = "data-bi-prd-935c"
        dataset_id = "bi_dm"
        table_id = "raw_net_qoe"
        client = bigquery.Client(project=project_id)
        full_table_id = f"{project_id}.{dataset_id}.{table_id}" 

        delete_query = f"""
                    DELETE FROM `{full_table_id}`
                    WHERE week = '{next_year}-{next_week}' 
                    """
        print(delete_query)
        client.query(delete_query).result()


        # ==== APPEND NEW DATA ====
        job_config = bigquery.LoadJobConfig(
            write_disposition=bigquery.WriteDisposition.WRITE_APPEND,
            autodetect=True,
        )
        job = client.load_table_from_dataframe(df, full_table_id, job_config=job_config)
        job.result()

        status=f"Success Appended {len(df)} rows into {full_table_id}"
        print(status)
        return status
    except Exception as e:
        status=f"Step failed in file{file_name} but pipeline continues with error {e}"
        print(status)
        return status

@op
def ran_voice_perf(status):
    try:
        print(status)
        query = '''
        select 
            max(`week`) week
        from `data-bi-prd-935c`.bi_dm.raw_net_voice;
        '''
        project_id = "data-bi-prd-935c"
        dataset_id = "bi_dm"
        client = bigquery.Client(project=project_id)
        week_num=client.query(query).to_dataframe()
        week_num=week_num.iloc[0,0]
        next_year, next_week = get_next_year_week(week_num)

        file_name=f"ran_index_{next_year}{next_week}.csv"

        download_network_file_2(file_name)
        df=pd.read_csv(f'/data/network_perf/{file_name}')
        df

        df.columns = (
            df.columns
            .str.strip()                 # remove leading/trailing spaces
            .str.lower()                 # to lowercase
            .str.replace(r"[\.\s]+", "_", regex=True)  # replace . or space with _
        )
        df
        df=df[[
            'year_months',
            'siteid',
            '4g_voice_score',
            '2g_voice_score',
            'volte_low',
            'voice_low_70',
            'voice_low_80'
            ]]
        df
        df[['volte_low','voice_low_70','voice_low_80']]=df[['volte_low','voice_low_70','voice_low_80']].fillna(0)
        df
        df.columns=[
            'week',
            'siteid',
            'v_4g_voice_score',
            'v_2g_voice_score',
            'volte_low',
            'voice_low_70',
            'voice_low_80'
        ]
        df
        df['week']=df['week'].str.replace('W','')
        df['date_partition'] = pd.to_datetime(df['week'] + '-1', format='%G-%V-%u')
        project_id = "data-bi-prd-935c"
        dataset_id = "bi_dm"
        table_id = "raw_net_voice"
        client = bigquery.Client(project=project_id)
        full_table_id = f"{project_id}.{dataset_id}.{table_id}" 

        delete_query = f"""
                    DELETE FROM `{full_table_id}`
                    WHERE week = '{next_year}-{next_week}' 
                    """
        print(delete_query)
        client.query(delete_query).result()


        # ==== APPEND NEW DATA ====
        job_config = bigquery.LoadJobConfig(
            write_disposition=bigquery.WriteDisposition.WRITE_APPEND,
            autodetect=True,
        )
        job = client.load_table_from_dataframe(df, full_table_id, job_config=job_config)
        job.result()

        status=f"Success Appended {len(df)} rows into {full_table_id}"
        print(status)
        return status
    except Exception as e:
        status=f"Step failed in file{file_name} but pipeline continues with error {e}"
        print(status)
        return status



@graph
def ne_perf_weekly():
    iplinks_perf_weekly()
    t0=ran_rsrp_perf()
    t1=ran_streaming_perf(t0)
    t2=ran_eut_perf(t1)
    t3=ran_suppress_perf(t2)
    t4=ran_qoe_perf(t3)
    t5=ran_voice_perf(t4)