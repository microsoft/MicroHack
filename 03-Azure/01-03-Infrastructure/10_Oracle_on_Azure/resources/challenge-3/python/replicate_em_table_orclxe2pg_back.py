import cx_Oracle
import psycopg2
import os
import platform

# This is the path to the ORACLE client files
lib_dir = r"C://oracle//instantclient_23_6"
try:
    cx_Oracle.init_oracle_client(lib_dir=lib_dir)
except Exception as err:
    print("Error connecting: cx_Oracle.init_oracle_client()")
    print(err)
    # sys.exit(1)

# Test to see if the cx_Oracle is recognized
print(cx_Oracle.version)   # this returns 8.0.1 for me

# Oracle connection
try:
    oracle_conn = cx_Oracle.connect('demo_schema', 'password', '127.0.0.1:1521/XE')
    oracle_cursor = oracle_conn.cursor()
    print("Connected to Oracle")
except cx_Oracle.DatabaseError as e:
    print(f"Error connecting to Oracle: {e}")
    oracle_conn = None

# PostgreSQL connection
try:
    pg_conn = psycopg2.connect(
        dbname='postgres',
        user='demo_schema',
        password='password',
        host='microhack.postgres.database.azure.com',
        port='5432',
        sslmode='require',
        options="-c search_path=demo_schema"
    )
    pg_cursor = pg_conn.cursor()
    print("Connected to PostgreSQL")
except psycopg2.DatabaseError as e:
    print(f"Error connecting to PostgreSQL: {e}")
    pg_conn = None

# Fetch changes from Oracle audit table and apply to PostgreSQL
if oracle_conn and pg_conn:
    try:
        # Verify data in Oracle audit table
        oracle_cursor.execute("SELECT COUNT(*) FROM demo_schema.employees_audit WHERE change_time > SYSDATE - INTERVAL '10' MINUTE")
        count = oracle_cursor.fetchone()[0]
        print(f"Number of changes in Oracle audit table: {count}")

        if count > 0:
            oracle_cursor.execute("SELECT operation, employee_id, first_name, last_name, email, hire_date, salary, change_time FROM demo_schema.employees_audit WHERE change_time > SYSDATE - INTERVAL '10' MINUTE")
            changes = oracle_cursor.fetchall()
            print(f"Fetched {len(changes)} changes from Oracle")

            # Apply changes to PostgreSQL
            for change in changes:
                operation, employee_id, first_name, last_name, email, hire_date, salary, change_time = change
                print(f"Processing {operation} for employee_id {employee_id}")
                pg_cursor.execute("""
                    INSERT INTO demo_schema.employees_audit (operation, employee_id, first_name, last_name, email, hire_date, salary, change_time)
                    VALUES (%s, %s, %s, %s, %s, %s, %s, %s)
                """, (operation, employee_id, first_name, last_name, email, hire_date, salary, change_time))
                print(f"Inserted audit record for employee_id {employee_id}")

            # Commit changes to PostgreSQL
            pg_conn.commit()
            print("Changes committed to PostgreSQL")

            # Verify the changes
            pg_cursor.execute("SELECT * FROM demo_schema.employees_audit")
            rows = pg_cursor.fetchall()
            print(f"Current rows in employees_audit table: {rows}")
        else:
            print("No changes found in Oracle audit table")

    except Exception as e:
        print(f"Error during data replication: {e}")

    # Close connections
    oracle_cursor.close()
    oracle_conn.close()
    pg_cursor.close()
    pg_conn.close()
else:
    print("Skipping data replication due to connection issues.")