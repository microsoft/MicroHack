# How to work with Oracle Express Edition 21c multitenancy 

# Connect to the Container Database (CDB) using SQL*Plus
sqlplus sys as sysdba

# Open the PDB if it is not already open
ALTER PLUGGABLE DATABASE xepdb OPEN;

# Switch to the PDB
ALTER SESSION SET CONTAINER = xepdb;


# Create a user in the PDB (optional)
CREATE USER myuser IDENTIFIED BY mypassword;
GRANT CONNECT, RESOURCE TO myuser;


# Connect directly to the PDB using SQL*Plus
sqlplus myuser/mypassword@//localhost:1521/xepdb