USE master;
GO

-- 1. Tạo Database Staging
IF NOT EXISTS (SELECT * FROM sys.databases WHERE name = 'OnlineRetailDWStage')
BEGIN
    CREATE DATABASE OnlineRetailDWStage;
END
GO

USE OnlineRetailDWStage;
GO

-- 2. Bảng chứa dữ liệu giao dịch từ file .csv
IF OBJECT_ID('Sales_Stage', 'U') IS NOT NULL DROP TABLE Sales_Stage;
CREATE TABLE Sales_Stage (
    InvoiceNo NVARCHAR(50),
    StockCode NVARCHAR(50),
    ProductName NVARCHAR(255),
    Quantity INT,
    InvoiceDate DATETIME,
    UnitPrice FLOAT,
    CustomerID FLOAT, -- Để FLOAT vì dữ liệu thô có thể chứa NULL
    Country NVARCHAR(100),
    -- Các cột tính toán thêm trong quá trình Transform
    SalesAmount FLOAT, 
    IsReturn BIT,
    ProfitEstimate FLOAT 
);

-- 3. Bảng chứa dữ liệu phân vùng từ file .xlsx
IF OBJECT_ID('CountryMap_Stage', 'U') IS NOT NULL DROP TABLE CountryMap_Stage;
CREATE TABLE CountryMap_Stage (
    Country NVARCHAR(100),
    Region NVARCHAR(100),
    Continent NVARCHAR(100)
);

-- 4. Bảng Log để theo dõi tiến trình 
IF OBJECT_ID('ETL_LOG_Stage', 'U') IS NOT NULL DROP TABLE ETL_LOG_Stage;
CREATE TABLE ETL_LOG_Stage (
    RunID BIGINT PRIMARY KEY,
    TableName NVARCHAR(50),
    StartTime DATETIME,
    EndTime DATETIME,
    RowsLoaded INT,
    Status NVARCHAR(50)
);