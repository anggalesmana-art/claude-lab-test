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
from data_automation_scheduling.jobs.retail.retail_3id_kpi import tri_retail_report
from data_automation_scheduling.jobs.retail.retail_im3_kpi import im3_retail_report
from data_automation_scheduling.jobs.retail.retail_sdp_interactions import retail_interactions


# Get data D-2 
year_month=(dt.date.today() - timedelta(days = 2)).strftime("%Y%m") 
dt_id = (dt.date.today() - timedelta(days = 2)).strftime("%Y%m%d")  

# Rerun manual
# year_month="202510"
# dt_id ="20251031" 

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
        
# def hdp_get_df(query):
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

# def hdp_execute_query(query):
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

import paramiko
import pandas as pd
import io

def hdp_execute_query(query):
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

def hdp_get_df(query):
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

## Function for grab, read, and execute data in Cockpit
# Cockpit SSH and MySQL connection settings
ssh_host = '10.0.144.159'         # SSH host
ssh_port = 22                     # SSH port (default is 22)
ssh_user = 'dinar'    # SSH username
ssh_password = 'BI@Bersatu2026'  # SSH password (optional if using key)
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

# def cockpit_connect_and_tunnel():
#     # Establish SSH tunnel
#     tunnel = SSHTunnelForwarder(
#         (ssh_host, ssh_port),
#         ssh_username=ssh_user,
#         ssh_password=ssh_password if ssh_key_path is None else None,
#         ssh_pkey=ssh_key_path,
#         remote_bind_address=(mysql_host, mysql_port),
#         local_bind_address=('127.0.0.1', 3308)  # Port forwarding to local port 3307
#     )
#     try: 
#         tunnel.start()
#         print("SSH Tunnel established on port 3308")
#         # Connect to MySQL through SQLAlchemy
#         engine = create_engine(
#             f"mysql+pymysql://{mysql_user}:{mysql_password}@127.0.0.1:3308/{mysql_database}"
#         )
#         connection = engine.connect()
#         print("MySQL connection established")
#         return tunnel, connection

#     except Exception as e:
#         if tunnel.is_active:
#             tunnel.stop()
#         raise e   

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

@op
def t0_gp_3id_sce_ga(input_task):
    print(input_task)   
    filename = '/data/data_automation_bai/data_automation_scheduling/scripts/retail/retail_3id_sdp_sce_ga.sql'
    fd = open(filename, 'r')
    sql_file = fd.read() 
    sql_file=sql_file.format(**{"year_month": year_month, 
                                "dt_id": dt_id
                                })
    fd.close() 
    query = sql_file.split(';') 

    print(f'Deleting row in table 3id marketing.rtl_sce_sdp where mth_id : {year_month}')
    execute_sql(query[0]) 

    print(f'Inserting row in table 3id marketing.rtl_sce_sdp where mth_id : {year_month}') 
    execute_sql(query[1]) 

    status_job = 't0_3id_sce_ga : success'
    print(status_job) 
    
    df=fetch_data_as_dataframe(query[2]) 
    df.to_excel(f"/data/retail/3id_sce_ga_{year_month}.xlsx", 
         index=False)
    os.system(f'''rclone copy /data/retail/3id_sce_ga_{year_month}.xlsx dsn:retail/kpi_retail/sce_ga_sdp/''') 
    
    os.system(f'''rclone copy dsn:retail/kpi_retail/sce_ga_sdp/3id_sce_ga_{year_month}.xlsx dsn:"Retail Performance Management - R100/sce_ga_sdp"''')  
    
    # local_file = f"/data/retail/3id_sce_ga_{year_month}.xlsx"
    # remote_path = f"\\\\{server}\\S100\\{share}\\3id_sce_ga_{year_month}.xlsx"
    # # Configure SMB authentication
    # smbclient.ClientConfig(username=username, password=password)
    # # Upload file
    # with open(local_file, "rb") as src, smbclient.open_file(remote_path, mode="wb") as dst:
    #     shutil.copyfileobj(src, dst)
    print("File uploaded successfully!") 
    
    os.system(f'''rm -rf /data/retail/3id_sce_ga_{year_month}.xlsx)''') 
    return status_job 

@op
def t1_gp_3id_sim_rev(last_task):
    print(last_task)
    bq_project = "data-nationalslsdist-prd-986g"
    client = bigquery.Client(project=bq_project)
    
    print('Starting SIM Replacement 3ID on GCP')
    query = f"""
        select 
            a.msisdn, 
            case when a.source_channel like '%dvm%' then a.agent_id 
                else a.store_code end as dealercode,
            'SIM Replacement' as calltypetier3, 
            left(a.change_dt, 6) as simrepl_month_id,
            a.source_channel as source, 
            sum(a.rev_service) as prepaid_rev,
            left(a.rev_dt, 6) as rev_month
        from `data-nationalslsdist-prd-986g`.retail.raw_3id_rev_service as a
            where left(a.rev_dt,6)=left('{dt_id}',6)
        group by all
    """
    # # Run query and return DataFrame
    df_rev = client.query(query).to_dataframe() 
    df_rev.to_csv(f"/data/retail/dm_3id_simcard_replacement_revenue_{year_month}.csv", 
         index=False)
    os.system(f'''rclone copy /data/retail/dm_3id_simcard_replacement_revenue_{year_month}.csv dsn:retail/kpi_retail/sim_replacement_rev/''') 

    os.system(f'''rclone copy dsn:retail/kpi_retail/sim_replacement_rev/dm_3id_simcard_replacement_revenue_{year_month}.csv dsn:"Data/SIM Card Replacement (Revenue)/3ID"''')  
    print("File uploaded successfully!") 

    os.system(f'''rclone copy dsn:retail/kpi_retail/sim_replacement_rev/dm_3id_simcard_replacement_revenue_{year_month}.csv dsn:"Retail Performance Management - R100/sim_replacement_rev"''')  
    # os.system(f'''rm -rf /data/retail/dm_3id_simcard_replacement_revenue_{year_month}.csv''')

    status_job = 'Job running successfully'
    return status_job 

# def t1_gp_3id_sim_rev(last_task):
#     print(last_task)
#     query=f''' 
#         SELECT
#         case 
#             when left(customerid,3)='089' then concat('62',substr(customerid,2,100)) 
#             when left(customerid,3)='628' then customerid
#             else customerid
#         end msisdn,
#         terminal_code as dealercode, product_name as calltypetier3, replace(substring(date_trx,1,7),'-','') simrepl_month_id, 'DVM' source_channel,
#         max(date_format(date_trx, '%Y%m%d')) as simrepl_dt
#         FROM cockpit_archieve.raw_3db_trx T1
#                 left join cockpit_archieve.master_3db_terminal as T2 on T1.terminal_code=T2.code
#             Where replace(substring(date_trx,1,7),'-','')  = '{year_month}'
#             and date_format(date_trx, '%Y%m%d') <='{dt_id}'
#             and product_code <> 'VALIDITY_KTP'
#             and product_code IN ('THREE_CHANGE_CARD','THREE_SIMCARD4G', 'THREE_CHANGE_CARD_O2O', 'Upgrade 4G O2O')
#             and result = 'success'
#             and state='Done'
#         group by 1, 2, 3, 4, 5
#         union all 
#         SELECT distinct msisdn, dealercode, calltypetier3, replace(substring(Opened,1,7),'-','') simrepl_month_id, 'SIEBEL' source_channel,
#         max(date_format(Opened, '%Y%m%d')) as simrepl_dt
#             FROM cockpit.raw_sr_opened
#             where replace(substring(Opened,1,7),'-','')  ='{year_month}'
#             and date_format(Opened, '%Y%m%d') <= '{dt_id}'
#             and CallTypeTier3 = 'Replacement SIM Card'
#             and STATUS = 'Closed'
#         group by 1, 2, 3, 4, 5
#         union all 
#         select 
#             -- a.user_contact as msisdn,
#             case 
#                 when left(trim(a.user_contact),3)='089' then concat('62',substr(trim(a.user_contact),2,100)) 
#                 when left(trim(a.user_contact),3)='628' then trim(a.user_contact)
#                 else trim(a.user_contact)
#             end msisdn,
#             coalesce(ma.store_code, mb.dealercode) as dealercode, 
#             a.subcat as calltypetier3, 
#             date_format(a.opened_time, '%Y%m') simrepl_month_id,
#             'CSTOOLS' as source_channel, 
#             max(date_format(a.opened_time, '%Y%m%d')) as dt_id
#         from cockpit_archieve.cstools_raw_tickets as a 
#             left join (
#                 select 
#                 distinct msisdn, CreatedBy
#                 FROM cockpit.raw_sr_opened
#                     where replace(substring(Opened,1,7),'-','')=left('{dt_id}',6)
#                     and date_format(Opened, '%Y%m%d')<='{dt_id}'
#                     and CallTypeTier3 = 'Replacement SIM Card'
#                     and STATUS = 'Closed'
#             ) as b
#                 on a.user_contact = b.msisdn and a.opened_by=b.CreatedBy 
#             left join cockpit.mapping_agent_nik ma
#                 on  case when left(upper(a.opened_by),4)='MPBS' then UPPER(CONCAT('MBPS', SUBSTRING(TRIM(REPLACE(REPLACE(a.opened_by, '-', ''), '_', '')), 5)))
#                 else upper(TRIM(REPLACE(REPLACE(a.opened_by, '-', ''), '_', ''))) end = upper(ma.idx)
#             left join cockpit.master_agent mb
#                 on a.opened_by = mb.siebel_id 
#         where 1=1
#             and DATE_FORMAT(a.opened_time, '%Y%m%d') >= '20251101'
#             and DATE_FORMAT(a.opened_time, '%Y%m') = left('{dt_id}',6)
#             and DATE_FORMAT(a.opened_time, '%Y%m%d') <= '{dt_id}' 
#             and a.source='3Store' 
#             and (lower(a.subcat) like '%sim%replacement%' or lower(a.subcat) like '%replacement%sim%')
#             and a.status_text='Close'
#             and b.msisdn is null
#         group by 1, 2, 3, 4, 5
#         ;
#     ''' 
#     df = cockpit_get_df(query)
#     query=f'''
#     delete from marketing.dm_3id_simcard_replacement where simrepl_month_id='{year_month}';
#     '''
#     execute_sql(query)
#     write_df_fast(df, 'dm_3id_simcard_replacement', schema='marketing')

#     ym1=int(year_month)
#     ym2=int(get_previous_month(ym1, 1))
#     ym3=int(get_previous_month(ym1, 2))
#     query=f'''
#     delete from marketing.dm_3id_simcard_replacement_revenue where rev_month={str(ym1)};
#     '''
#     execute_sql(query)

#     query=f'''
#     delete from marketing.dm_3id_simcard_replacement_revenue_dly where rev_month={str(ym1)};
#     '''
#     execute_sql(query)

#     query=f'''
#     insert into marketing.dm_3id_simcard_replacement_revenue
#     select x1.msisdn, x1.dealercode, x1.calltypetier3, x1.simrepl_month_id, x1.source_channel, 
#     coalesce(t2.prepaid_rev,0) prepaid_rev, t2.rev_month
#     from (
#         select t1.* from
#             (
#             select a.*, row_number() over(partition by msisdn order by simrepl_month_id desc, dealercode) idx 
#             from marketing.dm_3id_simcard_replacement a
#             where simrepl_month_id in ('{str(ym3)}','{str(ym2)}','{str(ym1)}')
#             ) t1
#             where idx=1	 
#         ) x1	
#     left join 
#     (
#         select		b.sbscrptn_msisdn msisdn
#                     ,sum(revenue) prepaid_rev
#                     ,trx_Dt_Sk_id/100 rev_month
#         -- from 		mis.fct_cwn_rev_detail_fnl_prepaid_site a
#         from 		mis.fct_cwn_rev_detail_fnl a
#         left join	dwh.sbscrptn_attribs b on a.sbscrptn_ek_id=b.sbscrptn_ek_id and b.rank_ind=1
#         where 		trx_Dt_Sk_id::int/100={str(ym1)} --GANTI TANGGAL
#         group by 	1,3
#         ) t2
#     on x1.msisdn=t2.msisdn
#     ;  
#     '''
#     execute_sql(query)

#     query=f'''
#     insert into marketing.dm_3id_simcard_replacement_revenue_dly
#     select 
#         x1.msisdn, 
#         x1.dealercode, 
#         x1.calltypetier3, 
#         x1.simrepl_month_id,
#         x1.simrepl_dt,
#         x1.source_channel, 
#         coalesce(t2.prepaid_rev,0) prepaid_rev, 
#         t2.rev_month, 
#         t2.rev_dt::int rev_dt
#         from (
#             select t1.* from
#                 (
#                 select a.*, row_number() over(partition by msisdn order by simrepl_month_id desc, dealercode) idx 
#                 from marketing.dm_3id_simcard_replacement a
#                 where simrepl_month_id in ('{str(ym3)}','{str(ym2)}','{str(ym1)}') and simrepl_dt <= '{dt_id}'
#                 ) t1
#                 where idx=1	 
#             ) x1	
#         left join 
#         (
#             select		b.sbscrptn_msisdn msisdn
#                         ,sum(revenue) prepaid_rev
#                         ,trx_Dt_Sk_id/100 rev_month 
#                         ,trx_Dt_Sk_id as rev_dt
#             from 		mis.fct_cwn_rev_detail_fnl_prepaid_site a
#             left join	dwh.sbscrptn_attribs b on a.sbscrptn_ek_id=b.sbscrptn_ek_id and b.rank_ind=1
#             where 		trx_Dt_Sk_id::int/100={str(ym1)} and trx_Dt_Sk_id::int<='{dt_id}'::int
#             group by 	1,3,4
#             ) t2
#         on x1.msisdn=t2.msisdn 
#         where t2.rev_dt is not null
#         ;  
#     '''
#     execute_sql(query)

#     query=f''' 
#     select
#     *
#     from marketing.dm_3id_simcard_replacement_revenue 
#     where rev_month={year_month}
#     '''
#     df_rev=fetch_data_as_dataframe(query)
#     df_rev.to_csv(f"/data/retail/dm_3id_simcard_replacement_revenue_{year_month}.csv", 
#          index=False)
#     os.system(f'''rclone copy /data/retail/dm_3id_simcard_replacement_revenue_{year_month}.csv dsn:retail/kpi_retail/sim_replacement_rev/''') 

#     os.system(f'''rclone copy dsn:retail/kpi_retail/sim_replacement_rev/dm_3id_simcard_replacement_revenue_{year_month}.csv dsn:"Data/SIM Card Replacement (Revenue)/3ID"''')  
#     print("File uploaded successfully!") 

#     os.system(f'''rclone copy dsn:retail/kpi_retail/sim_replacement_rev/dm_3id_simcard_replacement_revenue_{year_month}.csv dsn:"Retail Performance Management - R100/sim_replacement_rev"''')  
#     # os.system(f'''rm -rf /data/retail/dm_3id_simcard_replacement_revenue_{year_month}.csv''')

#     status_job = 'Job running successfully'
#     return status_job

@op 
def t0_hdp_im3_sce_ga(input_task):
    print(input_task) 
    filename = '/data/data_automation_bai/data_automation_scheduling/scripts/retail/retail_im3_sdp_sce_ga.sql'
    fd = open(filename, 'r')
    sql_file = fd.read() 
    sql_file=sql_file.format(**{"year_month": year_month, 
                                "dt_id": dt_id
                                })
    fd.close() 
    query = sql_file.split(';') 

    print(f'Inserting row in table im3 rdm.rtl_sce_sdp where mth_id : {year_month}') 
    hdp_execute_query(query[0]) 

    status_job = 't1_im3_sce_ga : success'
    print(status_job)
    
    df=hdp_get_df(query[1]) 
    df.to_excel(f"/data/retail/im3_sce_ga_{year_month}.xlsx", 
         index=False)
    os.system(f'''rclone copy /data/retail/im3_sce_ga_{year_month}.xlsx dsn:retail/kpi_retail/sce_ga_sdp/''') 
    
    os.system(f'''rclone copy dsn:retail/kpi_retail/sce_ga_sdp/im3_sce_ga_{year_month}.xlsx dsn:"Retail Performance Management - R100/sce_ga_sdp"''')  
    
    # local_file = f"/data/retail/im3_sce_ga_{year_month}.xlsx"
    # remote_path = f"\\\\{server}\\S100\\{share}\\im3_sce_ga_{year_month}.xlsx" 
    
    # # Configure SMB authentication
    # smbclient.ClientConfig(username=username, password=password)
    # # Upload file
    # with open(local_file, "rb") as src, smbclient.open_file(remote_path, mode="wb") as dst:
    #     shutil.copyfileobj(src, dst)
    print("File uploaded successfully!") 
    
    os.system(f'''rm -rf /data/retail/im3_sce_ga{year_month}.xlsx)''') 
    return status_job

@op 
def t0_cockpit_3id_dump(input_task):
    print(input_task)  
    # year_month=(dt.date.today() - timedelta(days = 1)).strftime("%Y%m") 
    # dt_id = (dt.date.today() - timedelta(days = 1)).strftime("%Y%m%d")
    print('Start Executing 3id retail cockpit dump') 
    filename = '/data/data_automation_bai/data_automation_scheduling/scripts/retail/retail_3id_dump_cockpit.sql'
    fd = open(filename, 'r')
    sql_file = fd.read() 
    sql_file=sql_file.format(**{"year_month": year_month, 
                                "dt_id": dt_id
                                })
    fd.close() 
    query = sql_file.split(';') 
    print("01. 3ID AHT")   
    file_name=f'_3ID_AHT_{year_month}.csv' 
    final_location = f'3ID AHT'
    df=cockpit_get_df(query[0]) 
    df.to_csv(f"/data/retail/{file_name}", index=False)
    os.system(f'''rclone copy /data/retail/{file_name} dsn:retail/''')     
    os.system(f'''rclone copy dsn:retail/{file_name} dsn:"Data/NEW RETAIL DASHBOARD/00_Dump Retail Cockpit/{final_location}"''')
    df = df.astype(str)
    # ==== BIGQUERY UPLOAD ====
    project_id = "data-nationalslsdist-prd-986g"
    dataset_id = "retail"
    table_id = "raw_3id_aht"
    full_table_id = f"{project_id}.{dataset_id}.{table_id}"
    print(f"Loaded {len(df)} rows from {final_location} CSV files")
    # ==== BIGQUERY CLIENT ====
    client = bigquery.Client(project=project_id)
    # ==== DELETE ROWS BASED ON CONDITION ====
    delete_query = f"""
    DELETE FROM `{full_table_id}`
    WHERE  format_date('%Y%m',parse_date('%Y-%m-%d',period))=left('{dt_id}',6)
    """
    client.query(delete_query).result()
    print(f"Deleted rows in {full_table_id} where period = '{dt_id[:6]}'")
    # ==== APPEND NEW DATA ====
    job_config = bigquery.LoadJobConfig(
        write_disposition=bigquery.WriteDisposition.WRITE_APPEND,  # Append rows
        autodetect=True,  # Detect schema automatically
    )
    job = client.load_table_from_dataframe(df, full_table_id, job_config=job_config)
    job.result()
    print(f"Success Appended {len(df)} rows into {full_table_id}")
    # ==== Finish BIGQUERY UPLOAD ==== 

    print("02. 3ID CSAT 3Store In House") 
    file_name=f'_3ID_CSAT_3Store_In_House_{year_month}.csv' 
    final_location = f'3ID CSAT 3Store In House'
    df=cockpit_get_df(query[1]) 
    df.to_csv(f"/data/retail/{file_name}", index=False)
    os.system(f'''rclone copy /data/retail/{file_name} dsn:retail/''')     
    os.system(f'''rclone copy dsn:retail/{file_name} dsn:"Data/NEW RETAIL DASHBOARD/00_Dump Retail Cockpit/{final_location}"''') 
    df = df.astype(str)
    # ==== BIGQUERY UPLOAD ====
    project_id = "data-nationalslsdist-prd-986g"
    dataset_id = "retail"
    table_id = "raw_3id_csat_inhouse"
    full_table_id = f"{project_id}.{dataset_id}.{table_id}"
    print(f"Loaded {len(df)} rows from {final_location} CSV files")
    # ==== BIGQUERY CLIENT ====
    client = bigquery.Client(project=project_id)
    # ==== DELETE ROWS BASED ON CONDITION ====
    delete_query = f"""
    DELETE FROM `{full_table_id}`
    WHERE  format_date('%Y%m',parse_date('%Y-%m-%d',period))=left('{dt_id}',6)
    """
    client.query(delete_query).result()
    print(f"Deleted rows in {full_table_id} where period = '{dt_id[:6]}'")
    # ==== APPEND NEW DATA ====
    job_config = bigquery.LoadJobConfig(
        write_disposition=bigquery.WriteDisposition.WRITE_APPEND,  # Append rows
        autodetect=True,  # Detect schema automatically
    )
    job = client.load_table_from_dataframe(df, full_table_id, job_config=job_config)
    job.result()
    print(f"Success Appended {len(df)} rows into {full_table_id}")
    # ==== Finish BIGQUERY UPLOAD ====
 
    print("03. 3ID DVM Interaction") 
    file_name=f'_3ID_DVM_Interaction_{year_month}.csv' 
    final_location = f'3ID DVM Interaction'
    df=cockpit_get_df(query[2]) 
    df.to_csv(f"/data/retail/{file_name}", index=False)
    os.system(f'''rclone copy /data/retail/{file_name} dsn:retail/''')     
    os.system(f'''rclone copy dsn:retail/{file_name} dsn:"Data/NEW RETAIL DASHBOARD/00_Dump Retail Cockpit/{final_location}"''') 
    df = df.astype(str)
    # ==== BIGQUERY UPLOAD ====
    project_id = "data-nationalslsdist-prd-986g"
    dataset_id = "retail"
    table_id = "raw_3id_dvm_interaction"
    full_table_id = f"{project_id}.{dataset_id}.{table_id}"
    print(f"Loaded {len(df)} rows from {final_location} CSV files")
    # ==== BIGQUERY CLIENT ====
    client = bigquery.Client(project=project_id)
    # ==== DELETE ROWS BASED ON CONDITION ====
    delete_query = f"""
    DELETE FROM `{full_table_id}`
    WHERE  format_date('%Y%m',parse_date('%Y-%m-%d',period))=left('{dt_id}',6)
    """
    client.query(delete_query).result()
    print(f"Deleted rows in {full_table_id} where period = '{dt_id[:6]}'")
    # ==== APPEND NEW DATA ====
    job_config = bigquery.LoadJobConfig(
        write_disposition=bigquery.WriteDisposition.WRITE_APPEND,  # Append rows
        autodetect=True,  # Detect schema automatically
    )
    job = client.load_table_from_dataframe(df, full_table_id, job_config=job_config)
    job.result()
    print(f"Success Appended {len(df)} rows into {full_table_id}")
    # ==== Finish BIGQUERY UPLOAD ====

    print("04. 3ID Interaction") 
    file_name=f'_3ID_Interaction_{year_month}.csv' 
    final_location = f'3ID Interaction'
    df=cockpit_get_df(query[3]) 
    df.to_csv(f"/data/retail/{file_name}", index=False)
    os.system(f'''rclone copy /data/retail/{file_name} dsn:retail/''')     
    os.system(f'''rclone copy dsn:retail/{file_name} dsn:"Data/NEW RETAIL DASHBOARD/00_Dump Retail Cockpit/{final_location}"''') 
    df = df.astype(str)
    # ==== BIGQUERY UPLOAD ====
    project_id = "data-nationalslsdist-prd-986g"
    dataset_id = "retail"
    table_id = "raw_3id_interaction"
    full_table_id = f"{project_id}.{dataset_id}.{table_id}"
    print(f"Loaded {len(df)} rows from {final_location} CSV files")
    # ==== BIGQUERY CLIENT ====
    client = bigquery.Client(project=project_id)
    # ==== DELETE ROWS BASED ON CONDITION ====
    delete_query = f"""
    DELETE FROM `{full_table_id}`
    WHERE  format_date('%Y%m',parse_date('%Y-%m-%d',period))=left('{dt_id}',6)
    """
    client.query(delete_query).result()
    print(f"Deleted rows in {full_table_id} where period = '{dt_id[:6]}'")
    # ==== APPEND NEW DATA ====
    job_config = bigquery.LoadJobConfig(
        write_disposition=bigquery.WriteDisposition.WRITE_APPEND,  # Append rows
        autodetect=True,  # Detect schema automatically
    )
    job = client.load_table_from_dataframe(df, full_table_id, job_config=job_config)
    job.result()
    print(f"Success Appended {len(df)} rows into {full_table_id}")
    # ==== Finish BIGQUERY UPLOAD ====

    print("05. 3ID Revenue Union 3 table") 
    file_name=f'_3ID_Revenue_union_3_table_{year_month}.csv' 
    final_location = f'3ID Revenue Union 3 table'
    df=cockpit_get_df(query[4]) 
    df.to_csv(f"/data/retail/{file_name}", index=False)
    os.system(f'''rclone copy /data/retail/{file_name} dsn:retail/''')     
    os.system(f'''rclone copy dsn:retail/{file_name} dsn:"Data/NEW RETAIL DASHBOARD/00_Dump Retail Cockpit/{final_location}"''') 
    df = df.astype(str)
    # ==== BIGQUERY UPLOAD ====
    project_id = "data-nationalslsdist-prd-986g"
    dataset_id = "retail"
    table_id = "raw_3id_revenue_union"
    full_table_id = f"{project_id}.{dataset_id}.{table_id}"
    print(f"Loaded {len(df)} rows from {final_location} CSV files")
    # ==== BIGQUERY CLIENT ====
    client = bigquery.Client(project=project_id)
    # ==== DELETE ROWS BASED ON CONDITION ====
    delete_query = f"""
    DELETE FROM `{full_table_id}`
    WHERE  format_date('%Y%m',parse_date('%Y-%m-%d',period))=left('{dt_id}',6)
    """
    client.query(delete_query).result()
    print(f"Deleted rows in {full_table_id} where period = '{dt_id[:6]}'")
    # ==== APPEND NEW DATA ====
    job_config = bigquery.LoadJobConfig(
        write_disposition=bigquery.WriteDisposition.WRITE_APPEND,  # Append rows
        autodetect=True,  # Detect schema automatically
    )
    job = client.load_table_from_dataframe(df, full_table_id, job_config=job_config)
    job.result()
    print(f"Success Appended {len(df)} rows into {full_table_id}")
    # ==== Finish BIGQUERY UPLOAD ====

    print("06. 3ID Traffic Scan QR") 
    file_name=f'_Traffic_Scan_QR_{year_month}.csv' 
    final_location = f'3ID Traffic Scan QR'
    df=cockpit_get_df(query[5]) 
    df.to_csv(f"/data/retail/{file_name}", index=False)
    os.system(f'''rclone copy /data/retail/{file_name} dsn:retail/''')     
    os.system(f'''rclone copy dsn:retail/{file_name} dsn:"Data/NEW RETAIL DASHBOARD/00_Dump Retail Cockpit/{final_location}"''') 
    df = df.astype(str)
    # ==== BIGQUERY UPLOAD ====
    project_id = "data-nationalslsdist-prd-986g"
    dataset_id = "retail"
    table_id = "raw_3id_traffic_scan_qr"
    full_table_id = f"{project_id}.{dataset_id}.{table_id}"
    print(f"Loaded {len(df)} rows from {final_location} CSV files")
    # ==== BIGQUERY CLIENT ====
    client = bigquery.Client(project=project_id)
    # ==== DELETE ROWS BASED ON CONDITION ====
    delete_query = f"""
    DELETE FROM `{full_table_id}`
    WHERE  format_date('%Y%m',parse_date('%Y-%m-%d',period))=left('{dt_id}',6)
    """
    client.query(delete_query).result()
    print(f"Deleted rows in {full_table_id} where period = '{dt_id[:6]}'")
    # ==== APPEND NEW DATA ====
    job_config = bigquery.LoadJobConfig(
        write_disposition=bigquery.WriteDisposition.WRITE_APPEND,  # Append rows
        autodetect=True,  # Detect schema automatically
    )
    job = client.load_table_from_dataframe(df, full_table_id, job_config=job_config)
    job.result()
    print(f"Success Appended {len(df)} rows into {full_table_id}")
    # ==== Finish BIGQUERY UPLOAD ====

    print("07. 3ID Traffic Visitor Union") 
    file_name=f'_3ID_Traffic_Visitor_Union_{year_month}.csv' 
    final_location = f'3ID Traffic Visitor Union'
    df=cockpit_get_df(query[6]) 
    df.to_csv(f"/data/retail/{file_name}", index=False)
    os.system(f'''rclone copy /data/retail/{file_name} dsn:retail/''')     
    os.system(f'''rclone copy dsn:retail/{file_name} dsn:"Data/NEW RETAIL DASHBOARD/00_Dump Retail Cockpit/{final_location}"''') 
    os.system(f'''rclone copy dsn:retail/{file_name} dsn:"R100/visitor/{final_location}"''') 
    df = df.astype(str)
    # ==== BIGQUERY UPLOAD ====
    project_id = "data-nationalslsdist-prd-986g"
    dataset_id = "retail"
    table_id = "raw_3id_traffic_union"
    full_table_id = f"{project_id}.{dataset_id}.{table_id}"
    print(f"Loaded {len(df)} rows from {final_location} CSV files")
    # ==== BIGQUERY CLIENT ====
    client = bigquery.Client(project=project_id)
    # ==== DELETE ROWS BASED ON CONDITION ====
    delete_query = f"""
    DELETE FROM `{full_table_id}`
    WHERE  format_date('%Y%m',parse_date('%Y-%m-%d',period))=left('{dt_id}',6)
    """
    client.query(delete_query).result()
    print(f"Deleted rows in {full_table_id} where period = '{dt_id[:6]}'")
    # ==== APPEND NEW DATA ====
    job_config = bigquery.LoadJobConfig(
        write_disposition=bigquery.WriteDisposition.WRITE_APPEND,  # Append rows
        autodetect=True,  # Detect schema automatically
    )
    job = client.load_table_from_dataframe(df, full_table_id, job_config=job_config)
    job.result()
    print(f"Success Appended {len(df)} rows into {full_table_id}")
    # ==== Finish BIGQUERY UPLOAD ====

    status_job = 'Dump data success' 
    return status_job

@op 
def t2_cockpit_3id_sr_tt(input_task):   
    print(input_task)
    # filename = '/data/data_automation_bai/data_automation_scheduling/scripts/retail/retail_3id_dump_cockpit.sql'
    # fd = open(filename, 'r')
    # sql_file = fd.read() 
    # sql_file=sql_file.format(**{"year_month": year_month, 
    #                             "dt_id": dt_id
    #                             })
    # fd.close() 
    # query = sql_file.split(';') 
    # df=cockpit_get_df(query[7]) 

    bq_project = "data-nationalslsdist-prd-986g"
    client = bigquery.Client(project=bq_project)
    
    print('Starting SR TT 3ID on GCP')
    query = f"""
        with sr_total as (
            select 
                '{dt_id}' as dt_id,
                b.circle,
                b.region,
                b.store_name,
                a.brand,
                a.store_code,
                a.agent_id,
                'sr_total' as kpi_name,
                sum(case when a.dt_id='{dt_id}' then a.value else 0 end) as mtd_value,
                sum(case when a.dt_id=FORMAT_DATE('%Y%m%d',DATE_SUB(PARSE_DATE('%Y%m%d', '{dt_id}'), INTERVAL 1 MONTH)) then a.value else 0 end) as lmtd_value
            from `data-bi-prd-935c.bi_snd.rtl_raw_master_kpi_mtd` as a
                left join (
                    select * from `data-nationalslsdist-prd-986g`.retail.ref_storelist rs 
                    where mth_id = (select max(mth_id) from `data-nationalslsdist-prd-986g`.retail.ref_storelist where mth_id <= left('{dt_id}',6))
                ) as b
                on a.store_code = b.store_code
                where 1=1
                    and ( a.dt_id='{dt_id}'
                        or a.dt_id=FORMAT_DATE('%Y%m%d',DATE_SUB(PARSE_DATE('%Y%m%d', '{dt_id}'), INTERVAL 1 MONTH)))
                    -- and a.kpi_name='sr_closed'
                    and a.kpi_name='sr_total'
                    and a.level='agent'
                    and a.brand='3ID'
            group by all
        )
        , sr_done as (
            select 
                '{dt_id}' as dt_id,
                b.circle,
                b.region,
                b.store_name,
                a.brand,
                a.store_code,
                a.agent_id,
                'sr_done' as kpi_name,
                sum(case when a.dt_id='{dt_id}' then a.value else 0 end) as mtd_value,
                sum(case when a.dt_id=FORMAT_DATE('%Y%m%d',DATE_SUB(PARSE_DATE('%Y%m%d', '{dt_id}'), INTERVAL 1 MONTH)) then a.value else 0 end) as lmtd_value
            from `data-bi-prd-935c.bi_snd.rtl_raw_master_kpi_mtd` as a
                left join (
                    select * from `data-nationalslsdist-prd-986g`.retail.ref_storelist rs 
                    where mth_id = (select max(mth_id) from `data-nationalslsdist-prd-986g`.retail.ref_storelist where mth_id <= left('{dt_id}',6))
                ) as b
                on a.store_code = b.store_code
                where 1=1
                    and ( a.dt_id='{dt_id}'
                        or a.dt_id=FORMAT_DATE('%Y%m%d',DATE_SUB(PARSE_DATE('%Y%m%d', '{dt_id}'), INTERVAL 1 MONTH)))
                    -- and a.kpi_name='sr_ontime'
                    and a.kpi_name='sr_closed'
                    and a.level='agent'
                    and a.brand='3ID'
            group by all
        )
        , sr_tt as (
            select 
                a.dt_id,
                a.circle,
                a.region,
                a.store_name,
                a.brand,
                a.store_code,
                a.agent_id,
                'sr_tt' as kpi_name,
                safe_divide(sum(b.mtd_value),sum(a.mtd_value)) as mtd_value,
                safe_divide(sum(b.lmtd_value),sum(a.lmtd_value)) as lmtd_value
            from sr_total as a
                left join sr_done as b
                    on a.agent_id = b.agent_id and a.store_code = b.store_code
            group by all
        )
        select
        *
        from sr_total 
        union all
        select
        *
        from sr_done
        union all
        select
        *
        from sr_tt

    """
    # # Run query and return DataFrame
    df = client.query(query).to_dataframe() 

    df.to_excel(f"/data/retail/3id_sr_tt_{year_month}.xlsx", 
         index=False) 

    os.system(f'''rclone copy /data/retail/3id_sr_tt_{year_month}.xlsx dsn:retail/sr_tt/''') 
    
    os.system(f'''rclone copy dsn:retail/sr_tt/3id_sr_tt_{year_month}.xlsx dsn:"Retail Performance Management - R100/sr_tt"''')  
    status_job = "SR TT file uploaded successfully!"
    print(status_job) 
    
    return status_job  

@op 
def t3_cockpit_csat_3id(input_task):   
    print(input_task)
    # filename = '/data/data_automation_bai/data_automation_scheduling/scripts/retail/retail_3id_dump_cockpit.sql'
    # fd = open(filename, 'r')
    # sql_file = fd.read() 
    # sql_file=sql_file.format(**{"year_month": year_month, 
    #                             "dt_id": dt_id
    #                             })
    # fd.close() 
    # query = sql_file.split(';') 
    # df=cockpit_get_df(query[8]) 

    bq_project = "data-nationalslsdist-prd-986g"
    client = bigquery.Client(project=bq_project)
    
    print('Starting CSAT 3ID on GCP')
    query = f"""
        with kpi_csat as (
        select 
        --	a.*,
            a.dt_id, a.source_data, a.store_code, a.csat_delivered, a.csat_respond, a.csat_happy, 
                case when b.agent_nik is not null then upper(b.agent_nik)
                    when left(upper(a.agent_id),5)='MBPS3' then concat('MPBS-3', upper(substring(a.agent_id,6,length(a.agent_id)))) 
                    when c.agent_nik is not null then upper(c.agent_nik)
                    when split(a.agent_id,'-')[OFFSET(0)]=a.store_code and upper(split(a.agent_id,'-')[SAFE_OFFSET(1)]) is not null then upper(split(a.agent_id,'-')[SAFE_OFFSET(1)])
                    else upper(a.agent_id)
                end as agent_id
            from `data-nationalslsdist-prd-986g`.retail.raw_3id_csat as a 
            left join (
                        select 
                            distinct
                            upper(regexp_replace(agent_id, r'[-_#\s]+', '')) id, 
                            agent_nik,
                            store_code
                        from `data-nationalslsdist-prd-986g`.retail.ref_agent_spv 
                            where brand='3ID'
                                and agent_id is not null 
                                and mth_id = (select max(mth_id) from `data-nationalslsdist-prd-986g`.retail.ref_agent_spv)
                    ) as b on upper(regexp_replace(a.agent_id, r'[-_#\s]+', ''))=b.id and a.store_code=b.store_code
            left join (
                        select 
                            distinct
                            upper(regexp_replace(spv_id, r'[-_#\s]+', '')) id, 
                            spv_nik as agent_nik,
                            store_code
                        from `data-nationalslsdist-prd-986g`.retail.ref_agent_spv 
                            where brand='3ID'
                                and agent_id is not null 
                                and mth_id = (select max(mth_id) from `data-nationalslsdist-prd-986g`.retail.ref_agent_spv)
                    ) as c on upper(regexp_replace(a.agent_id, r'[-_#\s]+', ''))=c.id and a.store_code=c.store_code
                where date(dt_id) between date_trunc(parse_date('%Y%m%d', '{dt_id}'), month)
                    and parse_date('%Y%m%d', '{dt_id}')
            group by all
        )
        select  
            format_date('%Y%m', a.dt_id) as mth_id,
            format_date('%Y%m%d', a.dt_id) as dt_id,
            a.agent_id,
            a.store_code,
            b.status_2 as channel,
            b.store_name, 
            b.store_code_distribution as dist_id,
            b.circle,
            b.region,
            '3ID' as brand,
            a.csat_delivered as responden_delivered, 
            a.csat_respond as responden_feedback,
            a.csat_happy as happy,
            safe_divide(a.csat_happy, a.csat_respond) as csat, 
            safe_divide(a.csat_respond, a.csat_delivered) as responden_rate, 
            case when safe_divide(a.csat_respond, a.csat_delivered)>=0.1 then 'Valid' 
                else 'Not Valid' end as responden_rate_status
        from kpi_csat as a
            left join (
                select * from `data-nationalslsdist-prd-986g`.retail.ref_storelist rs 
                where mth_id = (select max(mth_id) from `data-nationalslsdist-prd-986g`.retail.ref_storelist where mth_id <= left('{dt_id}',6))
            ) as b
            on a.store_code = b.store_code
    """
    # # Run query and return DataFrame
    df = client.query(query).to_dataframe()

    df.to_excel(f"/data/retail/3id_csat_agent_{year_month}.xlsx", 
         index=False)
    os.system(f'''rclone copy /data/retail/3id_csat_agent_{year_month}.xlsx dsn:retail/kpi_retail/csat''') 
    
    os.system(f'''rclone copy dsn:retail/kpi_retail/csat/3id_csat_agent_{year_month}.xlsx dsn:"Retail Performance Management - R100/csat_3id_new"''')  
    status_job = "CSAT 3ID New file uploaded successfully!"
    print(status_job) 
    
    return status_job 

@op 
def t1_hdp_sensum_feed(input_task): 
    print(input_task) 
    # year_month=(dt.date.today() - timedelta(days = 3)).strftime("%Y%m") 
    # dt_id = (dt.date.today() - timedelta(days = 3)).strftime("%Y%m%d") 
    query=f''' 
    select distinct
    customer_msisdn msisdn, 'IM3' Brand_Name, 
    'IPOS' Channel_Source,
    case 
    when a.gerai_type in ('JV','Third Party','Own Store','MPC Store') then 'GERAI IM3'
    when a.gerai_type = 'SDP' then 'MITRA IM3'
    end Channel_Name,  
    user_name Agent_ID, 
    b.organization_ref_code Store_ID,
    b.organization_name Store_Name,
    transaction_id Interaction_ID, 
    FROM_UNIXTIME(UNIX_TIMESTAMP(a.transactiondatetime, 'yyyy-MM-dd HH:mm:ss'), 'yyyyMMdd') as Transaction_Date
    from STG.STG_IPOS_TRANSACTION_DETAIL a 
    left join STG.STG_IPOS_SNAPSHOT_ORGANIZATION_DETAILS b 
    on a.organization_id = b.organization_id 
    where FROM_UNIXTIME(UNIX_TIMESTAMP(a.transactiondatetime, 'yyyy-MM-dd HH:mm:ss'), 'yyyyMMdd')<='{dt_id}' and FROM_UNIXTIME(UNIX_TIMESTAMP(a.transactiondatetime, 'yyyy-MM-dd HH:mm:ss'), 'yyyyMM')=strleft('{dt_id}',6)
    and a.gerai_type in ('SDP','JV','Third Party','Own Store','MPC Store')
    ''' 
    #print(query)
    df = hdp_get_df(query) 
    # Local and remote file paths
    local_csv_path = f"/data/surveysensum/csat_agent_{dt_id}_2.csv"  # Path to the local file
    remote_csv_path = f"/IOHGeraiSurvey/csat_agent_{dt_id}_2.csv"  # Full path to save the file on the SFTP server
    df.to_csv(local_csv_path, index=False, sep='|') 
    # SFTP connection details
    host = '52.76.140.165'
    port = 22
    username = 'ioh_gerai'
    password = 'ioh_gerai@#survey'
    proxy_host = '10.45.127.5'
    proxy_port = 3128

    # Create an SSH client
    ssh = paramiko.SSHClient()
    ssh.set_missing_host_key_policy(paramiko.AutoAddPolicy())

    try:
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

        # Copy the CSV file from the local machine to the remote server
        sftp.put(local_csv_path, remote_csv_path)
        print(f"File copied successfully to {remote_csv_path} on the SFTP server")

        # Close the SFTP session and SSH connection
        sftp.close()
        ssh.close()

    except Exception as e:
        print(f"An error occurred: {e}") 
    status_job='success' 
    return status_job  

@op 
def t2_hdp_im3_cc(input_task): 
    print(input_task)
    filename = '/data/data_automation_bai/data_automation_scheduling/scripts/retail/champion_clubs_retail_im3.sql'
    fd = open(filename, 'r')
    sql_file = fd.read() 
    sql_file=sql_file.format(**{"year_month": year_month, 
                                "dt_id": dt_id
                                })
    fd.close() 
    query = sql_file.split(';') 

    print(f'01. Inserting agent productivity where mth_id : {year_month}') 
    hdp_execute_query(query[0]) 
    print(f'01. Finish inserting agent productivity where mth_id : {year_month}')

    print(f'02. Inserting store productivity where mth_id : {year_month}') 
    hdp_execute_query(query[1]) 
    print(f'02. Finish inserting store productivity where mth_id : {year_month}')

    print(f'03. Inserting GA platinum where mth_id : {year_month}') 
    hdp_execute_query(query[2]) 
    print(f'03. Finish inserting GA platinum where mth_id : {year_month}')

    print(f'04. Inserting store revenue where mth_id : {year_month}') 
    hdp_execute_query(query[3]) 
    print(f'04. Finish inserting store_revenue where mth_id : {year_month}')

    print(f'05. Inserting mystery shopper where mth_id : {year_month}') 
    hdp_execute_query(query[4]) 
    print(f'05. Finish inserting mystery shopper where mth_id : {year_month}')

    print(f'06. Inserting CSAT gerai where mth_id : {year_month}') 
    hdp_execute_query(query[5]) 
    print(f'06. Finish inserting CSAT gerai where mth_id : {year_month}')

    print(f'07. Inserting CSAT sdp where mth_id : {year_month}') 
    hdp_execute_query(query[6]) 
    print(f'07. Finish inserting CSAT sdp where mth_id : {year_month}')

    
    df=hdp_get_df(query[7]) 
    df.to_csv(f"/data/retail/champion_clubs_retail_im3_{year_month}.csv", 
         index=False)
    os.system(f'''rclone copy /data/retail/champion_clubs_retail_im3_{year_month}.csv dsn:retail/kpi_retail/champion_club/''') 
    
    os.system(f'''rclone copy dsn:retail/kpi_retail/champion_club/champion_clubs_retail_im3_{year_month}.csv dsn:"Retail Performance Management - R100/champion_club"''')  
    
    status_job = "Champion clubs file uploaded successfully!"

    print(status_job) 
    
    os.system(f'''rm -rf /data/retail/champion_clubs_retail_im3_{year_month}.csv)''') 
    return status_job

@op 
def t3_hdp_sr_tt(input_task): 
    print(input_task) 
    # filename = '/data/data_automation_bai/data_automation_scheduling/scripts/retail/retail_im3_kpi.sql'
    # fd = open(filename, 'r')
    # sql_file = fd.read() 
    # sql_file=sql_file.format(**{"year_month": year_month, 
    #                             "dt_id": dt_id
    #                             })
    # fd.close() 
    # query = sql_file.split(';') 
    # df=hdp_get_df(query[2])

    print(dt_id)
    project_id = "data-nationalslsdist-prd-986g"
    dataset_id = "retail"
    # table_id = "raw_interaction_mitra_im3"
    # full_table_id = f"{project_id}.{dataset_id}.{table_id}"
    client = bigquery.Client(project=project_id) 

    cmd=f'''
    select
        '{dt_id}' as dt_id,
        b.circle,
        b.region,
        b.store_name,
        a.brand,
        a.store_code, 
        a.agent_id,
        case when a.kpi_name='sr_closed' then 'sr_done'
            else a.kpi_name end as kpi_name,
        sum(case when a.dt_id='{dt_id}' then a.value end) as mtd_value,
        sum(case when a.dt_id=format_date('%Y%m%d',date_sub(parse_date('%Y%m%d', '{dt_id}'), interval 1 month)) then a.value end) as lmtd_value
    from `data-bi-prd-935c`.bi_snd.rtl_raw_master_kpi_mtd as a
        inner join 
            (
            select 
                store_code,
                store_name,
                circle,
                region,
                row_number() over(partition by store_code order by mth_id desc) as rnk
            from `data-nationalslsdist-prd-986g`.retail.ref_storelist 
                where lower(status_2) like '%gerai%im3%'
            ) as b
            on a.store_code=b.store_code and b.rnk=1
    where (a.dt_id = '{dt_id}' 
            or a.dt_id=format_date('%Y%m%d',date_sub(parse_date('%Y%m%d', '{dt_id}'), interval 1 month)))
            and a.brand = 'IM3'
            and a.kpi_name in ('sr_closed', 'sr_total', 'sr_tt')
            and a.`level` ='agent'
    group by all
    '''  
    df=client.query(cmd).to_dataframe()
    df.to_excel(f"/data/retail/im3_sr_tt_{year_month}.xlsx", 
         index=False)
    os.system(f'''rclone copy /data/retail/im3_sr_tt_{year_month}.xlsx dsn:retail/sr_tt/''') 
    
    os.system(f'''rclone copy dsn:retail/sr_tt/im3_sr_tt_{year_month}.xlsx dsn:"Retail Performance Management - R100/sr_tt"''')  
    status_job = "SR TT file uploaded successfully!"

    print(status_job) 
    return status_job

@op
def t4_hdp_im3_sim_rev(last_task): 
    print(last_task)
    # filename = '/data/data_automation_bai/data_automation_scheduling/scripts/retail/retail_im3_sim_replacement_rev.sql'
    # fd = open(filename, 'r')
    # sql_file = fd.read() 
    # sql_file=sql_file.format(**{"year_month": year_month, 
    #                             "dt_id": dt_id
    #                             })
    # fd.close() 
    # query = sql_file.split(';') 

    # print(f'Inserting row in table im3 rdm.dm_im3_simcard_replacement where mth_id : {year_month}') 
    # hdp_execute_query(query[0]) 

    # status_job = 'task 0 : success'
    # print(status_job) 
    
    # print(f'Inserting row in table im3 rdm.dm_im3_simcard_replacement_revenue where mth_id : {year_month}') 
    # hdp_execute_query(query[1]) 

    # status_job = 'task 1 : success'
    # print(status_job)
    
    # print(f'Inserting row in table im3 rdm.dm_im3_simcard_replacement_revenue_dly where mth_id : {year_month}') 
    # hdp_execute_query(query[3]) 

    # status_job = 'task 2 : success'
    # print(status_job)

    # df=hdp_get_df(query[2])  
    print(dt_id)
    project_id = "data-nationalslsdist-prd-986g"
    dataset_id = "retail"
    # table_id = "raw_interaction_mitra_im3"
    # full_table_id = f"{project_id}.{dataset_id}.{table_id}"
    client = bigquery.Client(project=project_id) 

    cmd=f'''
    select 
        a.msisdn,
        cast(null as string) as organization_name,
        a.store_code,
        'SIM Replacement' event_type_main,
        left(a.change_dt,6) as simrepl_month_id,
        sum(a.rev_service) as rev_30,
        left(a.rev_dt, 6) as rev_month
    from `data-nationalslsdist-prd-986g`.retail.raw_im3_rev_service as a
    where left(a.rev_dt,6)=left('{dt_id}',6) 
    group by all
    '''  
    df=client.query(cmd).to_dataframe()
    df.to_csv(f"/data/retail/dm_im3_simcard_replacement_revenue_{year_month}.csv", 
         index=False)
    os.system(f'''rclone copy /data/retail/dm_im3_simcard_replacement_revenue_{year_month}.csv dsn:retail/kpi_retail/sim_replacement_rev/''') 
    
    os.system(f'''rclone copy dsn:retail/kpi_retail/sim_replacement_rev/dm_im3_simcard_replacement_revenue_{year_month}.csv dsn:"Data/SIM Card Replacement (Revenue)/IM3"''')   

    os.system(f'''rclone copy dsn:retail/kpi_retail/sim_replacement_rev/dm_im3_simcard_replacement_revenue_{year_month}.csv dsn:"Retail Performance Management - R100/sim_replacement_rev"''')
    print("File uploaded successfully!") 
    status_job = 'task completed............'
    # os.system(f'''rm -rf /data/retail/dm_im3_simcard_replacement_revenue_{year_month}.csv''') 
    return status_job

@op 
def t1_cockpit_3id_cc(input_task):  
    print(input_task) 
    filename = '/data/data_automation_bai/data_automation_scheduling/scripts/retail/champion_clubs_retail_3id.sql'
    fd = open(filename, 'r')
    sql_file = fd.read() 
    sql_file=sql_file.format(**{"year_month": year_month, 
                                "dt_id": dt_id
                                })
    fd.close() 
    query = sql_file.split(';')   

    print(f'01. Inserting agent productivity where mth_id:{year_month}')
    cockpit_execute_sql(query[0]) 
    cockpit_execute_sql(query[1]) 
    cockpit_execute_sql(query[2]) 
    cockpit_execute_sql(query[3])

    print(f'02. Inserting CSAT 3KIOSK where mth_id:{year_month}')
    cockpit_execute_sql(query[4])
    cockpit_execute_sql(query[5])

    print(f'03. Inserting CSAT 3STORE where mth_id:{year_month}')
    cockpit_execute_sql(query[6])
    cockpit_execute_sql(query[7])


    print(f'04. Inserting mysteryy shopper where mth_id:{year_month}')
    cockpit_execute_sql(query[7]) 
    cockpit_execute_sql(query[8])
    
    print(f'05. Deleteing Store Productivity and Store revenue ')
    cockpit_execute_sql(query[9])

    print(f'06. Inserting store productivity where mth_id:{year_month}')
    query=f''' 
        -- mtd
        SELECT distinct 
        case 
            when left(customerid,3)='089' then concat('62',substr(customerid,2,100)) 
            when left(customerid,3)='628' then customerid
            else customerid
        end msisdn,
        terminal_code as dealercode,
        product_name as calltypetier3, 
        left('{dt_id}',6) simrepl_month_id, 
        'DVM' source_channel
        FROM cockpit_archieve.raw_3db_trx T1
                inner join cockpit_archieve.master_3db_terminal as T2 on T1.terminal_code=T2.code
            where 1=1 
            and date_format(date_trx, '%Y%m')>=DATE_FORMAT(DATE_SUB('{dt_id}', INTERVAL 2 MONTH), '%Y%m') 
            and date_format(date_trx, '%Y%m%d')<='{dt_id}'
            and product_code <> 'VALIDITY_KTP'
            and product_code IN ('THREE_CHANGE_CARD','THREE_SIMCARD4G', 'THREE_CHANGE_CARD_O2O', 'Upgrade 4G O2O')
            and result = 'success'
            and state='Done'
        union all 
        SELECT distinct msisdn, dealercode, calltypetier3, left('{dt_id}',6) simrepl_month_id, 'SIEBEL' source_channel
            FROM cockpit.raw_sr_opened
            where 1=1 
            and date_format(Opened, '%Y%m')>=DATE_FORMAT(DATE_SUB('{dt_id}', INTERVAL 2 MONTH), '%Y%m') 
            and date_format(Opened, '%Y%m%d')<='{dt_id}'
            and CallTypeTier3 = 'Replacement SIM Card'
            and STATUS = 'Closed'
    ''' 
    df_mtd = cockpit_get_df(query) 

    query=f''' 
        -- lmtd
        SELECT distinct 
        case 
            when left(customerid,3)='089' then concat('62',substr(customerid,2,100)) 
            when left(customerid,3)='628' then customerid
            else customerid
        end msisdn,
        terminal_code as dealercode,
        product_name as calltypetier3, 
        DATE_FORMAT(DATE_SUB('{dt_id}', INTERVAL 1 MONTH), '%Y%m') simrepl_month_id, 
        'DVM' source_channel
        FROM cockpit_archieve.raw_3db_trx T1
                inner join cockpit_archieve.master_3db_terminal as T2 on T1.terminal_code=T2.code
            where 1=1 
            and date_format(date_trx, '%Y%m')>=DATE_FORMAT(DATE_SUB('{dt_id}', INTERVAL 3 MONTH), '%Y%m') 
            and date_format(date_trx, '%Y%m%d')<=DATE_FORMAT(DATE_SUB('{dt_id}', INTERVAL 1 MONTH), '%Y%m%d')
            and product_code <> 'VALIDITY_KTP'
            and product_code IN ('THREE_CHANGE_CARD','THREE_SIMCARD4G', 'THREE_CHANGE_CARD_O2O', 'Upgrade 4G O2O')
            and result = 'success'
            and state='Done'
        union all 
        SELECT distinct msisdn, dealercode, calltypetier3, DATE_FORMAT(DATE_SUB('{dt_id}', INTERVAL 1 MONTH), '%Y%m') simrepl_month_id, 'SIEBEL' source_channel
            FROM cockpit.raw_sr_opened
            where 1=1 
            and date_format(Opened, '%Y%m')>=DATE_FORMAT(DATE_SUB('{dt_id}', INTERVAL 3 MONTH), '%Y%m') 
            and date_format(Opened, '%Y%m%d')<=DATE_FORMAT(DATE_SUB('{dt_id}', INTERVAL 1 MONTH), '%Y%m%d')
            and CallTypeTier3 = 'Replacement SIM Card'
            and STATUS = 'Closed';
    ''' 
    df_lmtd = cockpit_get_df(query)  
    
    execute_sql('truncate table marketing.dm_temp_simcard_replacement_mtd') 
    execute_sql('truncate table marketing.dm_temp_simcard_replacement_lmtd')
    
    write_df_fast(df_mtd, 'dm_temp_simcard_replacement_mtd', schema='marketing')
    write_df_fast(df_lmtd, 'dm_temp_simcard_replacement_lmtd', schema='marketing')  

    query=f''' 
    with rev_sim_mtd as (
        select 
            x1.dealercode, 
            x1.simrepl_month_id,  
            sum(coalesce(t2.prepaid_rev,0)) as rev_sim_replacement
        from (
            select t1.* from
                (
                select a.*, row_number() over(partition by msisdn order by simrepl_month_id desc, dealercode) idx 
                from marketing.dm_temp_simcard_replacement_mtd a
                ) t1
                where idx=1	 
            ) x1	
        left join 
        (
            select		b.sbscrptn_msisdn msisdn
                        ,sum(revenue) prepaid_rev
                        ,trx_Dt_Sk_id/100 rev_month
            from 		mis.fct_cwn_rev_detail_fnl_prepaid_site a
            left join	dwh.sbscrptn_attribs b on a.sbscrptn_ek_id=b.sbscrptn_ek_id and b.rank_ind=1
            where 		trx_Dt_Sk_id::int/100='{dt_id}'::int/100
                        and trx_Dt_Sk_id::int<='{dt_id}'::int
            group by 	1,3
            ) t2
        on x1.msisdn=t2.msisdn 
        group by 1, 2 
    )
    , rev_sim_lmtd as(
        select 
            x1.dealercode, 
            x1.simrepl_month_id,  
            sum(coalesce(t2.prepaid_rev,0)) as rev_sim_replacement
        from (
            select t1.* from
                (
                select a.*, row_number() over(partition by msisdn order by simrepl_month_id desc, dealercode) idx 
                from marketing.dm_temp_simcard_replacement_lmtd a
                ) t1
                where idx=1	 
            ) x1	
        left join 
        (
            select		b.sbscrptn_msisdn msisdn
                        ,sum(revenue) prepaid_rev
                        ,trx_Dt_Sk_id/100 rev_month
            from 		mis.fct_cwn_rev_detail_fnl_prepaid_site a
            left join	dwh.sbscrptn_attribs b on a.sbscrptn_ek_id=b.sbscrptn_ek_id and b.rank_ind=1
            where 		trx_Dt_Sk_id::int/100=cast(to_char(to_date('{dt_id}', 'YYYYMMDD') - (1 || 'months')::interval, 'YYYYMM') as int)
                        and trx_Dt_Sk_id::int<=cast(to_char(to_date('{dt_id}', 'YYYYMMDD') - (1 || 'months')::interval, 'YYYYMMDD') as int)
            group by 	1,3
            ) t2
        on x1.msisdn=t2.msisdn 
        group by 1, 2
    )
    select 
    coalesce(a.dealercode, b.dealercode) as dealercode, 
    coalesce(a.rev_sim_replacement,0) as rev_sim_replacement_mtd, 
    coalesce(b.rev_sim_replacement,0) as rev_sim_replacement_lmtd
    from rev_sim_mtd as a 
    full outer join rev_sim_lmtd as b
        on a.dealercode=b.dealercode;
    '''
    df_rev_sim=fetch_data_as_dataframe(query)

    query=f''' 
            SELECT DATE_FORMAT(buv.salesdate, "%Y%m") AS period
                    , buv.DealerCode AS dealercode
                    , SUM(COALESCE(buv.TotalAmount, 0)) AS rev_cash_in
                FROM cockpit.raw_poss buv 
                WHERE buv.TotalAmount > 0
                AND buv.ProductName not like 'SP-PR%' 
                AND DATE_FORMAT(buv.SalesDate, '%Y%m') = left('{dt_id}',6) and DATE_FORMAT(buv.SalesDate, '%Y%m%d')<='{dt_id}'
                GROUP BY 1,2
            UNION ALL
                SELECT DATE_FORMAT(buv.document_date, "%Y%m") AS period
                    , dealercode AS dealercode
                    , SUM(COALESCE(buv.amount, 0)) AS rev_cash_in
                FROM cockpit.raw_post_payment buv
                WHERE buv.amount > 0
                AND DATE_FORMAT(buv.document_date, '%Y%m') = left('{dt_id}',6) and DATE_FORMAT(buv.document_date, '%Y%m%d')<='{dt_id}'
                GROUP BY 1,2
            UNION ALL
                SELECT DATE_FORMAT(T1.date_trx, "%Y%m") as period
                , trim(T1.terminal_code) as dealercode
                , sum(payment_value) as rev_cash_in
                FROM cockpit_archieve.raw_3db_trx T1
                    inner join cockpit_archieve.master_3db_terminal as T2 on T1.terminal_code=T2.code
                Where result = 'success'
                and product_code NOT IN ('THREE_CHANGE_CARD','THREE_REGPRABAYAR','THREE_SIMCARD4G', 'THREE_CHANGE_CARD_O2O', 'Upgrade 4G O2O', 'VALIDITY_KTP')
                and DATE_FORMAT(T1.date_trx, "%Y%m") = left('{dt_id}',6) and  DATE_FORMAT(T1.date_trx, "%Y%m%d")<='{dt_id}'
                GROUP BY 1,2
    ''' 
    df_mtd = cockpit_get_df(query)
    df_mtd=df_mtd.groupby(['period','dealercode']).sum('rev_cash_in').reset_index()
    query=f''' 
            SELECT DATE_FORMAT(buv.salesdate, "%Y%m") AS period
                    , buv.DealerCode AS dealercode
                    , SUM(COALESCE(buv.TotalAmount, 0)) AS rev_cash_in
                FROM cockpit.raw_poss buv 
                WHERE buv.TotalAmount > 0
                AND buv.ProductName not like 'SP-PR%' 
                AND DATE_FORMAT(buv.SalesDate, '%Y%m') = DATE_FORMAT(DATE_SUB(STR_TO_DATE('{dt_id}', '%Y%m%d'), INTERVAL 1 MONTH), '%Y%m') 
                    and DATE_FORMAT(buv.SalesDate, '%Y%m%d')<=DATE_FORMAT(DATE_SUB(STR_TO_DATE('{dt_id}', '%Y%m%d'), INTERVAL 1 MONTH), '%Y%m%d')
                GROUP BY 1,2
            UNION ALL
                SELECT DATE_FORMAT(buv.document_date, "%Y%m") AS period
                    , dealercode AS dealercode
                    , SUM(COALESCE(buv.amount, 0)) AS rev_cash_in
                FROM cockpit.raw_post_payment buv
                WHERE buv.amount > 0
                AND DATE_FORMAT(buv.document_date, '%Y%m') = DATE_FORMAT(DATE_SUB(STR_TO_DATE('{dt_id}', '%Y%m%d'), INTERVAL 1 MONTH), '%Y%m') 
                    and DATE_FORMAT(buv.document_date, '%Y%m%d')<=DATE_FORMAT(DATE_SUB(STR_TO_DATE('{dt_id}', '%Y%m%d'), INTERVAL 1 MONTH), '%Y%m%d')
                GROUP BY 1,2
            UNION ALL
                SELECT DATE_FORMAT(T1.date_trx, "%Y%m") as period
                , trim(T1.terminal_code) as dealercode
                , sum(payment_value) as rev_cash_in
                FROM cockpit_archieve.raw_3db_trx T1
                    inner join cockpit_archieve.master_3db_terminal as T2 on T1.terminal_code=T2.code
                Where result = 'success'
                and product_code NOT IN ('THREE_CHANGE_CARD','THREE_REGPRABAYAR','THREE_SIMCARD4G', 'THREE_CHANGE_CARD_O2O', 'Upgrade 4G O2O', 'VALIDITY_KTP')
                and DATE_FORMAT(T1.date_trx, "%Y%m") = DATE_FORMAT(DATE_SUB(STR_TO_DATE('{dt_id}', '%Y%m%d'), INTERVAL 1 MONTH), '%Y%m') 
                    and  DATE_FORMAT(T1.date_trx, "%Y%m%d")<=DATE_FORMAT(DATE_SUB(STR_TO_DATE('{dt_id}', '%Y%m%d'), INTERVAL 1 MONTH), '%Y%m%d')
                GROUP BY 1,2
    ''' 
    df_lmtd = cockpit_get_df(query) 
    df_lmtd=df_lmtd.groupby(['period','dealercode']).sum('rev_cash_in').reset_index()
    df_rev_cash=pd.merge(df_mtd,df_lmtd,on='dealercode',how='outer',suffixes=('_mtd', '_lmtd'))
    df_rev_cash['rev_cash_in_mtd']=df_rev_cash['rev_cash_in_mtd'].fillna(0) 
    df_rev_cash['rev_cash_in_lmtd']=df_rev_cash['rev_cash_in_lmtd'].fillna(0)
    df_rev_cash=df_rev_cash[['dealercode','rev_cash_in_mtd','rev_cash_in_lmtd']]
    df_fin=df_rev_sim.merge(df_rev_cash,on='dealercode',how='outer')
    df_fin=df_fin.fillna(0)
    df_fin['revenue_mtd']=df_fin['rev_cash_in_mtd']+df_fin['rev_sim_replacement_mtd']
    df_fin['revenue_lmtd']=df_fin['rev_cash_in_lmtd']+df_fin['rev_sim_replacement_lmtd']
    df_rev_all = df_fin[['dealercode','revenue_mtd','revenue_lmtd']].copy()
    os.system(f'''rclone copy "dsn:retail/champion_club/target_retail_revenue_3id.xlsx" /data/retail/''')
    df_tgt = pd.read_excel(r'/data/retail/target_retail_revenue_3id.xlsx', 
                    sheet_name='tgt',engine="openpyxl")
    mtd=dt_id
    lmtd=(datetime.strptime(dt_id, '%Y%m%d') - relativedelta(months = 1)).strftime('%Y%m%d')
    mth=mtd[:6]
    lmth=lmtd[:6]
    df_tgt['periode']=df_tgt['periode'].astype(str)
    tgt_mth = df_tgt[df_tgt['periode'].astype(str) == mth].copy()
    tgt_lmth = df_tgt[df_tgt['periode'].astype(str) == lmth].copy()
    tgt_mth = tgt_mth.rename(columns={'revenue_target': 'mtd_tgt'})
    tgt_lmth = tgt_lmth.rename(columns={'revenue_target': 'lmtd_tgt'})
    key_cols = ['store_code', 'store_name', 'type', 'region', 'circle']
    tgt = pd.merge(tgt_mth[key_cols + ['mtd_tgt']], tgt_lmth[key_cols + ['lmtd_tgt']], on=key_cols, how='left')
    df_rev_all=df_rev_all.rename(columns={'dealercode': 'store_code'})
    tgt=tgt.merge(df_rev_all[['store_code','revenue_mtd','revenue_lmtd']], on='store_code', how='left')
    tgt['mtd_ach']=tgt['revenue_mtd']/tgt['mtd_tgt'] 
    tgt['lmtd_ach']=tgt['revenue_lmtd']/tgt['lmtd_tgt']
    tgt['mtd_cnt']=tgt['mtd_ach'].apply(lambda x: 1 if x>=1 else 0) 
    tgt['lmtd_cnt']=tgt['lmtd_ach'].apply(lambda x: 1 if x>=1 else 0)
    summary=tgt.groupby(['region', 'circle']).agg(
        mtd_all=('mtd_tgt', lambda x: (x > 0 ).sum()), 
        lmtd_all=('lmtd_tgt', lambda x: (x > 0 ).sum()),
        mtd_cnt=('mtd_cnt', lambda x: (x==1 ).sum()), 
        lmtd_cnt=('lmtd_cnt', lambda x: (x==1 ).sum())
    ).reset_index()
    summary['mtd_ach']=summary['mtd_cnt']/summary['mtd_all'] 
    summary['lmtd_ach']=summary['lmtd_cnt']/summary['lmtd_all']
    summary['dt_id']=dt_id 
    summary['mth_id']=mth 
    summary['brand']='3ID' 
    store_prod_cnt = summary[['region', 'circle', 'mtd_cnt', 'lmtd_cnt','dt_id','mth_id','brand']].copy() 
    store_prod_cnt.columns = ['region_circle', 'circle', 'mtd_value', 'lmtd_value','dt_id','mth_id','brand'] 
    store_prod_cnt['kpi_name']='store_prod_rev_cnt' 
    store_prod_cnt=store_prod_cnt[['dt_id', 'circle', 'region_circle', 'brand', 
                                'mtd_value','lmtd_value','kpi_name','mth_id']] 
    store_prod_ach = summary[['region', 'circle', 'mtd_ach', 'lmtd_ach','dt_id','mth_id','brand']].copy() 
    store_prod_ach.columns = ['region_circle', 'circle', 'mtd_value', 'lmtd_value','dt_id','mth_id','brand'] 
    store_prod_ach['kpi_name']='store_prod_rev_ach' 
    store_prod_ach=store_prod_ach[['dt_id', 'circle', 'region_circle', 'brand', 
                                'mtd_value','lmtd_value','kpi_name','mth_id']] 
    store_prod_tgt = summary[['region', 'circle', 'mtd_all', 'lmtd_all','dt_id','mth_id','brand']].copy() 
    store_prod_tgt.columns = ['region_circle', 'circle', 'mtd_value', 'lmtd_value','dt_id','mth_id','brand'] 
    store_prod_tgt['kpi_name']='store_prod_rev_tgt' 
    store_prod_tgt=store_prod_tgt[['dt_id', 'circle', 'region_circle', 'brand', 
                                'mtd_value','lmtd_value','kpi_name','mth_id']] 
    summary2=tgt.groupby(['region', 'circle']).agg(
        mtd_tgt=('mtd_tgt','sum'), 
        lmtd_tgt=('lmtd_tgt','sum'),
        mtd_rev=('revenue_mtd','sum'), 
        lmtd_rev=('revenue_lmtd','sum')
    ).reset_index()
    summary2['mtd_ach']=summary2['mtd_rev']/summary2['mtd_tgt'] 
    summary2['lmtd_ach']=summary2['lmtd_rev']/summary2['lmtd_tgt']
    summary2['dt_id']=dt_id 
    summary2['mth_id']=mth 
    summary2['brand']='3ID' 
    store_rev = summary2[['region', 'circle', 'mtd_rev', 'lmtd_rev','dt_id','mth_id','brand']].copy() 
    store_rev.columns = ['region_circle', 'circle', 'mtd_value', 'lmtd_value','dt_id','mth_id','brand'] 
    store_rev['kpi_name']='store_rev' 
    store_rev=store_rev[['dt_id', 'circle', 'region_circle', 'brand', 
                                'mtd_value','lmtd_value','kpi_name','mth_id']] 
    store_rev_tgt = summary2[['region', 'circle', 'mtd_tgt', 'lmtd_tgt','dt_id','mth_id','brand']].copy() 
    store_rev_tgt.columns = ['region_circle', 'circle', 'mtd_value', 'lmtd_value','dt_id','mth_id','brand'] 
    store_rev_tgt['kpi_name']='store_rev_tgt' 
    store_rev_tgt=store_rev_tgt[['dt_id', 'circle', 'region_circle', 'brand', 
                                'mtd_value','lmtd_value','kpi_name','mth_id']] 
    store_rev_ach = summary2[['region', 'circle', 'mtd_ach', 'lmtd_ach','dt_id','mth_id','brand']].copy() 
    store_rev_ach.columns = ['region_circle', 'circle', 'mtd_value', 'lmtd_value','dt_id','mth_id','brand'] 
    store_rev_ach['kpi_name']='store_rev_ach' 
    store_rev_ach=store_rev_tgt[['dt_id', 'circle', 'region_circle', 'brand', 
                                'mtd_value','lmtd_value','kpi_name','mth_id']] 

    try:
        tunnel, connection = cockpit_connect_and_tunnel()
        store_prod_cnt.to_sql('retail_champion_club', schema='cockpit',  
                    con=connection, index=False, if_exists='append') 
        print("Data upload successfully.")
    finally:
        connection.close()
        tunnel.stop()
        print("Connection closed and tunnel stopped.")

    try:
        tunnel, connection = cockpit_connect_and_tunnel()
        store_prod_tgt.to_sql('retail_champion_club', schema='cockpit',  
                    con=connection, index=False, if_exists='append') 
        print("Data upload successfully.")
    finally:
        connection.close()
        tunnel.stop()
        print("Connection closed and tunnel stopped.")

    try:
        tunnel, connection = cockpit_connect_and_tunnel()
        store_prod_ach.to_sql('retail_champion_club', schema='cockpit',  
                    con=connection, index=False, if_exists='append') 
        print("Data upload successfully.")
    finally:
        connection.close()
        tunnel.stop()
        print("Connection closed and tunnel stopped.")

    try:
        tunnel, connection = cockpit_connect_and_tunnel()
        store_rev.to_sql('retail_champion_club', schema='cockpit',  
                    con=connection, index=False, if_exists='append') 
        print("Data upload successfully.")
    finally:
        connection.close()
        tunnel.stop()
        print("Connection closed and tunnel stopped.")

    try:
        tunnel, connection = cockpit_connect_and_tunnel()
        store_rev_ach.to_sql('retail_champion_club', schema='cockpit',  
                    con=connection, index=False, if_exists='append') 
        print("Data upload successfully.")
    finally:
        connection.close()
        tunnel.stop()
        print("Connection closed and tunnel stopped.") 

    try:
        tunnel, connection = cockpit_connect_and_tunnel()
        store_rev_tgt.to_sql('retail_champion_club', schema='cockpit',  
                    con=connection, index=False, if_exists='append') 
        print("Data upload successfully.")
    finally:
        connection.close()
        tunnel.stop()
        print("Connection closed and tunnel stopped.")


    df=cockpit_get_df(f"select * from cockpit.retail_champion_club where mth_id='{year_month}'") 
    df.to_csv(f"/data/retail/champion_clubs_retail_3id_{year_month}.csv", 
        index=False)
    os.system(f'''rclone copy /data/retail/champion_clubs_retail_3id_{year_month}.csv dsn:retail/kpi_retail/champion_club/''') 

    os.system(f'''rclone copy dsn:retail/kpi_retail/champion_club/champion_clubs_retail_3id_{year_month}.csv dsn:"Retail Performance Management - R100/champion_club"''')  

    status_job = "Champion clubs file uploaded successfully!"

    print(status_job) 

    os.system(f'''rm -rf /data/retail/champion_clubs_retail_3id_{year_month}.csv)''') 

    status_job = 'Dump data success' 
    return status_job

def clean_column_names(cols):
    # Step 1: Replace non-alphanumeric characters with underscore and convert to lowercase
    clean_cols = [col.lower().replace(' ', '_').replace('/', '').replace('(', '').replace(')', '').replace('.', '') for col in cols]
    clean_cols = [col.lower().replace('__', '_') for col in clean_cols]
    # Step 2: Handle duplicates by appending a suffix
    seen = set()
    final_cols = []
    for col in clean_cols:
        # If the column name already exists, add a suffix
        if col in seen:
            suffix = 1
            new_col = f"{col}_{suffix}"
            while new_col in seen:  # Check if the new name is still taken
                suffix += 1
                new_col = f"{col}_{suffix}"
            final_cols.append(new_col)
        else:
            final_cols.append(col)
            seen.add(col)
    
    return final_cols

@op
def t4_rtl_storelist(last_task):
    print(last_task)
    year_month=(dt.date.today()).strftime("%Y%m") 
    dt_id = (dt.date.today()).strftime("%Y%m%d")
    os.system(f'''rclone copy dsn:"Data/PBI 3KIOSK - MITRA IM3/Retail Reference" dsn:retail --include "PBI Database Retail IM3 & 3ID.xlsx"''')
    os.system(f'''rclone copy dsn:retail /data/retail --include "PBI Database Retail IM3 & 3ID.xlsx"''')
    df = pd.read_excel('/data/retail/PBI Database Retail IM3 & 3ID.xlsx', engine="openpyxl", dtype=str,
                  sheet_name='PBI Retail Store Ref')
    df.drop(columns={'No.'}, inplace=True)
    columns=df.columns
    # Apply the function to clean the column names
    cleaned_columns = clean_column_names(columns)
    df.columns=cleaned_columns
    df['update_dt']=dt_id
    df['mth_id']=year_month
    # Define the characters to remove
    chars_to_remove = '''\t#|,;"\n\r'''

    # Apply replacement
    for col in df.select_dtypes(include=['object']):
        df[col] = df[col].str.replace(f"[{chars_to_remove}]", " ", regex=True)
    
    df.to_csv(f'/data/retail/rtl_storelist_{dt_id}.csv', index=False, sep='|')
    ssh = SSHClient()
    ssh.set_missing_host_key_policy(AutoAddPolicy())
    ssh.connect('10.34.163.126', username='hdp-rdm', password='beqkZl@6' , port=22)
    sftp=ssh.open_sftp()   
    sftp.put(f"/data/retail/rtl_storelist_{dt_id}.csv", f"/home/hdp-rdm@office.corp.indosat.com/file_retail/rtl_storelist_{dt_id}.csv") 
    command=f"hdfs dfs -rm -R /data/rdm/upload/retail/rtl_storelist/rtl_storelist_{dt_id}.csv"
    stdin, stdout, stderr = ssh.exec_command(command)  # Non-blocking call
    exit_status = stdout.channel.recv_exit_status()          # Blocking call
    if exit_status == 0:
        print ("running_success")
    else:
        print("Error", exit_status)
    command=f"hdfs dfs -moveFromLocal /home/hdp-rdm@office.corp.indosat.com/file_retail/rtl_storelist_{dt_id}.csv /data/rdm/upload/retail/rtl_storelist/"
    stdin, stdout, stderr = ssh.exec_command(command)  # Non-blocking call
    exit_status = stdout.channel.recv_exit_status()          # Blocking call
    if exit_status == 0:
        print ("running_success")
    else:
        print("Error", exit_status) 
    command='impala-shell --quiet -i udc2-impala-lb.office.corp.indosat.com:25003 -d default -k --ssl -q "refresh rdm.rtl_storelist;"'
    stdin, stdout, stderr = ssh.exec_command(command)  # Non-blocking call
    exit_status = stdout.channel.recv_exit_status()          # Blocking call
    if exit_status == 0:
        print ("running_success")
    else:
        print("Error", exit_status)
    
    cockpit_execute_sql(f"delete from cockpit.rtl_storelist where update_dt={dt_id}")
    try:
        tunnel, connection = cockpit_connect_and_tunnel()
        df.to_sql('rtl_storelist', schema='cockpit',  
                    con=connection, index=False, if_exists='append') 
        print("Data upload successfully.")
    finally:
        connection.close()
        tunnel.stop()
        print("Connection closed and tunnel stopped.")
    
    status_job='success'
    return status_job

@op
def gcp_im3_intraction_revenue(): 
    filename = '/data/data_automation_bai/data_automation_scheduling/scripts/retail/gcp_dly_kpi.sql'
    fd = open(filename, 'r')
    sql_file = fd.read() 
    sql_file=sql_file.format(**{"year_month": year_month, 
                                "dt_id": dt_id
                                })
    fd.close() 
    query = sql_file.split(';')
    bq_project = "data-nationalslsdist-prd-986g"
    bq_dataset = "retail"
    # bq_table = "raw_new_verification"
    client = bigquery.Client(project=bq_project)
    print('Start Deleting Raw Interactions Revenue')
    query_delete=f""" 
    DELETE FROM
	`data-nationalslsdist-prd-986g`.retail.raw_im3_interaction_revenue
    WHERE left(dt_id,6) = left('{dt_id}',6);
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
        print(f"Inserting new data to `data-nationalslsdist-prd-986g`.postpaid.raw_daily_ga")
    except Exception as e:
        print(f"Error inserting new `data data-nationalslsdist-prd-986g`.postpaid.raw_daily_ga")
        raise

    print('Finish Deleting Raw Interactions Revenue')

    job_config = bigquery.QueryJobConfig(
        query_parameters=[
            bigquery.ScalarQueryParameter("year_month", "STRING", year_month),
            bigquery.ScalarQueryParameter("dt_id", "STRING", dt_id)
        ]
    )
 
    try:
        job = client.query(query[0], job_config=job_config)
        job.result()  # Wait for the job to complete
        print(f"Inserting new data to `data-nationalslsdist-prd-986g`.retail.raw_im3_interaction_revenue")
    except Exception as e:
        print(f"Error inserting new `data-nationalslsdist-prd-986g`.retail.raw_im3_interaction_revenue")
        raise
    
    # print('Starting dump report daily GA')
    # bq_project = "data-nationalslsdist-prd-986g"
    # bq_dataset = "retail" 
    # bq_table = "raw_im3_interaction_revenue"
    # client = bigquery.Client(project=bq_project)
    # # Your SQL query
    # query = f"""
    #     SELECT 
    #     dt_id,
    #     activity_type,
    #     store_code,
    #     replace(ticket_type, '|', ' ') ticket_type,
    #     replace(issue_group, '|', ' ') issue_group,
    #     replace(issue_sub, '|', ' ') issue_sub,
    #     replace(issue_desc, '|', ' ') issue_desc,
    #     cnt,
    #     cnt_msisdn,
    #     invoice_amount 
    #     FROM `{bq_project}.{bq_dataset}.{bq_table}`
    # """
    # # Run query and return DataFrame
    # df = client.query(query).to_dataframe()
    # df.to_csv('/data/rclone/sourcepostpaid/_RETAIL/ret_im3_interaction_revenue.csv', sep='|', index=False)
    
    status='Finish Create Report'
    print(status)
    return status

@op
def gcp_im3_traffic_visitor(last_status):
    print(last_status) 
    filename = '/data/data_automation_bai/data_automation_scheduling/scripts/retail/gcp_dly_kpi.sql'
    fd = open(filename, 'r')
    sql_file = fd.read() 
    sql_file=sql_file.format(**{"year_month": year_month, 
                                "dt_id": dt_id
                                })
    fd.close() 
    query = sql_file.split(';')
    bq_project = "data-nationalslsdist-prd-986g"
    bq_dataset = "retail"
    # bq_table = "raw_new_verification"
    client = bigquery.Client(project=bq_project)
    print('Start Deleting Raw Traffic Visitor')
    query_delete=f""" 
    DELETE FROM
	`data-nationalslsdist-prd-986g`.retail.raw_im3_traffic_visitor
    WHERE left(dt_id,6) = left('{dt_id}',6);
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
        print(f"Inserting new data to `data-nationalslsdist-prd-986g`.postpaid.raw_daily_ga")
    except Exception as e:
        print(f"Error inserting new `data data-nationalslsdist-prd-986g`.postpaid.raw_daily_ga")
        raise

    print('Finish Deleting Raw Interactions Revenue')

    job_config = bigquery.QueryJobConfig(
        query_parameters=[
            bigquery.ScalarQueryParameter("year_month", "STRING", year_month),
            bigquery.ScalarQueryParameter("dt_id", "STRING", dt_id)
        ]
    )
 
    try:
        job = client.query(query[1], job_config=job_config)
        job.result()  # Wait for the job to complete
        print(f"Inserting new data to `data-nationalslsdist-prd-986g`.retail.raw_im3_interaction_revenue")
    except Exception as e:
        print(f"Error inserting new `data-nationalslsdist-prd-986g`.retail.raw_im3_interaction_revenue")
        raise
    
    # print('Starting dump Traffic Visitor')
    # bq_project = "data-nationalslsdist-prd-986g"
    # bq_dataset = "retail" 
    # bq_table = "raw_im3_traffic_visitor"
    # client = bigquery.Client(project=bq_project)
    # # Your SQL query
    # query = f"""
    #     SELECT 
    #     dt_id, 
    #     store_code, 
    #     cnt_msisdn
    #     FROM `{bq_project}.{bq_dataset}.{bq_table}`
    # """
    # # Run query and return DataFrame
    # df = client.query(query).to_dataframe()
    # df.to_csv('/data/rclone/sourcepostpaid/_RETAIL/ret_im3_traffic_visitor.csv', sep='|', index=False)
    
    status='Finish Create Report'
    print(status)
    return status

@op
def gcp_sdp_trx(last_status):
    print(last_status) 
    bq_project = "data-nationalslsdist-prd-986g"
    client = bigquery.Client(project=bq_project)
    
    print('Starting dump 3KIOSK SDP Interaction from IPOS')
    query = f"""
        select 
            format_date('%Y-%m-%d',PARSE_TIMESTAMP('%d/%m/%Y %H:%M:%S', a.transaction_date)) as period,
            'IPOS' as source_data,
            a.username as opened_by,
            'Service Request' as intent,
            a.service_type as usecase,
            'Non Transaction' as intent_type,
            '' as FCR_Flag,
            count(distinct customer_msisdn) as TotalTrx
        from `data-nationalslsdist-prd-986g`.retail.raw_ipos_sdp_trx as a
        where format_date('%Y%m',PARSE_TIMESTAMP('%d/%m/%Y %H:%M:%S', a.transaction_date))=left('{dt_id}',6)
                and (`status` in ('Success', '') or `status` is null)
        group by 1, 2, 3, 4, 5, 6, 7
    """
    # # Run query and return DataFrame
    df = client.query(query).to_dataframe()
    df.to_csv(f'/data/retail/_3ID_SDP_Interaction_{year_month}.csv', index=False)
    os.system(f'''rclone copy /data/retail/_3ID_SDP_Interaction_{year_month}.csv dsn:retail/''')     
    os.system(f'''rclone copy dsn:retail/_3ID_SDP_Interaction_{year_month}.csv dsn:"Data/NEW RETAIL DASHBOARD/00_Dump Retail Cockpit/3ID Interaction"''') 
    
    status='Finish Create Report'
    print(status)
    return status

@op
def gcp_qmatics(last_status):
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
    return status

@graph
# def rtl_daily_kpi():
def rtl_etl(): 
    # t0_gp = t0_gp_3id_sce_ga()
    # t1_gp = t1_gp_3id_sim_rev(t0_gp)


    # t0_hdp = t0_hdp_im3_sce_ga() 
    # t1_hdp = t1_hdp_sensum_feed(t0_hdp) 
    # t2_hdp = t2_hdp_im3_cc(t1_hdp)
    # t3_hdp = t3_hdp_sr_tt(t2_hdp) 
    # t4_hdp = t4_hdp_im3_sim_rev(t3_hdp)

    # t0_cockpit = t0_cockpit_3id_dump()
    # t1_cockpit = t1_cockpit_3id_cc(t0_cockpit) 
    # t2_cockpit = t2_cockpit_3id_sr_tt(t1_cockpit) 
    # t3_cockpit = t3_cockpit_csat_3id(t2_cockpit)
    # t4_cockpit = t4_rtl_storelist(t3_cockpit)

    # t1_gcp = gcp_im3_intraction_revenue()
    # t2_gcp = gcp_im3_traffic_visitor(t1_gcp) 

    # serial 
    t1_gcp = gcp_im3_intraction_revenue()
    t2_gcp = gcp_im3_traffic_visitor(t1_gcp)
    # t3_gcp = gcp_qmatics(t2_gcp)
    t_hub1 = gcp_sdp_trx(t2_gcp)

    t0_cockpit = t0_cockpit_3id_dump(t_hub1)
    # t1_cockpit = t1_cockpit_3id_cc(t0_cockpit) 
    t2_cockpit = t2_cockpit_3id_sr_tt(t0_cockpit) 
    t3_cockpit = t3_cockpit_csat_3id(t2_cockpit)
    t_hub2 = t4_rtl_storelist(t3_cockpit)

    t0_gp = t0_gp_3id_sce_ga(t_hub2)
    t_hub3 = t1_gp_3id_sim_rev(t0_gp)

    # t0_hdp = t0_hdp_im3_sce_ga(t_hub3) 
    # t1_hdp = t1_hdp_sensum_feed(t0_hdp) 
    # t2_hdp = t2_hdp_im3_cc(t1_hdp)
    t3_hdp = t3_hdp_sr_tt(t_hub3) 
    t4_hdp = t4_hdp_im3_sim_rev(t3_hdp)

    return t4_hdp

@graph
def rtl_daily_kpi():
    t1=rtl_etl()
    t2=tri_retail_report(t1) 
    # t3=im3_retail_report(t2)
    t4=retail_interactions(t2)


