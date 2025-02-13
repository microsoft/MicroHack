# ora2pgWorkshop


## Useful links:


### Online documentation 

[Oracle to Azure PostgreSQL migration book](https://github.com/microsoft/OrcasNinjaTeam/blob/master/Oracle%20to%20PostgreSQL%20Migration%20Guide/Oracle%20to%20Azure%20Database%20for%20PostgreSQL%20Migration%20Guide.pdf)
[MSFT Doc - Oracle 2 Postgresql Migration mit Hilfe von ORA2PG](https://learn.microsoft.com/de-de/azure/postgresql/migrate/how-to-migrate-oracle-ora2pg)
[Ora2PG Github project](https://github.com/darold/ora2pg)


### Docker images

[ora2pg image: georgmoser/ora2pg](https://hub.docker.com/r/georgmoser/ora2pg)


Oracle image: 
[gvenzl/oracle-xe](https://hub.docker.com/r/georgmoser/ora2pg)
[jaspeen/oracle-11g](https://hub.docker.com/r/jaspeen/oracle-11g)


### Ora2PG installation under Linux / Windows

[Step-by-Step guide to Install ora2pg on Linux](https://download.microsoft.com/download/3/b/2/3b2dc2ed-849d-45dd-a68f-8ba8502c9faf/Step-by-Step%20guide%20to%20Install%20ora2pg%20on%20Linux.pdf)
[Steps to Install ora2pg on Windows and Linux.pdf](https://github.com/microsoft/DataMigrationTeam/blob/master/Whitepapers/Steps%20to%20Install%20ora2pg%20on%20Windows%20and%20Linux.pdf)



## DDLScript - Import the Schema Microhack 

Azure Microhack Oracle on Github available [here](https://github.com/microsoft/MicroHack/tree/oracle-migration-r-20250227/03-Azure/01-03-Infrastructure/10_Oracle_on_Azure/resources/environment_setup/Oracle_Schema)

If you find the original Oracle database sample files [here](https://www.oracle.com/database/technologies/appdev/datamodeler-samples.html)  to repeat the migration with different data sets. Please keep the Oracle license policies in mind before you use them. 

Additional open sourec data set can be downloaded like:
[Like NYC Taxi data](https://www.nyc.gov/site/tlc/about/tlc-trip-record-data.page), [TPC.ORG](https://www.tpc.org/tpcds/)


The workshop was checked against the available docker image mentioned above

Setting up a Linux vm server on Azure and install ora2pg natively on the 

## Linux: 


~~~bash
sudo -i
~~~

__From root user and depending on the used linux version__
~~~bash
apt-get 
rpm / dnf
yum update -y
yum install docker -y



mkdir /data /config
~~~

## Get inside container: 
~~~bash
docker run -it --privileged -v /mnt/maikmh/:/config -v /mnt/maikmh:/data georgmoser/ora2pg-docker /bin/bash

ora2pg --version

apt-get update -y

apt-get install vim
~~~


__Generate a migration project:__
~~~bash
ora2pg --project_base /data\`\`\` --init_project myproject
~~~

change ORACLE_DSN in config file:
~~~bash
vi /data/myproject/config/ora2pg.conf

cd data/myproject/
~~~

__Discovery:__

~~~bash
ora2pg -c config/ora2pg.conf -t SHOW_VERSION

ora2pg -c config/ora2pg.conf -t SHOW_SCHEMA 
~~~

__Check which tables contain DEMO_SCHAME schema:__
~~~bash
ora2pg -c config/ora2pg.conf -t SHOW_TABLE -n DEMO_SCHEMA
~~~

__List columns of table JOBS:__
~~~bash
ora2pg -c config/ora2pg.conf -t SHOW_COLUMN -a 'TABLE[EMPLOYEES]' -n DEMO_SCHEMA
~~~

__Generate report__
~~~bash
ora2pg -c config/ora2pg.conf -t SHOW_REPORT --estimate_cost --dump_as_html -n DEMO_SCHEMA > reports/report.html
~~~

 
## SCHEMA Migration

Offline migration
__Inside /data/myproject directory create a new directory:__
~~~bash
mkdir offline
cd offline
~~~

__Create a new file with following content:__

~~~bash
vi employees.sql

CREATE TABLE employees (
    employee_id NUMBER PRIMARY KEY,
    first_name VARCHAR2(50),
    last_name VARCHAR2(50),
    email VARCHAR2(100),
    hire_date DATE,
    salary NUMBER(10, 2),
    manager_id NUMBER,
    department_id NUMBER,
    address_id NUMBER,
bank_account_id NUMBER,
);
~~~

now run ora2pg against this file:
~~~bash
root@13a8720887da:/data/myproject/offline# ora2pg -i employees.sql -t TABLE -c ../config/ora2pg.conf 
[========================>] 1/1 tables (100.0%) end of table export.


root@13a8720887da:/data/myproject/offline# ls
CONSTRAINTS_output.sql	INDEXES_output.sql  employees.sql  output.sql
Investigate the content of 3 files that has been created.
~~~

Online migration
Create online directory inside your project:
~~~bash
root@13a8720887da:/data/myproject/offline# mkdir /data/myproject/online
root@13a8720887da:/data/myproject/offline# cd /data/myproject/online
~~~

Get the sources of oracle procedures:
~~~bash
root@13a8720887da:/data/myproject/online# ora2pg -t PROCEDURE -o procedure.sql -c ../config/ora2pg.conf
[========================>] 2/2 procedures (100.0%) end of procedures export.


root@13a8720887da:/data/myproject/online# ls
ADD_JOB_HISTORY_procedure.sql  SECURE_DML_procedure.sql  procedure.sql
Investigate the content of generated files
Add -p to the command above to convert procedures to plpgsql:
root@13a8720887da:/data/myproject/online# ora2pg -p -t PROCEDURE -o procedure.sql -c ../config/ora2pg.conf
[========================>] 2/2 procedures (100.0%) end of procedures export.

root@13a8720887da:/data/myproject/online# ls
ADD_JOB_HISTORY_procedure.sql  SECURE_DML_procedure.sql  procedure.sql
The previous content has been overwritten. Check if conversion went well by exploring the content of the files.
~~~
 
## Schema export 
Let run the export then!

__change the name of the schema in ora2pg.conf file:__

### Oracle schema/owner to use
~~~bash
SCHEMA  CHANGE_THIS_SCHEMA_NAME
~~~

__So it looks as follows:__
### Oracle schema/owner to use
~~~bash
SCHEMA DEMO_SCHEMA
~~~

Run the export. Make sure you are in the /data/myproject directory:
~~~bash
root@13a8720887da:/data/myproject# pwd
/data/myproject

root@13a8720887da:/data/myproject# ./export_schema.sh
~~~

Check the content of two directories:
•	sources - where oracle sources are kept
•	schema - with objects converted to PostgreSQL


## DATA Export
From /data/myproject run the following command:
~~~bash
ora2pg -t COPY -o data.sql -b ./data -c ./config/ora2pg.conf
~~~

Investigate the content of the data directory:
~~~bash
root@13a8720887da:/data/myproject# cd data/
root@13a8720887da:/data/myproject/data$ ls
ADDRESSES_data.sql  BANK_ACCOUNTS_data.sql  EMPLOYEES_AUDIT_data.sql  EMPLOYEE_DEPARTMENTS_data.sql   data.sql   AUDIT_LOG_data.sql  DEPARTMENTS_data.sql    EMPLOYEES_data.sql  TRANSFORMED_EMPLOYEES_data.sql
~~~

## PostgreSQL PaaS
•	Create an instance in Azure Database for PostgreSQL.
•	Connect to the instance and create a database using the instruction in this document.


### Import to PostgreSQL PaaS

Create .pg_azure file with the credentials to your PaaS database:
~~~bash
vi .pg_azure

export PGDATABASE=ora2pg
export PGHOST=name.postgres.database.azure.com
export PGUSER=user@host
export PGPASSWORD=VeryBadPractice;
~~~

Save the .pg_azure file and load it in the session:
~~~bash
source .pg_azure
~~~

Create a new database:
~~~bash
createdb ora2pg
~~~

From the /data/myproject directory load the files:
~~~bash
psql -f schema/tables/table.sql
psql -f schema/sequences/sequence.sql
psql -f schema/views/view.sql 
psql -f schema/procedures/procedure.sql
psql -f schema/triggers/trigger.sql
~~~
Check if all objects were correctly created in your new postgres database.

Import data:
~~~bash
psql -f data/data.sql
~~~

Create constraints:
~~~bash
psql -f schema/tables/INDEXES_table.sql
psql -f schema/tables/CONSTRAINTS_table.sql
psql -f schema/tables/FKEYS_table.sql
~~~


Optional part:

Test the migration
In order to lack of DBD::Pg perl module we are not able count rows. If you install the module the command to check migration looks as follows:
ora2pg -c config/ora2pg.conf -t TEST
Online data migration
For online data migration approach please refer here

