/* ============================================================
   Serverless SQL: CETAS external tables in Gold (materialise views)

   Purpose
   -------
   - Ensure the `gold` schema exists
   - Create External Tables in the Gold container using CETAS:
       CREATE EXTERNAL TABLE ... AS SELECT ...
   - Materialise each OPENROWSET-backed Gold view into Parquet
     under the Gold external data source location

   Execution Notes
   ---------------
   - Run this in Synapse *Built-in* (serverless) SQL.
   - Prerequisites (expected to already exist):
       * External data source  : [source_gold]
       * External file format  : [format_parquet]
       * Gold views            : [gold].[*] (calendar, customers, etc.)
   - CETAS requires the target LOCATION folder to be EMPTY or NON-EXISTENT.
     If you re-run this script, delete the corresponding folders in the
     Gold container first.

   Idempotency Behaviour
   ---------------------
   - The script drops the external table objects if they exist.
   - It does NOT delete underlying files in ADLS:
       * you must manually clear the target folders for CETAS reruns.
   ============================================================ */

-- ============================================================
-- 1) Ensure correct database context
-- ============================================================

USE [adventureworks_serverless];
GO


-- ============================================================
-- 2) Ensure Gold schema exists
-- ============================================================

IF SCHEMA_ID('gold') IS NULL
BEGIN
    EXEC ('CREATE SCHEMA [gold]');
END
GO


/* ============================================================
   3) CETAS: create external tables under [gold]

   Pattern
   -------
   For each dataset:
     - Drop external table if it exists
     - Create external table with:
         LOCATION     = '<folder name>'
         DATA_SOURCE  = [source_gold]
         FILE_FORMAT  = [format_parquet]
       AS
         SELECT * FROM [gold].[<view>];

   IMPORTANT
   ---------
   - CETAS will fail if LOCATION already contains files.
   - Clearing the folder is a storage operation, not handled here.
   ============================================================ */


-- ============================================================
-- gold.ext_calendar  (source: gold.calendar)
-- ============================================================

IF EXISTS (
    SELECT 1
    FROM sys.external_tables
    WHERE name = 'ext_calendar'
      AND schema_id = SCHEMA_ID('gold')
)
BEGIN
    DROP EXTERNAL TABLE [gold].[ext_calendar];
END
GO

CREATE EXTERNAL TABLE [gold].[ext_calendar]
WITH (
    LOCATION = 'ext_calendar',
    DATA_SOURCE = [source_gold],
    FILE_FORMAT = [format_parquet]
)
AS
SELECT *
FROM [gold].[calendar];
GO


-- ============================================================
-- gold.ext_customers  (source: gold.customers)
-- ============================================================

IF EXISTS (
    SELECT 1
    FROM sys.external_tables
    WHERE name = 'ext_customers'
      AND schema_id = SCHEMA_ID('gold')
)
BEGIN
    DROP EXTERNAL TABLE [gold].[ext_customers];
END
GO

CREATE EXTERNAL TABLE [gold].[ext_customers]
WITH (
    LOCATION = 'ext_customers',
    DATA_SOURCE = [source_gold],
    FILE_FORMAT = [format_parquet]
)
AS
SELECT *
FROM [gold].[customers];
GO


-- ============================================================
-- gold.ext_product_categories  (source: gold.product_categories)
-- ============================================================

IF EXISTS (
    SELECT 1
    FROM sys.external_tables
    WHERE name = 'ext_product_categories'
      AND schema_id = SCHEMA_ID('gold')
)
BEGIN
    DROP EXTERNAL TABLE [gold].[ext_product_categories];
END
GO

CREATE EXTERNAL TABLE [gold].[ext_product_categories]
WITH (
    LOCATION = 'ext_product_categories',
    DATA_SOURCE = [source_gold],
    FILE_FORMAT = [format_parquet]
)
AS
SELECT *
FROM [gold].[product_categories];
GO


-- ============================================================
-- gold.ext_product_subcategories  (source: gold.product_subcategories)
-- ============================================================

IF EXISTS (
    SELECT 1
    FROM sys.external_tables
    WHERE name = 'ext_product_subcategories'
      AND schema_id = SCHEMA_ID('gold')
)
BEGIN
    DROP EXTERNAL TABLE [gold].[ext_product_subcategories];
END
GO

CREATE EXTERNAL TABLE [gold].[ext_product_subcategories]
WITH (
    LOCATION = 'ext_product_subcategories',
    DATA_SOURCE = [source_gold],
    FILE_FORMAT = [format_parquet]
)
AS
SELECT *
FROM [gold].[product_subcategories];
GO


-- ============================================================
-- gold.ext_products  (source: gold.products)
-- ============================================================

IF EXISTS (
    SELECT 1
    FROM sys.external_tables
    WHERE name = 'ext_products'
      AND schema_id = SCHEMA_ID('gold')
)
BEGIN
    DROP EXTERNAL TABLE [gold].[ext_products];
END
GO

CREATE EXTERNAL TABLE [gold].[ext_products]
WITH (
    LOCATION = 'ext_products',
    DATA_SOURCE = [source_gold],
    FILE_FORMAT = [format_parquet]
)
AS
SELECT *
FROM [gold].[products];
GO


-- ============================================================
-- gold.ext_returns  (source: gold.returns)
-- ============================================================

IF EXISTS (
    SELECT 1
    FROM sys.external_tables
    WHERE name = 'ext_returns'
      AND schema_id = SCHEMA_ID('gold')
)
BEGIN
    DROP EXTERNAL TABLE [gold].[ext_returns];
END
GO

CREATE EXTERNAL TABLE [gold].[ext_returns]
WITH (
    LOCATION = 'ext_returns',
    DATA_SOURCE = [source_gold],
    FILE_FORMAT = [format_parquet]
)
AS
SELECT *
FROM [gold].[returns];
GO


-- ============================================================
-- gold.ext_sales_2015  (source: gold.sales_2015)
-- ============================================================

IF EXISTS (
    SELECT 1
    FROM sys.external_tables
    WHERE name = 'ext_sales_2015'
      AND schema_id = SCHEMA_ID('gold')
)
BEGIN
    DROP EXTERNAL TABLE [gold].[ext_sales_2015];
END
GO

CREATE EXTERNAL TABLE [gold].[ext_sales_2015]
WITH (
    LOCATION = 'ext_sales_2015',
    DATA_SOURCE = [source_gold],
    FILE_FORMAT = [format_parquet]
)
AS
SELECT *
FROM [gold].[sales_2015];
GO


-- ============================================================
-- gold.ext_sales_2016  (source: gold.sales_2016)
-- ============================================================

IF EXISTS (
    SELECT 1
    FROM sys.external_tables
    WHERE name = 'ext_sales_2016'
      AND schema_id = SCHEMA_ID('gold')
)
BEGIN
    DROP EXTERNAL TABLE [gold].[ext_sales_2016];
END
GO

CREATE EXTERNAL TABLE [gold].[ext_sales_2016]
WITH (
    LOCATION = 'ext_sales_2016',
    DATA_SOURCE = [source_gold],
    FILE_FORMAT = [format_parquet]
)
AS
SELECT *
FROM [gold].[sales_2016];
GO


-- ============================================================
-- gold.ext_sales_2017  (source: gold.sales_2017)
-- ============================================================

IF EXISTS (
    SELECT 1
    FROM sys.external_tables
    WHERE name = 'ext_sales_2017'
      AND schema_id = SCHEMA_ID('gold')
)
BEGIN
    DROP EXTERNAL TABLE [gold].[ext_sales_2017];
END
GO

CREATE EXTERNAL TABLE [gold].[ext_sales_2017]
WITH (
    LOCATION = 'ext_sales_2017',
    DATA_SOURCE = [source_gold],
    FILE_FORMAT = [format_parquet]
)
AS
SELECT *
FROM [gold].[sales_2017];
GO


-- ============================================================
-- gold.ext_territories  (source: gold.territories)
-- ============================================================

IF EXISTS (
    SELECT 1
    FROM sys.external_tables
    WHERE name = 'ext_territories'
      AND schema_id = SCHEMA_ID('gold')
)
BEGIN
    DROP EXTERNAL TABLE [gold].[ext_territories];
END
GO

CREATE EXTERNAL TABLE [gold].[ext_territories]
WITH (
    LOCATION = 'ext_territories',
    DATA_SOURCE = [source_gold],
    FILE_FORMAT = [format_parquet]
)
AS
SELECT *
FROM [gold].[territories];
GO
