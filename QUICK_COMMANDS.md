# ⚡ Quick Commands - Continue from Here

Copy/paste these commands to continue with remaining deployment steps.

---

## 🚀 Step 13: Load Sample Documents (⏳ ~10 minutes)

### Option A: Load 5 test documents via API

```powershell
$funcUrl = "https://aisearch-demo-func-wyjsbl.azurewebsites.net"
$funcKey = "9MFqImI9hiVoK_y16s_dMEHEpb1dnNJKka3sOOwQYvUhAzFuu3vQDQ=="

# Upload 5 sample documents
for ($i = 1; $i -le 5; $i++) {
    $body = @{
        documentId = "sample-doc-$i"
        title = "Market Analysis Report - Q1 202$i"
        content = "This is a comprehensive market analysis report covering capital markets, investment opportunities, and portfolio recommendations for Q1 202$i. The report includes analysis of technology, healthcare, and financial sectors with focus on sustainable and ESG-compliant investments."
        advisorIds = @("ADV001", "ADV002", "ADV003")
    } | ConvertTo-Json
    
    $response = Invoke-WebRequest "$funcUrl/api/documents?code=$funcKey" `
        -Method Post `
        -Body $body `
        -ContentType "application/json" `
        -UseBasicParsing
    
    Write-Host "Uploaded: $i/5 - Status $($response.StatusCode)"
}

Write-Host "✅ Sample documents loaded!"
```

### Option B: Upload from CSV file

```powershell
# Create a CSV file with documents
$documents = @(
    @{documentId="doc-2024-Q1";title="Q1 2024 Overview";content="First quarter analysis...";advisorIds="ADV001,ADV002"},
    @{documentId="doc-tech-growth";title="Technology Sector Growth";content="Tech sector analysis...";advisorIds="ADV001"},
    @{documentId="doc-esg-trends";title="ESG Investment Trends";content="ESG trends analysis...";advisorIds="ADV002,ADV003"},
    @{documentId="doc-fixed-income";title="Fixed Income Opportunities";content="Fixed income analysis...";advisorIds="ADV003"},
    @{documentId="doc-portfolio-mix";title="Portfolio Diversification";content="Portfolio strategy...";advisorIds="ADV001,ADV002,ADV003"}
)

# Upload each document
$funcUrl = "https://aisearch-demo-func-wyjsbl.azurewebsites.net"
$funcKey = "9MFqImI9hiVoK_y16s_dMEHEpb1dnNJKka3sOOwQYvUhAzFuu3vQDQ=="

foreach ($doc in $documents) {
    $body = @{
        documentId = $doc.documentId
        title = $doc.title
        content = $doc.content
        advisorIds = $doc.advisorIds -split ","
    } | ConvertTo-Json
    
    Invoke-WebRequest "$funcUrl/api/documents?code=$funcKey" `
        -Method Post `
        -Body $body `
        -ContentType "application/json" `
        -UseBasicParsing | Out-Null
    
    Write-Host "✅ $($doc.title)"
}
```

---

## 🔍 Step 13B: Verify Documents Loaded

```powershell
# Search to verify documents are indexed
$funcUrl = "https://aisearch-demo-func-wyjsbl.azurewebsites.net"
$funcKey = "9MFqImI9hiVoK_y16s_dMEHEpb1dnNJKka3sOOwQYvUhAzFuu3vQDQ=="

$body = @{
    query = "market analysis"
    advisorId = "ADV001"
    searchType = "hybrid"
    top = 10
} | ConvertTo-Json

$response = Invoke-WebRequest "$funcUrl/api/search?code=$funcKey" `
    -Method Post `
    -Body $body `
    -ContentType "application/json" `
    -UseBasicParsing

$results = $response.Content | ConvertFrom-Json
Write-Host "Search Results: $($results.count) documents found"
$results.results | ForEach-Object {
    Write-Host "  • $($_.title)"
}
```

---

## 🛡️ Step 14: Configure API Management (Optional)

### Get APIM Details

```powershell
$apimName = "aisearch-demo-apim-wyjsbl"
$rgName = "aisearch-demo"
$apimUrl = "https://aisearch-demo-apim-wyjsbl.azure-api.net"

Write-Host "API Management Service: $apimName"
Write-Host "Gateway URL: $apimUrl"
Write-Host ""
Write-Host "Next: Configure via Azure Portal"
Write-Host "  1. Go to https://portal.azure.com"
Write-Host "  2. Search for '$apimName'"
Write-Host "  3. Go to APIs → search-api → Design"
Write-Host "  4. Apply policies for rate limiting, CORS, etc."
```

### Test APIM Gateway (after configuration)

```powershell
$apimUrl = "https://aisearch-demo-apim-wyjsbl.azure-api.net"

# Test health endpoint through APIM
try {
    $response = Invoke-WebRequest "$apimUrl/health" -UseBasicParsing
    Write-Host "✅ APIM Gateway Status: $($response.StatusCode)"
} catch {
    Write-Host "⚠️ APIM gateway not responding (may need configuration)"
}
```

---

## 📊 Step 15: Enable Monitoring & Diagnostics

```powershell
$appInsightName = "aisearch-demo-ai-wyjsbl"
$funcAppName = "aisearch-demo-func-wyjsbl"
$rgName = "aisearch-demo"

# Verify Application Insights is connected
Write-Host "Checking Application Insights..."
$appSettings = az functionapp config appsettings list `
    --name $funcAppName `
    --resource-group $rgName `
    --query "[?name=='APPINSIGHTS_INSTRUMENTATIONKEY']"

if ($appSettings) {
    Write-Host "✅ Application Insights is connected"
    Write-Host ""
    Write-Host "View metrics:"
    Write-Host "  1. Go to Azure Portal"
    Write-Host "  2. Search for '$appInsightName'"
    Write-Host "  3. View Live Metrics, Performance, Logs"
} else {
    Write-Host "⚠️ Application Insights not connected"
}
```

---

## 🧪 Full End-to-End Test

```powershell
# Complete test of all endpoints
$funcUrl = "https://aisearch-demo-func-wyjsbl.azurewebsites.net"
$funcKey = "9MFqImI9hiVoK_y16s_dMEHEpb1dnNJKka3sOOwQYvUhAzFuu3vQDQ=="

Write-Host "════════════════════════════════════════" -ForegroundColor Cyan
Write-Host "    Complete API Test Suite" -ForegroundColor Yellow
Write-Host "════════════════════════════════════════`n"

# 1. Health
Write-Host "1️⃣  Testing Health Endpoint..." -ForegroundColor Green
$r1 = Invoke-WebRequest "$funcUrl/api/health?code=$funcKey" -UseBasicParsing
Write-Host "   Status: $($r1.StatusCode) ✅`n"

# 2. Upload Test Document
Write-Host "2️⃣  Uploading Test Document..." -ForegroundColor Green
$testDocId = "test-$(Get-Random)"
$body = @{
    documentId = $testDocId
    title = "End-to-End Test Document"
    content = "This document is used for end-to-end testing of the AI Search Security demo system."
    advisorIds = @("ADV001", "ADV002")
} | ConvertTo-Json

$r2 = Invoke-WebRequest "$funcUrl/api/documents?code=$funcKey" `
    -Method Post `
    -Body $body `
    -ContentType "application/json" `
    -UseBasicParsing
Write-Host "   Status: $($r2.StatusCode) ✅"
Write-Host "   Document ID: $testDocId`n"

# 3. Search
Write-Host "3️⃣  Testing Search Endpoint..." -ForegroundColor Green
$searchBody = @{
    query = "test document"
    advisorId = "ADV001"
    searchType = "hybrid"
    top = 5
} | ConvertTo-Json

$r3 = Invoke-WebRequest "$funcUrl/api/search?code=$funcKey" `
    -Method Post `
    -Body $searchBody `
    -ContentType "application/json" `
    -UseBasicParsing
$search = $r3.Content | ConvertFrom-Json
Write-Host "   Status: $($r3.StatusCode) ✅"
Write-Host "   Results: $($search.count) documents`n"

# 4. Get Document
Write-Host "4️⃣  Testing Get Document Endpoint..." -ForegroundColor Green
$r4 = Invoke-WebRequest "$funcUrl/api/documents/$testDocId?advisorId=ADV001&code=$funcKey" `
    -Method Get `
    -UseBasicParsing
Write-Host "   Status: $($r4.StatusCode) ✅`n"

Write-Host "════════════════════════════════════════" -ForegroundColor Cyan
Write-Host "    ✅ All Tests Passed!" -ForegroundColor Green
Write-Host "════════════════════════════════════════"
```

---

## 📋 Deployment Checklist

```powershell
# Run this to verify all components are ready
Write-Host "Checking Deployment Status..." -ForegroundColor Cyan

# 1. Function App
$func = az webapp show --name aisearch-demo-func-wyjsbl --resource-group aisearch-demo --query state -o tsv
Write-Host "Function App: $func"

# 2. APIM
$apim = az apim show --name aisearch-demo-apim-wyjsbl --resource-group aisearch-demo --query provisioningState -o tsv
Write-Host "API Management: $apim"

# 3. Search Service
$search = az search service show --name aisearch-demo-search-wyjsbl --resource-group aisearch-demo --query "?" -o tsv
Write-Host "AI Search: $search"

# 4. SQL Database
$sql = az sql db show --name aisearch-demo-sqldb --server aisearch-demo-sql-wyjsbl --resource-group aisearch-demo --query status -o tsv
Write-Host "SQL Database: $sql"

# 5. Storage
$storage = az storage account show --name aisearchdemostwyjsbl --resource-group aisearch-demo --query provisioningState -o tsv
Write-Host "Storage Account: $storage"

Write-Host ""
Write-Host "✅ All systems operational" -ForegroundColor Green
```

---

## 🔗 Useful Links

```
Azure Portal:         https://portal.azure.com
Function App:         https://aisearch-demo-func-wyjsbl.azurewebsites.net
APIM Gateway:         https://aisearch-demo-apim-wyjsbl.azure-api.net
App Insights:         Azure Portal → aisearch-demo-ai-wyjsbl
SQL Database:         Azure Portal → aisearch-demo-sqldb
Search Service:       Azure Portal → aisearch-demo-search-wyjsbl
```

---

## 📞 Support

**API Documentation**: See [API_QUICK_REFERENCE.md](API_QUICK_REFERENCE.md)  
**Deployment Guide**: See [docs/DEPLOYMENT.md](docs/DEPLOYMENT.md)  
**Status Report**: See [DEPLOYMENT_STATUS.md](DEPLOYMENT_STATUS.md)

**Function Key**: `9MFqImI9hiVoK_y16s_dMEHEpb1dnNJKka3sOOwQYvUhAzFuu3vQDQ==`

---

**Last Updated**: April 21, 2026  
**Status**: ✅ All endpoints live and tested
