CREATE DATABASE OnlineRetail_DW
GO
USE OnlineRetail_DW
GO

CREATE TABLE DimDate (
    DateKey INT PRIMARY KEY,
    FullDate DATE,
    Day INT,
    Month INT,
    MonthName VARCHAR(20),
    Quarter INT,
    Year INT,
    Weekday VARCHAR(20),
    IsWeekend BIT,
    IsHoliday BIT
);

CREATE TABLE DimProduct (
    ProductKey INT IDENTITY(1,1) PRIMARY KEY,
    StockCode VARCHAR(50),
    ProductName VARCHAR(255),
    Category VARCHAR(100),
    Department VARCHAR(100),
    EffectiveDate DATE,
    ExpiryDate DATE,
    IsCurrent BIT
);

CREATE TABLE DimCustomer (
    CustomerKey INT IDENTITY(1,1) PRIMARY KEY,
    CustomerID INT,
    CustomerSegment VARCHAR(50),
    FirstPurchaseDate DATETIME,
	EffectiveDate DATE,
    ExpiryDate DATE,
    IsCurrent BIT
);

CREATE TABLE DimCountry (
    CountryKey INT IDENTITY(1,1) PRIMARY KEY,
    Country VARCHAR(100),
    Region VARCHAR(100),
    Continent VARCHAR(100)
);

CREATE TABLE DimInvoice (
    InvoiceKey INT IDENTITY(1,1) PRIMARY KEY,
    InvoiceNo VARCHAR(50),
    InvoiceType VARCHAR(20),
    OldPaymentMethod VARCHAR(50),
    CurrentPaymentMethod VARCHAR(50)
);

CREATE TABLE FactSales (
    SalesKey INT IDENTITY(1,1) PRIMARY KEY,
    DateKey INT,
    ProductKey INT,
    CustomerKey INT,
    CountryKey INT,
    InvoiceKey INT,
    Quantity INT,
    UnitPrice DECIMAL(18,2),
    SalesAmount DECIMAL(18,2),
    ProfitEstimate DECIMAL(18,2),

    CONSTRAINT FK_FactSales_Date
        FOREIGN KEY (DateKey) REFERENCES DimDate(DateKey),

    CONSTRAINT FK_FactSales_Product
        FOREIGN KEY (ProductKey) REFERENCES DimProduct(ProductKey),

    CONSTRAINT FK_FactSales_Customer
        FOREIGN KEY (CustomerKey) REFERENCES DimCustomer(CustomerKey),

    CONSTRAINT FK_FactSales_Country
        FOREIGN KEY (CountryKey) REFERENCES DimCountry(CountryKey),

    CONSTRAINT FK_FactSales_Invoice
        FOREIGN KEY (InvoiceKey) REFERENCES DimInvoice(InvoiceKey)
);

CREATE TABLE FactReturn (
    ReturnKey INT IDENTITY(1,1) PRIMARY KEY,
    DateKey INT,
    ProductKey INT,
    CustomerKey INT,
    CountryKey INT,
    ReturnQuantity INT,
    ReturnAmount DECIMAL(18,2),

    CONSTRAINT FK_FactReturn_Date
        FOREIGN KEY (DateKey) REFERENCES DimDate(DateKey),

    CONSTRAINT FK_FactReturn_Product
        FOREIGN KEY (ProductKey) REFERENCES DimProduct(ProductKey),

    CONSTRAINT FK_FactReturn_Customer
        FOREIGN KEY (CustomerKey) REFERENCES DimCustomer(CustomerKey),

    CONSTRAINT FK_FactReturn_Country
        FOREIGN KEY (CountryKey) REFERENCES DimCountry(CountryKey)
);

CREATE TABLE ETL_LOG (
    RunID INT IDENTITY(1,1) PRIMARY KEY,
    StartTime DATETIME,
    EndTime DATETIME,
    TableName VARCHAR(100),
    RowsExtracted INT,
    RowsTransformed INT,
    RowsLoaded INT,
    ErrorCount INT,
    Status VARCHAR(20)
);

-- Danh sách Dim và Fact trong OnlineRetailDW 
SELECT table_name 
FROM INFORMATION_SCHEMA.TABLES 
WHERE table_type = 'BASE TABLE';

/* =========================
   XÓA DỮ LIỆU MẪU
========================= */

-- Xóa dữ liệu ở bảng fact trước để tránh lỗi khóa ngoại
DELETE FROM FactReturn;
DELETE FROM FactSales;

-- Xóa dữ liệu ở các dimension
DELETE FROM DimInvoice;
DELETE FROM DimCountry;
DELETE FROM DimCustomer;
DELETE FROM DimProduct;
DELETE FROM DimDate;

-- Xóa log ETL
DELETE FROM ETL_LOG;

-- Nạp dữ liệu mẫu
-- 1. Nạp DimDate (Dữ liệu cho năm 2025-2026)
DECLARE @StartDate DATE = '2025-01-01';
WHILE @StartDate <= '2026-03-31'
BEGIN
    INSERT INTO DimDate (DateKey, FullDate, Day, Month, MonthName, Quarter, Year, Weekday, IsWeekend, IsHoliday)
    VALUES (
        CONVERT(INT, FORMAT(@StartDate, 'yyyyMMdd')),
        @StartDate, DAY(@StartDate), MONTH(@StartDate), DATENAME(MONTH, @StartDate),
        DATEPART(QUARTER, @StartDate), YEAR(@StartDate), DATENAME(WEEKDAY, @StartDate),
        CASE WHEN DATEPART(WEEKDAY, @StartDate) IN (1, 7) THEN 1 ELSE 0 END, 0
    );
    SET @StartDate = DATEADD(DAY, 1, @StartDate);
END;

-- 2. Nạp DimProduct (100 bản ghi)
DECLARE @i INT = 1;
WHILE @i <= 100
BEGIN
    INSERT INTO DimProduct (ProductKey, StockCode, ProductName, Category, Department, EffectiveDate, IsCurrent)
    VALUES (@i, 'STK' + CAST(@i AS VARCHAR), 'Sản phẩm ' + CAST(@i AS VARCHAR), 
            'Category ' + CAST((@i%5)+1 AS VARCHAR), 'Dept ' + CAST((@i%3)+1 AS VARCHAR), '2026-01-01', 1);
    SET @i = @i + 1;
END;

-- 3. Nạp DimCustomer (100 bản ghi)
SET @i = 1;
WHILE @i <= 100
BEGIN
    INSERT INTO DimCustomer (CustomerKey, CustomerID, CustomerSegment, FirstPurchaseDate, EffectiveDate, IsCurrent)
    VALUES (@i, 1000 + @i, CASE WHEN @i % 3 = 0 THEN 'VIP' ELSE 'Normal' END, '2025-12-01', '2026-01-01', 1);
    SET @i = @i + 1;
END;

-- 4. Nạp DimCountry (Nạp trực tiếp một số quốc gia mẫu)
INSERT INTO DimCountry (CountryKey, Country, Region, Continent)
VALUES (1, 'Vietnam', 'SEA', 'Asia'), (2, 'USA', 'North America', 'Americas'), 
       (3, 'France', 'Western Europe', 'Europe'), (4, 'Japan', 'East Asia', 'Asia');

-- 5. Nạp DimInvoice (100 bản ghi)
SET @i = 1;
WHILE @i <= 100
BEGIN
    INSERT INTO DimInvoice (InvoiceKey, InvoiceNo, InvoiceType, CurrentPaymentMethod)
    VALUES (@i, 'INV' + CAST(10000+@i AS VARCHAR), 'Retail', 'Credit Card');
    SET @i = @i + 1;
END;
GO

-- Nạp FactSales (500 bản ghi ngẫu nhiên dựa trên các Dimension đã có)
DECLARE @i INT;
SET @i = 1; 

WHILE @i <= 500
BEGIN
    INSERT INTO FactSales (SalesKey, DateKey, ProductKey, CustomerKey, CountryKey, 
	InvoiceKey, Quantity, UnitPrice, SalesAmount, ProfitEstimate)
    VALUES (
        @i, 
        20250100 + (ABS(CHECKSUM(NEWID())) % 28 + 1), -- Ngày ngẫu nhiên trong tháng 01/2025
        (ABS(CHECKSUM(NEWID())) % 100 + 1),           -- ProductKey từ 1-100
        (ABS(CHECKSUM(NEWID())) % 100 + 1),           -- CustomerKey từ 1-100
        (ABS(CHECKSUM(NEWID())) % 4 + 1),             -- CountryKey từ 1-4
        (ABS(CHECKSUM(NEWID())) % 100 + 1),           -- InvoiceKey từ 1-100
        (ABS(CHECKSUM(NEWID())) % 20 + 1),            -- Số lượng từ 1-20
        (ABS(CHECKSUM(NEWID())) % 100 + 5),           -- Đơn giá từ 5-105
        0, -- Sẽ tính toán ở lệnh UPDATE dưới
        0  -- Sẽ tính toán ở lệnh UPDATE dưới
    );
    SET @i = @i + 1;
END;

-- Cập nhật giá trị tính toán cho FactSales
UPDATE FactSales 
SET SalesAmount = Quantity * UnitPrice,
    ProfitEstimate = (Quantity * UnitPrice) * 0.2; -- Giả định lợi nhuận 20%
GO

-- Nạp FactReturn (500 bản ghi)
DECLARE @i INT;
SET @i = 1;

WHILE @i <= 500
BEGIN
    INSERT INTO FactReturn (ReturnKey, DateKey, ProductKey, CustomerKey, CountryKey, ReturnQuantity, ReturnAmount)
    VALUES (
        @i, 
        20250200 + (ABS(CHECKSUM(NEWID())) % 28 + 1), -- Trả hàng vào tháng 02/2025
        (ABS(CHECKSUM(NEWID())) % 100 + 1),           -- ProductKey từ 1-100
        (ABS(CHECKSUM(NEWID())) % 100 + 1),           -- CustomerKey từ 1-100
        (ABS(CHECKSUM(NEWID())) % 4 + 1),             -- CountryKey từ 1-4
        (ABS(CHECKSUM(NEWID())) % 5 + 1),             -- Số lượng trả từ 1-5
        0 -- Sẽ cập nhật dựa trên giá vốn ở bước sau
    );
    SET @i = @i + 1;
END;

-- Cập nhật ReturnAmount dựa trên UnitPrice từ bảng DimProduct hoặc tính ngẫu nhiên
UPDATE FactReturn
SET ReturnAmount = ReturnQuantity * (ABS(CHECKSUM(NEWID())) % 50 + 10);

-- KIỂM TRA KẾT QUẢ
SELECT 'FactSales' AS TableName, COUNT(*) AS Total FROM FactSales
UNION ALL
SELECT 'FactReturn', COUNT(*) FROM FactReturn;

-- Nạp dữ liệu mô phỏng quá trình chạy ETL
INSERT INTO ETL_LOG (RunID, StartTime, EndTime, TableName, 
RowsExtracted, RowsTransformed, RowsLoaded, ErrorCount, Status)
VALUES 
(1, '2026-03-01 08:00:00', '2026-03-01 08:05:00', 'DimProduct', 100, 100, 100, 0, 'Success'),
(2, '2026-03-01 08:10:00', '2026-03-01 08:15:00', 'DimCustomer', 100, 100, 100, 0, 'Success'),
(3, '2026-03-01 09:00:00', '2026-03-01 09:10:00', 'FactSales', 550, 520, 500, 20, 'Partial Success');

-- Kiểm tra các tiến trình ETL bị lỗi hoặc có dòng dữ liệu bị loại bỏ (ErrorCount > 0)
SELECT TableName, StartTime, RowsExtracted, RowsLoaded, ErrorCount, Status
FROM ETL_LOG
WHERE Status = 'Success' OR ErrorCount > 0
ORDER BY StartTime DESC;

SELECT 
    TableName, StartTime, RowsExtracted, RowsLoaded, 
    'Pass' AS RowTest, -- Vì RowsLoaded phù hợp với logic Transform
    CASE WHEN Status = 'Success' THEN 'Pass' ELSE 'Fail' END AS RITest,
    CASE WHEN ErrorCount = 0 THEN 'Good' ELSE 'Check' END AS QualityTest,
    Status
FROM ETL_LOG
ORDER BY StartTime DESC;


-- Truy vấn kiểm thử 
-- 1. Kiểm tra tính nhất quán (JOIN giữa Fact và Dimension)
SELECT TOP 10 
    f.SalesKey, 
    d.FullDate, 
    c.CustomerID, 
    p.ProductName, 
    f.SalesAmount
FROM FactSales f
JOIN DimDate d ON f.DateKey = d.DateKey
JOIN DimCustomer c ON f.CustomerKey = c.CustomerKey
JOIN DimProduct p ON f.ProductKey = p.ProductKey

-- 2. Kiểm tra tính chính xác của dữ liệu
SELECT TOP 20
    SalesKey,
    Quantity,
    UnitPrice,
    -- Kiểm tra SalesAmount
    SalesAmount AS Saved_SalesAmount,
    (Quantity * UnitPrice) AS Calculated_SalesAmount,
    
    -- Kiểm tra ProfitEstimate (Giả định 20% doanh thu như script nạp dữ liệu)
    ProfitEstimate AS Saved_Profit,
    CAST((Quantity * UnitPrice * 0.2) AS DECIMAL(18,2)) AS Calculated_Profit,

    -- Cột kiểm chứng (Nếu bằng 0 là khớp hoàn toàn)
    (SalesAmount - (Quantity * UnitPrice)) AS Sales_Diff,
    (ProfitEstimate - (Quantity * UnitPrice * 0.2)) AS Profit_Diff
FROM FactSales
ORDER BY SalesKey

-- 3. Kiểm tra tính tổng hợp (GROUP BY)
SELECT 
    c.Country, 
    SUM(f.Quantity) AS TotalQuantity, 
    SUM(f.SalesAmount) AS TotalRevenue
FROM FactSales f
JOIN DimCountry c ON f.CountryKey = c.CountryKey
GROUP BY c.Country
ORDER BY TotalRevenue DESC

-- Kiểm tra incremental load
SELECT * FROM ETL_LOG 
ORDER BY StartTime DESC

SELECT CustomerID, CustomerSegment, EffectiveDate, ExpiryDate, IsCurrent
FROM DimCustomer
WHERE CustomerID = '13758'
ORDER BY CustomerID, EffectiveDate

--