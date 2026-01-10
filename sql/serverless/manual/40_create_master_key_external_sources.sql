/* ============================================================
   Serverless SQL: security primitives + external access setup

   Purpose
   -------
   - Ensure required cryptographic and security prerequisites exist
   - Configure a managed-identity–based credential for ADLS access
   - Define external data sources for Silver and Gold containers
   - Register a reusable Parquet external file format

   Execution Notes
   ---------------
   - Run this in Synapse *Built-in* (serverless) SQL.
   - STORAGE_ACCOUNT_NAME is injected at runtime
     (e.g. via sqlcmd variable substitution).
   - This script is designed to be idempotent:
       * objects are created only if missing
       * existing data sources / formats are dropped and recreated
   ============================================================ */

-- ============================================================
-- 1) Ensure correct database context
-- ============================================================

USE [adventureworks_serverless];
GO


/* ============================================================
   2) Database Master Key (DMK)

   Purpose
   -------
   - Required for database-scoped credentials
   - Created once per database

   Notes
   -----
   - Serverless SQL auto-creates the symmetric key name
     '##MS_DatabaseMasterKey##'
   - The password is only used to encrypt the key at creation time
   ============================================================ */

IF NOT EXISTS (
    SELECT 1
    FROM sys.symmetric_keys
    WHERE name = '##MS_DatabaseMasterKey##'
)
BEGIN
    CREATE MASTER KEY
        ENCRYPTION BY PASSWORD = 'ChangeMe-Strong-MasterKey-123!';
END
GO


/* ============================================================
   3) Database-scoped credential (Managed Identity)

   Purpose
   -------
   - Allow serverless SQL to authenticate to ADLS Gen2
     using the workspace Managed Identity
   ============================================================ */

IF NOT EXISTS (
    SELECT 1
    FROM sys.database_scoped_credentials
    WHERE name = 'cred_adventureworks_mi'
)
BEGIN
    CREATE DATABASE SCOPED CREDENTIAL [cred_adventureworks_mi]
    WITH IDENTITY = 'Managed Identity';
END
GO


/* ============================================================
   4) External data source: Silver

   Purpose
   -------
   - Define a reusable reference to the Silver container
   - Uses HTTPS DFS endpoint (required by serverless SQL)

   Notes
   -----
   - Dropped and recreated to allow location changes
   ============================================================ */

IF EXISTS (
    SELECT 1
    FROM sys.external_data_sources
    WHERE name = 'source_silver'
)
BEGIN
    DROP EXTERNAL DATA SOURCE [source_silver];
END
GO

CREATE EXTERNAL DATA SOURCE [source_silver]
WITH (
    LOCATION   = 'https://$(STORAGE_ACCOUNT_NAME).dfs.core.windows.net/silver',
    CREDENTIAL = [cred_adventureworks_mi]
);
GO


/* ============================================================
   5) External data source: Gold

   Purpose
   -------
   - Define a reusable reference to the Gold container
   - Mirrors the Silver external data source pattern
   ============================================================ */

IF EXISTS (
    SELECT 1
    FROM sys.external_data_sources
    WHERE name = 'source_gold'
)
BEGIN
    DROP EXTERNAL DATA SOURCE [source_gold];
END
GO

CREATE EXTERNAL DATA SOURCE [source_gold]
WITH (
    LOCATION   = 'https://$(STORAGE_ACCOUNT_NAME).dfs.core.windows.net/gold',
    CREDENTIAL = [cred_adventureworks_mi]
);
GO


/* ============================================================
   6) External file format: Parquet

   Purpose
   -------
   - Register a reusable Parquet file format definition
   - Allows consistent reuse across OPENROWSET / external tables

   Notes
   -----
   - Dropped and recreated to allow format changes
   - Snappy is the default compression for most Parquet writers
   ============================================================ */

IF EXISTS (
    SELECT 1
    FROM sys.external_file_formats
    WHERE name = 'format_parquet'
)
BEGIN
    DROP EXTERNAL FILE FORMAT [format_parquet];
END
GO

CREATE EXTERNAL FILE FORMAT [format_parquet]
WITH (
    FORMAT_TYPE = PARQUET,
    DATA_COMPRESSION = 'org.apache.hadoop.io.compress.SnappyCodec'
);
GO
