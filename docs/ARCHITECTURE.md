# Architecture Guide

## System Overview

The Azure AI Search Security Demo is a multi-tier application demonstrating enterprise-grade search with document-level security for capital markets scenarios.

### Key Components

1. **API Management** - Gateway, authentication, rate limiting
2. **Azure Functions** - Serverless compute for API and ingestion
3. **Azure AI Search** - Full-text, vector, and hybrid search
4. **Azure SQL Database** - Access control metadata
5. **Azure OpenAI** - Embedding generation
6. **Blob Storage** - Document storage
7. **Web UI** - Browser-based demo app for login, search, and upload
8. **Microsoft Entra ID** - Interactive user authentication for demo identities

---

## Architecture Diagram

```
┌─────────────────────────────────────────────────────────────┐
│                      Client Applications                    │
│              (Web, Mobile, Desktop, APIs)                   │
└────────────────────┬────────────────────────────────────────┘
                     │ HTTPS + OAuth 2.0
                     │
┌────────────────────▼────────────────────────────────────────┐
│                   API Management (APIM)                      │
│  ┌──────────────────────────────────────────────────────┐   │
│  │ • OAuth 2.0 JWT Validation (Entra ID)               │   │
│  │ • Rate Limiting (100 req/min per subscription)       │   │
│  │ • Request/Response Transformation                    │   │
│  │ • Correlation ID Injection                           │   │
│  │ • CORS Policy                                        │   │
│  └──────────────────────────────────────────────────────┘   │
└────────────────────┬────────────────────────────────────────┘
                     │ Function Key
                     │
┌────────────────────▼────────────────────────────────────────┐
│              Azure Functions (Premium EP1)                   │
│                                                              │
│  ┌───────────────────────┐   ┌─────────────────────────┐    │
│  │    Search API         │   │  Document Ingestion     │    │
│  │  ┌─────────────────┐  │   │  ┌──────────────────┐   │    │
│  │  │ POST /search    │  │   │  │ POST /documents  │   │    │
│  │  │ • Vector Search │  │   │  │ • Generate       │   │    │
│  │  │ • Hybrid Search │  │   │  │   Embeddings     │   │    │
│  │  │ • Keyword Search│  │   │  │ • Index Document │   │    │
│  │  │ • Security      │  │   │  │ • Set Security   │   │    │
│  │  │   Filtering     │  │   │  │   Tags           │   │    │
│  │  └─────────────────┘  │   │  └──────────────────┘   │    │
│  │  ┌─────────────────┐  │   │                          │    │
│  │  │ GET /documents  │  │   │  Blob Trigger (Future)   │    │
│  │  │   /{id}         │  │   │  Auto-index on upload    │    │
│  │  └─────────────────┘  │   └─────────────────────────┘    │
│  │  ┌─────────────────┐  │                                   │
│  │  │ GET /health     │  │                                   │
│  │  └─────────────────┘  │                                   │
│  └───────────────────────┘                                   │
│                                                              │
│  System-Assigned Managed Identity                           │
└──┬─────────────────┬────────────────────┬────────────────┬──┘
   │                 │                    │                │
   │ RBAC:           │ RBAC:              │ RBAC:          │ Token Auth
   │ Search Index    │ Storage Blob       │ Cognitive      │
   │ Data Reader +   │ Data Contributor   │ Services       │
   │ Contributor     │                    │ OpenAI User    │
   │                 │                    │                │
   ▼                 ▼                    ▼                ▼
┌──────────┐   ┌──────────┐   ┌──────────────┐   ┌──────────────┐
│  Azure   │   │  Blob    │   │   Azure      │   │  Azure SQL   │
│  AI      │   │ Storage  │   │   OpenAI     │   │  Database    │
│ Search   │   │          │   │              │   │              │
│          │   │ documents│   │ Embeddings:  │   │ Tables:      │
│ Index:   │   │ container│   │ text-        │   │ • Advisors   │
│ capital- │   │          │   │ embedding-   │   │ • Clients    │
│ markets- │   │          │   │ ada-002      │   │ • Advisor    │
│ docs     │   │          │   │              │   │   Client     │
│          │   │          │   │ (1536 dims)  │   │   Access     │
│ Fields:  │   │          │   │              │   │              │
│ • id     │   │          │   │              │   │ Entra ID     │
│ • title  │   │          │   │              │   │ Auth Only    │
│ • content│   │          │   │              │   │              │
│ • vector │   │          │   │              │   │              │
│ • allowed│   │          │   │              │   │              │
│   Advisors│  │          │   │              │   │              │
└──────────┘   └──────────┘   └──────────────┘   └──────────────┘
     │                                                    │
     │                                                    │
     └────────Semantic Search with Security Filter───────┘
```

---

## Data Flow

### 0. User Login and Advisor Context Resolution

```
User -> Web UI -> Entra ID -> APIM -> Function (/api/me/context) -> SQL UserIdentityMap -> UI Session Context
```

**Steps**:
1. User logs in via Entra ID from the Web UI
2. Web UI sends bearer token to APIM
3. APIM validates JWT
4. Function extracts `oid` or `upn` from claims
5. Function resolves `advisorId` from SQL `UserIdentityMap`
6. UI stores resolved advisor context for searches and uploads

### 1. Search Request Flow

```
User → APIM → Function → SQL (Get Allowed Clients) → AI Search (with filter) → Function → APIM → User
```

**Steps**:
1. User sends search request with OAuth token (advisorId can be omitted by UI)
2. APIM validates JWT token (Entra ID)
3. APIM forwards to Function with correlation ID
4. Function resolves advisorId from identity mapping (or uses provided advisorId for internal testing)
5. Function queries SQL for advisor's allowed clients
6. Function builds security filter: `search.in(allowedAdvisors, 'advisor-001', ',')`
7. Function generates query embedding (for vector/hybrid search)
8. AI Search executes search with security filter
9. Results returned only for accessible documents
10. Function formats and returns response

### 2. Document Ingestion Flow

```
User → APIM → Function → OpenAI (Generate Embedding) → AI Search (Index) → Function → User
```

**Steps**:
1. User uploads document with metadata (title, content, clientId, allowedAdvisors)
2. Function validates required fields
3. Function generates summary (first 200 chars)
4. Function calls Azure OpenAI to generate content embedding
5. Function prepares search document with all fields + vector
6. Function indexes document in AI Search
7. Success response returned

---

## Security Architecture

### Authentication & Authorization

```
┌─────────────────────────────────────────────────────────┐
│                   Microsoft Entra ID                    │
│  (Azure Active Directory)                               │
│                                                         │
│  • Application Registration                            │
│  • OAuth 2.0 / OIDC                                    │
│  • JWT Token Issuance                                  │
│  • Claims: sub, oid, roles, etc.                       │
└────────────────────┬────────────────────────────────────┘
                     │
                     │ JWT Token
                     ▼
    ┌────────────────────────────────────────────┐
    │          API Management                    │
    │                                            │
    │  validate-jwt policy:                      │
    │  • Verify signature                        │
    │  • Check expiration                        │
    │  • Validate audience                       │
    │  • Validate issuer                         │
    └────────────────┬───────────────────────────┘
                     │
                     │ Validated Request
                     ▼
    ┌────────────────────────────────────────────┐
    │         Azure Functions                    │
    │                                            │
    │  Extract advisorId from request or claims  │
    └────────────────┬───────────────────────────┘
                     │
                     ▼
         Query SQL for allowed clients
                     │
                     ▼
         Apply filter to AI Search query
```

### Document-Level Security

**Index Schema**:
```json
{
  "id": "doc-001",
  "title": "Q4 Portfolio Analysis - Client 005",
  "content": "...",
  "allowedAdvisors": ["advisor-001", "advisor-002"]
}
```

### Identity-to-Advisor Mapping

Add a mapping table to bind logged-in identities to advisor IDs used by filtering logic.

```sql
CREATE TABLE UserIdentityMap (
  Id INT IDENTITY(1,1) PRIMARY KEY,
  EntraObjectId NVARCHAR(64) NOT NULL,
  UserPrincipalName NVARCHAR(256) NULL,
  AdvisorId NVARCHAR(50) NOT NULL,
  IsActive BIT NOT NULL DEFAULT 1,
  CreatedAt DATETIME2 NOT NULL DEFAULT SYSUTCDATETIME()
);
```

This table enables the demo to show different results for different signed-in users without requiring manual advisorId input.

**Query-Time Filter**:
```python
# Only documents where allowedAdvisors contains the requesting advisor
filter = f"search.in(allowedAdvisors, '{advisor_id}', ',')"

search_client.search(
    search_text=query,
    filter=filter,  # Security enforcement
    ...
)
```

**SQL Access Control**:
```sql
-- Get clients accessible by advisor
SELECT c.ClientId
FROM AdvisorClientAccess aca
INNER JOIN Clients c ON aca.ClientId = c.Id
WHERE aca.AdvisorId = (
    SELECT Id FROM Advisors WHERE AdvisorId = 'advisor-001'
)
AND aca.IsActive = 1
```

---

## Search Capabilities

### 1. Vector Search

**Use Case**: Semantic similarity, conceptual search

**How it works**:
1. Query text → Azure OpenAI → 1536-dim embedding vector
2. AI Search compares query vector with document vectors (cosine similarity)
3. Returns documents with highest semantic similarity

**Example**:
```
Query: "sustainable investment opportunities"
Matches: Documents about ESG, renewable energy, green bonds
         (even if exact words don't appear)
```

### 2. Keyword Search

**Use Case**: Exact term matching, traditional search

**How it works**:
1. Query text → Linguistic analyzer (stemming, tokenization)
2. AI Search matches terms in inverted index
3. BM25 ranking algorithm

**Example**:
```
Query: "dividend stocks"
Matches: Documents containing "dividend", "dividends", etc.
```

### 3. Hybrid Search (Recommended)

**Use Case**: Best of both worlds

**How it works**:
1. Parallel execution of vector + keyword search
2. Reciprocal Rank Fusion (RRF) combines scores
3. Optional semantic reranking

**Example**:
```
Query: "Q4 market volatility"
Combines: Keyword matches + Semantic similarity
Result: More accurate and comprehensive
```

### Semantic Ranking

**Configuration**:
```json
{
  "semantic": {
    "configurations": [{
      "name": "default",
      "prioritizedFields": {
        "titleField": "title",
        "contentFields": ["content"],
        "keywordsFields": ["documentType"]
      }
    }]
  }
}
```

**Benefits**:
- Deep learning models re-rank results
- Understands query intent
- Improves relevance

---

## Managed Identity & RBAC

### Identity Flow

```
Azure Function (System-Assigned MI)
    ↓
    ├─→ AI Search: Search Index Data Reader + Contributor
    ├─→ Storage: Storage Blob Data Contributor
    ├─→ OpenAI: Cognitive Services OpenAI User
    ├─→ SQL: Entra ID authentication
    └─→ Key Vault: Key Vault Secrets User
```

### Benefits

- **No credentials in code or config**
- Automatic token refresh
- Azure AD centralized access control
- Audit trail in Azure AD logs

---

## Scalability & Performance

### Auto-Scaling

- **Azure Functions**: Premium Plan (EP1) with auto-scale
- **AI Search**: Standard S1 (can scale replicas/partitions)
- **SQL Database**: DTU-based (can upgrade SKU)

### Caching Opportunities

1. **SQL query results** (advisor → clients mapping)
   - Cache in Function memory (5-15 min TTL)
2. **Search client** (singleton pattern)
3. **OpenAI client** (singleton pattern)

### Performance Optimizations

- **Vector search**: HNSW algorithm (fast approximate nearest neighbor)
- **SQL indexes**: On AdvisorId, ClientId for fast lookups
- **Search index**: Optimized field configuration

---

## Monitoring & Observability

### Application Insights

- **Metrics**: Request rate, latency, failures
- **Logs**: Structured logging from Functions
- **Distributed Tracing**: End-to-end request tracking
- **Correlation IDs**: Trace requests across services

### Key Metrics to Monitor

1. **Search latency** (p50, p95, p99)
2. **Function execution time**
3. **SQL query duration**
4. **OpenAI API latency**
5. **Rate limit hits**
6. **Authentication failures**

---

## Cost Optimization

### Recommendations

1. **Reserved Capacity**: For production workloads
2. **Right-size SKUs**: Start small, scale based on metrics
3. **Embedding caching**: Cache frequently-searched query embeddings
4. **Batch operations**: Bulk document indexing
5. **Index optimization**: Remove unused fields

---

## Future Enhancements

1. **Blob Trigger Function**: Auto-index documents on upload
2. **Change Feed**: Real-time SQL → Search sync
3. **Redis Cache**: Distributed caching layer
4. **Power BI**: Analytics dashboard
5. **Azure Front Door**: Global load balancing
6. **AI Enrichment**: Extract entities, key phrases via AI
7. **Document Intelligence**: OCR for scanned documents

---

## References

- [Azure AI Search Documentation](https://learn.microsoft.com/azure/search/)
- [Vector Search in Azure AI Search](https://learn.microsoft.com/azure/search/vector-search-overview)
- [Azure Functions Best Practices](https://learn.microsoft.com/azure/azure-functions/functions-best-practices)
- [Azure SQL Managed Identity](https://learn.microsoft.com/azure/azure-sql/database/authentication-aad-configure)
