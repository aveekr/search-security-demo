# Azure AI Search Security Demo - Deployment Plan

**Status**: Ready for Validation  
**Created**: 2026-04-19  
**Mode**: NEW  
**Recipe**: Terraform  
**Language**: Python 3.11  
**Target Platform**: Azure Functions (Python v2 model)  
**Region**: Central US  
**Resource Group**: aisearch-demo  
**Authentication**: OAuth 2.0  
**Sample Documents**: 18 documents created

---

## Project Overview

Capital markets demo showcasing Azure AI Search with document-level security:
- **Vector Search**: Semantic similarity search using embeddings
- **Hybrid Search**: Combined keyword + vector search for best results
- **Document-Level Security**: Advisor → Client access control via security filters
- **API Management**: Centralized gateway with authentication and rate limiting
- **Scenario**: Financial advisors access client-specific research documents

---

## Business Scenario

**Actors**:
- **Advisors**: Financial advisors who serve specific clients
- **Clients**: Individual investors with portfolios

**Access Model**:
- Each advisor has access only to their assigned clients' documents
- Security enforced at query time via Azure AI Search security filters
- Access mappings stored in Azure SQL Database

**Document Types**:
- Research reports
- Market analysis
- Client-specific recommendations
- Portfolio insights

---

## Architecture Summary

```
┌─────────────┐
│   API Mgmt  │ ← Entry point (authentication, rate limiting)
└──────┬──────┘
       │
┌──────▼───────────────────────────────────────────────┐
│  Azure Functions (Python)                            │
│  ┌────────────────┐  ┌─────────────────────┐        │
│  │ Search API     │  │ Document Ingestion  │        │
│  │ - Vector       │  │ - Upload & Index    │        │
│  │ - Hybrid       │  │ - Generate Embeddings│       │
│  │ - Security     │  │ - Set Security Tags │        │
│  └────────────────┘  └─────────────────────┘        │
└──────┬───────────────────────┬──────────────────────┘
       │                       │
┌──────▼──────────┐    ┌──────▼───────────┐
│  Azure AI Search│    │   Azure SQL DB   │
│  - Vector Index │    │  - Advisor/Client│
│  - Security     │    │    Mappings      │
│    Filters      │    │  - Permissions   │
└─────────────────┘    └──────────────────┘
       │
┌──────▼──────────┐
│  Blob Storage   │
│  - Documents    │
│  - Raw files    │
└─────────────────┘
```

---

## Components

### 1. **API Functions** (`src/api/`)
- **GET /search**: Vector and hybrid search with security filters
- **POST /documents**: Upload and index documents
- **GET /documents/{id}**: Retrieve document metadata
- **GET /health**: Health check endpoint

### 2. **Data Ingestion Functions** (`src/ingestion/`)
- **Blob Trigger**: Auto-index documents on upload
- **HTTP Trigger**: Manual document ingestion with metadata

### 3. **Sample Data** (`data/`)
- SQL scripts for advisor-client mappings
- Sample documents (PDFs, reports)
- Sample search queries

---

## Infrastructure Services (Terraform)

| Service | SKU/Tier | Purpose |
|---------|----------|---------|
| **Azure AI Search** | Standard S1 | Vector + Hybrid search, security filters |
| **Azure OpenAI** | Standard | Generate embeddings (text-embedding-ada-002) |
| **Azure Functions** | Premium EP1 | Python runtime, VNet integration capable |
| **Azure SQL Database** | Standard S0 | Advisor-client access mappings |
| **API Management** | Developer | API gateway, auth, rate limiting |
| **Storage Account** | Standard LRS | Document storage, function app storage |
| **Application Insights** | Standard | Monitoring and telemetry |
| **Key Vault** | Standard | Secrets management |
| **Managed Identity** | N/A | Passwordless authentication |

---

## Security Model

### Document-Level Filtering
1. **Index Schema**: Each document has `allowedAdvisors` field (Collection(Edm.String))
2. **Query-Time Filter**: Filter appended based on authenticated advisor ID
   ```
   search.in(allowedAdvisors, 'advisor-001,advisor-002', ',')
   ```
3. **Access Mapping**: SQL table `AdvisorClientAccess` maps advisor → clients
4. **Document Tagging**: On ingestion, documents tagged with advisor IDs who can access them

### Authentication Flow
1. Client → API Management (API key or OAuth)
2. APIM → Azure Functions (managed identity)
3. Functions → AI Search (managed identity)
4. Functions → Azure SQL (managed identity)
5. Functions → Azure OpenAI (managed identity)

---

## Execution Steps

### Phase 1: Infrastructure (Terraform)
- [x] Create deployment plan
- [x] User approval received
- [ ] Generate Terraform modules
  - [ ] Resource group
  - [ ] Azure AI Search with vector configuration
  - [ ] Azure OpenAI deployment
  - [ ] Azure Functions with Python runtime
  - [ ] Azure SQL with Entra ID authentication
  - [ ] API Management
  - [ ] Storage Account
  - [ ] Key Vault
  - [ ] Managed identities and RBAC assignments
  - [ ] Application Insights
- [ ] Generate `terraform.tfvars.example`
- [ ] Generate `variables.tf` with descriptions

### Phase 2: Application Code
- [ ] Initialize Python project structure
- [ ] Create `requirements.txt` with dependencies:
  - `azure-functions`
  - `azure-search-documents`
  - `azure-identity`
  - `azure-storage-blob`
  - `openai` (for embeddings)
  - `pyodbc` (SQL connectivity)
  - `pydantic` (data validation)
- [ ] Implement search API functions
  - [ ] Vector search endpoint
  - [ ] Hybrid search endpoint
  - [ ] Security filter logic
- [ ] Implement document ingestion
  - [ ] Blob trigger for auto-indexing
  - [ ] Embedding generation
  - [ ] Security tagging
- [ ] Create data models (Pydantic)
- [ ] Add error handling and logging

### Phase 3: Database Schema
- [ ] Create SQL initialization script
  - [ ] `Advisors` table
  - [ ] `Clients` table
  - [ ] `AdvisorClientAccess` table (many-to-many)
  - [ ] Sample data insert scripts

### Phase 4: Search Index Configuration
- [ ] Create search index definition (JSON)
  - [ ] Text fields (title, content, summary)
  - [ ] Vector field (contentVector, 1536 dimensions)
  - [ ] Security field (allowedAdvisors)
  - [ ] Metadata fields (clientId, documentType, date)
- [ ] Configure analyzers and semantic configurations

### Phase 5: API Management Configuration
- [ ] Create APIM policy XML
  - [ ] Rate limiting
  - [ ] Request validation
  - [ ] Backend routing
- [ ] Define API operations
- [ ] Configure subscription keys

### Phase 6: Sample Data & Testing
- [ ] Create sample documents
- [ ] Create SQL seed data (10 advisors, 50 clients, mappings)
- [ ] Create Postman/REST collection
- [ ] Create test scenarios document

### Phase 7: Documentation
- [ ] README.md with quickstart
- [ ] ARCHITECTURE.md with detailed design
- [ ] DEPLOYMENT.md with step-by-step instructions
- [ ] API.md with endpoint documentation

---

## File Structure

```
ai_search_security/
├── .azure/
│   └── deployment-plan.md
├── infra/
│   ├── main.tf
│   ├── variables.tf
│   ├── outputs.tf
│   ├── terraform.tfvars.example
│   └── modules/
│       ├── search/
│       ├── functions/
│       ├── sql/
│       ├── apim/
│       ├── storage/
│       └── monitoring/
├── src/
│   ├── api/
│   │   ├── __init__.py
│   │   ├── function_app.py
│   │   ├── search.py
│   │   ├── documents.py
│   │   └── health.py
│   ├── ingestion/
│   │   ├── __init__.py
│   │   ├── function_app.py
│   │   └── blob_trigger.py
│   ├── shared/
│   │   ├── __init__.py
│   │   ├── models.py
│   │   ├── search_client.py
│   │   ├── sql_client.py
│   │   ├── security.py
│   │   └── embeddings.py
│   └── requirements.txt
├── data/
│   ├── sql/
│   │   ├── schema.sql
│   │   └── seed_data.sql
│   ├── search/
│   │   └── index_definition.json
│   ├── sample_documents/
│   │   └── (sample PDFs and reports)
│   └── apim/
│       └── policies.xml
├── tests/
│   └── (test files)
├── docs/
│   ├── ARCHITECTURE.md
│   ├── DEPLOYMENT.md
│   └── API.md
├── .gitignore
├── README.md
└── local.settings.json.example
```

---

## Cost Estimate (Monthly - Development)

| Service | SKU | Estimated Cost |
|---------|-----|----------------|
| Azure AI Search | Standard S1 | ~$250 |
| Azure OpenAI | Standard (embeddings) | ~$20 |
| Azure Functions | Premium EP1 | ~$150 |
| Azure SQL | Standard S0 | ~$15 |
| API Management | Developer | ~$50 |
| Storage | Standard LRS | ~$5 |
| Application Insights | Standard | ~$10 |
| **Total** | | **~$500/month** |

*Note: Costs vary by region and usage. For production, consider reserved capacity.*

---

## Prerequisites

- Azure subscription with Owner or Contributor role
- Terraform 1.5+ installed
- Azure CLI installed and authenticated (`az login`)
- Python 3.11 installed locally
- Azure Functions Core Tools v4
- Git for version control

---

## Success Criteria

- [ ] Vector search returns semantically relevant results
- [ ] Hybrid search combines keyword + vector effectively
- [ ] Security filters enforce advisor → client access control
- [ ] Advisors can only see their assigned clients' documents
- [ ] API Management properly authenticates and rate limits
- [ ] All services use managed identity (passwordless)
- [ ] Sample queries demonstrate all capabilities
- [ ] Complete documentation for deployment and usage

---

## Next Steps

**WAITING FOR APPROVAL** - Please review this plan. Once approved, I will:
1. Generate Terraform infrastructure code
2. Create Python Azure Functions
3. Set up database schema and sample data
4. Create search index configuration
5. Configure API Management
6. Add comprehensive documentation
7. Invoke azure-validate for pre-deployment checks
