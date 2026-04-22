-- Capital Markets Search Demo - Database Schema
-- Azure SQL Database with Entra ID authentication

-- Advisors table
CREATE TABLE Advisors (
    Id INT PRIMARY KEY IDENTITY(1,1),
    AdvisorId NVARCHAR(50) UNIQUE NOT NULL,
    FirstName NVARCHAR(100) NOT NULL,
    LastName NVARCHAR(100) NOT NULL,
    Email NVARCHAR(255) NOT NULL,
    Region NVARCHAR(50),
    CreatedDate DATETIME2 DEFAULT GETUTCDATE(),
    CONSTRAINT UQ_Advisor_Email UNIQUE (Email)
);

-- Clients table
CREATE TABLE Clients (
    Id INT PRIMARY KEY IDENTITY(1,1),
    ClientId NVARCHAR(50) UNIQUE NOT NULL,
    FirstName NVARCHAR(100) NOT NULL,
    LastName NVARCHAR(100) NOT NULL,
    CompanyName NVARCHAR(255),
    Email NVARCHAR(255) NOT NULL,
    PortfolioValue DECIMAL(18,2),
    RiskTolerance NVARCHAR(20),
    CreatedDate DATETIME2 DEFAULT GETUTCDATE(),
    CONSTRAINT UQ_Client_Email UNIQUE (Email),
    CONSTRAINT CHK_RiskTolerance CHECK (RiskTolerance IN ('Conservative', 'Moderate', 'Aggressive'))
);

-- Advisor-Client Access mapping (many-to-many)
CREATE TABLE AdvisorClientAccess (
    Id INT PRIMARY KEY IDENTITY(1,1),
    AdvisorId INT NOT NULL,
    ClientId INT NOT NULL,
    AssignedDate DATETIME2 DEFAULT GETUTCDATE(),
    IsActive BIT DEFAULT 1,
    CONSTRAINT FK_AdvisorClientAccess_Advisor FOREIGN KEY (AdvisorId) REFERENCES Advisors(Id),
    CONSTRAINT FK_AdvisorClientAccess_Client FOREIGN KEY (ClientId) REFERENCES Clients(Id),
    CONSTRAINT UQ_AdvisorClient UNIQUE (AdvisorId, ClientId)
);

-- User identity to advisor mapping (for demo login context resolution)
CREATE TABLE UserIdentityMap (
    Id INT PRIMARY KEY IDENTITY(1,1),
    EntraObjectId NVARCHAR(64) NOT NULL,
    UserPrincipalName NVARCHAR(255) NULL,
    AdvisorId NVARCHAR(50) NOT NULL,
    IsActive BIT DEFAULT 1,
    CreatedDate DATETIME2 DEFAULT GETUTCDATE(),
    CONSTRAINT UQ_UserIdentityMap_EntraObjectId UNIQUE (EntraObjectId),
    CONSTRAINT FK_UserIdentityMap_Advisor FOREIGN KEY (AdvisorId) REFERENCES Advisors(AdvisorId)
);

-- Create indexes for performance
CREATE INDEX IX_AdvisorClientAccess_AdvisorId ON AdvisorClientAccess(AdvisorId) WHERE IsActive = 1;
CREATE INDEX IX_AdvisorClientAccess_ClientId ON AdvisorClientAccess(ClientId) WHERE IsActive = 1;
CREATE INDEX IX_Advisors_AdvisorId ON Advisors(AdvisorId);
CREATE INDEX IX_Clients_ClientId ON Clients(ClientId);
CREATE INDEX IX_UserIdentityMap_UPN ON UserIdentityMap(UserPrincipalName) WHERE IsActive = 1;

-- Create view for easy access mapping queries
CREATE VIEW vw_AdvisorClientMapping AS
SELECT 
    a.AdvisorId,
    a.FirstName + ' ' + a.LastName AS AdvisorName,
    a.Email AS AdvisorEmail,
    c.ClientId,
    c.FirstName + ' ' + c.LastName AS ClientName,
    c.CompanyName,
    c.Email AS ClientEmail,
    aca.AssignedDate,
    aca.IsActive
FROM AdvisorClientAccess aca
INNER JOIN Advisors a ON aca.AdvisorId = a.Id
INNER JOIN Clients c ON aca.ClientId = c.Id
WHERE aca.IsActive = 1;

GO

PRINT 'Schema created successfully';
