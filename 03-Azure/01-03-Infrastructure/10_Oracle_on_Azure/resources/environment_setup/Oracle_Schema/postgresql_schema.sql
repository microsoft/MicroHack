CREATE TABLE departments (
    department_id SERIAL PRIMARY KEY,
    department_name VARCHAR(100),
    location VARCHAR(100)
);

CREATE TABLE addresses (
    address_id SERIAL PRIMARY KEY,
    street VARCHAR2(100),
    city VARCHAR2(50),
    state VARCHAR2(50),
    zip_code VARCHAR2(10)
);

CREATE TABLE bank_accounts (
    bank_account_id SERIAL PRIMARY KEY,
    bank_name VARCHAR2(100),
    account_number VARCHAR2(20),
    iban VARCHAR2(34),
    swift_code VARCHAR2(11),
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


-- Create a function to calculate bonus
CREATE OR REPLACE FUNCTION calculate_bonus(p_salary NUMERIC) RETURNS NUMERIC AS $$
BEGIN
    RETURN p_salary * 0.05; -- 5% bonus
END;
$$ LANGUAGE plpgsql;

-- Create a function to transform and insert data
CREATE OR REPLACE FUNCTION transform_and_insert() RETURNS VOID AS $$
DECLARE
    emp_cursor CURSOR FOR SELECT employee_id, first_name, last_name, email, hire_date, salary FROM employees;
    v_employee_id INTEGER;
    v_first_name VARCHAR(50);
    v_last_name VARCHAR(50);
    v_email VARCHAR(100);
    v_hire_date DATE;
    v_salary NUMERIC(10, 2);
    v_new_salary NUMERIC(10, 2);
    v_bonus NUMERIC(10, 2);
BEGIN
    FOR emp_record IN emp_cursor LOOP
        v_employee_id := emp_record.employee_id;
        v_first_name := emp_record.first_name;
        v_last_name := emp_record.last_name;
        v_email := emp_record.email;
        v_hire_date := emp_record.hire_date;
        v_salary := emp_record.salary;

        -- Example transformation: Increase salary by 10%
        v_new_salary := v_salary * 1.10;

        -- Calculate bonus using the function
        v_bonus := calculate_bonus(v_salary);

        -- Insert transformed data into a new table
        INSERT INTO transformed_employees (employee_id, first_name, last_name, email, hire_date, new_salary, bonus)
        VALUES (v_employee_id, v_first_name, v_last_name, v_email, v_hire_date, v_new_salary, v_bonus);
    END LOOP;
END;
$$ LANGUAGE plpgsql;

-- Create a procedure to ingest 1 million records with realistic data
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
BEGIN
    FOR i IN 1..1000000 LOOP
        v_first_name := 'First' || i;
        v_last_name := 'Last' || i;
        v_email := 'email' || i || '@example.com';
        v_hire_date := CURRENT_DATE - (i % 365);
        v_salary := 50000 + (i % 10000);
        v_department_id := (i % 5) + 1;

        INSERT INTO employees (first_name, last_name, email, hire_date, salary, department_id)
        VALUES (v_first_name, v_last_name, v_email, v_hire_date, v_salary, v_department_id);
    END LOOP;
END;
$$;

-- Schedule the data_generator procedure to run every 2 minutes
CREATE OR REPLACE FUNCTION data_generator() RETURNS VOID AS $$
BEGIN
    PERFORM ingest_1_million_records();
END;
$$ LANGUAGE plpgsql;

CREATE OR REPLACE FUNCTION schedule_data_generator() RETURNS VOID AS $$
BEGIN
    PERFORM pg_sleep(120);
    PERFORM data_generator();
END;
$$ LANGUAGE plpgsql;

-- Trigger to log changes to the departments table
CREATE OR REPLACE FUNCTION trg_departments_audit() RETURNS TRIGGER AS $$
BEGIN
    IF TG_OP = 'INSERT' THEN
        INSERT INTO audit_log (table_name, operation, record_id, new_values)
        VALUES ('departments', 'INSERT', NEW.department_id, row_to_json(NEW)::text);
    ELSIF TG_OP = 'UPDATE' THEN
        INSERT INTO audit_log (table_name, operation, record_id, old_values, new_values)
        VALUES ('departments', 'UPDATE', NEW.department_id, row_to_json(OLD)::text, row_to_json(NEW)::text);
    ELSIF TG_OP = 'DELETE' THEN
        INSERT INTO audit_log (table_name, operation, record_id, old_values)
        VALUES ('departments', 'DELETE', OLD.department_id, row_to_json(OLD)::text);
    END IF;
    RETURN NULL;
END;
$$ LANGUAGE plpgsql;

CREATE TRIGGER trg_departments_audit
AFTER INSERT OR UPDATE OR DELETE ON departments
FOR EACH ROW EXECUTE FUNCTION trg_departments_audit();

-- Repeat similar triggers for other tables as needed