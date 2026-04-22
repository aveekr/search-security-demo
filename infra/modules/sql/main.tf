# SQL Server with Entra ID authentication only
resource "azurerm_mssql_server" "main" {
  name                         = "${var.resource_prefix}-sql-${var.random_suffix}"
  resource_group_name          = var.resource_group_name
  location                     = var.location
  version                      = "12.0"
  minimum_tls_version          = "1.2"
  
  # Entra ID (Azure AD) authentication only - NO SQL authentication
  azuread_administrator {
    login_username              = var.current_user_id
    object_id                   = var.current_user_id
    azuread_authentication_only = true
  }
  
  tags = var.tags
}

# SQL Database
resource "azurerm_mssql_database" "main" {
  name           = "${var.resource_prefix}-sqldb"
  server_id      = azurerm_mssql_server.main.id
  collation      = "SQL_Latin1_General_CP1_CI_AS"
  sku_name       = "S0"
  max_size_gb    = 10
  zone_redundant = false
  
  tags = var.tags
}

# Firewall rule to allow Azure services
resource "azurerm_mssql_firewall_rule" "allow_azure_services" {
  name             = "AllowAzureServices"
  server_id        = azurerm_mssql_server.main.id
  start_ip_address = "0.0.0.0"
  end_ip_address   = "0.0.0.0"
}
