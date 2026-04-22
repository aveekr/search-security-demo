-- Sample data for Capital Markets Search Demo
-- 10 Advisors, 50 Clients, and their relationships

-- Insert Advisors
INSERT INTO Advisors (AdvisorId, FirstName, LastName, Email, Region) VALUES
('advisor-001', 'Sarah', 'Johnson', 'sarah.johnson@capitalmarkets.com', 'Northeast'),
('advisor-002', 'Michael', 'Chen', 'michael.chen@capitalmarkets.com', 'West'),
('advisor-003', 'Emily', 'Rodriguez', 'emily.rodriguez@capitalmarkets.com', 'Southeast'),
('advisor-004', 'David', 'Kim', 'david.kim@capitalmarkets.com', 'Midwest'),
('advisor-005', 'Jennifer', 'Williams', 'jennifer.williams@capitalmarkets.com', 'Southwest'),
('advisor-006', 'Robert', 'Martinez', 'robert.martinez@capitalmarkets.com', 'Northeast'),
('advisor-007', 'Lisa', 'Anderson', 'lisa.anderson@capitalmarkets.com', 'West'),
('advisor-008', 'James', 'Taylor', 'james.taylor@capitalmarkets.com', 'Southeast'),
('advisor-009', 'Maria', 'Garcia', 'maria.garcia@capitalmarkets.com', 'Midwest'),
('advisor-010', 'Christopher', 'Lee', 'christopher.lee@capitalmarkets.com', 'Southwest');

-- Insert Clients
INSERT INTO Clients (ClientId, FirstName, LastName, CompanyName, Email, PortfolioValue, RiskTolerance) VALUES
('client-001', 'John', 'Smith', 'Smith Enterprises', 'john.smith@example.com', 2500000.00, 'Moderate'),
('client-002', 'Mary', 'Davis', 'Davis Tech', 'mary.davis@example.com', 5000000.00, 'Aggressive'),
('client-003', 'William', 'Brown', 'Brown Industries', 'william.brown@example.com', 1200000.00, 'Conservative'),
('client-004', 'Patricia', 'Wilson', 'Wilson Corp', 'patricia.wilson@example.com', 3500000.00, 'Moderate'),
('client-005', 'Richard', 'Moore', 'Moore Holdings', 'richard.moore@example.com', 7500000.00, 'Aggressive'),
('client-006', 'Linda', 'Taylor', 'Taylor Investments', 'linda.taylor@example.com', 1800000.00, 'Conservative'),
('client-007', 'Thomas', 'Anderson', 'Anderson LLC', 'thomas.anderson@example.com', 4200000.00, 'Moderate'),
('client-008', 'Barbara', 'Jackson', 'Jackson Partners', 'barbara.jackson@example.com', 6000000.00, 'Aggressive'),
('client-009', 'Charles', 'White', 'White Capital', 'charles.white@example.com', 2100000.00, 'Moderate'),
('client-010', 'Susan', 'Harris', 'Harris Ventures', 'susan.harris@example.com', 3800000.00, 'Conservative'),
('client-011', 'Joseph', 'Martin', 'Martin Group', 'joseph.martin@example.com', 5500000.00, 'Aggressive'),
('client-012', 'Jessica', 'Thompson', 'Thompson Advisory', 'jessica.thompson@example.com', 1500000.00, 'Conservative'),
('client-013', 'Daniel', 'Garcia', 'Garcia Traders', 'daniel.garcia@example.com', 4800000.00, 'Moderate'),
('client-014', 'Sarah', 'Martinez', 'Martinez Equity', 'sarah.martinez@example.com', 6500000.00, 'Aggressive'),
('client-015', 'Matthew', 'Robinson', 'Robinson Trust', 'matthew.robinson@example.com', 2800000.00, 'Moderate'),
('client-016', 'Karen', 'Clark', 'Clark Financial', 'karen.clark@example.com', 1900000.00, 'Conservative'),
('client-017', 'Paul', 'Rodriguez', 'Rodriguez Capital', 'paul.rodriguez@example.com', 7200000.00, 'Aggressive'),
('client-018', 'Nancy', 'Lewis', 'Lewis Holdings', 'nancy.lewis@example.com', 3200000.00, 'Moderate'),
('client-019', 'Mark', 'Lee', 'Lee Enterprises', 'mark.lee@example.com', 4500000.00, 'Moderate'),
('client-020', 'Betty', 'Walker', 'Walker Investments', 'betty.walker@example.com', 2600000.00, 'Conservative'),
('client-021', 'Donald', 'Hall', 'Hall Partners', 'donald.hall@example.com', 5800000.00, 'Aggressive'),
('client-022', 'Helen', 'Allen', 'Allen Group', 'helen.allen@example.com', 3100000.00, 'Moderate'),
('client-023', 'Kenneth', 'Young', 'Young Corp', 'kenneth.young@example.com', 4100000.00, 'Moderate'),
('client-024', 'Dorothy', 'Hernandez', 'Hernandez LLC', 'dorothy.hernandez@example.com', 1700000.00, 'Conservative'),
('client-025', 'Steven', 'King', 'King Capital', 'steven.king@example.com', 6800000.00, 'Aggressive'),
('client-026', 'Carol', 'Wright', 'Wright Ventures', 'carol.wright@example.com', 2900000.00, 'Moderate'),
('client-027', 'Edward', 'Lopez', 'Lopez Trading', 'edward.lopez@example.com', 3700000.00, 'Moderate'),
('client-028', 'Michelle', 'Hill', 'Hill Equity', 'michelle.hill@example.com', 5200000.00, 'Aggressive'),
('client-029', 'Brian', 'Scott', 'Scott Financial', 'brian.scott@example.com', 2300000.00, 'Conservative'),
('client-030', 'Sandra', 'Green', 'Green Holdings', 'sandra.green@example.com', 4600000.00, 'Moderate'),
('client-031', 'Ronald', 'Adams', 'Adams Industries', 'ronald.adams@example.com', 7000000.00, 'Aggressive'),
('client-032', 'Ashley', 'Baker', 'Baker Trust', 'ashley.baker@example.com', 1600000.00, 'Conservative'),
('client-033', 'Kevin', 'Gonzalez', 'Gonzalez Partners', 'kevin.gonzalez@example.com', 3900000.00, 'Moderate'),
('client-034', 'Kimberly', 'Nelson', 'Nelson Capital', 'kimberly.nelson@example.com', 5900000.00, 'Aggressive'),
('client-035', 'Timothy', 'Carter', 'Carter Group', 'timothy.carter@example.com', 2700000.00, 'Moderate'),
('client-036', 'Donna', 'Mitchell', 'Mitchell Investments', 'donna.mitchell@example.com', 2000000.00, 'Conservative'),
('client-037', 'Jeffrey', 'Perez', 'Perez Holdings', 'jeffrey.perez@example.com', 6200000.00, 'Aggressive'),
('client-038', 'Rebecca', 'Roberts', 'Roberts Ventures', 'rebecca.roberts@example.com', 3400000.00, 'Moderate'),
('client-039', 'Ryan', 'Turner', 'Turner Trading', 'ryan.turner@example.com', 4300000.00, 'Moderate'),
('client-040', 'Laura', 'Phillips', 'Phillips Financial', 'laura.phillips@example.com', 1400000.00, 'Conservative'),
('client-041', 'Jason', 'Campbell', 'Campbell Capital', 'jason.campbell@example.com', 7100000.00, 'Aggressive'),
('client-042', 'Amy', 'Parker', 'Parker Group', 'amy.parker@example.com', 3300000.00, 'Moderate'),
('client-043', 'Gary', 'Evans', 'Evans Corp', 'gary.evans@example.com', 4700000.00, 'Moderate'),
('client-044', 'Stephanie', 'Edwards', 'Edwards LLC', 'stephanie.edwards@example.com', 2200000.00, 'Conservative'),
('client-045', 'Nicholas', 'Collins', 'Collins Capital', 'nicholas.collins@example.com', 6400000.00, 'Aggressive'),
('client-046', 'Deborah', 'Stewart', 'Stewart Ventures', 'deborah.stewart@example.com', 3000000.00, 'Moderate'),
('client-047', 'Raymond', 'Morris', 'Morris Investments', 'raymond.morris@example.com', 5100000.00, 'Moderate'),
('client-048', 'Cynthia', 'Rogers', 'Rogers Equity', 'cynthia.rogers@example.com', 1300000.00, 'Conservative'),
('client-049', 'Frank', 'Reed', 'Reed Holdings', 'frank.reed@example.com', 6900000.00, 'Aggressive'),
('client-050', 'Kathleen', 'Cook', 'Cook Financial', 'kathleen.cook@example.com', 2400000.00, 'Moderate');

-- Assign clients to advisors (each advisor gets 5-8 clients with some overlap)
INSERT INTO AdvisorClientAccess (AdvisorId, ClientId, IsActive) VALUES
-- Sarah Johnson (advisor-001) - Clients 1-7
(1, 1, 1), (1, 2, 1), (1, 3, 1), (1, 4, 1), (1, 5, 1), (1, 6, 1), (1, 7, 1),

-- Michael Chen (advisor-002) - Clients 6-12
(2, 6, 1), (2, 7, 1), (2, 8, 1), (2, 9, 1), (2, 10, 1), (2, 11, 1), (2, 12, 1),

-- Emily Rodriguez (advisor-003) - Clients 11-17
(3, 11, 1), (3, 12, 1), (3, 13, 1), (3, 14, 1), (3, 15, 1), (3, 16, 1), (3, 17, 1),

-- David Kim (advisor-004) - Clients 16-22
(4, 16, 1), (4, 17, 1), (4, 18, 1), (4, 19, 1), (4, 20, 1), (4, 21, 1), (4, 22, 1),

-- Jennifer Williams (advisor-005) - Clients 21-27
(5, 21, 1), (5, 22, 1), (5, 23, 1), (5, 24, 1), (5, 25, 1), (5, 26, 1), (5, 27, 1),

-- Robert Martinez (advisor-006) - Clients 26-32
(6, 26, 1), (6, 27, 1), (6, 28, 1), (6, 29, 1), (6, 30, 1), (6, 31, 1), (6, 32, 1),

-- Lisa Anderson (advisor-007) - Clients 31-37
(7, 31, 1), (7, 32, 1), (7, 33, 1), (7, 34, 1), (7, 35, 1), (7, 36, 1), (7, 37, 1),

-- James Taylor (advisor-008) - Clients 36-42
(8, 36, 1), (8, 37, 1), (8, 38, 1), (8, 39, 1), (8, 40, 1), (8, 41, 1), (8, 42, 1),

-- Maria Garcia (advisor-009) - Clients 41-47
(9, 41, 1), (9, 42, 1), (9, 43, 1), (9, 44, 1), (9, 45, 1), (9, 46, 1), (9, 47, 1),

-- Christopher Lee (advisor-010) - Clients 45-50, 1-2 (wraps around)
(10, 45, 1), (10, 46, 1), (10, 47, 1), (10, 48, 1), (10, 49, 1), (10, 50, 1), (10, 1, 1), (10, 2, 1);

GO

-- Query to verify data
SELECT 
    a.AdvisorId,
    a.FirstName + ' ' + a.LastName AS AdvisorName,
    COUNT(aca.ClientId) AS ClientCount
FROM Advisors a
LEFT JOIN AdvisorClientAccess aca ON a.Id = aca.AdvisorId AND aca.IsActive = 1
GROUP BY a.AdvisorId, a.FirstName, a.LastName
ORDER BY a.AdvisorId;

-- Demo login identity mappings (replace with your tenant's real users/oids)
IF NOT EXISTS (SELECT 1 FROM UserIdentityMap WHERE EntraObjectId = '00000000-0000-0000-0000-000000000001')
BEGIN
    INSERT INTO UserIdentityMap (EntraObjectId, UserPrincipalName, AdvisorId, IsActive) VALUES
    ('00000000-0000-0000-0000-000000000001', 'advisor1@contoso.com', 'advisor-001', 1),
    ('00000000-0000-0000-0000-000000000002', 'advisor2@contoso.com', 'advisor-003', 1),
    ('00000000-0000-0000-0000-000000000003', 'advisor3@contoso.com', 'advisor-010', 1);
END

PRINT 'Sample data loaded successfully';
PRINT '10 Advisors created';
PRINT '50 Clients created';
PRINT 'Advisor-Client mappings created';
PRINT '3 demo UserIdentityMap rows created (replace with real Entra identities)';
