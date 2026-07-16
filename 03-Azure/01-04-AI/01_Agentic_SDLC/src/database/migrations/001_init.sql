-- Initial database schema for OctoCAT Supply Chain Management
-- Migration 001: Create core tables

-- Create suppliers table
CREATE TABLE suppliers (
    supplier_id INTEGER PRIMARY KEY,
    name TEXT NOT NULL,
    description TEXT,
    contact_person TEXT,
    email TEXT,
    phone TEXT
);

-- Create headquarters table
CREATE TABLE headquarters (
    headquarters_id INTEGER PRIMARY KEY,
    name TEXT NOT NULL,
    description TEXT,
    address TEXT,
    contact_person TEXT,
    email TEXT,
    phone TEXT
);

-- Create branches table (references headquarters)
CREATE TABLE branches (
    branch_id INTEGER PRIMARY KEY,
    headquarters_id INTEGER NOT NULL,
    name TEXT NOT NULL,
    description TEXT,
    address TEXT,
    contact_person TEXT,
    email TEXT,
    phone TEXT,
    FOREIGN KEY (headquarters_id) REFERENCES headquarters(headquarters_id) ON DELETE CASCADE
);

-- Create products table (references suppliers)
CREATE TABLE products (
    product_id INTEGER PRIMARY KEY,
    supplier_id INTEGER NOT NULL,
    name TEXT NOT NULL,
    description TEXT,
    price REAL NOT NULL,
    sku TEXT NOT NULL,
    unit TEXT NOT NULL,
    img_name TEXT,
    discount REAL DEFAULT 0.0,
    FOREIGN KEY (supplier_id) REFERENCES suppliers(supplier_id) ON DELETE CASCADE
);

-- Create orders table (references branches)
CREATE TABLE orders (
    order_id INTEGER PRIMARY KEY,
    branch_id INTEGER NOT NULL,
    order_date TEXT NOT NULL,
    name TEXT NOT NULL,
    description TEXT,
    status TEXT NOT NULL DEFAULT 'pending',
    FOREIGN KEY (branch_id) REFERENCES branches(branch_id) ON DELETE CASCADE
);

-- Create order_details table (references orders and products)
CREATE TABLE order_details (
    order_detail_id INTEGER PRIMARY KEY,
    order_id INTEGER NOT NULL,
    product_id INTEGER NOT NULL,
    quantity INTEGER NOT NULL,
    unit_price REAL NOT NULL,
    notes TEXT,
    FOREIGN KEY (order_id) REFERENCES orders(order_id) ON DELETE CASCADE,
    FOREIGN KEY (product_id) REFERENCES products(product_id) ON DELETE CASCADE
);

-- Create deliveries table (references suppliers)
CREATE TABLE deliveries (
    delivery_id INTEGER PRIMARY KEY,
    supplier_id INTEGER NOT NULL,
    delivery_date TEXT NOT NULL,
    name TEXT NOT NULL,
    description TEXT,
    status TEXT NOT NULL DEFAULT 'pending',
    FOREIGN KEY (supplier_id) REFERENCES suppliers(supplier_id) ON DELETE CASCADE
);

-- Create order_detail_deliveries table (junction table)
CREATE TABLE order_detail_deliveries (
    order_detail_delivery_id INTEGER PRIMARY KEY,
    order_detail_id INTEGER NOT NULL,
    delivery_id INTEGER NOT NULL,
    quantity INTEGER NOT NULL,
    notes TEXT,
    FOREIGN KEY (order_detail_id) REFERENCES order_details(order_detail_id) ON DELETE CASCADE,
    FOREIGN KEY (delivery_id) REFERENCES deliveries(delivery_id) ON DELETE CASCADE
);

-- Create indexes for better performance
CREATE INDEX idx_branches_headquarters_id ON branches(headquarters_id);
CREATE INDEX idx_products_supplier_id ON products(supplier_id);
CREATE INDEX idx_products_sku ON products(sku);
CREATE INDEX idx_orders_branch_id ON orders(branch_id);
CREATE INDEX idx_orders_status ON orders(status);
CREATE INDEX idx_order_details_order_id ON order_details(order_id);
CREATE INDEX idx_order_details_product_id ON order_details(product_id);
CREATE INDEX idx_deliveries_supplier_id ON deliveries(supplier_id);
CREATE INDEX idx_deliveries_status ON deliveries(status);
CREATE INDEX idx_order_detail_deliveries_order_detail_id ON order_detail_deliveries(order_detail_id);
CREATE INDEX idx_order_detail_deliveries_delivery_id ON order_detail_deliveries(delivery_id);