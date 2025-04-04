---------------------------------------------------------------------------------------------------------------------------------------------------
-- START PostgreSQL Schema Creation Script

-- Create a new user/schema
--CREATE USER demo_schema WITH PASSWORD 'password';
--CREATE DATABASE demo_schema;
--GRANT ALL ON DATABASE demo_schema TO demo_schema WITH GRANT OPTION;

-- Revoke the role from all users
-- REVOKE demo_schema1 FROM ALL;

-- Create a new role with specific attributes
CREATE ROLE demo_schema WITH
	LOGIN
	NOSUPERUSER
	CREATEDB
	CREATEROLE
	CONNECTION LIMIT -1
	PASSWORD 'password';

-- Create a new schema and assign ownership to a user
CREATE SCHEMA demo_schema AUTHORIZATION masandma;

-- Grant all privileges on the schema to the role
GRANT ALL ON SCHEMA demo_schema TO demo_schema;

-- Switch to the new schema
SET search_path TO demo_schema;


-- Enable the pgcrypto extension
CREATE EXTENSION IF NOT EXISTS pgcrypto;
-- Enable the pg_cron extension
CREATE EXTENSION IF NOT EXISTS pg_cron;


-- Create a table for departments
CREATE TABLE departments (
    department_id SERIAL PRIMARY KEY,
    department_name VARCHAR(100),
    location VARCHAR(100)
);

CREATE TABLE addresses (
    address_id SERIAL PRIMARY KEY,
    street VARCHAR(100),
    city VARCHAR(50),
    state VARCHAR(50),
    zip_code VARCHAR(10)
);

CREATE TABLE bank_accounts (
    bank_account_id SERIAL PRIMARY KEY,
    bank_name VARCHAR(100),
    account_number VARCHAR(20),
    iban VARCHAR(34),
    swift_code VARCHAR(11),
    encrypted_no BYTEA
);

CREATE TABLE employees (
    employee_id SERIAL PRIMARY KEY,
    first_name VARCHAR(50),
    last_name VARCHAR(50),
    email VARCHAR(100),
    hire_date DATE,
    salary NUMERIC(10, 2),
    manager_id INTEGER,
    department_id INTEGER,
    address_id INTEGER,
    bank_account_id INTEGER,
    FOREIGN KEY (department_id) REFERENCES departments(department_id),
    FOREIGN KEY (address_id) REFERENCES addresses(address_id),
    FOREIGN KEY (bank_account_id) REFERENCES bank_accounts(bank_account_id)
);

CREATE TABLE employee_departments (
    employee_id INTEGER,
    department_id INTEGER,
    PRIMARY KEY (employee_id, department_id),
    FOREIGN KEY (employee_id) REFERENCES employees(employee_id),
    FOREIGN KEY (department_id) REFERENCES departments(department_id)
);

CREATE TABLE transformed_employees (
    employee_id INTEGER PRIMARY KEY,
    first_name VARCHAR(50),
    last_name VARCHAR(50),
    email VARCHAR(100),
    hire_date DATE,
    new_salary NUMERIC(10, 2),
    bonus NUMERIC(10, 2)
);

CREATE TABLE audit_log (
    audit_id SERIAL PRIMARY KEY,
    table_name VARCHAR(50),
    operation VARCHAR(10),
    record_id INTEGER,
    old_values TEXT,
    new_values TEXT,
    change_date TIMESTAMP DEFAULT CURRENT_TIMESTAMP
);

----------------------------------------------------------------
-- Create an audit table for employees
CREATE TABLE employees_audit (
    audit_id_emp SERIAL PRIMARY KEY,
    operation VARCHAR(10),
    employee_id INTEGER,
    first_name VARCHAR(50),
    last_name VARCHAR(50),
    email VARCHAR(100),
    hire_date DATE,
    salary NUMERIC(10, 2),
    change_time TIMESTAMP DEFAULT CURRENT_TIMESTAMP
);
-- Sequence to generate unique audit IDs
CREATE SEQUENCE IF NOT EXISTS audit_seq_emp START WITH 1 INCREMENT BY 1;
----------------------------------------------------------------


-- Create sequences if not already created
CREATE SEQUENCE IF NOT EXISTS emp_seq START WITH 1 INCREMENT BY 1;
CREATE SEQUENCE IF NOT EXISTS dept_seq START WITH 1 INCREMENT BY 1;
CREATE SEQUENCE IF NOT EXISTS addr_seq START WITH 1 INCREMENT BY 1;
CREATE SEQUENCE IF NOT EXISTS bank_acc_seq START WITH 1 INCREMENT BY 1;
-- Sequence to generate unique audit IDs
CREATE SEQUENCE IF NOT EXISTS audit_seq START WITH 1 INCREMENT BY 1;
-- Create a Sequence for address_id
CREATE SEQUENCE IF NOT EXISTS address_seq START WITH 1 INCREMENT BY 1;
-- Create a Sequence for bank_account_id
CREATE SEQUENCE IF NOT EXISTS bank_account_seq START WITH 1 INCREMENT BY 1;
-- Create a Sequence for employee_id
CREATE SEQUENCE IF NOT EXISTS employee_seq START WITH 1 INCREMENT BY 1;


-- Insert necessary department records
INSERT INTO departments (department_name, location) VALUES
('HR', 'New York'),
('Finance', 'San Francisco'),
('Engineering', 'Seattle'),
('Sales', 'Chicago'),
('Marketing', 'Boston'),
('Marketing', 'Los Angeles'),
('Marketing', 'Houston'),
('Marketing', 'Phoenix'),
('Marketing', 'Philadelphia'),
('Marketing', 'San Antonio'),
('Marketing', 'Berlin'),
('Marketing', 'Hamburg'),
('Marketing', 'Munich'),
('Sales', 'Cologne'),
('Engineering', 'Frankfurt'),
('Finance', 'Stuttgart'),
('HR', 'Duesseldorf'),
('Marketing', 'Dortmund'),
('Marketing', 'Essen'),
('Marketing', 'Leipzig');


-- Create the trigger function to automatically insert into employee_departments
CREATE OR REPLACE FUNCTION trg_insert_employee_department() RETURNS TRIGGER AS $$
BEGIN
    INSERT INTO employee_departments (employee_id, department_id)
    VALUES (NEW.employee_id, NEW.department_id);
    RETURN NEW;
END;
$$ LANGUAGE plpgsql;

-- Create the trigger to call the trigger function after insert on employees
CREATE TRIGGER trg_insert_employee_department
AFTER INSERT ON employees
FOR EACH ROW
EXECUTE FUNCTION trg_insert_employee_department();


-- Create the trigger function for addresses
CREATE OR REPLACE FUNCTION trg_addresses_id() RETURNS TRIGGER AS $$
BEGIN
    IF NEW.address_id IS NULL THEN
        NEW.address_id := nextval('address_seq');
    END IF;
    RETURN NEW;
END;
$$ LANGUAGE plpgsql;

-- Create the trigger for addresses
CREATE TRIGGER trg_addresses_id
BEFORE INSERT ON addresses
FOR EACH ROW
EXECUTE FUNCTION trg_addresses_id();

-- Create the trigger function for bank_accounts
CREATE OR REPLACE FUNCTION trg_bank_accounts_id() RETURNS TRIGGER AS $$
BEGIN
    IF NEW.bank_account_id IS NULL THEN
        NEW.bank_account_id := nextval('bank_account_seq');
    END IF;
    RETURN NEW;
END;
$$ LANGUAGE plpgsql;

-- Create the trigger for bank_accounts
CREATE TRIGGER trg_bank_accounts_id
BEFORE INSERT ON bank_accounts
FOR EACH ROW
EXECUTE FUNCTION trg_bank_accounts_id();


-- Create the trigger function to auto-increment employee_id
CREATE OR REPLACE FUNCTION trg_employees_id() RETURNS TRIGGER AS $$
BEGIN
    IF NEW.employee_id IS NULL THEN
        NEW.employee_id := nextval('employee_seq');
    END IF;
    RETURN NEW;
END;
$$ LANGUAGE plpgsql;

-- Create the trigger to call the trigger function before insert on employees
CREATE TRIGGER trg_employees_id
BEFORE INSERT ON employees
FOR EACH ROW
EXECUTE FUNCTION trg_employees_id();



-- Create a function to calculate bonus
CREATE OR REPLACE FUNCTION calculate_bonus(p_salary NUMERIC) RETURNS NUMERIC AS $$
BEGIN
    RETURN p_salary * 0.05; -- 5% bonus
END;
$$ LANGUAGE plpgsql;


-- Create a procedure to transform and insert data
CREATE OR REPLACE PROCEDURE transform_and_insert() LANGUAGE plpgsql AS $$
DECLARE
    -- Declare a cursor to select employee data from the employees table
    emp_cursor CURSOR FOR SELECT employee_id, first_name, last_name, email, hire_date, salary FROM employees;
    v_employee_id employees.employee_id%TYPE;
    v_first_name employees.first_name%TYPE;
    v_last_name employees.last_name%TYPE;
    v_email employees.email%TYPE;
    v_hire_date employees.hire_date%TYPE;
    v_salary employees.salary%TYPE;
    v_new_salary employees.salary%TYPE;
    v_bonus employees.salary%TYPE;
BEGIN
    -- Open the cursor
    OPEN emp_cursor;
    -- Loop through each row fetched by the cursor
    LOOP
        -- Fetch the next row into the declared variables
        FETCH emp_cursor INTO v_employee_id, v_first_name, v_last_name, v_email, v_hire_date, v_salary;
        -- Exit the loop if no more rows are found
        EXIT WHEN NOT FOUND;
        
        -- Example transformation: Increase salary by 10%
        v_new_salary := v_salary * 1.10;
        
        -- Calculate bonus using the function
        v_bonus := calculate_bonus(v_salary);
        
        -- Insert transformed data into a new table
        INSERT INTO transformed_employees (employee_id, first_name, last_name, email, hire_date, new_salary, bonus)
        VALUES (v_employee_id, v_first_name, v_last_name, v_email, v_hire_date, v_new_salary, v_bonus);
    END LOOP;
    -- Close the cursor
    CLOSE emp_cursor;
END;
$$;



CREATE OR REPLACE PROCEDURE ingest_1_million_records() LANGUAGE plpgsql AS $$
DECLARE
    v_employee_id INTEGER;
    v_first_name VARCHAR(50);
    v_last_name VARCHAR(50);
    v_email VARCHAR(100);
    v_hire_date DATE;
    v_salary NUMERIC(10, 2);
    v_manager_id INTEGER;
    v_department_id INTEGER;
    v_address_id INTEGER;
    v_bank_account_id INTEGER;
    v_manager_probability NUMERIC;
    v_street VARCHAR(100);
    v_city VARCHAR(50);
    v_state VARCHAR(50);
    v_zip_code VARCHAR(10);
    v_bank_name VARCHAR(100);
    v_account_number VARCHAR(20);
    v_iban VARCHAR(34);
    v_swift_code VARCHAR(11);
    v_region VARCHAR(10);

    first_names_us TEXT[] := ARRAY['John', 'Jane', 'Michael', 'Emily', 'Chris', 'Jessica', 'David', 'Sarah', 'James', 'Laura'];
    last_names_us TEXT[] := ARRAY['Smith', 'Johnson', 'Williams', 'Jones', 'Brown', 'Davis', 'Miller', 'Wilson', 'Moore', 'Taylor'];
    email_domains_us TEXT[] := ARRAY['example.com', 'mail.com', 'test.com', 'demo.com', 'sample.com'];
    streets_us TEXT[] := ARRAY['Main St', 'High St', 'Broadway', 'Elm St', 'Maple Ave'];
    cities_us TEXT[] := ARRAY['New York', 'San Francisco', 'Seattle', 'Chicago', 'Boston'];
    states_us TEXT[] := ARRAY['NY', 'CA', 'WA', 'IL', 'MA'];
    bank_names_us TEXT[] := ARRAY['Bank of America', 'Chase', 'Wells Fargo', 'Citibank', 'US Bank'];
    swift_codes_us TEXT[] := ARRAY['BOFAUS3N', 'CHASUS33', 'WFBIUS6S', 'CITIUS33', 'USBKUS44'];

    first_names_de TEXT[] := ARRAY['Hans', 'Anna', 'Peter', 'Laura', 'Thomas', 'Julia', 'Michael', 'Sophie', 'Stefan', 'Marie'];
    last_names_de TEXT[] := ARRAY['Müller', 'Schmidt', 'Schneider', 'Fischer', 'Weber', 'Meyer', 'Wagner', 'Becker', 'Schulz', 'Hoffmann'];
    email_domains_de TEXT[] := ARRAY['example.de', 'mail.de', 'test.de', 'demo.de', 'sample.de'];
    streets_de TEXT[] := ARRAY['Hanomagstrasse', 'Hildesheimer Strasse', 'Hermann-Bahlsen-Allee', 'Hermann-Mende-Strasse', 'Hermann-Lons-Strasse'];
    cities_de TEXT[] := ARRAY['Berlin', 'Hamburg', 'Munich', 'Cologne', 'Frankfurt'];
    states_de TEXT[] := ARRAY['BE', 'HH', 'BY', 'NW', 'HE'];
    bank_names_de TEXT[] := ARRAY['Deutsche Bank', 'Commerzbank', 'UniCredit', 'BNP Paribas', 'Santander'];
    swift_codes_de TEXT[] := ARRAY['DEUTDEFF', 'COBADEFF', 'UNCRITMM', 'BNPAFRPP', 'BSCHESMM'];

BEGIN
    FOR i IN 1..10000 LOOP
        -- Randomly assign region
        v_region := CASE WHEN random() < 0.5 THEN 'US' ELSE 'DE' END;

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

        v_hire_date := CURRENT_DATE - floor(random() * 3650)::INTEGER;
        v_salary := round((random() * (150000 - 30000) + 30000)::NUMERIC, 2);
        v_department_id := floor(random() * 5 + 1)::INTEGER;

        -- Insert address
        INSERT INTO addresses (street, city, state, zip_code)
        VALUES (v_street, v_city, v_state, '12345')
        RETURNING address_id INTO v_address_id;

        -- Insert bank account
        v_account_number := 'ACC' || i;
        v_iban := 'US' || lpad(floor(random() * 9999999999999999999999999999 + 1000000000000000000000000000)::text, 30, '0');
        INSERT INTO bank_accounts (bank_name, account_number, iban, swift_code, encrypted_no)
        VALUES (v_bank_name, v_account_number, v_iban, v_swift_code, gen_random_bytes(20))
        RETURNING bank_account_id INTO v_bank_account_id;

        -- Insert employee
        INSERT INTO employees (first_name, last_name, email, hire_date, salary, department_id, address_id, bank_account_id)
        VALUES (v_first_name, v_last_name, v_email, v_hire_date, v_salary, v_department_id, v_address_id, v_bank_account_id)
        RETURNING employee_id INTO v_employee_id;

        -- Randomly assign manager
        v_manager_probability := random();
        IF v_manager_probability < 0.1 THEN
            v_manager_id := NULL;
        ELSE
            v_manager_id := floor(random() * v_employee_id + 1)::INTEGER;
        END IF;

        UPDATE employees SET manager_id = v_manager_id WHERE employee_id = v_employee_id;
    END LOOP;

    -- Call the transform_and_insert procedure to insert data into transformed_employees
    CALL transform_and_insert();
END;
$$;



-- Create a function to get a random element from an array
--CREATE OR REPLACE FUNCTION get_random_element(p_array TEXT[]) RETURNS TEXT AS $$
--DECLARE
--    v_index INTEGER;
--BEGIN
--    v_index := ceil(random() * array_length(p_array, 1));
--    RETURN p_array[v_index];
--END;
--$$ LANGUAGE plpgsql;


-- Alternative verion with floor: Create a function to get a random element from an array
CREATE OR REPLACE FUNCTION get_random_element(p_array TEXT[]) RETURNS TEXT AS $$
DECLARE
    v_index INTEGER;
BEGIN
    v_index := floor(random() * array_length(p_array, 1) + 1);
    RETURN p_array[v_index];
END;
$$ LANGUAGE plpgsql;


-- Create a function to get a random date
CREATE OR REPLACE FUNCTION get_random_date() RETURNS DATE AS $$
DECLARE
    v_start_date DATE := '2000-01-01';
    v_end_date DATE := '2023-12-31';
    v_diff INTEGER := v_end_date - v_start_date;
BEGIN
    RETURN v_start_date + floor(random() * v_diff)::INTEGER;
END;
$$ LANGUAGE plpgsql;



-- Drop the existing function if it exists
DROP FUNCTION IF EXISTS get_random_element(TEXT[]);

-- Create the get_random_element function
CREATE OR REPLACE FUNCTION get_random_element(p_array TEXT[]) RETURNS TEXT AS $$
DECLARE
    v_index INTEGER;
BEGIN
    v_index := floor(random() * array_length(p_array, 1) + 1);
    RETURN p_array[v_index];
END;
$$ LANGUAGE plpgsql;


-- Drop the existing function if it exists
DROP FUNCTION IF EXISTS get_random_date();

-- Create the get_random_date function
--CREATE OR REPLACE FUNCTION get_random_date() RETURNS DATE AS $$
--BEGIN
--    RETURN CURRENT_DATE - floor(random() * 3650)::INTEGER;
--END;
--$$ LANGUAGE plpgsql;

CREATE OR REPLACE FUNCTION get_random_date() RETURNS DATE AS $$
BEGIN
    RETURN CURRENT_DATE - CAST(floor(random() * 3650) AS INTEGER);
END;
$$ LANGUAGE plpgsql;


-- Drop the existing function if it exists
DROP FUNCTION IF EXISTS get_random_salary();

-- Create the get_random_salary function
CREATE OR REPLACE FUNCTION get_random_salary() RETURNS NUMERIC AS $$
BEGIN
    RETURN round((random() * (200000 - 30000) + 30000)::NUMERIC, 2);
END;
$$ LANGUAGE plpgsql;


-- Drop the existing function if it exists
DROP FUNCTION IF EXISTS get_random_department_id();

-- Create the get_random_department_id function
CREATE OR REPLACE FUNCTION get_random_department_id() RETURNS INTEGER AS $$
BEGIN
    RETURN floor(random() * 5 + 1)::INTEGER;
END;
$$ LANGUAGE plpgsql;

-- Drop the existing function if it exists
DROP FUNCTION IF EXISTS get_random_zip_code();

-- Create the get_random_zip_code function
CREATE OR REPLACE FUNCTION get_random_zip_code() RETURNS VARCHAR AS $$
BEGIN
    RETURN lpad(floor(random() * (99999 - 10000) + 10000)::text, 5, '0');
END;
$$ LANGUAGE plpgsql;

-- Drop the existing function if it exists
DROP FUNCTION IF EXISTS get_random_account_number();

-- Create the get_random_account_number function
CREATE OR REPLACE FUNCTION get_random_account_number() RETURNS VARCHAR AS $$
BEGIN
    RETURN lpad(floor(random() * 9999999999 + 1000000000)::text, 10, '0');
END;
$$ LANGUAGE plpgsql;

-- Drop the existing function if it exists
DROP FUNCTION IF EXISTS get_random_iban();

-- Create the get_random_iban function
CREATE OR REPLACE FUNCTION get_random_iban() RETURNS VARCHAR AS $$
BEGIN
    RETURN 'US' || lpad(floor(random() * 9999999999999999999999999999 + 1000000000000000000000000000)::text, 30, '0');
END;
$$ LANGUAGE plpgsql;

-- Drop the existing procedure if it exists
DROP PROCEDURE IF EXISTS data_generator;

-- Create the data_generator procedure
CREATE OR REPLACE PROCEDURE data_generator() LANGUAGE plpgsql AS $$
DECLARE
    v_employee_id INTEGER;
    v_first_name VARCHAR(50);
    v_last_name VARCHAR(50);
    v_email VARCHAR(100);
    v_hire_date DATE;
    v_salary NUMERIC(10, 2);
    v_manager_id INTEGER;
    v_department_id INTEGER;
    v_address_id INTEGER;
    v_bank_account_id INTEGER;
    v_manager_probability NUMERIC;
    v_street VARCHAR(100);
    v_city VARCHAR(50);
    v_state VARCHAR(50);
    v_zip_code VARCHAR(10);
    v_bank_name VARCHAR(100);
    v_account_number VARCHAR(20);
    v_iban VARCHAR(34);
    v_swift_code VARCHAR(11);

    first_names TEXT[] := ARRAY['John', 'Jane', 'Michael', 'Emily', 'Chris', 'Jessica', 'David', 'Sarah', 'James', 'Laura', 'Robert', 'Mary', 'William', 'Patricia', 'Linda', 'Barbara', 'Elizabeth', 'Jennifer', 'Maria', 'Susan'];
    last_names TEXT[] := ARRAY['Smith', 'Johnson', 'Williams', 'Jones', 'Brown', 'Davis', 'Miller', 'Wilson', 'Moore', 'Taylor', 'Anderson', 'Thomas', 'Jackson', 'White', 'Harris', 'Martin', 'Thompson', 'Garcia', 'Martinez', 'Robinson'];
    email_domains TEXT[] := ARRAY['example.com', 'mail.com', 'test.com', 'demo.com', 'sample.com', 'company.com', 'corp.com', 'org.com', 'net.com', 'edu.com', 'gov.com', 'us.com', 'uk.com', 'de.com', 'fr.com', 'it.com', 'es.com', 'ca.com', 'au.com', 'jp.com'];
    streets TEXT[] := ARRAY['Main St', 'High St', 'Broadway', 'Elm St', 'Maple Ave', 'Oak St', 'Pine St', 'Cedar St', 'Birch St', 'Walnut St', 'Hanomagstrasse', 'Hildesheimer Strasse', 'Hermann-Bahlsen-Allee', 'Hermann-Mende-Strasse', 'Hermann-Lons-Strasse', 'Hermann-Kohl-Strasse', 'Hermann-Billung-Strasse', 'Hermann-Bote-Strasse', 'Hermann-Boye-Strasse', 'Hermann-Blumenau-Strasse'];
    cities TEXT[] := ARRAY['New York', 'San Francisco', 'Seattle', 'Chicago', 'Boston', 'Los Angeles', 'Houston', 'Phoenix', 'Philadelphia', 'San Antonio', 'Berlin', 'Hamburg', 'Munich', 'Cologne', 'Frankfurt', 'Stuttgart', 'Dusseldorf', 'Dortmund', 'Essen', 'Leipzig'];
    states TEXT[] := ARRAY['NY', 'CA', 'WA', 'IL', 'MA', 'TX', 'AZ', 'PA', 'TX', 'TX', 'BE', 'HH', 'BY', 'NW', 'HE', 'BW', 'RP', 'SL', 'TH', 'BB'];
    bank_names TEXT[] := ARRAY['Bank of America', 'Chase', 'Wells Fargo', 'Citibank', 'US Bank', 'PNC Bank', 'Capital One', 'TD Bank', 'BB&T', 'SunTrust', 'Deutsche Bank', 'Commerzbank', 'UniCredit', 'BNP Paribas', 'Santander', 'Barclays', 'HSBC', 'Lloyds Bank', 'NatWest'];
    swift_codes TEXT[] := ARRAY['BOFAUS3N', 'CHASUS33', 'WFBIUS6S', 'CITIUS33', 'USBKUS44', 'PNCCUS33', 'NFBKUS33', 'TDBKUS33', 'BRBTUS33', 'SNTRUS3A', 'DEUTDEFF', 'COBADEFF', 'UNCRITMM', 'BNPAFRPP', 'BSCHESMM', 'LOYDGB2L', 'NWBKGB2L', 'BARCGB22', 'HSBCGB2L', 'SANTGB2L'];

    first_names_de TEXT[] := ARRAY['Hans', 'Anna', 'Peter', 'Laura', 'Thomas', 'Julia', 'Michael', 'Sophie', 'Stefan', 'Marie'];
    last_names_de TEXT[] := ARRAY['Müller', 'Schmidt', 'Schneider', 'Fischer', 'Weber', 'Meyer', 'Wagner', 'Becker', 'Schulz', 'Hoffmann'];
    email_domains_de TEXT[] := ARRAY['example.de', 'mail.de', 'test.de', 'demo.de', 'sample.de'];
    streets_de TEXT[] := ARRAY['Hanomagstrasse', 'Hildesheimer Strasse', 'Hermann-Bahlsen-Allee', 'Hermann-Mende-Strasse', 'Hermann-Lons-Strasse'];
    cities_de TEXT[] := ARRAY['Berlin', 'Hamburg', 'Munich', 'Cologne', 'Frankfurt'];
    states_de TEXT[] := ARRAY['BE', 'HH', 'BY', 'NW', 'HE'];
    bank_names_de TEXT[] := ARRAY['Deutsche Bank', 'Commerzbank', 'UniCredit', 'BNP Paribas', 'Santander'];
    swift_codes_de TEXT[] := ARRAY['DEUTDEFF', 'COBADEFF', 'UNCRITMM', 'BNPAFRPP', 'BSCHESMM'];

BEGIN
    -- Randomly decide the number of operations to perform
    FOR i IN 1..floor(random() * 10 + 1) LOOP
        -- Randomly decide the type of operation: insert, update, or delete
        CASE floor(random() * 3 + 1)::int
            WHEN 1 THEN
                -- Insert operation
                v_first_name := get_random_element(first_names);
                v_last_name := get_random_element(last_names);
                v_email := v_first_name || '.' || v_last_name || '@' || get_random_element(email_domains);
                v_hire_date := get_random_date();
                v_salary := get_random_salary();
                v_department_id := get_random_department_id(); -- Ensure this department_id exists

                -- Insert address
                v_street := get_random_element(streets);
                v_city := get_random_element(cities);
                v_state := get_random_element(states);
                v_zip_code := get_random_zip_code();
                INSERT INTO addresses (street, city, state, zip_code)
                VALUES (v_street, v_city, v_state, v_zip_code)
                RETURNING address_id INTO v_address_id;

                -- Insert bank account
                v_bank_name := get_random_element(bank_names);
                v_account_number := get_random_account_number();
                v_iban := get_random_iban();
                v_swift_code := get_random_element(swift_codes);
                INSERT INTO bank_accounts (bank_name, account_number, iban, swift_code)
                VALUES (v_bank_name, v_account_number, v_iban, v_swift_code)
                RETURNING bank_account_id INTO v_bank_account_id;

                -- Assign a manager with a certain probability
                v_manager_probability := random();
                IF v_manager_probability < 0.1 THEN
                    v_manager_id := floor(random() * 1000) + 1; -- Assuming there are 1000 employees
                ELSE
                    v_manager_id := NULL;
                END IF;

                INSERT INTO employees (first_name, last_name, email, hire_date, salary, manager_id, department_id, address_id, bank_account_id)
                VALUES (v_first_name, v_last_name, v_email, v_hire_date, v_salary, v_manager_id, v_department_id, v_address_id, v_bank_account_id)
                RETURNING employee_id INTO v_employee_id;

            WHEN 2 THEN
                -- Update operation
                SELECT employee_id INTO v_employee_id FROM employees ORDER BY random() LIMIT 1;
                v_salary := get_random_salary();
                UPDATE employees SET salary = v_salary WHERE employee_id = v_employee_id;

            WHEN 3 THEN
                -- Delete operation
                SELECT employee_id INTO v_employee_id FROM employees ORDER BY random() LIMIT 1;
                -- Delete related records in employee_departments first
                DELETE FROM employee_departments WHERE employee_id = v_employee_id;
                DELETE FROM employees WHERE employee_id = v_employee_id;
        END CASE;
    END LOOP;

    COMMIT;
END;
$$;


-- Create the audit function
CREATE OR REPLACE FUNCTION trg_departments_audit() RETURNS TRIGGER AS $$
DECLARE
    v_old_values TEXT;
    v_new_values TEXT;
BEGIN
    IF TG_OP = 'INSERT' THEN
        v_new_values := 'department_id=' || NEW.department_id || ', department_name=' || NEW.department_name || ', location=' || NEW.location;
        INSERT INTO audit_log (audit_id, table_name, operation, record_id, new_values)
        VALUES (nextval('audit_seq'), 'departments', 'INSERT', NEW.department_id, v_new_values);
    ELSIF TG_OP = 'UPDATE' THEN
        v_old_values := 'department_id=' || OLD.department_id || ', department_name=' || OLD.department_name || ', location=' || OLD.location;
        v_new_values := 'department_id=' || NEW.department_id || ', department_name=' || NEW.department_name || ', location=' || NEW.location;
        INSERT INTO audit_log (audit_id, table_name, operation, record_id, old_values, new_values)
        VALUES (nextval('audit_seq'), 'departments', 'UPDATE', NEW.department_id, v_old_values, v_new_values);
    ELSIF TG_OP = 'DELETE' THEN
        v_old_values := 'department_id=' || OLD.department_id || ', department_name=' || OLD.department_name || ', location=' || OLD.location;
        INSERT INTO audit_log (audit_id, table_name, operation, record_id, old_values)
        VALUES (nextval('audit_seq'), 'departments', 'DELETE', OLD.department_id, v_old_values);
    END IF;
    RETURN NULL;
END;
$$ LANGUAGE plpgsql;

-- Create the trigger
CREATE TRIGGER trg_departments_audit
AFTER INSERT OR UPDATE OR DELETE ON departments
FOR EACH ROW EXECUTE FUNCTION trg_departments_audit();



-- Create the audit function
CREATE OR REPLACE FUNCTION trg_employees_audit() RETURNS TRIGGER AS $$
DECLARE
    v_old_values TEXT;
    v_new_values TEXT;
BEGIN
    IF TG_OP = 'INSERT' THEN
        v_new_values := 'employee_id=' || NEW.employee_id || ', first_name=' || NEW.first_name || ', last_name=' || NEW.last_name || ', email=' || NEW.email || ', hire_date=' || NEW.hire_date || ', salary=' || NEW.salary;
        INSERT INTO audit_log (audit_id, table_name, operation, record_id, new_values)
        VALUES (nextval('audit_seq'), 'employees', 'INSERT', NEW.employee_id, v_new_values);
    ELSIF TG_OP = 'UPDATE' THEN
        v_old_values := 'employee_id=' || OLD.employee_id || ', first_name=' || OLD.first_name || ', last_name=' || OLD.last_name || ', email=' || OLD.email || ', hire_date=' || OLD.hire_date || ', salary=' || OLD.salary;
        v_new_values := 'employee_id=' || NEW.employee_id || ', first_name=' || NEW.first_name || ', last_name=' || NEW.last_name || ', email=' || NEW.email || ', hire_date=' || NEW.hire_date || ', salary=' || NEW.salary;
        INSERT INTO audit_log (audit_id, table_name, operation, record_id, old_values, new_values)
        VALUES (nextval('audit_seq'), 'employees', 'UPDATE', NEW.employee_id, v_old_values, v_new_values);
    ELSIF TG_OP = 'DELETE' THEN
        v_old_values := 'employee_id=' || OLD.employee_id || ', first_name=' || OLD.first_name || ', last_name=' || OLD.last_name || ', email=' || OLD.email || ', hire_date=' || OLD.hire_date || ', salary=' || OLD.salary;
        INSERT INTO audit_log (audit_id, table_name, operation, record_id, old_values)
        VALUES (nextval('audit_seq'), 'employees', 'DELETE', OLD.employee_id, v_old_values);
    END IF;
    RETURN NULL;
END;
$$ LANGUAGE plpgsql;


-- Create the trigger
CREATE TRIGGER trg_employees_audit
AFTER INSERT OR UPDATE OR DELETE ON employees
FOR EACH ROW EXECUTE FUNCTION trg_employees_audit();