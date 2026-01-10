/* ============================================================
   Serverless SQL: Gold schema + external views over Silver Parquet

   Purpose
   -------
   - Ensure the `gold` schema exists in the serverless database
   - Create/replace a set of Gold-layer views that expose Silver-layer
     Parquet datasets via OPENROWSET
   - Provide a convenient SQL surface area for downstream analytics

   Execution Notes
   ---------------
   - Run this in Synapse *Built-in* (serverless) SQL.
   - Views are defined over Parquet files stored in ADLS Gen2 using
     the HTTPS DFS endpoint.
   - `CREATE OR ALTER VIEW` makes this script idempotent and safe
     to re-run during iterative development.

   Assumptions
   -----------
   - The Silver Parquet data already exists at the referenced paths.
   - The current principal has permission to read from the storage account.
   ============================================================ */

-- ============================================================
-- 1) Ensure correct database context
-- ============================================================

USE [adventureworks_serverless];
GO


-- ============================================================
-- 2) Ensure Gold schema exists
--
-- Notes
-- -----
-- - SCHEMA_ID returns NULL if the schema does not exist
-- - CREATE SCHEMA must be executed via dynamic SQL inside IF
-- ============================================================

IF SCHEMA_ID('gold') IS NULL
BEGIN
    EXEC ('CREATE SCHEMA [gold]');
END
GO


/* ============================================================
   3) Gold views (Silver Parquet → OPENROWSET → VIEW)

   Pattern
   -------
   Each view follows the same pattern:

     CREATE OR ALTER VIEW [gold].[<name>] AS
     SELECT *
     FROM OPENROWSET(
         BULK '<https path>/*.parquet',
         FORMAT = 'PARQUET'
     ) AS rows;

   Notes
   -----
   - SELECT * is intentional: schema is inferred from Parquet metadata.
   - If schema evolves, the view will reflect the new schema on next read.
   ============================================================ */


-- ============================================================
-- gold.calendar
-- ============================================================

CREATE OR ALTER VIEW [gold].[calendar] AS
SELECT *
FROM OPENROWSET(
    BULK 'https://stadvworksabovegnat.dfs.core.windows.net/silver/calendar/AdventureWorks_Calendar.csv/*.parquet',
    FORMAT = 'PARQUET'
) AS rows;
GO


-- ============================================================
-- gold.customers
-- ============================================================

CREATE OR ALTER VIEW [gold].[customers] AS
SELECT *
FROM OPENROWSET(
    BULK 'https://stadvworksabovegnat.dfs.core.windows.net/silver/customers/AdventureWorks_Customers.csv/*.parquet',
    FORMAT = 'PARQUET'
) AS rows;
GO


-- ============================================================
-- gold.product_categories
-- ============================================================

CREATE OR ALTER VIEW [gold].[product_categories] AS
SELECT *
FROM OPENROWSET(
    BULK 'https://stadvworksabovegnat.dfs.core.windows.net/silver/product_categories/AdventureWorks_Product_Categories.csv/*.parquet',
    FORMAT = 'PARQUET'
) AS rows;
GO


-- ============================================================
-- gold.product_subcategories
-- ============================================================

CREATE OR ALTER VIEW [gold].[product_subcategories] AS
SELECT *
FROM OPENROWSET(
    BULK 'https://stadvworksabovegnat.dfs.core.windows.net/silver/product_subcategories/AdventureWorks_Product_Subcategories.csv/*.parquet',
    FORMAT = 'PARQUET'
) AS rows;
GO


-- ============================================================
-- gold.products
-- ============================================================

CREATE OR ALTER VIEW [gold].[products] AS
SELECT *
FROM OPENROWSET(
    BULK 'https://stadvworksabovegnat.dfs.core.windows.net/silver/products/AdventureWorks_Products.csv/*.parquet',
    FORMAT = 'PARQUET'
) AS rows;
GO


-- ============================================================
-- gold.returns
-- ============================================================

CREATE OR ALTER VIEW [gold].[returns] AS
SELECT *
FROM OPENROWSET(
    BULK 'https://stadvworksabovegnat.dfs.core.windows.net/silver/returns/AdventureWorks_Returns.csv/*.parquet',
    FORMAT = 'PARQUET'
) AS rows;
GO


-- ============================================================
-- gold.sales_2015
-- ============================================================

CREATE OR ALTER VIEW [gold].[sales_2015] AS
SELECT *
FROM OPENROWSET(
    BULK 'https://stadvworksabovegnat.dfs.core.windows.net/silver/sales/2015/AdventureWorks_Sales_2015.csv/*.parquet',
    FORMAT = 'PARQUET'
) AS rows;
GO


-- ============================================================
-- gold.sales_2016
-- ============================================================

CREATE OR ALTER VIEW [gold].[sales_2016] AS
SELECT *
FROM OPENROWSET(
    BULK 'https://stadvworksabovegnat.dfs.core.windows.net/silver/sales/2016/AdventureWorks_Sales_2016.csv/*.parquet',
    FORMAT = 'PARQUET'
) AS rows;
GO


-- ============================================================
-- gold.sales_2017
-- ============================================================

CREATE OR ALTER VIEW [gold].[sales_2017] AS
SELECT *
FROM OPENROWSET(
    BULK 'https://stadvworksabovegnat.dfs.core.windows.net/silver/sales/2017/AdventureWorks_Sales_2017.csv/*.parquet',
    FORMAT = 'PARQUET'
) AS rows;
GO


-- ============================================================
-- gold.territories
-- ============================================================

CREATE OR ALTER VIEW [gold].[territories] AS
SELECT *
FROM OPENROWSET(
    BULK 'https://stadvworksabovegnat.dfs.core.windows.net/silver/territories/AdventureWorks_Territories.csv/*.parquet',
    FORMAT = 'PARQUET'
) AS rows;
GO
