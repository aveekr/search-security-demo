output "apim_id" {
  description = "ID of the API Management service"
  value       = azurerm_api_management.main.id
}

output "apim_name" {
  description = "Name of the API Management service"
  value       = azurerm_api_management.main.name
}

output "apim_gateway_url" {
  description = "Gateway URL of the API Management service"
  value       = azurerm_api_management.main.gateway_url
}

output "apim_identity_principal_id" {
  description = "Principal ID of APIM's managed identity"
  value       = azurerm_api_management.main.identity[0].principal_id
}
