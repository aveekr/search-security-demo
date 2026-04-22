# Azure AI Search Service
resource "azurerm_search_service" "main" {
  name                = "${var.resource_prefix}-search-${var.random_suffix}"
  resource_group_name = var.resource_group_name
  location            = var.location
  sku                 = "standard"
  replica_count       = 1
  partition_count     = 1
  
  # Enable semantic search for better ranking
  semantic_search_sku = "standard"
  
  # Disable public network access - can be enabled for demo
  public_network_access_enabled = true
  
  # Authentication via Azure AD/Managed Identity
  authentication_failure_mode = "http403"
  
  tags = var.tags
}
