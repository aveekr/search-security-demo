# Sample Document Upload Scripts

This directory contains scripts for uploading and managing sample documents.

## Scripts

### upload_documents.py

Uploads all sample documents from `data/documents/` to the Azure AI Search index via the API Management gateway.

**Usage**:

1. **Configure the script**:
   ```python
   APIM_GATEWAY_URL = "https://your-apim.azure-api.net"
   ACCESS_TOKEN = "your-oauth-token"
   ```

2. **Get OAuth Token** (PowerShell):
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

3. **Run the script**:
   ```bash
   python upload_documents.py
   ```

**Output**:
```
Loading documents from data\documents...
Loaded 18 documents

[1/18] Uploading: Q4 2024 Technology Sector Analysis - Client 001...
  ✓ Success - Document ID: doc-8f3c2a91
[2/18] Uploading: ESG Investment Opportunities 2024 - Client 005...
  ✓ Success - Document ID: doc-7b2d1f45
...
============================================================
Upload Summary:
  Total documents: 18
  Successful: 18
  Failed: 0
============================================================
```

## Sample Documents

The `data/documents/` directory contains 18 capital markets documents:

| File | Title | Client | Type | Advisors |
|------|-------|--------|------|----------|
| doc_001.json | Q4 2024 Technology Sector Analysis | client-001 | market-analysis | advisor-001, advisor-002 |
| doc_002.json | ESG Investment Opportunities 2024 | client-005 | portfolio-recommendation | advisor-001, advisor-003 |
| doc_003.json | Dividend Growth Strategy Report | client-012 | portfolio-recommendation | advisor-002, advisor-004 |
| doc_004.json | Emerging Markets Investment Thesis | client-018 | research-report | advisor-003, advisor-006 |
| doc_005.json | Real Estate Investment Trust Analysis | client-007 | market-analysis | advisor-002, advisor-004, advisor-007 |
| doc_006.json | Cryptocurrency Portfolio Allocation | client-025 | portfolio-recommendation | advisor-005 |
| doc_007.json | Fixed Income Strategy Rising Rates | client-030 | market-analysis | advisor-006, advisor-008 |
| doc_008.json | Healthcare Sector Opportunities | client-014 | research-report | advisor-003, advisor-007 |
| doc_009.json | Retirement Income Drawdown Strategy | client-042 | portfolio-recommendation | advisor-008, advisor-009 |
| doc_010.json | Small Cap Growth Investment Thesis | client-021 | research-report | advisor-004, advisor-005 |
| doc_011.json | Commodities and Inflation Protection | client-036 | market-analysis | advisor-007, advisor-010 |
| doc_012.json | Quantitative Investment Strategy | client-048 | portfolio-recommendation | advisor-009, advisor-010 |
| doc_013.json | International Developed Markets | client-033 | research-report | advisor-006, advisor-008 |
| doc_014.json | Tax-Efficient Investing Strategies | client-027 | portfolio-recommendation | advisor-005, advisor-009 |
| doc_015.json | Alternative Investments Diversification | client-039 | market-analysis | advisor-010 |
| doc_016.json | Cybersecurity Investment Opportunities | client-016 | research-report | advisor-003, advisor-004 |
| doc_017.json | Climate Change Investment Impact | client-024 | market-analysis | advisor-005, advisor-006 |
| doc_018.json | FIRE Strategy Analysis | client-011 | portfolio-recommendation | advisor-002, advisor-005 |

## Testing Security

After uploading, test document-level security:

```bash
# Search as advisor-001 (should find documents where allowed)
curl -X POST "$APIM_URL/search" \
  -H "Authorization: Bearer $TOKEN" \
  -d '{"query": "technology AI investment", "advisorId": "advisor-001", "searchType": "hybrid"}'

# Search as advisor-010 (different results based on access)
curl -X POST "$APIM_URL/search" \
  -H "Authorization: Bearer $TOKEN" \
  -d '{"query": "technology AI investment", "advisorId": "advisor-010", "searchType": "hybrid"}'
```

Results should differ based on `allowedAdvisors` field in each document.
