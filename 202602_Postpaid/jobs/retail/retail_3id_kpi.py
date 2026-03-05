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
import paramiko
from dotenv import load_dotenv 
# set
load_dotenv("/data/data_automation_bai/data_automation_scheduling/cred/pst_rtl.env") 

year_month=(dt.date.today() - timedelta(days = 2)).strftime("%Y%m") 
dt_id = (dt.date.today() - timedelta(days = 2)).strftime("%Y%m%d") 

## SQL Script  
filename = '/data/data_automation_bai/data_automation_scheduling/scripts/retail/retail_3id_kpi.sql'
fd = open(filename, 'r')
sql_file = fd.read()

sql_file=sql_file.format(**{"year_month": year_month, 
                            "dt_id": dt_id
                            })  

# params_dt = {"year_month": year_month, "dt_id": dt_id}

fd.close() 
query = sql_file.split(';')

# SSH and MySQL connection settings
# ssh_host = '10.0.144.159'         # SSH host
# ssh_port = 22                     # SSH port (default is 22)
# ssh_user = 'dinar'    # SSH username
# ssh_password = '@AIengineer2503'  # SSH password (optional if using key)
# ssh_key_path = None               # Path to SSH private key if used

# # Cockpit SSH and MySQL connection settings
# ssh_host = os.getenv("cockpit_ssh_host")
# ssh_port = int(os.getenv("cockpit_ssh_port"))
# ssh_user = os.getenv("cockpit_ssh_user")
# ssh_password = os.getenv("cockpit_ssh_password")
# ssh_key_path = None
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
def connect_and_tunnel(
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

# def connect_and_tunnel():
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

def get_df(query, params=None):
    try:
        tunnel, connection = connect_and_tunnel()
        df = pd.read_sql(query, connection)
        print("Data fetched successfully.")
        return df
    finally:
        connection.close()
        tunnel.stop()
        print("Connection closed and tunnel stopped.")

def execute_sql(command, params=None):
    try:
        tunnel, connection = connect_and_tunnel()
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
def t0_del_fcr(last_status):
    print(last_status)   
    cmd = query[0]
    print(cmd[:100])
    execute_sql(cmd)
    return "last task success" 

@op 
def t1_ins_fcr(input_task):  
    print(input_task)   
    cmd = query[1]
    print(cmd[:100])
    execute_sql(cmd)
    return "last task success" 

@op 
def t2_dump_fcr(input_task):
    print(input_task) 
    cmd = query[2]
    print(cmd[:100])
    df=get_df(cmd)
    df.to_excel(f"/data/retail/3id_agent_fcr_{year_month}.xlsx", 
         index=False)
    os.system(f'''rclone copy /data/retail/3id_agent_fcr_{year_month}.xlsx dsn:"retail/kpi_retail/fcr"''') 
    os.system(f'''rclone copy dsn:"retail/kpi_retail/fcr/3id_agent_fcr_{year_month}.xlsx" dsn:"Retail Performance Management - R100/fcr"''')
    return "last task success"  

@op 
def t3_dump_csat(input_task):
    print(input_task) 
    cmd = query[3]
    print(cmd[:100])
    df=get_df(cmd)
    df.to_excel(f"/data/retail/3id_agent_csat_{year_month}.xlsx", 
         index=False)
    os.system(f'''rclone copy /data/retail/3id_agent_csat_{year_month}.xlsx dsn:"retail/kpi_retail/csat"''') 
    os.system(f'''rclone copy dsn:"retail/kpi_retail/csat/3id_agent_csat_{year_month}.xlsx" dsn:"Retail Performance Management - R100/csat"''')
    return "last task success" 

@graph
def tri_retail_report(last_status):
    t0 = t0_del_fcr(last_status) 
    t1 = t1_ins_fcr(t0) 
    t2 = t2_dump_fcr(t1) 
    t3 = t3_dump_csat(t2)

    return t3