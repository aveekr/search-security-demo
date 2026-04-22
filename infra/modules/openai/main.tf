# Azure OpenAI Service
resource "azurerm_cognitive_account" "openai" {
  name                = "${var.resource_prefix}-openai-${var.random_suffix}"
  location            = var.location
  resource_group_name = var.resource_group_name
  kind                = "OpenAI"
  sku_name            = "S0"
  
  custom_subdomain_name = "${var.resource_prefix}-openai-${var.random_suffix}"
  
  tags = var.tags
}

# Embedding model deployment
resource "azurerm_cognitive_deployment" "embedding" {
  name                 = var.embedding_deployment_name
  cognitive_account_id = azurerm_cognitive_account.openai.id
  
  model {
    format  = "OpenAI"
    name    = var.embedding_model_name
    version = var.embedding_model_version
  }
  
  scale {
    type     = "Standard"
    capacity = var.embedding_deployment_capacity
  }
}
