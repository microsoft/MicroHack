# The following table is used for a check for Kafka.

~~~bash
-- Create a test table
CREATE TABLE test_table (
    id NUMBER PRIMARY KEY,
    name VARCHAR2(50),
    created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP
);

-- Create a sequence for the test table
CREATE SEQUENCE test_table_seq
START WITH 1
INCREMENT BY 1
NOCACHE
NOCYCLE;


-- Insert 10 records into the test table
BEGIN
    FOR i IN 1..10 LOOP
        INSERT INTO test_table (id, name)
        VALUES (test_table_seq.NEXTVAL, 'Name ' || i);
    END LOOP;
    COMMIT;
END;
/


-- Verify the records
SELECT * FROM test_table;
~~~


# For the update later after the kafka cluster is deployed and configured


~~~bash
-- Update the name of the record with id 1

UPDATE test_table
SET name = 'Updated Name'
WHERE id = 1;

-- Commit the changes
COMMIT;

-- Verify the update
SELECT * FROM test_table WHERE id = 1;

~~~