-- Create a serverless SQL database (run while connected to Built-in and using master)
IF DB_ID('adventureworks_serverless') IS NULL
BEGIN
    CREATE DATABASE [adventureworks_serverless];
END
GO

-- Switch context for the rest of this script
USE [adventureworks_serverless];
GO

-- Sanity check
SELECT DB_NAME() AS current_db;
GO
