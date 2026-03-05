from dagster import op, graph, schedule, DefaultScheduleStatus, repository 
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
import numpy as np
from google.cloud import bigquery
from google.auth.transport.requests import Request
from google_auth_oauthlib.flow import InstalledAppFlow
from google.oauth2.credentials import Credentials
from google.cloud.bigquery import SchemaField
from google.cloud import storage

# Get data D-2 
dt_id = (dt.date.today() - timedelta(days = 2)).strftime("%Y%m%d") 
# year_month=(dt.date.today() - timedelta(days = 2)).strftime("%Y%m") 
 

# Rerun manual
# dt_id ="20251117"
year_month=dt_id[:6]
# ym1="202506"
# ym1="202505"
# ym1="202504"

# fd_id = ((dt.date.today() - timedelta(days = 2)).replace(day=1)).strftime("%Y%m%d")  
# dt_min2 = (dt.date.today() - timedelta(days = 2)).strftime("%Y%m%d")
# fm=(dt.date.today() - timedelta(days = 2)).strftime("%Y%m")
# lfm = (dt.date.today() - relativedelta(months = 2)).strftime("%Y%m") 
# ldt_id = ((dt.date.today() - timedelta(days = 2)) - relativedelta(months = 1)).strftime("%Y%m%d") 
# lfd_id = ((dt.date.today() - timedelta(days = 2)) - relativedelta(months = 1)).replace(day=1).strftime("%Y%m%d") 

# SSH and PostgreSQL Configuration
SSH_HOST = '10.34.167.52'          # SSH server IP or hostname
SSH_PORT = 22                     # SSH server port
SSH_USER = 'hdp-rdm'             # SSH username
SSH_PASSWORD = 'beqkZl@6'     # SSH password

DB_HOST = '10.64.16.165'           # PostgreSQL server IP
DB_PORT = 5432                    # PostgreSQL port
DB_NAME = 'pdwh'         # PostgreSQL database name
DB_USER = 'ioh_dinar_syahid'               # PostgreSQL username
DB_PASSWORD = 'iohds#123'       # PostgreSQL password

# SMB Server details
server = "10.34.3.12"
share = "RETAIL"
username = "INDOSAT\\NSH_BAI"
password = "ISATnov24*!!"

## SQL Script  
# filename = '/data/data_automation_bai/data_automation_scheduling/scripts/dsf/dsf_3id_report.sql'
# fd = open(filename, 'r')
# sql_file = fd.read() 
# sql_file=sql_file.format(**{"year_month": year_month, 
#                             "dt_id": dt_id,
#                             "fd_id" : fd_id,
#                             "dt_min2": dt_min2,
#                             "fm": fm,
#                             "lfm": lfm, 
#                             "ldt_id": ldt_id, 
#                             "lfd_id": lfd_id
#                             })
# fd.close() 
# query = sql_file.split(';')

def get_previous_month(year_month: int, num_months: int = 1):
    # Convert integer to string and parse into datetime object
    year = int(str(year_month)[:4])
    month = int(str(year_month)[4:])
    current_date = datetime(year, month, 1)
    
    # Calculate the target previous month
    for _ in range(num_months):
        current_date = (current_date.replace(day=1) - timedelta(days=1))
    
    return current_date.strftime('%Y%m')

## Function for grab, read, and execute data in Greenplum
def connect_and_tunnel():
    tunnel = SSHTunnelForwarder(
        (SSH_HOST, SSH_PORT),
        ssh_username=SSH_USER,
        ssh_password=SSH_PASSWORD,
        remote_bind_address=(DB_HOST, DB_PORT),
        local_bind_address=('localhost', 0)  # Dynamic port
    )
    try:
        tunnel.start()
        print(f"SSH tunnel established on localhost:{tunnel.local_bind_port}")
        connection = psycopg2.connect(
            host='localhost',
            port=tunnel.local_bind_port,
            database=DB_NAME,
            user=DB_USER,
            password=DB_PASSWORD
        )
        print("Connected to PostgreSQL database.")
        return tunnel, connection
    except Exception as e:
        if tunnel.is_active:
            tunnel.stop()
        raise e 
                
def connect_and_tunnel_engine():
    tunnel = SSHTunnelForwarder(
        (SSH_HOST, SSH_PORT),
        ssh_username=SSH_USER,
        ssh_password=SSH_PASSWORD,
        remote_bind_address=(DB_HOST, DB_PORT),
        local_bind_address=('localhost', 0)
    )
    try:
        tunnel.start()
        print(f"SSH tunnel established on localhost:{tunnel.local_bind_port}")

        engine = create_engine(
            f"postgresql+psycopg2://{DB_USER}:{DB_PASSWORD}@localhost:{tunnel.local_bind_port}/{DB_NAME}"
        )
        return tunnel, engine
    except Exception as e:
        if tunnel.is_active:
            tunnel.stop()
        raise e
    
def write_df_fast(df, table_name, schema='public'):
    tunnel, _ = connect_and_tunnel_engine()
    try:
        # Create a temporary CSV file from DataFrame
        with tempfile.NamedTemporaryFile(mode='w', suffix='.csv', delete=False) as tmpfile:
            df.to_csv(tmpfile.name, index=False)
            tmpfile_path = tmpfile.name
        
        print(f"Temporary CSV file created at: {tmpfile_path}")

        # Use psycopg2 directly to connect through the tunnel
        conn = psycopg2.connect(
            host='localhost',
            port=tunnel.local_bind_port,
            dbname=DB_NAME,
            user=DB_USER,
            password=DB_PASSWORD
        )
        cur = conn.cursor()

        # COPY command
        with open(tmpfile_path, 'r') as f:
            copy_sql = sql.SQL(
                "COPY {}.{} FROM stdin WITH CSV HEADER DELIMITER ','"
            ).format(sql.Identifier(schema), sql.Identifier(table_name))
            cur.copy_expert(copy_sql, f)

        conn.commit()
        print(f"DataFrame copied to table '{schema}.{table_name}' successfully.")
    finally:
        cur.close()
        conn.close()
        tunnel.stop()
        print("Connection closed and tunnel stopped.")
        os.remove(tmpfile_path)
        print(f"Temporary file {tmpfile_path} deleted.")    
        
def fetch_data_as_dataframe(query):
    try:
        tunnel, connection = connect_and_tunnel()
        df = pd.read_sql(query, connection)
        print("Data fetched successfully.")
        return df
    finally:
        connection.close()
        tunnel.stop()
        print("Connection closed and tunnel stopped.")

def execute_sql(command):
    try:
        tunnel, connection = connect_and_tunnel()
        cursor = connection.cursor()
        cursor.execute(command)
        connection.commit()
        print("Command executed successfully.")
    except Exception as e:
        print(f"Error executing command: {e}")
    finally:
        cursor.close()
        connection.close()
        tunnel.stop()
        print("Connection closed and tunnel stopped.")  

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

## Function for grab, read, and execute data in Cockpit
# Cockpit SSH and MySQL connection settings
ssh_host = '10.0.144.159'         # SSH host
ssh_port = 22                     # SSH port (default is 22)
ssh_user = 'dinar'    # SSH username
ssh_password = 'BI_SND2025'  # SSH password (optional if using key)
ssh_key_path = None               # Path to SSH private key if used

mysql_host = 'localhost'          # MySQL host (use 'localhost' when tunneling)
mysql_port = 3306                 # MySQL port
mysql_user = 'reporting' # MySQL username
mysql_password = 'admin1234' # MySQL password
mysql_database = 'cockpit'  # MySQL database name 

import random
def cockpit_connect_and_tunnel(
    base_port=3308, retries=5
):
    """
    Establish SSH tunnel and connect to MySQL with retry logic.
    Each retry will use a different local port starting from base_port.
    """

    attempt = 0
    while attempt < retries:
        local_port = base_port + attempt  # e.g., 3308, 3309, 3310, ...
        tunnel = SSHTunnelForwarder(
            (ssh_host, ssh_port),
            ssh_username=ssh_user,
            ssh_password=ssh_password if ssh_key_path is None else None,
            ssh_pkey=ssh_key_path,
            remote_bind_address=(mysql_host, mysql_port),
            local_bind_address=("127.0.0.1", local_port),
        )

        try:
            tunnel.start()
            print(f"SSH TunnelIM3  established on port {local_port}")

            # Create SQLAlchemy engine
            engine = create_engine(
                f"mysql+pymysql://{mysql_user}:{mysql_password}@127.0.0.1:{local_port}/{mysql_database}"
            )
            connection = engine.connect()
            print("MySQL connection established")
            return tunnel, connection

        except Exception as e:
            print(f"Attempt {attempt+1} failed on port {local_port}: {e}")
            if tunnel.is_active:
                tunnel.stop()

            attempt += 1
            if attempt < retries:
                time.sleep(2)  # wait before retry
                print("Retrying...")
            else:
                raise RuntimeError(f"All {retries} attempts failed.") from e

def cockpit_get_df(query, params=None):
    try:
        tunnel, connection = cockpit_connect_and_tunnel()
        df = pd.read_sql(query, connection)
        print("Data fetched successfully.")
        return df
    finally:
        connection.close()
        tunnel.stop()
        print("Connection closed and tunnel stopped.")

def cockpit_execute_sql(command, params=None):
    try:
        tunnel, connection = cockpit_connect_and_tunnel()
        # Use parameterized query to prevent formatting issues
        if params is None:
            result = connection.execute(text(command))
        else:
            result = connection.execute(text(command), params)
        connection.connection.commit()
        print(f"Command executed successfully. Rows affected: {result.rowcount}") 
    except Exception as e:
        print(f"Error executing command: {e}")
    finally:
        connection.close()
        tunnel.stop()
        print("Connection closed and tunnel stopped.")

def get_yearmonths_in_quarter(dt_id):
    # Convert dt_id string to a datetime object
    dt_obj = dt.datetime.strptime(dt_id, "%Y%m%d")
    
    # Determine the current quarter
    month = dt_obj.month
    year = dt_obj.year
    
    # Calculate start month of the quarter
    quarter_start_month = 3 * ((month - 1) // 3) + 1
    
    # Generate yearmonths in the quarter
    yearmonths = []
    for i in range(3):
        m = quarter_start_month + i
        ym = dt.date(year, m, 1).strftime("%Y%m")
        yearmonths.append(ym)
    
    return yearmonths

@op
def tri_revenue_store_cc():
    os.system(f'''rclone copy "dsn:retail/champion_club/target_retail_revenue_3id.xlsx" /data/retail/''')
    df_tgt = pd.read_excel(r'/data/retail/target_retail_revenue_3id.xlsx', 
                    sheet_name='tgt',engine="openpyxl")
    df_tgt[df_tgt.store_code=='JKT-WIC-05']
    df_tgt=df_tgt[df_tgt['periode']==int(year_month)]
    df_tgt[df_tgt.store_name.str.contains('Kuta')]
    df_tgt=df_tgt[(df_tgt['revenue_target'].notna()) & (df_tgt['revenue_target'] != 0)]
    df_cash=pd.read_csv(f"/data/retail/_3ID_Revenue_union_3_table_{year_month}.csv")
    df_cash['mth_id']=year_month
    df_cash=df_cash.groupby(['mth_id','dealer_code']).agg(revenue_cash_in=('total_amount_inc_ppn','sum')).reset_index()
    df_cash[df_cash.dealer_code.str.contains('DPS')]
    df_simrepl=pd.read_csv(f"/data/retail/dm_3id_simcard_replacement_revenue_{year_month}.csv")
    df_simrepl=df_simrepl.groupby(['rev_month','dealercode']).agg(revenue_services=('prepaid_rev','sum')).reset_index()
    df_cash.columns=['periode', 'store_code', 'revenue_cash_in']
    df_simrepl.columns=['periode', 'store_code', 'revenue_services']
    df_tgt['periode']=df_tgt['periode'].astype(str)
    df_cash['periode']=df_cash['periode'].astype(str)
    df_simrepl['periode']=df_simrepl['periode'].astype(str)
    df_rev=df_tgt.merge(df_cash, on=['store_code', 'periode'], how='left')
    df_rev=df_rev.merge(df_simrepl,on=['store_code', 'periode'], how='left')
    os.system(f'''rclone copy "dsn:retail/champion_club/dvm_mapping.xlsx" /data/retail/''')
    df_dvm = pd.read_excel('/data/retail/dvm_mapping.xlsx',engine="openpyxl") 
    df_cash_dvm=df_cash.merge(df_dvm, left_on='store_code', right_on='dvm_code', how='inner')
    df_cash_dvm=df_cash_dvm[['periode', 'dvm_code', 'store_code_y', 'revenue_cash_in']] 
    df_cash_dvm.columns=['periode', 'dvm_code', 'store_code', 'revenue_cash_in_dvm']
    df_simrepl_dvm=df_simrepl.merge(df_dvm, left_on='store_code', right_on='dvm_code', how='inner')
    df_simrepl_dvm=df_simrepl_dvm[['periode', 'dvm_code', 'store_code_y', 'revenue_services']] 
    df_simrepl_dvm.columns=['periode', 'dvm_code', 'store_code', 'revenue_services_dvm']
    df_rev=df_rev.merge(df_cash_dvm[['store_code', 'periode', 'revenue_cash_in_dvm']],on=['store_code', 'periode'], how='left') 
    df_rev=df_rev.merge(df_simrepl_dvm[['store_code', 'periode', 'revenue_services_dvm']],on=['store_code', 'periode'], how='left') 
    df_rev
    df_rev.fillna({
        'revenue_cash_in': 0,
        'revenue_services': 0,
        'revenue_cash_in_dvm': 0, 
        'revenue_services_dvm': 0
    }, inplace=True)
    df_rev['revenue_store']=df_rev['revenue_cash_in']+df_rev['revenue_services']+df_rev['revenue_cash_in_dvm']+df_rev['revenue_services_dvm']
    df_rev['revenue_ach']=(df_rev['revenue_store']/df_rev['revenue_target']).astype(float)
    df_rev['store_productivity']=df_rev['revenue_ach'].apply(lambda x: 1 if x >= 1 else 0)
    df_rev=df_rev[df_rev['type']!='DVM Stand alone'].copy() 
    df_rev.type.unique()
    df_rev['brand']='3ID'
    df_rev[df_rev.store_name.str.lower().str.contains('kuta')]
    df_rev[df_rev['circle']=='JAKARTA RAYA'].revenue_cash_in.sum()
    df_rev.to_csv(f"/data/retail/cc_revenue_store_3id_{year_month}.csv", 
            index=False)
    os.system(f'''rclone copy /data/retail/cc_revenue_store_3id_{year_month}.csv dsn:retail/kpi_retail/champion_club/''')
    os.system(f'''rclone copy dsn:retail/kpi_retail/champion_club/cc_revenue_store_3id_{year_month}.csv dsn:"Retail Performance Management - R100/champion_club/revenue_store"''') 
    
    df_rev.to_excel(f"/data/retail/revenue_3id_{year_month}.xlsx",index=False)
    os.system(f'''rclone copy /data/retail/revenue_retail_3id_{year_month}.xlsx dsn:retail/kpi_retail/''') 
    os.system(f'''rclone copy dsn:retail/kpi_retail/revenue_retail_3id_{year_month}.xlsx dsn:"Retail Performance Management - R100/revenue_retail_3id"''')
    status='Finished'
    return status


@op
def im3_revenue_store_cc(status):
    print(status)
    os.system(f'''rclone copy "dsn:retail/champion_club/target_retail_revenue_im3_v3.xlsx" /data/retail/''')
    df_tgt = pd.read_excel(r'/data/retail/target_retail_revenue_im3_v3.xlsx', 
                    sheet_name='tgt (revised)',engine="openpyxl")
    df_tgt=df_tgt[df_tgt['periode']==int(year_month)]
    df_tgt=df_tgt[(df_tgt['revenue_tgt'].notna()) & (df_tgt['revenue_tgt'] != 0)]
    print('Starting dump report daily GA')
    bq_project = "data-nationalslsdist-prd-986g"
    bq_dataset = "retail" 
    bq_table = "raw_im3_interaction_revenue"
    client = bigquery.Client(project=bq_project)
    # Your SQL query
    query = f"""
        SELECT 
        dt_id,
        activity_type,
        store_code,
        replace(ticket_type, '|', ' ') ticket_type,
        replace(issue_group, '|', ' ') issue_group,
        replace(issue_sub, '|', ' ') issue_sub,
        replace(issue_desc, '|', ' ') issue_desc,
        cnt,
        cnt_msisdn,
        invoice_amount 
        FROM `{bq_project}.{bq_dataset}.{bq_table}`
        where left(dt_id,6)=left('{dt_id}',6)
    """
    # Run query and return DataFrame
    df_cash = client.query(query).to_dataframe()
    df_cash['periode']=df_cash['dt_id'].str[:6]
    df_cash['invoice_amount']=df_cash['invoice_amount'].astype(float)
    df_cash.head(5)
    df_cash=df_cash.groupby(['periode','store_code']).agg(revenue_cash_in=('invoice_amount','sum')).reset_index()
    df_cash=df_cash[df_cash['periode']==year_month]
    df_simrepl=pd.read_csv(f"/data/retail/dm_im3_simcard_replacement_revenue_{year_month}.csv")
    df_simrepl=df_simrepl.groupby(['rev_month','store_code']).agg(revenue_services=('rev_30','sum')).reset_index()
    df_simrepl.columns=['periode', 'store_code', 'revenue_services']
    df_tgt['periode']=df_tgt['periode'].astype(str)
    df_cash['periode']=df_cash['periode'].astype(str)
    df_simrepl['periode']=df_simrepl['periode'].astype(str)
    df_tgt.columns=['store_code', 'store_name', 'type', 'region', 'circle', 'periode',
           'revenue_target']
    df_rev=df_tgt.merge(df_cash, on=['store_code', 'periode'], how='left')
    df_rev=df_rev.merge(df_simrepl,on=['store_code', 'periode'], how='left')
    df_rev.fillna({
        'revenue_cash_in': 0,
        'revenue_services': 0
    }, inplace=True)
    df_rev['revenue_cash_in_dvm']=0
    df_rev['revenue_services_dvm']=0
    df_rev['revenue_store']=df_rev['revenue_cash_in']+df_rev['revenue_services']+df_rev['revenue_cash_in_dvm']+df_rev['revenue_services_dvm']
    df_rev['revenue_ach']=(df_rev['revenue_store']/df_rev['revenue_target']).astype(float)
    df_rev['store_productivity']=df_rev['revenue_ach'].apply(lambda x: 1 if x >= 1 else 0)
    df_rev['brand']='IM3'
    # exclude dua gerai jaya yang sudah tidak beroperasi since august 2025
    df_rev=df_rev[~df_rev['store_code'].isin(['FCBE','JGLM'])]
    jaya = pd.read_excel('/home/acp/retail/champion_club/map_jaya.xlsx', engine='openpyxl')
    jaya.columns=['sc', 'c', 'r']
    df_rev=df_rev.merge(jaya, left_on='store_code', right_on='sc', how='left')
    df_rev['region']=df_rev['r'].fillna(df_rev['region'])
    df_rev
    df_rev.drop(columns=['sc', 'c', 'r'], inplace=True)
    df_rev.to_csv(f"/data/retail/cc_revenue_store_im3_{year_month}.csv", 
            index=False)
    os.system(f'''rclone copy /data/retail/cc_revenue_store_im3_{year_month}.csv dsn:retail/kpi_retail/champion_club/''')
    os.system(f'''rclone copy dsn:retail/kpi_retail/champion_club/cc_revenue_store_im3_{year_month}.csv dsn:"Retail Performance Management - R100/champion_club/revenue_store"''')
    
    df_rev.to_excel(f"/data/retail/revenue_im3_{year_month}.xlsx",index=False)
    os.system(f'''rclone copy /data/retail/revenue_retail_im3_{year_month}.xlsx dsn:retail/kpi_retail/''') 
    os.system(f'''rclone copy dsn:retail/kpi_retail/revenue_retail_im3_{year_month}.xlsx dsn:"Retail Performance Management - R100/revenue_retail_im3"''')
    print(year_month)
    status='Finished'
    return status

@op
def myster_shopper_cc(status):
    print(status)

    ym_1 = pd.to_datetime(pd.Series(year_month), format="%Y%m") \
             .apply(lambda x: (x - pd.DateOffset(months=1)).strftime("%Y%m")) \
             .tolist()

    ym_abv=pd.to_datetime(pd.Series(ym_1, dtype=str), format="%Y%m").dt.strftime("%b %Y") 
    ym_abv=ym_abv[0]
    ym_abv
    os.system(f'''rclone copy dsn:"Data/PBI 3KIOSK - MITRA IM3/Mystery Shopper" dsn:retail --include Myshopp_*.xlsx''')
    os.system(f'''rclone copy dsn:retail /data/retail --include Myshopp_*.xlsx''')
    df_myshop=pd.read_excel(f'/data/retail/Myshopp_{ym_abv}.xlsx', engine='openpyxl')
    df_myshop.columns=['periode', 'store_name', 'store_code', 'channel', 'circle', 'region', 'score']
    df_myshop['mth_cal']=pd.to_datetime(df_myshop['periode'], format="%Y%m") \
             .apply(lambda x: (x + pd.DateOffset(months=1)).strftime("%Y%m")) \
             .tolist()
    df_myshop['brand']=df_myshop['channel'].apply(lambda x: '3ID' if str(x).lower()=='3store' else 'IM3')
    df_myshop['score']=pd.to_numeric(df_myshop['score'].replace('-', np.nan), errors='coerce')
    df_myshop['myshop_flag']=df_myshop['score'].apply(lambda x: 1 if x>=90 else 0)
    jaya = pd.read_excel('/home/acp/retail/champion_club/map_jaya.xlsx', engine='openpyxl')
    jaya.columns=['sc', 'c', 'r']
    df_myshop=df_myshop.merge(jaya, left_on='store_code', right_on='sc', how='left')
    df_myshop['region']=df_myshop['r'].fillna(df_myshop['region'])
    df_myshop.drop(columns=['sc', 'c', 'r'], inplace=True)
    df_myshop.to_csv(f"/data/retail/cc_myshop_{year_month}.csv", 
            index=False)
    os.system(f'''rclone copy /data/retail/cc_myshop_{year_month}.csv dsn:retail/kpi_retail/champion_club/''')
    os.system(f'''rclone copy dsn:retail/kpi_retail/champion_club/cc_myshop_{year_month}.csv dsn:"Retail Performance Management - R100/champion_club/mystery_shopper"''')
    status='Finished'
    return status

@op    
def tri_csat_cc(status):
    print(status)
    df_csat=pd.read_excel(f"/data/retail/3id_csat_agent_{year_month}.xlsx", engine='openpyxl')
    df_csat=df_csat[df_csat['channel']=='3Store']
    df_csat=df_csat.groupby(['mth_id', 'store_code','store_name','circle','region']).\
        agg({'responden_delivered':'sum', 'responden_feedback':'sum','happy':'sum'}).\
        reset_index()
    df_csat['responden_rate']=df_csat['responden_feedback'].astype(float)/df_csat['responden_delivered'].astype(float)
    df_csat['csat_score']=df_csat['happy'].astype(float)/df_csat['responden_feedback'].astype(float)
    df_csat['status']=df_csat.apply(lambda x: 'Valid' if x['responden_rate']>=0.03 else 'Not Valid',
                 axis=1)
    df_csat['brand']='3ID'
    df_csat['csat_flag']=df_csat.apply(lambda x: 1 if x['status']=='Valid' and x['csat_score']>=0.98 else 0,
                                     axis=1)
    df_csat.to_csv(f"/data/retail/cc_csat_3id_{year_month}.csv", 
            index=False)
    os.system(f'''rclone copy /data/retail/cc_csat_3id_{year_month}.csv dsn:retail/kpi_retail/champion_club/''')
    os.system(f'''rclone copy dsn:retail/kpi_retail/champion_club/cc_csat_3id_{year_month}.csv dsn:"Retail Performance Management - R100/champion_club/csat"''')
    status = 'Finished'
    return status

@op
def im3_csat_cc(status):
    print(status)
    
    ym_abv=pd.to_datetime(pd.Series(year_month, dtype=str), format="%Y%m").dt.strftime("%b'%Y") 
    ym_abv=ym_abv[0]
    os.system(f'''rclone copy dsn:"Data/PBI 3KIOSK - MITRA IM3/CSAT" dsn:retail --include "CSAT-{ym_abv}.xlsx"''')
    os.system(f'''rclone copy dsn:retail /data/retail/ --include "CSAT-{ym_abv}.xlsx"''')
    df_csat=pd.read_excel(f"/data/retail/CSAT-{ym_abv}.xlsx", engine='openpyxl', usecols='A:O')
    df_csat[df_csat['store_code']=='FCTB']
    # Get the most frequent store_name for each store_code
    preferred_names = (
        df_csat.groupby('store_code')['store_name']
          .value_counts()
          .groupby(level=0)
          .head(1)
          .reset_index(name='count')
    )
    store_name_map = dict(zip(preferred_names['store_code'], preferred_names['store_name']))
    df_csat['store_name'] = df_csat['store_code'].map(store_name_map)
    df_csat[df_csat.store_code=='DPPD'].store_name.unique()
    df_csat['channel']=df_csat['channel'].str.upper()
    df_csat=df_csat[df_csat['channel']=='GERAI IM3']
    df_csat.columns=['mth_id','dt_id','store_code','agent_id','channel',
                     'store_name', 'dist_id', 'circle', 'region',
                     'brand', 'responden_delivered', 'responden_feedback', 
                     'happy', 'csat', 'responden_rate']
    df_csat=df_csat.groupby(['mth_id', 'store_code','store_name','circle','region']).\
        agg({'responden_delivered':'sum', 'responden_feedback':'sum','happy':'sum'}).\
        reset_index()
    df_csat['responden_rate']=df_csat['responden_feedback'].astype(float)/df_csat['responden_delivered'].astype(float)
    df_csat['csat_score']=df_csat['happy'].astype(float)/df_csat['responden_feedback'].astype(float)
    # df_csat['status']=df_csat.apply(lambda x: 'Valid' if (x['responden_rate']>=0.03 and x['mth_id']<=202504) else ('Valid' if (x['responden_rate']>=0.05 and x['mth_id']>=202505) else 'Not Valid'),
    #              axis=1)
    df_csat['status']=df_csat.apply(lambda x: 'Valid' if x['responden_rate']>=0.03 else 'Not Valid',
                 axis=1)
    df_csat['brand']='IM3'
    df_csat['mth_id']=df_csat['mth_id'].astype(int)
    df_csat['csat_flag']=df_csat.apply(lambda x: 1 if x['status']=='Valid' and x['csat_score']>=0.98 else 0,
                                     axis=1)


    # exclude manual
    df_csat=df_csat[(df_csat['store_code']!='MDAH')]
    df_csat.to_csv(f"/data/retail/cc_csat_im3_{year_month}.csv", 
            index=False)
    os.system(f'''rclone copy /data/retail/cc_csat_im3_{year_month}.csv dsn:retail/kpi_retail/champion_club/''')
    os.system(f'''rclone copy dsn:retail/kpi_retail/champion_club/cc_csat_im3_{year_month}.csv dsn:"Retail Performance Management - R100/champion_club/csat"''')
    status = 'Finished'
    return status

@op
def gads_platinum_cc(status):
    print(status)
    bq_project = "data-nationalslsdist-prd-986g"
    client = bigquery.Client(project=bq_project)
    query = f"""
        select 
            left('{dt_id}',6) periode,
            trim(a.store_code) store_code,
            upper(a.store_name) store_name,
            a.region,
            circle,
            status as `type`,
            coalesce(b.ga_only,0) ga_only
            from  `data-nationalslsdist-prd-986g`.retail.ref_store_mth as a
                left join ( 
                    select 
                        store_code_rev as store_code, 
                        count(distinct msisdn) as ga_only
                    from `data-nationalslsdist-prd-986g`.postpaid.raw_daily_ga
                    where left(activation_date,6)=left('{dt_id}',6)
                        and order_type in ('New Registration', 'Migration', 'Port in Migration')
                    group by 1
                ) as b
                on trim(a.store_code)=b.store_code
                where lower(a.status) like '%gerai%';
    """
    df_ga = client.query(query).to_dataframe()
 
    ym_abv=pd.to_datetime(pd.Series(year_month, dtype=str), format="%Y%m").dt.strftime("%b_%Y")
    ym_abv=ym_abv[0]
    os.system(f'''rclone copy dsn:"Data/Power BI Dashboard/Target GA" dsn:retail/ --include "Target_GA_{ym_abv}.xlsx"''')
    os.system(f'''rclone copy dsn:retail/ /data/retail --include "Target_GA_{ym_abv}.xlsx"''')
    df_tgt_ga=pd.read_excel(f"/data/retail/Target_GA_{ym_abv}.xlsx", engine='openpyxl', sheet_name='Sheet1', usecols='A:Z')
    df_tgt_ga.Date.unique()


    df_tgt_ga['periode']=pd.to_datetime(df_tgt_ga['Date']).dt.strftime('%Y%m')


    df_tgt_ga['periode']=df_tgt_ga['periode'].astype(str) 
    df_tgt_ga['Store Code Rev']=df_tgt_ga['Store Code Rev'].astype(str) 


    df_tgt_ga['periode'].unique()


    df_tgt_ga=df_tgt_ga.groupby(['periode', 'Store Code Rev']).agg(ga_target=('TOTAL GA','sum')).reset_index()
    df_tgt_ga.columns=['periode','store_code','ga_target']

    if int(year_month)>=202509:
        print('Started with GA Target from Retail')
        os.system(f'''rclone copy dsn:"retail/champion_club" /data/retail --include "target_retail_ga_im3.xlsx"''')
        tgt_new=pd.read_excel(f"/data/retail/target_retail_ga_im3.xlsx", engine='openpyxl', sheet_name='Sheet1')
        df_tgt_ga=df_tgt_ga[(~df_tgt_ga['store_code'].isin(tgt_new.store_code.unique().tolist())) & (~df_tgt_ga['store_code'].isin(tgt_new.mth_id.unique().tolist()))]
        tgt_new=tgt_new[['mth_id', 'store_code', 'target_ga']]
        tgt_new.columns=['periode', 'store_code', 'ga_target']
        tgt_new['periode']=tgt_new['periode'].astype(str)
        tgt_new=tgt_new[tgt_new['periode']==year_month]
        df_tgt_ga=pd.concat([df_tgt_ga, tgt_new])
    else:
        print('Not started with GA Target from Retail')


    df_ach=df_ga.merge(df_tgt_ga, on=['periode', 'store_code'], how='left')

    df_ach=df_ach[['store_code', 'store_name', 'type', 'region', 'circle', 'periode',
                   'ga_target', 'ga_only']]
    jaya = pd.read_excel('/home/acp/retail/champion_club/map_jaya.xlsx', engine='openpyxl')
    jaya.columns=['sc', 'c', 'r']
    df_ach=df_ach.merge(jaya, left_on='store_code', right_on='sc', how='left')
    df_ach['region']=df_ach['r'].fillna(df_ach['region'])
    df_ach.drop(columns=['sc', 'c', 'r'], inplace=True)

    df_ach.to_csv(f"/data/retail/cc_ga_platinum_{year_month}.csv", 
            index=False)
    os.system(f'''rclone copy /data/retail/cc_ga_platinum_{year_month}.csv dsn:retail/kpi_retail/champion_club/''')
    os.system(f'''rclone copy dsn:retail/kpi_retail/champion_club/cc_ga_platinum_{year_month}.csv dsn:"Retail Performance Management - R100/champion_club/ga_platinum"''')
    status='Finished'
    return status

@op
def im3_conversion_rate_cc(status):
    print(status)
    print(dt_id)


    bq_project = "data-nationalslsdist-prd-986g"
    client = bigquery.Client(project=bq_project)
    query=f'''
       with siebel_data as
        (
        select
        distinct
        format_date('%Y%m%d',a.dt_id) as dt_id,
        REGEXP_EXTRACT(a.creator_location, r'^(.*?)-') AS store_code,
        creator_login as creator_id,
        creator_name,
        a.msisdn
        from `data-dtp-prd-aa1a.stg.stg_siebel_dly_intrctn` as a
        where date(a.dt_id) between date(SUBSTR('{dt_id}',1,4) || '-' || SUBSTR('{dt_id}',5,2) || '-01') 
        and PARSE_DATE('%Y%m%d', '{dt_id}')
        and a.status='Closed'
        -- and format_date('%Y%m',a.dt_id)=left('{dt_id}',6)
        )
        ,ipos_data as
        (
        select
            distinct
            format_date('%Y%m%d',PARSE_TIMESTAMP('%d/%m/%Y %H:%M:%S', a.transaction_date)) as dt_id,
            organization_ref_code as store_code,
            a.username as creator_id,
            concat(a.username,'-',a.organization_name) creator_name,
            customer_msisdn as msisdn
        from `data-nationalslsdist-prd-986g`.retail.raw_ipos_nonps_trx as a
        where format_date('%Y%m',PARSE_TIMESTAMP('%d/%m/%Y %H:%M:%S', a.transaction_date))=left('{dt_id}',6)
        and status='Success'
        )
        , data_interactions as (
        select
            'siebel' as source,
            a.dt_id,
            a.store_code,
            a.creator_id,
            count(distinct a.msisdn) as interactions
        from siebel_data as a
        group by 1, 2, 3, 4
        union all
            select
            'ipos' as source,
            b.dt_id,
            b.store_code,
            b.creator_id,
            count(distinct b.msisdn) as interactions
        from (select
            x.*
        from ipos_data as x
        where concat(left(x.dt_id,6),x.store_code,x.msisdn) not in (select distinct concat(left(a.dt_id,6),a.store_code, a.msisdn) from siebel_data as a)
        )as b
        group by 1, 2, 3, 4),
        itrx as (
        select
            a.dt_id,
            a.store_code,
            a.creator_id,
            sum(interactions) as interactions
        from data_interactions as a
        group by 1, 2, 3
        )
        , rgu_ga as (
            select
                a.activation_date as dt_id,
                a.store_code_rev as store_code,
                a.nik_sales as creator_id,
                b.circle,
                b.region as region_circle,
                b.branch as area,
                b.branch as sales_area,
                upper(b.store_name) store_name,
                b.channel_group,
                count(distinct case when lower(a.order_type) in ('migration', 'new registration', 'port in migration') then a.msisdn end) as rgu_ga_only,
                count(distinct case when lower(a.order_type) in ('migration', 'change postpaid plan', 'new registration', 'port in migration') then a.msisdn end) as rgu_ga
            from `data-nationalslsdist-prd-986g`.postpaid.raw_daily_ga as a
            left join (
    		        select * from (
    					select 
    						* ,
    						row_number() over(partition by store_code order by updated_dt desc) rnk
    					from `data-nationalslsdist-prd-986g`.postpaid.ref_storelist_base
    					) as x where x.rnk=1
            	) as b
                on case when lower(a.agent_type) like '%outcall%' then upper(a.nik_sales) else upper(a.store_code_rev) end=upper(b.store_code)
            where 1=1
            and left(a.activation_date,6)=left('{dt_id}',6)
            and lower(a.agent_type) not like '%outcall%' 
            and a.nik_sales is not null and a.nik_sales <>'' and a.nik_sales <> '-'
            and (lower(b.channel_group) like '%gerai%' or lower(b.channel_group) like '%franchise%')
            group by 1, 2, 3, 4, 5, 6, 7, 8, 9
        )
        , final_result as (
        select
            a.dt_id,
            left(a.dt_id,6) as mth_id,
            a.circle,
            a.region_circle,
            a.area,
            a.sales_area,
            a.store_name,
            a.channel_group,
            a.store_code,
            a.creator_id,
            a.rgu_ga,
            a.rgu_ga_only,
        coalesce(b.interactions,0) unique_visitors
        from rgu_ga as a
        left join itrx as b
        on a.store_code=b.store_code and a.dt_id=b.dt_id and a.creator_id = b.creator_id
        )
        select
            a.mth_id,
            a.circle,
            a.region_circle,
            a.store_name,
            a.store_code,
            a.creator_id as agent_id, 
            null as agent_category,
            sum(a.rgu_ga_only) as ga,
            sum(unique_visitors) as visitor,
            (SAFE_DIVIDE(sum(a.rgu_ga_only),sum(unique_visitors))) as conversion_rate
        from final_result as a
        group by 1, 2, 3, 4, 5, 6, 7
        having sum(a.rgu_ga_only)>0;
    '''
    df_ga = client.query(query).to_dataframe()
    # df_ga=hdp_get_df(query)
    df_ga


    df_ga.agent_category.unique()


    df_ga['ga_store']=df_ga['ga']
    df_ga['visitor_store']=df_ga['visitor']
    df_ga['ga_dvm']=0
    df_ga['visitor_dvm']=0


    df_ga=df_ga[['mth_id', 'circle', 'region_circle', 'store_name', 'store_code',
            'agent_id', 'agent_category',
            'ga_dvm', 'visitor_dvm', 'ga_store',
            'visitor_store', 'ga', 'visitor', 'conversion_rate']]


    df_ga['brand']='IM3'


    df_ga['agent_productivity']=df_ga['conversion_rate'].apply(lambda x: 1 if x>=0.1 else 0)


    df_ga.to_csv(f"/data/retail/cc_conversion_rate_im3_{year_month}.csv", 
            index=False)
    os.system(f'''rclone copy /data/retail/cc_conversion_rate_im3_{year_month}.csv dsn:retail/kpi_retail/champion_club/''')
    os.system(f'''rclone copy dsn:retail/kpi_retail/champion_club/cc_conversion_rate_im3_{year_month}.csv dsn:"Retail Performance Management - R100/champion_club/conversion_rate"''')
    status ='finished'
    return status

@op
def tri_conversion_rate_cc(status):
    print(status)
    
    query=f'''
    select
    	a.mth_id,
        d.circle,
        d.region as region_circle,
        d.store_name,
    	a.dealer_code as store_code,
    	a.agent_id,
        ma.title as agent_category,
    	sum(coalesce(a.gross_add,0)) as ga, 
    	sum(coalesce((b.visitor+c.visitor),e.visitor)) as visitor,
        sum(e.visitor) as invoice,
    	sum(coalesce(a.gross_add,0))/sum(coalesce((b.visitor+c.visitor),e.visitor)) as conversion_rate
    from 
    (
            select
                DATE_FORMAT(buv.salesdate, "%Y%m") AS mth_id 
                , DATE_FORMAT(buv.salesdate, "%Y%m%d") AS dt_id
                -- , buv.agent_id AS agent_id
                , buv.AgentName AS agent_id
                , buv.DealerCode AS dealer_code
                , SUM(buv.Quantity) AS gross_add
            from cockpit.raw_poss buv
            where (lower(buv.ProductName) like 'sp %'
                or lower(buv.ProductName) like 'perdana %'
                or lower(buv.ProductName) like 'elite%')
                and buv.ItemCode not like 'SP-PR%'
                and buv.ItemCode not like 'SP-RPLC%'
                and DATE_FORMAT(buv.SalesDate, '%Y%m') = '{year_month}'
            group by 1, 2, 3, 4
    ) as a
    left join (
        select mth_id, dt_id, agent_id, dealercode, sum(visitor) as visitor 
            from (
            select
                DATE_FORMAT(qms.DateTimeCustQue, '%Y%m') as mth_id,
                DATE_FORMAT(qms.DateTimeCustQue, '%Y%m%d') as dt_id,
                qms.AgentName as agent_id,
                ma.dealercode, 
                count(distinct Msisdn) as visitor
            FROM cockpit.raw_qms_detil as qms
                left join cockpit.master_agent ma
                    on qms.AgentName = ma.siebel_id
                WHERE DATE_FORMAT(qms.DateTimeCustQue, '%Y%m') = '{year_month}'
                -- WHERE DATE_FORMAT(qms.DateTimeCustQue, '%Y%m')='202505'
            group by 1, 2, 3, 4
            ) as x
            group by 1, 2, 3, 4
    ) as b
    on a.agent_id=b.agent_id and a.mth_id=b.mth_id and a.dt_id=b.dt_id
    left join (
        select mth_id, agent_id, dt_id, dealercode, sum(visitor) visitor from (
            select mth_id, dt_id, agent_id, dealercode, count(distinct user_contact) visitor from(
            select 
                distinct
                DATE_FORMAT(a.opened_time, '%Y%m') as mth_id
                , DATE_FORMAT(a.opened_time, '%Y%m%d') as dt_id
                , a.opened_by as agent_id
                , ma.dealercode
                , a.user_contact
            from cockpit_archieve.cstools_raw_tickets as a
                left join cockpit.master_agent ma
                    on a.opened_by = ma.siebel_id
                left join (
                    select
                        distinct
                        DATE_FORMAT(qms.DateTimeCustQue, '%Y%m') as mth_id,
                        DATE_FORMAT(qms.DateTimeCustQue, '%Y%m%d') as dt_id,
                        qms.AgentName as agent_id,
                        ma.dealercode,
                        qms.Msisdn as visitor
                    FROM cockpit.raw_qms_detil as qms
                    left join cockpit.master_agent ma
                        on qms.AgentName = ma.siebel_id
                        WHERE DATE_FORMAT(qms.DateTimeCustQue, '%Y%m') = '{year_month}'
                        -- WHERE DATE_FORMAT(qms.DateTimeCustQue, '%Y%m')='202505'
                    ) as b
                on a.user_contact=b.visitor and DATE_FORMAT(a.opened_time, '%Y%m%d')=b.dt_id and ma.dealercode=b.dealercode
            where left(replace(substring(opened_time, 1, 10),'-',''),6) = '{year_month}'
            -- where DATE_FORMAT(a.opened_time, '%Y%m')='202505'
            and a.source in ('3Store')
            and b.visitor is null
            ) x
            group by 1, 2, 3, 4
            ) z
            group by 1, 2, 3, 4
    ) as c
        on a.agent_id=c.agent_id and a.mth_id=c.mth_id and a.dt_id=c.dt_id
    left join cockpit.master_pbi_store_ref as d
        on a.dealer_code=d.store_code
    left join (
        select
            DATE_FORMAT(buv.salesdate, "%Y%m") AS mth_id
            , DATE_FORMAT(buv.salesdate, "%Y%m%d") AS dt_id
            -- , buv.agent_id AS agent_id
            , buv.AgentName AS agent_id
            , buv.DealerCode AS dealer_code
            , count(distinct InvoiceNumber) AS visitor
        from cockpit.raw_poss buv
        where 1=1
            and DATE_FORMAT(buv.SalesDate, '%Y%m') = '{year_month}'
        group by 1, 2, 3, 4
    ) as e
        on a.agent_id=e.agent_id and a.mth_id=e.mth_id and a.dealer_code=e.dealer_code
            and a.dt_id=e.dt_id
    left join cockpit.master_agent ma
         on a.agent_id = ma.siebel_id
    -- where a.agent_id is not null and a.agent_id <> ''
    group by 1, 2, 3, 4, 5, 6, 7
    '''
    df_ga=cockpit_get_df(query)
    df_ga[df_ga['store_code']=='MND-WIC-01']


    query=f'''
    select
        DATE_FORMAT(T1.date_trx, "%Y%m") as mth_id, 
        T1.terminal_code, 
        T1.terminal_name, 
        count(distinct case when T1.product_code in ('THREEPERDANA_CARD', 'THREEPERDANAPYON_CARD') then T1.customerid end) as ga, 
        count(distinct T1.customerid) as visitor
    FROM cockpit_archieve.raw_3db_trx T1
    where 1=1 
    and T1.result = 'success'
    and DATE_FORMAT(T1.date_trx, "%Y%m")='{year_month}'
    group by 1, 2, 3;
    '''
    df_ga_dvm=cockpit_get_df(query)
    df_ga_dvm


    os.system(f'''rclone copy "dsn:retail/champion_club/dvm_mapping.xlsx" /data/retail/''')
    df_dvm = pd.read_excel('/data/retail/dvm_mapping.xlsx',engine="openpyxl") 
    df_dvm


    df_ga_dvm=df_ga_dvm.merge(df_dvm, left_on='terminal_code', right_on='dvm_code', how='left')


    df_count=df_ga.groupby(['mth_id', 'store_code']).agg(agent_count=('agent_id', 'nunique')).reset_index()


    df_count[df_count.store_code=='DPS-WIC-01']


    df_ga_dvm=df_ga_dvm.merge(df_count, on=['mth_id', 'store_code'], how='left')

    df_ga_dvm['ga_dvm']=df_ga_dvm['ga']
    df_ga_dvm['visitor_dvm']=df_ga_dvm['visitor']


    df_ga_dvm=df_ga_dvm[['mth_id', 'store_code', 'ga_dvm', 'visitor_dvm']]


    df_ga=df_ga.merge(df_ga_dvm, on=['mth_id', 'store_code'], how='left')


    def distribute_vending_agents(agent_df, vending_total):
        agent_df = agent_df.copy()
        total_ach = agent_df["value"].sum()
        
        if total_ach == 0 or vending_total == 0:
            agent_df["dvm_alloc"] = 0
            return agent_df
        
        # Ideal (with decimals)
        agent_df["ideal"] = agent_df["value"] / total_ach * vending_total
        
        # Floor to integer
        agent_df["base"] = np.floor(agent_df["ideal"]).astype(int)
        
        # Calculate remainder
        remainder = int(round(vending_total - agent_df["base"].sum()))
        agent_df["frac"] = agent_df["ideal"] - agent_df["base"]
        
        # Distribute remainder to highest fractional parts
        agent_df = agent_df.sort_values("frac", ascending=False)
        agent_df["extra"] = 0
        agent_df.iloc[:remainder, agent_df.columns.get_loc("extra")] = 1
        
        agent_df["dvm_alloc"] = agent_df["base"] + agent_df["extra"]
        return agent_df.sort_index()


    df_ga['value']=df_ga['ga']
    df_ga['value_dvm']=df_ga['ga_dvm']
    df_ga = (
        df_ga.groupby("store_code", group_keys=False)
              .apply(lambda g: distribute_vending_agents(g, g["value_dvm"].iloc[0] if pd.notna(g["value_dvm"].iloc[0]) else 0))
    )
    df_ga['ga_dvm']=df_ga['dvm_alloc']


    df_ga['value']=df_ga['visitor']
    df_ga['value_dvm']=df_ga['visitor_dvm']
    df_ga = (
        df_ga.groupby("store_code", group_keys=False)
              .apply(lambda g: distribute_vending_agents(g, g["value_dvm"].iloc[0] if pd.notna(g["value_dvm"].iloc[0]) else 0))
    )
    df_ga['visitor_dvm']=df_ga['dvm_alloc']


    df_ga['ga_store']=df_ga['ga']
    df_ga['visitor_store']=df_ga['visitor']
    df_ga['ga']=df_ga['ga_store']+df_ga['ga_dvm'].fillna(0)
    df_ga['visitor']=df_ga['visitor_store']+df_ga['visitor_dvm'].fillna(0)


    df_ga['conversion_rate']=df_ga['ga']/df_ga['visitor']
    df_ga


    df_ga=df_ga[['mth_id', 'circle', 'region_circle', 'store_name', 'store_code',
            'agent_id', 'agent_category', 'invoice',
            'ga_dvm', 'visitor_dvm', 'ga_store',
            'visitor_store', 'ga', 'visitor', 'conversion_rate']]


    df_ga[df_ga['store_code']=='MDN-WIC-02']


    df_ga.drop('invoice', axis=1, inplace=True)


    df_ga['brand']='3ID'


    df_ga['agent_productivity']=df_ga['conversion_rate'].apply(lambda x: 1 if x>=0.1 else 0)


    df_ga[df_ga['store_code']=='DPS-WIC-01']





    df_ga.to_csv(f"/data/retail/cc_conversion_rate_3id_{year_month}.csv", 
            index=False)
    os.system(f'''rclone copy /data/retail/cc_conversion_rate_3id_{year_month}.csv dsn:retail/kpi_retail/champion_club/''')
    os.system(f'''rclone copy dsn:retail/kpi_retail/champion_club/cc_conversion_rate_3id_{year_month}.csv dsn:"Retail Performance Management - R100/champion_club/conversion_rate"''')
    status = 'Finished'
    return status

@op
def cc_conversion_rate():
    print('Start Executing Conversion Rate') 
    filename = '/data/data_automation_bai/data_automation_scheduling/scripts/retail/cc_conversion_rate.sql'
    fd = open(filename, 'r')
    sql_file = fd.read() 
    sql_file=sql_file.format(**{"year_month": year_month, 
                                "dt_id": dt_id
                                })
    fd.close() 
    query = sql_file.split(';')
    project_id = "data-nationalslsdist-prd-986g"
    client = bigquery.Client(project=project_id)
    df = client.query(query[0]).to_dataframe()
    df.to_csv(f"/data/retail/cc_conversion_rate_{year_month}.csv", 
                index=False)
    os.system(f'''rclone copy /data/retail/cc_conversion_rate_{year_month}.csv dsn:retail/kpi_retail/champion_club/''')
    os.system(f'''rclone copy dsn:retail/kpi_retail/champion_club/cc_conversion_rate_{year_month}.csv dsn:"Retail Performance Management - R100/champion_club/conversion_rate"''')
    status = 'Finished'
    return status

@op
def cc_revenue_store(status):
    print(status)
    print('Start Revenue Store') 
    filename = '/data/data_automation_bai/data_automation_scheduling/scripts/retail/cc_revenue_store.sql'
    fd = open(filename, 'r')
    sql_file = fd.read() 
    sql_file=sql_file.format(**{"year_month": year_month, 
                                "dt_id": dt_id
                                })
    fd.close() 
    query = sql_file.split(';')
    project_id = "data-nationalslsdist-prd-986g"
    client = bigquery.Client(project=project_id)
    df = client.query(query[0]).to_dataframe()
    df.to_csv(f"/data/retail/cc_revenue_store_{year_month}.csv", 
                index=False)
    os.system(f'''rclone copy /data/retail/cc_revenue_store_{year_month}.csv dsn:retail/kpi_retail/champion_club/''')
    os.system(f'''rclone copy dsn:retail/kpi_retail/champion_club/cc_revenue_store_{year_month}.csv dsn:"Retail Performance Management - R100/champion_club/revenue_store"''')
    status = 'Finished'
    return status

@op
def cc_ga_platinum(status):
    print(status)
    print('Start GA Platinum') 
    filename = '/data/data_automation_bai/data_automation_scheduling/scripts/retail/cc_ga_platinum.sql'
    fd = open(filename, 'r')
    sql_file = fd.read() 
    sql_file=sql_file.format(**{"year_month": year_month, 
                                "dt_id": dt_id
                                })
    fd.close() 
    query = sql_file.split(';')
    project_id = "data-nationalslsdist-prd-986g"
    client = bigquery.Client(project=project_id)
    df = client.query(query[0]).to_dataframe()
    df.to_csv(f"/data/retail/cc_ga_platinum_{year_month}.csv", 
                index=False)
    os.system(f'''rclone copy /data/retail/cc_ga_platinum_{year_month}.csv dsn:retail/kpi_retail/champion_club/''')
    os.system(f'''rclone copy dsn:retail/kpi_retail/champion_club/cc_ga_platinum_{year_month}.csv dsn:"Retail Performance Management - R100/champion_club/ga_platinum"''')
    status = 'Finished'
    return status

@op
def cc_csat(status):
    print(status)
    print('Start CSAT') 
    filename = '/data/data_automation_bai/data_automation_scheduling/scripts/retail/cc_csat.sql'
    fd = open(filename, 'r')
    sql_file = fd.read() 
    sql_file=sql_file.format(**{"year_month": year_month, 
                                "dt_id": dt_id
                                })
    fd.close() 
    query = sql_file.split(';')
    project_id = "data-nationalslsdist-prd-986g"
    client = bigquery.Client(project=project_id)
    df = client.query(query[0]).to_dataframe()
    df.to_csv(f"/data/retail/cc_csat_{year_month}.csv", 
                index=False)
    os.system(f'''rclone copy /data/retail/cc_csat_{year_month}.csv dsn:retail/kpi_retail/champion_club/''')
    os.system(f'''rclone copy dsn:retail/kpi_retail/champion_club/cc_csat_{year_month}.csv dsn:"Retail Performance Management - R100/champion_club/csat"''')
    status = 'Finished'
    return status

@op
def cc_myshop(status):
    print(status)
    print('Start Mystery Shopper') 
    filename = '/data/data_automation_bai/data_automation_scheduling/scripts/retail/cc_myshop.sql'
    fd = open(filename, 'r')
    sql_file = fd.read() 
    sql_file=sql_file.format(**{"year_month": year_month, 
                                "dt_id": dt_id
                                })
    fd.close() 
    query = sql_file.split(';')
    project_id = "data-nationalslsdist-prd-986g"
    client = bigquery.Client(project=project_id)
    df = client.query(query[0]).to_dataframe()
    df.to_csv(f"/data/retail/cc_myshop_{year_month}.csv", 
                index=False)
    os.system(f'''rclone copy /data/retail/cc_myshop_{year_month}.csv dsn:retail/kpi_retail/champion_club/''')
    os.system(f'''rclone copy dsn:retail/kpi_retail/champion_club/cc_myshop_{year_month}.csv dsn:"Retail Performance Management - R100/champion_club/mystery_shopper"''')
    status = 'Finished'
    return status

@graph
def retail_cc():
    # t0=tri_revenue_store_cc()
    # t1=tri_csat_cc(t0)
    # t2=tri_conversion_rate_cc(t1)
    # t3=im3_revenue_store_cc(t2)
    # t4=im3_conversion_rate_cc(t3)
    # t5=gads_platinum_cc(t4)
    # t6=im3_csat_cc(t5)
    # t7=myster_shopper_cc(t6)
    t0=cc_conversion_rate()
    t1=cc_revenue_store(t0)
    t2=cc_ga_platinum(t1)
    t3=cc_csat(t2)
    t4=cc_myshop(t3)




