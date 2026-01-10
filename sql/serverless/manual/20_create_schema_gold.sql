/* ============================================================
   Serverless SQL: ensure Gold schema exists

   Purpose
   -------
   - Verify the presence of the `gold` schema
   - Create the schema if it does not already exist
   - Prepare the database for Gold-layer objects (views, tables)

   Execution Notes
   ---------------
   - Must be executed within the target database context
     (adventureworks_serverless).
   - The script is idempotent and safe to re-run.
   - Dynamic SQL is required for CREATE SCHEMA inside conditional logic.
   ============================================================ */

-- ============================================================
-- 1) Ensure correct database context
-- ============================================================

USE [adventureworks_serverless];
GO


-- ============================================================
-- 2) Create the Gold schema if it does not exist
--
-- Notes
-- -----
-- - SCHEMA_ID returns NULL if the schema is missing
-- - CREATE SCHEMA cannot be executed directly inside IF
--   without dynamic SQL
-- ============================================================

IF SCHEMA_ID('gold') IS NULL
BEGIN
    EXEC ('CREATE SCHEMA [gold]');
END
GO
