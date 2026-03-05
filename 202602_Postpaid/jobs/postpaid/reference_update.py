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
from dateutil.relativedelta import relativedelta 
from google.cloud import bigquery
from google.auth.transport.requests import Request
from google_auth_oauthlib.flow import InstalledAppFlow
from google.oauth2.credentials import Credentials
from google.cloud.bigquery import SchemaField
from openpyxl import load_workbook
from openpyxl.utils import get_column_letter
from openpyxl.styles import Protection

# Get data time
year_month=dt.datetime.today().strftime('%Y%m')
dt_id=dt.datetime.today()  

# Rerun manual
# year_month="202506"
# dt_id ="20250630"

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
ssh_password = '@AIengineer2503'  # SSH password (optional if using key)
ssh_key_path = None               # Path to SSH private key if used

mysql_host = 'localhost'          # MySQL host (use 'localhost' when tunneling)
mysql_port = 3306                 # MySQL port
mysql_user = 'reporting' # MySQL username
mysql_password = 'admin1234' # MySQL password
mysql_database = 'cockpit'  # MySQL database name 

def cockpit_connect_and_tunnel():
    # Establish SSH tunnel
    tunnel = SSHTunnelForwarder(
        (ssh_host, ssh_port),
        ssh_username=ssh_user,
        ssh_password=ssh_password if ssh_key_path is None else None,
        ssh_pkey=ssh_key_path,
        remote_bind_address=(mysql_host, mysql_port),
        local_bind_address=('127.0.0.1', 3308)  # Port forwarding to local port 3307
    )
    try: 
        tunnel.start()
        print("SSH Tunnel established on port 3308")
        # Connect to MySQL through SQLAlchemy
        engine = create_engine(
            f"mysql+pymysql://{mysql_user}:{mysql_password}@127.0.0.1:3308/{mysql_database}"
        )
        connection = engine.connect()
        print("MySQL connection established")
        return tunnel, connection

    except Exception as e:
        if tunnel.is_active:
            tunnel.stop()
        raise e   

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
        
def replace_if_keyword(val):
    if pd.notnull(val) and isinstance(val, str):
        if any(keyword in val.lower() for keyword in ['closed', 'tutup', 'tidak buka']):
            return datetime.now().strftime('%Y%m%d')
    try:
        return pd.to_datetime(val).strftime('%Y%m%d')
    except:
        return val  # atau np.nan jika ingin kosong

@op
def copy_files():
    os.system(f'''rclone copy dsn:"Retail Performance Management - R100/reference_postpaid/JAKARTA RAYA" dsn:postpaid --include "jakarta_raya_postpaid_mapping.xlsx"''')
    os.system(f'''rclone copy dsn:postpaid /data/postpaid --include "jakarta_raya_postpaid_mapping.xlsx"''')

    os.system(f'''rclone copy dsn:"Retail Performance Management - R100/reference_postpaid/JAVA" dsn:postpaid --include "java_postpaid_mapping.xlsx"''')
    os.system(f'''rclone copy dsn:postpaid /data/postpaid --include "java_postpaid_mapping.xlsx"''')

    os.system(f'''rclone copy dsn:"Retail Performance Management - R100/reference_postpaid/KALISUMAPA" dsn:postpaid --include "kalisumapa_postpaid_mapping.xlsx"''')
    os.system(f'''rclone copy dsn:postpaid /data/postpaid --include "kalisumapa_postpaid_mapping.xlsx"''')

    os.system(f'''rclone copy dsn:"Retail Performance Management - R100/reference_postpaid/SUMATERA" dsn:postpaid --include "sumatera_postpaid_mapping.xlsx"''')
    os.system(f'''rclone copy dsn:postpaid /data/postpaid --include "sumatera_postpaid_mapping.xlsx"''')

    os.system(f'''rclone copy dsn:"Retail Performance Management - R100/reference_postpaid/NATIONAL" dsn:postpaid --include "others_partner.xlsx"''')
    os.system(f'''rclone copy dsn:postpaid /data/postpaid --include "others_partner.xlsx"''')

    return "copy file success"

@op
def update_storelist(last_status):
    print(last_status)
    print('Update Storelist Mapping Started')
    all_dfs=[]
    list_file = ['jakarta_raya_postpaid_mapping.xlsx', 'java_postpaid_mapping.xlsx',
                'kalisumapa_postpaid_mapping.xlsx', 'sumatera_postpaid_mapping.xlsx', 'others_partner.xlsx']
    # for circle in list_file:
    #     print(circle)
    #     df_circle=pd.read_excel(f'/data/postpaid/{circle}', engine='openpyxl',
    #                             dtype=str, usecols='A:M', sheet_name='Storelist')
    #     all_dfs.append(df_circle)

    for circle in list_file:
        print(circle)
        df_circle=pd.read_excel(f'/data/postpaid/{circle}', engine='openpyxl',
                                dtype=str, usecols='A:M', sheet_name='Storelist', 
                                skiprows=1, header=None, names=[
                                                        'registered_date',
                                                        'closed_date',
                                                        'store_code',
                                                        'store_name',
                                                        'branch',
                                                        'region',
                                                        'circle',
                                                        'channel_group',
                                                        'channel_detail',
                                                        'longtitude',
                                                        'latitude',
                                                        'rce_nik',
                                                        'rce'
                                                    ])
        print(len(df_circle.columns))
        print(df_circle.columns)
        all_dfs.append(df_circle)
    
    print('finish reading all circle file')
    df_store=pd.concat(all_dfs, ignore_index=True)
    # df_store.columns=[
    #     'registered_date',
    #     'closed_date',
    #     'store_code',
    #     'store_name',
    #     'branch',
    #     'region',
    #     'circle',
    #     'channel_group',
    #     'channel_detail',
    #     'longtitude',
    #     'latitude',
    #     'rce_nik',
    #     'rce'
    # ]
    df_store['mth_id']=year_month
    df_store['updated_dt']=dt_id
    df_store['registered_date']=pd.to_datetime(df_store['registered_date']).dt.strftime('%Y%m%d')
    #df_store['closed_date']=pd.to_datetime(df_store['closed_date']).dt.strftime('%Y%m%d')
    df_store['closed_date'] = df_store['closed_date'].apply(replace_if_keyword)

    df_store.drop_duplicates(inplace=True)
    df=df_store.copy()
    bq_project = "data-nationalslsdist-prd-986g"
    bq_dataset = "postpaid" 
    bq_table = "ref_storelist_base"
    client = bigquery.Client(project=bq_project)
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
    last_status="Update storelist mapping success"
    print(last_status)
    #return last_status, df_store
    return df_store

@op
def update_is(df_last):
    print(df_last.head(1))
    print("Update IS mapping started")
    all_dfs=[]
    list_file = ['jakarta_raya_postpaid_mapping.xlsx', 'java_postpaid_mapping.xlsx',
                'kalisumapa_postpaid_mapping.xlsx', 'sumatera_postpaid_mapping.xlsx']
    # for circle in list_file:
    #     df_circle=pd.read_excel(f'/data/postpaid/{circle}', engine='openpyxl',
    #                             dtype=str, usecols='A:M', sheet_name='IS')
    #     all_dfs.append(df_circle)

    for circle in list_file:
        print(circle)
        df_circle=pd.read_excel(f'/data/postpaid/{circle}', engine='openpyxl',
                                dtype=str, usecols='A:N', sheet_name='IS', header=None, names=[
                                    'rce_nik',
                                    'rce_name',
                                    'postpaid_officer_nik',
                                    'postpaid_officer_name',
                                    'hopr_nik',
                                    'hopr_name',
                                    'hor_nik',
                                    'hor_name',
                                    'hopc_nik',
                                    'hopc_name',
                                    'region',
                                    'circle',
                                    'kpi_eligible', 
                                    'rce_title'
                                    ])
        all_dfs.append(df_circle)
    df_is = pd.concat(all_dfs, ignore_index=True)
    df_is=df_is[~df_is['rce_nik'].isin(['RCE NIK'])]
    # df_is.columns=[
    # 'rce_nik',
    # 'rce_name',
    # 'postpaid_officer_nik',
    # 'postpaid_officer_name',
    # 'hopr_nik',
    # 'hopr_name',
    # 'hor_nik',
    # 'hor_name',
    # 'hopc_nik',
    # 'hopc_name',
    # 'region',
    # 'circle',
    # 'kpi_eligible'
    # ]
    df_is=df_is.dropna(subset=['rce_nik', 'rce_name'], how='all')
    df_is['mth_id']=year_month
    df_is['updated_dt']=dt_id
    df_is = df_is[[
        'rce_nik',
        'rce_name',
        'postpaid_officer_nik',
        'postpaid_officer_name',
        'hopr_nik',
        'hopr_name',
        'hor_nik',
        'hor_name',
        'hopc_nik',
        'hopc_name',
        'region',
        'circle',
        'kpi_eligible',
        'mth_id',
        'updated_dt', 
        'rce_title'
    ]]
    df_is = df_is.drop_duplicates()
    df=df_is.copy()
    bq_project = "data-nationalslsdist-prd-986g"
    bq_dataset = "postpaid" 
    bq_table = "ref_is_mapping"
    client = bigquery.Client(project=bq_project)
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
    last_status="Update IS mapping finished"
    print(last_status)
    return df_is

@op
def update_dsa(df_last):
    print(df_last.head(1))
    print("Update DSA mapping starting")
    all_dfs=[] 
    list_file = ['jakarta_raya_postpaid_mapping.xlsx', 'java_postpaid_mapping.xlsx',
                'kalisumapa_postpaid_mapping.xlsx', 'sumatera_postpaid_mapping.xlsx']
    for circle in list_file:
        df_circle=pd.read_excel(f'/data/postpaid/{circle}', engine='openpyxl',
                                dtype=str, usecols='A:H', sheet_name='DSA Mapping')
        all_dfs.append(df_circle)
    df_dsa = pd.concat(all_dfs, ignore_index=True)
    df_dsa.columns=[
    'circle',
    'store_code',
    'region',
    'dsa_nik',
    'dsa_name',
    'spv_nik',
    'spv_name',
    'kpi_eligible'
    ]
    df_dsa=df_dsa.dropna(subset=['store_code', 'region', 'dsa_nik', 'dsa_name'], how='all')
    df_dsa=df_dsa.drop_duplicates()
    df_dsa['mth_id']=year_month
    df_dsa['updated_dt']=dt_id
    df=df_dsa.copy()
    bq_project = "data-nationalslsdist-prd-986g"
    bq_dataset = "postpaid" 
    bq_table = "ref_dsa_mapping"
    client = bigquery.Client(project=bq_project)
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
    last_status="Update DSA mapping finished"
    print(last_status)
    return df_dsa

@op
def update_promotor(df_last):
    print(df_last.head(1))
    # all_dfs=[]
    # for circle in list_file:
    #     df_circle=pd.read_excel(f'/data/postpaid/{circle}', engine='openpyxl',
    #                             dtype=str, usecols='A:H', sheet_name='Promotor Mapping')
    #     all_dfs.append(df_circle)
    # df_promotor = pd.concat(all_dfs, ignore_index=True) 
    # df_promotor=pd.read_excel(f'/data/postpaid/others_partner.xlsx', engine='openpyxl',
    #                         dtype=str, usecols='A:H', sheet_name='Promotor Mapping')
    all_dfs=[]
    
    # list_file = ['java_postpaid_mapping.xlsx', 'others_partner.xlsx']
    # perubahan 3 december 2025
    list_file = ['others_partner.xlsx']
    for circle in list_file:
        df_circle=pd.read_excel(f'/data/postpaid/{circle}', engine='openpyxl',
                                dtype=str, usecols='A:J', sheet_name='Promotor Mapping', header=None,
                                skiprows=1,
                                names=['store_code',
                                    'store_name',
                                    'promotor_nik',
                                    'promotor_name',
                                    'promotor_spv_nik',
                                    'promotor_spv_name',
                                    'partner',
                                    'channel',
                                    'circle',
                                    'region'])
        if circle=='others_partner.xlsx':
            df_circle=df_circle[df_circle['circle'].str.lower()!='java']
        all_dfs.append(df_circle)
    df_promotor = pd.concat(all_dfs, ignore_index=True)

    df_promotor=df_promotor.drop_duplicates()
    # df_promotor.columns=[
    # 'store_code',
    # 'store_name',
    # 'promotor_nik',
    # 'promotor_name',
    # 'promotor_spv_nik',
    # 'promotor_spv_name',
    # 'partner',
    # 'channel'
    # ]
    df_promotor['mth_id']=year_month
    df_promotor['updated_dt']=dt_id
    df_promotor = df_promotor[[
        'store_code',
        'store_name',
        'promotor_nik',
        'promotor_name',
        'promotor_spv_nik',
        'promotor_spv_name',
        'partner',
        'channel',
        'mth_id',
        'updated_dt',
        'circle',
        'region'
    ]]
    df=df_promotor.copy()
    bq_project = "data-nationalslsdist-prd-986g"
    bq_dataset = "postpaid" 
    bq_table = "ref_promotor_mapping"
    client = bigquery.Client(project=bq_project)
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
    last_status="Update Promotor mapping finished"
    print(last_status)
    return df_promotor

@op
def update_branch(df_last):
    print(df_last.head(1))
    all_dfs=[] 
    list_file = ['jakarta_raya_postpaid_mapping.xlsx', 'java_postpaid_mapping.xlsx',
                'kalisumapa_postpaid_mapping.xlsx', 'sumatera_postpaid_mapping.xlsx']
    for circle in list_file:
        df_circle=pd.read_excel(f'/data/postpaid/{circle}', engine='openpyxl',
                                dtype=str, usecols='A:D', sheet_name='Ref Branch')
        all_dfs.append(df_circle)
    df_branch = pd.concat(all_dfs, ignore_index=True)
    df_branch.drop_duplicates(inplace=True)
    df_branch.columns=[
    'branch',
    'area',
    'region',
    'circle'
    ]
    df_branch['mth_id']=year_month
    df_branch['updated_dt']=dt_id
    df=df_branch.copy()
    bq_project = "data-nationalslsdist-prd-986g"
    bq_dataset = "postpaid" 
    bq_table = "ref_branch_mapping"
    client = bigquery.Client(project=bq_project)
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
    last_status="Update Branch mapping finished"
    print(last_status)
    return df_branch

@op
def update_final(df_store, df_is, df_dsa, df_promotor, df_branch):
    print(df_store.head(1))
    # Save Excel file with multiple sheets
    file_path = f'/data/postpaid/nationwide_postpaid_mapping_{year_month}.xlsx'

    with pd.ExcelWriter(file_path, engine='openpyxl') as writer:
        df_store.to_excel(writer, sheet_name='Storelist', index=False)
        df_is.to_excel(writer, sheet_name='IS', index=False)
        df_dsa.to_excel(writer, sheet_name='DSA Mapping', index=False)
        df_promotor.to_excel(writer, sheet_name='Promoto Mapping', index=False)
        df_branch.to_excel(writer, sheet_name='Ref Branch', index=False)

    # Load the workbook for further editing
    wb = load_workbook(file_path)

    for sheet_name in wb.sheetnames:
        ws = wb[sheet_name]

        # ✅ Auto-fit column width
        for col in ws.columns:
            max_length = 0
            col_letter = get_column_letter(col[0].column)
            for cell in col:
                try:
                    cell_value = str(cell.value)
                    if cell_value:
                        max_length = max(max_length, len(cell_value))
                except:
                    pass
            adjusted_width = max_length + 2
            ws.column_dimensions[col_letter].width = adjusted_width

        # ✅ Lock all cells (default: locked=True)
        # for row in ws.iter_rows():
        #     for cell in row:
        #         cell.protection = Protection(locked=True)

        # ✅ Protect sheet: prevent edit, allow selection
        ws.protection.sheet = True
        ws.protection.password = 'BAI@snd2025'
        ws.protection.autoFilter = True
        # ws.protection.selectLockedCells = True
        # ws.protection.selectUnlockedCells = True

    wb.save(file_path)
    os.system(f'''rclone copy /data/postpaid/nationwide_postpaid_mapping_{year_month}.xlsx dsn:postpaid''')
    os.system(f'''rclone copy dsn:postpaid/nationwide_postpaid_mapping_{year_month}.xlsx dsn:"Retail Performance Management - R100/reference_postpaid"''')

    print('Start Creating File Dump for PBI')
    df_merge=df_store\
        .merge(df_branch, on='branch', how='left', suffixes=('', '_df2'))\
        .merge(df_promotor, on='store_code', how='left', suffixes=('', '_df3'))\
        .merge(df_is, on='rce_nik', how='left', suffixes=('','_df4'))
    df_all=pd.DataFrame({
    'registered_date': df_merge['registered_date'],
    'store_name': df_merge['store_name'],
    'store_code': df_merge['store_code'],
    'hos': pd.NA,
    'bsm': df_merge['branch'],
    'manager_rcm': df_merge['rce'],
    'promotor': df_merge['promotor_name'],
    'region': df_merge['region'],
    'area': df_merge['branch'],
    'sales_area': df_merge['branch'],
    'city': pd.NA,
    'channel_group': df_merge['channel_group'],
    'channel_detail': df_merge['channel_detail'],
    'province': pd.NA,
    'longitude': df_merge['longtitude'],
    'latitude': df_merge['latitude'],
    'pic_name': pd.NA,
    'pic_email': pd.NA,
    'pic_phone_no': pd.NA,
    'address': pd.NA,
    'closed_date': df_merge['closed_date'],
    'postpaid_manger': df_merge['postpaid_officer_name'],
    'hor': df_merge['hor_name'],
    'nik_hor_era': pd.NA,
    'hor_era_name': pd.NA,
    'nik_hot_era': pd.NA,
    'head_of_territory_era_name': pd.NA,
    'nik_tsh_era': pd.NA,
    'tsh_era_name': pd.NA,
    'nik_store_leader_era': pd.NA,
    'store_leader_era_name': pd.NA,
    'nik_ast_store_leader_era': pd.NA,
    'ast_store_leader_era_name': pd.NA,
    'spv': pd.NA,
    'flag_target': pd.NA,
    'rce_buddy': df_merge['postpaid_officer_name'],
    'rce': df_merge['rce'],
    'rce_title': df_merge['rce_title'],
    # 'rce_title': df_merge.apply(
    #     lambda row: 'RCE PS' if 'partner store' in str(row['channel_group']).lower() else pd.NA,
    #     axis=1),
    'avp': df_merge['hopr_name'],
    'avp_title': pd.NA,
    'vp_pro': df_merge['hopc_name'],
    'circle': df_merge['circle'],
    'region_circle': df_merge['region']   
    })
    df_all.columns=[
    'Registered Date',
    'store_name',
    'store_code',
    'HOS',
    'BSM',
    'Manager (RCM)',
    'promotor',
    'Region',
    'Area',
    'Sales Area',
    'City',
    'channel_group',
    'channel_detail',
    'Province',
    'Lontitude',
    'Latitude',
    'PIC Name',
    'PIC Email',
    'PIC Phone No.',
    'address ',
    'Closed Date',
    'POSTPAID MANGER',
    'HOR',
    'NIK HOR ERA',
    'HOR ERA_NAME',
    'NIK HOT ERA',
    'HEAD OF TERRITORY ERA_NAME',
    'NIK TSH ERA',
    'TSH ERA_NAME',
    'NIK STORE LEADER ERA',
    'STORE LEADER ERA_NAME',
    'NIK AST. STORE LEADER ERA',
    'AST. STORE LEADER ERA_NAME',
    'SPV',
    'FLAG Target',
    'RCE BUDDY',
    'RCE',
    'RCE TITLE',
    'AVP',
    'AVP TITLE',
    'VP PRO',
    'Circle',
    'Region New 2024'
    ]
    df_all.drop_duplicates(inplace=True)
    df_all.dropna(subset=['store_name', 'store_code'], inplace=True)
    # Find duplicated store_code
    # duplicated_mask = df_all.duplicated(subset=["store_code"], keep=False)

    # Update store_code by concatenating with store_name for duplicates
    # df_all.loc[duplicated_mask, "store_code"] = (
    #     df_all.loc[duplicated_mask, "store_code"] + "_" + df_all.loc[duplicated_mask, "store_name"]
    # )
    # Example condition list (you can add more)
    special_codes = ["process", "vacant", "on process"]

    # Find duplicates by store_code
    duplicated_mask = df_all.duplicated(subset=["store_code"], keep=False)

    # Split dataframe into special and non-special codes
    special_mask = df_all["store_code"].str.lower().isin([s.lower() for s in special_codes])
    normal_mask = ~special_mask

    # --- Handle special codes ---
    df_all.loc[duplicated_mask & special_mask, "store_code"] = (
        df_all.loc[duplicated_mask & special_mask, "store_code"]
        + "_" 
        + df_all.loc[duplicated_mask & special_mask, "store_name"]
    )

    # --- Handle non-special codes (drop duplicates, keep first) ---
    df_all = pd.concat([
        df_all.loc[~duplicated_mask | special_mask],          # all non-duplicates + special duplicates
        df_all.loc[duplicated_mask & normal_mask].drop_duplicates(subset=["store_code"], keep="first")  # drop extras
    ])
    df_all.to_excel('/data/postpaid/Database Hirearki Store Historical.xlsx',index=False, sheet_name='Database_Store')
    os.system(f'''rclone copy "/data/postpaid/Database Hirearki Store Historical.xlsx" dsn:postpaid''')
    os.system(f'''rclone copy "dsn:postpaid/Database Hirearki Store Historical.xlsx" dsn:"Retail Performance Management - R100/reference_postpaid"''')
    os.system(f'''rclone copy "dsn:postpaid/Database Hirearki Store Historical.xlsx" dsn:"Data/Power BI Dashboard/Store"''')
    status='task finished'
    return status

@op
def update_ref_ssot(status):
    print(status)
    # ==== BIGQUERY CONFIG ====
    project_id = "data-bi-prd-935c"
    dataset_id = "bi_snd"
    table_id = "pst_ref_storelist"
    full_table_id = f"{project_id}.{dataset_id}.{table_id}"
    client = bigquery.Client(project=project_id)

    query = f"""
    merge into `data-bi-prd-935c.bi_snd.pst_ref_storelist` as tgt
    using (
        select * from (
            select 
            *, 
            row_number() over(partition by store_code order by updated_dt desc) as idx
            from `data-nationalslsdist-prd-986g`.postpaid.ref_storelist_base as a 
                where store_code is not null
        ) as x where x.idx=1
    ) as src
    on tgt.store_code = src.store_code 
    when matched then 
        update set 
            tgt.store_name = src.store_name,
            tgt.channel_group = src.channel_group,
            tgt.channel_detail = src.channel_detail,
            tgt.circle = src.circle,
            tgt.region = src.region,
            tgt.branch = src.branch,
            tgt.rce_nik = src.rce_nik,
            tgt.rce = src.rce, 
            tgt.registered_date = src.registered_date,
            tgt.closed_date = src.closed_date,
            tgt.longitude = safe_cast(src.longtitude as float64),
            tgt.latitude = safe_cast(src.latitude as float64)
    when not matched then 
        insert (store_code, store_name, channel_group, channel_detail, circle, region, branch, rce_nik, rce, flag, updated_dt, registered_date, closed_date, longitude, latitude)
        values (src.store_code, 
            src.store_name,
            src.channel_group,
            src.channel_detail,
            src.circle,
            src.region,
            src.branch,
            src.rce_nik,
            src.rce,
            'EXISTING', 
            current_date("Asia/Jakarta"),
            src.registered_date,
            src.closed_date,
            safe_cast(src.longtitude as float64),
            safe_cast(src.latitude as float64))
    """
    client.query(query).result()

@graph
def postpaid_reference_update():
    t0 = copy_files()
    df_store = update_storelist(t0) 
    df_is = update_is(df_store)
    df_dsa = update_dsa(df_is)
    df_promotor = update_promotor(df_dsa)
    df_branch = update_branch(df_promotor)
    flag_final=update_final(df_store, df_is, df_dsa, df_promotor, df_branch)
    update_ref_ssot(flag_final)
