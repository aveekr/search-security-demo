# Deployment Guide

This guide walks through deploying the Azure AI Search Security Demo from scratch.

---

## Prerequisites

### Required Tools

- **Azure CLI** (v2.50+) - [Install](https://learn.microsoft.com/cli/azure/install-azure-cli)
- **Terraform** (v1.5+) - [Install](https://developer.hashicorp.com/terraform/downloads)
- **Python** (3.11+) - [Install](https://www.python.org/downloads/)
- **Azure Functions Core Tools** (v4) - [Install](https://learn.microsoft.com/azure/azure-functions/functions-run-local#install-the-azure-functions-core-tools)
- **Git** - [Install](https://git-scm.com/downloads)
- **SQL Server ODBC Driver 18** - [Install](https://learn.microsoft.com/sql/connect/odbc/download-odbc-driver-for-sql-server)

### Azure Permissions

You need:
- **Subscription Contributor** role (to create resources)
- **User Access Administrator** or **Owner** (for RBAC assignments)

### Check Prerequisites

```powershell
# Azure CLI
az --version

# Terraform
terraform --version

# Python
python --version

# Functions Core Tools
func --version

# ODBC Driver (Windows)
Get-OdbcDriver | Where-Object {$_.Name -like "*SQL Server*"}
```

---

## Step 1: Clone Repository

```powershell
git clone <repository-url>
cd ai_search_security
```

---

## Step 2: Azure Login & Subscription

```powershell
# Login to Azure
az login

# List subscriptions
az account list --output table

# Set active subscription
az account set --subscription "<subscription-id-or-name>"

# Verify
az account show
```

---

## Step 3: Create Entra ID App Registration (OAuth 2.0)

### 3.1 Register Application

```powershell
# Create app registration
$appName = "ai-search-security-demo"
$app = az ad app create --display-name $appName --sign-in-audience "AzureADMyOrg" | ConvertFrom-Json

# Save App ID
$appId = $app.appId
Write-Host "App ID (Client ID): $appId"

# Create service principal
az ad sp create --id $appId

# Reset client secret
$secret = az ad app credential reset --id $appId --query password -o tsv
Write-Host "Client Secret: $secret"
Write-Host "Save this secret securely - it won't be shown again!"
```

### 3.2 Configure API Permissions (Optional)

```powershell
# Add Microsoft Graph User.Read permission
$graphApiId = "00000003-0000-0000-c000-000000000000"  # Microsoft Graph
$userReadPermission = "e1fe6dd8-ba31-4d61-89e7-88639da4683d"  # User.Read

az ad app permission add `
  --id $appId `
  --api $graphApiId `
  --api-permissions "$userReadPermission=Scope"

# Grant admin consent (requires admin privileges)
az ad app permission admin-consent --id $appId
```

### 3.3 Configure Redirect URIs

```powershell
# Add redirect URIs (for testing)
az ad app update --id $appId --web-redirect-uris "https://oauth.pstmn.io/v1/callback" "http://localhost:7071/callback"
```

### 3.4 Save Configuration

```powershell
# Note these values for later:
$tenantId = (az account show --query tenantId -o tsv)

Write-Host @"
=== OAuth Configuration ===
Tenant ID:     $tenantId
Client ID:     $appId
Client Secret: $secret (saved earlier)
"@
```

---

## Step 4: Initialize Terraform

```powershell
cd infra

# Initialize Terraform
terraform init
```

---

## Step 5: Configure Variables

### 5.1 Create terraform.tfvars

```powershell
# Copy example
copy terraform.tfvars.example terraform.tfvars

# Edit terraform.tfvars
notepad terraform.tfvars
```

### 5.2 Update Values

```hcl
# terraform.tfvars
resource_group_name = "aisearch-demo"
location            = "centralus"
resource_prefix     = "aisearch"

tags = {
  Environment = "Demo"
  Project     = "AI-Search-Security"
  ManagedBy   = "Terraform"
}

# OpenAI settings
openai_location          = "eastus"  # Limited availability
embedding_model_name     = "text-embedding-ada-002"
embedding_model_version  = "2"
embedding_deployment_capacity = 120
```

---

## Step 6: Deploy Infrastructure

### 6.1 Plan Deployment

```powershell
terraform plan -out=tfplan
```

Review the plan carefully. Expected resources:
- Resource Group
- Storage Account (2 containers)
- Key Vault
- Application Insights
- Log Analytics Workspace
- Azure AI Search (Standard S1)
- Azure OpenAI (with embedding deployment)
- Azure SQL Server + Database
- Azure Functions (Premium EP1)
- App Service Plan
- API Management (Developer tier)

### 6.2 Apply Deployment

```powershell
terraform apply tfplan
```

**Duration**: ~15-20 minutes

### 6.3 Capture Outputs

```powershell
# Save outputs
terraform output -json > ../outputs.json

# View key outputs
terraform output
```

**Important Outputs**:
- `search_service_name`
- `search_admin_key` (for initial setup only)
- `sql_server_fqdn`
- `sql_database_name`
- `function_app_name`
- `apim_gateway_url`
- `storage_account_name`

---

## Step 7: Configure SQL Database

### 7.1 Set Up SQL Admin

```powershell
$sqlServerName = terraform output -raw sql_server_name
$currentUser = az account show --query user.name -o tsv

# Set yourself as SQL Admin
az sql server ad-admin create `
  --resource-group aisearch-demo `
  --server-name $sqlServerName `
  --display-name $currentUser `
  --object-id (az ad signed-in-user show --query id -o tsv)
```

### 7.2 Allow Azure Services

```powershell
# Firewall rule already created by Terraform
# Verify:
az sql server firewall-rule show `
  --resource-group aisearch-demo `
  --server $sqlServerName `
  --name AllowAzureServices
```

### 7.3 Deploy Database Schema

```powershell
cd ..\data\sql

# Connect and run schema
$sqlFqdn = terraform output -raw sql_server_fqdn -no-color
$sqlDb = terraform output -raw sql_database_name -no-color

# Using sqlcmd (requires SQL tools)
sqlcmd -S $sqlFqdn -d $sqlDb -G -i schema.sql
```

**Alternative: Azure Portal**:
1. Go to Azure Portal → SQL Database `aisearch-demo-db`
2. Click **Query editor**
3. Login with your Entra ID
4. Copy/paste `schema.sql` and execute

### 7.4 Load Sample Data

```powershell
# Load seed data
sqlcmd -S $sqlFqdn -d $sqlDb -G -i seed_data.sql
```

### 7.5 Verify Data

```powershell
# Test query
sqlcmd -S $sqlFqdn -d $sqlDb -G -Q "SELECT COUNT(*) FROM Advisors; SELECT COUNT(*) FROM Clients;"
```

Expected output:
- Advisors: 10
- Clients: 50

---

## Step 8: Configure AI Search Index

### 8.1 Get Search Service Details

```powershell
$searchServiceName = terraform output -raw search_service_name -no-color
$searchAdminKey = terraform output -raw search_admin_key -no-color
$searchEndpoint = "https://$searchServiceName.search.windows.net"
```

### 8.2 Create Index

```powershell
cd ..\..\data\search

# Create index using REST API
$headers = @{
    "Content-Type" = "application/json"
    "api-key" = $searchAdminKey
}

$indexDefinition = Get-Content index_definition.json -Raw

Invoke-RestMethod `
    -Uri "$searchEndpoint/indexes/capital-markets-docs?api-version=2024-07-01" `
    -Method PUT `
    -Headers $headers `
    -Body $indexDefinition
```

### 8.3 Verify Index

```powershell
# List indexes
Invoke-RestMethod `
    -Uri "$searchEndpoint/indexes?api-version=2024-07-01" `
    -Method GET `
    -Headers $headers | Select-Object -ExpandProperty value | Select-Object name
```

Expected output: `capital-markets-docs`

---

## Step 9: Grant Function App Permissions

**Note**: Most RBAC assignments are handled by Terraform. Verify:

```powershell
$functionAppName = terraform output -raw function_app_name -no-color
$funcPrincipalId = az functionapp show `
    --name $functionAppName `
    --resource-group aisearch-demo `
    --query identity.principalId -o tsv

# Verify role assignments
az role assignment list `
    --assignee $funcPrincipalId `
    --output table
```

Expected roles:
- Search Index Data Reader
- Search Index Data Contributor
- Storage Blob Data Contributor
- Cognitive Services OpenAI User

### 9.1 Grant SQL Database Access

**Important**: This must be done manually via SQL

```powershell
# Connect to SQL as admin
sqlcmd -S $sqlFqdn -d $sqlDb -G

# Run these commands in sqlcmd
```

```sql
-- In sqlcmd session:
CREATE USER [<function-app-name>] FROM EXTERNAL PROVIDER;
GO

ALTER ROLE db_datareader ADD MEMBER [<function-app-name>];
GO

-- Verify
SELECT dp.name, dp.type_desc
FROM sys.database_principals dp
WHERE dp.name = '<function-app-name>';
GO

EXIT
```

Replace `<function-app-name>` with your actual function app name (e.g., `aisearch-func-abc123`).

---

## Step 10: Deploy Function App Code ✅ COMPLETED

### 10.1 Install Dependencies ✅

```powershell
cd ..\..\src

# Create virtual environment
python -m venv .venv

# Activate
.\.venv\Scripts\Activate.ps1

# Install dependencies
pip install -r requirements.txt
```

### 10.2 Configure Local Settings (Optional - for local testing)

```powershell
# Copy example
copy local.settings.json.example local.settings.json

# Edit local.settings.json
notepad local.settings.json
```

Update with your Terraform outputs:
```json
{
  "IsEncrypted": false,
  "Values": {
    "AzureWebJobsStorage": "UseDevelopmentStorage=true",
    "FUNCTIONS_WORKER_RUNTIME": "python",
    "SEARCH_ENDPOINT": "https://<search-service>.search.windows.net",
    "SEARCH_INDEX_NAME": "capital-markets-docs",
    "OPENAI_ENDPOINT": "https://<openai-service>.openai.azure.com",
    "OPENAI_EMBEDDING_DEPLOYMENT": "embedding",
    "SQL_SERVER": "<sql-server>.database.windows.net",
    "SQL_DATABASE": "aisearch-demo-db"
  }
}
```

### 10.3 Test Locally (Optional)

```powershell
func start
```

### 10.4 Deploy to Azure ✅

```powershell
$functionAppName = terraform output -raw function_app_name -no-color

# Deploy (from src directory)
func azure functionapp publish $functionAppName --python
```

**Status**: ✅ Remote build succeeded in ~12 seconds
**Duration**: ~2-5 minutes

### 10.5 Verify Deployment ✅

```powershell
# Check function list
az functionapp function list `
    --name $functionAppName `
    --resource-group aisearch-demo `
    --output table
```

**Deployed functions** ✅:
- `health` - Health check endpoint
- `search` - Vector and hybrid search
- `upload_document` - Document upload
- `get_document` - Document retrieval

**All functions:** Status 200 ✅

---

## Step 11: Configure API Management ✅ READY

### 11.1 APIM Configuration Status ✅

**Deployed Resources**:
- API Management Service: `aisearch-demo-apim-wyjsbl`
- Gateway URL: `https://aisearch-demo-apim-wyjsbl.azure-api.net`
- Backend: Configured to Function App

```powershell
$apimName = terraform output -raw apim_name -no-color
$apimUrl = terraform output -raw apim_gateway_url -no-color

Write-Host "APIM Service: $apimName"
Write-Host "Gateway URL: $apimUrl"
```

**Via Azure Portal**:
1. Go to API Management service: `aisearch-demo-apim-wyjsbl`
2. In left menu, click **APIs** → **Security** → **OAuth 2.0 + OpenID Connect**
3. Click **+ Add** to create new OAuth2 service
4. Fill in the form:
   - **Id**: `azure-ad-oauth`
   - **Description**: `Azure AD OAuth 2.0 Authorization Server`
   - **Client registration page URL**: `https://portal.azure.com` (or leave blank)
   - **Authorization grant types**: Check `Authorization code` and `Client credentials`
   - **Authorization endpoint URL**: `https://login.microsoftonline.com/<tenant-id>/oauth2/v2.0/authorize`
   - **Token endpoint URL**: `https://login.microsoftonline.com/<tenant-id>/oauth2/v2.0/token`
   - **Authorization request method**: `GET`
   - **Support state parameter**: Check ✓
   - **Client authentication methods**: `In the body`
5. Click **Create**

**Then configure API to use OAuth2**:
1. Go to **APIs** → **search-api** → **Design**
2. In **Inbound processing**, click `</>` (policies editor)
3. Add OAuth 2.0 validation policy

### 11.2 Get Function Key

```powershell
# Get default host key
$funcKey = az functionapp keys list `
    --name $functionAppName `
    --resource-group aisearch-demo `
    --query functionKeys.default -o tsv

Write-Host "Function Key: $funcKey"
```

### 11.3 Update APIM Backend (if needed)

The backend is already configured by Terraform, but verify:

```powershell
$funcAppUrl = "https://$functionAppName.azurewebsites.net"

# Backend should point to this URL with function key in header
```

### 11.4 Apply API Policy via Azure Portal

The API policy is configured manually to avoid Terraform validation issues.

**Steps:**

1. **Navigate to API Management**:
   - Go to [Azure Portal](https://portal.azure.com)
   - Search for your APIM service (e.g., `aisearch-demo-apim-wyjsbl`)
   - Click on the resource

2. **Open the API**:
   - In the left menu, select **APIs**
   - Click on **search-api**

3. **Add API Policy**:
   - In the API designer, click on the **Design** tab
   - In the **Inbound processing** section, click the `</>` (code editor) icon
   - Replace the existing policy with:

```xml
<policies>
  <inbound>
    <base />

    <!-- Rate limiting -->
    <rate-limit calls="100" renewal-period="60" />

    <!-- Backend -->
    <set-backend-service backend-id="search-function-backend" />

    <!-- Correlation ID -->
    <set-header name="x-correlation-id" exists-action="override">
      <value>@(context.RequestId.ToString())</value>
    </set-header>

    <!-- CORS MUST be in inbound -->
    <cors allow-credentials="false">
      <allowed-origins>
        <origin>*</origin>
      </allowed-origins>
      <allowed-methods>
        <method>GET</method>
        <method>POST</method>
        <method>OPTIONS</method>
      </allowed-methods>
      <allowed-headers>
        <header>*</header>
      </allowed-headers>
    </cors>

  </inbound>

  <backend>
    <base />
  </backend>

  <outbound>
    <base />
  </outbound>

  <on-error>
    <base />
  </on-error>
</policies>
```

4. **Save the Policy**:
   - Click **Save** at the bottom
   - Verify no validation errors appear

5. **Test the Policy**:
   - Click on any operation (e.g., **search**)
   - Click **Test** tab
   - The policy should now apply rate limiting, backend routing, and CORS

**Optional: Add OAuth JWT Validation**

If you want to enforce OAuth authentication (configured in Step 3), add this to the `<inbound>` section after `<base />`:

```xml
<validate-jwt header-name="Authorization" failed-validation-httpcode="401" failed-validation-error-message="Unauthorized">
  <openid-config url="https://login.microsoftonline.com/{YOUR-TENANT-ID}/v2.0/.well-known/openid-configuration" />
  <audiences>
    <audience>{YOUR-CLIENT-ID}</audience>
  </audiences>
  <issuers>
    <issuer>https://sts.windows.net/{YOUR-TENANT-ID}/</issuer>
  </issuers>
</validate-jwt>
```

Replace:
- `{YOUR-TENANT-ID}`: Your Azure AD tenant ID (from Step 3.4)
- `{YOUR-CLIENT-ID}`: Your app registration client ID (from Step 3.4)

---

## Step 12: Test Deployment ✅ COMPLETED

### 12.1 Health Check ✅

```powershell
$funcUrl = "https://aisearch-demo-func-wyjsbl.azurewebsites.net"
$funcKey = "9MFqImI9hiVoK_y16s_dMEHEpb1dnNJKka3sOOwQYvUhAzFuu3vQDQ=="

# Test health endpoint
Invoke-WebRequest "$funcUrl/api/health?code=$funcKey" -UseBasicParsing
```

**Status**: ✅ 200 OK
**Response**:
```json
{
  "status": "healthy",
  "message": "Function app is running"
}
```

### 12.2 Search Endpoint ✅

```powershell
$funcUrl = "https://aisearch-demo-func-wyjsbl.azurewebsites.net"
$funcKey = "9MFqImI9hiVoK_y16s_dMEHEpb1dnNJKka3sOOwQYvUhAzFuu3vQDQ=="

$body = @{
    query = "capital markets investment"
    advisorId = "ADV001"
    searchType = "hybrid"
    top = 5
} | ConvertTo-Json

$response = Invoke-WebRequest "$funcUrl/api/search?code=$funcKey" `
    -Method Post `
    -Body $body `
    -ContentType "application/json" `
    -UseBasicParsing

Write-Host "Response: $($response.StatusCode) OK"
```

**Status**: ✅ 200 OK
**Endpoints ready**: Vector search, hybrid search with security filtering

### 12.3 Upload Document ✅

```powershell
$funcUrl = "https://aisearch-demo-func-wyjsbl.azurewebsites.net"
$funcKey = "9MFqImI9hiVoK_y16s_dMEHEpb1dnNJKka3sOOwQYvUhAzFuu3vQDQ=="

$body = @{
    documentId = "doc-001"
    title = "Q1 2024 Market Analysis"
    content = "Capital markets overview for Q1 2024"
    advisorIds = @("ADV001", "ADV002")
} | ConvertTo-Json

$response = Invoke-WebRequest "$funcUrl/api/documents?code=$funcKey" `
    -Method Post `
    -Body $body `
    -ContentType "application/json" `
    -UseBasicParsing

Write-Host "Document uploaded: $($response.StatusCode) Created"
```

**Status**: ✅ 201 Created
**Response**: Document prepared for indexing

### 12.4 Get Document ✅

```powershell
$funcUrl = "https://aisearch-demo-func-wyjsbl.azurewebsites.net"
$funcKey = "9MFqImI9hiVoK_y16s_dMEHEpb1dnNJKka3sOOwQYvUhAzFuu3vQDQ=="
$docId = "doc-001"
$advisorId = "ADV001"

$response = Invoke-WebRequest `
    -Uri "$funcUrl/api/documents/$docId?advisorId=$advisorId&code=$funcKey" `
    -Method Get `
    -UseBasicParsing

Write-Host "Document retrieved: $($response.StatusCode) OK"
```

**Status**: ✅ 200 OK
**Response**: Document with metadata and access control applied

### 12.5 API Endpoint Summary ✅

| Endpoint | Method | Status | Purpose |
|----------|--------|--------|----------|
| `/api/health` | GET | ✅ 200 | Health check |
| `/api/search` | POST | ✅ 200 | Vector/hybrid search |
| `/api/documents` | POST | ✅ 201 | Upload documents |
| `/api/documents/{id}` | GET | ✅ 200 | Retrieve documents |

**Authentication**: Function key in query string `?code={key}`
**All endpoints working and tested** ✅

---

## Step 13: Load Sample Documents

```powershell
# Run document loading script (already available)
# This uploads sample documents from data/documents

cd scripts
python upload_documents.py
```

---

## Step 14: Demo UI + Login Mapping Plan

This section documents what is needed to demo secure multi-user behavior with advisor-based access.

### 14.1 Scope

Build a demo web UI with:
- Login using Microsoft Entra ID
- Upload documents from UI
- Search documents from UI
- Automatic user-to-advisor mapping so each logged-in user sees only authorized documents

### 14.2 Implementation Tasks

1. Frontend app
   - Add a web app (recommended: React + Vite) in a new `web/` folder
   - Add login/logout using MSAL browser library
   - Build screens:
     - Login screen
     - Search screen (query, search type, results)
     - Upload screen (title, content, advisor list)
     - Session panel (signed-in user, resolved advisorId)

2. Identity mapping service
   - Add SQL table for identity mapping:
     - `UserIdentityMap` with `EntraObjectId`, `UserPrincipalName`, `AdvisorId`, `IsActive`
   - Seed with demo users mapped to advisor IDs
   - Add Function API endpoint `GET /api/me/context` to:
     - Read Entra claims (oid/upn)
     - Resolve mapped `advisorId`
     - Return user context to UI

3. API authorization behavior
   - Keep APIM as auth gateway with JWT validation
   - Update API behavior:
     - `POST /api/search`: use mapped advisorId from user context by default
     - `POST /api/documents`: restrict to allowed roles (for demo, advisor or admin)
     - `GET /api/documents/{id}`: enforce advisor filter as already implemented

4. Demo-ready test identities
   - Create at least 3 Entra users and map them to different advisor IDs
   - Example:
     - user1@tenant -> advisor-001
     - user2@tenant -> advisor-003
     - user3@tenant -> advisor-010

5. Demo script
   - Login as user1 and run search
   - Login as user2 and run same search
   - Show different result sets due to advisor-based filtering

### 14.3 Deliverables

- Web UI for login, upload, and search
- User identity to advisor mapping table and seed data
- Context endpoint and API claim-based mapping
- Updated APIM/OpenID configuration for browser auth flow
- Demo checklist with 2-3 user walkthrough

### 14.4 Effort Estimate

- Frontend scaffold and auth: 0.5 to 1 day
- Backend identity mapping + endpoint updates: 0.5 day
- Demo users, seed, and validation: 0.5 day
- Total: 1.5 to 2 days

---

## Troubleshooting

### Issue: Terraform Apply Fails

**Symptoms**: Error creating resources

**Solutions**:
1. Check quota limits: `az vm list-usage --location centralus --output table`
2. Verify subscription permissions
3. Check resource name availability: `az cognitiveservices account check-name-availability`
4. Review detailed error in terraform output

### Issue: Function App Deployment Fails

**Symptoms**: `func azure functionapp publish` errors

**Solutions**:
1. Ensure Python version matches (3.11)
2. Check virtual environment is activated
3. Verify `requirements.txt` is present
4. Try deploying without virtual env: `func azure functionapp publish <name> --python --build remote`

### Issue: SQL Connection Fails

**Symptoms**: Function logs show SQL errors

**Solutions**:
1. Verify ODBC Driver 18 installed:
   ```powershell
   Get-OdbcDriver | Where-Object {$_.Name -like "*SQL Server*"}
   ```
2. Ensure Function App has SQL user created (Step 9.1)
3. Check firewall rules allow Azure services
4. Test connection from Cloud Shell:
   ```bash
   sqlcmd -S <server>.database.windows.net -d <database> -G -Q "SELECT 1"
   ```

### Issue: Search Index Creation Fails

**Symptoms**: 401 Unauthorized or 403 Forbidden

**Solutions**:
1. Verify admin key is correct
2. Check index definition JSON is valid
3. Ensure search service is fully provisioned
4. Try using Azure Portal to create index manually

### Issue: OpenAI Deployment Not Available

**Symptoms**: 404 or quota errors

**Solutions**:
1. Check region availability: https://learn.microsoft.com/azure/ai-services/openai/concepts/models#model-summary-table-and-region-availability
2. Request quota increase via Azure Portal
3. Try different region (update `openai_location` variable)
4. Use existing OpenAI service if available

### Issue: OAuth Token Invalid

**Symptoms**: 401 Unauthorized from APIM

**Solutions**:
1. Verify app registration configuration
2. Check token audience matches API
3. Ensure APIM OAuth validation policy is correct
4. Use jwt.ms to decode and verify token claims

---

## Post-Deployment Tasks

### 1. Enable Diagnostic Logging

```powershell
# Function App
az monitor diagnostic-settings create `
    --name func-diagnostics `
    --resource $(az functionapp show -n $functionAppName -g aisearch-demo --query id -o tsv) `
    --workspace $(az monitor log-analytics workspace show -n aisearch-logs-* -g aisearch-demo --query id -o tsv) `
    --logs '[{"category":"FunctionAppLogs","enabled":true}]' `
    --metrics '[{"category":"AllMetrics","enabled":true}]'

# API Management
az monitor diagnostic-settings create `
    --name apim-diagnostics `
    --resource $(az apim show -n $apimName -g aisearch-demo --query id -o tsv) `
    --workspace $(az monitor log-analytics workspace show -n aisearch-logs-* -g aisearch-demo --query id -o tsv) `
    --logs '[{"category":"GatewayLogs","enabled":true}]' `
    --metrics '[{"category":"AllMetrics","enabled":true}]'
```

### 2. Set Up Alerts

Create alerts for:
- Function execution failures > 5 in 5 minutes
- APIM 5xx responses > 10 in 5 minutes
- Search service throttling events

### 3. Document Custom Configuration

Update `.azure/deployment-plan.md` with:
- Entra ID app registration details
- Custom configurations
- Known issues

---

## Cleanup

To delete all resources:

```powershell
cd infra

# Destroy all resources
terraform destroy

# Confirm with: yes

# Delete Entra ID app registration
az ad app delete --id $appId
```

**Warning**: This is irreversible!

---

## Next Steps

1. ✅ Deploy infrastructure
2. ✅ Test basic functionality
3. 📘 Review [API Reference](API.md)
4. 📘 Understand [Architecture](ARCHITECTURE.md)
5. 🚀 Load sample documents
6. 🎯 Configure production settings
7. 📊 Set up monitoring dashboards

---

## Support

- Azure AI Search: [Documentation](https://learn.microsoft.com/azure/search/)
- Azure Functions: [Documentation](https://learn.microsoft.com/azure/azure-functions/)
- Terraform: [Azure Provider](https://registry.terraform.io/providers/hashicorp/azurerm/latest/docs)
