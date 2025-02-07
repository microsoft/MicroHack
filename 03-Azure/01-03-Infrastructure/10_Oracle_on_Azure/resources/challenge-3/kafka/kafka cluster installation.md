online documentation 

https://docs.confluent.io/kafka-connectors/oracle-cdc/current/prereqs-validation.html#connect-oracle-cdc-source-prereqs-user-privileges




Step 1: 
Set Up Kafka with or without Debezium 
    - choose confluent
    - choose kafka apache

Create a Docker Compose File: Create a docker-compose.yml file to set up Kafka, Zookeeper, and Debezium

    see file docker-compose.yml


If the container doesn't communicate well, you can delete existing created networks via:

    docker network prune

    

Step 2:
Configure the Oracle database 

For old Oracle release utl_file_dir can be used in newer release directory replaced utl_file_dir
a: SET the utl_file_dir parameter:

connect to the oracle docker container:
    docker exec -it oracle-xe1 bash

    mkdir -p /u01/app/oracle/admin/dpdump
    chmod 755 /u01/app/oracle/admin/dpdump


sqlpus / as sysdba
    ALTER SYSTEM SET utl_file_dir = '/u01/app/oracle/admin/dpdump' SCOPE=SPFILE;


    SHUTDOWN IMMEDIATE;
    STARTUP;

--------------------------------------------------------------------------------
    do not execute instead continue with the creation of a directory (go to b.)
    SQL> declare
    file_open utl_file.file_type;
    begin
    file_open:=utl_file.fopen('LOGMINER_DIR','utl_file.ora', 'w');
    utl_file.fclose(file_open);
    end;
    /

    show parameter utl_file_dir;

    
    If you disable UTL_FILE execute the following steps:
    
    a. ALTER SYSTEM SET utl_file_dir = '' SCOPE=SPFILE;
    b. SHUTDOWN IMMEDIATE
    c. STARTUP
--------------------------------------------------------------------------------

b. Use Directory instead of utl_file_dir if possible

show parameter utl_file_dir;

create directory logminer_dir as '/u01/app/oracle/admin/dpdump';

CREATE OR REPLACE DIRECTORY logminer_dir AS '/u01/app/oracle/admin/dpdump';

GRANT READ, WRITE ON DIRECTORY logminer_dir TO public;
    
 
    select * from dba_directories where directory_name like 'LOGMINER_DIR';

    Create the LogMiner Dictionary:
    EXECUTE DBMS_LOGMNR_D.BUILD('dictioniary.ora', 'LOGMINER_DIR');


c: Enable SUPPLEMENTAL Logging in the oracle database:

    ALTER DATABASE ADD SUPPLEMENTAL LOG DATA;

    --- if newer oracle databases are used!!!
    ALTER SYSTEM SET ENABLE_GOLDENGATE_REPLICATION=TRUE SCOPE=BOTH;
    ALTER SYSTEM SET ENABLE_LOGMINING=TRUE SCOPE=BOTH;
    
      
    ALTER SYSTEM SWITCH LOGFILE;

    Depending on the use database 11g vs 19c for example check the following parameter of the database:

        SQL> SHOW PARAMETER ENABLE_GOLDENGATE_REPLICATION;

            NAME                                 TYPE        VALUE
            ------------------------------------ ----------- ------------------------------
            enable_goldengate_replication        boolean     TRUE

            SQL> SHOW PARAMETER SUPPLEMENTAL_LOG_DATA;

            NAME                                 TYPE        VALUE
            ------------------------------------ ----------- ------------------------------
            supplemental_log_data_min            boolean     TRUE
            supplemental_log_data_pk             boolean     TRUE
            supplemental_log_data_ui             boolean     TRUE


b:  Switch database in archive log mode
    
    sqlplus / as sysdba
    
    SQL> SELECT LOG_MODE FROM V$DATABASE;
    
    LOG_MODE
    ------------
    NOARCHIVELOG
    
    SQL> show parameter LOG_ARCHIVE_DEST_1
    
    NAME                                 TYPE        VALUE
    ------------------------------------ ----------- ------------------------------
    log_archive_dest_1                   string
    log_archive_dest_10                  string
    log_archive_dest_11                  string
    log_archive_dest_12                  string
    log_archive_dest_13                  string
    log_archive_dest_14                  string
    log_archive_dest_15                  string
    log_archive_dest_16                  string
    log_archive_dest_17                  string
    log_archive_dest_18                  string
    log_archive_dest_19                  string
    
    ALTER SYSTEM SET LOG_ARCHIVE_DEST_1 = 'LOCATION=USE_DB_RECOVERY_FILE_DEST' scope=both;
    
    System altered.
    Now you need to stop the Oracle database and to mount it.

    SQL> SHUTDOWN IMMEDIATE
    Database closed.
    Database dismounted.
    ORACLE instance shut down.
    
    SQL> STARTUP MOUNT
    ORACLE instance started.
    
    Total System Global Area 1073738888 bytes
    Fixed Size                  9143432 bytes
    Variable Size             532676608 bytes
    Database Buffers          524288000 bytes
    Redo Buffers                7630848 bytes
    Database mounted.
    
    SQL> ALTER DATABASE ARCHIVELOG;
    
    Database altered.
    
    SQL> ALTER DATABASE OPEN;
    
    Database altered.
    
    SQL> ALTER SYSTEM SWITCH LOGFILE;
    
    System altered.
    So now you can check that archive log mode is enabled in your Oracle database.

    SQL> SELECT NAME FROM V$ARCHIVED_LOG;
    
    NAME
    --------------------------------------------------------------------------------
    /u01/app/oracle/fra/ORADB/archivelog/2021_04_10/o1_mf_1_19_j72qftrw_.arc
    
    SQL> SELECT LOG_MODE FROM V$DATABASE;
    
    LOG_MODE
    ------------
    ARCHIVELOG
    
    SQL> show parameter LOG_ARCHIVE_DEST_1
    
    NAME                                 TYPE        VALUE
    ------------------------------------ ----------- ------------------------------
    log_archive_dest_1                   string      LOCATION=USE_DB_RECOVERY_FILE_
                                                    DEST
    log_archive_dest_10                  string
    log_archive_dest_11                  string
    log_archive_dest_12                  string
    log_archive_dest_13                  string
    log_archive_dest_14                  string
    log_archive_dest_15                  string
    log_archive_dest_16                  string
    log_archive_dest_17                  string
    log_archive_dest_18                  string
    log_archive_dest_19                  string


c: Create a database user for debezium

    CREATE USER debezium IDENTIFIED BY debezium;
    GRANT CONNECT, RESOURCE TO debezium;
    GRANT SELECT ANY TABLE TO debezium;
    GRANT SELECT_CATALOG_ROLE TO debezium;
    GRANT CREATE SESSION TO debezium;
    GRANT EXECUTE_CATALOG_ROLE TO debezium;
    GRANT FLASHBACK ANY TABLE TO debezium;
    GRANT SELECT ANY TRANSACTION TO debezium;
    GRANT READ, WRITE ON DIRECTORY logminer_dir TO debezium;
    GRANT LOGMINING TO debezium;

    For older databases like 11g rel.2 where the role logmining is not available grant the following roles:
    CREATE USER debezium IDENTIFIED BY debezium;
    GRANT READ, WRITE ON DIRECTORY logminer_dir TO debezium;
    GRANT CONNECT, RESOURCE TO debezium;
    GRANT SELECT ANY TABLE TO debezium;
    GRANT SELECT_CATALOG_ROLE TO debezium;
    GRANT CREATE SESSION TO debezium;
    GRANT EXECUTE_CATALOG_ROLE TO debezium;
    GRANT FLASHBACK ANY TABLE TO debezium;
    GRANT SELECT ANY TRANSACTION TO debezium;
    GRANT ALTER ANY TABLE TO debezium;
    GRANT CREATE TABLE TO debezium;
    GRANT LOCK ANY TABLE TO debezium;
    GRANT CREATE SEQUENCE TO debezium;
    GRANT CREATE TRIGGER TO debezium;
    GRANT CREATE VIEW TO debezium;
    GRANT UNLIMITED TABLESPACE TO debezium;


    CREATE USER demo_schema IDENTIFIED BY "password";
    GRANT CONNECT, RESOURCE, DBA TO demo_schema;
    ALTER USER demo_schema QUOTA UNLIMITED ON USERS;
    ALTER USER demo_schema QUOTA 1000M ON USERS;
   
    GRANT CONNECT, RESOURCE TO demo_schema;
    GRANT READ, WRITE ON DIRECTORY logminer_dir TO demo_schema;
    GRANT SELECT ANY TABLE TO demo_schema;
    GRANT SELECT_CATALOG_ROLE TO demo_schema;
    GRANT CREATE SESSION TO demo_schema;
    GRANT EXECUTE_CATALOG_ROLE TO demo_schema;
    GRANT FLASHBACK ANY TABLE TO demo_schema;
    GRANT SELECT ANY TRANSACTION TO demo_schema;
    GRANT ALTER ANY TABLE TO demo_schema;
    GRANT CREATE TABLE TO demo_schema;
    GRANT LOCK ANY TABLE TO demo_schema;
    GRANT CREATE SEQUENCE TO demo_schema;
    GRANT CREATE TRIGGER TO demo_schema;
    GRANT CREATE VIEW TO demo_schema;
    GRANT UNLIMITED TABLESPACE TO demo_schema;
    CREATE ROLE CDC_PRIVS;
    GRANT CREATE SESSION TO CDC_PRIVS;
    GRANT LOGMINING TO CDC_PRIVS;
    GRANT SELECT ON V_$DATABASE TO demo_schema;
    GRANT SELECT ON V_$INSTANCE to demo_schema;
    GRANT SELECT ON V_$THREAD TO demo_schema;
    GRANT SELECT ON V_$PARAMETER TO demo_schema;
    GRANT SELECT ON V_$NLS_PARAMETERS TO demo_schema;
    GRANT SELECT ON V_$TIMEZONE_NAMES TO demo_schema;
    GRANT SELECT ON V_$LOG TO demo_schema;
    GRANT SELECT ON V_$LOGFILE TO demo_schema;
    GRANT SELECT ON V_$LOGMNR_CONTENTS TO demo_schema;
    GRANT SELECT ON V_$ARCHIVED_LOG TO demo_schema;
    GRANT SELECT ON V_$ARCHIVE_DEST_STATUS TO demo_schema;
    GRANT EXECUTE ON SYS.DBMS_LOGMNR TO demo_schema;
    GRANT EXECUTE ON SYS.DBMS_LOGMNR_D TO demo_schema;


d. Create database schema - see orcl_setup01_oracle_schema.sql
   Execute initial data load - see orcl_setup02:initial_dataload.sql
   verify the data load ingested the demo data successfully

   SQL> select count(*) from employees;

        COUNT(*)
        ----------
        10000


Step 2: 
Start the Kafka Cluster: Run the following command to start the Kafka cluster:

    start the container zookeeper, kafka, connect 
    
        docker-compose start zookeeper, kafka, connect

        docker compose -f 'kafka\docker-compose.yaml' up -d --build 'zookeeper'

    The following command would start the complete containers -- don't use the one here docker-compose up -d


Step 2a:

check the if the containers are reachable. if your are using docker on Windows use the WSL in Windows.

nc -zv localhost 22181
Connection to localhost port 22181 [tcp/*] succeeded!

nc -zv localhost 29092
Connection to localhost port 29092 [tcp/*] succeeded!


Step 2b: Check kafka connect logs
    
    docker-compose logs connect 
    docker logs <container-name>


Step 3: Test and execute a first message in kafka

    1. open a new terminal/cmd and log into the kafka container
        docker exec -it  kafka-kafka-1 bash
        
        Create the test topic called test-topic
        a.  /bin/kafka-topics --create --topic test-topic --bootstrap-server 172.18.0.1:9092 --partitions 1 --replication-factor 1
        b. Create a producer to send a test message
            /bin/kafka-console-producer --broker-list 172.18.0.1:9092 --topic test-topic

        c. Delete the topics
            kafka-topics --delete --topic schema-changes-oracle --bootstrap-server localhost:9092

        d. set the retention time of a topic
            kafka-configs.sh --alter --entity-type topics --entity-name schema-changes.oracle --add-config retention.ms=1000 --bootstrap-server localhost:9092


    2. open a new terminal/cmd and log into the kafka container 
        docker exec -it  kafka-kafka-1 bash
        Now we will consumed the previous meesage using kafka shell.
        /bin/kafka-console-consumer --bootstrap-server 172.18.0.1:9092 --topic test-topic --from-beginning



Step 4: Configure the oracle connector of Debezium

oracle-connector.json
    Identify the database.hostname by using docker inspect container-name (in our case oracle-xe)

    {
    "name": "oracle-connector",  // The name of the connector instance
    "config": {
        "connector.class": "io.debezium.connector.oracle.OracleConnector",  // The class for the Oracle connector
        "tasks.max": "1",  // The maximum number of tasks to be created by this connector
        "database.server.name": "oracle",  // Logical name for the database server, used for namespacing Kafka topics
        "database.hostname": "172.20.0.3",  // Actual hostname or IP address of the Oracle database
        "database.port": "1521",  // Port number where the Oracle database is listening
        "database.user": "debezium",  // Username to connect to the Oracle database
        "database.password": "debezium",  // Password to connect to the Oracle database
        "database.dbname": "XE",  // Name of the Oracle database (SID)
        "database.pdb.name": "XEPDB1",  // Name of the pluggable database (PDB) if applicable
        "database.out.server.name": "dbzxout",  // Name of the Oracle LogMiner out server
        "database.history.kafka.bootstrap.servers": "kafka:9092",  // Kafka bootstrap servers for storing database history
        "database.history.kafka.topic": "schema-changes-oracle",  // Kafka topic for storing database schema history
        "database.connection.adapter": "logminer",  // Adapter to use for capturing changes (LogMiner in this case)
        "database.tablename.case.insensitive": "false",  // Whether table names are case insensitive
        "database.history.store.only.monitored.tables.ddl": "true",  // Store DDL changes only for monitored tables
        "database.history.skip.unparseable.ddl": "true"  // Skip unparseable DDL statements
    }
    }

    Explanation of Each Variable:
    name: The name of the connector instance.
    connector.class: The fully qualified class name of the connector.
    tasks.max: The maximum number of tasks that should be created for this connector.
    database.server.name: A logical name that identifies the database server/cluster. This name is used to namespace all the Kafka topics generated by this connector.
    database.hostname: The hostname or IP address of the Oracle database server.
    database.port: The port number on which the Oracle database is listening.
    database.user: The username to connect to the Oracle database.
    database.password: The password to connect to the Oracle database.
    database.dbname: The SID (System Identifier) of the Oracle database.
    database.pdb.name: The name of the pluggable database (PDB) if applicable.
    database.out.server.name: The name of the Oracle LogMiner out server.
    database.history.kafka.bootstrap.servers: The Kafka bootstrap servers used for storing the database history.
    database.history.kafka.topic: The Kafka topic used for storing the database schema history.
    database.connection.adapter: The adapter to use for capturing changes. In this case, it is set to logminer.
    database.tablename.case.insensitive: Whether table names are case insensitive.
    database.history.store.only.monitored.tables.ddl: Whether to store DDL changes only for monitored tables.
    database.history.skip.unparseable.ddl: Whether to skip unparseable DDL statements.

---------------------------------------------------------------------------------------------------------

    Error management in case the oracle-connector can not be registered 

    If there are http 400 error you can test the oracle connection from the kafka-connect container by following the next steps:

    1. docker exec -it kafka-connect /bin/bash

    2. Create the following small java program:

        import java.sql.Connection;
        import java.sql.DriverManager;
        import java.sql.SQLException;

        public class OracleConnectionTest {
            public static void main(String[] args) {
                String jdbcUrl = "jdbc:oracle:thin:@oracle-xe1:1521:XE";
                String username = "demo_schema";
                String password = "password";

                try {
                    Connection connection = DriverManager.getConnection(jdbcUrl, username, password);
                    System.out.println("Connected to Oracle database!");
                    connection.close();
                } catch (SQLException e) {
                    e.printStackTrace();
                }
            }
        }

    3. check the java verions on your docker conatiner kafka-connect via:

        java -version
        openjdk version "11.0.15" 2022-04-19


    4.  javac -source 11 -target 11 .\OracleConnectionTest.java

    5. upload the compiled java class on the docker container

        docker cp .\OracleConnectionTest.class kafka-connect:/tmp
        
    6. Execute the OracleConnectionTest file on the docker container

        java -cp .:/kafka/plugins/ojdbc8.jar OracleConnectionTest
            Connected to Oracle database!

    
    Further possibilities is to change the variable in oracle-connector.json

    - Instead of "database.dbname": "XE", try "database.SID": "XE"

    - Is the topic.prefix required in oracle-connector.json ? "topic.prefix": "oracle-"

    - Instead of using hostname, port, dbname you can try out -  "database.url": "jdbc:oracle:thin:@165.22.61.66:49161:XE",



Step5: Connector registration in Debezium via curl 

please consider the curl command in powershell vs bash / cmd looks different. The following curl command is for a BASH / CMD execution.

How to create or recreate the oracle debezium connector
a: curl -i -X POST -H "Accept:application/json" -H "Content-Type:application/json" http://localhost:8083/connectors/ -d @oracle-connector.json

Option: How to delete the oracle debezium connector if required and recreate the one 
curl -X DELETE http://localhost:8083/connectors/oracle-connector


if the status displayed error the log level in the file oracle-connector.json can be set on DEBUG in the Config settings via the following command:
          
          CONNECT_LOG4J_ROOT_LOGLEVEL: DEBUG

    a. Typical error are for example ora-02248 if the database is not configured as a Multi-Tenancy database.
        
        If your database is not a multi-tenacy database removed in the oracle-connector.json file the like database.pdb.name
    
    b. The error ORA-18716: {0} not in any time zone.DATE indicates that there is an issue with the time zone configuration in your Oracle database

        online information about how to set time_zone in Oracle can be found here - https://oracle-base.com/articles/misc/setting-database-time-zones-in-oracle

        See Solution subsequent:

            sqlplus / as sysdba

            SQL> SELECT DBTIMEZONE FROM DUAL;

            DBTIMEZONE
            ----------
            +00:00

            SQL> SELECT SESSIONTIMEZONE FROM DUAL;

            SESSIONTIMEZONE
            ---------------
            +00:00

            SQL> SELECT * FROM V$TIMEZONE_FILE;

            FILENAME                VERSION     CON_ID
            -------------------- ---------- ----------
            timezlrg_32.dat             32          0

        
        Set Time zone in the following example to UTC: 

        ALTER DATABASE SET TIME_ZONE = 'UTC';


        restart database if required:
            
            SHUTDOWN IMMEDIATE;
            STARTUP;
            ALTER SESSION SET TIME_ZONE = 'UTC';



Following the output if you don't have any issues.

    Output:
    HTTP/1.1 201 Created
    Date: Sun, 26 Jan 2025 10:13:22 GMT
    Location: http://localhost:8083/connectors/oracle-connector
    Content-Type: application/json
    Content-Length: 710
    Server: Jetty(9.4.44.v20210927)

    {"name":"oracle-connector","config":
        {"connector.class":
                "io.debezium.connector.oracle.OracleConnector",
            "tasks.max":
                "1",
            "database.server.name":
                "oracle",
            "database.hostname":
                "oracle-xe1",
            "database.port":
                "1521",
            "database.user":
                "debezium",
            "database.password":
                "debezium",
            "database.dbname":
                "XE",
            "database.pdb.name":
                "XEPDB1",
            "database.out.server.name":
                "dbzxout",
            "database.history.kafka.bootstrap.servers":
            "kafka:9092",
            "database.history.kafka.topic":
                "schema-changes.oracle",
            "database.connection.adapter":
                "logminer",
            "database.tablename.case.insensitive":
                "false",
            "database.history.store.only.monitored.tables.ddl":
                "true",
            "database.history.skip.unparseable.ddl":
                "true",
            "name":
                "oracle-connector"
            },
            "tasks":[],
            "type":
                "source"
    }


b: How to pause, resume and restart the connector

    # Pause the connector
    curl -X PUT http://localhost:8083/connectors/oracle-connector/pause

    # Resume the connector
    curl -X PUT http://localhost:8083/connectors/oracle-connector/resume

    # Alternatively, restart the connector
    curl -X POST http://localhost:8083/connectors/oracle-connector/restart

    # Verify the connector status
    curl -X GET http://localhost:8083/connectors/oracle-connector/status



Step6: Check kafka connect logs
    docker-compose logs connect 
    docker logs <container-name>



Step7:

on windows / linux -> curl -X GET http://localhost:8083/connectors/oracle-connector/status

on linux (need to install JQ) ->curl -s localhost:8083/connector-plugins|jq '.[].class'


Output:

    {"name":"oracle-connector",
    "connector":
    {
        "state":"RUNNING",
        "worker_id":"172.18.0.6:8083"
    },
        "tasks":
        [{
            "id":0,
            "state":"RUNNING",
            "worker_id":"172.18.0.6:8083"
        }],
        "type":"source"
    }


Step 7a:

Check Kafka Broker Status
You can check the status of your Kafka broker by listing the topics available in the cluster. This can be done using the kafka-topics.sh script.

    List Topics:
    docker exec -it kafka-kafka-1 kafka-topics --bootstrap-server kafka:9092 --list


Describe a Topic
To get more details about a specific topic, you can describe it using the kafka-topics.sh script.

    Describe Topic
    



Step8: Create a PostgreSQL sink connector

    create postgres-sink-connector.json file and add the following parameter:

        {
    "name": "postgres-sink-connector",
    "config": {
        "connector.class": "io.confluent.connect.jdbc.JdbcSinkConnector",
        "tasks.max": "1",
        "topics": "schema-changes.oracle",
        "connection.url": "jdbc:postgresql://<azure-postgres-host>:5432/<database-name>",
        "connection.user": "<username>",
        "connection.password": "<password>",
        "auto.create": "true",
        "auto.evolve": "true",
        "insert.mode": "upsert",
        "pk.mode": "record_key",
        "pk.fields": "id",
        "delete.enabled": "false"
            }
        }


name: The name of the connector.
    connector.class: The class name of the connector to use.
    tasks.max: The maximum number of tasks to create for this connector.
    topics: The Kafka topics to consume data from.
    connection.url: The JDBC connection URL for the PostgreSQL database.
    connection.user: The username to connect to the PostgreSQL database.
    connection.password: The password to connect to the PostgreSQL database.
    auto.create: Whether to automatically create the destination table.
    auto.evolve: Whether to automatically evolve the table schema.
    insert.mode: The insertion mode to use.
    pk.mode: The primary key mode to use.
    pk.fields: The fields to use as the primary key.
    delete.enabled: Whether to enable deletion of records.
    schema.enable: Whether to enable schema support.
    key.converter: The converter class to use for the key.
    key.converter.schemas.enable: Whether to enable schema support for the key converter.
    value.converter: The converter class to use for the value.
    value.converter.schemas.enable: Whether to enable schema support for the value converter.
    table.name.format: The format string for the destination table name.


    curl -i -X POST -H "Accept:application/json" -H "Content-Type:application/json" http://localhost:8083/connectors/ -d @postgres-sink-connector.json
    
    output:
    HTTP/1.1 201 Created
    Date: Mon, 27 Jan 2025 09:49:42 GMT
    Location: http://localhost:8083/connectors/postgres-sink-connector
    Content-Type: application/json
    Content-Length: 497
    Server: Jetty(9.4.44.v20210927)

    {"name":"postgres-sink-connector","config":
    {"connector.class":
    "io.confluent.connect.jdbc.JdbcSinkConnector","tasks.max":
    "1","topics":
    "schema-changes.oracle","connection.url":
    "jdbc:postgresql://microhack.postgres.database.azure.com:5432/postgres","connection.user":
    "debezium","connection.password":"debezium","auto.create":"true","auto.evolve":"true","insert.mode":"upsert","pk.mode":
    "record_key","pk.fields":"id","delete.enabled":"false","name":"postgres-sink-connector"},"tasks":[],"type":"sink"}


Step 8: Monitoring of the data replication 

    Connect into the kafka-kafka-1 container
     
    execute the following query to track the changes
    kafka-console-consumer --bootstrap-server localhost:9092 --topic schema-changes-oracle --from-beginning


Step 9: Required configuration step in kafka

a. Display the kafka-topics version
kafka-topics --version

curl -X GET http://localhost:8083/
{"version":"3.2.0","commit":"38103ffaa962ef50","kafka_cluster_id":"qrb6F8mTTzGIPERygDo2NA"}

b. Check Kafka Broker Configuration: Ensure that your Kafka broker is correctly configured and running
kafka-topics --list --bootstrap-server localhost:9092

b. Change of the retention time of the topic 
kafka-configs --alter --bootstrap-server localhost:9092 --entity-type topics --entity-name schema-changes-oracle --add-config retention.ms=157680000000

c. display of the topic 
kafka-topics --describe --bootstrap-server localhost:9092 --topic schema-changes-oracle

Topic: schema-changes-oracle    TopicId: LcnKvNSuSduL4hNzUgUe7w PartitionCount: 1       ReplicationFactor: 1    Configs: retention.ms=157680000000
        Topic: schema-changes-oracle    Partition: 0    Leader: 1       Replicas: 1     Isr: 1  Elr: N/A        LastKnownElr: N/A

d. delete topics in kafka if required
kafka-topics --delete --topic schema-changes-oracle --bootstrap-server localhost:9092