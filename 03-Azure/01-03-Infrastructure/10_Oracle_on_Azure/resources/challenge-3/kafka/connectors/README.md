# Following the description of the connector variables. Some are mandatory, others have default values if they are not set.


__1. Confluent JDBC Connector__

This configuration file sets up an Oracle JDBC source connector that connects to an Oracle database, captures changes using both timestamp and incrementing columns, and writes the changes to Kafka topics with a specified prefix. The configuration includes error logging, schema history management, and specific settings for handling database history and DDL changes.


1. name: The name of the connector instance.
2. connector.class: The class implementing the connector logic.
3. tasks.max: The maximum number of tasks that should be created for this connector.
4. connection.url: The JDBC URL to connect to the Oracle database.
5. connection.user: The username to connect to the Oracle database.
6. connection.password: The password to connect to the Oracle database.
7. mode: The mode of operation for the connector. In this case, it uses both timestamp and incrementing columns to detect changes.
8. incrementing.column.name: The name of the column that contains incrementing values (e.g., an auto-incrementing primary key).
9. timestamp.column.name: The name of the column that contains timestamp values.
10. validate.non.null: Ensures that the specified columns are not null.
11. timestamp.initial: The initial timestamp value to use when no offsets are available.
12. topic.prefix: The prefix to prepend to the Kafka topic names for the data.
13. poll.interval.ms: The frequency in milliseconds to poll for new data.
14. errors.log.enable: Enables logging of errors.
15. errors.log.include.messages: Includes error messages in the logs.
16. schema.history.internal.kafka.bootstrap.servers: The Kafka bootstrap servers for the internal schema history topic.
17. schema.history.internal.kafka.topic: The Kafka topic to store internal schema history.
18. database.history.recovery.mode: The mode for recovering database history. SCHEMA_ONLY_RECOVERY means only schema changes are recovered.
19. database.schema: The schema name in the Oracle database.
20. database.out.server.name: The name of the database out server.
21. database.history.kafka.bootstrap.servers: The Kafka bootstrap servers for the database history topic.
22. database.history.kafka.topic: The Kafka topic to store database history.
23. database.connection.adapter: The adapter used for database connection. logminer is used for Oracle.
24. database.history.store.only.captured.tables.ddl: Stores only the DDL changes for captured tables.
25. database.history.skip.unparseable.ddl: Skips unparseable DDL statements.

<br>
<br>

__2. Debezium connector__

See the online documentation of Debezium [here](https://debezium.io/documentation/reference/stable/connectors/postgresql.html).

The first time it connects to a PostgreSQL server or cluster, the connector takes a consistent snapshot of all schemas. After that snapshot is complete, the connector continuously captures row-level changes that insert, update, and delete database content and that were committed to a PostgreSQL database. The connector generates data change event records and streams them to Kafka topics. For each table, the default behavior is that the connector streams all generated events to a separate Kafka topic for that table. Applications and services consume data change event records from that topic.

