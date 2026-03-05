from dagster import op, graph, schedule, DefaultScheduleStatus, repository, RetryPolicy  
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
import os
import datetime as dt
import paramiko
import io

# set
load_dotenv("/data/data_automation_bai/data_automation_scheduling/cred/pst_rtl.env")

# Get data D-2 
dt_id = (dt.date.today() - timedelta(days = 2)).strftime("%Y%m%d")  

# Rerun manual
# dt_id ="20250331" 

year_month=dt_id[:6]

@op
def site_5g_kpi_mtd(): 
    project_id = "data-nationalslsdist-prd-986g"
    client = bigquery.Client(project=project_id)
    filename = '/data/data_automation_bai/data_automation_scheduling/scripts/network/site_5g_kpi_mtd.sql'
    fd = open(filename, 'r')
    sql_file = fd.read() 
    sql_file=sql_file.format(**{"year_month": year_month, 
                                "dt_id": dt_id
                                })
    fd.close() 
    query = sql_file.split(';') 
    print("01. Start Dump Site 5G KPI MTD") 
    df=client.query(query[0]).to_dataframe()
    df.to_csv('/data/tmp/site_5g_kpi_mtd.csv', index=False, sep='|') 

    # === Connection Config ===
    ssh_host = "10.34.167.52"
    ssh_port = 22
    ssh_user = "hdp-rdm"
    ssh_password = "beqkZl@6"   # consider using key/env in prod

    remote_dir = "/data/05/ioh/BI/ero/file_network"
    # today = dt.datetime.now().strftime("%Y%m%d")
    filename = f"site_5g_kpi_mtd.csv"
    remote_path = os.path.join(remote_dir, filename)

    # === Convert DataFrame to CSV in memory ===
    csv_buffer = io.StringIO()
    df.to_csv(csv_buffer, index=False, sep='|')
    csv_buffer.seek(0)

    # === Connect SSH ===
    ssh = paramiko.SSHClient()
    ssh.set_missing_host_key_policy(paramiko.AutoAddPolicy())
    ssh.connect(
        hostname=ssh_host,
        port=ssh_port,
        username=ssh_user,
        password=ssh_password
    )

    # === Open SFTP and write file ===
    sftp = ssh.open_sftp()
    try:
        with sftp.file(remote_path, "w") as remote_file:
            remote_file.write(csv_buffer.getvalue())

        print(f"CSV file successfully created: {remote_path}")
    finally:
        sftp.close()
        ssh.close()

    os.system(f'''rclone copy /data/tmp/site_5g_kpi_mtd.csv dsn:tmp''')
    os.system(f'''rclone copy dsn:tmp/site_5g_kpi_mtd.csv dsn:"Business Intelligence's files - Master_Tracker"''')
    status='Task finished'
    return status

@op
def technocom_network_competition(status):
    print(status)
    month_dt=((dt.date.today() - timedelta(days = 2)).replace(day=1)).strftime("%Y-%m-%d")
    start_dt=((dt.date.today() - timedelta(days = 2)).replace(day=1)).strftime("%Y-%m-%d")
    end_dt=(dt.date.today() - timedelta(days = 2)).strftime("%Y-%m-%d")
    asof_dt=(dt.date.today() - timedelta(days = 2)).strftime("%Y-%m-%d")
    query = '''
        select
            max(week_num)
        from `data-bi-prd-935c`.bi_dm.raw_iplinks_weekly_usage
        '''
    project_id = "data-bi-prd-935c"
    dataset_id = "bi_dm"
    client = bigquery.Client(project=project_id)
    week_cache=client.query(query).to_dataframe()
    week_cache=week_cache.iloc[0,0]
    print(f'''month_dt:{month_dt}\n
    start_dt:{start_dt}\n
    end_dt:{end_dt}\n
    asof_dt:{asof_dt}\n
    week_cache:{week_cache}''')
    filename = '/data/data_automation_bai/data_automation_scheduling/scripts/network/technocom_network_competition.sql'
    fd = open(filename, 'r')
    sql_file = fd.read() 
    sql_file=sql_file.format(**{"month_dt": month_dt, 
                                "start_dt": start_dt,
                                "end_dt": end_dt,
                                "asof_dt": asof_dt,
                                "week_cache": week_cache
                                })
    fd.close() 
    query = sql_file.split(';')
    print("01. Delete Technocom Network Competition")
    client.query(query[0]).result()
    print("02. Insert Technocom Network Competition")
    client.query(query[1]).result()
    status='Task Finished'
    return status

@op
def technocom_dashboard_data(): 
    project_id = "data-bi-prd-935c"
    client = bigquery.Client(project=project_id)
    filename = '/data/data_automation_bai/data_automation_scheduling/scripts/network/technocom_dashboard_data.sql'
    fd = open(filename, 'r')
    sql_file = fd.read() 
    sql_file=sql_file.format(**{"year_month": year_month, 
                                "dt_id": dt_id
                                })
    fd.close() 
    query = sql_file.split(';')
    print("01. Delete Technocom Dashboard Data")
    client.query(query[0]).result()
    print("02. Insert Technocom Dashboard Data")
    client.query(query[1]).result()
    print("03. Insert Agg KPI Technocom Dashboard Data")
    client.query(query[2]).result()
    status='Task Finished'
    return status

@graph
def ne_perf_daily():
    t0=site_5g_kpi_mtd()
    technocom_dashboard_data()
    # technocom_network_competition(t0)
    