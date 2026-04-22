# API Reference

Complete API documentation for the Azure AI Search Security Demo.

---

## Base URL

```
https://<apim-gateway-url>/
```

Get your gateway URL from Terraform outputs:
```powershell
terraform output apim_gateway_url
```

---

## Authentication

All API endpoints require **OAuth 2.0 Bearer Token** authentication via Microsoft Entra ID.

### Get Access Token

**Token Endpoint**:
```
POST https://login.microsoftonline.com/<tenant-id>/oauth2/v2.0/token
```

**Request Body** (application/x-www-form-urlencoded):
```
client_id=<your-client-id>
client_secret=<your-client-secret>
scope=<client-id>/.default
grant_type=client_credentials
```

**Example (PowerShell)**:
```powershell
$tokenResponse = Invoke-RestMethod `
    -Uri "https://login.microsoftonline.com/$tenantId/oauth2/v2.0/token" `
    -Method POST `
    -Body @{
        client_id     = $clientId
        client_secret = $clientSecret
        scope         = "$clientId/.default"
        grant_type    = "client_credentials"
    }

$accessToken = $tokenResponse.access_token
```

**Example (curl)**:
```bash
curl -X POST "https://login.microsoftonline.com/$TENANT_ID/oauth2/v2.0/token" \
  -H "Content-Type: application/x-www-form-urlencoded" \
  -d "client_id=$CLIENT_ID" \
  -d "client_secret=$CLIENT_SECRET" \
  -d "scope=$CLIENT_ID/.default" \
  -d "grant_type=client_credentials"
```

**Response**:
```json
{
  "token_type": "Bearer",
  "expires_in": 3599,
  "access_token": "eyJ0eXAiOiJKV1QiLCJhbGc..."
}
```

### Use Access Token

Include in all requests:
```
Authorization: Bearer <access-token>
```

---

## Endpoints

### 0. User Context

Resolve logged-in identity to advisor mapping for UI/demo usage.

**Request**:
```
GET /me-context
```

**Headers**:
```
Authorization: Bearer <token>
```

**Response** (200 OK):
```json
{
  "authenticated": true,
  "mapped": true,
  "mappingSource": "sql",
  "oid": "<entra-object-id>",
  "upn": "advisor1@contoso.com",
  "advisorId": "advisor-001",
  "advisorName": "Sarah Johnson"
}
```

**Response** (404 Not Found):
```json
{
  "authenticated": true,
  "mapped": false,
  "message": "User not mapped to advisor. Add row in UserIdentityMap or USER_ADVISOR_MAP_JSON."
}
```

---

### 1. Health Check

Check API and service health.

**Request**:
```
GET /health
```

**Headers**:
```
Authorization: Bearer <token>
```

**Response** (200 OK):
```json
{
  "status": "healthy",
  "timestamp": "2024-01-15T10:30:00Z",
  "checks": {
    "environment": "ok",
    "search": "ok",
    "sql": "ok",
    "openai": "ok"
  }
}
```

**Response** (503 Service Unavailable):
```json
{
  "status": "unhealthy",
  "timestamp": "2024-01-15T10:30:00Z",
  "checks": {
    "environment": "ok",
    "search": "ok",
    "sql": "error",
    "openai": "ok"
  },
  "errors": [
    "SQL database connection failed"
  ]
}
```

**Example**:
```powershell
$headers = @{ "Authorization" = "Bearer $accessToken" }
Invoke-RestMethod -Uri "$apimUrl/health" -Headers $headers
```

---

### 2. Search Documents

Search documents with vector, keyword, or hybrid search.

**Request**:
```
POST /search
```

**Headers**:
```
Authorization: Bearer <token>
Content-Type: application/json
```

**Body**:
```json
{
  "query": "sustainable investment opportunities ESG",
  "advisorId": "advisor-001",
  "searchType": "hybrid",
  "top_k": 10
}
```

**Parameters**:
| Field | Type | Required | Description |
|-------|------|----------|-------------|
| `query` | string | Yes | Search query text |
| `advisorId` | string | Yes | Advisor identifier (e.g., "advisor-001") |
| `searchType` | string | No | "vector", "keyword", or "hybrid" (default: "hybrid") |
| `top_k` | integer | No | Number of results to return (default: 10, max: 50) |

**Response** (200 OK):
```json
{
  "query": "sustainable investment opportunities ESG",
  "searchType": "hybrid",
  "advisorId": "advisor-001",
  "count": 3,
  "results": [
    {
      "id": "doc-001",
      "title": "Q4 2024 ESG Investment Analysis",
      "content": "Our comprehensive analysis of environmental, social, and governance...",
      "summary": "Our comprehensive analysis of environmental, social, and governance factors reveals strong performance in renewable energy sectors...",
      "clientId": "client-005",
      "documentType": "market-analysis",
      "date": "2024-01-10",
      "score": 0.92
    },
    {
      "id": "doc-015",
      "title": "Sustainable Portfolio Recommendations 2024",
      "content": "Based on current market trends, we recommend increasing exposure to...",
      "summary": "Based on current market trends, we recommend increasing exposure to green bonds and sustainable infrastructure...",
      "clientId": "client-012",
      "documentType": "portfolio-recommendation",
      "date": "2024-01-08",
      "score": 0.87
    }
  ]
}
```

**Response** (400 Bad Request):
```json
{
  "error": "Invalid request",
  "message": "Missing required field: advisorId"
}
```

**Response** (403 Forbidden):
```json
{
  "error": "Access denied",
  "message": "Advisor not found or inactive"
}
```

**Examples**:

**Vector Search** (Semantic):
```powershell
$searchRequest = @{
    query = "high-risk emerging markets with growth potential"
    advisorId = "advisor-001"
    searchType = "vector"
    top_k = 5
} | ConvertTo-Json

Invoke-RestMethod `
    -Uri "$apimUrl/search" `
    -Method POST `
    -Headers $headers `
    -Body $searchRequest
```

**Keyword Search**:
```bash
curl -X POST "$APIM_URL/search" \
  -H "Authorization: Bearer $TOKEN" \
  -H "Content-Type: application/json" \
  -d '{
    "query": "dividend stocks tech sector",
    "advisorId": "advisor-002",
    "searchType": "keyword",
    "top_k": 10
  }'
```

**Hybrid Search** (Recommended):
```python
import requests

response = requests.post(
    f"{apim_url}/search",
    headers={"Authorization": f"Bearer {access_token}"},
    json={
        "query": "Q1 portfolio rebalancing strategies",
        "advisorId": "advisor-003",
        "searchType": "hybrid",
        "top_k": 15
    }
)

results = response.json()
for doc in results["results"]:
    print(f"{doc['score']:.2f} - {doc['title']}")
```

---

### 3. Upload Document

Upload a new document to the search index.

**Request**:
```
POST /documents
```

**Headers**:
```
Authorization: Bearer <token>
Content-Type: application/json
```

**Body**:
```json
{
  "title": "Q1 2024 Market Outlook - Client 025",
  "content": "The first quarter of 2024 presents unique opportunities in the technology sector. Our analysis suggests a strategic shift towards AI-driven companies with strong fundamentals. We recommend a diversified approach focusing on both established tech giants and promising startups in the machine learning space. Risk assessment indicates moderate volatility with potential for 15-20% returns over the next 12 months.",
  "clientId": "client-025",
  "documentType": "market-analysis",
  "allowedAdvisors": ["advisor-001", "advisor-003", "advisor-005"]
}
```

**Parameters**:
| Field | Type | Required | Description |
|-------|------|----------|-------------|
| `title` | string | Yes | Document title (max 500 chars) |
| `content` | string | Yes | Document content (max 100KB) |
| `clientId` | string | Yes | Client identifier (e.g., "client-001") |
| `documentType` | string | No | Type: "market-analysis", "portfolio-recommendation", "research-report", etc. |
| `allowedAdvisors` | array[string] | Yes | Array of advisor IDs with access (e.g., ["advisor-001", "advisor-002"]) |

**Response** (201 Created):
```json
{
  "id": "doc-8f3c2a91",
  "title": "Q1 2024 Market Outlook - Client 025",
  "status": "indexed",
  "message": "Document successfully uploaded and indexed",
  "timestamp": "2024-01-15T10:45:23Z"
}
```

**Response** (400 Bad Request):
```json
{
  "error": "Validation error",
  "message": "Invalid clientId format. Must match pattern: client-XXX"
}
```

**Response** (500 Internal Server Error):
```json
{
  "error": "Indexing failed",
  "message": "Failed to generate embedding for document content"
}
```

**Examples**:

```powershell
$document = @{
    title = "Tech Sector Analysis - Client 042"
    content = "Based on our comprehensive research of the technology sector, we identify three key trends driving growth in 2024: artificial intelligence integration, cloud infrastructure expansion, and cybersecurity innovations. Companies with strong positions in these areas are expected to outperform market averages. We recommend a portfolio allocation of 40% established tech leaders, 35% mid-cap growth stocks, and 25% emerging AI startups."
    clientId = "client-042"
    documentType = "research-report"
    allowedAdvisors = @("advisor-007", "advisor-008")
} | ConvertTo-Json

$response = Invoke-RestMethod `
    -Uri "$apimUrl/documents" `
    -Method POST `
    -Headers $headers `
    -Body $document

Write-Host "Document ID: $($response.id)"
```

```bash
curl -X POST "$APIM_URL/documents" \
  -H "Authorization: Bearer $TOKEN" \
  -H "Content-Type: application/json" \
  -d '{
    "title": "Dividend Growth Strategy - Client 018",
    "content": "Our dividend growth strategy focuses on companies with consistent payout histories and strong cash flows. Target allocation includes 60% blue-chip dividend aristocrats, 30% high-yield REITs, and 10% dividend growth ETFs. Expected annual yield: 4.5-5.2%.",
    "clientId": "client-018",
    "documentType": "portfolio-recommendation",
    "allowedAdvisors": ["advisor-002", "advisor-004"]
  }'
```

---

### 4. Get Document

Retrieve a specific document by ID (with security check).

**Request**:
```
GET /documents/{documentId}?advisorId={advisorId}
```

**Path Parameters**:
| Parameter | Type | Required | Description |
|-----------|------|----------|-------------|
| `documentId` | string | Yes | Document ID (e.g., "doc-001") |

**Query Parameters**:
| Parameter | Type | Required | Description |
|-----------|------|----------|-------------|
| `advisorId` | string | Yes | Advisor identifier for authorization |

**Headers**:
```
Authorization: Bearer <token>
```

**Response** (200 OK):
```json
{
  "id": "doc-001",
  "title": "Q4 2024 ESG Investment Analysis",
  "content": "Our comprehensive analysis of environmental, social, and governance factors...",
  "summary": "Our comprehensive analysis of environmental, social...",
  "clientId": "client-005",
  "documentType": "market-analysis",
  "date": "2024-01-10",
  "allowedAdvisors": ["advisor-001", "advisor-002", "advisor-003"]
}
```

**Response** (403 Forbidden):
```json
{
  "error": "Access denied",
  "message": "Advisor advisor-005 does not have access to document doc-001"
}
```

**Response** (404 Not Found):
```json
{
  "error": "Not found",
  "message": "Document doc-999 not found"
}
```

**Examples**:

```powershell
$documentId = "doc-001"
$advisorId = "advisor-001"

$document = Invoke-RestMethod `
    -Uri "$apimUrl/documents/${documentId}?advisorId=$advisorId" `
    -Headers $headers

Write-Host "Title: $($document.title)"
Write-Host "Client: $($document.clientId)"
```

```bash
curl -X GET "$APIM_URL/documents/doc-001?advisorId=advisor-002" \
  -H "Authorization: Bearer $TOKEN"
```

---

## Error Responses

### Standard Error Format

All errors follow this structure:

```json
{
  "error": "Error type",
  "message": "Detailed error message",
  "timestamp": "2024-01-15T10:30:00Z",
  "correlationId": "abc123-def456-ghi789"
}
```

### HTTP Status Codes

| Code | Description | Common Causes |
|------|-------------|---------------|
| 200 | OK | Request successful |
| 201 | Created | Document uploaded successfully |
| 400 | Bad Request | Invalid parameters, missing fields |
| 401 | Unauthorized | Missing or invalid access token |
| 403 | Forbidden | Insufficient permissions, advisor access denied |
| 404 | Not Found | Document or resource not found |
| 429 | Too Many Requests | Rate limit exceeded (100 req/min) |
| 500 | Internal Server Error | Service failure, contact support |
| 503 | Service Unavailable | Dependency unavailable (Search, SQL, OpenAI) |

---

## Rate Limiting

**Limits**:
- **100 requests per minute** per API subscription key
- Rate limit applies across all endpoints

**Headers in Response**:
```
X-RateLimit-Limit: 100
X-RateLimit-Remaining: 73
X-RateLimit-Reset: 1705318260
```

**Rate Limit Exceeded Response** (429):
```json
{
  "error": "Rate limit exceeded",
  "message": "You have exceeded the rate limit of 100 requests per minute",
  "retryAfter": 45
}
```

---

## CORS

CORS is enabled for the following origins (configure in APIM policy):
- `http://localhost:3000` (local development)
- `https://yourdomain.com` (production)

**Allowed Methods**: GET, POST, OPTIONS  
**Allowed Headers**: Authorization, Content-Type  
**Exposed Headers**: X-RateLimit-Limit, X-RateLimit-Remaining

---

## Examples: Complete Workflows

### Workflow 1: Search for Documents

```python
import requests

# Configuration
apim_url = "https://aisearch-apim-abc123.azure-api.net"
tenant_id = "your-tenant-id"
client_id = "your-client-id"
client_secret = "your-client-secret"

# Step 1: Get access token
token_response = requests.post(
    f"https://login.microsoftonline.com/{tenant_id}/oauth2/v2.0/token",
    data={
        "client_id": client_id,
        "client_secret": client_secret,
        "scope": f"{client_id}/.default",
        "grant_type": "client_credentials"
    }
)
access_token = token_response.json()["access_token"]

# Step 2: Search
headers = {"Authorization": f"Bearer {access_token}"}
search_response = requests.post(
    f"{apim_url}/search",
    headers=headers,
    json={
        "query": "ESG investment strategies renewable energy",
        "advisorId": "advisor-001",
        "searchType": "hybrid",
        "top_k": 5
    }
)

# Step 3: Display results
search_data = search_response.json()
print(f"Found {search_data['count']} documents:")
for doc in search_data["results"]:
    print(f"\n[{doc['score']:.2f}] {doc['title']}")
    print(f"Client: {doc['clientId']} | Type: {doc['documentType']}")
    print(f"Summary: {doc['summary'][:150]}...")
```

### Workflow 2: Upload and Verify

```powershell
# Configuration
$apimUrl = "https://aisearch-apim-abc123.azure-api.net"
$accessToken = "<your-access-token>"

$headers = @{
    "Authorization" = "Bearer $accessToken"
    "Content-Type" = "application/json"
}

# Step 1: Upload document
$newDoc = @{
    title = "Emerging Markets Analysis - Client 033"
    content = "Emerging markets in Southeast Asia show strong recovery post-pandemic. Key opportunities exist in Vietnam, Indonesia, and Thailand. Recommended allocation: 30% Vietnamese equities, 45% Indonesian infrastructure bonds, 25% Thai real estate. Expected returns: 12-18% annually with moderate risk."
    clientId = "client-033"
    documentType = "market-analysis"
    allowedAdvisors = @("advisor-006")
} | ConvertTo-Json

$uploadResponse = Invoke-RestMethod `
    -Uri "$apimUrl/documents" `
    -Method POST `
    -Headers $headers `
    -Body $newDoc

$documentId = $uploadResponse.id
Write-Host "Uploaded document: $documentId"

# Step 2: Wait for indexing (small delay)
Start-Sleep -Seconds 2

# Step 3: Retrieve document
$retrievedDoc = Invoke-RestMethod `
    -Uri "$apimUrl/documents/${documentId}?advisorId=advisor-006" `
    -Headers $headers

Write-Host "Retrieved: $($retrievedDoc.title)"

# Step 4: Search for it
$searchRequest = @{
    query = "Southeast Asia emerging markets Vietnam"
    advisorId = "advisor-006"
    searchType = "hybrid"
    top_k = 5
} | ConvertTo-Json

$searchResponse = Invoke-RestMethod `
    -Uri "$apimUrl/search" `
    -Method POST `
    -Headers $headers `
    -Body $searchRequest

# Verify document appears in search
$found = $searchResponse.results | Where-Object { $_.id -eq $documentId }
if ($found) {
    Write-Host "✓ Document found in search results with score: $($found.score)"
} else {
    Write-Host "✗ Document not found in search results"
}
```

---

## Postman Collection

Import this collection for quick testing:

```json
{
  "info": {
    "name": "Azure AI Search Security Demo",
    "schema": "https://schema.getpostman.com/json/collection/v2.1.0/collection.json"
  },
  "auth": {
    "type": "oauth2",
    "oauth2": [{
      "key": "tokenUrl",
      "value": "https://login.microsoftonline.com/{{tenant_id}}/oauth2/v2.0/token",
      "type": "string"
    }]
  },
  "variable": [
    {"key": "apim_url", "value": "https://your-apim.azure-api.net"},
    {"key": "tenant_id", "value": "your-tenant-id"},
    {"key": "client_id", "value": "your-client-id"},
    {"key": "client_secret", "value": "your-client-secret"}
  ],
  "item": [
    {
      "name": "Health Check",
      "request": {
        "method": "GET",
        "url": "{{apim_url}}/health"
      }
    },
    {
      "name": "Search - Hybrid",
      "request": {
        "method": "POST",
        "url": "{{apim_url}}/search",
        "body": {
          "mode": "raw",
          "raw": "{\n  \"query\": \"technology investment trends AI\",\n  \"advisorId\": \"advisor-001\",\n  \"searchType\": \"hybrid\",\n  \"top_k\": 10\n}"
        }
      }
    },
    {
      "name": "Upload Document",
      "request": {
        "method": "POST",
        "url": "{{apim_url}}/documents",
        "body": {
          "mode": "raw",
          "raw": "{\n  \"title\": \"Test Document\",\n  \"content\": \"This is a test document for API verification\",\n  \"clientId\": \"client-001\",\n  \"documentType\": \"test\",\n  \"allowedAdvisors\": [\"advisor-001\"]\n}"
        }
      }
    },
    {
      "name": "Get Document",
      "request": {
        "method": "GET",
        "url": "{{apim_url}}/documents/doc-001?advisorId=advisor-001"
      }
    }
  ]
}
```

Save as `postman_collection.json` and import into Postman.

---

## Testing Checklist

- [ ] Health endpoint returns 200 OK
- [ ] OAuth token obtained successfully
- [ ] Upload document returns 201 Created
- [ ] Vector search returns relevant results
- [ ] Keyword search returns matching documents
- [ ] Hybrid search combines both approaches
- [ ] Security filter blocks unauthorized access
- [ ] Get document validates advisor access
- [ ] Rate limiting enforced (429 after 100 requests)
- [ ] CORS headers present in responses

---

## Additional Resources

- [Azure AI Search REST API](https://learn.microsoft.com/rest/api/searchservice/)
- [Azure Functions HTTP Triggers](https://learn.microsoft.com/azure/azure-functions/functions-bindings-http-webhook-trigger)
- [OAuth 2.0 Client Credentials Flow](https://learn.microsoft.com/azure/active-directory/develop/v2-oauth2-client-creds-grant-flow)
- [API Management Policies](https://learn.microsoft.com/azure/api-management/api-management-policies)
