from dagster import op, graph, schedule, DefaultScheduleStatus, repository , RetryPolicy
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


year_month=(dt.date.today() - timedelta(days = 2)).strftime("%Y%m") 
dt_id = (dt.date.today() - timedelta(days = 2)).strftime("%Y%m%d") 

## SQL Script  
filename = '/data/data_automation_bai/data_automation_scheduling/scripts/retail/retail_im3_kpi.sql'
fd = open(filename, 'r')
sql_file = fd.read()
sql_file=sql_file.format(**{"year_month": year_month, 
                            "dt_id": dt_id
                            })
fd.close() 
query = sql_file.split(';')

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

@op 
def t0_ins_fcr(last_status):   
    print(last_status)
    cmd = query[0]
    print(cmd[:100])
    execute_query(cmd)
    return "last task success" 

@op 
def t1_dump_fcr(input_task):
    print(input_task) 
    cmd = query[1]
    print(cmd[:100])
    df=get_df(cmd) 
    print(df.head(10))
    df.to_excel(f"/data/retail/im3_agent_fcr_{year_month}.xlsx", 
         index=False)
    os.system(f'''rclone copy /data/retail/im3_agent_fcr_{year_month}.xlsx dsn:"retail/kpi_retail/fcr"''')
    os.system(f'''rclone copy dsn:"retail/kpi_retail/fcr/im3_agent_fcr_{year_month}.xlsx" dsn:"Retail Performance Management - R100/fcr"''')
    return "last task success" 

@graph
def im3_retail_report(last_status): 
    t0 = t0_ins_fcr(last_status) 
    t1 = t1_dump_fcr(t0)

    return t1