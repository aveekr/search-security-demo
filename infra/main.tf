terraform {
  required_version = ">= 1.5.0"
  
  required_providers {
    azurerm = {
      source  = "hashicorp/azurerm"
      version = "~> 3.100"
    }
    azuread = {
      source  = "hashicorp/azuread"
      version = "~> 2.47"
    }
    random = {
      source  = "hashicorp/random"
      version = "~> 3.6"
    }
  }
}

provider "azurerm" {
  features {
    key_vault {
      purge_soft_delete_on_destroy = false
    }
    resource_group {
      prevent_deletion_if_contains_resources = false
    }
  }
  
  # Use Azure AD authentication for storage operations instead of keys
  storage_use_azuread = true
}

provider "azuread" {}

# Data sources
data "azurerm_client_config" "current" {}

data "azuread_client_config" "current" {}

# Random suffix for globally unique names
resource "random_string" "suffix" {
  length  = 6
  special = false
  upper   = false
}

# Resource Group
resource "azurerm_resource_group" "main" {
  name     = var.resource_group_name
  location = var.location
  tags     = var.tags
}

# Application Insights
resource "azurerm_log_analytics_workspace" "main" {
  name                = "${var.resource_prefix}-law-${random_string.suffix.result}"
  location            = azurerm_resource_group.main.location
  resource_group_name = azurerm_resource_group.main.name
  sku                 = "PerGB2018"
  retention_in_days   = 30
  tags                = var.tags
}

resource "azurerm_application_insights" "main" {
  name                = "${var.resource_prefix}-ai-${random_string.suffix.result}"
  location            = azurerm_resource_group.main.location
  resource_group_name = azurerm_resource_group.main.name
  workspace_id        = azurerm_log_analytics_workspace.main.id
  application_type    = "web"
  tags                = var.tags
}

# Storage Account
resource "azurerm_storage_account" "main" {
  name                     = "${replace(var.resource_prefix, "-", "")}st${random_string.suffix.result}"
  resource_group_name      = azurerm_resource_group.main.name
  location                 = azurerm_resource_group.main.location
  account_tier             = "Standard"
  account_replication_type = "LRS"
  min_tls_version          = "TLS1_2"
  
  # Disable shared key access for enhanced security (using Entra ID instead)
  shared_access_key_enabled = false
  
  blob_properties {
    versioning_enabled = true
  }
  
  tags = var.tags
}

resource "azurerm_storage_container" "documents" {
  name                  = "documents"
  storage_account_name  = azurerm_storage_account.main.name
  container_access_type = "private"
}

resource "azurerm_storage_container" "function_app" {
  name                  = "function-releases"
  storage_account_name  = azurerm_storage_account.main.name
  container_access_type = "private"
}

# Key Vault
resource "azurerm_key_vault" "main" {
  name                       = "${var.resource_prefix}-kv-${random_string.suffix.result}"
  location                   = azurerm_resource_group.main.location
  resource_group_name        = azurerm_resource_group.main.name
  tenant_id                  = data.azurerm_client_config.current.tenant_id
  sku_name                   = "standard"
  soft_delete_retention_days = 7
  purge_protection_enabled   = false
  enable_rbac_authorization  = true
  
  tags = var.tags
}

# Modules
module "search" {
  source              = "./modules/search"
  resource_group_name = azurerm_resource_group.main.name
  location            = azurerm_resource_group.main.location
  resource_prefix     = var.resource_prefix
  random_suffix       = random_string.suffix.result
  tags                = var.tags
}

module "openai" {
  source                       = "./modules/openai"
  resource_group_name          = azurerm_resource_group.main.name
  location                     = var.openai_location
  resource_prefix              = var.resource_prefix
  random_suffix                = random_string.suffix.result
  tags                         = var.tags
  embedding_model_name         = var.embedding_model_name
  embedding_model_version      = var.embedding_model_version
  embedding_deployment_name    = var.embedding_deployment_name
  embedding_deployment_capacity = var.embedding_deployment_capacity
}

module "sql" {
  source              = "./modules/sql"
  resource_group_name = azurerm_resource_group.main.name
  location            = azurerm_resource_group.main.location
  resource_prefix     = var.resource_prefix
  random_suffix       = random_string.suffix.result
  tenant_id           = data.azurerm_client_config.current.tenant_id
  current_user_id     = data.azuread_client_config.current.object_id
  tags                = var.tags
}

module "functions" {
  source                   = "./modules/functions"
  resource_group_name      = azurerm_resource_group.main.name
  location                 = azurerm_resource_group.main.location
  resource_prefix          = var.resource_prefix
  random_suffix            = random_string.suffix.result
  storage_account_name     = azurerm_storage_account.main.name
  app_insights_conn_string = azurerm_application_insights.main.connection_string
  app_insights_key         = azurerm_application_insights.main.instrumentation_key
  tags                     = var.tags
  
  # Service endpoints
  search_endpoint   = module.search.search_endpoint
  sql_server_fqdn   = module.sql.sql_server_fqdn
  sql_database_name = module.sql.sql_database_name
  openai_endpoint   = module.openai.openai_endpoint
  storage_account_name_docs = azurerm_storage_account.main.name
}

module "apim" {
  source               = "./modules/apim"
  resource_group_name  = azurerm_resource_group.main.name
  location             = azurerm_resource_group.main.location
  resource_prefix      = var.resource_prefix
  random_suffix        = random_string.suffix.result
  function_app_url     = module.functions.function_app_default_hostname
  function_app_key     = module.functions.function_app_key
  tags                 = var.tags
}

# RBAC Assignments

# Function App -> Search Service (Search Index Data Reader, Search Index Data Contributor)
resource "azurerm_role_assignment" "function_to_search_reader" {
  scope                = module.search.search_service_id
  role_definition_name = "Search Index Data Reader"
  principal_id         = module.functions.function_app_identity_principal_id
}

resource "azurerm_role_assignment" "function_to_search_contributor" {
  scope                = module.search.search_service_id
  role_definition_name = "Search Index Data Contributor"
  principal_id         = module.functions.function_app_identity_principal_id
}

resource "azurerm_role_assignment" "function_to_search_service_contributor" {
  scope                = module.search.search_service_id
  role_definition_name = "Search Service Contributor"
  principal_id         = module.functions.function_app_identity_principal_id
}

# Function App -> Storage Account (Storage Blob Data Contributor)
resource "azurerm_role_assignment" "function_to_storage" {
  scope                = azurerm_storage_account.main.id
  role_definition_name = "Storage Blob Data Contributor"
  principal_id         = module.functions.function_app_identity_principal_id
}

# Function App -> Storage Account (for file shares - required when using managed identity)
resource "azurerm_role_assignment" "function_to_storage_account" {
  scope                = azurerm_storage_account.main.id
  role_definition_name = "Storage Account Contributor"
  principal_id         = module.functions.function_app_identity_principal_id
}

# Function App -> Azure OpenAI (Cognitive Services OpenAI User)
resource "azurerm_role_assignment" "function_to_openai" {
  scope                = module.openai.openai_id
  role_definition_name = "Cognitive Services OpenAI User"
  principal_id         = module.functions.function_app_identity_principal_id
}

# Current user -> Key Vault (Key Vault Administrator)
resource "azurerm_role_assignment" "current_user_to_kv" {
  scope                = azurerm_key_vault.main.id
  role_definition_name = "Key Vault Administrator"
  principal_id         = data.azuread_client_config.current.object_id
}

# Function App -> Key Vault (Key Vault Secrets User)
resource "azurerm_role_assignment" "function_to_kv" {
  scope                = azurerm_key_vault.main.id
  role_definition_name = "Key Vault Secrets User"
  principal_id         = module.functions.function_app_identity_principal_id
}
