-- Delete all objects in User schema demo_schema under user system / sys
-- enter 2 time the schema name to confirm the deletion 
SET SERVEROUTPUT ON SIZE 1000000
set verify off
BEGIN
FOR c1 IN (SELECT OWNER,table_name, constraint_name FROM dba_constraints 
WHERE constraint_type = 'R' and owner=upper('&shema_name')) LOOP
EXECUTE IMMEDIATE 'ALTER TABLE '||' "'||c1.owner||'"."'||c1.table_name||'" DROP CONSTRAINT ' || c1.constraint_name;
END LOOP;
FOR c1 IN (SELECT owner,object_name,object_type FROM dba_objects where owner=upper('&shema_name')) LOOP
BEGIN
IF c1.object_type = 'TYPE' THEN
EXECUTE IMMEDIATE 'DROP '||c1.object_type||' "'||c1.owner||'"."'||c1.object_name||'" FORCE';
END IF;
IF c1.object_type != 'DATABASE LINK' THEN
EXECUTE IMMEDIATE 'DROP '||c1.object_type||' "'||c1.owner||'"."'||c1.object_name||'"';
END IF;
EXCEPTION
WHEN OTHERS THEN
NULL;
END;
END LOOP;
EXECUTE IMMEDIATE('purge dba_recyclebin');
END;
/


-- In a second step delete existing job in user schema demo_schema
begin dbms_scheduler.drop_job(job_name => 'TRANSFORM_JOB');
end;
/







-- Create a new user/schema
CREATE USER demo_schema IDENTIFIED BY "password";
GRANT CONNECT, RESOURCE TO demo_schema;
ALTER USER demo_schema QUOTA UNLIMITED ON USERS;
ALTER USER demo_schema QUOTA 500M ON USERS;

-- Switch to the new schema
ALTER SESSION SET CURRENT_SCHEMA = demo_schema;

-- Create tables
CREATE TABLE employees (
    employee_id NUMBER PRIMARY KEY,
    first_name VARCHAR2(50),
    last_name VARCHAR2(50),
    email VARCHAR2(100),
    hire_date DATE,
    salary NUMBER(10, 2),
    manager_id NUMBER,
    department_id NUMBER
);

CREATE TABLE departments (
    department_id NUMBER PRIMARY KEY,
    department_name VARCHAR2(100),
    location VARCHAR2(100)
);

CREATE TABLE employee_departments (
    employee_id NUMBER,
    department_id NUMBER,
    PRIMARY KEY (employee_id, department_id),
    FOREIGN KEY (employee_id) REFERENCES employees(employee_id),
    FOREIGN KEY (department_id) REFERENCES departments(department_id)
);

-- Create a table to store transformed data
CREATE TABLE transformed_employees (
    employee_id NUMBER PRIMARY KEY,
    first_name VARCHAR2(50),
    last_name VARCHAR2(50),
    email VARCHAR2(100),
    hire_date DATE,
    new_salary NUMBER(10, 2),
    bonus NUMBER(10, 2)
);

-- Create sequences
CREATE SEQUENCE emp_seq START WITH 1 INCREMENT BY 1;
CREATE SEQUENCE dept_seq START WITH 1 INCREMENT BY 1;

-- Create indexes
CREATE INDEX idx_employee_last_name ON employees(last_name);
CREATE INDEX idx_department_name ON departments(department_name);

-- Create a view
CREATE VIEW employee_details AS
SELECT e.employee_id, e.first_name, e.last_name, e.email, e.hire_date, e.salary, d.department_name, d.location
FROM employees e
JOIN employee_departments ed ON e.employee_id = ed.employee_id
JOIN departments d ON ed.department_id = d.department_id;

-- Create a synonym
CREATE SYNONYM emp_details FOR employee_details;

-- Create a PL/SQL package for data transformation
CREATE OR REPLACE PACKAGE data_transform_pkg IS
    PROCEDURE transform_and_insert;
    FUNCTION calculate_bonus(p_salary NUMBER) RETURN NUMBER;
END data_transform_pkg;
/

CREATE OR REPLACE PACKAGE BODY data_transform_pkg IS
    PROCEDURE transform_and_insert IS
        CURSOR emp_cursor IS
            SELECT employee_id, first_name, last_name, email, hire_date, salary
            FROM employees;
        v_employee_id employees.employee_id%TYPE;
        v_first_name employees.first_name%TYPE;
        v_last_name employees.last_name%TYPE;
        v_email employees.email%TYPE;
        v_hire_date employees.hire_date%TYPE;
        v_salary employees.salary%TYPE;
        v_new_salary employees.salary%TYPE;
        v_bonus employees.salary%TYPE;
    BEGIN
        OPEN emp_cursor;
        LOOP
            FETCH emp_cursor INTO v_employee_id, v_first_name, v_last_name, v_email, v_hire_date, v_salary;
            EXIT WHEN emp_cursor%NOTFOUND;
            
            -- Example transformation: Increase salary by 10%
            v_new_salary := v_salary * 1.10;
            
            -- Calculate bonus using the function
            v_bonus := calculate_bonus(v_salary);
            
            -- Insert transformed data into a new table
            INSERT INTO transformed_employees (employee_id, first_name, last_name, email, hire_date, new_salary, bonus)
            VALUES (v_employee_id, v_first_name, v_last_name, v_email, v_hire_date, v_new_salary, v_bonus);
        END LOOP;
        CLOSE emp_cursor;
    END transform_and_insert;

    FUNCTION calculate_bonus(p_salary NUMBER) RETURN NUMBER IS
    BEGIN
        RETURN p_salary * 0.05; -- 5% bonus
    END calculate_bonus;
END data_transform_pkg;
/

-- Create a trigger to automatically insert into employee_departments
CREATE OR REPLACE TRIGGER trg_insert_employee_department
AFTER INSERT ON employees
FOR EACH ROW
BEGIN
    INSERT INTO employee_departments (employee_id, department_id)
    VALUES (:NEW.employee_id, :NEW.department_id);
END;
/

-- Example data insertion
-- INSERT INTO departments (department_id, department_name, location)
-- VALUES (dept_seq.NEXTVAL, 'HR', 'New York');

INSERT INTO employees (employee_id, first_name, last_name, email, hire_date, salary, manager_id, department_id)
VALUES (emp_seq.NEXTVAL, 'John', 'Doe', 'john.doe@example.com', TO_DATE('2020-01-01', 'YYYY-MM-DD'), 50000, NULL, 1);


-- Execute the transformation procedure
BEGIN
    data_transform_pkg.transform_and_insert;
END;
/




BEGIN
    -- Drop the job if it already exists
    BEGIN
        DBMS_SCHEDULER.drop_job('demo_schema.transform_job');
    EXCEPTION
        WHEN OTHERS THEN
            IF SQLCODE != -27475 THEN
                RAISE;
            END IF;
    END;

    -- Create the job
    DBMS_SCHEDULER.create_job (
        job_name        => 'demo_schema.transform_job',
        job_type        => 'PLSQL_BLOCK',
        job_action      => 'BEGIN data_transform_pkg.transform_and_insert; END;',
        start_date      => SYSTIMESTAMP,
        repeat_interval => 'FREQ=SECONDLY; INTERVAL=5',
        enabled         => TRUE
    );
END;
/



-- Create a procedure to ingest 1 million records
CREATE OR REPLACE PROCEDURE ingest_1_million_records IS
    v_employee_id NUMBER;
    v_first_name VARCHAR2(50);
    v_last_name VARCHAR2(50);
    v_email VARCHAR2(100);
    v_hire_date DATE;
    v_salary NUMBER(10, 2);
    v_manager_id NUMBER;
    v_department_id NUMBER;
BEGIN
    FOR i IN 1..1000000 LOOP
        v_employee_id := emp_seq.NEXTVAL;
        v_first_name := 'First_' || TO_CHAR(i);
        v_last_name := 'Last_' || TO_CHAR(i);
        v_email := 'email_' || TO_CHAR(i) || '@example.com';
        v_hire_date := TO_DATE('2020-01-01', 'YYYY-MM-DD') + MOD(i, 365);
        v_salary := 30000 + MOD(i, 20000);
        v_manager_id := NULL;
        v_department_id := 1; -- Ensure this department_id exists

        INSERT INTO employees (employee_id, first_name, last_name, email, hire_date, salary, manager_id, department_id)
        VALUES (v_employee_id, v_first_name, v_last_name, v_email, v_hire_date, v_salary, v_manager_id, v_department_id);

        -- Commit every 1000 records to avoid excessive memory usage
        IF MOD(i, 1000) = 0 THEN
            COMMIT;
        END IF;
    END LOOP;
    COMMIT;
END ingest_1_million_records;
/

-- Execute the procedure to ingest 1 million records
BEGIN
    ingest_1_million_records;
END;
/