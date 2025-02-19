# How to query remote date between Oracle and Azure PGFS

The following demo will show quickly how to use the PostgreSQL extension ORACLE_FDW to query remote table data from an Oracle database and ingest them into an AZURE PGFS. 

1. Delete in advance the remote example with oracle_fdw
~~~bash
DROP SERVER oracle_server CASCADE;
DROP USER MAPPING FOR demo_schema SERVER oracle_server;
DROP TABLE postgres_table;
DROP FOREIGN TABLE oracle_table;
~~~


2. Connect via SQLPlus on the oracle database and create in our case a small demo table for the test case.
~~~bash
Create the oracle_table
CREATE TABLE oracle_table (
    id NUMBER PRIMARY KEY,
    name VARCHAR2(100),
    value NUMBER
);
~~~

In the second step insert data into the created oracle table oracle_table:
~~~bash
INSERT INTO oracle_table (id, name, value) VALUES (1, 'Item 1', 100);
INSERT INTO oracle_table (id, name, value) VALUES (2, 'Item 2', 200);
INSERT INTO oracle_table (id, name, value) VALUES (3, 'Item 3', 300);
~~~

3. Connect as Admin on the PostgreSQL Flexible Server and enable the extension ORACLE_FDW if not already done.

Use the PostgreSQL CLI psql or PGADMIN

The connection to the Azure PostgreSQL database server depends on the used deployment method User/Password or Entra ID.
~~~bash
psql -h microhack.postgres.database.azure.com -p 5432 -U Maik.Sandmann@microsoft.com postgres
~~~


4. Enable the required extensions in PostgreSQL Server
~~~bash
CREATE EXTENSION oracle_fdw;
~~~


5. Grant rights to the database user
~~~bash
GRANT USAGE ON FOREIGN DATA WRAPPER oracle_fdw TO demo_schema;
GRANT CREATE ON DATABASE your_database TO demo_schema;
~~~


6. Connect as the created user demo_schema on the PostgreSQL database


7. Create a foreign server that points to the Oracle database use the ip address of the vm server

a. 48.209.90.102 or the fqdn
b. microhack.westeurope.cloudapp.azure.com

~~~bash
CREATE SERVER oracle_server
FOREIGN DATA WRAPPER oracle_fdw
OPTIONS (dbserver '//48.209.90.102:1521/XE');
~~~


8. Create a user mapping that maps a PostgreSQL user to an Oracle user.
~~~bash
CREATE USER MAPPING FOR demo_schema
SERVER oracle_server
OPTIONS (user 'demo_schema', password 'password');
~~~


9. Create foreign tables in PostgreSQL that map to the Oracle tables.

Oracle table names are case-sensitive. If the table was created without quotes, it is stored in uppercase. Ensure that the table name is specified correctly in the PostgreSQL foreign table definition.
~~~bash
CREATE FOREIGN TABLE oracle_table (
    id INTEGER,
    name VARCHAR(100),
    value NUMERIC
)
SERVER oracle_server
OPTIONS (schema 'DEMO_SCHEMA', table 'ORACLE_TABLE');
~~~


10. Create a PostgreSQL table
~~~bash
CREATE TABLE postgres_table (
    id INTEGER,
    name VARCHAR(100),
    value NUMERIC
);
~~~


11. Insert data from Oracle into PostgreSQL
~~~bash
INSERT INTO postgres_table (id, name, value)
SELECT id, name, value
FROM oracle_table;
~~~


12. Query the remote ingested data from the Oracle database
~~~bash
SELECT * from postgres_table;
~~~

<br>

![Output in PGAdmin](images/Select_PG_Table_FDW.png)



