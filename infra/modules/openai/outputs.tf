output "openai_id" {
  description = "ID of the OpenAI account"
  value       = azurerm_cognitive_account.openai.id
}

output "openai_name" {
  description = "Name of the OpenAI account"
  value       = azurerm_cognitive_account.openai.name
}

output "openai_endpoint" {
  description = "Endpoint URL of the OpenAI account"
  value       = azurerm_cognitive_account.openai.endpoint
}

output "embedding_deployment_name" {
  description = "Name of the embedding deployment"
  value       = azurerm_cognitive_deployment.embedding.name
}
