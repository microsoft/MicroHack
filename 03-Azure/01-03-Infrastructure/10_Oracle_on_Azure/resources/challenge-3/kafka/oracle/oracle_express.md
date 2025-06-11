# How to work with Oracle Express Edition 21c multitenancy 


## Connect to the Container Database (CDB) using SQL*Plus
sqlplus sys as sysdba


## Create a Pluggable Database (PDB) called demo_schema
CREATE PLUGGABLE DATABASE demo_admin ADMIN USER demo_schema IDENTIFIED BY password
  FILE_NAME_CONVERT = ('/opt/oracle/oradata/XE/pdbseed/', '/opt/oracle/oradata/XE/demo_schema/');


## Open the PDB if it is not already open
ALTER PLUGGABLE DATABASE demo_admin OPEN;


## Switch to the PDB
ALTER SESSION SET CONTAINER = demo_admin;


## Create a user in the PDB (optional)
CREATE USER demo_schema IDENTIFIED BY password;
GRANT CONNECT, RESOURCE, DBA TO demo_schema;


## Connect directly to the PDB using SQL*Plus
sqlplus demo_schema/password@//localhost:1521/demo_schema



# Delete / Drop a pdb in Oracle

## Connect to the CDB as SYSDBA
sqlplus sys as sysdba


## Use the ALTER PLUGGABLE DATABASE statement to close the PDB.
ALTER PLUGGABLE DATABASE demo_schema CLOSE IMMEDIATE;


## Use the DROP PLUGGABLE DATABASE statement to drop the PDB, including its data files.
DROP PLUGGABLE DATABASE demo_schema INCLUDING DATAFILES;


## Query all pdbs with schema
BEGIN
   FOR pdb IN (SELECT PDB_NAME FROM CDB_PDBS WHERE STATUS = 'NORMAL') LOOP
      EXECUTE IMMEDIATE 'ALTER SESSION SET CONTAINER = ' || pdb.PDB_NAME;
      DBMS_OUTPUT.PUT_LINE('Schemas in PDB: ' || pdb.PDB_NAME);
      FOR user_rec IN (SELECT USERNAME FROM ALL_USERS) LOOP
         DBMS_OUTPUT.PUT_LINE(user_rec.USERNAME);
      END LOOP;
   END LOOP;
END;
/