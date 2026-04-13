USE OnlineRetailDWStage;
GO

-----------------------------------------------------------
-- 1. TRANSFORM CHO BẢNG SALES (FACT)
-----------------------------------------------------------
-- Thêm các cột phát sinh vào bảng Stage nếu chưa có
-- Nếu bảng Sales_Stage chưa có các cột này, ta sẽ thêm vào
IF NOT EXISTS (SELECT * FROM sys.columns WHERE object_id = OBJECT_ID('Sales_Stage') AND name = 'DateKey')
    ALTER TABLE Sales_Stage ADD DateKey INT;

IF NOT EXISTS (SELECT * FROM sys.columns WHERE object_id = OBJECT_ID('Sales_Stage') AND name = 'SalesAmount')
    ALTER TABLE Sales_Stage ADD SalesAmount FLOAT;

IF NOT EXISTS (SELECT * FROM sys.columns WHERE object_id = OBJECT_ID('Sales_Stage') AND name = 'ProfitEstimate')
    ALTER TABLE Sales_Stage ADD ProfitEstimate FLOAT;

IF NOT EXISTS (SELECT * FROM sys.columns WHERE object_id = OBJECT_ID('Sales_Stage') AND name = 'IsReturn')
    ALTER TABLE Sales_Stage ADD IsReturn BIT;
GO

-- Thực hiện làm sạch và tính toán logic
UPDATE Sales_Stage
SET 
    -- 1. Làm sạch chuỗi
    Country = UPPER(LTRIM(RTRIM(Country))),
    
    -- 2. Ép kiểu và xử lý NULL CustomerID (dropna trong python)
    -- Nếu CustomerID là NULL, ta có thể đánh dấu để xóa hoặc gán giá trị mặc định
    CustomerID = ISNULL(CustomerID, 0),

    -- 3. Tính toán cột phát sinh (Derived Fields)
    SalesAmount = Quantity * UnitPrice,
    IsReturn = CASE WHEN InvoiceNo LIKE 'C%' THEN 1 ELSE 0 END,
    ProfitEstimate = (Quantity * UnitPrice) * 0.2, -- Giả định biên lợi nhuận 20%
    
    -- 4. Tạo DateKey (YYYMMDD) để Mapping sau này
    DateKey = CONVERT(INT, CONVERT(VARCHAR(8), InvoiceDate, 112))
WHERE InvoiceNo IS NOT NULL;

-- Loại bỏ các dòng bị NULL CustomerID (tương đương df.dropna(subset=['CustomerID']))
DELETE FROM Sales_Stage WHERE CustomerID = 0;

-- Loại bỏ trùng lặp (tương đương drop_duplicates())
WITH CTE AS (
    SELECT *, ROW_NUMBER() OVER (PARTITION BY InvoiceNo, StockCode, CustomerID, InvoiceDate ORDER BY InvoiceNo) as rn
    FROM Sales_Stage
)
DELETE FROM CTE WHERE rn > 1;
GO

-----------------------------------------------------------
-- 2. TRANSFORM CHO DIMPRODUCT (SCD TYPE 2 PREP)
-----------------------------------------------------------
IF OBJECT_ID('Product_Stage', 'U') IS NOT NULL DROP TABLE Product_Stage;

SELECT DISTINCT 
    StockCode, 
    ProductName,
    'Retail' AS Category,
    'General' AS Department,
    GETDATE() AS EffectiveDate,
    CAST(NULL AS DATETIME) AS ExpiryDate,
    1 AS IsCurrent
INTO Product_Stage
FROM Sales_Stage;
GO

-----------------------------------------------------------
-- 3. TRANSFORM CHO DIMCUSTOMER (SCD TYPE 2 PREP)
-----------------------------------------------------------
IF OBJECT_ID('Customer_Stage', 'U') IS NOT NULL DROP TABLE Customer_Stage;

-- Tính FirstPurchaseDate (tương đương groupby transform min trong python)
SELECT 
    CustomerID,
    'Standard' AS CustomerSegment,
    MIN(InvoiceDate) AS FirstPurchaseDate,
    GETDATE() AS EffectiveDate,
    CAST(NULL AS DATETIME) AS ExpiryDate,
    1 AS IsCurrent
INTO Customer_Stage
FROM Sales_Stage
GROUP BY CustomerID;
GO

-----------------------------------------------------------
-- 4. TRANSFORM CHO DIMINVOICE (SCD TYPE 3 PREP)
-----------------------------------------------------------
IF OBJECT_ID('Invoice_Stage', 'U') IS NOT NULL DROP TABLE Invoice_Stage;

SELECT DISTINCT 
    InvoiceNo,
    CASE WHEN InvoiceNo LIKE 'C%' THEN 'Return' ELSE 'Sale' END AS InvoiceType,
    CAST(NULL AS NVARCHAR(50)) AS OldPaymentMethod,
    CAST('Credit Card' AS NVARCHAR(50)) AS CurrentPaymentMethod
INTO Invoice_Stage
FROM Sales_Stage;
GO

-----------------------------------------------------------
-- 5. TRANSFORM CHO DIMDATE
-----------------------------------------------------------
-- Tạo bảng DimDate tạm thời từ dữ liệu thực tế trong Sales
IF OBJECT_ID('Date_Stage', 'U') IS NOT NULL DROP TABLE Date_Stage;

SELECT DISTINCT
    CONVERT(INT, CONVERT(VARCHAR(8), InvoiceDate, 112)) AS DateKey,
    CAST(InvoiceDate AS DATE) AS FullDate,
    DAY(InvoiceDate) AS [Day],
    MONTH(InvoiceDate) AS [Month],
    DATENAME(MONTH, InvoiceDate) AS MonthName,
    DATEPART(QUARTER, InvoiceDate) AS [Quarter],
    YEAR(InvoiceDate) AS [Year],
    DATENAME(WEEKDAY, InvoiceDate) AS [Weekday],
    CASE WHEN DATEPART(WEEKDAY, InvoiceDate) IN (1, 7) THEN 1 ELSE 0 END AS IsWeekend,
    0 AS IsHoliday
INTO Date_Stage
FROM Sales_Stage;
GO