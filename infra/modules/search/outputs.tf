output "search_service_id" {
  description = "ID of the Search Service"
  value       = azurerm_search_service.main.id
}

output "search_service_name" {
  description = "Name of the Search Service"
  value       = azurerm_search_service.main.name
}

output "search_endpoint" {
  description = "Endpoint URL of the Search Service"
  value       = "https://${azurerm_search_service.main.name}.search.windows.net"
}
