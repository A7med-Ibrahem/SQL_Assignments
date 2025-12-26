-- ==============================================
-- 13. Customer Order History Procedure
-- ==============================================
CREATE PROCEDURE sp_GetCustomerOrderHistory
    @CustomerID INT,
    @StartDate DATE = NULL,
    @EndDate DATE = NULL
AS
BEGIN
    SELECT 
        o.order_id,
        o.order_date,
        SUM(oi.quantity * oi.unit_price) AS order_total
    FROM Orders o
    JOIN OrderItems oi ON o.order_id = oi.order_id
    WHERE o.customer_id = @CustomerID
      AND (@StartDate IS NULL OR o.order_date >= @StartDate)
      AND (@EndDate IS NULL OR o.order_date <= @EndDate)
    GROUP BY o.order_id, o.order_date
    ORDER BY o.order_date DESC;
END
GO

-- ==============================================
-- 14. Inventory Restock Procedure
-- ==============================================
CREATE PROCEDURE sp_RestockProduct
    @StoreID INT,
    @ProductID INT,
    @RestockQty INT,
    @OldQty INT OUTPUT,
    @NewQty INT OUTPUT,
    @Success BIT OUTPUT
AS
BEGIN
    SET @Success = 0;

    SELECT @OldQty = quantity
    FROM Stocks
    WHERE store_id = @StoreID AND product_id = @ProductID;

    IF @OldQty IS NULL
    BEGIN
        INSERT INTO Stocks(store_id, product_id, quantity)
        VALUES (@StoreID, @ProductID, @RestockQty);
        SET @NewQty = @RestockQty;
    END
    ELSE
    BEGIN
        UPDATE Stocks
        SET quantity = quantity + @RestockQty
        WHERE store_id = @StoreID AND product_id = @ProductID;
        SET @NewQty = @OldQty + @RestockQty;
    END

    SET @Success = 1;
END
GO

-- ==============================================
-- 15. Order Processing Procedure
-- ==============================================
CREATE PROCEDURE sp_ProcessNewOrder
    @CustomerID INT,
    @ProductID INT,
    @Quantity INT,
    @StoreID INT
AS
BEGIN
    BEGIN TRY
        BEGIN TRANSACTION;

        DECLARE @UnitPrice DECIMAL(10,2);
        SELECT @UnitPrice = price FROM Products WHERE product_id = @ProductID;

        INSERT INTO Orders(customer_id, order_date)
        VALUES (@CustomerID, GETDATE());

        DECLARE @OrderID INT = SCOPE_IDENTITY();

        INSERT INTO OrderItems(order_id, product_id, quantity, unit_price)
        VALUES (@OrderID, @ProductID, @Quantity, @UnitPrice);

        UPDATE Stocks
        SET quantity = quantity - @Quantity
        WHERE store_id = @StoreID AND product_id = @ProductID;

        COMMIT TRANSACTION;
    END TRY
    BEGIN CATCH
        ROLLBACK TRANSACTION;
        PRINT 'Error: ' + ERROR_MESSAGE();
    END CATCH
END
GO

-- ==============================================
-- 16. Dynamic Product Search Procedure
-- ==============================================
CREATE PROCEDURE sp_SearchProducts
    @ProductName NVARCHAR(100) = NULL,
    @CategoryID INT = NULL,
    @MinPrice DECIMAL(10,2) = NULL,
    @MaxPrice DECIMAL(10,2) = NULL,
    @SortColumn NVARCHAR(50) = 'product_name'
AS
BEGIN
    DECLARE @SQL NVARCHAR(MAX) = 'SELECT * FROM Products WHERE 1=1';

    IF @ProductName IS NOT NULL
        SET @SQL += ' AND product_name LIKE ''%' + @ProductName + '%''';

    IF @CategoryID IS NOT NULL
        SET @SQL += ' AND category_id = ' + CAST(@CategoryID AS NVARCHAR);

    IF @MinPrice IS NOT NULL
        SET @SQL += ' AND price >= ' + CAST(@MinPrice AS NVARCHAR);

    IF @MaxPrice IS NOT NULL
        SET @SQL += ' AND price <= ' + CAST(@MaxPrice AS NVARCHAR);

    SET @SQL += ' ORDER BY ' + @SortColumn;

    EXEC sp_executesql @SQL;
END
GO

-- ==============================================
-- 17. Staff Bonus Calculation Procedure
-- ==============================================
CREATE PROCEDURE sp_CalculateStaffBonus
AS
BEGIN
    DECLARE @StartDate DATE = DATEADD(QUARTER, DATEDIFF(QUARTER, 0, GETDATE()), 0);
    DECLARE @EndDate DATE = DATEADD(DAY, -1, DATEADD(QUARTER, 1, @StartDate));

    SELECT 
        s.staff_id,
        s.staff_name,
        SUM(o.quantity * oi.unit_price) AS total_sales,
        CASE
            WHEN SUM(o.quantity * oi.unit_price) >= 10000 THEN SUM(o.quantity * oi.unit_price) * 0.10
            WHEN SUM(o.quantity * oi.unit_price) >= 5000 THEN SUM(o.quantity * oi.unit_price) * 0.05
            ELSE SUM(o.quantity * oi.unit_price) * 0.02
        END AS bonus
    FROM Staff s
    LEFT JOIN Orders o ON s.staff_id = o.staff_id AND o.order_date BETWEEN @StartDate AND @EndDate
    LEFT JOIN OrderItems oi ON o.order_id = oi.order_id
    GROUP BY s.staff_id, s.staff_name;
END
GO

-- ==============================================
-- 18. Smart Inventory Management
-- ==============================================
CREATE PROCEDURE sp_ManageInventory
AS
BEGIN
    DECLARE @ProductID INT, @CurrentQty INT, @ReorderQty INT;

    DECLARE cur CURSOR FOR
        SELECT product_id, quantity FROM Stocks;

    OPEN cur;
    FETCH NEXT FROM cur INTO @ProductID, @CurrentQty;

    WHILE @@FETCH_STATUS = 0
    BEGIN
        IF @CurrentQty < 10
            SET @ReorderQty = 50;
        ELSE IF @CurrentQty < 50
            SET @ReorderQty = 20;
        ELSE
            SET @ReorderQty = 0;

        IF @ReorderQty > 0
            UPDATE Stocks
            SET quantity = quantity + @ReorderQty
            WHERE product_id = @ProductID;

        FETCH NEXT FROM cur INTO @ProductID, @CurrentQty;
    END

    CLOSE cur;
    DEALLOCATE cur;
END
GO

-- ==============================================
-- 19. Customer Loyalty Tier Assignment
-- ==============================================
CREATE PROCEDURE sp_AssignLoyaltyTier
AS
BEGIN
    UPDATE Customers
    SET loyalty_tier =
        CASE 
            WHEN total_spent >= 10000 THEN 'Platinum'
            WHEN total_spent >= 5000 THEN 'Gold'
            WHEN total_spent >= 1000 THEN 'Silver'
            ELSE 'Bronze'
        END
    WHERE total_spent IS NOT NULL;

    UPDATE Customers
    SET loyalty_tier = 'Bronze'
    WHERE total_spent IS NULL;
END
GO

-- ==============================================
-- 20. Product Lifecycle Management
-- ==============================================
CREATE PROCEDURE sp_DiscontinueProduct
    @ProductID INT
AS
BEGIN
    DECLARE @PendingOrders INT;

    SELECT @PendingOrders = COUNT(*) 
    FROM OrderItems 
    WHERE product_id = @ProductID;

    IF @PendingOrders > 0
        PRINT 'Cannot discontinue product, pending orders exist.';
    ELSE
    BEGIN
        DELETE FROM Stocks WHERE product_id = @ProductID;
        DELETE FROM Products WHERE product_id = @ProductID;
        PRINT 'Product discontinued successfully.';
    END
END
GO
