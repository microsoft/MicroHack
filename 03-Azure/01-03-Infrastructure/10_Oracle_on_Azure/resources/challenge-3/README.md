# challenges3 (Oracle to PostgreSQL)

## In the following challenge 3 you have to think about modernization and how to migrate your Oracle data estate to an Azure managed service - in our case Azure PostgreSQL flexible server.

For the following exercises we will use a container based environment with the following containers.

__vmware 1 with a debian 12 - bookworm__

1.  Zookeeper      (because Zookeeper is EOL, you can also be replaced by using KRAFT)
2.  Kafka          - Broker (Confluentic or Debezium version)
3.  Kafka          - Connect (Confluentic or Debezium version)
4.  Kafdrop        - A Kafka UI
5.  Control Center - Kafka UI von Confluent for Kafka Deployments
6.  Oracle         - Express Edition 11g Rel.2
7.  Oracle         - Express Edition 21c Rel.3
8.  PostgreSQL     - Version 17
9.  PGAdmin        - Administration UI for PostgreSQL
10. ORA2PG         - Migration tool for Oracle 2 PostgreSQL migrations


__vmware 2 with a window system as a jumpbox for web UI / c/s deployment__

1. Windows 11 or server
2. SQLDeveloper
3. Browser for web access
   1. Confluent Control Center
   2. KAFDROP (an alternative KAFKA UI)
   3. PGADMIN




Migration can be done in mainly 2 flavors:

    1. Offline Migrations
    2. Online Migrations

For offline migration we will use in the demo the tool 

    1. ORA2PG
    2. ORACLE_FDW
    3. Python     (depending on the available time)

For online migration we will setup a kafka cluster. To keep the demo easy we are using a JDBC source - and sink connector for the Oracle - and PostgreSQL database.

    1.  Kafka (Debezium or Confluent version)
