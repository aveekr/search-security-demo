# Service Plan for Azure Functions
resource "azurerm_service_plan" "main" {
  name                = "${var.resource_prefix}-plan-${var.random_suffix}"
  resource_group_name = var.resource_group_name
  location            = var.location
  os_type             = "Linux"
  sku_name            = "EP1"
  
  tags = var.tags
}

# Linux Function App
resource "azurerm_linux_function_app" "main" {
  name                        = "${var.resource_prefix}-func-${var.random_suffix}"
  resource_group_name         = var.resource_group_name
  location                    = var.location
  service_plan_id             = azurerm_service_plan.main.id
  storage_account_name        = var.storage_account_name
  storage_uses_managed_identity = true
  
  site_config {
    application_stack {
      python_version = "3.11"
    }
    
    ftps_state = "Disabled"
    
    cors {
      allowed_origins = ["*"]
    }
  }
  
  app_settings = {
    "FUNCTIONS_WORKER_RUNTIME"              = "python"
    "APPLICATIONINSIGHTS_CONNECTION_STRING" = var.app_insights_conn_string
    "APPINSIGHTS_INSTRUMENTATIONKEY"        = var.app_insights_key
    "AzureWebJobsFeatureFlags"              = "EnableWorkerIndexing"
    
    # Service endpoints (managed identity)
    "AZURE_SEARCH_ENDPOINT"      = var.search_endpoint
    "AZURE_SQL_SERVER"           = var.sql_server_fqdn
    "AZURE_SQL_DATABASE"         = var.sql_database_name
    "AZURE_OPENAI_ENDPOINT"      = var.openai_endpoint
    "STORAGE_ACCOUNT_NAME"       = var.storage_account_name_docs
    "DOCUMENTS_CONTAINER"        = "documents"
    
    # Search index configuration
    "SEARCH_INDEX_NAME"          = "capital-markets-docs"
    
    # OpenAI configuration
    "OPENAI_EMBEDDING_DEPLOYMENT" = "text-embedding-ada-002"
    "OPENAI_API_VERSION"         = "2024-02-01"
    
    # Use managed identity for authentication
    "AZURE_CLIENT_ID" = ""  # Empty for system-assigned managed identity
  }
  
  identity {
    type = "SystemAssigned"
  }
  
  tags = var.tags
}

# Function App Host Keys (for APIM)
data "azurerm_function_app_host_keys" "main" {
  name                = azurerm_linux_function_app.main.name
  resource_group_name = var.resource_group_name
  
  depends_on = [azurerm_linux_function_app.main]
}
