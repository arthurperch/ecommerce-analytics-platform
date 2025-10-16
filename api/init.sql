-- Initialize database with sample schema and data
USE analytics;

-- Create sample sales transactions
CREATE TABLE IF NOT EXISTS sample_sales_transactions (
    id INT AUTO_INCREMENT PRIMARY KEY,
    transaction_id VARCHAR(50) UNIQUE,
    customer_id VARCHAR(50),
    product_id VARCHAR(50),
    product_name VARCHAR(200),
    category VARCHAR(100),
    quantity INT,
    unit_price DECIMAL(10,2),
    total_amount DECIMAL(10,2),
    transaction_date DATETIME,
    region VARCHAR(50),
    channel VARCHAR(50),
    created_at DATETIME DEFAULT CURRENT_TIMESTAMP,
    INDEX idx_customer (customer_id),
    INDEX idx_product (product_id),
    INDEX idx_date (transaction_date),
    INDEX idx_region (region),
    INDEX idx_channel (channel)
);

-- Insert sample data
INSERT INTO sample_sales_transactions (
    transaction_id, customer_id, product_id, product_name, category,
    quantity, unit_price, total_amount, transaction_date, region, channel
) VALUES 
    ('TXN001', 'CUST001', 'PROD001', 'Wireless Headphones', 'Electronics', 1, 99.99, 99.99, '2024-01-15 10:30:00', 'US-East', 'online'),
    ('TXN002', 'CUST002', 'PROD002', 'Smart Watch', 'Electronics', 1, 299.99, 299.99, '2024-01-15 14:20:00', 'US-West', 'store'),
    ('TXN003', 'CUST003', 'PROD003', 'Running Shoes', 'Sports', 1, 129.99, 129.99, '2024-01-16 09:15:00', 'EU', 'mobile'),
    ('TXN004', 'CUST001', 'PROD004', 'Coffee Maker', 'Home', 1, 89.99, 89.99, '2024-01-16 16:45:00', 'US-East', 'online'),
    ('TXN005', 'CUST004', 'PROD001', 'Wireless Headphones', 'Electronics', 2, 99.99, 199.98, '2024-01-17 11:30:00', 'CA', 'online'),
    ('TXN006', 'CUST005', 'PROD005', 'Laptop Stand', 'Office', 1, 49.99, 49.99, '2024-01-17 13:20:00', 'US-West', 'store'),
    ('TXN007', 'CUST002', 'PROD006', 'Bluetooth Speaker', 'Electronics', 1, 79.99, 79.99, '2024-01-18 15:10:00', 'US-West', 'mobile'),
    ('TXN008', 'CUST006', 'PROD007', 'Yoga Mat', 'Sports', 1, 39.99, 39.99, '2024-01-18 08:30:00', 'EU', 'online'),
    ('TXN009', 'CUST003', 'PROD008', 'Water Bottle', 'Sports', 3, 19.99, 59.97, '2024-01-19 12:15:00', 'EU', 'store'),
    ('TXN010', 'CUST007', 'PROD002', 'Smart Watch', 'Electronics', 1, 299.99, 299.99, '2024-01-19 17:45:00', 'APAC', 'online');

-- Create sample customer metrics
CREATE TABLE IF NOT EXISTS sample_customer_metrics (
    id INT AUTO_INCREMENT PRIMARY KEY,
    customer_id VARCHAR(50) UNIQUE,
    total_orders INT DEFAULT 0,
    total_spent DECIMAL(10,2) DEFAULT 0.00,
    avg_order_value DECIMAL(10,2) DEFAULT 0.00,
    last_purchase_date DATETIME,
    customer_lifetime_value DECIMAL(10,2) DEFAULT 0.00,
    is_active BOOLEAN DEFAULT TRUE,
    acquisition_date DATETIME,
    updated_at DATETIME DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP,
    INDEX idx_customer_id (customer_id),
    INDEX idx_active (is_active)
);

-- Insert sample customer metrics
INSERT INTO sample_customer_metrics (
    customer_id, total_orders, total_spent, avg_order_value,
    last_purchase_date, customer_lifetime_value, acquisition_date
) VALUES 
    ('CUST001', 2, 189.98, 94.99, '2024-01-16 16:45:00', 250.00, '2024-01-01 00:00:00'),
    ('CUST002', 2, 379.98, 189.99, '2024-01-18 15:10:00', 400.00, '2024-01-02 00:00:00'),
    ('CUST003', 2, 189.96, 94.98, '2024-01-19 12:15:00', 220.00, '2024-01-03 00:00:00'),
    ('CUST004', 1, 199.98, 199.98, '2024-01-17 11:30:00', 300.00, '2024-01-04 00:00:00'),
    ('CUST005', 1, 49.99, 49.99, '2024-01-17 13:20:00', 150.00, '2024-01-05 00:00:00'),
    ('CUST006', 1, 39.99, 39.99, '2024-01-18 08:30:00', 100.00, '2024-01-06 00:00:00'),
    ('CUST007', 1, 299.99, 299.99, '2024-01-19 17:45:00', 350.00, '2024-01-07 00:00:00');