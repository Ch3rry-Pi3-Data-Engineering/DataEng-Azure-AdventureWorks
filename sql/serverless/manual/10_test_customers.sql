/* ============================================================
   Serverless SQL: parameterised OPENROWSET test query (Parquet)

   Purpose
   -------
   - Switch into the AdventureWorks serverless database
   - Construct a dynamic BULK path using a supplied storage account
   - Execute a test query against Parquet data in ADLS Gen2
   - Validate serverless SQL access to Silver-layer data

   Execution Notes
   ---------------
   - This script is intended for Synapse *Built-in* (serverless) SQL.
   - The STORAGE_ACCOUNT_NAME value is injected at runtime
     (e.g. via sqlcmd variable substitution).
   - The query uses OPENROWSET with FORMAT = 'PARQUET'.
   - TOP (100) is used as a lightweight validation read.
   ============================================================ */

-- ============================================================
-- 1) Ensure correct database context
-- ============================================================

USE [adventureworks_serverless];
GO


-- ============================================================
-- 2) Declare parameters and construct the BULK path
--
-- @storage_account:
--   - Provided at execution time (e.g. sqlcmd -v)
--   - Must correspond to an ADLS Gen2 account
--
-- @bulk:
--   - HTTPS endpoint required by serverless SQL
--   - Points to Parquet files in the Silver layer
-- ============================================================

DECLARE @storage_account sysname = '$(STORAGE_ACCOUNT_NAME)';

DECLARE @bulk nvarchar(4000) =
    'https://' + @storage_account +
    '.dfs.core.windows.net/silver/customers/AdventureWorks_Customers.csv/*.parquet';


-- ============================================================
-- 3) Build the dynamic SQL statement
--
-- Notes
-- -----
-- - OPENROWSET does not accept variables directly for BULK paths
-- - Dynamic SQL is therefore required
-- ============================================================

DECLARE @sql nvarchar(max) =
    'SELECT TOP (100) *
     FROM OPENROWSET(
         BULK ''' + @bulk + ''',
         FORMAT = ''PARQUET''
     ) AS rows;';


-- ============================================================
-- 4) Execute the query
--
-- This returns a sample of rows to confirm:
--   - Storage access
--   - Path correctness
--   - Parquet schema readability
-- ============================================================

EXEC sp_executesql @sql;
GO
