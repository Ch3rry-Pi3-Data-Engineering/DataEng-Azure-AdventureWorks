USE [adventureworks_serverless]
GO

DECLARE @storage_account sysname = '$(STORAGE_ACCOUNT_NAME)';
DECLARE @bulk nvarchar(4000) =
    'https://' + @storage_account + '.dfs.core.windows.net/silver/customers/AdventureWorks_Customers.csv/*.parquet';

DECLARE @sql nvarchar(max) =
    'SELECT TOP (100) * FROM OPENROWSET(BULK ''' + @bulk + ''', FORMAT = ''PARQUET'') AS rows;';

EXEC sp_executesql @sql;
GO
