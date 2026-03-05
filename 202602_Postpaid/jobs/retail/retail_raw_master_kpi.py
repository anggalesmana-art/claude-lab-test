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
import cx_Oracle
import sys
import traceback

os.environ["LD_LIBRARY_PATH"] = "/data/oracleclient/instantclient_12_2"
os.environ["ORACLE_HOME"] = "/data/oracleclient/instantclient_12_2"


# set
load_dotenv("/data/data_automation_bai/data_automation_scheduling/cred/pst_rtl.env")

# Get data D-2 
dt_id = (dt.date.today() - timedelta(days = 2)).strftime("%Y%m%d")  

# Rerun manual
# dt_id ="20250331" 

year_month=dt_id[:6]

# SSH and PostgreSQL Configuration
SSH_HOST = os.getenv("gp_ssh_host")
SSH_PORT = int(os.getenv("gp_ssh_port"))
SSH_USER = os.getenv("gp_ssh_user")
SSH_PASSWORD = os.getenv("gp_ssh_password")

DB_HOST = os.getenv("gp_host")
DB_PORT = int(os.getenv("gp_port"))
DB_NAME = os.getenv("gp_database")
DB_USER = os.getenv("gp_user")
DB_PASSWORD = os.getenv("gp_password")

# SMB Server details
server = os.getenv("smb_server")
share = os.getenv("smb_share")
username = os.getenv("smb_user")
password = os.getenv("smb_password")

## Function for grab, read, and execute data in Cockpit
# Cockpit SSH and MySQL connection settings
ssh_host = os.getenv("cockpit_ssh_host")
ssh_port = int(os.getenv("cockpit_ssh_port"))
ssh_user = os.getenv("cockpit_ssh_user")
ssh_password = os.getenv("cockpit_ssh_password")
ssh_key_path = None

mysql_host = os.getenv("cockpit_host")
mysql_port = int(os.getenv("cockpit_port"))
mysql_user = os.getenv("cockpit_user")
mysql_password = os.getenv("cockpit_password")
mysql_database = os.getenv("cockpit_database") 

# Connection details
rgst_username = os.getenv("rgst_username")
rgst_password = os.getenv("rgst_password")
rgst_host = os.getenv("rgst_host")
rgst_port = int(os.getenv("rgst_port"))
rgst_service_name = os.getenv("rgst_service")


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
    user = os.getenv("gp_ssh_user")
    password = os.getenv("gp_ssh_password")
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
    user = os.getenv("gp_ssh_user")
    password = os.getenv("gp_ssh_password")
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
            print(f"SSH Tunnel established on port {local_port}")

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

def upload_kpi_data(dt_id: str, kpi_list: list, brand_list: list,df, table: str):
    # ==== BIGQUERY CONFIG ====
    project_id = "data-bi-prd-935c"
    dataset_id = "bi_snd"
    if table=='mtd':
        table_id = "rtl_raw_master_kpi_mtd"
    else: 
        table_id = "rtl_raw_master_kpi_dly"
    full_table_id = f"{project_id}.{dataset_id}.{table_id}"

    client = bigquery.Client(project=project_id)

    # ==== CONVERT LIST TO SQL IN CLAUSE ====
    if not kpi_list:
        raise ValueError("kpi_list cannot be empty")

    kpi_str = ",".join(f"'{k}'" for k in kpi_list)
    brand_str = ",".join(f"'{k}'" for k in brand_list)

    # ==== DELETE ROWS BASED ON CONDITION ====
    if table=='mtd':
        delete_query = f"""
        DELETE FROM `{full_table_id}`
        WHERE dt_id = '{dt_id}' 
          AND kpi_name IN ({kpi_str})
          and brand in ({brand_str})
        """
    else: 
        delete_query = f"""
        DELETE FROM `{full_table_id}`
        WHERE left(dt_id,6) = left('{dt_id}',6) 
          AND kpi_name IN ({kpi_str})
          and brand in ({brand_str})
        """
    client.query(delete_query).result()
    if table=='mtd':
        print(f"Deleted rows in {full_table_id} where dt_id='{dt_id}' and kpi_name in ({kpi_str}) and brand in ({brand_str})")
    else:
        print(f"Deleted rows in {full_table_id} where left(dt_id,6)='{dt_id[:6]}' and kpi_name in ({kpi_str}) and brand in ({brand_str})")

    # ==== APPEND NEW DATA ====
    job_config = bigquery.LoadJobConfig(
        write_disposition=bigquery.WriteDisposition.WRITE_APPEND,
        autodetect=True,
    )
    job = client.load_table_from_dataframe(df, full_table_id, job_config=job_config)
    job.result()

    print(f"Success Appended {len(df)} rows into {full_table_id}")

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

@op(retry_policy=RetryPolicy(max_retries=3, delay=60))
def rgst_data(status):
    print(status)
    print(sys.executable)
    print(os.environ.get("LD_LIBRARY_PATH"))

    # Daily Order
    print('Daily Order 3Store')
    dsn = cx_Oracle.makedsn(rgst_host, rgst_port, service_name=rgst_service_name)
    conn = cx_Oracle.connect(
        user=rgst_username,
        password=rgst_password,
        dsn=dsn
    )
    query = f"""
    select 
        z.*,
        to_char(ORDER_DATE,'yyyymmdd') DT_ID,
        to_char(ORDER_DATE,'yyyymm') MONTH_ID 
    from (
        select ORDER#,MSISDN,ORDER_DATE,COMPLETION_DATE,
            ORDER_NAME,ACTION,ORDER_STATUS,COMMENTS,REASON,
            case 
                when a.DEALER is not null then a.DEALER
                when a.DEALER is null then b.BRANCH end as DEALER,CHANNEL,
            CREATOR,NIK,SUBMITTED_BY,ASSIGNED_TO,INTEGRATION_ST,ERROR_MSG
        from siebel.WIO_ORDER_3ID a
            left join siebel.SIEBEL_USERS b on a.NIK=b.LOGIN
        where to_char(ORDER_DATE,'yyyymm')='{year_month}') z
        where DEALER like '%WIC%'
        order by ORDER_DATE
    """
    df = pd.read_sql(query, conn)
    conn.close()
    df.columns = [
        'order_id',
        'msisdn',
        'order_date',
        'completion_date',
        'order_name',
        'action',
        'order_status',
        'comments',
        'reason',
        'dealer',
        'channel',
        'creator',
        'nik',
        'submitted_by',
        'assigned_to',
        'integration_st',
        'error_msg',
        'dt_id', 
        'month_id']
    df['dt_id']=pd.to_datetime(df['dt_id'], format='%Y%m%d').dt.date
    df['order_date']=df['order_date'].astype(str)
    df['completion_date']=df['completion_date'].astype(str)
    project_id='data-nationalslsdist-prd-986g'
    client = bigquery.Client(project=project_id) 
    dataset_id = "retail"
    table_id = "raw_3id_siebel_order"
    full_table_id = f"{project_id}.{dataset_id}.{table_id}"
    delete_query = f"""
            DELETE FROM `{full_table_id}`
            WHERE month_id = '{year_month}' 
            """
    print(delete_query)
    client.query(delete_query).result()
    job_config = bigquery.LoadJobConfig(
        write_disposition=bigquery.WriteDisposition.WRITE_APPEND,
        autodetect=True,
    )
    job = client.load_table_from_dataframe(df, full_table_id, job_config=job_config)
    job.result()

    # Daily Interaction
    print('Daily Interaction 3Store')
    dsn = cx_Oracle.makedsn(rgst_host, rgst_port, service_name=rgst_service_name)
    conn = cx_Oracle.connect(
        user=rgst_username,
        password=rgst_password,
        dsn=dsn
    )
    query = f"""
    select 
        SRNUMBER,
        SERVICE_NUM,
        REQUEST_MSISDN,
        BRAND,
        a.GROUP_ACTCODE,
        a.ACT_CODE,
        TICKET_TYPE,
        ISSUE_GROUP,
        a.ISSUE_SUBGROUP,
        ISSUE_DESC,
        b.GROUP_ACTCODE GROUP_COMPLAINT,
        STATUS,
        SUB_STATUS,
        CREATEDDATE,
        DUEDATE,
        CLOSEDATE,
        CREATOR,
        CREATORNAME,
        CREATORPOSITION,
        case 
            when a.BRANCH is not null then a.BRANCH
            when a.BRANCH is null then c.BRANCH end as BRANCH,
        case 
            when a.GERAI_WIC is not null then a.GERAI_WIC
            when a.GERAI_WIC is null then c.DEALER end as GERAI_WIC,
        SOURCE,DETAIL_INFORMATION,CUST_SEGMENT,ARPU_SEGMENT,
        to_char(CREATEDDATE,'yyyymmdd') DT_ID,
        to_char(CREATEDDATE,'yyyymm') MONTH_ID,
        'INTERACTION' as FLAG,'No' as IS_ESCALATED
    from siebel.WIO_INT_3STORE a
        left join siebel.TB_ACTCODE_MIR b on a.ACT_CODE=b.ACT_CODE
        left join siebel.SIEBEL_USERS c on a.CREATOR=c.LOGIN
    where CREATORPOSITION like '%WIC%'
        and to_char(CREATEDDATE,'yyyymm')='{year_month}'
        order by CREATEDDATE
    """
    df = pd.read_sql(query, conn)
    conn.close()
    df.columns = df.columns.str.lower()
    df['dt_id']=pd.to_datetime(df['dt_id'], format='%Y%m%d').dt.date
    project_id='data-nationalslsdist-prd-986g'
    client = bigquery.Client(project=project_id)
    dataset_id = "retail"
    table_id = "raw_3id_siebel_interaction"
    full_table_id = f"{project_id}.{dataset_id}.{table_id}"
    delete_query = f"""
            DELETE FROM `{full_table_id}`
            WHERE month_id = '{year_month}' 
            """
    print(delete_query)
    client.query(delete_query).result()
    job_config = bigquery.LoadJobConfig(
        write_disposition=bigquery.WriteDisposition.WRITE_APPEND,
        autodetect=True,
    )
    job = client.load_table_from_dataframe(df, full_table_id, job_config=job_config)
    job.result()

    # Daily Service Request
    print('Daily Service Request 3Store')
    dsn = cx_Oracle.makedsn(rgst_host, rgst_port, service_name=rgst_service_name)
    conn = cx_Oracle.connect(
        user=rgst_username,
        password=rgst_password,
        dsn=dsn
    )
    query = f"""
    select 
        SRNUMBER,
        SERVICE_NUM,
        REQUEST_MSISDN,
        BRAND,
        a.GROUP_ACTCODE,
        a.ACT_CODE,
        TICKET_TYPE,
        ISSUE_GROUP,
        a.ISSUE_SUBGROUP,
        ISSUE_DESC,
        b.GROUP_ACTCODE GROUP_COMPLAINT,
        STATUS,
        SUB_STATUS,
        CREATEDDATE,
        DUEDATE,
        CLOSEDATE,
        CREATOR,
        CREATORNAME,
        CREATORPOSITION,
        case 
            when a.BRANCH is not null then a.BRANCH
            when a.BRANCH is null then c.BRANCH end as BRANCH,
        case 
            when a.GERAI_CC is not null then a.GERAI_CC
            when a.GERAI_CC is null then c.DEALER end as GERAI_WIC,
        SOURCE,
        OWNER,
        OWNERNAME,
        OWNERPOSITION,
        OWNERLOCATION1 OWNERLOCATION,
        DETAIL_INFORMATION,
        CUST_SEGMENT,
        ARPU_SEGMENT,
        to_char(CREATEDDATE,'yyyymmdd') DT_ID,
        to_char(CREATEDDATE,'yyyymm') MONTH_ID,
        'SR_TT' as FLAG,'Yes' as IS_ESCALATED
    from siebel.WIO_SR_3ID a
        left join siebel.TB_ACTCODE_MIR b on a.ACT_CODE=b.ACT_CODE
        left join siebel.SIEBEL_USERS c on a.CREATOR=c.LOGIN
    where CREATORPOSITION like '%WIC%'
        and OWNER is not null
        and to_char(CREATEDDATE,'yyyymm')='{year_month}'
    order by CREATEDDATE
    """

    df = pd.read_sql(query, conn)
    conn.close()
    df.columns = df.columns.str.lower()
    df['dt_id']=pd.to_datetime(df['dt_id'], format='%Y%m%d').dt.date
    project_id='data-nationalslsdist-prd-986g'
    client = bigquery.Client(project=project_id)
    dataset_id = "retail"
    table_id = "raw_3id_siebel_sr_tt"
    full_table_id = f"{project_id}.{dataset_id}.{table_id}"
    delete_query = f"""
            DELETE FROM `{full_table_id}`
            WHERE month_id = '{year_month}' 
            """
    print(delete_query)
    client.query(delete_query).result()
    job_config = bigquery.LoadJobConfig(
        write_disposition=bigquery.WriteDisposition.WRITE_APPEND,
        autodetect=True,
    )
    job = client.load_table_from_dataframe(df, full_table_id, job_config=job_config)
    job.result()
    status = 'RGST FINISH SEND DATA'
    return status


@op(retry_policy=RetryPolicy(max_retries=3, delay=60))
def tri_revenue_cash_in(status):
    print(status)
    print(dt_id)
    print('Start Executing 3ID Master KPI on Cockpit') 
    filename = '/data/data_automation_bai/data_automation_scheduling/scripts/retail/master_kpi/3id_revenue_cash_in.sql'
    fd = open(filename, 'r')
    sql_file = fd.read() 
    sql_file=sql_file.format(**{"year_month": year_month, 
                                "dt_id": dt_id
                                })
    fd.close() 
    query = sql_file.split(';') 
    print("01. Deleting tmp revenue table") 
    cockpit_execute_sql(query[0])
    print("02. Creating tmp revenue table") 
    cockpit_execute_sql(query[1])
    print("03. Dump revenue KPI MTD")
    df=cockpit_get_df(query[2])
    df['insert_dt']=dt.datetime.now()
    df['prt_dt']=pd.to_datetime(df['dt_id'], format='%Y-%m-%d').dt.date
    upload_kpi_data(dt_id, df.kpi_name.unique().tolist(), df.brand.unique().tolist(), df, 'mtd')
    print("04. Dump revenue KPI DLY")
    df=cockpit_get_df(query[3])
    df['insert_dt']=dt.datetime.now()
    df['prt_dt']=pd.to_datetime(df['dt_id'], format='%Y-%m-%d').dt.date
    upload_kpi_data(dt_id, df.kpi_name.unique().tolist(), df.brand.unique().tolist(), df, 'dly')
    print("05. Dump transaction category KPI MTD")
    df=cockpit_get_df(query[4])
    df['insert_dt']=dt.datetime.now()
    df['prt_dt']=pd.to_datetime(df['dt_id'], format='%Y-%m-%d').dt.date
    upload_kpi_data(dt_id, df.kpi_name.unique().tolist(), df.brand.unique().tolist(), df, 'mtd')
    print("06. Dump transaction category KPI DLY")
    df=cockpit_get_df(query[5])
    df['insert_dt']=dt.datetime.now()
    df['prt_dt']=pd.to_datetime(df['dt_id'], format='%Y-%m-%d').dt.date
    upload_kpi_data(dt_id, df.kpi_name.unique().tolist(), df.brand.unique().tolist(), df, 'dly')
    status = 'finished'
    return status

@op(retry_policy=RetryPolicy(max_retries=3, delay=60))
def tri_ga_prepaid(status):
    print(status)
    print(dt_id)
    print('Start Executing 3ID Master KPI on Cockpit') 
    filename = '/data/data_automation_bai/data_automation_scheduling/scripts/retail/master_kpi/3id_ga_prepaid.sql'
    fd = open(filename, 'r')
    sql_file = fd.read() 
    sql_file=sql_file.format(**{"year_month": year_month, 
                                "dt_id": dt_id
                                })
    fd.close() 
    query = sql_file.split(';') 
    print("01. Deleting tmp ga table") 
    cockpit_execute_sql(query[0])
    print("02. Creating tmp ga table") 
    cockpit_execute_sql(query[1])
    print("03. Dump ga KPI MTD")
    df=cockpit_get_df(query[2])
    df['insert_dt']=dt.datetime.now()
    df['prt_dt']=pd.to_datetime(df['dt_id'], format='%Y-%m-%d').dt.date
    upload_kpi_data(dt_id, df.kpi_name.unique().tolist(), df.brand.unique().tolist(), df, 'mtd')
    print("04. Dump revenue KPI DLY")
    df=cockpit_get_df(query[3])
    df['insert_dt']=dt.datetime.now()
    df['prt_dt']=pd.to_datetime(df['dt_id'], format='%Y-%m-%d').dt.date
    upload_kpi_data(dt_id, df.kpi_name.unique().tolist(), df.brand.unique().tolist(), df, 'dly')

    # df=cockpit_get_df(f'''
    #     select
    #             '{dt_id}' as dt_id,
    #             'ga_prepaid' as kpi_name,
    #             'agent' as level, 
    #             agent_id, 
    #             store_code, 
    #             '3ID' as brand, 
    #             sum(ga) as value
    #         from cockpit.tmp_kpi_ga
    #             where buv_source not in ('dvm_store', 'dvm_standalone')
    #                 and left(dt_id,6)=left('{dt_id}',6)
    #                 and dt_id<='{dt_id}'
    #         group by 1, 2, 3, 4, 5, 6
    # ''')
    # dvm=cockpit_get_df(f'''
    #     select
    #         buv_source as level, 
    #         store_code, 
    #         sum(ga) as value
    #     from cockpit.tmp_kpi_ga
    #         where buv_source='dvm_store'
    #             and left(dt_id,6)=left('{dt_id}',6)
    #             and dt_id<='{dt_id}'
    #     group by 1, 2
    # ''')
    # merged = df.merge(dvm[["store_code", "value"]], on="store_code", how="left", suffixes=("", "_dvm"))
    # # Allocate vending machine achievements per store
    # result = (
    #     merged.groupby("store_code", group_keys=False)
    #         .apply(lambda g: distribute_vending_agents(g, g["value_dvm"].iloc[0] if pd.notna(g["value_dvm"].iloc[0]) else 0))
    # )
    # result['kpi_name']='ga_prepaid_dvm'
    # result['value']=result['value']+result['dvm_alloc']
    # result=result[['dt_id', 'kpi_name', 'level', 'agent_id', 'store_code', 'brand', 'value']]
    # result['insert_dt']=dt.datetime.now()
    # result['prt_dt']=pd.to_datetime(result['dt_id'], format='%Y-%m-%d').dt.date
    # upload_kpi_data(dt_id, result.kpi_name.unique().tolist(), df.brand.unique().tolist(), result, 'mtd')

    status = 'finished'
    return status

@op(retry_policy=RetryPolicy(max_retries=3, delay=60))
def tri_traffic_visitor(status):
    print(status)
    print(dt_id)
    print('Start Executing 3ID Master KPI on Cockpit') 
    filename = '/data/data_automation_bai/data_automation_scheduling/scripts/retail/master_kpi/3id_traffic_visitor_new.sql'
    fd = open(filename, 'r')
    sql_file = fd.read() 
    sql_file=sql_file.format(**{"year_month": year_month, 
                                "dt_id": dt_id
                                })
    fd.close() 
    query = sql_file.split(';') 
    print("00. Dump traffic visitor QMS to GCP")
    df=cockpit_get_df(query[0])
    df['prt_dt']=pd.to_datetime(df['dt_id'], format='%Y-%m-%d').dt.date
     # ==== BIGQUERY CONFIG ====
    project_id = "data-nationalslsdist-prd-986g"
    dataset_id = "retail"
    table_id="raw_qms_visitor"
    full_table_id = f"{project_id}.{dataset_id}.{table_id}"
    client = bigquery.Client(project=project_id)
    # ==== DELETE ROWS BASED ON CONDITION ====
    delete_query = f"""
    DELETE FROM `{full_table_id}`
    WHERE left(dt_id,6) = left('{dt_id}',6) 
    """
    client.query(delete_query).result()
    print(f"Deleted rows in {full_table_id} where left(dt_id,6)='{dt_id[:6]}'")
    # ==== APPEND NEW DATA ====
    job_config = bigquery.LoadJobConfig(
        write_disposition=bigquery.WriteDisposition.WRITE_APPEND,
        autodetect=True,
    )
    job = client.load_table_from_dataframe(df, full_table_id, job_config=job_config)
    job.result()

    print(f"Success Appended {len(df)} rows into {full_table_id}")
    
    
    print("01. Dump traffic visitor new KPI MTD")
    df=client.query(query[1]).to_dataframe()
    df['insert_dt']=dt.datetime.now()
    df['prt_dt']=pd.to_datetime(df['dt_id'], format='%Y-%m-%d').dt.date
    upload_kpi_data(dt_id, df.kpi_name.unique().tolist(), df.brand.unique().tolist(), df, 'mtd')
    status = 'finished'
    return status

# def tri_traffic_visitor(status):
#     print(status)
#     print(dt_id)
#     print('Start Executing 3ID Master KPI on Cockpit') 
#     filename = '/data/data_automation_bai/data_automation_scheduling/scripts/retail/master_kpi/3id_traffic_visitor.sql'
#     fd = open(filename, 'r')
#     sql_file = fd.read() 
#     sql_file=sql_file.format(**{"year_month": year_month, 
#                                 "dt_id": dt_id
#                                 })
#     fd.close() 
#     query = sql_file.split(';') 
#     print("01. Deleting tmp traffic visitor 1 table") 
#     cockpit_execute_sql(query[0])
#     print("02. Creating tmp traffic visitor 1 table") 
#     cockpit_execute_sql(query[1])
#     print("03. Deleting tmp traffic visitor 2 table") 
#     cockpit_execute_sql(query[2])
#     print("04. Creating tmp traffic visitor 2 table") 
#     cockpit_execute_sql(query[3])
#     print("05. Dump traffic visitor KPI MTD")
#     df=cockpit_get_df(query[4])
#     df['insert_dt']=dt.datetime.now()
#     df['prt_dt']=pd.to_datetime(df['dt_id'], format='%Y-%m-%d').dt.date
#     upload_kpi_data(dt_id, df.kpi_name.unique().tolist(), df.brand.unique().tolist(), df, 'mtd')
#     print("04. Dump traffic visior KPI DLY")
#     df=cockpit_get_df(query[5])
#     df['insert_dt']=dt.datetime.now()
#     df['prt_dt']=pd.to_datetime(df['dt_id'], format='%Y-%m-%d').dt.date
#     upload_kpi_data(dt_id, df.kpi_name.unique().tolist(), df.brand.unique().tolist(), df, 'dly')
#     status = 'finished'
#     return status

@op(retry_policy=RetryPolicy(max_retries=3, delay=60))
def tri_csat_inhouse(status):
    # print(status)
    # print(dt_id)
    # print('Start Executing 3ID Master KPI on Cockpit') 
    # filename = '/data/data_automation_bai/data_automation_scheduling/scripts/retail/master_kpi/3id_csat_inhouse.sql'
    # fd = open(filename, 'r')
    # sql_file = fd.read() 
    # sql_file=sql_file.format(**{"year_month": year_month, 
    #                             "dt_id": dt_id
    #                             })
    # fd.close() 
    # query = sql_file.split(';') 
    # print("01. Deleting tmp csat table") 
    # cockpit_execute_sql(query[0])
    # print("02. Creating tmp csat table") 
    # cockpit_execute_sql(query[1])
    # print("03. Dump csat KPI MTD")
    # df=cockpit_get_df(query[2])
    # df['insert_dt']=dt.datetime.now()
    # df['prt_dt']=pd.to_datetime(df['dt_id'], format='%Y-%m-%d').dt.date
    # upload_kpi_data(dt_id, df.kpi_name.unique().tolist(), df.brand.unique().tolist(), df, 'mtd') 
    
    print(status)
    print(dt_id)
    print('Start Executing 3ID Master KPI on Cockpit') 
    filename = '/data/data_automation_bai/data_automation_scheduling/scripts/retail/master_kpi/3id_csat_inhouse.sql'
    fd = open(filename, 'r')
    sql_file = fd.read() 
    sql_file=sql_file.format(**{"year_month": year_month, 
                                "dt_id": dt_id
                                })
    fd.close() 
    query = sql_file.split(';') 
    print('00. Dump CSAT INHOUSE Cockpit')
    df=cockpit_get_df(query[0])
    df['dt_id']=pd.to_datetime(df['dt_id'], format='%Y%m%d').dt.date
    df['csat_delivered']=df['csat_delivered'].astype(int)
    df['csat_respond']=df['csat_respond'].astype(int) 
    df['csat_happy']=df['csat_happy'].astype(int) 
    # ==== BIGQUERY CONFIG ====
    project_id = "data-nationalslsdist-prd-986g"
    dataset_id = "retail"
    table_id="raw_3id_csat"
    full_table_id = f"{project_id}.{dataset_id}.{table_id}"
    client = bigquery.Client(project=project_id)
    # ==== DELETE ROWS BASED ON CONDITION ====
    delete_query = f"""
    DELETE FROM `{full_table_id}`
    WHERE format_date('%Y%m', dt_id) = left('{dt_id}',6)
        and source_data = 'CSTOOLS'
    """
    client.query(delete_query).result()
    print(f"Deleted rows in {full_table_id} where format_date('%Y%m', dt_id)='{dt_id[:6]}'")
    # ==== APPEND NEW DATA ====
    job_config = bigquery.LoadJobConfig(
        write_disposition=bigquery.WriteDisposition.WRITE_APPEND,
        autodetect=True,
    )
    job = client.load_table_from_dataframe(df, full_table_id, job_config=job_config)
    job.result()
    print(f"Success Appended {len(df)} rows into {full_table_id}")

    print("02. Deleting csat kpi on mtd master kpi") 
    client.query(query[1]).result()

    print("03. Inserting csat kpi on mtd master kpi") 
    client.query(query[2]).result()
    status = 'finished'

    return status

@op(retry_policy=RetryPolicy(max_retries=3, delay=60))
def tri_interaction(status):
    print(status)
    print(dt_id)
    print('Start Executing 3ID Master KPI on Cockpit') 
    filename = '/data/data_automation_bai/data_automation_scheduling/scripts/retail/master_kpi/3id_interaction.sql'
    fd = open(filename, 'r')
    sql_file = fd.read() 
    sql_file=sql_file.format(**{"year_month": year_month, 
                                "dt_id": dt_id
                                })
    fd.close() 
    query = sql_file.split(';') 
    print("01. Deleting tmp interaction table") 
    cockpit_execute_sql(query[0])
    print("02. Creating tmp interaction table") 
    cockpit_execute_sql(query[1])
    # print("03. Dump interaction KPI MTD")
    # df=cockpit_get_df(query[2])
    # df['insert_dt']=dt.datetime.now()
    # df['prt_dt']=pd.to_datetime(df['dt_id'], format='%Y-%m-%d').dt.date
    # upload_kpi_data(dt_id, df.kpi_name.unique().tolist(), df.brand.unique().tolist(), df, 'mtd')
    # print("04. Dump interaction KPI DLY")
    # df=cockpit_get_df(query[3])
    # df['insert_dt']=dt.datetime.now()
    # df['prt_dt']=pd.to_datetime(df['dt_id'], format='%Y-%m-%d').dt.date
    # upload_kpi_data(dt_id, df.kpi_name.unique().tolist(), df.brand.unique().tolist(), df, 'dly')
    print('change card trx from cockpit to gcp')
    query_dump=f'''
        select * from cockpit.tmp_kpi_interaction
        where left(dt_id,6)=left('{dt_id}',6)
                and dt_id<='{dt_id}';
    '''
    df=cockpit_get_df(query_dump)
    df['dt_id']=pd.to_datetime(df['dt_id'], format='%Y%m%d').dt.date  
    # ==== BIGQUERY CONFIG ====
    project_id = "data-nationalslsdist-prd-986g"
    dataset_id = "retail"
    table_id="raw_3id_interactions"
    full_table_id = f"{project_id}.{dataset_id}.{table_id}"
    client = bigquery.Client(project=project_id)
    # ==== DELETE ROWS BASED ON CONDITION ====
    delete_query = f"""
    DELETE FROM `{full_table_id}`
    WHERE format_date('%Y%m', dt_id) = left('{dt_id}',6)
        and source_data not like '%ICARE%'
    """
    client.query(delete_query).result()
    print(f"Deleted rows in {full_table_id} where format_date('%Y%m', dt_id)='{dt_id[:6]}'")
    # ==== APPEND NEW DATA ====
    job_config = bigquery.LoadJobConfig(
        write_disposition=bigquery.WriteDisposition.WRITE_APPEND,
        autodetect=True,
    )
    job = client.load_table_from_dataframe(df, full_table_id, job_config=job_config)
    job.result()
    print(f"Success Appended {len(df)} rows into {full_table_id}")
    
    print("00. Deleting iCare trx on 3id interaction") 
    client.query(query[2]).result()
    
    print("01. Inserting iCare trx on 3id interaction") 
    client.query(query[3]).result()
    
    print("02. Deleting change card kpi on mtd master kpi") 
    client.query(query[4]).result()
    
    print("03. Inserting change card kpi on mtd master kpi") 
    client.query(query[5]).result()
    
    print("04. Deleting change card kpi on dly master kpi") 
    client.query(query[6]).result()
    
    print("05. Inserting change card kpi on dly master kpi") 
    client.query(query[7]).result()
    
    status = 'finished'
    return status

@op(retry_policy=RetryPolicy(max_retries=3, delay=60))
def tri_fcr_sr(status):
    print(status)
    print(dt_id)
    print('Start Executing 3ID Master KPI on Cockpit') 
    filename = '/data/data_automation_bai/data_automation_scheduling/scripts/retail/master_kpi/3id_fcr_sr.sql'
    fd = open(filename, 'r')
    sql_file = fd.read() 
    sql_file=sql_file.format(**{"year_month": year_month, 
                                "dt_id": dt_id
                                })
    fd.close() 
    query = sql_file.split(';') 
    
    project_id = "data-nationalslsdist-prd-986g"
    client = bigquery.Client(project=project_id) 
    
    print("01. Deleting fcr sr kpi mtd") 
    client.query(query[0]).result()
    print("02. Inserting fcr sr kpi_mtd") 
    client.query(query[1]).result()
    
    status = 'finished'
    return status 

# def tri_fcr_sr(status):
#     print(status)
#     print(dt_id)
#     print('Start Executing 3ID Master KPI on Cockpit') 
#     filename = '/data/data_automation_bai/data_automation_scheduling/scripts/retail/master_kpi/3id_fcr_sr.sql'
#     fd = open(filename, 'r')
#     sql_file = fd.read() 
#     sql_file=sql_file.format(**{"year_month": year_month, 
#                                 "dt_id": dt_id
#                                 })
#     fd.close() 
#     query = sql_file.split(';') 
#     print("01. Deleting tmp fcr sr table") 
#     cockpit_execute_sql(query[0])
#     print("02. Creating tmp fcr sr table") 
#     cockpit_execute_sql(query[1])
#     print("03. Dump fcr sr KPI MTD")
#     df=cockpit_get_df(query[2])
#     df['insert_dt']=dt.datetime.now()
#     df['prt_dt']=pd.to_datetime(df['dt_id'], format='%Y-%m-%d').dt.date
#     upload_kpi_data(dt_id, df.kpi_name.unique().tolist(), df.brand.unique().tolist(), df, 'mtd')
#     status = 'finished'
#     return status

@op(retry_policy=RetryPolicy(max_retries=3, delay=60))
def tri_change_card(status):
    print(status)
    print(dt_id)
    print('Start Executing 3ID Master KPI on Cockpit') 
    filename = '/data/data_automation_bai/data_automation_scheduling/scripts/retail/master_kpi/3id_change_card.sql'
    fd = open(filename, 'r')
    sql_file = fd.read() 
    sql_file=sql_file.format(**{"year_month": year_month, 
                                "dt_id": dt_id
                                })
    fd.close() 
    query = sql_file.split(';') 
    print("01. Deleting tmp change card table") 
    cockpit_execute_sql(query[0])
    print("02. Creating tmp change card table") 
    cockpit_execute_sql(query[1])
    
    # print("03. Dump change card KPI MTD")
    # df=cockpit_get_df(query[2])
    # df['insert_dt']=dt.datetime.now()
    # df['prt_dt']=pd.to_datetime(df['dt_id'], format='%Y-%m-%d').dt.date
    # upload_kpi_data(dt_id, df.kpi_name.unique().tolist(), df.brand.unique().tolist(), df, 'mtd')
    # print("04. Dump change card KPI DLY")
    # df=cockpit_get_df(query[3])
    # df['insert_dt']=dt.datetime.now()
    # df['prt_dt']=pd.to_datetime(df['dt_id'], format='%Y-%m-%d').dt.date
    # upload_kpi_data(dt_id, df.kpi_name.unique().tolist(), df.brand.unique().tolist(), df, 'dly')
    # df=cockpit_get_df(query[4])
    # df['prt_dt']=pd.to_datetime(df['dt_id'], format='%Y-%m-%d').dt.date 
    print('change card trx from cockpit to gcp')
    query=f'''
        select * from cockpit.tmp_kpi_change_card
        where left(dt_id,6)=left('{dt_id}',6)
                and dt_id<='{dt_id}';
    '''
    df=cockpit_get_df(query)
    df['prt_dt']=pd.to_datetime(df['dt_id'], format='%Y-%m-%d').dt.date 
    
    # ==== BIGQUERY CONFIG ====
    project_id = "data-nationalslsdist-prd-986g"
    dataset_id = "retail"
    table_id="raw_3id_change_card"
    full_table_id = f"{project_id}.{dataset_id}.{table_id}"
    client = bigquery.Client(project=project_id)
    # ==== DELETE ROWS BASED ON CONDITION ====
    delete_query = f"""
    DELETE FROM `{full_table_id}`
    WHERE left(dt_id,6) = left('{dt_id}',6) 
        and lower(source_channel)<>'icare'
    """
    client.query(delete_query).result()
    print(f"Deleted rows in {full_table_id} where left(dt_id,6)='{dt_id[:6]}'")
    # ==== APPEND NEW DATA ====
    job_config = bigquery.LoadJobConfig(
        write_disposition=bigquery.WriteDisposition.WRITE_APPEND,
        autodetect=True,
    )
    job = client.load_table_from_dataframe(df, full_table_id, job_config=job_config)
    job.result()

    print(f"Success Appended {len(df)} rows into {full_table_id}")
    
    filename = '/data/data_automation_bai/data_automation_scheduling/scripts/retail/master_kpi/3id_change_card_gcp.sql'
    fd = open(filename, 'r')
    sql_file = fd.read() 
    sql_file=sql_file.format(**{"year_month": year_month, 
                                "dt_id": dt_id
                                })
    fd.close() 
    query = sql_file.split(';') 
    
    print("00. Deleting iCare trx on 3id change card") 
    client.query(query[0]).result()
    
    print("01. Inserting iCare trx on 3id change card") 
    client.query(query[1]).result()
    
    print("02. Deleting change card kpi on mtd master kpi") 
    client.query(query[2]).result()
    
    print("03. Inserting change card kpi on mtd master kpi") 
    client.query(query[3]).result()
    
    print("04. Deleting change card kpi on dly master kpi") 
    client.query(query[4]).result()
    
    print("05. Inserting change card kpi on dly master kpi") 
    client.query(query[5]).result()
        
    
    status = 'finished'
    return status

@op(retry_policy=RetryPolicy(max_retries=3, delay=60))
def tri_revenue_service(status):
    print(status)
    print(dt_id)
    project_id = "data-nationalslsdist-prd-986g"
    client = bigquery.Client(project=project_id)
    print('Start Executing 3ID Master KPI on Cockpit') 
    filename = '/data/data_automation_bai/data_automation_scheduling/scripts/retail/master_kpi/3id_revenue_service.sql'
    fd = open(filename, 'r')
    sql_file = fd.read() 
    sql_file=sql_file.format(**{"year_month": year_month, 
                                "dt_id": dt_id
                                })
    fd.close() 
    query = sql_file.split(';') 
    print("01. Deleting tmp revenue services table") 
    client.query(query[0]).result()
    print("02. Creating tmp revenue services table") 
    client.query(query[1]).result()
    print("03. Dump revenue services KPI MTD")
    df=client.query(query[2]).to_dataframe()
    df['insert_dt']=dt.datetime.now()
    df['prt_dt']=pd.to_datetime(df['dt_id'], format='%Y-%m-%d').dt.date
    upload_kpi_data(dt_id, df.kpi_name.unique().tolist(), df.brand.unique().tolist(), df, 'mtd')
    print("04. Dump revenue services KPI DLY")
    df=client.query(query[3]).to_dataframe()
    df['insert_dt']=dt.datetime.now()
    df['prt_dt']=pd.to_datetime(df['dt_id'], format='%Y-%m-%d').dt.date
    upload_kpi_data(dt_id, df.kpi_name.unique().tolist(), df.brand.unique().tolist(), df, 'dly')
    status = 'finished'
    return status

@op(retry_policy=RetryPolicy(max_retries=3, delay=60))
def traffic_qmatic(status):
    print(status)
    print(dt_id)
    project_id = "data-nationalslsdist-prd-986g"
    client = bigquery.Client(project=project_id)
    print('Start Executing Traffic Qmatic') 
    filename = '/data/data_automation_bai/data_automation_scheduling/scripts/retail/master_kpi/traffic_qmatic.sql'
    fd = open(filename, 'r')
    sql_file = fd.read() 
    sql_file=sql_file.format(**{"year_month": year_month, 
                                "dt_id": dt_id
                                })
    fd.close() 
    query = sql_file.split(';') 
    print("01. Deleting tmp kpi traffic qmatic table") 
    client.query(query[0]).result()
    print("02. Creating tmp kpi traffic qmatic table") 
    client.query(query[1]).result()
    print("03. Updating value agent nik") 
    for i in range(2,11):
        print("query "+str(i))
        client.query(query[i]).result()
        time.sleep(5)
    print("03. Dump traffic qmatic KPI MTD")
    df=client.query(query[11]).to_dataframe()
    df['insert_dt']=dt.datetime.now()
    df['prt_dt']=pd.to_datetime(df['dt_id'], format='%Y-%m-%d').dt.date
    upload_kpi_data(dt_id, df.kpi_name.unique().tolist(), df.brand.unique().tolist(), df, 'mtd')
    print("04. Dump traffic qmatic KPI DLY")
    df=client.query(query[12]).to_dataframe()
    df['insert_dt']=dt.datetime.now()
    df['prt_dt']=pd.to_datetime(df['dt_id'], format='%Y-%m-%d').dt.date
    upload_kpi_data(dt_id, df.kpi_name.unique().tolist(), df.brand.unique().tolist(), df, 'dly')
    status = 'finished'
    return status

@op(retry_policy=RetryPolicy(max_retries=3, delay=60))
def google_rating(status):
    print(status)
    print(dt_id)
    project_id = "data-nationalslsdist-prd-986g"
    client = bigquery.Client(project=project_id)
    print('Start Executing Google Rating') 
    filename = '/data/data_automation_bai/data_automation_scheduling/scripts/retail/master_kpi/google_rating.sql'
    fd = open(filename, 'r')
    sql_file = fd.read() 
    sql_file=sql_file.format(**{"year_month": year_month, 
                                "dt_id": dt_id
                                })
    fd.close() 
    query = sql_file.split(';') 
    print("01. Dump Google Rating MTD")
    df=client.query(query[0]).to_dataframe()
    df['insert_dt']=dt.datetime.now()
    df['prt_dt']=pd.to_datetime(df['dt_id'], format='%Y-%m-%d').dt.date
    upload_kpi_data(dt_id, df.kpi_name.unique().tolist(), df.brand.unique().tolist(), df, 'mtd')
    status = 'finished'
    return status

@op(retry_policy=RetryPolicy(max_retries=3, delay=60))
def im3_revenue_cash_in():
    # print(status)
    print(dt_id)
    project_id = "data-nationalslsdist-prd-986g"
    client = bigquery.Client(project=project_id)
    print('Start Executing IM3 Revenue cash in on Cockpit') 
    filename = '/data/data_automation_bai/data_automation_scheduling/scripts/retail/master_kpi/im3_revenue_cash_in.sql'
    fd = open(filename, 'r')
    sql_file = fd.read() 
    sql_file=sql_file.format(**{"year_month": year_month, 
                                "dt_id": dt_id
                                })
    fd.close() 
    query = sql_file.split(';') 
    print("01. Deleting tmp revenue cash in im3 table") 
    client.query(query[0]).result()
    print("02. Creating tmp revenue cash in im3 table") 
    client.query(query[1]).result()
    print("03. Dump revenue cash in im3 KPI MTD")
    df=client.query(query[2]).to_dataframe()
    df['insert_dt']=dt.datetime.now()
    df['prt_dt']=pd.to_datetime(df['dt_id'], format='%Y-%m-%d').dt.date
    upload_kpi_data(dt_id, df.kpi_name.unique().tolist(), df.brand.unique().tolist(), df, 'mtd')
    print("04. Dump revenue cash in KPI DLY")
    df=client.query(query[3]).to_dataframe()
    df['insert_dt']=dt.datetime.now()
    df['prt_dt']=pd.to_datetime(df['dt_id'], format='%Y-%m-%d').dt.date
    upload_kpi_data(dt_id, df.kpi_name.unique().tolist(), df.brand.unique().tolist(), df, 'dly')
    status = 'finished'
    return status

@op(retry_policy=RetryPolicy(max_retries=3, delay=60))
def im3_change_card(status):
    print(status)
    print(dt_id)
    project_id = "data-nationalslsdist-prd-986g"
    client = bigquery.Client(project=project_id)
    print('Start Executing IM3 Change Card on GCP') 
    filename = '/data/data_automation_bai/data_automation_scheduling/scripts/retail/master_kpi/im3_change_card.sql'
    fd = open(filename, 'r')
    sql_file = fd.read() 
    sql_file=sql_file.format(**{"year_month": year_month, 
                                "dt_id": dt_id
                                })
    fd.close() 
    query = sql_file.split(';') 
    print("01. Deleting tmp change card im3 table") 
    client.query(query[0]).result()
    print("02. Creating tmp change card im3 table") 
    client.query(query[1]).result()
    print("03. Dump change card KPI MTD")
    df=client.query(query[2]).to_dataframe()
    df['insert_dt']=dt.datetime.now()
    df['prt_dt']=pd.to_datetime(df['dt_id'], format='%Y-%m-%d').dt.date
    upload_kpi_data(dt_id, df.kpi_name.unique().tolist(), df.brand.unique().tolist(), df, 'mtd')
    print("04. Dump change card KPI DLY")
    df=client.query(query[3]).to_dataframe()
    df['insert_dt']=dt.datetime.now()
    df['prt_dt']=pd.to_datetime(df['dt_id'], format='%Y-%m-%d').dt.date
    upload_kpi_data(dt_id, df.kpi_name.unique().tolist(), df.brand.unique().tolist(), df, 'dly')
    status = 'finished'
    return status

@op(retry_policy=RetryPolicy(max_retries=3, delay=60))
def im3_revenue_service(status):
    print(status)
    print(dt_id)
    project_id = "data-nationalslsdist-prd-986g"
    client = bigquery.Client(project=project_id)
    print('Start Executing IM3 Revenue Service on Cockpit') 
    filename = '/data/data_automation_bai/data_automation_scheduling/scripts/retail/master_kpi/im3_revenue_service.sql'
    fd = open(filename, 'r')
    sql_file = fd.read() 
    sql_file=sql_file.format(**{"year_month": year_month, 
                                "dt_id": dt_id
                                })
    fd.close() 
    query = sql_file.split(';') 
    print("01. Deleting tmp revenue Service im3 table") 
    client.query(query[0]).result()
    print("02. Creating tmp revenue Service im3 table") 
    client.query(query[1]).result()
    print("03. Dump revenue service im3 KPI MTD")
    df=client.query(query[2]).to_dataframe()
    df['insert_dt']=dt.datetime.now()
    df['prt_dt']=pd.to_datetime(df['dt_id'], format='%Y-%m-%d').dt.date
    upload_kpi_data(dt_id, df.kpi_name.unique().tolist(), df.brand.unique().tolist(), df, 'mtd')
    print("04. Dump revenue service KPI DLY")
    df=client.query(query[3]).to_dataframe()
    df['insert_dt']=dt.datetime.now()
    df['prt_dt']=pd.to_datetime(df['dt_id'], format='%Y-%m-%d').dt.date
    upload_kpi_data(dt_id, df.kpi_name.unique().tolist(), df.brand.unique().tolist(), df, 'dly')
    status = 'finished'
    return status

@op(retry_policy=RetryPolicy(max_retries=3, delay=60))
def im3_ga_postpaid(status):
    print(status)
    print(dt_id)
    project_id = "data-nationalslsdist-prd-986g"
    client = bigquery.Client(project=project_id)
    print('Start Executing IM3 GA Postpaid') 
    filename = '/data/data_automation_bai/data_automation_scheduling/scripts/retail/master_kpi/im3_ga_postpaid.sql'
    fd = open(filename, 'r')
    sql_file = fd.read() 
    sql_file=sql_file.format(**{"year_month": year_month, 
                                "dt_id": dt_id
                                })
    fd.close() 
    query = sql_file.split(';') 
    print("03. Dump IM3 GA Postpaid MTD")
    df=client.query(query[0]).to_dataframe()
    df['insert_dt']=dt.datetime.now()
    df['prt_dt']=pd.to_datetime(df['dt_id'], format='%Y-%m-%d').dt.date
    upload_kpi_data(dt_id, df.kpi_name.unique().tolist(), df.brand.unique().tolist(), df, 'mtd')
    print("02. Dump GA Postpaid KPI DLY")
    df=client.query(query[1]).to_dataframe()
    df['insert_dt']=dt.datetime.now()
    df['prt_dt']=pd.to_datetime(df['dt_id'], format='%Y-%m-%d').dt.date
    upload_kpi_data(dt_id, df.kpi_name.unique().tolist(), df.brand.unique().tolist(), df, 'dly')
    status = 'finished'
    return status

@op(retry_policy=RetryPolicy(max_retries=3, delay=60))
def im3_traffic_visitor(status):
    print(status)
    print(dt_id)
    project_id = "data-nationalslsdist-prd-986g"
    client = bigquery.Client(project=project_id)
    print('Start Executing IM3 Traffic Visitor') 
    filename = '/data/data_automation_bai/data_automation_scheduling/scripts/retail/master_kpi/im3_traffic_visitor.sql'
    fd = open(filename, 'r')
    sql_file = fd.read() 
    sql_file=sql_file.format(**{"year_month": year_month, 
                                "dt_id": dt_id
                                })
    fd.close() 
    query = sql_file.split(';') 
    print("03. Dump IM3 Traffic Visitor MTD")
    df=client.query(query[0]).to_dataframe()
    df['insert_dt']=dt.datetime.now()
    df['prt_dt']=pd.to_datetime(df['dt_id'], format='%Y-%m-%d').dt.date
    upload_kpi_data(dt_id, df.kpi_name.unique().tolist(), df.brand.unique().tolist(), df, 'mtd')
    print("02. Dump Traffic Visitor KPI DLY")
    df=client.query(query[1]).to_dataframe()
    df['insert_dt']=dt.datetime.now()
    df['prt_dt']=pd.to_datetime(df['dt_id'], format='%Y-%m-%d').dt.date
    upload_kpi_data(dt_id, df.kpi_name.unique().tolist(), df.brand.unique().tolist(), df, 'dly')
    status = 'finished'
    return status

@op(retry_policy=RetryPolicy(max_retries=3, delay=60))
def im3_csat_inhouse(status):
    print(status)
    try:
        ym_abv=pd.to_datetime(pd.Series(year_month, dtype=str), format="%Y%m").dt.strftime("%b'%Y") 
        ym_abv=ym_abv[0]
        print(ym_abv)
        os.system("rm -rf /data/retail/CSAT-*.xlsx")
        os.system(f'''rclone copy dsn:"Data/PBI 3KIOSK - MITRA IM3/CSAT" dsn:retail --include "CSAT-{ym_abv}.xlsx"''')
        os.system(f'''rclone copy dsn:retail /data/retail/ --include "CSAT-{ym_abv}.xlsx"''')
        df_csat=pd.read_excel(f"/data/retail/CSAT-{ym_abv}.xlsx", engine='openpyxl', usecols='A:O', dtype=str)
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
        df_csat['channel']=df_csat['channel'].str.upper()
        # df_csat=df_csat[df_csat['channel']=='GERAI IM3']
        df_csat['brand']='IM3'
        df_csat['prt_dt']=pd.to_datetime(df_csat['dt_id'], format='%Y-%m-%d').dt.date
        df_csat.rename(columns={'respond rate':'respond_rate'}, inplace=True)
        df_csat['delivered']=df_csat['delivered'].astype(float)
        df_csat['respond']=df_csat['respond'].astype(float)
        df_csat['happy']=df_csat['happy'].astype(float)
        df_csat['csat']=df_csat['csat'].astype(float)
        df_csat['respond_rate']=df_csat['respond_rate'].astype(float)
        # ==== BIGQUERY CONFIG ====
        project_id = "data-nationalslsdist-prd-986g"
        dataset_id = "retail"
        table_id="raw_im3_csat"
        full_table_id = f"{project_id}.{dataset_id}.{table_id}"
        client = bigquery.Client(project=project_id)
        # ==== DELETE ROWS BASED ON CONDITION ====
        delete_query = f"""
        DELETE FROM `{full_table_id}`
        WHERE left(dt_id,6) = left('{dt_id}',6) 
        """
        client.query(delete_query).result()
        print(f"Deleted rows in {full_table_id} where left(dt_id,6)='{dt_id[:6]}'")
        # ==== APPEND NEW DATA ====
        job_config = bigquery.LoadJobConfig(
            write_disposition=bigquery.WriteDisposition.WRITE_APPEND,
            autodetect=True,
        )
        job = client.load_table_from_dataframe(df_csat, full_table_id, job_config=job_config)
        job.result()

        print(f"Success Appended {len(df_csat)} rows into {full_table_id}")
        print(dt_id)
        project_id = "data-nationalslsdist-prd-986g"
        client = bigquery.Client(project=project_id)
        print('Start Executing IM3 CSAT Inhouse') 
        filename = '/data/data_automation_bai/data_automation_scheduling/scripts/retail/master_kpi/im3_csat_inhouse.sql'
        fd = open(filename, 'r')
        sql_file = fd.read() 
        sql_file=sql_file.format(**{"year_month": year_month, 
                                    "dt_id": dt_id
                                    })
        fd.close() 
        query = sql_file.split(';') 
        print("03. Dump IM3 CSAT Inhouse")
        df=client.query(query[0]).to_dataframe()
        df['insert_dt']=dt.datetime.now()
        df['prt_dt']=pd.to_datetime(df['dt_id'], format='%Y-%m-%d').dt.date
        upload_kpi_data(dt_id, df.kpi_name.unique().tolist(), df.brand.unique().tolist(), df, 'mtd')
    except Exception:
        traceback.print_exc()
    status = 'finished'
    return status

@op(retry_policy=RetryPolicy(max_retries=3, delay=60))
def im3_interaction(status):
    print(status)
    print(dt_id)
    project_id = "data-nationalslsdist-prd-986g"
    client = bigquery.Client(project=project_id)
    print('Start Executing IM3 Interaction') 
    filename = '/data/data_automation_bai/data_automation_scheduling/scripts/retail/master_kpi/im3_interaction.sql'
    fd = open(filename, 'r')
    sql_file = fd.read() 
    sql_file=sql_file.format(**{"year_month": year_month, 
                                "dt_id": dt_id
                                })
    fd.close() 
    query = sql_file.split(';') 
    print("01. Creating IM3 tmp interaction") 
    client.query(query[0]).result()
    print("01. Dump IM3 Interaction MTD")
    df=client.query(query[1]).to_dataframe()
    df['insert_dt']=dt.datetime.now()
    df['prt_dt']=pd.to_datetime(df['dt_id'], format='%Y-%m-%d').dt.date
    upload_kpi_data(dt_id, df.kpi_name.unique().tolist(), df.brand.unique().tolist(), df, 'mtd')
    print("02. Dump Interaction DLY")
    df=client.query(query[2]).to_dataframe()
    df['insert_dt']=dt.datetime.now()
    df['prt_dt']=pd.to_datetime(df['dt_id'], format='%Y-%m-%d').dt.date
    upload_kpi_data(dt_id, df.kpi_name.unique().tolist(), df.brand.unique().tolist(), df, 'dly')
    status = 'finished'
    return status

@op(retry_policy=RetryPolicy(max_retries=3, delay=60))
def im3_fcr_sr(status):
    print(status)
    print(dt_id)
    project_id = "data-nationalslsdist-prd-986g"
    client = bigquery.Client(project=project_id)
    print('Start Executing IM3 FCR SR') 
    filename = '/data/data_automation_bai/data_automation_scheduling/scripts/retail/master_kpi/im3_fcr_sr.sql'
    fd = open(filename, 'r')
    sql_file = fd.read() 
    sql_file=sql_file.format(**{"year_month": year_month, 
                                "dt_id": dt_id
                                })
    fd.close() 
    query = sql_file.split(';') 
    print("01. Creating IM3 tmp SR TT") 
    client.query(query[0]).result()
    print("01. Dump IM3 FCR SR MTD")
    df=client.query(query[1]).to_dataframe()
    df['insert_dt']=dt.datetime.now()
    df['prt_dt']=pd.to_datetime(df['dt_id'], format='%Y-%m-%d').dt.date
    upload_kpi_data(dt_id, df.kpi_name.unique().tolist(), df.brand.unique().tolist(), df, 'mtd')
    status = 'finished'
    return status

@op(retry_policy=RetryPolicy(max_retries=3, delay=60))
def mystery_shopper(status):
    print(status)
    try:
        ym_1 = pd.to_datetime(pd.Series(year_month), format="%Y%m") \
            .apply(lambda x: (x - pd.DateOffset(months=1)).strftime("%Y%m")) \
            .tolist()
        ym_abv=pd.to_datetime(pd.Series(ym_1, dtype=str), format="%Y%m").dt.strftime("%b %Y") 
        ym_abv=ym_abv[0]
        os.system("rm -rf /data/retail/Myshopp_*.xlsx")
        os.system(f'''rclone copy dsn:"Data/PBI 3KIOSK - MITRA IM3/Mystery Shopper" dsn:retail --include Myshopp_*.xlsx''')
        os.system(f'''rclone copy dsn:retail /data/retail --include Myshopp_*.xlsx''')
        df_myshop=pd.read_excel(f'/data/retail/Myshopp_{ym_abv}.xlsx', engine='openpyxl')
        df_myshop.columns=['periode', 'store_name', 'store_code', 'channel', 'circle', 'region', 'score']
        df_myshop['mth_cal']=pd.to_datetime(df_myshop['periode'], format="%Y%m") \
                .apply(lambda x: (x + pd.DateOffset(months=1)).strftime("%Y%m")) \
                .tolist()
        df_myshop['brand']=df_myshop['channel'].apply(lambda x: '3ID' if str(x).lower()=='3store' else 'IM3')
        df_myshop['score']=pd.to_numeric(df_myshop['score'].replace('-', np.nan), errors='coerce')
        df=df_myshop[['store_code','score', 'brand']].copy() 
        df['dt_id']=dt_id
        df['kpi_name']='mystery_shopper'
        df['level']='store'
        df['value']=df['score']
        df['agent_id']= nan
        df = df[['dt_id', 'kpi_name', 'level', 'agent_id', 'store_code', 'brand', 'value']]
        df['insert_dt']=dt.datetime.now()
        df['prt_dt']=pd.to_datetime(df['dt_id'], format='%Y-%m-%d').dt.date
        upload_kpi_data(dt_id, df.kpi_name.unique().tolist(), df.brand.unique().tolist(), df, 'mtd')
    except Exception:
        traceback.print_exc()
    status = 'finished'
    return status

@op(retry_policy=RetryPolicy(max_retries=3, delay=60))
def im3_rev_billed_postpaid(status):
    print(status)
    print(dt_id)
    project_id = "data-nationalslsdist-prd-986g"
    client = bigquery.Client(project=project_id)
    print('Start Executing IM3 Revenue Service on Cockpit') 
    filename = '/data/data_automation_bai/data_automation_scheduling/scripts/retail/master_kpi/im3_revenue_billed_postpaid.sql'
    fd = open(filename, 'r')
    sql_file = fd.read() 
    sql_file=sql_file.format(**{"year_month": year_month, 
                                "dt_id": dt_id
                                })
    fd.close() 
    query = sql_file.split(';') 
    print("01. Deleting IM3 billed postpaid") 
    client.query(query[0]).result()
    print("02. Inserting IM3 billed postpaid") 
    client.query(query[1]).result()
    print("03. Dump IM3 billed postpaid")
    df=client.query(query[2]).to_dataframe()
    df['insert_dt']=dt.datetime.now()
    df['prt_dt']=pd.to_datetime(df['dt_id'], format='%Y-%m-%d').dt.date
    upload_kpi_data(dt_id, df.kpi_name.unique().tolist(), df.brand.unique().tolist(), df, 'mtd')
    status = 'finished'
    return status

@op(retry_policy=RetryPolicy(max_retries=3, delay=60))
def tri_traffic_visitor_dvm(status):
    print(status)
    print(dt_id)
    try:
        print('Start Executing 3ID Traffic Visitor DVM on Cockpit') 
        filename = '/data/data_automation_bai/data_automation_scheduling/scripts/retail/master_kpi/3id_traffic_visitor_dvm.sql'
        fd = open(filename, 'r')
        sql_file = fd.read() 
        sql_file=sql_file.format(**{"year_month": year_month, 
                                    "dt_id": dt_id
                                    })
        fd.close() 
        query = sql_file.split(';') 
        print("01. Dump 3ID Traffic Visitor DVM MTD")
        df=cockpit_get_df(query[0])
        df['insert_dt']=dt.datetime.now()
        df['prt_dt']=pd.to_datetime(df['dt_id'], format='%Y-%m-%d').dt.date
        upload_kpi_data(dt_id, df.kpi_name.unique().tolist(), df.brand.unique().tolist(), df, 'mtd')
        print("02. Dump 3ID Traffic Visitor DLY")
        df=cockpit_get_df(query[1])
        df['insert_dt']=dt.datetime.now()
        df['prt_dt']=pd.to_datetime(df['dt_id'], format='%Y-%m-%d').dt.date
        upload_kpi_data(dt_id, df.kpi_name.unique().tolist(), df.brand.unique().tolist(), df, 'dly')
    except Exception:
        traceback.print_exc()
    status = 'finished'
    return status

@op(retry_policy=RetryPolicy(max_retries=3, delay=60))
def tri_dvm_to_agent(status):
    print(status)
    print(dt_id)
    try:
        project_id = "data-nationalslsdist-prd-986g"
        client = bigquery.Client(project=project_id)
        print('Start 3ID DVM Value to Agent') 
        filename = '/data/data_automation_bai/data_automation_scheduling/scripts/retail/master_kpi/3id_dvm_to_agent.sql'
        fd = open(filename, 'r')
        sql_file = fd.read() 
        sql_file=sql_file.format(**{"year_month": year_month, 
                                    "dt_id": dt_id
                                    })
        fd.close() 
        query = sql_file.split(';') 
        print("01. Deleting 3ID DVM to Agent") 
        client.query(query[0]).result()
        print("02. Inserting 3ID DVM to Agent") 
        client.query(query[1]).result()
        print("Job Finished ................")
    except Exception:
        traceback.print_exc()
    status = 'finished'
    return status

@op(retry_policy=RetryPolicy(max_retries=3, delay=60))
def tri_conversion_rate(status):
    print(status)
    print(dt_id)
    project_id = "data-nationalslsdist-prd-986g"
    client = bigquery.Client(project=project_id)
    print('Start 3ID COnversion Rate to Agent') 
    filename = '/data/data_automation_bai/data_automation_scheduling/scripts/retail/master_kpi/3id_conversion_rate.sql'
    fd = open(filename, 'r')
    sql_file = fd.read() 
    sql_file=sql_file.format(**{"year_month": year_month, 
                                "dt_id": dt_id
                                })
    fd.close() 
    query = sql_file.split(';') 
    print("01. Deleting 3ID Conversion Rate") 
    client.query(query[0]).result()
    print("02. Inserting 3ID Conversion Rate") 
    client.query(query[1]).result()
    print("Job Finished ................")
    status = 'finished'
    return status

@op(retry_policy=RetryPolicy(max_retries=3, delay=60))
def im3_conversion_rate(status):
    print(status)
    print(dt_id)
    project_id = "data-nationalslsdist-prd-986g"
    client = bigquery.Client(project=project_id)
    print('Start IM3 COnversion Rate to Agent') 
    filename = '/data/data_automation_bai/data_automation_scheduling/scripts/retail/master_kpi/im3_conversion_rate.sql'
    fd = open(filename, 'r')
    sql_file = fd.read() 
    sql_file=sql_file.format(**{"year_month": year_month, 
                                "dt_id": dt_id
                                })
    fd.close() 
    query = sql_file.split(';') 
    print("01. Deleting IM3 Conversion Rate") 
    client.query(query[0]).result()
    print("02. Inserting IM3 Conversion Rate") 
    client.query(query[1]).result()
    print("Job Finished ................")
    status = 'finished'
    return status

@op(retry_policy=RetryPolicy(max_retries=3, delay=60))
def rev_others_ftth(status):
    print(status)
    print(dt_id)
    project_id = "data-nationalslsdist-prd-986g"
    client = bigquery.Client(project=project_id)
    print('Start Revenue Others FTTH') 
    filename = '/data/data_automation_bai/data_automation_scheduling/scripts/retail/master_kpi/rev_others_ftth.sql'
    fd = open(filename, 'r')
    sql_file = fd.read() 
    sql_file=sql_file.format(**{"year_month": year_month, 
                                "dt_id": dt_id
                                })
    fd.close() 
    query = sql_file.split(';') 
    print("01. Deleting Revenue Others FTTH") 
    client.query(query[0]).result()
    print("02. Inserting Revenue Others FTTH") 
    client.query(query[1]).result()
    print("Job Finished ................")
    status = 'finished'
    return status

@op(retry_policy=RetryPolicy(max_retries=3, delay=60))
def monthly_quiz(status):
    print(status)
    print(dt_id)
    try:
        df_3id=pd.read_excel(f"/data/retail/monthly_quiz/Monthly QUIZ 3Store {year_month}.xlsx", engine="openpyxl")
        df_3id.columns=[
            'first_name',
            'last_name',
            'id_number',
            'institution', 
            'department',
            'email_address',
            'score',
            'download_id'
        ]
        df_3id['idx']=df_3id['email_address'].str.split("@").str[0]
        df_3id['brand_check']='3ID'
        df_im3=pd.read_excel(f"/data/retail/monthly_quiz/Monthly QUIZ Gerai IM3 {year_month}.xlsx", engine="openpyxl")
        df_im3.columns=[
            'first_name',
            'last_name',
            'id_number',
            'institution', 
            'department',
            'email_address',
            'score',
            'download_id'
        ]
        df_im3['idx']=df_im3['email_address'].str.split("@").str[0]
        df_im3['brand_check']='IM3'

        df=pd.concat([df_3id, df_im3])
        df=df[df['score']!='-']
        df.reset_index(inplace=True, drop=True)
        query=f'''
            select 
                a.*, b.status as channel_type
            from `data-nationalslsdist-prd-986g`.retail.ref_agent_spv as a
                left join (
                    select * except (idx) from (
                        select
                            a.store_code,
                            a.status,
                            row_number() over(partition by a.store_code order by a.mth_id desc) as idx
                        from `data-nationalslsdist-prd-986g`.retail.ref_store_mth as a
                    ) as x where x.idx=1
                ) as b on a.store_code = b.store_code
                where mth_id=left('{dt_id}',6)
        '''
        project_id = "data-nationalslsdist-prd-986g"
        dataset_id = "retail"
        table_id="raw_monthly_quiz"
        full_table_id = f"{project_id}.{dataset_id}.{table_id}"
        client = bigquery.Client(project=project_id)

        df_agent = client.query(query).to_dataframe()
        map_agent=df_agent[['circle',
                            'region',
                            'store_code',
                            'store_name',
                            'channel_type',
                            'agent_nik',
                            'agent_name',
                            'agent_id',
                            'agent_monthly_quiz',
                            'brand']].copy()
        df['idx_norm']=df['idx'].str.lower().str.replace(r"[^a-z0-9]", "", regex=True)
        map_agent['agent_monthly_quiz_norm']=map_agent['agent_monthly_quiz'].str.lower().str.replace(r"[^a-z0-9]", "", regex=True)
        df1=df.merge(map_agent, left_on='idx_norm',
                right_on='agent_monthly_quiz_norm',
                how='inner')
        df1.drop(columns=['idx_norm', 'agent_monthly_quiz_norm'], inplace=True)
        df.drop(columns=['idx_norm'], inplace=True)
        map_agent.drop(columns=['agent_monthly_quiz_norm'], inplace=True)
        df=df[~df['email_address'].isin(df1['email_address'])]
        df['name_norm']=df['first_name'].str.lower().str.replace(r"[^a-z0-9]", "", regex=True)
        map_agent['name_norm']=map_agent['agent_name'].str.lower().str.replace(r"[^a-z0-9]", "", regex=True)
        df2=df.merge(map_agent, on='name_norm',
                how='inner')
        df2.drop(columns=['name_norm'], inplace=True)
        df.drop(columns=['name_norm'], inplace=True)
        map_agent.drop(columns=['name_norm'], inplace=True)
        df=df[~df['email_address'].isin(df2['email_address'])]
        df['id_norm']=df['idx'].str.lower().str.replace(r"[^a-z0-9]", "", regex=True)
        map_agent['id_norm']=map_agent['agent_id'].str.lower().str.replace(r"[^a-z0-9]", "", regex=True)
        df3=df.merge(map_agent, on='id_norm',
                how='inner')
        df3.drop(columns=['id_norm'], inplace=True)
        df.drop(columns=['id_norm'], inplace=True)
        map_agent.drop(columns=['id_norm'], inplace=True)
        df=df[~df['email_address'].isin(df3['email_address'])]
        df['id_norm']=df['email_address'].str.lower()
        map_agent['id_norm']=map_agent['agent_monthly_quiz'].str.lower()
        df.merge(map_agent, on='id_norm',
                how='inner')
        df1=df1[['agent_name', 'store_code', 'agent_nik', 'channel_type', 'store_name', 'region', 'circle', 'score', 'brand']]
        df2=df2[['agent_name', 'store_code', 'agent_nik', 'channel_type', 'store_name', 'region', 'circle', 'score', 'brand']]
        df3=df3[['agent_name', 'store_code', 'agent_nik', 'channel_type', 'store_name', 'region', 'circle', 'score', 'brand']]
        df_all=pd.concat([df1, df2, df3])
        query=f'''
            select * except (idx) from (
                select
                    a.agent_name, 
                    a.store_code, 
                    a.agent_nik,
                    a.channel_type,
                    a.store_name, 
                    a.new_region as region,
                    a.circle,
                    a.brand,
                    row_number() over(partition by upper(trim(a.agent_name)) order by a.mth_id desc) idx
                from `data-nationalslsdist-prd-986g`.retail.raw_monthly_quiz as a
                    where a.agent_name is not null
            ) as x where x.idx=1
        '''
        project_id = "data-nationalslsdist-prd-986g"
        dataset_id = "retail"
        table_id="raw_monthly_quiz"
        full_table_id = f"{project_id}.{dataset_id}.{table_id}"
        client = bigquery.Client(project=project_id)

        map_old = client.query(query).to_dataframe()
        df['name']=df['first_name'].str.lower().str.lstrip().str.rstrip()
        map_old['name']=map_old['agent_name'].str.lower().str.lstrip().str.rstrip()
        df=df.merge(map_old, on='name', how='left')
        df["agent_name"]=df["agent_name"].fillna(df["first_name"]+" "+df["last_name"])
        df["store_code"]=df["store_code"].fillna(df["department"])
        df["agent_nik"]=df["agent_nik"].fillna(df["idx"])
        df["store_name"]=df["store_name"].fillna(df["institution"])
        df=df[['agent_name', 'store_code', 'agent_nik', 'channel_type', 'store_name', 'region', 'circle', 'score', 'brand']]
        df_all=pd.concat([df_all, df])
        mask_brand_null = df_all["brand"].isna()
        df_all.loc[
            mask_brand_null & df_all["store_name"].str.lower().str.contains("3store", na=False),
            "brand"
        ] = "3ID"

        df_all.loc[
            mask_brand_null & df_all["store_name"].str.lower().str.contains("gerai", na=False),
            "brand"
        ] = "IM3"
        df_all['score']=df_all['score'].astype(float)*10
        df_all['mth_id']=year_month
        df_all=df_all.rename(columns={'region':'new_region'})
        df_all=df_all[['mth_id', 'agent_name', 'store_code', 'agent_nik', 'channel_type', 'store_name', 'new_region', 'circle', 'score', 'brand']]
        project_id = "data-nationalslsdist-prd-986g"
        dataset_id = "retail"
        table_id = "raw_monthly_quiz"
        client = bigquery.Client(project=project_id)
        full_table_id = f"{project_id}.{dataset_id}.{table_id}"
        delete_query = f"""
                DELETE FROM `{full_table_id}`
                WHERE mth_id = '{year_month}' 
                """
        print(delete_query)
        client.query(delete_query).result()
        # ==== APPEND NEW DATA ====
        job_config = bigquery.LoadJobConfig(
            write_disposition=bigquery.WriteDisposition.WRITE_APPEND,
            autodetect=True,
        )
        job = client.load_table_from_dataframe(df_all, full_table_id, job_config=job_config)
        job.result()

        print(f"Success Appended {len(df_all)} rows into {full_table_id}")

        project_id = "data-nationalslsdist-prd-986g"
        client = bigquery.Client(project=project_id)
        print('Start Monthly Quiz For All Brand') 
        filename = '/data/data_automation_bai/data_automation_scheduling/scripts/retail/master_kpi/monthly_quiz.sql'
        fd = open(filename, 'r')
        sql_file = fd.read() 
        sql_file=sql_file.format(**{"year_month": year_month, 
                                    "dt_id": dt_id
                                    })
        fd.close() 
        query = sql_file.split(';') 
        print("01. Deleting Monthly Quiz") 
        client.query(query[0]).result()
        print("02. Inserting Monthly Quiz") 
        client.query(query[1]).result()
        print("Job Finished ................") 
    except Exception:
        traceback.print_exc()
    status = 'finished'
    return status

@op(retry_policy=RetryPolicy(max_retries=3, delay=60))
def extract_all(status):
    print(status)
    print(dt_id)
    query=f'''
        select 
            a.* except(insert_dt, prt_dt),
            b.store_name,
            b.region,
            b.circle,
            b.status_2 as store_type
        from `data-bi-prd-935c.bi_snd.rtl_raw_master_kpi_mtd` as a
            left join `data-nationalslsdist-prd-986g`.retail.ref_storelist as b on a.store_code=b.store_code
                and b.mth_id=left('{dt_id}',6)
            where dt_id='{dt_id}'
                and kpi_name not in ('sr_ontime')
                and level='store'
    '''
    project_id = "data-bi-prd-935c"
    dataset_id = "bi_snd"
    table_id="rtl_raw_master_kpi_mtd"
    full_table_id = f"{project_id}.{dataset_id}.{table_id}"
    client = bigquery.Client(project=project_id)
    df_store = client.query(query).to_dataframe() 
    df_store.to_excel(f"/data/retail/retail_kpi_store_{dt_id}.xlsx", 
        index=False)
    os.system(f'''rclone copy /data/retail/retail_kpi_store_{dt_id}.xlsx dsn:retail/''') 
    os.system(f'''rclone copy dsn:retail/retail_kpi_store_{dt_id}.xlsx dsn:"Retail Performance Management - R100/retail_kpi"''')  

    query=f'''
        select 
            a.* except(insert_dt, prt_dt),
            b.store_name,
            b.region,
            b.circle,
            b.status_2 as store_type
        from `data-bi-prd-935c.bi_snd.rtl_raw_master_kpi_mtd` as a
            left join `data-nationalslsdist-prd-986g`.retail.ref_storelist as b on a.store_code=b.store_code
            and b.mth_id=left('{dt_id}',6)
            where dt_id='{dt_id}'
                and kpi_name not in ('sr_ontime')
                and level='agent'
    '''
    project_id = "data-bi-prd-935c"
    dataset_id = "bi_snd"
    table_id="rtl_raw_master_kpi_mtd"
    full_table_id = f"{project_id}.{dataset_id}.{table_id}"
    client = bigquery.Client(project=project_id)
    df_agent = client.query(query).to_dataframe() 
    df_agent.to_excel(f"/data/retail/retail_kpi_agent_{dt_id}.xlsx", 
        index=False)
    os.system(f'''rclone copy /data/retail/retail_kpi_agent_{dt_id}.xlsx dsn:retail/''') 
    os.system(f'''rclone copy dsn:retail/retail_kpi_agent_{dt_id}.xlsx dsn:"Retail Performance Management - R100/retail_kpi"''') 

    query=f'''
        select 
            a.* except(insert_dt, prt_dt),
            b.store_name,
            b.region,
            b.circle,
            b.status_2 as store_type
        from `data-bi-prd-935c.bi_snd.rtl_raw_master_kpi_mtd` as a
            left join `data-nationalslsdist-prd-986g`.retail.ref_storelist as b on a.store_code=b.store_code
            and b.mth_id=left('{dt_id}',6)
            where dt_id='{dt_id}'
                and kpi_name not in ('sr_ontime')
                and level like '%dvm%'
    '''
    project_id = "data-bi-prd-935c"
    dataset_id = "bi_snd"
    table_id="rtl_raw_master_kpi_mtd"
    full_table_id = f"{project_id}.{dataset_id}.{table_id}"
    client = bigquery.Client(project=project_id)
    df_dvm = client.query(query).to_dataframe() 
    df_dvm.to_excel(f"/data/retail/retail_kpi_dvm_{dt_id}.xlsx", 
        index=False)
    os.system(f'''rclone copy /data/retail/retail_kpi_dvm_{dt_id}.xlsx dsn:retail/''') 
    os.system(f'''rclone copy dsn:retail/retail_kpi_dvm_{dt_id}.xlsx dsn:"Retail Performance Management - R100/retail_kpi"''') 
    print("Job Finished ................") 
    status = 'finished'
    return status

@graph
def retail_raw_master_kpi():
    # first_satus='start'
    # t1=im3_revenue_cash_in()
    # t2=im3_change_card(t1)
    # t3=im3_revenue_service(t2)
    # t4=im3_ga_postpaid(t3)
    # t5=im3_traffic_visitor(t4)
    # t6=im3_interaction(t5)
    # t7=im3_fcr_sr(t6)
    # t8=im3_rev_billed_postpaid(t7)
    # t9=im3_conversion_rate(t8)
    # t10=tri_revenue_cash_in(t9)
    # t11=tri_ga_prepaid(t10)
    # t12=tri_traffic_visitor(t11)
    # t13=tri_csat_inhouse(t12)
    # t14=tri_interaction(t13)
    # t15=tri_fcr_sr(t14)
    # t16=tri_change_card(t15)
    # t17=tri_revenue_service(t16)
    # t18=tri_traffic_visitor_dvm(t17)
    # t19=tri_dvm_to_agent(t18) 
    # t20=tri_conversion_rate(t19)
    # t21=traffic_qmatic(t20)
    # t22=google_rating(t21)
    # t23=im3_csat_inhouse(t22)
    # t24=mystery_shopper(t23)
    out_im3_revenue_cash_in=im3_revenue_cash_in()
    out_im3_change_card=im3_change_card(out_im3_revenue_cash_in)
    out_im3_revenue_service=im3_revenue_service(out_im3_change_card)
    out_im3_ga_postpaid=im3_ga_postpaid(out_im3_revenue_service)
    out_im3_traffic_visitor=im3_traffic_visitor(out_im3_ga_postpaid)
    out_im3_interaction=im3_interaction(out_im3_traffic_visitor)
    out_im3_fcr_sr=im3_fcr_sr(out_im3_interaction)
    out_im3_rev_billed_postpaid=im3_rev_billed_postpaid(out_im3_fcr_sr)
    out_im3_conversion_rate=im3_conversion_rate(out_im3_rev_billed_postpaid) 
    out_rgst_data=rgst_data(out_im3_conversion_rate)
    out_traffic_qmatic=traffic_qmatic(out_rgst_data)
    out_tri_revenue_cash_in=tri_revenue_cash_in(out_traffic_qmatic)
    out_tri_ga_prepaid=tri_ga_prepaid(out_tri_revenue_cash_in)
    out_tri_traffic_visitor=tri_traffic_visitor(out_tri_ga_prepaid)
    out_tri_csat_inhouse=tri_csat_inhouse(out_tri_traffic_visitor)
    out_tri_interaction=tri_interaction(out_tri_csat_inhouse)
    out_tri_fcr_sr=tri_fcr_sr(out_tri_interaction)
    out_tri_change_card=tri_change_card(out_tri_fcr_sr)
    out_tri_revenue_service=tri_revenue_service(out_tri_change_card)
    out_tri_traffic_visitor_dvm=tri_traffic_visitor_dvm(out_tri_revenue_service)
    out_tri_dvm_to_agent=tri_dvm_to_agent(out_tri_traffic_visitor_dvm)
    out_tri_conversion_rate=tri_conversion_rate(out_tri_dvm_to_agent)
    out_rev_others_ftth=rev_others_ftth(out_tri_conversion_rate)
    out_google_rating=google_rating(out_rev_others_ftth)
    out_im3_csat_inhouse=im3_csat_inhouse(out_google_rating)
    out_mystery_shopper=mystery_shopper(out_im3_csat_inhouse)
    out_monthly_quiz=monthly_quiz(out_mystery_shopper)
    extract_all(out_monthly_quiz)

    