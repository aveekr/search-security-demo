window.DEMO_CONFIG = {
  // Azure Entra app registration for browser login
  entra: {
    clientId: "<YOUR_ENTRA_APP_CLIENT_ID>",
    tenantId: "<YOUR_TENANT_ID>",
    redirectUri: "http://localhost:8080"
  },

  // Function App endpoint for APIs
  api: {
    baseUrl: "https://aisearch-demo-func-wyjsbl.azurewebsites.net",
    functionKey: "<YOUR_FUNCTION_KEY>"
  },

  // Optional fallback map for quick demo if SQL mapping is not set.
  // Key: login UPN/email, Value: advisorId
  fallbackAdvisorMap: {
    "advisor1@contoso.com": "advisor-001",
    "advisor2@contoso.com": "advisor-003",
    "advisor3@contoso.com": "advisor-010"
  }
};
