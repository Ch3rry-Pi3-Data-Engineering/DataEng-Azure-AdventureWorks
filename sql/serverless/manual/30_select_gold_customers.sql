/* ============================================================
   Serverless SQL: Gold view validation query

   Purpose
   -------
   - Verify that the `gold.customers` view is accessible
   - Confirm that OPENROWSET-based views over Silver Parquet
     return data as expected
   - Provide a simple sanity check for downstream consumers

   Execution Notes
   ---------------
   - Run this in Synapse *Built-in* (serverless) SQL.
   - Assumes the `gold` schema and `customers` view already exist.
   - This is a read-only validation query (no side effects).
   ============================================================ */

-- ============================================================
-- 1) Ensure correct database context
-- ============================================================

USE [adventureworks_serverless];
GO


-- ============================================================
-- 2) Validate Gold customers view
--
-- Notes
-- -----
-- - SELECT * is intentional for exploratory validation
-- - For production queries, explicit column lists are recommended
-- ============================================================

SELECT *
FROM [gold].[customers];
GO
