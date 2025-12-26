-- ==============================================
-- 1. Non-clustered index on email column
-- ==============================================
CREATE NONCLUSTERED INDEX idx_customers_email
ON sales.customers(email);
GO

-- ==============================================
-- 2. Composite index on category_id and brand_id
-- ==============================================
CREATE NONCLUSTERED INDEX idx_products_category_brand
ON production.products(category_id, brand_id);
GO

-- ==============================================
-- 3. Index on orders with included columns
-- ==============================================
CREATE NONCLUSTERED INDEX idx_orders_date_included
ON sales.orders(order_date)
INCLUDE (customer_id, store_id, order_status);
GO

-- ==============================================
-- 4. Trigger: Insert welcome record on new customer
-- ==============================================
-- First, create the log table if not exists
CREATE TABLE sales.customer_log (
    log_id INT IDENTITY(1,1) PRIMARY KEY,
    customer_id INT,
    action VARCHAR(50),
    log_date DATETIME DEFAULT GETDATE()
);
GO

CREATE TRIGGER trg_Customers_Insert
ON sales.customers
AFTER INSERT
AS
BEGIN
    INSERT INTO sales.customer_log(customer_id, action)
    SELECT customer_id, 'Welcome record added'
    FROM inserted;
END
GO

-- ==============================================
-- 5. Trigger: Log price changes
-- ==============================================
CREATE TABLE production.price_history (
    history_id INT IDENTITY(1,1) PRIMARY KEY,
    product_id INT,
    old_price DECIMAL(10,2),
    new_price DECIMAL(10,2),
    change_date DATETIME DEFAULT GETDATE(),
    changed_by VARCHAR(100)
);
GO

CREATE TRIGGER trg_Products_PriceChange
ON production.products
AFTER UPDATE
AS
BEGIN
    IF UPDATE(list_price)
    BEGIN
        INSERT INTO production.price_history(product_id, old_price, new_price, changed_by)
        SELECT i.product_id, d.list_price, i.list_price, SYSTEM_USER
        FROM inserted i
        JOIN deleted d ON i.product_id = d.product_id;
    END
END
GO

-- ==============================================
-- 6. INSTEAD OF DELETE trigger on categories
-- ==============================================
CREATE TRIGGER trg_Categories_PreventDelete
ON production.categories
INSTEAD OF DELETE
AS
BEGIN
    IF EXISTS (
        SELECT 1
        FROM deleted d
        JOIN production.products p ON d.category_id = p.category_id
    )
    BEGIN
        RAISERROR('Cannot delete category with associated products.', 16, 1);
        RETURN;
    END
    ELSE
    BEGIN
        DELETE FROM production.categories
        WHERE category_id IN (SELECT category_id FROM deleted);
    END
END
GO

-- ==============================================
-- 7. Trigger: Reduce stock when order item inserted
-- ==============================================
CREATE TRIGGER trg_OrderItems_ReduceStock
ON sales.order_items
AFTER INSERT
AS
BEGIN
    UPDATE s
    SET s.quantity = s.quantity - i.quantity
    FROM production.stocks s
    JOIN inserted i ON s.product_id = i.product_id AND s.store_id = i.store_id;
END
GO

-- ==============================================
-- 8. Trigger: Log all new orders
-- ==============================================
CREATE TABLE sales.order_audit (
    audit_id INT IDENTITY(1,1) PRIMARY KEY,
    order_id INT,
    customer_id INT,
    store_id INT,
    staff_id INT,
    order_date DATE,
    audit_timestamp DATETIME DEFAULT GETDATE()
);
GO

CREATE TRIGGER trg_Orders_Audit
ON sales.orders
AFTER INSERT
AS
BEGIN
    INSERT INTO sales.order_audit(order_id, customer_id, store_id, staff_id, order_date)
    SELECT order_id, customer_id, store_id, staff_id, order_date
    FROM inserted;
END
GO
