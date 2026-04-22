-- Grant Function App Managed Identity Access to SQL Database
-- Function App: aisearch-demo-func-wyjsbl
-- Principal ID: b38ba5d7-b071-4490-9808-bdd4f89c1bfb

-- Create user for Function App managed identity
CREATE USER [aisearch-demo-func-wyjsbl] FROM EXTERNAL PROVIDER;
GO

-- Grant db_datareader role (read access to all tables)
ALTER ROLE db_datareader ADD MEMBER [aisearch-demo-func-wyjsbl];
GO

-- Verify the user was created and role assigned
SELECT dp.name, dp.type_desc, dp.authentication_type_desc
FROM sys.database_principals dp
WHERE dp.name = 'aisearch-demo-func-wyjsbl';
GO

-- Verify role membership
SELECT 
    dp.name AS UserName,
    rp.name AS RoleName
FROM sys.database_principals dp
JOIN sys.database_role_members drm ON dp.principal_id = drm.member_principal_id
JOIN sys.database_principals rp ON drm.role_principal_id = rp.principal_id
WHERE dp.name = 'aisearch-demo-func-wyjsbl';
GO

PRINT 'Function App SQL access granted successfully!';
GO
