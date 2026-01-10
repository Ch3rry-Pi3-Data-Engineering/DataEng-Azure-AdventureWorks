/* ============================================================
   Serverless SQL: create (if missing) + switch database context

   Purpose
   -------
   - Ensure a serverless SQL database exists for the workload
   - Switch context into that database for subsequent objects/scripts
   - Confirm the active database context

   Execution Notes
   ---------------
   - Run this while connected to the Synapse *Built-in* (serverless) SQL pool.
   - The CREATE DATABASE statement must be executed from the `master` database.
   - This script is idempotent: re-running it will not recreate the database.
   ============================================================ */

-- ============================================================
-- 1) Create the serverless SQL database (only if it does not exist)
--
-- Requirement:
-- - Must be executed while connected to Built-in and in `master`
-- ============================================================

IF DB_ID('adventureworks_serverless') IS NULL
BEGIN
    CREATE DATABASE [adventureworks_serverless];
END
GO


-- ============================================================
-- 2) Switch context for the rest of the script
--
-- Notes
-- -----
-- - Subsequent statements will execute in this database context
-- ============================================================

USE [adventureworks_serverless];
GO


-- ============================================================
-- 3) Sanity check: confirm current database context
-- ============================================================

SELECT DB_NAME() AS current_db;
GO
