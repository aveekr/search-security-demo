# Azure AI Search Security Demo

![Azure](https://img.shields.io/badge/Azure-0078D4?style=flat&logo=microsoft-azure&logoColor=white)
![Python](https://img.shields.io/badge/Python-3.11-blue?style=flat&logo=python&logoColor=white)
![Terraform](https://img.shields.io/badge/Terraform-7B42BC?style=flat&logo=terraform&logoColor=white)
![License](https://img.shields.io/badge/License-MIT-green.svg)

Enterprise-grade demonstration of **Azure AI Search** with document-level security filtering for capital markets. Features vector search, hybrid search, and row-level security managed via Azure SQL Database.

## 🎯 Key Features

- **🔍 Vector Search**: Semantic similarity search using Azure OpenAI embeddings
- **🔀 Hybrid Search**: Combined keyword + vector search for optimal results
- **🔒 Document-Level Security**: Fine-grained access control per advisor
- **🖥️ Demo Web UI**: Login, upload, and search workflows for live demos
- **🏦 Capital Markets Scenario**: Advisors → Clients access model
- **🔐 OAuth 2.0**: Secure API access via Microsoft Entra ID
- **👤 Identity Mapping**: Logged-in Entra users map to advisor IDs
- **🚀 API Management**: Centralized gateway with rate limiting
- **🔑 Passwordless**: Managed identities throughout

## 📊 Architecture

```
┌──────────────────────┐
│ Demo Web UI          │ Login + Upload + Search
└──────────┬───────────┘
      │ OAuth 2.0
┌──────────▼───────────┐
│ API Mgmt             │ JWT validation, policies
└──────────┬───────────┘
      │
┌──────────▼────────────────────────────────────┐
│ Azure Functions (Python 3.11)                │
│ ├─ Search API (Vector, Hybrid, Security)     │
│ ├─ Document Ingestion (Indexing)             │
│ └─ User Context API (identity -> advisorId)  │
└──────────┬───────────────────┬───────────────┘
      │                   │
┌──────────▼─────────┐   ┌─────▼───────────────┐
│ AI Search          │   │ Azure SQL           │
│ + Vectors          │   │ + Advisor Access    │
│ + Security Filter  │   │ + User Identity Map │
└────────────────────┘   └─────────────────────┘
```

## 🚀 Quick Start

### Prerequisites

- Azure subscription ([Free tier](https://azure.microsoft.com/free/))
- [Terraform](https://www.terraform.io/downloads) 1.5+
- [Azure CLI](https://docs.microsoft.com/cli/azure/install-azure-cli)
- [Python](https://www.python.org/downloads/) 3.11+
- [Azure Functions Core Tools](https://docs.microsoft.com/azure/azure-functions/functions-run-local) v4

### 1. Deploy Infrastructure

```bash
# Login to Azure
az login

# Navigate to infrastructure directory
cd infra

# Copy and configure variables
cp terraform.tfvars.example terraform.tfvars
# Edit terraform.tfvars with your values

# Initialize and deploy
terraform init
terraform plan
terraform apply
```

### 2. Initialize Database

```bash
# Get SQL Server FQDN from Terraform outputs
SQL_SERVER=$(terraform output -raw sql_server_name)
SQL_DB=$(terraform output -raw sql_database_name)

# Run schema and seed scripts (using Entra ID auth)
cd ../data/sql
sqlcmd -S $SQL_SERVER.database.windows.net -d $SQL_DB -G -i schema.sql
sqlcmd -S $SQL_SERVER.database.windows.net -d $SQL_DB -G -i seed_data.sql
```

### 3. Create Search Index

```bash
# Using Azure Portal:
# 1. Navigate to your AI Search service
# 2. Go to "Indexes" → "Add Index" → "Import JSON"
# 3. Upload: data/search/index_definition.json

# OR using Azure CLI:
SEARCH_SERVICE=$(terraform output -raw search_service_name)
az search index create \
  --service-name $SEARCH_SERVICE \
  --index-definition @../data/search/index_definition.json
```

### 4. Deploy Functions

```bash
cd ../../src

# Create local settings from template
cp local.settings.json.example local.settings.json

# Install dependencies
pip install -r requirements.txt

# Deploy to Azure
FUNCTION_APP=$(terraform output -raw function_app_name)
func azure functionapp publish $FUNCTION_APP
```

### 5. Test the API

```bash
# Get API Gateway URL
APIM_URL=$(terraform output -raw apim_gateway_url)

# Health check
curl $APIM_URL/api/health

# Search (requires OAuth token)
curl -X POST $APIM_URL/api/search \
  -H "Authorization: Bearer YOUR_TOKEN" \
  -H "Content-Type: application/json" \
  -d '{
    "query": "Q4 market analysis",
    "advisorId": "advisor-001",
    "searchType": "hybrid",
    "top": 10
  }'
```

## 📖 Documentation

- **[Architecture](docs/ARCHITECTURE.md)** - Detailed design and data flow
- **[Deployment Guide](docs/DEPLOYMENT.md)** - Step-by-step deployment
- **[API Reference](docs/API.md)** - Endpoint documentation and examples

## 🖥️ Demo UI (Login + Upload + Search)

The `web/` app supports:
- Entra login with different credentials
- user -> advisor mapping
- document upload
- advisor-scoped search results

### 1. Configure user mapping in SQL

Run incremental script:

```powershell
cd data/sql
sqlcmd -S <sql-server>.database.windows.net -d <database> -G -i user_identity_map.sql
```

Update rows in `UserIdentityMap` with real Entra `oid` and UPN values for your demo users.

### 2. Configure web app

```powershell
cd web
copy config.sample.js config.js
```

Edit `config.js` values:
- `entra.clientId`
- `entra.tenantId`
- `api.baseUrl`
- `api.functionKey`

### 3. Run locally

```powershell
cd web
python -m http.server 8080
```

Open `http://localhost:8080` and sign in with different Entra users.

### 4. Demo behavior

1. Login as user A mapped to `advisor-001`, run search
2. Logout, login as user B mapped to `advisor-003`, run same search
3. Show different results due to advisor security filter

## 🔐 Security Model

### Document-Level Filtering

Each document in the search index has an `allowedAdvisors` field:

```json
{
  "id": "doc-20260419120000-client-005",
  "title": "Q4 Portfolio Analysis",
  "content": "...",
  "allowedAdvisors": ["advisor-001", "advisor-002"]
}
```

At **query time**, the API automatically applies a security filter:

```python
filter = f"search.in(allowedAdvisors, '{advisor_id}', ',')"
```

This ensures advisors can **only** see documents they're authorized to access.

## 🗂️ Project Structure

```
ai_search_security/
├── infra/                  # Terraform infrastructure
│   ├── main.tf
│   ├── modules/
│   │   ├── search/
│   │   ├── functions/
│   │   ├── sql/
│   │   └── apim/
│   └── terraform.tfvars.example
├── src/                    # Python Functions
│   ├── api/                # HTTP endpoints
│   ├── shared/             # Shared utilities
│   └── requirements.txt
├── data/
│   ├── sql/                # Database schema + seed data
│   └── search/             # Index definition
├── docs/                   # Documentation
└── README.md
```

## 💡 Sample Queries

### Vector Search
```json
{
  "query": "sustainable investment opportunities",
  "advisorId": "advisor-001",
  "searchType": "vector",
  "top": 5
}
```

### Hybrid Search (Recommended)
```json
{
  "query": "Q4 2025 market volatility analysis",
  "advisorId": "advisor-003",
  "searchType": "hybrid",
  "top": 10
}
```

### Keyword Search
```json
{
  "query": "dividend stocks",
  "advisorId": "advisor-005",
  "searchType": "keyword",
  "top": 20
}
```

## 🧪 Testing

Sample data includes:
- **10 Advisors** (advisor-001 through advisor-010)
- **50 Clients** (client-001 through client-050)
- **Overlapping assignments** (some clients have multiple advisors)

Test with different `advisorId` values to see security filtering in action.

## 💰 Cost Estimation

Development environment (~$500/month):

| Service | SKU | Monthly Cost |
|---------|-----|--------------|
| Azure AI Search | Standard S1 | ~$250 |
| Azure OpenAI | Embeddings | ~$20 |
| Azure Functions | Premium EP1 | ~$150 |
| Azure SQL | Standard S0 | ~$15 |
| API Management | Developer | ~$50 |
| Storage + Monitoring | Standard | ~$15 |

**Production**: Use reserved capacity and scale appropriately.

## 📝 License

MIT License - see [LICENSE](LICENSE) file for details.

## 🤝 Contributing

Contributions welcome! Please open an issue or pull request.

## 📧 Support

For questions or issues:
- Open a [GitHub Issue](../../issues)
- Review the [Documentation](docs/)

---

**Built with ❤️ using Azure AI Search, Azure Functions, and Terraform**
