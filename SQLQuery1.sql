
-- TASK 1: Customer Spending Analysis
-- ========================================
DECLARE @CustomerID INT = 1;
DECLARE @TotalSpent DECIMAL(10,2);

SELECT @TotalSpent = SUM(oi.Quantity * oi.Price)
FROM [Order] o
JOIN OrderItem oi ON o.OrderID = oi.OrderID
WHERE o.CustomerID = @CustomerID;

IF @TotalSpent > 5000
    PRINT 'Customer ' + CAST(@CustomerID AS NVARCHAR) + ' is VIP';
ELSE
    PRINT 'Customer ' + CAST(@CustomerID AS NVARCHAR) + ' is Regular';


-- TASK 2: Product Price Threshold Report
DECLARE @Threshold DECIMAL(10,2) = 1500;
DECLARE @Count INT;

SELECT @Count = COUNT(*) FROM Product WHERE ListPrice > @Threshold;
PRINT 'Products above ' + CAST(@Threshold AS NVARCHAR) + ': ' + CAST(@Count AS NVARCHAR);

-- TASK 3: Staff Performance Calculator
DECLARE @StaffID INT = 2;
DECLARE @Year INT = 2017;
DECLARE @StaffSales DECIMAL(10,2);

SELECT @StaffSales = SUM(oi.Quantity * oi.Price)
FROM [Order] o
JOIN OrderItem oi ON o.OrderID = oi.OrderID
WHERE o.StaffID = @StaffID AND YEAR(o.OrderDate) = @Year;

PRINT 'Staff ' + CAST(@StaffID AS NVARCHAR) + ' Total Sales in ' + CAST(@Year AS NVARCHAR) + ': ' + CAST(@StaffSales AS NVARCHAR);

-- TASK 4: Global Variables Information
SELECT @@SERVERNAME AS ServerName, @@VERSION AS SQLVersion, @@ROWCOUNT AS LastRowsAffected;

-- TASK 5: Inventory Level Check
DECLARE @StoreID INT = 1;
DECLARE @ProductID INT = 1;
DECLARE @Quantity INT;

SELECT @Quantity = Quantity FROM Inventory WHERE StoreID = @StoreID AND ProductID = @ProductID;

IF @Quantity > 20
    PRINT 'Well stocked';
ELSE IF @Quantity BETWEEN 10 AND 20
    PRINT 'Moderate stock';
ELSE
    PRINT 'Low stock - reorder needed';

-- TASK 6: WHILE loop updating low-stock items
DECLARE @Counter INT = 1;

WHILE EXISTS(SELECT 1 FROM Inventory WHERE Quantity < 5)
BEGIN
    UPDATE TOP (3) Inventory
    SET Quantity = Quantity + 10
    WHERE Quantity < 5;

    SET @Counter = @Counter + 1;
    PRINT 'Batch ' + CAST(@Counter AS NVARCHAR) + ' processed';
END

-- TASK 7: Product Price Categorization
SELECT ProductName, ListPrice,
CASE 
    WHEN ListPrice < 300 THEN 'Budget'
    WHEN ListPrice BETWEEN 300 AND 800 THEN 'Mid-Range'
    WHEN ListPrice BETWEEN 801 AND 2000 THEN 'Premium'
    ELSE 'Luxury'
END AS PriceCategory
FROM Product;

-- TASK 8: Customer Order Validation
DECLARE @CustID INT = 5;
IF EXISTS(SELECT 1 FROM Customer WHERE CustomerID = @CustID)
BEGIN
    SELECT COUNT(*) AS OrderCount FROM [Order] WHERE CustomerID = @CustID;
END
ELSE
    PRINT 'Customer does not exist';

-- TASK 9: Shipping Cost Calculator Function
IF OBJECT_ID('CalculateShipping', 'FN') IS NOT NULL DROP FUNCTION CalculateShipping;
GO
CREATE FUNCTION CalculateShipping(@OrderTotal DECIMAL(10,2))
RETURNS DECIMAL(10,2)
AS
BEGIN
    DECLARE @Shipping DECIMAL(10,2);
    IF @OrderTotal > 100 SET @Shipping = 0;
    ELSE IF @OrderTotal BETWEEN 50 AND 99 SET @Shipping = 5.99;
    ELSE SET @Shipping = 12.99;
    RETURN @Shipping;
END;
GO


-- TASK 10: Product Category Function (Inline TVF)
IF OBJECT_ID('GetProductsByPriceRange', 'IF') IS NOT NULL DROP FUNCTION GetProductsByPriceRange;
GO
CREATE FUNCTION GetProductsByPriceRange(@MinPrice DECIMAL(10,2), @MaxPrice DECIMAL(10,2))
RETURNS TABLE
AS
RETURN
(
    SELECT ProductName, ListPrice, BrandID, CategoryID
    FROM Product
    WHERE ListPrice BETWEEN @MinPrice AND @MaxPrice
);
GO

-- TASK 11: Customer Sales Summary Function (Multi-statement TVF)
IF OBJECT_ID('GetCustomerYearlySummary', 'TF') IS NOT NULL DROP FUNCTION GetCustomerYearlySummary;
GO
CREATE FUNCTION GetCustomerYearlySummary(@CustomerID INT)
RETURNS @Result TABLE(
    Year INT,
    TotalOrders INT,
    TotalSpent DECIMAL(10,2),
    AvgOrderValue DECIMAL(10,2)
)
AS
BEGIN
    INSERT INTO @Result(Year, TotalOrders, TotalSpent, AvgOrderValue)
    SELECT YEAR(o.OrderDate), COUNT(DISTINCT o.OrderID),
           SUM(oi.Quantity * oi.Price),
           AVG(oi.Quantity * oi.Price)
    FROM [Order] o
    JOIN OrderItem oi ON o.OrderID = oi.OrderID
    WHERE o.CustomerID = @CustomerID
    GROUP BY YEAR(o.OrderDate);

    RETURN;
END;
GO


-- TASK 12: Discount Calculation Function
IF OBJECT_ID('CalculateBulkDiscount', 'FN') IS NOT NULL DROP FUNCTION CalculateBulkDiscount;
GO
CREATE FUNCTION CalculateBulkDiscount(@Quantity INT)
RETURNS INT
AS
BEGIN
    DECLARE @Discount INT;
    IF @Quantity BETWEEN 1 AND 2 SET @Discount = 0;
    ELSE IF @Quantity BETWEEN 3 AND 5 SET @Discount = 5;
    ELSE IF @Quantity BETWEEN 6 AND 9 SET @Discount = 10;
    ELSE SET @Discount = 15;
    RETURN @Discount;
END;
GO

-- TASK 13: Customer Order History Procedure
IF OBJECT_ID('sp_GetCustomerOrderHistory', 'P') IS NOT NULL DROP PROCEDURE sp_GetCustomerOrderHistory;
GO
CREATE PROCEDURE sp_GetCustomerOrderHistory
    @CustomerID INT,
    @StartDate DATE = NULL,
    @EndDate DATE = NULL
AS
BEGIN
    SELECT o.OrderID, o.OrderDate, SUM(oi.Quantity * oi.Price) AS OrderTotal
    FROM [Order] o
    JOIN OrderItem oi ON o.OrderID = oi.OrderID
    WHERE o.CustomerID = @CustomerID
    AND (@StartDate IS NULL OR o.OrderDate >= @StartDate)
    AND (@EndDate IS NULL OR o.OrderDate <= @EndDate)
    GROUP BY o.OrderID, o.OrderDate
    ORDER BY o.OrderDate;
END;
GO

-- TASK 14: Inventory Restock Procedure
IF OBJECT_ID('sp_RestockProduct', 'P') IS NOT NULL DROP PROCEDURE sp_RestockProduct;
GO
CREATE PROCEDURE sp_RestockProduct
    @StoreID INT,
    @ProductID INT,
    @RestockQty INT,
    @OldQty INT OUTPUT,
    @NewQty INT OUTPUT,
    @Status NVARCHAR(50) OUTPUT
AS
BEGIN
    SELECT @OldQty = Quantity FROM Inventory WHERE StoreID = @StoreID AND ProductID = @ProductID;
    IF @OldQty IS NULL
    BEGIN
        SET @Status = 'Product not found';
        RETURN;
    END

    UPDATE Inventory
    SET Quantity = Quantity + @RestockQty
    WHERE StoreID = @StoreID AND ProductID = @ProductID;

    SELECT @NewQty = Quantity FROM Inventory WHERE StoreID = @StoreID AND ProductID = @ProductID;
    SET @Status = 'Success';
END;
GO

-- TASK 15: Order Processing Procedure
IF OBJECT_ID('sp_ProcessNewOrder', 'P') IS NOT NULL DROP PROCEDURE sp_ProcessNewOrder;
GO
CREATE PROCEDURE sp_ProcessNewOrder
    @CustomerID INT,
    @ProductID INT,
    @Quantity INT,
    @StoreID INT
AS
BEGIN
    BEGIN TRY
        BEGIN TRANSACTION;

        DECLARE @Price DECIMAL(10,2);
        SELECT @Price = ListPrice FROM Product WHERE ProductID = @ProductID;

        INSERT INTO [Order](CustomerID, StaffID, OrderDate)
        VALUES (@CustomerID, NULL, GETDATE());

        DECLARE @OrderID INT = SCOPE_IDENTITY();

        INSERT INTO OrderItem(OrderID, ProductID, Quantity, Price)
        VALUES (@OrderID, @ProductID, @Quantity, @Price);

        UPDATE Inventory
        SET Quantity = Quantity - @Quantity
        WHERE ProductID = @ProductID AND StoreID = @StoreID;

        COMMIT TRANSACTION;
    END TRY
    BEGIN CATCH
        ROLLBACK TRANSACTION;
        THROW;
    END CATCH
END;
GO

-- TASK 16: Dynamic Product Search Procedure
IF OBJECT_ID('sp_SearchProducts', 'P') IS NOT NULL DROP PROCEDURE sp_SearchProducts;
GO
CREATE PROCEDURE sp_SearchProducts
    @ProductName NVARCHAR(50) = NULL,
    @CategoryID INT = NULL,
    @MinPrice DECIMAL(10,2) = NULL,
    @MaxPrice DECIMAL(10,2) = NULL,
    @SortColumn NVARCHAR(50) = 'ProductName'
AS
BEGIN
    DECLARE @SQL NVARCHAR(MAX) = 'SELECT * FROM Product WHERE 1=1';

    IF @ProductName IS NOT NULL
        SET @SQL += ' AND ProductName LIKE ''%' + @ProductName + '%''';
    IF @CategoryID IS NOT NULL
        SET @SQL += ' AND CategoryID = ' + CAST(@CategoryID AS NVARCHAR);
    IF @MinPrice IS NOT NULL
        SET @SQL += ' AND ListPrice >= ' + CAST(@MinPrice AS NVARCHAR);
    IF @MaxPrice IS NOT NULL
        SET @SQL += ' AND ListPrice <= ' + CAST(@MaxPrice AS NVARCHAR);

    SET @SQL += ' ORDER BY ' + @SortColumn;

    EXEC(@SQL);
END;
GO

-- TASK 17: Staff Bonus Calculation System
DECLARE @QuarterStart DATE = '2025-10-01', @QuarterEnd DATE = '2025-12-31';
DECLARE @BonusRate DECIMAL(5,2);

SELECT StaffID, SUM(oi.Quantity*oi.Price) AS TotalSales,
CASE 
    WHEN SUM(oi.Quantity*oi.Price) >= 5000 THEN 0.10
    WHEN SUM(oi.Quantity*oi.Price) BETWEEN 3000 AND 4999 THEN 0.05
    ELSE 0.02
END AS BonusRate,
SUM(oi.Quantity*oi.Price) * 
CASE 
    WHEN SUM(oi.Quantity*oi.Price) >= 5000 THEN 0.10
    WHEN SUM(oi.Quantity*oi.Price) BETWEEN 3000 AND 4999 THEN 0.05
    ELSE 0.02
END AS BonusAmount
FROM [Order] o
JOIN OrderItem oi ON o.OrderID = oi.OrderID
WHERE o.OrderDate BETWEEN @QuarterStart AND @QuarterEnd
GROUP BY StaffID;
GO

-- TASK 18: Smart Inventory Management
SELECT i.ProductID, i.Quantity,
CASE 
    WHEN i.Quantity < 5 AND p.CategoryID = 1 THEN 'Reorder 20'
    WHEN i.Quantity < 5 AND p.CategoryID = 2 THEN 'Reorder 10'
    WHEN i.Quantity BETWEEN 5 AND 10 THEN 'Reorder 5'
    ELSE 'Sufficient Stock'
END AS Action
FROM Inventory i
JOIN Product p ON i.ProductID = p.ProductID;
GO

-- TASK 19: Customer Loyalty Tier Assignment
SELECT c.CustomerID, ISNULL(SUM(oi.Quantity*oi.Price),0) AS TotalSpent,
CASE 
    WHEN ISNULL(SUM(oi.Quantity*oi.Price),0) > 5000 THEN 'Platinum'
    WHEN ISNULL(SUM(oi.Quantity*oi.Price),0) BETWEEN 3000 AND 5000 THEN 'Gold'
    WHEN ISNULL(SUM(oi.Quantity*oi.Price),0) BETWEEN 1000 AND 2999 THEN 'Silver'
    ELSE 'Bronze'
END AS LoyaltyTier
FROM Customer c
LEFT JOIN [Order] o ON c.CustomerID = o.CustomerID
LEFT JOIN OrderItem oi ON o.OrderID = oi.OrderID
GROUP BY c.CustomerID;
GO

-- TASK 20: Product Lifecycle Management
IF OBJECT_ID('sp_DiscontinueProduct', 'P') IS NOT NULL DROP PROCEDURE sp_DiscontinueProduct;
GO
CREATE PROCEDURE sp_DiscontinueProduct
    @ProductID INT,
    @ReplacementProductID INT = NULL
AS
BEGIN
    BEGIN TRY
        BEGIN TRANSACTION;

        IF EXISTS(SELECT 1 FROM OrderItem WHERE ProductID = @ProductID)
        BEGIN
            IF @ReplacementProductID IS NOT NULL
            BEGIN
                UPDATE OrderItem
                SET ProductID = @ReplacementProductID
                WHERE ProductID = @ProductID;
            END
            ELSE
            BEGIN
                PRINT 'Cannot discontinue, pending orders exist';
                ROLLBACK TRANSACTION;
                RETURN;
            END
        END

        DELETE FROM Inventory WHERE ProductID = @ProductID;
        DELETE FROM Product WHERE ProductID = @ProductID;

        PRINT 'Product discontinued successfully';
        COMMIT TRANSACTION;
    END TRY
    BEGIN CATCH
        ROLLBACK TRANSACTION;
        THROW;
    END CATCH
END;
GO
