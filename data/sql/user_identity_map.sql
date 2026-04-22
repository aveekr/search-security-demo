-- Incremental script: create and seed UserIdentityMap for login-to-advisor demo
-- Run this against existing environments without recreating other tables.

IF OBJECT_ID('dbo.UserIdentityMap', 'U') IS NULL
BEGIN
    CREATE TABLE dbo.UserIdentityMap (
        Id INT PRIMARY KEY IDENTITY(1,1),
        EntraObjectId NVARCHAR(64) NOT NULL,
        UserPrincipalName NVARCHAR(255) NULL,
        AdvisorId NVARCHAR(50) NOT NULL,
        IsActive BIT DEFAULT 1,
        CreatedDate DATETIME2 DEFAULT GETUTCDATE(),
        CONSTRAINT UQ_UserIdentityMap_EntraObjectId UNIQUE (EntraObjectId),
        CONSTRAINT FK_UserIdentityMap_Advisor FOREIGN KEY (AdvisorId) REFERENCES dbo.Advisors(AdvisorId)
    );
END;

IF NOT EXISTS (
    SELECT 1 FROM sys.indexes
    WHERE name = 'IX_UserIdentityMap_UPN'
      AND object_id = OBJECT_ID('dbo.UserIdentityMap')
)
BEGIN
    CREATE INDEX IX_UserIdentityMap_UPN
    ON dbo.UserIdentityMap(UserPrincipalName)
    WHERE IsActive = 1;
END;

-- Replace these sample values with real Entra users from your tenant.
MERGE dbo.UserIdentityMap AS target
USING (VALUES
    ('c62d90e2-8c61-4370-86fc-deafa157cfa0', 'test@MngEnvMCAP012775.onmicrosoft.com', 'advisor-001', 1),
    ('44121d17-aef4-4ea3-953b-3ec0cd2bef75', 'testrlscls@MngEnvMCAP012775.onmicrosoft.com', 'advisor-003', 1),
    ('da2109ac-4ec5-4087-8bda-81342946927d', 'advisor3@MngEnvMCAP012775.onmicrosoft.com', 'advisor-010', 1)
) AS src (EntraObjectId, UserPrincipalName, AdvisorId, IsActive)
ON target.EntraObjectId = src.EntraObjectId
WHEN MATCHED THEN
    UPDATE SET
        target.UserPrincipalName = src.UserPrincipalName,
        target.AdvisorId = src.AdvisorId,
        target.IsActive = src.IsActive
WHEN NOT MATCHED THEN
    INSERT (EntraObjectId, UserPrincipalName, AdvisorId, IsActive)
    VALUES (src.EntraObjectId, src.UserPrincipalName, src.AdvisorId, src.IsActive);

SELECT EntraObjectId, UserPrincipalName, AdvisorId, IsActive
FROM dbo.UserIdentityMap
ORDER BY AdvisorId;
