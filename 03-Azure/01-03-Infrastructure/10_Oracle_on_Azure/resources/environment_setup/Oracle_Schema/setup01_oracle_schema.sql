---------------------------------------------------------------------------------------------------------------------------------------------------
-- START Oracle Schema Creation Script
-- Create a new user/schema
CREATE USER demo_schema IDENTIFIED BY "password";
GRANT CONNECT, RESOURCE, DBA TO demo_schema;
ALTER USER demo_schema QUOTA UNLIMITED ON USERS;
ALTER USER demo_schema QUOTA 1000M ON USERS;

-- Switch to the new schema
ALTER SESSION SET CURRENT_SCHEMA = demo_schema;

-- Create tables
CREATE TABLE departments (
    department_id NUMBER PRIMARY KEY,
    department_name VARCHAR2(100),
    location VARCHAR2(100)
);

CREATE TABLE addresses (
    address_id NUMBER PRIMARY KEY,
    street VARCHAR2(100),
    city VARCHAR2(50),
    state VARCHAR2(50),
    zip_code VARCHAR2(10)
);

CREATE TABLE bank_accounts (
    bank_account_id NUMBER PRIMARY KEY,
    bank_name VARCHAR2(100),
    account_number VARCHAR2(20),
    iban VARCHAR2(34),
    swift_code VARCHAR2(11),
    encrypted_no RAW(2000)
);

-- ALTER TABLE bank_accounts ADD (encrypted_no RAW(2000));


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
    FOREIGN KEY (department_id) REFERENCES departments(department_id),
    FOREIGN KEY (address_id) REFERENCES addresses(address_id),
    FOREIGN KEY (bank_account_id) REFERENCES bank_accounts(bank_account_id)
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

------------------------------------------------------------------------
-- To achieve data replication with Change Data Capture (CDC) from Oracle Express Edition 21c 
--to an Azure PostgreSQL Flexible Server, you can use a combination of Oracle 
--triggers and a custom script to capture changes and replicate them to the 
--PostgreSQL server. Since Oracle XE does not support built-in CDC, we will 
--use triggers to capture changes and a script to apply these changes to the PostgreSQL server.
--Step-by-Step Guide:
--Create Audit Tables in Oracle XE: Create audit tables to capture changes 
--(INSERT, UPDATE, DELETE) in the source tables.
--
--Create Triggers in Oracle XE: Create triggers on the source tables to log 
--changes into the audit tables.
--
--Create a Script to Replicate Changes: Create a script to read changes from 
--the audit tables and apply them to the PostgreSQL server.
--
--Schedule the Script: Schedule the script to run at regular intervals to 
--ensure continuous replication.
-- Create an audit table for employees
CREATE TABLE employees_audit (
    audit_id NUMBER,
    operation VARCHAR2(10),
    employee_id NUMBER,
    first_name VARCHAR2(50),
    last_name VARCHAR2(50),
    email VARCHAR2(100),
    hire_date DATE,
    salary NUMBER(10, 2),
    change_time TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    PRIMARY KEY (audit_id)
);

CREATE SEQUENCE employees_audit_seq
START WITH 1
INCREMENT BY 1
NOCACHE
NOCYCLE;


-- Create a trigger to populate the audit_id using the sequence
CREATE OR REPLACE TRIGGER trg_employees_audit_id
BEFORE INSERT ON employees_audit
FOR EACH ROW
BEGIN
    IF :NEW.audit_id IS NULL THEN
        SELECT employees_audit_seq.NEXTVAL INTO :NEW.audit_id FROM dual;
    END IF;
END;
/


-- Create or replace the trigger for auditing changes in the employees table
CREATE OR REPLACE TRIGGER trg_employees_audit
AFTER INSERT OR UPDATE OR DELETE ON employees
FOR EACH ROW
BEGIN
    IF INSERTING THEN
        INSERT INTO employees_audit (operation, employee_id, first_name, last_name, email, hire_date, salary, change_time)
        VALUES ('INSERT', :NEW.employee_id, :NEW.first_name, :NEW.last_name, :NEW.email, :NEW.hire_date, :NEW.salary, SYSTIMESTAMP);
    ELSIF UPDATING THEN
        INSERT INTO employees_audit (operation, employee_id, first_name, last_name, email, hire_date, salary, change_time)
        VALUES ('UPDATE', :NEW.employee_id, :NEW.first_name, :NEW.last_name, :NEW.email, :NEW.hire_date, :NEW.salary, SYSTIMESTAMP);
    ELSIF DELETING THEN
        INSERT INTO employees_audit (operation, employee_id, first_name, last_name, email, hire_date, salary, change_time)
        VALUES ('DELETE', :OLD.employee_id, :OLD.first_name, :OLD.last_name, :OLD.email, :OLD.hire_date, :OLD.salary, SYSTIMESTAMP);
    END IF;
END;
/
------------------------------------------------------------------------



-- Table to store audit logs of changes to the departments and employees tables
CREATE TABLE audit_log (
    audit_id NUMBER PRIMARY KEY,
    table_name VARCHAR2(50),
    operation VARCHAR2(10),
    record_id NUMBER,
    old_values CLOB,
    new_values CLOB,
    change_date TIMESTAMP DEFAULT CURRENT_TIMESTAMP
);


-- Create sequences if not already created
CREATE SEQUENCE emp_seq START WITH 1 INCREMENT BY 1;
CREATE SEQUENCE dept_seq START WITH 1 INCREMENT BY 1;
CREATE SEQUENCE addr_seq START WITH 1 INCREMENT BY 1;
CREATE SEQUENCE bank_acc_seq START WITH 1 INCREMENT BY 1;
-- Sequence to generate unique audit IDs
CREATE SEQUENCE audit_seq START WITH 1 INCREMENT BY 1;
-- Create a Sequence for address_id
CREATE SEQUENCE address_seq START WITH 1 INCREMENT BY 1 NOCACHE;
-- Create a Sequence for bank_account_id
CREATE SEQUENCE bank_account_seq START WITH 1 INCREMENT BY 1 NOCACHE;
-- Create a Sequence for employee_id
CREATE SEQUENCE employee_seq START WITH 1 INCREMENT BY 1 NOCACHE;


-- Insert necessary department records
INSERT INTO departments (department_id, department_name, location)
VALUES (1, 'HR', 'New York');
INSERT INTO departments (department_id, department_name, location)
VALUES (2, 'Finance', 'San Francisco');
INSERT INTO departments (department_id, department_name, location)
VALUES (3, 'Engineering', 'Seattle');
INSERT INTO departments (department_id, department_name, location)
VALUES (4, 'Sales', 'Chicago');
INSERT INTO departments (department_id, department_name, location)
VALUES (5, 'Marketing', 'Boston');
INSERT INTO departments (department_id, department_name, location)
VALUES (6, 'Marketing', 'Los Angeles');
INSERT INTO departments (department_id, department_name, location)
VALUES (7, 'Marketing', 'Houston');
INSERT INTO departments (department_id, department_name, location)
VALUES (8, 'Marketing', 'Phoenix');
INSERT INTO departments (department_id, department_name, location)
VALUES (9, 'Marketing', 'Philadelphia');
INSERT INTO departments (department_id, department_name, location)
VALUES (10, 'Marketing', 'San Antonio');
INSERT INTO departments (department_id, department_name, location)
VALUES (11, 'Marketing', 'Berlin');
INSERT INTO departments (department_id, department_name, location)
VALUES (12, 'Marketing', 'Hamburg');
INSERT INTO departments (department_id, department_name, location)
VALUES (13, 'Marketing', 'Munich');
INSERT INTO departments (department_id, department_name, location)
VALUES (14, 'Sales', 'Cologne');
INSERT INTO departments (department_id, department_name, location)
VALUES (15, 'Engineering', 'Frankfurt');
INSERT INTO departments (department_id, department_name, location)
VALUES (16, 'Finance', 'Stuttgart');
INSERT INTO departments (department_id, department_name, location)
VALUES (17, 'HR', 'Duesseldorf');
INSERT INTO departments (department_id, department_name, location)
VALUES (18, 'Marketing', 'Dortmund');
INSERT INTO departments (department_id, department_name, location)
VALUES (19, 'Marketing', 'Essen');
INSERT INTO departments (department_id, department_name, location)
VALUES (20, 'Marketing', 'Leipzig');


-- Create the trigger to automatically insert into employee_departments
CREATE OR REPLACE TRIGGER trg_insert_employee_department
AFTER INSERT ON employees
FOR EACH ROW
BEGIN
    INSERT INTO employee_departments (employee_id, department_id)
    VALUES (:NEW.employee_id, :NEW.department_id);
END;
/

-- Create the trigger for addresses
CREATE OR REPLACE TRIGGER trg_addresses_id
BEFORE INSERT ON addresses
FOR EACH ROW
BEGIN
    IF :NEW.address_id IS NULL THEN
        SELECT address_seq.NEXTVAL INTO :NEW.address_id FROM dual;
    END IF;
END;
/

-- Create trigger for bank_accounts
CREATE OR REPLACE TRIGGER trg_bank_accounts_id
BEFORE INSERT ON bank_accounts
FOR EACH ROW
BEGIN
    IF :NEW.bank_account_id IS NULL THEN
        SELECT bank_account_seq.NEXTVAL INTO :NEW.bank_account_id FROM dual;
    END IF;
END;
/

-- Create a Trigger to Auto-Increment employee_id
CREATE OR REPLACE TRIGGER trg_employees_id
BEFORE INSERT ON employees
FOR EACH ROW
BEGIN
    IF :NEW.employee_id IS NULL THEN
        SELECT employee_seq.NEXTVAL INTO :NEW.employee_id FROM dual;
    END IF;
END;
/




-- Create the package specification
CREATE OR REPLACE PACKAGE data_transform_pkg IS
    PROCEDURE transform_and_insert;
    FUNCTION calculate_bonus(p_salary NUMBER) RETURN NUMBER;
END data_transform_pkg;
/

-- Create the package body
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

commit;


CREATE OR REPLACE PROCEDURE ingest_1_million_records IS
    v_employee_id NUMBER;
    v_first_name VARCHAR2(50);
    v_last_name VARCHAR2(50);
    v_email VARCHAR2(100);
    v_hire_date DATE;
    v_salary NUMBER(10, 2);
    v_manager_id NUMBER;
    v_department_id NUMBER;
    v_address_id NUMBER;
    v_bank_account_id NUMBER;
    v_manager_probability NUMBER;
    v_street VARCHAR2(100);
    v_city VARCHAR2(50);
    v_state VARCHAR2(50);
    v_zip_code VARCHAR2(10);
    v_bank_name VARCHAR2(100);
    v_account_number VARCHAR2(20);
    v_iban VARCHAR2(34);
    v_swift_code VARCHAR2(11);
    v_region VARCHAR2(10);

    TYPE name_array IS TABLE OF VARCHAR2(50);
    first_names_us name_array := name_array('John', 'Jane', 'Michael', 'Emily', 'Chris', 'Jessica', 'David', 'Sarah', 'James', 'Laura');
    last_names_us name_array := name_array('Smith', 'Johnson', 'Williams', 'Jones', 'Brown', 'Davis', 'Miller', 'Wilson', 'Moore', 'Taylor');
    email_domains_us name_array := name_array('example.com', 'mail.com', 'test.com', 'demo.com', 'sample.com');
    streets_us name_array := name_array('Main St', 'High St', 'Broadway', 'Elm St', 'Maple Ave');
    cities_us name_array := name_array('New York', 'San Francisco', 'Seattle', 'Chicago', 'Boston');
    states_us name_array := name_array('NY', 'CA', 'WA', 'IL', 'MA');
    bank_names_us name_array := name_array('Bank of America', 'Chase', 'Wells Fargo', 'Citibank', 'US Bank');
    swift_codes_us name_array := name_array('BOFAUS3N', 'CHASUS33', 'WFBIUS6S', 'CITIUS33', 'USBKUS44');

    first_names_de name_array := name_array('Hans', 'Anna', 'Peter', 'Laura', 'Thomas', 'Julia', 'Michael', 'Sophie', 'Stefan', 'Marie');
    last_names_de name_array := name_array('Müller', 'Schmidt', 'Schneider', 'Fischer', 'Weber', 'Meyer', 'Wagner', 'Becker', 'Schulz', 'Hoffmann');
    email_domains_de name_array := name_array('example.de', 'mail.de', 'test.de', 'demo.de', 'sample.de');
    streets_de name_array := name_array('Hanomagstrasse', 'Hildesheimer Strasse', 'Hermann-Bahlsen-Allee', 'Hermann-Mende-Strasse', 'Hermann-Lons-Strasse');
    cities_de name_array := name_array('Berlin', 'Hamburg', 'Munich', 'Cologne', 'Frankfurt');
    states_de name_array := name_array('BE', 'HH', 'BY', 'NW', 'HE');
    bank_names_de name_array := name_array('Deutsche Bank', 'Commerzbank', 'UniCredit', 'BNP Paribas', 'Santander');
    swift_codes_de name_array := name_array('DEUTDEFF', 'COBADEFF', 'UNCRITMM', 'BNPAFRPP', 'BSCHESMM');

    FUNCTION get_random_element(p_array name_array) RETURN VARCHAR2 IS
        v_index PLS_INTEGER;
    BEGIN
        v_index := TRUNC(DBMS_RANDOM.VALUE(1, p_array.COUNT + 1));
        RETURN p_array(v_index);
    END;

BEGIN
    FOR i IN 1..10000 LOOP
        -- Randomly assign region
        v_region := CASE WHEN DBMS_RANDOM.VALUE(0, 1) < 0.5 THEN 'US' ELSE 'DE' END;

        IF v_region = 'US' THEN
            v_first_name := get_random_element(first_names_us);
            v_last_name := get_random_element(last_names_us);
            v_email := v_first_name || '.' || v_last_name || '@' || get_random_element(email_domains_us);
            v_street := get_random_element(streets_us);
            v_city := get_random_element(cities_us);
            v_state := get_random_element(states_us);
            v_bank_name := get_random_element(bank_names_us);
            v_swift_code := get_random_element(swift_codes_us);
        ELSE
            v_first_name := get_random_element(first_names_de);
            v_last_name := get_random_element(last_names_de);
            v_email := v_first_name || '.' || v_last_name || '@' || get_random_element(email_domains_de);
            v_street := get_random_element(streets_de);
            v_city := get_random_element(cities_de);
            v_state := get_random_element(states_de);
            v_bank_name := get_random_element(bank_names_de);
            v_swift_code := get_random_element(swift_codes_de);
        END IF;

        v_hire_date := CURRENT_DATE - TRUNC(DBMS_RANDOM.VALUE(0, 3650));
        v_salary := TRUNC(DBMS_RANDOM.VALUE(30000, 150000), 2);
        v_department_id := TRUNC(DBMS_RANDOM.VALUE(1, 6));

        -- Insert address
        INSERT INTO addresses (street, city, state, zip_code)
        VALUES (v_street, v_city, v_state, '12345')
        RETURNING address_id INTO v_address_id;

        -- Insert bank account
        v_account_number := DBMS_RANDOM.STRING('X', 20);
        v_iban := DBMS_RANDOM.STRING('X', 34);
        INSERT INTO bank_accounts (bank_name, account_number, iban, swift_code, encrypted_no)
        VALUES (v_bank_name, v_account_number, v_iban, v_swift_code, UTL_RAW.CAST_TO_RAW(DBMS_RANDOM.STRING('X', 20)))
        RETURNING bank_account_id INTO v_bank_account_id;

        -- Insert employee
        INSERT INTO employees (first_name, last_name, email, hire_date, salary, department_id, address_id, bank_account_id)
        VALUES (v_first_name, v_last_name, v_email, v_hire_date, v_salary, v_department_id, v_address_id, v_bank_account_id)
        RETURNING employee_id INTO v_employee_id;

        -- Randomly assign manager
        v_manager_probability := DBMS_RANDOM.VALUE(0, 1);
        IF v_manager_probability < 0.1 THEN
            v_manager_id := NULL;
        ELSE
            v_manager_id := TRUNC(DBMS_RANDOM.VALUE(1, v_employee_id));
        END IF;

        UPDATE employees SET manager_id = v_manager_id WHERE employee_id = v_employee_id;
    END LOOP;
END;
/

-- Define a collection type
CREATE OR REPLACE TYPE name_array AS TABLE OF VARCHAR2(50);
/

-- Create a procedure to randomly insert, update, and delete data records
CREATE OR REPLACE PROCEDURE data_generator IS
    v_employee_id NUMBER;
    v_first_name VARCHAR2(50);
    v_last_name VARCHAR2(50);
    v_email VARCHAR2(100);
    v_hire_date DATE;
    v_salary NUMBER(10, 2);
    v_manager_id NUMBER;
    v_department_id NUMBER;
    v_address_id NUMBER;
    v_bank_account_id NUMBER;
    v_manager_probability NUMBER;
    v_street VARCHAR2(100);
    v_city VARCHAR2(50);
    v_state VARCHAR2(50);
    v_zip_code VARCHAR2(10);
    v_bank_name VARCHAR2(100);
    v_account_number VARCHAR2(20);
    v_iban VARCHAR2(34);
    v_swift_code VARCHAR2(11);

    --TYPE name_array IS TABLE OF VARCHAR2(50);
   
    first_names name_array := name_array('John', 'Jane', 'Michael', 'Emily', 'Chris', 'Jessica', 'David', 'Sarah', 'James', 'Laura', 'Robert', 'Mary', 'William', 'Patricia', 'Linda', 'Barbara', 'Elizabeth', 'Jennifer', 'Maria', 'Susan');
    last_names name_array := name_array('Smith', 'Johnson', 'Williams', 'Jones', 'Brown', 'Davis', 'Miller', 'Wilson', 'Moore', 'Taylor', 'Anderson', 'Thomas', 'Jackson', 'White', 'Harris', 'Martin', 'Thompson', 'Garcia', 'Martinez', 'Robinson');
    email_domains name_array := name_array('example.com', 'mail.com', 'test.com', 'demo.com', 'sample.com', 'company.com', 'corp.com', 'org.com', 'net.com', 'edu.com', 'gov.com', 'us.com', 'uk.com', 'de.com', 'fr.com', 'it.com', 'es.com', 'ca.com', 'au.com', 'jp.com');
    streets name_array := name_array('Main St', 'High St', 'Broadway', 'Elm St', 'Maple Ave', 'Oak St', 'Pine St', 'Cedar St', 'Birch St', 'Walnut St', 'Hanomagstrasse', 'Hildesheimer Strasse', 'Hermann-Bahlsen-Allee', 'Hermann-Mende-Strasse', 'Hermann-Lons-Strasse', 'Hermann-Kohl-Strasse', 'Hermann-Billung-Strasse', 'Hermann-Bote-Strasse', 'Hermann-Boye-Strasse', 'Hermann-Blumenau-Strasse');
    cities name_array := name_array('New York', 'San Francisco', 'Seattle', 'Chicago', 'Boston', 'Los Angeles', 'Houston', 'Phoenix', 'Philadelphia', 'San Antonio', 'Berlin', 'Hamburg', 'Munich', 'Cologne', 'Frankfurt', 'Stuttgart', 'Dusseldorf', 'Dortmund', 'Essen', 'Leipzig');
    states name_array := name_array('NY', 'CA', 'WA', 'IL', 'MA', 'TX', 'AZ', 'PA', 'TX', 'TX', 'BE', 'HH', 'BY', 'NW', 'HE', 'BW', 'RP', 'SL', 'TH', 'BB');
    bank_names name_array := name_array('Bank of America', 'Chase', 'Wells Fargo', 'Citibank', 'US Bank', 'PNC Bank', 'Capital One', 'TD Bank', 'BB&T', 'SunTrust', 'Deutsche Bank', 'Commerzbank', 'UniCredit', 'BNP Paribas', 'Santander', 'Barclays', 'HSBC', 'Lloyds Bank', 'NatWest');
    swift_codes name_array := name_array('BOFAUS3N', 'CHASUS33', 'WFBIUS6S', 'CITIUS33', 'USBKUS44', 'PNCCUS33', 'NFBKUS33', 'TDBKUS33', 'BRBTUS33', 'SNTRUS3A', 'DEUTDEFF', 'COBADEFF', 'UNCRITMM', 'BNPAFRPP', 'BSCHESMM', 'LOYDGB2L', 'NWBKGB2L', 'BARCGB22', 'HSBCGB2L', 'SANTGB2L');

    first_names_de name_array := name_array('Hans', 'Anna', 'Peter', 'Laura', 'Thomas', 'Julia', 'Michael', 'Sophie', 'Stefan', 'Marie');
    last_names_de name_array := name_array('Müller', 'Schmidt', 'Schneider', 'Fischer', 'Weber', 'Meyer', 'Wagner', 'Becker', 'Schulz', 'Hoffmann');
    email_domains_de name_array := name_array('example.de', 'mail.de', 'test.de', 'demo.de', 'sample.de');
    streets_de name_array := name_array('Hanomagstrasse', 'Hildesheimer Strasse', 'Hermann-Bahlsen-Allee', 'Hermann-Mende-Strasse', 'Hermann-Lons-Strasse');
    cities_de name_array := name_array('Berlin', 'Hamburg', 'Munich', 'Cologne', 'Frankfurt');
    states_de name_array := name_array('BE', 'HH', 'BY', 'NW', 'HE');
    bank_names_de name_array := name_array('Deutsche Bank', 'Commerzbank', 'UniCredit', 'BNP Paribas', 'Santander');
    swift_codes_de name_array := name_array('DEUTDEFF', 'COBADEFF', 'UNCRITMM', 'BNPAFRPP', 'BSCHESMM');

    FUNCTION get_random_element(p_array name_array) RETURN VARCHAR2 IS
        v_index PLS_INTEGER;
    BEGIN
        v_index := TRUNC(DBMS_RANDOM.VALUE(1, p_array.COUNT + 1));
        RETURN p_array(v_index);
    END get_random_element;

    FUNCTION get_random_date RETURN DATE IS
        v_start_date DATE := TO_DATE('2000-01-01', 'YYYY-MM-DD');
        v_end_date DATE := TO_DATE('2023-12-31', 'YYYY-MM-DD');
        v_diff NUMBER := v_end_date - v_start_date;
    BEGIN
        RETURN v_start_date + TRUNC(DBMS_RANDOM.VALUE(0, v_diff));
    END get_random_date;

    FUNCTION get_random_salary RETURN NUMBER IS
    BEGIN
        RETURN ROUND(DBMS_RANDOM.VALUE(30000, 200000), 2);
    END get_random_salary;

    FUNCTION get_random_department_id RETURN NUMBER IS
    BEGIN
        RETURN TRUNC(DBMS_RANDOM.VALUE(1, 6));
    END get_random_department_id;

    FUNCTION get_random_zip_code RETURN VARCHAR2 IS
    BEGIN
        RETURN LPAD(TRUNC(DBMS_RANDOM.VALUE(10000, 99999)), 5, '0');
    END get_random_zip_code;

    FUNCTION get_random_account_number RETURN VARCHAR2 IS
    BEGIN
        RETURN LPAD(TRUNC(DBMS_RANDOM.VALUE(1000000000, 9999999999)), 10, '0');
    END get_random_account_number;

    FUNCTION get_random_iban RETURN VARCHAR2 IS
    BEGIN
        RETURN 'US' || LPAD(TRUNC(DBMS_RANDOM.VALUE(1000000000000000000000000000, 9999999999999999999999999999)), 30, '0');
    END get_random_iban;

BEGIN
    -- Randomly decide the number of operations to perform
    FOR i IN 1..TRUNC(DBMS_RANDOM.VALUE(1, 11)) LOOP
        -- Randomly decide the type of operation: insert, update, or delete
        CASE TRUNC(DBMS_RANDOM.VALUE(1, 4))
            WHEN 1 THEN
                -- Insert operation
                v_employee_id := emp_seq.NEXTVAL;
                v_first_name := get_random_element(first_names);
                v_last_name := get_random_element(last_names);
                v_email := v_first_name || '.' || v_last_name || '@' || get_random_element(email_domains);
                v_hire_date := get_random_date;
                v_salary := get_random_salary;
                v_department_id := get_random_department_id; -- Ensure this department_id exists

                -- Insert address
                v_address_id := addr_seq.NEXTVAL;
                v_street := get_random_element(streets);
                v_city := get_random_element(cities);
                v_state := get_random_element(states);
                v_zip_code := get_random_zip_code;
                INSERT INTO addresses (address_id, street, city, state, zip_code)
                VALUES (v_address_id, v_street, v_city, v_state, v_zip_code);

                -- Insert bank account
                v_bank_account_id := bank_acc_seq.NEXTVAL;
                v_bank_name := get_random_element(bank_names);
                v_account_number := get_random_account_number;
                v_iban := get_random_iban;
                v_swift_code := get_random_element(swift_codes);
                INSERT INTO bank_accounts (bank_account_id, bank_name, account_number, iban, swift_code)
                VALUES (v_bank_account_id, v_bank_name, v_account_number, v_iban, v_swift_code);

                -- Assign a manager with a certain probability
                v_manager_probability := DBMS_RANDOM.VALUE(0, 1);
                IF v_manager_probability < 0.1 THEN
                    v_manager_id := TRUNC(DBMS_RANDOM.VALUE(1, 1000)); -- Assuming there are 1000 employees
                ELSE
                    v_manager_id := NULL;
                END IF;

                INSERT INTO employees (employee_id, first_name, last_name, email, hire_date, salary, manager_id, department_id, address_id, bank_account_id)
                VALUES (v_employee_id, v_first_name, v_last_name, v_email, v_hire_date, v_salary, v_manager_id, v_department_id, v_address_id, v_bank_account_id);

            WHEN 2 THEN
                -- Update operation
                SELECT employee_id INTO v_employee_id FROM (SELECT employee_id FROM employees ORDER BY DBMS_RANDOM.VALUE) WHERE ROWNUM = 1;
                v_salary := get_random_salary;
                UPDATE employees SET salary = v_salary WHERE employee_id = v_employee_id;

            WHEN 3 THEN
                -- Delete operation
                SELECT employee_id INTO v_employee_id FROM (SELECT employee_id FROM employees ORDER BY DBMS_RANDOM.VALUE) WHERE ROWNUM = 1;
                -- Delete related records in employee_departments first
                DELETE FROM employee_departments WHERE employee_id = v_employee_id;
                DELETE FROM employees WHERE employee_id = v_employee_id;
        END CASE;
    END LOOP;

    COMMIT;
END data_generator;
/


-- Trigger to log changes to the departments table
CREATE OR REPLACE TRIGGER trg_departments_audit
AFTER INSERT OR UPDATE OR DELETE ON departments
FOR EACH ROW
DECLARE
    v_old_values CLOB;
    v_new_values CLOB;
BEGIN
    IF INSERTING THEN
        v_new_values := 'department_id=' || :NEW.department_id || ', department_name=' || :NEW.department_name || ', location=' || :NEW.location;
        INSERT INTO audit_log (audit_id, table_name, operation, record_id, new_values)
        VALUES (audit_seq.NEXTVAL, 'departments', 'INSERT', :NEW.department_id, v_new_values);
    ELSIF UPDATING THEN
        v_old_values := 'department_id=' || :OLD.department_id || ', department_name=' || :OLD.department_name || ', location=' || :OLD.location;
        v_new_values := 'department_id=' || :NEW.department_id || ', department_name=' || :NEW.department_name || ', location=' || :NEW.location;
        INSERT INTO audit_log (audit_id, table_name, operation, record_id, old_values, new_values)
        VALUES (audit_seq.NEXTVAL, 'departments', 'UPDATE', :NEW.department_id, v_old_values, v_new_values);
    ELSIF DELETING THEN
        v_old_values := 'department_id=' || :OLD.department_id || ', department_name=' || :OLD.department_name || ', location=' || :OLD.location;
        INSERT INTO audit_log (audit_id, table_name, operation, record_id, old_values)
        VALUES (audit_seq.NEXTVAL, 'departments', 'DELETE', :OLD.department_id, v_old_values);
    END IF;
END;
/


-- Trigger to log changes to the employees table
CREATE OR REPLACE TRIGGER trg_employees_audit
AFTER INSERT OR UPDATE OR DELETE ON employees
FOR EACH ROW
DECLARE
    v_old_values CLOB;
    v_new_values CLOB;
BEGIN
    IF INSERTING THEN
        v_new_values := 'employee_id=' || :NEW.employee_id || ', first_name=' || :NEW.first_name || ', last_name=' || :NEW.last_name || ', email=' || :NEW.email || ', hire_date=' || :NEW.hire_date || ', salary=' || :NEW.salary;
        INSERT INTO audit_log (audit_id, table_name, operation, record_id, new_values)
        VALUES (audit_seq.NEXTVAL, 'employees', 'INSERT', :NEW.employee_id, v_new_values);
    ELSIF UPDATING THEN
        v_old_values := 'employee_id=' || :OLD.employee_id || ', first_name=' || :OLD.first_name || ', last_name=' || :OLD.last_name || ', email=' || :OLD.email || ', hire_date=' || :OLD.hire_date || ', salary=' || :OLD.salary;
        v_new_values := 'employee_id=' || :NEW.employee_id || ', first_name=' || :NEW.first_name || ', last_name=' || :NEW.last_name || ', email=' || :NEW.email || ', hire_date=' || :NEW.hire_date || ', salary=' || :NEW.salary;
        INSERT INTO audit_log (audit_id, table_name, operation, record_id, old_values, new_values)
        VALUES (audit_seq.NEXTVAL, 'employees', 'UPDATE', :NEW.employee_id, v_old_values, v_new_values);
    ELSIF DELETING THEN
        v_old_values := 'employee_id=' || :OLD.employee_id || ', first_name=' || :OLD.first_name || ', last_name=' || :OLD.last_name || ', email=' || :OLD.email || ', hire_date=' || :OLD.hire_date || ', salary=' || :OLD.salary;
        INSERT INTO audit_log (audit_id, table_name, operation, record_id, old_values)
        VALUES (audit_seq.NEXTVAL, 'employees', 'DELETE', :OLD.employee_id, v_old_values);
    END IF;
END;
/